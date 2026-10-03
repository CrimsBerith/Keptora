import SwiftUI

struct MobileOnboardingView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenMobileOnboarding") private var hasSeenMobileOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            title: "Every Photo. Your Choice.",
            subtitle: "Browse your entire library or compare similar shots using images, capture time and location. Only remove items you choose.",
            icon: "checkmark.seal.fill",
            tint: MobileKeptoraDesign.accent
        ),
        OnboardingStep(
            id: 2,
            title: "Review Before Removing",
            subtitle: "Photos can be recovered from Recently Deleted for up to 30 days unless deleted sooner. Folder files stay in a recovery area until you restore them.",
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
                        ScrollView {
                          VStack(spacing: 24) {

                            Image(["onboarding_privacy", "onboarding_proof", "onboarding_restore"][step.id])
                                .resizable().scaledToFit().frame(maxHeight: 270)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal, 24).accessibilityHidden(true)

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

                          }.padding(.vertical, 20)
                        }
                        .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    Button {
                        if currentPage < steps.count - 1 {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
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
