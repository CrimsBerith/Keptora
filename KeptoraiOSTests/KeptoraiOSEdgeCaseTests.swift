import XCTest
import KeptoraCore
@testable import KeptoraiOS

@MainActor
final class KeptoraiOSEdgeCaseTests: XCTestCase {

    func testLimitedPhotosAccessActionMapping() {
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .limited), .connect)
    }

    func testDeniedPhotosAccessActionMapping() {
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .denied), .showSettingsHelp)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .restricted), .showRestrictedHelp)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .unavailable), .showUnavailableHelp)
    }

    func testKeeperIsNeverSelectedUnderAnyBatchAction() {
        let store = MobileKeptoraStore()
        let keeperAsset = UniversalMediaAsset(
            id: "keeper-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/keeper.jpg")),
            displayName: "keeper.jpg",
            mediaKind: .image,
            byteCount: 5_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            isFavorite: true
        )
        let copyAsset = UniversalMediaAsset(
            id: "copy-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/copy.jpg")),
            displayName: "copy.jpg",
            mediaKind: .image,
            byteCount: 5_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        let group = UniversalExactGroup(
            digest: "sha256-test-digest",
            assets: [keeperAsset, copyAsset],
            keeperID: keeperAsset.id
        )

        // Attempt to select all safe copies
        let selected = store.selectAllSafeCopies(in: group, isUnlocked: true)
        XCTAssertTrue(selected)
        
        // Assert keeper is never selected
        XCTAssertFalse(store.selectedAssetIDs.contains(keeperAsset.id))
        XCTAssertTrue(store.selectedAssetIDs.contains(copyAsset.id))
        
        // Attempt to toggle keeper directly
        let toggledKeeper = store.toggleSelection(keeperAsset, in: group, isUnlocked: true)
        XCTAssertTrue(toggledKeeper)
        XCTAssertFalse(store.selectedAssetIDs.contains(keeperAsset.id))
    }

    func testProtectedAssetWithAdjustmentsOrFavoritesIsExcluded() {
        let store = MobileKeptoraStore()
        let protectedFav = UniversalMediaAsset(
            id: "fav-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/fav.jpg")),
            displayName: "fav.jpg",
            mediaKind: .image,
            byteCount: 1_000_000,
            isFavorite: true
        )
        let protectedEdit = UniversalMediaAsset(
            id: "edit-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/edit.jpg")),
            displayName: "edit.jpg",
            mediaKind: .image,
            byteCount: 1_000_000,
            hasAdjustments: true
        )
        let plainCopy = UniversalMediaAsset(
            id: "plain-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/plain.jpg")),
            displayName: "plain.jpg",
            mediaKind: .image,
            byteCount: 1_000_000
        )
        
        let group = UniversalExactGroup(
            digest: "sha256-mixed",
            assets: [protectedFav, protectedEdit, plainCopy],
            keeperID: protectedFav.id
        )
        
        XCTAssertEqual(group.safeCopies.map(\.id), [plainCopy.id])
        _ = store.selectAllSafeCopies(in: group, isUnlocked: true)
        XCTAssertEqual(store.selectedAssetIDs, [plainCopy.id])
    }

    func testAppLifecycleBackgroundSuspensionAndResume() {
        let store = MobileKeptoraStore()
        store.suspendScanForBackground()
        // Ensure state remains valid and non-crashing on background
        XCTAssertNil(store.errorMessage)
    }
}
