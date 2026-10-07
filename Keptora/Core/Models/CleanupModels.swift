import Foundation
import CryptoKit
#if !os(Linux)
import KeptoraCore
#endif

enum CleanupPlanState: String, Codable, Sendable {
    case draft
    case committing
    case committed
    case partiallyCommitted
    case restored
    case partiallyRestored
    case failed

    var label: String {
        switch self {
        case .draft: return ReviewText.tr("Draft")
        case .committing: return ReviewText.tr("Committing")
        case .committed: return ReviewText.tr("Quarantined")
        case .partiallyCommitted: return ReviewText.tr("Partially quarantined")
        case .restored: return ReviewText.tr("Restored")
        case .partiallyRestored: return ReviewText.tr("Partially restored")
        case .failed: return ReviewText.tr("Needs attention")
        }
    }
}

enum CleanupOperationState: String, Codable, Sendable {
    case pending
    case quarantined
    case restored
    case failed
}

struct CleanupCandidate: Hashable, Sendable {
    let groupID: String
    let assetID: AssetID
    let canonicalAssetID: AssetID
    let displayName: String
    let originalURL: URL
    let byteCount: Int64
    let digest: String
    let family: AssetFamilySummary?
    let decisionActor: String
    let decisionReasonCode: String
    let decisionUpdatedAt: Date

    init(
        groupID: String,
        assetID: AssetID,
        canonicalAssetID: AssetID,
        displayName: String,
        originalURL: URL,
        byteCount: Int64,
        digest: String,
        family: AssetFamilySummary? = nil,
        decisionActor: String = "user",
        decisionReasonCode: String = "user-added-to-plan",
        decisionUpdatedAt: Date = .distantPast
    ) {
        self.groupID = groupID
        self.assetID = assetID
        self.canonicalAssetID = canonicalAssetID
        self.displayName = displayName
        self.originalURL = originalURL
        self.byteCount = byteCount
        self.digest = digest
        self.family = family
        self.decisionActor = decisionActor
        self.decisionReasonCode = decisionReasonCode
        self.decisionUpdatedAt = decisionUpdatedAt
    }
}

struct CleanupOperationPreview: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let groupID: String
    let assetID: AssetID
    let displayName: String
    let originalURL: URL
    let quarantineURL: URL
    let byteCount: Int64
    let digest: String
    let familyID: String?
    let familyKind: AssetFamilyKind?
    let familyRole: AssetFamilyRole?
    let familyPolicy: FamilySafetyPolicy?
    let decisionActor: String?
    let decisionReasonCode: String?
    let decisionUpdatedAt: Date?
    let canonicalAssetID: AssetID?

    init(
        id: String,
        groupID: String,
        assetID: AssetID,
        displayName: String,
        originalURL: URL,
        quarantineURL: URL,
        byteCount: Int64,
        digest: String,
        familyID: String? = nil,
        familyKind: AssetFamilyKind? = nil,
        familyRole: AssetFamilyRole? = nil,
        familyPolicy: FamilySafetyPolicy? = nil,
        decisionActor: String? = nil,
        decisionReasonCode: String? = nil,
        decisionUpdatedAt: Date? = nil,
        canonicalAssetID: AssetID? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.assetID = assetID
        self.displayName = displayName
        self.originalURL = originalURL
        self.quarantineURL = quarantineURL
        self.byteCount = byteCount
        self.digest = digest
        self.familyID = familyID
        self.familyKind = familyKind
        self.familyRole = familyRole
        self.familyPolicy = familyPolicy
        self.decisionActor = decisionActor
        self.decisionReasonCode = decisionReasonCode
        self.decisionUpdatedAt = decisionUpdatedAt
        self.canonicalAssetID = canonicalAssetID
    }

    var decisionReasonLabel: String? {
        guard let decisionReasonCode else { return nil }
        switch decisionReasonCode {
        case "user-added-to-plan": return ReviewText.tr("Added to the Safety Plan by you")
        case "user-batch-added-exact-extras": return ReviewText.tr("Extra copies added together")
        default: return ReviewText.tr("Review decision recorded")
        }
    }
}


