import KeptoraCore
import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    @AppStorage("hasSeenMobileOnboarding") private var hasSeenMobileOnboarding = false
    @AppStorage(AppStorageKeys.iOSSourceSetupCompleted) private var sourceSetupCompleted = false

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack { MobileLibraryView() }
                .tabItem { Label("Library", systemImage: "photo.stack") }
                .tag(MobileTab.library)
                .accessibilityIdentifier("tab.library")
            NavigationStack { MobileCleanupHubView() }
                .tabItem { Label("Cleanup", systemImage: "sparkles.rectangle.stack") }
                .tag(MobileTab.review)
                .accessibilityIdentifier("tab.review")
            NavigationStack { MobileHistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(MobileTab.history)
                .accessibilityIdentifier("tab.history")
        }
        .tint(MobileKeptoraDesign.accent)
        .onAppear { presentStartupIfNeeded() }
        .onChange(of: store.startupSourcesPrepared) { _, _ in presentStartupIfNeeded() }
        .sheet(item: $store.modalRoute, onDismiss: { presentStartupIfNeeded() }) { route in
            MobileModalHost(route: route)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func presentStartupIfNeeded() {
        guard store.startupSourcesPrepared, store.modalRoute == nil else { return }
        if !hasSeenMobileOnboarding { store.present(.onboarding) }
        else if LibraryAccessPolicy.needsStartupSetup(introductionCompleted: hasSeenMobileOnboarding, setupCompleted: sourceSetupCompleted) {
            store.present(.sourceSetup)
        }
    }
}

private struct MobileModalHost: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    let route: MobileModalRoute

    @ViewBuilder
    var body: some View {
        Group {
            switch route {
            case .filePicker:
                DirectoryPicker { url in
                    store.dismissModal()
                    if let url { store.connectFolder(url) }
                }
            case .settings:
                NavigationStack { MobileSettingsView() }
            case .paywall:
                MobilePaywallView()
            case .onboarding:
                MobileOnboardingView()
                    .interactiveDismissDisabled()
            case .sourceSetup:
                NavigationStack { MobileSourceLibraryView(isStartupSetup: true) }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
