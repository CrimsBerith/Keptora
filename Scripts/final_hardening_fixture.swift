import Foundation

@main
struct FinalHardeningFixture {
    static func main() async {
        let coordinator = KeptoraLifecycleCoordinator()
        let first = await coordinator.begin("first")
        let firstMayCommit = await coordinator.mayCommit(first)
        precondition(firstMayCommit)
        await coordinator.suspendAndInvalidateOutstandingWork()
        let staleMayCommit = await coordinator.mayCommit(first)
        precondition(!staleMayCommit)
        await coordinator.resumeAfterResourceRevalidation()
        await coordinator.markBookmarkRevalidated()
        let second = await coordinator.begin("second")
        let secondMayCommit = await coordinator.mayCommit(second)
        precondition(secondMayCommit)
        await coordinator.cancel(second)
        let cancelledMayCommit = await coordinator.mayCommit(second)
        precondition(!cancelledMayCommit)
        let snap = await coordinator.snapshot()
        precondition(snap.state == .active)
        precondition(snap.bookmarkRevision == 1)
        precondition(KeptoraWindowStressContract.density(width: 1010, height: 800) == .compact)
        precondition(KeptoraWindowStressContract.density(width: 1490, height: 900) == .expansive)
        for i in 0..<50_000 {
            let t = await coordinator.begin("stress-\(i)")
            if i.isMultiple(of: 2) { await coordinator.cancel(t) } else { await coordinator.finish(t) }
        }
        let end = await coordinator.snapshot()
        precondition(end.outstandingWorkCount == 0)
        print("FINAL_HARDENING_PASS Cullora epoch=\(end.epoch) bookmarkRevision=\(end.bookmarkRevision)")
    }
}
