import Foundation
import XCTest
@testable import KeptoraCore

final class AutonomousTenMediaWorkflowTests: XCTestCase {

    private func makePhoto(
        _ id: String,
        bytes: Int64? = 3_500_000,
        width: Int = 4032,
        height: Int = 3024,
        isFavorite: Bool = false,
        hasAlbum: Bool = false,
        burstID: String? = nil,
        timestamp: TimeInterval = 1_700_000_000,
        fileURL: URL? = nil
    ) -> UniversalMediaAsset {
        let url = fileURL ?? URL(fileURLWithPath: "/fixtures/photos/\(id).jpg")
        let date = Date(timeIntervalSince1970: timestamp)
        let context = burstID.map { MediaContext(captureDate: date, captureTimeIsReliable: true, burstID: $0) }
        return UniversalMediaAsset(
            id: id,
            sourceID: "fixture-source",
            reference: .file(url),
            displayName: "\(id).jpg",
            mediaKind: .image,
            byteCount: bytes,
            pixelWidth: width,
            pixelHeight: height,
            creationDate: date,
            modificationDate: date,
            isFavorite: isFavorite,
            hasAlbumMembership: hasAlbum,
            context: context,
            fileRevision: .init(physicalIdentity: id, changeToken: "rev-1")
        )
    }

    private func makeVideo(
        _ id: String,
        bytes: Int64? = 20_000_000,
        width: Int = 1920,
        height: Int = 1080,
        duration: TimeInterval = 15.0,
        isFavorite: Bool = false,
        hasAlbum: Bool = false,
        fileURL: URL? = nil
    ) -> UniversalMediaAsset {
        let url = fileURL ?? URL(fileURLWithPath: "/fixtures/videos/\(id).mp4")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return UniversalMediaAsset(
            id: id,
            sourceID: "fixture-source",
            reference: .file(url),
            displayName: "\(id).mp4",
            mediaKind: .video,
            byteCount: bytes,
            pixelWidth: width,
            pixelHeight: height,
            duration: duration,
            creationDate: date,
            modificationDate: date,
            isFavorite: isFavorite,
            hasAlbumMembership: hasAlbum,
            fileRevision: .init(physicalIdentity: id, changeToken: "rev-1")
        )
    }

    // 10 Photos Corpus
    private func buildTenPhotos() -> [UniversalMediaAsset] {
        [
            makePhoto("P1_Original", bytes: 3_500_000, width: 4032, height: 3024, timestamp: 1_700_000_000),
            makePhoto("P2_ExactCopy", bytes: 3_500_000, width: 4032, height: 3024, timestamp: 1_700_010_000),
            makePhoto("P3_AlbumCopy", bytes: 3_500_000, width: 4032, height: 3024, hasAlbum: true, timestamp: 1_700_020_000),
            makePhoto("P4_FavoriteCopy", bytes: 3_500_000, width: 4032, height: 3024, isFavorite: true, timestamp: 1_700_030_000),
            makePhoto("P5_BurstTake1", bytes: 2_800_000, width: 4032, height: 3024, burstID: "burst-alpha", timestamp: 1_700_040_000),
            makePhoto("P6_BurstTake2", bytes: 2_810_000, width: 4032, height: 3024, burstID: "burst-alpha", timestamp: 1_700_040_001),
            makePhoto("P7_LowRes", bytes: 50_000, width: 320, height: 240, timestamp: 1_700_050_000),
            makePhoto("P8_Dark", bytes: 800_000, width: 1920, height: 1080, timestamp: 1_700_060_000),
            makePhoto("P9_Bright", bytes: 850_000, width: 1920, height: 1080, timestamp: 1_700_070_000),
            makePhoto("P10_UniqueLandscape", bytes: 14_000_000, width: 6000, height: 4000, timestamp: 1_700_080_000)
        ]
    }

    // 10 Videos Corpus
    private func buildTenVideos() -> [UniversalMediaAsset] {
        [
            makeVideo("V1_Original", bytes: 20_000_000, width: 1920, height: 1080, duration: 15.0),
            makeVideo("V2_ExactCopy", bytes: 20_000_000, width: 1920, height: 1080, duration: 15.0),
            makeVideo("V3_AlbumMember", bytes: 85_000_000, width: 3840, height: 2160, duration: 30.0, hasAlbum: true),
            makeVideo("V4_Favorite", bytes: 85_000_000, width: 3840, height: 2160, duration: 30.0, isFavorite: true),
            makeVideo("V5_ClipTakeA", bytes: 12_000_000, width: 1920, height: 1080, duration: 10.0),
            makeVideo("V6_ClipTakeB", bytes: 12_200_000, width: 1920, height: 1080, duration: 10.2),
            makeVideo("V7_SlowMo", bytes: 120_000_000, width: 1920, height: 1080, duration: 60.0),
            makeVideo("V8_ShortReel", bytes: 6_000_000, width: 1080, height: 1920, duration: 5.0),
            makeVideo("V9_Drone4K", bytes: 250_000_000, width: 4096, height: 2160, duration: 45.0),
            makeVideo("V10_ArchiveClip", bytes: 18_000_000, width: 1280, height: 720, duration: 25.0)
        ]
    }

