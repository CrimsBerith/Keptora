import KeptoraCore
import AppKit
@preconcurrency import AVFoundation
import ImageIO
import Photos
import SwiftUI


// Thumbnail loading shared by the library grid. The old Photos-only library screen that used
// to live in this file was replaced by MacArchiveView.

struct MacPhotosThumbnail: View {
    let asset: UniversalMediaAsset
    var pixelSize: CGFloat = 512
    var fit = false
    var allowNetwork = false
    @State private var image: NSImage?
    @State private var finished = false
    private var cacheKey: String { "\(asset.id)|\(asset.modificationDate?.timeIntervalSince1970 ?? 0)|\(asset.fileRevision?.changeToken ?? "")|\(pixelSize)|\(fit)|\(allowNetwork)" }
    var body: some View {
        ZStack {
            Color.secondary.opacity(0.10)
            if let image {
                if fit { Image(nsImage: image).resizable().scaledToFit() }
                else { Image(nsImage: image).resizable().scaledToFill() }
            } else if !finished { ProgressView() }
            else { Label("Preview unavailable", systemImage: asset.mediaKind == .video ? "video.slash" : "photo").font(.caption).foregroundStyle(.secondary) }
        }.clipped().task(id: cacheKey) { await load() }
    }
    private func load() async {
        image = nil; finished = false
        defer {
            if !Task.isCancelled {
                finished = true
                if let image, asset.modificationDate != nil { MacArchiveThumbnailCache.shared.store(image, key: cacheKey) }
            }
        }
        if asset.modificationDate != nil, let cached = MacArchiveThumbnailCache.shared.get(cacheKey) { image = cached; return }
        if case .file(let url) = asset.reference {
            do { try await FolderSourceAdapter(rootURL: url.deletingLastPathComponent(), cleanupAvailable: false).prepareForAccess(url, allowNetwork: allowNetwork) }
            catch { return }
            if asset.mediaKind == .video {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: pixelSize, height: pixelSize)
                let cgImage = await withTaskCancellationHandler {
                    try? await generator.image(at: CMTime(seconds: 0, preferredTimescale: 600)).image
                } onCancel: { generator.cancelAllCGImageGeneration() }
                if let cgImage, !Task.isCancelled { image = NSImage(cgImage: cgImage, size: .zero) }
            } else {
                let size = pixelSize
                let work = Task.detached(priority: .utility) { () -> NSImage? in
                    try? await MediaWorkGate.thumbnails.withPermit {
                        guard !Task.isCancelled, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceThumbnailMaxPixelSize: Int(size),
                                kCGImageSourceCreateThumbnailWithTransform: true
                              ] as CFDictionary) else { return nil as NSImage? }
                        return NSImage(cgImage: cg, size: .zero)
                    }
                }
                let decoded = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
                if !Task.isCancelled { image = decoded }
            }
            return
        }
        guard case .photoLibrary(let identifier) = asset.reference,
              let photo = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return }
        let request = MacArchiveImageRequest()
        let decoded: NSImage? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions(); options.deliveryMode = .highQualityFormat
                options.resizeMode = .exact; options.isNetworkAccessAllowed = allowNetwork
                let id = PHImageManager.default().requestImage(for: photo, targetSize: NSSize(width: pixelSize, height: pixelSize),
                    contentMode: fit ? .aspectFit : .aspectFill, options: options) { value, info in
                        let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                        let failed = info?[PHImageErrorKey] != nil
                        let localCloud = !allowNetwork && (info?[PHImageResultIsInCloudKey] as? Bool) == true
                        if degraded && !cancelled && !failed && !localCloud { return }
                        request.resume { continuation.resume(returning: value) }
                    }
                request.install(id)
            }
        } onCancel: { request.cancel() }
        if !Task.isCancelled { image = decoded }
    }
}
private final class MacArchiveThumbnailCache: @unchecked Sendable {
    static let shared = MacArchiveThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() { cache.totalCostLimit = 64 * 1_048_576; cache.countLimit = 250 }
    func get(_ key: String) -> NSImage? { cache.object(forKey: key as NSString) }
    func store(_ image: NSImage, key: String) {
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let cost = cg.map { $0.bytesPerRow * $0.height } ?? Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}
private final class MacArchiveImageRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var id = PHInvalidImageRequestID
    private var cancelled = false
    private var resumed = false
    func install(_ value: PHImageRequestID) {
        lock.lock(); id = value; let cancelNow = cancelled; lock.unlock()
        if cancelNow { PHImageManager.default().cancelImageRequest(value) }
    }
    func cancel() {
        lock.lock(); cancelled = true; let value = id; lock.unlock()
        if value != PHInvalidImageRequestID { PHImageManager.default().cancelImageRequest(value) }
    }
    func resume(_ operation: () -> Void) {
        lock.lock(); let shouldResume = !resumed; resumed = true; lock.unlock()
        if shouldResume { operation() }
    }
}
