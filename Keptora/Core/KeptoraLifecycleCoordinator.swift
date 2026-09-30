import Foundation

/// Product-owned stale-work and lifecycle ownership gate.
/// The coordinator deliberately has no UI dependency so background/resume,
/// external-volume and async adapters can share one deterministic epoch rule.
struct KeptoraWorkToken: Hashable, Sendable {
    let id: UUID
    let epoch: UInt64
    let label: String
}

struct KeptoraLifecycleSnapshot: Equatable, Sendable {
    enum State: String, Sendable { case active, suspended }
    let epoch: UInt64
    let state: State
    let outstandingWorkCount: Int
    let bookmarkRevision: UInt64
}

actor KeptoraLifecycleCoordinator {
    private var epoch: UInt64 = 1
    private var state: KeptoraLifecycleSnapshot.State = .active
    private var activeTokens: Set<KeptoraWorkToken> = []
    private var cancelledIDs: Set<UUID> = []
    private var bookmarkRevision: UInt64 = 0

    @discardableResult
    func begin(_ label: String) -> KeptoraWorkToken {
        let token = KeptoraWorkToken(id: UUID(), epoch: epoch, label: label)
        activeTokens.insert(token)
        return token
    }

    /// Call immediately before committing an async result to app state.
    func mayCommit(_ token: KeptoraWorkToken) -> Bool {
        state == .active && token.epoch == epoch && activeTokens.contains(token) && !cancelledIDs.contains(token.id)
    }

    func finish(_ token: KeptoraWorkToken) {
        activeTokens.remove(token)
        cancelledIDs.remove(token.id)
    }

    func cancel(_ token: KeptoraWorkToken) {
        if activeTokens.remove(token) != nil { cancelledIDs.insert(token.id) }
    }

    /// Invalidates every callback captured before suspension or external-volume loss.
    func suspendAndInvalidateOutstandingWork() {
        state = .suspended
        epoch &+= 1
        activeTokens.removeAll(keepingCapacity: true)
        cancelledIDs.removeAll(keepingCapacity: true)
    }

    /// Resume never revives old tokens; adapters must open/revalidate resources again.
    func resumeAfterResourceRevalidation() { state = .active }

    /// Increment only after a security-scoped bookmark or external resource is revalidated.
    func markBookmarkRevalidated() { bookmarkRevision &+= 1 }

    func snapshot() -> KeptoraLifecycleSnapshot {
        .init(epoch: epoch, state: state, outstandingWorkCount: activeTokens.count, bookmarkRevision: bookmarkRevision)
    }
}
