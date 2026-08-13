import Foundation



enum SimilaritySensitivityPreset: String, Codable, CaseIterable, Sendable, Identifiable {
    case precisionFirst
    case balanced
    case discovery

    var id: String { rawValue }
    var label: String {
        switch self {
        case .precisionFirst: return "Precision first"
        case .balanced: return "Balanced"
        case .discovery: return "Discovery"
        }
    }
    var detail: String {
        switch self {
        case .precisionFirst: return "Shows fewer sets and minimizes visual false positives. Recommended for release builds."
        case .balanced: return "A moderate review set. Similar photos remain review-only and are never added to cleanup automatically."
        case .discovery: return "Uses the calibrated profile without widening it. Best for deliberate manual review."
        }
    }
    fileprivate var thresholdMultiplier: Float {
        switch self {
        case .precisionFirst: return 0.78
        case .balanced: return 0.90
        case .discovery: return 1.00
        }
    }
    static let defaultsKey = "Cullora.SimilaritySensitivity.v1"
    static func stored(defaults: UserDefaults = .standard) -> Self {
        guard let raw = defaults.string(forKey: defaultsKey), let value = Self(rawValue: raw) else { return .precisionFirst }
        return value
    }
}


enum SimilarityTier: String, Codable, CaseIterable, Sendable {
    case veryStrong
    case strong
    case review

    var label: String {
        switch self {
        case .veryStrong: return "Very strong"
        case .strong: return "Strong"
        case .review: return "Possible"
        }
    }

    var systemImage: String {
        switch self {
        case .veryStrong: return "sparkles.rectangle.stack.fill"
        case .strong: return "rectangle.stack.fill"
        case .review: return "questionmark.square.dashed"
        }
    }
}

struct SimilarityCalibrationProfile: Codable, Hashable, Sendable {
    let id: String
    let visionRevision: Int
    let cropScale: String
    let veryStrongMaximum: Float
    let strongMaximum: Float
    let reviewMaximum: Float
    let storageMaximum: Float
    let positiveSampleCount: Int
    let negativeSampleCount: Int
    let generatedAt: Date
    let isCalibrated: Bool

    func tier(for distance: Float) -> SimilarityTier? {
        guard distance.isFinite, distance >= 0 else { return nil }
        if distance <= veryStrongMaximum { return .veryStrong }
        if distance <= strongMaximum { return .strong }
        if distance <= reviewMaximum { return .review }
        return nil
    }

    func applying(_ preset: SimilaritySensitivityPreset) -> SimilarityCalibrationProfile {
        let multiplier = preset.thresholdMultiplier
        let adjustedVeryStrong = max(0.01, veryStrongMaximum * multiplier)
        let adjustedStrong = max(adjustedVeryStrong, strongMaximum * multiplier)
        let adjustedReview = max(adjustedStrong, reviewMaximum * multiplier)
        return SimilarityCalibrationProfile(
            id: "\(id)-\(preset.rawValue)",
            visionRevision: visionRevision,
            cropScale: cropScale,
            veryStrongMaximum: adjustedVeryStrong,
            strongMaximum: adjustedStrong,
            reviewMaximum: adjustedReview,
            storageMaximum: storageMaximum,
            positiveSampleCount: positiveSampleCount,
            negativeSampleCount: negativeSampleCount,
            generatedAt: generatedAt,
            isCalibrated: isCalibrated
        )
    }

    static func conservativeBootstrap(visionRevision: Int) -> SimilarityCalibrationProfile {
        SimilarityCalibrationProfile(
            id: "bootstrap-v1-r\(visionRevision)",
            visionRevision: visionRevision,
            cropScale: "scaleFit",
            veryStrongMaximum: 0.18,
            strongMaximum: 0.28,
            reviewMaximum: 0.40,
            storageMaximum: 0.55,
            positiveSampleCount: 0,
            negativeSampleCount: 0,
            generatedAt: Date(timeIntervalSince1970: 0),
            isCalibrated: false
        )
    }
}