// MARK: - Phase 5R Safety Plan Freshness & Lineage

enum SafetyPlanFreshnessState: String, Codable, Hashable, Sendable {
    case current
    case stale
    case legacy

    var label: String {
        switch self {
        case .current: return ReviewText.tr("Current")
        case .stale: return ReviewText.tr("Stale — regenerate")
        case .legacy: return ReviewText.tr("Legacy — regenerate")
        }
    }
}

struct SafetyPlanFreshnessAssessment: Codable, Hashable, Sendable {
    let state: SafetyPlanFreshnessState
    let expectedFingerprint: String?
    let currentFingerprint: String
    let expectedOperationCount: Int
    let currentOperationCount: Int

    var permitsCommit: Bool { state == .current }
}

struct SafetyPlanLineageIdentity: Codable, Hashable, Sendable {
    let lineageID: String
    let previousLineageID: String?
    let revisionNumber: Int
}

enum SafetyPlanLineageState: String, Codable, Hashable, Sendable {
    case prepared
    case stale
    case superseded
    case cancelled
    case committed
    case failed
}

struct SafetyPlanLineageRecord: Identifiable, Codable, Hashable, Sendable {
    var id: String { lineage.lineageID }
    let lineage: SafetyPlanLineageIdentity
    let planID: String
    let sourceRoot: String
    let decisionSnapshotFingerprint: String
    let operationCount: Int
    let createdAt: Date
    var state: SafetyPlanLineageState
}

enum SafetyPlanLineageEngine {
    static func nextIdentity(records: [SafetyPlanLineageRecord], sourceRoot: URL) -> SafetyPlanLineageIdentity {
        let source = sourceRoot.standardizedFileURL.path
        let latest = records
            .filter { $0.sourceRoot == source }
            .max { lhs, rhs in lhs.lineage.revisionNumber < rhs.lineage.revisionNumber }
        return SafetyPlanLineageIdentity(
            lineageID: UUID().uuidString.lowercased(),
            previousLineageID: latest?.lineage.lineageID,
            revisionNumber: (latest?.lineage.revisionNumber ?? 0) + 1
        )
    }
}

enum KeptoraSafetyPlanSHA256 {
    static func hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum SafetyPlanDecisionFingerprint {
    static func fingerprint(operations: [CleanupOperationPreview]) -> String {
        digest(operations.map { operation in
            canonical(
                groupID: operation.groupID,
                assetID: operation.assetID,
                canonicalAssetID: operation.canonicalAssetID,
                digest: operation.digest,
                actor: operation.decisionActor,
                reasonCode: operation.decisionReasonCode,
                updatedAt: operation.decisionUpdatedAt
            )
        })
    }

    static func fingerprint(candidates: [CleanupCandidate]) -> String {
        digest(candidates.map { candidate in
            canonical(
                groupID: candidate.groupID,
                assetID: candidate.assetID,
                canonicalAssetID: candidate.canonicalAssetID,
                digest: candidate.digest,
                actor: candidate.decisionActor,
                reasonCode: candidate.decisionReasonCode,
                updatedAt: candidate.decisionUpdatedAt
            )
        })
    }

    private static func canonical(
        groupID: String,
        assetID: AssetID,
        canonicalAssetID: AssetID?,
        digest: String,
        actor: String?,
        reasonCode: String?,
        updatedAt: Date?
    ) -> String {
        let timestamp = updatedAt.map { String(format: "%.6f", $0.timeIntervalSince1970) } ?? ""
        return [
            groupID,
            assetID.rawValue,
            canonicalAssetID?.rawValue ?? "",
            digest,
            actor ?? "",
            reasonCode ?? "",
            timestamp
        ].joined(separator: "\u{1f}")
    }

    private static func digest(_ rows: [String]) -> String {
        KeptoraSafetyPlanSHA256.hex(rows.sorted().joined(separator: "\u{1e}"))
    }
}

struct CleanupPlanPreview: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceRoot: URL
    let quarantineRoot: URL
    let createdAt: Date
    let operations: [CleanupOperationPreview]
    let sourceVolume: VolumeIdentity?
    let familyWarnings: [FamilySafetyIssue]
    let decisionSnapshotFingerprint: String?
    let lineage: SafetyPlanLineageIdentity?

