@preconcurrency import AVFoundation
import Foundation
import ImageIO

private final class EnumerationIssues: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []
    func append(_ message: String) { lock.lock(); messages.append(message); lock.unlock() }
    func snapshot() -> [String] { lock.lock(); defer { lock.unlock() }; return messages }
}

public actor FolderSourceAdapter: SourceAdapter, SimilarityImageProviding, SimilarityVideoProviding {
    public nonisolated let source: LibrarySource
    public nonisolated let capabilities: PlatformCapabilities
    public nonisolated let rootURL: URL

    private let supportedExtensions: Set<String> = SupportedMediaExtensions.allMedia
    private var warnings: [String] = []
    private let configuration: LibraryConfiguration
    public func enumerationWarnings() async -> [String] { warnings }

    public init(rootURL: URL, cleanupAvailable: Bool, configuration: LibraryConfiguration = .init()) {
        self.rootURL = rootURL
        self.configuration = configuration
        let cloudRoot = rootURL.path.contains("CloudStorage") || rootURL.path.contains("Mobile Documents") || (try? rootURL.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
        let kind: LibrarySource.Kind = cloudRoot ? .fileProvider : .folder
        self.source = LibrarySource(
            id: "folder:\(LibraryFileIdentity.key(for: rootURL))",
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
            .isRegularFileKey, .isDirectoryKey, .isHiddenKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey,
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey
        ]
        let issues = EnumerationIssues()
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in issues.append(url.lastPathComponent + ": " + error.localizedDescription); return true }
        ) else { throw UniversalScanError.inaccessibleAsset(rootURL.lastPathComponent) }

        var assets: [UniversalMediaAsset] = []
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            if configuration.excludesDirectory(url.lastPathComponent),
               (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                enumerator.skipDescendants(); continue
            }
            let ext = url.pathExtension.lowercased()
            guard supportedExtensions.contains(ext), !configuration.excludesExtension(ext) else { continue }
            let values: URLResourceValues?
            do { values = try url.resourceValues(forKeys: keys) }
            catch { issues.append(url.lastPathComponent + ": " + error.localizedDescription); continue }
            guard values?.isRegularFile == true else { continue }
            let kind: UniversalMediaKind = SupportedMediaExtensions.videos.contains(ext) ? .video : .image
            let cloudOnly = values?.isUbiquitousItem == true && values?.ubiquitousItemDownloadingStatus == .notDownloaded
            let metadata = kind == .image && !cloudOnly ? PhotoMetadataExtractor.extract(from: url) : nil
            assets.append(
                UniversalMediaAsset(
                    id: "file:\(LibraryFileIdentity.key(for: url))",
                    sourceID: source.id,
                    reference: .file(url),
                    displayName: url.lastPathComponent,
                    mediaKind: kind,
                    byteCount: values?.fileSize.map { Int64($0) },
                    pixelWidth: metadata?.pixelWidth ?? 0, pixelHeight: metadata?.pixelHeight ?? 0,
                    creationDate: values?.creationDate,
                    modificationDate: values?.contentModificationDate,
                    requiresNetwork: cloudOnly,
                    context: MediaContext(location: metadata.flatMap { m in
                        guard let lat = m.latitude, let lon = m.longitude else { return nil }
                        return MediaLocation(latitude: lat, longitude: lon)
                    }, captureDate: metadata?.dateCaptured, captureTimeIsReliable: metadata?.captureTimeIsReliable == true, camera: metadata?.cameraModel, captureDateText: metadata?.dateCapturedText)
                )
            )
        }
        warnings = issues.snapshot()
        return assets.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    public func exactFingerprint(
        for asset: UniversalMediaAsset,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint {
        guard case .file(let url) = asset.reference else { throw UniversalScanError.unsupportedReference }
        try await ensureLocal(url, allowNetwork: allowNetwork)
        return try await StreamingSHA256.file(at: url, progress: progress)
    }

    public func similarityImage(
        for asset: UniversalMediaAsset,
        maximumPixelSize: Int,
        allowNetwork: Bool
    ) async throws -> CGImage {
        guard case .file(let url) = asset.reference, asset.mediaKind == .image else { throw UniversalScanError.unsupportedReference }
        try await ensureLocal(url, allowNetwork: allowNetwork)
        guard
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
        try await ensureLocal(url, allowNetwork: allowNetwork)
        return try await UniversalVideoFrameSampler.sample(
            avAsset: AVURLAsset(url: url),
            maximumPixelSize: maximumPixelSize
        )
    }

    public func prepareForAccess(_ url: URL, allowNetwork: Bool) async throws {
        try await ensureLocal(url, allowNetwork: allowNetwork)
    }

    private func ensureLocal(_ url: URL, allowNetwork: Bool) async throws {
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        let values = try url.resourceValues(forKeys: keys)
        guard values.isUbiquitousItem == true, values.ubiquitousItemDownloadingStatus == .notDownloaded else { return }
        guard allowNetwork else { throw UniversalScanError.networkRequired(url.lastPathComponent) }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0..<120 {
            try Task.checkCancellation()
            var refreshedURL = url
            refreshedURL.removeCachedResourceValue(forKey: .ubiquitousItemDownloadingStatusKey)
            let fresh = try refreshedURL.resourceValues(forKeys: keys)
            if fresh.ubiquitousItemDownloadingStatus != .notDownloaded { return }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw UniversalScanError.resourceUnavailable(url.lastPathComponent)
    }
}
