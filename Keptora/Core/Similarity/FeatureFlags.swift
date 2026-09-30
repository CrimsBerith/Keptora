import Foundation

enum KeptoraFeatureFlags {
    static var similarityPipelineEnabled: Bool {
        if ProcessInfo.processInfo.environment["KEPTORA_ENABLE_SIMILARITY"] == "1" { return true }
        if ProcessInfo.processInfo.environment["KEPTORA_ENABLE_SIMILARITY"] == "0" { return false }
        if UserDefaults.standard.object(forKey: "Keptora.Feature.Similarity.v1") == nil { return true }
        return UserDefaults.standard.bool(forKey: "Keptora.Feature.Similarity.v1")
    }

    static var photoKitOriginalByteProbeEnabled: Bool {
        if ProcessInfo.processInfo.environment["KEPTORA_ENABLE_PHOTOKIT_BYTES"] == "1" { return true }
        return UserDefaults.standard.bool(forKey: "Keptora.Feature.PhotoKitBytes.v1")
    }
}
