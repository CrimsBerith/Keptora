import Foundation

public struct FolderQuarantineOperation: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let originalURL: URL
    public let quarantineURL: URL
    public let expectedDigest: String

    public init(originalURL: URL, quarantineURL: URL, expectedDigest: String) {
        self.id = UUID()
        self.originalURL = originalURL
        self.quarantineURL = quarantineURL
        self.expectedDigest = expectedDigest
    }
}

public struct FolderQuarantineRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let sourceRoot: URL
    public let operations: [FolderQuarantineOperation]
    public var restoredAt: Date?

    public init(id: UUID = UUID(), createdAt: Date = Date(), sourceRoot: URL, operations: [FolderQuarantineOperation], restoredAt: Date? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.sourceRoot = sourceRoot
        self.operations = operations
        self.restoredAt = restoredAt
    }
}

public actor FolderQuarantineExecutor {
    public init() {}

    public func preflight(root: URL) -> Bool {
        let values = try? root.resourceValues(forKeys: [.isWritableKey, .isDirectoryKey])
        return values?.isDirectory == true && values?.isWritable == true
    }

    public func quarantine(
        root: URL,
        selections: [(asset: UniversalMediaAsset, expectedDigest: String)]
    ) async throws -> FolderQuarantineRecord {
        guard preflight(root: root) else {
            throw UniversalScanError.cleanupNotPermitted("This Files provider does not currently allow safe coordinated moves. Review is still available.")
        }
        guard !selections.isEmpty else { throw UniversalScanError.cleanupNotPermitted("No files were selected.") }
        let planID = UUID()
        let quarantineRoot = root.appendingPathComponent(".Keptora Quarantine", isDirectory: true)
            .appendingPathComponent(planID.uuidString, isDirectory: true)
        var operations: [FolderQuarantineOperation] = []
        var paths = Set<String>()

        for selection in selections {
            guard case .file(let originalURL) = selection.asset.reference,
                  originalURL.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/"),
                  paths.insert(originalURL.standardizedFileURL.path).inserted else {
                throw UniversalScanError.cleanupNotPermitted("Keptora blocked an item outside the selected source.")
            }
            let fresh = try await StreamingSHA256.file(at: originalURL, progress: { _ in })
            guard fresh.digest == selection.expectedDigest else {
                throw UniversalScanError.cleanupNotPermitted("A selected file changed after review. Scan again before cleanup.")
            }
            let relative = String(originalURL.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
            let destination = quarantineRoot.appendingPathComponent(relative)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw UniversalScanError.cleanupNotPermitted("Keptora blocked a quarantine name collision.")
            }
            operations.append(
                FolderQuarantineOperation(
                    originalURL: originalURL,
                    quarantineURL: destination,
                    expectedDigest: selection.expectedDigest
                )
            )
        }

        let record = FolderQuarantineRecord(id: planID, sourceRoot: root, operations: operations)
        // Persist before moving the first byte. Recovery survives an interrupted app
        // or lost preferences, and never relies solely on an in-memory history entry.
        try saveManifest(record)
        var completed: [FolderQuarantineOperation] = []
        do {
            for operation in operations {
                try Task.checkCancellation()
                try FileManager.default.createDirectory(
                    at: operation.quarantineURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let beforeMove = try await StreamingSHA256.file(at: operation.originalURL, progress: { _ in })
                guard beforeMove.digest == operation.expectedDigest else {
                    throw UniversalScanError.cleanupNotPermitted("A selected file changed after review. Scan again before cleanup.")
                }
                try coordinatedMove(from: operation.originalURL, to: operation.quarantineURL)
                completed.append(operation)
                let afterMove = try await StreamingSHA256.file(at: operation.quarantineURL, progress: { _ in })
                guard afterMove.digest == operation.expectedDigest else {
                    throw UniversalScanError.cleanupNotPermitted("A selected file changed while moving. The operation was rolled back.")
                }
            }
        } catch {
            var rollbackFailed = false
            for operation in completed.reversed() {
                do { try coordinatedMove(from: operation.quarantineURL, to: operation.originalURL) }
                catch { rollbackFailed = true }
            }
            if rollbackFailed {
                throw UniversalScanError.cleanupNotPermitted("Some files remain in the recovery folder. Reopen this source and restore its recovery record.")
            }
            try? FileManager.default.removeItem(at: quarantineRoot)
            throw error
        }
        return record
    }

    /// Reload disk manifests so interrupted operations can be recovered after relaunch.
    public func recoveryRecords(root: URL) throws -> [FolderQuarantineRecord] {
        let directory = root.appendingPathComponent(".Keptora Quarantine", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .compactMap { url in
                guard let data = try? Data(contentsOf: url.appendingPathComponent("recovery.json")),
                      let record = try? JSONDecoder().decode(FolderQuarantineRecord.self, from: data),
                      record.sourceRoot.standardizedFileURL == root.standardizedFileURL else { return nil }
                return record
            }
    }

    public func restore(_ record: FolderQuarantineRecord) async throws -> FolderQuarantineRecord {
        var pending: [FolderQuarantineOperation] = []
        let root = record.sourceRoot.resolvingSymlinksInPath().path + "/"
        let quarantineRoot = record.sourceRoot.appendingPathComponent(".Keptora Quarantine")
            .appendingPathComponent(record.id.uuidString).resolvingSymlinksInPath().path + "/"
        for operation in record.operations {
            try Task.checkCancellation()
            guard operation.originalURL.resolvingSymlinksInPath().path.hasPrefix(root),
                  operation.quarantineURL.resolvingSymlinksInPath().path.hasPrefix(quarantineRoot) else {
                throw UniversalScanError.cleanupNotPermitted("A recovery path is outside its original source.")
            }
            let inRecovery = FileManager.default.fileExists(atPath: operation.quarantineURL.path)
            let atOriginal = FileManager.default.fileExists(atPath: operation.originalURL.path)
            guard inRecovery != atOriginal else {
                throw UniversalScanError.cleanupNotPermitted("Restore stopped because an original path is occupied or quarantine content is missing.")
            }
            // A crash halfway through restore is resumable if originals match.
            let fresh = try await StreamingSHA256.file(at: inRecovery ? operation.quarantineURL : operation.originalURL, progress: { _ in })
            guard fresh.digest == operation.expectedDigest else {
                throw UniversalScanError.cleanupNotPermitted("Restore stopped because recovery content changed.")
            }
            if inRecovery { pending.append(operation) }
        }
        var completed: [FolderQuarantineOperation] = []
        var restored = record
        restored.restoredAt = Date()
        do {
            for operation in pending {
                try Task.checkCancellation()
                try FileManager.default.createDirectory(at: operation.originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try coordinatedMove(from: operation.quarantineURL, to: operation.originalURL)
                completed.append(operation)
            }
            try saveManifest(restored)
        } catch {
            var rollbackFailed = false
            for operation in completed.reversed() {
                do { try coordinatedMove(from: operation.originalURL, to: operation.quarantineURL) }
                catch { rollbackFailed = true }
            }
            if rollbackFailed {
                throw UniversalScanError.cleanupNotPermitted("Restore was interrupted. Keep the recovery folder and retry; verified originals will be preserved.")
            }
            throw error
        }
        return restored
    }

    private func saveManifest(_ record: FolderQuarantineRecord) throws {
        let directory = record.sourceRoot.appendingPathComponent(".Keptora Quarantine", isDirectory: true)
            .appendingPathComponent(record.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: directory.appendingPathComponent("recovery.json"), options: .atomic)
    }

    private func coordinatedMove(from source: URL, to destination: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(
            writingItemAt: source,
            options: .forMoving,
            writingItemAt: destination,
            options: [],
            error: &coordinationError
        ) { coordinatedSource, coordinatedDestination in
            do { try FileManager.default.moveItem(at: coordinatedSource, to: coordinatedDestination) }
            catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
    }
}

