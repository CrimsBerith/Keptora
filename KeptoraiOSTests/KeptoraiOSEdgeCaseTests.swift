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

    func testIsAnalyzingAndCancelScanStateFlow() {
        let store = MobileKeptoraStore()
        XCTAssertFalse(store.isAnalyzing)

        store.similarityProgress = (processed: 5, total: 10)
        XCTAssertTrue(store.isAnalyzing)

        store.cancelScan()
        XCTAssertFalse(store.isAnalyzing)
        XCTAssertEqual(store.scanState, .idle)
        XCTAssertNil(store.similarityProgress)
        XCTAssertNil(store.videoSimilarityProgress)

        store.videoSimilarityProgress = (processed: 2, total: 4)
        XCTAssertTrue(store.isAnalyzing)

        store.cancelScan()
        XCTAssertFalse(store.isAnalyzing)
        XCTAssertNil(store.videoSimilarityProgress)
    }

    func testSuspendScanForBackgroundWhenScanningTransitionsToPaused() {
        let store = MobileKeptoraStore()
        store.scanState = .scanning(processed: 50, total: 100, current: "img.jpg")
        store.suspendScanForBackground()
        XCTAssertEqual(store.scanState, .paused)
        XCTAssertTrue(store.suspendedForBackground)

        store.cancelScan()
        XCTAssertEqual(store.scanState, .idle)
    }

    func testClearSelectionResetsSelectedAssets() {
        let store = MobileKeptoraStore()
        store.selectedAssetIDs = ["asset-1", "asset-2"]
        store.selectedSimilarVideoAssetIDs = ["vid-1"]

        store.clearExactSelection()
        XCTAssertTrue(store.selectedAssetIDs.isEmpty)

        store.clearSimilarVideoSelection()
        XCTAssertTrue(store.selectedSimilarVideoAssetIDs.isEmpty)
    }
}
