import SwiftUI

@main
@MainActor
struct CulloraApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var store = StoreEntitlementController()

    var body: some Scene {
        WindowGroup {
            MainRootView()
                .environmentObject(model)
                .environmentObject(store)
                .task {
                    async let appPreparation: Void = model.prepare()
                    async let storePreparation: Void = store.refresh()
                    _ = await (appPreparation, storePreparation)
                }
        }
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose Photo Folder…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Connect Cloud Folder…") { model.chooseCloudFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Start Read-Only Scan") { model.startScan() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(!model.canStartScan)
                Button("Analyze Similar Photos") { model.startSimilarityAnalysis() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(model.similarityProgress.isRunning)
            }
            CommandMenu("Review") {
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
                    .keyboardShortcut("1", modifiers: [.command])
                    .disabled(!model.canApplyFocusedReviewDecision)
                Button("Add Focused Photo to Safety Plan") { model.applyFocusedDecision(.quarantinePlan, access: store) }
                    .keyboardShortcut("2", modifiers: [.command])
                    .disabled(!model.canApplyFocusedReviewDecision)
                Button("Skip Focused Photo") { model.applyFocusedDecision(.skip, access: store) }
                    .keyboardShortcut("3", modifiers: [.command])
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
            CommandGroup(after: .help) {
                Button("Export Diagnostics…") { model.exportDiagnostics() }
                Button("Show Welcome Tour") { model.showOnboarding() }
            }
        }
    }
}
