import KeptoraCore
@preconcurrency import AVFoundation
import ImageIO
import Photos
import SwiftUI

struct MobileAssetThumbnail: View {
    let asset: UniversalMediaAsset
    /// Longest edge requested from PhotoKit; grid cells use the default, full-screen viewers pass more.
    var pixelSize: CGFloat = 500
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var didFinish = false

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
                Image(systemName: asset.mediaKind == .video ? "video.fill" : "photo")
                    .font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: asset.id) {
            didFinish = false
            await load()
            if !Task.isCancelled { didFinish = true }
        }
    }

    private var cacheKey: String {
        "\(asset.id)_\(Int(pixelSize))_\(contentMode == .fit ? "fit" : "fill")"
    }

    private func load() async {
        if let cached = MobileThumbnailCache.shared.image(forKey: cacheKey) {
            self.image = cached
            return
        }

        var loadedImage: UIImage?
        switch asset.reference {
        case .file(let url):
            if asset.mediaKind == .video {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: max(pixelSize, 600), height: max(pixelSize, 600))
                loadedImage = await withTaskCancellationHandler {
                    if let frame = try? await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image {
                        return UIImage(cgImage: frame)
                    }
                    return nil
                } onCancel: {
                    generator.cancelAllCGImageGeneration()
                }
            } else {
                loadedImage = await Task.detached(priority: .utility) {
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: max(Int(pixelSize), 600),
                            kCGImageSourceCreateThumbnailWithTransform: true
                          ] as CFDictionary) else { return nil }
                    return UIImage(cgImage: cgImage)
                }.value
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
                    options.isNetworkAccessAllowed = false
                    let targetMode: PHImageContentMode = (contentMode == .fit) ? .aspectFit : .aspectFill
                    let id = PHImageManager.default().requestImage(
                        for: photo,
                        targetSize: size,
                        contentMode: targetMode,
                        options: options
                    ) { img, info in
                        let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        // A degraded image is only a preview; wait for the final one unless PhotoKit
                        // reports an error or cancellation.
                        let failed = info?[PHImageErrorKey] != nil || (info?[PHImageCancelledKey] as? Bool) == true
                        if degraded && img != nil && !failed { return }
                        request.resumeOnce { continuation.resume(returning: img) }
                    }
                    request.setID(id)
                }
            } onCancel: {
                request.cancel()
            }
        }

        if let loadedImage, !Task.isCancelled {
            MobileThumbnailCache.shared.setImage(loadedImage, forKey: cacheKey)
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
        let cost = Int(image.size.width * image.size.height * 4)
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
        lock.lock(); defer { lock.unlock() }
        requestID = id
        if wasCancelled { PHImageManager.default().cancelImageRequest(id) }
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        wasCancelled = true
        if requestID != PHInvalidImageRequestID { PHImageManager.default().cancelImageRequest(requestID) }
    }

    func resumeOnce(_ body: () -> Void) {
        lock.lock()
        let shouldResume = !didResume
        didResume = true
        lock.unlock()
        if shouldResume { body() }
    }
}
