import KeptoraCore
import SwiftUI

private enum SettingsStorageKeys {
    static let checkpointInterval = "Keptora.CheckpointInterval"
    static let showFilePaths = "Keptora.ShowFilePaths"
    static let similarityEnabled = "Keptora.Feature.Similarity.v1"
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsStorageKeys.checkpointInterval) private var checkpointInterval = 100
    @AppStorage(SettingsStorageKeys.showFilePaths) private var showFilePaths = false
    @AppStorage(SettingsStorageKeys.similarityEnabled) private var similarityEnabled = true
    @AppStorage(SourceExclusionPolicy.folderDefaultsKey) private var excludedFolders = ""
    @AppStorage(SourceExclusionPolicy.extensionDefaultsKey) private var excludedExtensions = ""
    @AppStorage(SimilaritySensitivityPreset.defaultsKey) private var sensitivityRaw = SimilaritySensitivityPreset.precisionFirst.rawValue
    @AppStorage(KeeperSelectionPolicy.defaultsKey) private var keeperPolicyRaw = KeeperSelectionPolicy.preserve.rawValue

    private var sensitivity: Binding<SimilaritySensitivityPreset> {
        Binding(
            get: { SimilaritySensitivityPreset(rawValue: sensitivityRaw) ?? .precisionFirst },
            set: { sensitivityRaw = $0.rawValue }
        )
    }

    private var keeperPolicy: Binding<KeeperSelectionPolicy> {
        Binding(
            get: { KeeperSelectionPolicy(rawValue: keeperPolicyRaw) ?? .preserve },
            set: { keeperPolicyRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            MacSessionHealthBanner()
            KeptoraReleaseLinks()
            Section("Scanning") {
                Stepper("Checkpoint every \(checkpointInterval) assets", value: $checkpointInterval, in: 25...500, step: 25)
                Text("Smaller checkpoints save scan progress more often. Changes apply to your next scan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Source Exclusions") {
                TextField("Folder names, comma-separated", text: $excludedFolders)
                    .textFieldStyle(.roundedBorder)
                TextField("File extensions, comma-separated", text: $excludedExtensions)
                    .textFieldStyle(.roundedBorder)
                Label("Keptora always skips hidden items, package contents, .Keptora Quarantine, .git and node_modules. Custom rules apply on the next scan.", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keep Strategy") {
                Picker("Keep", selection: keeperPolicy) {
                    ForEach(KeeperSelectionPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                Text(keeperPolicy.wrappedValue == .preserve ? L10n.tr("Prefer favorites, edited versions and better detail. Your choices always take priority.") : keeperPolicy.wrappedValue.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Your manual keeper choice always takes priority. This preference applies to new scan results.", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Similar photo suggestions") {
                Toggle("Similar photo suggestions", isOn: $similarityEnabled)
                Picker("Review sensitivity", selection: sensitivity) {
                    Text("Fewer Suggestions").tag(SimilaritySensitivityPreset.precisionFirst)
                    Text("Balanced").tag(SimilaritySensitivityPreset.balanced)
                    Text("More Suggestions").tag(SimilaritySensitivityPreset.discovery)
                }
                .disabled(!similarityEnabled)
                Text("Choose how closely photos must match. Start with fewer suggestions to reduce uncertain matches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Scan with These Settings") { archive.analyze() }
                    .disabled(!archive.canScanSelectedSources)
                Label("Changes apply to the next scan. Similar photos always require your review.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Turn off similar photo suggestions to scan exact copies and photo quality only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keptora Pro") {
                LabeledContent("Lifetime unlock", value: store.entitlementLabel)
                LabeledContent("Free allowance", value: store.trialLabel)
#if DEBUG
                if store.requiresProductConfiguration {
                    Label("Replace the placeholder bundle and product identifiers before App Store submission.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
#endif
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { purchaseActions }
                    VStack(alignment: .leading, spacing: 8) { purchaseActions }
                }.controlSize(.large)
                if let message = store.statusMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                DisclosureGroup("Advanced Tools") {
                    Toggle("Show full file paths", isOn: $showFilePaths)
                    Text("This display setting applies to Advanced Tools. Library diagnostics always redact paths.").font(.caption).foregroundStyle(.secondary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { privacyActions }
                    VStack(alignment: .leading, spacing: 8) { privacyActions }
                }.controlSize(.large)
                LabeledContent("Image upload", value: "Never")
                LabeledContent("Account", value: "Not required")
            }

        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .accessibilityIdentifier("mac.page.settings")
        .task { await store.refresh() }
        .onDisappear { if archive.presentationOwner == .settings { archive.closePresentation() } }
        .sheet(isPresented: store.paywallBinding(for: .settings)) { PaywallView().environmentObject(store) }
        .alert("Something went wrong", isPresented: archive.errorBinding(for: .settings)) {
            Button("OK", role: .cancel) { archive.error = nil; archive.closePresentation() }
        } message: { Text(archive.error ?? "") }
    }
    @ViewBuilder private var purchaseActions: some View {
        Button("View Keptora Pro") { store.presentPaywall(.settings, host: .settings) }
            .buttonStyle(.borderedProminent).tint(KeptoraDesign.accent).accessibilityIdentifier("mac.settings.showPaywall")
        Button("Restore Purchases") { Task { await store.restorePurchases() } }.disabled(store.isWorking)
    }
    @ViewBuilder private var privacyActions: some View {
        Button("Show Welcome Tour") { openWindow(id: "main"); model.showOnboarding() }.accessibilityIdentifier("mac.settings.showOnboarding")
        Button("Export Diagnostics…") { archive.presentationOwner = .settings; archive.exportDiagnostics(); if archive.error == nil { archive.closePresentation() } }
    }
}

private struct KeptoraReleaseLinks: View {
    var body: some View {
        Section("Links") {
            Link("Privacy Policy", destination: AppStoreConfiguration.privacyPolicyURL)
            Link("Support", destination: AppStoreConfiguration.supportURL)
            Link("Terms of Use", destination: AppStoreConfiguration.termsOfUseURL)
        }
    }
}
