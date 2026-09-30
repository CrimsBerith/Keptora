import Foundation
#if canImport(os)
import os
#endif

// Runtime failure + resource-budget infrastructure for Keptora.
// This file stores categories/metrics only; it intentionally never persists raw file names or document content.

enum KeptoraFailureKind: String, Codable, CaseIterable {
    case missingInput, permissionDenied, corruptInput, diskFull, cancelled, timedOut, memoryPressure, unexpected
}

struct KeptoraFailurePresentation: Equatable {
    let title: String
    let message: String
    let recoveryAction: String
    let canRetry: Bool
}

struct KeptoraRuntimeFailure: Codable, Equatable {
    let kind: KeptoraFailureKind
    let operation: String
    let occurredAt: Date
}

struct KeptoraRuntimeHealthSnapshot: Equatable {
    let failureCount: Int
    let latencySampleCount: Int
    let p95Milliseconds: Double
    let recommendedBatchSize: Int
}

private struct KeptoraBoundedBuffer<Element> {
    private var storage: [Element?]
    private var nextIndex = 0
    private(set) var count = 0

    init(capacity: Int) { storage = Array(repeating: nil, count: max(1, capacity)) }
    mutating func append(_ value: Element) {
        storage[nextIndex] = value
        nextIndex = (nextIndex + 1) % storage.count
        count = min(count + 1, storage.count)
    }
    func values() -> [Element] {
        guard count > 0 else { return [] }
        let start = count == storage.count ? nextIndex : 0
        return (0..<count).compactMap { storage[(start + $0) % storage.count] }
    }
}

struct KeptoraResourceBudget: Equatable {
    let temporaryWorkingSetBytes: Int
    let minBatchItems: Int
    let maxBatchItems: Int
    let safetyFraction: Double

    static let production = KeptoraResourceBudget(
        temporaryWorkingSetBytes: 96 * 1024 * 1024,
        minBatchItems: 8,
        maxBatchItems: 2048,
        safetyFraction: 0.70
    )

    func recommendedBatchSize(estimatedItemBytes: Int, availableBytes: Int? = nil) -> Int {
        let itemBytes = max(1, estimatedItemBytes)
        let sourceBudget = min(temporaryWorkingSetBytes, max(1, availableBytes ?? temporaryWorkingSetBytes))
        let safeBytes = max(itemBytes, Int(Double(sourceBudget) * min(max(safetyFraction, 0.10), 0.95)))
        return min(maxBatchItems, max(minBatchItems, safeBytes / itemBytes))
    }
}

struct KeptoraFailureClassifier {
    static func classify(error: Error) -> KeptoraFailureKind {
        if error is CancellationError { return .cancelled }
        let ns = error as NSError
        return classify(domain: ns.domain, code: ns.code)
    }

    static func classify(domain: String, code: Int) -> KeptoraFailureKind {
        if domain == NSURLErrorDomain {
            if code == -999 { return .cancelled }
            if code == -1001 { return .timedOut }
        }
        if domain == NSCocoaErrorDomain {
            switch code {
            case 257: return .permissionDenied
            case 259: return .corruptInput
            case 260: return .missingInput
            case 640: return .diskFull
            default: break
            }
        }
        return .unexpected
    }

    static func presentation(for kind: KeptoraFailureKind) -> KeptoraFailurePresentation {
        switch kind {
        case .missingInput: return .init(title: "Archive Review Missing", message: "The source is no longer available. Re-select the source before continuing.", recoveryAction: "Return to Review Floor", canRetry: true)
        case .permissionDenied: return .init(title: "Archive Review Locked", message: "macOS denied access. Restore access without weakening sandbox boundaries.", recoveryAction: "Return to Review Floor", canRetry: true)
        case .corruptInput: return .init(title: "Archive Review Unreadable", message: "The source could not be decoded safely. The original remains unchanged.", recoveryAction: "Return to Review Floor", canRetry: false)
        case .diskFull: return .init(title: "Storage Required", message: "The operation stopped before committing output. Free space and retry.", recoveryAction: "Return to Review Floor", canRetry: true)
        case .cancelled: return .init(title: "Operation Cancelled", message: "No partial result is treated as complete.", recoveryAction: "Return to Review Floor", canRetry: true)
        case .timedOut: return .init(title: "Operation Timed Out", message: "The current work was stopped safely and can be attempted again.", recoveryAction: "Return to Review Floor", canRetry: true)
        case .memoryPressure: return .init(title: "Workload Reduced", message: "The batch was reduced to protect app responsiveness and document integrity.", recoveryAction: "Return to Review Floor", canRetry: true)
        case .unexpected: return .init(title: "Operation Could Not Finish", message: "The current result was not committed. Review the source and try again.", recoveryAction: "Return to Review Floor", canRetry: true)
        }
    }
}

