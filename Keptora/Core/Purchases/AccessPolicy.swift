import Foundation
import KeptoraCore

struct AccessPolicy: Equatable, Sendable {
    static let freeReviewLimit = AppStoreConfiguration.freeReviewLimit

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
    case settings

    var id: String { rawValue }

    // Pro removes the 100-item limit on selecting suggestions in bulk; browsing, manual
    // selection, removal and recovery are free. The copy must not promise more than that.
    var titleKey: LocalizedStringKey {
        switch self {
        case .reviewLimit: return "You’ve used the free suggestions"
        case .settings: return "Keptora Pro Lifetime"
        }
    }

    var detailKey: LocalizedStringKey {
        switch self {
        case .reviewLimit:
            return "You selected 100 suggested items for free. Keptora Pro removes this limit. Manual selection, removal and recovery stay free."
        case .settings:
            return "One purchase removes the 100-item limit on selecting suggestions, on your Apple devices with the same Apple Account."
        }
    }

    var title: String {
        switch self {
        case .reviewLimit: return L10n.tr("You’ve used the free suggestions")
        case .settings: return L10n.tr("Keptora Pro Lifetime")
        }
    }

    var detail: String {
        switch self {
        case .reviewLimit:
            return L10n.tr("You selected 100 suggested items for free. Keptora Pro removes this limit. Manual selection, removal and recovery stay free.")
        case .settings:
            return L10n.tr("One purchase removes the 100-item limit on selecting suggestions, on your Apple devices with the same Apple Account.")
        }
    }
}
