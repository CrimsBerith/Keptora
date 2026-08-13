import XCTest
@testable import Cullora

final class RestorePreviewTests: XCTestCase {
    func testPreviewBlocksOccupiedOriginalAndThenAllowsVerifiedRestore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceRoot = directory.appendingPathComponent("Library", isDirectory: true)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()
        let sourceVolume = try VolumeIdentity.resolve(for: sourceRoot)
        let source = SourceIdentity.folderID(for: sourceRoot, volume: sourceVolume)
        let content = Data("byte-identical".utf8)

        for index in 0..<2 {
            let file = sourceRoot.appendingPathComponent("copy-\(index).jpg")
            try content.write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"), sourceID: source, stableKey: file.path,
                displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                byteCount: Int64(content.count), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            let fingerprint = try await ExactHasher().hashFile(at: file)
            try await database.upsert(asset: asset, fingerprint: fingerprint, scanID: "scan")
        }

        try await database.rebuildExactGroups()
        let groups = try await database.fetchDuplicateGroups()
        let group = try XCTUnwrap(groups.first)
        let selected = try XCTUnwrap(group.assets.first { $0.id != group.canonicalAssetID })
        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        let plan = try await coordinator.preparePlan(sourceRoot: sourceRoot)
        XCTAssertEqual(plan.provenanceCount, 1)
        XCTAssertEqual(plan.operations.first?.decisionReasonCode, "user-added-to-plan")
        XCTAssertEqual(plan.operations.first?.canonicalAssetID, group.canonicalAssetID)
        let commit = try await coordinator.commit(plan, appVersion: "test")

        let envelopeData = try Data(contentsOf: commit.manifestURL)
        let envelope = try ManifestSigner.canonicalDecoder.decode(SignedCleanupManifest.self, from: envelopeData)
        let manifest = try await ManifestSigner(keyURL: support.appendingPathComponent("Keys/manifest-signing.key")).decodedManifest(from: envelope)
        XCTAssertEqual(manifest.schemaVersion, 4)
        XCTAssertEqual(manifest.operations.first?.decisionReasonCode, "user-added-to-plan")
        XCTAssertEqual(manifest.operations.first?.canonicalAssetID, group.canonicalAssetID.rawValue)
        XCTAssertEqual(manifest.decisionSnapshotFingerprint, plan.decisionSnapshotFingerprint)

        try Data("occupied".utf8).write(to: selected.fileURL)
        var preview = try await coordinator.previewRestore(planID: plan.id)
        XCTAssertEqual(preview.readyCount, 0)
        XCTAssertEqual(preview.blockedCount, 1)
        XCTAssertEqual(preview.operations.first?.readiness, .originalOccupied)
        XCTAssertFalse(preview.canRestore)

        try FileManager.default.removeItem(at: selected.fileURL)
        preview = try await coordinator.previewRestore(planID: plan.id)
        XCTAssertEqual(preview.readyCount, 1)
        XCTAssertEqual(preview.blockedCount, 0)
        XCTAssertTrue(preview.canRestore)
    }

    func testPreviewDetectsChangedQuarantineContent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceRoot = directory.appendingPathComponent("Library", isDirectory: true)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()
        let sourceVolume = try VolumeIdentity.resolve(for: sourceRoot)
        let source = SourceIdentity.folderID(for: sourceRoot, volume: sourceVolume)
        let content = Data("same-content".utf8)
        for index in 0..<2 {
            let file = sourceRoot.appendingPathComponent("image-\(index).jpg")
            try content.write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "image-\(index)"), sourceID: source, stableKey: file.path,
                displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                byteCount: Int64(content.count), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            try await database.upsert(asset: asset, fingerprint: try await ExactHasher().hashFile(at: file), scanID: "scan")
        }
        try await database.rebuildExactGroups()
        let groups = try await database.fetchDuplicateGroups()
        let group = try XCTUnwrap(groups.first)
        let selected = try XCTUnwrap(group.assets.first { $0.id != group.canonicalAssetID })
        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        let plan = try await coordinator.preparePlan(sourceRoot: sourceRoot)
        _ = try await coordinator.commit(plan, appVersion: "test")
        let quarantineURL = try XCTUnwrap(plan.operations.first?.quarantineURL)
        try Data("tampered".utf8).write(to: quarantineURL)

        let preview = try await coordinator.previewRestore(planID: plan.id)
        XCTAssertEqual(preview.operations.first?.readiness, .contentChanged)
        XCTAssertFalse(preview.canRestore)
    }
}
