import AppKit
import CoreGraphics
import SwiftUI

enum KeptoraDesign {
    // MARK: – Layout
    static let pagePadding: CGFloat = 28
    static let cardRadius: CGFloat = 20
    static let compactRadius: CGFloat = 12

    // MARK: – Semantic colours (adaptive)
    // Keptora aurora palette
    static let accent   = Color(red: 0.34, green: 0.28, blue: 0.96)
    static let violet   = Color(red: 0.58, green: 0.25, blue: 0.94)
    static let cyan     = Color(red: 0.08, green: 0.67, blue: 0.88)
    static let coral    = Color(red: 0.98, green: 0.39, blue: 0.47)
    static let success  = Color(red: 0.08, green: 0.64, blue: 0.46)
    static let warning  = Color(red: 0.94, green: 0.58, blue: 0.12)
    static let danger   = Color(red: 0.92, green: 0.24, blue: 0.30)

    // MARK: – Derived / glow
    static let accentGlow       = violet.opacity(0.30)
    static let accentSubtle     = accent.opacity(0.12)
    static let accentBorder     = accent.opacity(0.20)

    // MARK: – Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.22, green: 0.46, blue: 0.98),
                 Color(red: 0.46, green: 0.24, blue: 0.95),
                 Color(red: 0.92, green: 0.27, blue: 0.56)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
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
    static let quiet           = Color(nsColor: .underPageBackgroundColor)
    static let ticketSelected  = accent.opacity(0.14)
    static let reviewFloor     = Color(nsColor: .underPageBackgroundColor).opacity(0.62)
    static let drawerSurface   = Color(nsColor: .windowBackgroundColor)

    // MARK: – Typography
    static let titleFont   = Font.system(size: 36, weight: .bold,     design: .rounded)
    static let sectionFont = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let labelFont   = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let bodyFont    = Font.system(.body,   design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)

    // MARK: – Animation presets
    static let animFast   = Animation.easeOut(duration: 0.16)
    static let animMedium = Animation.easeInOut(duration: 0.26)
    static let animSpring = Animation.spring(response: 0.38, dampingFraction: 0.72)

    // MARK: – Layout constants
    static let drawerWidth:  CGFloat = 320
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
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                KeptoraDesign.canvas
                KeptoraGlow(color: KeptoraDesign.violet.opacity(0.13), diameter: min(proxy.size.width * 0.62, 720))
                    .offset(x: proxy.size.width * 0.30, y: -proxy.size.height * 0.35)
                KeptoraGlow(color: KeptoraDesign.cyan.opacity(0.10), diameter: min(proxy.size.width * 0.52, 600))
                    .offset(x: -proxy.size.width * 0.34, y: proxy.size.height * 0.34)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct KeptoraSidebarBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                KeptoraDesign.accent.opacity(0.12),
                KeptoraDesign.violet.opacity(0.06),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .background(.bar)
        .ignoresSafeArea()
    }
}

// MARK: - Shapes

struct ArchivePlateShape: InsettableShape {
    var cut: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let c = min(cut, min(r.width, r.height) / 3)
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY + c))
        path.addLine(to: CGPoint(x: r.minX + c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - c * 0.55, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + c * 0.55))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + c * 0.55, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - c * 0.55))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> ArchivePlateShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - Reusable Components

struct PremiumCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: KeptoraDesign.cardRadius, style: .continuous))
            .background(KeptoraDesign.elevated.opacity(0.86), in: RoundedRectangle(cornerRadius: KeptoraDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KeptoraDesign.cardRadius, style: .continuous)
                    .stroke(KeptoraDesign.borderGradient, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }
}

struct MetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color

    init(title: LocalizedStringKey, value: String, systemImage: String, tint: Color = KeptoraDesign.accent) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.13))
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                }
                .frame(width: 44, height: 44)
                Text(value)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

struct KeptoraUnavailableView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey?
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        description: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(KeptoraDesign.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(KeptoraDesign.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)

                if let description {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct KeptoraSheetCloseButton: View {
    let accessibilityLabel: LocalizedStringKey
    let accessibilityIdentifier: String
    var isDisabled = false
    var disabledHint: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        ZStack {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.07), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help(isDisabled ? Text(disabledHint ?? "This screen cannot be closed until the operation finishes.") : Text("Close"))
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityIdentifier(accessibilityIdentifier)
            .accessibilityHint(isDisabled ? Text(disabledHint ?? "This screen cannot be closed until the operation finishes.") : Text("Returns to the previous screen."))

            Button(action: action) { EmptyView() }
                .keyboardShortcut("w", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .disabled(isDisabled)
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

// MARK: - Hover / pressed feedback

/// Plain button that lifts slightly on hover and dips when pressed (Reduce Motion aware).
struct KeptoraCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(isHovered && !configuration.isPressed ? 0.02 : 0)
            .shadow(color: .black.opacity(isHovered ? 0.10 : 0), radius: 8, y: 3)
            .animation(reduceMotion ? nil : KeptoraDesign.animFast, value: isHovered)
            .animation(reduceMotion ? nil : KeptoraDesign.animFast, value: configuration.isPressed)
            .onHover { isHovered = $0 }
            .contentShape(Rectangle())
    }
}
