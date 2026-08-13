import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreEntitlementController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                // Hero icon
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(CulloraDesign.accentGradient)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 108, height: 108)
                .shadow(color: CulloraDesign.accentGlow, radius: 18, y: 6)

                // Headline
                VStack(spacing: 8) {
                    Text(store.paywallReason.title)
                        .font(CulloraDesign.titleFont)
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
                    feature("Family Sharing included", image: "person.3")
                    feature("One-time purchase · Privacy-first · No upload", image: "checkmark.shield.fill")
                }
                .padding(20)
                .frame(maxWidth: 590, alignment: .leading)
                .background(CulloraDesign.quiet,
                            in: RoundedRectangle(cornerRadius: CulloraDesign.cardRadius, style: .continuous))

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

            Divider()

            HStack {
                Button("Maybe Later") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Restore Purchases") { Task { await store.restorePurchases() } }
                    .disabled(store.isWorking)
                Button {
                    Task { await store.purchaseLifetime() }
                } label: {
                    if store.isWorking {
                        ProgressView().controlSize(.small).frame(minWidth: 150)
                    } else {
                        Text(store.purchaseButtonLabel).frame(minWidth: 150)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(CulloraDesign.accent)
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
                .foregroundStyle(CulloraDesign.success)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
