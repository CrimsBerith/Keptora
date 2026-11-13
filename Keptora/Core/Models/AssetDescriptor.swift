import Foundation
import KeptoraCore

struct AssetID: Hashable, Codable, Sendable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
}

