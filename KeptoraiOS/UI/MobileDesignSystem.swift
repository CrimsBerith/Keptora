import SwiftUI

enum MobileKeptoraDesign {
    // MARK: – Layout Tokens
    static let pagePadding: CGFloat = 18
    static let cardRadius: CGFloat = 22
    static let actionSpacing: CGFloat = 12
    static let stackedActionSpacing: CGFloat = 8
    static let minimumTouchTarget: CGFloat = 44
    static let primaryButtonHeight: CGFloat = 52

    // MARK: – Semantic Palette (Matching macOS Keptora Aurora)
    static let ink = Color(uiColor: .label)
    // Opaque secondary text stays legible on tinted panels as well as plain system surfaces.
    static let secondaryInk = adaptive(light: (0.34, 0.34, 0.38), dark: (0.76, 0.76, 0.80))

    // Keptora aurora spectrum.
    // Text, icon and tint colors have a light and a dark value, each at least 4.5:1 against
    // system and lightly tinted backgrounds (WCAG AA). Filled buttons with white labels use the
    // fixed `…Fill` colors instead, which keep white text above 4.5:1 in both modes.
    static let accent   = adaptive(light: (0.29, 0.22, 0.86), dark: (0.70, 0.67, 1.00))
    static let accentFill = Color(red: 0.34, green: 0.28, blue: 0.96)
    static let violet   = Color(red: 0.58, green: 0.25, blue: 0.94)
    static let cyan     = Color(red: 0.08, green: 0.67, blue: 0.88)
    static let coral    = Color(red: 0.98, green: 0.39, blue: 0.47)
    static let mint     = adaptive(light: (0.00, 0.42, 0.28), dark: (0.30, 0.85, 0.62))
    static let mintFill = Color(red: 0.05, green: 0.50, blue: 0.35)
    static let success  = mint
    static let amber    = adaptive(light: (0.56, 0.30, 0.00), dark: (1.00, 0.72, 0.30))
    static let warning  = amber
    static let danger   = adaptive(light: (0.70, 0.06, 0.12), dark: (1.00, 0.58, 0.58))
    static let dangerFill = Color(red: 0.75, green: 0.08, blue: 0.14)

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }

    // MARK: – Derived Glow & Subtle Accents
    static let accentGlow       = violet.opacity(0.30)

    // MARK: – Gradients
    static let brandGradient = LinearGradient(
        colors: [cyan, accent, violet, coral],
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
    static let labelFont   = Font.system(.caption2, design: .rounded).weight(.bold)

    // MARK: – Animation Presets
    static let animFast   = Animation.easeOut(duration: 0.16)
}

// MARK: – Ambient Aurora Mesh Background

struct MobileAuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MobileKeptoraDesign.pageGradient
                if !reduceTransparency {
                    glow(MobileKeptoraDesign.violet.opacity(colorScheme == .dark ? 0.18 : 0.12), max(proxy.size.width * 0.95, 340))
                        .offset(x: proxy.size.width * 0.38, y: -proxy.size.height * 0.34)
                    glow(MobileKeptoraDesign.cyan.opacity(colorScheme == .dark ? 0.15 : 0.09), max(proxy.size.width * 0.85, 300))
                        .offset(x: -proxy.size.width * 0.40, y: proxy.size.height * 0.32)
                    glow(MobileKeptoraDesign.coral.opacity(colorScheme == .dark ? 0.09 : 0.06), max(proxy.size.width * 0.65, 240))
                        .offset(x: proxy.size.width * 0.20, y: proxy.size.height * 0.15)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// Radial gradient instead of a blurred circle: same look, no offscreen blur pass behind every list.
    private func glow(_ color: Color, _ diameter: CGFloat) -> some View {
        RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: diameter * 0.8)
            .frame(width: diameter * 1.6, height: diameter * 1.6)
    }
}

// MARK: – Glassmorphism System

