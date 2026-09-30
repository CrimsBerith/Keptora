import KeptoraCore
import Photos
import SwiftUI

struct MobileSettingsView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Keptora.AppLanguage") private var selectedLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(purchase.isUnlocked ? MobileKeptoraDesign.brandGradient : LinearGradient(colors: [MobileKeptoraDesign.accent, MobileKeptoraDesign.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Image(systemName: purchase.isUnlocked ? "checkmark.seal.fill" : "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keptora Pro")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                            Text(purchase.isUnlocked ? LocalizedStringKey("Lifetime unlocked") : LocalizedStringKey("Free version active"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if purchase.isUnlocked {
                            MobilePillBadge(title: "Unlocked", systemImage: "checkmark", tint: MobileKeptoraDesign.mint)
                        }
                    }

                    if !purchase.isUnlocked {
                        Button {
                            store.present(.paywall)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("View Keptora Pro")
                            }
                            .frame(maxWidth: .infinity, minHeight: 38)
                        }
                        .buttonStyle(MobilePrimaryButtonStyle())
                        .accessibilityIdentifier("ios.settings.showPaywall")
                    }

                    Button("Restore Purchases") { Task { await purchase.restore() } }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .disabled(purchase.isWorking)
                        .accessibilityIdentifier("ios.settings.restorePurchases")

                    if let status = purchase.statusMessage {
                        Text(status)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Keptora Pro")
                    .font(MobileKeptoraDesign.labelFont)
            }

            Section {
                LabeledContent("Permission", value: permissionLabel)
                if store.canOpenPhotosSettings {
                    Button("Open Settings") { store.openPhotosSettings() }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                if store.authorization == .limited {
                    Text("Keptora scans only the photos you selected. You can change access in Settings > Privacy & Security > Photos.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Label("iCloud originals are never downloaded until you approve a network scan.", systemImage: "icloud.and.arrow.down")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Photos Access")
                    .font(MobileKeptoraDesign.labelFont)
            }

            Section {
                Label("Exact copies require SHA-256 byte-level proof.", systemImage: "checkmark.seal")
                Label("Similar photos are review-only and never enter cleanup.", systemImage: "hand.raised")
                Label("Photos cleanup uses Apple's Recently Deleted flow.", systemImage: "photo.on.rectangle")
            } header: {
                Text("Safety")
                    .font(MobileKeptoraDesign.labelFont)
            }

            Section {
                LabeledContent(String(localized: "Photo upload")) { Text(String(localized: "Never")) }
                LabeledContent(String(localized: "Account")) { Text(String(localized: "Not required")) }
                LabeledContent(String(localized: "Analytics")) { Text(String(localized: "None")) }
                if let privacyURL = URL(string: "https://alfagolab.com/keptora/privacy") {
                    Link(String(localized: "Privacy Policy"), destination: privacyURL)
                        .accessibilityIdentifier("ios.settings.privacy")
                }
                if let supportURL = URL(string: "https://alfagolab.com/keptora/support") {
                    Link(String(localized: "Support"), destination: supportURL)
                        .accessibilityIdentifier("ios.settings.support")
                }
            } header: {
                Text(String(localized: "Privacy"))
                    .font(MobileKeptoraDesign.labelFont)
            }

            Section {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Language")
                    .font(MobileKeptoraDesign.labelFont)
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await MediaFingerprintDiskCache.shared.clear()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                    }
                }
                .accessibilityIdentifier("ios.settings.clearCache")
            } header: {
                Text("Maintenance")
                    .font(MobileKeptoraDesign.labelFont)
            }

            Section {
                LabeledContent("Version", value: "1.0.0 (182)")
                Text("Keptora by AlfagoLab")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
                    .font(MobileKeptoraDesign.labelFont)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MobileAuroraBackground())
        .tint(MobileKeptoraDesign.accent)
        .navigationTitle("Settings")
        .accessibilityIdentifier("ios.page.settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Close Settings screen")
                    .accessibilityIdentifier("ios.settings.close")
            }
        }
    }

    private var permissionLabel: String {
        switch store.authorization {
        case .authorized: return String(localized: "Full access")
        case .limited: return String(localized: "Selected photos")
        case .denied: return String(localized: "Denied")
        case .restricted: return String(localized: "Restricted")
        case .notDetermined: return String(localized: "Not requested")
        case .unavailable: return String(localized: "Unavailable")
        }
    }
}
