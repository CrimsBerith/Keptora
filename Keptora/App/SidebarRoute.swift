import SwiftUI

enum SidebarRoute: String, CaseIterable, Identifiable, Hashable {
    case archive
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
        case .archive:      return "Library"
        case .home:         return "Advanced Folder Scan"
        case .review:       return "Folder Plan Review"
        case .smartBuckets: return "Worth Reviewing"
        case .insights:     return "Insights"
        case .history:      return "History"
        case .diagnostics:  return "Support"
        case .settings:     return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .archive:      return "photo.stack"
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
