import Foundation

enum ReconciliationIssueKind: String, Codable, Sendable {
    case recoveredQuarantine
    case recoveredRestore
    case incompleteMove
    case ambiguousDiskState
    case missingBothCopies
    case volumeUnavailable
}

struct ReconciliationIssue: Identifiable, Hashable, Sendable {
    let id: String
    let planID: String
    let operationID: String?
    let kind: ReconciliationIssueKind
    let title: String
    let detail: String
    let needsUserAttention: Bool
}

struct PendingCleanupOperationRecord: Hashable, Sendable {
    let planID: String
    let planState: CleanupPlanState
    let operationID: String
    let assetID: AssetID
    let originalURL: URL
    let quarantineURL: URL
    let byteCount: Int64
    let digest: String
    let operationState: CleanupOperationState
}

struct ResumableScanSession: Hashable, Sendable {
    let id: String
    let cursorStableKey: String?
    let processed: Int
    let total: Int
    let hashed: Int
    let reused: Int
    let volumeID: String?
}