struct LabeledSimilaritySample: Hashable, Sendable {
    let distance: Float
    let isSimilar: Bool
}

struct SimilarityAssetInput: Hashable, Sendable {
    let assetID: AssetID
    let sourceID: SourceID
    let fileURL: URL
    let displayName: String
    let byteCount: Int64
    let modificationDate: Date?
    let exactDigest: String
    let family: AssetFamilySummary?
}

struct PerceptualFeaturePayload: Hashable, Sendable {
    let featureArchive: Data
    let perceptualHash: UInt64
    let pixelWidth: Int
    let pixelHeight: Int
    let visionRevision: Int
    let cropScale: String
}

struct StoredPerceptualFeature: Hashable, Sendable {
    let assetID: AssetID
    let sourceID: SourceID
    let contentDigest: String
    let featureArchive: Data
    let perceptualHash: UInt64
    let pixelWidth: Int
    let pixelHeight: Int
    let visionRevision: Int
    let cropScale: String
    let pairingRevision: Int
}

struct SimilarityPairRecord: Hashable, Sendable {
    let sourceID: SourceID
    let firstAssetID: AssetID
    let secondAssetID: AssetID
    let distance: Float
    let tier: SimilarityTier?
    let profileID: String
    let evaluatedAt: Date

    init(
        sourceID: SourceID,
        firstAssetID: AssetID,
        secondAssetID: AssetID,
        distance: Float,
        tier: SimilarityTier?,
        profileID: String,
        evaluatedAt: Date = Date()
    ) {
        self.sourceID = sourceID
        if firstAssetID.rawValue <= secondAssetID.rawValue {
            self.firstAssetID = firstAssetID
            self.secondAssetID = secondAssetID
        } else {
            self.firstAssetID = secondAssetID
            self.secondAssetID = firstAssetID
        }
        self.distance = distance
        self.tier = tier
        self.profileID = profileID
        self.evaluatedAt = evaluatedAt
    }
}

struct SimilarityReviewMember: Identifiable, Hashable, Sendable {
    let asset: ReviewAsset
    let distanceToAnchor: Float
    var id: AssetID { asset.id }
}

struct SimilarityReviewGroup: Identifiable, Hashable, Sendable {
    let id: String
    let anchorAssetID: AssetID
    let tier: SimilarityTier
    let maximumDistance: Float
    let profileID: String
    let isCalibrated: Bool
    let members: [SimilarityReviewMember]

    var title: String { "Similar set · \(members.count) photos" }
    var anchor: SimilarityReviewMember? { members.first { $0.asset.id == anchorAssetID } }

    // Similarity is advisory evidence, never authorization for cleanup.
    var allowsCleanup: Bool { false }
}

enum SimilarityPhase: String, Codable, Sendable {
    case idle
    case indexing
    case comparing
    case grouping
    case completed
    case cancelled
    case failed
}

struct SimilarityProgress: Hashable, Sendable {
    let phase: SimilarityPhase
    let processed: Int
    let total: Int
    let indexed: Int
    let reused: Int
    let failed: Int
    let comparedPairs: Int
    let currentItem: String?
    let message: String

    static let idle = SimilarityProgress(
        phase: .idle, processed: 0, total: 0, indexed: 0, reused: 0, failed: 0,
        comparedPairs: 0, currentItem: nil, message: "Similarity analysis has not started"
    )

    var isRunning: Bool { phase == .indexing || phase == .comparing || phase == .grouping }

    var label: String {
        switch phase {
        case .idle: return "Ready"
        case .indexing: return "Building on-device visual index"
        case .comparing: return "Ranking candidate pairs"
        case .grouping: return "Building review-only groups"
        case .completed: return "Similarity analysis completed"
        case .cancelled: return "Similarity analysis cancelled"
        case .failed: return "Similarity analysis failed"
        }
    }
}

struct SimilarityOutcome: Hashable, Sendable {
    let groups: [SimilarityReviewGroup]
    let discoveredImages: Int
    let indexed: Int
    let reused: Int
    let failed: Int
    let comparedPairs: Int
    let storedPairs: Int
}
