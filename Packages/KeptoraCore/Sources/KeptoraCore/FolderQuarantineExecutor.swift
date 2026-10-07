import Foundation

public actor FolderQuarantineExecutor {
    private var verified: [URL: (LibraryFileRevision, UniversalExactFingerprint)] = [:]
    private let beforeRestoreMove: (@Sendable (FolderQuarantineOperation, Int) async throws -> Void)?
    private let afterRestoreMove: (@Sendable (FolderQuarantineOperation, Int) async throws -> Void)?
    public init(beforeRestoreMove: (@Sendable (FolderQuarantineOperation, Int) async throws -> Void)? = nil,
                afterRestoreMove: (@Sendable (FolderQuarantineOperation, Int) async throws -> Void)? = nil) {
        self.beforeRestoreMove = beforeRestoreMove; self.afterRestoreMove = afterRestoreMove
    }

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
        var reviewedAssets = selections.map(\.asset)
        do {
            for (index, operation) in operations.enumerated() {
                try Task.checkCancellation()
                try FileManager.default.createDirectory(
                    at: operation.quarantineURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let beforeMove = try await StreamingSHA256.file(at: operation.originalURL, progress: { _ in })
                try validateReviewed([reviewedAssets[index]])
                guard beforeMove.digest == operation.expectedDigest else {
                    throw UniversalScanError.cleanupNotPermitted("A selected file changed after review. Scan again before cleanup.")
                }
                try coordinatedMove(from: operation.originalURL, to: operation.quarantineURL)
                completed.append(operation)
                let afterMove = try await StreamingSHA256.file(at: operation.quarantineURL, progress: { _ in })
                guard afterMove.digest == operation.expectedDigest else {
                    throw UniversalScanError.cleanupNotPermitted("A selected file changed while moving. The operation was rolled back.")
                }
                // Renaming one selected hard link changes the shared inode's ctime.
                // The content remains bound to its reviewed digest for every entry.
                if let moved = LibraryFileRevision.capture(at: operation.quarantineURL) {
                    for i in reviewedAssets.indices where i > index && reviewedAssets[i].fileRevision?.physicalIdentity == moved.physicalIdentity {
                        if case .file(let url) = reviewedAssets[i].reference, let revision = LibraryFileRevision.capture(at: url), revision.physicalIdentity == moved.physicalIdentity {
                            reviewedAssets[i] = reviewedAssets[i].with(fileRevision: .some(revision))
                        }
                    }
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
            await reconcileAfterCompensation(&record)
            try? saveManifest(record)
            if rollbackFailed {
                throw FolderCleanupFailure(record: record, message: L10n.tr("Some files remain in the recovery folder. Reopen this source and restore its recovery record."))
            }
            throw error
        }
        return record
    }

    /// Reload disk manifests so interrupted operations can be recovered after relaunch.
    public func recoveryRecords(root: URL) async throws -> [FolderQuarantineRecord] {
        try await recoveryCatalogue(root: root).records
    }

    public func recoveryCatalogue(root: URL, verifyContents: Bool = true) async throws -> FolderRecoveryCatalogue {
        let directory = root.appendingPathComponent(".Keptora Quarantine", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return .init(records: [], issues: []) }
        var records: [FolderQuarantineRecord] = []
        var issues: [FolderRecoveryIssue] = []
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try Task.checkCancellation()
            let manifest = url.appendingPathComponent("recovery.json")
            do {
                let record = try JSONDecoder().decode(FolderQuarantineRecord.self, from: Data(contentsOf: manifest))
                guard url.lastPathComponent == record.id.uuidString else { throw CocoaError(.coderReadCorrupt) }
                var rebased = try record.rebased(to: root)
                // A completed receipt records a past restoration, not a live promise
                // that the user will never edit, rename or move that photo afterwards.
                if record.restoredAt != nil { records.append(rebased); continue }
                for i in rebased.operations.indices {
                    let op = rebased.operations[i]
                    let inRecovery = FileManager.default.fileExists(atPath: op.quarantineURL.path)
                    let atOriginal = FileManager.default.fileExists(atPath: op.originalURL.path)
                    if op.state == .restored && !inRecovery { continue }
                    if !verifyContents {
                        if inRecovery { rebased.operations[i].needsAttention = atOriginal }
                        else if op.state == .moved { rebased.operations[i].needsAttention = true }
                        continue
                    }
                    let location = inRecovery ? op.quarantineURL : op.originalURL
                    if (inRecovery || atOriginal), let hash = try? await verifiedFingerprint(at: location), hash.digest == op.expectedDigest {
                        rebased.operations[i].state = inRecovery ? .moved : .restored
                        rebased.operations[i].byteCount = hash.byteCount
                        rebased.operations[i].needsAttention = inRecovery && atOriginal
                    } else { rebased.operations[i].state = .interrupted; rebased.operations[i].needsAttention = true }
                }
                if rebased.operations.allSatisfy({ $0.state == .restored }) { rebased.restoredAt = rebased.restoredAt ?? Date() }
                if rebased != record { try saveManifest(rebased) }
                records.append(rebased)
            } catch is CancellationError { throw CancellationError() }
            catch { issues.append(.init(manifestURL: manifest, message: error.localizedDescription)) }
            }
        return .init(records: records, issues: issues)
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
            if operation.state == .restored && !inRecovery { continue }
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
            for (position, operation) in pending.enumerated() {
                try Task.checkCancellation()
                try FileManager.default.createDirectory(at: operation.originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try await beforeRestoreMove?(operation, position)
                let revision = LibraryFileRevision.capture(at: operation.quarantineURL)
                let before = try await StreamingSHA256.file(at: operation.quarantineURL, progress: { _ in })
                guard before.digest == operation.expectedDigest,
                      revision == LibraryFileRevision.capture(at: operation.quarantineURL),
                      !FileManager.default.fileExists(atPath: operation.originalURL.path) else {
                    throw UnifiedLibraryError.selectionChanged
                }
                try coordinatedMove(from: operation.quarantineURL, to: operation.originalURL)
                completed.append(operation)
                try await afterRestoreMove?(operation, position)
                let after = try await StreamingSHA256.file(at: operation.originalURL, progress: { _ in })
                guard after.digest == operation.expectedDigest else { throw UnifiedLibraryError.selectionChanged }
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
            await reconcileAfterCompensation(&restored)
            try? saveManifest(restored)
            if rollbackFailed {
                throw UniversalScanError.cleanupNotPermitted("Restore was interrupted. Keep the recovery folder and retry; verified originals will be preserved.")
            }
            throw error
        }
        return restored
    }

    private func verifiedFingerprint(at url: URL) async throws -> UniversalExactFingerprint {
        let revision = LibraryFileRevision.capture(at: url)
        if let revision, let cached = verified[url], cached.0 == revision { return cached.1 }
        let hash = try await StreamingSHA256.file(at: url, progress: { _ in })
        guard revision == LibraryFileRevision.capture(at: url) else { throw UnifiedLibraryError.selectionChanged }
        if let revision { verified[url] = (revision, hash) }
        return hash
    }

    private func reconcileAfterCompensation(_ record: inout FolderQuarantineRecord) async {
        record.restoredAt = nil
        for i in record.operations.indices {
            let op = record.operations[i]
            let inRecovery = FileManager.default.fileExists(atPath: op.quarantineURL.path)
            let atOriginal = FileManager.default.fileExists(atPath: op.originalURL.path)
            let location = inRecovery ? op.quarantineURL : op.originalURL
            let hash = try? await Task.detached { try await StreamingSHA256.file(at: location, progress: { _ in }) }.value
            let valid = hash?.digest == op.expectedDigest
            record.operations[i].state = valid ? (inRecovery ? .moved : .restored) : .interrupted
            record.operations[i].needsAttention = !valid || (inRecovery && atOriginal)
        }
        if record.operations.allSatisfy({ $0.state == .restored && $0.needsAttention != true }) { record.restoredAt = Date() }
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
