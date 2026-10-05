import KeptoraCore
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreEntitlementController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Hero illustration
                        Image("paywall_hero")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(KeptoraDesign.borderGradient, lineWidth: 1)
                            }
                            .shadow(color: KeptoraDesign.accentGlow, radius: 22, y: 8)
                            .accessibilityHidden(true)

                        // Headline
                        VStack(spacing: 8) {
                            Text(store.paywallReason.titleKey)
                                .font(KeptoraDesign.titleFont)
                            Text(store.paywallReason.detailKey)
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
                            Text("Manual selection, privacy and recovery are available without Pro.").font(.callout).foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: 590, alignment: .leading)
                        .background(KeptoraDesign.quiet,
                                    in: RoundedRectangle(cornerRadius: KeptoraDesign.cardRadius, style: .continuous))

                        // Trial label
                        Text(store.trialLabel)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)

#if DEBUG
                        if store.requiresProductConfiguration {
                            Label("StoreKit is using a placeholder product ID. Configure release identifiers before testing purchases.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: 590)
                        }
#endif

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

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Link(destination: AppStoreConfiguration.privacyPolicyURL) { Text("Privacy Policy").font(.caption).frame(minHeight: 32).contentShape(Rectangle()) }
                        Link(destination: AppStoreConfiguration.termsOfUseURL) { Text("Terms of Use").font(.caption).frame(minHeight: 32).contentShape(Rectangle()) }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { secondaryActions; Spacer(minLength: 12); purchaseButton }
                        VStack(alignment: .leading, spacing: 8) { secondaryActions; purchaseButton }
                    }
                }.controlSize(.large)
                .padding(18)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(14)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("mac.paywall.dismiss")
        }
        .frame(minWidth: 540, idealWidth: 640, minHeight: 480, idealHeight: 580)
        .task { if store.lifetimeProduct == nil { await store.refresh() } }
    }
    private var secondaryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondaryButtons }
            VStack(alignment: .leading, spacing: 8) { secondaryButtons }
        }
    }
    @ViewBuilder private var secondaryButtons: some View {
        Button("Maybe Later") { dismiss() }.keyboardShortcut(.cancelAction).accessibilityIdentifier("mac.paywall.close")
        if store.lifetimeProduct == nil && !store.isLifetimeUnlocked {
            Button("Retry Loading") { Task { await store.refresh() } }.disabled(store.isWorking).accessibilityIdentifier("mac.paywall.retry")
        }
        Button("Restore Purchases") { Task { await store.restorePurchases() } }.disabled(store.isWorking)
    }
    private var purchaseButton: some View {
        Button { Task { await store.purchaseLifetime() } } label: {
            Group {
                if store.isWorking { ProgressView().controlSize(.small) }
                else if let product = store.lifetimeProduct { Text("Unlock for \(product.displayPrice)") }
                else if store.isLifetimeUnlocked { Text("Purchased") }
                else { Text("Lifetime Product Unavailable") }
            }.frame(minWidth: 150, minHeight: 32)
        }.buttonStyle(.borderedProminent).tint(KeptoraDesign.accent)
            .disabled(store.isWorking || store.isLifetimeUnlocked || store.lifetimeProduct == nil)
    }

    private func feature(_ text: LocalizedStringKey, image: String) -> some View {
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
