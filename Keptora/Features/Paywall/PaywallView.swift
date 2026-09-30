import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreEntitlementController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
            VStack(spacing: 20) {
                // Hero illustration
                Image("paywall_hero")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(KeptoraDesign.borderGradient, lineWidth: 1)
                    }
                    .shadow(color: KeptoraDesign.accentGlow, radius: 22, y: 8)
                    .accessibilityHidden(true)

                // Headline
                VStack(spacing: 8) {
                    Text(store.paywallReason.title)
                        .font(KeptoraDesign.titleFont)
                    Text(store.paywallReason.detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                // One-time callout
                (Text("One-time purchase.").fontWeight(.semibold) + Text(" No subscription, ever."))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Feature list
                VStack(alignment: .leading, spacing: 14) {
                    feature("Unlimited exact-duplicate review decisions", image: "infinity")
                    feature("Unlimited reversible Cleanup Plans", image: "arrow.uturn.backward.circle")
                    feature("Private, on-device processing", image: "lock.shield.fill")
                    feature("One-time purchase · Privacy-first · No upload", image: "checkmark.shield.fill")
                }
                .padding(20)
                .frame(maxWidth: 590, alignment: .leading)
                .background(KeptoraDesign.quiet,
                            in: RoundedRectangle(cornerRadius: KeptoraDesign.cardRadius, style: .continuous))

                // Trial label
                Text(store.trialLabel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                if store.requiresProductConfiguration {
                    Label("StoreKit is using a placeholder product ID. Configure release identifiers before testing purchases.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: 590)
                }

                if let statusMessage = store.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 590)
                }
            }
            .padding(28)
            }

            Divider()

            HStack(spacing: 16) {
                Button("Maybe Later") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("mac.paywall.close")
                Spacer()
                if let privacyURL = URL(string: "https://alfagolab.com/keptora/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if let termsURL = URL(string: "https://alfagolab.com/keptora") {
                    Link("Terms of Use", destination: termsURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Restore Purchases") { Task { await store.restorePurchases() } }
                    .disabled(store.isWorking)
                Button {
                    Task { await store.purchaseLifetime() }
                } label: {
                    if store.isWorking {
                        ProgressView().controlSize(.small).frame(minWidth: 150)
                    } else if let product = store.lifetimeProduct {
                        Text("Unlock for \(product.displayPrice)").frame(minWidth: 150)
                    } else if store.isLifetimeUnlocked {
                        Text("Purchased").frame(minWidth: 150)
                    } else {
                        Text("Lifetime Product Unavailable").frame(minWidth: 150)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(KeptoraDesign.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(store.isWorking || store.isLifetimeUnlocked || store.lifetimeProduct == nil)
            }
            .padding(18)
        }
        .frame(minWidth: 700, idealWidth: 740, minHeight: 600, idealHeight: 640)
        .task { if store.lifetimeProduct == nil { await store.refresh() } }
    }

    private func feature(_ text: String, image: String) -> some View {
        Label {
            Text(text)
                .font(.callout.weight(.medium))
        } icon: {
            Image(systemName: image)
                .foregroundStyle(KeptoraDesign.success)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
