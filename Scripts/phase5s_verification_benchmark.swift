import Foundation

@main
struct Phase5SVerificationBenchmark {
    static func main() {
        var operations: [CleanupManifestOperation] = []
        var observed: [QuarantineObservedOperationState] = []
        operations.reserveCapacity(100_000); observed.reserveCapacity(100_000)
        for i in 0..<100_000 {
            let id = "op-\(i)"
            let digest = "digest-\(i)"
            operations.append(CleanupManifestOperation(
                operationID: id, groupID: "g-\(i % 1000)", assetID: "a-\(i)",
                originalPath: "/source/\(i)", quarantinePath: "/q/\(i)", byteCount: Int64(i + 1), digest: digest
            ))
            observed.append(QuarantineObservedOperationState(
                operationID: id, databaseState: .quarantined, originalExists: false, quarantineExists: true,
                observedDigest: digest, observedByteCount: Int64(i + 1)
            ))
        }
        let manifest = CleanupManifest(
            schemaVersion: 4, planID: "benchmark", sourceRoot: "/source", quarantineRoot: "/q",
            createdAt: Date(timeIntervalSince1970: 0), appVersion: "0.9.9", operations: operations
        )
        let start = Date()
        let report = QuarantineVerificationEngine.report(manifest: manifest, phase: .manualReview, observed: observed)
        let elapsed = Date().timeIntervalSince(start)
        guard report.state == .verified, report.verifiedCount == 100_000 else { fatalError("benchmark correctness failed") }
        print(String(format: "100k quarantine verification assessment: %.4fs", elapsed))
    }
}
