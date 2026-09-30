import XCTest
@testable import KeptoraCore

final class KeptoraCoreTests: XCTestCase {
    func testExactGroupNeverSelectsKeeperOrProtectedAssets() {
        let keeper = asset(id: "keeper")
        let favorite = asset(id: "favorite", favorite: true)
        let copy = asset(id: "copy")
        let group = UniversalExactGroup(digest: "abc", assets: [keeper, favorite, copy], keeperID: keeper.id)
        XCTAssertEqual(group.safeCopies.map(\.id), [copy.id])
    }

    func testPhotosCapabilitiesUseRecentlyDeletedWithoutInAppRestore() {
        XCTAssertEqual(PlatformCapabilities.photos.cleanupMode, .photosRecentlyDeleted)
        XCTAssertFalse(PlatformCapabilities.photos.canRestoreInApp)
        XCTAssertTrue(PlatformCapabilities.photos.similarityReview)
    }

    func testSimilarVideoSelectionKeepsBestAndExcludesProtectedAssets() throws {
        let protected = UniversalMediaAsset(
            id: "favorite-video",
            sourceID: "test",
            reference: .photoLibrary(localIdentifier: "favorite-video"),
            displayName: "favorite.mov",
            mediaKind: .video,
            byteCount: 300,
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 12,
            isFavorite: true
        )
        let reviewCandidate = UniversalMediaAsset(
            id: "candidate-video",
            sourceID: "test",
            reference: .photoLibrary(localIdentifier: "candidate-video"),
            displayName: "candidate.mov",
            mediaKind: .video,
            byteCount: 200,
            pixelWidth: 1280,
            pixelHeight: 720,
            duration: 12
        )
        let group = UniversalSimilarityGroup(
            id: "similar-video:test",
            assets: [reviewCandidate, protected],
            maximumDistance: 0.2,
            mediaKind: .video
        )

        XCTAssertEqual(group.keeperID, protected.id)
        XCTAssertEqual(group.safeCandidates.map(\.id), [reviewCandidate.id])
        XCTAssertEqual(group.selectableBytes, 200)
    }

    func testVisualQualityEngineEvaluatesSharpnessAndBadges() throws {
        let width = 64
        let height = 64
        var pixels = [UInt8](repeating: 128, count: width * height)
        // Draw high contrast edges
        for y in 0..<height {
            for x in 0..<width {
                if (x + y) % 4 == 0 {
                    pixels[y * width + x] = 255
                }
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let image = ctx.makeImage() else {
            XCTFail("Failed to create test CGImage")
            return
        }
        
        let testAsset = UniversalMediaAsset(
            id: "quality-asset-1",
            sourceID: "test",
            reference: .file(URL(fileURLWithPath: "/tmp/sharp.dng")),
            displayName: "sharp.dng",
            mediaKind: .image,
            byteCount: 20_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        
        let report = VisualQualityEngine.evaluateQuality(for: image, asset: testAsset)
        XCTAssertGreaterThan(report.sharpnessScore, 10.0)
        XCTAssertTrue(report.badges.contains(VisualQualityBadge.proRawOriginal))
        XCTAssertTrue(report.badges.contains(VisualQualityBadge.highResolution))
        XCTAssertGreaterThanOrEqual(report.compositeScore, 20.0)
    }

    func testFolderQuarantineRehashesMovesAndRestoresWithoutOverwrite() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeptoraCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("copy.jpg")
        try Data("verified duplicate".utf8).write(to: file)
        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: true)
        let enumerated = try await adapter.enumerateAssets()
        let asset = try XCTUnwrap(enumerated.first)
        let fingerprint = try await adapter.exactFingerprint(for: asset, allowNetwork: false) { _ in }
        let executor = FolderQuarantineExecutor()
        let record = try await executor.quarantine(root: root, selections: [(asset, fingerprint.digest)])

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(record.operations.first).quarantineURL.path))

        let restored = try await executor.restore(record)
        XCTAssertNotNil(restored.restoredAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testFolderRestoreFailsClosedWhenOriginalPathIsOccupied() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeptoraCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("copy.jpg")
        try Data("verified duplicate".utf8).write(to: file)
        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: true)
        let enumerated = try await adapter.enumerateAssets()
        let asset = try XCTUnwrap(enumerated.first)
        let fingerprint = try await adapter.exactFingerprint(for: asset, allowNetwork: false) { _ in }
        let executor = FolderQuarantineExecutor()
        let record = try await executor.quarantine(root: root, selections: [(asset, fingerprint.digest)])
        try Data("new occupant".utf8).write(to: file)

