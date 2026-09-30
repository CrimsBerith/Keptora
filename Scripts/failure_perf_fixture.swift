import Foundation

@main
struct Runner {
    static func main() throws {

        let c = KeptoraResiliencePerformanceController(failureHistoryLimit: 128, latencySampleLimit: 512)
        precondition(KeptoraFailureClassifier.classify(domain: NSCocoaErrorDomain, code: 257) == .permissionDenied)
        precondition(KeptoraFailureClassifier.classify(domain: NSCocoaErrorDomain, code: 259) == .corruptInput)
        precondition(KeptoraFailureClassifier.classify(domain: NSCocoaErrorDomain, code: 260) == .missingInput)
        precondition(KeptoraFailureClassifier.classify(domain: NSCocoaErrorDomain, code: 640) == .diskFull)
        precondition(KeptoraFailureClassifier.classify(domain: NSURLErrorDomain, code: -1001) == .timedOut)
        precondition(KeptoraFailureClassifier.classify(domain: NSURLErrorDomain, code: -999) == .cancelled)

        let start = Date()
        for i in 0..<100_000 {
            c.recordLatency(milliseconds: Double(i % 701))
            if i % 7 == 0 { c.record(kind: (i % 14 == 0 ? .memoryPressure : .unexpected), operation: "fixture-\(i % 11)") }
        }
        let snapshot = c.snapshot(estimatedItemBytes: 256 * 1024)
        let recent = c.recentFailures()
        precondition(snapshot.failureCount == 128)
        precondition(snapshot.latencySampleCount == 512)
        precondition(recent.count == 128)
        precondition(snapshot.recommendedBatchSize >= 8 && snapshot.recommendedBatchSize <= 2048)
        precondition(snapshot.p95Milliseconds >= 0)
        let elapsed = Date().timeIntervalSince(start)
        print("FAILURE_PERF_PASS failures=\(snapshot.failureCount) latency=\(snapshot.latencySampleCount) batch=\(snapshot.recommendedBatchSize) p95=\(String(format: "%.1f", snapshot.p95Milliseconds)) elapsed=\(String(format: "%.4f", elapsed))")
    }
}
