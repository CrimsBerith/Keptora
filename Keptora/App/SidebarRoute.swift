import SwiftUI
import KeptoraCore

enum SidebarRoute: String, CaseIterable, Identifiable, Hashable {
    case archive
    case exact
    case similar
    case bursts
    case screenshots
    case videos
    case review
    case history

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .archive: return "All Photos"
        case .exact: return "Exact Copies"
        case .similar: return "Similar Photos"
        case .bursts: return "Rapid Bursts"
        case .screenshots: return "Screenshots"
        case .videos: return "Large Videos"
        case .review: return "Needs Review"
        case .history: return "History"
        }
    }

    var localizedTitle: String {
        switch self {
        case .archive: return L10n.tr("All Photos")
        case .exact: return L10n.tr("Exact Copies")
        case .similar: return L10n.tr("Similar Photos")
        case .bursts: return L10n.tr("Rapid Bursts")
        case .screenshots: return L10n.tr("Screenshots")
        case .videos: return L10n.tr("Large Videos")
        case .review: return L10n.tr("Needs Review")
        case .history: return L10n.tr("History")
        }
    }

    var systemImage: String {
        switch self {
        case .archive: return "photo.stack"
        case .exact: return "square.2.layers.3d"
        case .similar: return "photo.on.rectangle.angled"
        case .bursts: return "square.stack.3d.down.right.fill"
        case .screenshots: return "viewfinder"
        case .videos: return "video"
        case .review: return "camera.metering.center.weighted"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

@MainActor
final class MacNavigation: ObservableObject {
    @Published var selectedRoute: SidebarRoute = .archive
}
