import AppKit
import KeptoraCore
import SwiftUI

@MainActor
private final class KeptoraAppDelegate: NSObject, NSApplicationDelegate {
    let operations = LibraryOperationCoordinator()
    let navigation = MacNavigation()
    let store = StoreEntitlementController()
    lazy var archive = MacArchiveModel(operations: operations)
    private var terminating = false
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        archive.authorizeSuggestions = { [weak self] identifiers in
            guard let self else { return false }
            let ids = identifiers.map { AssetID(rawValue: $0) }
            guard self.store.authorizeReviews(ids) else { return false }
            self.store.recordReviews(ids)
            return true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showMainWindowIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindowIfNeeded()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        operations.beginTermination()
        Task {
            let saved = await archive.prepareForTermination()
            await operations.waitForIdle()
            if !saved { terminating = false; operations.resumeAfterCancelledTermination() }
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }

    private func showMainWindowIfNeeded() {
        if let window = NSApp.windows.first(where: { $0.identifier == MacWindowIdentity.main }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let selectedLang = UserDefaults.standard.string(forKey: "Keptora.AppLanguage") ?? AppLanguage.system.rawValue
        let activeLocale = AppLanguage(rawValue: selectedLang)?.locale ?? .current

        let root = MainRootView()
            .environmentObject(navigation)
            .environmentObject(store)
            .environmentObject(archive)
            .environment(\.locale, activeLocale)
            .task { [store] in await store.refresh() }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keptora"
        window.identifier = MacWindowIdentity.main
        window.minSize = NSSize(width: 900, height: 650)
        window.contentViewController = NSHostingController(rootView: root)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        fallbackWindow = window
    }
}

@main
@MainActor
struct KeptoraApp: App {
    @NSApplicationDelegateAdaptor(KeptoraAppDelegate.self) private var appDelegate
    @AppStorage("Keptora.AppLanguage") private var selectedLanguage = AppLanguage.system.rawValue

    private var activeLocale: Locale {
        AppLanguage(rawValue: selectedLanguage)?.locale ?? .current
    }

    var body: some Scene {
        Window("Keptora", id: "main") {
            MainRootView()
                .environmentObject(appDelegate.navigation)
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.archive)
                .environment(\.locale, activeLocale)
                .task { await appDelegate.store.refresh() }
        }
        .defaultSize(width: 1240, height: 800)
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .commands { MacLibraryCommands(archive: appDelegate.archive, navigation: appDelegate.navigation) }
    }
}

@MainActor
private struct MacLibraryCommands: Commands {
    @ObservedObject var archive: MacArchiveModel
    @ObservedObject var navigation: MacNavigation
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Folder…") { navigation.selectedRoute = .archive; archive.chooseFolder() }
                .keyboardShortcut("o", modifiers: [.command]).disabled(archive.sourceControlsDisabled)
            Button("Start Scan") { navigation.selectedRoute = .archive; archive.analyze() }
                .keyboardShortcut("r", modifiers: [.command]).disabled(!archive.canScanSelectedSources)
            Button("Cancel Scan") { archive.cancelAnalysis() }.disabled(!archive.analyzing && !archive.analysisPaused)
        }
    }
}
