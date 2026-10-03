import Foundation
import XCTest
@testable import KeptoraCore

final class LibraryWorkflowTests: XCTestCase {
    func testStartupSetupFollowsIntroductionAndCompletesIndependentlyOfPermission() {
        XCTAssertFalse(LibraryAccessPolicy.needsStartupSetup(introductionCompleted: false, setupCompleted: false))
        XCTAssertTrue(LibraryAccessPolicy.needsStartupSetup(introductionCompleted: true, setupCompleted: false))
        XCTAssertFalse(LibraryAccessPolicy.needsStartupSetup(introductionCompleted: true, setupCompleted: true))
        XCTAssertFalse(LibraryAccessPolicy.needsStartupSetup(introductionCompleted: false, setupCompleted: true))
    }
    func testStartupNeverRepeatsDeniedRestrictedOrLimitedPhotosPrompts() {
        XCTAssertTrue(LibraryAccessPolicy.shouldRequestPhotosAtStartup(.notDetermined))
        for authorization: SourceAuthorization in [.denied, .restricted, .limited, .authorized, .unavailable] {
            XCTAssertFalse(LibraryAccessPolicy.shouldRequestPhotosAtStartup(authorization), authorization.rawValue)
        }
    }
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

    func testUnifiedEnumerationKeepsCrossSourceCopiesButDeduplicatesOverlappingPathsAndAlbums() async throws {
        let photos = LibrarySource.photos
        let folder = LibrarySource(id: "folder", kind: .folder, displayName: "Downloads")
        let overlap = LibrarySource(id: "overlap", kind: .folder, displayName: "Nested")
        let a = asset("photo").with(sourceID: photos.id)
        let b = asset("file").with(sourceID: folder.id, reference: .file(URL(fileURLWithPath: "/library/photo.jpg")))
        let alias = asset("alias").with(sourceID: overlap.id, reference: .file(URL(fileURLWithPath: "/library/nested/../photo.jpg")))
        let duplicateView = asset("album-view").with(sourceID: photos.id, reference: a.reference)
        let adapter = UnifiedLibraryAdapter(adapters: [WorkflowSource(source: photos, items: [a, duplicateView]),
            WorkflowSource(source: folder, items: [b]), WorkflowSource(source: overlap, items: [alias])])
        let result = try await adapter.enumerateAssets()
        XCTAssertEqual(result.map(\.id), [a.id, b.id])
        let reports = await adapter.coverage
        XCTAssertEqual(reports.count, 3)
    }

    func testUnifiedEnumerationSurvivesDeniedAndFailedSourcesWithoutClaimingCoverage() async throws {
        let allowed = LibrarySource(id: "allowed", kind: .folder, displayName: "Available")
        let denied = LibrarySource(id: "denied", kind: .fileProvider, displayName: "Cloud")
        let failed = LibrarySource(id: "failed", kind: .externalVolume, displayName: "Offline Drive")
        let adapter = UnifiedLibraryAdapter(adapters: [WorkflowSource(source: allowed, items: [asset("a").with(sourceID: allowed.id)]),
            WorkflowSource(source: denied, status: .denied), WorkflowSource(source: failed, fails: true)])
        let items = try await adapter.enumerateAssets()
        let reports = await adapter.coverage
        XCTAssertEqual(items.count, 1)
        XCTAssertNil(reports[0].error); XCTAssertEqual(reports[1].authorization, .denied)
        XCTAssertNotNil(reports[1].error); XCTAssertNotNil(reports[2].error)
        XCTAssertEqual(reports[2].itemCount, 0)
    }

    func testLimitedAndPartiallyReadableSourcesKeepItemsAndExposeLimits() async throws {
        let adapter = UnifiedLibraryAdapter(adapters: [WorkflowSource(source: .photos, items: [asset("allowed")], status: .limited),
            WorkflowSource(source: LibrarySource(id: "partial", kind: .folder, displayName: "Partial"), items: [asset("readable")], warnings: ["One subfolder is unreadable"])])
        let items = try await adapter.enumerateAssets()
        let reports = await adapter.coverage
        XCTAssertEqual(items.count, 2); XCTAssertEqual(reports[0].authorization, .limited)
        XCTAssertEqual(reports[1].itemCount, 1); XCTAssertNotNil(reports[1].error)
    }

