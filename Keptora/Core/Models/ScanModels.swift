import Foundation

enum ScanPhase: String, Sendable {
    case idle
    case discovering
    case hashing
    case grouping
    case completed
    case cancelled
    case failed
}

struct ScanProgress: Equatable, Sendable {
    let phase: ScanPhase
    let processed: Int
    let total: Int
    let currentItem: String?
    let message: String?

    static let idle = ScanProgress(phase: .idle, processed: 0, total: 0, currentItem: nil, message: nil)
    static let cancelled = ScanProgress(phase: .cancelled, processed: 0, total: 0, currentItem: nil, message: String(localized: "Scan cancelled safely."))

    static func completed(outcome: ScanOutcome) -> ScanProgress {
        ScanProgress(
            phase: .completed,
            processed: outcome.discovered,
            total: outcome.discovered,
            currentItem: nil,
            message: String(localized: "Incremental scan complete · \(outcome.hashed) hashed · \(outcome.reused) reused · \(outcome.missing) missing")
        )
    }

    static func failed(message: String) -> ScanProgress {
        ScanProgress(phase: .failed, processed: 0, total: 0, currentItem: nil, message: message)
    }

    var fraction: Double {
        guard total > 0 else { return phase == .completed ? 1 : 0 }
        return min(1, Double(processed) / Double(total))
    }

    var isRunning: Bool { [.discovering, .hashing, .grouping].contains(phase) }

    var label: String {
        switch phase {
        case .idle: return String(localized: "Ready")
        case .discovering: return String(localized: "Discovering media")
        case .hashing: return String(localized: "Updating incremental index")
        case .grouping: return String(localized: "Building exact groups")
        case .completed: return String(localized: "Completed")
        case .cancelled: return String(localized: "Cancelled")
        case .failed: return String(localized: "Needs attention")
        }
    }
}
