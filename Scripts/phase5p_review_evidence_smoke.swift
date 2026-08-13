import Foundation

@main
struct Phase5PReviewEvidenceSmoke {
    static func main() {
        let keeper = ReviewAsset(
            id: AssetID(rawValue: "keeper"), displayName: "keeper.jpg",
            fileURL: URL(fileURLWithPath: "/tmp/keeper.jpg"), byteCount: 10,
            modificationDate: nil, digest: "same"
        )
        let extra = ReviewAsset(
            id: AssetID(rawValue: "extra"), displayName: "extra.jpg",
            fileURL: URL(fileURLWithPath: "/tmp/extra.jpg"), byteCount: 10,
            modificationDate: nil, digest: "same"
        )
        let group = ReviewGroup(
            id: "exact:demo", kind: "exact", confidence: "exact", digest: "same",
            reclaimableBytes: 10, canonicalAssetID: keeper.id, assets: [keeper, extra]
        )
        let record = PersistedReviewDecision(
            groupID: group.id, assetID: extra.id, decision: .quarantinePlan,
            actor: "user", reasonCode: "user-added-to-plan", updatedAt: Date(timeIntervalSince1970: 10)
        )
        let evidence = ReviewDecisionEvidenceEngine.evidence(group: group, asset: extra, record: record)
        precondition(evidence.proofState == .verifiedExactPlan)
        precondition(evidence.canonicalAssetID == keeper.id)

        let changed = ReviewAsset(
            id: extra.id, displayName: extra.displayName, fileURL: extra.fileURL,
            byteCount: extra.byteCount, modificationDate: nil, digest: "changed"
        )
        precondition(ReviewDecisionEvidenceEngine.evidence(group: group, asset: changed, record: record).proofState == .needsReview)

        let start = Date()
        var verified = 0
        for index in 0..<100_000 {
            let asset = ReviewAsset(
                id: AssetID(rawValue: "a-\(index)"), displayName: "a.jpg",
                fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), byteCount: 10,
                modificationDate: nil, digest: "same"
            )
            let r = PersistedReviewDecision(
                groupID: group.id, assetID: asset.id, decision: .quarantinePlan,
                actor: "user", reasonCode: "user-batch-added-exact-extras", updatedAt: .distantPast
            )
            if ReviewDecisionEvidenceEngine.evidence(group: group, asset: asset, record: r).isPlanVerified { verified += 1 }
        }
        print("assets=100000")
        print("verified=\(verified)")
        print(String(format: "elapsed_seconds=%.6f", Date().timeIntervalSince(start)))
        print("cullora-phase5p-review-evidence-ok")
    }
}