    func testUnifiedFingerprintRoutesByOwnershipAndRejectsUnknownSource() async throws {
        let source = LibrarySource(id: "file", kind: .folder, displayName: "Files")
        let adapter = UnifiedLibraryAdapter(adapters: [WorkflowSource(source: .photos, fingerprint: .init(digest: "photos", byteCount: 10)),
            WorkflowSource(source: source, fingerprint: .init(digest: "file", byteCount: 20))])
        let photoHash = try await adapter.exactFingerprint(for: asset("p").with(sourceID: LibrarySource.photos.id), allowNetwork: false, progress: { _ in })
        let fileHash = try await adapter.exactFingerprint(for: asset("f").with(sourceID: source.id), allowNetwork: false, progress: { _ in })
        XCTAssertEqual(photoHash.digest, "photos"); XCTAssertEqual(fileHash.digest, "file")
        do { _ = try await adapter.exactFingerprint(for: asset("unknown"), allowNetwork: false, progress: { _ in }); XCTFail("Unknown owner must not route to Photos") }
        catch UnifiedLibraryError.sourceUnavailable { }
    }

    func testUnifiedSourceIdentityIsOrderIndependentAndChangesWhenScopeChanges() {
        let photos = WorkflowSource(source: .photos)
        let file = WorkflowSource(source: LibrarySource(id: "file", kind: .folder, displayName: "Files"))
        XCTAssertEqual(UnifiedLibraryAdapter(adapters: [photos, file]).source.id, UnifiedLibraryAdapter(adapters: [file, photos]).source.id)
        XCTAssertNotEqual(UnifiedLibraryAdapter(adapters: [photos]).source.id, UnifiedLibraryAdapter(adapters: [photos, file]).source.id)
    }

    func testSourceBadgesUseAlbumMembershipAndConnectedFolderInsteadOfFilenameGuessing() {
        let fakeName = asset("WhatsApp-IMG-001")
        XCTAssertFalse(fakeName.sourceLabel(in: []).contains("WhatsApp"))
        let saved = fakeName.with(context: MediaContext(albums: [.init(id: "assigned", title: "Saved")]))
        XCTAssertTrue(saved.sourceLabel(in: [], whatsAppAlbumIDs: ["assigned"]).contains("WhatsApp"))
        let file = fakeName.with(sourceID: "folder", reference: .file(URL(fileURLWithPath: "/Downloads/Trip/photo.jpg")))
        XCTAssertTrue(file.sourceLabel(in: [.init(id: "folder", kind: .folder, displayName: "Downloads")]).contains("Downloads"))
    }

    func testCombinedReviewKeepsSimilarRelationsAcrossExactGroupsAndHidesRedundantExactOnlyGroups() {
        let a = asset("a"), b = asset("b"), c = asset("c")
        let exact = UniversalExactGroup(digest: "same", assets: [a, b])
        let redundant = UniversalSimilarityGroup(id: "redundant", assets: [a, b], maximumDistance: 0)
        let similar = UniversalSimilarityGroup(id: "different", assets: [a, c], maximumDistance: 0.2)
        let groups = LibraryReviewGroup.combined(exact: [exact], similar: [redundant, similar])
        XCTAssertEqual(groups.map(\.id), [exact.id, similar.id])
        XCTAssertEqual(groups[1].assets.count, 2)
    }

    func testUnifiedEnumerationPropagatesCancellationInsteadOfReportingEmptySuccess() async throws {
        let adapter = UnifiedLibraryAdapter(adapters: [WorkflowSource(source: .photos, cancels: true)])
        do { _ = try await adapter.enumerateAssets(); XCTFail("Cancellation must propagate") }
        catch is CancellationError { }
    }

