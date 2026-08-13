import Foundation

enum AssetFamilyKind: String, Codable, Sendable {
    case rawBundle
    case livePhoto
    case sidecarBundle
    case burst
    case editedExport
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
