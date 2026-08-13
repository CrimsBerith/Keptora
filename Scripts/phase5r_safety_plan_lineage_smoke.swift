import Foundation

@main
struct Phase5RSmoke {
    static func main() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        func op(_ index: Int, reason: String = "user-added-to-plan") -> CleanupOperationPreview {
            let id = AssetID(rawValue: "asset-\(index)")
            return CleanupOperationPreview(
                id: "op-\(index)", groupID: "group-\(index % 25)", assetID: id,
                displayName: "asset-\(index).jpg", originalURL: URL(fileURLWithPath: "/source/asset-\(index).jpg"),
                quarantineURL: URL(fileURLWithPath: "/source/.Cullora Quarantine/asset-\(index).jpg"),
                byteCount: 100, digest: "digest-\(index % 5)", decisionActor: "user",
                decisionReasonCode: reason, decisionUpdatedAt: baseDate.addingTimeInterval(Double(index)),
                canonicalAssetID: AssetID(rawValue: "keeper-\(index % 25)")
            )
        }

        let a = op(1), b = op(2)
        precondition(SafetyPlanDecisionFingerprint.fingerprint(operations: [a,b]) == SafetyPlanDecisionFingerprint.fingerprint(operations: [b,a]))
        precondition(SafetyPlanDecisionFingerprint.fingerprint(operations: [a,b]) != SafetyPlanDecisionFingerprint.fingerprint(operations: [a,op(2, reason: "changed")]))

        let source = URL(fileURLWithPath: "/source")
        let first = SafetyPlanLineageEngine.nextIdentity(records: [], sourceRoot: source)
        let record = SafetyPlanLineageRecord(lineage: first, planID: "p1", sourceRoot: source.standardizedFileURL.path, decisionSnapshotFingerprint: "abc", operationCount: 2, createdAt: baseDate, state: .committed)
        let second = SafetyPlanLineageEngine.nextIdentity(records: [record], sourceRoot: source)
        precondition(second.revisionNumber == 2 && second.previousLineageID == first.lineageID)

        let start = Date()
        let many = (0..<100_000).map { op($0) }
        let digest = SafetyPlanDecisionFingerprint.fingerprint(operations: many)
        precondition(digest.count == 64)
        let elapsed = Date().timeIntervalSince(start)
        let elapsedText = String(format: "%.3f", elapsed)
        print("cullora-phase5r-safety-plan-lineage-ok operations=100000 elapsed_seconds=\(elapsedText) digest=\(digest.prefix(12))")
    }
}
