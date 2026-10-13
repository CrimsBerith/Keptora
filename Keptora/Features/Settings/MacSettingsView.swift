import KeptoraCore
import SwiftUI

/// The standard Keptora ▸ Settings… window: purchase, language, support and diagnostics.
struct MacSettingsView: View {
    @EnvironmentObject private var store: StoreEntitlementController
    @EnvironmentObject private var archive: MacArchiveModel
    @AppStorage(AppStorageKeys.appLanguage) private var selectedLanguage = AppLanguage.system.rawValue
    @State private var copiedDiagnostics = false

    private var appVersionLabel: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(Bundle.main.appVersionString) (\(build))"
    }

    var body: some View {
        Form {
            Section("Keptora Pro") {
                LabeledContent("Status") {
                    Text(store.isLifetimeUnlocked ? LocalizedStringKey("Lifetime unlocked") : LocalizedStringKey("Free version active"))
                }
                HStack {
                    if !store.isLifetimeUnlocked {
                        Button("View Keptora Pro") { store.presentPaywall(.settings, host: .settings) }
                            .accessibilityIdentifier("mac.settings.showPaywall")
                    }
                    Button("Restore Purchases") { Task { await store.restorePurchases() } }
                        .disabled(store.isWorking)
                        .accessibilityIdentifier("mac.settings.restorePurchases")
                }
                if let status = store.statusMessage {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Language") {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
                .labelsHidden()
                .accessibilityIdentifier("mac.settings.language")
            }

            Section("Privacy") {
                LabeledContent("Photo upload") { Text("Never") }
                LabeledContent("Account") { Text("Not required") }
                LabeledContent("Analytics") { Text("None") }
                Link("Privacy Policy", destination: AppStoreConfiguration.privacyPolicyURL)
                Link("Terms of Use", destination: AppStoreConfiguration.termsOfUseURL)
            }

            Section("Support") {
                Link("Support", destination: AppStoreConfiguration.supportURL)
                    .accessibilityIdentifier("mac.settings.support")
                HStack {
                    Button("Export Diagnostics…") { archive.exportDiagnostics() }
                        .accessibilityIdentifier("mac.settings.exportDiagnostics")
                    Button("Copy Diagnostics") { archive.copyDiagnostics(); copiedDiagnostics = archive.error == nil }
                }
                Text(copiedDiagnostics ? "Diagnostics copied." : "Diagnostics contain counts and app state only. Photos, file names and paths are not included.")
                    .font(.footnote).foregroundStyle(.secondary)
                LabeledContent("Version", value: appVersionLabel)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: store.paywallBinding(for: .settings)) {
            PaywallView().environmentObject(store)
        }
    }
}
