@preconcurrency import Photos
@preconcurrency import AVFoundation
import CryptoKit
import Foundation
import ImageIO

private final class LockedPhotoHasher: @unchecked Sendable {
    private let lock = NSLock()
    private var hasher = SHA256()
    private var byteCount: Int64 = 0

    func append(_ data: Data, countAsContent: Bool = true) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        hasher.update(data: data)
        if countAsContent { byteCount += Int64(data.count) }
        return byteCount
    }

    func finish() -> UniversalExactFingerprint {
        lock.lock()
        defer { lock.unlock() }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return UniversalExactFingerprint(digest: digest, byteCount: byteCount)
    }
}

private final class CancellablePhotosRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var id: PHImageRequestID?
    private var cancelled = false
    func install(_ id: PHImageRequestID) {
        lock.lock(); self.id = id; let shouldCancel = cancelled; lock.unlock()
        if shouldCancel { PHImageManager.default().cancelImageRequest(id) }
    }
    func cancel() {
        lock.lock(); cancelled = true; let current = id; lock.unlock()
        if let current { PHImageManager.default().cancelImageRequest(current) }
    }
}

private final class SingleShotContinuation<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var isResumed = false
    private let continuation: CheckedContinuation<T, Error>

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        if !isResumed {
            isResumed = true
            continuation.resume(returning: value)
        }
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        if !isResumed {
            isResumed = true
            continuation.resume(throwing: error)
        }
    }
}

