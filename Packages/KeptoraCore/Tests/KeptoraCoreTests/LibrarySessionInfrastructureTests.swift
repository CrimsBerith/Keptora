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
            mediaKind: .image, byteCount: Int64(values.fileSize ?? 0), modificationDate: values.contentModificationDate)
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
