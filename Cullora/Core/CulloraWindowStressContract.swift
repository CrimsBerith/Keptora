import Foundation

/// Layout policy for Archive Review Studio. It encodes only this product's silhouette;
/// it must not be reused as a shared visible shell by another portfolio app.
struct CulloraWindowStressContract: Sendable {
    enum Density: String, Sendable { case compact, standard, expansive }
    enum PrimaryRegion: String, Sendable { case reviewFloor }
    enum CompactBehavior: String, Sendable { case collapseTicketShelf }

    static let minimumUsableWidth: Double = 760
    static let compactBreakpoint: Double = 1020
    static let expansiveBreakpoint: Double = 1480
    static let minimumUsableHeight: Double = 620
    static let primaryRegion: PrimaryRegion = .reviewFloor
    static let compactBehavior: CompactBehavior = .collapseTicketShelf

    static func density(width: Double, height: Double) -> Density {
        guard width >= minimumUsableWidth, height >= minimumUsableHeight else { return .compact }
        if width < compactBreakpoint { return .compact }
        if width >= expansiveBreakpoint { return .expansive }
        return .standard
    }

    static func isSupported(width: Double, height: Double) -> Bool {
        width >= minimumUsableWidth && height >= minimumUsableHeight
    }
}
