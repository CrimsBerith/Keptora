import AppKit
import Combine
import KeptoraCore
@preconcurrency import Photos
import SwiftUI

struct MacRecoveryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let count: Int
    let bytes: Int64
    var folderRecord: FolderQuarantineRecord?
    var bookmark: Data?
    var isPhotos: Bool
    var operationState: RecoveryOperationState? = nil
}

struct MacGalleryContext: Codable, Equatable, Sendable {
    var search = ""
    var finding: LibraryFindingFilter = .all
    var quality: LibraryQualityFilter?
    var smartOrder = true
    var media = 0
    var albumID = ""
    var focusedID: String?
    var scrollID: String?
}

struct MacLibraryState: Codable, Sendable {
    var selection: Set<String>
    var selectedAssets: [UniversalMediaAsset]
    var decisions: LibraryReviewDecisions
    var history: [MacRecoveryEntry]
    var bookmarks: [String: Data]
    var excludedSources: Set<String>
    var context: MacGalleryContext
    var checkpoint: UniversalScanCheckpoint?
    var configuration: LibraryConfiguration?
    var checkpointSources: Set<String>?
    var analysis: MacSavedAnalysis?
}

struct MacSavedAnalysis: Codable, Sendable {
    var assets: [UniversalMediaAsset]
    var exact: [UniversalExactGroup]
    var similar: [UniversalSimilarityGroup]
    var videos: [UniversalSimilarityGroup]
    var quality: [String: QualityAssessment]
    var progress: AnalysisSessionProgress
    var checkpoint: UniversalScanCheckpoint?
    var configuration: LibraryConfiguration?
    var sources: Set<String>?
    var fingerprints: [String: UniversalExactFingerprint]?
    var issues: [AnalysisIssue]?
    var failedStages: [AnalysisStage]?
}

enum MacPersistenceHealth { case loading, healthy, unreadable, writeFailed }
enum MacLibraryPresentation { case main, sources, review, settings }

