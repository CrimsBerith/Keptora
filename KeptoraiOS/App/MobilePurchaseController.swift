import KeptoraCore
import StoreKit
import SwiftUI

@MainActor
final class MobilePurchaseController: ObservableObject {
    static let productID = AppStoreConfiguration.defaultLifetimeProductID

    @Published private(set) var product: Product?
    @Published private(set) var isUnlocked = false
    @Published private(set) var isWorking = false
    @Published private(set) var statusMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.refreshEntitlement()
            for await update in Transaction.updates {
                guard let self else { return }
                switch update {
                case .verified(let transaction):
                    await self.refreshEntitlement()
                    await transaction.finish()
                case .unverified(let transaction, let error):
                    self.statusMessage = L10n.tr("Unverified transaction: \(error.localizedDescription)")
                    await transaction.finish()
                }
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func refresh() async {
        isWorking = true
        defer { isWorking = false }
        statusMessage = nil
        // Resolve cached entitlements first so an offline product query cannot lock out a paying user.
        await refreshEntitlement()
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil {
                statusMessage = L10n.tr("StoreKit product unavailable. Check internet connection and try again.")
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product, !isUnlocked else { return }
        isWorking = true
        defer { isWorking = false }
        statusMessage = nil
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await refreshEntitlement()
                await transaction.finish()
                statusMessage = L10n.tr("Keptora Pro is unlocked on this Apple Account.")
            case .success(.unverified(let transaction, let error)):
                statusMessage = L10n.tr("Unverified transaction: \(error.localizedDescription)")
                await transaction.finish()
            case .pending:
                statusMessage = L10n.tr("Purchase is pending approval.")
            case .userCancelled:
                statusMessage = L10n.tr("Purchase cancelled.")
            default:
                statusMessage = L10n.tr("The purchase could not be verified.")
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        statusMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            statusMessage = isUnlocked
                ? L10n.tr("Purchase restored.")
                : L10n.tr("No purchase was found for this Apple Account.")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            unlocked = true
        }
        isUnlocked = unlocked
    }
}
