import Foundation

public enum AppStoreConfiguration {
    public static let fallbackLifetimeProductID = "com.keptora.app.pro.lifetime"
    public static let freeReviewLimit = 100

    public static var defaultLifetimeProductID: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APP_LIFETIME_PRODUCT_ID") as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return fallbackLifetimeProductID
    }

    public static var privacyPolicyURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APP_PRIVACY_POLICY_URL") as? String,
           let url = URL(string: configured),
           url.scheme == "https", !(url.host?.isEmpty ?? true) {
            return url
        }
        return URL(string: "https://alfagolab.com/keptora/privacy")!
    }

    public static var supportURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APP_SUPPORT_URL") as? String,
           let url = URL(string: configured),
           url.scheme == "https", !(url.host?.isEmpty ?? true) {
            return url
        }
        return URL(string: "https://alfagolab.com/keptora/support")!
    }

    public static var termsOfUseURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APP_TERMS_OF_USE_URL") as? String,
           let url = URL(string: configured),
           url.scheme == "https", !(url.host?.isEmpty ?? true) {
            return url
        }
        return URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }

    public static var marketingURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APP_MARKETING_URL") as? String,
           let url = URL(string: configured),
           url.scheme == "https", !(url.host?.isEmpty ?? true) {
            return url
        }
        return URL(string: "https://alfagolab.com/keptora")!
    }
}
