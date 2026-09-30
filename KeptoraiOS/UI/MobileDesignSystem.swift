import SwiftUI

enum MobileKeptoraDesign {
    // MARK: – Layout Tokens
    static let pagePadding: CGFloat = 18
    static let cardRadius: CGFloat = 22
    static let compactRadius: CGFloat = 14

    // MARK: – Semantic Palette (Matching macOS Cullora Aurora)
    static let ink = Color(uiColor: .label)
    static let secondaryInk = Color(uiColor: .secondaryLabel)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let elevated = Color(uiColor: .secondarySystemGroupedBackground)

    // Keptora aurora spectrum
    static let accent   = Color(red: 0.34, green: 0.28, blue: 0.96)
    static let violet   = Color(red: 0.58, green: 0.25, blue: 0.94)
    static let cyan     = Color(red: 0.08, green: 0.67, blue: 0.88)
    static let coral    = Color(red: 0.98, green: 0.39, blue: 0.47)
    static let mint     = Color(red: 0.08, green: 0.64, blue: 0.46)
    static let success  = mint
    static let amber    = Color(red: 0.94, green: 0.58, blue: 0.12)
    static let warning  = amber
    static let danger   = Color(red: 0.92, green: 0.24, blue: 0.30)

    // MARK: – Derived Glow & Subtle Accents
    static let accentGlow       = violet.opacity(0.30)
    static let accentSubtle     = accent.opacity(0.12)
    static let accentBorder     = accent.opacity(0.22)

