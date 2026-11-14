import XCTest
import KeptoraCore
@testable import KeptoraiOS

@MainActor
final class KeptoraiOSEdgeCaseTests: XCTestCase {

    func testPartialRollbackPreservesRecoveryReceiptAndOnlyRemovesMovedItemsFromSelection() async throws {
        let defaults = UserDefaults.standard
        let keys = [AppStorageKeys.iOSCleanupHistory, "Keptora.ManualSelection.unified.iOS"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstURL = root.appendingPathComponent("a.jpg"), secondURL = root.appendingPathComponent("b.jpg")
        let firstBytes = Data("first original".utf8), secondBytes = Data("second original".utf8)
        let occupiedBytes = Data("new file at original path; must not be overwritten".utf8)
        try firstBytes.write(to: firstURL)
        try secondBytes.write(to: secondURL)
        let executor = FolderQuarantineExecutor(beforeQuarantineMove: { _, index in
            guard index == 1 else { return }
            try occupiedBytes.write(to: firstURL)
            throw CocoaError(.fileWriteUnknown)
        })
        let store = MobileKeptoraStore(folderCleanup: executor)
        store.connectLocalFolderForTesting(root)
        await store.loadCatalogue()
        let items = store.assets.sorted { $0.displayName < $1.displayName }
        XCTAssertEqual(items.count, 2)
        store.replaceAssetsForTesting(items)
        store.selectedLibraryIDs = Set(items.map(\.id))

        let removed = await store.cleanupLibrarySelection(expectedIDs: store.selectedLibraryIDs, reviewedAssets: items)

        XCTAssertFalse(removed)
        XCTAssertEqual(store.selectedLibraryIDs, [items[1].id])
        XCTAssertTrue(store.errorMessage?.hasPrefix(L10n.format("Moved: %lld items. Not moved: %lld items. See History for recovery.", 1, 1)) == true)
        let receipt = try XCTUnwrap(store.history.first { $0.folderRecord?.sourceRoot == root })
        XCTAssertEqual(receipt.itemCount, 1)
        XCTAssertEqual(receipt.folderRecord?.movedCount, 1)
        let operation = try XCTUnwrap(receipt.folderRecord?.operations.first { $0.state == .moved })
        XCTAssertEqual(try Data(contentsOf: operation.quarantineURL), firstBytes)
        XCTAssertEqual(try Data(contentsOf: firstURL), occupiedBytes)
        XCTAssertEqual(try Data(contentsOf: secondURL), secondBytes)
        XCTAssertFalse(store.isCleaningUp)
    }

    func testProtectedItemsStayOutOfManualAndBulkSelection() {
        let defaults = UserDefaults.standard, key = "Keptora.ReviewDecisions.iOS"
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let protected = photo(namespace + "protected"), other = photo(namespace + "other")
        store.replaceAssetsForTesting([protected, other])
        store.selectedLibraryIDs = []
        store.decisions = LibraryReviewDecisions()
        store.toggleProtection(protected)

        store.toggleLibrarySelection(protected)
        XCTAssertTrue(store.selectedLibraryIDs.isEmpty)
        store.selectLibraryItems([protected, other])
        XCTAssertEqual(store.selectedLibraryIDs, [other.id])
        store.replaceLibrarySelection([protected.id])
        XCTAssertTrue(store.selectedLibraryIDs.isEmpty)
        store.unprotectAndSelect(protected)
        XCTAssertEqual(store.selectedLibraryIDs, [protected.id])
        XCTAssertFalse(store.decisions.protectedIDs.contains(protected.id))
        store.undoLibrarySelection()
        XCTAssertTrue(store.selectedLibraryIDs.isEmpty)
        XCTAssertTrue(store.decisions.protectedIDs.contains(protected.id))
    }

    func testRemovalRejectsPreviouslySelectedProtectedFileWithoutMovingIt() async throws {
        let defaults = UserDefaults.standard
        let keys = [AppStorageKeys.iOSCleanupHistory, "Keptora.ReviewDecisions.iOS", "Keptora.ManualSelection.unified.iOS"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("protected.jpg"), bytes = Data("protected original".utf8)
        try bytes.write(to: original)
        let store = MobileKeptoraStore()
        store.connectLocalFolderForTesting(root)
        await store.loadCatalogue()
        let asset = try XCTUnwrap(store.assets.first)
        store.decisions = LibraryReviewDecisions()
        store.decisions.toggleProtection(asset.id)
        // Simulate a selection restored from an older version, bypassing UI guards.
        store.selectedLibraryIDs = [asset.id]
        let history = store.history

        let removed = await store.cleanupLibrarySelection(expectedIDs: [asset.id], reviewedAssets: [asset])

        XCTAssertFalse(removed)
        XCTAssertEqual(try? Data(contentsOf: original), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".Keptora Quarantine").path))
        XCTAssertEqual(store.history, history)
        XCTAssertNotNil(store.errorMessage)
    }

