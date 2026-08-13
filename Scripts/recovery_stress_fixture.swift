import Foundation

@main
enum RecoveryStressRunner {
    static func main() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Cullora-recovery-" + UUID().uuidString, isDirectory: true)
        let journal = CulloraRecoveryJournal(directory: base, defaultStaleAfter: 5)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let a = try journal.begin(operation: "export", payloadDigest: "abc", now: t0)
        let b = try journal.begin(operation: "review", payloadDigest: "def", now: t0.addingTimeInterval(10))
        _ = try journal.transition(id: b.id, to: .cancelled, note: "user-cancel", now: t0.addingTimeInterval(11))
        let stale = journal.recoverableOperations(now: t0.addingTimeInterval(20), staleAfter: 5)
        precondition(stale.map(\.id) == [a.id])

        let recordsURL = base.appendingPathComponent("records", isDirectory: true)
        try Data("{bad-json".utf8).write(to: recordsURL.appendingPathComponent("corrupt.json"))
        _ = journal.loadAll()
        let corruptURL = base.appendingPathComponent("corrupt", isDirectory: true)
        let quarantined = try FileManager.default.contentsOfDirectory(at: corruptURL, includingPropertiesForKeys: nil)
        precondition(!quarantined.isEmpty)

        var bulk: [CulloraRecoveryRecord] = []
        bulk.reserveCapacity(100_000)
        for i in 0..<100_000 {
            let state: CulloraRecoveryState = (i % 4 == 0) ? .started : ((i % 4 == 1) ? .committed : ((i % 4 == 2) ? .cancelled : .failed))
            bulk.append(CulloraRecoveryRecord(id: UUID(), operation: "op-\(i % 17)", startedAt: t0, updatedAt: t0.addingTimeInterval(Double(i % 30)), payloadDigest: String(i), state: state))
        }
        let start = Date()
        let result = journal.classifyRecoverable(bulk, now: t0.addingTimeInterval(60), staleAfter: 15)
        let elapsed = Date().timeIntervalSince(start)
        precondition(result.count == 25_000)
        print("RECOVERY_STRESS_PASS count=\(result.count) elapsed=\(String(format: "%.4f", elapsed))")
        try? FileManager.default.removeItem(at: base)
    }
}