public actor PhotoLibrarySourceAdapter: SourceAdapter, SimilarityImageProviding, SimilarityVideoProviding {
    public nonisolated let source = LibrarySource.photos
    public nonisolated let capabilities = PlatformCapabilities.photos

    public init() {}

    public func authorizationStatus() async -> SourceAuthorization {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    public func requestAuthorization() async -> SourceAuthorization {
        Self.map(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    public func enumerateAssets() async throws -> [UniversalMediaAsset] {
        try await enumerateAssets(batchSize: 100, control: nil, onBatch: { _ in })
    }
    public func enumerateAssets(batchSize: Int, control: LibraryAnalysisControl?, onBatch: @escaping @Sendable ([UniversalMediaAsset]) async -> Void) async throws -> [UniversalMediaAsset] {
        let authorization = await authorizationStatus()
        guard authorization == .authorized || authorization == .limited else {
            throw UniversalScanError.sourcePermissionDenied
        }
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        options.includeHiddenAssets = true
        let fetch = PHAsset.fetchAssets(with: options)
        let albumMemberships = Self.albumMemberships()
        var output: [UniversalMediaAsset] = []
        output.reserveCapacity(fetch.count)
        for index in 0..<fetch.count {
            try Task.checkCancellation(); try await control?.waitIfPaused()
            let asset = fetch.object(at: index)
            guard asset.mediaType == .image || asset.mediaType == .video else { continue }
            let resources = PHAssetResource.assetResources(for: asset)
            let filename = Self.primaryResource(in: resources, mediaType: asset.mediaType)?.originalFilename
                ?? resources.first?.originalFilename ?? (asset.mediaType == .video ? "Video_\(index + 1)" : "Photo_\(index + 1)")
            // PhotoKit has no public size property. Unknown is honest; a completed
            // fingerprint supplies measured bytes without private KVC keys.
            let byteCount: Int64? = nil
            output.append(
                UniversalMediaAsset(
                    id: "photos:\(asset.localIdentifier)",
                    sourceID: source.id,
                    reference: .photoLibrary(localIdentifier: asset.localIdentifier),
                    displayName: filename,
                    mediaKind: asset.mediaType == .video ? .video : .image,
                    byteCount: byteCount,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.mediaType == .video ? asset.duration : nil,
                    creationDate: asset.creationDate,
                    modificationDate: asset.modificationDate,
                    isFavorite: asset.isFavorite,
                    isHidden: asset.isHidden,
                    hasAdjustments: resources.contains { $0.type == .adjustmentData || $0.type == .adjustmentBasePhoto || $0.type == .adjustmentBaseVideo },
                    isSharedLibraryAsset: Self.isSharedAsset(asset),
                    hasAlbumMembership: !(albumMemberships[asset.localIdentifier] ?? []).isEmpty,
                    context: MediaContext(albums: albumMemberships[asset.localIdentifier] ?? [],
                        location: asset.location.map { MediaLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) },
                        captureDate: asset.creationDate, captureTimeIsReliable: true, burstID: asset.burstIdentifier,
                        isLivePhoto: asset.mediaSubtypes.contains(.photoLive), isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot))
                )
            )
            if output.count % max(25, batchSize) == 0 { await onBatch(output) }
        }
        await onBatch(output)
        return output
    }

    public func exactFingerprint(
        for asset: UniversalMediaAsset,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint {
        guard case .photoLibrary(let localIdentifier) = asset.reference else {
            throw UniversalScanError.unsupportedReference
        }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let photo = fetch.firstObject else { throw UniversalScanError.inaccessibleAsset(asset.displayName) }

        return try await Self.withTimeout(seconds: allowNetwork ? 60 : 15) {
            if photo.mediaType == .image {
                return try await Self.fingerprintImage(
                    photo: photo,
                    displayName: asset.displayName,
                    allowNetwork: allowNetwork,
                    progress: progress
                )
            } else if photo.mediaType == .video {
                return try await Self.fingerprintVideo(
                    photo: photo,
                    displayName: asset.displayName,
                    allowNetwork: allowNetwork,
                    progress: progress
                )
            } else {
                throw UniversalScanError.inaccessibleAsset(asset.displayName)
            }
        }
    }

    private static func fingerprintImage(
        photo: PHAsset,
        displayName: String,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint {
        let resources = Self.originalResources(in: PHAssetResource.assetResources(for: photo), mediaType: .image)
        if photo.mediaSubtypes.contains(.photoLive) || resources.count > 1 {
            guard !resources.isEmpty else { throw UniversalScanError.inaccessibleAsset(displayName) }
            if photo.mediaSubtypes.contains(.photoLive), !resources.contains(where: { $0.type == .pairedVideo || $0.type == .fullSizePairedVideo }) {
                throw UniversalScanError.resourceUnavailable(displayName)
            }
            let options = PHAssetResourceRequestOptions(); options.isNetworkAccessAllowed = allowNetwork
            var family = SHA256(), bytes: Int64 = 0
            for resource in resources {
                let accumulator = LockedPhotoHasher()
                try await requestData(for: resource, options: options) { data in _ = accumulator.append(data) }
                let part = accumulator.finish()
                family.update(data: Data("\(resource.type.rawValue)|\(part.byteCount)|\(part.digest)|".utf8))
                bytes += part.byteCount; progress(bytes)
            }
            return UniversalExactFingerprint(algorithm: "photos-family-sha256-v2", digest: family.finalize().map { String(format: "%02x", $0) }.joined(), byteCount: bytes)
        }
        let imgOptions = PHImageRequestOptions()
        imgOptions.isNetworkAccessAllowed = allowNetwork
        imgOptions.isSynchronous = false
        imgOptions.deliveryMode = .highQualityFormat
        let request = CancellablePhotosRequest()
        return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
            let singleShot = SingleShotContinuation(continuation)
            let requestID = PHImageManager.default().requestImageDataAndOrientation(for: photo, options: imgOptions) { data, _, _, info in
                autoreleasepool {
                    if let error = info?[PHImageErrorKey] as? Error {
                        if !allowNetwork && Self.isNetworkAccessRequired(error) {
                            singleShot.resume(throwing: UniversalScanError.networkRequired(displayName))
                        } else if Self.isResourceUnavailable(error) {
                            singleShot.resume(throwing: UniversalScanError.resourceUnavailable(displayName))
                        } else if Self.isDownloadCancelled(error) {
                            singleShot.resume(throwing: UniversalScanError.downloadCancelled(displayName))
                        } else {
                            singleShot.resume(throwing: error)
                        }
                    } else if let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool, isInCloud, !allowNetwork,
                           data == nil || (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                        singleShot.resume(throwing: UniversalScanError.networkRequired(displayName))
                    } else if let data {
                        var hasher = SHA256()
                        hasher.update(data: data)
                        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                        let count = Int64(data.count)
                        progress(count)
                        singleShot.resume(returning: UniversalExactFingerprint(digest: digest, byteCount: count))
                    } else {
                        singleShot.resume(throwing: UniversalScanError.inaccessibleAsset(displayName))
                    }
                }
            }
                request.install(requestID)
            }
            } onCancel: { request.cancel() }
    }

    private static func fingerprintVideo(
        photo: PHAsset,
        displayName: String,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint {
        let vidOptions = PHVideoRequestOptions()
        vidOptions.isNetworkAccessAllowed = allowNetwork
        vidOptions.deliveryMode = .highQualityFormat
        let request = CancellablePhotosRequest()
        let avAsset: AVAsset = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
            let singleShot = SingleShotContinuation(continuation)
            let requestID = PHImageManager.default().requestAVAsset(forVideo: photo, options: vidOptions) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    if !allowNetwork && Self.isNetworkAccessRequired(error) {
                        singleShot.resume(throwing: UniversalScanError.networkRequired(displayName))
                    } else if Self.isResourceUnavailable(error) {
                        singleShot.resume(throwing: UniversalScanError.resourceUnavailable(displayName))
                    } else {
                        singleShot.resume(throwing: error)
                    }
                } else if let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool, isInCloud, !allowNetwork {
                    singleShot.resume(throwing: UniversalScanError.networkRequired(displayName))
                } else if let avAsset {
                    singleShot.resume(returning: avAsset)
                } else {
                    singleShot.resume(throwing: UniversalScanError.inaccessibleAsset(displayName))
                }
            }
                request.install(requestID)
            }
            } onCancel: { request.cancel() }
        if let urlAsset = avAsset as? AVURLAsset {
            return try await StreamingSHA256.file(at: urlAsset.url, progress: progress)
        }
        let availableResources = PHAssetResource.assetResources(for: photo)
        // An edited AVComposition without a current file URL must not be compared
        // to its unedited resource as if those were the bytes the user sees.
        guard !availableResources.contains(where: { $0.type == .adjustmentData || $0.type == .adjustmentBaseVideo }) else {
            throw UniversalScanError.resourceUnavailable(displayName)
        }
        let resources = Self.originalResources(in: availableResources, mediaType: .video)
        guard let primary = resources.first else {
            throw UniversalScanError.inaccessibleAsset(displayName)
        }
        let resOptions = PHAssetResourceRequestOptions()
        resOptions.isNetworkAccessAllowed = allowNetwork
        let accumulator = LockedPhotoHasher()
        try await requestData(for: primary, options: resOptions) { chunk in
            progress(accumulator.append(chunk))
        }
        return accumulator.finish()
    }

    private static func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw UniversalScanError.resourceUnavailable("Timeout after \(Int(seconds))s")
            }
            guard let result = try await group.next() else {
                throw UniversalScanError.resourceUnavailable("No result")
            }
            group.cancelAll()
            return result
        }
    }

    public func assetByteCount(for asset: UniversalMediaAsset) async -> Int64? {
        if let byteCount = asset.byteCount, byteCount > 0 { return byteCount }
        return nil
    }

    private static func isNetworkAccessRequired(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == "PHPhotosErrorDomain" && (ns.code == 3164 || ns.code == 3169) {
            return true
        }
        let desc = ns.localizedDescription.lowercased()
        return desc.contains("network") || desc.contains("icloud") || desc.contains("download")
    }

    private static func isResourceUnavailable(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == "PHPhotosErrorDomain" && ns.code == 3169 {
            return true
        }
        let desc = ns.localizedDescription.lowercased()
        return desc.contains("unavailable") || desc.contains("not available")
    }

    private static func isDownloadCancelled(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == "PHPhotosErrorDomain" && ns.code == 3054 {
            return true
        }
        if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError {
            return true
        }
        let desc = ns.localizedDescription.lowercased()
        return desc.contains("cancelled") || desc.contains("canceled")
    }

    /// Detailed camera/lens/EXIF data is fetched only when a person opens Details.
    public func metadata(for asset: UniversalMediaAsset, allowNetwork: Bool = false) async throws -> DetailedPhotoMetadata {
        guard case .photoLibrary(let id) = asset.reference, asset.mediaKind == .image,
              let photo = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            throw UniversalScanError.unsupportedReference
        }
        return try await withCheckedThrowingContinuation { continuation in
            let singleShot = SingleShotContinuation<DetailedPhotoMetadata>(continuation)
            let options = PHImageRequestOptions(); options.isNetworkAccessAllowed = allowNetwork
            options.deliveryMode = .highQualityFormat; options.version = .current
            PHImageManager.default().requestImageDataAndOrientation(for: photo, options: options) { data, _, _, info in
                if let data, let source = CGImageSourceCreateWithData(data as CFData, nil) {
                    singleShot.resume(returning: PhotoMetadataExtractor.extract(from: source))
                } else {
                    singleShot.resume(throwing: (info?[PHImageErrorKey] as? Error) ?? UniversalScanError.inaccessibleAsset(asset.displayName))
                }
            }
        }
    }

    public func similarityImage(
        for asset: UniversalMediaAsset,
        maximumPixelSize: Int,
        allowNetwork: Bool
    ) async throws -> CGImage {
        guard case .photoLibrary(let localIdentifier) = asset.reference,
              asset.mediaKind == .image,
              let photo = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            throw UniversalScanError.inaccessibleAsset(asset.displayName)
        }
        return try await Self.withTimeout(seconds: 10) {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = allowNetwork
            options.isSynchronous = false
            let targetSize = CGSize(width: maximumPixelSize, height: maximumPixelSize)
            let request = CancellablePhotosRequest()
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                let singleShot = SingleShotContinuation(continuation)
                let requestID = PHImageManager.default().requestImage(
                    for: photo,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, info in
                    autoreleasepool {
                        if let error = info?[PHImageErrorKey] as? Error {
                            if !allowNetwork && Self.isNetworkAccessRequired(error) {
                                singleShot.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                            } else if Self.isResourceUnavailable(error) {
                                singleShot.resume(throwing: UniversalScanError.resourceUnavailable(asset.displayName))
                            } else if Self.isDownloadCancelled(error) {
                                singleShot.resume(throwing: UniversalScanError.downloadCancelled(asset.displayName))
                            } else {
                                singleShot.resume(throwing: error)
                            }
                            return
                        }
                        if let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool, isInCloud, !allowNetwork {
                            singleShot.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                            return
                        }
#if os(macOS)
                        let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
#else
                        let cgImage = Self.orientedPreview(image)
#endif
                        if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                        if let cgImage {
                            singleShot.resume(returning: cgImage)
                        } else {
                            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                            if !isDegraded {
                                singleShot.resume(throwing: UniversalScanError.inaccessibleAsset(asset.displayName))
                            }
                        }
                    }
                }
                request.install(requestID)
            }
            } onCancel: { request.cancel() }
        }
    }

    public func deleteExactAssets(localIdentifiers: [String]) async throws {
        try await deleteSelectedAssets(localIdentifiers: localIdentifiers)
    }

    public func deleteSelectedAssets(localIdentifiers: [String], intent: PhotosRemovalIntent = .suggestedCopies,
                                     reviewedAssets: [UniversalMediaAsset]? = nil) async throws {
        let identifiers = Array(Set(localIdentifiers))
        guard !identifiers.isEmpty else { return }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard fetched.count == identifiers.count else {
            throw UniversalScanError.cleanupNotPermitted("Some Photos items changed after review. Scan again before cleanup.")
        }
        if case .suggestedCopies = intent {
        var protectedNames: [String] = []
        let albumMemberIDs = Self.albumMemberIdentifiers()
        fetched.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if asset.isFavorite || asset.isHidden || Self.isSharedAsset(asset) || albumMemberIDs.contains(asset.localIdentifier) || resources.contains(where: { $0.type == .adjustmentData || $0.type == .adjustmentBasePhoto }) {
                protectedNames.append(resources.first?.originalFilename ?? asset.localIdentifier)
            }
        }
        guard protectedNames.isEmpty else {
            throw UniversalScanError.cleanupNotPermitted("Protected Photos items must be reviewed individually before removal.")
        }
        }
        if let reviewedAssets {
            let reviewedIDs = Set(reviewedAssets.compactMap { item -> String? in
                if case .photoLibrary(let id) = item.reference { return id }; return nil
            })
            guard reviewedIDs == Set(identifiers), reviewedAssets.count == identifiers.count else { throw UnifiedLibraryError.selectionChanged }
            try LibraryRevisionValidator.validate(reviewedAssets)
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(fetched)
        }
    }

    public func similarityVideoSample(
        for asset: UniversalMediaAsset,
        maximumPixelSize: Int,
        allowNetwork: Bool
    ) async throws -> UniversalVideoSimilaritySample {
        guard case .photoLibrary(let localIdentifier) = asset.reference,
              asset.mediaKind == .video,
              let video = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            throw UniversalScanError.inaccessibleAsset(asset.displayName)
        }
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = allowNetwork
        let request = CancellablePhotosRequest()
        let avAsset: AVAsset = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
            let singleShot = SingleShotContinuation(continuation)
            let requestID = PHImageManager.default().requestAVAsset(forVideo: video, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    if !allowNetwork && Self.isNetworkAccessRequired(error) {
                        singleShot.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                    } else if Self.isResourceUnavailable(error) {
                        singleShot.resume(throwing: UniversalScanError.resourceUnavailable(asset.displayName))
                    } else if Self.isDownloadCancelled(error) {
                        singleShot.resume(throwing: UniversalScanError.downloadCancelled(asset.displayName))
                    } else {
                        singleShot.resume(throwing: error)
                    }
                } else if let avAsset {
                    singleShot.resume(returning: avAsset)
                } else if allowNetwork {
                    singleShot.resume(throwing: UniversalScanError.inaccessibleAsset(asset.displayName))
                } else {
                    singleShot.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                }
            }
                request.install(requestID)
            }
            } onCancel: { request.cancel() }
        return try await UniversalVideoFrameSampler.sample(
            avAsset: avAsset,
            maximumPixelSize: maximumPixelSize
        )
    }

    private static func primaryResource(in resources: [PHAssetResource], mediaType: PHAssetMediaType) -> PHAssetResource? {
        let preferred: [PHAssetResourceType] = mediaType == .video
            ? [.fullSizeVideo, .video, .pairedVideo]
            : [.fullSizePhoto, .photo]
        for type in preferred {
            if let resource = resources.first(where: { $0.type == type }) { return resource }
        }
        return resources.first
    }

    private static func originalResources(
        in resources: [PHAssetResource],
        mediaType: PHAssetMediaType
    ) -> [PHAssetResource] {
        let originalTypes: Set<PHAssetResourceType> = mediaType == .video
            ? [.fullSizeVideo, .video, .pairedVideo, .fullSizePairedVideo]
            : [.fullSizePhoto, .photo, .alternatePhoto, .pairedVideo, .fullSizePairedVideo]
        let originals = resources.filter { originalTypes.contains($0.type) }
        let selected = originals.isEmpty ? Array(resources.prefix(1)) : originals
        return selected.sorted {
            if $0.type.rawValue != $1.type.rawValue { return $0.type.rawValue < $1.type.rawValue }
            return $0.originalFilename.localizedStandardCompare($1.originalFilename) == .orderedAscending
        }
    }

    private static func requestData(
        for resource: PHAssetResource,
        options: PHAssetResourceRequestOptions,
        dataReceived: @escaping @Sendable (Data) -> Void
    ) async throws {
        final class RequestBox: @unchecked Sendable {
            private let lock = NSLock()
            private var requestID: PHAssetResourceDataRequestID?
            private var cancelled = false
            func install(_ id: PHAssetResourceDataRequestID) {
                lock.lock(); requestID = id; let pending = cancelled; lock.unlock()
                if pending { PHAssetResourceManager.default().cancelDataRequest(id) }
            }
            func cancel() {
                lock.lock(); cancelled = true; let id = requestID; lock.unlock()
                if let id { PHAssetResourceManager.default().cancelDataRequest(id) }
            }
        }
        let box = RequestBox()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let singleShot = SingleShotContinuation(continuation)
                let requestID = PHAssetResourceManager.default().requestData(
                    for: resource,
                    options: options,
                    dataReceivedHandler: dataReceived,
                    completionHandler: { error in
                        if let error { singleShot.resume(throwing: error) }
                        else { singleShot.resume(returning: ()) }
                    }
                )
                box.install(requestID)
            }
        } onCancel: {
            box.cancel()
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> SourceAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        case .limited: return .limited
        @unknown default: return .unavailable
        }
    }

    private static func albumMemberships() -> [String: [MediaAlbum]] {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var membership: [String: [MediaAlbum]] = [:]
        collections.enumerateObjects { collection, _, _ in
            let album = MediaAlbum(id: collection.localIdentifier, title: collection.localizedTitle ?? "Album")
            let members = PHAsset.fetchAssets(in: collection, options: nil)
            members.enumerateObjects { asset, _, _ in membership[asset.localIdentifier, default: []].append(album) }
        }
        return membership
    }

    private static func albumMemberIdentifiers() -> Set<String> {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var identifiers = Set<String>()
        collections.enumerateObjects { collection, _, _ in
            let members = PHAsset.fetchAssets(in: collection, options: nil)
            members.enumerateObjects { asset, _, _ in identifiers.insert(asset.localIdentifier) }
        }
        return identifiers
    }

    private static func isSharedAsset(_ asset: PHAsset) -> Bool {
#if os(iOS)
        return asset.sourceType.contains(.typeCloudShared)
#else
        return false
#endif
    }
}

#if os(iOS)
import CoreImage
import UIKit
private extension PhotoLibrarySourceAdapter {
    static func orientedPreview(_ image: UIImage?) -> CGImage? {
        guard let image, let cg = image.cgImage else { return nil }
        guard image.imageOrientation != .up else { return cg }
        let orientation: Int32
        switch image.imageOrientation {
        case .up: orientation = 1
        case .upMirrored: orientation = 2
        case .down: orientation = 3
        case .downMirrored: orientation = 4
        case .leftMirrored: orientation = 5
        case .right: orientation = 6
        case .rightMirrored: orientation = 7
        case .left: orientation = 8
        @unknown default: orientation = 1
        }
        let oriented = CIImage(cgImage: cg).oriented(forExifOrientation: orientation)
        return CIContext().createCGImage(oriented, from: oriented.extent)
    }
}
#endif
