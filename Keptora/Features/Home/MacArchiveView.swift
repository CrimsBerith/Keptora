import AppKit
import KeptoraCore
import Photos
import SwiftUI

struct MacScanSourcesSection: View {
    @EnvironmentObject private var archive: MacArchiveModel
    private var masterSymbol: String {
        switch archive.sourceSelectionState {
        case .none: return "square"
        case .some: return "minus.square.fill"
        case .all: return "checkmark.square.fill"
        }
    }
    private var masterValue: LocalizedStringKey {
        switch archive.sourceSelectionState {
        case .none: return "Not selected"
        case .some: return "Partially selected"
        case .all: return "Selected"
        }
    }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Button { archive.toggleAllScanSources() } label: {
                    Label("All Connected Sources", systemImage: masterSymbol).font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityValue(Text(masterValue)).accessibilityIdentifier("sources.selectAll")
                    .disabled(archive.sourceControlsDisabled || LibrarySourceSelection().selectedIDs(in: archive.connectedSources, coverage: archive.coverage).isEmpty)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(archive.connectedSources) { source in
                            let report = archive.coverage.first { $0.id == source.id }
                            let available = report == nil || report?.authorization == .authorized || report?.authorization == .limited
                            let selected = archive.selectedSourceIDs.contains(source.id)
                            Button { archive.toggleScanSource(source.id) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected ? "checkmark.square.fill" : "square").foregroundStyle(selected ? KeptoraDesign.accent : Color.secondary)
                                    Image(systemName: source.scanSymbol).foregroundStyle(.secondary).frame(width: 22)
                                    Text(source.kind == .photos ? L10n.tr("Photos / iCloud Photos") : source.displayName)
                                    Spacer()
                                    if let report {
                                        (report.error == nil ? Text(String(format: L10n.tr("%lld items"), report.itemCount)) : Text("Count incomplete")).monospacedDigit().foregroundStyle(.secondary)
                                        Text(LocalizedStringKey(report.statusKey)).font(.caption)
                                            .foregroundStyle(report.error != nil || report.authorization == .limited ? Color.orange : Color.secondary)
                                    } else { Text("Loading item count…").foregroundStyle(.secondary) }
                                }.frame(maxWidth: .infinity, minHeight: 28, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(archive.sourceControlsDisabled || !available)
                                .accessibilityValue(Text(selected ? LocalizedStringKey("Selected") : LocalizedStringKey("Not selected")))
                                .accessibilityIdentifier("sources.source." + source.id)
                        }
                    }
                }.frame(height: min(CGFloat(archive.connectedSources.count) * 38, 160))
                Divider()
                if archive.selectedSourceIDs.isEmpty {
                    Text("Select at least one source").foregroundStyle(.secondary).accessibilityIdentifier("sources.emptySelection")
                } else {
                    Text(String(format: L10n.tr("%lld sources selected · %lld items"), archive.selectedSourceIDs.count, archive.scopedAssets.count))
                        .foregroundStyle(.secondary).accessibilityIdentifier("sources.summary")
                }
                Text("Selected sources appear together. The same item in overlapping folders is counted once.").font(.caption).foregroundStyle(.secondary)
            }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MacSourceSetupView: View {
    var isStartupSetup = false
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.macSourceSetupCompleted) private var sourceSetupCompleted = false
    private var controlsDisabled: Bool { archive.busy || archive.analyzing || archive.loading || archive.isRequestingPhotosAccess }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image("onboarding_privacy").resizable().scaledToFit().frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                    Text("Connect your library").font(.title.bold())
                    Text("Connect Photos and folders once. Choose which sources to include in each scan.").foregroundStyle(.secondary)
                    if archive.isRequestingPhotosAccess { ProgressView("Waiting for Photos access…") }
                    if !archive.connectedSources.isEmpty { MacScanSourcesSection() }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Photos", systemImage: "photo.on.rectangle.angled").font(.headline)
                            Text("Full Photos access includes iCloud Photos. Limited access shows only the items you approve.")
                            if archive.photosConnected { Label("Photos Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                            else if archive.authorization == .notDetermined {
                                Button("Connect Photos") { archive.connectPhotos() }
                            } else {
                                Text(archive.authorization == .unavailable ? LocalizedStringKey("Photos is not available on this device.") : (archive.authorization == .restricted ? LocalizedStringKey("Access is restricted on this device.") : LocalizedStringKey("Photos access disabled")))
                                if archive.authorization == .denied { Button("Open Settings") { archive.openPhotosSettings() }.accessibilityIdentifier("mac.sourceSetup.openSettings") }
                            }
                            if archive.authorization == .limited {
                                Text("Limited Photos access").foregroundStyle(.orange)
                                Button("Manage Access") { archive.openPhotosSettings() }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Files & cloud folders", systemImage: "folder.badge.plus").font(.headline)
                            Text("Choose Pictures, Downloads, iCloud Drive or another cloud folder. Keptora remembers folders you approve; other apps' private storage is unavailable.")
                            Text("Cloud providers may download files according to their own settings.").font(.callout).foregroundStyle(.secondary)
                            ForEach(archive.connectedFolders) { folder in Label(folder.displayName, systemImage: "checkmark.circle") }
                            Button("Add Folders…") { archive.chooseFolder() }.accessibilityIdentifier("mac.sourceSetup.folders")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("No camera, microphone, contacts or live location permission is needed. Existing photo details are read only from media you approve.").font(.callout).foregroundStyle(.secondary)
                    Text("You can continue without access and add sources later.").font(.callout).foregroundStyle(.secondary)
                    ForEach(Array(archive.connectionErrors.enumerated()), id: \.offset) { entry in Text(entry.element).foregroundStyle(.orange) }
                }.padding(24).disabled(controlsDisabled)
            }
            Divider()
            HStack {
                Spacer()
                Button(isStartupSetup ? LocalizedStringKey("Continue to Library") : LocalizedStringKey("Done")) {
                    if isStartupSetup { sourceSetupCompleted = true }
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(archive.isRequestingPhotosAccess)
                    .accessibilityIdentifier("mac.sourceSetup.continue")
            }.padding(18)
        }
        .frame(width: 650, height: 600)
        .accessibilityIdentifier("mac.sourceSetup")
        .interactiveDismissDisabled(isStartupSetup)
        .task {
            if isStartupSetup, LibraryAccessPolicy.shouldRequestPhotosAtStartup(archive.authorization) {
                await archive.requestPhotosAccess(showError: false)
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK", role: .cancel) { archive.error = nil }
        } message: { Text(archive.error ?? "") }
    }
}

