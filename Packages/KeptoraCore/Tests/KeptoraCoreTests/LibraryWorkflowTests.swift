import Foundation
import XCTest
@testable import KeptoraCore

final class LibraryWorkflowTests: XCTestCase {
    private func asset(_ id: String, kind: UniversalMediaKind = .image, bytes: Int64? = nil,
                       favorite: Bool = false, context: MediaContext? = nil) -> UniversalMediaAsset {
        UniversalMediaAsset(id: id, sourceID: "test", reference: .photoLibrary(localIdentifier: id),
            displayName: id + ".jpg", mediaKind: kind, byteCount: bytes, isFavorite: favorite, context: context)
    }
    func testManualSelectionIncludesFavoritesAndItemsOutsideDuplicateGroups() {
        let items = [asset("ordinary"), asset("favorite", favorite: true)]
        var selection = LibrarySelection()
        selection.select(items)
        XCTAssertEqual(selection.assets(in: items), items)
        XCTAssertEqual(selection.ids, ["ordinary", "favorite"])
    }
    func testFiltersDoNotDiscardHiddenSelection() {
        let items = [asset("visible"), asset("filtered")]
        var selection = LibrarySelection(); selection.select(items)
        XCTAssertEqual(selection.hiddenCount(in: [items[0]]), 1)
        XCTAssertEqual(selection.assets(in: items).count, 2)
    }
    func testReconcileDropsExternallyRemovedItems() {
        var selection = LibrarySelection(ids: ["one", "removed"])
        selection.reconcile(with: [asset("one"), asset("new")])
        XCTAssertEqual(selection.ids, ["one"])
        selection.toggle("one"); XCTAssertTrue(selection.ids.isEmpty)
    }
    func testSummaryKeepsUnknownSizeSeparateFromKnownBytes() {
        let summary = MediaSelectionSummary([asset("a", bytes: 10), asset("b", kind: .video, favorite: true)])
        XCTAssertEqual(summary.photos, 1); XCTAssertEqual(summary.videos, 1)
        XCTAssertEqual(summary.knownBytes, 10); XCTAssertEqual(summary.unknownSizeCount, 1)
        XCTAssertEqual(summary.personalItems, 1)
    }
    func testAlbumLabelIsExplicitRatherThanFilenameProvenance() {
        XCTAssertTrue(MediaAlbum(id: "wa", title: "WhatsApp Images").isWhatsAppNamed)
        XCTAssertFalse(MediaAlbum(id: "trip", title: "Vacation").isWhatsAppNamed)
        XCTAssertTrue(asset("IMG-WA0001").context?.albums.isEmpty ?? true)
    }
    func testUnreliableCaptureTimeIsNotUsedAsEvidence() {
        let date = Date(timeIntervalSince1970: 100)
        let a = asset("a", context: MediaContext(captureDate: date, captureTimeIsReliable: false))
        let b = asset("b", context: MediaContext(captureDate: date, captureTimeIsReliable: true))
        XCTAssertNil(SimilarityContext(a, b).secondsApart)
    }
    func testContextRanksOnlyVisuallyEligibleCandidates() {
        let context = MediaContext(location: MediaLocation(latitude: 41, longitude: 29),
            captureDate: Date(timeIntervalSince1970: 100), captureTimeIsReliable: true, burstID: "burst")
        let evidence = SimilarityContext(asset("a", context: context), asset("b", context: context))
        XCTAssertEqual(evidence.rankingAdjustment(visualDistance: 0.8, threshold: 0.3), 0)
        XCTAssertGreaterThan(evidence.rankingAdjustment(visualDistance: 0.1, threshold: 0.3), 0)
        XCTAssertEqual(evidence.secondsApart, 0); XCTAssertEqual(evidence.metersApart, 0)
    }
    func testLocationDistanceUsesMetersAndIsSymmetric() {
        let a = MediaLocation(latitude: 0, longitude: 0), b = MediaLocation(latitude: 0, longitude: 1)
        XCTAssertEqual(a.distance(to: b), 111_194.9, accuracy: 1)
        XCTAssertEqual(a.distance(to: b), b.distance(to: a), accuracy: 0.01)
    }
    func testOlderAssetJSONWithoutContextStillDecodes() throws {
        let encoded = try JSONEncoder().encode(asset("legacy"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "context")
        let decoded = try JSONDecoder().decode(UniversalMediaAsset.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.id, "legacy"); XCTAssertNil(decoded.context)
    }
    func testOffsetFreeEXIFDateIsDisplayedAsRecorded() {
        let item = asset("recorded", context: MediaContext(captureDate: Date(timeIntervalSince1970: 100),
            captureTimeIsReliable: false, captureDateText: "2026:10:03 09:45:00"))
        XCTAssertEqual(item.captureDateDescription, "2026:10:03 09:45:00")
    }
    func testAssetCopyPreservesAndCanClearContext() {
        let original = asset("a", context: MediaContext(camera: "Camera"))
        XCTAssertEqual(original.with(byteCount: .some(12)).context, original.context)
        XCTAssertNil(original.with(context: .some(nil)).context)
    }
}
