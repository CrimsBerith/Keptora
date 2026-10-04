import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Photos)
@preconcurrency import Photos
#endif

public enum LibraryAccessPolicy {
    public static func needsStartupSetup(introductionCompleted: Bool, setupCompleted: Bool) -> Bool {
        introductionCompleted && !setupCompleted
    }

    /// A denied, restricted or limited permission must never trigger another automatic prompt.
    public static func shouldRequestPhotosAtStartup(_ authorization: SourceAuthorization) -> Bool {
        authorization == .notDetermined
    }
}

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
    public init(source: LibrarySource, authorization: SourceAuthorization, itemCount: Int, error: String? = nil) {
        self.source = source; self.authorization = authorization; self.itemCount = itemCount; self.error = error
    }
    public var statusKey: String {
        if authorization == .limited { return error == nil ? "Limited Photos access" : "Some items unavailable" }
        if authorization != .authorized { return "Access unavailable" }
        return error == nil ? "Access granted" : "Some items unavailable"
    }
}

public extension LibrarySource {
    var scanTitle: String { kind == .photos ? "Photos / iCloud Photos" : displayName }
    var localizedScanTitle: String {
        guard kind == .photos else { return displayName }
        #if os(Linux)
        return NSLocalizedString("Photos / iCloud Photos", comment: "Photos source")
        #else
        return L10n.tr("Photos / iCloud Photos")
        #endif
    }
    var scanSymbol: String {
        switch kind {
        case .photos: return "photo.on.rectangle.angled"
        case .fileProvider: return "icloud"
        case .externalVolume: return "externaldrive"
        case .folder: return "folder"
        }
    }
}

/// Exclusions preserve the user's choices while newly connected sources start selected.
public struct LibrarySourceSelection: Equatable, Codable, Sendable {
    public enum State: Sendable { case none, some, all }
    public private(set) var excludedIDs: Set<String>
    public init(excludedIDs: Set<String> = []) { self.excludedIDs = excludedIDs }
    public func selectedIDs(in sources: [LibrarySource], coverage: [LibrarySourceCoverage]) -> Set<String> {
        Set(sources.filter { source in
            guard !excludedIDs.contains(source.id) else { return false }
            guard let report = coverage.first(where: { $0.id == source.id }) else { return true }
            return report.authorization == .authorized || report.authorization == .limited
        }.map(\.id))
    }
    public func state(in sources: [LibrarySource], coverage: [LibrarySourceCoverage]) -> State {
        let available = Self().selectedIDs(in: sources, coverage: coverage)
        let selected = selectedIDs(in: sources, coverage: coverage)
        if selected.isEmpty { return .none }
        return selected == available ? .all : .some
    }
    public mutating func setSelected(_ selected: Bool, id: String) {
        if selected { excludedIDs.remove(id) } else { excludedIDs.insert(id) }
    }
    public mutating func toggleAll(in sources: [LibrarySource], coverage: [LibrarySourceCoverage]) {
        let select = state(in: sources, coverage: coverage) != .all
        for id in Self().selectedIDs(in: sources, coverage: coverage) { setSelected(select, id: id) }
    }
}

