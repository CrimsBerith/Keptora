import Foundation

struct AccessPolicy: Equatable, Sendable {
    static let freeReviewLimit = 100

    let isLifetimeUnlocked: Bool
    let reviewedAssetIDs: Set<String>

    var freeReviewsUsed: Int { min(reviewedAssetIDs.count, Self.freeReviewLimit) }
    var freeReviewsRemaining: Int { max(0, Self.freeReviewLimit - freeReviewsUsed) }

    func allowsReview(assetID: AssetID) -> Bool {
        isLifetimeUnlocked || reviewedAssetIDs.contains(assetID.rawValue) || freeReviewsRemaining > 0
    }

    func newReviewCount(assetIDs: [AssetID]) -> Int {
        Set(assetIDs.map(\.rawValue)).subtracting(reviewedAssetIDs).count
    }

    func allowsReviews(assetIDs: [AssetID]) -> Bool {
        isLifetimeUnlocked || newReviewCount(assetIDs: assetIDs) <= freeReviewsRemaining
    }

    func allowsSafetyPlan(assetIDs: [AssetID]) -> Bool {
        isLifetimeUnlocked || assetIDs.allSatisfy { reviewedAssetIDs.contains($0.rawValue) }
    }
}

enum PaywallReason: String, Identifiable, Sendable {
    case reviewLimit
    case safetyPlan
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reviewLimit: return String(localized: "Your free review is complete")
        case .safetyPlan: return String(localized: "Unlock unlimited Safety Plans")
        case .settings: return String(localized: "Keptora Pro Lifetime")
        }
    }

    var detail: String {
        switch self {
        case .reviewLimit:
            return String(localized: "You reviewed 100 unique recommendations. Unlock Keptora Pro to keep reviewing without limits.")
        case .safetyPlan:
            return String(localized: "This plan contains recommendations outside the free 100-review allowance. Pro keeps every future plan unlimited and reversible.")
        case .settings:
            return String(localized: "One purchase unlocks unlimited review decisions and Safety Plans on your supported Apple devices using the purchasing Apple Account.")
        }
    }
}
