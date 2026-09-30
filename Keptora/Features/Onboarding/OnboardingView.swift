import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page = 0
    @State private var iconBounce = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Everything stays on your Mac",
            detail: "Keptora scans only the folder you choose. Images, hashes, thumbnails, and decisions are never uploaded — no account required.",
            systemImage: "lock.shield.fill",
            accent: Color(red: 0.15, green: 0.52, blue: 0.37)
        ),
        OnboardingPage(
            title: "Proof, not guesswork",
            detail: "Exact duplicates are confirmed by SHA-256 hash. Similar-photo groups are visual suggestions only — they never become cleanup actions automatically.",
            systemImage: "checkmark.seal.fill",
            accent: Color(red: 0.14, green: 0.42, blue: 0.88)
        ),
        OnboardingPage(
            title: "Undo anything, any time",
            detail: "Review a Cleanup Plan before anything moves. Keptora protects one keeper per group, signs a manifest, and supports full restore from History.",
            systemImage: "arrow.uturn.backward.circle.fill",
            accent: Color(red: 0.78, green: 0.42, blue: 0.12)
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            let item = pages[page]

            // Icon container with gradient
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [item.accent.opacity(0.18), item.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: item.systemImage)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(item.accent)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(iconBounce ? 1.08 : 1.0)
            }
            .frame(width: 120, height: 120)
            .shadow(color: item.accent.opacity(0.22), radius: 14, y: 6)
            .accessibilityHidden(true)
            .onChange(of: page) { _ in
                withAnimation(KeptoraDesign.animSpring) {
                    iconBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(KeptoraDesign.animSpring) { iconBounce = false }
                }
            }
            .onAppear {
                withAnimation(KeptoraDesign.animSpring.delay(0.1)) { iconBounce = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(KeptoraDesign.animSpring) { iconBounce = false }
                }
            }

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
            .animation(KeptoraDesign.animMedium, value: page)

            // Dot indicator
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? item.accent : Color.secondary.opacity(0.22))
                        .frame(width: index == page ? 28 : 8, height: 8)
                        .animation(KeptoraDesign.animSpring, value: page)
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
                    .accessibilityIdentifier("mac.onboarding.close")
                Spacer()
                if page > 0 {
                    Button("Back") {
                        withAnimation(KeptoraDesign.animMedium) { page -= 1 }
                    }
                    .accessibilityIdentifier("mac.onboarding.back")
                }
                Button(page == pages.count - 1 ? "Get Started" : "Continue") {
                    if page == pages.count - 1 {
                        model.completeOnboarding()
                        model.chooseFolder()
                    } else {
                        withAnimation(KeptoraDesign.animMedium) { page += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(item.accent)
                .keyboardShortcut(.defaultAction)
                .animation(KeptoraDesign.animFast, value: page)
                .accessibilityIdentifier("mac.onboarding.continue")
            }
            .padding(20)
        }
        .frame(minWidth: 720, idealWidth: 760, minHeight: 560, idealHeight: 600)
        .interactiveDismissDisabled()
    }
}

private struct OnboardingPage {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String
    let accent: Color
}
