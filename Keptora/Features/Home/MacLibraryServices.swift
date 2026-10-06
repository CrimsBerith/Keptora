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
    func makeCoordinator() -> Coordinator { Coordinator(selectAll: selectAll) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView(); context.coordinator.view = view; return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.selectAll = selectAll }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.stop() }
    @MainActor final class Coordinator {
        weak var view: NSView?
        var selectAll: () -> Void
        private var monitor: Any?
        init(selectAll: @escaping () -> Void) {
            self.selectAll = selectAll
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.view?.window, NSApp.keyWindow === window,
                      !(window.firstResponder is NSTextView), event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                      event.charactersIgnoringModifiers?.lowercased() == "a" else { return event }
                self.selectAll(); return nil
            }
        }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }
}
