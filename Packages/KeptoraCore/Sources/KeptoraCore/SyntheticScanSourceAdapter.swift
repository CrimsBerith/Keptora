#if DEBUG
import Foundation

public actor SyntheticScanSourceAdapter: SourceAdapter {
    public nonisolated let source: LibrarySource
    public nonisolated let capabilities = PlatformCapabilities(
        exactScan: true,
        similarityReview: false,
        cleanupMode: .unavailable,
        canRestoreInApp: false,
        mayRequireNetworkDownload: false,
        canRevealInFileBrowser: false
    )

    private let assetCount: Int
    private let initialBatchSize: Int
    private let batchDelayNanoseconds: UInt64

    public init(
        sourceID: String,
        assetCount: Int = 10_000,
        initialBatchSize: Int = 1_000,
        batchDelayNanoseconds: UInt64 = 0
    ) {
        precondition(assetCount >= 0)
        precondition(initialBatchSize > 0)
        self.source = LibrarySource(id: sourceID, kind: .folder, displayName: "Synthetic Test Library")
        self.assetCount = assetCount
        self.initialBatchSize = initialBatchSize
        self.batchDelayNanoseconds = batchDelayNanoseconds
    }

    public func authorizationStatus() async -> SourceAuthorization { .authorized }
    public func requestAuthorization() async -> SourceAuthorization { .authorized }

    public func enumerateAssets() async throws -> [UniversalMediaAsset] {
        (0..<assetCount).map { Self.asset(at: $0, sourceID: source.id) }
    }

    public func enumerateAssets(
        batchSize: Int,
        control: LibraryAnalysisControl?,
        onBatch: @escaping @Sendable ([UniversalMediaAsset]) async -> Void
    ) async throws -> [UniversalMediaAsset] {
        guard batchSize > 0 else { throw SyntheticScanSourceAdapterError.invalidBatchSize }

        var assets: [UniversalMediaAsset] = []
        var nextIndex = 0
        while nextIndex < assetCount {
            try Task.checkCancellation()
            try await control?.waitIfPaused()
            if nextIndex > 0, batchDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: batchDelayNanoseconds)
            }

            let count = nextIndex == 0 ? initialBatchSize : batchSize
            let endIndex = min(nextIndex + count, assetCount)
            assets.append(contentsOf: (nextIndex..<endIndex).map {
                Self.asset(at: $0, sourceID: source.id)
            })
            nextIndex = endIndex
            await onBatch(assets)
        }
        return assets
    }

    public func exactFingerprint(
        for asset: UniversalMediaAsset,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint {
        guard asset.sourceID == source.id else {
            throw UnifiedLibraryError.sourceUnavailable(asset.sourceID)
        }
        let byteCount = asset.byteCount ?? 0
        progress(byteCount)
        return UniversalExactFingerprint(
            algorithm: "synthetic-fixture-v1",
            digest: asset.id,
            byteCount: byteCount
        )
    }

    public nonisolated static func asset(at index: Int, sourceID: String) -> UniversalMediaAsset {
        precondition(index >= 0)
        let filename = "Synthetic-\(index).mov"
        let root = URL(fileURLWithPath: "/tmp/keptora-synthetic-scan/\(sourceID)", isDirectory: true)
        return UniversalMediaAsset(
            id: "synthetic-scan-\(sourceID)-\(index)",
            sourceID: sourceID,
            reference: .file(root.appendingPathComponent(filename)),
            displayName: filename,
            mediaKind: .video,
            byteCount: Int64(1_000_000 + index),
            duration: 3,
            creationDate: Date(timeIntervalSince1970: 1_600_000_000 + Double(index) * 60)
        )
    }
}

private enum SyntheticScanSourceAdapterError: Error {
    case invalidBatchSize
}
#endif