/// Keep membership before deduplication: an overlapping folder remains usable when
/// the other folder is unchecked. Real copies at separate paths remain separate.
public struct LibrarySourceCatalogue: Sendable {
    public private(set) var batches: [String: [UniversalMediaAsset]]
    public init(batches: [String: [UniversalMediaAsset]] = [:]) { self.batches = batches }
    public mutating func merge(_ other: Self) {
        for (id, items) in other.batches { batches[id] = items }
    }
    public func assets(in sources: [LibrarySource], selectedIDs: Set<String>, current: [UniversalMediaAsset]? = nil) -> [UniversalMediaAsset] {
        let ordered = sources.sorted {
            if ($0.kind == .photos) != ($1.kind == .photos) { return $0.kind == .photos }
            return $0.id < $1.id
        }
        let latest = current.map { Dictionary($0.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
        let items = ordered.filter { selectedIDs.contains($0.id) }.flatMap { source in
            (batches[source.id] ?? current?.filter { $0.sourceID == source.id } ?? []).compactMap { item -> UniversalMediaAsset? in
                guard let latest else { return item }
                guard let updated = latest[item.id] else { return nil }
                return updated.with(sourceID: item.sourceID, reference: item.reference)
            }
        }
        return UnifiedLibraryAdapter.uniqueReferences(items)
    }
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
    public private(set) var catalogue = LibrarySourceCatalogue()

    public init(adapters: [any SourceAdapter], selectedSourceIDs: Set<String>? = nil) {
        let scoped = adapters.filter { selectedSourceIDs?.contains($0.source.id) ?? true }
        self.adapters = scoped.sorted {
            if ($0.source.kind == .photos) != ($1.source.kind == .photos) { return $0.source.kind == .photos }
            return $0.source.id < $1.source.id
        }
        self.source = LibrarySource(id: "unified-v2:" + StableDigest.fnv1a64(scoped.map { $0.source.id }.sorted().joined(separator: "|")), kind: .photos, displayName: "All Connected Sources")
    }
    public func authorizationStatus() async -> SourceAuthorization { adapters.isEmpty ? .unavailable : .authorized }
    public func requestAuthorization() async -> SourceAuthorization { await authorizationStatus() }
    public func enumerateAssets() async throws -> [UniversalMediaAsset] {
        try await enumerateAssets(onSourceBatch: nil)
    }
    public func enumerateAssets(onSourceBatch: (@Sendable ([UniversalMediaAsset], [LibrarySourceCoverage], LibrarySourceCatalogue) async -> Void)?) async throws -> [UniversalMediaAsset] {
        var items: [UniversalMediaAsset] = [], reports: [LibrarySourceCoverage] = []
        var batches: [String: [UniversalMediaAsset]] = [:]
        for adapter in adapters {
            try Task.checkCancellation()
            batches[adapter.source.id] = []
            let auth = await adapter.authorizationStatus()
            guard auth == .authorized || auth == .limited else {
                reports.append(.init(source: adapter.source, authorization: auth, itemCount: 0, error: "Source access is unavailable"))
                coverage = reports; catalogue = LibrarySourceCatalogue(batches: batches)
                await onSourceBatch?(Self.uniqueReferences(items), reports, catalogue)
                continue
            }
            do {
                let batch = try await adapter.enumerateAssets()
                items.append(contentsOf: batch)
                batches[adapter.source.id] = Self.uniqueReferences(batch)
                let warnings = await adapter.enumerationWarnings()
                reports.append(.init(source: adapter.source, authorization: auth, itemCount: batches[adapter.source.id]?.count ?? 0, error: warnings.isEmpty ? nil : warnings.joined(separator: "\n")))
            } catch is CancellationError { throw CancellationError() }
            catch { reports.append(.init(source: adapter.source, authorization: auth, itemCount: 0, error: error.localizedDescription)) }
            coverage = reports; catalogue = LibrarySourceCatalogue(batches: batches)
            await onSourceBatch?(Self.uniqueReferences(items), reports, catalogue)
        }
        coverage = reports
        catalogue = LibrarySourceCatalogue(batches: batches)
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
        guard let provider = try owner(asset) as? any SimilarityImageProviding else { throw UniversalScanError.unsupportedReference }
        return try await provider.similarityImage(for: asset, maximumPixelSize: maximumPixelSize, allowNetwork: allowNetwork)
    }
    public func similarityVideoSample(for asset: UniversalMediaAsset, maximumPixelSize: Int, allowNetwork: Bool) async throws -> UniversalVideoSimilaritySample {
        guard let provider = try owner(asset) as? any SimilarityVideoProviding else { throw UniversalScanError.unsupportedReference }
        return try await provider.similarityVideoSample(for: asset, maximumPixelSize: maximumPixelSize, allowNetwork: allowNetwork)
    }
}
#endif

public struct LibraryReviewGroup: Identifiable, Sendable {
    public enum Kind: Sendable { case exact, verySimilar, similar }
    public let id: String
    public let kind: Kind
    public let assets: [UniversalMediaAsset]
    public let keeperID: String
    public var titleKey: String { kind == .exact ? "Exact Copies" : kind == .verySimilar ? "Very Similar" : "Similar Photos" }
    public var priority: Int { kind == .exact ? 0 : kind == .verySimilar ? 1 : 2 }
    public static func combined(exact: [UniversalExactGroup], similar: [UniversalSimilarityGroup]) -> [Self] {
        let exactSets = exact.map { Set($0.assets.map(\.id)) }
        var exactMembership: [String: [Int]] = [:]
        for (index, ids) in exactSets.enumerated() { for id in ids { exactMembership[id, default: []].append(index) } }
        return exact.map { Self(id: $0.id, kind: .exact, assets: $0.assets, keeperID: $0.keeperID) } + similar.filter { group in
            let ids = Set(group.assets.map(\.id))
            guard let first = ids.first else { return false }
            return !(exactMembership[first] ?? []).contains { ids.isSubset(of: exactSets[$0]) }
        }.map { Self(id: $0.id, kind: $0.strength == .verySimilar ? .verySimilar : .similar, assets: $0.assets, keeperID: $0.keeperID) }
    }
}

extension UniversalMediaAsset {
    public func sourceBadgeKey(in sources: [LibrarySource]) -> String {
        if case .photoLibrary = reference { return "Photos" }
        return sources.first(where: { $0.id == sourceID })?.kind == .fileProvider || requiresNetwork ? "Cloud Files" : "Files"
    }
    public func sourceBadgeSymbol(in sources: [LibrarySource]) -> String {
        switch sourceBadgeKey(in: sources) {
        case "Photos": return "photo"
        case "Cloud Files": return "icloud"
        default: return "folder"
        }
    }
    public func sourceLabel(in sources: [LibrarySource]) -> String {
        let source = sources.first { $0.id == sourceID }
        switch reference {
        case .photoLibrary:
            #if os(Linux)
            return NSLocalizedString("Photos / iCloud Photos", comment: "Photo source badge")
            #else
            return L10n.tr("Photos / iCloud Photos")
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

/// The final review keeps the captured asset revisions, including when undoing a
/// removal. It never substitutes newer catalogue entries into the deletion plan.
public struct FrozenSelectionReview: Equatable, Sendable {
    public private(set) var items: [UniversalMediaAsset]
    private var removed: (item: UniversalMediaAsset, index: Int)?
    public var canUndoRemoval: Bool { removed != nil }

    public init(_ items: [UniversalMediaAsset] = []) {
        var seen = Set<String>()
        self.items = items.filter { seen.insert($0.id).inserted }
    }

    @discardableResult public mutating func remove(_ id: String) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        removed = (items.remove(at: index), index)
        return true
    }

    @discardableResult public mutating func undoRemoval() -> UniversalMediaAsset? {
        guard let previous = removed else { return nil }
        items.insert(previous.item, at: min(previous.index, items.count))
        removed = nil
        return previous.item
    }

    /// Explicitly discarded unavailable items must not return through review undo.
    public mutating func discard(_ ids: Set<String>) {
        if var previous = removed {
            if ids.contains(previous.item.id) { removed = nil }
            else {
                previous.index -= items.prefix(previous.index).filter { ids.contains($0.id) }.count
                removed = previous
            }
        }
        items.removeAll { ids.contains($0.id) }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items && lhs.removed?.item == rhs.removed?.item && lhs.removed?.index == rhs.removed?.index
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
        #if os(Linux)
        let locale = Locale.current
        #else
        let locale = L10n.currentLocale
        #endif
        if context.captureTimeIsReliable { return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)) }
        if let recorded = context.captureDateText { return recorded }
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        formatter.locale = locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
