import KeptoraCore
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreEntitlementController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            KeptoraBackdrop()

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
                                    .allowsHitTesting(false)
                            }
                            .shadow(color: reduceTransparency ? .clear : KeptoraDesign.accentGlow, radius: 22, y: 8)
                            .accessibilityHidden(true)

                        // Headline
                        VStack(spacing: 8) {
                            Text(store.paywallReason.titleKey)
                                .font(KeptoraDesign.titleFont)
                            Text(store.paywallReason.detailKey)
                                .font(.title3)
                                .foregroundStyle(KeptoraDesign.secondaryInk)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 560)
                        }

                        // One-time callout
                        Text("One purchase · No subscription")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(KeptoraDesign.secondaryInk)

                        // Feature list
                        VStack(alignment: .leading, spacing: 14) {
                            // What Pro actually unlocks: suggested batch selection beyond the first 100 items.
                            feature("Select suggestions in bulk without the 100-item limit", image: "infinity")
                            Text("Manual selection, privacy and recovery are available without Pro.").font(.callout).foregroundStyle(KeptoraDesign.secondaryInk)
                        }
                        .padding(20)
                        .frame(maxWidth: 590, alignment: .leading)
                        .keptoraGlass(cornerRadius: KeptoraDesign.cardRadius, tint: KeptoraDesign.violet)

                        // Trial label
                        Text(store.trialLabel)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(KeptoraDesign.secondaryInk)

#if DEBUG
                        if store.requiresProductConfiguration {
                            Label("StoreKit is using a placeholder product ID. Configure release identifiers before testing purchases.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(KeptoraDesign.warning)
                                .frame(maxWidth: 590)
                        }
#endif

                        if let statusMessage = store.statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(KeptoraDesign.secondaryInk)
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
                .background {
                    if reduceTransparency {
                        KeptoraDesign.canvas
                    } else {
                        Rectangle().fill(.ultraThinMaterial)
                    }
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.28 : 0.60), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 1)
                    .allowsHitTesting(false)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(KeptoraDesign.secondaryInk)
                    .frame(width: 28, height: 28)
                    .background(
                        reduceTransparency ? Color.secondary.opacity(0.18) : Color.white.opacity(0.12),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1).allowsHitTesting(false))
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
                else if let product = store.lifetimeProduct { Text(L10n.format("Unlock for %@", product.displayPrice)) }
                else if store.isLifetimeUnlocked { Text("Purchased") }
                else { Text("Lifetime Product Unavailable") }
            }.frame(minWidth: 150, minHeight: 32)
        }.buttonStyle(.borderedProminent).tint(KeptoraDesign.accentFill)
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
