import XCTest
@testable import Keptora

final class ReviewSessionCheckpointTests: XCTestCase {
    func testCheckpointRoundTripsAndComputesProgress() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let checkpoint = ReviewSessionCheckpoint(
            sourceID: SourceID(rawValue: "source-demo"),
            sourceName: "Demo Library",
            groupID: "group-3",
            focusedAssetID: AssetID(rawValue: "asset-7"),
            groupPosition: 3,
            totalGroups: 10,
            reviewedAssets: 24,
            completedGroups: 4,
            plannedBytes: 1_048_576,
            startedAt: start,
            updatedAt: start.addingTimeInterval(120)
        )

        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(ReviewSessionCheckpoint.self, from: data)

        XCTAssertEqual(decoded, checkpoint)
        XCTAssertEqual(decoded.progressFraction, 0.4, accuracy: 0.0001)
        XCTAssertEqual(decoded.reviewedPerMinute, 12, accuracy: 0.0001)
        XCTAssertEqual(decoded.positionLabel, "Group 3 of 10")
    }

    func testCheckpointClampsInvalidProgress() {
        let now = Date()
        let checkpoint = ReviewSessionCheckpoint(
            sourceID: SourceID(rawValue: "source"), sourceName: "Source", groupID: "group",
            focusedAssetID: nil, groupPosition: 99, totalGroups: 2, reviewedAssets: 0,
            completedGroups: 9, plannedBytes: 0, startedAt: now, updatedAt: now
        )
        XCTAssertEqual(checkpoint.progressFraction, 1)
        XCTAssertEqual(checkpoint.positionLabel, "Group 2 of 2")
        XCTAssertEqual(checkpoint.reviewedPerMinute, 0)
    }
}


final class ReviewDecisionEvidenceTests: XCTestCase {
    func testExactPlannedExtraProducesVerifiedEvidence() {
        let keeper = ReviewAsset(
            id: AssetID(rawValue: "keeper"), displayName: "keeper.jpg",
            fileURL: URL(fileURLWithPath: "/tmp/keeper.jpg"), byteCount: 100,
            modificationDate: nil, digest: "digest"
        )
        let extra = ReviewAsset(
            id: AssetID(rawValue: "extra"), displayName: "extra.jpg",
            fileURL: URL(fileURLWithPath: "/tmp/extra.jpg"), byteCount: 100,
            modificationDate: nil, digest: "digest"
        )
        let group = ReviewGroup(
            id: "group", kind: "exact", confidence: "exact", digest: "digest",
            reclaimableBytes: 100, canonicalAssetID: keeper.id, assets: [keeper, extra]
        )
        let record = PersistedReviewDecision(
            groupID: group.id, assetID: extra.id, decision: .quarantinePlan,
            actor: "user", reasonCode: "user-added-to-plan",
            updatedAt: Date(timeIntervalSince1970: 123)
        )

        let evidence = ReviewDecisionEvidenceEngine.evidence(group: group, asset: extra, record: record)

        XCTAssertEqual(evidence.proofState, .verifiedExactPlan)
        XCTAssertTrue(evidence.isPlanVerified)
        XCTAssertEqual(evidence.canonicalAssetID, keeper.id)
        XCTAssertEqual(evidence.reasonLabel, "Added to Safety Plan by user")
    }

    func testDigestMismatchFailsClosed() {
        let keeper = ReviewAsset(
            id: AssetID(rawValue: "keeper"), displayName: "keeper.jpg",
            fileURL: URL(fileURLWithPath: "/tmp/keeper.jpg"), byteCount: 100,
            modificationDate: nil, digest: "group-digest"
        )
        let changed = ReviewAsset(
            id: AssetID(rawValue: "changed"), displayName: "changed.jpg",
            fileURL: URL(fileURLWithPath: "/tmp/changed.jpg"), byteCount: 100,
            modificationDate: nil, digest: "different"
        )
        let group = ReviewGroup(
            id: "group", kind: "exact", confidence: "exact", digest: "group-digest",
            reclaimableBytes: 100, canonicalAssetID: keeper.id, assets: [keeper, changed]
        )
        let record = PersistedReviewDecision(
            groupID: group.id, assetID: changed.id, decision: .quarantinePlan,
            actor: "user", reasonCode: "user-added-to-plan", updatedAt: Date()
        )

        XCTAssertEqual(
            ReviewDecisionEvidenceEngine.evidence(group: group, asset: changed, record: record).proofState,
            .needsReview
        )
    }
}