    init(
        id: String,
        sourceRoot: URL,
        quarantineRoot: URL,
        createdAt: Date,
        operations: [CleanupOperationPreview],
        sourceVolume: VolumeIdentity? = nil,
        familyWarnings: [FamilySafetyIssue] = [],
        decisionSnapshotFingerprint: String? = nil,
        lineage: SafetyPlanLineageIdentity? = nil
    ) {
        self.id = id
        self.sourceRoot = sourceRoot
        self.quarantineRoot = quarantineRoot
        self.createdAt = createdAt
        self.operations = operations
        self.sourceVolume = sourceVolume
        self.familyWarnings = familyWarnings
        self.decisionSnapshotFingerprint = decisionSnapshotFingerprint ?? SafetyPlanDecisionFingerprint.fingerprint(operations: operations)
        self.lineage = lineage
    }

    func withLineage(_ lineage: SafetyPlanLineageIdentity) -> CleanupPlanPreview {
        CleanupPlanPreview(
            id: id, sourceRoot: sourceRoot, quarantineRoot: quarantineRoot, createdAt: createdAt,
            operations: operations, sourceVolume: sourceVolume, familyWarnings: familyWarnings,
            decisionSnapshotFingerprint: decisionSnapshotFingerprint, lineage: lineage
        )
    }

    var estimatedBytes: Int64 { operations.reduce(0) { $0 + $1.byteCount } }
    var provenanceCount: Int { operations.filter { $0.decisionReasonCode != nil && $0.canonicalAssetID != nil }.count }
}

struct CleanupManifestOperation: Codable, Hashable, Sendable {
    let operationID: String
    let groupID: String
    let assetID: String
    let originalPath: String
    let quarantinePath: String
    let byteCount: Int64
    let digest: String
    let familyID: String?
    let familyKind: String?
    let familyRole: String?
    let decisionActor: String?
    let decisionReasonCode: String?
    let decisionUpdatedAt: Date?
    let canonicalAssetID: String?

    init(
        operationID: String,
        groupID: String,
        assetID: String,
        originalPath: String,
        quarantinePath: String,
        byteCount: Int64,
        digest: String,
        familyID: String? = nil,
        familyKind: String? = nil,
        familyRole: String? = nil,
        decisionActor: String? = nil,
        decisionReasonCode: String? = nil,
        decisionUpdatedAt: Date? = nil,
        canonicalAssetID: String? = nil
    ) {
        self.operationID = operationID
        self.groupID = groupID
        self.assetID = assetID
        self.originalPath = originalPath
        self.quarantinePath = quarantinePath
        self.byteCount = byteCount
        self.digest = digest
        self.familyID = familyID
        self.familyKind = familyKind
        self.familyRole = familyRole
        self.decisionActor = decisionActor
        self.decisionReasonCode = decisionReasonCode
        self.decisionUpdatedAt = decisionUpdatedAt
        self.canonicalAssetID = canonicalAssetID
    }
}

