// Keptora supports macOS 13, where AppKit's newer Sendable annotations are
// unavailable. The cache uses an explicit unchecked wrapper at its actor
// boundary and keeps all NSImage mutation inside the cache actor.
@preconcurrency import AppKit
import Foundation
import ImageIO
import QuickLookThumbnailing

private final class SendableThumbnail: @unchecked Sendable {
    let image: NSImage

    init(_ image: NSImage) {
        self.image = image
    }
}

actor BoundedThumbnailCache {
    static let shared = BoundedThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [String: Task<SendableThumbnail?, Never>] = [:]

    init(memoryBudgetBytes: Int = 96 * 1024 * 1024, countLimit: Int = 320) {
        cache.totalCostLimit = memoryBudgetBytes
        cache.countLimit = countLimit
    }

    func image(for url: URL, maxPixelSize: CGFloat, scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2) async -> NSImage? {
        let key = cacheKey(url: url, maxPixelSize: maxPixelSize, scale: scale)
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] { return await task.value?.image }

        let task = Task<SendableThumbnail?, Never> {
            if let image = Self.imageIOThumbnail(url: url, maxPixelSize: maxPixelSize) { return SendableThumbnail(image) }
            guard let image = await Self.quickLookThumbnail(url: url, maxPixelSize: maxPixelSize, scale: scale) else { return nil }
            return SendableThumbnail(image)
        }
        inFlight[key] = task
        let image = await task.value?.image
        inFlight[key] = nil
        if let image {
            let pixels = max(1, Int(image.size.width * scale)) * max(1, Int(image.size.height * scale))
            cache.setObject(image, forKey: key as NSString, cost: pixels * 4)
        }
        return image
    }

    func removeAll() {
        cache.removeAllObjects()
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
    }

    private func cacheKey(url: URL, maxPixelSize: CGFloat, scale: CGFloat) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        return "\(url.standardizedFileURL.path)|\(values?.fileSize ?? 0)|\(modified)|\(Int(maxPixelSize))|\(scale)"
    }

    private static func imageIOThumbnail(url: URL, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: max(64, Int(maxPixelSize))
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: .zero)
    }

    private static func quickLookThumbnail(url: URL, maxPixelSize: CGFloat, scale: CGFloat) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: maxPixelSize, height: maxPixelSize),
                scale: scale,
                representationTypes: [.thumbnail, .lowQualityThumbnail, .icon]
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                guard let representation else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: NSImage(cgImage: representation.cgImage, size: .zero))
            }
        }
    }
}
