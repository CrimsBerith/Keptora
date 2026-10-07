import AppKit
import KeptoraCore
import SwiftUI

/// Checkpoints are captured synchronously from worker callbacks before quit flushes state.
final class MacAnalysisSession: @unchecked Sendable {
    let control = LibraryAnalysisControl()
    private let lock = NSLock()
    private var checkpoint: UniversalScanCheckpoint?
    func capture(_ checkpoint: UniversalScanCheckpoint) { lock.lock(); self.checkpoint = checkpoint; lock.unlock() }
    func snapshot() -> UniversalScanCheckpoint? { lock.lock(); defer { lock.unlock() }; return checkpoint }
}

/// Owns security-scoped access independently of gallery presentation and commands.
@MainActor
final class MacSourceAccessCoordinator {
    let photos: PhotoLibrarySourceAdapter
    var adapters: [String: FolderSourceAdapter] = [:]
    var scopes: [String: URL] = [:]
    var bookmarks: [String: Data] = [:]
    private var directoryObservers: [String: MacSourceDirectoryObserver] = [:]
    init(photos: PhotoLibrarySourceAdapter = PhotoLibrarySourceAdapter()) { self.photos = photos }
    deinit { for url in scopes.values { url.stopAccessingSecurityScopedResource() } }

    func revalidate(configuration: LibraryConfiguration) throws {
        for (id, bookmark) in bookmarks {
            guard scopes[id] != nil else { continue }
            var stale = false
            let resolved = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
            guard id == "folder:" + LibraryFileIdentity.key(for: resolved) else { throw UniversalScanError.sourcePermissionDenied }
            if scopes[id]?.standardizedFileURL != resolved.standardizedFileURL {
                guard resolved.startAccessingSecurityScopedResource() else { throw UniversalScanError.sourcePermissionDenied }
                scopes[id]?.stopAccessingSecurityScopedResource(); scopes[id] = resolved
            }
            adapters[id] = FolderSourceAdapter(rootURL: resolved, cleanupAvailable: true, configuration: configuration)
            if stale { bookmarks[id] = try resolved.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) }
        }
    }
    func observeChanges(_ changed: @escaping @Sendable () -> Void) {
        directoryObservers = directoryObservers.filter { scopes[$0.key] == $0.value.presentedItemURL }
        for (id, url) in scopes where directoryObservers[id] == nil {
            directoryObservers[id] = MacSourceDirectoryObserver(url: url, changed: changed)
        }
    }
}

private final class MacSourceDirectoryObserver: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let changed: @Sendable () -> Void
    init(url: URL, changed: @escaping @Sendable () -> Void) {
        self.presentedItemURL = url; self.changed = changed
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1; self.presentedItemOperationQueue = queue
        super.init(); NSFileCoordinator.addFilePresenter(self)
    }
    deinit { NSFileCoordinator.removeFilePresenter(self) }
    func presentedItemDidChange() { changed() }
    func presentedSubitemDidAppear(at url: URL) { changed() }
    func presentedSubitemDidChange(at url: URL) { changed() }
    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) { changed() }
}

/// Command-A belongs to the gallery's window and yields to native text editing and sheets.
struct MacGalleryKeyboardMonitor: NSViewRepresentable {
    var selectAll: () -> Void
    var find: () -> Void = {}
    var undo: () -> Void = {}
    var redo: () -> Void = {}
    func makeCoordinator() -> Coordinator { Coordinator(selectAll: selectAll, find: find, undo: undo, redo: redo) }
    func makeNSView(context: Context) -> NSView {
        let view = EventProbe(); context.coordinator.view = view; return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.selectAll = selectAll; context.coordinator.find = find
        context.coordinator.undo = undo; context.coordinator.redo = redo
    }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.stop() }
    // The probe observes its window's keyboard events only. A full-size native
    // background view must let mouse events reach SwiftUI's gallery controls.
    private final class EventProbe: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
    @MainActor final class Coordinator {
        weak var view: NSView?
        var selectAll: () -> Void
        var find: () -> Void
        var undo: () -> Void
        var redo: () -> Void
        private var monitor: Any?
        init(selectAll: @escaping () -> Void, find: @escaping () -> Void, undo: @escaping () -> Void, redo: @escaping () -> Void) {
            self.selectAll = selectAll
            self.find = find
            self.undo = undo; self.redo = redo
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.view?.window, NSApp.keyWindow === window,
                      window.attachedSheet == nil else { return event }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard flags == .command || flags == [.command, .shift] else { return event }
                if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "f" { self.find(); return nil }
                if !(window.firstResponder is NSTextView), event.charactersIgnoringModifiers?.lowercased() == "z" {
                    if flags.contains(.shift) { self.redo() } else { self.undo() }; return nil
                }
                guard flags == .command, !(window.firstResponder is NSTextView), event.charactersIgnoringModifiers?.lowercased() == "a" else { return event }
                self.selectAll(); return nil
            }
        }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }
}