struct CleanupManifest: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let planID: String
    let sourceRoot: String
    let quarantineRoot: String
    let createdAt: Date
    let appVersion: String
    let sourceVolumeID: String?
    let decisionSnapshotFingerprint: String?
    let safetyPlanLineageID: String?
    let previousSafetyPlanLineageID: String?
    let safetyPlanRevision: Int?
    let operations: [CleanupManifestOperation]

    init(
        schemaVersion: Int,
        planID: String,
        sourceRoot: String,
        quarantineRoot: String,
        createdAt: Date,
        appVersion: String,
        sourceVolumeID: String? = nil,
        decisionSnapshotFingerprint: String? = nil,
        safetyPlanLineageID: String? = nil,
        previousSafetyPlanLineageID: String? = nil,
        safetyPlanRevision: Int? = nil,
        operations: [CleanupManifestOperation]
    ) {
        self.schemaVersion = schemaVersion
        self.planID = planID
        self.sourceRoot = sourceRoot
        self.quarantineRoot = quarantineRoot
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.sourceVolumeID = sourceVolumeID
        self.decisionSnapshotFingerprint = decisionSnapshotFingerprint
        self.safetyPlanLineageID = safetyPlanLineageID
        self.previousSafetyPlanLineageID = previousSafetyPlanLineageID
        self.safetyPlanRevision = safetyPlanRevision
        self.operations = operations
    }
}

struct SignedCleanupManifest: Codable, Hashable, Sendable {
    let algorithm: String
    let payloadBase64: String
    let signatureBase64: String
    let publicKeyBase64: String
}

struct CleanupHistoryItem: Identifiable, Hashable, Sendable {
    let id: String
    let state: CleanupPlanState
    let sourcePath: String
    let operationCount: Int
    let estimatedBytes: Int64
    let createdAt: Date
    let committedAt: Date?
    let restoredAt: Date?
    let manifestPath: String?

    var canRestore: Bool {
        state == .committed || state == .partiallyCommitted || state == .partiallyRestored
    }
}

struct StoredManifestRecord: Hashable, Sendable {
    let planID: String
    let path: String
    let signature: String
    let publicKey: String
}

struct CleanupCommitResult: Hashable, Sendable {
    let planID: String
    let movedCount: Int
    let failedCount: Int
    let manifestURL: URL
    let verification: QuarantineVerificationReport?
}

struct CleanupRestoreResult: Hashable, Sendable {
    let planID: String
    let restoredCount: Int
    let failedCount: Int
    let verification: QuarantineVerificationReport?
}

struct IndexedAssetState: Hashable, Sendable {
    let assetID: AssetID
    let byteCount: Int64
    let modificationDate: Date?
    let digest: String?
    let isQuarantined: Bool
    let lastSeenScanID: String?

    func matches(byteCount: Int64, modificationDate: Date?) -> Bool {
        guard !isQuarantined, self.byteCount == byteCount, digest != nil else { return false }
        switch (self.modificationDate, modificationDate) {
        case (nil, nil): return true
        case let (lhs?, rhs?): return abs(lhs.timeIntervalSince(rhs)) < 0.001
        default: return false
        }
    }
}

struct ScanOutcome: Hashable, Sendable {
    let groups: [ReviewGroup]
    let discovered: Int
    let hashed: Int
    let reused: Int
    let missing: Int
}

enum RestoreOperationReadiness: String, Codable, Sendable {
    case ready
    case originalOccupied
    case quarantineMissing
    case contentChanged
    case alreadyRestored
    case notQuarantined

    var label: String {
        switch self {
        case .ready: return ReviewText.tr("Ready to restore")
        case .originalOccupied: return ReviewText.tr("Original path occupied")
        case .quarantineMissing: return ReviewText.tr("Quarantine file missing")
        case .contentChanged: return ReviewText.tr("Quarantine content changed")
        case .alreadyRestored: return ReviewText.tr("Already restored")
        case .notQuarantined: return ReviewText.tr("Not eligible")
        }
    }

    var isRestorable: Bool { self == .ready }
}

struct RestoreOperationCheck: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let displayName: String
    let originalURL: URL
    let quarantineURL: URL
    let byteCount: Int64
    let readiness: RestoreOperationReadiness
    let detail: String
}

