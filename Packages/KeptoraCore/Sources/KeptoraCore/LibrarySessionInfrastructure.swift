import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A review token includes filesystem identity and nanosecond change time. Size
/// and mtime alone cannot detect replacement or an edit that restores the mtime.
public struct LibraryFileRevision: Codable, Hashable, Sendable {
    public let physicalIdentity: String
    public let changeToken: String
    public let linkCount: UInt64
    public init(physicalIdentity: String, changeToken: String, linkCount: UInt64 = 1) {
        self.physicalIdentity = physicalIdentity; self.changeToken = changeToken; self.linkCount = linkCount
    }
    public static func capture(at url: URL) -> Self? {
        var status = stat()
        guard url.withUnsafeFileSystemRepresentation({ path in
            guard let path else { return false }
            return fstatat(AT_FDCWD, path, &status, 0) == 0
        }) else { return nil }
        #if canImport(Darwin)
        let changed = status.st_ctimespec
        #else
        let changed = status.st_ctim
        #endif
        return .init(physicalIdentity: LibraryFileIdentity.key(for: url),
                     changeToken: "\(changed.tv_sec):\(changed.tv_nsec):\(status.st_size)",
                     linkCount: UInt64(status.st_nlink))
    }
}

/// Captured once for a scan; changing preferences never changes an in-flight review.
public struct LibraryConfiguration: Codable, Hashable, Sendable {
    public enum Keeper: String, Codable, Sendable { case preserve, oldest, newest, largest, shortestPath }
    public var version = 1
    public var similarityEnabled: Bool
    public var sensitivity: String
    public var keeper: Keeper
    public var excludedFolders: Set<String>
    public var excludedExtensions: Set<String>
    public var checkpointInterval: Int
    public init(similarityEnabled: Bool = true, sensitivity: String = "precisionFirst", keeper: Keeper = .preserve,
                excludedFolders: Set<String> = [], excludedExtensions: Set<String> = [], checkpointInterval: Int = 100) {
        self.similarityEnabled = similarityEnabled; self.sensitivity = sensitivity; self.keeper = keeper
        self.excludedFolders = Set(excludedFolders.map { $0.lowercased() })
        self.excludedExtensions = Set(excludedExtensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) })
        self.checkpointInterval = max(25, min(500, checkpointInterval))
    }
    public static func stored(in defaults: UserDefaults = .standard) -> Self {
        func list(_ key: String) -> Set<String> {
            Set((defaults.string(forKey: key) ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        }
        return .init(similarityEnabled: defaults.object(forKey: "Keptora.Feature.Similarity.v1") == nil || defaults.bool(forKey: "Keptora.Feature.Similarity.v1"),
                     sensitivity: defaults.string(forKey: "Keptora.SimilaritySensitivity.v1") ?? "precisionFirst",
                     keeper: Keeper(rawValue: defaults.string(forKey: "Keptora.KeeperSelectionPolicy") ?? "") ?? .preserve,
                     excludedFolders: list("Keptora.ExcludedFolderNames"), excludedExtensions: list("Keptora.ExcludedExtensions"),
                     checkpointInterval: defaults.object(forKey: "Keptora.CheckpointInterval") == nil ? 100 : defaults.integer(forKey: "Keptora.CheckpointInterval"))
    }
    public var visualThreshold: Float { 0.30 * (sensitivity == "discovery" ? 1 : sensitivity == "balanced" ? 0.90 : 0.78) }
    public func excludesDirectory(_ name: String) -> Bool {
        [".keptora quarantine", ".git", "node_modules", "@eadir"].contains(name.lowercased()) || excludedFolders.contains(name.lowercased())
    }
    public func excludesExtension(_ name: String) -> Bool { excludedExtensions.contains(name.lowercased()) }
    public func keeperID(in assets: [UniversalMediaAsset], recommendedKeeperID: String? = nil, quality: [String: QualityAssessment] = [:]) -> String? {
        assets.sorted { lhs, rhs in
            let a = UniversalKeeperPolicy.qualityScore(for: lhs), b = UniversalKeeperPolicy.qualityScore(for: rhs)
            if a != b { return a > b }
            switch keeper {
            case .oldest, .newest:
                let l = lhs.creationDate ?? lhs.modificationDate ?? .distantPast, r = rhs.creationDate ?? rhs.modificationDate ?? .distantPast
                if l != r { return keeper == .oldest ? l < r : l > r }
            case .largest:
                if lhs.byteCount != rhs.byteCount { return (lhs.byteCount ?? 0) > (rhs.byteCount ?? 0) }
            case .shortestPath:
                func length(_ a: UniversalMediaAsset) -> Int { if case .file(let url) = a.reference { return url.path.count }; return a.displayName.count }
                if length(lhs) != length(rhs) { return length(lhs) < length(rhs) }
            case .preserve:
                if let l = quality[lhs.id]?.score, let r = quality[rhs.id]?.score, l != r { return l > r }
                if let recommendedKeeperID, lhs.id == recommendedKeeperID || rhs.id == recommendedKeeperID { return lhs.id == recommendedKeeperID }
            }
            return UniversalKeeperPolicy.prefersAsKeeper(lhs, rhs)
        }.first?.id
    }
}

/// Volume + file identity survives moves and prevents reuse of a mount path by another disk.
public enum LibraryFileIdentity {
    public static func volumeKey(for url: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.standardizedFileURL.resolvingSymlinksInPath().path)
        return "volume:" + ((attributes?[.systemNumber] as? NSNumber)?.stringValue ?? url.path)
    }
    /// Hard links are separate directory entries, but share a physical revision.
    /// Ordinary files retain the move-stable inode identity used by older sessions.
    public static func assetID(for url: URL) -> String {
        let physical = key(for: url)
        guard (LibraryFileRevision.capture(at: url)?.linkCount ?? 1) > 1 else { return "file:" + physical }
        let entry = key(for: url.deletingLastPathComponent()) + ":" + url.lastPathComponent
        return "file:" + physical + ":entry:" + StableDigest.fnv1a64(entry)
    }
    public static func key(for url: URL) -> String {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        let attributes = try? FileManager.default.attributesOfItem(atPath: canonical.path)
        if let device = attributes?[.systemNumber] as? NSNumber, let inode = attributes?[.systemFileNumber] as? NSNumber {
            #if os(macOS) || os(iOS)
            let volume = (try? canonical.resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString ?? device.stringValue
            #else
            let volume = device.stringValue
            #endif
            return StableDigest.fnv1a64(volume + ":" + inode.stringValue)
        }
        // Providers without persistent IDs retain path identity; reconnect/review is required after a move.
        return StableDigest.fnv1a64(canonical.path)
    }
    public static func relativePath(_ url: URL, root: URL) -> String? {
        guard let location = resolvedLocation(url), let source = resolvedLocation(root) else { return nil }
        let prefix = source.path == "/" ? "/" : source.path + "/"
        guard location.path.hasPrefix(prefix) else { return nil }
        let relative = String(location.path.dropFirst(prefix.count))
        guard !relative.split(separator: "/").contains("..") else { return nil }
        return relative
    }
    /// Foundation may leave a missing leaf unresolved on macOS. Resolve the
    /// nearest existing ancestor, then append absent components; also follow
    /// dangling aliases so a recorded root can be rebased after its move.
    private static func resolvedLocation(_ url: URL) -> URL? {
        let files = FileManager.default
        var cursor = url.standardizedFileURL
        var suffix: [String] = []
        var visited: Set<String> = []
        while !files.fileExists(atPath: cursor.path) && cursor.path != "/" {
            guard visited.insert(cursor.path).inserted else { return nil }
            if let target = try? files.destinationOfSymbolicLink(atPath: cursor.path) {
                cursor = (target.hasPrefix("/") ? URL(fileURLWithPath: target) :
                    cursor.deletingLastPathComponent().appendingPathComponent(target)).standardizedFileURL
            } else {
                suffix.append(cursor.lastPathComponent); cursor = cursor.deletingLastPathComponent()
            }
        }
        var result = cursor.resolvingSymlinksInPath()
        for component in suffix.reversed() { result.appendPathComponent(component) }
        return result.standardizedFileURL
    }
}

/// Cooperative pause retains the running passes and their progress, rather than starting over.
public actor LibraryAnalysisControl {
    private var paused = false
    private var commandSequence = -1
    public init() {}
    public func setPaused(_ value: Bool, sequence: Int? = nil) {
        if let sequence {
            guard sequence > commandSequence else { return }
            commandSequence = sequence
        }
        paused = value
    }
    public func waitIfPaused() async throws {
        while paused { try Task.checkCancellation(); try await Task.sleep(nanoseconds: 100_000_000) }
        try Task.checkCancellation()
    }
}

public struct LibraryRepositoryLoad<Value: Sendable>: Sendable {
    public let value: Value?
    public let recoveredBackup: Bool
}

/// One versioned document for user state; cache failures are kept separate from user decisions.
public actor LibraryRepository<Value: Codable & Sendable> {
    private struct Envelope: Codable { let version: Int; let sequence: Int; let value: Value }
    private let url: URL
    private var sequence = -1
    public init(url: URL) { self.url = url }
    public func load() throws -> LibraryRepositoryLoad<Value> {
        let backup = url.appendingPathExtension("backup")
        for (candidate, recovered) in [(url, false), (backup, true)] {
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            do {
                let document = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: candidate))
                guard document.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                sequence = document.sequence
                return .init(value: document.value, recoveredBackup: recovered)
            } catch { if recovered || !FileManager.default.fileExists(atPath: backup.path) { throw error } }
        }
        return .init(value: nil, recoveredBackup: false)
    }
    public func save(_ value: Value, sequence next: Int) throws {
        guard next > sequence else { return }
        let data = try JSONEncoder().encode(Envelope(version: 1, sequence: next, value: value))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Only a valid primary becomes a backup, so corruption never overwrites the last good copy.
        if let previous = try? Data(contentsOf: url), (try? JSONDecoder().decode(Envelope.self, from: previous)) != nil {
            try previous.write(to: url.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: url, options: .atomic); sequence = next
    }
    public func nextSequence() -> Int { sequence + 1 }
    public func preserveUnreadableFiles() throws {
        for candidate in [url, url.appendingPathExtension("backup")] where FileManager.default.fileExists(atPath: candidate.path) {
            let preserved = candidate.appendingPathExtension("unreadable-" + UUID().uuidString)
            try Data(contentsOf: candidate).write(to: preserved, options: .atomic)
        }
        sequence = -1
    }
}

