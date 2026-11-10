import Foundation

/// Bounded decode/IO admission. Cancelled queued work checks cancellation before
/// entering the operation and always gives its slot back.
public actor MediaWorkGate {
    public static let thumbnails = MediaWorkGate(limit: 4)
    private let limit: Int
    private var active = 0
    private var waiting: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var waitOrder: [UUID] = []

    public init(limit: Int) { self.limit = max(1, limit) }

    private func acquire() async throws {
        if active < limit { active += 1; return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waiting[id] = continuation
                waitOrder.append(id)
            }
        } onCancel: {
            Task { [weak self] in
                await self?.cancelWait(id: id)
            }
        }
    }

    private func cancelWait(id: UUID) {
        if let cont = waiting.removeValue(forKey: id) {
            waitOrder.removeAll { $0 == id }
            cont.resume(throwing: CancellationError())
        }
    }

    private func release() {
        while !waitOrder.isEmpty {
            let id = waitOrder.removeFirst()
            if let cont = waiting.removeValue(forKey: id) {
                cont.resume()
                return
            }
        }
        active -= 1
    }

    public func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        try Task.checkCancellation()
        try await acquire()
        do {
            try Task.checkCancellation()
            let value = try await operation()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }
}