    private struct FixtureMockSource: SourceAdapter {
        let source: LibrarySource
        var items: [UniversalMediaAsset]
        var capabilities: PlatformCapabilities { .photos }
        var fingerprints: [String: UniversalExactFingerprint] = [:]

        func authorizationStatus() async -> SourceAuthorization { .authorized }
        func requestAuthorization() async -> SourceAuthorization { .authorized }
        func enumerationWarnings() async -> [String] { [] }
        func enumerateAssets() async throws -> [UniversalMediaAsset] { items }
        func exactFingerprint(
            for asset: UniversalMediaAsset,
            allowNetwork: Bool,
            progress: @escaping @Sendable (Int64) -> Void
        ) async throws -> UniversalExactFingerprint {
            fingerprints[asset.id] ?? UniversalExactFingerprint(digest: "hash-\(asset.id)", byteCount: asset.byteCount ?? 0)
        }
    }

    /// 1. Autonomous candidate pre-filtering: singletons with unique signatures are pruned without full SHA-256
    func testCandidatePreFilteringPrunesSingletonsAutonomously() async throws {
        let photos = buildTenPhotos()
        let videos = buildTenVideos()
        let all20 = photos + videos

        var customFingerprints: [String: UniversalExactFingerprint] = [:]
        // Exact copy cluster 1 (P1, P2, P3, P4 share exact content hash)
        for p in ["P1_Original", "P2_ExactCopy", "P3_AlbumCopy", "P4_FavoriteCopy"] {
            customFingerprints[p] = UniversalExactFingerprint(digest: "sha256-exact-photos-batch", byteCount: 3_500_000)
        }
        // Exact copy cluster 2 (V1, V2 share exact content hash)
        for v in ["V1_Original", "V2_ExactCopy"] {
            customFingerprints[v] = UniversalExactFingerprint(digest: "sha256-exact-videos-batch", byteCount: 20_000_000)
        }

        let mock = FixtureMockSource(
            source: LibrarySource(id: "source-fixtures", kind: .folder, displayName: "Fixtures"),
            items: all20,
            fingerprints: customFingerprints
        )

        let scanner = UniversalExactScanner()
        let result = try await scanner.scan(
            adapter: mock,
            allowNetwork: false,
            fingerprintAllAssets: false,
            progress: { _, _, _ in }
        )

        // Exactly 2 duplicate groups must be formed:
        // Group 1: 4 photos (P1, P2, P3, P4)
        // Group 2: 2 videos (V1, V2)
        XCTAssertEqual(result.groups.count, 2)

        let photoGroup = try XCTUnwrap(result.groups.first(where: { $0.digest == "sha256-exact-photos-batch" }))
        XCTAssertEqual(Set(photoGroup.assets.map(\.id)), ["P1_Original", "P2_ExactCopy", "P3_AlbumCopy", "P4_FavoriteCopy"])

        let videoGroup = try XCTUnwrap(result.groups.first(where: { $0.digest == "sha256-exact-videos-batch" }))
        XCTAssertEqual(Set(videoGroup.assets.map(\.id)), ["V1_Original", "V2_ExactCopy"])

        // Distinct dimension singletons (e.g. P10, V7, V8, V9, V10) must be pruned as "unique:"
        XCTAssertTrue(result.fingerprintsByAssetID["P10_UniqueLandscape"]?.digest.hasPrefix("unique:") == true)
        XCTAssertTrue(result.fingerprintsByAssetID["V9_Drone4K"]?.digest.hasPrefix("unique:") == true)
        XCTAssertTrue(result.fingerprintsByAssetID["V8_ShortReel"]?.digest.hasPrefix("unique:") == true)

        // Hashed originals must only include candidates, not all 20 assets!
        let metrics = await scanner.metrics
        XCTAssertLessThan(metrics.hashedOriginals, 20)
    }

