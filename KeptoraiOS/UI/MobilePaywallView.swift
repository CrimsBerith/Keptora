import KeptoraCore
import SwiftUI

struct MobilePaywallView: View {
    @EnvironmentObject private var purchase: MobilePurchaseController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MobileAuroraBackground()
                ScrollView {
                    VStack(spacing: 24) {
                        Image("paywall_hero")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(MobileKeptoraDesign.borderGradient, lineWidth: 1)
                            }
                            .shadow(color: MobileKeptoraDesign.accentGlow, radius: 20, y: 8)
                            .accessibilityHidden(true)

                        VStack(spacing: 6) {
                            Text("Keptora Pro")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .foregroundStyle(MobileKeptoraDesign.brandGradient)

                            Text("One purchase. No subscription.")
                                .font(.system(.title3, design: .rounded).weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            feature("Unlimited exact-copy review", "infinity", MobileKeptoraDesign.violet)
                            Text("Manual selection, privacy and recovery are available without Pro.").font(.callout).foregroundStyle(.secondary)
                        }
                        .keptoraPanel(tint: MobileKeptoraDesign.violet)

                        VStack(spacing: 14) {
                            Button {
                                Task { await purchase.purchase() }
                            } label: {
                                Group {
                                    if purchase.isWorking {
                                        ProgressView().tint(.white)
                                    } else if let product = purchase.product {
                                        Text("Unlock for \(product.displayPrice)")
                                    } else {
                                        Text("Product unavailable")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MobilePrimaryButtonStyle())
                            .disabled(purchase.product == nil || purchase.isWorking)
                            .accessibilityIdentifier("ios.paywall.purchase")

                            if purchase.product == nil && !purchase.isUnlocked {
                                Button(String(localized: "Retry Loading Product")) {
                                    Task { await purchase.refresh() }
                                }
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(MobileKeptoraDesign.accent)
                                .buttonStyle(MobileActionButtonStyle(fillsWidth: true))
                                .disabled(purchase.isWorking)
                                .accessibilityIdentifier("ios.paywall.retry")
                            }

                            Button("Restore Purchases") { Task { await purchase.restore() } }
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(MobileKeptoraDesign.accent)
                                .buttonStyle(MobileActionButtonStyle(fillsWidth: true))
                                .disabled(purchase.isWorking)
                                .accessibilityIdentifier("ios.paywall.restorePurchases")

                            // Purchase / restore outcomes (cancelled, pending, failed) were previously invisible here.
                            if let status = purchase.statusMessage {
                                Text(status)
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .accessibilityIdentifier("ios.paywall.status")
                            }

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 12) { legalLinks }
                                VStack(spacing: 8) { legalLinks }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.top, 4)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Keptora Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityLabel("Close Keptora Pro screen")
                        .accessibilityIdentifier("ios.paywall.close")
                }
            }
            .onChange(of: purchase.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
            .task {
                if purchase.product == nil {
                    await purchase.refresh()
                }
            }
        }
    }
    @ViewBuilder private var legalLinks: some View {
        Link(destination: AppStoreConfiguration.privacyPolicyURL) {
            Text("Privacy Policy").font(.caption).padding(.horizontal, 8).padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        Link(destination: AppStoreConfiguration.termsOfUseURL) {
            Text("Terms of Use").font(.caption).padding(.horizontal, 8).padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
    }

    @ScaledMetric(relativeTo: .body) private var featureIconBoxSize: CGFloat = 38

    private func feature(_ title: LocalizedStringKey, _ image: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: image)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: featureIconBoxSize, height: featureIconBoxSize)

            Text(title)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}