final class KeptoraResiliencePerformanceController {
    private let lock = NSLock()
    private var failures: KeptoraBoundedBuffer<KeptoraRuntimeFailure>
    private var latencies: KeptoraBoundedBuffer<Double>
    let budget: KeptoraResourceBudget

    init(failureHistoryLimit: Int = 128, latencySampleLimit: Int = 512, budget: KeptoraResourceBudget = .production) {
        self.failures = .init(capacity: failureHistoryLimit)
        self.latencies = .init(capacity: latencySampleLimit)
        self.budget = budget
    }

    @discardableResult
    func record(error: Error, operation: String, now: Date = Date()) -> KeptoraFailurePresentation {
        let kind = KeptoraFailureClassifier.classify(error: error)
        record(kind: kind, operation: operation, now: now)
        return KeptoraFailureClassifier.presentation(for: kind)
    }

    func record(kind: KeptoraFailureKind, operation: String, now: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        failures.append(.init(kind: kind, operation: operation, occurredAt: now))
    }

    func recordLatency(milliseconds: Double) {
        guard milliseconds.isFinite, milliseconds >= 0 else { return }
        lock.lock(); defer { lock.unlock() }
        latencies.append(milliseconds)
    }

    func recentFailures() -> [KeptoraRuntimeFailure] {
        lock.lock(); defer { lock.unlock() }
        return failures.values()
    }

    func snapshot(estimatedItemBytes: Int) -> KeptoraRuntimeHealthSnapshot {
        lock.lock(); defer { lock.unlock() }
        let samples = latencies.values().sorted()
        let p95: Double
        if samples.isEmpty { p95 = 0 } else {
            let index = min(samples.count - 1, Int(Double(samples.count - 1) * 0.95))
            p95 = samples[index]
        }
        return .init(
            failureCount: failures.count,
            latencySampleCount: latencies.count,
            p95Milliseconds: p95,
            recommendedBatchSize: budget.recommendedBatchSize(estimatedItemBytes: estimatedItemBytes)
        )
    }
}


// MARK: - Instruments / real-corpus profiling readiness

enum KeptoraProfileOperation: CaseIterable {
    case enumerateLibrary, fingerprintAssets, groupSimilarity, quarantineCommit, healthSnapshot

#if canImport(os)
    var signpostName: StaticString {
        switch self {
        case .enumerateLibrary: return "KeptoraEnumerateLibrary"
        case .fingerprintAssets: return "KeptoraFingerprintAssets"
        case .groupSimilarity: return "KeptoraGroupSimilarity"
        case .quarantineCommit: return "KeptoraQuarantineCommit"
        case .healthSnapshot: return "KeptoraHealthSnapshot"
        }
    }
#endif
}

enum KeptoraProfilingHooks {
    static let realCorpusEnvironmentKey = "KEPTORA_REAL_CORPUS_PATH"
    static let allowedRealCorpusExtensions: Set<String> = ["jpg", "jpeg", "heic", "png", "tif", "tiff", "dng"]

    static func measure<T>(_ operation: KeptoraProfileOperation, _ body: () throws -> T) rethrows -> T {
#if canImport(os)
        let log = OSLog(
            subsystem: Bundle.main.bundleIdentifier ?? "local.Keptora",
            category: "ArchiveReviewStudioPerformance"
        )
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: operation.signpostName, signpostID: signpostID)
        defer { os_signpost(.end, log: log, name: operation.signpostName, signpostID: signpostID) }
#endif
        return try body()
    }

    /// Returns external test-corpus URLs only when explicitly configured by the profiling environment.
    /// Raw paths/content are never persisted by this helper.
    static func realCorpusURLs(limit: Int = 5_000) -> [URL] {
        guard limit > 0,
              let path = ProcessInfo.processInfo.environment[realCorpusEnvironmentKey],
              !path.isEmpty else { return [] }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var urls: [URL] = []
        while let url = enumerator.nextObject() as? URL, urls.count < limit {
            guard allowedRealCorpusExtensions.contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            urls.append(url)
        }
        return urls
    }
}