    /// 2. Suggested copies vs manual selection intent routing with ordinary album copy and favorite copy
    func testSuggestedCopiesVsManualIntentRoutingWithOrdinaryAlbumAndFavorite() {
        let photos = buildTenPhotos()
        let photoGroup = UniversalExactGroup(
            digest: "sha256-exact-photos-batch",
            assets: [photos[0], photos[1], photos[2], photos[3]], // P1, P2, P3 (album), P4 (favorite)
            keeperID: photos[0].id
        )

        // safeCopies includes non-keeper assets that are NOT protected
        let safe = photoGroup.safeCopies
        let safeIDs = Set(safe.map(\.id))

        // P2 (ordinary copy) and P3 (ordinary album copy) CAN be suggested!
        XCTAssertTrue(safeIDs.contains("P2_ExactCopy"))
        XCTAssertTrue(safeIDs.contains("P3_AlbumCopy"), "Invariant #2: Ordinary album membership must not block suggested copy cleanup")

        // P4 (favorite) must NOT be suggested!
        XCTAssertFalse(safeIDs.contains("P4_FavoriteCopy"), "Favorites must always be protected from suggested cleanup")

        // Intent resolution:
        // When snapshot only has safe copies -> intent is .suggestedCopies
        let safeSnapshot = safe
        let isSafeIntent = !safeSnapshot.contains(where: \.isProtectedFromGlobalSelection)
        XCTAssertTrue(isSafeIntent)

        // When snapshot contains favorite P4 -> must be treated as .manualSelection
        let manualSnapshot = [photos[3]]
        let isManualIntent = manualSnapshot.contains(where: \.isProtectedFromGlobalSelection)
        XCTAssertTrue(isManualIntent)
    }

