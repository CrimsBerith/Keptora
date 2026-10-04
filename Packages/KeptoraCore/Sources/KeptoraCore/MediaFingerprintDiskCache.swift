import Foundation

/// Revision- and algorithm-scoped cache. Unknown revisions are never reused.
public actor MediaFingerprintDiskCache {
    public static let shared = MediaFingerprintDiskCache()
    
    public struct CacheEntry: Codable, Sendable {
        public let assetID: String
        public let digest: String
        public let byteCount: Int64
        public let coarseHash: UInt64?
        public let featurePrintData: Data?
        public let sharpnessScore: Float?
        public let exposureScore: Float?
        public let compositeScore: Float?
        public var quality: QualityAssessment? = nil
        public let timestamp: TimeInterval
        
        public init(
            assetID: String,
            digest: String,
            byteCount: Int64,
            coarseHash: UInt64? = nil,
            featurePrintData: Data? = nil,
            sharpnessScore: Float? = nil,
            exposureScore: Float? = nil,
            compositeScore: Float? = nil,
            timestamp: TimeInterval = Date().timeIntervalSince1970
        ) {
            self.assetID = assetID
            self.digest = digest
            self.byteCount = byteCount
            self.coarseHash = coarseHash
            self.featurePrintData = featurePrintData
            self.sharpnessScore = sharpnessScore
            self.exposureScore = exposureScore
            self.compositeScore = compositeScore
            self.timestamp = timestamp
        }
    }
    
    private var entries: [String: CacheEntry] = [:]
    private var currentCost = 0
    private var isDirty = false
    private var hasLoaded = false
    private let cacheURL: URL
    private let maxEntries: Int
    private let maximumBytes: Int
    
    public init(customCacheURL: URL? = nil, maximumEntries: Int = 10_000, maximumBytes: Int = 64 * 1_048_576) {
        self.maxEntries = max(1, maximumEntries)
        self.maximumBytes = max(1, maximumBytes)
        if let custom = customCacheURL {
            self.cacheURL = custom
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let folder = base.appendingPathComponent("KeptoraCache", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.cacheURL = folder.appendingPathComponent("media_fingerprints_v3.json")
        }
    }
    
    public func get(asset: UniversalMediaAsset, algorithm: String) -> CacheEntry? {
        ensureLoaded()
        guard let key = MediaRevisionPolicy.key(for: asset, algorithm: algorithm) else { return nil }
        return entries[key]
    }
    
    public func store(
        asset: UniversalMediaAsset,
        algorithm: String,
        entry: CacheEntry
    ) {
        ensureLoaded()
        guard let key = MediaRevisionPolicy.key(for: asset, algorithm: algorithm) else { return }
        if let previous = entries[key] { currentCost -= cost(key: key, entry: previous) }
        entries[key] = entry
        currentCost += cost(key: key, entry: entry)
        isDirty = true
        
        evictOldest()
    }
    
    public func persistToDisk() {
        ensureLoaded()
        guard isDirty else { return }
        do {
            let data = try JSONEncoder().encode(entries)
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: cacheURL, options: .atomic)
            isDirty = false
        } catch {
            // Non-fatal cache write failure
        }
    }
    
    public func clear() {
        hasLoaded = true
        entries.removeAll()
        currentCost = 0
        isDirty = true
        persistToDisk()
    }
    
    private func ensureLoaded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        do {
            let size = (try? cacheURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= maximumBytes * 2 else { return }
            let data = try Data(contentsOf: cacheURL)
            let loaded = try JSONDecoder().decode([String: CacheEntry].self, from: data)
            for (k, v) in loaded {
                if entries[k] == nil {
                    entries[k] = v
                    currentCost += cost(key: k, entry: v)
                }
            }
            evictOldest()
        } catch {
            // Non-fatal cache decode error
        }
    }
    
    private func evictOldest() {
        guard entries.count > maxEntries || currentCost > maximumBytes else { return }
        let sortedKeys = entries.sorted { $0.value.timestamp < $1.value.timestamp }
        for item in sortedKeys {
            guard entries.count > maxEntries || currentCost > maximumBytes else { break }
            currentCost -= cost(key: item.key, entry: item.value)
            entries.removeValue(forKey: item.key)
            isDirty = true
        }
    }
    private func cost(key: String, entry: CacheEntry) -> Int {
        key.utf8.count + entry.assetID.utf8.count + entry.digest.utf8.count + 1024 + (entry.featurePrintData?.count ?? 0) * 4 / 3
    }
}