    func testRecoveryReloadShowsCorruptRecordBesideHealthyRecordAndClearsWarningAfterRepair() async throws {
        let defaults = UserDefaults.standard
        let historyKey = AppStorageKeys.iOSCleanupHistory
        let previousHistory = defaults.object(forKey: historyKey)
        defer {
            if let previousHistory { defaults.set(previousHistory, forKey: historyKey) }
            else { defaults.removeObject(forKey: historyKey) }
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("recoverable photo".utf8).write(to: root.appendingPathComponent("photo.jpg"))
        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: true)
        let assets = try await adapter.enumerateAssets()
        let selections = try await LibraryCleanupPreflight().prepare(assets, adapter: adapter)
        let record = try await FolderQuarantineExecutor().quarantine(root: root, selections: selections)
        let corruptID = UUID()
        let corruptDirectory = root.appendingPathComponent(".Keptora Quarantine/\(corruptID.uuidString)")
        try FileManager.default.createDirectory(at: corruptDirectory, withIntermediateDirectories: true)
        let manifest = corruptDirectory.appendingPathComponent("recovery.json")
        try Data("broken manifest".utf8).write(to: manifest)

        let store = MobileKeptoraStore()
        store.connectLocalFolderForTesting(root)
        await store.loadCatalogue()
        XCTAssertNil(store.catalogueError)
        XCTAssertEqual(store.recoveryCatalogueIssues.map(\.manifestURL), [manifest])
        XCTAssertTrue(store.history.contains { $0.id == record.id })
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.operations[0].quarantineURL.path))

        let repaired = FolderQuarantineRecord(id: corruptID, sourceRoot: root, operations: [])
        try JSONEncoder().encode(repaired).write(to: manifest, options: .atomic)
        await store.loadCatalogue()
        XCTAssertTrue(store.recoveryCatalogueIssues.isEmpty)
        XCTAssertTrue(store.history.contains { $0.id == record.id })
    }

    private func photo(_ id: String, bytes: Int64 = 1_000, modified: Double = 1_700_000_000) -> UniversalMediaAsset {
        UniversalMediaAsset(id: id, sourceID: "photos", reference: .photoLibrary(localIdentifier: id), displayName: id + ".jpg",
                            mediaKind: .image, byteCount: bytes, modificationDate: Date(timeIntervalSince1970: modified))
    }

    func testRemovingOneItemKeepsTheSimilarGroupsKeeperAndStrength() {
        let store = MobileKeptoraStore(), ns = UUID().uuidString
        let a = photo(ns + "a", bytes: 1_000), b = photo(ns + "b", bytes: 3_000), c = photo(ns + "c", bytes: 2_000)
        store.replaceAssetsForTesting([a, b, c])
        // The analyzer chose `a` although the default keeper order would prefer the larger `b`.
        store.replaceSimilarityGroupsForTesting([UniversalSimilarityGroup(id: ns, assets: [a, b, c], maximumDistance: 0.1, strength: .verySimilar, mediaKind: .image, keeperID: a.id)])
        store.reconcileRemoved([c.id])
        XCTAssertEqual(store.similarityGroups.first?.keeperID, a.id)
        XCTAssertEqual(store.similarityGroups.first?.strength, .verySimilar)
        XCTAssertEqual(store.similarityGroups.first?.assets.count, 2)
    }

    func testSelectSimilarSuggestionsSelectsOnlyCandidatesAndPreservesKeepers() {
        let store = MobileKeptoraStore(), ns = UUID().uuidString
        let a = photo(ns + "a", bytes: 1_000), b = photo(ns + "b", bytes: 3_000), c = photo(ns + "c", bytes: 2_000)
        store.replaceAssetsForTesting([a, b, c])
        store.replaceSimilarityGroupsForTesting([UniversalSimilarityGroup(id: ns, assets: [a, b, c], maximumDistance: 0.1, strength: .verySimilar, mediaKind: .image, keeperID: a.id)])

        let candidates = store.similarSuggestionCandidates()
        XCTAssertEqual(Set(candidates.map(\.id)), [b.id, c.id])
        XCTAssertFalse(candidates.contains(where: { $0.id == a.id }), "Keeper must never be suggested")

        let didSelect = store.selectSimilarSuggestions(isUnlocked: true)
        XCTAssertTrue(didSelect)
        XCTAssertEqual(store.selectedLibraryIDs, Set([b.id, c.id]))
        XCTAssertFalse(store.selectedLibraryIDs.contains(a.id))

        // Removal intent must be .suggestedCopies
        XCTAssertEqual(store.removalIntent(for: store.librarySelection), .suggestedCopies)
    }

    func testSelectSimilarSuggestionsEnforcesFreeReviewPolicyAndProtection() {
        let store = MobileKeptoraStore(), ns = UUID().uuidString
        let a = photo(ns + "a"), b = photo(ns + "b"), c = photo(ns + "c")
        store.replaceAssetsForTesting([a, b, c])
        store.replaceSimilarityGroupsForTesting([UniversalSimilarityGroup(id: ns, assets: [a, b, c], maximumDistance: 0.1, strength: .verySimilar, mediaKind: .image, keeperID: a.id)])

        // Protect b: b should no longer be in similar candidates
        store.toggleProtection(b)
        XCTAssertEqual(store.similarSuggestionCandidates().map(\.id), [c.id])

        // Unprotect b: both b and c are candidates
        store.toggleProtection(b)
        XCTAssertEqual(Set(store.similarSuggestionCandidates().map(\.id)), [b.id, c.id])

        // Exceed free limit
        let dummyIDs = Set((0..<100).map { "dummy_\($0)" })
        UserDefaults.standard.set(Array(dummyIDs), forKey: AppStorageKeys.iOSReviewedAssets)
        defer { UserDefaults.standard.removeObject(forKey: AppStorageKeys.iOSReviewedAssets) }
        let restrictedStore = MobileKeptoraStore()
        restrictedStore.replaceAssetsForTesting([a, b, c])
        restrictedStore.replaceSimilarityGroupsForTesting([UniversalSimilarityGroup(id: ns, assets: [a, b, c], maximumDistance: 0.1, strength: .verySimilar, mediaKind: .image, keeperID: a.id)])

        let didSelectLocked = restrictedStore.selectSimilarSuggestions(isUnlocked: false)
        XCTAssertFalse(didSelectLocked, "Free tier must reject review when exceeding limit")
        XCTAssertTrue(restrictedStore.selectedLibraryIDs.isEmpty)

        // With isUnlocked: true, succeeds
        let didSelectUnlocked = restrictedStore.selectSimilarSuggestions(isUnlocked: true)
        XCTAssertTrue(didSelectUnlocked)
        XCTAssertEqual(restrictedStore.selectedLibraryIDs, Set([b.id, c.id]))
    }

    func testCatalogueChangeKeepsResultsForUnchangedItems() {
        let store = MobileKeptoraStore(), ns = UUID().uuidString
        let a = photo(ns + "a"), b = photo(ns + "b"), c = photo(ns + "c"), d = photo(ns + "d")
        store.replaceAssetsForTesting([a, b, c, d])
        store.exactGroups = [UniversalExactGroup(digest: ns + "ab", assets: [a, b], keeperID: a.id),
                             UniversalExactGroup(digest: ns + "cd", assets: [c, d], keeperID: c.id)]
        store.replaceSimilarityGroupsForTesting([UniversalSimilarityGroup(id: ns, assets: [a, b], maximumDistance: 0.1, strength: .verySimilar, mediaKind: .image, keeperID: b.id)])
        // `d` was edited; `a`, `b` and `c` did not change.
        store.keepResults(for: [a.id, b.id, c.id])
        XCTAssertEqual(store.exactGroups.map(\.digest), [ns + "ab"])
        XCTAssertEqual(store.similarityGroups.first?.keeperID, b.id)
        XCTAssertEqual(store.similarityGroups.first?.strength, .verySimilar)
    }

    func testRepeatedKeeperAndProtectionActionsPreserveLastMeaningfulUndo() {
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        store.replaceAssetsForTesting([a, b]); store.decisions = LibraryReviewDecisions()
        store.exactGroups = [UniversalExactGroup(digest: namespace, assets: [a, b], keeperID: a.id)]
        let group = store.reviewGroups[0], original = store.decisions
        store.selectedLibraryIDs = [a.id, b.id]
        store.keep(b, in: group); store.keep(b, in: group); store.undoLibrarySelection()
        XCTAssertEqual(store.selectedLibraryIDs, [a.id, b.id]); XCTAssertEqual(store.decisions, original)
        store.protect(group); store.protect(group); store.undoLibrarySelection()
        XCTAssertEqual(store.selectedLibraryIDs, [a.id, b.id]); XCTAssertEqual(store.decisions, original)
    }

    func testScopedCopySuggestionDoesNotSelectHiddenItemsOrReauthorizeNoOp() {
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let items = (0..<102).map { n in UniversalMediaAsset(id: namespace + "\(n)", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "\(n)"), displayName: "\(n).jpg", mediaKind: .image) }
        store.replaceAssetsForTesting(items); store.decisions = LibraryReviewDecisions(); store.selectedLibraryIDs = []
        store.exactGroups = [UniversalExactGroup(digest: namespace, assets: items, keeperID: items[0].id)]
        XCTAssertTrue(store.selectExactSuggestions(isUnlocked: true, visibleIDs: [items[1].id]))
        XCTAssertEqual(store.selectedLibraryIDs, [items[1].id])
        store.replaceLibrarySelection([])
        XCTAssertTrue(store.selectOthers(in: store.reviewGroups[0], isUnlocked: true, visibleIDs: [items[1].id]))
        XCTAssertEqual(store.selectedLibraryIDs, [items[1].id])
        store.selectedLibraryIDs = Set(items.dropFirst().map(\.id))
        XCTAssertTrue(store.selectExactSuggestions(isUnlocked: false), "Already selected items do not consume review allowance")
        XCTAssertTrue(store.selectOthers(in: store.reviewGroups[0], isUnlocked: false))
    }

    func testUndoWorksAfterLastItemIsDeselectedAndClearIsNoOp() {
        let store = MobileKeptoraStore(), id = UUID().uuidString
        let asset = UniversalMediaAsset(id: id, sourceID: "test", reference: .photoLibrary(localIdentifier: id), displayName: "photo.jpg", mediaKind: .image)
        store.replaceAssetsForTesting([asset]); store.selectedLibraryIDs = []
        store.toggleLibrarySelection(asset); store.toggleLibrarySelection(asset)
        XCTAssertTrue(store.selectedLibraryIDs.isEmpty)
        XCTAssertTrue(store.canUndoLibrarySelection)
        store.replaceLibrarySelection([]) // A disabled/no-op clear must not overwrite the last edit.
        store.undoLibrarySelection()
        XCTAssertEqual(store.selectedLibraryIDs, [id])
        XCTAssertFalse(store.canUndoLibrarySelection)
    }

    func testUndoGroupProtectionRestoresSelectionAndKeeperDecisionTogether() {
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        store.replaceAssetsForTesting([a, b]); store.exactGroups = [UniversalExactGroup(digest: namespace, assets: [a, b], keeperID: a.id)]
        let group = store.reviewGroups[0]
        store.selectedLibraryIDs = [a.id, b.id]
        store.keep(b, in: group)
        let keptDecision = store.decisions
        store.protect(group); store.undoLibrarySelection()
        XCTAssertEqual(store.selectedLibraryIDs, [a.id])
        XCTAssertEqual(store.decisions, keptDecision)
        XCTAssertEqual(store.decisions.keeper(in: group), b.id)
        XCTAssertFalse(store.decisions.protectedIDs.contains(a.id))
    }

    func testKeepFromGridAppliesToEveryOverlappingGroupAndCanBeUndone() {
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let items = (0..<3).map { n in UniversalMediaAsset(id: namespace + "\(n)", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "\(n)"), displayName: "\(n).jpg", mediaKind: .image) }
        store.replaceAssetsForTesting(items)
        store.exactGroups = [UniversalExactGroup(digest: namespace + "1", assets: [items[0], items[1]], keeperID: items[0].id), UniversalExactGroup(digest: namespace + "2", assets: [items[1], items[2]], keeperID: items[2].id)]
        let groups = store.reviewGroups, originalDecisions = store.decisions
        store.selectedLibraryIDs = Set(items.map(\.id))
        store.keep(items[1], in: groups)
        XCTAssertTrue(groups.allSatisfy { store.decisions.keeper(in: $0) == items[1].id })
        XCTAssertFalse(store.selectedLibraryIDs.contains(items[1].id))
        store.undoLibrarySelection()
        XCTAssertEqual(store.selectedLibraryIDs, Set(items.map(\.id)))
        XCTAssertEqual(store.decisions, originalDecisions)
    }

    func testSelectionUndoPreservesPendingIDsWithoutResurrectingRemovedItems() {
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let removed = UniversalMediaAsset(id: namespace + "removed", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "removed"), displayName: "removed.jpg", mediaKind: .image)
        let pending = UniversalMediaAsset(id: namespace + "pending", sourceID: "offline", reference: .photoLibrary(localIdentifier: namespace + "pending"), displayName: "pending.jpg", mediaKind: .image)
        let legacyID = namespace + "legacy"
        store.replaceAssetsForTesting([removed]); store.pendingSelection = [pending]; store.unresolvedSelectionIDs = [legacyID]
        store.selectedLibraryIDs = [removed.id, pending.id, legacyID]
        store.replaceLibrarySelection([]); store.replaceAssetsForTesting([])
        store.undoLibrarySelection()
        XCTAssertEqual(store.selectedLibraryIDs, [pending.id, legacyID])
    }

    func testDetailedReviewAndLibraryShareOneSelectionBasket() {
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let keeper = UniversalMediaAsset(id: namespace + "-keep", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "-keep"), displayName: "keep.jpg", mediaKind: .image)
        let copy = UniversalMediaAsset(id: namespace + "-copy", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "-copy"), displayName: "copy.jpg", mediaKind: .image)
        let group = UniversalExactGroup(digest: namespace, assets: [keeper, copy], keeperID: keeper.id)
        store.exactGroups = [group]
        XCTAssertTrue(store.selectAllSafeCopies(in: group, isUnlocked: true))
        XCTAssertEqual(store.selectedLibraryIDs, [copy.id])
        store.selectedLibraryIDs.removeAll()
        XCTAssertTrue(store.selectedAssetIDs.isEmpty)
        store.toggleLibrarySelection(copy)
        XCTAssertEqual(store.selectedAssetIDs, [copy.id])
    }
    func testUserKeeperAndGroupProtectionRemoveItemsFromSharedBasket() {
        let store = MobileKeptoraStore(), namespace = UUID().uuidString
        let a = UniversalMediaAsset(id: namespace + "a", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "a"), displayName: "a.jpg", mediaKind: .image)
        let b = UniversalMediaAsset(id: namespace + "b", sourceID: "test", reference: .photoLibrary(localIdentifier: namespace + "b"), displayName: "b.jpg", mediaKind: .image)
        store.exactGroups = [UniversalExactGroup(digest: namespace, assets: [a, b], keeperID: a.id)]
        let group = store.reviewGroups[0]
        store.selectedLibraryIDs = [a.id, b.id]
        store.keep(b, in: group)
        XCTAssertEqual(store.selectedLibraryIDs, [a.id]); XCTAssertEqual(store.decisions.keeper(in: group), b.id)
        store.protect(group); XCTAssertTrue(store.selectedLibraryIDs.isEmpty)
    }

    func testLimitedPhotosAccessActionMapping() {
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .limited), .connect)
    }

    func testDeniedPhotosAccessActionMapping() {
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .denied), .showSettingsHelp)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .restricted), .showRestrictedHelp)
        XCTAssertEqual(MobileKeptoraStore.photosAuthorizationAction(for: .unavailable), .showUnavailableHelp)
    }

    func testKeeperIsNeverSelectedUnderAnyBatchAction() {
        let store = MobileKeptoraStore()
        let keeperAsset = UniversalMediaAsset(
            id: "keeper-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/keeper.jpg")),
            displayName: "keeper.jpg",
            mediaKind: .image,
            byteCount: 5_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            isFavorite: true
        )
        let copyAsset = UniversalMediaAsset(
            id: "copy-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/copy.jpg")),
            displayName: "copy.jpg",
            mediaKind: .image,
            byteCount: 5_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        let group = UniversalExactGroup(
            digest: "sha256-test-digest",
            assets: [keeperAsset, copyAsset],
            keeperID: keeperAsset.id
        )
        store.exactGroups = [group]

        // Attempt to select all safe copies
        let selected = store.selectAllSafeCopies(in: group, isUnlocked: true)
        XCTAssertTrue(selected)
        
        // Assert keeper is never selected by default bulk selection
        XCTAssertFalse(store.selectedAssetIDs.contains(keeperAsset.id))
        XCTAssertTrue(store.selectedAssetIDs.contains(copyAsset.id))
        
        // User can manually select keeper if desired
        let toggledKeeper = store.toggleSelection(keeperAsset, in: group, isUnlocked: true)
        XCTAssertTrue(toggledKeeper)
        XCTAssertFalse(store.selectedAssetIDs.contains(keeperAsset.id))
        store.toggleLibrarySelection(keeperAsset)
        XCTAssertTrue(store.selectedAssetIDs.contains(keeperAsset.id))
        XCTAssertTrue(store.hasSelectedKeeper)
    }

    func testProtectedAssetWithAdjustmentsOrFavoritesIsExcluded() {
        let store = MobileKeptoraStore()
        let protectedFav = UniversalMediaAsset(
            id: "fav-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/fav.jpg")),
            displayName: "fav.jpg",
            mediaKind: .image,
            byteCount: 1_000_000,
            isFavorite: true
        )
        let protectedEdit = UniversalMediaAsset(
            id: "edit-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/edit.jpg")),
            displayName: "edit.jpg",
            mediaKind: .image,
            byteCount: 1_000_000,
            hasAdjustments: true
        )
        let plainCopy = UniversalMediaAsset(
            id: "plain-1",
            sourceID: "test-src",
            reference: .file(URL(fileURLWithPath: "/tmp/plain.jpg")),
            displayName: "plain.jpg",
            mediaKind: .image,
            byteCount: 1_000_000
        )
        
        let group = UniversalExactGroup(
            digest: "sha256-mixed",
            assets: [protectedFav, protectedEdit, plainCopy],
            keeperID: protectedFav.id
        )
        
        store.exactGroups = [group]
        XCTAssertEqual(group.safeCopies.map(\.id), [plainCopy.id])
        _ = store.selectAllSafeCopies(in: group, isUnlocked: true)
        XCTAssertEqual(store.selectedAssetIDs, [plainCopy.id])
    }

    func testAppLifecycleBackgroundSuspensionAndResume() {
        let store = MobileKeptoraStore()
        store.suspendScanForBackground()
        // Ensure state remains valid and non-crashing on background
        XCTAssertNil(store.errorMessage)
    }

    func testIsAnalyzingAndCancelScanStateFlow() {
        let store = MobileKeptoraStore()
        XCTAssertFalse(store.isAnalyzing)

        store.similarityProgress = (processed: 5, total: 10)
        XCTAssertTrue(store.isAnalyzing)

        store.cancelScan()
        XCTAssertFalse(store.isAnalyzing)
        XCTAssertEqual(store.scanState, .idle)
        XCTAssertNil(store.similarityProgress)
        XCTAssertNil(store.videoSimilarityProgress)

        store.videoSimilarityProgress = (processed: 2, total: 4)
        XCTAssertTrue(store.isAnalyzing)

        store.cancelScan()
        XCTAssertFalse(store.isAnalyzing)
        XCTAssertNil(store.videoSimilarityProgress)
    }

    func testSuspendScanForBackgroundWhenScanningTransitionsToPaused() {
        let store = MobileKeptoraStore()
        store.scanState = .scanning(processed: 50, total: 100, current: "img.jpg")
        store.suspendScanForBackground()
        XCTAssertEqual(store.scanState, .paused)
        XCTAssertTrue(store.suspendedForBackground)

        store.cancelScan()
        XCTAssertEqual(store.scanState, .idle)
    }

    func testClearSelectionResetsSelectedAssets() {
        let store = MobileKeptoraStore()
        store.selectedAssetIDs = ["asset-1", "asset-2"]
        store.selectedSimilarVideoAssetIDs = ["vid-1"]

        store.clearExactSelection()
        XCTAssertTrue(store.selectedAssetIDs.isEmpty)

        store.clearSimilarVideoSelection()
        XCTAssertTrue(store.selectedSimilarVideoAssetIDs.isEmpty)
    }
}
