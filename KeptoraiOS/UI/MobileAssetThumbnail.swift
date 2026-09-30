import KeptoraCore
@preconcurrency import AVFoundation
import ImageIO
import Photos
import SwiftUI

struct MobileAssetThumbnail: View {
    let asset: UniversalMediaAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: asset.mediaKind == .video ? "video.fill" : "photo")
                    .font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: asset.id) { await load() }
    }

    private func load() async {
        switch asset.reference {
        case .file(let url):
            if asset.mediaKind == .video {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 600, height: 600)
                if let frame = try? await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image {
                    image = UIImage(cgImage: frame)
                }
                return
            }
            image = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 600,
                        kCGImageSourceCreateThumbnailWithTransform: true
                      ] as CFDictionary) else { return nil }
                return UIImage(cgImage: cgImage)
            }.value
        case .photoLibrary(let localIdentifier):
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let photo = result.firstObject else { return }
            image = await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .fast
                options.isNetworkAccessAllowed = false
                var hasResumed = false
                PHImageManager.default().requestImage(
                    for: photo,
                    targetSize: CGSize(width: 500, height: 500),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !hasResumed && (!degraded || image != nil) {
                        hasResumed = true
                        continuation.resume(returning: image)
                    } else if !hasResumed && image == nil {
                        hasResumed = true
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}
