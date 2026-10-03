import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Photos)
@preconcurrency import Photos
#endif

public enum LibraryRevisionValidator {
    /// Check the metadata revision the user actually reviewed before hashing or
    /// starting either kind of removal. This also covers manual archive choices.
    public static func validate(_ assets: [UniversalMediaAsset]) throws {
        for asset in assets {
            switch asset.reference {
            case .file(let url):
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                if let date = asset.modificationDate, values.contentModificationDate != date { throw UnifiedLibraryError.selectionChanged }
                if let size = asset.byteCount, values.fileSize.map(Int64.init) != size { throw UnifiedLibraryError.selectionChanged }
            case .photoLibrary(let id):
                #if canImport(Photos)
                guard let current = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
                      current.modificationDate == asset.modificationDate,
                      current.isFavorite == asset.isFavorite,
                      current.isHidden == asset.isHidden else { throw UnifiedLibraryError.selectionChanged }
                #else
                throw UnifiedLibraryError.sourceUnavailable(asset.sourceID)
                #endif
            }
        }
    }
}

public struct LibrarySourceCoverage: Equatable, Sendable, Identifiable {
    public var id: String { source.id }
    public let source: LibrarySource
    public let authorization: SourceAuthorization
    public let itemCount: Int
    public let error: String?
}

public enum UnifiedLibraryError: LocalizedError {
    case sourceUnavailable(String)
    case selectionChanged
    public var errorDescription: String? {
        switch self {
        case .sourceUnavailable: return NSLocalizedString("A connected source is unavailable. Reconnect it and try again.", comment: "Unavailable library source")
        case .selectionChanged: return NSLocalizedString("Your selection changed. Review it again before removing items.", comment: "Stale selected item")
        }
    }
}

/// Routes each item to its owning adapter. Enumeration failure in one source does
/// not hide accessible items in another; callers must display `coverage`.
public actor UnifiedLibraryAdapter: SourceAdapter {
    public nonisolated let source: LibrarySource
    public nonisolated let capabilities = PlatformCapabilities(exactScan: true, similarityReview: true,
        cleanupMode: .unavailable, canRestoreInApp: false, mayRequireNetworkDownload: true, canRevealInFileBrowser: false)
    private let adapters: [any SourceAdapter]
    public private(set) var coverage: [LibrarySourceCoverage] = []

    public init(adapters: [any SourceAdapter]) {
        self.adapters = adapters.sorted {
            if ($0.source.kind == .photos) != ($1.source.kind == .photos) { return $0.source.kind == .photos }
            return $0.source.id < $1.source.id
        }
        self.source = LibrarySource(id: "unified-v2:" + StableDigest.fnv1a64(adapters.map { $0.source.id }.sorted().joined(separator: "|")), kind: .photos, displayName: "All Connected Sources")
    }
    public func authorizationStatus() async -> SourceAuthorization { adapters.isEmpty ? .unavailable : .authorized }
    public func requestAuthorization() async -> SourceAuthorization { await authorizationStatus() }
    public func enumerateAssets() async throws -> [UniversalMediaAsset] {
        var items: [UniversalMediaAsset] = [], reports: [LibrarySourceCoverage] = []
        for adapter in adapters {
            try Task.checkCancellation()
            let auth = await adapter.authorizationStatus()
            guard auth == .authorized || auth == .limited else {
                reports.append(.init(source: adapter.source, authorization: auth, itemCount: 0, error: "Source access is unavailable")); continue
            }
            do {
                let batch = try await adapter.enumerateAssets()
                items.append(contentsOf: batch)
                let warnings = await adapter.enumerationWarnings()
                reports.append(.init(source: adapter.source, authorization: auth, itemCount: batch.count, error: warnings.isEmpty ? nil : warnings.joined(separator: "\n")))
            } catch is CancellationError { throw CancellationError() }
            catch { reports.append(.init(source: adapter.source, authorization: auth, itemCount: 0, error: error.localizedDescription)) }
        }
        coverage = reports
        return Self.uniqueReferences(items)
    }
    /// An album or overlapping folder is another view of the same item. Separate
    /// file copies and Photos exports remain separate so cross-source copies exist.
    public nonisolated static func uniqueReferences(_ items: [UniversalMediaAsset]) -> [UniversalMediaAsset] {
        var seen: Set<MediaAssetReference> = []
        return items.filter { item in
            let key: MediaAssetReference
            switch item.reference {
            case .file(let url): key = .file(url.standardizedFileURL.resolvingSymlinksInPath())
            case .photoLibrary: key = item.reference
            }
            return seen.insert(key).inserted
        }
    }
    private func owner(_ asset: UniversalMediaAsset) throws -> any SourceAdapter {
        guard let adapter = adapters.first(where: { $0.source.id == asset.sourceID }) else { throw UnifiedLibraryError.sourceUnavailable(asset.sourceID) }
        return adapter
    }
    public func exactFingerprint(for asset: UniversalMediaAsset, allowNetwork: Bool, progress: @escaping @Sendable (Int64) -> Void) async throws -> UniversalExactFingerprint {
        try await owner(asset).exactFingerprint(for: asset, allowNetwork: allowNetwork, progress: progress)
    }
    public func assetByteCount(for asset: UniversalMediaAsset) async -> Int64? {
        guard let adapter = try? owner(asset) else { return nil }
        return await adapter.assetByteCount(for: asset)
    }
}