struct MacRecoveryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let count: Int
    let bytes: Int64
    var folderRecord: FolderQuarantineRecord?
    var bookmark: Data?
    var isPhotos: Bool
}

@MainActor
final class MacArchiveModel: ObservableObject {
    @Published var assets: [UniversalMediaAsset] = []
    @Published var selection: Set<String> = [] { didSet { if sourceReady { persistSelection() } } }
    @Published var sourceName = L10n.tr("Choose a source")
    @Published var sourceRoot: URL?
    @Published var busy = false
    @Published var loading = false
    @Published var analyzing = false
    @Published var analysisPaused = false
    private var lastAnalysisAllowedNetwork = false
    @Published var error: String?
    @Published var history: [MacRecoveryEntry] = []
    @Published var exact: [UniversalExactGroup] = []
    @Published var similarVideos: [UniversalSimilarityGroup] = []
    @Published var coverage: [LibrarySourceCoverage] = []
    @Published var connectionErrors: [String] = []
    @Published var connectedFolders: [LibrarySource] = []
    @Published var photosConnected = false
    @Published var skippedCloudItems = 0
    @Published private(set) var scanSourceSelection = LibrarySourceSelection(excludedIDs: Set(UserDefaults.standard.stringArray(forKey: AppStorageKeys.macExcludedScanSources) ?? []))
    private var sourceCatalogue = LibrarySourceCatalogue()
    private var folderAdapters: [String: FolderSourceAdapter] = [:]
    private var folderScopes: [String: URL] = [:]
    private var bookmarks: [String: Data] = [:]
    var connectedSources: [LibrarySource] { (photosConnected ? [.photos] : []) + connectedFolders }
    var selectedSourceIDs: Set<String> { scanSourceSelection.selectedIDs(in: connectedSources, coverage: coverage) }
    var scopedAssets: [UniversalMediaAsset] { sourceCatalogue.assets(in: connectedSources, selectedIDs: selectedSourceIDs, current: assets) }
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
        UserDefaults.standard.set(Array(scanSourceSelection.excludedIDs).sorted(), forKey: AppStorageKeys.macExcludedScanSources)
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
    var reviewGroups: [LibraryReviewGroup] { LibraryReviewGroup.combined(exact: exact, similar: similar + similarVideos) }
    func sourceLabel(_ item: UniversalMediaAsset) -> String {
        item.sourceLabel(in: connectedSources)
    }
    @Published var similar: [UniversalSimilarityGroup] = []
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
    private let selectionArchive = LibrarySelectionArchive(name: "selection-mac-v3")
    private var selectionSequence = 0
    private var archivedSelectionLoaded = false
    private func persistSelection() {
        UserDefaults.standard.set(Array(selection).sorted(), forKey: selectionKey)
        selectionSequence += 1
        let sequence = selectionSequence, snapshot = selected
        Task { try? await selectionArchive.save(snapshot, sequence: sequence) }
    }
    func discardPendingSelection() {
        selection.subtract(pendingSelection.map(\.id)); selection.subtract(unresolvedSelectionIDs); unresolvedSelectionIDs = []; pendingSelection = []
    }
    func keep(_ item: UniversalMediaAsset, in group: LibraryReviewGroup) {
        guard !busy else { return }; decisions.keep(item.id, in: group); selection.remove(item.id); persistDecisions()
    }
    func toggleProtection(_ item: UniversalMediaAsset) {
        guard !busy else { return }; decisions.toggleProtection(item.id)
        if decisions.protectedIDs.contains(item.id) { selection.remove(item.id) }; persistDecisions()
    }
    func protect(_ group: LibraryReviewGroup) {
        guard !busy else { return }; decisions.protect(group); selection.subtract(group.assets.map(\.id)); persistDecisions()
    }
    func selectOthers(in group: LibraryReviewGroup) { guard !busy else { return }; selection.formUnion(decisions.candidates(in: group).map(\.id)) }
    func selectExactSuggestions() { guard !busy else { return }; selection.formUnion(decisions.exactSuggestions(reviewGroups).map(\.id)) }
    private func persistDecisions() { UserDefaults.standard.set(try? JSONEncoder().encode(decisions), forKey: "Keptora.ReviewDecisions.Mac") }
    private func reconcileSelection(previousSelection: [UniversalMediaAsset] = []) {
        var saved = Set(UserDefaults.standard.stringArray(forKey: selectionKey) ?? [])
        if UserDefaults.standard.object(forKey: selectionKey) == nil {
            saved.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection.Mac.photos") ?? [])
            for root in folderScopes.values { saved.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection.Mac." + StableDigest.fnv1a64(root.standardizedFileURL.path)) ?? []) }
        }
        for item in assets {
            if case .file(let url) = item.reference {
                let oldID = "file:" + StableDigest.fnv1a64(item.sourceID + "|" + url.standardizedFileURL.path)
                if saved.remove(oldID) != nil { saved.insert(item.id) }
            }
        }
        let resolved = PendingLibrarySelection(ids: saved, current: assets, previous: previousSelection + pendingSelection, coverage: coverage)
        pendingSelection = resolved.pending; unresolvedSelectionIDs = resolved.unresolvedIDs; selection = resolved.ids
    }
    private let photos = PhotoLibrarySourceAdapter()
    private let folders = FolderQuarantineExecutor()
    private let analyzer = VisualSimilarityAnalyzer()
    private var task: Task<Void, Never>?
    private let historyKey = "Keptora.ManualCleanupHistory.Mac"
    init() {
        if LaunchArguments.contains(LaunchArguments.resetSourceSetupUITesting) {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.macSourceSetupCompleted)
        }
        if let data = UserDefaults.standard.data(forKey: historyKey), let entries = try? JSONDecoder().decode([MacRecoveryEntry].self, from: data) { history = entries }
    }
    deinit { task?.cancel(); for url in folderScopes.values { url.stopAccessingSecurityScopedResource() } }
    var selected: [UniversalMediaAsset] { assets.filter { selection.contains($0.id) } + pendingSelection.filter { selection.contains($0.id) } }
    var albums: [MediaAlbum] {
        var values: [String: MediaAlbum] = [:]
        for asset in scopedAssets { for album in asset.context?.albums ?? [] { values[album.id] = album } }
        return values.values.sorted { $0.title < $1.title }
    }
    func restoreConnections() async {
        guard !connectionsRestored else { return }
        connectionsRestored = true
        let saved = UserDefaults.standard.dictionary(forKey: "Keptora.UnifiedFolderBookmarks.Mac")?.compactMapValues { $0 as? Data } ?? [:]
        bookmarks = saved
        for bookmark in saved.values {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                try addFolder(url)
            } catch { connectionErrors.append(L10n.tr("Reconnect an unavailable folder in Sources.")) }
        }
        authorization = await currentPhotosAuthorization()
        photosConnected = authorization == .authorized || authorization == .limited
        updateConnections(); refresh()
    }
    private func updateConnections() {
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
        guard connectionsRestored, !busy, !analyzing, !loading, !isRequestingPhotosAccess else { return }
        let latest = await currentPhotosAuthorization()
        let wasConnected = photosConnected
        authorization = latest
        photosConnected = latest == .authorized || latest == .limited
        updateConnections()
        if sourceReady { refresh() }
        else if wasConnected { pendingSelection = selected; assets = []; exact = []; similar = []; similarVideos = []; coverage = [] }
    }
    func openPhotosSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") else { return }
        NSWorkspace.shared.open(url)
    }
    private func addFolder(_ root: URL) throws {
        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: true)
        guard folderAdapters[adapter.source.id] == nil else { return }
        guard root.startAccessingSecurityScopedResource() else { throw UniversalScanError.sourcePermissionDenied }
        do {
            let bookmark = try root.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            folderScopes[adapter.source.id] = root; folderAdapters[adapter.source.id] = adapter
            bookmarks[adapter.source.id] = bookmark; connectedFolders.append(adapter.source)
            UserDefaults.standard.set(bookmarks, forKey: "Keptora.UnifiedFolderBookmarks.Mac")
        } catch { root.stopAccessingSecurityScopedResource(); throw error }
    }
    func chooseFolder() {
        guard !busy, !analyzing, !loading else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for root in panel.urls { do { try addFolder(root) } catch { self.error = error.localizedDescription } }
        updateConnections(); refresh()
    }
    func disconnectFolder(_ id: String) {
        guard !busy, !loading, !analyzing else { return }
        folderScopes.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
        folderAdapters.removeValue(forKey: id); bookmarks.removeValue(forKey: id)
        connectedFolders.removeAll { $0.id == id }
        UserDefaults.standard.set(bookmarks, forKey: "Keptora.UnifiedFolderBookmarks.Mac")
        updateConnections()
        if sourceReady { refresh() } else { pendingSelection = selected; assets = []; exact = []; similar = []; similarVideos = []; coverage = [] }
    }
    func refresh() {
        guard sourceReady, !busy, !analyzing, !loading else { return }
        task?.cancel(); loading = true
        let current = UUID(); generation = current
        let adapter = self.adapter
        task = Task {
            defer { if generation == current { loading = false } }
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
                assets = catalogue; reconcileSelection(previousSelection: previous)
                // Metadata or membership changes invalidate prior analysis.
                exact = []; similar = []; similarVideos = []; qualityAssessments = [:]; analysisIssues = []; sessionProgress = .init()
                for connected in connectedFolders {
                    guard let root = folderScopes[connected.id] else { continue }
                    let records = try await folders.recoveryRecords(root: root)
                    for record in records {
                        if let index = history.firstIndex(where: { $0.id == record.id }) { history[index].folderRecord = record; continue }
                        history.insert(MacRecoveryEntry(id: record.id, date: record.createdAt, count: record.operations.count, bytes: 0,
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
        analysisPaused = false; lastAnalysisAllowedNetwork = allowNetwork
        analyzing = true; sessionProgress = .init(); analysisIssues = []; qualityAssessments = [:]
        exact = []; similar = []; similarVideos = []
        status = L10n.tr("Loading sources"); analysisProcessed = 0; analysisTotal = scopedAssets.count
        let adapter = scanAdapter
        task = Task {
            defer { if generation == current { analyzing = false; status = nil } }
            let coordinator = LibraryAnalysisCoordinator { [weak self] update in await self?.receiveAnalysis(update, generation: current) }
            do { try await coordinator.run(adapter: adapter, allowNetwork: allowNetwork) }
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
            sessionProgress.update(stage, value)
            if let focus = [AnalysisStage.photos, .exact, .videos, .catalogue].first(where: { sessionProgress.stages[$0]?.status == .running }),
               let progress = sessionProgress.stages[focus] {
                status = L10n.tr(String.LocalizationValue(focus.titleKey)); analysisProcessed = progress.processed; analysisTotal = progress.total
            }
        case .exact(let groups, _, let items, let issues):
            exact = groups
            let latest = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            assets = assets.map { latest[$0.id] ?? $0 }; replaceIssues(.exact, issues)
        case .photoGroups(let groups): similar = groups
        case .exactGroups(let groups): exact = groups
        case .photos(let groups, let quality, let issues): similar = groups; qualityAssessments = quality; replaceIssues(.photos, issues); skippedPreviews = issues.count
        case .findings(let quality, let issues): qualityAssessments = quality; replaceIssues(.photos, issues)
        case .videos(let groups, let issues): similarVideos = groups; replaceIssues(.videos, issues)
        case .metrics: break
        case .failure(_, let message): error = message
        case .finished(let progress): sessionProgress = progress
        }
    }
    private func replaceIssues(_ stage: AnalysisStage, _ issues: [AnalysisIssue]) {
        analysisIssues.removeAll { $0.stage == stage }; analysisIssues.append(contentsOf: issues)
        skippedCloudItems = Set(analysisIssues.filter { $0.reason == .downloadRequired }.map(\.assetID)).count
    }
    func cancelAnalysis() {
        generation = UUID(); analysisPaused = false; task?.cancel()
        analyzing = false; status = nil; sessionProgress.cancel()
    }
    func pauseAnalysis() {
        cancelAnalysis(); analysisPaused = true
    }
    func resumeAnalysis() { analyze(allowNetwork: lastAnalysisAllowedNetwork) }
    func removeSelection(expectedIDs: Set<String>, reviewedAssets: [UniversalMediaAsset]? = nil) async -> Bool {
        guard !busy, !loading, !analyzing, selection == expectedIDs else { return false }
        guard unresolvedSelectionIDs.intersection(selection).isEmpty, pendingSelection.filter({ selection.contains($0.id) }).isEmpty else {
            error = L10n.tr("Reconnect unavailable sources or remove their items from your selection."); return false
        }
        let snapshot = selected
        if let reviewedAssets, Set(snapshot) != Set(reviewedAssets) { error = L10n.tr("Your selection changed. Review it again before removing items."); return false }
        guard !snapshot.isEmpty, snapshot.count == expectedIDs.count else { return false }
        busy = true; status = L10n.tr("Reviewing selected items…")
        defer { busy = false; status = nil }
        do {
            try LibraryRevisionValidator.validate(snapshot)
            let batches = Dictionary(grouping: snapshot, by: \.sourceID)
            var prepared: [String: [(asset: UniversalMediaAsset, expectedDigest: String)]] = [:]
            for (id, batch) in batches where id != LibrarySource.photos.id {
                guard let folder = folderAdapters[id], let root = folderScopes[id], await folders.preflight(root: root) else { throw UniversalScanError.sourcePermissionDenied }
                var candidates: [(asset: UniversalMediaAsset, expectedDigest: String)] = []
                for item in batch { let hash = try await folder.exactFingerprint(for: item, allowNetwork: false, progress: { _ in }); candidates.append((item, hash.digest)) }
                prepared[id] = candidates
            }
            var completedIDs: Set<String> = []
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
                try await photos.deleteSelectedAssets(localIdentifiers: ids, intent: .manualSelection)
                history.insert(MacRecoveryEntry(id: UUID(), date: Date(), count: batch.count, bytes: MediaSelectionSummary(batch).knownBytes, folderRecord: nil, bookmark: nil, isPhotos: true), at: 0)
                completedIDs.formUnion(batch.map(\.id))
            }
            for connected in connectedFolders {
                guard let candidates = prepared[connected.id], let root = folderScopes[connected.id] else { continue }
                let record = try await folders.quarantine(root: root, selections: candidates)
                history.insert(MacRecoveryEntry(id: record.id, date: record.createdAt, count: candidates.count,
                    bytes: MediaSelectionSummary(candidates.map(\.asset)).knownBytes, folderRecord: record,
                    bookmark: bookmarks[connected.id], isPhotos: false), at: 0)
                completedIDs.formUnion(candidates.map { $0.asset.id })
            }
            return true
        } catch {
            let ns = error as NSError
            if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError { return false }
            self.error = error.localizedDescription
            Task { refresh() }
            return false
        }
    }
    func restore(_ entry: MacRecoveryEntry) async {
        guard !busy, let record = entry.folderRecord, record.restoredAt == nil else { return }
        busy = true; status = L10n.tr("Restoring files…")
        defer { busy = false; status = nil; refresh() }
        do {
            var recoveryScope: URL?
            if let bookmark = entry.bookmark {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                if url.startAccessingSecurityScopedResource() { recoveryScope = url }
            }
            defer { recoveryScope?.stopAccessingSecurityScopedResource() }
            let restored = try await folders.restore(record)
            if let index = history.firstIndex(where: { $0.id == entry.id }) { history[index].folderRecord = restored }
            persistHistory()
        } catch { self.error = error.localizedDescription }
    }
    private func persistHistory() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(history), forKey: historyKey) }
        catch { self.error = error.localizedDescription }
    }
}

