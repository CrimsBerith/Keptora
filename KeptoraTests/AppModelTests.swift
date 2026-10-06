import XCTest
import KeptoraCore
@testable import Keptora

@MainActor
final class AppModelTests: XCTestCase {
    func testUnifiedRecommendationAllowanceDoesNotLimitManualSelection() {
        let model = MacArchiveModel(), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        model.assets = [a, b]; model.exact = [.init(digest: namespace, assets: [a, b], keeperID: a.id)]
        model.authorizeSuggestions = { _ in false }
        model.selectExactSuggestions(); XCTAssertTrue(model.selection.isEmpty)
        model.toggleSelection(b); XCTAssertEqual(model.selection, [b.id])
    }
    func testUnifiedSelectionUsesNativeUndoManager() {
        let model = MacArchiveModel(), manager = UndoManager()
        manager.groupsByEvent = false; model.undoManager = manager
        let item = UniversalMediaAsset(id: UUID().uuidString, sourceID: "test", reference: .photoLibrary(localIdentifier: "a"), displayName: "a.jpg", mediaKind: .image)
        model.assets = [item]
        manager.beginUndoGrouping(); model.toggleSelection(item); manager.endUndoGrouping()
        XCTAssertTrue(manager.canUndo); manager.undo()
        XCTAssertTrue(model.selection.isEmpty); XCTAssertFalse(model.canUndoSelection)
    }
    func testUnifiedDiagnosticsRedactPathsNamesAndRawErrors() throws {
        let model = MacArchiveModel(), secret = "private-photo-" + UUID().uuidString
        model.assets = [.init(id: secret, sourceID: secret, reference: .file(URL(fileURLWithPath: "/private/" + secret)), displayName: secret, mediaKind: .image)]
        model.error = "Cannot open /private/" + secret
        let json = String(decoding: try model.diagnosticData(), as: UTF8.self)
        XCTAssertFalse(json.contains(secret)); XCTAssertFalse(json.contains("/private/")); XCTAssertTrue(json.contains("hasError"))
    }
    func testUnifiedRemovalAndRestoreCannotStartDuringAnalysis() async {
        let model = MacArchiveModel(); model.analyzing = true
        let result = await model.removeSelection(expectedIDs: [])
        XCTAssertFalse(result); XCTAssertFalse(model.busy)
        let entry = MacRecoveryEntry(id: UUID(), date: Date(), count: 1, bytes: 1,
            folderRecord: .init(sourceRoot: URL(fileURLWithPath: "/unavailable"), operations: []), bookmark: nil, isPhotos: false)
        await model.restore(entry)
        XCTAssertFalse(model.busy); XCTAssertNil(model.error)
    }
    func testFinalReviewRejectsChangedSelectionAndRestoredStaleRevision() async {
        let model = MacArchiveModel(), id = UUID().uuidString
        let original = UniversalMediaAsset(id: id, sourceID: "test", reference: .photoLibrary(localIdentifier: id), displayName: "a.jpg", mediaKind: .image, byteCount: 100)
        model.assets = [original]; model.selection = []
        let changedSelection = await model.removeSelection(expectedIDs: [id], reviewedAssets: [original])
        XCTAssertFalse(changedSelection)
        XCTAssertEqual(model.error, L10n.tr("Your selection changed. Review it again before removing items."))
        var review = FrozenSelectionReview([original])
        review.remove(id); review.undoRemoval()
        model.error = nil; model.selection = [id]; model.assets = [original.with(byteCount: .some(999))]
        let staleRevision = await model.removeSelection(expectedIDs: [id], reviewedAssets: review.items)
        XCTAssertFalse(staleRevision)
        XCTAssertEqual(model.error, L10n.tr("Your selection changed. Review it again before removing items."))
        XCTAssertEqual(model.selection, [id])
        XCTAssertFalse(model.busy)
    }

    func testRepeatedArchiveDecisionsPreserveMeaningfulUndo() {
        let model = MacArchiveModel(), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        model.assets = [a, b]; model.decisions = LibraryReviewDecisions()
        model.exact = [UniversalExactGroup(digest: namespace, assets: [a, b], keeperID: a.id)]
        let group = model.reviewGroups[0], original = model.decisions
        model.selection = [a.id, b.id]
        model.keep(b, in: group); model.keep(b, in: group); model.undoSelection()
        XCTAssertEqual(model.selection, [a.id, b.id]); XCTAssertEqual(model.decisions, original)
        model.protect(group); model.protect(group); model.undoSelection()
        XCTAssertEqual(model.selection, [a.id, b.id]); XCTAssertEqual(model.decisions, original)
    }

