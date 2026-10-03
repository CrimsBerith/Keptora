import AppKit
import KeptoraCore
import Photos
import SwiftUI

struct MacSourceSetupView: View {
    var isStartupSetup = false
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.macSourceSetupCompleted) private var sourceSetupCompleted = false
    @State private var cannotOpenWhatsApp = false
    private var controlsDisabled: Bool { archive.busy || archive.analyzing || archive.loading || archive.isRequestingPhotosAccess }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image("onboarding_privacy").resizable().scaledToFit().frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                    Text("Connect your library").font(.title.bold())
                    Text("Approve Photos and connect folders once. Future scans combine every connected source.").foregroundStyle(.secondary)
                    if archive.isRequestingPhotosAccess { ProgressView("Waiting for Photos access…") }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Photos", systemImage: "photo.on.rectangle.angled").font(.headline)
                            Text("Full Photos access includes iCloud Photos and WhatsApp media saved to Photos. Limited access shows only the items you approve.")
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
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("WhatsApp storage & chat media", systemImage: "bubble.left.and.bubble.right").font(.headline)
                            Text("Keptora can clean copies saved in Photos or folders you choose. It cannot access WhatsApp's private chat storage.")
                            Text("To manage media kept inside WhatsApp, open WhatsApp → Settings → Storage and Data → Manage Storage.")
                            Button("Open WhatsApp") {
                                if let url = URL(string: "whatsapp://") { cannotOpenWhatsApp = !NSWorkspace.shared.open(url) }
                            }
                            Text("Export the chat with media on your phone, transfer it to your Mac, extract the ZIP, then connect the extracted folder to view its photos and videos.")
                            Button("Choose an Exported Folder") { archive.chooseFolder() }
                            Text("Removing exported or saved copies does not free the original WhatsApp chat storage.").font(.callout).foregroundStyle(.secondary)
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
        .alert(cannotOpenWhatsApp ? LocalizedStringKey("WhatsApp could not be opened") : LocalizedStringKey("Something went wrong"),
               isPresented: Binding(get: { cannotOpenWhatsApp || archive.error != nil }, set: { if !$0 { cannotOpenWhatsApp = false; archive.error = nil } })) {
            Button("OK", role: .cancel) { cannotOpenWhatsApp = false; archive.error = nil }
        } message: {
            if cannotOpenWhatsApp { Text("Open WhatsApp manually if it is installed on this device.") }
            else { Text(archive.error ?? "") }
        }
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
    @Published var selection: Set<String> = [] { didSet { if sourceReady { UserDefaults.standard.set(Array(selection).sorted(), forKey: selectionKey) } } }
    @Published var sourceName = String(localized: "Choose a source")
    @Published var sourceRoot: URL?
    @Published var busy = false
    @Published var loading = false
    @Published var analyzing = false
    @Published var error: String?
    @Published var history: [MacRecoveryEntry] = []
    @Published var exact: [UniversalExactGroup] = []
    @Published var similarVideos: [UniversalSimilarityGroup] = []
    @Published var coverage: [LibrarySourceCoverage] = []
    @Published var connectionErrors: [String] = []
    @Published var connectedFolders: [LibrarySource] = []
    @Published var photosConnected = false
    @Published var skippedCloudItems = 0
    private var folderAdapters: [String: FolderSourceAdapter] = [:]
    private var folderScopes: [String: URL] = [:]
    private var bookmarks: [String: Data] = [:]
    var connectedSources: [LibrarySource] { (photosConnected ? [.photos] : []) + connectedFolders }
    var adapter: UnifiedLibraryAdapter {
        var values: [any SourceAdapter] = []
        if photosConnected { values.append(photos) }
        values.append(contentsOf: connectedFolders.compactMap { folderAdapters[$0.id] })
        return UnifiedLibraryAdapter(adapters: values)
    }
    var reviewGroups: [LibraryReviewGroup] { LibraryReviewGroup.combined(exact: exact, similar: similar + similarVideos) }
    func sourceLabel(_ item: UniversalMediaAsset) -> String {
        item.sourceLabel(in: connectedSources, whatsAppAlbumIDs: Set(UserDefaults.standard.stringArray(forKey: "Keptora.WhatsAppAlbumIDs.Mac") ?? []))
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
    private func reconcileSelection() {
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
        selection = saved.intersection(assets.map(\.id))
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
    var selected: [UniversalMediaAsset] { assets.filter { selection.contains($0.id) } }
    var albums: [MediaAlbum] {
        var values: [String: MediaAlbum] = [:]
        for asset in assets { for album in asset.context?.albums ?? [] { values[album.id] = album } }
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
            } catch { connectionErrors.append(String(localized: "Reconnect an unavailable folder in Sources.")) }
        }
        authorization = await currentPhotosAuthorization()
        photosConnected = authorization == .authorized || authorization == .limited
        updateConnections(); refresh()
    }
    private func updateConnections() {
        sourceReady = !connectedSources.isEmpty
        sourceName = String(localized: "All Connected Sources")
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
        else if showError { error = String(localized: "Allow Photos access in System Settings to open this library.") }
    }
    func refreshPhotosAccess() async {
        guard connectionsRestored, !busy, !analyzing, !loading, !isRequestingPhotosAccess else { return }
        let latest = await currentPhotosAuthorization()
        let wasConnected = photosConnected
        authorization = latest
        photosConnected = latest == .authorized || latest == .limited
        updateConnections()
        if sourceReady { refresh() }
        else if wasConnected { assets = []; selection = []; exact = []; similar = []; similarVideos = []; coverage = [] }
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
        if sourceReady { refresh() } else { assets = []; selection = []; exact = []; similar = []; similarVideos = []; coverage = [] }
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
                assets = catalogue; reconcileSelection()
                // Metadata or membership changes invalidate prior analysis.
                exact = []; similar = []; similarVideos = []
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
        guard !busy, !loading, !analyzing, sourceReady else { return }
        analyzing = true; status = String(localized: "Scanning all connected sources…")
        analysisProcessed = 0; analysisTotal = assets.count
        let adapter = self.adapter
        task = Task {
            defer { analyzing = false; status = nil }
            do {
                let result = try await UniversalExactScanner().scan(adapter: adapter, allowNetwork: allowNetwork, fingerprintAllAssets: true) { [weak self] done, total, _ in
                    Task { @MainActor in self?.analysisProcessed = done; self?.analysisTotal = total }
                }
                try Task.checkCancellation()
                assets = result.assets; exact = result.groups; skippedCloudItems = result.skippedNetwork
                coverage = await adapter.coverage; reconcileSelection()
                status = String(localized: "Comparing images and capture details…")
                similar = try await analyzer.analyze(assets: assets, provider: adapter, allowNetwork: allowNetwork, maximumAssets: assets.count) { [weak self] done, total in
                    Task { @MainActor in self?.analysisProcessed = done; self?.analysisTotal = total }
                }
                skippedPreviews = await analyzer.skippedPreviewCount
                status = String(localized: "Comparing videos…")
                similarVideos = try await VideoSimilarityAnalyzer().analyze(assets: assets.filter { $0.mediaKind == .video }, provider: adapter, allowNetwork: allowNetwork) { [weak self] done, total in
                    Task { @MainActor in self?.analysisProcessed = done; self?.analysisTotal = total }
                }
                try Task.checkCancellation()
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
    func cancelAnalysis() { task?.cancel() }
    func removeSelection(expectedIDs: Set<String>) async -> Bool {
        guard !busy, !loading, !analyzing, selection == expectedIDs else { return false }
        let snapshot = selected
        guard !snapshot.isEmpty, snapshot.count == expectedIDs.count else { return false }
        busy = true; status = String(localized: "Reviewing selected items…")
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
        busy = true; status = String(localized: "Restoring files…")
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
    @State private var groupedResults = false
    @State private var cloudScan = false
    @State private var media = 0
    @State private var albumID = ""
    @State private var whatsapp = false
    @State private var whatsappAlbumIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "Keptora.WhatsAppAlbumIDs.Mac") ?? [])
    @State private var comparisonGroup: UniversalSimilarityGroup?
    @State private var showPlan = false
    @State private var inspected: UniversalMediaAsset?
    @State private var previewNetwork = false
    @State private var undoIDs: Set<String>?
    @State private var showAccessGuide = false
    private var visible: [UniversalMediaAsset] {
        let groupedIDs = groupedResults ? Set(archive.reviewGroups.flatMap { $0.assets.map(\.id) }) : Set<String>()
        return archive.assets.filter { item in
            (!groupedResults || groupedIDs.contains(item.id)) &&
            (media == 0 || (media == 1 ? item.mediaKind == .image : item.mediaKind == .video)) &&
            (albumID.isEmpty || item.context?.albums.contains { $0.id == albumID } == true) &&
            (!whatsapp || item.context?.albums.contains { $0.isWhatsAppNamed || whatsappAlbumIDs.contains($0.id) } == true) &&
            (comparisonGroup == nil || comparisonGroup!.assets.contains { $0.id == item.id }) &&
            (search.isEmpty || item.displayName.localizedCaseInsensitiveContains(search))
        }.sorted { ($0.context?.captureDate ?? $0.creationDate ?? .distantPast) > ($1.context?.captureDate ?? $1.creationDate ?? .distantPast) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("All Photos & Videos").font(.title2.bold())
                    Text(archive.sourceName).foregroundStyle(.secondary)
                }
                Spacer()
                Button(archive.photosConnected ? LocalizedStringKey("Photos Connected") : LocalizedStringKey("Connect Photos")) { archive.connectPhotos() }
                Button("Add Folders…") { archive.chooseFolder() }
                Button { archive.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh Library")
            }.padding(20).disabled(archive.busy || archive.analyzing)
            DisclosureGroup("Sources") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Photos includes iCloud Photos and saved WhatsApp albums. Files includes the folders you connect. Private chat storage is excluded.").font(.callout).foregroundStyle(.secondary)
                    Text("Cloud providers may download files according to their own settings.").font(.caption).foregroundStyle(.secondary)
                    Button("Permissions & WhatsApp Guide") { showAccessGuide = true }
                    ForEach(archive.coverage) { report in
                        HStack {
                            Label(report.source.displayName, systemImage: report.error == nil ? "checkmark.circle" : "exclamationmark.triangle")
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
                Label("Some sources were not fully scanned. Check Scan Coverage.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).padding(12)
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
                if archive.authorization == .limited {
                    Text("Limited Photos access. Keptora can only show the items you allow.").font(.callout).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                if archive.skippedPreviews > 0 {
                    Text(String(format: String(localized: "%lld previews could not be analyzed. Results cover only accessible items."), archive.skippedPreviews)).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                if whatsapp {
                    Text("This collection uses album membership. Removing a saved copy from Photos does not remove it from WhatsApp chats.").font(.callout).foregroundStyle(.secondary).padding(.horizontal, 20)
                    Menu("Choose WhatsApp Albums") {
                        ForEach(archive.albums) { album in Button {
                            if !whatsappAlbumIDs.insert(album.id).inserted { whatsappAlbumIDs.remove(album.id) }
                            UserDefaults.standard.set(Array(whatsappAlbumIDs), forKey: "Keptora.WhatsAppAlbumIDs.Mac")
                        } label: { Label(album.title, systemImage: whatsappAlbumIDs.contains(album.id) ? "checkmark" : "square") } }
                    }.padding(8)
                }
                if archive.skippedCloudItems > 0 {
                    Text(String(format: String(localized: "%lld originals could not be analyzed. They remain in the library."), archive.skippedCloudItems)).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                Picker("Library view", selection: $groupedResults) { Text("All Items").tag(false); Text("Copies & Similar").tag(true) }
                    .pickerStyle(.segmented).frame(maxWidth: 400).padding(12)
                ScrollView {
                    if groupedResults {
                        if archive.reviewGroups.isEmpty { Text("Scan all connected sources to find exact copies and similar photos together.").foregroundStyle(.secondary).padding(20) }
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(archive.reviewGroups) { group in
                                let items = group.assets.filter { item in visible.contains { $0.id == item.id } }
                                if !items.isEmpty {
                                    Label(group.kind == .exact ? LocalizedStringKey("Exact Copies") : LocalizedStringKey("Similar Photos & Videos"), systemImage: group.kind == .exact ? "doc.on.doc" : "square.stack").font(.headline)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 250), spacing: 12)], spacing: 12) {
                                        ForEach(items) { item in archiveCell(item, suggestedKeeper: item.id == group.keeperID) }
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
                    Text(String(format: String(localized: "Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.headline)
                    let hidden = archive.selection.subtracting(visible.map(\.id)).count
                    if hidden > 0 { Text(String(format: String(localized: "%lld selected outside this view"), hidden)).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if let status = archive.status { ProgressView().controlSize(.small); Text(status).font(.caption) }
                Button("Select All in This View") { undoIDs = archive.selection; archive.selection.formUnion(visible.map(\.id)) }.keyboardShortcut("a", modifiers: [.command])
                if let undoIDs { Button("Undo") { archive.selection = undoIDs; self.undoIDs = nil }.keyboardShortcut("z", modifiers: [.command]) }
                Button("Clear Selection") { undoIDs = archive.selection; archive.selection.removeAll() }
                Button("Review Selection") { showPlan = true }.buttonStyle(.borderedProminent).disabled(archive.selected.isEmpty)
            }.padding(16).disabled(archive.busy || archive.loading || archive.analyzing)
        }
        .background(KeptoraDesign.canvas)
        .accessibilityIdentifier("mac.page.archive")
        .sheet(isPresented: $showPlan) { MacManualSelectionSheet().environmentObject(archive) }
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
        .onChange(of: archive.connectedFolders) { _ in comparisonGroup = nil; albumID = ""; media = 0; search = ""; whatsapp = false }
        .onChange(of: archive.sourceName) { _ in comparisonGroup = nil; albumID = ""; media = 0; search = ""; undoIDs = nil }
    }
    private func archiveCell(_ item: UniversalMediaAsset, suggestedKeeper: Bool = false) -> some View {
                            VStack(alignment: .leading, spacing: 8) {
                                Button { inspected = item } label: {
                                    MacPhotosThumbnail(asset: item).frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .topLeading) {
                                            Text(archive.sourceLabel(item)).font(.caption.weight(.semibold)).lineLimit(2)
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
                                if suggestedKeeper { Label("Suggested Keep", systemImage: "bookmark.fill").font(.caption).foregroundStyle(KeptoraDesign.accent) }
                                if item.isFavorite { Label("Favorite", systemImage: "heart.fill").font(.caption) }
                            }
                            .padding(10).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(archive.selection.contains(item.id) ? KeptoraDesign.accent : .clear, lineWidth: 2))
                            .contextMenu { Button("Select") { archive.selection.insert(item.id) }; Button("Preview") { inspected = item } }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Media type", selection: $media) { Text("All").tag(0); Text("Photos").tag(1); Text("Videos").tag(2) }.pickerStyle(.segmented).frame(maxWidth: 240)
                Picker("Album", selection: $albumID) { Text("All Albums").tag(""); ForEach(archive.albums) { Text($0.title).tag($0.id) } }.frame(maxWidth: 220)
                Toggle("WhatsApp Media", isOn: $whatsapp).toggleStyle(.button)
                TextField("Search filenames", text: $search).textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("Reset Filters") { media = 0; albumID = ""; whatsapp = false; search = ""; comparisonGroup = nil }
                Spacer()
                if archive.analyzing {
                    ProgressView(value: Double(archive.analysisProcessed), total: Double(max(archive.analysisTotal, 1))).frame(maxWidth: 200)
                    Text(archive.status ?? String(localized: "Analysis in progress. Groups may change.")).font(.caption)
                    Button("Cancel Scan") { archive.cancelAnalysis() }
                }
                else {
                    Button("Scan All Sources") { archive.analyze() }.accessibilityIdentifier("mac.archive.scanAll").disabled(!archive.sourceReady || archive.loading)
                    Button("Include Cloud Originals") { cloudScan = true }.disabled(!archive.sourceReady || archive.loading)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Selection").font(.title.bold())
            let summary = MediaSelectionSummary(archive.selected)
            Text(String(format: String(localized: "Photos: %lld · Videos: %lld"), summary.photos, summary.videos))
            Text(archive.sourceName + " · " + ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file))
            Text("Media size, not freed space").font(.caption).foregroundStyle(.secondary)
            if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption).foregroundStyle(.secondary) }
            Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.").foregroundStyle(.secondary)
            ForEach(archive.connectedSources) { source in
                let items = archive.selected.filter { $0.sourceID == source.id }
                if !items.isEmpty {
                    HStack {
                        Text(source.displayName + " · " + items.count.formatted())
                        Spacer()
                        Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Moves in connected cloud folders may sync to other devices.").font(.caption).foregroundStyle(.secondary)
            if summary.personalItems > 0 { Label("Includes favorites, edited or album items you selected manually.", systemImage: "exclamationmark.triangle") }
            if archive.exact.contains(where: { $0.assets.allSatisfy { archive.selection.contains($0.id) } }) {
                Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            List(archive.selected) { item in
                HStack {
                    VStack(alignment: .leading) { Text(item.displayName); Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(.secondary) }; Spacer()
                    Button { archive.selection.remove(item.id) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove from selection")
                }
            }.disabled(archive.busy)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(archive.busy)
                Spacer()
                if archive.busy { ProgressView(archive.status ?? String(localized: "Removing selected items…")) }
                Button("Remove Selected Items") { expectedIDs = archive.selection; confirm = true }
                    .buttonStyle(.borderedProminent).disabled(archive.busy || archive.selected.isEmpty)
            }
        }.padding(24).frame(minWidth: 640, minHeight: 500).interactiveDismissDisabled(archive.busy)
        .alert("Remove selected items?", isPresented: $confirm) {
            Button("Remove Selected Items", role: .destructive) { Task { if await archive.removeSelection(expectedIDs: expectedIDs) { dismiss() } } }
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
                        Text(String(format: String(localized: "%lld items"), entry.count))
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
