import Foundation
import CoreGraphics

public struct LibrarySource: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case photos
        case folder
        case externalVolume
        case fileProvider
    }

    public let id: String
    public let kind: Kind
    public let displayName: String

    public init(id: String, kind: Kind, displayName: String) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
    }

    public static let photos = LibrarySource(
        id: "photos-system-library",
        kind: .photos,
        displayName: "Apple Photos"
    )
}

public enum CleanupExecutionMode: String, Codable, Sendable {
    case unavailable
    case folderQuarantine
    case photosRecentlyDeleted
}

public struct PlatformCapabilities: Hashable, Codable, Sendable {
    public let exactScan: Bool
    public let similarityReview: Bool
    public let cleanupMode: CleanupExecutionMode
    public let canRestoreInApp: Bool
    public let mayRequireNetworkDownload: Bool
    public let canRevealInFileBrowser: Bool

    public init(
        exactScan: Bool,
        similarityReview: Bool,
        cleanupMode: CleanupExecutionMode,
        canRestoreInApp: Bool,
        mayRequireNetworkDownload: Bool,
        canRevealInFileBrowser: Bool
    ) {
        self.exactScan = exactScan
        self.similarityReview = similarityReview
        self.cleanupMode = cleanupMode
        self.canRestoreInApp = canRestoreInApp
        self.mayRequireNetworkDownload = mayRequireNetworkDownload
        self.canRevealInFileBrowser = canRevealInFileBrowser
    }

    public static let photos = PlatformCapabilities(
        exactScan: true,
        similarityReview: true,
        cleanupMode: .photosRecentlyDeleted,
        canRestoreInApp: false,
        mayRequireNetworkDownload: true,
        canRevealInFileBrowser: false
    )
}

public enum MediaAssetReference: Hashable, Codable, Sendable {
    case file(URL)
    case photoLibrary(localIdentifier: String)
}

public enum UniversalMediaKind: String, Codable, Sendable {
    case image
    case video
}

public struct UniversalMediaAsset: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let sourceID: String
    public let reference: MediaAssetReference
    public let displayName: String
    public let mediaKind: UniversalMediaKind
    public let byteCount: Int64?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let duration: TimeInterval?
    public let creationDate: Date?
    public let modificationDate: Date?
    public let isFavorite: Bool
    public let isHidden: Bool
    public let hasAdjustments: Bool
    public let isSharedLibraryAsset: Bool
    public let hasAlbumMembership: Bool
    public let requiresNetwork: Bool

    public init(
        id: String,
        sourceID: String,
        reference: MediaAssetReference,
        displayName: String,
        mediaKind: UniversalMediaKind,
        byteCount: Int64? = nil,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        duration: TimeInterval? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        hasAdjustments: Bool = false,
        isSharedLibraryAsset: Bool = false,
        hasAlbumMembership: Bool = false,
        requiresNetwork: Bool = false
    ) {
        self.id = id
        self.sourceID = sourceID
        self.reference = reference
        self.displayName = displayName
        self.mediaKind = mediaKind
        self.byteCount = byteCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.hasAdjustments = hasAdjustments
        self.isSharedLibraryAsset = isSharedLibraryAsset
        self.hasAlbumMembership = hasAlbumMembership
        self.requiresNetwork = requiresNetwork
    }

    public var isProtectedFromGlobalSelection: Bool {
        isFavorite || isHidden || hasAdjustments || isSharedLibraryAsset || hasAlbumMembership
    }
}

public struct UniversalExactFingerprint: Hashable, Codable, Sendable {
    public let algorithm: String
    public let digest: String
    public let byteCount: Int64

    public init(algorithm: String = "sha256-v1", digest: String, byteCount: Int64) {
        self.algorithm = algorithm
        self.digest = digest
        self.byteCount = byteCount
    }
}

