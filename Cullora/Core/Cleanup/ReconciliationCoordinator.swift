import Foundation

actor ReconciliationCoordinator {
    private let database: SQLiteDatabase
    private let hasher = ExactHasher()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func reconcile(sourceRoot: URL) async throws -> [ReconciliationIssue] {
        let records = try await database.fetchOperationsNeedingReconciliation(
            sourcePath: sourceRoot.standardizedFileURL.path
        )
        var issues: [ReconciliationIssue] = []
        var affectedPlans = Set<String>()

        for record in records {
            affectedPlans.insert(record.planID)
            let originalExists = FileManager.default.fileExists(atPath: record.originalURL.path)
            let quarantineExists = FileManager.default.fileExists(atPath: record.quarantineURL.path)

            switch (record.operationState, originalExists, quarantineExists) {
            case (.pending, false, true):
                if try await matches(record.quarantineURL, record: record) {
                    try await database.markOperationQuarantined(operationID: record.operationID, assetID: record.assetID, quarantinePath: record.quarantineURL.path)
                    issues.append(issue(record, .recoveredQuarantine, "Recovered interrupted quarantine", "The file had moved before the previous process ended. Cullora verified its digest and repaired the database record.", false))
                } else {
                    issues.append(issue(record, .ambiguousDiskState, "Quarantine copy changed", "A file exists in quarantine but no longer matches the signed operation digest.", true))
                }
            case (.pending, true, false):
                try await database.markOperationFailed(operationID: record.operationID, message: "Recovered after interruption: source remained in place.")
                issues.append(issue(record, .incompleteMove, "Interrupted move did not complete", "The original is still present and no quarantine copy exists. No file was removed.", false))
            case (.pending, true, true):
                issues.append(issue(record, .ambiguousDiskState, "Both file copies exist", "Cullora found both the original and quarantine paths and will not choose one automatically.", true))
            case (.pending, false, false):
                issues.append(issue(record, .missingBothCopies, "File unavailable at both paths", "Reconnect the original volume or locate the file manually before continuing.", true))
            case (.quarantined, true, false):
                if try await matches(record.originalURL, record: record) {
                    try await database.markOperationRestored(operationID: record.operationID, assetID: record.assetID, originalPath: record.originalURL.path)
                    issues.append(issue(record, .recoveredRestore, "Recovered interrupted restore", "The original file was restored before the previous process ended. Cullora repaired the database record.", false))
                } else {
                    issues.append(issue(record, .ambiguousDiskState, "Restored copy changed", "The file at the original path does not match the signed operation digest.", true))
                }
            case (.quarantined, true, true):
                issues.append(issue(record, .ambiguousDiskState, "Both original and quarantine copies exist", "Cullora will not choose or remove either copy automatically. Review both files before continuing.", true))
            case (.quarantined, false, false):
                issues.append(issue(record, .missingBothCopies, "Quarantined file is offline", "The source volume may be disconnected. Cullora made no database changes.", true))
            default:
                break
            }
        }

        for planID in affectedPlans {
            try await database.refreshCleanupPlanState(planID: planID)
        }
        if !records.isEmpty { try await database.rebuildExactGroups() }
        return issues
    }

    private func matches(_ url: URL, record: PendingCleanupOperationRecord) async throws -> Bool {
        let fingerprint = try await hasher.hashFile(at: url)
        return fingerprint.digest == record.digest && fingerprint.byteCount == record.byteCount
    }

    private func issue(_ record: PendingCleanupOperationRecord, _ kind: ReconciliationIssueKind, _ title: String, _ detail: String, _ attention: Bool) -> ReconciliationIssue {
        ReconciliationIssue(
            id: "\(record.operationID):\(kind.rawValue)",
            planID: record.planID,
            operationID: record.operationID,
            kind: kind,
            title: title,
            detail: detail,
            needsUserAttention: attention
        )
    }
}