struct MacArchiveView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    @State private var search = ""
    @State private var finding: LibraryFindingFilter = .all
    @State private var smartOrder = true
    @State private var comparing: LibraryReviewGroup?
    @State private var cloudScan = false
    @State private var media = 0
    @State private var albumID = ""
    @State private var comparisonGroup: UniversalSimilarityGroup?
    @State private var showPlan = false
    @State private var inspected: UniversalMediaAsset?
    @State private var previewNetwork = false
    @State private var undoIDs: Set<String>?
    @State private var showAccessGuide = false
    private var visible: [UniversalMediaAsset] {
        let findingIDs = finding.ids(groups: archive.reviewGroups, quality: archive.qualityAssessments)
        return archive.scopedAssets.filter { item in
            (findingIDs == nil || findingIDs!.contains(item.id)) &&
            (media == 0 || (media == 1 ? item.mediaKind == .image : item.mediaKind == .video)) &&
            (albumID.isEmpty || item.context?.albums.contains { $0.id == albumID } == true) &&
            (comparisonGroup == nil || comparisonGroup!.assets.contains { $0.id == item.id }) &&
            (search.isEmpty || item.displayName.localizedCaseInsensitiveContains(search))
        }.sorted { ($0.context?.captureDate ?? $0.creationDate ?? .distantPast) > ($1.context?.captureDate ?? $1.creationDate ?? .distantPast) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("All Photos & Videos").font(.title2.bold())
                    Text(archive.sourceSelectionState == .all ? LocalizedStringKey("All Connected Sources") : LocalizedStringKey("Selected Sources")).foregroundStyle(.secondary)
                }
                Spacer()
                Button(archive.photosConnected ? LocalizedStringKey("Photos Connected") : LocalizedStringKey("Connect Photos")) { archive.connectPhotos() }
                Button("Add Folders…") { archive.chooseFolder() }
                Button { archive.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh Library")
            }.padding(20).disabled(archive.busy || archive.analyzing)
            if !archive.connectedSources.isEmpty {
                Button { showAccessGuide = true } label: {
                    HStack { Label("Scan Sources", systemImage: "checklist"); Spacer(); Text(archive.selectedSourceIDs.count.formatted()); Image(systemName: "chevron.right") }
                }.padding(.horizontal, 20).padding(.bottom, 12).accessibilityIdentifier("mac.archive.sourcesSummary")
            }
            DisclosureGroup("Source Access") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Photos includes iCloud Photos. Files includes the folders you connect.").font(.callout).foregroundStyle(.secondary)
                    Text("Cloud providers may download files according to their own settings.").font(.caption).foregroundStyle(.secondary)
                    Button("Permissions & Sources") { showAccessGuide = true }
                    ForEach(archive.coverage) { report in
                        HStack {
                            Label(report.source.localizedScanTitle, systemImage: report.error == nil ? "checkmark.circle" : "exclamationmark.triangle")
                            Spacer(); Text(report.itemCount.formatted())
                        }.font(.callout)
                        if report.error != nil { Text("Some items in this source are unavailable. Reconnect or check access.").font(.caption).foregroundStyle(.orange) }
                    }
                    ForEach(archive.connectedFolders) { folder in
                        HStack { Text(folder.displayName); Spacer(); Button("Disconnect") { archive.disconnectFolder(folder.id) } }
                    }
                    ForEach(Array(archive.connectionErrors.enumerated()), id: \.offset) { entry in Text(entry.element).font(.caption).foregroundStyle(.orange) }
                }
            }.padding(.horizontal, 20).padding(.bottom, 12).disabled(archive.busy || archive.loading || archive.analyzing)
            Text("Connected sources only. Add Photos and folders in Sources.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
            if archive.coverage.contains(where: { $0.error != nil }) || !archive.connectionErrors.isEmpty {
                Label("Some sources have limited access. Check Source Access.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).padding(12)
            }
            Divider()
            if archive.assets.isEmpty && !archive.loading {
                VStack(spacing: 16) {
                    Image("onboarding_privacy").resizable().scaledToFit().frame(maxWidth: 520).clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
                    Text("Your photos. Your choice.").font(.largeTitle.bold())
                    Text("Open Photos or a folder. Select any photo or video without waiting for duplicate analysis.").foregroundStyle(.secondary)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                filters
                if archive.loading { ProgressView("Loading your library…").padding() }
                if archive.selectedSourceIDs.isEmpty {
                    Text("Select at least one source").font(.headline).padding()
                    Text("Tick a source above to show its photos and videos.").foregroundStyle(.secondary)
                }
                if archive.authorization == .limited {
                    Text("Limited Photos access. Keptora can only show the items you allow.").font(.callout).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                if archive.skippedPreviews > 0 {
                    Text(String(format: L10n.tr("%lld previews could not be analyzed. Results cover only accessible items."), archive.skippedPreviews)).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                if archive.skippedCloudItems > 0 {
                    Text(String(format: L10n.tr("%lld originals could not be analyzed. They remain in the library."), archive.skippedCloudItems)).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                Picker("Library view", selection: $finding) {
                    ForEach(LibraryFindingFilter.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 640).padding(12)
                if archive.sessionProgress.isFinished && !archive.sessionProgress.isComplete && !archive.sessionProgress.stages.values.contains(where: { $0.status == .cancelled }) {
                    Label("Analysis partially completed. Some items need attention.", systemImage: "exclamationmark.triangle").font(.caption).padding(.horizontal, 20)
                }
                if !archive.analysisIssues.isEmpty {
                    DisclosureGroup("Items needing attention") {
                        ForEach(AnalysisIssueReason.allCases, id: \.rawValue) { reason in
                            let count = Set(archive.analysisIssues.filter { $0.reason == reason }.map(\.assetID)).count
                            if count > 0 { HStack { Text(LocalizedStringKey(reason.titleKey)); Spacer(); Text(count.formatted()) } }
                        }
                    }.padding(.horizontal, 20)
                }
                ScrollView {
                    if smartOrder {
                        let blocks = LibraryReviewBlock.make(assets: visible, groups: archive.reviewGroups, quality: archive.qualityAssessments, smart: true)
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(blocks) { block in
                                let keepers = Set(block.groups.map { archive.decisions.keeper(in: $0) })
                                Text(LocalizedStringKey(block.titleKey)).font(.headline)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 250), spacing: 12)], spacing: 12) {
                                    ForEach(block.assets) { item in archiveCell(item, suggestedKeeper: keepers.contains(item.id)) }
                                }
                                ForEach(block.groups) { group in
                                    Text(LocalizedStringKey(archive.decisions.keeperReason(in: group, quality: archive.qualityAssessments))).font(.caption).foregroundStyle(.secondary)
                                    HStack {
                                        Text(LocalizedStringKey(group.titleKey)).font(.caption)
                                        Button("Compare Group") { comparing = group }
                                        Button("Select Others") { undoIDs = archive.selection; archive.selectOthers(in: group) }
                                        Button("Protect Group") { undoIDs = archive.selection; archive.protect(group) }
                                    }
                                }
                            }
                        }.padding(20)
                    } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 250), spacing: 12)], spacing: 12) {
                        ForEach(visible) { item in
                            archiveCell(item)
                        }
                    }.padding(20)
                    }
                }.disabled(archive.busy)

            }
            Divider()
            HStack(spacing: 12) {
                let summary = MediaSelectionSummary(archive.selected)
                VStack(alignment: .leading) {
                    Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.headline)
                    let hidden = archive.selection.subtracting(visible.map(\.id)).count
                    if hidden > 0 { Text(String(format: L10n.tr("%lld selected outside this view"), hidden)).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if let status = archive.status { ProgressView().controlSize(.small); Text(status).font(.caption) }
                Button("Select All in This View") { undoIDs = archive.selection; archive.selection.formUnion(visible.map(\.id)) }.keyboardShortcut("a", modifiers: [.command])
                if let undoIDs { Button("Undo") { archive.selection = undoIDs; self.undoIDs = nil }.keyboardShortcut("z", modifiers: [.command]) }
                Button("Clear Selection") { undoIDs = archive.selection; archive.selection.removeAll() }
                Button("Review Selection") { showPlan = true }.buttonStyle(.borderedProminent).disabled(archive.selection.isEmpty)
            }.padding(16).disabled(archive.busy || archive.loading || archive.analyzing)
        }
        .background(KeptoraDesign.canvas)
        .accessibilityIdentifier("mac.page.archive")
        .sheet(isPresented: $showPlan) { MacManualSelectionSheet().environmentObject(archive) }
        .sheet(item: $comparing) { group in MacArchiveGroupReview(group: group).environmentObject(archive) }
        .sheet(item: $inspected) { item in
            VStack(spacing: 14) {
                MacPhotosThumbnail(asset: item, pixelSize: 1600, fit: true, allowNetwork: previewNetwork).frame(minWidth: 600, minHeight: 420)
                Text(item.displayName).font(.headline)
                Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(.secondary)
                if !previewNetwork && (item.requiresNetwork || { if case .photoLibrary = item.reference { return true }; return false }()) { Button("Download Preview from iCloud") { previewNetwork = true } }
                if let date = item.captureDateDescription { Text(date) }
                if let context = item.context, let camera = context.camera { Text(camera) }
                if let location = item.context?.location { Text(String(format: "%.5f, %.5f", location.latitude, location.longitude)) }
                HStack { Button("Close") { inspected = nil }; Button("Select") { archive.selection.insert(item.id); inspected = nil } }
            }.padding(20)
        }
        .alert("Something went wrong", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK") { archive.error = nil }
        } message: { Text(archive.error ?? "") }
        .onChange(of: inspected?.id) { _ in previewNetwork = false }
        .sheet(isPresented: $showAccessGuide) { MacSourceSetupView().environmentObject(archive) }
        .confirmationDialog("Download iCloud originals?", isPresented: $cloudScan) {
            Button("Download and Scan") { archive.analyze(allowNetwork: true) }
        } message: { Text("This may use network data and device storage. You can cancel the scan at any time.") }
        .onChange(of: archive.connectedFolders) { _ in comparisonGroup = nil; albumID = ""; media = 0; search = "" }
        .onChange(of: archive.scanSourceSelection) { _ in comparisonGroup = nil; finding = .all; albumID = ""; media = 0; search = "" }
        .onChange(of: archive.sourceName) { _ in comparisonGroup = nil; albumID = ""; media = 0; search = ""; undoIDs = nil }
    }
    private func archiveCell(_ item: UniversalMediaAsset, suggestedKeeper: Bool = false) -> some View {
                            VStack(alignment: .leading, spacing: 8) {
                                Button { inspected = item } label: {
                                    MacPhotosThumbnail(asset: item).frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .topLeading) {
                                            Label(LocalizedStringKey(item.sourceBadgeKey(in: archive.connectedSources)), systemImage: item.sourceBadgeSymbol(in: archive.connectedSources)).font(.caption.weight(.semibold)).lineLimit(1)
                                                .padding(6).foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 5)).padding(6)
                                        }
                                }.buttonStyle(.plain)
                                HStack {
                                    Text(item.displayName).lineLimit(1)
                                    Spacer()
                                    Toggle("Select", isOn: Binding(get: { archive.selection.contains(item.id) }, set: { enabled in
                                        undoIDs = archive.selection
                                        if enabled { archive.selection.insert(item.id) } else { archive.selection.remove(item.id) }
                                    })).toggleStyle(.checkbox).labelsHidden().accessibilityLabel("Select \(item.displayName)")
                                }
                                if let date = item.captureDateDescription { Text(date).font(.caption).foregroundStyle(.secondary) }
                                if let value = archive.qualityAssessments[item.id]?.findings.first { Label(LocalizedStringKey(value.titleKey), systemImage: value.symbol).font(.caption).foregroundStyle(.secondary) }
                                if archive.decisions.protectedIDs.contains(item.id) { Label("Protected", systemImage: "lock.fill").font(.caption) }
                                if suggestedKeeper { Label("Suggested Keep", systemImage: "bookmark.fill").font(.caption).foregroundStyle(KeptoraDesign.accent) }
                                if item.isFavorite { Label("Favorite", systemImage: "heart.fill").font(.caption) }
                            }
                            .padding(10).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(archive.selection.contains(item.id) ? KeptoraDesign.accent : .clear, lineWidth: 2))
                            .contextMenu { Button("Select") { archive.selection.insert(item.id) }; Button("Preview") { inspected = item }; Button(archive.decisions.protectedIDs.contains(item.id) ? "Unprotect Photo" : "Protect Photo") { archive.toggleProtection(item) } }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Media type", selection: $media) { Text("All").tag(0); Text("Photos").tag(1); Text("Videos").tag(2) }.pickerStyle(.segmented).frame(maxWidth: 240)
                Picker("Album", selection: $albumID) { Text("All Albums").tag(""); ForEach(archive.albums) { Text($0.title).tag($0.id) } }.frame(maxWidth: 220)
                TextField("Search filenames", text: $search).textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("Reset Filters") { media = 0; albumID = ""; search = ""; comparisonGroup = nil; finding = .all }
                Toggle("Keep Related Shots Together", isOn: $smartOrder).toggleStyle(.checkbox)
                Button("Select Exact Copy Suggestions") { undoIDs = archive.selection; archive.selectExactSuggestions() }.disabled(archive.analyzing)
                Spacer()
                if archive.analyzing {
                    ProgressView(value: Double(archive.analysisProcessed), total: Double(max(archive.analysisTotal, 1))).frame(maxWidth: 200)
                    Text(archive.status ?? L10n.tr("Analysis in progress. Groups may change.")).font(.caption)
                    Button("Pause Scan") { archive.pauseAnalysis() }
                    Button("Cancel Scan") { archive.cancelAnalysis() }
                }
                else {
                    if archive.analysisPaused { Button("Resume Scan") { archive.resumeAnalysis() }.disabled(!archive.canScanSelectedSources) }
                    Button("Scan Selected Sources") { archive.analyze() }.accessibilityIdentifier("mac.archive.scanAll").disabled(!archive.canScanSelectedSources)
                    Button("Include Cloud Originals") { cloudScan = true }.disabled(!archive.canScanSelectedSources)
                }
            }
        }.padding(16).disabled(archive.busy)
    }

}

