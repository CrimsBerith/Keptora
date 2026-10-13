import XCTest
@testable import Keptora

final class AccessPolicyTests: XCTestCase {
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
