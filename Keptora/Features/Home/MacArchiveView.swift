import AppKit
import KeptoraCore
import Photos
import SwiftUI

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
    @Published var similar: [UniversalSimilarityGroup] = []
    @Published var status: String?
    @Published var analysisTotal = 0
    @Published var analysisProcessed = 0
    @Published var skippedPreviews = 0
    @Published var sourceReady = false
    @Published var authorization: SourceAuthorization = .notDetermined
    private var generation = UUID()
    private var observer: MacArchivePhotoObserver?
    private var selectionKey: String { "Keptora.ManualSelection.Mac." + (sourceRoot.map { StableDigest.fnv1a64($0.standardizedFileURL.path) } ?? "photos") }
    private func reconcileSelection() {
        let saved = Set(UserDefaults.standard.stringArray(forKey: selectionKey) ?? [])
        selection = saved.intersection(assets.map(\.id))
    }
    private let photos = PhotoLibrarySourceAdapter()
    private let folders = FolderQuarantineExecutor()
    private let analyzer = VisualSimilarityAnalyzer()
    private var scope: URL?
    private var folderAdapter: FolderSourceAdapter?
    private var task: Task<Void, Never>?
    private let historyKey = "Keptora.ManualCleanupHistory.Mac"
    init() {
        if let data = UserDefaults.standard.data(forKey: historyKey), let entries = try? JSONDecoder().decode([MacRecoveryEntry].self, from: data) { history = entries }
    }
    deinit { task?.cancel(); scope?.stopAccessingSecurityScopedResource() }
    var selected: [UniversalMediaAsset] { assets.filter { selection.contains($0.id) } }
    var albums: [MediaAlbum] {
        var values: [String: MediaAlbum] = [:]
        for asset in assets { for album in asset.context?.albums ?? [] { values[album.id] = album } }
        return values.values.sorted { $0.title < $1.title }
    }
    func connectPhotos() {
        guard !busy, !analyzing, !loading else { return }
        task?.cancel(); loading = true
        let current = UUID(); generation = current
        task = Task {
            defer { if generation == current { loading = false } }
            let auth = await photos.authorizationStatus()
            let permission = auth == .notDetermined ? await photos.requestAuthorization() : auth
            guard !Task.isCancelled, generation == current else { return }
            authorization = permission
            guard permission == .authorized || permission == .limited else {
                error = String(localized: "Allow Photos access in System Settings to open this library."); return
            }
            scope?.stopAccessingSecurityScopedResource(); scope = nil; folderAdapter = nil
            sourceReady = false; sourceRoot = nil; sourceName = String(localized: "Apple Photos")
            selection.removeAll(); similar.removeAll(); assets.removeAll()
            do {
                let catalogue = try await photos.enumerateAssets()
                guard !Task.isCancelled, generation == current else { return }
                assets = catalogue; sourceReady = true; reconcileSelection()
                observer = MacArchivePhotoObserver { [weak self] in Task { @MainActor in self?.refresh() } }
            } catch { if generation == current { self.error = error.localizedDescription } }
        }
    }
    func chooseFolder() {
        guard !busy, !analyzing, !loading else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let root = panel.url else { return }
        task?.cancel(); observer = nil; scope?.stopAccessingSecurityScopedResource()
        if root.startAccessingSecurityScopedResource() { scope = root } else { scope = nil }
        sourceReady = false; sourceRoot = root; sourceName = root.lastPathComponent
        assets.removeAll(); selection.removeAll(); similar.removeAll()
        folderAdapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: true)
        sourceReady = true; refresh()
    }
    func refresh() {
        guard sourceReady, !busy, !analyzing, !loading else { return }
        task?.cancel(); loading = true
        let current = UUID(); generation = current
        let adapter = folderAdapter
        task = Task {
            defer { if generation == current { loading = false } }
            do {
                let catalogue: [UniversalMediaAsset]
                if let adapter { catalogue = try await adapter.enumerateAssets() }
                else {
                    authorization = await photos.authorizationStatus()
                    guard authorization == .authorized || authorization == .limited else {
                        assets.removeAll(); selection.removeAll(); similar.removeAll()
                        error = String(localized: "Allow Photos access in System Settings to open this library."); return
                    }
                    catalogue = try await photos.enumerateAssets()
                }
                guard !Task.isCancelled, generation == current else { return }
                assets = catalogue; reconcileSelection()
                similar.removeAll { group in !group.assets.allSatisfy { item in catalogue.contains { $0.id == item.id } } }
                if let root = sourceRoot {
                    let records = try await folders.recoveryRecords(root: root)
                    guard !Task.isCancelled, generation == current else { return }
                    let bookmark = try? root.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    for record in records {
                        if let index = history.firstIndex(where: { $0.id == record.id }) { history[index].folderRecord = record; continue }
                        history.insert(MacRecoveryEntry(id: record.id, date: record.createdAt, count: record.operations.count, bytes: 0,
                            folderRecord: record, bookmark: bookmark, isPhotos: false), at: 0)
                    }
                    persistHistory()
                }
            } catch is CancellationError { }
            catch { if generation == current { self.error = error.localizedDescription } }
        }
    }
    func analyze() {
        guard !busy, !loading, !analyzing, !assets.isEmpty else { return }
        analyzing = true; status = String(localized: "Comparing images and capture details…")
        task = Task {
            defer { analyzing = false; status = nil }
            do {
                let provider: any SimilarityImageProviding
                if let folderAdapter { provider = folderAdapter } else { provider = photos }
                let groups = try await analyzer.analyze(assets: assets, provider: provider, maximumAssets: assets.count) { [weak self] done, total in
                    Task { @MainActor in self?.analysisProcessed = done; self?.analysisTotal = total }
                }
                try Task.checkCancellation()
                similar = groups; skippedPreviews = await analyzer.skippedPreviewCount
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
            let summary = MediaSelectionSummary(snapshot)
            if let root = sourceRoot, let adapter = folderAdapter {
                var candidates: [(asset: UniversalMediaAsset, expectedDigest: String)] = []
                for item in snapshot {
                    let fingerprint = try await adapter.exactFingerprint(for: item, allowNetwork: false, progress: { _ in })
                    candidates.append((item, fingerprint.digest))
                }
                let bookmark = try root.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                let record = try await folders.quarantine(root: root, selections: candidates)
                history.insert(MacRecoveryEntry(id: record.id, date: record.createdAt, count: snapshot.count, bytes: summary.knownBytes, folderRecord: record, bookmark: bookmark, isPhotos: false), at: 0)
            } else {
                let ids = snapshot.compactMap { item -> String? in if case .photoLibrary(let id) = item.reference { return id }; return nil }
                guard ids.count == snapshot.count else { return false }
                try await photos.deleteSelectedAssets(localIdentifiers: ids, intent: .manualSelection)
                history.insert(MacRecoveryEntry(id: UUID(), date: Date(), count: snapshot.count, bytes: summary.knownBytes, folderRecord: nil, bookmark: nil, isPhotos: true), at: 0)
            }
            persistHistory()
            assets.removeAll { expectedIDs.contains($0.id) }
            similar.removeAll { $0.assets.contains { expectedIDs.contains($0.id) } }
            selection.subtract(expectedIDs)
            return true
        } catch {
            let ns = error as NSError
            if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError { return false }
            self.error = error.localizedDescription
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
    @State private var media = 0
    @State private var albumID = ""
    @State private var whatsapp = false
    @State private var whatsappAlbumIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "Keptora.WhatsAppAlbumIDs.Mac") ?? [])
    @State private var comparisonGroup: UniversalSimilarityGroup?
    @State private var showPlan = false
    @State private var inspected: UniversalMediaAsset?
    @State private var undoIDs: Set<String>?
    private var visible: [UniversalMediaAsset] {
        archive.assets.filter { item in
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
                Button("Apple Photos") { archive.connectPhotos() }
                Button("Choose Folder…") { archive.chooseFolder() }
                Button { archive.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh Library")
            }.padding(20).disabled(archive.busy || archive.analyzing)
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
                if archive.authorization == .limited && archive.sourceRoot == nil {
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
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 250), spacing: 12)], spacing: 12) {
                        ForEach(visible) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Button { inspected = item } label: {
                                    MacPhotosThumbnail(asset: item).frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12))
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
                                if item.isFavorite { Label("Favorite", systemImage: "heart.fill").font(.caption) }
                            }
                            .padding(10).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(archive.selection.contains(item.id) ? KeptoraDesign.accent : .clear, lineWidth: 2))
                            .contextMenu { Button("Select") { archive.selection.insert(item.id) }; Button("Preview") { inspected = item } }
                        }
                    }.padding(20)
                }.disabled(archive.busy)
                if !archive.similar.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            Button("Entire Library") { comparisonGroup = nil }
                            ForEach(archive.similar) { group in Button(String(format: String(localized: "%lld similar items"), group.assets.count)) { comparisonGroup = group } }
                        }.padding(12)
                    }
                }
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
                MacPhotosThumbnail(asset: item, pixelSize: 1600, fit: true).frame(minWidth: 600, minHeight: 420)
                Text(item.displayName).font(.headline)
                if let date = item.captureDateDescription { Text(date) }
                if let context = item.context, let camera = context.camera { Text(camera) }
                if let location = item.context?.location { Text(String(format: "%.5f, %.5f", location.latitude, location.longitude)) }
                HStack { Button("Close") { inspected = nil }; Button("Select") { archive.selection.insert(item.id); inspected = nil } }
            }.padding(20)
        }
        .alert("Something went wrong", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK") { archive.error = nil }
        } message: { Text(archive.error ?? "") }
        .onChange(of: archive.sourceName) { _ in comparisonGroup = nil; albumID = ""; media = 0; search = ""; undoIDs = nil }
    }
    private var filters: some View {
        HStack {
            Picker("Media type", selection: $media) { Text("All").tag(0); Text("Photos").tag(1); Text("Videos").tag(2) }.pickerStyle(.segmented).frame(maxWidth: 240)
            Picker("Album", selection: $albumID) { Text("All Albums").tag(""); ForEach(archive.albums) { Text($0.title).tag($0.id) } }.frame(maxWidth: 220)
            Toggle("WhatsApp Media", isOn: $whatsapp).toggleStyle(.button)
            TextField("Search filenames", text: $search).textFieldStyle(.roundedBorder)
            if archive.analyzing { Button("Cancel Analysis") { archive.cancelAnalysis() } }
            else { Button("Find Similar Photos") { archive.analyze() }.disabled(archive.assets.isEmpty || archive.loading) }
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
            Text(archive.sourceRoot == nil ? "Items go to Recently Deleted in Apple Photos for up to 30 days unless permanently deleted sooner. iCloud Photos changes also sync to your other devices." : "Files move to a recovery folder on the same storage. This does not free disk space. Keep the recovery folder and record to restore them.").foregroundStyle(.secondary)
            if summary.personalItems > 0 { Label("Includes favorites, edited or album items you selected manually.", systemImage: "exclamationmark.triangle") }
            List(archive.selected) { item in
                HStack {
                    Text(item.displayName); Spacer()
                    Button { archive.selection.remove(item.id) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove from selection")
                }
            }.disabled(archive.busy)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(archive.busy)
                Spacer()
                if archive.busy { ProgressView(archive.status ?? String(localized: "Removing selected items…")) }
                Button(archive.sourceRoot == nil ? "Remove from Photos" : "Move to Recovery Folder") { expectedIDs = archive.selection; confirm = true }
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
