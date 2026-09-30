import Foundation

extension Bundle {
    public var appVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
