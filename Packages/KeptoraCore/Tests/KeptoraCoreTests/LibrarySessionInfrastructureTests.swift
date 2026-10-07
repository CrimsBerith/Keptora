import Foundation
import XCTest
@testable import KeptoraCore

final class LibrarySessionInfrastructureTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    private func item(_ id: String, bytes: Int64 = 10, date: Date = .distantPast, favorite: Bool = false) -> UniversalMediaAsset {
        .init(id: id, sourceID: "fixture", reference: .photoLibrary(localIdentifier: id), displayName: id,
              mediaKind: .image, byteCount: bytes, creationDate: date, isFavorite: favorite)
    }
    func testCanonicalRelativePathsHandleAliasesMissingLeavesAndRejectEscapedParents() throws {
        let base = try root(), files = FileManager.default
        defer { try? files.removeItem(at: base) }
        let originalRoot = base.appendingPathComponent("Before"), alias = base.appendingPathComponent("Alias")
        let renamed = base.appendingPathComponent("After"), outside = base.appendingPathComponent("Outside")
        try files.createDirectory(at: originalRoot.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try files.createDirectory(at: outside, withIntermediateDirectories: true)
        try files.createSymbolicLink(at: alias, withDestinationURL: originalRoot)
        let photo = originalRoot.appendingPathComponent("nested/photo.jpg")
        XCTAssertEqual(LibraryFileIdentity.relativePath(photo, root: alias), "nested/photo.jpg")
        try Data("photo".utf8).write(to: photo)
        XCTAssertEqual(LibraryFileIdentity.relativePath(photo, root: alias), "nested/photo.jpg")
        try files.removeItem(at: photo)
        XCTAssertEqual(LibraryFileIdentity.relativePath(photo, root: alias), "nested/photo.jpg")
        let id = UUID()
        let record = FolderQuarantineRecord(id: id, sourceRoot: alias, operations: [.init(
            originalURL: photo, quarantineURL: originalRoot.appendingPathComponent(".Keptora Quarantine/\(id.uuidString)/nested/photo.jpg"), expectedDigest: "hash")])
        try files.moveItem(at: originalRoot, to: renamed)
        let rebased = try record.rebased(to: renamed)
        XCTAssertEqual(rebased.operations[0].originalURL, renamed.appendingPathComponent("nested/photo.jpg"))
        let escape = renamed.appendingPathComponent("escape")
        try files.createSymbolicLink(at: escape, withDestinationURL: outside)
        XCTAssertNil(LibraryFileIdentity.relativePath(escape.appendingPathComponent("missing/photo.jpg"), root: renamed))
        XCTAssertNil(LibraryFileIdentity.relativePath(outside.appendingPathComponent("photo.jpg"), root: renamed))
    }
    func testSettingsSnapshotReadsExistingKeysAndNormalizesExclusions() throws {
        let name = UUID().uuidString, defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("Cache, TMP", forKey: "Keptora.ExcludedFolderNames")
        defaults.set(".JPG, MOV", forKey: "Keptora.ExcludedExtensions")
        defaults.set(false, forKey: "Keptora.Feature.Similarity.v1")
        defaults.set("newest", forKey: "Keptora.KeeperSelectionPolicy")
        defaults.set(250, forKey: "Keptora.CheckpointInterval")
        let config = LibraryConfiguration.stored(in: defaults)
        XCTAssertFalse(config.similarityEnabled); XCTAssertEqual(config.keeper, .newest)
        XCTAssertTrue(config.excludesDirectory("TMP")); XCTAssertTrue(config.excludesDirectory("node_modules"))
        XCTAssertTrue(config.excludesExtension("jpg")); XCTAssertEqual(config.checkpointInterval, 250)
        XCTAssertLessThan(config.visualThreshold, LibraryConfiguration(sensitivity: "discovery").visualThreshold)
    }
    func testKeeperPreferencesPreserveUserProtection() {
        let old = item("old"), new = item("new", date: Date()), favorite = item("favorite", favorite: true)
        XCTAssertEqual(LibraryConfiguration(keeper: .newest).keeperID(in: [old, new]), "new")
        XCTAssertEqual(LibraryConfiguration(keeper: .oldest).keeperID(in: [old, new]), "old")
        XCTAssertEqual(LibraryConfiguration(keeper: .largest).keeperID(in: [item("small"), item("large", bytes: 100)]), "large")
        XCTAssertEqual(LibraryConfiguration(keeper: .newest).keeperID(in: [favorite, new]), "favorite")
    }
    func testIdentitySurvivesFolderRenameAndDistinguishesReplacementAtSamePath() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let folder = base.appendingPathComponent("old"), moved = base.appendingPathComponent("new")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("photo.jpg"); try Data([1, 2, 3]).write(to: file)
        let source = LibraryFileIdentity.key(for: folder), asset = LibraryFileIdentity.key(for: file)
        try FileManager.default.moveItem(at: folder, to: moved)
        XCTAssertEqual(LibraryFileIdentity.key(for: moved), source)
        XCTAssertEqual(LibraryFileIdentity.key(for: moved.appendingPathComponent("photo.jpg")), asset)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertNotEqual(LibraryFileIdentity.key(for: folder), source)
    }
    func testRecoveryRebasesRelativePathsAndRejectsDifferentSource() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let old = base.appendingPathComponent("old"), moved = base.appendingPathComponent("new"), other = base.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        let id = UUID(), op = FolderQuarantineOperation(originalURL: old.appendingPathComponent("nested/a.jpg"),
            quarantineURL: old.appendingPathComponent(".Keptora Quarantine/\(id.uuidString)/nested/a.jpg"), expectedDigest: "hash")
        let record = FolderQuarantineRecord(id: id, sourceRoot: old, operations: [op])
        try FileManager.default.moveItem(at: old, to: moved)
        let rebased = try record.rebased(to: moved)
        XCTAssertEqual(rebased.operations[0].id, op.id)
        XCTAssertEqual(rebased.operations[0].originalURL, moved.appendingPathComponent("nested/a.jpg"))
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        XCTAssertThrowsError(try record.rebased(to: other))
    }
    func testLegacyRecoveryManifestDecodesWithoutNewLedgerFields() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let record = FolderQuarantineRecord(sourceRoot: base, operations: [])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        json.removeValue(forKey: "sourceIdentity")
        let legacy = try JSONDecoder().decode(FolderQuarantineRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.sourceIdentity); XCTAssertEqual(legacy.movedCount, 0)
    }
    func testLedgerCountsActualMovedFilesSeparatelyFromPlannedAndUnresolved() {
        let base = URL(fileURLWithPath: "/fixture"), id = UUID()
        var operations = (0..<5).map { FolderQuarantineOperation(originalURL: base.appendingPathComponent("\($0).jpg"),
            quarantineURL: base.appendingPathComponent(".Keptora Quarantine/\(id)/\($0).jpg"), expectedDigest: "x") }
        operations[0].state = .moved; operations[0].byteCount = 50
        operations[1].state = .restored; operations[2].state = .interrupted
        let record = FolderQuarantineRecord(id: id, sourceRoot: base, operations: operations)
        XCTAssertEqual(record.movedCount, 1); XCTAssertEqual(record.unresolvedCount, 3); XCTAssertEqual(record.recoveryBytes, 50)
    }
    func testRepositoryRejectsStaleWritesAndRecoversLastValidBackup() async throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let url = base.appendingPathComponent("state.json"), repo = LibraryRepository<[String]>(url: url)
        try await repo.save(["first"], sequence: 1); try await repo.save(["second"], sequence: 2)
        try await repo.save(["stale"], sequence: 1)
        let latest = try await repo.load(); XCTAssertEqual(latest.value, ["second"])
        try Data("broken".utf8).write(to: url)
        let restored = try await LibraryRepository<[String]>(url: url).load()
        XCTAssertEqual(restored.value, ["first"]); XCTAssertTrue(restored.recoveredBackup)
    }
    func testCorruptRepositoryWithoutBackupReportsFailureInsteadOfEmptySelection() async throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let url = base.appendingPathComponent("state.json"); try Data("broken".utf8).write(to: url)
        do { _ = try await LibraryRepository<[String]>(url: url).load(); XCTFail("Corruption must be visible") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), Data("broken".utf8))
    }
    func testCleanupRejectsFileChangedDuringFingerprintPreparation() async throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let url = base.appendingPathComponent("photo.jpg"); try Data([1, 2, 3]).write(to: url)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let asset = UniversalMediaAsset(id: "a", sourceID: "fixture", reference: .file(url), displayName: "photo.jpg",
            mediaKind: .image, byteCount: Int64(values.fileSize ?? 0), modificationDate: values.contentModificationDate,
            fileRevision: LibraryFileRevision.capture(at: url))
        do { _ = try await LibraryCleanupPreflight().prepare([asset], adapter: MutatingSource(url: url)); XCTFail("Changed content must require a new review") } catch { }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func testFamilyWarningFindsSidecarRawAndMotionWithoutIncludingUnrelatedFiles() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        for name in ["capture.jpg", "capture.dng", "capture.mov", "capture.xmp", "other.jpg"] { try Data([1]).write(to: base.appendingPathComponent(name)) }
        let a = item("photo").with(reference: .file(base.appendingPathComponent("capture.jpg")))
        XCTAssertEqual(Set(LibraryFileFamilies.omittedCompanions(for: [a]).map(\.lastPathComponent)), ["capture.dng", "capture.mov", "capture.xmp"])
    }
    func testRangeSelectionIsInclusiveReversibleAndCannotEscapeVisibleList() {
        let items = [item("a"), item("b"), item("c"), item("d")]
        XCTAssertEqual(LibraryRangeSelection.items(from: "c", through: "a", in: items).map(\.id), ["a", "b", "c"])
        XCTAssertTrue(LibraryRangeSelection.items(from: "hidden", through: "a", in: items).isEmpty)
    }
    func testPausedWorkCanBeCancelledWithoutResuming() async throws {
        let control = LibraryAnalysisControl(); await control.setPaused(true)
        let task = Task { try await control.waitIfPaused() }
        task.cancel()
        do { try await task.value; XCTFail("Paused tasks must respond to cancellation") } catch is CancellationError { }
    }
    func testUnchangedCataloguePreservesResultsButChangedContentAndIntentInvalidate() {
        let original = item("a"), other = item("b")
        XCTAssertEqual(LibraryCatalogueReconciliation.unchangedIDs(current: [original, other], previous: [original, other]), ["a", "b"])
        XCTAssertEqual(LibraryCatalogueReconciliation.unchangedIDs(current: [original.with(isFavorite: true), other], previous: [original, other]), ["b"])
        XCTAssertEqual(LibraryCatalogueReconciliation.unchangedIDs(current: [original.with(byteCount: .some(100)), other], previous: [original, other]), ["b"])
        XCTAssertEqual(LibraryCatalogueReconciliation.unchangedIDs(current: [original.with(byteCount: .some(nil), requiresNetwork: true)], previous: [original]), ["a"])
    }
    func testLatePauseCommandCannotOverrideNewerResume() async throws {
        let control = LibraryAnalysisControl()
        await control.setPaused(false, sequence: 2)
        await control.setPaused(true, sequence: 1)
        // A stale pause would suspend this operation; cancellation bounds failures.
        let work = Task { try await control.waitIfPaused() }
        let watchdog = Task { try await Task.sleep(nanoseconds: 500_000_000); work.cancel() }
        try await work.value; watchdog.cancel()
    }
    func testSelectionSessionUndoesDecisionsTogetherAndExcludesMissingItems() {
        var decisions = LibraryReviewDecisions(); decisions.toggleProtection("a")
        var session = LibrarySelectionUndoSession(); session.capture(ids: ["a", "missing"], decisions: decisions)
        let restored = session.undo(available: ["a"])
        XCTAssertEqual(restored?.ids, ["a"]); XCTAssertEqual(restored?.decisions, decisions)
        XCTAssertNil(session.undo(available: ["a"]))
    }

    private func reviewedFile(_ url: URL) throws -> UniversalMediaAsset {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return .init(id: LibraryFileIdentity.assetID(for: url), sourceID: "fixture", reference: .file(url),
            displayName: url.lastPathComponent, mediaKind: .image, byteCount: values.fileSize.map(Int64.init),
            modificationDate: values.contentModificationDate, fileRevision: LibraryFileRevision.capture(at: url))
    }
    func testReviewRejectsAtomicReplacementWithSameSizeAndModificationTime() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let url = base.appendingPathComponent("photo.jpg"), replacement = base.appendingPathComponent("new.jpg")
        try Data("AAAA".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: url.path)
        let reviewed = try reviewedFile(url)
        try Data("BBBB".utf8).write(to: replacement)
        try FileManager.default.setAttributes([.modificationDate: try XCTUnwrap(reviewed.modificationDate)], ofItemAtPath: replacement.path)
        try FileManager.default.removeItem(at: url); try FileManager.default.moveItem(at: replacement, to: url)
        let current = try reviewedFile(url)
        XCTAssertEqual(current.byteCount, reviewed.byteCount); XCTAssertEqual(current.modificationDate, reviewed.modificationDate)
        XCTAssertNotEqual(current.fileRevision?.physicalIdentity, reviewed.fileRevision?.physicalIdentity)
        XCTAssertThrowsError(try LibraryRevisionValidator.validate([reviewed]))
        XCTAssertNoThrow(try LibraryRevisionValidator.validate([current]))
    }
    func testReviewRejectsInPlaceEditWithRestoredModificationTimeAndInvalidatesCache() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let url = base.appendingPathComponent("photo.jpg"); try Data("AAAA".utf8).write(to: url)
        let reviewed = try reviewedFile(url), handle = try FileHandle(forWritingTo: url)
        try handle.write(contentsOf: Data("BBBB".utf8)); try handle.close()
        try FileManager.default.setAttributes([.modificationDate: try XCTUnwrap(reviewed.modificationDate)], ofItemAtPath: url.path)
        let current = try reviewedFile(url)
        XCTAssertEqual(current.fileRevision?.physicalIdentity, reviewed.fileRevision?.physicalIdentity)
        XCTAssertNotEqual(current.fileRevision?.changeToken, reviewed.fileRevision?.changeToken)
        XCTAssertThrowsError(try LibraryRevisionValidator.validate([reviewed]))
        XCTAssertFalse(MediaRevisionPolicy.same(current, reviewed, algorithm: "test"))
        XCTAssertEqual(current.with(byteCount: .some(4)).fileRevision, current.fileRevision)
    }
    func testLegacyFileSnapshotRequiresFreshReviewAndCannotReuseCache() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let url = base.appendingPathComponent("photo.jpg"); try Data([1]).write(to: url)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(reviewedFile(url))) as? [String: Any])
        json.removeValue(forKey: "fileRevision")
        let old = try JSONDecoder().decode(UniversalMediaAsset.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.fileRevision); XCTAssertNil(MediaRevisionPolicy.key(for: old, algorithm: "test"))
        XCTAssertThrowsError(try LibraryRevisionValidator.validate([old]))
    }
    func testHardLinksHaveDistinctEntryIDsAndSharedPhysicalIdentity() throws {
        let base = try root(); defer { try? FileManager.default.removeItem(at: base) }
        let a = base.appendingPathComponent("a.jpg"), b = base.appendingPathComponent("b.jpg")
        try Data([1, 2, 3]).write(to: a); try FileManager.default.linkItem(at: a, to: b)
        let first = try reviewedFile(a), second = try reviewedFile(b)
        XCTAssertNotEqual(first.id, second.id); XCTAssertEqual(first.fileRevision?.physicalIdentity, second.fileRevision?.physicalIdentity)
        let catalogue = UnifiedLibraryAdapter.uniqueReferences([first, second, first.with(sourceID: "overlapping")])
        XCTAssertEqual(catalogue.count, 2); XCTAssertEqual(Set(catalogue.map(\.id)).count, 2)
        XCTAssertEqual(LibraryFileIdentity.volumeKey(for: a), LibraryFileIdentity.volumeKey(for: base))
    }
    func testCleanupBindsAlreadyMeasuredFingerprintToTheReviewedItem() async throws {
        let asset = item("a"), source = FixedDigestSource()
        let preflight = LibraryCleanupPreflight(validate: { _ in })
        do {
            _ = try await preflight.prepare([asset], adapter: source, reviewedFingerprints: [asset.id: .init(digest: "old", byteCount: 10)])
            XCTFail("A changed digest must not become a new reviewed digest")
        } catch UnifiedLibraryError.selectionChanged { }
        let prepared = try await preflight.prepare([asset], adapter: source, reviewedFingerprints: [asset.id: .init(digest: "current", byteCount: 10)])
        XCTAssertEqual(prepared.first?.expectedDigest, "current")
    }
    func testMeasuredQualityKeeperSurvivesDefaultPolicyButExplicitIntentWins() {
        let sharp = item("sharp", bytes: 10), blurry = item("blurry", bytes: 1_000)
        let quality = [sharp.id: QualityAssessment(state: .evaluated, findings: [], detailScore: 95, exposureScore: 90),
                       blurry.id: QualityAssessment(state: .evaluated, findings: [.possibleBlur], detailScore: 5, exposureScore: 90)]
        XCTAssertEqual(LibraryConfiguration().keeperID(in: [blurry, sharp], recommendedKeeperID: sharp.id), sharp.id)
        XCTAssertEqual(LibraryConfiguration().keeperID(in: [blurry, sharp], quality: quality), sharp.id)
        XCTAssertEqual(LibraryConfiguration(keeper: .largest).keeperID(in: [blurry, sharp], recommendedKeeperID: sharp.id, quality: quality), blurry.id)
        XCTAssertEqual(LibraryConfiguration().keeperID(in: [blurry.with(isFavorite: true), sharp], recommendedKeeperID: sharp.id, quality: quality), blurry.id)
        let group = LibraryReviewGroup(id: "pair", kind: .verySimilar, assets: [blurry, sharp], keeperID: sharp.id)
        XCTAssertEqual(LibraryReviewDecisions().keeperReason(in: group, quality: quality), "Suggested from Measured Detail")
        XCTAssertEqual(LibraryReviewDecisions().keeperReason(in: group, quality: quality, configuration: .init(keeper: .largest)), "Suggested from Available Media Information")
    }
    func testQualityFiltersSeparateHintsAndProblemItems() {
        let quality = ["blur": QualityAssessment(state: .evaluated, findings: [.possibleBlur, .lowResolution], detailScore: 5, exposureScore: 90),
                       "dark": QualityAssessment(state: .insufficientDetail, findings: [.dark], detailScore: 0, exposureScore: 0)]
        let issues = [AnalysisIssue(assetID: "offline", sourceID: "fixture", stage: .exact, reason: .downloadRequired)]
        XCTAssertEqual(LibraryQualityFilter.possibleBlur.ids(quality: quality, issues: issues), ["blur"])
        XCTAssertEqual(LibraryQualityFilter.lowResolution.ids(quality: quality, issues: issues), ["blur"])
        XCTAssertEqual(LibraryQualityFilter.dark.ids(quality: quality, issues: issues), ["dark"])
        XCTAssertEqual(LibraryQualityFilter.bright.ids(quality: quality, issues: issues), [])
        XCTAssertEqual(LibraryQualityFilter.issues.ids(quality: quality, issues: issues), ["offline"])
        XCTAssertNil(LibraryQualityFilter.all.ids(quality: quality, issues: issues))
    }
    func testMultiStepUndoRedoKeepsDecisionsFiltersUnavailableAndDropsRedoBranch() {
        var session = LibrarySelectionUndoSession(), decisions = LibraryReviewDecisions()
        session.capture(ids: [], decisions: decisions)
        session.capture(ids: ["a", "gone"], decisions: decisions)
        decisions.toggleProtection("b")
        let undo = session.undo(available: ["a", "b"], currentIDs: ["b"], decisions: decisions)
        XCTAssertEqual(undo?.ids, ["a"]); XCTAssertEqual(undo?.decisions.protectedIDs, [])
        let redo = session.redo(available: ["a", "b"], currentIDs: undo!.ids, decisions: undo!.decisions)
        XCTAssertEqual(redo?.ids, ["b"]); XCTAssertEqual(redo?.decisions.protectedIDs, ["b"])
        _ = session.undo(available: ["a", "b"], currentIDs: redo!.ids, decisions: redo!.decisions)
        _ = session.undo(available: ["a", "b"], currentIDs: ["a"], decisions: .init())
        XCTAssertFalse(session.canUndo); XCTAssertTrue(session.canRedo)
        session.capture(ids: ["a"], decisions: .init()); XCTAssertFalse(session.canRedo)
    }
    func testUndoHistoryIsBoundedForThousandsOfSelectionChanges() {
        var session = LibrarySelectionUndoSession(limit: 50)
        for n in 0..<3_000 { session.capture(ids: ["\(n)"], decisions: .init()) }
        var count = 0
        while session.undo(available: ["2999"]) != nil { count += 1 }
        XCTAssertEqual(count, 50)
    }
    func testPartialCleanupRemovesCompletedItemsFromFrozenReviewAndUndo() {
        let a = item("a"), b = item("b"), c = item("c")
        var review = FrozenSelectionReview([a, b, c]); review.remove(a.id)
        let outcome = LibraryCleanupOutcome(requestedIDs: [a.id, b.id, c.id], completedIDs: [a.id], failedIDs: [b.id])
        review.discard(outcome.completedIDs)
        XCTAssertNil(review.undoRemoval()); XCTAssertEqual(review.items, [b, c])
        XCTAssertEqual(outcome.notAttemptedIDs, [c.id]); XCTAssertFalse(outcome.isComplete)
    }
    @MainActor func testSharedOperationOwnerAllowsReadsButExcludesOverlappingWritersAndQuit() async throws {
        let owner = LibraryOperationCoordinator(), resources: Set<String> = ["volume:one"]
        let first = try XCTUnwrap(owner.acquire(resources, mode: .read)), second = try XCTUnwrap(owner.acquire(resources, mode: .read))
        XCTAssertNil(owner.acquire(resources, mode: .write))
        let independent = try XCTUnwrap(owner.acquire(["volume:two"], mode: .write))
        XCTAssertFalse(owner.canAcquire(["volume:two"], mode: .read))
        owner.release(first); owner.release(second)
        let writer = try XCTUnwrap(owner.acquire(resources, mode: .write))
        XCTAssertFalse(owner.canAcquire(resources, mode: .read)); owner.beginTermination()
        XCTAssertNil(owner.acquire(["volume:three"], mode: .read))
        owner.release(writer); owner.release(independent); await owner.waitForIdle()
        owner.resumeAfterCancelledTermination(); XCTAssertTrue(owner.canAcquire(resources, mode: .write))
    }
    func testIncompleteCatalogueCannotDropAnExistingSelection() {
        let old = item("not-seen-yet").with(sourceID: "fixture", reference: .file(URL(fileURLWithPath: "/fixture/a.jpg")))
        let source = LibrarySource(id: "fixture", kind: .folder, displayName: "Fixture")
        let partial = LibrarySourceCoverage(source: source, authorization: .authorized, itemCount: 25, enumerationComplete: false)
        let selection = PendingLibrarySelection(ids: [old.id], current: [], previous: [old], coverage: [partial])
        XCTAssertEqual(selection.ids, [old.id]); XCTAssertEqual(selection.pending, [old])
        let complete = LibrarySourceCoverage(source: source, authorization: .authorized, itemCount: 25)
        XCTAssertTrue(PendingLibrarySelection(ids: selection.ids, current: [], previous: selection.pending, coverage: [complete]).ids.isEmpty)
    }
}