#if canImport(CoreGraphics)
extension UnifiedLibraryAdapter: SimilarityImageProviding, SimilarityVideoProviding {
    public func similarityImage(for asset: UniversalMediaAsset, maximumPixelSize: Int, allowNetwork: Bool) async throws -> CGImage {
        guard let provider = try owner(asset) as? any SimilarityImageProviding else { throw UnifiedLibraryError.sourceUnavailable(asset.sourceID) }
        return try await provider.similarityImage(for: asset, maximumPixelSize: maximumPixelSize, allowNetwork: allowNetwork)
    }
    public func similarityVideoSample(for asset: UniversalMediaAsset, maximumPixelSize: Int, allowNetwork: Bool) async throws -> UniversalVideoSimilaritySample {
        guard let provider = try owner(asset) as? any SimilarityVideoProviding else { throw UnifiedLibraryError.sourceUnavailable(asset.sourceID) }
        return try await provider.similarityVideoSample(for: asset, maximumPixelSize: maximumPixelSize, allowNetwork: allowNetwork)
    }
}
#endif

public struct LibraryReviewGroup: Identifiable, Sendable {
    public enum Kind: Sendable { case exact, similar }
    public let id: String
    public let kind: Kind
    public let assets: [UniversalMediaAsset]
    public let keeperID: String
    public static func combined(exact: [UniversalExactGroup], similar: [UniversalSimilarityGroup]) -> [Self] {
        let exactSets = exact.map { Set($0.assets.map(\.id)) }
        return exact.map { Self(id: $0.id, kind: .exact, assets: $0.assets, keeperID: $0.keeperID) } + similar.filter { group in
            let ids = Set(group.assets.map(\.id))
            return !exactSets.contains { ids.isSubset(of: $0) }
        }.map { Self(id: $0.id, kind: .similar, assets: $0.assets, keeperID: $0.keeperID) }
    }
}

extension UniversalMediaAsset {
    public func sourceLabel(in sources: [LibrarySource], whatsAppAlbumIDs: Set<String> = []) -> String {
        let source = sources.first { $0.id == sourceID }
        switch reference {
        case .photoLibrary:
            let whatsapp = context?.albums.contains { $0.isWhatsAppNamed || whatsAppAlbumIDs.contains($0.id) } == true
            #if os(Linux)
            return NSLocalizedString(whatsapp ? "WhatsApp · Photos" : "Photos / iCloud Photos", comment: "Photo source badge")
            #else
            return L10n.tr(whatsapp ? "WhatsApp · Photos" : "Photos / iCloud Photos")
            #endif
        case .file(let url):
            #if os(Linux)
            let prefix = NSLocalizedString(source?.kind == .fileProvider || requiresNetwork ? "Cloud Files" : "Files", comment: "File source badge")
            #else
            let prefix = L10n.tr(source?.kind == .fileProvider || requiresNetwork ? "Cloud Files" : "Files")
            #endif
            return prefix + " · " + (source?.displayName ?? url.deletingLastPathComponent().lastPathComponent)
        }
    }
}

/// Context helps a person compare media. It never constitutes proof of a duplicate.
public struct MediaLocation: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    public func distance(to other: MediaLocation) -> Double {
        let radians = Double.pi / 180
        let dLat = (other.latitude - latitude) * radians
        let dLon = (other.longitude - longitude) * radians
        let a = pow(sin(dLat / 2), 2) + cos(latitude * radians) * cos(other.latitude * radians) * pow(sin(dLon / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, a)), sqrt(max(0, 1 - a)))
    }
}

