import KeptoraCore
@preconcurrency import AVFoundation
import ImageIO
import Photos
import SwiftUI

struct MobileAssetThumbnail: View {
    let asset: UniversalMediaAsset
    /// Longest edge requested from PhotoKit; grid cells use the default, full-screen viewers pass more.
    var pixelSize: CGFloat = 384
    var contentMode: ContentMode = .fill
    var allowNetwork = false
    var showsRetryButton = true
    @State private var image: UIImage?
    @State private var didFinish = false
    @State private var needsDownload = false

    var body: some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)
            if let image {
                if contentMode == .fit {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            } else if !didFinish {
                ProgressView()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark").font(.title2)
                    Text(needsDownload ? LocalizedStringKey("Cloud original needs download") : LocalizedStringKey("Preview unavailable")).font(.caption2).multilineTextAlignment(.center)
                    if showsRetryButton {
                        Button { Task { didFinish = false; await load(); didFinish = true } } label: {
                            Text("Retry").font(.caption).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }
                    }
                }.foregroundStyle(.secondary).padding(4)
            }
        }
        .clipped()
        .task(id: cacheKey) {
            image = nil; didFinish = false; needsDownload = false
            await load()
            if !Task.isCancelled { didFinish = true }
        }
    }

    private var cacheKey: String {
        "\(asset.id)_\(asset.modificationDate?.timeIntervalSince1970 ?? 0)_\(Int(pixelSize))_\(contentMode == .fit ? "fit" : "fill")_\(allowNetwork)"
    }

    private func load() async {
        if asset.modificationDate != nil, let cached = MobileThumbnailCache.shared.image(forKey: cacheKey) {
            self.image = cached
            return
        }

        var loadedImage: UIImage?
        switch asset.reference {
        case .file(let url):
            do { try await FolderSourceAdapter(rootURL: url.deletingLastPathComponent(), cleanupAvailable: false).prepareForAccess(url, allowNetwork: allowNetwork) }
            catch UniversalScanError.networkRequired { needsDownload = true; return }
            catch { return }
            if asset.mediaKind == .video {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: max(pixelSize, 64), height: max(pixelSize, 64))
                loadedImage = await withTaskCancellationHandler {
                    if let frame = try? await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image {
                        return UIImage(cgImage: frame)
                    }
                    return nil
                } onCancel: {
                    generator.cancelAllCGImageGeneration()
                }
            } else {
                let work = Task.detached(priority: .utility) { () -> UIImage? in
                    try? await MediaWorkGate.thumbnails.withPermit {
                    guard !Task.isCancelled else { return nil as UIImage? }
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: max(Int(pixelSize), 64),
                            kCGImageSourceCreateThumbnailWithTransform: true
                          ] as CFDictionary) else { return nil }
                    return UIImage(cgImage: cgImage)
                    }
                }
                loadedImage = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            }
        case .photoLibrary(let localIdentifier):
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let photo = result.firstObject else { return }
            let request = PhotoImageRequest()
            let size = CGSize(width: pixelSize, height: pixelSize)
            // Cancelling the SwiftUI task (cell scrolled away) must also cancel the PhotoKit request,
            // otherwise fast scrolling queues up hundreds of decodes.
            loadedImage = await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.resizeMode = .fast
                    options.isNetworkAccessAllowed = allowNetwork
                    let targetMode: PHImageContentMode = (contentMode == .fit) ? .aspectFit : .aspectFill
                    let id = PHImageManager.default().requestImage(
                        for: photo,
                        targetSize: size,
                        contentMode: targetMode,
                        options: options
                    ) { img, info in
                        let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        let failed = info?[PHImageErrorKey] != nil || (info?[PHImageCancelledKey] as? Bool) == true
                        let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                        // If network access is disabled or asset is in iCloud, degraded image is the only locally available representation
                        let isFinalOrOnlyAvailable = !options.isNetworkAccessAllowed && isInCloud
                        if degraded && img != nil && !failed && !isFinalOrOnlyAvailable { return }
                        request.resumeOnce { continuation.resume(returning: img) }
                    }
                    request.setID(id)
                }
            } onCancel: {
                request.cancel()
            }
        }

        if let loadedImage, !Task.isCancelled {
            if asset.modificationDate != nil { MobileThumbnailCache.shared.setImage(loadedImage, forKey: cacheKey) }
            self.image = loadedImage
        }
    }
}

final class MobileThumbnailCache: @unchecked Sendable {
    static let shared = MobileThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024 // 64 MB
        cache.countLimit = 250
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

/// Thread-safe holder so the cancellation handler can cancel the in-flight PhotoKit request and the
/// completion handler can resume its continuation exactly once.
private final class PhotoImageRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var requestID = PHInvalidImageRequestID
    private var didResume = false
    private var wasCancelled = false

    func setID(_ id: PHImageRequestID) {
        lock.lock(); requestID = id; let cancelNow = wasCancelled; lock.unlock()
        if cancelNow { PHImageManager.default().cancelImageRequest(id) }
    }

    func cancel() {
        lock.lock(); wasCancelled = true; let id = requestID; lock.unlock()
        if id != PHInvalidImageRequestID { PHImageManager.default().cancelImageRequest(id) }
    }

    func resumeOnce(_ body: () -> Void) {
        lock.lock()
        let shouldResume = !didResume
        didResume = true
        lock.unlock()
        if shouldResume { body() }
    }
}