    func testManualFileRemovalRejectsChangedContentRevision() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("reviewed".utf8).write(to: file)
        let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let item = asset("selected", bytes: Int64(try XCTUnwrap(values.fileSize))).with(reference: .file(file), modificationDate: .some(values.contentModificationDate))
        XCTAssertNoThrow(try LibraryRevisionValidator.validate([item]))
        try Data("new content after review".utf8).write(to: file)
        XCTAssertThrowsError(try LibraryRevisionValidator.validate([item]))
    }

    #if canImport(CryptoKit)
    func testUnknownPhotoSizeDoesNotExcludeAnExactFileCopy() async throws {
        let photos = asset("p").with(sourceID: LibrarySource.photos.id, pixelWidth: 1920, pixelHeight: 1080)
        let source = LibrarySource(id: "file", kind: .folder, displayName: "Downloads")
        let file = asset("f", bytes: 10).with(sourceID: source.id, reference: .file(URL(fileURLWithPath: "/Downloads/p.jpg")))
        let adapter = UnifiedLibraryAdapter(adapters: [WorkflowSource(source: .photos, items: [photos]), WorkflowSource(source: source, items: [file])])
        let result = try await UniversalExactScanner().scan(adapter: adapter, allowNetwork: false, progress: { _, _, _ in })
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(Set(result.groups[0].assets.map(\.sourceID)), [LibrarySource.photos.id, source.id])
    }

    func testFullLibraryScanMeasuresSingletonsWithRealFingerprints() async throws {
        let source = WorkflowSource(source: .photos, items: [asset("one", bytes: 10).with(sourceID: LibrarySource.photos.id)])
        let result = try await UniversalExactScanner().scan(adapter: source, allowNetwork: false, fingerprintAllAssets: true, progress: { _, _, _ in })
        XCTAssertEqual(result.fingerprintsByAssetID["one"]?.digest, "same")
        XCTAssertEqual(result.assets.count, 1); XCTAssertTrue(result.groups.isEmpty)
    }

    func testResourceFamilyCannotBeAnExactStandaloneStillEvenWithSameDigestAndSize() async throws {
        let files = LibrarySource(id: "file", kind: .folder, displayName: "Files")
        let live = asset("live", bytes: 10).with(sourceID: LibrarySource.photos.id)
        let still = asset("still", bytes: 10).with(sourceID: files.id)
        let adapter = UnifiedLibraryAdapter(adapters: [WorkflowSource(source: .photos, items: [live], fingerprint: .init(algorithm: "photos-family-sha256-v2", digest: "same", byteCount: 10)),
            WorkflowSource(source: files, items: [still])])
        let result = try await UniversalExactScanner().scan(adapter: adapter, allowNetwork: false, progress: { _, _, _ in })
        XCTAssertTrue(result.groups.isEmpty)
    }
    #endif
}

private struct WorkflowSource: SourceAdapter {
    let source: LibrarySource
    var items: [UniversalMediaAsset] = []
    var status: SourceAuthorization = .authorized
    var fails = false
    var warnings: [String] = []
    var cancels = false
    var fingerprint = UniversalExactFingerprint(digest: "same", byteCount: 10)
    var capabilities: PlatformCapabilities { .photos }
    func authorizationStatus() async -> SourceAuthorization { status }
    func requestAuthorization() async -> SourceAuthorization { status }
    func enumerationWarnings() async -> [String] { warnings }
    func enumerateAssets() async throws -> [UniversalMediaAsset] {
        if cancels { throw CancellationError() }
        if fails { throw UnifiedLibraryError.sourceUnavailable(source.id) }
        return items
    }
    func exactFingerprint(for asset: UniversalMediaAsset, allowNetwork: Bool, progress: @escaping @Sendable (Int64) -> Void) async throws -> UniversalExactFingerprint { fingerprint }
}
