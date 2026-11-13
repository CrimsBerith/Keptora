import Combine
import Foundation
import KeptoraCore
import StoreKit
import SwiftUI

@MainActor
final class StoreEntitlementController: ObservableObject {
    enum PaywallHost { case main, settings }
    static let lifetimeProductID = AppStoreConfiguration.defaultLifetimeProductID

    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isLifetimeUnlocked = false
    @Published private(set) var isWorking = false
    @Published private(set) var statusMessage: String?
    @Published var isShowingPaywall = false
    @Published private(set) var paywallHost: PaywallHost = .main
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
            await self?.refreshEntitlement()
            for await result in Transaction.updates {
                guard let self else { return }
                switch result {
                case .verified(let transaction):
                    if transaction.productID == Self.lifetimeProductID {
                        if transaction.revocationDate != nil {
                            self.isLifetimeUnlocked = false
                        } else {
                            self.isLifetimeUnlocked = true
                            self.isShowingPaywall = false
                        }
                    }
                    await transaction.finish()
                    await self.refreshEntitlement()
                case .unverified(let transaction, let error):
                    self.statusMessage = L10n.format("Unverified transaction: %@", error.localizedDescription)
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

    func presentPaywall(_ reason: PaywallReason, host: PaywallHost = .main) {
        paywallHost = host
        paywallReason = reason
        isShowingPaywall = true
    }
    func paywallBinding(for host: PaywallHost) -> Binding<Bool> {
        Binding(get: { self.isShowingPaywall && self.paywallHost == host }, set: { value in
            if self.paywallHost == host { self.isShowingPaywall = value }
        })
    }

    func refresh() async {
        isWorking = true
        defer { isWorking = false }
        statusMessage = nil
        // Entitlements are cached locally by StoreKit, so resolve them first: a paying user
        // must stay unlocked even when the product query fails offline.
        await refreshEntitlement()
        do {
            lifetimeProduct = try await Product.products(for: [Self.lifetimeProductID]).first
            if lifetimeProduct == nil && !isLifetimeUnlocked {
                statusMessage = L10n.tr("Keptora Pro is unavailable right now. Check your internet connection and try again.")
            }
        } catch {
            if !isLifetimeUnlocked {
                statusMessage = L10n.format("Purchases could not be refreshed: %@", error.localizedDescription)
            }
        }
    }

    func purchaseLifetime() async {
        guard !isWorking else { return }
        guard let lifetimeProduct, !isLifetimeUnlocked else { return }
        isWorking = true
        defer { isWorking = false }
        statusMessage = nil
        do {
            switch try await lifetimeProduct.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                if transaction.productID == Self.lifetimeProductID && transaction.revocationDate == nil {
                    isLifetimeUnlocked = true
                    isShowingPaywall = false
                }
                await transaction.finish()
                await refreshEntitlement()
                statusMessage = L10n.tr("Keptora Pro is unlocked on this Apple Account.")
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
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        statusMessage = nil

        // Resolve cached local entitlements first to avoid password modal and allow offline restore
        await refreshEntitlement()
        if isLifetimeUnlocked {
            statusMessage = L10n.tr("Purchase restored.")
            isShowingPaywall = false
            return
        }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            statusMessage = isLifetimeUnlocked
                ? L10n.tr("Purchase restored.")
                : L10n.tr("No lifetime purchase was found for this Apple Account.")
            if isLifetimeUnlocked { isShowingPaywall = false }
        } catch {
            statusMessage = L10n.format("Restore failed: %@", error.localizedDescription)
        }
    }

    private func refreshEntitlement() async {
        var unlocked = false
        var hasRevocation = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.lifetimeProductID else { continue }
            if transaction.revocationDate != nil {
                hasRevocation = true
            } else {
                unlocked = true
            }
        }
        if hasRevocation {
            isLifetimeUnlocked = false
        } else if unlocked {
            isLifetimeUnlocked = true
        }
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
