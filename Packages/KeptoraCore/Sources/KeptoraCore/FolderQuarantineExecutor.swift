import Foundation

public actor FolderQuarantineExecutor {
    public init() {}

    public func preflight(root: URL) -> Bool {
        let values = try? root.resourceValues(forKeys: [.isWritableKey, .isDirectoryKey])
        return values?.isDirectory == true && values?.isWritable == true
    }

    public func quarantine(
        root: URL,
        selections: [(asset: UniversalMediaAsset, expectedDigest: String)],
        allowPartialFamilies: Bool = false
    ) async throws -> FolderQuarantineRecord {
        guard preflight(root: root) else {
            throw UniversalScanError.cleanupNotPermitted("This Files provider does not currently allow safe coordinated moves. Review is still available.")
        }
        guard !selections.isEmpty else { throw UniversalScanError.cleanupNotPermitted("No files were selected.") }
        if !allowPartialFamilies, !LibraryFileFamilies.omittedCompanions(for: selections.map(\.asset)).isEmpty {
            throw UniversalScanError.cleanupNotPermitted(L10n.tr("Linked files remain outside your selection. Review them before removing this photo."))
        }
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
            try validateReviewed([selection.asset])
            let fresh = try await StreamingSHA256.file(at: originalURL, progress: { _ in })
            try validateReviewed([selection.asset])
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

        var record = FolderQuarantineRecord(id: planID, sourceRoot: root, operations: operations)
        // Persist before moving the first byte. Recovery survives an interrupted app
        // or lost preferences, and never relies solely on an in-memory history entry.
        try saveManifest(record)
        var completed: [FolderQuarantineOperation] = []
        do {
            for (index, operation) in operations.enumerated() {
                try Task.checkCancellation()
                try FileManager.default.createDirectory(
                    at: operation.quarantineURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let beforeMove = try await StreamingSHA256.file(at: operation.originalURL, progress: { _ in })
                try validateReviewed([selections[index].asset])
                guard beforeMove.digest == operation.expectedDigest else {
                    throw UniversalScanError.cleanupNotPermitted("A selected file changed after review. Scan again before cleanup.")
                }
                try coordinatedMove(from: operation.originalURL, to: operation.quarantineURL)
                completed.append(operation)
                let afterMove = try await StreamingSHA256.file(at: operation.quarantineURL, progress: { _ in })
                guard afterMove.digest == operation.expectedDigest else {
                    throw UniversalScanError.cleanupNotPermitted("A selected file changed while moving. The operation was rolled back.")
                }
                record.operations[index].state = .moved
                record.operations[index].byteCount = afterMove.byteCount
                try saveManifest(record)
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
    public func recoveryRecords(root: URL) async throws -> [FolderQuarantineRecord] {
        let directory = root.appendingPathComponent(".Keptora Quarantine", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        var records: [FolderQuarantineRecord] = []
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                guard let data = try? Data(contentsOf: url.appendingPathComponent("recovery.json")),
                      let record = try? JSONDecoder().decode(FolderQuarantineRecord.self, from: data),
                      url.lastPathComponent == record.id.uuidString else { continue }
                var rebased = try record.rebased(to: root)
                for i in rebased.operations.indices {
                    let op = rebased.operations[i]
                    let inRecovery = FileManager.default.fileExists(atPath: op.quarantineURL.path)
                    let atOriginal = FileManager.default.fileExists(atPath: op.originalURL.path)
                    let location = inRecovery ? op.quarantineURL : op.originalURL
                    if (inRecovery || atOriginal), let hash = try? await StreamingSHA256.file(at: location, progress: { _ in }), hash.digest == op.expectedDigest {
                        rebased.operations[i].state = inRecovery ? .moved : .restored
                        rebased.operations[i].byteCount = hash.byteCount
                        rebased.operations[i].needsAttention = inRecovery && atOriginal
                    } else { rebased.operations[i].state = .interrupted }
                }
                if rebased.operations.allSatisfy({ $0.state == .restored }) { rebased.restoredAt = rebased.restoredAt ?? Date() }
                try saveManifest(rebased)
                records.append(rebased)
            }
        return records
    }

    public func restore(_ record: FolderQuarantineRecord) async throws -> FolderQuarantineRecord {
        guard record.sourceIdentity == nil || record.sourceIdentity == LibraryFileIdentity.key(for: record.sourceRoot) else {
            throw UniversalScanError.cleanupNotPermitted(L10n.tr("Reconnect the original source before restoring these files."))
        }
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
                if let index = restored.operations.firstIndex(where: { $0.id == operation.id }) { restored.operations[index].state = .restored }
                // A durable partial restore must not claim every operation is complete.
                restored.restoredAt = nil
                try saveManifest(restored)
            }
            for i in restored.operations.indices { restored.operations[i].state = .restored; restored.operations[i].needsAttention = false }
            restored.restoredAt = Date()
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
    private func validateReviewed(_ assets: [UniversalMediaAsset]) throws {
        do { try LibraryRevisionValidator.validate(assets) }
        catch UnifiedLibraryError.selectionChanged {
            throw UniversalScanError.cleanupNotPermitted("A selected file changed after review. Scan again before cleanup.")
        }
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
