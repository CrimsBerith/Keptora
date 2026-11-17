import CoreGraphics
import ImageIO
import KeptoraCore
import XCTest
@testable import KeptoraiOS

/// Measures the work the library gallery repeats when it redraws, on a 50,000-item library.
@MainActor
final class GalleryPerformanceTests: XCTestCase {
    private static func library(count: Int) -> [UniversalMediaAsset] {
        let root = URL(fileURLWithPath: "/tmp/keptora-performance", isDirectory: true)
        let start = Date(timeIntervalSince1970: 1_600_000_000)
        var assets: [UniversalMediaAsset] = []
        assets.reserveCapacity(count)
        for index in 0..<count {
            let kind: UniversalMediaKind = index % 10 == 0 ? .video : .image
            let name = "IMG_\(index).jpg"
            let date = start.addingTimeInterval(Double(index) * 60)
            assets.append(UniversalMediaAsset(id: "perf-\(index)", sourceID: "perf", reference: .file(root.appendingPathComponent(name)),
                                              displayName: name, mediaKind: kind, byteCount: Int64(1_000_000 + index), creationDate: date))
        }
        return assets
    }

    /// One gallery projection: filter, sort, section, and build review data for 50,000 items.
    func testGalleryProjectionComputationFor50kItems() {
        let assets = Self.library(count: 50_000)
        var criteria = MobileLibraryFilterCriteria()
        criteria.media = 1
        let input = MobileGalleryProjectionInput(
            assets: assets,
            criteria: criteria,
            search: "",
            collectionIDs: nil,
            collectionKind: nil,
            sortBySize: false,
            reviewGroups: [],
            qualityAssessments: [:],
            decisions: LibraryReviewDecisions()
        )
        var visibleCount = 0
        var unusedSectionCount = -1
        var unusedReviewIDCount = -1
        measure(metrics: [XCTClockMetric()]) {
            let projection = MobileGalleryProjectionBuilder.build(input)
            visibleCount = projection?.visible.count ?? 0
            unusedSectionCount = projection?.sections.count ?? -1
            unusedReviewIDCount = projection?.visibleIDs.count ?? -1
        }
        XCTAssertEqual(visibleCount, 45_000)
        XCTAssertEqual(unusedSectionCount, 0)
        XCTAssertEqual(unusedReviewIDCount, 0)
    }

    func testFileBackedSyntheticScanUsesRealDecodeHashAndWarmCache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeJPEGFixture(to: root, groupCount: 10, copiesPerGroup: 10)

        await MediaFingerprintDiskCache.shared.clear()
        let cold = try await scanFolder(root)
        let warm = try await scanFolder(root)

