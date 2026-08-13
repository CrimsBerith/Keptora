import SwiftUI

enum CulloraDesign {
    // MARK: – Layout
    static let pagePadding: CGFloat = 28
    static let cardRadius: CGFloat = 12
    static let compactRadius: CGFloat = 8
    static let sidebarWidth: CGFloat = 230

    // MARK: – Semantic colours (adaptive)
    static let graphite = Color(nsColor: .labelColor)
    static let ink      = Color(nsColor: .textColor)

    // Primary accent – vibrant indigo-blue
    static let accent   = Color(red: 0.14, green: 0.42, blue: 0.88)
    static let success  = Color(red: 0.15, green: 0.52, blue: 0.37)
    static let warning  = Color(red: 0.78, green: 0.42, blue: 0.12)
    static let danger   = Color(red: 0.82, green: 0.18, blue: 0.18)

    // MARK: – Derived / glow
    static let accentGlow       = accent.opacity(0.24)
    static let accentSubtle     = accent.opacity(0.10)
    static let accentBorder     = accent.opacity(0.18)

    // MARK: – Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.50, blue: 0.95),
                 Color(red: 0.10, green: 0.34, blue: 0.80)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let iconGradient = LinearGradient(
        colors: [Color(red: 0.24, green: 0.54, blue: 0.98),
                 Color(red: 0.08, green: 0.30, blue: 0.74)],
        startPoint: .top, endPoint: .bottom
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
    static let titleFont   = Font.system(size: 32, weight: .bold,     design: .rounded)
    static let sectionFont = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let labelFont   = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let bodyFont    = Font.system(.body,   design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)

    // MARK: – Animation presets
    static let animFast   = Animation.easeOut(duration: 0.16)
    static let animMedium = Animation.easeInOut(duration: 0.26)
    static let animSpring = Animation.spring(response: 0.38, dampingFraction: 0.72)
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
            .background(CulloraDesign.elevated, in: ArchivePlateShape(cut: 11))
            .overlay {
                ArchivePlateShape(cut: 11)
                    .strokeBorder(CulloraDesign.accentBorder)
            }
            .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CulloraDesign.accent)
                Text(value)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CulloraUnavailableView: View {
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
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            if let description {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
