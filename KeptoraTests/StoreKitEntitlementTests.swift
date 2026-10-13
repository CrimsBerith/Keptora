import StoreKit
import StoreKitTest
import XCTest
import KeptoraCore
@testable import Keptora

@MainActor
final class StoreKitEntitlementTests: XCTestCase {
    private var session: SKTestSession!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        // A signed sandboxed host can read its test resources; #filePath points
        // outside the app's container and is not a portable test configuration.
        let storekitURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Keptora", withExtension: "storekit"),
                                       "StoreKit configuration must be bundled with KeptoraTests")

        session = try SKTestSession(contentsOf: storekitURL)
        cleanSessionTransactions()

        defaultsSuiteName = "Keptora.Tests.StoreKit.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
    }

    override func tearDown() async throws {
        cleanSessionTransactions()
        session = nil
        if let suite = defaultsSuiteName {
            defaults?.removePersistentDomain(forName: suite)
        }
        defaults = nil
        try await super.tearDown()
    }

    private func cleanSessionTransactions() {
        guard let session else { return }
        session.disableDialogs = true
        session.clearTransactions()
        for transaction in session.allTransactions() {
            try? session.deleteTransaction(identifier: transaction.identifier)
        }
    }

    func testProductLoadingAndConfiguration() async {
        let controller = StoreEntitlementController(defaults: defaults)
        XCTAssertFalse(controller.isLifetimeUnlocked)
        XCTAssertNil(controller.lifetimeProduct)

        await controller.refresh()

        XCTAssertNotNil(controller.lifetimeProduct)
        XCTAssertEqual(controller.lifetimeProduct?.id, AppStoreConfiguration.defaultLifetimeProductID)
        XCTAssertFalse(controller.isLifetimeUnlocked)
        XCTAssertFalse(controller.purchaseButtonLabel.isEmpty)
        XCTAssertFalse(controller.trialLabel.isEmpty)
    }

    func testSuccessfulPurchaseUnlocksLifetimeAccess() async throws {
        let controller = StoreEntitlementController(defaults: defaults)
        await controller.refresh()
        XCTAssertNotNil(controller.lifetimeProduct)
        XCTAssertFalse(controller.isLifetimeUnlocked)

        // Simulate successful purchase via StoreKit test session
        _ = try session.buyProduct(productIdentifier: AppStoreConfiguration.defaultLifetimeProductID)
        try await AppStore.sync()
        await controller.refresh()

        XCTAssertTrue(controller.isLifetimeUnlocked)
        XCTAssertTrue(controller.accessPolicy.isLifetimeUnlocked)
        XCTAssertEqual(controller.entitlementLabel, L10n.tr("Unlocked"))
        XCTAssertEqual(controller.purchaseButtonLabel, L10n.tr("Purchased"))
        XCTAssertEqual(controller.trialLabel, L10n.tr("Unlimited reviews"))
    }

    func testRestorePurchasesWhenTransactionExists() async throws {
        let controller = StoreEntitlementController(defaults: defaults)
        XCTAssertFalse(controller.isLifetimeUnlocked)

        // Buy product directly through StoreKit Test session
        _ = try session.buyProduct(productIdentifier: AppStoreConfiguration.defaultLifetimeProductID)

        await controller.restorePurchases()

        XCTAssertTrue(controller.isLifetimeUnlocked)
        XCTAssertTrue(controller.accessPolicy.isLifetimeUnlocked)
    }

    func testRestorePurchasesWhenNoTransactionExists() async {
        let controller = StoreEntitlementController(defaults: defaults)
        XCTAssertFalse(controller.isLifetimeUnlocked)

        await controller.restorePurchases()

        XCTAssertFalse(controller.isLifetimeUnlocked)
        XCTAssertNotNil(controller.statusMessage)
    }

    func testCachedEntitlementPersistsAcrossRefreshes() async throws {
        _ = try session.buyProduct(productIdentifier: AppStoreConfiguration.defaultLifetimeProductID)

        let controller = StoreEntitlementController(defaults: defaults)
        await controller.refresh()
        XCTAssertTrue(controller.isLifetimeUnlocked)
        XCTAssertTrue(controller.accessPolicy.isLifetimeUnlocked)

        // Refresh again; entitlement must remain unlocked
        await controller.refresh()
        XCTAssertTrue(controller.isLifetimeUnlocked)
        XCTAssertTrue(controller.accessPolicy.isLifetimeUnlocked)
    }

    func testRetryRefreshClearsPriorStatusMessage() async {
        let controller = StoreEntitlementController(defaults: defaults)
        // Trigger restore with no purchase so statusMessage is populated
        await controller.restorePurchases()
        XCTAssertNotNil(controller.statusMessage)

        // Retry refresh clears the error state
        await controller.refresh()
        XCTAssertNil(controller.statusMessage)
    }
}