        do {
            _ = try await executor.restore(record)
            XCTFail("Restore must never overwrite an occupied original path.")
        } catch UniversalScanError.cleanupNotPermitted {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(record.operations.first).quarantineURL.path))
        }
    }

    func testResumedScanReusesOnlySameRevisionCheckpointEntries() async throws {
        let first = asset(id: "copy-1")
        let second = asset(id: "copy-2")
        let unique = asset(id: "unique")
        let fingerprinted = UniversalMediaAsset(
            id: first.id,
            sourceID: first.sourceID,
            reference: first.reference,
            displayName: first.displayName,
            mediaKind: first.mediaKind,
            byteCount: 100
        )
        let fingerprint = UniversalExactFingerprint(digest: "same", byteCount: 100)
        let checkpoint = UniversalScanCheckpoint(
            sourceID: "test",
            allowNetwork: false,
            entries: [.init(sourceAsset: first, fingerprintedAsset: fingerprinted, fingerprint: fingerprint)]
        )
        let adapter = CountingSourceAdapter(assets: [first, second, unique])
        let result = try await UniversalExactScanner().scan(
            adapter: adapter,
            allowNetwork: false,
            resuming: checkpoint,
            progress: { _, _, _ in }
        )

        let hashCount = await adapter.hashCount()
        XCTAssertEqual(hashCount, 2)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups.first?.assets.count, 2)
    }

    func testMediaFingerprintDiskCacheStoresAndRetrieves() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_cache_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let cache = MediaFingerprintDiskCache(customCacheURL: tempURL)
        let now = Date()
        let entry = MediaFingerprintDiskCache.CacheEntry(
            assetID: "asset-123",
            digest: "sha256-abc",
            byteCount: 2048,
            sharpnessScore: 0.85
        )
        
        await cache.store(assetID: "asset-123", modificationDate: now, byteCount: 2048, entry: entry)
        await cache.persistToDisk()
        
        let fetched = await cache.get(assetID: "asset-123", modificationDate: now, byteCount: 2048)
        XCTAssertEqual(fetched?.digest, "sha256-abc")
        XCTAssertEqual(fetched?.sharpnessScore, 0.85)
        
        // Non-existent key should return nil
        let missing = await cache.get(assetID: "asset-999", modificationDate: now, byteCount: 2048)
        XCTAssertNil(missing)
    }

    func testBurstSequenceAnalyzerGroupsRapidPhotosAndPicksSharpest() {
        let baseTime = Date()
        let photo1 = UniversalMediaAsset(
            id: "burst-1",
            sourceID: "test",
            reference: .file(URL(fileURLWithPath: "/tmp/b1.jpg")),
            displayName: "b1.jpg",
            mediaKind: .image,
            byteCount: 3_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            creationDate: baseTime
        )
        let photo2 = UniversalMediaAsset(
            id: "burst-2",
            sourceID: "test",
            reference: .file(URL(fileURLWithPath: "/tmp/b2.jpg")),
            displayName: "b2.jpg",
            mediaKind: .image,
            byteCount: 3_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            creationDate: baseTime.addingTimeInterval(0.8),
            isFavorite: true // Favorite bonus makes it keeper
        )
        let photo3 = UniversalMediaAsset(
            id: "burst-3",
            sourceID: "test",
            reference: .file(URL(fileURLWithPath: "/tmp/b3.jpg")),
            displayName: "b3.jpg",
            mediaKind: .image,
            byteCount: 3_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            creationDate: baseTime.addingTimeInterval(1.6)
        )
        let distantPhoto = UniversalMediaAsset(
            id: "distant-1",
            sourceID: "test",
            reference: .file(URL(fileURLWithPath: "/tmp/d1.jpg")),
            displayName: "d1.jpg",
            mediaKind: .image,
            byteCount: 3_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            creationDate: baseTime.addingTimeInterval(300.0) // 5 minutes later
        )
        
        let bursts = BurstSequenceAnalyzer.analyzeBursts(assets: [photo1, photo2, photo3, distantPhoto])
        XCTAssertEqual(bursts.count, 1)
        
        let burst = bursts[0]
        XCTAssertEqual(burst.assets.count, 3)
        XCTAssertEqual(burst.keeperID, photo2.id) // Favorite photo2 must be chosen as keeper
        XCTAssertEqual(burst.removableCopies.map(\.id), [photo1.id, photo3.id])
    }

    func testSmartCategorizationDetectsScreenshotsAndSmartBucket() {
        let width = 64
        let height = 64
        var pixels = [UInt8](repeating: 200, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let image = context.makeImage() else {
            XCTFail("Failed to create image")
            return
        }
        
        let screenshotAsset = UniversalMediaAsset(
            id: "screen-1",
            sourceID: "test",
            reference: .file(URL(fileURLWithPath: "/tmp/Screenshot_2026-09-29.png")),
            displayName: "Screenshot_2026-09-29.png",
            mediaKind: .image,
            byteCount: 50_000,
            pixelWidth: 1170,
            pixelHeight: 2532
        )
        
        let report = SmartCategorizationEngine.analyze(image: image, asset: screenshotAsset)
        XCTAssertEqual(report.primaryCategory, .screenshotsGraphics)
        XCTAssertEqual(report.suggestedBucket, .screenshots)
        XCTAssertTrue(report.isDeclutterCandidate)
    }

    func testEventClusterGroupsChronologicalPhotosAndSelectsHeroCover() {
        let baseTime = Date()
        let photo1 = UniversalMediaAsset(
            id: "p1", sourceID: "test", reference: .file(URL(fileURLWithPath: "/p1.jpg")),
            displayName: "p1.jpg", mediaKind: .image, byteCount: 1000,
            creationDate: baseTime
        )
        let photo2 = UniversalMediaAsset(
            id: "p2", sourceID: "test", reference: .file(URL(fileURLWithPath: "/p2.jpg")),
            displayName: "p2.jpg", mediaKind: .image, byteCount: 2000,
            creationDate: baseTime.addingTimeInterval(1800) // +30 mins
        )
        let distantPhoto = UniversalMediaAsset(
            id: "distant", sourceID: "test", reference: .file(URL(fileURLWithPath: "/p3.jpg")),
            displayName: "p3.jpg", mediaKind: .image, byteCount: 1500,
            creationDate: baseTime.addingTimeInterval(3600 * 24) // +24 hours
        )
        
        let clusters = SmartCategorizationEngine.clusterEvents(
            assets: [photo1, photo2, distantPhoto],
            clusterGapInterval: 3600 * 4
        )
        
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters[0].assetIDs, ["p1", "p2"])
        XCTAssertEqual(clusters[0].totalByteCount, 3000)
        XCTAssertEqual(clusters[1].assetIDs, ["distant"])
    }

    func testHeavyMediaAnalyzerFlagsAccidentalShortVideosAndOversized() {
        let shortVideo = UniversalMediaAsset(
            id: "short-v",
            sourceID: "test",
            reference: .file(URL(fileURLWithPath: "/v1.mov")),
            displayName: "v1.mov",
            mediaKind: .video,
            byteCount: 8_000_000,
            duration: 2.1
        )
        
        let report = HeavyMediaAnalyzer.evaluate(asset: shortVideo, duration: 2.1, byteCount: 8_000_000)
        XCTAssertNotNil(report)
        XCTAssertTrue(report?.reasons.contains(.accidentalShortVideo) ?? false)
    }

    func testMetadataDoctorInfersDateFromStandardFilenamePattern() {
        let filename = "IMG_20240815_142310.jpg"
        let date = MetadataDoctorEngine.inferDateFromFilename(filename)
        XCTAssertNotNil(date)
        
        let cal = Calendar.current
        if let date {
            XCTAssertEqual(cal.component(.year, from: date), 2024)
            XCTAssertEqual(cal.component(.month, from: date), 8)
            XCTAssertEqual(cal.component(.day, from: date), 15)
            XCTAssertEqual(cal.component(.hour, from: date), 14)
            XCTAssertEqual(cal.component(.minute, from: date), 23)
            XCTAssertEqual(cal.component(.second, from: date), 10)
        }
    }

    func testPhysicalArchiveExporterOrganizesByYearAndMonth() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("export")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        
        let testFile = sourceDir.appendingPathComponent("sample.jpg")
        try Data("test image bytes".utf8).write(to: testFile)
        
        let testDate = DateComponents(calendar: .current, year: 2026, month: 5, day: 20).date ?? Date()
        let asset = UniversalMediaAsset(
            id: "exp-1",
            sourceID: "test",
            reference: .file(testFile),
            displayName: "sample.jpg",
            mediaKind: .image,
            byteCount: 16,
            creationDate: testDate
        )
        
        let config = PhysicalExportConfiguration(destinationURL: destDir, structure: .yearAndMonth, transferMode: .copy)
        try await PhysicalArchiveExporter.export(assets: [asset], config: config) { _ in }
        
        let expectedSubdir = destDir.appendingPathComponent("2026").appendingPathComponent("05 - May")
        let exportedFile = expectedSubdir.appendingPathComponent("sample.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedFile.path))
        
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testFolderWatchdogServiceStatusLifecycle() async {
        let service = FolderWatchdogService()
        let initialStatus = await service.status
        if case .stopped = initialStatus {
            XCTAssertTrue(true)
        } else {
            XCTFail("Watchdog should start stopped")
        }
    }

    func testAppStoreConfigurationDefaultsAndFallbacks() {
        XCTAssertEqual(AppStoreConfiguration.fallbackLifetimeProductID, "com.keptora.app.pro.lifetime")
        XCTAssertFalse(AppStoreConfiguration.defaultLifetimeProductID.isEmpty)
        XCTAssertEqual(AppStoreConfiguration.privacyPolicyURL.scheme, "https")
        XCTAssertEqual(AppStoreConfiguration.supportURL.scheme, "https")
        XCTAssertEqual(AppStoreConfiguration.termsOfUseURL.scheme, "https")
        XCTAssertEqual(AppStoreConfiguration.marketingURL.scheme, "https")
        XCTAssertTrue(AppStoreConfiguration.privacyPolicyURL.absoluteString.contains("alfagolab.com"))
        XCTAssertTrue(AppStoreConfiguration.termsOfUseURL.absoluteString.contains("apple.com") || AppStoreConfiguration.termsOfUseURL.absoluteString.contains("alfagolab.com"))
    }

    func testUniversalScanErrorDescriptions() {
        let errUnavailable = UniversalScanError.resourceUnavailable("IMG_0001.HEIC")
        XCTAssertNotNil(errUnavailable.errorDescription)
        XCTAssertTrue(errUnavailable.errorDescription?.contains("IMG_0001.HEIC") == true)

        let errCancelled = UniversalScanError.downloadCancelled("IMG_0002.HEIC")
        XCTAssertNotNil(errCancelled.errorDescription)
        XCTAssertTrue(errCancelled.errorDescription?.contains("IMG_0002.HEIC") == true)
    }

    private func asset(id: String, favorite: Bool = false) -> UniversalMediaAsset {
        UniversalMediaAsset(
            id: id,
            sourceID: "test",
            reference: .photoLibrary(localIdentifier: id),
            displayName: "\(id).jpg",
            mediaKind: .image,
            byteCount: 100,
            isFavorite: favorite
        )
    }
}

private actor CountingSourceAdapter: SourceAdapter {
    nonisolated let source = LibrarySource(id: "test", kind: .folder, displayName: "Test")
    nonisolated let capabilities = PlatformCapabilities(
        exactScan: true,
        similarityReview: true,
        cleanupMode: .folderQuarantine,
        canRestoreInApp: true,
        mayRequireNetworkDownload: false,
        canRevealInFileBrowser: false
    )
    let assets: [UniversalMediaAsset]
    private var calls = 0

    init(assets: [UniversalMediaAsset]) { self.assets = assets }
    func authorizationStatus() async -> SourceAuthorization { .authorized }
    func requestAuthorization() async -> SourceAuthorization { .authorized }
    func enumerateAssets() async throws -> [UniversalMediaAsset] { assets }
    func exactFingerprint(for asset: UniversalMediaAsset, allowNetwork: Bool, progress: @escaping @Sendable (Int64) -> Void) async throws -> UniversalExactFingerprint {
        calls += 1
        return UniversalExactFingerprint(digest: asset.id == "unique" ? "unique" : "same", byteCount: 100)
    }
    func hashCount() -> Int { calls }
}
