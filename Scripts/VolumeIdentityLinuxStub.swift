#if os(Linux)
import Foundation

struct VolumeIdentity: Hashable, Codable, Sendable {
    let stableID: String
    let uuid: String?
    let name: String
    let rootPath: String
    let isRemovable: Bool
    let isLocal: Bool

    init(
        stableID: String,
        rootPath: String,
        uuid: String? = nil,
        name: String = "Linux Test Volume",
        isRemovable: Bool = false,
        isLocal: Bool = true
    ) {
        self.stableID = stableID
        self.uuid = uuid
        self.name = name
        self.rootPath = rootPath
        self.isRemovable = isRemovable
        self.isLocal = isLocal
    }

    static func resolve(for url: URL) throws -> VolumeIdentity {
        // Linux CI has no reliable Foundation volume UUID parity with macOS.
        // Keep every path in the fixture on the same deterministic test volume.
        VolumeIdentity(stableID: "linux-test-volume", rootPath: "/")
    }

    func matches(_ other: VolumeIdentity) -> Bool {
        stableID == other.stableID
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
#endif
