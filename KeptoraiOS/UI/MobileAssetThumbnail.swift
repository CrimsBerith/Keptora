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
                    Image(uiImage: image).resizable().scaledToFit().transition(.opacity)
                } else {
                    Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
                }
            } else if !didFinish {
                Color(uiColor: .secondarySystemFill)
            } else {
                GeometryReader { geometry in
                    let compact = geometry.size.width < 120 || geometry.size.height < 120
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark").font(.system(size: compact ? 20 : 28))
                        if !compact {
                            Text(unavailableLabel).font(.caption2).multilineTextAlignment(.center)
                            if showsRetryButton {
                                Button { Task { didFinish = false; await load(); didFinish = true } } label: {
                                    Text("Retry").font(.caption).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityElement(children: compact ? .ignore : .contain)
                    .accessibilityLabel(unavailableLabel)
                }
            }
        }
        .clipped()
        .task(id: cacheKey) {
            if let cached = MobileThumbnailCache.shared.image(forKey: cacheKey) {
                self.image = cached
                self.didFinish = true
                return
            }
            image = nil; didFinish = false; needsDownload = false
            await load()
            if !Task.isCancelled { didFinish = true }
        }
    }

    private static let cachingImageManager = PHCachingImageManager()

    private var unavailableLabel: LocalizedStringKey {
        needsDownload ? "Cloud original needs download" : "Preview unavailable"
    }

    var cacheKey: String {
        let stamp = asset.modificationDate?.timeIntervalSince1970 ?? asset.creationDate?.timeIntervalSince1970 ?? 0
        return "\(asset.id)_\(stamp)_\(asset.fileRevision?.physicalIdentity ?? "")_\(asset.fileRevision?.changeToken ?? "")_\(Int(pixelSize))_\(contentMode == .fit ? "fit" : "fill")_\(allowNetwork)"
    }

    private func load() async {
        if let cached = MobileThumbnailCache.shared.image(forKey: cacheKey) {
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
                        return autoreleasepool {
                            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                                    kCGImageSourceThumbnailMaxPixelSize: max(Int(pixelSize), 64),
                                    kCGImageSourceCreateThumbnailWithTransform: true
                                  ] as CFDictionary) else { return nil }
                            return UIImage(cgImage: cgImage)
                        }
                    }
                }
                loadedImage = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            }
        case .photoLibrary(let localIdentifier):
            let photo: PHAsset?
            if let cachedPhoto = MobilePHAssetCache.shared.asset(for: localIdentifier) {
                photo = cachedPhoto
            } else if let coreCached = PhotoLibraryAssetCache.shared.asset(for: localIdentifier) {
                photo = coreCached
                MobilePHAssetCache.shared.setAsset(coreCached, for: localIdentifier)
            } else {
                let fetched = await Task.detached(priority: .userInitiated) {
                    PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
                }.value
                if let fetched {
                    MobilePHAssetCache.shared.setAsset(fetched, for: localIdentifier)
                }
                photo = fetched
            }
            guard let photo else { return }
            let request = PhotoImageRequest()
            let size = CGSize(width: pixelSize, height: pixelSize)
            // Cancelling the SwiftUI task (cell scrolled away) must also cancel the PhotoKit request,
            // otherwise fast scrolling queues up hundreds of decodes.
            loadedImage = await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                    request.setContinuation(continuation)
                    let options = PHImageRequestOptions()
                    options.deliveryMode = pixelSize <= 384 ? .fastFormat : .highQualityFormat
                    options.resizeMode = .fast
                    options.isNetworkAccessAllowed = allowNetwork
                    let targetMode: PHImageContentMode = (contentMode == .fit) ? .aspectFit : .aspectFill
                    let id = Self.cachingImageManager.requestImage(
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
                        if degraded && img != nil && !failed && !isFinalOrOnlyAvailable && pixelSize > 384 { return }
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

/// Larger look at one item from the gallery's touch-and-hold menu, so people can check a photo
/// before selecting it. Uses on-device data only; iCloud originals are not downloaded here.
struct MobileAssetPreview: View {
    let asset: UniversalMediaAsset
    let sourceLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MobileAssetThumbnail(asset: asset, pixelSize: 1200, contentMode: .fit, showsRetryButton: false)
                .frame(width: 340, height: 340)
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(details).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk).lineLimit(2)
            }
            .padding(12)
            .frame(width: 340, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .keptoraMobileGlass(cornerRadius: 18)
    }

    private var details: String {
        var parts = [sourceLabel]
        if let date = asset.captureDateDescription { parts.append(date) }
        if asset.mediaKind == .video { parts.append(asset.formattedDuration) }
        if let bytes = asset.byteCount { parts.append(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) }
        return parts.joined(separator: " · ")
    }
}