struct MacGalleryProjection {
    let visible: [UniversalMediaAsset]
    let blocks: [LibraryReviewBlock]
    let ordered: [UniversalMediaAsset]
    let membership: [String: [LibraryReviewGroup]]
    let keeperBadges: [String: String]
    let candidates: [String: [UniversalMediaAsset]]
    let issuesByAsset: [String: AnalysisIssue]
    let findingCounts: [LibraryFindingFilter: Int]
    let qualityCounts: [LibraryQualityFilter: Int]
    init(assets: [UniversalMediaAsset], groups: [LibraryReviewGroup], quality: [String: QualityAssessment],
         issues: [AnalysisIssue], decisions: LibraryReviewDecisions, context: MacGalleryContext, search: String) {
        let findingIDs = context.finding.ids(groups: groups, quality: quality)
        let qualityIDs = (context.quality ?? .all).ids(quality: quality, issues: issues)
        visible = assets.filter { item in
            (findingIDs?.contains(item.id) ?? true) && (qualityIDs?.contains(item.id) ?? true) &&
            (context.media == 0 || (context.media == 1 ? item.mediaKind == .image : item.mediaKind == .video)) &&
            (context.albumID.isEmpty || item.context?.albums.contains { $0.id == context.albumID } == true) &&
            (search.isEmpty || item.displayName.localizedCaseInsensitiveContains(search))
        }.sorted {
            let a = $0.context?.captureDate ?? $0.creationDate ?? .distantPast
            let b = $1.context?.captureDate ?? $1.creationDate ?? .distantPast
            return a == b ? $0.id < $1.id : a > b
        }
        blocks = LibraryReviewBlock.make(assets: visible, groups: groups, quality: quality, smart: context.smartOrder)
        ordered = context.smartOrder ? blocks.flatMap(\.assets) : visible
        var related: [String: [LibraryReviewGroup]] = [:]
        for group in groups { for item in group.assets { related[item.id, default: []].append(group) } }
        membership = related; keeperBadges = decisions.keeperBadgeKeys(in: groups); candidates = decisions.candidatesByGroup(groups)
        issuesByAsset = Dictionary(issues.map { ($0.assetID, $0) }, uniquingKeysWith: { first, _ in first })
        let scope = Set(assets.map(\.id))
        findingCounts = Dictionary(uniqueKeysWithValues: LibraryFindingFilter.allCases.map { filter in
            (filter, filter.ids(groups: groups, quality: quality)?.intersection(scope).count ?? assets.count)
        })
        qualityCounts = Dictionary(uniqueKeysWithValues: LibraryQualityFilter.allCases.map { filter in
            (filter, filter.ids(quality: quality, issues: issues)?.intersection(scope).count ?? assets.count)
        })
    }
}

enum MacWindowIdentity {
    static let main = NSUserInterfaceItemIdentifier("Keptora.main")
    static func openSettings() {
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

struct MacSessionHealthBanner: View {
    @EnvironmentObject private var archive: MacArchiveModel
    var body: some View {
        if let message = archive.persistenceMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label("Your session needs attention", systemImage: "exclamationmark.triangle.fill").font(.headline)
                Text(message).font(.callout).textSelection(.enabled)
                Text("Selection changes and cleanup are paused until your session can be saved.").font(.caption)
                if archive.persistenceHealth == .unreadable {
                    Text("The unreadable session will be kept as a separate file. Saving the current session does not recover missing choices.").font(.caption)
                }
                Button(archive.persistenceHealth == .unreadable ? "Preserve Original and Save Current Session" : "Retry Saving") {
                    Task { await archive.repairPersistence() }
                }.disabled(!archive.canRepairPersistence).accessibilityIdentifier("mac.session.repair")
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.12))
                .accessibilityIdentifier("mac.session.health")
        }
    }
}
struct MacMainWindowMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Marker() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class Marker: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.identifier = MacWindowIdentity.main; window?.minSize = NSSize(width: 900, height: 650) }
    }
}