public enum UniversalKeeperPolicy: Sendable {
    /// Evaluates which asset is superior as the preserved keeper.
    /// Returns true if `lhs` is preferred over `rhs`.
    public static func prefersAsKeeper(_ lhs: UniversalMediaAsset, _ rhs: UniversalMediaAsset) -> Bool {
        // 1. User intent & protection flags (Favorites, edits, album placement)
        let lhsScore = qualityScore(for: lhs)
        let rhsScore = qualityScore(for: rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }
        
        // 2. Higher Resolution (Total Megapixels)
        let lhsPixels = lhs.pixelWidth * lhs.pixelHeight
        let rhsPixels = rhs.pixelWidth * rhs.pixelHeight
        if lhsPixels != rhsPixels {
            return lhsPixels > rhsPixels
        }
        
        // 3. Higher File Size / Fidelity (Uncompressed / Less lossy compression)
        let lhsBytes = lhs.byteCount ?? 0
        let rhsBytes = rhs.byteCount ?? 0
        if lhsBytes != rhsBytes {
            return lhsBytes > rhsBytes
        }
        
        // 4. Video duration (prefer full uncut version)
        if let lhsDur = lhs.duration, let rhsDur = rhs.duration, abs(lhsDur - rhsDur) > 0.1 {
            return lhsDur > rhsDur
        }
        
        // 5. Earliest creation date (original authentic capture)
        let lhsDate = lhs.creationDate ?? lhs.modificationDate ?? .distantFuture
        let rhsDate = rhs.creationDate ?? rhs.modificationDate ?? .distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        
        // 6. Stable alphabetical tie-breaker
        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    public static func qualityScore(for asset: UniversalMediaAsset) -> Int {
        var score = 0
        if asset.isFavorite { score += 10_000 }
        if asset.hasAdjustments { score += 5_000 }
        if asset.hasAlbumMembership { score += 3_000 }
        if asset.isSharedLibraryAsset { score += 2_000 }
        if asset.isHidden { score += 1_000 }
        
        let ext = (asset.displayName as NSString).pathExtension.lowercased()
        if ["cr2", "cr3", "nef", "arw", "dng", "raw", "raf", "orf", "rw2"].contains(ext) {
            score += 800
        }
        return score
    }
}

public struct UniversalExactGroup: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let digest: String
    public let assets: [UniversalMediaAsset]
    public let keeperID: String

    public init(digest: String, assets: [UniversalMediaAsset], keeperID: String? = nil) {
        let ordered = assets.sorted(by: UniversalKeeperPolicy.prefersAsKeeper)
        self.id = "exact:\(digest)"
        self.digest = digest
        self.assets = ordered
        self.keeperID = keeperID ?? ordered.first?.id ?? ""
    }

    public var keeper: UniversalMediaAsset? { assets.first { $0.id == keeperID } }
    public var safeCopies: [UniversalMediaAsset] {
        assets.filter { $0.id != keeperID && !$0.isProtectedFromGlobalSelection }
    }
    public var reclaimableBytes: Int64 {
        safeCopies.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }
}

public struct UniversalSimilarityGroup: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let assets: [UniversalMediaAsset]
    public let maximumDistance: Float
    public let mediaKind: UniversalMediaKind
    public let keeperID: String

    public init(
        id: String,
        assets: [UniversalMediaAsset],
        maximumDistance: Float,
        mediaKind: UniversalMediaKind? = nil,
        keeperID: String? = nil
    ) {
        let ordered = assets.sorted(by: UniversalKeeperPolicy.prefersAsKeeper)
        self.id = id
        self.assets = ordered
        self.maximumDistance = maximumDistance
        self.mediaKind = mediaKind ?? ordered.first?.mediaKind ?? .image
        self.keeperID = keeperID ?? ordered.first?.id ?? ""
    }

    public var keeper: UniversalMediaAsset? { assets.first { $0.id == keeperID } }
    public var safeCandidates: [UniversalMediaAsset] {
        assets.filter { $0.id != keeperID && !$0.isProtectedFromGlobalSelection }
    }
    public var selectableBytes: Int64 {
        safeCandidates.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }
}

public struct UniversalVideoSimilaritySample: @unchecked Sendable {
    public let duration: TimeInterval
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let frames: [CGImage]

    public init(duration: TimeInterval, pixelWidth: Int, pixelHeight: Int, frames: [CGImage]) {
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.frames = frames
    }
}

public enum SourceAuthorization: String, Codable, Sendable {
    case notDetermined
    case denied
    case restricted
    case limited
    case authorized
    case unavailable
}

public protocol SourceAdapter: Sendable {
    var source: LibrarySource { get }
    var capabilities: PlatformCapabilities { get }
    func authorizationStatus() async -> SourceAuthorization
    func requestAuthorization() async -> SourceAuthorization
    func enumerateAssets() async throws -> [UniversalMediaAsset]
    func exactFingerprint(
        for asset: UniversalMediaAsset,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint
}

public protocol SimilarityImageProviding: Sendable {
    func similarityImage(
        for asset: UniversalMediaAsset,
        maximumPixelSize: Int,
        allowNetwork: Bool
    ) async throws -> CGImage
}

public protocol SimilarityVideoProviding: Sendable {
    func similarityVideoSample(
        for asset: UniversalMediaAsset,
        maximumPixelSize: Int,
        allowNetwork: Bool
    ) async throws -> UniversalVideoSimilaritySample
}

public struct DashboardSnapshot: Hashable, Codable, Sendable {
    public let scannedItems: Int
    public let exactGroups: Int
    public let safeCopies: Int
    public let potentialRecoveryBytes: Int64

    public init(scannedItems: Int, groups: [UniversalExactGroup]) {
        self.scannedItems = scannedItems
        self.exactGroups = groups.count
        self.safeCopies = groups.reduce(0) { $0 + $1.safeCopies.count }
        self.potentialRecoveryBytes = groups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    public static let empty = DashboardSnapshot(scannedItems: 0, groups: [])
}
