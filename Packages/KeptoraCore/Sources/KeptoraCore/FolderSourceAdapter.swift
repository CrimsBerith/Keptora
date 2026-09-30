@preconcurrency import AVFoundation
import Foundation
import ImageIO

public actor FolderSourceAdapter: SourceAdapter, SimilarityImageProviding, SimilarityVideoProviding {
    public nonisolated let source: LibrarySource
    public nonisolated let capabilities: PlatformCapabilities
    public nonisolated let rootURL: URL

    private let supportedExtensions: Set<String> = SupportedMediaExtensions.allMedia

    public init(rootURL: URL, cleanupAvailable: Bool) {
        self.rootURL = rootURL
        let kind: LibrarySource.Kind = rootURL.path.contains("CloudStorage") ? .fileProvider : .folder
        self.source = LibrarySource(
            id: "folder:\(StableDigest.fnv1a64(rootURL.standardizedFileURL.path))",
            kind: kind,
            displayName: rootURL.lastPathComponent
        )
        self.capabilities = PlatformCapabilities(
            exactScan: true,
            similarityReview: true,
            cleanupMode: cleanupAvailable ? .folderQuarantine : .unavailable,
            canRestoreInApp: cleanupAvailable,
            mayRequireNetworkDownload: kind == .fileProvider,
            canRevealInFileBrowser: true
        )
    }

    public func authorizationStatus() async -> SourceAuthorization { .authorized }
    public func requestAuthorization() async -> SourceAuthorization { .authorized }

    public func enumerateAssets() async throws -> [UniversalMediaAsset] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isHiddenKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var assets: [UniversalMediaAsset] = []
        let discovered = enumerator.compactMap { $0 as? URL }
        for url in discovered {
            try Task.checkCancellation()
            if url.pathComponents.contains(".Keptora Quarantine") { continue }
            let ext = url.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            let kind: UniversalMediaKind = SupportedMediaExtensions.videos.contains(ext) ? .video : .image
            let stablePath = url.standardizedFileURL.path
            assets.append(
                UniversalMediaAsset(
                    id: "file:\(StableDigest.fnv1a64(source.id + "|" + stablePath))",
                    sourceID: source.id,
                    reference: .file(url),
                    displayName: url.lastPathComponent,
                    mediaKind: kind,
                    byteCount: Int64(values?.fileSize ?? 0),
                    creationDate: values?.creationDate,
                    modificationDate: values?.contentModificationDate
                )
            )
        }
        return assets.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    public func exactFingerprint(
        for asset: UniversalMediaAsset,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint {
        guard case .file(let url) = asset.reference else { throw UniversalScanError.unsupportedReference }
        return try await StreamingSHA256.file(at: url, progress: progress)
    }

    public func similarityImage(
        for asset: UniversalMediaAsset,
        maximumPixelSize: Int,
        allowNetwork: Bool
    ) async throws -> CGImage {
        guard case .file(let url) = asset.reference, asset.mediaKind == .image,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else {
            throw UniversalScanError.inaccessibleAsset(asset.displayName)
        }
        return image
    }

    public func similarityVideoSample(
        for asset: UniversalMediaAsset,
        maximumPixelSize: Int,
        allowNetwork: Bool
    ) async throws -> UniversalVideoSimilaritySample {
        guard case .file(let url) = asset.reference, asset.mediaKind == .video else {
            throw UniversalScanError.unsupportedReference
        }
        return try await UniversalVideoFrameSampler.sample(
            avAsset: AVURLAsset(url: url),
            maximumPixelSize: maximumPixelSize
        )
    }
}