@MainActor
final class MacArchiveModel: ObservableObject {
    @Published var assets: [UniversalMediaAsset] = [] { didSet { invalidateScope(); analysisCacheDirty = true } }
    private var cachedScopedAssets: [UniversalMediaAsset]?
    private var cachedAlbums: [MediaAlbum]?
    private var cachedReviewGroups: [LibraryReviewGroup]?
    private var cachedProjection: MacGalleryProjection?
    private(set) var galleryProjectionBuilds = 0
    private var appliedSearch = ""
    private var searchTask: Task<Void, Never>?
    var gallery: MacGalleryProjection {
        if let cachedProjection { return cachedProjection }
        galleryProjectionBuilds += 1
        let value = MacGalleryProjection(assets: scopedAssets, groups: reviewGroups, quality: qualityAssessments,
            issues: analysisIssues, decisions: decisions, context: galleryContext, search: appliedSearch)
        cachedProjection = value; return value
    }
    private func invalidateScope() { cachedScopedAssets = nil; cachedAlbums = nil; cachedProjection = nil }
    private func invalidateGroups() { cachedReviewGroups = nil; cachedProjection = nil; analysisCacheDirty = true }
    @Published var selection: Set<String> = [] { didSet { if sourceReady { persistSelection() } } }
    @Published var sourceName = L10n.tr("Choose a source")
    @Published var sourceRoot: URL?
    @Published var busy = false
    @Published var loading = false
    @Published var analyzing = false
    @Published var analysisPaused = false
    @Published var galleryContext = MacGalleryContext() {
        didSet {
            var prior = oldValue; prior.search = galleryContext.search
            if prior != galleryContext { cachedProjection = nil }
            guard galleryContext.search != oldValue.search else { return }
            searchTask?.cancel()
            let value = galleryContext.search
            searchTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 120_000_000) } catch { return }
                guard let self else { return }; self.objectWillChange.send(); self.appliedSearch = value; self.cachedProjection = nil
            }
        }
    }
    private var navigationScrollID: String?
    private var navigationFocusID: String?
    var scrollAnchorID: String? { navigationScrollID ?? galleryContext.scrollID }
    var focusedAssetID: String? { navigationFocusID ?? galleryContext.focusedID }
    func recordScrollAnchor(_ id: String) { if scrollAnchorID != id { navigationScrollID = id; scheduleSave() } }
    func recordFocus(_ id: String?) { navigationFocusID = id; scheduleSave() }
    @Published var workMetrics: [AnalysisStage: AnalysisWorkMetrics] = [:]
    var authorizeSuggestions: (([String]) -> Bool)?
    weak var undoManager: UndoManager? { didSet { undoManager?.levelsOfUndo = 50 } }
    private var pendingRefresh = false
    private var pendingAccessRefresh = false
    private var pauseCommandSequence = 0
    private var discardScanCheckpoint = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var analysisSession = MacAnalysisSession()
    private var checkpoint: UniversalScanCheckpoint? { didSet { analysisCacheDirty = true } }
    private var checkpointConfiguration: LibraryConfiguration?
    private var checkpointSources: Set<String>?
    private var saveTask: Task<Void, Never>?
    private let repository: LibraryRepository<MacLibraryState>
    private let analysisRepository: LibraryRepository<MacSavedAnalysis>
    private let persistentSession: Bool
    private let migrateLegacyPreferences: Bool
    private var analysisCacheDirty = false
    private var analysisSequence = 0
    private var analysisSaveTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    @Published private(set) var persistenceHealth: MacPersistenceHealth = .loading
    @Published private(set) var persistenceMessage: String?
    @Published private(set) var analysisCacheMessage: String?
    let operations: LibraryOperationCoordinator
    private var operationObserver: UUID?
    private var operationResources: Set<String> {
        Set(folderScopes.values.map { LibraryFileIdentity.volumeKey(for: $0) }).union(photosConnected ? ["photos:system"] : [])
    }
    var canEditLibrary: Bool { !operations.isTerminating && (!persistentSession || persistenceHealth == .healthy) }
    var analysisConfiguration: LibraryConfiguration { checkpointConfiguration ?? .stored() }
    var canRemoveSelection: Bool { canEditLibrary && !busy && !loading && !analyzing && operations.canAcquire(operationResources, mode: .write) }
    var cleanupStorageIsBusy: Bool { !operations.canAcquire(operationResources, mode: .write) }
    private var repositoryLoaded = false
    private var migratingLegacyState = false
    private var repositorySequence = 0
    private var persistenceError: String?
    var canRepairPersistence: Bool { (persistenceHealth == .unreadable || persistenceHealth == .writeFailed) && !busy && !loading && !analyzing }
    private var fixtureRoot: URL?
    private var lastAnalysisAllowedNetwork = false
    @Published var error: String? { didSet { if error != nil { errorOwner = presentationOwner } } }
    @Published var presentationOwner: MacLibraryPresentation = .main
    @Published private(set) var errorOwner: MacLibraryPresentation = .main
    @Published var filterScopeMessage: String?
    func errorBinding(for owner: MacLibraryPresentation) -> Binding<Bool> {
        Binding(get: { self.error != nil && self.errorOwner == owner && self.presentationOwner == owner }, set: { value in
            if !value && self.errorOwner == owner { self.error = nil }
        })
    }
    func closePresentation() { presentationOwner = .main; if error != nil { errorOwner = .main } }
    @Published var history: [MacRecoveryEntry] = []
    @Published var exact: [UniversalExactGroup] = [] { didSet { invalidateGroups() } }
    @Published var similarVideos: [UniversalSimilarityGroup] = [] { didSet { invalidateGroups() } }
    @Published var coverage: [LibrarySourceCoverage] = [] { didSet { invalidateScope() } }
    @Published var connectionErrors: [String] = []
    @Published var connectedFolders: [LibrarySource] = [] { didSet { invalidateScope() } }
    @Published var photosConnected = false { didSet { invalidateScope() } }
    @Published private(set) var recoveryCatalogueIssues: [FolderRecoveryIssue] = []
    @Published var skippedCloudItems = 0
    @Published private(set) var scanSourceSelection = LibrarySourceSelection(excludedIDs: Set(UserDefaults.standard.stringArray(forKey: AppStorageKeys.macExcludedScanSources) ?? []))
    private var sourceCatalogue = LibrarySourceCatalogue() { didSet { invalidateScope() } }
    private let sourceAccess: MacSourceAccessCoordinator
    private var folderAdapters: [String: FolderSourceAdapter] { get { sourceAccess.adapters } set { sourceAccess.adapters = newValue } }
    private var folderScopes: [String: URL] { get { sourceAccess.scopes } set { sourceAccess.scopes = newValue } }
    private var bookmarks: [String: Data] { get { sourceAccess.bookmarks } set { sourceAccess.bookmarks = newValue } }
    var connectedSources: [LibrarySource] { (photosConnected ? [.photos] : []) + connectedFolders }
    var selectedSourceIDs: Set<String> { scanSourceSelection.selectedIDs(in: connectedSources, coverage: coverage) }
    var scopedAssets: [UniversalMediaAsset] {
        if let cachedScopedAssets { return cachedScopedAssets }
        let items = sourceCatalogue.assets(in: connectedSources, selectedIDs: selectedSourceIDs, current: assets)
        cachedScopedAssets = items; return items
    }
    var sourceControlsDisabled: Bool { busy || loading || analyzing || isRequestingPhotosAccess || !canEditLibrary || !operations.canAcquire(operationResources, mode: .read) }
    var canScanSelectedSources: Bool { !sourceControlsDisabled && !selectedSourceIDs.isEmpty }
    var sourceSelectionState: LibrarySourceSelection.State { scanSourceSelection.state(in: connectedSources, coverage: coverage) }
    func toggleScanSource(_ id: String) {
        guard !sourceControlsDisabled, LibrarySourceSelection().selectedIDs(in: connectedSources, coverage: coverage).contains(id) else { return }
        scanSourceSelection.setSelected(!selectedSourceIDs.contains(id), id: id)
        scanSourcesChanged()
    }
    func toggleAllScanSources() {
        guard !sourceControlsDisabled else { return }
        scanSourceSelection.toggleAll(in: connectedSources, coverage: coverage)
        scanSourcesChanged()
    }
    private func scanSourcesChanged() {
        invalidateScope()
        checkpoint = nil; analysisPaused = false; scheduleSave()
        exact = []; similar = []; similarVideos = []; qualityAssessments = [:]; analysisIssues = []; analysisFailures = [:]; sessionProgress = .init(); skippedCloudItems = 0; skippedPreviews = 0
    }
    private var connectedAdapters: [any SourceAdapter] {
        var values: [any SourceAdapter] = []
        if photosConnected { values.append(photos) }
        values.append(contentsOf: connectedFolders.compactMap { source in
            guard let root = folderScopes[source.id], source.id == "folder:" + LibraryFileIdentity.key(for: root) else { return nil }
            return folderAdapters[source.id]
        })
        return values
    }
    var adapter: UnifiedLibraryAdapter { UnifiedLibraryAdapter(adapters: connectedAdapters) }
    private var scanAdapter: UnifiedLibraryAdapter { UnifiedLibraryAdapter(adapters: connectedAdapters, selectedSourceIDs: selectedSourceIDs) }
    var reviewGroups: [LibraryReviewGroup] {
        if let cachedReviewGroups { return cachedReviewGroups }
        let groups = LibraryReviewGroup.combined(exact: exact, similar: similar + similarVideos)
        cachedReviewGroups = groups; return groups
    }
    func sourceLabel(_ item: UniversalMediaAsset) -> String {
        item.sourceLabel(in: connectedSources)
    }
    @Published var similar: [UniversalSimilarityGroup] = [] { didSet { invalidateGroups() } }
    @Published var status: String?
    @Published var analysisTotal = 0
    @Published var analysisProcessed = 0
    @Published var skippedPreviews = 0
    @Published var sourceReady = false
    @Published var authorization: SourceAuthorization = .notDetermined
    @Published private(set) var isRequestingPhotosAccess = false
    private var connectionsRestored = false
    private var generation = UUID()
    private var observer: MacArchivePhotoObserver?
    private var selectionKey: String { "Keptora.ManualSelection.unified.Mac" }
    @Published var qualityAssessments: [String: QualityAssessment] = [:] { didSet { cachedProjection = nil; analysisCacheDirty = true } }
    @Published var analysisIssues: [AnalysisIssue] = [] { didSet { cachedProjection = nil; analysisCacheDirty = true } }
    @Published private(set) var analysisFailures: [AnalysisStage: String] = [:] { didSet { analysisCacheDirty = true } }
    @Published var sessionProgress = AnalysisSessionProgress() { didSet { analysisCacheDirty = true } }
    private var fingerprints: [String: UniversalExactFingerprint] = [:]
    @Published private(set) var lastCleanupOutcome: LibraryCleanupOutcome?
    @Published var pendingSelection: [UniversalMediaAsset] = []
    @Published var unresolvedSelectionIDs: Set<String> = []
    @Published var decisions = (UserDefaults.standard.data(forKey: "Keptora.ReviewDecisions.Mac").flatMap { try? JSONDecoder().decode(LibraryReviewDecisions.self, from: $0) }) ?? LibraryReviewDecisions() { didSet { cachedProjection = nil } }
    @Published private(set) var canUndoSelection = false
    @Published private(set) var canRedoSelection = false
    private var selectionSession = LibrarySelectionUndoSession()
    private let selectionArchive = LibrarySelectionArchive(name: "selection-mac-v3")
    private var archivedSelectionLoaded = false
    private func persistSelection() {
        scheduleSave()
    }
    func discardPendingSelection() {
        guard canEditLibrary, !busy else { return }
        selection.subtract(pendingSelection.map(\.id)); selection.subtract(unresolvedSelectionIDs); unresolvedSelectionIDs = []; pendingSelection = []
    }
    func keep(_ item: UniversalMediaAsset, in group: LibraryReviewGroup) {
        keep(item, in: [group])
    }
    func keep(_ item: UniversalMediaAsset, in groups: [LibraryReviewGroup]) {
        guard canEditLibrary, !busy else { return }
        let related = groups.filter { $0.assets.contains { $0.id == item.id } }
        guard !related.isEmpty else { return }
        var updated = decisions
        for group in related { updated.keep(item.id, in: group) }
        applyDecisions(updated, selection: selection.subtracting([item.id]))
    }
    func toggleProtection(_ item: UniversalMediaAsset) {
        guard canEditLibrary, !busy else { return }
        var updated = decisions; updated.toggleProtection(item.id)
        applyDecisions(updated, selection: updated.protectedIDs.contains(item.id) ? selection.subtracting([item.id]) : selection)
    }
    func protect(_ group: LibraryReviewGroup) {
        guard canEditLibrary, !busy else { return }
        var updated = decisions; updated.protect(group)
        applyDecisions(updated, selection: selection.subtracting(group.assets.map(\.id)))
    }
    private func applyDecisions(_ updated: LibraryReviewDecisions, selection ids: Set<String>) {
        guard canEditLibrary, !busy, updated != decisions || ids != selection else { return }
        rememberSelection(); decisions = updated; selection = ids; persistDecisions()
    }
    func groupSuggestionCandidates(_ group: LibraryReviewGroup) -> [UniversalMediaAsset] {
        decisions.candidates(in: group, respecting: reviewGroups)
    }
    func exactSuggestionCandidates(visibleIDs: Set<String>? = nil) -> [UniversalMediaAsset] {
        decisions.exactSuggestions(reviewGroups).filter { visibleIDs?.contains($0.id) ?? true }
    }
    func selectOthers(in group: LibraryReviewGroup, visibleIDs: Set<String>? = nil) {
        let candidates = groupSuggestionCandidates(group).filter { !selection.contains($0.id) && (visibleIDs?.contains($0.id) ?? true) }
        guard authorizeSuggestions?(candidates.map(\.id)) ?? true else { return }
        selectItems(candidates)
    }
    func selectExactSuggestions(visibleIDs: Set<String>? = nil) {
        let candidates = exactSuggestionCandidates(visibleIDs: visibleIDs).filter { !selection.contains($0.id) }
        guard authorizeSuggestions?(candidates.map(\.id)) ?? true else { return }
        selectItems(candidates)
    }
    func selectItems(_ items: [UniversalMediaAsset]) { setSelection(selection.union(items.filter { !decisions.protectedIDs.contains($0.id) }.map(\.id))) }
    func toggleSelection(_ item: UniversalMediaAsset) {
        guard !decisions.protectedIDs.contains(item.id) else { return }
        var ids = selection
        if !ids.insert(item.id).inserted { ids.remove(item.id) }
        setSelection(ids)
    }
    func setSelection(_ ids: Set<String>) {
        let permitted = ids.subtracting(decisions.protectedIDs)
        guard canEditLibrary, !busy, permitted != selection else { return }
        rememberSelection(); selection = permitted
    }
    func unprotectAndSelect(_ item: UniversalMediaAsset) {
        guard canEditLibrary, !busy else { return }
        var updated = decisions
        if updated.protectedIDs.contains(item.id) { updated.toggleProtection(item.id) }
        applyDecisions(updated, selection: selection.union([item.id]))
    }
    private func rememberSelection() {
        selectionSession.capture(ids: selection, decisions: decisions); updateUndoAvailability()
        undoManager?.registerUndo(withTarget: self) { model in MainActor.assumeIsolated { model.undoSelection() } }
        undoManager?.setActionName(L10n.tr("Selection"))
    }
    func undoSelection() {
        guard canEditLibrary, !busy else { return }
        if let undoManager, !undoManager.isUndoing { if undoManager.canUndo { undoManager.undo() }; return }
        let available = Set((assets + pendingSelection).map(\.id)).union(unresolvedSelectionIDs)
        guard let previous = selectionSession.undo(available: available, currentIDs: selection, decisions: decisions) else { return }
        undoManager?.registerUndo(withTarget: self) { model in MainActor.assumeIsolated { model.redoSelection() } }
        undoManager?.setActionName(L10n.tr("Selection"))
        selection = previous.ids; decisions = previous.decisions
        updateUndoAvailability(); persistDecisions()
    }
    func redoSelection() {
        guard canEditLibrary, !busy else { return }
        if let undoManager, !undoManager.isRedoing { if undoManager.canRedo { undoManager.redo() }; return }
        let available = Set((assets + pendingSelection).map(\.id)).union(unresolvedSelectionIDs)
        guard let next = selectionSession.redo(available: available, currentIDs: selection, decisions: decisions) else { return }
        undoManager?.registerUndo(withTarget: self) { model in MainActor.assumeIsolated { model.undoSelection() } }
        undoManager?.setActionName(L10n.tr("Selection"))
        selection = next.ids; decisions = next.decisions; updateUndoAvailability(); persistDecisions()
    }
    private func updateUndoAvailability() { canUndoSelection = selectionSession.canUndo; canRedoSelection = selectionSession.canRedo }
    private func persistDecisions() { scheduleSave() }
    private func reconcileSelection(previousSelection: [UniversalMediaAsset] = []) {
        guard canEditLibrary else { return }
        var saved = repositoryLoaded ? selection : Set(UserDefaults.standard.stringArray(forKey: selectionKey) ?? [])
        if migratingLegacyState, UserDefaults.standard.object(forKey: selectionKey) == nil {
            saved.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection.Mac.photos") ?? [])
            for root in folderScopes.values { saved.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection.Mac." + StableDigest.fnv1a64(root.standardizedFileURL.path)) ?? []) }
        }
        migratingLegacyState = false
        var migratedIDs: [String: String] = [:]
        for item in assets {
            if case .file(let url) = item.reference {
                for previous in previousSelection + pendingSelection where previous.id != item.id && previous.reference == item.reference &&
                    previous.fileRevision?.physicalIdentity == item.fileRevision?.physicalIdentity && item.fileRevision != nil {
                    if saved.remove(previous.id) != nil { saved.insert(item.id) }; migratedIDs[previous.id] = item.id
                }
                let oldID = "file:" + StableDigest.fnv1a64(item.sourceID + "|" + url.standardizedFileURL.path)
                if saved.remove(oldID) != nil { saved.insert(item.id) }
                let pathID = "file:" + StableDigest.fnv1a64(url.standardizedFileURL.resolvingSymlinksInPath().path)
                if saved.remove(pathID) != nil { saved.insert(item.id) }
                migratedIDs[oldID] = item.id; migratedIDs[pathID] = item.id
                for root in folderScopes.values where url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") {
                    let previousSource = "folder:" + StableDigest.fnv1a64(root.standardizedFileURL.path)
                    let previousID = "file:" + StableDigest.fnv1a64(previousSource + "|" + url.standardizedFileURL.path)
                    if saved.remove(previousID) != nil { saved.insert(item.id) }
                    migratedIDs[previousID] = item.id
                }
            }
        }
        decisions.migrateProtectedIDs(migratedIDs)
        let resolved = PendingLibrarySelection(ids: saved, current: assets, previous: previousSelection + pendingSelection, coverage: coverage)
        pendingSelection = resolved.pending; unresolvedSelectionIDs = resolved.unresolvedIDs; selection = resolved.ids
    }
    private var photos: PhotoLibrarySourceAdapter { sourceAccess.photos }
    private let cleanupPreflight: LibraryCleanupPreflight
    private let folders: FolderQuarantineExecutor
    private var task: Task<Void, Never>?
    private let historyKey = "Keptora.ManualCleanupHistory.Mac"
    init(repositoryURL: URL? = nil, sourceAccess: MacSourceAccessCoordinator? = nil, cleanupPreflight: LibraryCleanupPreflight = LibraryCleanupPreflight(), folderCleanup: FolderQuarantineExecutor = FolderQuarantineExecutor(), persistentSession: Bool = true, operations: LibraryOperationCoordinator? = nil) {
        self.persistentSession = persistentSession; migrateLegacyPreferences = repositoryURL == nil && persistentSession
        self.operations = operations ?? LibraryOperationCoordinator()
        self.sourceAccess = sourceAccess ?? MacSourceAccessCoordinator()
        self.cleanupPreflight = cleanupPreflight
        self.folders = folderCleanup
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        #if DEBUG
        let testRoot = LaunchArguments.contains("-keptoraUnifiedMacUITesting") ? FileManager.default.temporaryDirectory.appendingPathComponent("KeptoraMacUI-" + (ProcessInfo.processInfo.environment["KEPTORA_MAC_FIXTURE_ID"] ?? UUID().uuidString)) : nil
        fixtureRoot = testRoot
        #else
        let testRoot: URL? = nil
        #endif
        let sessionURL = repositoryURL ?? testRoot?.appendingPathComponent("session.json") ?? base.appendingPathComponent("Keptora/mac-library-session-v1.json")
        repository = LibraryRepository(url: sessionURL)
        analysisRepository = LibraryRepository(url: sessionURL.appendingPathExtension("analysis-cache"))
        if !persistentSession { repositoryLoaded = true; persistenceHealth = .healthy; archivedSelectionLoaded = true }
        operationObserver = self.operations.observe { [weak self] in
            guard let self else { return }; self.objectWillChange.send()
            if self.pendingRefresh && self.operations.canAcquire(self.operationResources, mode: .read) { self.drainRefresh() }
        }
        if LaunchArguments.contains(LaunchArguments.resetSourceSetupUITesting) {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.macSourceSetupCompleted)
        }
        if let data = UserDefaults.standard.data(forKey: historyKey), let entries = try? JSONDecoder().decode([MacRecoveryEntry].self, from: data) { history = entries }
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pauseAnalysis(); await self?.flushState() }
        })
    }
    deinit {
        task?.cancel(); saveTask?.cancel(); searchTask?.cancel(); analysisSaveTask?.cancel(); recoveryTask?.cancel()
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    }
    var selected: [UniversalMediaAsset] { UnifiedLibraryAdapter.uniqueReferences(assets.filter { selection.contains($0.id) } + pendingSelection.filter { selection.contains($0.id) }) }
    var albums: [MediaAlbum] {
        if let cachedAlbums { return cachedAlbums }
        var values: [String: MediaAlbum] = [:]
        for asset in scopedAssets { for album in asset.context?.albums ?? [] { values[album.id] = album } }
        let result = values.values.sorted { $0.title < $1.title }
        cachedAlbums = result; return result
    }
    func restoreConnections(loadSources: Bool = true) async {
        guard !connectionsRestored else { return }
        connectionsRestored = true
        #if DEBUG
        if let fixtureRoot {
            do { try installUnifiedFixture(at: fixtureRoot); repositoryLoaded = true; persistenceHealth = .healthy; archivedSelectionLoaded = true; updateConnections(); refresh() }
            catch { self.error = error.localizedDescription }
            return
        }
        #endif
        do {
            let loaded = try await repository.load()
            repositorySequence = await repository.nextSequence()
            if let state = loaded.value {
                selection = state.selection; pendingSelection = state.selectedAssets; decisions = state.decisions; history = state.history
                bookmarks = state.bookmarks; scanSourceSelection = .init(excludedIDs: state.excludedSources)
                galleryContext = state.context; appliedSearch = state.context.search; checkpoint = state.checkpoint; checkpointConfiguration = state.configuration; checkpointSources = state.checkpointSources
                analysisPaused = checkpoint != nil
                if let analysis = state.analysis {
                    assets = analysis.assets; exact = analysis.exact; similar = analysis.similar; similarVideos = analysis.videos
                    qualityAssessments = analysis.quality; sessionProgress = analysis.progress
                    restoreSavedIssues(analysis)
                }
                do {
                    let cache = try await analysisRepository.load()
                    analysisSequence = await analysisRepository.nextSequence()
                    if let value = cache.value {
                        assets = value.assets; exact = value.exact; similar = value.similar; similarVideos = value.videos
                        qualityAssessments = value.quality; sessionProgress = value.progress; fingerprints = value.fingerprints ?? [:]
                        restoreSavedIssues(value)
                        checkpoint = value.checkpoint; checkpointConfiguration = value.configuration; checkpointSources = value.sources
                        analysisPaused = checkpoint != nil; analysisCacheDirty = false
                    }
                } catch { analysisCacheMessage = L10n.tr("Saved scan results are unavailable. Run a new scan; your selection and keep choices are preserved.") }
                repositoryLoaded = true; archivedSelectionLoaded = true
            } else {
                if migrateLegacyPreferences {
                    migratingLegacyState = true
                    selection = Set(UserDefaults.standard.stringArray(forKey: selectionKey) ?? [])
                    pendingSelection = try await selectionArchive.loadStrict()
                    bookmarks = UserDefaults.standard.dictionary(forKey: "Keptora.UnifiedFolderBookmarks.Mac")?.compactMapValues { $0 as? Data } ?? [:]
                }
                archivedSelectionLoaded = true
                repositoryLoaded = true
            }
            persistenceHealth = .healthy
            if loaded.recoveredBackup { error = L10n.tr("Your saved session was recovered from its backup. Check your selection before continuing.") }
        } catch {
            let message = L10n.tr("Your saved session could not be read. The original file was preserved.") + "\n" + error.localizedDescription
            self.error = message; persistenceError = message; persistenceMessage = message; persistenceHealth = .unreadable
        }
        guard loadSources else { return }
        let saved = repositoryLoaded ? bookmarks : UserDefaults.standard.dictionary(forKey: "Keptora.UnifiedFolderBookmarks.Mac")?.compactMapValues { $0 as? Data } ?? [:]
        bookmarks = saved
        for (previousID, bookmark) in saved {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                try addFolder(url)
                let newID = "folder:" + LibraryFileIdentity.key(for: url)
                if previousID != newID {
                    if scanSourceSelection.excludedIDs.contains(previousID) { scanSourceSelection.setSelected(false, id: newID) }
                    bookmarks.removeValue(forKey: previousID)
                }
            } catch { connectionErrors.append(L10n.tr("Reconnect an unavailable folder in Sources.")) }
        }
        authorization = await currentPhotosAuthorization()
        photosConnected = authorization == .authorized || authorization == .limited
        updateConnections(); refresh()
    }
    private func updateConnections() {
        sourceAccess.observeChanges { [weak self] in Task { @MainActor in self?.refresh() } }
        sourceReady = !connectedSources.isEmpty
        sourceName = L10n.tr("All Connected Sources")
        // Kept only for compatibility; never used to route mixed selections.
        sourceRoot = nil
    }
    func connectPhotos() {
        Task { await requestPhotosAccess() }
    }
    private func currentPhotosAuthorization() async -> SourceAuthorization {
        if LaunchArguments.contains(LaunchArguments.photosDeniedUITesting) { return .denied }
        return await photos.authorizationStatus()
    }
    func requestPhotosAccess(showError: Bool = true) async {
        guard canEditLibrary, !busy, !analyzing, !isRequestingPhotosAccess else { return }
        isRequestingPhotosAccess = true
        defer { isRequestingPhotosAccess = false }
        // Let the restored folder catalogue finish before adding another source.
        if loading { await task?.value }
        let current = await currentPhotosAuthorization()
        authorization = current == .notDetermined ? await photos.requestAuthorization() : current
        photosConnected = authorization == .authorized || authorization == .limited
        updateConnections()
        if photosConnected { refresh() }
        else if showError { error = L10n.tr("Allow Photos access in System Settings to open this library.") }
    }
    func refreshPhotosAccess() async {
        guard connectionsRestored else { return }
        guard !busy, !analyzing, !loading, !isRequestingPhotosAccess else { pendingAccessRefresh = true; return }
        let latest = await currentPhotosAuthorization()
        let wasConnected = photosConnected
        let authorizationBeforeRefresh = authorization
        authorization = latest
        photosConnected = latest == .authorized || latest == .limited
        updateConnections()
        if sourceReady && (wasConnected != photosConnected || latest != authorizationBeforeRefresh) { refresh() }
        else if wasConnected && !sourceReady { pendingSelection = selected; assets = []; exact = []; similar = []; similarVideos = []; coverage = [] }
    }
    func openPhotosSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") else { return }
        NSWorkspace.shared.open(url)
    }
    private func addFolder(_ root: URL) throws {
        guard canEditLibrary else { throw CocoaError(.fileWriteUnknown) }
        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: true, configuration: .stored())
        guard folderAdapters[adapter.source.id] == nil else { return }
        guard root.startAccessingSecurityScopedResource() else { throw UniversalScanError.sourcePermissionDenied }
        do {
            let bookmark = try root.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            folderScopes[adapter.source.id] = root; folderAdapters[adapter.source.id] = adapter
            bookmarks[adapter.source.id] = bookmark; connectedFolders.append(adapter.source)
            let oldID = "folder:" + StableDigest.fnv1a64(root.standardizedFileURL.path)
            if scanSourceSelection.excludedIDs.contains(oldID) { scanSourceSelection.setSelected(false, id: adapter.source.id) }
            bookmarks.removeValue(forKey: oldID); scheduleSave()
        } catch { root.stopAccessingSecurityScopedResource(); throw error }
    }
    func chooseFolder() {
        guard !sourceControlsDisabled else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for root in panel.urls { do { try addFolder(root) } catch { self.error = error.localizedDescription } }
        updateConnections(); refresh()
    }
    func connectFolder(_ root: URL) {
        guard !sourceControlsDisabled else { return }
        do { try addFolder(root); updateConnections(); refresh() }
        catch { self.error = error.localizedDescription }
    }
    func disconnectFolder(_ id: String) {
        guard !sourceControlsDisabled else { return }
        folderScopes.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
        folderAdapters.removeValue(forKey: id); bookmarks.removeValue(forKey: id)
        connectedFolders.removeAll { $0.id == id }
        scheduleSave()
        updateConnections()
        if sourceReady { refresh() } else { pendingSelection = selected; assets = []; exact = []; similar = []; similarVideos = []; coverage = [] }
    }
    func refresh() {
        guard sourceReady, !operations.isTerminating else { return }
        guard !busy, !analyzing, !loading else { pendingRefresh = true; return }
        // Lease notifications are synchronous. Claim the refresh before acquiring
        // so an observer cannot start the same pending refresh recursively.
        pendingRefresh = false
        loading = true
        guard let lease = operations.acquire(operationResources, mode: .read) else {
            loading = false; pendingRefresh = true; return
        }
        do {
            try sourceAccess.revalidate(configuration: .stored())
            connectedFolders = connectedFolders.compactMap { folderAdapters[$0.id]?.source }
            sourceAccess.observeChanges { [weak self] in Task { @MainActor in self?.refresh() } }
        } catch { connectionErrors = [L10n.tr("Reconnect an unavailable folder in Sources.")] }
        task?.cancel()
        let current = UUID(); generation = current
        let adapter = self.adapter
        let previousAssets = assets
        task = Task {
            defer { if generation == current { loading = false }; operations.release(lease); drainRefresh() }
            do {
                authorization = await photos.authorizationStatus()
                let catalogue = try await adapter.enumerateAssets(onSourceBatch: { [weak self] items, reports, catalogue in
                    await self?.receiveAnalysis(.catalogue(items, reports, catalogue), generation: current)
                })
                guard !Task.isCancelled, generation == current else { return }
                let reports = await adapter.coverage
                coverage = connectedSources.map { source in
                    reports.first { $0.id == source.id } ?? .init(source: source, authorization: .unavailable, itemCount: 0,
                        error: L10n.tr("Reconnect an unavailable folder in Sources."))
                }
                sourceCatalogue = await adapter.catalogue
                if !archivedSelectionLoaded {
                    pendingSelection = await selectionArchive.load(); archivedSelectionLoaded = true
                    guard !Task.isCancelled, generation == current else { return }
                }
                let previous = assets + pendingSelection
                let valid = LibraryCatalogueReconciliation.unchangedIDs(current: catalogue, previous: previousAssets)
                let changed = Set(catalogue.map(\.id)) != Set(previousAssets.map(\.id)) || valid.count != catalogue.count
                assets = catalogue; reconcileSelection(previousSelection: previous)
                exact.removeAll { !$0.assets.allSatisfy { valid.contains($0.id) } }
                similar.removeAll { !$0.assets.allSatisfy { valid.contains($0.id) } }
                similarVideos.removeAll { !$0.assets.allSatisfy { valid.contains($0.id) } }
                let currentByID = Dictionary(catalogue.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                exact = exact.map { .init(digest: $0.digest, assets: $0.assets.compactMap { currentByID[$0.id] }, keeperID: $0.keeperID) }
                func rebaseGroups(_ groups: [UniversalSimilarityGroup]) -> [UniversalSimilarityGroup] {
                    groups.map { .init(id: $0.id, assets: $0.assets.compactMap { currentByID[$0.id] }, maximumDistance: $0.maximumDistance,
                                       strength: $0.strength, mediaKind: $0.mediaKind, keeperID: $0.keeperID) }
                }
                similar = rebaseGroups(similar); similarVideos = rebaseGroups(similarVideos)
                qualityAssessments = qualityAssessments.filter { valid.contains($0.key) }
                fingerprints = fingerprints.filter { valid.contains($0.key) }
                analysisIssues = analysisIssues.filter { valid.contains($0.assetID) }
                if changed && !analysisPaused { sessionProgress = .init() }
                recoveryCatalogueIssues = []
                for connected in connectedFolders {
                    guard let root = folderScopes[connected.id] else { continue }
                    let catalogue = try await folders.recoveryCatalogue(root: root, verifyContents: false)
                    recoveryCatalogueIssues.append(contentsOf: catalogue.issues)
                    for record in catalogue.records {
                        if let index = history.firstIndex(where: { $0.id == record.id }) { history[index].folderRecord = record; history[index].bookmark = bookmarks[connected.id]; continue }
                        history.insert(MacRecoveryEntry(id: record.id, date: record.createdAt, count: record.movedCount, bytes: record.recoveryBytes,
                            folderRecord: record, bookmark: bookmarks[connected.id], isPhotos: false), at: 0)
                    }
                }
                persistHistory()
                if photosConnected && observer == nil {
                    observer = MacArchivePhotoObserver { [weak self] in Task { @MainActor in self?.refresh() } }
                }
            } catch is CancellationError { }
            catch { if generation == current { self.error = error.localizedDescription } }
        }
    }
    func analyze(allowNetwork: Bool = false) {
        guard canScanSelectedSources else { return }
        do { try sourceAccess.revalidate(configuration: .stored()) }
        catch { self.error = L10n.tr("Reconnect an unavailable folder in Sources."); refresh(); return }
        guard let lease = operations.acquire(operationResources, mode: .read) else { return }
        let current = UUID(); generation = current
        let configuration = LibraryConfiguration.stored()
        if checkpoint != nil && (checkpointConfiguration != configuration || checkpointSources != selectedSourceIDs) {
            checkpoint = nil; error = L10n.tr("Sources or scan settings changed. A new scan will start.")
        }
        checkpointConfiguration = configuration; checkpointSources = selectedSourceIDs
        for (id, root) in folderScopes { folderAdapters[id] = FolderSourceAdapter(rootURL: root, cleanupAvailable: true, configuration: configuration) }
        analysisSession = MacAnalysisSession()
        discardScanCheckpoint = false
        let session = analysisSession, control = analysisSession.control, resumeCheckpoint = checkpoint
        analysisPaused = false; lastAnalysisAllowedNetwork = allowNetwork
        analyzing = true; sessionProgress = .init(); analysisIssues = []; analysisFailures = [:]; qualityAssessments = [:]
        exact = []; similar = []; similarVideos = []; fingerprints = [:]
        status = L10n.tr("Loading sources"); analysisProcessed = 0; analysisTotal = scopedAssets.count
        let adapter = scanAdapter
        task = Task {
            defer { if generation == current { analyzing = false; status = nil; scheduleSave(); scheduleAnalysisSave() }; operations.release(lease); drainRefresh() }
            let coordinator = LibraryAnalysisCoordinator { [weak self] update in await self?.receiveAnalysis(update, generation: current) }
            do {
                try await coordinator.run(adapter: adapter, allowNetwork: allowNetwork, configuration: configuration, control: control,
                    checkpoint: resumeCheckpoint, checkpointUpdate: { [weak self] value in
                        session.capture(value)
                        Task { @MainActor in guard let self, self.generation == current, !self.discardScanCheckpoint, !self.sessionProgress.isComplete else { return }; self.checkpoint = value; self.scheduleAnalysisSave() }
                    })
                if generation == current { checkpoint = nil }
            }
            catch is CancellationError { if generation == current { sessionProgress.cancel() } }
            catch { if generation == current { self.error = error.localizedDescription } }
        }
    }
    private func receiveAnalysis(_ update: LibraryAnalysisUpdate, generation current: UUID) {
        guard generation == current, !Task.isCancelled else { return }
        switch update {
        case .catalogue(let items, let reports, let catalogue):
            let previous = assets + pendingSelection
            sourceCatalogue.merge(catalogue)
            assets = sourceCatalogue.assets(in: connectedSources, selectedIDs: Set(connectedSources.map(\.id)), current: items + assets)
            coverage = connectedSources.compactMap { source in reports.first { $0.id == source.id } ?? coverage.first { $0.id == source.id } }
            reconcileSelection(previousSelection: previous)
        case .progress(let stage, let value):
            guard sessionProgress.stages[stage]?.isTerminal != true || value.isTerminal else { return }
            sessionProgress.update(stage, value)
            if let focus = [AnalysisStage.photos, .exact, .videos, .catalogue].first(where: { sessionProgress.stages[$0]?.status == .running }),
               let progress = sessionProgress.stages[focus] {
                status = L10n.tr(String.LocalizationValue(focus.titleKey)); analysisProcessed = progress.processed; analysisTotal = progress.total
            }
        case .exact(let groups, let hashes, let items, let issues):
            sessionProgress.update(.exact, .init(status: issues.isEmpty ? .completed : .partial, processed: items.count, total: items.count))
            exact = groups; fingerprints = hashes
            let latest = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            assets = assets.map { latest[$0.id] ?? $0 }; replaceIssues(.exact, issues)
        case .photoGroups(let groups): if sessionProgress.stages[.photos]?.isTerminal != true { similar = groups }
        case .exactGroups(let groups): if sessionProgress.stages[.exact]?.isTerminal != true { exact = groups }
        case .photos(let groups, let quality, let issues):
            sessionProgress.update(.photos, .init(status: issues.isEmpty ? .completed : .partial, processed: quality.count, total: quality.count))
            similar = groups; qualityAssessments = quality; replaceIssues(.photos, issues); skippedPreviews = issues.count
        case .findings(let quality, let issues):
            guard sessionProgress.stages[.photos]?.isTerminal != true else { return }
            qualityAssessments = quality; replaceIssues(.photos, issues)
        case .videos(let groups, let issues): similarVideos = groups; replaceIssues(.videos, issues)
        case .metrics(let stage, let metrics): workMetrics[stage] = metrics
        case .failure(let stage, let message): analysisFailures[stage] = message; if error == nil { error = message }
        case .finished(let progress): sessionProgress = progress; checkpoint = nil
        }
        if case .progress = update {} else { scheduleAnalysisSave() }
    }
    private func restoreSavedIssues(_ value: MacSavedAnalysis) {
        analysisIssues = value.issues ?? []
        let message = L10n.tr("A saved scan stage could not be completed. Run a new scan to retry.")
        analysisFailures = Dictionary((value.failedStages ?? []).map { ($0, message) }, uniquingKeysWith: { first, _ in first })
        skippedCloudItems = Set(analysisIssues.filter { $0.reason == .downloadRequired }.map(\.assetID)).count
    }
    private func replaceIssues(_ stage: AnalysisStage, _ issues: [AnalysisIssue]) {
        analysisIssues.removeAll { $0.stage == stage }; analysisIssues.append(contentsOf: issues)
        skippedCloudItems = Set(analysisIssues.filter { $0.reason == .downloadRequired }.map(\.assetID)).count
    }
    func cancelAnalysis() {
        guard analyzing || analysisPaused else { return }
        discardScanCheckpoint = true; analysisPaused = false; checkpoint = nil; task?.cancel(); sessionProgress.cancel()
        if !analyzing { status = nil; scheduleSave(); scheduleAnalysisSave() }
    }
    func pauseAnalysis() {
        guard analyzing, !analysisPaused else { return }
        analysisPaused = true
        let control = analysisSession.control; pauseCommandSequence += 1; let sequence = pauseCommandSequence
        Task { await control.setPaused(true, sequence: sequence); await flushState() }
    }
    func resumeAnalysis() {
        guard analysisPaused else { return }
        if analyzing {
            analysisPaused = false
            let control = analysisSession.control; pauseCommandSequence += 1; let sequence = pauseCommandSequence
            Task { await control.setPaused(false, sequence: sequence) }
        }
        else { analyze(allowNetwork: checkpoint?.allowNetwork ?? lastAnalysisAllowedNetwork) }
    }
    func removeSelection(expectedIDs: Set<String>, reviewedAssets: [UniversalMediaAsset]? = nil, allowPartialFamilies: Bool = false) async -> Bool {
        await removeSelectionOutcome(expectedIDs: expectedIDs, reviewedAssets: reviewedAssets, allowPartialFamilies: allowPartialFamilies).isComplete
    }
    func removeSelectionOutcome(expectedIDs: Set<String>, reviewedAssets: [UniversalMediaAsset]? = nil, allowPartialFamilies: Bool = false) async -> LibraryCleanupOutcome {
        lastCleanupOutcome = .init(requestedIDs: expectedIDs)
        _ = await performRemoval(expectedIDs: expectedIDs, reviewedAssets: reviewedAssets, allowPartialFamilies: allowPartialFamilies)
        return lastCleanupOutcome ?? .init(requestedIDs: expectedIDs)
    }
    private func performRemoval(expectedIDs: Set<String>, reviewedAssets: [UniversalMediaAsset]?, allowPartialFamilies: Bool) async -> Bool {
        guard canRemoveSelection else { return false }
        guard selection == expectedIDs else {
            error = L10n.tr("Your selection changed. Review it again before removing items."); return false
        }
        guard unresolvedSelectionIDs.intersection(selection).isEmpty, pendingSelection.filter({ selection.contains($0.id) }).isEmpty else {
            error = L10n.tr("Reconnect unavailable sources or remove their items from your selection."); return false
        }
        let snapshot = selected
        if let reviewedAssets, Set(snapshot) != Set(reviewedAssets) { error = L10n.tr("Your selection changed. Review it again before removing items."); return false }
        guard !snapshot.isEmpty, snapshot.count == expectedIDs.count else { return false }
        guard decisions.protectedIDs.intersection(expectedIDs).isEmpty else { error = L10n.tr("Unprotect these photos before selecting them for removal."); return false }
        guard let lease = operations.acquire(operationResources, mode: .write) else { return false }
        busy = true; status = L10n.tr("Reviewing selected items…")
        var completedIDs: Set<String> = []
        var attemptedIDs: Set<String> = []
        defer {
            lastCleanupOutcome = .init(requestedIDs: expectedIDs, completedIDs: completedIDs, failedIDs: attemptedIDs.subtracting(completedIDs))
            busy = false; status = nil; operations.release(lease); drainRefresh()
        }
        do {
            try await saveStateNow()
            try LibraryRevisionValidator.validate(snapshot)
            let batches = Dictionary(grouping: snapshot, by: \.sourceID)
            var prepared: [String: [(asset: UniversalMediaAsset, expectedDigest: String)]] = [:]
            for (id, batch) in batches where id != LibrarySource.photos.id {
                guard let folder = folderAdapters[id], let root = folderScopes[id],
                      id == "folder:" + LibraryFileIdentity.key(for: root), await folders.preflight(root: root) else { throw UniversalScanError.sourcePermissionDenied }
                let candidates = try await cleanupPreflight.prepare(batch, adapter: folder, reviewedFingerprints: fingerprints)
                prepared[id] = candidates
            }
            defer {
                persistHistory()
                assets.removeAll { completedIDs.contains($0.id) }
                exact.removeAll { $0.assets.contains { completedIDs.contains($0.id) } }
                similar.removeAll { $0.assets.contains { completedIDs.contains($0.id) } }
                similarVideos.removeAll { $0.assets.contains { completedIDs.contains($0.id) } }
                selection.subtract(completedIDs)
            }
            if let batch = batches[LibrarySource.photos.id] {
                attemptedIDs.formUnion(batch.map(\.id))
                let ids = batch.compactMap { item -> String? in if case .photoLibrary(let id) = item.reference { return id }; return nil }
                guard ids.count == batch.count else { throw UniversalScanError.unsupportedReference }
                let receiptID = UUID()
                history.insert(MacRecoveryEntry(id: receiptID, date: Date(), count: batch.count, bytes: MediaSelectionSummary(batch).knownBytes,
                    folderRecord: nil, bookmark: nil, isPhotos: true, operationState: .planned), at: 0)
                try await saveStateNow()
                do {
                    try await photos.deleteSelectedAssets(localIdentifiers: ids, intent: .manualSelection, reviewedAssets: batch)
                } catch {
                    if let index = history.firstIndex(where: { $0.id == receiptID }) { history[index].operationState = .failed }
                    throw error
                }
                if let index = history.firstIndex(where: { $0.id == receiptID }) { history[index].operationState = .moved }
                completedIDs.formUnion(batch.map(\.id))
                selection.subtract(completedIDs)
                try await saveStateNow()
            }
            for connected in connectedFolders {
                guard let candidates = prepared[connected.id], let root = folderScopes[connected.id] else { continue }
                attemptedIDs.formUnion(candidates.map { $0.asset.id })
                try LibraryRevisionValidator.validate(candidates.map(\.asset))
                let record = try await folders.quarantine(root: root, selections: candidates, allowPartialFamilies: allowPartialFamilies)
                history.insert(MacRecoveryEntry(id: record.id, date: record.createdAt, count: candidates.count,
                    bytes: MediaSelectionSummary(candidates.map(\.asset)).knownBytes, folderRecord: record,
                    bookmark: bookmarks[connected.id], isPhotos: false), at: 0)
                completedIDs.formUnion(candidates.map { $0.asset.id })
                let identities = Set(candidates.compactMap { $0.asset.fileRevision?.physicalIdentity })
                // A confirmed move can update another selected hard link's ctime.
                // Later sources still verify their original reviewed content digest.
                for sourceID in Array(prepared.keys) where sourceID != connected.id {
                    prepared[sourceID] = prepared[sourceID]?.map { candidate in
                        guard let physical = candidate.asset.fileRevision?.physicalIdentity, identities.contains(physical),
                              case .file(let url) = candidate.asset.reference, let revision = LibraryFileRevision.capture(at: url),
                              revision.physicalIdentity == physical else { return candidate }
                        return (candidate.asset.with(fileRevision: .some(revision)), candidate.expectedDigest)
                    }
                }
            }
            selection.subtract(completedIDs)
            try await saveStateNow()
            return true
        } catch {
            if let partial = error as? FolderCleanupFailure {
                let record = partial.record
                let completedPaths = Set(record.operations.filter { $0.state == .moved }.map(\.originalURL))
                completedIDs.formUnion(snapshot.filter { if case .file(let url) = $0.reference { return completedPaths.contains(url) }; return false }.map(\.id))
                let sourceID = snapshot.first { if case .file(let url) = $0.reference { return LibraryFileIdentity.relativePath(url, root: record.sourceRoot) != nil }; return false }?.sourceID
                history.insert(.init(id: record.id, date: record.createdAt, count: record.movedCount, bytes: record.recoveryBytes,
                    folderRecord: record, bookmark: sourceID.flatMap { bookmarks[$0] }, isPhotos: false), at: 0)
            }
            let ns = error as NSError
            if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError && completedIDs.isEmpty { return false }
            self.error = completedIDs.isEmpty ? error.localizedDescription :
                L10n.format("Moved: %lld items. Not moved: %lld items. See History for recovery.", completedIDs.count, snapshot.count - completedIDs.count) + "\n\n" + error.localizedDescription
            Task { refresh() }
            return false
        }
    }
    func restore(_ entry: MacRecoveryEntry) async {
        guard canRemoveSelection, var record = entry.folderRecord, record.restoredAt == nil else { return }
        var lease: LibraryOperationCoordinator.Lease?
        busy = true; status = L10n.tr("Restoring files…")
        defer { busy = false; status = nil; if let lease { operations.release(lease) }; refresh() }
        do {
            var recoveryScope: URL?
            if let bookmark = entry.bookmark {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                guard url.startAccessingSecurityScopedResource() else { throw UniversalScanError.sourcePermissionDenied }
                recoveryScope = url; record = try record.rebased(to: url)
            }
            defer { recoveryScope?.stopAccessingSecurityScopedResource() }
            var resources = operationResources; resources.insert(LibraryFileIdentity.volumeKey(for: record.sourceRoot))
            guard let acquired = operations.acquire(resources, mode: .write) else {
                throw UniversalScanError.cleanupNotPermitted(L10n.tr("Another operation is using this storage. Wait for it to finish or cancel its scan."))
            }
            lease = acquired
            #if DEBUG
            if LaunchArguments.contains("-keptoraRestoreConflictUITesting"), let original = record.operations.first?.originalURL {
                try Data("Occupied original — must not be overwritten".utf8).write(to: original)
            }
            #endif
            let restored = try await folders.restore(record)
            if let index = history.firstIndex(where: { $0.id == entry.id }) { history[index].folderRecord = restored }
            persistHistory()
        } catch { self.error = error.localizedDescription }
    }
    private func persistHistory() {
        scheduleSave()
    }

    private func drainRefresh() {
        guard !busy, !loading, !analyzing, !operations.isTerminating else { return }
        if pendingAccessRefresh { pendingAccessRefresh = false; Task { await refreshPhotosAccess() } }
        if pendingRefresh { refresh() }
    }
    func contextChanged() { scheduleSave() }
    func openFinding(_ finding: LibraryFindingFilter = .all, quality: LibraryQualityFilter = .all) {
        galleryContext.search = ""; appliedSearch = ""; galleryContext.media = 0; galleryContext.albumID = ""
        galleryContext.finding = finding; galleryContext.quality = quality; galleryContext.smartOrder = true
        filterScopeMessage = L10n.tr("Showing this category from your selected sources. Search, album and media filters were cleared; your selection is kept.")
        contextChanged()
    }
    func verifyRecoveryCatalogue() async {
        guard recoveryTask == nil else { return }
        let worker = Task { await performRecoveryVerification() }
        recoveryTask = worker
        await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        recoveryTask = nil
    }
    private func performRecoveryVerification() async {
        guard !busy, !loading, !analyzing, let lease = operations.acquire(operationResources, mode: .read) else { return }
        defer { operations.release(lease) }
        var issues: [FolderRecoveryIssue] = []
        for source in connectedFolders {
            guard let root = folderScopes[source.id] else { continue }
            do {
                let catalogue = try await folders.recoveryCatalogue(root: root)
                issues.append(contentsOf: catalogue.issues)
                for record in catalogue.records {
                    if let index = history.firstIndex(where: { $0.id == record.id }) { history[index].folderRecord = record }
                }
            } catch is CancellationError { return }
            catch { issues.append(.init(manifestURL: root.appendingPathComponent(".Keptora Quarantine"), message: error.localizedDescription)) }
        }
        recoveryCatalogueIssues = issues; persistHistory()
    }
    private func stateSnapshot() -> MacLibraryState {
        var context = galleryContext; context.scrollID = scrollAnchorID; context.focusedID = focusedAssetID
        return .init(selection: selection, selectedAssets: selected, decisions: decisions, history: history, bookmarks: bookmarks,
              excludedSources: scanSourceSelection.excludedIDs, context: context, checkpoint: nil,
              configuration: nil, checkpointSources: nil, analysis: nil)
    }
    private func scheduleSave() {
        guard persistentSession, repositoryLoaded, persistenceHealth == .healthy else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            await self?.flushState(includeAnalysis: false)
        }
    }
    private func saveStateNow() async throws {
        guard persistentSession else { return }
        guard repositoryLoaded, persistenceHealth != .unreadable else { throw CocoaError(.fileWriteUnknown) }
        repositorySequence += 1
        do { try await repository.save(stateSnapshot(), sequence: repositorySequence) }
        catch {
            persistenceHealth = .writeFailed; persistenceError = error.localizedDescription
            persistenceMessage = L10n.tr("Your session could not be saved. Keep Keptora open and check available storage.") + "\n" + error.localizedDescription
            throw error
        }
    }
    @discardableResult func flushState(includeAnalysis: Bool = true) async -> Bool {
        guard persistentSession else { return true }
        guard repositoryLoaded, persistenceHealth != .unreadable else { return false }
        do {
            try await saveStateNow(); persistenceHealth = .healthy; persistenceError = nil; persistenceMessage = nil
            if includeAnalysis { await flushAnalysisCache() }
            return true
        } catch {
            let message = L10n.tr("Your session could not be saved. Keep Keptora open and check available storage.") + "\n" + error.localizedDescription
            self.error = message; persistenceMessage = message; persistenceError = message; persistenceHealth = .writeFailed; return false
        }
    }
    private func scheduleAnalysisSave() {
        guard persistentSession, repositoryLoaded else { return }
        // A bounded periodic write, independent of selection/search/scroll writes.
        guard analysisSaveTask == nil else { return }
        analysisSaveTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            guard let self else { return }; await self.flushAnalysisCache(); self.analysisSaveTask = nil
            if self.analysisCacheDirty { self.scheduleAnalysisSave() }
        }
    }
    private func flushAnalysisCache() async {
        guard persistentSession, analysisCacheDirty else { return }
        analysisCacheDirty = false; analysisSequence += 1
        let value = MacSavedAnalysis(assets: assets, exact: exact, similar: similar, videos: similarVideos,
            quality: qualityAssessments, progress: sessionProgress, checkpoint: checkpoint,
            configuration: checkpointConfiguration, sources: checkpointSources, fingerprints: fingerprints,
            issues: analysisIssues, failedStages: AnalysisStage.allCases.filter { analysisFailures[$0] != nil })
        do { try await analysisRepository.save(value, sequence: analysisSequence); analysisCacheMessage = nil }
        catch { analysisCacheMessage = L10n.tr("Saved scan results are unavailable. Run a new scan; your selection and keep choices are preserved.") }
    }
    func repairPersistence() async {
        guard canRepairPersistence else { return }
        do {
            if persistenceHealth == .unreadable {
                try await repository.preserveUnreadableFiles(); repositoryLoaded = true; repositorySequence = 0
            }
            persistenceError = nil; persistenceHealth = .healthy
            if await flushState() { error = nil; persistenceMessage = nil; if sourceReady { refresh() } }
        } catch { self.error = error.localizedDescription; persistenceMessage = error.localizedDescription; persistenceHealth = .unreadable }
    }
    func prepareForTermination() async -> Bool {
        recoveryTask?.cancel(); await recoveryTask?.value
        // Let a system-confirmed removal finish; never interrupt a move halfway through quit.
        while busy { try? await Task.sleep(nanoseconds: 100_000_000) }
        if analyzing {
            analysisPaused = true; task?.cancel(); await task?.value
            if !discardScanCheckpoint { checkpoint = analysisSession.snapshot() ?? checkpoint }
        }
        else if loading { task?.cancel(); await task?.value }
        saveTask?.cancel(); analysisSaveTask?.cancel(); return await flushState()
    }
    func diagnosticData() throws -> Data {
        struct Snapshot: Encodable {
            let version: Int
            let assets: Int
            let selected: Int
            let sourceKinds: [String: Int]
            let running: Bool
            let paused: Bool
            let stages: AnalysisSessionProgress
            let metrics: [AnalysisStage: AnalysisWorkMetrics]
            let issues: [String: Int]
            let recoveryIssues: Int
            let hasError: Bool
        }
        let snapshot = Snapshot(version: 1, assets: assets.count, selected: selection.count,
            sourceKinds: Dictionary(grouping: connectedSources, by: { $0.kind.rawValue }).mapValues(\.count),
            running: analyzing, paused: analysisPaused, stages: sessionProgress, metrics: workMetrics,
            issues: Dictionary(grouping: analysisIssues, by: { $0.reason.rawValue }).mapValues(\.count),
            recoveryIssues: history.reduce(0) { $0 + ($1.folderRecord?.unresolvedCount ?? ($1.operationState == .planned ? 1 : 0)) },
            hasError: error != nil || !analysisFailures.isEmpty || persistenceHealth != .healthy)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
    func exportDiagnostics() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Keptora-diagnostics.json"; panel.allowedFileTypes = ["json"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try diagnosticData().write(to: url, options: .atomic) } catch { self.error = error.localizedDescription }
    }
    func copyDiagnostics() {
        do { let data = try diagnosticData(); NSPasteboard.general.clearContents(); NSPasteboard.general.setString(String(decoding: data, as: UTF8.self), forType: .string) }
        catch { self.error = error.localizedDescription }
    }
    var familyWarnings: [URL] { LibraryFileFamilies.omittedCompanions(for: selected) }
    func revealRecovery(_ entry: MacRecoveryEntry) {
        guard let record = entry.folderRecord else { return }
        NSWorkspace.shared.activateFileViewerSelecting([record.sourceRoot.appendingPathComponent(".Keptora Quarantine").appendingPathComponent(record.id.uuidString)])
    }
    #if DEBUG
    private func installUnifiedFixture(at root: URL) throws {
        let first = root.appendingPathComponent("Camera"), second = root.appendingPathComponent("Files")
        for folder in [first, second] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        func jpeg(color: NSColor) throws -> Data {
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 96, pixelsHigh: 96, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw CocoaError(.coderInvalidValue) }
            NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current = context; color.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 96, height: 96)).fill()
            NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: 12, y: 18, width: 48, height: 35)).fill()
            guard let data = bitmap.representation(using: .jpeg, properties: [:]) else { throw CocoaError(.coderInvalidValue) }
            return data
        }
        let copy = try jpeg(color: .systemBlue), different = try jpeg(color: .systemOrange)
        for (url, data) in [(first.appendingPathComponent("original.jpg"), copy), (second.appendingPathComponent("copy.jpg"), copy),
                            (first.appendingPathComponent("holiday.jpg"), different)] {
            if !FileManager.default.fileExists(atPath: url.path) { try data.write(to: url) }
        }
        for folder in [first, second] {
            let adapter = FolderSourceAdapter(rootURL: folder, cleanupAvailable: true)
            folderScopes[adapter.source.id] = folder; folderAdapters[adapter.source.id] = adapter; connectedFolders.append(adapter.source)
        }
        selection = []; history = []; decisions = .init(); photosConnected = false; authorization = .denied
    }
    #endif
}


final class MacArchivePhotoObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let changed: @Sendable () -> Void
    init(changed: @escaping @Sendable () -> Void) {
        self.changed = changed; super.init(); PHPhotoLibrary.shared().register(self)
    }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    func photoLibraryDidChange(_ changeInstance: PHChange) { changed() }
}
