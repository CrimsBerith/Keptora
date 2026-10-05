import Foundation
import XCTest
@testable import KeptoraCore

final class BulkCleanupPolicyTests: XCTestCase {
    private func item(_ id: String, bytes: Int64? = 100, date: Date? = Date(timeIntervalSince1970: 100.125), file: Bool = true,
                      album: Bool = false, favorite: Bool = false) -> UniversalMediaAsset {
        UniversalMediaAsset(id: id, sourceID: "source", reference: file ? .file(URL(fileURLWithPath: "/library/" + id + ".jpg")) : .photoLibrary(localIdentifier: id),
            displayName: id + ".jpg", mediaKind: .image, byteCount: bytes, pixelWidth: 2000, pixelHeight: 1500,
            modificationDate: date, isFavorite: favorite, hasAlbumMembership: album)
    }
    func testReviewUndoRestoresLastRemovedItemAtOriginalPosition() {
        let assets = [item("a"), item("b"), item("c")]
        var review = FrozenSelectionReview(assets)
        XCTAssertTrue(review.remove("b"))
        XCTAssertEqual(review.items.map(\.id), ["a", "c"])
        XCTAssertTrue(review.canUndoRemoval)
        XCTAssertEqual(review.undoRemoval(), assets[1])
        XCTAssertEqual(review.items, assets)
        XCTAssertFalse(review.canUndoRemoval)
        XCTAssertNil(review.undoRemoval())
    }
    func testReviewNoOpDoesNotLoseUndoAndLastItemCanBeRestored() {
        let a = item("a"), b = item("b")
        var review = FrozenSelectionReview([a, b])
        review.remove("a"); review.remove("b")
        XCTAssertTrue(review.items.isEmpty)
        XCTAssertFalse(review.remove("missing"))
        XCTAssertEqual(review.undoRemoval(), b)
        XCTAssertEqual(review.items, [b], "Undo restores only the most recent removal")
    }
    func testReviewUndoKeepsFrozenRevisionAndDeduplicatesIDs() {
        let original = item("a"), newer = original.with(byteCount: .some(999))
        var review = FrozenSelectionReview([original, newer])
        XCTAssertEqual(review.items, [original])
        review.remove(original.id)
        let restored = review.undoRemoval()
        XCTAssertEqual(restored, original)
        XCTAssertFalse(MediaRevisionPolicy.same(restored!, newer, algorithm: "review"), "Later changes still fail cleanup's revision check")
    }
    func testReviewDiscardDoesNotRestoreUnavailableItems() {
        let a = item("a"), b = item("b"), c = item("c")
        var review = FrozenSelectionReview([a, b, c])
        review.remove("b")
        review.discard(["a"])
        XCTAssertEqual(review.undoRemoval(), b)
        XCTAssertEqual(review.items, [b, c])
        review.remove("b"); review.discard(["b"])
        XCTAssertFalse(review.canUndoRemoval)
        XCTAssertNil(review.undoRemoval())
        XCTAssertEqual(review.items, [c])
    }
    func testSessionFinishesOnlyAfterAllStagesAndReportsPartial() {
        var session = AnalysisSessionProgress()
        for stage in [AnalysisStage.catalogue, .exact, .photos] { session.update(stage, .init(status: .completed)) }
        XCTAssertFalse(session.isFinished)
        session.update(.videos, .init(status: .partial))
        XCTAssertTrue(session.isFinished); XCTAssertFalse(session.isComplete)
        session.update(.videos, .init(status: .completed)); XCTAssertTrue(session.isComplete)
    }
    func testCancellationKeepsCompletedStageAndTerminatesOthers() {
        var session = AnalysisSessionProgress(); session.update(.exact, .init(status: .completed)); session.cancel()
        XCTAssertTrue(session.isFinished); XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.stages[.exact]?.status, .completed)
        XCTAssertEqual(session.stages[.photos]?.status, .cancelled)
        session.update(.photos, .init(status: .running, processed: 10, total: 100))
        XCTAssertEqual(session.stages[.photos]?.status, .cancelled, "Late progress cannot reopen a finished stage")
    }
    func testUnknownRevisionNeverReused() {
        XCTAssertNil(MediaRevisionPolicy.key(for: item("a", date: nil), algorithm: "v1"))
        XCTAssertNil(MediaRevisionPolicy.key(for: item("a", bytes: nil), algorithm: "v1"))
        XCTAssertFalse(MediaRevisionPolicy.same(item("a", date: nil), item("a", date: nil), algorithm: "v1"))
        XCTAssertNotNil(MediaRevisionPolicy.key(for: item("a", bytes: nil, file: false), algorithm: "v1"))
    }
    func testRevisionSeparatesSubsecondsAndAlgorithmsButNotRoutes() {
        let a = item("a")
        XCTAssertNotEqual(MediaRevisionPolicy.key(for: a, algorithm: "v1"), MediaRevisionPolicy.key(for: a, algorithm: "v2"))
        XCTAssertFalse(MediaRevisionPolicy.same(a, a.with(modificationDate: .some(Date(timeIntervalSince1970: 100.126))), algorithm: "v1"))
        XCTAssertTrue(MediaRevisionPolicy.same(a, a.with(sourceID: "another-root"), algorithm: "v1"))
    }
    func testSelectionRetainsUnavailableFilesButDropsProvenRemovedFiles() {
        let source = LibrarySource(id: "source", kind: .folder, displayName: "Files")
        let previous = [item("a"), item("b")]
        let failed = [LibrarySourceCoverage(source: source, authorization: .authorized, itemCount: 1, error: "offline")]
        let pending = PendingLibrarySelection(ids: ["a", "b"], current: [previous[0]], previous: previous, coverage: failed)
        XCTAssertEqual(pending.pending.map(\.id), ["b"]); XCTAssertEqual(pending.ids, ["a", "b"])
        let complete = [LibrarySourceCoverage(source: source, authorization: .authorized, itemCount: 1)]
        XCTAssertEqual(PendingLibrarySelection(ids: pending.ids, current: [previous[0]], previous: previous, coverage: complete).ids, ["a"])
    }
    func testPhotosMissingFromLimitedAccessRemainPending() {
        let photo = item("photo", file: false)
        let result = PendingLibrarySelection(ids: [photo.id], current: [], previous: [photo], coverage: [])
        XCTAssertEqual(result.pending, [photo]); XCTAssertEqual(result.ids, [photo.id])
    }
    func testLegacySelectionWithoutMetadataRemainsVisibleAsUnresolved() {
        let result = PendingLibrarySelection(ids: ["legacy"], current: [], previous: [], coverage: [])
        XCTAssertEqual(result.unresolvedIDs, ["legacy"]); XCTAssertEqual(result.ids, ["legacy"])
    }
    func testWorkGateLimitsConcurrencyAndReturnsSlotsAfterFailure() async throws {
        let gate = MediaWorkGate(limit: 3), probe = WorkGateProbe()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<100 { group.addTask {
                try await gate.withPermit {
                    await probe.enter(); await Task.yield(); await probe.leave()
                }
            } }
            try await group.waitForAll()
        }
        let peak = await probe.peak, completed = await probe.completed
        XCTAssertLessThanOrEqual(peak, 3); XCTAssertEqual(completed, 100)
        do { let _: Int = try await gate.withPermit { throw GateTestError.expected }; XCTFail("Expected failure") }
        catch GateTestError.expected { }
        let value = try await gate.withPermit { 42 }; XCTAssertEqual(value, 42)
    }
    func testOrdinaryAlbumDoesNotBlockCopySuggestionsButFavoriteDoes() {
        let ordinary = item("album", album: true), favorite = item("favorite", favorite: true)
        XCTAssertFalse(ordinary.isProtectedFromGlobalSelection); XCTAssertTrue(favorite.isProtectedFromGlobalSelection)
        let groups = LibraryReviewGroup.combined(exact: [UniversalExactGroup(digest: "same", assets: [item("keeper"), ordinary, favorite], keeperID: "keeper")], similar: [])
        XCTAssertEqual(LibraryReviewDecisions().exactSuggestions(groups).map(\.id), ["album"])
    }
    func testUserKeeperAndProtectionControlSuggestions() {
        let assets = [item("a"), item("b"), item("c")]
        let group = LibraryReviewGroup.combined(exact: [UniversalExactGroup(digest: "same", assets: assets, keeperID: "a")], similar: [])[0]
        var decisions = LibraryReviewDecisions(); decisions.keep("b", in: group)
        XCTAssertEqual(decisions.keeper(in: group), "b")
        XCTAssertEqual(Set(decisions.candidates(in: group).map(\.id)), ["a", "c"])
        decisions.protect(group); XCTAssertTrue(decisions.candidates(in: group).isEmpty)
    }
    func testUserKeeperBadgeWinsAcrossOverlappingGroupsAndExpiresWithRevision() {
        let a = item("a"), b = item("b"), c = item("c")
        let groups = LibraryReviewGroup.combined(exact: [UniversalExactGroup(digest: "same", assets: [b, c], keeperID: "b")],
            similar: [UniversalSimilarityGroup(id: "related", assets: [a, b], maximumDistance: 0.1, strength: .verySimilar, keeperID: "a")])
        var decisions = LibraryReviewDecisions()
        let similar = groups.first { $0.kind == .verySimilar }!
        decisions.keep("b", in: similar)
        XCTAssertEqual(decisions.keeperBadgeKeys(in: groups), ["b": "Your Keep Choice"])
        XCTAssertEqual(decisions.keeperBadgeKeys(in: Array(groups.reversed())), ["b": "Your Keep Choice"])
        let changed = LibraryReviewGroup.combined(exact: [], similar: [UniversalSimilarityGroup(id: "related", assets: [a, b.with(byteCount: .some(999))], maximumDistance: 0.1, strength: .verySimilar, keeperID: "a")])
        XCTAssertEqual(decisions.keeperBadgeKeys(in: changed), ["a": "Suggested Keep"])
    }
    func testKeeperOverrideInvalidatesWhenGroupRevisionChanges() {
        let assets = [item("a"), item("b")]
        let old = LibraryReviewGroup.combined(exact: [UniversalExactGroup(digest: "same", assets: assets, keeperID: "a")], similar: [])[0]
        var decisions = LibraryReviewDecisions(); decisions.keep("b", in: old)
        XCTAssertTrue(decisions.hasUserKeeper(in: old))
        let changed = LibraryReviewGroup.combined(exact: [UniversalExactGroup(digest: "same", assets: [assets[0], assets[1].with(byteCount: .some(999))], keeperID: "a")], similar: [])[0]
        XCTAssertEqual(decisions.keeper(in: changed), "a")
        XCTAssertFalse(decisions.hasUserKeeper(in: changed), "An old choice must not be labelled as the user's current decision")
    }
    func testExactSuggestionsNeverIncludeKeeperFromRelatedGroup() {
        let a = item("a"), b = item("b"), c = item("c")
        let groups = LibraryReviewGroup.combined(exact: [UniversalExactGroup(digest: "same", assets: [a,b], keeperID: "a")],
            similar: [UniversalSimilarityGroup(id: "similar", assets: [b,c], maximumDistance: 0.1, strength: .verySimilar, keeperID: "b")])
        XCTAssertTrue(LibraryReviewDecisions().exactSuggestions(groups).isEmpty)
    }
    func testGroupSelectionRespectsKeepersInOtherVisibleRelations() {
        let a = item("a"), b = item("b"), c = item("c")
        let groups = LibraryReviewGroup.combined(exact: [UniversalExactGroup(digest: "same", assets: [a, b], keeperID: "a")],
            similar: [UniversalSimilarityGroup(id: "similar", assets: [b, c], maximumDistance: 0.1, strength: .verySimilar, keeperID: "b")])
        var decisions = LibraryReviewDecisions()
        XCTAssertTrue(decisions.candidates(in: groups[0], respecting: groups).isEmpty,
            "Select Others must not select a photo shown as kept in an overlapping group")
        XCTAssertEqual(decisions.candidatesByGroup(groups)[groups[0].id]?.map(\.id), [])
        decisions.keep(c.id, in: groups[1])
        XCTAssertEqual(decisions.candidates(in: groups[0], respecting: groups).map(\.id), [b.id])
        XCTAssertEqual(decisions.candidatesByGroup(groups)[groups[0].id]?.map(\.id), [b.id])
        decisions.protect(groups[1])
        XCTAssertTrue(decisions.candidates(in: groups[0], respecting: groups).isEmpty)
    }
    func testThreeThousandItemSmartGridShowsEachItemOnceWithOverlappingRelations() {
        let assets = (0..<3000).map { item(String($0)) }
        let exact = (0..<750).map { UniversalExactGroup(digest: String($0), assets: [assets[$0*2], assets[$0*2+1]]) }
        var similar: [UniversalSimilarityGroup] = []
        for index in 0..<750 {
            let members = [assets[index * 2 + 1], assets[index * 2 + 2]]
            similar.append(UniversalSimilarityGroup(id: "s" + String(index), assets: members, maximumDistance: 0.1))
        }
        let groups = LibraryReviewGroup.combined(exact: exact, similar: similar)
        let blocks = LibraryReviewBlock.make(assets: assets, groups: groups, quality: [:], smart: true)
        let ids = blocks.flatMap { $0.assets.map(\.id) }
        XCTAssertEqual(ids.count, 3000); XCTAssertEqual(Set(ids).count, 3000)
        XCTAssertEqual(blocks.first?.titleKey, "Related Shots"); XCTAssertEqual(blocks.first?.groups.count, 1500)
        XCTAssertEqual(blocks.last?.id, "other")
    }
    func testFindingFiltersKeepQualitySingletonsAndSeparateVerySimilar() {
        let a = item("a"), b = item("b"), c = item("c")
        let groups = LibraryReviewGroup.combined(exact: [], similar: [UniversalSimilarityGroup(id: "similar", assets: [a,b], maximumDistance: 0.1, strength: .verySimilar)])
        let quality = ["c": QualityAssessment.evaluate(luma: Array(repeating: 0, count: 10000), width: 100, height: 100, originalWidth: 2000, originalHeight: 2000)]
        XCTAssertEqual(LibraryFindingFilter.verySimilar.ids(groups: groups, quality: quality), ["a", "b"])
        XCTAssertEqual(LibraryFindingFilter.review.ids(groups: groups, quality: quality), ["c"])
        let blocks = LibraryReviewBlock.make(assets: [a,b,c], groups: groups, quality: quality, smart: true)
        XCTAssertEqual(blocks.last?.titleKey, "Worth Reviewing")
    }
    func testAspectFitAndTinyPreviewDoNotInventLowResolution() {
        let size = QualityAssessment.sampleSize(width: 4000, height: 2000)
        XCTAssertEqual(size.width, 256); XCTAssertEqual(size.height, 128)
        let report = QualityAssessment.evaluate(luma: Array(repeating: 128, count: 10000), width: 100, height: 100, originalWidth: 4000, originalHeight: 3000)
        XCTAssertEqual(report.state, .insufficientDetail); XCTAssertFalse(report.needsReview)
    }
    func testFlatAndNoisyImagesAreNotConfidentBlurEvidence() {
        let flat = QualityAssessment.evaluate(luma: Array(repeating: 128, count: 256*256), width: 256, height: 256, originalWidth: 4000, originalHeight: 3000)
        var seed: UInt64 = 1
        let noise: [UInt8] = (0..<256*256).map { _ in seed = seed &* 6364136223846793005 &+ 1; return UInt8(truncatingIfNeeded: seed >> 32) }
        let noisy = QualityAssessment.evaluate(luma: noise, width: 256, height: 256, originalWidth: 4000, originalHeight: 3000)
        XCTAssertFalse(flat.findings.contains(.possibleBlur)); XCTAssertFalse(noisy.findings.contains(.possibleBlur))
        XCTAssertEqual(noisy.state, .insufficientDetail)
    }
    func testExposureFlagsAreHintsAndInvalidDecodeIsUnavailable() {
        let dark = QualityAssessment.evaluate(luma: Array(repeating: 0, count: 10000), width: 100, height: 100, originalWidth: 800, originalHeight: 600)
        XCTAssertEqual(Set(dark.findings), [.dark, .lowResolution])
        let bright = QualityAssessment.evaluate(luma: Array(repeating: 255, count: 10000), width: 100, height: 100, originalWidth: 4000, originalHeight: 3000)
        XCTAssertEqual(bright.findings, [.bright])
        XCTAssertEqual(QualityAssessment.evaluate(luma: [], width: 100, height: 100, originalWidth: 0, originalHeight: 0).state, .unavailable)
    }
    func testCacheRoundTripSeparatesVersionsAndUnknownRevisions() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = MediaFingerprintDiskCache(customCacheURL: url)
        let asset = item("a"), entry = MediaFingerprintDiskCache.CacheEntry(assetID: "a", digest: "sha256", byteCount: 100)
        await cache.store(asset: asset, algorithm: "exact", entry: entry); await cache.persistToDisk()
        let loaded = MediaFingerprintDiskCache(customCacheURL: url)
        let hit = await loaded.get(asset: asset, algorithm: "exact")
        let miss = await loaded.get(asset: asset, algorithm: "visual")
        let unknown = await loaded.get(asset: asset.with(modificationDate: .some(nil)), algorithm: "exact")
        XCTAssertEqual(hit?.digest, "sha256"); XCTAssertNil(miss); XCTAssertNil(unknown)
    }
    func testCacheBoundsAndCorruptionFailClosed() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("broken".utf8).write(to: url)
        let cache = MediaFingerprintDiskCache(customCacheURL: url, maximumEntries: 1)
        let cold = await cache.get(asset: item("a"), algorithm: "exact"); XCTAssertNil(cold)
        await cache.store(asset: item("a"), algorithm: "exact", entry: .init(assetID: "a", digest: "a", byteCount: 100, timestamp: 1))
        await cache.store(asset: item("b"), algorithm: "exact", entry: .init(assetID: "b", digest: "b", byteCount: 100, timestamp: 2))
        let evicted = await cache.get(asset: item("a"), algorithm: "exact")
        let retained = await cache.get(asset: item("b"), algorithm: "exact")
        XCTAssertNil(evicted); XCTAssertEqual(retained?.digest, "b")
    }
}

private enum GateTestError: Error { case expected }
private actor WorkGateProbe {
    var active = 0
    private(set) var peak = 0
    private(set) var completed = 0
    func enter() { active += 1; peak = max(peak, active) }
    func leave() { active -= 1; completed += 1 }
}
