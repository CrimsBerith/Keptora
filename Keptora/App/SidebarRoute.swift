import SwiftUI

enum SidebarRoute: String, CaseIterable, Identifiable, Hashable {
    case archive
    case history

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .archive: return "Photo Library"
        case .history: return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .archive: return "photo.stack"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

@MainActor
final class MacNavigation: ObservableObject {
    @Published var selectedRoute: SidebarRoute = .archive
}
