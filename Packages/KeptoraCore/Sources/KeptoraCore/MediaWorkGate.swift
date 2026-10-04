import Foundation

/// Bounded decode/IO admission. Cancelled queued work checks cancellation before
/// entering the operation and always gives its slot back.
public actor MediaWorkGate {
    public static let thumbnails = MediaWorkGate(limit: 4)
    private let limit: Int
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    public init(limit: Int) { self.limit = max(1, limit) }
    private func acquire() async {
        if active < limit { active += 1; return }
        await withCheckedContinuation { waiting.append($0) }
    }
    private func release() {
        if waiting.isEmpty { active -= 1 }
        else { waiting.removeFirst().resume() }
    }
    public func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        try Task.checkCancellation()
        await acquire()
        do {
            try Task.checkCancellation()
            let value = try await operation()
            release(); return value
        } catch { release(); throw error }
    }
}
