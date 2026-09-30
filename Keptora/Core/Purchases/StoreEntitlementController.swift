import Combine
import Foundation
import KeptoraCore
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
    private var reservedAssetIDs: Set<String> = []

    private let defaults: UserDefaults
    private let reviewedAssetsKey = "Keptora.Trial.ReviewedAssetIDs.v1"
    private var transactionUpdatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reviewedAssetIDs = Set(defaults.stringArray(forKey: reviewedAssetsKey) ?? [])
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.refreshEntitlement()
                case .unverified(let transaction, let error):
                    self.statusMessage = String(localized: "Unverified transaction: \(error.localizedDescription)")
                    await transaction.finish()
                }
            }
        }
    }

    deinit { transactionUpdatesTask?.cancel() }

    var accessPolicy: AccessPolicy {
        AccessPolicy(isLifetimeUnlocked: isLifetimeUnlocked, reviewedAssetIDs: reviewedAssetIDs.union(reservedAssetIDs))
    }

    var requiresProductConfiguration: Bool {
        let trimmedProductID = Self.lifetimeProductID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedProductID.isEmpty || trimmedProductID.contains("yourcompany") || trimmedProductID.contains("example")
    }
    var entitlementLabel: String {
        if isLifetimeUnlocked { return L10n.tr("Unlocked") }
        return lifetimeProduct?.displayPrice ?? L10n.tr("Product configuration required")
    }
    var purchaseButtonLabel: String {
        if isLifetimeUnlocked { return L10n.tr("Purchased") }
        return lifetimeProduct.map { L10n.format("Unlock for %@", $0.displayPrice) } ?? L10n.tr("Lifetime Product Unavailable")
    }
    var trialLabel: String {
        if isLifetimeUnlocked { return L10n.tr("Unlimited reviews") }
        return L10n.format("%1$lld of %2$lld free reviews remaining", Int64(accessPolicy.freeReviewsRemaining), Int64(AccessPolicy.freeReviewLimit))
    }

    func canReview(_ assetID: AssetID) -> Bool { accessPolicy.allowsReview(assetID: assetID) }

    func authorizeReview(_ assetID: AssetID) -> Bool {
        guard accessPolicy.allowsReview(assetID: assetID) else {
            presentPaywall(.reviewLimit)
            return false
        }
        reservedAssetIDs.insert(assetID.rawValue)
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
        for id in assetIDs {
            reservedAssetIDs.insert(id.rawValue)
        }
        return true
    }

    func recordReviews(_ assetIDs: [AssetID]) {
        for id in assetIDs {
            reservedAssetIDs.remove(id.rawValue)
        }
        guard !isLifetimeUnlocked else { return }
        var changed = false
        for assetID in assetIDs {
            changed = reviewedAssetIDs.insert(assetID.rawValue).inserted || changed
        }
        guard changed else { return }
        defaults.set(Array(reviewedAssetIDs).sorted(), forKey: reviewedAssetsKey)
    }

    func releaseReservedReviews(_ assetIDs: [AssetID]) {
        for id in assetIDs {
            reservedAssetIDs.remove(id.rawValue)
        }
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
                statusMessage = L10n.tr("The StoreKit product was not returned. Verify the product ID, agreements, availability, and StoreKit configuration.")
            }
        } catch {
            statusMessage = L10n.format("StoreKit refresh failed: %@", error.localizedDescription)
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
                statusMessage = L10n.tr("Keptora Pro is unlocked on this Apple Account.")
                isShowingPaywall = false
            case .pending:
                statusMessage = L10n.tr("Purchase is pending approval.")
            case .userCancelled:
                statusMessage = L10n.tr("Purchase cancelled.")
            @unknown default:
                statusMessage = L10n.tr("Purchase returned an unknown state.")
            }
        } catch {
            statusMessage = L10n.format("Purchase failed: %@", error.localizedDescription)
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
        var errorDescription: String? { L10n.tr("The App Store transaction could not be verified.") }
    }
}
