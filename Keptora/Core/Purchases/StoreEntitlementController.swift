import Combine
import Foundation
import StoreKit

@MainActor
final class StoreEntitlementController: ObservableObject {
    static let lifetimeProductID = Bundle.main.object(forInfoDictionaryKey: "APP_LIFETIME_PRODUCT_ID") as? String ?? "com.keptora.app.pro.lifetime"

    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isLifetimeUnlocked = false
    @Published private(set) var isWorking = false
    @Published private(set) var statusMessage: String?
    @Published var isShowingPaywall = false
    @Published private(set) var paywallReason: PaywallReason = .settings
    @Published private(set) var reviewedAssetIDs: Set<String>

    private let defaults: UserDefaults
    private let reviewedAssetsKey = "Keptora.Trial.ReviewedAssetIDs.v1"
    private var transactionUpdatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reviewedAssetIDs = Set(defaults.stringArray(forKey: reviewedAssetsKey) ?? [])
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.refreshEntitlement()
            }
        }
    }

    deinit { transactionUpdatesTask?.cancel() }

    var accessPolicy: AccessPolicy {
        AccessPolicy(isLifetimeUnlocked: isLifetimeUnlocked, reviewedAssetIDs: reviewedAssetIDs)
    }

    var requiresProductConfiguration: Bool {
        let trimmedProductID = Self.lifetimeProductID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedProductID.isEmpty || trimmedProductID.contains("yourcompany") || trimmedProductID.contains("example")
    }
    var entitlementLabel: String {
        if isLifetimeUnlocked { return "Unlocked" }
        return lifetimeProduct?.displayPrice ?? "Product configuration required"
    }
    var purchaseButtonLabel: String {
        if isLifetimeUnlocked { return String(localized: "Purchased") }
        return lifetimeProduct.map { String(localized: "Unlock for \($0.displayPrice)") } ?? String(localized: "Lifetime Product Unavailable")
    }
    var trialLabel: String {
        if isLifetimeUnlocked { return "Unlimited reviews" }
        return "\(accessPolicy.freeReviewsRemaining) of \(AccessPolicy.freeReviewLimit) free reviews remaining"
    }

    func canReview(_ assetID: AssetID) -> Bool { accessPolicy.allowsReview(assetID: assetID) }

    func authorizeReview(_ assetID: AssetID) -> Bool {
        guard accessPolicy.allowsReview(assetID: assetID) else {
            presentPaywall(.reviewLimit)
            return false
        }
        return true
    }

    func recordReview(_ assetID: AssetID) {
        recordReviews([assetID])
    }

    func authorizeReviews(_ assetIDs: [AssetID]) -> Bool {
        guard accessPolicy.allowsReviews(assetIDs: assetIDs) else {
            presentPaywall(.reviewLimit)
            return false
        }
        return true
    }

    func recordReviews(_ assetIDs: [AssetID]) {
        guard !isLifetimeUnlocked else { return }
        var changed = false
        for assetID in assetIDs {
            changed = reviewedAssetIDs.insert(assetID.rawValue).inserted || changed
        }
        guard changed else { return }
        defaults.set(Array(reviewedAssetIDs).sorted(), forKey: reviewedAssetsKey)
    }

    func authorizeSafetyPlan(assetIDs: [AssetID]) -> Bool {
        guard accessPolicy.allowsSafetyPlan(assetIDs: assetIDs) else {
            presentPaywall(.safetyPlan)
            return false
        }
        return true
    }

    func presentPaywall(_ reason: PaywallReason) {
        paywallReason = reason
        isShowingPaywall = true
    }

    func refresh() async {
        isWorking = true
        defer { isWorking = false }
        // Entitlements are cached locally by StoreKit, so resolve them first: a paying user
        // must stay unlocked even when the product query fails offline.
        await refreshEntitlement()
        do {
            lifetimeProduct = try await Product.products(for: [Self.lifetimeProductID]).first
            if lifetimeProduct == nil {
                statusMessage = "The StoreKit product was not returned. Verify the product ID, agreements, availability, and StoreKit configuration."
            }
        } catch {
            statusMessage = "StoreKit refresh failed: \(error.localizedDescription)"
        }
    }

    func purchaseLifetime() async {
        guard let lifetimeProduct, !isLifetimeUnlocked else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await lifetimeProduct.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlement()
                statusMessage = "Keptora Pro is unlocked on this Apple Account."
                isShowingPaywall = false
            case .pending:
                statusMessage = "Purchase is pending approval."
            case .userCancelled:
                statusMessage = "Purchase cancelled."
            @unknown default:
                statusMessage = "Purchase returned an unknown state."
            }
        } catch {
            statusMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            statusMessage = isLifetimeUnlocked
                ? "Purchase restored."
                : "No lifetime purchase was found for this Apple Account."
            if isLifetimeUnlocked { isShowingPaywall = false }
        } catch {
            statusMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.lifetimeProductID,
                  transaction.revocationDate == nil else { continue }
            unlocked = true
        }
        isLifetimeUnlocked = unlocked
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.failedVerification
        }
    }

    private enum StoreError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "The App Store transaction could not be verified." }
    }
}
