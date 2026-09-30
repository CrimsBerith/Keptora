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
                        ZStack {
                            Circle()
                                .fill(MobileKeptoraDesign.violet.opacity(0.20))
                                .frame(width: 175, height: 175)
                                .blur(radius: 18)

                            MobileBrandMark(size: 110)

                            Image(systemName: "sparkles")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: MobileKeptoraDesign.violet, radius: 8)
                                .offset(x: 44, y: -42)
                        }
                        .padding(.top, 10)

                        VStack(spacing: 6) {
                            Text("Keptora Pro")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(MobileKeptoraDesign.brandGradient)

                            Text("One purchase. No subscription.")
                                .font(.system(.title3, design: .rounded).weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            feature("Unlimited exact-copy review", "infinity", MobileKeptoraDesign.violet)
                            feature("Reversible folder cleanup", "arrow.uturn.backward.circle", MobileKeptoraDesign.amber)
                            feature("Photos and Files", "photo.on.rectangle.angled", MobileKeptoraDesign.coral)
                            feature("Private, on-device processing", "lock.shield.fill", MobileKeptoraDesign.mint)
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

                            Button("Restore Purchases") { Task { await purchase.restore() } }
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(MobileKeptoraDesign.accent)
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

                            HStack(spacing: 12) {
                                if let privacyURL = URL(string: "https://alfagolab.com/keptora/privacy") {
                                    Link(String(localized: "Privacy Policy"), destination: privacyURL)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Text("•")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                if let termsURL = URL(string: "https://alfagolab.com/keptora") {
                                    Link(String(localized: "Terms of Use"), destination: termsURL)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
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
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Close Keptora Pro screen")
                        .accessibilityIdentifier("ios.paywall.close")
                }
            }
            .onChange(of: purchase.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }

    private func feature(_ title: LocalizedStringKey, _ image: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: image)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            Text(title)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}