struct MacManualSelectionSheet: View {
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var expectedIDs: Set<String> = []
    @State private var reviewedItems: [UniversalMediaAsset] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Selection").font(.title.bold())
            let summary = MediaSelectionSummary(reviewedItems)
            Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos))
            Text(L10n.tr("Selected Items") + " · " + ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file))
            Text("Media size, not freed space").font(.caption).foregroundStyle(.secondary)
            if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption).foregroundStyle(.secondary) }
            Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.").foregroundStyle(.secondary)
            ForEach(archive.connectedSources) { source in
                let items = reviewedItems.filter { $0.sourceID == source.id }
                if !items.isEmpty {
                    HStack {
                        Text(source.localizedScanTitle + " · " + items.count.formatted())
                        Spacer()
                        Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Moves in connected cloud folders may sync to other devices.").font(.caption).foregroundStyle(.secondary)
            if summary.personalItems > 0 { Label("Includes favorites, hidden, edited or shared items you selected manually.", systemImage: "exclamationmark.triangle") }
            if archive.exact.contains(where: { $0.assets.allSatisfy { archive.selection.contains($0.id) } }) {
                Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            if (!archive.unresolvedSelectionIDs.intersection(archive.selection).isEmpty || !archive.pendingSelection.filter({ archive.selection.contains($0.id) }).isEmpty) {
                Text("Reconnect unavailable sources or remove their items from your selection.")
                Button("Remove Unavailable Items from Selection") { archive.discardPendingSelection(); reviewedItems.removeAll { !archive.selection.contains($0.id) } }
            }
            List(reviewedItems) { item in
                HStack {
                    VStack(alignment: .leading) { Text(item.displayName); Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(.secondary) }; Spacer()
                    Button { archive.selection.remove(item.id); reviewedItems.removeAll { $0.id == item.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove from selection")
                }
            }.disabled(archive.busy)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(archive.busy)
                Spacer()
                if archive.busy { ProgressView(archive.status ?? L10n.tr("Removing selected items…")) }
                Button("Remove Selected Items") { expectedIDs = Set(reviewedItems.map(\.id)); confirm = true }
                    .buttonStyle(.borderedProminent).disabled(archive.busy || archive.loading || archive.analyzing || archive.selected.isEmpty || (!archive.unresolvedSelectionIDs.intersection(archive.selection).isEmpty || !archive.pendingSelection.filter({ archive.selection.contains($0.id) }).isEmpty))
            }
        }.padding(24).frame(minWidth: 640, minHeight: 500).interactiveDismissDisabled(archive.busy)
        .onAppear { reviewedItems = archive.selected }
        .alert("Remove selected items?", isPresented: $confirm) {
            Button("Remove Selected Items", role: .destructive) { Task { if await archive.removeSelection(expectedIDs: expectedIDs, reviewedAssets: reviewedItems) { dismiss() } } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Only the items listed here will be removed. Review the destination and recovery conditions before continuing.") }
        .alert("Something went wrong", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK") { archive.error = nil }
        } message: { Text(archive.error ?? "") }
    }
}

struct MacManualHistoryView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Library Cleanup").font(.title2.bold())
            if archive.history.isEmpty { Text("No manual cleanup history yet.").foregroundStyle(.secondary) }
            ForEach(archive.history) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.date.formatted()).font(.headline)
                        Text(String(format: L10n.tr("%lld items"), entry.count))
                        Text(entry.isPhotos ? "Recover items in Apple Photos → Recently Deleted for up to 30 days unless permanently deleted sooner." : "Files remain in the recovery folder on the same storage.").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if entry.isPhotos {
                        Button("Open Apple Photos") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Photos.app")) }
                    } else if entry.folderRecord?.restoredAt != nil { Label("Restored", systemImage: "checkmark.circle") }
                    else { Button("Restore Files") { Task { await archive.restore(entry) } }.disabled(archive.busy) }
                }.padding(16).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
            }
        }.padding(20)
    }
}

