import Foundation

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
        let fallback = stableDigest(rootPath)
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

    private static func stableDigest(_ value: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}

enum SourceAvailability: Hashable, Sendable {
    case noSource
    case available(VolumeIdentity)
    case disconnected(expected: VolumeIdentity?)
    case replaced(expected: VolumeIdentity, actual: VolumeIdentity)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .noSource: return "No source"
        case .available(let volume): return volume.isRemovable ? "External volume connected" : "Volume available"
        case .disconnected: return "Source volume disconnected"
        case .replaced: return "Different volume at saved path"
        }
    }
}
