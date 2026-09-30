import XCTest
@testable import Keptora

final class SQLiteDatabaseTests: XCTestCase {
    func testMigrationAndExactGrouping() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = SQLiteDatabase(url: directory.appendingPathComponent("test.sqlite"))
        try await database.initialize()

        let source = SourceID(rawValue: "test-source")
        for index in 0..<2 {
            let url = directory.appendingPathComponent("asset-\(index).jpg")
            try Data("same".utf8).write(to: url)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"), sourceID: source, stableKey: url.path,
                displayName: url.lastPathComponent, fileURL: url, mediaKind: .image,
                byteCount: 4, pixelWidth: nil, pixelHeight: nil, creationDate: nil, modificationDate: nil
            )
            try await database.upsert(asset: asset, fingerprint: ExactFingerprint(algorithm: "sha256-v1", digest: "same-digest", byteCount: 4))
        }
        try await database.rebuildExactGroups()
        let groups = try await database.fetchDuplicateGroups()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].assets.count, 2)
        XCTAssertEqual(groups[0].reclaimableBytes, 4)
    }

    func testExactGroupsAndSummaryAreSourceScoped() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: directory.appendingPathComponent("sources.sqlite"))
        try await database.initialize()
        let sourceA = SourceID(rawValue: "source-a")
        let sourceB = SourceID(rawValue: "source-b")

        for (source, prefix) in [(sourceA, "a"), (sourceB, "b")] {
            for index in 0..<2 {
                let file = directory.appendingPathComponent("\(prefix)-\(index).jpg")
                try Data("same-across-sources".utf8).write(to: file)
                let asset = AssetDescriptor(
                    id: AssetID(rawValue: "\(prefix)-asset-\(index)"), sourceID: source, stableKey: file.path,
                    displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                    byteCount: 19, pixelWidth: nil, pixelHeight: nil, creationDate: nil, modificationDate: nil
                )
                try await database.upsert(
                    asset: asset,
                    fingerprint: ExactFingerprint(algorithm: "sha256-v1", digest: "shared-digest", byteCount: 19),
                    scanID: "scan"
                )
            }
        }

        try await database.rebuildExactGroups()
        let allGroups = try await database.fetchDuplicateGroups()
        let sourceAGroups = try await database.fetchDuplicateGroups(sourceID: sourceA)
        let sourceBGroups = try await database.fetchDuplicateGroups(sourceID: sourceB)
        let sourceASummary = try await database.summary(sourceID: sourceA)

        XCTAssertEqual(allGroups.count, 2)
        XCTAssertEqual(sourceAGroups.count, 1)
        XCTAssertEqual(sourceBGroups.count, 1)
        XCTAssertNotEqual(sourceAGroups[0].id, sourceBGroups[0].id)
        XCTAssertTrue(sourceAGroups[0].assets.allSatisfy { $0.id.rawValue.hasPrefix("a-") })
        XCTAssertEqual(sourceASummary.indexedAssets, 2)
        XCTAssertEqual(sourceASummary.duplicateGroups, 1)
        XCTAssertEqual(sourceASummary.duplicateAssets, 2)
        XCTAssertEqual(sourceASummary.reclaimableBytes, 19)
    }


    func testSourceIdentitySurvivesExternalVolumeRename() {
        let oldVolume = VolumeIdentity(
            stableID: "volume:abc", uuid: "ABC", name: "Archive", rootPath: "/Volumes/Archive",
            isRemovable: true, isLocal: true
        )
        let renamedVolume = VolumeIdentity(
            stableID: "volume:abc", uuid: "ABC", name: "Archive 2026", rootPath: "/Volumes/Archive 2026",
            isRemovable: true, isLocal: true
        )
        let oldURL = URL(fileURLWithPath: "/Volumes/Archive/Photos/Library")
        let renamedURL = URL(fileURLWithPath: "/Volumes/Archive 2026/Photos/Library")

        XCTAssertEqual(
            SourceIdentity.folderID(for: oldURL, volume: oldVolume),
            SourceIdentity.folderID(for: renamedURL, volume: renamedVolume)
        )
    }

    func testExactBatchActionPlansOnlyNonKeeperAssets() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: directory.appendingPathComponent("batch.sqlite"))
        try await database.initialize()
        let source = SourceID(rawValue: "batch-source")
        for index in 0..<3 {
            let file = directory.appendingPathComponent("copy-\(index).jpg")
            try Data("same".utf8).write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "batch-asset-\(index)"), sourceID: source, stableKey: file.path,
                displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                byteCount: 4, pixelWidth: nil, pixelHeight: nil, creationDate: nil,
                modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            try await database.upsert(
                asset: asset,
                fingerprint: ExactFingerprint(algorithm: "sha256-v1", digest: "batch-digest", byteCount: 4),
                scanID: "scan"
            )
        }
        try await database.rebuildExactGroups()
        let groups = try await database.fetchDuplicateGroups()
        let group = try XCTUnwrap(groups.first)
        let extras = group.assets.filter { $0.id != group.canonicalAssetID }.map(\.id)

        try await database.applyExactGroupAction(
            groupID: group.id,
            keeperAssetID: group.canonicalAssetID,
            extraAssetIDs: extras,
            action: .planSafeExtras
        )

        let decisions = try await database.fetchReviewDecisions()
        XCTAssertEqual(decisions.first { $0.assetID == group.canonicalAssetID }?.decision, .keep)
        XCTAssertTrue(extras.allSatisfy { assetID in
            decisions.first { $0.assetID == assetID }?.decision == .quarantinePlan
        })
        XCTAssertTrue(extras.allSatisfy { assetID in
            decisions.first { $0.assetID == assetID }?.reasonCode == "user-batch-added-exact-extras"
        })
    }

}