public struct MediaAlbum: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
    /// An album name is a collection label, not authenticated app provenance.
    public var isWhatsAppNamed: Bool {
        title.lowercased().replacingOccurrences(of: " ", with: "").contains("whatsapp")
    }
}

public struct MediaContext: Hashable, Codable, Sendable {
    public var albums: [MediaAlbum]
    public var location: MediaLocation?
    public var captureDate: Date?
    public var captureTimeIsReliable: Bool
    public var captureDateText: String?
    public var camera: String?
    public var burstID: String?
    public var isLivePhoto: Bool
    public var isScreenshot: Bool
    public init(albums: [MediaAlbum] = [], location: MediaLocation? = nil, captureDate: Date? = nil,
                captureTimeIsReliable: Bool = false, camera: String? = nil, burstID: String? = nil,
                isLivePhoto: Bool = false, isScreenshot: Bool = false, captureDateText: String? = nil) {
        self.albums = albums; self.location = location; self.captureDate = captureDate
        self.captureTimeIsReliable = captureTimeIsReliable; self.camera = camera; self.burstID = burstID
        self.isLivePhoto = isLivePhoto; self.isScreenshot = isScreenshot; self.captureDateText = captureDateText
    }
}

public struct SimilarityContext: Equatable, Sendable {
    public let secondsApart: TimeInterval?
    public let metersApart: Double?
    public let sameBurst: Bool
    public init(_ lhs: UniversalMediaAsset, _ rhs: UniversalMediaAsset) {
        if let a = lhs.context?.captureDate, let b = rhs.context?.captureDate,
           lhs.context?.captureTimeIsReliable == true, rhs.context?.captureTimeIsReliable == true {
            secondsApart = abs(a.timeIntervalSince(b))
        } else { secondsApart = nil }
        if let a = lhs.context?.location, let b = rhs.context?.location { metersApart = a.distance(to: b) }
        else { metersApart = nil }
        sameBurst = lhs.context?.burstID != nil && lhs.context?.burstID == rhs.context?.burstID
    }
    /// Context can rank visually valid candidates, but cannot make a visual mismatch eligible.
    public func rankingAdjustment(visualDistance: Float, threshold: Float) -> Float {
        guard visualDistance < threshold else { return 0 }
        var result: Float = 0
        if sameBurst { result += 0.025 }
        if let secondsApart, secondsApart <= 60 { result += 0.015 }
        if let metersApart, metersApart <= 100 { result += 0.01 }
        return result
    }
}

public struct LibrarySelection: Equatable, Sendable {
    public private(set) var ids: Set<String>
    public init(ids: Set<String> = []) { self.ids = ids }
    public mutating func toggle(_ id: String) {
        if !ids.insert(id).inserted { ids.remove(id) }
    }
    public mutating func select(_ assets: [UniversalMediaAsset]) { ids.formUnion(assets.map(\.id)) }
    public mutating func reconcile(with assets: [UniversalMediaAsset]) { ids.formIntersection(assets.map(\.id)) }
    public func assets(in catalogue: [UniversalMediaAsset]) -> [UniversalMediaAsset] {
        catalogue.filter { ids.contains($0.id) }
    }
    public func hiddenCount(in visible: [UniversalMediaAsset]) -> Int {
        ids.subtracting(visible.map(\.id)).count
    }
}

public struct MediaSelectionSummary: Equatable, Sendable {
    public let photos: Int
    public let videos: Int
    public let knownBytes: Int64
    public let unknownSizeCount: Int
    public let personalItems: Int
    public init(_ assets: [UniversalMediaAsset]) {
        photos = assets.filter { $0.mediaKind == .image }.count
        videos = assets.count - photos
        knownBytes = assets.reduce(0) { $0 + max(0, $1.byteCount ?? 0) }
        unknownSizeCount = assets.filter { $0.byteCount == nil }.count
        personalItems = assets.filter { $0.isProtectedFromGlobalSelection }.count
    }
}

public enum PhotosRemovalIntent: Sendable {
    case suggestedCopies
    case manualSelection
}

public extension UniversalMediaAsset {
    /// Offset-free EXIF is shown verbatim rather than shifted to the device zone.
    var captureDateDescription: String? {
        guard let context, let date = context.captureDate else { return nil }
        if context.captureTimeIsReliable { return date.formatted(date: .abbreviated, time: .shortened) }
        if let recorded = context.captureDateText { return recorded }
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