struct RestorePlanPreview: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceRoot: URL
    let quarantineRoot: URL
    let createdAt: Date
    let operations: [RestoreOperationCheck]

    var readyCount: Int { operations.filter { $0.readiness == .ready }.count }
    var blockedCount: Int { operations.count - readyCount - alreadyRestoredCount }
    var alreadyRestoredCount: Int { operations.filter { $0.readiness == .alreadyRestored }.count }
    var restorableBytes: Int64 {
        operations.filter { $0.readiness == .ready }.reduce(0) { $0 + $1.byteCount }
    }
    var canRestore: Bool { readyCount > 0 && blockedCount == 0 }
}

// MARK: - Phase 5S Quarantine Verification & Restore Lineage

enum QuarantineVerificationPhase: String, Codable, Hashable, Sendable {
    case postCommit
    case manualReview
    case postRestore

    var localizedLabel: String {
        switch self {
        case .postCommit: return ReviewText.tr("Post-commit")
        case .manualReview: return ReviewText.tr("Manual review")
        case .postRestore: return ReviewText.tr("Post-restore")
        }
    }
}

enum QuarantineVerificationState: String, Codable, Hashable, Sendable {
    case verified
    case reviewRequired

    var label: String {
        switch self {
        case .verified: return ReviewText.tr("Verified against manifest")
        case .reviewRequired: return ReviewText.tr("Review required")
        }
    }
}

enum QuarantineOperationVerificationState: String, Codable, Hashable, Sendable {
    case verifiedQuarantined
    case verifiedRestored
    case databaseStateMismatch
    case originalUnexpectedlyPresent
    case quarantineMissing
    case quarantineContentChanged
    case restoredSourceMissing
    case restoredSourceChanged
    case quarantineUnexpectedlyPresent

    var isVerified: Bool { self == .verifiedQuarantined || self == .verifiedRestored }
}

struct QuarantineObservedOperationState: Hashable, Codable, Sendable {
    let operationID: String
    let databaseState: CleanupOperationState?
    let originalExists: Bool
    let quarantineExists: Bool
    let observedDigest: String?
    let observedByteCount: Int64?
}

struct QuarantineOperationVerification: Identifiable, Hashable, Codable, Sendable {
    var id: String { operationID }
    let operationID: String
    let state: QuarantineOperationVerificationState
    let expectedDigest: String
    let observedDigest: String?
    let expectedByteCount: Int64
    let observedByteCount: Int64?
}

struct QuarantineVerificationReport: Hashable, Codable, Sendable {
    let planID: String
    let phase: QuarantineVerificationPhase
    let checkedAt: Date
    let manifestFingerprint: String
    let checks: [QuarantineOperationVerification]
    let reportFingerprint: String

    var verifiedCount: Int { checks.filter { $0.state.isVerified }.count }
    var issueCount: Int { checks.count - verifiedCount }
    var state: QuarantineVerificationState { issueCount == 0 ? .verified : .reviewRequired }
}

struct QuarantineVerificationLineageIdentity: Hashable, Codable, Sendable {
    let recordID: String
    let previousRecordID: String?
    let revisionNumber: Int
}

struct QuarantineVerificationLineageRecord: Identifiable, Hashable, Codable, Sendable {
    var id: String { identity.recordID }
    let identity: QuarantineVerificationLineageIdentity
    let planID: String
    let phase: QuarantineVerificationPhase
    let createdAt: Date
    let manifestFingerprint: String
    let reportFingerprint: String
    let state: QuarantineVerificationState
    let operationCount: Int
    let verifiedCount: Int
    let issueCount: Int
}

