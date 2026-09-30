import Foundation
import KeptoraCore

enum KeptoraFeatureFlags {
    static var similarityPipelineEnabled: Bool {
        if ProcessInfo.processInfo.environment["KEPTORA_ENABLE_SIMILARITY"] == "1" { return true }
        if ProcessInfo.processInfo.environment["KEPTORA_ENABLE_SIMILARITY"] == "0" { return false }
        if UserDefaults.standard.object(forKey: AppStorageKeys.featureSimilarity) == nil { return true }
        return UserDefaults.standard.bool(forKey: AppStorageKeys.featureSimilarity)
    }
}