        XCTAssertEqual(cold.itemCount, 100)
        XCTAssertEqual(cold.exactGroupCount, 10)
        XCTAssertEqual(cold.exactMetrics?.hashedOriginals, 100)
        XCTAssertEqual(cold.photoMetrics?.decodedPreviews, 100)
        XCTAssertEqual(warm.itemCount, 100)
        XCTAssertEqual(warm.exactGroupCount, 10)
        XCTAssertEqual(warm.exactMetrics?.hashedOriginals, 0)
        XCTAssertEqual(warm.exactMetrics?.cacheHits, 100)
        XCTAssertEqual(warm.photoMetrics?.decodedPreviews, 0)
        XCTAssertEqual(warm.photoMetrics?.cacheHits, 100)

        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: false)
        let batches = FolderBatchRecorder()
        do {
            _ = try await adapter.enumerateAssets(batchSize: 25, control: nil) { _ in
                await batches.record()
                withUnsafeCurrentTask { $0?.cancel() }
            }
            XCTFail("File enumeration must stop after cancellation")
        } catch is CancellationError {
        }
        let batchCount = await batches.count
        XCTAssertEqual(batchCount, 1)

        print("File-backed scan: 100 JPEGs; cold \(cold.elapsedSeconds)s; warm \(warm.elapsedSeconds)s; exact cache hit \(warm.exactMetrics?.cacheHits ?? -1); preview cache hit \(warm.photoMetrics?.cacheHits ?? -1)")
    }

    func testGalleryProjectionRunsDuringFileBackedScan() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeJPEGFixture(to: root, groupCount: 50, copiesPerGroup: 10)

        await MediaFingerprintDiskCache.shared.clear()
        let galleryAssets = Self.library(count: 50_000)
        let recorder = FileBackedScanRecorder(projectionAssets: galleryAssets)
        let coordinator = LibraryAnalysisCoordinator { await recorder.record($0) }
        try await coordinator.run(
            adapter: UnifiedLibraryAdapter(adapters: [FolderSourceAdapter(rootURL: root, cleanupAvailable: false)]),
            allowNetwork: false,
            configuration: LibraryConfiguration(similarityEnabled: false)
        )

        let pass = await recorder.result()
        XCTAssertEqual(pass.itemCount, 500)
        XCTAssertGreaterThan(pass.projectionRunsDuringPhotoAnalysis, 0)
        XCTAssertEqual(pass.projectedVisibleCount, 45_000)
        XCTAssertGreaterThan(pass.projectionSeconds, 0)
        print("Concurrent file-backed scan: \(pass.itemCount) JPEGs; 50K gallery projection \(pass.projectionSeconds)s during photo analysis; \(pass.projectedVisibleCount) visible")
    }

    func testOfflineSwipePrefetchCanWarmVisibleThumbnailCache() {
        let asset = Self.library(count: 1)[0]
        let prefetched = MobileAssetThumbnail(asset: asset, pixelSize: 1200, contentMode: .fit, allowNetwork: false)
        let visible = MobileAssetThumbnail(asset: asset, pixelSize: 1200, contentMode: .fit, allowNetwork: true)

        XCTAssertEqual(prefetched.cacheKey, visible.cacheKey)
    }

    func testGalleryProjectionFiltersSortsAndGroupsOffscreenAssets() throws {
        var criteria = MobileLibraryFilterCriteria()
        criteria.media = 1
        criteria.oldestFirst = true
        criteria.finding = .copies
        let assets = Self.library(count: 20)
        let groups = LibraryReviewGroup.combined(
            exact: [.init(digest: "copies", assets: [assets[1], assets[2], assets[10]], keeperID: "perf-1")],
            similar: [],
            bursts: []
        )
        let input = MobileGalleryProjectionInput(
            assets: assets,
            criteria: criteria,
            search: "",
            collectionIDs: ["perf-1", "perf-2", "perf-10"],
            collectionKind: nil,
            sortBySize: false,
            reviewGroups: groups,
            qualityAssessments: [:],
            decisions: LibraryReviewDecisions()
        )

        let projection = try XCTUnwrap(MobileGalleryProjectionBuilder.build(input))

        XCTAssertEqual(projection.visible.map(\.id), ["perf-2", "perf-1"])
        XCTAssertEqual(projection.sections.count, 1)
        XCTAssertEqual(Set(projection.review.orderedAssets.map(\.id)), ["perf-1", "perf-2"])
    }

    func testGallerySectionsPreserveNoncontiguousMonthOrder() throws {
        let calendar = Calendar.current
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31, hour: 12)))
        let february = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: january))
        let assets = [january, february, january].enumerated().map { index, date in
            UniversalMediaAsset(
                id: "section-\(index)",
                sourceID: "perf",
                reference: .file(URL(fileURLWithPath: "/tmp/section-\(index).jpg")),
                displayName: "section-\(index).jpg",
                mediaKind: .image,
                creationDate: date
            )
        }
        var criteria = MobileLibraryFilterCriteria()
        criteria.smartOrder = false
        let input = MobileGalleryProjectionInput(
            assets: assets,
            criteria: criteria,
            search: "",
            collectionIDs: nil,
            collectionKind: nil,
            sortBySize: false,
            reviewGroups: [],
            qualityAssessments: [:],
            decisions: LibraryReviewDecisions()
        )

        let projection = try XCTUnwrap(MobileGalleryProjectionBuilder.build(input))
        XCTAssertEqual(projection.sections.map(\.assets).map { $0.map(\.id) }, [["section-0"], ["section-1"], ["section-2"]])
        XCTAssertEqual(projection.sections.map(\.date), [
            calendar.dateInterval(of: .month, for: january)?.start,
            calendar.dateInterval(of: .month, for: february)?.start,
            calendar.dateInterval(of: .month, for: january)?.start
        ])
    }

    func testRepeatedDateGroupsHaveStableUniqueIdentity() throws {
        let calendar = Calendar.current
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31, hour: 12)))
        let february = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: january))
        let assets = [january, february, january].enumerated().map { index, date in
            UniversalMediaAsset(
                id: "identity-\(index)",
                sourceID: "perf",
                reference: .file(URL(fileURLWithPath: "identity-\(index).jpg")),
                displayName: "identity-\(index).jpg",
                mediaKind: .image,
                creationDate: date
            )
        }
        var criteria = MobileLibraryFilterCriteria()
        criteria.smartOrder = false
        let input = MobileGalleryProjectionInput(
            assets: assets,
            criteria: criteria,
            search: "",
            collectionIDs: nil,
            collectionKind: nil,
            sortBySize: false,
            reviewGroups: [],
            qualityAssessments: [:],
            decisions: LibraryReviewDecisions()
        )

        let first = try XCTUnwrap(MobileGalleryProjectionBuilder.build(input))
        let second = try XCTUnwrap(MobileGalleryProjectionBuilder.build(input))
        let firstBlocks = MobileGalleryBlock.dateSections(first.sections)
        let secondBlocks = MobileGalleryBlock.dateSections(second.sections)

        XCTAssertEqual(first.sections.map(\.assets).flatMap { $0.map(\.id) }, assets.map(\.id))
        XCTAssertEqual(Set(first.sections.map(\.id)).count, first.sections.count)
        XCTAssertEqual(first.sections.map(\.id), second.sections.map(\.id))
        XCTAssertEqual(Set(firstBlocks.map(\.id)).count, firstBlocks.count)
        XCTAssertEqual(firstBlocks.map(\.id), secondBlocks.map(\.id))
        XCTAssertEqual(firstBlocks.flatMap(\.entries).map(\.asset.id), assets.map(\.id))
    }

    func testGalleryProjectionStopsWhenWorkerIsCancelled() async {
        let input = MobileGalleryProjectionInput(
            assets: Self.library(count: 2_000),
            criteria: MobileLibraryFilterCriteria(),
            search: "",
            collectionIDs: nil,
            collectionKind: nil,
            sortBySize: false,
            reviewGroups: [],
            qualityAssessments: [:],
            decisions: LibraryReviewDecisions()
        )
        let result = await Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            return MobileGalleryProjectionBuilder.build(input)
        }.value

        XCTAssertNil(result)
    }

    private func scanFolder(_ root: URL) async throws -> FileBackedScanPass {
        let recorder = FileBackedScanRecorder()
        let coordinator = LibraryAnalysisCoordinator { await recorder.record($0) }
        try await coordinator.run(
            adapter: UnifiedLibraryAdapter(adapters: [FolderSourceAdapter(rootURL: root, cleanupAvailable: false)]),
            allowNetwork: false,
            configuration: LibraryConfiguration(similarityEnabled: false)
        )
        return await recorder.result()
    }

    private func writeJPEGFixture(to root: URL, groupCount: Int, copiesPerGroup: Int) throws {
        for group in 0..<groupCount {
            let data = try jpeg(seed: group)
            for copy in 0..<copiesPerGroup {
                try data.write(to: root.appendingPathComponent("g\(group)-\(copy).jpg"))
            }
        }
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
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

private struct FileBackedScanPass: Sendable {
    var itemCount = 0
    var exactGroupCount = 0
    var exactMetrics: AnalysisWorkMetrics?
    var photoMetrics: AnalysisWorkMetrics?
    var elapsedSeconds: TimeInterval = 0
    var projectionRunsDuringPhotoAnalysis = 0
    var projectedVisibleCount = 0
    var projectionSeconds: TimeInterval = 0
}

private actor FileBackedScanRecorder {
    private let started = Date()
    private let projectionAssets: [UniversalMediaAsset]
    private var pass = FileBackedScanPass()

    init(projectionAssets: [UniversalMediaAsset] = []) {
        self.projectionAssets = projectionAssets
    }

    func record(_ event: LibraryAnalysisUpdate) async {
        switch event {
        case .catalogue(let assets, _, _):
            pass.itemCount = assets.count
        case .progress(.photos, let progress)
            where progress.status == .running && !projectionAssets.isEmpty && pass.projectionRunsDuringPhotoAnalysis == 0:
            let assets = projectionAssets
            let projectionResult = await MainActor.run {
                let started = Date()
                var criteria = MobileLibraryFilterCriteria()
                criteria.media = 1
                let input = MobileGalleryProjectionInput(
                    assets: assets,
                    criteria: criteria,
                    search: "",
                    collectionIDs: nil,
                    collectionKind: nil,
                    sortBySize: false,
                    reviewGroups: [],
                    qualityAssessments: [:],
                    decisions: LibraryReviewDecisions()
                )
                let visibleCount = MobileGalleryProjectionBuilder.build(input)?.visible.count ?? 0
                return (visibleCount, Date().timeIntervalSince(started))
            }
            recordProjection(visibleCount: projectionResult.0, seconds: projectionResult.1)
        case .exactGroups(let groups):
            pass.exactGroupCount = groups.count
        case .metrics(let stage, let metrics):
            if stage == .exact { pass.exactMetrics = metrics }
            if stage == .photos { pass.photoMetrics = metrics }
        case .finished:
            pass.elapsedSeconds = Date().timeIntervalSince(started)
        default:
            break
        }
    }

    func result() -> FileBackedScanPass { pass }

    private func recordProjection(visibleCount: Int, seconds: TimeInterval) {
        pass.projectionRunsDuringPhotoAnalysis += 1
        pass.projectedVisibleCount = visibleCount
        pass.projectionSeconds = seconds
    }
}

private actor FolderBatchRecorder {
    private(set) var count = 0
    func record() { count += 1 }
}