enum QuarantineVerificationEngine {
    static func classify(
        expected: CleanupManifestOperation,
        observed: QuarantineObservedOperationState
    ) -> QuarantineOperationVerification {
        let state: QuarantineOperationVerificationState
        switch observed.databaseState {
        case .quarantined:
            if observed.originalExists { state = .originalUnexpectedlyPresent }
            else if !observed.quarantineExists { state = .quarantineMissing }
            else if observed.observedDigest != expected.digest || observed.observedByteCount != expected.byteCount { state = .quarantineContentChanged }
            else { state = .verifiedQuarantined }
        case .restored:
            if !observed.originalExists { state = .restoredSourceMissing }
            else if observed.quarantineExists { state = .quarantineUnexpectedlyPresent }
            else if observed.observedDigest != expected.digest || observed.observedByteCount != expected.byteCount { state = .restoredSourceChanged }
            else { state = .verifiedRestored }
        default:
            state = .databaseStateMismatch
        }
        return QuarantineOperationVerification(
            operationID: expected.operationID,
            state: state,
            expectedDigest: expected.digest,
            observedDigest: observed.observedDigest,
            expectedByteCount: expected.byteCount,
            observedByteCount: observed.observedByteCount
        )
    }

    static func report(
        manifest: CleanupManifest,
        phase: QuarantineVerificationPhase,
        observed: [QuarantineObservedOperationState],
        checkedAt: Date = .now
    ) -> QuarantineVerificationReport {
        let byID = Dictionary(observed.map { ($0.operationID, $0) }, uniquingKeysWith: { first, _ in first })
        let checks = manifest.operations.map { operation in
            classify(
                expected: operation,
                observed: byID[operation.operationID] ?? QuarantineObservedOperationState(
                    operationID: operation.operationID,
                    databaseState: nil,
                    originalExists: false,
                    quarantineExists: false,
                    observedDigest: nil,
                    observedByteCount: nil
                )
            )
        }
        let manifestFingerprint = manifestIdentityFingerprint(manifest)
        let reportFingerprint = fingerprint(
            [manifestFingerprint, phase.rawValue] + checks.map {
                [
                    $0.operationID,
                    $0.state.rawValue,
                    $0.expectedDigest,
                    $0.observedDigest ?? "",
                    String($0.expectedByteCount),
                    $0.observedByteCount.map(String.init) ?? ""
                ].joined(separator: "\u{1f}")
            }.sorted()
        )
        return QuarantineVerificationReport(
            planID: manifest.planID,
            phase: phase,
            checkedAt: checkedAt,
            manifestFingerprint: manifestFingerprint,
            checks: checks,
            reportFingerprint: reportFingerprint
        )
    }

    static func nextIdentity(
        records: [QuarantineVerificationLineageRecord],
        planID: String
    ) -> QuarantineVerificationLineageIdentity {
        let latest = records
            .filter { $0.planID == planID }
            .max { $0.identity.revisionNumber < $1.identity.revisionNumber }
        return QuarantineVerificationLineageIdentity(
            recordID: UUID().uuidString.lowercased(),
            previousRecordID: latest?.identity.recordID,
            revisionNumber: (latest?.identity.revisionNumber ?? 0) + 1
        )
    }

    static func lineageRecord(
        report: QuarantineVerificationReport,
        existing: [QuarantineVerificationLineageRecord]
    ) -> QuarantineVerificationLineageRecord {
        QuarantineVerificationLineageRecord(
            identity: nextIdentity(records: existing, planID: report.planID),
            planID: report.planID,
            phase: report.phase,
            createdAt: report.checkedAt,
            manifestFingerprint: report.manifestFingerprint,
            reportFingerprint: report.reportFingerprint,
            state: report.state,
            operationCount: report.checks.count,
            verifiedCount: report.verifiedCount,
            issueCount: report.issueCount
        )
    }

    static func manifestIdentityFingerprint(_ manifest: CleanupManifest) -> String {
        let rows = manifest.operations.map {
            [$0.operationID, $0.assetID, $0.digest, String($0.byteCount), $0.originalPath, $0.quarantinePath].joined(separator: "\u{1f}")
        }.sorted()
        return fingerprint([
            manifest.planID,
            manifest.sourceRoot,
            manifest.quarantineRoot,
            manifest.decisionSnapshotFingerprint ?? "",
            manifest.safetyPlanLineageID ?? "",
            String(manifest.safetyPlanRevision ?? 0)
        ] + rows)
    }

