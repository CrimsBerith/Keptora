import Foundation

enum AssetFamilyKind: String, Codable, Sendable {
    case rawBundle
    case livePhoto
    case sidecarBundle
    case burst
    case editedExport

    var localizedLabel: String {
        switch self {
        case .rawBundle: return String(localized: "RAW bundle")
        case .livePhoto: return String(localized: "Live Photo")
        case .sidecarBundle: return String(localized: "Sidecar bundle")
        case .burst: return String(localized: "Burst")
        case .editedExport: return String(localized: "Edited export")
        }
    }
}

enum AssetFamilyRole: String, Codable, Sendable {
    case primary
    case raw
    case rendered
    case motion
    case sidecar
    case burstMember
    case edited
    case exported

    var localizedLabel: String {
        switch self {
        case .primary: return String(localized: "Primary")
        case .raw: return String(localized: "RAW")
        case .rendered: return String(localized: "Rendered")
        case .motion: return String(localized: "Motion")
        case .sidecar: return String(localized: "Sidecar")
        case .burstMember: return String(localized: "Burst member")
        case .edited: return String(localized: "Edited")
        case .exported: return String(localized: "Exported")
        }
    }
}

enum FamilySafetyPolicy: String, Codable, Sendable {
    case allOrNothing
    case advisory
}

struct AssetFamilyMember: Hashable, Codable, Sendable {
    let assetID: AssetID
    let role: AssetFamilyRole
    let displayName: String
    let fileURL: URL
}

struct AssetFamily: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceID: SourceID
    let kind: AssetFamilyKind
    let policy: FamilySafetyPolicy
    let normalizedStem: String
    let directoryPath: String
    let members: [AssetFamilyMember]
}

struct AssetFamilySummary: Hashable, Codable, Sendable {
    let id: String
    let kind: AssetFamilyKind
    let policy: FamilySafetyPolicy
    let role: AssetFamilyRole
    let memberCount: Int
}

struct FamilySafetyIssue: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let familyID: String
    let kind: AssetFamilyKind
    let message: String
    let missingMembers: [String]
}

struct FamilyMembershipRecord: Hashable, Sendable {
    let familyID: String
    let kind: AssetFamilyKind
    let policy: FamilySafetyPolicy
    let assetID: AssetID
    let role: AssetFamilyRole
    let displayName: String
    let path: String
    let isMissing: Bool
    let isQuarantined: Bool
}
