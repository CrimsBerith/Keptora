import Foundation

enum KeeperSelectionPolicy: String, CaseIterable, Identifiable, Sendable {
    case preserve = "preserve"
    case oldest = "oldest"
    case newest = "newest"
    case largest = "largest"
    case shortestPath = "shortestPath"

    static let defaultsKey = "Cullora.KeeperSelectionPolicy"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .preserve: return "Cullora default"
        case .oldest: return "Oldest file"
        case .newest: return "Newest file"
        case .largest: return "Largest file"
        case .shortestPath: return "Shortest path"
        }
    }
    var detail: String {
        switch self {
        case .preserve: return "Keep the current keeper; new groups use the oldest file."
        case .oldest: return "Keep the older copy."
        case .newest: return "Keep the newer copy."
        case .largest: return "Keep the largest file, often the highest-resolution copy."
        case .shortestPath: return "Keep the copy with the shortest file path."
        }
    }
}

enum ReviewDecision: String, Codable, Sendable {
    case keep
    case quarantinePlan
    case skip

    var label: String {
        switch self {
        case .keep: return "Keep"
        case .quarantinePlan: return "Add to Plan"
        case .skip: return "Skip"
        }
    }
}

struct ReviewAsset: Identifiable, Hashable, Codable, Sendable {
    let id: AssetID
    let displayName: String
    let fileURL: URL
    let byteCount: Int64
    let modificationDate: Date?
    let digest: String
    let family: AssetFamilySummary?

    init(
        id: AssetID,
        displayName: String,
        fileURL: URL,
        byteCount: Int64,
        modificationDate: Date?,
        digest: String,
        family: AssetFamilySummary? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.fileURL = fileURL
        self.byteCount = byteCount
        self.modificationDate = modificationDate
        self.digest = digest
        self.family = family
    }
}

struct ReviewGroup: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let kind: String
    let confidence: String
    let digest: String
    let reclaimableBytes: Int64
    let canonicalAssetID: AssetID
    let assets: [ReviewAsset]

    var title: String { "Exact set · \(assets.count) files" }
    var canonicalAsset: ReviewAsset? { assets.first { $0.id == canonicalAssetID } }
}

struct PersistedReviewDecision: Hashable, Sendable {
    let groupID: String
    let assetID: AssetID
    let decision: ReviewDecision
    let actor: String
    let reasonCode: String
    let updatedAt: Date
}

enum ReviewDecisionProofState: String, Codable, Sendable {
    case protectedKeeper
    case verifiedExactPlan
    case reviewedSkip
    case selectedKeeper
    case needsReview

    var label: String {
        switch self {
        case .protectedKeeper: return "Protected keeper"
        case .verifiedExactPlan: return "Verified exact copy"
        case .reviewedSkip: return "Reviewed · not planned"
        case .selectedKeeper: return "User-selected keeper"
        case .needsReview: return "Needs review"
        }
    }

    var systemImage: String {
        switch self {
        case .protectedKeeper: return "lock.shield.fill"
        case .verifiedExactPlan: return "checkmark.seal.fill"
        case .reviewedSkip: return "forward.fill"
        case .selectedKeeper: return "person.crop.circle.badge.checkmark"
        case .needsReview: return "exclamationmark.triangle.fill"
        }
    }
}

struct ReviewDecisionEvidence: Identifiable, Hashable, Codable, Sendable {
    let groupID: String
    let assetID: AssetID
    let decision: ReviewDecision
    let actor: String
    let reasonCode: String
    let decidedAt: Date
    let exactDigest: String
    let canonicalAssetID: AssetID
    let proofState: ReviewDecisionProofState
    let familyID: String?
    let familyKind: String?
    let familyRole: String?

    var id: String { "\(groupID):\(assetID.rawValue)" }
    var isPlanVerified: Bool { proofState == .verifiedExactPlan }

