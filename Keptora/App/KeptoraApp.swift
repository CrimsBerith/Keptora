import AppKit
import KeptoraCore
import SwiftUI

@MainActor
private final class KeptoraAppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let store = StoreEntitlementController()
    let archive = MacArchiveModel()
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
        if !flag {
            showMainWindowIfNeeded()
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        model.checkpointReviewSession()
        Task {
            let saved = await archive.prepareForTermination()
            if !saved { terminating = false }
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }

    private func showMainWindowIfNeeded() {
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let selectedLang = UserDefaults.standard.string(forKey: "Keptora.AppLanguage") ?? AppLanguage.system.rawValue
        let activeLocale = AppLanguage(rawValue: selectedLang)?.locale ?? .current

        let root = MainRootView()
            .environmentObject(model)
            .environmentObject(store)
            .environmentObject(archive)
            .environment(\.locale, activeLocale)
            .task { [model, store] in
                async let appPreparation: Void = model.prepare()
                async let storePreparation: Void = store.refresh()
                _ = await (appPreparation, storePreparation)
            }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keptora"
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
                .environmentObject(appDelegate.model)
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.archive)
                .environment(\.locale, activeLocale)
                .task {
                    async let appPreparation: Void = appDelegate.model.prepare()
                    async let storePreparation: Void = appDelegate.store.refresh()
                    _ = await (appPreparation, storePreparation)
                }
        }
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.titleBar)
        .commands { MacLibraryCommands(archive: appDelegate.archive, model: appDelegate.model, store: appDelegate.store) }
        Settings {
            SettingsView().environmentObject(appDelegate.model).environmentObject(appDelegate.store)
                .environmentObject(appDelegate.archive).environment(\.locale, activeLocale)
                .frame(minWidth: 560, idealWidth: 650, minHeight: 580)
        }
    }
}

@MainActor
private struct MacLibraryCommands: Commands {
    @ObservedObject var archive: MacArchiveModel
    @ObservedObject var model: AppModel
    @ObservedObject var store: StoreEntitlementController
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Folder…") { model.selectedRoute = .archive; archive.chooseFolder() }
                .keyboardShortcut("o", modifiers: [.command]).disabled(archive.sourceControlsDisabled)
            Button("Start Scan") { model.selectedRoute = .archive; archive.analyze() }
                .keyboardShortcut("r", modifiers: [.command]).disabled(!archive.canScanSelectedSources)
            Button("Pause Scan") { archive.pauseAnalysis() }
                .disabled(!archive.analyzing || archive.analysisPaused)
            Button("Resume Scan") { archive.resumeAnalysis() }.disabled(!archive.analysisPaused)
        }
        CommandMenu("Advanced Review") {
            Button("Previous Exact Group") { model.selectPreviousExactGroup() }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!model.canNavigateExactGroups)
            Button("Next Exact Group") { model.selectNextExactGroup() }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!model.canNavigateExactGroups)
            Divider()
            Button("Previous Photo") { model.focusPreviousReviewAsset() }
                .keyboardShortcut(.leftArrow, modifiers: [.option])
                .disabled(!model.canApplyFocusedReviewDecision)
            Button("Next Photo") { model.focusNextReviewAsset() }
                .keyboardShortcut(.rightArrow, modifiers: [.option])
                .disabled(!model.canApplyFocusedReviewDecision)
            Divider()
            Button("Keep Focused Photo") { model.applyFocusedDecision(.keep, access: store) }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(!model.canApplyFocusedReviewDecision)
            Button("Add Focused Photo to Safety Plan") { model.applyFocusedDecision(.quarantinePlan, access: store) }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(!model.canApplyFocusedReviewDecision)
            Button("Skip Focused Photo") { model.applyFocusedDecision(.skip, access: store) }
                .keyboardShortcut("3", modifiers: [.command, .option])
                .disabled(!model.canApplyFocusedReviewDecision)
            Divider()
            Button("Select All Safe Copies") { model.applyBatchActionToAllExactGroups(.planSafeExtras, access: store) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(!model.canApplyAllExactGroups)
            Button("Skip This Group") { model.applyBatchActionToSelected(.skipExtras, access: store) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!model.canApplySelectedGroupBatch)
            Divider()
            Button("Resume Last Review Session") { model.resumeReviewSession() }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(!model.hasResumableReviewSession)
        }
        CommandMenu("Go") {
            Button("Photos") { model.selectedRoute = .archive }.keyboardShortcut("1", modifiers: [.command])
            Button("Suggestions") { model.selectedRoute = .smartBuckets }.keyboardShortcut("2", modifiers: [.command])
            Button("History") { model.selectedRoute = .history }.keyboardShortcut("3", modifiers: [.command])
            Divider()
            Button("Support & Diagnostics") { model.selectedRoute = .diagnostics }
        }
        CommandGroup(after: .help) {
            Button("Export Diagnostics…") { archive.exportDiagnostics() }
            Button("Show Welcome Tour") { model.showOnboarding() }
        }
        }
}