    func testArchiveCopySuggestionsRespectVisibleScopeAndKeepOutsideSelection() {
        let model = MacArchiveModel(), namespace = UUID().uuidString
        let items = (0..<3).map { n in UniversalMediaAsset(id: namespace + "\(n)", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "\(n)"), displayName: "\(n).jpg", mediaKind: .image) }
        model.assets = items; model.decisions = LibraryReviewDecisions()
        model.exact = [UniversalExactGroup(digest: namespace, assets: items, keeperID: items[0].id)]
        model.selection = [items[2].id]
        model.selectExactSuggestions(visibleIDs: [items[1].id])
        XCTAssertEqual(model.selection, [items[1].id, items[2].id])
        model.selectExactSuggestions(visibleIDs: [items[1].id]); model.undoSelection()
        XCTAssertEqual(model.selection, [items[2].id])
        model.selectOthers(in: model.reviewGroups[0], visibleIDs: [items[1].id])
        XCTAssertEqual(model.selection, [items[1].id, items[2].id])
    }

    func testArchiveSelectionUndoRestoresProtectionAndKeeperTogether() {
        let model = MacArchiveModel(), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        model.assets = [a, b]; model.exact = [UniversalExactGroup(digest: namespace, assets: [a, b], keeperID: a.id)]
        let group = model.reviewGroups[0]
        model.selection = [a.id, b.id]; model.keep(b, in: [group])
        let keptDecision = model.decisions
        model.protect(group); model.undoSelection()
        XCTAssertEqual(model.selection, [a.id]); XCTAssertEqual(model.decisions, keptDecision)
        XCTAssertFalse(model.canUndoSelection)
    }

    func testArchiveSelectionUndoSurvivesEmptySelectionButExcludesRemovedItems() {
        let model = MacArchiveModel(), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        model.assets = [a, b]; model.selection = [a.id, b.id]
        model.setSelection([]); model.setSelection([])
        XCTAssertTrue(model.canUndoSelection)
        model.assets = [b]; model.undoSelection()
        XCTAssertEqual(model.selection, [b.id])
    }

    func testKeeperCanNeverBeQueuedForQuarantine() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = AppModel(applicationSupportDirectory: directory)
        await model.prepare()

        let keeperID = AssetID(rawValue: "keeper-1")
        let copyID = AssetID(rawValue: "copy-1")
        let groupID = "test-group"

        let keeper = ReviewAsset(
            id: keeperID, displayName: "keeper.jpg", fileURL: URL(fileURLWithPath: "/tmp/keeper.jpg"),
            byteCount: 100, modificationDate: Date(), digest: "digest1"
        )
        let copy = ReviewAsset(
            id: copyID, displayName: "copy.jpg", fileURL: URL(fileURLWithPath: "/tmp/copy.jpg"),
            byteCount: 100, modificationDate: Date(), digest: "digest1"
        )

        let group = ReviewGroup(
            id: groupID,
            kind: "exact",
            confidence: "high",
            digest: "digest1",
            reclaimableBytes: 100,
            canonicalAssetID: keeperID,
            assets: [keeper, copy]
        )

        model.duplicateGroups = [group]
        let store = StoreEntitlementController()

        // Attempt to mark the canonical keeper as .quarantinePlan
        model.setDecision(.quarantinePlan, for: keeperID, access: store)

        // It should be blocked synchronously and never stored
        XCTAssertNil(model.decisions[keeperID])
        XCTAssertFalse(store.reviewedAssetIDs.contains(keeperID.rawValue))

        // But marking copy as .quarantinePlan should be accepted
        model.setDecision(.quarantinePlan, for: copyID, access: store)
        XCTAssertEqual(model.decisions[copyID], .quarantinePlan)
    }

    func testBatchActionQuarantinePlanProtectsKeeper() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = AppModel(applicationSupportDirectory: directory)
        await model.prepare()

        let keeperID = AssetID(rawValue: "keeper-2")
        let copy1ID = AssetID(rawValue: "copy-2A")
        let copy2ID = AssetID(rawValue: "copy-2B")
        let groupID = "batch-group"

        let keeper = ReviewAsset(
            id: keeperID, displayName: "keeper.jpg", fileURL: URL(fileURLWithPath: "/tmp/keeper.jpg"),
            byteCount: 100, modificationDate: Date(), digest: "digest2"
        )
        let copy1 = ReviewAsset(
            id: copy1ID, displayName: "copy1.jpg", fileURL: URL(fileURLWithPath: "/tmp/copy1.jpg"),
            byteCount: 100, modificationDate: Date(), digest: "digest2"
        )
        let copy2 = ReviewAsset(
            id: copy2ID, displayName: "copy2.jpg", fileURL: URL(fileURLWithPath: "/tmp/copy2.jpg"),
            byteCount: 100, modificationDate: Date(), digest: "digest2"
        )

        let group = ReviewGroup(
            id: groupID,
            kind: "exact",
            confidence: "high",
            digest: "digest2",
            reclaimableBytes: 200,
            canonicalAssetID: keeperID,
            assets: [keeper, copy1, copy2]
        )

        model.duplicateGroups = [group]
        let store = StoreEntitlementController()

        model.applyBatchAction(.planSafeExtras, to: groupID, access: store)

        // Extras should be planned
        XCTAssertEqual(model.decisions[copy1ID], .quarantinePlan)
        XCTAssertEqual(model.decisions[copy2ID], .quarantinePlan)

        // Keeper must remain completely untouched
        XCTAssertNil(model.decisions[keeperID])
    }

    func testUniquingKeysWithPreventsCrashOnDuplicateAssetRecords() {
        struct StoredDecision {
            let assetID: AssetID
            let decision: ReviewDecision
        }

        let id = AssetID(rawValue: "duplicate-asset")
        let stored = [
            StoredDecision(assetID: id, decision: .skip),
            StoredDecision(assetID: id, decision: .quarantinePlan)
        ]

        let decisions = Dictionary(stored.map { ($0.assetID, $0.decision) }, uniquingKeysWith: { _, newer in newer })
        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(decisions[id], .quarantinePlan)
    }

    func testPrepareIdempotency() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = AppModel(applicationSupportDirectory: directory)
        await model.prepare()
        let initialGroups = model.duplicateGroups.count
        await model.prepare()
        XCTAssertEqual(model.duplicateGroups.count, initialGroups)
    }
}
