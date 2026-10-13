import XCTest
@testable import Keptora

final class IncrementalIndexTests: XCTestCase {
    func testUnchangedAssetCanBeReusedAndMissingStateIsTracked() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: directory.appendingPathComponent("index.sqlite"))
        try await database.initialize()
        let file = directory.appendingPathComponent("photo.jpg")
        try Data("stable-content".utf8).write(to: file)
        let modified = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let source = SourceID(rawValue: "source")
        let asset = AssetDescriptor(
            id: AssetID(rawValue: "asset"), sourceID: source, stableKey: file.path,
            displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
            byteCount: 14, pixelWidth: nil, pixelHeight: nil, creationDate: nil, modificationDate: modified
        )
        try await database.upsert(
            asset: asset,
            fingerprint: ExactFingerprint(algorithm: "sha256-v1", digest: "digest", byteCount: 14),
            scanID: "scan-1"
        )

        let state = try await database.indexState(sourceID: source, stableKey: file.path)
        XCTAssertTrue(state?.matches(byteCount: 14, modificationDate: modified) == true)

        try await database.touchUnchangedAsset(asset, scanID: "scan-2")
        let unchangedMissing = try await database.markMissingAssets(sourceID: source, notSeenIn: "scan-2")
        let nextMissing = try await database.markMissingAssets(sourceID: source, notSeenIn: "scan-3")
        let summary = try await database.summary()
        XCTAssertEqual(unchangedMissing, 0)
        XCTAssertEqual(nextMissing, 1)
        XCTAssertEqual(summary.activeAssets, 0)
    }

    func testCanonicalAndReviewDecisionsSurviveGroupRebuild() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: directory.appendingPathComponent("decisions.sqlite"))
        try await database.initialize()
        let source = SourceID(rawValue: "source")
        for index in 0..<3 {
            let file = directory.appendingPathComponent("copy-\(index).jpg")
            try Data("same".utf8).write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"), sourceID: source, stableKey: file.path,
                displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                byteCount: 4, pixelWidth: nil, pixelHeight: nil, creationDate: nil, modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            try await database.upsert(
                asset: asset,
                fingerprint: ExactFingerprint(algorithm: "sha256-v1", digest: "same", byteCount: 4),
                scanID: "scan"
            )
        }
        try await database.rebuildExactGroups()
        let initialGroups = try await database.fetchDuplicateGroups()
        let firstGroup = try XCTUnwrap(initialGroups.first)
        let newKeeper = try XCTUnwrap(firstGroup.assets.first { $0.id != firstGroup.canonicalAssetID })
        let previousKeeper = firstGroup.canonicalAssetID

        try await database.setDecision(groupID: firstGroup.id, assetID: newKeeper.id, decision: .keep)
        try await database.setDecision(groupID: firstGroup.id, assetID: previousKeeper, decision: .quarantinePlan)
        try await database.rebuildExactGroups()

        let rebuiltGroups = try await database.fetchDuplicateGroups()
        let rebuilt = try XCTUnwrap(rebuiltGroups.first)
        XCTAssertEqual(rebuilt.canonicalAssetID, newKeeper.id)
        let decisions = try await database.fetchReviewDecisions()
        XCTAssertEqual(decisions.first { $0.assetID == previousKeeper }?.decision, .quarantinePlan)
        XCTAssertEqual(decisions.first { $0.assetID == newKeeper.id }?.decision, .keep)
    }
}
