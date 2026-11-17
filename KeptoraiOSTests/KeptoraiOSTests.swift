import XCTest
import KeptoraCore
import CoreGraphics
import ImageIO
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

    func testPhotosHistoryIsPersistedBeforeDeletionAndMarkedCompletedAfterSuccess() async {
        let key = AppStorageKeys.iOSCleanupHistory
        let previousHistory = UserDefaults.standard.data(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer {
            if let previousHistory {
                UserDefaults.standard.set(previousHistory, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let adapter = FakeMobilePhotosDeletionAdapter()
        let store = MobileKeptoraStore(photosDeletionAdapter: adapter)
        let asset = UniversalMediaAsset(
            id: "synthetic-photo",
            sourceID: LibrarySource.photos.id,
            reference: .photoLibrary(localIdentifier: "synthetic-photo"),
            displayName: "synthetic-photo.jpg",
            mediaKind: .image,
            byteCount: 1_000
        )
        store.replaceAssetsForTesting([asset])

        let succeeded = await store.cleanupLibraryAssetImmediately(asset)

        XCTAssertTrue(succeeded, store.errorMessage ?? "Cleanup returned false without an error.")
        let persistedBeforeDeletion = await adapter.persistedStateObservedBeforeDeletion
        let deletionCallCount = await adapter.deletionCallCount
        XCTAssertEqual(deletionCallCount, 1)
        XCTAssertEqual(persistedBeforeDeletion, .planned)
        XCTAssertEqual(store.history.first?.operationState, .moved)
        let reloadedStore = MobileKeptoraStore(photosDeletionAdapter: adapter)
        XCTAssertEqual(reloadedStore.history.first?.operationState, .moved)
    }

    func testCancelledPhotosConfirmationDoesNotRemainInHistory() async {
        let key = AppStorageKeys.iOSCleanupHistory
        let previousHistory = UserDefaults.standard.data(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer {
            if let previousHistory {
                UserDefaults.standard.set(previousHistory, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let adapter = FakeMobilePhotosDeletionAdapter(error: NSError(domain: "PHPhotosErrorDomain", code: 3072))
        let store = MobileKeptoraStore(photosDeletionAdapter: adapter)
        let asset = UniversalMediaAsset(
            id: "cancelled-synthetic-photo",
            sourceID: LibrarySource.photos.id,
            reference: .photoLibrary(localIdentifier: "cancelled-synthetic-photo"),
            displayName: "cancelled-synthetic-photo.jpg",
            mediaKind: .image
        )
        store.replaceAssetsForTesting([asset])

        let succeeded = await store.cleanupLibraryAssetImmediately(asset)

        XCTAssertFalse(succeeded)
        let deletionCallCount = await adapter.deletionCallCount
        let persistedBeforeCancellation = await adapter.persistedStateObservedBeforeDeletion
        XCTAssertEqual(deletionCallCount, 1)
        XCTAssertEqual(persistedBeforeCancellation, .planned)
        XCTAssertTrue(store.history.isEmpty)
        let persistedHistory = try? JSONDecoder().decode(
            [MobileKeptoraStore.CleanupHistoryEntry].self,
            from: XCTUnwrap(UserDefaults.standard.data(forKey: key))
        )
        XCTAssertEqual(persistedHistory, [])
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
            throw XCTSkip("Grant Photos access before running the real-media integration test.")
        }
        let assets = try await adapter.enumerateAssets()
        guard assets.count >= 5 else {
            throw XCTSkip("Import at least 5 sample test assets into simulator before running real-media integration test.")
        }
        
        let scanner = UniversalExactScanner()
        let outcome = try await scanner.scan(adapter: adapter, allowNetwork: false) { _, _, _ in }
        guard !outcome.groups.isEmpty else {
            throw XCTSkip("Import duplicate sample test assets into simulator before testing exact duplicate grouping.")
        }
        
        for group in outcome.groups {
            XCTAssertFalse(group.keeperID.isEmpty, "Every exact duplicate group must contain a protected keeper.")
            XCTAssertGreaterThanOrEqual(group.assets.count, 2, "Duplicate groups must contain at least 2 assets.")
        }
    }

    func testLocalFolderScanComputesDuplicateResultsFromSimulatorFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for group in 0..<20 {
            let data = try jpeg(seed: group)
            for copy in 0..<2 {
                try data.write(to: root.appendingPathComponent("group-\(group)-copy-\(copy).jpg"))
            }
        }

        let recorder = LocalScanRecorder()
        let coordinator = LibraryAnalysisCoordinator { await recorder.record($0) }
        let startedAt = Date()
        try await coordinator.run(
            adapter: UnifiedLibraryAdapter(adapters: [FolderSourceAdapter(rootURL: root, cleanupAvailable: false)]),
            allowNetwork: false
        )
        let elapsedMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
        let result = await recorder.snapshot()

        XCTAssertTrue(result.finished)
        XCTAssertEqual(result.itemCount, 40)
        XCTAssertEqual(result.exactGroupSizes.count, 20)
        XCTAssertTrue(result.exactGroupSizes.allSatisfy { $0 == 2 })
        print("SIMULATOR_LOCAL_SCAN items=40 exactGroups=20 elapsedMs=\(Int(elapsedMilliseconds))")
    }

    func testMainActorRemainsResponsiveDuringLocalFileScan() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for group in 0..<20 {
            let data = try jpeg(seed: group)
            for copy in 0..<2 {
                try data.write(to: root.appendingPathComponent("group-\(group)-copy-\(copy).jpg"))
            }
        }

        let store = MobileKeptoraStore()
        store.connectLocalFolderForTesting(root)
        store.startScan()
        XCTAssertTrue(store.scanState.isScanning, "Local folder scan should start with the generated JPEG corpus.")

        var mainActorGaps: [Double] = []
        var previousTick = Date()
        let deadline = Date().addingTimeInterval(30)
        while store.scanState.isScanning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(8))
            let now = Date()
            mainActorGaps.append(now.timeIntervalSince(previousTick) * 1_000)
            previousTick = now
        }

        guard !store.scanState.isScanning else {
            store.cancelScan()
            XCTFail("Local scan did not finish within 30 seconds.")
            return
        }

        XCTAssertEqual(store.assets.count, 40)
        XCTAssertEqual(store.exactGroups.count, 20)
        XCTAssertFalse(mainActorGaps.isEmpty)
        let sortedGaps = mainActorGaps.sorted()
        let p95 = sortedGaps[Int(Double(sortedGaps.count - 1) * 0.95)]
        let maximumGap = sortedGaps[sortedGaps.count - 1]
        print("SIMULATOR_SCAN_MAIN_ACTOR samples=\(sortedGaps.count) p95GapMs=\(Int(p95)) maxGapMs=\(Int(maximumGap))")
        XCTAssertLessThanOrEqual(p95, 16.7, "Main-actor scan work should stay within one 60 Hz frame for at least 95% of ticks.")
        XCTAssertLessThanOrEqual(maximumGap, 100, "A local scan must not block the main actor for more than 100 ms.")
    }

    private func jpeg(seed: Int) throws -> Data {
        let width = 320, height = 240
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: CGFloat(seed % 17) / 17, green: CGFloat(seed % 31) / 31, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0.95, alpha: 1))
        context.fillEllipse(in: CGRect(x: seed % 190, y: seed % 110, width: 100, height: 100))

        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func testMobilePurchaseControllerInitialStateAndProductID() {
        let controller = MobilePurchaseController()
        XCTAssertEqual(MobilePurchaseController.productID, AppStoreConfiguration.defaultLifetimeProductID)
        XCTAssertFalse(MobilePurchaseController.productID.isEmpty)
        XCTAssertNil(controller.product)
        XCTAssertFalse(controller.isWorking)
    }
}

private actor FakeMobilePhotosDeletionAdapter: MobilePhotosDeletionAdapter {
    private let error: NSError?
    private(set) var persistedStateObservedBeforeDeletion: RecoveryOperationState?
    private(set) var deletionCallCount = 0

    init(error: NSError? = nil) {
        self.error = error
    }

    func validateReviewedAssets(_ assets: [UniversalMediaAsset]) async throws {}

    func deleteSelectedAssets(
        localIdentifiers: [String],
        intent: PhotosRemovalIntent,
        reviewedAssets: [UniversalMediaAsset]?
    ) async throws {
        deletionCallCount += 1
        let restartedStore = await MobileKeptoraStore(photosDeletionAdapter: self)
        persistedStateObservedBeforeDeletion = await MainActor.run {
            restartedStore.history.first?.operationState
        }
        if let error { throw error }
    }
}

private actor LocalScanRecorder {
    struct Result: Sendable {
        var itemCount = 0
        var exactGroupSizes: [Int] = []
        var finished = false
    }

    private var result = Result()

    func record(_ update: LibraryAnalysisUpdate) {
        switch update {
        case .catalogue(let items, _, _):
            result.itemCount = items.count
        case .exact(let groups, _, _, _), .exactGroups(let groups):
            result.exactGroupSizes = groups.map(\.assets.count)
        case .finished:
            result.finished = true
        default:
            break
        }
    }

    func snapshot() -> Result { result }
}
