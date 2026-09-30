import AppKit
import CoreGraphics
import SwiftUI

enum KeptoraDesign {
    // MARK: – Layout
    static let pagePadding: CGFloat = 28
    static let cardRadius: CGFloat = 20
    static let compactRadius: CGFloat = 12
    static let sidebarWidth: CGFloat = 230

    // MARK: – Semantic colours (adaptive)
    static let graphite = Color(nsColor: .labelColor)
    static let ink      = Color(nsColor: .textColor)

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
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.07, green: 0.12, blue: 0.33),
            Color(red: 0.23, green: 0.14, blue: 0.52),
            Color(red: 0.48, green: 0.16, blue: 0.45)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
    static let ticketIdle      = Color(nsColor: .controlBackgroundColor).opacity(0.52)
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
    static let animRoute  = Animation.easeInOut(duration: 0.20)

    // MARK: – Layout constants
    static let drawerWidth:  CGFloat = 320
    static let shellHeight:  CGFloat = 52
}

struct KeptoraBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                KeptoraDesign.canvas
                Circle()
                    .fill(KeptoraDesign.violet.opacity(0.13))
                    .frame(width: min(proxy.size.width * 0.62, 720))
                    .blur(radius: 95)
                    .offset(x: proxy.size.width * 0.30, y: -proxy.size.height * 0.35)
                Circle()
                    .fill(KeptoraDesign.cyan.opacity(0.10))
                    .frame(width: min(proxy.size.width * 0.52, 600))
                    .blur(radius: 110)
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
            .shadow(color: KeptoraDesign.violet.opacity(0.08), radius: 24, y: 10)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
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

// MARK: – Dynamic Brand Dock Icon

@MainActor
enum KeptoraBrandIcon {
    static func makeDockIcon(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        
        // Standard macOS dock squircle proportions (approx 82% of tile canvas)
        let margin = size * 0.09
        let squircleRect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
        let cornerRadius = squircleRect.width * 0.224
        
        // Drop shadow for dock presence
        ctx.saveGState()
        let shadowColor = NSColor(red: 0.20, green: 0.10, blue: 0.45, alpha: 0.35).cgColor
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.045, color: shadowColor)
        
        let path = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        
        // Main Aurora Brand Gradient
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            NSColor(red: 0.12, green: 0.72, blue: 0.94, alpha: 1.0).cgColor, // Cyan
            NSColor(red: 0.38, green: 0.32, blue: 0.98, alpha: 1.0).cgColor, // Royal Accent
            NSColor(red: 0.62, green: 0.28, blue: 0.96, alpha: 1.0).cgColor  // Violet
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.48, 1.0]
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: squircleRect.minX, y: squircleRect.maxY),
                end: CGPoint(x: squircleRect.maxX, y: squircleRect.minY),
                options: []
            )
        }
        
        // Soft top-left specular highlight
        let highlightColors = [
            NSColor.white.withAlphaComponent(0.24).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray
        if let highlightGrad = CGGradient(colorsSpace: colorSpace, colors: highlightColors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                highlightGrad,
                start: CGPoint(x: squircleRect.minX, y: squircleRect.maxY),
                end: CGPoint(x: squircleRect.midX, y: squircleRect.midY),
                options: []
            )
        }
        ctx.restoreGState()
        
        // Subtle border rim
        ctx.saveGState()
        let strokePath = CGPath(roundedRect: squircleRect.insetBy(dx: size * 0.003, dy: size * 0.003),
                                cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(strokePath)
        ctx.setLineWidth(size * (1.5 / 512.0))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.30).cgColor)
        ctx.strokePath()
        ctx.restoreGState()
        
        // Crisp "camera.filters" SF Symbol centered in pure white
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        if let symbolImage = NSImage(systemSymbolName: "camera.filters", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig) {
            
            let symbolSize = symbolImage.size
            let targetRect = CGRect(
                x: (size - symbolSize.width) / 2.0,
                y: (size - symbolSize.height) / 2.0 + (size * 0.005),
                width: symbolSize.width,
                height: symbolSize.height
            )
            
            ctx.saveGState()
            let symbolShadow = NSColor.black.withAlphaComponent(0.22).cgColor
            ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.02, color: symbolShadow)
            
            symbolImage.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            ctx.restoreGState()
        }
        
        image.unlockFocus()
        return image
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
}