public struct FolderQuarantineOperation: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let originalURL: URL
    public let quarantineURL: URL
    public let expectedDigest: String
    public var state: RecoveryOperationState?
    public var byteCount: Int64?
    public var needsAttention: Bool?

    public init(id: UUID = UUID(), originalURL: URL, quarantineURL: URL, expectedDigest: String) {
        self.id = id
        self.originalURL = originalURL
        self.quarantineURL = quarantineURL
        self.expectedDigest = expectedDigest
        self.state = .planned
    }
}

public struct FolderQuarantineRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let sourceRoot: URL
    public var operations: [FolderQuarantineOperation]
    public var restoredAt: Date?
    public var sourceIdentity: String?
    public var movedCount: Int { operations.filter { $0.state == .moved }.count }
    public var unresolvedCount: Int { operations.filter { $0.state == nil || $0.state == .planned || $0.state == .interrupted || $0.state == .failed || $0.needsAttention == true }.count }
    public var recoveryBytes: Int64 { operations.filter { $0.state == .moved }.reduce(0) { $0 + ($1.byteCount ?? 0) } }

    public init(id: UUID = UUID(), createdAt: Date = Date(), sourceRoot: URL, operations: [FolderQuarantineOperation], restoredAt: Date? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.sourceRoot = sourceRoot
        self.operations = operations
        self.restoredAt = restoredAt
        self.sourceIdentity = LibraryFileIdentity.key(for: sourceRoot)
    }
}

