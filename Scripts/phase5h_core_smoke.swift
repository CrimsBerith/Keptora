#if os(Linux)
import Foundation

@main
struct Phase5HCoreSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        let otherSource = root.appendingPathComponent("Other", isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: otherSource, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("core.sqlite"))
        try await database.initialize()
        let volume = try VolumeIdentity.resolve(for: source)
        let sourceID = SourceIdentity.folderID(for: source, volume: volume)
        let session = try await database.beginOrResumeScanSession(
            sourceID: sourceID,
            sourcePath: source.standardizedFileURL.path,
            volumeID: volume.stableID
        )
        let hasher = ExactHasher()

        for index in 0..<120 {
            let file = source.appendingPathComponent(String(format: "%04d.jpg", index))
            try Data("asset-\(index)".utf8).write(to: file)
        }
        let enumerator = FolderEnumerator()
        let initialURLs = try enumerator.mediaFiles(in: source)
        for url in initialURLs.prefix(100) {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
            let stableKey = url.standardizedFileURL.path
            let descriptor = AssetDescriptor(
                id: AssetID(rawValue: "asset:" + stableKey),
                sourceID: sourceID,
                stableKey: stableKey,
                displayName: url.lastPathComponent,
                fileURL: url,
                mediaKind: .image,
                byteCount: Int64(values.fileSize ?? 0),
                pixelWidth: nil,
                pixelHeight: nil,
                creationDate: values.creationDate,
                modificationDate: values.contentModificationDate
            )
            try await database.upsert(asset: descriptor, fingerprint: try await hasher.hashFile(at: url), scanID: session.id)
        }
        let cursor = initialURLs[99].standardizedFileURL.path
        try await database.pauseScanSession(
            id: session.id, processed: 100, total: 120, hashed: 100, reused: 0, cursorStableKey: cursor
        )

        // This key sorts before the saved cursor. A blind resume would skip it.
        try Data("inserted-before-cursor".utf8).write(to: source.appendingPathComponent("0000a.jpg"))
        let resumedOutcome = try await ScanCoordinator(database: database).scan(folder: source) { _ in }
        guard resumedOutcome.discovered == 121,
              resumedOutcome.hashed == 21,
              resumedOutcome.reused == 100 else {
            fatalError("Unsafe cursor behavior: \(resumedOutcome)")
        }
        let warmOutcome = try await ScanCoordinator(database: database).scan(folder: source) { _ in }
        guard warmOutcome.hashed == 0, warmOutcome.reused == 121 else {
            fatalError("Warm scan reuse failed: \(warmOutcome)")
        }

        // Source-scoped reconciliation: source A repairs; source B stays pending.
        let aOriginal = source.appendingPathComponent("recovery-a.jpg")
        let bOriginal = otherSource.appendingPathComponent("recovery-b.jpg")
        try Data("recovery-a".utf8).write(to: aOriginal)
        try Data("recovery-b".utf8).write(to: bOriginal)
        let aFingerprint = try await hasher.hashFile(at: aOriginal)
        let bFingerprint = try await hasher.hashFile(at: bOriginal)
        let otherVolume = try VolumeIdentity.resolve(for: otherSource)
        let otherID = SourceIdentity.folderID(for: otherSource, volume: otherVolume)

        func descriptor(_ id: String, _ url: URL, _ sourceID: SourceID) throws -> AssetDescriptor {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return AssetDescriptor(
                id: AssetID(rawValue: id), sourceID: sourceID, stableKey: url.path,
                displayName: url.lastPathComponent, fileURL: url, mediaKind: .image,
                byteCount: Int64(values.fileSize ?? 0), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: values.contentModificationDate
            )
        }
        let aAsset = try descriptor("recovery-a", aOriginal, sourceID)
        let bAsset = try descriptor("recovery-b", bOriginal, otherID)
        try await database.upsert(asset: aAsset, fingerprint: aFingerprint)
        try await database.upsert(asset: bAsset, fingerprint: bFingerprint)

        let aQuarantine = source.appendingPathComponent(".Cullora Quarantine/plan-a/recovery-a.jpg")
        let bQuarantine = otherSource.appendingPathComponent(".Cullora Quarantine/plan-b/recovery-b.jpg")
        let aOperation = CleanupOperationPreview(
            id: "op-a", groupID: "group-a", assetID: aAsset.id, displayName: aAsset.displayName,
            originalURL: aOriginal, quarantineURL: aQuarantine, byteCount: aFingerprint.byteCount, digest: aFingerprint.digest
        )
        let bOperation = CleanupOperationPreview(
            id: "op-b", groupID: "group-b", assetID: bAsset.id, displayName: bAsset.displayName,
            originalURL: bOriginal, quarantineURL: bQuarantine, byteCount: bFingerprint.byteCount, digest: bFingerprint.digest
        )
        try await database.insertCleanupPlan(CleanupPlanPreview(
            id: "plan-a", sourceRoot: source, quarantineRoot: aQuarantine.deletingLastPathComponent(),
            createdAt: Date(), operations: [aOperation], sourceVolume: volume
        ))
        try await database.insertCleanupPlan(CleanupPlanPreview(
            id: "plan-b", sourceRoot: otherSource, quarantineRoot: bQuarantine.deletingLastPathComponent(),
            createdAt: Date(), operations: [bOperation], sourceVolume: otherVolume
        ))
        try await database.updateCleanupPlanState("plan-a", state: .committing)
        try await database.updateCleanupPlanState("plan-b", state: .committing)
        try FileManager.default.createDirectory(at: aQuarantine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bQuarantine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: aOriginal, to: aQuarantine)
        try FileManager.default.moveItem(at: bOriginal, to: bQuarantine)

        let issues = try await ReconciliationCoordinator(database: database).reconcile(sourceRoot: source)
        guard issues.contains(where: { $0.kind == .recoveredQuarantine }) else {
            fatalError("Source A reconciliation was not recovered")
        }
        let aStates = try await database.fetchCleanupOperationStates(planID: "plan-a")
        let bStates = try await database.fetchCleanupOperationStates(planID: "plan-b")
        guard aStates["op-a"] == .quarantined, bStates["op-b"] == .pending else {
            fatalError("Reconciliation crossed source boundary")
        }

        print("Phase 5H coordinator smoke passed: changed-prefix restart, warm reuse, and source-scoped reconciliation.")
    }
}
#endif
