import XCTest
import KeptoraCore
@testable import Keptora

final class AccessPolicyTests: XCTestCase {
    @MainActor
    func testArchiveSourceChoicesScopeTheGridAndKeepHiddenManualSelection() async throws {
        let key = AppStorageKeys.macExcludedScanSources
        let saved = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repositoryURL = root.appendingPathComponent("session.json")
        let archive = MacArchiveModel(repositoryURL: repositoryURL)
        await archive.restoreConnections(loadSources: false)
        let first = LibrarySource(id: "first", kind: .folder, displayName: "Pictures")
        let second = LibrarySource(id: "second", kind: .fileProvider, displayName: "Cloud")
        archive.connectedFolders = [first, second]
        archive.assets = [first, second].map { source in
            UniversalMediaAsset(id: source.id, sourceID: source.id, reference: .file(URL(fileURLWithPath: "/tmp/" + source.id + ".jpg")), displayName: source.id, mediaKind: .image)
        }
        archive.selection = [first.id]
        archive.toggleScanSource(first.id)
        XCTAssertEqual(archive.sourceSelectionState, .some)
        XCTAssertEqual(archive.scopedAssets.map(\.id), [second.id])
        XCTAssertEqual(archive.selected.map(\.id), [first.id])
        let savedState = await archive.flushState(includeAnalysis: false); XCTAssertTrue(savedState)
        let reopened = MacArchiveModel(repositoryURL: repositoryURL)
        await reopened.restoreConnections(loadSources: false)
        XCTAssertEqual(reopened.scanSourceSelection.excludedIDs, [first.id])
        archive.toggleAllScanSources()
        XCTAssertEqual(archive.sourceSelectionState, .all)
        archive.toggleAllScanSources()
        XCTAssertTrue(archive.scopedAssets.isEmpty)
        XCTAssertFalse(archive.canScanSelectedSources)
        archive.analyze()
        XCTAssertFalse(archive.analyzing)
        XCTAssertEqual(archive.selection, [first.id])
    }
    func testFreePolicyAllowsFirstHundredUniqueReviews() {
        let reviewed = Set((0..<99).map { "asset-\($0)" })
        let policy = AccessPolicy(isLifetimeUnlocked: false, reviewedAssetIDs: reviewed)

        XCTAssertEqual(policy.freeReviewsRemaining, 1)
        XCTAssertTrue(policy.allowsReview(assetID: AssetID(rawValue: "asset-99")))
    }

    func testFreePolicyBlocksNewReviewAfterLimitButAllowsExistingAsset() {
        let reviewed = Set((0..<100).map { "asset-\($0)" })
        let policy = AccessPolicy(isLifetimeUnlocked: false, reviewedAssetIDs: reviewed)

        XCTAssertFalse(policy.allowsReview(assetID: AssetID(rawValue: "asset-new")))
        XCTAssertTrue(policy.allowsReview(assetID: AssetID(rawValue: "asset-42")))
    }

    func testFreeSafetyPlanOnlyAllowsPreviouslyReviewedAssets() {
        let reviewed = Set(["a", "b"])
        let policy = AccessPolicy(isLifetimeUnlocked: false, reviewedAssetIDs: reviewed)

        XCTAssertTrue(policy.allowsSafetyPlan(assetIDs: [AssetID(rawValue: "a"), AssetID(rawValue: "b")]))
        XCTAssertFalse(policy.allowsSafetyPlan(assetIDs: [AssetID(rawValue: "a"), AssetID(rawValue: "c")]))
    }

    func testLifetimePolicyIsUnlimited() {
        let policy = AccessPolicy(isLifetimeUnlocked: true, reviewedAssetIDs: [])

        XCTAssertTrue(policy.allowsReview(assetID: AssetID(rawValue: "any")))
        XCTAssertTrue(policy.allowsSafetyPlan(assetIDs: [AssetID(rawValue: "any")]))
    }
    func testBatchReviewAuthorizationCountsOnlyNewAssets() {
        let reviewed = Set(["a", "b"])
        let policy = AccessPolicy(isLifetimeUnlocked: false, reviewedAssetIDs: reviewed)
        let assets = [AssetID(rawValue: "a"), AssetID(rawValue: "c"), AssetID(rawValue: "d")]

        XCTAssertEqual(policy.newReviewCount(assetIDs: assets), 2)
        XCTAssertTrue(policy.allowsReviews(assetIDs: assets))
    }

    func testBatchReviewAuthorizationFailsAtomicallyWhenLimitIsTooSmall() {
        let reviewed = Set((0..<99).map { "asset-\($0)" })
        let policy = AccessPolicy(isLifetimeUnlocked: false, reviewedAssetIDs: reviewed)
        let assets = [AssetID(rawValue: "new-1"), AssetID(rawValue: "new-2")]

        XCTAssertFalse(policy.allowsReviews(assetIDs: assets))
    }

}