private struct FixedDigestSource: SourceAdapter {
    var source: LibrarySource { .init(id: "fixture", kind: .folder, displayName: "Fixture") }
    var capabilities: PlatformCapabilities { .photos }
    func authorizationStatus() async -> SourceAuthorization { .authorized }
    func requestAuthorization() async -> SourceAuthorization { .authorized }
    func enumerateAssets() async throws -> [UniversalMediaAsset] { [] }
    func exactFingerprint(for asset: UniversalMediaAsset, allowNetwork: Bool, progress: @escaping @Sendable (Int64) -> Void) async throws -> UniversalExactFingerprint { .init(digest: "current", byteCount: 10) }
}

private struct MutatingSource: SourceAdapter {
    let url: URL
    var source: LibrarySource { .init(id: "fixture", kind: .folder, displayName: "Fixture") }
    var capabilities: PlatformCapabilities { .photos }
    func authorizationStatus() async -> SourceAuthorization { .authorized }
    func requestAuthorization() async -> SourceAuthorization { .authorized }
    func enumerateAssets() async throws -> [UniversalMediaAsset] { [] }
    func exactFingerprint(for asset: UniversalMediaAsset, allowNetwork: Bool, progress: @escaping @Sendable (Int64) -> Void) async throws -> UniversalExactFingerprint {
        try Data([9, 8, 7, 6]).write(to: url); return .init(digest: "changed", byteCount: 4)
    }
}