public enum RecoveryOperationState: String, Codable, Sendable { case planned, moved, restored, failed, interrupted }

public struct FolderRecoveryIssue: Identifiable, Hashable, Sendable {
    public var id: String { manifestURL.path }
    public let manifestURL: URL
    public let message: String
    public init(manifestURL: URL, message: String) { self.manifestURL = manifestURL; self.message = message }
}
public struct FolderRecoveryCatalogue: Sendable {
    public let records: [FolderQuarantineRecord]
    public let issues: [FolderRecoveryIssue]
    public init(records: [FolderQuarantineRecord], issues: [FolderRecoveryIssue]) { self.records = records; self.issues = issues }
}
public struct FolderCleanupFailure: LocalizedError, Sendable {
    public let record: FolderQuarantineRecord
    public let message: String
    public var errorDescription: String? { message }
    public init(record: FolderQuarantineRecord, message: String) { self.record = record; self.message = message }
}

/// Both Mac workflows share this owner. Reads may overlap; a writer exclusively
/// owns each physical volume (including parent/child folder connections).
@MainActor public final class LibraryOperationCoordinator {
    public enum Mode: Sendable { case read, write }
    public struct Lease: Sendable { public let id: UUID; public let resources: Set<String>; public let mode: Mode }
    private var leases: [UUID: Lease] = [:]
    private var observers: [UUID: @MainActor () -> Void] = [:]
    public private(set) var isTerminating = false
    public init() {}
    public func observe(_ change: @escaping @MainActor () -> Void) -> UUID { let id = UUID(); observers[id] = change; return id }
    public func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
    public func canAcquire(_ resources: Set<String>, mode: Mode) -> Bool {
        !isTerminating && !leases.values.contains { lease in
            !lease.resources.isDisjoint(with: resources) && (mode == .write || lease.mode == .write)
        }
    }
    public func acquire(_ resources: Set<String>, mode: Mode) -> Lease? {
        guard canAcquire(resources, mode: mode) else { return nil }
        let lease = Lease(id: UUID(), resources: resources, mode: mode); leases[lease.id] = lease; changed(); return lease
    }
    public func release(_ lease: Lease) { leases.removeValue(forKey: lease.id); changed() }
    public func beginTermination() { isTerminating = true; changed() }
    public func resumeAfterCancelledTermination() { isTerminating = false; changed() }
    public func waitForIdle() async { while !leases.isEmpty { try? await Task.sleep(nanoseconds: 50_000_000) } }
    private func changed() { for observer in observers.values { observer() } }
}

