import Foundation

struct AssetID: Hashable, Codable, Sendable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
}

struct SourceID: Hashable, Codable, Sendable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
}

enum MediaKind: String, Codable, Sendable {
    case image
    case video
    case sidecar
    case unknown
}

struct AssetDescriptor: Hashable, Codable, Sendable, Identifiable {
    let id: AssetID
    let sourceID: SourceID
    let stableKey: String
    let displayName: String
    let fileURL: URL
    let mediaKind: MediaKind
    let byteCount: Int64
    let pixelWidth: Int?
    let pixelHeight: Int?
    let creationDate: Date?
    let modificationDate: Date?
}

enum SourceIdentity {
    static func folderID(for url: URL) -> SourceID {
        let standardized = url.standardizedFileURL
        if let volume = try? VolumeIdentity.resolve(for: standardized) {
            return folderID(for: standardized, volume: volume)
        }
        return SourceID(rawValue: "folder-path-v2:" + stableDigest(standardized.path))
    }

    static func folderID(for url: URL, volume: VolumeIdentity) -> SourceID {
        let standardized = url.standardizedFileURL
        let relativePath = pathRelativeToVolume(standardized.path, volumeRoot: volume.rootPath)
        return SourceID(rawValue: "folder-volume-v2:" + stableDigest(volume.stableID + "|" + relativePath))
    }

    private static func pathRelativeToVolume(_ path: String, volumeRoot: String) -> String {
        let standardizedRoot = URL(fileURLWithPath: volumeRoot).standardizedFileURL.path
        if path == standardizedRoot { return "/" }
        let prefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"
        guard path.hasPrefix(prefix) else { return path }
        return String(path.dropFirst(prefix.count))
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
