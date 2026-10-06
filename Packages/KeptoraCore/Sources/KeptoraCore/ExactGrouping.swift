import CryptoKit
import Foundation

public enum UniversalScanError: LocalizedError, Sendable {
    case inaccessibleAsset(String)
    case networkRequired(String)
    case resourceUnavailable(String)
    case downloadCancelled(String)
    case sourcePermissionDenied
    case unsupportedReference
    case cleanupNotPermitted(String)

    public var errorDescription: String? {
        switch self {
        case .inaccessibleAsset(let name): return L10n.format("Keptora could not read %@.", name)
        case .networkRequired(let name): return L10n.format("%@ is stored in iCloud and requires an approved download.", name)
        case .resourceUnavailable(let name): return L10n.format("%@ is unavailable on this device or iCloud.", name)
        case .downloadCancelled(let name): return L10n.format("Download of %@ was cancelled.", name)
        case .sourcePermissionDenied: return L10n.tr("Keptora does not have permission to access this source.")
        case .unsupportedReference: return L10n.tr("This source reference is not supported.")
        case .cleanupNotPermitted(let reason): return L10n.tr(String.LocalizationValue(reason))
        }
    }
}

public extension AnalysisIssue {
    init(asset: UniversalMediaAsset, stage: AnalysisStage, error: Error) {
        let reason: AnalysisIssueReason
        switch error {
        case UniversalScanError.networkRequired: reason = .downloadRequired
        case UniversalScanError.sourcePermissionDenied: reason = .accessDenied
        case UniversalScanError.resourceUnavailable: reason = .missing
        case UniversalScanError.inaccessibleAsset: reason = .unreadable
        case UniversalScanError.unsupportedReference: reason = .unsupported
        case is CancellationError, UniversalScanError.downloadCancelled: reason = .cancelled
        case let value as CocoaError where value.code == .fileReadNoPermission: reason = .accessDenied
        case let value as CocoaError where value.code == .fileReadNoSuchFile: reason = .missing
        default: reason = .other
        }
        self.init(assetID: asset.id, sourceID: asset.sourceID, stage: stage, reason: reason)
    }
}

public struct UniversalScanCheckpoint: Hashable, Codable, Sendable {
    public struct Entry: Hashable, Codable, Sendable {
        public let sourceAsset: UniversalMediaAsset
        public let fingerprintedAsset: UniversalMediaAsset
        public let fingerprint: UniversalExactFingerprint

        public init(sourceAsset: UniversalMediaAsset, fingerprintedAsset: UniversalMediaAsset, fingerprint: UniversalExactFingerprint) {
            self.sourceAsset = sourceAsset
            self.fingerprintedAsset = fingerprintedAsset
            self.fingerprint = fingerprint
        }
    }

    public let sourceID: String
    public let allowNetwork: Bool
    public let entries: [Entry]
    public let algorithmVersion: String?

    public init(sourceID: String, allowNetwork: Bool, entries: [Entry]) {
        self.sourceID = sourceID
        self.allowNetwork = allowNetwork
        self.entries = entries
        self.algorithmVersion = MediaAnalysisVersion.exact
    }
}

