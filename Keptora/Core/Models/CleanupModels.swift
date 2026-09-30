import Foundation

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
        case .draft: return String(localized: "Draft")
        case .committing: return String(localized: "Committing")
        case .committed: return String(localized: "Quarantined")
        case .partiallyCommitted: return String(localized: "Partially quarantined")
        case .restored: return String(localized: "Restored")
        case .partiallyRestored: return String(localized: "Partially restored")
        case .failed: return String(localized: "Needs attention")
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
        self.decisionActor = decisionActor
        self.decisionReasonCode = decisionReasonCode
        self.decisionUpdatedAt = decisionUpdatedAt
        self.canonicalAssetID = canonicalAssetID
    }

    var decisionReasonLabel: String? {
        guard let decisionReasonCode else { return nil }
        switch decisionReasonCode {
        case "user-added-to-plan": return "Added by user"
        case "user-batch-added-exact-extras": return "Batch-added exact extra"
        default: return decisionReasonCode.replacingOccurrences(of: "-", with: " ").capitalized
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
        case .current: return String(localized: "Current")
        case .stale: return String(localized: "Stale — regenerate")
        case .legacy: return String(localized: "Legacy — regenerate")
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

private struct KeptoraSafetyPlanSHA256 {
    private static let initialState: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    private static let constants: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    ]
    private var state = KeptoraSafetyPlanSHA256.initialState
    private var buffer: [UInt8] = []
    private var byteCount: UInt64 = 0

    mutating func update<S: Sequence>(bytes: S) where S.Element == UInt8 {
        for byte in bytes {
            buffer.append(byte); byteCount &+= 1
            if buffer.count == 64 { process(buffer); buffer.removeAll(keepingCapacity: true) }
        }
    }

    mutating func finalizeHex() -> String {
        let bitLength = byteCount &* 8
        buffer.append(0x80)
        while buffer.count % 64 != 56 { buffer.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
        }
        var offset = 0
        while offset < buffer.count { process(Array(buffer[offset..<(offset + 64)])); offset += 64 }
        buffer.removeAll()
        return state.map { String(format: "%08x", $0) }.joined()
    }

    static func hex(_ string: String) -> String {
        var hasher = KeptoraSafetyPlanSHA256()
        hasher.update(bytes: string.utf8)
        return hasher.finalizeHex()
    }

    private mutating func process(_ chunk: [UInt8]) {
        var w = [UInt32](repeating: 0, count: 64)
        for i in 0..<16 {
            let o = i * 4
            w[i] = (UInt32(chunk[o]) << 24) | (UInt32(chunk[o+1]) << 16) | (UInt32(chunk[o+2]) << 8) | UInt32(chunk[o+3])
        }
        for i in 16..<64 {
            let s0 = ror(w[i-15], 7) ^ ror(w[i-15], 18) ^ (w[i-15] >> 3)
            let s1 = ror(w[i-2], 17) ^ ror(w[i-2], 19) ^ (w[i-2] >> 10)
            w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
        }
        var a=state[0], b=state[1], c=state[2], d=state[3], e=state[4], f=state[5], g=state[6], h=state[7]
        for i in 0..<64 {
            let s1 = ror(e, 6) ^ ror(e, 11) ^ ror(e, 25)
            let ch = (e & f) ^ ((~e) & g)
            let t1 = h &+ s1 &+ ch &+ Self.constants[i] &+ w[i]
            let s0 = ror(a, 2) ^ ror(a, 13) ^ ror(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let t2 = s0 &+ maj
            h=g; g=f; f=e; e=d &+ t1; d=c; c=b; b=a; a=t1 &+ t2
        }
        state[0]&+=a; state[1]&+=b; state[2]&+=c; state[3]&+=d
        state[4]&+=e; state[5]&+=f; state[6]&+=g; state[7]&+=h
    }

    private func ror(_ value: UInt32, _ amount: UInt32) -> UInt32 {
        (value >> amount) | (value << (32 - amount))
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
        case .ready: return String(localized: "Ready to restore")
        case .originalOccupied: return String(localized: "Original path occupied")
        case .quarantineMissing: return String(localized: "Quarantine file missing")
        case .contentChanged: return String(localized: "Quarantine content changed")
        case .alreadyRestored: return String(localized: "Already restored")
        case .notQuarantined: return String(localized: "Not eligible")
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
        case .postCommit: return String(localized: "Post-commit")
        case .manualReview: return String(localized: "Manual review")
        case .postRestore: return String(localized: "Post-restore")
        }
    }
}

enum QuarantineVerificationState: String, Codable, Hashable, Sendable {
    case verified
    case reviewRequired

    var label: String {
        switch self {
        case .verified: return String(localized: "Verified against manifest")
        case .reviewRequired: return String(localized: "Review required")
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
        case .current: return String(localized: "Current")
        case .reverifyRequired: return String(localized: "Reverification required")
        case .stale: return String(localized: "Stale")
        case .superseded: return String(localized: "Superseded")
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
