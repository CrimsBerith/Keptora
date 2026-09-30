import Foundation
import KeptoraCore

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
        return SourceID(rawValue: "folder-path-v2:" + StableDigest.fnv1a64(standardized.path))
    }

    static func folderID(for url: URL, volume: VolumeIdentity) -> SourceID {
        let standardized = url.standardizedFileURL
        let relativePath = pathRelativeToVolume(standardized.path, volumeRoot: volume.rootPath)
        return SourceID(rawValue: "folder-volume-v2:" + StableDigest.fnv1a64(volume.stableID + "|" + relativePath))
    }

    private static func pathRelativeToVolume(_ path: String, volumeRoot: String) -> String {
        let standardizedRoot = URL(fileURLWithPath: volumeRoot).standardizedFileURL.path
        if path == standardizedRoot { return "/" }
        let prefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"
        guard path.hasPrefix(prefix) else { return path }
        return String(path.dropFirst(prefix.count))
    }
}