    /// 3. Disk cache key stability across mutable metadata changes (byteCount discovery, favorite toggle, album toggle)
    func testDiskCacheKeyStabilityAcrossMetadataDiscoveryAndToggles() async {
        let original = makePhoto("P1_Original", bytes: nil, isFavorite: false, hasAlbum: false)
        let discovered = original.with(byteCount: .some(3_500_000))
        let favorited = discovered.with(isFavorite: true)
        let inAlbum = favorited.with(hasAlbumMembership: true)

        let algo = MediaAnalysisVersion.exact
        let k1 = MediaRevisionPolicy.fingerprintKey(for: original, algorithm: algo)
        let k2 = MediaRevisionPolicy.fingerprintKey(for: discovered, algorithm: algo)
        let k3 = MediaRevisionPolicy.fingerprintKey(for: favorited, algorithm: algo)
        let k4 = MediaRevisionPolicy.fingerprintKey(for: inAlbum, algorithm: algo)

        XCTAssertNotNil(k1)
        XCTAssertEqual(k1, k2, "Discovering byteCount must not invalidate fingerprint cache key")
        XCTAssertEqual(k2, k3, "Toggling favorite must not invalidate fingerprint cache key")
        XCTAssertEqual(k3, k4, "Toggling album membership must not invalidate fingerprint cache key")

        // Test with disk cache actor
        let cache = MediaFingerprintDiskCache(customCacheURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        let entry = MediaFingerprintDiskCache.CacheEntry(assetID: original.id, digest: "sha256-payload", byteCount: 3_500_000)
        await cache.store(asset: original, algorithm: algo, entry: entry)

        // Retrieve with the favorited + in-album + byteCount-discovered asset
        let retrieved = await cache.get(asset: inAlbum, algorithm: algo)
        XCTAssertNotNil(retrieved, "Cache hit must succeed across mutable metadata changes")
        XCTAssertEqual(retrieved?.digest, "sha256-payload")
    }

    /// 4. Autonomous Review Decisions: keeper selection, user override, and badge keys
    func testAutonomousReviewDecisionsAndBadges() {
        let photos = buildTenPhotos()
        let reviewGroup = LibraryReviewGroup(
            id: "review-group-1",
            kind: .exact,
            assets: [photos[0], photos[1], photos[2]], // P1, P2, P3
            keeperID: photos[0].id
        )

        var decisions = LibraryReviewDecisions()
        XCTAssertEqual(decisions.keeper(in: reviewGroup), "P1_Original")
        XCTAssertFalse(decisions.hasUserKeeper(in: reviewGroup))

        // Badge keys
        var badges = decisions.keeperBadgeKeys(in: [reviewGroup])
        XCTAssertEqual(badges["P1_Original"], "Suggested Keep")

        // User chooses P2 as keeper
        decisions.keep("P2_ExactCopy", in: reviewGroup)
        XCTAssertEqual(decisions.keeper(in: reviewGroup), "P2_ExactCopy")
        XCTAssertTrue(decisions.hasUserKeeper(in: reviewGroup))

        badges = decisions.keeperBadgeKeys(in: [reviewGroup])
        XCTAssertEqual(badges["P2_ExactCopy"], "Your Keep Choice")
    }

    /// 5. Quarantine & restore lifecycle with actual photo and video files
    func testQuarantineAndRestoreLifecycle() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let photoFile = root.appendingPathComponent("SamplePhoto.jpg")
        let videoFile = root.appendingPathComponent("SampleVideo.mp4")

        let photoData = Data("sample photo content bytes 12345".utf8)
        let videoData = Data("sample video content bytes 67890".utf8)

        try photoData.write(to: photoFile)
        try videoData.write(to: videoFile)

        let photoValues = try photoFile.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey])
        let videoValues = try videoFile.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey])

        let photoAsset = UniversalMediaAsset(
            id: "SamplePhoto",
            sourceID: "fixture-folder",
            reference: .file(photoFile),
            displayName: "SamplePhoto.jpg",
            mediaKind: .image,
            byteCount: photoValues.fileSize.map(Int64.init),
            pixelWidth: 100,
            pixelHeight: 100,
            creationDate: photoValues.creationDate,
            modificationDate: photoValues.contentModificationDate,
            fileRevision: LibraryFileRevision.capture(at: photoFile)
        )
        let videoAsset = UniversalMediaAsset(
            id: "SampleVideo",
            sourceID: "fixture-folder",
            reference: .file(videoFile),
            displayName: "SampleVideo.mp4",
            mediaKind: .video,
            byteCount: videoValues.fileSize.map(Int64.init),
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 5.0,
            creationDate: videoValues.creationDate,
            modificationDate: videoValues.contentModificationDate,
            fileRevision: LibraryFileRevision.capture(at: videoFile)
        )

        let photoDigest = try await StreamingSHA256.file(at: photoFile, progress: { _ in }).digest
        let videoDigest = try await StreamingSHA256.file(at: videoFile, progress: { _ in }).digest

        let executor = FolderQuarantineExecutor()
        let preflightOk = await executor.preflight(root: root)
        XCTAssertTrue(preflightOk)

        let selections: [(asset: UniversalMediaAsset, expectedDigest: String)] = [
            (photoAsset, photoDigest),
            (videoAsset, videoDigest)
        ]

        // 1. Quarantine
        let record = try await executor.quarantine(root: root, selections: selections, allowPartialFamilies: true)
        XCTAssertEqual(record.operations.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: videoFile.path))

        for op in record.operations {
            XCTAssertEqual(op.state, .moved)
            XCTAssertTrue(FileManager.default.fileExists(atPath: op.quarantineURL.path))
        }

        // 2. Restore
        let restoredRecord = try await executor.restore(record)
        XCTAssertNotNil(restoredRecord.restoredAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: videoFile.path))

        XCTAssertEqual(try Data(contentsOf: photoFile), photoData)
        XCTAssertEqual(try Data(contentsOf: videoFile), videoData)
    }

    /// 6. Filter & Category Button Scopes (All 20 items, Photos 10, Videos 10, Quality hints)
    func testFilterAndCategoryButtonsScope() {
        let photos = buildTenPhotos()
        let videos = buildTenVideos()
        let all20 = photos + videos

        XCTAssertEqual(photos.count, 10)
        XCTAssertEqual(videos.count, 10)
        XCTAssertEqual(all20.count, 20)

        // Summary counts
        let summary = MediaSelectionSummary(all20)
        XCTAssertEqual(summary.photos, 10)
        XCTAssertEqual(summary.videos, 10)
        XCTAssertEqual(summary.personalItems, 2) // P4 (favorite) and V4 (favorite)

        // Bursts detection
        let bursts = BurstSequenceAnalyzer.analyzeBursts(assets: all20)
        XCTAssertEqual(bursts.count, 1)
        XCTAssertEqual(bursts[0].assets.count, 2)
        XCTAssertEqual(Set(bursts[0].assets.map(\.id)), ["P5_BurstTake1", "P6_BurstTake2"])

        // Quality assessments
        let p7 = photos[6] // Low res (320x240)
        let evalLowRes = QualityAssessment.evaluate(
            luma: Array(repeating: 128, count: 128 * 128),
            width: 128,
            height: 128,
            originalWidth: p7.pixelWidth,
            originalHeight: p7.pixelHeight
        )
        XCTAssertTrue(evalLowRes.findings.contains(.lowResolution))

        // Dark photo
        let evalDark = QualityAssessment.evaluate(
            luma: Array(repeating: 5, count: 128 * 128),
            width: 128,
            height: 128,
            originalWidth: 1920,
            originalHeight: 1080
        )
        XCTAssertTrue(evalDark.findings.contains(.dark))

        // Bright photo
        let evalBright = QualityAssessment.evaluate(
            luma: Array(repeating: 250, count: 128 * 128),
            width: 128,
            height: 128,
            originalWidth: 1920,
            originalHeight: 1080
        )
        XCTAssertTrue(evalBright.findings.contains(.bright))
    }
}
