import StoreKit
import SwiftUI

@MainActor
final class MobilePurchaseController: ObservableObject {
    static let productID = "com.keptora.app.pro.lifetime"

    @Published private(set) var product: Product?
    @Published private(set) var isUnlocked = false
    @Published private(set) var isWorking = false
    @Published var statusMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.refreshEntitlement()
            for await update in Transaction.updates {
                guard let self, case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self.refreshEntitlement()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func refresh() async {
        isWorking = true
        defer { isWorking = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
            await refreshEntitlement()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
            case .pending:
                statusMessage = String(localized: "Purchase is pending approval.")
            case .userCancelled:
                break
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
