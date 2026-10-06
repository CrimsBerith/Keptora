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

struct MacGalleryContext: Codable, Sendable {
    var search = ""
    var finding: LibraryFindingFilter = .all
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
}

@MainActor
final class MacArchiveModel: ObservableObject {
    @Published var assets: [UniversalMediaAsset] = [] { didSet { cachedScopedAssets = nil } }
    private var cachedScopedAssets: [UniversalMediaAsset]?
    private var cachedReviewGroups: [LibraryReviewGroup]?
    @Published var selection: Set<String> = [] { didSet { if sourceReady { persistSelection() } } }
    @Published var sourceName = L10n.tr("Choose a source")
    @Published var sourceRoot: URL?
    @Published var busy = false
    @Published var loading = false
    @Published var analyzing = false
    @Published var analysisPaused = false
    @Published var galleryContext = MacGalleryContext()
    private var navigationScrollID: String?
    private var navigationFocusID: String?
    var scrollAnchorID: String? { navigationScrollID ?? galleryContext.scrollID }
    var focusedAssetID: String? { navigationFocusID ?? galleryContext.focusedID }
    func recordScrollAnchor(_ id: String) { if scrollAnchorID != id { navigationScrollID = id; scheduleSave() } }
    func recordFocus(_ id: String?) { navigationFocusID = id; scheduleSave() }
    @Published var workMetrics: [AnalysisStage: AnalysisWorkMetrics] = [:]
    var authorizeSuggestions: (([String]) -> Bool)?
    weak var undoManager: UndoManager?
    private var pendingRefresh = false
    private var pendingAccessRefresh = false
    private var pauseCommandSequence = 0
    private var workspaceObservers: [NSObjectProtocol] = []
    private var analysisSession = MacAnalysisSession()
    private var checkpoint: UniversalScanCheckpoint?
    private var checkpointConfiguration: LibraryConfiguration?
    private var checkpointSources: Set<String>?
    private var saveTask: Task<Void, Never>?
    private let repository: LibraryRepository<MacLibraryState>
    private var repositoryLoaded = false
    private var migratingLegacyState = false
    private var repositorySequence = 0
    private var persistenceError: String?
    var canRepairPersistence: Bool { persistenceError != nil && !busy && !loading && !analyzing }
    private var fixtureRoot: URL?
    private var lastAnalysisAllowedNetwork = false
    @Published var error: String?
    @Published var history: [MacRecoveryEntry] = []
    @Published var exact: [UniversalExactGroup] = [] { didSet { cachedReviewGroups = nil } }
    @Published var similarVideos: [UniversalSimilarityGroup] = [] { didSet { cachedReviewGroups = nil } }
    @Published var coverage: [LibrarySourceCoverage] = [] { didSet { cachedScopedAssets = nil } }
    @Published var connectionErrors: [String] = []
    @Published var connectedFolders: [LibrarySource] = [] { didSet { cachedScopedAssets = nil } }
    @Published var photosConnected = false { didSet { cachedScopedAssets = nil } }
    @Published var skippedCloudItems = 0
    @Published private(set) var scanSourceSelection = LibrarySourceSelection(excludedIDs: Set(UserDefaults.standard.stringArray(forKey: AppStorageKeys.macExcludedScanSources) ?? []))
    private var sourceCatalogue = LibrarySourceCatalogue() { didSet { cachedScopedAssets = nil } }
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
    var sourceControlsDisabled: Bool { busy || loading || analyzing || isRequestingPhotosAccess }
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
        cachedScopedAssets = nil
        checkpoint = nil; analysisPaused = false; scheduleSave()
        exact = []; similar = []; similarVideos = []; qualityAssessments = [:]; analysisIssues = []; sessionProgress = .init(); skippedCloudItems = 0; skippedPreviews = 0
    }
    private var connectedAdapters: [any SourceAdapter] {
        var values: [any SourceAdapter] = []
        if photosConnected { values.append(photos) }
        values.append(contentsOf: connectedFolders.compactMap { folderAdapters[$0.id] })
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
    @Published var similar: [UniversalSimilarityGroup] = [] { didSet { cachedReviewGroups = nil } }
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
    @Published var qualityAssessments: [String: QualityAssessment] = [:]
    @Published var analysisIssues: [AnalysisIssue] = []
    @Published var sessionProgress = AnalysisSessionProgress()
    @Published var pendingSelection: [UniversalMediaAsset] = []
    @Published var unresolvedSelectionIDs: Set<String> = []
    @Published var decisions = (UserDefaults.standard.data(forKey: "Keptora.ReviewDecisions.Mac").flatMap { try? JSONDecoder().decode(LibraryReviewDecisions.self, from: $0) }) ?? LibraryReviewDecisions()
    @Published private(set) var canUndoSelection = false
    private var selectionSession = LibrarySelectionUndoSession()
    private let selectionArchive = LibrarySelectionArchive(name: "selection-mac-v3")
    private var archivedSelectionLoaded = false
    private func persistSelection() {
        scheduleSave()
    }
    func discardPendingSelection() {
        selection.subtract(pendingSelection.map(\.id)); selection.subtract(unresolvedSelectionIDs); unresolvedSelectionIDs = []; pendingSelection = []
    }
    func keep(_ item: UniversalMediaAsset, in group: LibraryReviewGroup) {
        keep(item, in: [group])
    }
    func keep(_ item: UniversalMediaAsset, in groups: [LibraryReviewGroup]) {
        guard !busy else { return }
        let related = groups.filter { $0.assets.contains { $0.id == item.id } }
        guard !related.isEmpty else { return }
        var updated = decisions
        for group in related { updated.keep(item.id, in: group) }
        applyDecisions(updated, selection: selection.subtracting([item.id]))
    }
    func toggleProtection(_ item: UniversalMediaAsset) {
        guard !busy else { return }
        var updated = decisions; updated.toggleProtection(item.id)
        applyDecisions(updated, selection: updated.protectedIDs.contains(item.id) ? selection.subtracting([item.id]) : selection)
    }
    func protect(_ group: LibraryReviewGroup) {
        guard !busy else { return }
        var updated = decisions; updated.protect(group)
        applyDecisions(updated, selection: selection.subtracting(group.assets.map(\.id)))
    }
    private func applyDecisions(_ updated: LibraryReviewDecisions, selection ids: Set<String>) {
        guard !busy, updated != decisions || ids != selection else { return }
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
    func selectItems(_ items: [UniversalMediaAsset]) { setSelection(selection.union(items.map(\.id))) }
    func toggleSelection(_ item: UniversalMediaAsset) {
        var ids = selection
        if !ids.insert(item.id).inserted { ids.remove(item.id) }
        setSelection(ids)
    }
    func setSelection(_ ids: Set<String>) {
        guard !busy, ids != selection else { return }
        rememberSelection(); selection = ids
    }
    private func rememberSelection() {
        undoManager?.removeAllActions(withTarget: self)
        selectionSession.capture(ids: selection, decisions: decisions); canUndoSelection = true
        undoManager?.registerUndo(withTarget: self) { model in model.undoSelection() }
        undoManager?.setActionName(L10n.tr("Selection"))
    }
    func undoSelection() {
        guard !busy else { return }
        let available = Set((assets + pendingSelection).map(\.id)).union(unresolvedSelectionIDs)
        guard let previous = selectionSession.undo(available: available) else { return }
        selection = previous.ids; decisions = previous.decisions
        canUndoSelection = false; persistDecisions()
    }
    private func persistDecisions() { scheduleSave() }
    private func reconcileSelection(previousSelection: [UniversalMediaAsset] = []) {
        var saved = repositoryLoaded ? selection : Set(UserDefaults.standard.stringArray(forKey: selectionKey) ?? [])
        if migratingLegacyState, UserDefaults.standard.object(forKey: selectionKey) == nil {
            saved.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection.Mac.photos") ?? [])
            for root in folderScopes.values { saved.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection.Mac." + StableDigest.fnv1a64(root.standardizedFileURL.path)) ?? []) }
        }
        migratingLegacyState = false
        var migratedIDs: [String: String] = [:]
        for item in assets {
            if case .file(let url) = item.reference {
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
    init(repositoryURL: URL? = nil, sourceAccess: MacSourceAccessCoordinator? = nil, cleanupPreflight: LibraryCleanupPreflight = LibraryCleanupPreflight(), folderCleanup: FolderQuarantineExecutor = FolderQuarantineExecutor()) {
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
        repository = LibraryRepository(url: repositoryURL ?? testRoot?.appendingPathComponent("session.json") ?? base.appendingPathComponent("Keptora/mac-library-session-v1.json"))
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
        task?.cancel(); saveTask?.cancel()
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    }
    var selected: [UniversalMediaAsset] { UnifiedLibraryAdapter.uniqueReferences(assets.filter { selection.contains($0.id) } + pendingSelection.filter { selection.contains($0.id) }) }
    var albums: [MediaAlbum] {
        var values: [String: MediaAlbum] = [:]
        for asset in scopedAssets { for album in asset.context?.albums ?? [] { values[album.id] = album } }
        return values.values.sorted { $0.title < $1.title }
    }
    func restoreConnections() async {
        guard !connectionsRestored else { return }
        connectionsRestored = true
        #if DEBUG
        if let fixtureRoot {
            do { try installUnifiedFixture(at: fixtureRoot); repositoryLoaded = true; archivedSelectionLoaded = true; updateConnections(); refresh() }
            catch { error = error.localizedDescription }
            return
        }
        #endif
        do {
            let loaded = try await repository.load()
            repositorySequence = await repository.nextSequence()
            if let state = loaded.value {
                selection = state.selection; pendingSelection = state.selectedAssets; decisions = state.decisions; history = state.history
                bookmarks = state.bookmarks; scanSourceSelection = .init(excludedIDs: state.excludedSources)
                galleryContext = state.context; checkpoint = state.checkpoint; checkpointConfiguration = state.configuration; checkpointSources = state.checkpointSources
                analysisPaused = checkpoint != nil
                if let analysis = state.analysis {
                    assets = analysis.assets; exact = analysis.exact; similar = analysis.similar; similarVideos = analysis.videos
                    qualityAssessments = analysis.quality; sessionProgress = analysis.progress
                }
                repositoryLoaded = true; archivedSelectionLoaded = true
            } else {
                migratingLegacyState = true
                selection = Set(UserDefaults.standard.stringArray(forKey: selectionKey) ?? [])
                pendingSelection = try await selectionArchive.loadStrict(); archivedSelectionLoaded = true
                bookmarks = UserDefaults.standard.dictionary(forKey: "Keptora.UnifiedFolderBookmarks.Mac")?.compactMapValues { $0 as? Data } ?? [:]
                repositoryLoaded = true
            }
            if loaded.recoveredBackup { error = L10n.tr("Your saved session was recovered from its backup. Check your selection before continuing.") }
        } catch { error = L10n.tr("Your saved session could not be read. The original file was preserved.") + "\n" + error.localizedDescription; persistenceError = error }
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
        guard !busy, !analyzing, !isRequestingPhotosAccess else { return }
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
        guard !busy, !analyzing, !loading else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for root in panel.urls { do { try addFolder(root) } catch { self.error = error.localizedDescription } }
        updateConnections(); refresh()
    }
    func connectFolder(_ root: URL) {
        guard !sourceControlsDisabled else { return }
        do { try addFolder(root); updateConnections(); refresh() }
        catch { error = error.localizedDescription }
    }
    func disconnectFolder(_ id: String) {
        guard !busy, !loading, !analyzing else { return }
        folderScopes.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
        folderAdapters.removeValue(forKey: id); bookmarks.removeValue(forKey: id)
        connectedFolders.removeAll { $0.id == id }
        scheduleSave()
        updateConnections()
        if sourceReady { refresh() } else { pendingSelection = selected; assets = []; exact = []; similar = []; similarVideos = []; coverage = [] }
    }
    func refresh() {
        guard sourceReady else { return }
        guard !busy, !analyzing, !loading else { pendingRefresh = true; return }
        pendingRefresh = false
        do {
            try sourceAccess.revalidate(configuration: .stored())
            connectedFolders = connectedFolders.compactMap { folderAdapters[$0.id]?.source }
            sourceAccess.observeChanges { [weak self] in Task { @MainActor in self?.refresh() } }
        } catch { connectionErrors = [L10n.tr("Reconnect an unavailable folder in Sources.")] }
        task?.cancel(); loading = true
        let current = UUID(); generation = current
        let adapter = self.adapter
        task = Task {
            defer { if generation == current { loading = false; drainRefresh() } }
            do {
                authorization = await photos.authorizationStatus()
                let catalogue = try await adapter.enumerateAssets()
                guard !Task.isCancelled, generation == current else { return }
                coverage = await adapter.coverage
                sourceCatalogue = await adapter.catalogue
                if !archivedSelectionLoaded {
                    pendingSelection = await selectionArchive.load(); archivedSelectionLoaded = true
                    guard !Task.isCancelled, generation == current else { return }
                }
                let previous = assets + pendingSelection
                let valid = LibraryCatalogueReconciliation.unchangedIDs(current: catalogue, previous: assets)
                let changed = Set(catalogue.map(\.id)) != Set(assets.map(\.id)) || valid.count != catalogue.count
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
                analysisIssues = analysisIssues.filter { valid.contains($0.assetID) }
                if changed && !analysisPaused { sessionProgress = .init() }
                for connected in connectedFolders {
                    guard let root = folderScopes[connected.id] else { continue }
                    let records = try await folders.recoveryRecords(root: root)
                    for record in records {
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
        let current = UUID(); generation = current
        let configuration = LibraryConfiguration.stored()
        if checkpoint != nil && (checkpointConfiguration != configuration || checkpointSources != selectedSourceIDs) {
            checkpoint = nil; error = L10n.tr("Sources or scan settings changed. A new scan will start.")
        }
        checkpointConfiguration = configuration; checkpointSources = selectedSourceIDs
        for (id, root) in folderScopes { folderAdapters[id] = FolderSourceAdapter(rootURL: root, cleanupAvailable: true, configuration: configuration) }
        analysisSession = MacAnalysisSession()
        let session = analysisSession, control = analysisSession.control, resumeCheckpoint = checkpoint
        analysisPaused = false; lastAnalysisAllowedNetwork = allowNetwork
        analyzing = true; sessionProgress = .init(); analysisIssues = []; qualityAssessments = [:]
        exact = []; similar = []; similarVideos = []
        status = L10n.tr("Loading sources"); analysisProcessed = 0; analysisTotal = scopedAssets.count
        let adapter = scanAdapter
        task = Task {
            defer { if generation == current { analyzing = false; status = nil; drainRefresh(); scheduleSave() } }
            let coordinator = LibraryAnalysisCoordinator { [weak self] update in await self?.receiveAnalysis(update, generation: current) }
            do {
                try await coordinator.run(adapter: adapter, allowNetwork: allowNetwork, configuration: configuration, control: control,
                    checkpoint: resumeCheckpoint, checkpointUpdate: { [weak self] value in
                        session.capture(value)
                        Task { @MainActor in guard let self, self.generation == current, !self.sessionProgress.isComplete else { return }; self.checkpoint = value; self.scheduleSave() }
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
        case .exact(let groups, _, let items, let issues):
            sessionProgress.update(.exact, .init(status: issues.isEmpty ? .completed : .partial, processed: items.count, total: items.count))
            exact = groups
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
        case .failure(_, let message): error = message
        case .finished(let progress): sessionProgress = progress; checkpoint = nil
        }
    }
    private func replaceIssues(_ stage: AnalysisStage, _ issues: [AnalysisIssue]) {
        analysisIssues.removeAll { $0.stage == stage }; analysisIssues.append(contentsOf: issues)
        skippedCloudItems = Set(analysisIssues.filter { $0.reason == .downloadRequired }.map(\.assetID)).count
    }
    func cancelAnalysis() {
        generation = UUID(); analysisPaused = false; task?.cancel(); checkpoint = nil
        analyzing = false; status = nil; sessionProgress.cancel()
        scheduleSave(); drainRefresh()
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
        guard !busy, !loading, !analyzing else { return false }
        guard selection == expectedIDs else {
            error = L10n.tr("Your selection changed. Review it again before removing items."); return false
        }
        guard unresolvedSelectionIDs.intersection(selection).isEmpty, pendingSelection.filter({ selection.contains($0.id) }).isEmpty else {
            error = L10n.tr("Reconnect unavailable sources or remove their items from your selection."); return false
        }
        let snapshot = selected
        if let reviewedAssets, Set(snapshot) != Set(reviewedAssets) { error = L10n.tr("Your selection changed. Review it again before removing items."); return false }
        guard !snapshot.isEmpty, snapshot.count == expectedIDs.count else { return false }
        busy = true; status = L10n.tr("Reviewing selected items…")
        defer { busy = false; status = nil; drainRefresh() }
        var completedIDs: Set<String> = []
        do {
            try LibraryRevisionValidator.validate(snapshot)
            let batches = Dictionary(grouping: snapshot, by: \.sourceID)
            var prepared: [String: [(asset: UniversalMediaAsset, expectedDigest: String)]] = [:]
            for (id, batch) in batches where id != LibrarySource.photos.id {
                guard let folder = folderAdapters[id], let root = folderScopes[id], await folders.preflight(root: root) else { throw UniversalScanError.sourcePermissionDenied }
                let candidates = try await cleanupPreflight.prepare(batch, adapter: folder)
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
                try await saveStateNow()
            }
            for connected in connectedFolders {
                guard let candidates = prepared[connected.id], let root = folderScopes[connected.id] else { continue }
                try LibraryRevisionValidator.validate(candidates.map(\.asset))
                let record = try await folders.quarantine(root: root, selections: candidates, allowPartialFamilies: allowPartialFamilies)
                history.insert(MacRecoveryEntry(id: record.id, date: record.createdAt, count: candidates.count,
                    bytes: MediaSelectionSummary(candidates.map(\.asset)).knownBytes, folderRecord: record,
                    bookmark: bookmarks[connected.id], isPhotos: false), at: 0)
                completedIDs.formUnion(candidates.map { $0.asset.id })
            }
            return true
        } catch {
            let ns = error as NSError
            if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError && completedIDs.isEmpty { return false }
            self.error = completedIDs.isEmpty ? error.localizedDescription :
                L10n.format("Moved: %lld items. Not moved: %lld items. See History for recovery.", completedIDs.count, snapshot.count - completedIDs.count) + "\n\n" + error.localizedDescription
            Task { refresh() }
            return false
        }
    }
    func restore(_ entry: MacRecoveryEntry) async {
        guard !busy, !loading, !analyzing, var record = entry.folderRecord, record.restoredAt == nil else { return }
        busy = true; status = L10n.tr("Restoring files…")
        defer { busy = false; status = nil; refresh() }
        do {
            #if DEBUG
            if LaunchArguments.contains("-keptoraRestoreConflictUITesting"), let original = record.operations.first?.originalURL {
                try Data("Occupied original — must not be overwritten".utf8).write(to: original)
            }
            #endif
            var recoveryScope: URL?
            if let bookmark = entry.bookmark {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                guard url.startAccessingSecurityScopedResource() else { throw UniversalScanError.sourcePermissionDenied }
                recoveryScope = url; record = try record.rebased(to: url)
            }
            defer { recoveryScope?.stopAccessingSecurityScopedResource() }
            let restored = try await folders.restore(record)
            if let index = history.firstIndex(where: { $0.id == entry.id }) { history[index].folderRecord = restored }
            persistHistory()
        } catch { self.error = error.localizedDescription }
    }
    private func persistHistory() {
        scheduleSave()
    }

    private func drainRefresh() {
        guard !busy, !loading, !analyzing else { return }
        if pendingAccessRefresh { pendingAccessRefresh = false; Task { await refreshPhotosAccess() } }
        if pendingRefresh { refresh() }
    }
    func contextChanged() { scheduleSave() }
    private func stateSnapshot() -> MacLibraryState {
        var context = galleryContext; context.scrollID = scrollAnchorID; context.focusedID = focusedAssetID
        return .init(selection: selection, selectedAssets: selected, decisions: decisions, history: history, bookmarks: bookmarks,
              excludedSources: scanSourceSelection.excludedIDs, context: context, checkpoint: checkpoint,
              configuration: checkpointConfiguration, checkpointSources: checkpointSources,
              analysis: .init(assets: assets, exact: exact, similar: similar, videos: similarVideos, quality: qualityAssessments, progress: sessionProgress))
    }
    private func scheduleSave() {
        guard repositoryLoaded, persistenceError == nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            await self?.flushState()
        }
    }
    private func saveStateNow() async throws {
        guard persistenceError == nil else { throw CocoaError(.fileWriteUnknown) }
        repositorySequence += 1
        try await repository.save(stateSnapshot(), sequence: repositorySequence)
    }
    @discardableResult func flushState() async -> Bool {
        guard repositoryLoaded else { return true }
        do { try await saveStateNow(); return true }
        catch { self.error = L10n.tr("Your session could not be saved. Keep Keptora open and check available storage.") + "\n" + error.localizedDescription; return false }
    }
    func repairPersistence() async {
        guard canRepairPersistence else { return }
        do {
            try await repository.preserveUnreadableFiles()
            persistenceError = nil; repositoryLoaded = true; repositorySequence = 0
            try await saveStateNow(); error = nil
        } catch { self.error = error.localizedDescription }
    }
    func prepareForTermination() async -> Bool {
        // Let a system-confirmed removal finish; never interrupt a move halfway through quit.
        while busy { try? await Task.sleep(nanoseconds: 100_000_000) }
        if analyzing {
            analysisPaused = true; task?.cancel(); await task?.value
            checkpoint = analysisSession.snapshot() ?? checkpoint
        }
        saveTask?.cancel(); return await flushState()
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
            recoveryIssues: history.reduce(0) { $0 + ($1.folderRecord?.unresolvedCount ?? ($1.operationState == .planned ? 1 : 0)) }, hasError: error != nil)
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