    var reasonLabel: String {
        switch reasonCode {
        case "protected-canonical": return "Protected canonical keeper"
        case "user-selected-keeper": return "Keeper selected by user"
        case "keeper-replaced": return "Previous keeper replaced"
        case "user-added-to-plan": return "Added to Safety Plan by user"
        case "user-skipped": return "Skipped by user"
        case "user-batch-added-exact-extras": return "Batch-added exact extras"
        case "user-batch-skipped-exact-extras": return "Batch-skipped exact extras"
        default: return reasonCode.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}

enum ReviewDecisionEvidenceEngine {
    static func evidence(
        group: ReviewGroup,
        asset: ReviewAsset,
        record: PersistedReviewDecision
    ) -> ReviewDecisionEvidence {
        let exactMatch = asset.digest == group.digest
        let isKeeper = asset.id == group.canonicalAssetID
        let proofState: ReviewDecisionProofState
        if isKeeper && record.decision == .keep {
            proofState = record.actor == "user" ? .selectedKeeper : .protectedKeeper
        } else if record.decision == .quarantinePlan && !isKeeper && exactMatch {
            proofState = .verifiedExactPlan
        } else if record.decision == .skip && exactMatch {
            proofState = .reviewedSkip
        } else {
            proofState = .needsReview
        }

        return ReviewDecisionEvidence(
            groupID: group.id,
            assetID: asset.id,
            decision: record.decision,
            actor: record.actor,
            reasonCode: record.reasonCode,
            decidedAt: record.updatedAt,
            exactDigest: asset.digest,
            canonicalAssetID: group.canonicalAssetID,
            proofState: proofState,
            familyID: asset.family?.id,
            familyKind: asset.family?.kind.rawValue,
            familyRole: asset.family?.role.rawValue
        )
    }
}

struct DatabaseSummary: Hashable, Sendable {
    let indexedAssets: Int
    let activeAssets: Int
    let duplicateGroups: Int
    let duplicateAssets: Int
    let reclaimableBytes: Int64
    let quarantinedAssets: Int

    static let empty = DatabaseSummary(
        indexedAssets: 0,
        activeAssets: 0,
        duplicateGroups: 0,
        duplicateAssets: 0,
        reclaimableBytes: 0,
        quarantinedAssets: 0
    )
}


enum ExactGroupBatchAction: String, Sendable {
    case planSafeExtras
    case skipExtras
}

enum ReviewGroupState: String, CaseIterable, Sendable {
    case unreviewed
    case inProgress
    case planned
    case complete

    var label: String {
        switch self {
        case .unreviewed: return "Unreviewed"
        case .inProgress: return "In progress"
        case .planned: return "Planned"
        case .complete: return "Reviewed"
        }
    }

    var systemImage: String {
        switch self {
        case .unreviewed: return "circle.dashed"
        case .inProgress: return "circle.lefthalf.filled"
        case .planned: return "shippingbox.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

struct ReviewGroupProgress: Hashable, Sendable {
    let totalExtras: Int
    let planned: Int
    let skipped: Int
    let undecided: Int

    var decided: Int { planned + skipped }
    var state: ReviewGroupState {
        if totalExtras == 0 || undecided == 0 { return planned > 0 ? .planned : .complete }
        if decided == 0 { return .unreviewed }
        return .inProgress
    }
}



struct ReviewSessionCheckpoint: Identifiable, Hashable, Codable, Sendable {
    let sourceID: SourceID
    let sourceName: String
    let groupID: String
    let focusedAssetID: AssetID?
    let groupPosition: Int
    let totalGroups: Int
    let reviewedAssets: Int
    let completedGroups: Int
    let plannedBytes: Int64
    let startedAt: Date
    let updatedAt: Date

    var id: String { sourceID.rawValue }

    var progressFraction: Double {
        guard totalGroups > 0 else { return 0 }
        return min(1, max(0, Double(completedGroups) / Double(totalGroups)))
    }

    var elapsed: TimeInterval { max(0, updatedAt.timeIntervalSince(startedAt)) }

    var reviewedPerMinute: Double {
        guard elapsed >= 30 else { return 0 }
        return Double(reviewedAssets) / (elapsed / 60)
    }

    var positionLabel: String {
        guard totalGroups > 0 else { return "No exact groups" }
        return "Group \(min(max(groupPosition, 1), totalGroups)) of \(totalGroups)"
    }
}

struct ReviewInsights: Hashable, Sendable {
    let totalGroups: Int
    let unreviewedGroups: Int
    let inProgressGroups: Int
    let plannedGroups: Int
    let completeGroups: Int
    let totalPotentialBytes: Int64
    let plannedBytes: Int64
    let exactAssets: Int
    let similarGroups: Int
}
