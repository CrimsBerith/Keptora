import Foundation

public enum MediaAnalysisVersion {
    public static let exact = "exact-library-v3"
    public static let visual = "visual-fit-v3-vision1"
    public static let quality = "quality-luma-v3"
}
public struct AnalysisWorkMetrics: Codable, Sendable {
    public var decodedPreviews = 0
    public var featurePrintRequests = 0
    public var cacheHits = 0
    public var hashedOriginals = 0
    public init() {}
}

public enum AnalysisStage: String, Codable, CaseIterable, Sendable {
    case catalogue, exact, photos, videos
    public var titleKey: String {
        switch self {
        case .catalogue: return "Loading sources"
        case .exact: return "Checking exact copies"
        case .photos: return "Comparing photos and quality"
        case .videos: return "Comparing videos"
        }
    }
}

public enum AnalysisIssueReason: String, Codable, Sendable, CaseIterable {
    case downloadRequired, accessDenied, missing, unreadable, unsupported, cancelled, other
    public var titleKey: String {
        switch self {
        case .downloadRequired: return "Download required"
        case .accessDenied: return "Access unavailable"
        case .missing: return "Item unavailable"
        case .unreadable: return "Could not read this item"
        case .unsupported: return "Format could not be analyzed"
        case .cancelled: return "Analysis cancelled"
        case .other: return "Analysis could not finish"
        }
    }
}

public struct AnalysisIssue: Codable, Hashable, Sendable, Identifiable {
    public let assetID: String
    public let sourceID: String
    public let stage: AnalysisStage
    public let reason: AnalysisIssueReason
    public var id: String { stage.rawValue + ":" + assetID + ":" + reason.rawValue }
    public init(assetID: String, sourceID: String, stage: AnalysisStage, reason: AnalysisIssueReason) {
        self.assetID = assetID; self.sourceID = sourceID; self.stage = stage; self.reason = reason
    }
}

public struct AnalysisStageProgress: Equatable, Sendable {
    public enum Status: Sendable { case waiting, running, completed, partial, failed, cancelled }
    public var status: Status = .waiting
    public var processed = 0
    public var total = 0
    public init(status: Status = .waiting, processed: Int = 0, total: Int = 0) {
        self.status = status; self.processed = processed; self.total = total
    }
    public var isTerminal: Bool { [.completed, .partial, .failed, .cancelled].contains(status) }
}

public struct AnalysisSessionProgress: Sendable {
    public private(set) var stages: [AnalysisStage: AnalysisStageProgress] = [:]
    public init() { for stage in AnalysisStage.allCases { stages[stage] = .init() } }
    public mutating func update(_ stage: AnalysisStage, _ progress: AnalysisStageProgress) {
        guard stages[stage]?.isTerminal != true || progress.isTerminal else { return }
        stages[stage] = progress
    }
    public mutating func cancel() {
        for stage in AnalysisStage.allCases where stages[stage]?.isTerminal != true {
            stages[stage]?.status = .cancelled
        }
    }
    public var isFinished: Bool { AnalysisStage.allCases.allSatisfy { stages[$0]?.isTerminal == true } }
    public var isComplete: Bool { AnalysisStage.allCases.allSatisfy { stages[$0]?.status == .completed } }
}

/// Persistent evidence is usable only when the source exposes a meaningful revision.
public enum MediaRevisionPolicy {
    public static func key(for asset: UniversalMediaAsset, algorithm: String) -> String? {
        guard let modified = asset.modificationDate, modified.timeIntervalSince1970.isFinite else { return nil }
        switch asset.reference {
        case .file: guard let bytes = asset.byteCount, bytes >= 0 else { return nil }
        case .photoLibrary: break
        }
        // JSON keeps subsecond precision; include all resource/selection-relevant metadata.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var revision = asset.with(sourceID: "", requiresNetwork: false)
        // An overlapping root is a route, not a different content revision.
        if case .file(let url) = revision.reference {
            revision = revision.with(reference: .file(url.standardizedFileURL.resolvingSymlinksInPath()))
        }
        guard let data = try? encoder.encode(revision) else { return nil }
        return algorithm + ":" + data.base64EncodedString()
    }
    public static func same(_ lhs: UniversalMediaAsset, _ rhs: UniversalMediaAsset, algorithm: String) -> Bool {
        guard let a = key(for: lhs, algorithm: algorithm), let b = key(for: rhs, algorithm: algorithm) else { return false }
        return a == b
    }
}

