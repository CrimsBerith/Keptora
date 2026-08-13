import Foundation

enum CulloraFeatureFlags {
    static var similarityPipelineEnabled: Bool {
        if ProcessInfo.processInfo.environment["CULLORA_ENABLE_SIMILARITY"] == "1" { return true }
        if ProcessInfo.processInfo.environment["CULLORA_ENABLE_SIMILARITY"] == "0" { return false }
        if UserDefaults.standard.object(forKey: "Cullora.Feature.Similarity.v1") == nil { return true }
        return UserDefaults.standard.bool(forKey: "Cullora.Feature.Similarity.v1")
    }

    static var photoKitOriginalByteProbeEnabled: Bool {
        if ProcessInfo.processInfo.environment["CULLORA_ENABLE_PHOTOKIT_BYTES"] == "1" { return true }
        return UserDefaults.standard.bool(forKey: "Cullora.Feature.PhotoKitBytes.v1")
    }
}
