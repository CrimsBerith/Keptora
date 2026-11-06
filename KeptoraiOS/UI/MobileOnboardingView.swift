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
            title: "Total Control",
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
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(MobileKeptoraDesign.borderGradient, lineWidth: 1)
                        }
                        .shadow(color: MobileKeptoraDesign.accentGlow, radius: 18, y: 6)
                        .frame(maxWidth: .infinity).accessibilityHidden(true)
                    Text("Total Control").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    VStack(alignment: .leading, spacing: 14) {
                        welcomeRow("lock.shield.fill", "On-Device Privacy", tint: MobileKeptoraDesign.mint)
                        welcomeRow("checkmark.circle.fill", "Review Before Removing", tint: MobileKeptoraDesign.accent)
                        welcomeRow("arrow.uturn.backward.circle.fill", "Recoverable Anytime", tint: MobileKeptoraDesign.danger)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .keptoraPanel(tint: MobileKeptoraDesign.accent)
                }
                .padding(24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button { finishOnboarding() } label: {
                    Text("Get Started").font(.system(.headline, design: .rounded).weight(.bold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(MobilePrimaryButtonStyle())
                .accessibilityIdentifier("ios.onboarding.continue")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 1)
            }
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
                                .overlay {
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(MobileKeptoraDesign.borderGradient, lineWidth: 1)
                                }
                                .shadow(color: step.tint.opacity(0.25), radius: 18, y: 6)
                                .padding(.horizontal, 24).accessibilityHidden(true)

                            VStack(spacing: 12) {
                                Text(step.title)
                                    .font(.system(.title, design: .rounded).weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.primary)

                                Text(step.subtitle)
                                    .font(.system(.body, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(MobileKeptoraDesign.secondaryInk)
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
