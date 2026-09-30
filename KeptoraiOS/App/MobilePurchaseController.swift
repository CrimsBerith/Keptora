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
                    self.statusMessage = String(localized: "Unverified transaction: \(error.localizedDescription)")
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
                statusMessage = String(localized: "StoreKit product unavailable. Check internet connection and try again.")
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
                statusMessage = String(localized: "Keptora Pro is unlocked on this Apple Account.")
            case .success(.unverified(let transaction, let error)):
                statusMessage = String(localized: "Unverified transaction: \(error.localizedDescription)")
                await transaction.finish()
            case .pending:
                statusMessage = String(localized: "Purchase is pending approval.")
            case .userCancelled:
                statusMessage = String(localized: "Purchase cancelled.")
            default:
                statusMessage = String(localized: "The purchase could not be verified.")
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
                ? String(localized: "Purchase restored.")
                : String(localized: "No purchase was found for this Apple Account.")
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
