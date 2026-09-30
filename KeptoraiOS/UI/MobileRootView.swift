import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack { MobileLibraryView() }
                .tabItem { Label("Library", systemImage: "photo.stack") }
                .tag(0)
                .accessibilityIdentifier("tab.library")
            NavigationStack { MobileReviewView() }
                .tabItem { Label("Review", systemImage: "sparkles.rectangle.stack") }
                .tag(1)
                .accessibilityIdentifier("tab.review")
            NavigationStack { MobileHistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(2)
                .accessibilityIdentifier("tab.history")
        }
        .tint(MobileKeptoraDesign.accent)
        .sheet(isPresented: Binding(
            get: { store.modalRoute != nil },
            set: { if !$0 { store.dismissModal() } }
        ), onDismiss: store.dismissModal) {
            MobileModalHost()
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

    @ViewBuilder
    var body: some View {
        switch store.modalRoute {
        case .filePicker:
            DirectoryPicker { url in
                store.dismissModal()
                if let url { store.connectFolder(url) }
            }
        case .settings:
            NavigationStack { MobileSettingsView() }
        case .paywall:
            MobilePaywallView()
        case nil:
            EmptyView()
        }
    }
}