public struct LibraryCleanupOutcome: Sendable {
    public let requestedIDs: Set<String>
    public let completedIDs: Set<String>
    public let failedIDs: Set<String>
    public var notAttemptedIDs: Set<String> { requestedIDs.subtracting(completedIDs).subtracting(failedIDs) }
    public var isComplete: Bool { !requestedIDs.isEmpty && completedIDs == requestedIDs }
    public init(requestedIDs: Set<String>, completedIDs: Set<String> = [], failedIDs: Set<String> = []) {
        self.requestedIDs = requestedIDs; self.completedIDs = completedIDs; self.failedIDs = failedIDs
    }
}

public extension FolderQuarantineRecord {
    func rebased(to root: URL) throws -> FolderQuarantineRecord {
        guard sourceIdentity == nil || sourceIdentity == LibraryFileIdentity.key(for: root) else { throw UnifiedLibraryError.sourceUnavailable(root.lastPathComponent) }
        var result = FolderQuarantineRecord(id: id, createdAt: createdAt, sourceRoot: root, operations: [], restoredAt: restoredAt)
        result.operations = try operations.map { old in
            guard let original = LibraryFileIdentity.relativePath(old.originalURL, root: sourceRoot),
                  let recovery = LibraryFileIdentity.relativePath(old.quarantineURL, root: sourceRoot),
                  recovery.hasPrefix(".Keptora Quarantine/" + id.uuidString + "/") else { throw UnifiedLibraryError.selectionChanged }
            var op = FolderQuarantineOperation(id: old.id, originalURL: root.appendingPathComponent(original), quarantineURL: root.appendingPathComponent(recovery), expectedDigest: old.expectedDigest)
            op.state = old.state; op.byteCount = old.byteCount; op.needsAttention = old.needsAttention
            return op
        }
        return result
    }
}

