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

public enum L10n {
    public static var currentLanguage: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "Keptora.AppLanguage") ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    public static var currentLocale: Locale {
        currentLanguage.locale ?? .current
    }

    public static func tr(_ key: String.LocalizationValue, bundle: Bundle? = nil, comment: StaticString? = nil) -> String {
        String(localized: key, bundle: bundle ?? .main, locale: currentLocale, comment: comment)
    }

    public static func format(_ formatKey: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let template = String(localized: formatKey, bundle: .main, locale: currentLocale)
        return String(format: template, locale: currentLocale, arguments: arguments)
    }
}

