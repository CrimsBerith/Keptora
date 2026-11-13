import Foundation
import KeptoraCore

struct VolumeIdentity: Hashable, Codable, Sendable {
    let stableID: String
    let uuid: String?
    let name: String
    let rootPath: String
    let isRemovable: Bool
    let isLocal: Bool

    static func resolve(for url: URL) throws -> VolumeIdentity {
        let keys: Set<URLResourceKey> = [
            .volumeUUIDStringKey,
            .volumeNameKey,
            .volumeURLKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey
        ]
        let values = try url.resourceValues(forKeys: keys)
        let volumeURL = values.volume ?? url
        let rootPath = volumeURL.standardizedFileURL.path
        let uuid = values.volumeUUIDString
        let fallback = StableDigest.fnv1a64(rootPath)
        return VolumeIdentity(
            stableID: uuid.map { "volume:\($0.lowercased())" } ?? "volume-path:\(fallback)",
            uuid: uuid,
            name: values.volumeName ?? volumeURL.lastPathComponent,
            rootPath: rootPath,
            isRemovable: values.volumeIsRemovable ?? false,
            isLocal: values.volumeIsLocal ?? true
        )
    }

    func matches(_ other: VolumeIdentity) -> Bool {
        stableID == other.stableID
    }
}
