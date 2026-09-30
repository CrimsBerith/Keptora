import Foundation
import Photos

private final class LockedByteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64 = 0

    func add(_ count: Int) {
        lock.lock()
        value += Int64(count)
        lock.unlock()
    }

    func snapshot() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

struct PhotoResourceProbe: Hashable, Sendable {
    let localIdentifier: String
    let resourceCount: Int
    let originalFilename: String?
    let uniformTypeIdentifier: String?
    let locallyReadableBytes: Int64?
    let requiresNetwork: Bool
}

actor PhotoLibraryAdapter {
    func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func assetCount() -> Int {
        PHAsset.fetchAssets(with: nil).count
    }

    func localIdentifiers(limit: Int? = nil) -> [String] {
        let assets = PHAsset.fetchAssets(with: nil)
        let count = min(limit ?? assets.count, assets.count)
        var identifiers: [String] = []
        identifiers.reserveCapacity(count)
        for index in 0..<count { identifiers.append(assets.object(at: index).localIdentifier) }
        return identifiers
    }

    func probeOriginalResource(localIdentifier: String, allowNetwork: Bool = false) async throws -> PhotoResourceProbe {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else {
            return PhotoResourceProbe(
                localIdentifier: localIdentifier,
                resourceCount: 0,
                originalFilename: nil,
                uniformTypeIdentifier: nil,
                locallyReadableBytes: nil,
                requiresNetwork: false
            )
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let original = resources.first(where: { $0.type == .photo || $0.type == .video || $0.type == .fullSizePhoto || $0.type == .fullSizeVideo }) ?? resources.first else {
            return PhotoResourceProbe(
                localIdentifier: localIdentifier,
                resourceCount: 0,
                originalFilename: nil,
                uniformTypeIdentifier: nil,
                locallyReadableBytes: nil,
                requiresNetwork: false
            )
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = allowNetwork
        let byteCounter = LockedByteCounter()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHAssetResourceManager.default().requestData(
                    for: original,
                    options: options,
                    dataReceivedHandler: { data in byteCounter.add(data.count) },
                    completionHandler: { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: ()) }
                    }
                )
            }
            return PhotoResourceProbe(
                localIdentifier: localIdentifier,
                resourceCount: resources.count,
                originalFilename: original.originalFilename,
                uniformTypeIdentifier: original.uniformTypeIdentifier,
                locallyReadableBytes: byteCounter.snapshot(),
                requiresNetwork: false
            )
        } catch {
            return PhotoResourceProbe(
                localIdentifier: localIdentifier,
                resourceCount: resources.count,
                originalFilename: original.originalFilename,
                uniformTypeIdentifier: original.uniformTypeIdentifier,
                locallyReadableBytes: nil,
                requiresNetwork: !allowNetwork
            )
        }
    }

    // Phase 5J safety boundary: this adapter intentionally exposes no mutation or deletion API.
}
