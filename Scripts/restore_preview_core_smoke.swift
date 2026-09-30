#if os(Linux)
import Foundation

@main
struct RestorePreviewCoreSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("restore.sqlite"))
        try await database.initialize()
        let volume = try VolumeIdentity.resolve(for: source)
        let sourceID = SourceIdentity.folderID(for: source, volume: volume)
        let hasher = ExactHasher()
        let bytes = Data("phase-5o-identical".utf8)

        for index in 0..<2 {
            let url = source.appendingPathComponent("copy-\(index).jpg")
            try bytes.write(to: url)
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"), sourceID: sourceID, stableKey: url.path,
                displayName: url.lastPathComponent, fileURL: url, mediaKind: .image,
                byteCount: Int64(values.fileSize ?? 0), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: values.contentModificationDate
            )
            try await database.upsert(asset: asset, fingerprint: try await hasher.hashFile(at: url), scanID: "scan")
        }

        try await database.rebuildExactGroups()
        guard let group = try await database.fetchDuplicateGroups().first,
              let selected = group.assets.first(where: { $0.id != group.canonicalAssetID }) else {
            fatalError("Duplicate setup failed")
        }
        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        let plan = try await coordinator.preparePlan(sourceRoot: source)
        guard let operation = plan.operations.first else { fatalError("Plan operation missing") }

        let manifest = CleanupManifest(
            schemaVersion: 2,
            planID: plan.id,
            sourceRoot: plan.sourceRoot.path,
            quarantineRoot: plan.quarantineRoot.path,
            createdAt: plan.createdAt,
            appVersion: "5O-smoke",
            sourceVolumeID: plan.sourceVolume?.stableID,
            operations: [CleanupManifestOperation(
                operationID: operation.id,
                groupID: operation.groupID,
                assetID: operation.assetID.rawValue,
                originalPath: operation.originalURL.path,
                quarantinePath: operation.quarantineURL.path,
                byteCount: operation.byteCount,
                digest: operation.digest,
                familyID: operation.familyID,
                familyKind: operation.familyKind?.rawValue,
                familyRole: operation.familyRole?.rawValue
            )]
        )
        let signer = ManifestSigner(keyURL: support.appendingPathComponent("Keys/smoke.key"))
        let envelope = try await signer.seal(manifest)
        let manifestURL = support.appendingPathComponent("Manifests/\(plan.id).cullora-manifest.json")
        try FileManager.default.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ManifestSigner.canonicalEncoder.encode(envelope).write(to: manifestURL)
        try await database.storeManifest(planID: plan.id, envelope: envelope, path: manifestURL.path)
        try await database.updateCleanupPlanState(plan.id, state: .committing)
        try FileManager.default.createDirectory(at: operation.quarantineURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: operation.originalURL, to: operation.quarantineURL)
        try await database.markOperationQuarantined(operationID: operation.id, assetID: operation.assetID, quarantinePath: operation.quarantineURL.path)
        try await database.finishCleanupCommit(plan.id, state: .committed)

        var preview = try await coordinator.previewRestore(planID: plan.id)
        guard preview.readyCount == 1, preview.blockedCount == 0, preview.canRestore else {
            fatalError("Verified restore preview should be ready: \(preview)")
        }

        try Data("occupied".utf8).write(to: selected.fileURL)
        preview = try await coordinator.previewRestore(planID: plan.id)
        guard preview.blockedCount == 1,
              preview.operations.first?.readiness == .originalOccupied,
              !preview.canRestore else {
            fatalError("Occupied original path was not blocked")
        }
        try FileManager.default.removeItem(at: selected.fileURL)

        guard let quarantine = plan.operations.first?.quarantineURL else { fatalError("Missing quarantine URL") }
        try Data("tampered".utf8).write(to: quarantine)
        preview = try await coordinator.previewRestore(planID: plan.id)
        guard preview.operations.first?.readiness == .contentChanged, !preview.canRestore else {
            fatalError("Tampered quarantine content was not blocked")
        }

        try bytes.write(to: quarantine)
        preview = try await coordinator.previewRestore(planID: plan.id)
        guard preview.canRestore else { fatalError("Repaired quarantine should be restorable") }

        try FileManager.default.moveItem(at: quarantine, to: selected.fileURL)
        try await database.markOperationRestored(
            operationID: operation.id,
            assetID: operation.assetID,
            originalPath: selected.fileURL.path
        )
        try await database.finishCleanupRestore(plan.id, state: .restored)

        let restoredPreview = try await coordinator.previewRestore(planID: plan.id)
        guard restoredPreview.alreadyRestoredCount == 1, !restoredPreview.canRestore else {
            fatalError("Already-restored state not reported")
        }

        print("Phase 5O restore preview smoke passed: ready, occupied, tampered, restored states.")
    }
}
#endif
