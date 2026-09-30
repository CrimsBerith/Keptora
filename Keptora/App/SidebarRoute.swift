import SwiftUI

enum SidebarRoute: String, CaseIterable, Identifiable, Hashable {
    case home
    case review
    case smartBuckets
    case insights
    case history
    case diagnostics
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home:         return "Library"
        case .review:       return "Review"
        case .smartBuckets: return "Smart Categories"
        case .insights:     return "Insights"
        case .history:      return "History"
        case .diagnostics:  return "Support"
        case .settings:     return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:         return "house.fill"
        case .review:       return "square.on.square.fill"
        case .smartBuckets: return "sparkles.rectangle.stack.fill"
        case .insights:     return "chart.bar.xaxis"
        case .history:      return "clock.arrow.circlepath"
        case .diagnostics:  return "questionmark.circle"
        case .settings:     return "gearshape"
        }
    }
}