    // MARK: – Gradients
    static let brandGradient = LinearGradient(
        colors: [cyan, accent, violet, coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.22, green: 0.46, blue: 0.98),
                 Color(red: 0.46, green: 0.24, blue: 0.95),
                 Color(red: 0.92, green: 0.27, blue: 0.56)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let iconGradient = LinearGradient(
        colors: [cyan, accent, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.07, green: 0.10, blue: 0.30),
            Color(red: 0.23, green: 0.13, blue: 0.52),
            Color(red: 0.48, green: 0.16, blue: 0.45)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let borderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.46),
            cyan.opacity(0.32),
            violet.opacity(0.20),
            Color.white.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let pageGradient = LinearGradient(
        colors: [
            Color(uiColor: .systemGroupedBackground),
            accent.opacity(0.045),
            cyan.opacity(0.030),
            Color(uiColor: .systemGroupedBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: – Typography Tokens (Rounded Design)
    static let titleFont   = Font.system(size: 32, weight: .bold,     design: .rounded)
    static let sectionFont = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let labelFont   = Font.system(size: 11, weight: .bold,     design: .rounded)
    static let bodyFont    = Font.system(.body,   design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)
    static let metricFont  = Font.system(size: 24, weight: .bold,     design: .rounded)

    // MARK: – Animation Presets
    static let animFast   = Animation.easeOut(duration: 0.16)
    static let animMedium = Animation.easeInOut(duration: 0.26)
    static let animSpring = Animation.spring(response: 0.38, dampingFraction: 0.74)
}

// MARK: – Ambient Aurora Mesh Background

struct MobileAuroraBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MobileKeptoraDesign.pageGradient
                
                Circle()
                    .fill(MobileKeptoraDesign.violet.opacity(0.14))
                    .frame(width: max(proxy.size.width * 0.95, 340))
                    .blur(radius: 80)
                    .offset(x: proxy.size.width * 0.38, y: -proxy.size.height * 0.34)

                Circle()
                    .fill(MobileKeptoraDesign.cyan.opacity(0.11))
                    .frame(width: max(proxy.size.width * 0.85, 300))
                    .blur(radius: 85)
                    .offset(x: -proxy.size.width * 0.40, y: proxy.size.height * 0.32)

                Circle()
                    .fill(MobileKeptoraDesign.coral.opacity(0.07))
                    .frame(width: max(proxy.size.width * 0.65, 240))
                    .blur(radius: 70)
                    .offset(x: proxy.size.width * 0.20, y: proxy.size.height * 0.15)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: – Brand Mark

/// Keptora logo. Two photo frames: the translucent one behind is the duplicate that is set aside,
/// the solid one in front with a check mark is the keeper. Mirrors AppStore/AppIcon/logo/*.svg
/// (iOS copy of the macOS KeptoraLogoMark; geometry is expressed in the 1024-pt art space of those files).
struct MobileBrandMark: View {
    let size: CGFloat
    var showsShadow: Bool = true

    private var s: CGFloat { size / 1024 }
    private var corner: CGFloat { size * 0.2237 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.098, green: 0.761, blue: 0.949),
                             Color(red: 0.294, green: 0.247, blue: 0.918),
                             Color(red: 0.608, green: 0.184, blue: 0.878)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.31, blue: 0.60).opacity(0.50), .clear],
                    center: UnitPoint(x: 0.92, y: 0.96), startRadius: 0, endRadius: size * 0.60))
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.38), .clear],
                    center: UnitPoint(x: 0.16, y: 0.10), startRadius: 0, endRadius: size * 0.65))

            // Duplicate that is set aside
            RoundedRectangle(cornerRadius: 96 * s, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .overlay {
                    RoundedRectangle(cornerRadius: 96 * s, style: .continuous)
                        .stroke(Color.white.opacity(0.62), lineWidth: max(0.5, 16 * s))
                }
                .frame(width: 380 * s, height: 380 * s)
                .rotationEffect(.degrees(-8))
                .position(x: 422 * s, y: 412 * s)

            // Keeper
            RoundedRectangle(cornerRadius: 96 * s, style: .continuous)
                .fill(LinearGradient(
                    colors: [.white, Color(red: 0.914, green: 0.894, blue: 1.0)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 380 * s, height: 380 * s)
                .shadow(color: Color(red: 0.10, green: 0.04, blue: 0.36).opacity(0.45),
                        radius: 30 * s, y: 26 * s)
                .position(x: 602 * s, y: 612 * s)

            MobileCheckShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.118, green: 0.608, blue: 0.961),
                                 Color(red: 0.357, green: 0.247, blue: 0.941),
                                 Color(red: 0.886, green: 0.235, blue: 0.604)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 64 * s, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: max(0.5, size * 0.003))
        }
        .shadow(color: MobileKeptoraDesign.violet.opacity(showsShadow ? 0.32 : 0), radius: size * 0.20, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

private struct MobileCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 1024
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 520 * s, y: rect.minY + 616 * s))
        p.addLine(to: CGPoint(x: rect.minX + 584 * s, y: rect.minY + 680 * s))
        p.addLine(to: CGPoint(x: rect.minX + 694 * s, y: rect.minY + 548 * s))
        return p
    }
}

// MARK: – Reusable Premium Glassmorphic Card

struct MobilePremiumCard<Content: View>: View {
    var tint: Color = MobileKeptoraDesign.accent
    private let content: Content

    init(tint: Color = MobileKeptoraDesign.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: MobileKeptoraDesign.cardRadius, style: .continuous))
            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: MobileKeptoraDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MobileKeptoraDesign.cardRadius, style: .continuous)
                    .stroke(MobileKeptoraDesign.borderGradient, lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.09), radius: 22, y: 10)
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: – Metric Tile

struct MobileMetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color

    init(title: LocalizedStringKey, value: String, systemImage: String, tint: Color = MobileKeptoraDesign.accent) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(tint.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), tint.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: tint.opacity(0.08), radius: 14, y: 6)
    }
}

// MARK: – Primary Gradient Button Style

struct MobilePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .background(MobileKeptoraDesign.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: MobileKeptoraDesign.violet.opacity(configuration.isPressed ? 0.15 : 0.32), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(MobileKeptoraDesign.animFast, value: configuration.isPressed)
    }
}

// MARK: – Pill Status Badge

struct MobilePillBadge: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.24), lineWidth: 1)
        }
    }
}

// MARK: – Panel Modifier

extension View {
    func keptoraPanel(tint: Color = MobileKeptoraDesign.accent) -> some View {
        padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.40), tint.opacity(0.30), Color.primary.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: tint.opacity(0.09), radius: 22, y: 10)
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}
