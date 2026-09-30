import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case turkish = "tr"
    case german = "de"
    case french = "fr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return String(localized: "System Default")
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .german: return "Deutsch"
        case .french: return "Français"
        }
    }

    public var locale: Locale? {
        switch self {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .turkish: return Locale(identifier: "tr")
        case .german: return Locale(identifier: "de")
        case .french: return Locale(identifier: "fr")
        }
    }
}