public enum LibraryFileFamilies {
    /// Same capture basename: editing sidecars, RAW/JPEG and Live Photo motion components.
    /// Warnings never silently expand a manual deletion to unseen files.
    public static func omittedCompanions(for assets: [UniversalMediaAsset]) -> [URL] {
        let selected = Set(assets.compactMap { asset -> URL? in if case .file(let url) = asset.reference { return url.standardizedFileURL }; return nil })
        let extensions: Set<String> = ["jpg", "jpeg", "heic", "heif", "dng", "raw", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "mov", "mp4", "xmp", "aae"]
        var omitted: Set<URL> = []
        for url in selected where extensions.contains(url.pathExtension.lowercased()) {
            let base = url.deletingPathExtension().lastPathComponent.lowercased()
            let siblings = (try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: [.isRegularFileKey])) ?? []
            for sibling in siblings where extensions.contains(sibling.pathExtension.lowercased()) && sibling.deletingPathExtension().lastPathComponent.lowercased() == base {
                if !selected.contains(sibling.standardizedFileURL), (try? sibling.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true { omitted.insert(sibling) }
            }
        }
        return omitted.sorted { $0.path < $1.path }
    }
}

public enum LibraryRangeSelection {
    public static func items(from anchor: String, through target: String, in ordered: [UniversalMediaAsset]) -> [UniversalMediaAsset] {
        guard let a = ordered.firstIndex(where: { $0.id == anchor }), let b = ordered.firstIndex(where: { $0.id == target }) else { return [] }
        return Array(ordered[min(a, b)...max(a, b)])
    }
}

public struct LibrarySelectionUndoSession: Sendable {
    public struct Snapshot: Sendable { public let ids: Set<String>; public let decisions: LibraryReviewDecisions }
    private var past: [Snapshot] = []
    private var future: [Snapshot] = []
    private let limit: Int
    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    public init(limit: Int = 50) { self.limit = max(1, limit) }
    public mutating func capture(ids: Set<String>, decisions: LibraryReviewDecisions) {
        past.append(.init(ids: ids, decisions: decisions)); future.removeAll()
        if past.count > limit { past.removeFirst(past.count - limit) }
    }
    public mutating func undo(available: Set<String>, currentIDs: Set<String>? = nil, decisions: LibraryReviewDecisions = .init()) -> Snapshot? {
        guard let previous = past.popLast() else { return nil }
        if let currentIDs { future.append(.init(ids: currentIDs, decisions: decisions)) }
        return .init(ids: previous.ids.intersection(available), decisions: previous.decisions)
    }
    public mutating func redo(available: Set<String>, currentIDs: Set<String>, decisions: LibraryReviewDecisions) -> Snapshot? {
        guard let next = future.popLast() else { return nil }
        past.append(.init(ids: currentIDs, decisions: decisions))
        return .init(ids: next.ids.intersection(available), decisions: next.decisions)
    }
    public mutating func reset() { past.removeAll(); future.removeAll() }
}

public enum LibraryCatalogueReconciliation {
    public static func unchangedIDs(current: [UniversalMediaAsset], previous: [UniversalMediaAsset]) -> Set<String> {
        let oldItems = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return Set(current.filter { item in
            guard let old = oldItems[item.id] else { return false }
            // A refreshed route or an unknown Photos byte count does not change content.
            let refreshed = item.with(byteCount: .some(item.byteCount ?? old.byteCount))
            let prior = old.with(sourceID: item.sourceID, reference: item.reference, displayName: item.displayName, requiresNetwork: item.requiresNetwork)
            return refreshed == prior
        }.map(\.id))
    }
}

public actor LibraryCleanupPreflight {
    private let validate: @Sendable ([UniversalMediaAsset]) throws -> Void
    public init(validate: @escaping @Sendable ([UniversalMediaAsset]) throws -> Void = { try LibraryRevisionValidator.validate($0) }) { self.validate = validate }
    public func prepare(_ assets: [UniversalMediaAsset], adapter: any SourceAdapter, reviewedFingerprints: [String: UniversalExactFingerprint] = [:]) async throws -> [(asset: UniversalMediaAsset, expectedDigest: String)] {
        var result: [(asset: UniversalMediaAsset, expectedDigest: String)] = []
        for asset in assets {
            try Task.checkCancellation(); try validate([asset])
            let hash = try await adapter.exactFingerprint(for: asset, allowNetwork: false, progress: { _ in })
            try validate([asset])
            if let reviewed = reviewedFingerprints[asset.id], hash != reviewed { throw UnifiedLibraryError.selectionChanged }
            result.append((asset, hash.digest))
        }
        try validate(assets)
        return result
    }
}