struct CombinedCleanupHistoryView: View {
    @State private var manual = true
    var body: some View {
        VStack(spacing: 0) {
            Picker("History source", selection: $manual) {
                Text("Library Cleanup").tag(true)
                Text("Verified Copy Plans").tag(false)
            }.pickerStyle(.segmented).padding(20).frame(maxWidth: 500)
            if manual { ScrollView { MacManualHistoryView() } }
            else { HistoryView() }
        }
    }
}

private final class MacArchivePhotoObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let changed: @Sendable () -> Void
    init(changed: @escaping @Sendable () -> Void) {
        self.changed = changed; super.init(); PHPhotoLibrary.shared().register(self)
    }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    func photoLibraryDidChange(_ changeInstance: PHChange) { changed() }
}

private struct MacArchiveGroupReview: View {
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.dismiss) private var dismiss
    let group: LibraryReviewGroup
    @State private var allowNetwork = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(LocalizedStringKey(group.titleKey)).font(.title2.bold()); Spacer(); Button("Close") { dismiss() } }
            Text("Compare details before choosing what to keep.").foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 440), spacing: 16)], spacing: 16) {
                    ForEach(group.assets) { item in MacArchiveComparisonTile(item: item, group: group, allowNetwork: allowNetwork).environmentObject(archive) }
                }
            }
            HStack {
                Toggle("Download Preview from iCloud", isOn: $allowNetwork)
                Spacer()
                Button("Protect Group") { archive.protect(group) }
                Button("Select Others") { archive.selectOthers(in: group) }.buttonStyle(.borderedProminent)
            }
            Text("Quality hints require your review.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(minWidth: 650, minHeight: 550)
    }
}
private struct MacArchiveComparisonTile: View {
    @EnvironmentObject private var archive: MacArchiveModel
    let item: UniversalMediaAsset
    let group: LibraryReviewGroup
    let allowNetwork: Bool
    @State private var scale: CGFloat = 1
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MacPhotosThumbnail(asset: item, pixelSize: 1600, fit: true, allowNetwork: allowNetwork)
                .scaleEffect(scale).frame(height: 260).clipped()
                .gesture(MagnificationGesture().onChanged { scale = min(4, max(1, $0)) })
                .onTapGesture(count: 2) { scale = scale > 1 ? 1 : 2 }
            Text(item.displayName).lineLimit(1)
            Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(.secondary)
            if let date = item.captureDateDescription { Text(date).font(.caption) }
            Text("\(item.pixelWidth) × \(item.pixelHeight)").font(.caption)
            ForEach(archive.qualityAssessments[item.id]?.findings ?? [], id: \.rawValue) { value in Label(LocalizedStringKey(value.titleKey), systemImage: value.symbol).font(.caption) }
            if archive.decisions.keeper(in: group) == item.id { Label("Kept in This Group", systemImage: "bookmark.fill") }
            Button("Keep This Photo") { archive.keep(item, in: group) }
        }.padding(12).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
    }
}
