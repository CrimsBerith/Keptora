import SwiftUI

struct MobileOnboardingView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    /// First launch gets one short welcome; Settings ▸ How Keptora Works opens the full three-page tour.
    @State private var isFirstRun = !UserDefaults.standard.bool(forKey: "hasSeenMobileOnboarding")

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
            subtitle: "See related photos together. Tap to select, choose what to keep, and review before removing anything.",
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
        if isFirstRun { welcome } else { tour }
    }

    private var welcome: some View {
        ZStack {
            MobileAuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image("onboarding_privacy").resizable().scaledToFit().frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 24)).frame(maxWidth: .infinity).accessibilityHidden(true)
                    Text("Every Photo. Your Choice.").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    VStack(alignment: .leading, spacing: 14) {
                        welcomeRow("lock.shield.fill", "Your photos stay on this device.", tint: MobileKeptoraDesign.mint)
                        welcomeRow("checkmark.circle.fill", "You choose what to remove and review it first.", tint: MobileKeptoraDesign.accent)
                        welcomeRow("arrow.uturn.backward.circle.fill", "Removed items can be recovered.", tint: MobileKeptoraDesign.danger)
                    }
                }
                .padding(24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { finishOnboarding() } label: {
                Text("Get Started").font(.system(.headline, design: .rounded).weight(.bold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(MobilePrimaryButtonStyle())
            .accessibilityIdentifier("ios.onboarding.continue")
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
    }

    private func welcomeRow(_ icon: String, _ text: LocalizedStringKey, tint: Color) -> some View {
        Label { Text(text).font(.system(.body, design: .rounded)) } icon: {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }

    private var tour: some View {
        ZStack {
            MobileAuroraBackground()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        finishOnboarding()
                    }
                    .buttonStyle(MobileActionButtonStyle())
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
                            .frame(maxWidth: .infinity)
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
        store.completeOnboarding()
    }
}
