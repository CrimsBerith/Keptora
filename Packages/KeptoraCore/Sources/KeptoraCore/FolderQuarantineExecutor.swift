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
        let planID = UUID()
        let quarantineRoot = root.appendingPathComponent(".Keptora Quarantine", isDirectory: true)
            .appendingPathComponent(planID.uuidString, isDirectory: true)
        var operations: [FolderQuarantineOperation] = []

        for selection in selections {
            guard case .file(let originalURL) = selection.asset.reference,
                  originalURL.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") else {
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

        var completed: [FolderQuarantineOperation] = []
        do {
            for operation in operations {
                try Task.checkCancellation()
                try FileManager.default.createDirectory(
                    at: operation.quarantineURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try coordinatedMove(from: operation.originalURL, to: operation.quarantineURL)
                completed.append(operation)
            }
        } catch {
            for operation in completed.reversed() where !FileManager.default.fileExists(atPath: operation.originalURL.path) {
                try? FileManager.default.createDirectory(at: operation.originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? coordinatedMove(from: operation.quarantineURL, to: operation.originalURL)
            }
            throw error
        }
        return FolderQuarantineRecord(id: planID, sourceRoot: root, operations: operations)
    }

    public func restore(_ record: FolderQuarantineRecord) async throws -> FolderQuarantineRecord {
        for operation in record.operations {
            try Task.checkCancellation()
            guard FileManager.default.fileExists(atPath: operation.quarantineURL.path),
                  !FileManager.default.fileExists(atPath: operation.originalURL.path) else {
                throw UniversalScanError.cleanupNotPermitted("Restore stopped because an original path is occupied or quarantine content is missing.")
            }
            let fresh = try await StreamingSHA256.file(at: operation.quarantineURL, progress: { _ in })
            guard fresh.digest == operation.expectedDigest else {
                throw UniversalScanError.cleanupNotPermitted("Restore stopped because quarantined content changed.")
            }
        }
        for operation in record.operations {
            try FileManager.default.createDirectory(at: operation.originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try coordinatedMove(from: operation.quarantineURL, to: operation.originalURL)
        }
        return FolderQuarantineRecord(
            id: record.id,
            createdAt: record.createdAt,
            sourceRoot: record.sourceRoot,
            operations: record.operations,
            restoredAt: Date()
        )
    }

    private func coordinatedMove(from source: URL, to destination: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(
            writingItemAt: source,
            options: .forMoving,
            writingItemAt: destination,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedSource, coordinatedDestination in
            do { try FileManager.default.moveItem(at: coordinatedSource, to: coordinatedDestination) }
            catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
    }
}

