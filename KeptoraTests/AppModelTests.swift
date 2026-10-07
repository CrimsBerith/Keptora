import XCTest
import KeptoraCore
@testable import Keptora

@MainActor
final class AppModelTests: XCTestCase {
    func testReviewReasonLabelsFollowTheChosenAppLanguage() {
        let defaults = UserDefaults.standard, key = "Keptora.AppLanguage", previous = defaults.object(forKey: "Keptora.AppLanguage")
        defer { if let previous { defaults.set(previous, forKey: key) } else { defaults.removeObject(forKey: key) } }
        let evidence = ReviewDecisionEvidence(groupID: "g", assetID: .init(rawValue: "a"), decision: .keep, actor: "user",
            reasonCode: "user-selected-keeper", decidedAt: Date(), exactDigest: "digest", canonicalAssetID: .init(rawValue: "a"),
            proofState: .selectedKeeper, familyID: nil, familyKind: nil, familyRole: nil)
        for (language, expected, groupTitle) in [("en", "Photo to keep chosen by you", "Group 4 of 8"),
                                               ("tr", "Saklanacak fotoğrafı siz seçtiniz", "Grup 4 / 8"),
                                               ("fr", "Photo à conserver choisie par vous", "Groupe 4 sur 8"),
                                               ("de", "Von Ihnen zum Behalten ausgewähltes Foto", "Gruppe 4 von 8")] {
            defaults.set(language, forKey: key); XCTAssertEqual(evidence.reasonLabel, expected)
            XCTAssertEqual(ReviewText.format("Group %1$lld of %2$lld", Int64(4), Int64(8)), groupTitle)
            XCTAssertEqual(L10n.format("Group %1$lld of %2$lld", Int64(4), Int64(8)), groupTitle)
        }
    }
    func testProtectedPhotosRequireExplicitUnprotectForManualAndBulkSelection() {
        let model = MacArchiveModel(persistentSession: false)
        let photo = UniversalMediaAsset(id: UUID().uuidString, sourceID: "test", reference: .photoLibrary(localIdentifier: "a"), displayName: "a.jpg", mediaKind: .image)
        model.assets = [photo]; model.toggleProtection(photo)
        model.toggleSelection(photo); model.selectItems([photo]); model.setSelection([photo.id])
        XCTAssertTrue(model.selection.isEmpty)
        model.unprotectAndSelect(photo)
        XCTAssertEqual(model.selection, [photo.id]); XCTAssertFalse(model.decisions.protectedIDs.contains(photo.id))
        model.undoSelection(); XCTAssertTrue(model.selection.isEmpty); XCTAssertTrue(model.decisions.protectedIDs.contains(photo.id))
    }
    func testSuggestionCategoryClearsUnrelatedFiltersPreservesSourcesBasketAndTimelineBadges() {
        let model = MacArchiveModel(persistentSession: false), id = UUID().uuidString
        let a = UniversalMediaAsset(id: id + "a", sourceID: LibrarySource.photos.id, reference: .photoLibrary(localIdentifier: id + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = a.with(id: id + "b", reference: .photoLibrary(localIdentifier: id + "b"), displayName: "b.jpg")
        model.assets = [a, b]; model.photosConnected = true; model.selection = [b.id]
        model.exact = [.init(digest: id, assets: [a, b], keeperID: a.id)]
        model.galleryContext.search = "missing"; model.galleryContext.albumID = "missing"; model.galleryContext.media = 2
        let sources = model.scanSourceSelection
        model.openFinding(.copies)
        XCTAssertEqual(model.gallery.visible.count, 2); XCTAssertEqual(model.selection, [b.id]); XCTAssertEqual(model.scanSourceSelection, sources)
        model.galleryContext.smartOrder = false
        XCTAssertEqual(model.gallery.membership[a.id]?.first?.kind, .exact)
        XCTAssertEqual(model.gallery.keeperBadges[a.id], "Suggested Keep")
    }
    func testThreeThousandItemProjectionIsReusedDuringSelectionAndProgress() {
        let model = MacArchiveModel(persistentSession: false); model.photosConnected = true
        model.assets = (0..<3_000).map { n in .init(id: "\(n)", sourceID: LibrarySource.photos.id,
            reference: .photoLibrary(localIdentifier: "\(n)"), displayName: "\(n).jpg", mediaKind: .image) }
        XCTAssertEqual(model.gallery.visible.count, 3_000)
        let builds = model.galleryProjectionBuilds
        for item in model.assets.prefix(100) { model.toggleSelection(item); _ = model.gallery }
        model.sessionProgress.update(.exact, .init(status: .running, processed: 100, total: 3_000)); _ = model.gallery
        XCTAssertEqual(model.galleryProjectionBuilds, builds)
        model.galleryContext.media = 2; XCTAssertTrue(model.gallery.visible.isEmpty)
        XCTAssertEqual(model.galleryProjectionBuilds, builds + 1)
    }
    func testUnreadableSessionBlocksMutationsAndQuitAndPreservesOriginalDuringRepair() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("session.json"), broken = Data("unreadable original".utf8)
        try broken.write(to: url)
        let model = MacArchiveModel(repositoryURL: url)
        await model.restoreConnections(loadSources: false)
        XCTAssertEqual(model.persistenceHealth, .unreadable); XCTAssertFalse(model.canEditLibrary)
        model.setSelection(["unexpected"]); XCTAssertTrue(model.selection.isEmpty)
        let saved = await model.flushState(); XCTAssertFalse(saved)
        XCTAssertEqual(try Data(contentsOf: url), broken)
        await model.repairPersistence(); XCTAssertEqual(model.persistenceHealth, .healthy)
        let originals = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.contains("unreadable-") }
        XCTAssertEqual(originals.count, 1); XCTAssertEqual(try Data(contentsOf: XCTUnwrap(originals.first)), broken)
    }
    func testWriteFailureKeepsSelectionBlocksCleanupAndCanBeRetried() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocker = root.appendingPathComponent("blocker"); try Data([1]).write(to: blocker)
        let model = MacArchiveModel(repositoryURL: blocker.appendingPathComponent("session.json"))
        await model.restoreConnections(loadSources: false); model.selection = ["kept"]
        let saved = await model.flushState(); XCTAssertFalse(saved)
        XCTAssertEqual(model.persistenceHealth, .writeFailed); XCTAssertFalse(model.canRemoveSelection)
        model.setSelection([]); XCTAssertEqual(model.selection, ["kept"])
        try FileManager.default.removeItem(at: blocker)
        await model.repairPersistence(); XCTAssertEqual(model.persistenceHealth, .healthy); XCTAssertEqual(model.selection, ["kept"])
    }
    func testFrequentContextWritesDoNotRewriteFullAnalysisCache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("session.json"), model = MacArchiveModel(repositoryURL: url)
        await model.restoreConnections(loadSources: false)
        model.assets = (0..<3_000).map { n in .init(id: "\(n)", sourceID: LibrarySource.photos.id,
            reference: .photoLibrary(localIdentifier: "\(n)"), displayName: "\(n).jpg", mediaKind: .image) }
        let issue = AnalysisIssue(assetID: "2", sourceID: LibrarySource.photos.id, stage: .exact, reason: .downloadRequired)
        model.analysisIssues = [issue]
        let saved = await model.flushState(); XCTAssertTrue(saved)
        let cacheURL = url.appendingPathExtension("analysis-cache"), cache = try Data(contentsOf: cacheURL)
        model.galleryContext.search = "holiday"; model.selection = ["1"]
        let contextSaved = await model.flushState(includeAnalysis: false); XCTAssertTrue(contextSaved)
        XCTAssertEqual(try Data(contentsOf: cacheURL), cache)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let value = try XCTUnwrap(json["value"] as? [String: Any]); XCTAssertNil(value["analysis"])
        XCTAssertGreaterThan(cache.count, try Data(contentsOf: url).count * 10)
        let reopened = MacArchiveModel(repositoryURL: url)
        await reopened.restoreConnections(loadSources: false)
        XCTAssertEqual(reopened.analysisIssues, [issue]); XCTAssertEqual(reopened.skippedCloudItems, 1)
    }
    func testBothMacWorkflowsShareStorageOperationAvailabilityAndPaywallHost() throws {
        let owner = LibraryOperationCoordinator(), archive = MacArchiveModel(persistentSession: false, operations: owner)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = AppModel(applicationSupportDirectory: root, operations: owner)
        XCTAssertTrue(legacy.operations === archive.operations)
        owner.beginTermination(); XCTAssertFalse(archive.canEditLibrary); owner.resumeAfterCancelledTermination()
        let store = StoreEntitlementController(); store.presentPaywall(.settings, host: .settings)
        XCTAssertFalse(store.paywallBinding(for: .main).wrappedValue); XCTAssertTrue(store.paywallBinding(for: .settings).wrappedValue)
        store.paywallBinding(for: .main).wrappedValue = false; XCTAssertTrue(store.isShowingPaywall)
        store.paywallBinding(for: .settings).wrappedValue = false; XCTAssertFalse(store.isShowingPaywall)
    }
    func testUnifiedRecommendationAllowanceDoesNotLimitManualSelection() {
        let model = MacArchiveModel(persistentSession: false), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        model.assets = [a, b]; model.exact = [.init(digest: namespace, assets: [a, b], keeperID: a.id)]
        model.authorizeSuggestions = { _ in false }
        model.selectExactSuggestions(); XCTAssertTrue(model.selection.isEmpty)
        model.toggleSelection(b); XCTAssertEqual(model.selection, [b.id])
    }
    func testUnifiedSelectionUsesNativeUndoManager() {
        let model = MacArchiveModel(persistentSession: false), manager = UndoManager()
        manager.groupsByEvent = false; model.undoManager = manager
        let item = UniversalMediaAsset(id: UUID().uuidString, sourceID: "test", reference: .photoLibrary(localIdentifier: "a"), displayName: "a.jpg", mediaKind: .image)
        model.assets = [item]
        manager.beginUndoGrouping(); model.toggleSelection(item); manager.endUndoGrouping()
        model.busy = true; model.undoSelection()
        XCTAssertTrue(manager.canUndo); XCTAssertEqual(model.selection, [item.id])
        model.busy = false
        XCTAssertTrue(manager.canUndo); manager.undo()
        XCTAssertTrue(model.selection.isEmpty); XCTAssertFalse(model.canUndoSelection)
        XCTAssertTrue(manager.canRedo); manager.redo(); XCTAssertEqual(model.selection, [item.id])
    }
    func testUnifiedDiagnosticsRedactPathsNamesAndRawErrors() throws {
        let model = MacArchiveModel(persistentSession: false), secret = "private-photo-" + UUID().uuidString
        model.assets = [.init(id: secret, sourceID: secret, reference: .file(URL(fileURLWithPath: "/private/" + secret)), displayName: secret, mediaKind: .image)]
        model.error = "Cannot open /private/" + secret
        let json = String(decoding: try model.diagnosticData(), as: UTF8.self)
        XCTAssertFalse(json.contains(secret)); XCTAssertFalse(json.contains("/private/")); XCTAssertTrue(json.contains("hasError"))
    }
    func testUnifiedRemovalAndRestoreCannotStartDuringAnalysis() async {
        let model = MacArchiveModel(persistentSession: false); model.analyzing = true
        let result = await model.removeSelection(expectedIDs: [])
        XCTAssertFalse(result); XCTAssertFalse(model.busy)
        let entry = MacRecoveryEntry(id: UUID(), date: Date(), count: 1, bytes: 1,
            folderRecord: .init(sourceRoot: URL(fileURLWithPath: "/unavailable"), operations: []), bookmark: nil, isPhotos: false)
        await model.restore(entry)
        XCTAssertFalse(model.busy); XCTAssertNil(model.error)
    }
    func testFinalReviewRejectsChangedSelectionAndRestoredStaleRevision() async {
        let model = MacArchiveModel(persistentSession: false), id = UUID().uuidString
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
        let model = MacArchiveModel(persistentSession: false), namespace = UUID().uuidString
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
        let model = MacArchiveModel(persistentSession: false), namespace = UUID().uuidString
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
        let model = MacArchiveModel(persistentSession: false), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        model.assets = [a, b]; model.exact = [UniversalExactGroup(digest: namespace, assets: [a, b], keeperID: a.id)]
        let group = model.reviewGroups[0]
        model.selection = [a.id, b.id]; model.keep(b, in: [group])
        let keptDecision = model.decisions
        model.protect(group); model.undoSelection()
        XCTAssertEqual(model.selection, [a.id]); XCTAssertEqual(model.decisions, keptDecision)
        XCTAssertTrue(model.canUndoSelection)
        model.undoSelection(); XCTAssertEqual(model.selection, [a.id, b.id])
    }

    func testArchiveSelectionUndoSurvivesEmptySelectionButExcludesRemovedItems() {
        let model = MacArchiveModel(persistentSession: false), namespace = UUID().uuidString
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