struct MobileGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var cornerRadius: CGFloat = MobileKeptoraDesign.cardRadius
    var tint: Color = MobileKeptoraDesign.accent
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSelected ? tint.opacity(0.18) : Color(uiColor: .secondarySystemGroupedBackground))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                colorScheme == .dark
                                    ? Color.white.opacity(isSelected ? 0.08 : 0.03)
                                    : Color.white.opacity(isSelected ? 0.50 : 0.35)
                            )

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(isSelected ? 0.14 : 0.04))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        borderShapeStyle,
                        lineWidth: isSelected ? 1.5 : 1.0
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: shadowColor,
                radius: isSelected ? 16 : 10,
                x: 0,
                y: isSelected ? 6 : 3
            )
    }

    private var borderShapeStyle: AnyShapeStyle {
        if reduceTransparency {
            if isSelected {
                return AnyShapeStyle(tint)
            }
            return AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.20))
        }
        if isSelected {
            return AnyShapeStyle(selectedBorder)
        }
        return AnyShapeStyle(specularBorder)
    }

    private var shadowColor: Color {
        if reduceTransparency {
            return .clear
        }
        if isSelected {
            return tint.opacity(colorScheme == .dark ? 0.28 : 0.16)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04)
    }

    private var specularBorder: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    tint.opacity(0.20),
                    Color.white.opacity(0.04),
                    Color.white.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.70),
                    tint.opacity(0.22),
                    Color.white.opacity(0.15),
                    Color.black.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var selectedBorder: LinearGradient {
        LinearGradient(
            colors: [tint, MobileKeptoraDesign.violet, tint.opacity(0.60)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    /// Applies a refined frosted-glass surface with specular rim lighting, ambient shadow, and accessibility fallback.
    func keptoraMobileGlass(
        cornerRadius: CGFloat = MobileKeptoraDesign.cardRadius,
        tint: Color = MobileKeptoraDesign.accent,
        isSelected: Bool = false
    ) -> some View {
        modifier(MobileGlassModifier(cornerRadius: cornerRadius, tint: tint, isSelected: isSelected))
    }
}

// MARK: – Action Buttons

/// Size the label itself so padding belongs to the interactive area, including in List rows.
struct MobileActionButtonStyle: ButtonStyle {
    var fillsWidth = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let tint = configuration.role == .destructive ? MobileKeptoraDesign.danger : MobileKeptoraDesign.accent
        return configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: MobileKeptoraDesign.minimumTouchTarget,
                   maxWidth: fillsWidth ? .infinity : nil,
                   minHeight: MobileKeptoraDesign.minimumTouchTarget)
            .background(
                tint.opacity(configuration.isPressed ? 0.18 : 0.09),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        reduceTransparency
                            ? AnyShapeStyle(tint.opacity(0.35))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.28 : 0.65),
                                        tint.opacity(0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            ),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : MobileKeptoraDesign.animFast, value: configuration.isPressed)
    }
}

/// Refined Frosted-Glass action button for secondary mobile actions.
struct MobileSleekActionButtonStyle: ButtonStyle {
    var fillsWidth = false
    var tint: Color = MobileKeptoraDesign.accent
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? tint : Color.secondary.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: MobileKeptoraDesign.minimumTouchTarget,
                   maxWidth: fillsWidth ? .infinity : nil,
                   minHeight: MobileKeptoraDesign.minimumTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.18 : 0.09))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        reduceTransparency
                            ? AnyShapeStyle(tint.opacity(0.40))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.32 : 0.70),
                                        tint.opacity(0.22)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            ),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : MobileKeptoraDesign.animFast, value: configuration.isPressed)
    }
}

struct MobilePrimaryButtonStyle: ButtonStyle {
    var fillsWidth = false
    var tint = MobileKeptoraDesign.accentFill
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(minWidth: MobileKeptoraDesign.minimumTouchTarget,
                   maxWidth: fillsWidth ? .infinity : nil,
                   minHeight: MobileKeptoraDesign.primaryButtonHeight)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        reduceTransparency
                            ? AnyShapeStyle(Color.white.opacity(0.60))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.40), Color.white.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            ),
                        lineWidth: 1
                    )
            }
            .shadow(color: reduceTransparency ? .clear : tint.opacity(isEnabled ? (configuration.isPressed ? 0.15 : 0.24) : 0), radius: 8, y: 3)
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .opacity(isEnabled ? (configuration.isPressed ? 0.92 : 1.0) : 0.45)
            .animation(reduceMotion ? nil : MobileKeptoraDesign.animFast, value: configuration.isPressed)
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
                .font(.system(.caption2, design: .rounded).weight(.bold))
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}


// MARK: – Panel Modifier

extension View {
    func keptoraPanel(tint: Color = MobileKeptoraDesign.accent) -> some View {
        padding(18)
            .keptoraMobileGlass(cornerRadius: 22, tint: tint)
    }
}

// MARK: – Glass List/Form Row Background

struct MobileGlassListRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var tint: Color? = nil

    var body: some View {
        if reduceTransparency {
            Color(uiColor: .secondarySystemGroupedBackground)
        } else {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(
                        colorScheme == .dark
                            ? Color.white.opacity(0.04)
                            : Color.white.opacity(0.48)
                    )
                if let tint {
                    Rectangle()
                        .fill(tint.opacity(0.08))
                }
            }
        }
    }
}

extension View {
    /// Applies a translucent frosted-glass material to List and Form rows with accessibility fallback.
    func mobileGlassRow(tint: Color? = nil) -> some View {
        listRowBackground(MobileGlassListRow(tint: tint))
    }
}
