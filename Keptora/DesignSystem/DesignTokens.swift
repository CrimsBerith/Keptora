import AppKit
import CoreGraphics
import SwiftUI

enum KeptoraDesign {
    // MARK: – Layout
    static let cardRadius: CGFloat = 20

    // MARK: – Semantic colours (adaptive)
    // Keptora aurora palette. Text, icon and tint colors have a light and a dark value, each at
    // least 4.5:1 against macOS window and control backgrounds (WCAG AA). Prominent buttons with
    // white labels use the fixed `…Fill` colors.
    static let accent   = adaptive(light: (0.29, 0.22, 0.86), dark: (0.74, 0.71, 1.00))
    static let accentFill = Color(red: 0.34, green: 0.28, blue: 0.96)
    static let violet   = Color(red: 0.58, green: 0.25, blue: 0.94)
    static let cyan     = Color(red: 0.08, green: 0.67, blue: 0.88)
    static let coral    = Color(red: 0.98, green: 0.39, blue: 0.47)
    static let success  = adaptive(light: (0.00, 0.42, 0.28), dark: (0.30, 0.85, 0.62))
    static let warning  = adaptive(light: (0.56, 0.30, 0.00), dark: (1.00, 0.72, 0.30))
    static let danger   = adaptive(light: (0.70, 0.06, 0.12), dark: (1.00, 0.64, 0.64))
    static let dangerFill = Color(red: 0.75, green: 0.08, blue: 0.14)
    static let secondaryInk = adaptive(light: (0.34, 0.34, 0.38), dark: (0.76, 0.76, 0.80))

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }

    // MARK: – Derived / glow
    static let accentGlow       = violet.opacity(0.30)

    // MARK: – Gradients
    static let iconGradient = LinearGradient(
        colors: [cyan, accent, violet],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let borderGradient = LinearGradient(
        colors: [Color.white.opacity(0.42), cyan.opacity(0.34), violet.opacity(0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: – Surface layers
    static let canvas          = Color(nsColor: .windowBackgroundColor)
    static let elevated        = Color(nsColor: .controlBackgroundColor)

    // MARK: – Typography
    static let titleFont   = Font.system(size: 36, weight: .bold,     design: .rounded)

    // MARK: – Animation presets
    static let animFast   = Animation.easeOut(duration: 0.16)
}

/// Soft glow used by the backdrops. A radial gradient looks like the old blurred circle but costs
/// no offscreen blur pass, which mattered when it sat behind every scrolling screen.
struct KeptoraGlow: View {
    let color: Color
    let diameter: CGFloat

    var body: some View {
        RadialGradient(
            colors: [color, color.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: diameter * 0.8
        )
        .frame(width: diameter * 1.6, height: diameter * 1.6)
    }
}

struct KeptoraBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                KeptoraDesign.canvas
                if !reduceTransparency {
                    LinearGradient(
                        colors: [
                            KeptoraDesign.accent.opacity(colorScheme == .dark ? 0.07 : 0.03),
                            Color.clear,
                            KeptoraDesign.cyan.opacity(colorScheme == .dark ? 0.05 : 0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    KeptoraGlow(color: KeptoraDesign.violet.opacity(colorScheme == .dark ? 0.18 : 0.12), diameter: min(proxy.size.width * 0.68, 760))
                        .offset(x: proxy.size.width * 0.32, y: -proxy.size.height * 0.35)
                    KeptoraGlow(color: KeptoraDesign.cyan.opacity(colorScheme == .dark ? 0.14 : 0.09), diameter: min(proxy.size.width * 0.56, 640))
                        .offset(x: -proxy.size.width * 0.35, y: proxy.size.height * 0.34)
                    KeptoraGlow(color: KeptoraDesign.coral.opacity(colorScheme == .dark ? 0.08 : 0.05), diameter: min(proxy.size.width * 0.45, 480))
                        .offset(x: proxy.size.width * 0.18, y: proxy.size.height * 0.12)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct KeptoraSidebarBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
                KeptoraDesign.elevated
            } else {
                LinearGradient(
                    colors: [
                        KeptoraDesign.accent.opacity(colorScheme == .dark ? 0.15 : 0.08),
                        KeptoraDesign.violet.opacity(colorScheme == .dark ? 0.09 : 0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .background(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Liquid Glass Design System (iOS 26 / macOS Liquid Glass)

enum GlassShape: Sendable, Equatable {
    case capsule
    case circle
    case rect(cornerRadius: CGFloat)
}

struct GlassStyle: Sendable, Equatable {
    var tintColor: Color?
    var isInteractive: Bool = false
    var isProminent: Bool = false

    init(tintColor: Color? = nil, isInteractive: Bool = false, isProminent: Bool = false) {
        self.tintColor = tintColor
        self.isInteractive = isInteractive
        self.isProminent = isProminent
    }

    static var regular: GlassStyle { GlassStyle() }
    static var prominent: GlassStyle { GlassStyle(isProminent: true) }

    func tint(_ color: Color) -> GlassStyle {
        var copy = self
        copy.tintColor = color
        return copy
    }

    func interactive(_ isInteractive: Bool = true) -> GlassStyle {
        var copy = self
        copy.isInteractive = isInteractive
        return copy
    }
}

struct GlassEffectContainer<Content: View>: View {
    var spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 16.0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        content
    }
}

struct GlassEffectModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var style: GlassStyle = .regular
    var shape: GlassShape = .capsule
    var isSelected: Bool = false
    @State private var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                glassBackground
            }
            .overlay {
                glassBorder
            }
            .shadow(
                color: shadowColor,
                radius: isSelected ? 16 : (isHovered ? 14 : 9),
                x: 0,
                y: isSelected ? 5 : (isHovered ? 4 : 2.5)
            )
            .scaleEffect(style.isInteractive && isHovered && !reduceMotion ? 1.015 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.72), value: isHovered)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.72), value: isSelected)
            #if os(macOS)
            .onHover { hovering in
                if style.isInteractive {
                    isHovered = hovering
                }
            }
            #endif
    }

    @ViewBuilder
    private var glassBackground: some View {
        switch shape {
        case .capsule:
            applyBackground(to: Capsule())
        case .circle:
            applyBackground(to: Circle())
        case .rect(let radius):
            applyBackground(to: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @ViewBuilder
    private func applyBackground<S: Shape>(to shape: S) -> some View {
        if reduceTransparency {
            shape.fill(isSelected ? (style.tintColor ?? KeptoraDesign.accent).opacity(0.18) : KeptoraDesign.elevated)
        } else {
            ZStack {
                shape.fill(.ultraThinMaterial)

                // Specular Light Diffusion Layer
                shape.fill(
                    LinearGradient(
                        colors: [
                            colorScheme == .dark
                                ? Color.white.opacity(isHovered ? 0.12 : (isSelected ? 0.09 : 0.04))
                                : Color.white.opacity(isHovered ? 0.65 : (isSelected ? 0.58 : 0.42)),
                            colorScheme == .dark
                                ? Color.white.opacity(0.01)
                                : Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // Fluid Chromatic Tint Layer
                if let tint = style.tintColor {
                    shape.fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(isSelected ? 0.22 : (style.isProminent ? 0.28 : (isHovered ? 0.15 : 0.07))),
                                tint.opacity(isSelected ? 0.08 : (isHovered ? 0.05 : 0.02))
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                } else if isSelected {
                    shape.fill(KeptoraDesign.accent.opacity(0.14))
                }
            }
        }
    }

    @ViewBuilder
    private var glassBorder: some View {
        switch shape {
        case .capsule:
            applyBorder(to: Capsule())
        case .circle:
            applyBorder(to: Circle())
        case .rect(let radius):
            applyBorder(to: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @ViewBuilder
    private func applyBorder<S: InsettableShape>(to shape: S) -> some View {
        shape.strokeBorder(
            borderShapeStyle,
            lineWidth: isSelected ? 1.5 : 1.0
        )
        .allowsHitTesting(false)
    }

    private var borderShapeStyle: AnyShapeStyle {
        if reduceTransparency {
            if isSelected {
                return AnyShapeStyle(style.tintColor ?? KeptoraDesign.accent)
            }
            return AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.20))
        }
        return AnyShapeStyle(specularGradient)
    }

    private var specularGradient: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    (style.tintColor ?? KeptoraDesign.accent).opacity(0.95),
                    KeptoraDesign.violet.opacity(0.78),
                    (style.tintColor ?? KeptoraDesign.cyan).opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(isHovered ? 0.45 : 0.30),
                    (style.tintColor ?? KeptoraDesign.cyan).opacity(isHovered ? 0.25 : 0.14),
                    Color.white.opacity(0.03),
                    Color.white.opacity(0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(isHovered ? 0.90 : 0.78),
                    (style.tintColor ?? KeptoraDesign.accent).opacity(isHovered ? 0.30 : 0.18),
                    Color.white.opacity(0.18),
                    Color.black.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        if reduceTransparency {
            return .clear
        }
        if isSelected {
            return (style.tintColor ?? KeptoraDesign.accent).opacity(colorScheme == .dark ? 0.30 : 0.18)
        }
        if let tint = style.tintColor, style.isProminent {
            return tint.opacity(colorScheme == .dark ? 0.25 : 0.15)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05)
    }
}

struct GlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var shape: GlassShape = .capsule
    var fillsWidth: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    init(tint: Color? = nil, shape: GlassShape = .capsule, fillsWidth: Bool = false) {
        self.tint = tint
        self.shape = shape
        self.fillsWidth = fillsWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .glassEffect(
                .regular.tint(tint ?? KeptoraDesign.accent).interactive(),
                in: shape
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct GlassProminentButtonStyle: ButtonStyle {
    var tint: Color = KeptoraDesign.accentFill
    var shape: GlassShape = .capsule
    var fillsWidth: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(tint: Color = KeptoraDesign.accentFill, shape: GlassShape = .capsule, fillsWidth: Bool = false) {
        self.tint = tint
        self.shape = shape
        self.fillsWidth = fillsWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background {
                prominentBackground(isPressed: configuration.isPressed)
            }
            .overlay {
                prominentBorder
            }
            .shadow(
                color: tint.opacity(colorScheme == .dark ? 0.40 : 0.25),
                radius: configuration.isPressed ? 8 : 12,
                y: configuration.isPressed ? 2 : 4
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.90 : 1.0) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }

    @ViewBuilder
    private func prominentBackground(isPressed: Bool) -> some View {
        switch shape {
        case .capsule:
            applyProminentBackground(to: Capsule(), isPressed: isPressed)
        case .circle:
            applyProminentBackground(to: Circle(), isPressed: isPressed)
        case .rect(let radius):
            applyProminentBackground(to: RoundedRectangle(cornerRadius: radius, style: .continuous), isPressed: isPressed)
        }
    }

    @ViewBuilder
    private func applyProminentBackground<S: Shape>(to shape: S, isPressed: Bool) -> some View {
        if reduceTransparency {
            shape.fill(tint)
        } else {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(isPressed ? 0.92 : 0.85),
                            tint.opacity(isPressed ? 0.80 : 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                // Specular sheen
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var prominentBorder: some View {
        switch shape {
        case .capsule:
            applyProminentBorder(to: Capsule())
        case .circle:
            applyProminentBorder(to: Circle())
        case .rect(let radius):
            applyProminentBorder(to: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @ViewBuilder
    private func applyProminentBorder<S: InsettableShape>(to shape: S) -> some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.60),
                    tint.opacity(0.30),
                    Color.white.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1.0
        )
        .allowsHitTesting(false)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    static func glass(tint: Color? = nil, shape: GlassShape = .capsule, fillsWidth: Bool = false) -> GlassButtonStyle {
        GlassButtonStyle(tint: tint, shape: shape, fillsWidth: fillsWidth)
    }
}

extension ButtonStyle where Self == GlassProminentButtonStyle {
    static var glassProminent: GlassProminentButtonStyle { GlassProminentButtonStyle() }
    static func glassProminent(tint: Color = KeptoraDesign.accentFill, shape: GlassShape = .capsule, fillsWidth: Bool = false) -> GlassProminentButtonStyle {
        GlassProminentButtonStyle(tint: tint, shape: shape, fillsWidth: fillsWidth)
    }
}

struct KeptoraGlassGroupBoxStyle: GroupBoxStyle {
    var tint: Color? = nil
    var cornerRadius: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .padding(14)
        .keptoraGlass(cornerRadius: cornerRadius, tint: tint)
    }
}

extension View {
    /// Applies Apple's Liquid Glass material effect with blur, specular rim reflection, and interactive response.
    func glassEffect(_ style: GlassStyle = .regular, in shape: GlassShape = .capsule) -> some View {
        modifier(GlassEffectModifier(style: style, shape: shape))
    }

    /// Applies a refined frosted-glass surface with specular rim lighting, ambient shadow, and accessibility fallback.
    func keptoraGlass(
        cornerRadius: CGFloat = KeptoraDesign.cardRadius,
        tint: Color? = nil,
        isSelected: Bool = false
    ) -> some View {
        var style = GlassStyle.regular
        if let tint { style = style.tint(tint) }
        return modifier(GlassEffectModifier(style: style, shape: .rect(cornerRadius: cornerRadius), isSelected: isSelected))
    }
}

// MARK: – Brand Logo Mark

/// Keptora logo. Two photo frames: the translucent one behind is the duplicate that is set aside,
/// the solid one in front with a check mark is the keeper. Mirrors AppStore/AppIcon/logo/*.svg
/// (geometry is expressed in the 1024-pt art space of those files).
struct KeptoraLogoMark: View {
    var size: CGFloat = 40
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
                        .allowsHitTesting(false)
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

            KeptoraCheckShape()
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
                .allowsHitTesting(false)
        }
        .shadow(color: KeptoraDesign.violet.opacity(showsShadow ? 0.32 : 0), radius: size * 0.20, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

private struct KeptoraCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 1024
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 520 * s, y: rect.minY + 616 * s))
        p.addLine(to: CGPoint(x: rect.minX + 584 * s, y: rect.minY + 680 * s))
        p.addLine(to: CGPoint(x: rect.minX + 694 * s, y: rect.minY + 548 * s))
        return p
    }
}

// MARK: - Motion (Reduce Motion aware)

private struct KeptoraAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Like `.animation(_:value:)`, but disabled when the user turned on Reduce Motion.
    func keptoraAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(KeptoraAnimationModifier(animation: animation, value: value))
    }

    /// Compatibility helper for `onChange(of:)` bridging macOS 13 and macOS 14+.
    @ViewBuilder
    func keptoraOnChange<V: Equatable>(of value: V, perform action: @escaping (_ newValue: V) -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }

    /// Compatibility helper for `onChange(of:)` with no parameter closure.
    @ViewBuilder
    func keptoraOnChange<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, _ in
                action()
            }
        } else {
            self.onChange(of: value) { _ in
                action()
            }
        }
    }
}
