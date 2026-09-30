import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Everything stays on your Mac",
            detail: "Keptora scans only the folder you choose. Images, hashes, thumbnails, and decisions are never uploaded — no account required.",
            imageName: "onboarding_privacy",
            accent: Color(red: 0.15, green: 0.52, blue: 0.37)
        ),
        OnboardingPage(
            title: "Proof, not guesswork",
            detail: "Exact duplicates are confirmed by SHA-256 hash. Similar-photo groups are visual suggestions only — they never become cleanup actions automatically.",
            imageName: "onboarding_proof",
            accent: Color(red: 0.14, green: 0.42, blue: 0.88)
        ),
        OnboardingPage(
            title: "Undo anything, any time",
            detail: "Review a Cleanup Plan before anything moves. Keptora protects one keeper per group, signs a manifest, and supports full restore from History.",
            imageName: "onboarding_restore",
            accent: Color(red: 0.78, green: 0.42, blue: 0.12)
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            let item = pages[page]

            // Illustration
            Image(item.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 360, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(KeptoraDesign.borderGradient, lineWidth: 1)
                }
                .shadow(color: item.accent.opacity(0.28), radius: 22, y: 10)
                .id("art-\(page)")
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .keptoraAnimation(KeptoraDesign.animMedium, value: page)
                .accessibilityHidden(true)

            // Kopya
            VStack(spacing: 12) {
                Text(item.title)
                    .font(KeptoraDesign.titleFont)
                    .multilineTextAlignment(.center)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("title-\(page)")

                Text(item.detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 610)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("detail-\(page)")
            }
            .padding(.top, 26)
            .animation(reduceMotion ? nil : KeptoraDesign.animMedium, value: page)

            // Dot indicator
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? item.accent : Color.secondary.opacity(0.22))
                        .frame(width: index == page ? 28 : 8, height: 8)
                        .keptoraAnimation(KeptoraDesign.animSpring, value: page)
                }
            }
            .padding(.top, 26)

            Spacer(minLength: 28)
            Divider()

            // Navigation
            HStack {
                Button("Not Now") { model.completeOnboarding() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("mac.onboarding.close")
                Spacer()
                if page > 0 {
                    Button("Back") {
                        withAnimation(reduceMotion ? nil : KeptoraDesign.animMedium) { page -= 1 }
                    }
                    .accessibilityIdentifier("mac.onboarding.back")
                }
                Button(page == pages.count - 1 ? "Get Started" : "Continue") {
                    if page == pages.count - 1 {
                        model.completeOnboarding()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            model.chooseFolder()
                        }
                    } else {
                        withAnimation(reduceMotion ? nil : KeptoraDesign.animMedium) { page += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(item.accent)
                .keyboardShortcut(.defaultAction)
                .keptoraAnimation(KeptoraDesign.animFast, value: page)
                .accessibilityIdentifier("mac.onboarding.continue")
            }
            .padding(20)
        }
        .frame(minWidth: 720, idealWidth: 760, minHeight: 620, idealHeight: 660)
        .interactiveDismissDisabled()
    }
}

private struct OnboardingPage {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let imageName: String
    let accent: Color
}
