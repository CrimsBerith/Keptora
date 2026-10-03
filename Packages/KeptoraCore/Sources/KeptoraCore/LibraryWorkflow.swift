import Foundation

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
