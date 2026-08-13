import SwiftUI

enum SidebarRoute: String, CaseIterable, Identifiable, Hashable {
    case home
    case review
    case insights
    case history
    case diagnostics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:        return "Home"
        case .review:      return "Duplicates"
        case .insights:    return "Insights"
        case .history:     return "History"
        case .diagnostics: return "Support"
        case .settings:    return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:        return "house.fill"
        case .review:      return "square.on.square.fill"
        case .insights:    return "chart.bar.xaxis"
        case .history:     return "clock.arrow.circlepath"
        case .diagnostics: return "questionmark.circle"
        case .settings:    return "gearshape"
        }
    }
}