/// File I/O stays off the UI actor. A later ticket prevents stale saves after
/// completion, cancellation, or a source-scope change.
public actor LibraryCheckpointArchive {
    private var ticket = -1
    private var active = false
    public init() {}
    public func load(url: URL?, ticket: Int, sourceID: String, allowNetwork: Bool) -> UniversalScanCheckpoint? {
        guard ticket >= self.ticket else { return nil }
        self.ticket = ticket; active = true
        guard let url, let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(UniversalScanCheckpoint.self, from: data),
              value.algorithmVersion == MediaAnalysisVersion.exact,
              value.sourceID == sourceID, value.allowNetwork == allowNetwork else { return nil }
        return value
    }
    public func save(_ value: UniversalScanCheckpoint, url: URL?, ticket: Int) throws {
        guard active, ticket == self.ticket, let url else { return }
        let data = try JSONEncoder().encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    public func stop(url: URL?, ticket: Int, preserve: Bool) {
        guard ticket >= self.ticket else { return }
        self.ticket = ticket; active = false
        if !preserve, let url { try? FileManager.default.removeItem(at: url) }
    }
}

public actor UniversalExactScanner {
    public private(set) var metrics = AnalysisWorkMetrics()
    public init() {}

    public func scan(
        adapter: any SourceAdapter,
        allowNetwork: Bool,
        fingerprintAllAssets: Bool = false,
        preloadedAssets: [UniversalMediaAsset]? = nil,
        resuming checkpoint: UniversalScanCheckpoint? = nil,
        control: LibraryAnalysisControl? = nil,
        checkpointInterval: Int = 100,
        checkpointUpdate: @escaping @Sendable (UniversalScanCheckpoint) -> Void = { _ in },
        groupsUpdate: @escaping @Sendable ([UniversalExactGroup]) -> Void = { _ in },
        progress: @escaping @Sendable (_ processed: Int, _ total: Int, _ current: String) -> Void
    ) async throws -> (assets: [UniversalMediaAsset], groups: [UniversalExactGroup], skippedNetwork: Int, fingerprintsByAssetID: [String: UniversalExactFingerprint], issues: [AnalysisIssue]) {
        let assets: [UniversalMediaAsset]
        metrics = .init()
        if let preloadedAssets { assets = preloadedAssets } else { assets = try await adapter.enumerateAssets() }
        var groupsByFingerprint: [UniversalExactFingerprint: [UniversalMediaAsset]] = [:]
        var completedEntries: [UniversalScanCheckpoint.Entry] = []
        var skippedNetwork = 0
        var issues: [AnalysisIssue] = []
        let resumableEntries: [String: UniversalScanCheckpoint.Entry]
        if let checkpoint, checkpoint.algorithmVersion == MediaAnalysisVersion.exact, checkpoint.sourceID == adapter.source.id, checkpoint.allowNetwork == allowNetwork {
            resumableEntries = Dictionary(checkpoint.entries.map { ($0.sourceAsset.id, $0) }, uniquingKeysWith: { _, latest in latest })
        } else {
            resumableEntries = [:]
        }

        var lastCheckpointEmission = Date()
        var pendingEntriesCount = 0
        var lastProgressEmission = Date.distantPast

        func emitCheckpointIfNeeded(force: Bool = false) {
            guard !completedEntries.isEmpty else { return }
            let now = Date()
            if force || pendingEntriesCount >= checkpointInterval || now.timeIntervalSince(lastCheckpointEmission) >= 2.0 {
                checkpointUpdate(.init(sourceID: adapter.source.id, allowNetwork: allowNetwork, entries: completedEntries))
                groupsUpdate(groupsByFingerprint.compactMap { fingerprint, members in
                    members.count > 1 && !fingerprint.digest.hasPrefix("unique:") ? UniversalExactGroup(digest: fingerprint.digest, assets: members) : nil
                }.sorted { $0.id < $1.id })
                lastCheckpointEmission = now
                pendingEntriesCount = 0
            }
        }
        // Quit/cancellation saves the tail that did not reach the configured interval.
        defer { emitCheckpointIfNeeded(force: true) }

        // Phase 1: Candidate signature bucketing.
        // Exact duplicates must have identical byte count (or matching media metadata if size is unknown).
        // Assets with unique signatures cannot be duplicates and do not need full SHA-256 data hashing.
        var assetSignatures: [String: String] = [:]
        var signatureCounts: [String: Int] = [:]
        var unknownKinds: Set<UniversalMediaKind> = []
        let kindCounts = Dictionary(grouping: assets, by: \.mediaKind).mapValues(\.count)

        for asset in assets {
            try await control?.waitIfPaused()
            try Task.checkCancellation()
            let sig: String
            if let byteCount = asset.byteCount, byteCount > 0 {
                sig = "s:\(byteCount)"
            } else if let prior = resumableEntries[asset.id],
                      (prior.fingerprint.byteCount > 0 || (prior.fingerprintedAsset.byteCount ?? 0) > 0) {
                let b = prior.fingerprint.byteCount > 0 ? prior.fingerprint.byteCount : prior.fingerprintedAsset.byteCount!
                sig = "s:\(b)"
            } else if let queried = await adapter.assetByteCount(for: asset), queried > 0 {
                sig = "s:\(queried)"
            } else {
                sig = "d:\(asset.mediaKind.rawValue):\(asset.pixelWidth)x\(asset.pixelHeight):\(Int(asset.duration ?? 0))"
            }
            assetSignatures[asset.id] = sig
            signatureCounts[sig, default: 0] += 1
            if sig.hasPrefix("d:") { unknownKinds.insert(asset.mediaKind) }
        }

        // Phase 2: Processing and hashing candidate assets.
        for (index, asset) in assets.enumerated() {
            try await control?.waitIfPaused()
            try Task.checkCancellation()
            let now = Date()
            if index == 0 || index == assets.count - 1 || now.timeIntervalSince(lastProgressEmission) >= 0.05 {
                lastProgressEmission = now
                progress(index, assets.count, asset.displayName)
            }

            let sig = assetSignatures[asset.id] ?? "unknown"
            // Unknown Photos sizes cannot exclude same-byte files in another
            // source. Dimensions are metadata, not proof of distinct bytes.
            let isCandidate = fingerprintAllAssets || (signatureCounts[sig] ?? 0) > 1 ||
                (unknownKinds.contains(asset.mediaKind) && (kindCounts[asset.mediaKind] ?? 0) > 1)

            // Replay from prior checkpoint if valid and revision matches
            if let prior = resumableEntries[asset.id], Self.sameRevision(asset, prior.sourceAsset) {
                // Singletons can keep their unique fingerprint; candidates require real SHA256 (not "unique:")
                if !isCandidate || !prior.fingerprint.digest.hasPrefix("unique:") {
                    groupsByFingerprint[prior.fingerprint, default: []].append(prior.fingerprintedAsset)
                    metrics.cacheHits += 1
                    completedEntries.append(prior)
                    continue
                }
            }

            if let cached = await MediaFingerprintDiskCache.shared.get(asset: asset, algorithm: MediaAnalysisVersion.exact), !cached.digest.hasPrefix("unique:") {
                metrics.cacheHits += 1
                let fingerprint = UniversalExactFingerprint(digest: cached.digest, byteCount: cached.byteCount)
                let updated = asset.with(byteCount: cached.byteCount, requiresNetwork: false)
                groupsByFingerprint[fingerprint, default: []].append(updated)
                completedEntries.append(.init(sourceAsset: asset, fingerprintedAsset: updated, fingerprint: fingerprint))
                pendingEntriesCount += 1
                emitCheckpointIfNeeded()
                continue
            }

            // Singleton fast-path: prune hashing
            if !isCandidate {
                let resolvedByteCount = asset.byteCount ?? 0
                let fingerprint = UniversalExactFingerprint(
                    digest: "unique:\(asset.id)",
                    byteCount: resolvedByteCount
                )
                let fingerprintedAsset = asset.with(
                    byteCount: resolvedByteCount > 0 ? resolvedByteCount : nil,
                    requiresNetwork: asset.requiresNetwork
                )
                groupsByFingerprint[fingerprint, default: []].append(fingerprintedAsset)
                completedEntries.append(.init(sourceAsset: asset, fingerprintedAsset: fingerprintedAsset, fingerprint: fingerprint))
                pendingEntriesCount += 1
                emitCheckpointIfNeeded()
                continue
            }

            // Candidate duplicate: two or more assets share the exact signature. Full SHA-256 fingerprint required.
            do {
                metrics.hashedOriginals += 1
                let fingerprint = try await adapter.exactFingerprint(
                    for: asset,
                    allowNetwork: allowNetwork,
                    progress: { _ in }
                )
                let fingerprintedAsset = asset.with(
                    byteCount: fingerprint.byteCount,
                    requiresNetwork: false
                )
                groupsByFingerprint[fingerprint, default: []].append(fingerprintedAsset)
                completedEntries.append(.init(sourceAsset: asset, fingerprintedAsset: fingerprintedAsset, fingerprint: fingerprint))
                await MediaFingerprintDiskCache.shared.store(asset: asset, algorithm: MediaAnalysisVersion.exact,
                    entry: .init(assetID: asset.id, digest: fingerprint.digest, byteCount: fingerprint.byteCount))
                pendingEntriesCount += 1
                emitCheckpointIfNeeded()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let issue = AnalysisIssue(asset: asset, stage: .exact, error: error)
                issues.append(issue)
                if issue.reason == .downloadRequired { skippedNetwork += 1 }
            }
        }
        emitCheckpointIfNeeded(force: true)

        let groups = groupsByFingerprint.compactMap { fingerprint, members in
            members.count > 1 ? UniversalExactGroup(digest: fingerprint.digest, assets: members) : nil
        }.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
        progress(assets.count, assets.count, "")

        let completedAssetMap = Dictionary(completedEntries.map { ($0.fingerprintedAsset.id, $0.fingerprintedAsset) }, uniquingKeysWith: { _, latest in latest })
        let finalizedAssets = assets.map { completedAssetMap[$0.id] ?? $0 }

        return (
            finalizedAssets,
            groups,
            skippedNetwork,
            Dictionary(completedEntries.map { ($0.fingerprintedAsset.id, $0.fingerprint) }, uniquingKeysWith: { _, latest in latest }),
            issues
        )
    }

    private static func sameRevision(_ current: UniversalMediaAsset, _ prior: UniversalMediaAsset) -> Bool {
        MediaRevisionPolicy.same(current, prior, algorithm: MediaAnalysisVersion.exact)
    }
}

enum StreamingSHA256 {
    static func file(at url: URL, progress: @escaping @Sendable (Int64) -> Void) async throws -> UniversalExactFingerprint {
        // Task.detached does not inherit cancellation, so forward it explicitly; otherwise
        // cancelling a scan would keep hashing a multi-gigabyte file to the end.
        let work = Task.detached(priority: .utility) { () -> UniversalExactFingerprint in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { throw UniversalScanError.inaccessibleAsset(url.lastPathComponent) }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            var bytes: Int64 = 0
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
                try Task.checkCancellation()
                hasher.update(data: chunk)
                bytes += Int64(chunk.count)
                progress(bytes)
            }
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            return UniversalExactFingerprint(digest: digest, byteCount: bytes)
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }
}
