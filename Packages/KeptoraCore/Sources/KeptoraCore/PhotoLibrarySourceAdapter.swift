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
        let authorization = await authorizationStatus()
        guard authorization == .authorized || authorization == .limited else {
            throw UniversalScanError.sourcePermissionDenied
        }
        let fetch = PHAsset.fetchAssets(with: nil)
        let albumMemberIDs = Self.albumMemberIdentifiers()
        var output: [UniversalMediaAsset] = []
        output.reserveCapacity(fetch.count)
        for index in 0..<fetch.count {
            try Task.checkCancellation()
            let asset = fetch.object(at: index)
            guard asset.mediaType == .image || asset.mediaType == .video else { continue }
            let resources = PHAssetResource.assetResources(for: asset)
            let primary = Self.primaryResource(in: resources, mediaType: asset.mediaType)
            let hasAdjustments = resources.contains { $0.type == .adjustmentData || $0.type == .adjustmentBasePhoto }
            output.append(
                UniversalMediaAsset(
                    id: "photos:\(asset.localIdentifier)",
                    sourceID: source.id,
                    reference: .photoLibrary(localIdentifier: asset.localIdentifier),
                    displayName: primary?.originalFilename ?? "Photo",
                    mediaKind: asset.mediaType == .video ? .video : .image,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.mediaType == .video ? asset.duration : nil,
                    creationDate: asset.creationDate,
                    modificationDate: asset.modificationDate,
                    isFavorite: asset.isFavorite,
                    isHidden: asset.isHidden,
                    hasAdjustments: hasAdjustments || asset.hasAdjustments,
                    isSharedLibraryAsset: Self.isSharedAsset(asset),
                    hasAlbumMembership: albumMemberIDs.contains(asset.localIdentifier)
                )
            )
        }
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
        let resources = Self.originalResources(
            in: PHAssetResource.assetResources(for: photo),
            mediaType: photo.mediaType
        )
        guard !resources.isEmpty else {
            throw UniversalScanError.inaccessibleAsset(asset.displayName)
        }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = allowNetwork
        if allowNetwork {
            options.progressHandler = { downloadProgress in
                _ = downloadProgress
            }
        }
        let accumulator = LockedPhotoHasher()

        do {
            for resource in resources {
                try Task.checkCancellation()
                let boundary = Data("keptora-resource-v1|\(resource.type.rawValue)|".utf8)
                _ = accumulator.append(boundary, countAsContent: false)
                try await requestData(for: resource, options: options) { data in
                    progress(accumulator.append(data))
                }
            }
            return accumulator.finish()
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            if photo.mediaType == .image {
                let imgOptions = PHImageRequestOptions()
                imgOptions.isNetworkAccessAllowed = allowNetwork
                imgOptions.isSynchronous = false
                imgOptions.deliveryMode = .highQualityFormat
                if let data: Data = try? await withCheckedThrowingContinuation({ continuation in
                    PHImageManager.default().requestImageDataAndOrientation(for: photo, options: imgOptions) { data, _, _, info in
                        if let data { continuation.resume(returning: data) }
                        else if let err = info?[PHImageErrorKey] as? Error { continuation.resume(throwing: err) }
                        else { continuation.resume(throwing: UniversalScanError.inaccessibleAsset(asset.displayName)) }
                    }
                }) {
                    let fallbackHasher = LockedPhotoHasher()
                    _ = fallbackHasher.append(Data("keptora-resource-v1|direct-image|".utf8), countAsContent: false)
                    progress(fallbackHasher.append(data))
                    return fallbackHasher.finish()
                }
            }
            if let cancellation = error as? CancellationError { throw cancellation }
            if Task.isCancelled { throw CancellationError() }
            if !allowNetwork && Self.isNetworkAccessRequired(error) {
                throw UniversalScanError.networkRequired(asset.displayName)
            }
            if Self.isResourceUnavailable(error) {
                throw UniversalScanError.resourceUnavailable(asset.displayName)
            }
            if Self.isDownloadCancelled(error) {
                throw UniversalScanError.downloadCancelled(asset.displayName)
            }
            throw error
        }
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
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowNetwork
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: photo, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    if !allowNetwork && Self.isNetworkAccessRequired(error) {
                        continuation.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                    } else if Self.isResourceUnavailable(error) {
                        continuation.resume(throwing: UniversalScanError.resourceUnavailable(asset.displayName))
                    } else if Self.isDownloadCancelled(error) {
                        continuation.resume(throwing: UniversalScanError.downloadCancelled(asset.displayName))
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                }
            }
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else {
            throw UniversalScanError.inaccessibleAsset(asset.displayName)
        }
        return image
    }

    public func deleteExactAssets(localIdentifiers: [String]) async throws {
        try await deleteSelectedAssets(localIdentifiers: localIdentifiers)
    }

    public func deleteSelectedAssets(localIdentifiers: [String]) async throws {
        let identifiers = Array(Set(localIdentifiers))
        guard !identifiers.isEmpty else { return }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard fetched.count == identifiers.count else {
            throw UniversalScanError.cleanupNotPermitted("Some Photos items changed after review. Scan again before cleanup.")
        }
        var protectedNames: [String] = []
        let albumMemberIDs = Self.albumMemberIdentifiers()
        fetched.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if asset.isFavorite || asset.isHidden || asset.hasAdjustments || Self.isSharedAsset(asset) || albumMemberIDs.contains(asset.localIdentifier) || resources.contains(where: { $0.type == .adjustmentData || $0.type == .adjustmentBasePhoto }) {
                protectedNames.append(resources.first?.originalFilename ?? asset.localIdentifier)
            }
        }
        guard protectedNames.isEmpty else {
            throw UniversalScanError.cleanupNotPermitted("Protected Photos items must be reviewed individually before removal.")
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
        let avAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: video, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    if !allowNetwork && Self.isNetworkAccessRequired(error) {
                        continuation.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                    } else if Self.isResourceUnavailable(error) {
                        continuation.resume(throwing: UniversalScanError.resourceUnavailable(asset.displayName))
                    } else if Self.isDownloadCancelled(error) {
                        continuation.resume(throwing: UniversalScanError.downloadCancelled(asset.displayName))
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let avAsset {
                    continuation.resume(returning: avAsset)
                } else if allowNetwork {
                    continuation.resume(throwing: UniversalScanError.inaccessibleAsset(asset.displayName))
                } else {
                    continuation.resume(throwing: UniversalScanError.networkRequired(asset.displayName))
                }
            }
        }
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

    private func requestData(
        for resource: PHAssetResource,
        options: PHAssetResourceRequestOptions,
        dataReceived: @escaping @Sendable (Data) -> Void
    ) async throws {
        final class RequestBox: @unchecked Sendable {
            var requestID: PHAssetResourceDataRequestID?
        }
        let box = RequestBox()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                box.requestID = PHAssetResourceManager.default().requestData(
                    for: resource,
                    options: options,
                    dataReceivedHandler: dataReceived,
                    completionHandler: { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: ()) }
                    }
                )
            }
        } onCancel: {
            if let id = box.requestID {
                PHAssetResourceManager.default().cancelDataRequest(id)
            }
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
        return asset.sourceType != .typeUserLibrary
#else
        return false
#endif
    }
}
