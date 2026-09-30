import SwiftUI

struct MobileOnboardingView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenMobileOnboarding") private var hasSeenMobileOnboarding = false
    @State private var currentPage = 0

    private struct OnboardingStep: Identifiable {
        let id: Int
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let icon: String
        let tint: Color
    }

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            id: 0,
            title: "Private & On-Device",
            subtitle: "Keptora scans only what you choose. Photos, fingerprints, and review decisions never leave your device.",
            icon: "lock.shield.fill",
            tint: MobileKeptoraDesign.mint
        ),
        OnboardingStep(
            id: 1,
            title: "Proof, Not Guesswork",
            subtitle: "Exact duplicates require SHA-256 byte-level verification. Similar photos are for comparison only — never auto-deleted.",
            icon: "checkmark.seal.fill",
            tint: MobileKeptoraDesign.accent
        ),
        OnboardingStep(
            id: 2,
            title: "Always Reversible",
            subtitle: "One keeper photo is always protected. Cleaned files move to Recently Deleted or Keptora Bin and can be restored at any time.",
            icon: "arrow.uturn.backward.circle.fill",
            tint: MobileKeptoraDesign.coral
        )
    ]

    var body: some View {
        ZStack {
            MobileAuroraBackground()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        finishOnboarding()
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .accessibilityIdentifier("ios.onboarding.skip")
                }

                TabView(selection: $currentPage) {
                    ForEach(steps) { step in
                        VStack(spacing: 24) {
                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(step.tint.opacity(0.18))
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 12)

                                Circle()
                                    .fill(step.tint.opacity(0.12))
                                    .frame(width: 110, height: 110)

                                Image(systemName: step.icon)
                                    .font(.system(size: 54, weight: .semibold))
                                    .foregroundStyle(step.tint)
                            }

                            VStack(spacing: 12) {
                                Text(step.title)
                                    .font(.system(.title, design: .rounded).weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.primary)

                                Text(step.subtitle)
                                    .font(.system(.body, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 28)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }
                        .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    Button {
                        if currentPage < steps.count - 1 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentPage += 1
                            }
                        } else {
                            finishOnboarding()
                        }
                    } label: {
                        Text(currentPage == steps.count - 1 ? "Get Started" : "Continue")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(MobilePrimaryButtonStyle())
                    .accessibilityIdentifier("ios.onboarding.continue")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func finishOnboarding() {
        hasSeenMobileOnboarding = true
        store.dismissModal()
        dismiss()
    }
}
