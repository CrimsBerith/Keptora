import XCTest
import KeptoraCore
@testable import KeptoraiOS

@MainActor
final class KeptoraiOSTests: XCTestCase {
    func testInitialDashboardIsEmpty() {
        let store = MobileKeptoraStore()
        XCTAssertEqual(store.dashboard.scannedItems, 0)
        XCTAssertEqual(store.dashboard.exactGroups, 0)
        XCTAssertTrue(store.selectedAssetIDs.isEmpty)
    }

    func testFreeTierFailsClosedBeforeSelectingMoreThanOneHundredNewReviews() {
        UserDefaults.standard.removeObject(forKey: "Keptora.iOS.ReviewedAssets.v1")
        let store = MobileKeptoraStore()
        let assets = (0..<102).map { index in
            UniversalMediaAsset(
                id: "asset-\(index)",
                sourceID: "test",
                reference: .file(URL(fileURLWithPath: "/tmp/asset-\(index).jpg")),
                displayName: "asset-\(index).jpg",
                mediaKind: .image,
                byteCount: 10
            )
        }
        let group = UniversalExactGroup(digest: "same", assets: assets, keeperID: assets[0].id)

        XCTAssertFalse(store.selectAllSafeCopies(in: group, isUnlocked: false))
        XCTAssertTrue(store.selectedAssetIDs.isEmpty)
        UserDefaults.standard.removeObject(forKey: "Keptora.iOS.ReviewedAssets.v1")
    }

    func testPhotosAuthorizationRoutingNeverRequestsAgainAfterDenial() {
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .notDetermined), .requestSystemPermission)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .authorized), .connect)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .limited), .connect)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .denied), .showSettingsHelp)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .restricted), .showRestrictedHelp)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .unavailable), .showUnavailableHelp)
    }

    func testRootModalRouteReplacesSettingsWithPaywallWithoutStackingSheets() {
        let store = MobileKeptoraStore()

        store.present(.settings)
        XCTAssertEqual(store.modalRoute?.rawValue, MobileModalRoute.settings.rawValue)

        store.present(.paywall)
        XCTAssertEqual(store.modalRoute?.rawValue, MobileModalRoute.paywall.rawValue)

        store.dismissModal()
        XCTAssertNil(store.modalRoute)
    }

    func testRealPhotoLibraryDuplicateScanningOnSimulator() async throws {
        let adapter = PhotoLibrarySourceAdapter()
        let auth = await adapter.authorizationStatus()
        guard auth == .authorized || auth == .limited else {
            print("Photos authorization is not granted on this runner; skipping live scan.")
            return
        }
        let assets = try await adapter.enumerateAssets()
        XCTAssertGreaterThanOrEqual(assets.count, 5, "Simulator should contain the imported sample assets.")
        
        let scanner = UniversalExactScanner()
        let (_, groups, _, _) = try await scanner.scan(adapter: adapter, allowNetwork: false) { _, _, _ in }
        XCTAssertFalse(groups.isEmpty, "Scanner should identify the imported duplicate photo groups.")
        
        for group in groups {
            XCTAssertFalse(group.keeperID.isEmpty, "Every exact duplicate group must contain a protected keeper.")
            XCTAssertGreaterThanOrEqual(group.assets.count, 2, "Duplicate groups must contain at least 2 assets.")
        }
    }
}

