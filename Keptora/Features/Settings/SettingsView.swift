import SwiftUI

private enum SettingsStorageKeys {
    static let checkpointInterval = "Keptora.CheckpointInterval"
    static let showFilePaths = "Keptora.ShowFilePaths"
    static let similarityEnabled = "Keptora.Feature.Similarity.v1"
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
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

    private var effectiveBootstrap: SimilarityCalibrationProfile {
        SimilarityCalibrationProfile
            .conservativeBootstrap(visionRevision: SimilarityEngine.pinnedRevision)
            .applying(sensitivity.wrappedValue)
    }

    var body: some View {
        Form {
            KeptoraReleaseLinks()
            Section("Scanning") {
                Stepper("Checkpoint every \(checkpointInterval) assets", value: $checkpointInterval, in: 25...500, step: 25)
                Text("Smaller checkpoints improve interruption recovery but add a small amount of database work.")
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
                Text(keeperPolicy.wrappedValue.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Your manual keeper choice always takes priority. This preference applies to new scan results.", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Similarity Calibration") {
                Picker("Review sensitivity", selection: sensitivity) {
                    ForEach(SimilaritySensitivityPreset.allCases) { Text($0.label).tag($0) }
                }
                Text(sensitivity.wrappedValue.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                    GridRow { Text("Very strong"); Text(effectiveBootstrap.veryStrongMaximum, format: .number.precision(.fractionLength(3))).monospacedDigit() }
                    GridRow { Text("Strong"); Text(effectiveBootstrap.strongMaximum, format: .number.precision(.fractionLength(3))).monospacedDigit() }
                    GridRow { Text("Review maximum"); Text(effectiveBootstrap.reviewMaximum, format: .number.precision(.fractionLength(3))).monospacedDigit() }
                }
                .font(.callout)
                Button("Apply to Current Review Groups") { model.refreshSimilarityGroupsForCurrentSensitivity() }
                    .disabled(model.similarityProgress.isRunning)
                Label("Sensitivity can only narrow the calibrated envelope. Similar groups never authorize cleanup.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Analysis") {
                Toggle("Similar photo suggestions", isOn: $similarityEnabled)
                Text("Similar photos are suggestions only. They never enter a cleanup plan.")
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
                HStack {
                    Button("View Keptora Pro") { store.presentPaywall(.settings) }
                        .buttonStyle(.borderedProminent)
                        .tint(KeptoraDesign.accent)
                        .accessibilityIdentifier("mac.settings.showPaywall")
                    Button("Restore Purchases") { Task { await store.restorePurchases() } }
                        .disabled(store.isWorking)
                }
                if let message = store.statusMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Toggle("Show full file paths", isOn: $showFilePaths)
                HStack {
                    Button("Show Welcome Tour") { model.showOnboarding() }
                        .accessibilityIdentifier("mac.settings.showOnboarding")
                    Button("Export Diagnostics…") { model.exportDiagnostics() }
                }
                LabeledContent("Image upload", value: "Never")
                LabeledContent("Account", value: "Not required")
            }

        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .accessibilityIdentifier("mac.page.settings")
        .task { await store.refresh() }
    }
}

private struct KeptoraReleaseLinks: View {
    private var privacy: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APP_PRIVACY_POLICY_URL") as? String,
           let url = URL(string: configured),
           url.scheme == "https", !(url.host?.isEmpty ?? true) {
            return url
        }
        return URL(string: "https://alfagolab.com/keptora/privacy")!
    }

    private var support: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APP_SUPPORT_URL") as? String,
           let url = URL(string: configured),
           url.scheme == "https", !(url.host?.isEmpty ?? true) {
            return url
        }
        return URL(string: "https://alfagolab.com/keptora/support")!
    }

    var body: some View {
        Section("Links") {
            Link("Privacy Policy", destination: privacy)
            Link("Support", destination: support)
        }
    }
}