    private static func fingerprint(_ rows: [String]) -> String {
        KeptoraSafetyPlanSHA256.hex(rows.joined(separator: "\u{1e}"))
    }
}


// MARK: - Phase 6 — Quarantine Decision Reconciliation

enum QuarantineDecisionReconciliationState: String, Codable, CaseIterable, Hashable, Sendable {
    case current
    case reverifyRequired
    case stale
    case superseded

    var localizedLabel: String {
        switch self {
        case .current: return ReviewText.tr("Current")
        case .reverifyRequired: return ReviewText.tr("Reverification required")
        case .stale: return ReviewText.tr("Stale")
        case .superseded: return ReviewText.tr("Superseded")
        }
    }
}

struct QuarantineDecisionSnapshot: Codable, Hashable, Sendable {
    var planID: String
    var decisionFingerprint: String
    var manifestFingerprint: String
    var verificationFingerprint: String
    var filesystemFingerprint: String
    var restoreFingerprint: String?
}

struct QuarantineDecisionReconciliationRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var previousRecordID: UUID?
    var revisionNumber: Int
    var checkedAt: Date = Date()
    var snapshot: QuarantineDecisionSnapshot
    var state: QuarantineDecisionReconciliationState
    var reasons: [String]
}

enum KeptoraPhase6DecisionCore {
    static func assess(previous: QuarantineDecisionSnapshot?, current: QuarantineDecisionSnapshot) -> (QuarantineDecisionReconciliationState, [String]) {
        guard let previous else { return (.reverifyRequired, ["No prior decision snapshot exists."]) }
        var reasons: [String] = []
        if previous.decisionFingerprint != current.decisionFingerprint { reasons.append("Review decision changed.") }
        if previous.manifestFingerprint != current.manifestFingerprint { reasons.append("Quarantine manifest changed.") }
        if previous.filesystemFingerprint != current.filesystemFingerprint { reasons.append("Filesystem state changed.") }
        if previous.restoreFingerprint != current.restoreFingerprint { reasons.append("Restore state changed.") }
        if previous.verificationFingerprint != current.verificationFingerprint { reasons.append("Verification lineage changed.") }
        return reasons.isEmpty ? (.current, []) : (.stale, reasons)
    }

    static func makeRecord(snapshot: QuarantineDecisionSnapshot, history: [QuarantineDecisionReconciliationRecord], now: Date = Date()) -> QuarantineDecisionReconciliationRecord {
        let prior = history.filter { $0.snapshot.planID == snapshot.planID }.max { $0.revisionNumber < $1.revisionNumber }
        let assessment = assess(previous: prior?.snapshot, current: snapshot)
        return .init(previousRecordID: prior?.id, revisionNumber: (prior?.revisionNumber ?? 0) + 1, checkedAt: now, snapshot: snapshot, state: assessment.0, reasons: assessment.1)
    }
}

// MARK: - Phase 6 persistence — Decision Reconciliation

struct QuarantineDecisionReconciliationLedger: Codable, Sendable {
    var schemaVersion: Int = 1
    var records: [QuarantineDecisionReconciliationRecord] = []
}

final class QuarantineDecisionReconciliationStore {
    private let url: URL
    init(baseDirectory: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let base = (baseDirectory ?? appSupport).appendingPathComponent("Keptora", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("QuarantineDecisionReconciliation.json")
    }
    func load() -> [QuarantineDecisionReconciliationRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        if let ledger = try? decoder.decode(QuarantineDecisionReconciliationLedger.self, from: data) { return ledger.records }
        return (try? decoder.decode([QuarantineDecisionReconciliationRecord].self, from: data)) ?? []
    }
    func save(_ records: [QuarantineDecisionReconciliationRecord]) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(QuarantineDecisionReconciliationLedger(records: records)).write(to: url, options: .atomic)
    }
}