public struct PendingLibrarySelection: Sendable {
    public let available: [UniversalMediaAsset]
    public let pending: [UniversalMediaAsset]
    public let unresolvedIDs: Set<String>
    public var ids: Set<String> { Set((available + pending).map(\.id)).union(unresolvedIDs) }
    public init(ids: Set<String>, current: [UniversalMediaAsset], previous: [UniversalMediaAsset], coverage: [LibrarySourceCoverage]) {
        let currentIDs = Set(current.map(\.id))
        available = current.filter { ids.contains($0.id) }
        unresolvedIDs = ids.subtracting(Set((current + previous).map(\.id)))
        pending = UnifiedLibraryAdapter.uniqueReferences(previous).filter { item in
            guard ids.contains(item.id), !currentIDs.contains(item.id) else { return false }
            let report = coverage.first { $0.id == item.sourceID }
            // Photos access and partial folder enumeration cannot prove deletion.
            if case .photoLibrary = item.reference { return true }
            return report == nil || report?.authorization != .authorized || report?.error != nil
        }
    }
}

public actor LibrarySelectionArchive {
    private let url: URL
    private var lastSequence = -1
    public init(name: String) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        url = base.appendingPathComponent("Keptora", isDirectory: true).appendingPathComponent(name + ".json")
    }
    public func load() -> [UniversalMediaAsset] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UniversalMediaAsset].self, from: data)) ?? []
    }
    public func save(_ assets: [UniversalMediaAsset], sequence: Int) throws {
        guard sequence > lastSequence else { return }
        let data = try JSONEncoder().encode(assets)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        lastSequence = sequence
    }
}

public enum LibraryFindingFilter: String, CaseIterable, Sendable, Identifiable {
    case all, copies, verySimilar, review
    public var id: String { rawValue }
    public var titleKey: String {
        switch self { case .all: return "All Items"; case .copies: return "Exact Copies"; case .verySimilar: return "Very Similar"; case .review: return "Worth Reviewing" }
    }
    public func ids(groups: [LibraryReviewGroup], quality: [String: QualityAssessment]) -> Set<String>? {
        switch self {
        case .all: return nil
        case .copies: return Set(groups.filter { $0.kind == .exact }.flatMap { $0.assets.map(\.id) })
        case .verySimilar: return Set(groups.filter { $0.kind == .verySimilar }.flatMap { $0.assets.map(\.id) })
        case .review: return Set(quality.filter { $0.value.needsReview }.keys).union(groups.filter { $0.kind == .similar }.flatMap { $0.assets.map(\.id) })
        }
    }
}

public struct LibraryReviewDecisions: Codable, Equatable, Sendable {
    private struct Choice: Codable, Equatable, Sendable { let keeperID: String; let revision: String }
    private var choices: [String: Choice] = [:]
    public private(set) var protectedIDs: Set<String> = []
    public init() {}
    private func revision(_ group: LibraryReviewGroup) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return StableDigest.fnv1a64((try? encoder.encode(group.assets.sorted { $0.id < $1.id }).base64EncodedString()) ?? "")
    }
    public func keeper(in group: LibraryReviewGroup) -> String {
        guard let choice = choices[group.id], choice.revision == revision(group), group.assets.contains(where: { $0.id == choice.keeperID }) else { return group.keeperID }
        return choice.keeperID
    }
    public mutating func keep(_ id: String, in group: LibraryReviewGroup) {
        guard group.assets.contains(where: { $0.id == id }) else { return }
        choices[group.id] = .init(keeperID: id, revision: revision(group))
    }
    public func keeperReason(in group: LibraryReviewGroup, quality: [String: QualityAssessment]) -> String {
        if let choice = choices[group.id], choice.revision == revision(group) { return "Chosen by You" }
        guard let item = group.assets.first(where: { $0.id == keeper(in: group) }) else { return "Suggested Keep" }
        if item.isFavorite { return "Favorite Kept" }
        if item.hasAdjustments { return "Edited Version Kept" }
        if group.kind == .exact { return "One Identical Copy Kept" }
        if quality[item.id]?.state == .evaluated { return "Suggested from Detail and Resolution" }
        return "Suggested from Available Media Information"
    }
    public mutating func protect(_ group: LibraryReviewGroup) { protectedIDs.formUnion(group.assets.map(\.id)) }
    public mutating func toggleProtection(_ id: String) {
        if !protectedIDs.insert(id).inserted { protectedIDs.remove(id) }
    }
    public func candidates(in group: LibraryReviewGroup, respecting groups: [LibraryReviewGroup] = []) -> [UniversalMediaAsset] {
        let keeperID = keeper(in: group)
        let chosenKeepers = Set(choices.values.map(\.keeperID))
        let relatedKeepers = Set(groups.map { keeper(in: $0) })
        return group.assets.filter { $0.id != keeperID && !chosenKeepers.contains($0.id) && !relatedKeepers.contains($0.id) && !$0.isProtectedFromGlobalSelection && !protectedIDs.contains($0.id) }
    }
    public func exactSuggestions(_ groups: [LibraryReviewGroup]) -> [UniversalMediaAsset] {
        let exact = groups.filter { $0.kind == .exact }
        // Keepers in other overlapping groups are protected too.
        let keepers = Set(groups.map { keeper(in: $0) })
        return UnifiedLibraryAdapter.uniqueReferences(exact.flatMap { candidates(in: $0) }).filter { !keepers.contains($0.id) }
    }
}

