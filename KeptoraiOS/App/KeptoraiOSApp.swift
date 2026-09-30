import KeptoraCore
import SwiftUI

@main
struct KeptoraiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = MobileKeptoraStore()
    @StateObject private var purchase = MobilePurchaseController()
    @AppStorage("Keptora.AppLanguage") private var selectedLanguage = AppLanguage.system.rawValue

    private var activeLocale: Locale {
        AppLanguage(rawValue: selectedLanguage)?.locale ?? .current
    }

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environmentObject(store)
                .environmentObject(purchase)
                .environment(\.locale, activeLocale)
                .task {
                    await store.restoreSavedSource()
                    await purchase.refresh()
                    await store.handleAppLaunchAuthorization()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refreshPhotosAuthorization() }
                    } else if phase == .background {
                        // .inactive also fires for Control Center, banners and permission alerts.
                        store.suspendScanForBackground()
                    }
                }
        }
    }
}
