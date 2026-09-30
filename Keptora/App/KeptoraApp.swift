import AppKit
import KeptoraCore
import SwiftUI

@MainActor
private final class KeptoraAppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let store = StoreEntitlementController()
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
                .environment(\.locale, activeLocale)
                .task {
                    async let appPreparation: Void = appDelegate.model.prepare()
                    async let storePreparation: Void = appDelegate.store.refresh()
                    _ = await (appPreparation, storePreparation)
                }
        }
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose Photo Folder…") { appDelegate.model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Connect Cloud Folder…") { appDelegate.model.chooseCloudFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Start Read-Only Scan") { appDelegate.model.startScan() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(!appDelegate.model.canStartScan)
                Button("Analyze Similar Photos") { appDelegate.model.startSimilarityAnalysis() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(appDelegate.model.similarityProgress.isRunning)
            }
            CommandMenu("Review") {
                Button("Previous Exact Group") { appDelegate.model.selectPreviousExactGroup() }
                    .keyboardShortcut("[", modifiers: [.command])
                    .disabled(!appDelegate.model.canNavigateExactGroups)
                Button("Next Exact Group") { appDelegate.model.selectNextExactGroup() }
                    .keyboardShortcut("]", modifiers: [.command])
                    .disabled(!appDelegate.model.canNavigateExactGroups)
                Divider()
                Button("Previous Photo") { appDelegate.model.focusPreviousReviewAsset() }
                    .keyboardShortcut(.leftArrow, modifiers: [.option])
                    .disabled(!appDelegate.model.canApplyFocusedReviewDecision)
                Button("Next Photo") { appDelegate.model.focusNextReviewAsset() }
                    .keyboardShortcut(.rightArrow, modifiers: [.option])
                    .disabled(!appDelegate.model.canApplyFocusedReviewDecision)
                Divider()
                Button("Keep Focused Photo") { appDelegate.model.applyFocusedDecision(.keep, access: appDelegate.store) }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                    .disabled(!appDelegate.model.canApplyFocusedReviewDecision)
                Button("Add Focused Photo to Safety Plan") { appDelegate.model.applyFocusedDecision(.quarantinePlan, access: appDelegate.store) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                    .disabled(!appDelegate.model.canApplyFocusedReviewDecision)
                Button("Skip Focused Photo") { appDelegate.model.applyFocusedDecision(.skip, access: appDelegate.store) }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                    .disabled(!appDelegate.model.canApplyFocusedReviewDecision)
                Divider()
                Button("Select All Safe Copies") { appDelegate.model.applyBatchActionToAllExactGroups(.planSafeExtras, access: appDelegate.store) }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(!appDelegate.model.canApplyAllExactGroups)
                Button("Skip This Group") { appDelegate.model.applyBatchActionToSelected(.skipExtras, access: appDelegate.store) }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!appDelegate.model.canApplySelectedGroupBatch)
                Divider()
                Button("Resume Last Review Session") { appDelegate.model.resumeReviewSession() }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(!appDelegate.model.hasResumableReviewSession)
            }
            CommandMenu("Go") {
                Button("Library") { appDelegate.model.selectedRoute = .home }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Review Studio") { appDelegate.model.selectedRoute = .review }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Smart Categories") { appDelegate.model.selectedRoute = .smartBuckets }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("History & Quarantine") { appDelegate.model.selectedRoute = .history }
                    .keyboardShortcut("4", modifiers: [.command])
                Button("Insights") { appDelegate.model.selectedRoute = .insights }
                    .keyboardShortcut("5", modifiers: [.command])
                Divider()
                Button("Review Safety Plan…") { appDelegate.model.isShowingSafetyPlan = true }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                Button("Restore From Quarantine…") { appDelegate.model.isShowingRestorePreview = true }
                    .keyboardShortcut("z", modifiers: [.command, .option])
            }
            CommandGroup(after: .help) {
                Button("Export Diagnostics…") { appDelegate.model.exportDiagnostics() }
                Button("Show Welcome Tour") { appDelegate.model.showOnboarding() }
            }
        }
    }
}