public struct LibraryReviewBlock: Identifiable, Sendable {
    public let id: String
    public let assets: [UniversalMediaAsset]
    public let groups: [LibraryReviewGroup]
    /// Build once per block rather than searching every group for every grid cell.
    public var groupsByAsset: [String: [LibraryReviewGroup]] {
        var membership: [String: [LibraryReviewGroup]] = [:]
        for group in groups { for asset in group.assets { membership[asset.id, default: []].append(group) } }
        return membership
    }
    public var titleKey: String {
        if id == "quality" { return "Worth Reviewing" }
        if id == "other" || id == "timeline" { return "All Items" }
        if groups.count == 1 { return groups[0].titleKey }
        return "Related Shots"
    }
    /// Connected blocks retain their actual relationships; they don't assert transitivity.
    public static func make(assets: [UniversalMediaAsset], groups: [LibraryReviewGroup], quality: [String: QualityAssessment], smart: Bool) -> [Self] {
        if !smart { return [.init(id: "timeline", assets: assets, groups: [])] }
        let lookup = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var parent: [String: String] = [:]
        func root(_ id: String) -> String {
            var cursor = id
            while let next = parent[cursor], next != cursor { cursor = next }
            var node = id
            while let next = parent[node], next != node { parent[node] = cursor; node = next }
            return cursor
        }
        for group in groups {
            let members = group.assets.map(\.id).filter { lookup[$0] != nil }
            guard let first = members.first else { continue }
            for id in members { if parent[id] == nil { parent[id] = id } }
            for id in members.dropFirst() {
                let a = root(first), b = root(id)
                if a != b { parent[max(a, b)] = min(a, b) }
            }
        }
        var buckets: [String: [UniversalMediaAsset]] = [:]
        for asset in assets where parent[asset.id] != nil { buckets[root(asset.id), default: []].append(asset) }
        var relationBuckets: [String: [LibraryReviewGroup]] = [:]
        for group in groups {
            if let id = group.assets.first(where: { lookup[$0.id] != nil })?.id {
                relationBuckets[root(id), default: []].append(group)
            }
        }
        var result = buckets.map { key, items in
            let relations = relationBuckets[key] ?? []
            let keepers = Set(relations.map(\.keeperID))
            return Self(id: "block:" + StableDigest.fnv1a64(items.map(\.id).sorted().joined(separator: "|")), assets: items.sorted {
                if keepers.contains($0.id) != keepers.contains($1.id) { return keepers.contains($0.id) }
                return $0.id < $1.id
            }, groups: relations)
        }.sorted {
            let a = $0.groups.map(\.priority).min() ?? 3, b = $1.groups.map(\.priority).min() ?? 3
            return a == b ? $0.id < $1.id : a < b
        }
        let singles = assets.filter { parent[$0.id] == nil }
        let review = singles.filter { quality[$0.id]?.needsReview == true }
        let remaining = singles.filter { quality[$0.id]?.needsReview != true }
        if !review.isEmpty { result.append(.init(id: "quality", assets: review, groups: [])) }
        if !remaining.isEmpty { result.append(.init(id: "other", assets: remaining, groups: [])) }
        return result
    }
}