final class MobilePHAssetCache: @unchecked Sendable {
    static let shared = MobilePHAssetCache()
    private let cache = NSCache<NSString, PHAsset>()
    private init() {
        cache.countLimit = 4000
    }
    func asset(for identifier: String) -> PHAsset? {
        cache.object(forKey: identifier as NSString)
    }
    func setAsset(_ asset: PHAsset, for identifier: String) {
        cache.setObject(asset, forKey: identifier as NSString)
    }
}

final class MobileThumbnailCache: @unchecked Sendable {
    static let shared = MobileThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()
    private var memoryObserver: (any NSObjectProtocol)?

    private init() {
        cache.totalCostLimit = 256 * 1024 * 1024 // 256 MB
        cache.countLimit = 1500
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }

    deinit {
        if let memoryObserver {
            NotificationCenter.default.removeObserver(memoryObserver)
        }
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? max(Int(image.size.width * image.scale * image.size.height * image.scale * 4), 1024)
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
    private var continuation: CheckedContinuation<UIImage?, Never>?

    func setContinuation(_ continuation: CheckedContinuation<UIImage?, Never>) {
        lock.lock()
        self.continuation = continuation
        let cancelNow = wasCancelled && !didResume
        if cancelNow { didResume = true }
        lock.unlock()
        if cancelNow { continuation.resume(returning: nil) }
    }

    func setID(_ id: PHImageRequestID) {
        lock.lock()
        requestID = id
        let cancelNow = wasCancelled
        lock.unlock()
        if cancelNow { PHImageManager.default().cancelImageRequest(id) }
    }

    func cancel() {
        lock.lock()
        wasCancelled = true
        let id = requestID
        let cont = didResume ? nil : continuation
        didResume = true
        lock.unlock()
        if id != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(id)
        }
        cont?.resume(returning: nil)
    }

    func resumeOnce(_ body: () -> Void) {
        lock.lock()
        let shouldResume = !didResume
        didResume = true
        lock.unlock()
        if shouldResume { body() }
    }
}

struct MobileFullAssetViewer: View {
    let asset: UniversalMediaAsset
    let sourceLabel: String
    var isSelected: Bool
    var onToggleSelection: () -> Void
    var onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    MobileAssetThumbnail(
                        asset: asset,
                        pixelSize: 2048,
                        contentMode: .fit,
                        allowNetwork: true,
                        showsRetryButton: true
                    )
                    .offset(offset)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 4.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.05 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.05 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                } else {
                                    offset = value.translation
                                }
                            }
                            .onEnded { value in
                                if scale > 1.05 {
                                    lastOffset = offset
                                } else {
                                    if value.translation.width < -90 {
                                        // Swipe Left -> Select for Deletion
                                        if !isSelected {
                                            onToggleSelection()
                                        }
                                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    } else if value.translation.width > 90 {
                                        // Swipe Right -> Keep (Deselect)
                                        if isSelected {
                                            onToggleSelection()
                                        }
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    } else if value.translation.height > 120 {
                                        // Swipe Down -> Dismiss
                                        onDismiss()
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.2 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(details)
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.85))
                                }
                                selectionButton
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(details)
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.85))
                                        .lineLimit(1)
                                }
                                Spacer()
                                selectionButton
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 1)
                    }
                }
            }
            .navigationTitle(asset.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Done")) {
                        onDismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var selectionButton: some View {
        Button {
            onToggleSelection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                Text(isSelected ? LocalizedStringKey("Selected") : LocalizedStringKey("Select"))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: MobileKeptoraDesign.minimumTouchTarget)
            .background(isSelected ? MobileKeptoraDesign.accentFill : Color.white.opacity(0.25), in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel(isSelected ? L10n.tr("Deselect Photo") : L10n.tr("Select Photo"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var details: String {
        var parts = [sourceLabel]
        if let date = asset.captureDateDescription { parts.append(date) }
        if asset.mediaKind == .video { parts.append(asset.formattedDuration) }
        if let bytes = asset.byteCount { parts.append(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) }
        return parts.joined(separator: " · ")
    }
}
