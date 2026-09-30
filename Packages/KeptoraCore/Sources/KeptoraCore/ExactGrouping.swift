import CryptoKit
import Foundation

public enum UniversalScanError: LocalizedError, Sendable {
    case inaccessibleAsset(String)
    case networkRequired(String)
    case sourcePermissionDenied
    case unsupportedReference
    case cleanupNotPermitted(String)

    public var errorDescription: String? {
        switch self {
        case .inaccessibleAsset(let name): return "Keptora could not read \(name)."
        case .networkRequired(let name): return "\(name) is stored in iCloud and requires an approved download."
        case .sourcePermissionDenied: return "Keptora does not have permission to access this source."
        case .unsupportedReference: return "This source reference is not supported."
        case .cleanupNotPermitted(let reason): return reason
        }
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

    public init(sourceID: String, allowNetwork: Bool, entries: [Entry]) {
        self.sourceID = sourceID
        self.allowNetwork = allowNetwork
        self.entries = entries
    }
}

public actor UniversalExactScanner {
    public init() {}

    public func scan(
        adapter: any SourceAdapter,
        allowNetwork: Bool,
        resuming checkpoint: UniversalScanCheckpoint? = nil,
        checkpointUpdate: @escaping @Sendable (UniversalScanCheckpoint) -> Void = { _ in },
        progress: @escaping @Sendable (_ processed: Int, _ total: Int, _ current: String) -> Void
    ) async throws -> (assets: [UniversalMediaAsset], groups: [UniversalExactGroup], skippedNetwork: Int, fingerprintsByAssetID: [String: UniversalExactFingerprint]) {
        let assets = try await adapter.enumerateAssets()
        var groupsByFingerprint: [UniversalExactFingerprint: [UniversalMediaAsset]] = [:]
        var completedEntries: [UniversalScanCheckpoint.Entry] = []
        var skippedNetwork = 0
        let resumableEntries: [String: UniversalScanCheckpoint.Entry]
        if let checkpoint, checkpoint.sourceID == adapter.source.id, checkpoint.allowNetwork == allowNetwork {
            resumableEntries = Dictionary(checkpoint.entries.map { ($0.sourceAsset.id, $0) }, uniquingKeysWith: { _, latest in latest })
        } else {
            resumableEntries = [:]
        }

        var lastCheckpointEmission = Date()
        var pendingEntriesCount = 0

        func emitCheckpointIfNeeded(force: Bool = false) {
            guard !completedEntries.isEmpty else { return }
            let now = Date()
            if force || pendingEntriesCount >= 50 || now.timeIntervalSince(lastCheckpointEmission) >= 2.0 {
                checkpointUpdate(.init(sourceID: adapter.source.id, allowNetwork: allowNetwork, entries: completedEntries))
                lastCheckpointEmission = now
                pendingEntriesCount = 0
            }
        }

        for (index, asset) in assets.enumerated() {
            try Task.checkCancellation()
            progress(index, assets.count, asset.displayName)
            if let prior = resumableEntries[asset.id], Self.sameRevision(asset, prior.sourceAsset) {
                groupsByFingerprint[prior.fingerprint, default: []].append(prior.fingerprintedAsset)
                completedEntries.append(prior)
                pendingEntriesCount += 1
                emitCheckpointIfNeeded()
                continue
            }
            do {
                let fingerprint = try await adapter.exactFingerprint(
                    for: asset,
                    allowNetwork: allowNetwork,
                    progress: { _ in }
                )
                let fingerprintedAsset = UniversalMediaAsset(
                        id: asset.id,
                        sourceID: asset.sourceID,
                        reference: asset.reference,
                        displayName: asset.displayName,
                        mediaKind: asset.mediaKind,
                        byteCount: fingerprint.byteCount,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        duration: asset.duration,
                        creationDate: asset.creationDate,
                        modificationDate: asset.modificationDate,
                        isFavorite: asset.isFavorite,
                        isHidden: asset.isHidden,
                        hasAdjustments: asset.hasAdjustments,
                        isSharedLibraryAsset: asset.isSharedLibraryAsset,
                        hasAlbumMembership: asset.hasAlbumMembership,
                        requiresNetwork: false
                    )
                groupsByFingerprint[fingerprint, default: []].append(fingerprintedAsset)
                completedEntries.append(.init(sourceAsset: asset, fingerprintedAsset: fingerprintedAsset, fingerprint: fingerprint))
                pendingEntriesCount += 1
                emitCheckpointIfNeeded()
            } catch UniversalScanError.networkRequired {
                skippedNetwork += 1
            }
        }
        emitCheckpointIfNeeded(force: true)

        let groups = groupsByFingerprint.compactMap { fingerprint, members in
            members.count > 1 ? UniversalExactGroup(digest: fingerprint.digest, assets: members) : nil
        }.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
        progress(assets.count, assets.count, "")
        return (
            assets,
            groups,
            skippedNetwork,
            Dictionary(completedEntries.map { ($0.fingerprintedAsset.id, $0.fingerprint) }, uniquingKeysWith: { _, latest in latest })
        )
    }

    private static func sameRevision(_ current: UniversalMediaAsset, _ prior: UniversalMediaAsset) -> Bool {
        current.reference == prior.reference &&
        current.modificationDate == prior.modificationDate &&
        current.byteCount == prior.byteCount
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
