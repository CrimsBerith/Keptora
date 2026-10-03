import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    @AppStorage("hasSeenMobileOnboarding") private var hasSeenMobileOnboarding = false

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
        .onAppear {
            if !hasSeenMobileOnboarding {
                store.present(.onboarding)
            }
        }
        .sheet(item: $store.modalRoute) { route in
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
