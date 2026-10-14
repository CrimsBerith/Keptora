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

    /// One gallery redraw: scope, filter, sort and group the visible items.
    func testVisibleListComputationFor50kItems() {
        let store = MobileKeptoraStore()
        store.replaceAssetsForTesting(Self.library(count: 50_000))
        measure(metrics: [XCTClockMetric()]) {
            let visible = store.scopedAssets
                .filter { $0.mediaKind == .image && store.collectionContains($0) }
                .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            _ = LibraryReviewBlock.make(assets: visible, groups: store.reviewGroups, quality: store.qualityAssessments, smart: true)
        }
    }
}
