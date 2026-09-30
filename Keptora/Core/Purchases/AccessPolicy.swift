import Foundation
import KeptoraCore

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

import SwiftUI

enum PaywallReason: String, Identifiable, Sendable {
    case reviewLimit
    case safetyPlan
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .reviewLimit: return "Your free review is complete"
        case .safetyPlan: return "Unlock unlimited Safety Plans"
        case .settings: return "Keptora Pro Lifetime"
        }
    }

    var detailKey: LocalizedStringKey {
        switch self {
        case .reviewLimit:
            return "You reviewed 100 unique recommendations. Unlock Keptora Pro to keep reviewing without limits."
        case .safetyPlan:
            return "This plan contains recommendations outside the free 100-review allowance. Pro keeps every future plan unlimited and reversible."
        case .settings:
            return "One purchase unlocks unlimited review decisions and Safety Plans on your supported Apple devices using the purchasing Apple Account."
        }
    }

    var title: String {
        switch self {
        case .reviewLimit: return L10n.tr("Your free review is complete")
        case .safetyPlan: return L10n.tr("Unlock unlimited Safety Plans")
        case .settings: return L10n.tr("Keptora Pro Lifetime")
        }
    }

    var detail: String {
        switch self {
        case .reviewLimit:
            return L10n.tr("You reviewed 100 unique recommendations. Unlock Keptora Pro to keep reviewing without limits.")
        case .safetyPlan:
            return L10n.tr("This plan contains recommendations outside the free 100-review allowance. Pro keeps every future plan unlimited and reversible.")
        case .settings:
            return L10n.tr("One purchase unlocks unlimited review decisions and Safety Plans on your supported Apple devices using the purchasing Apple Account.")
        }
    }
}
