import Foundation

/// Fast persistent cache for media fingerprints, vision hashes, and visual quality scores.
/// Enables sub-second instant rescans for large photo libraries.
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
    private var isDirty = false
    private var hasLoaded = false
    private let cacheURL: URL
    private let maxEntries = 50_000
    
    public init(customCacheURL: URL? = nil) {
        if let custom = customCacheURL {
            self.cacheURL = custom
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let folder = base.appendingPathComponent("KeptoraCache", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.cacheURL = folder.appendingPathComponent("media_fingerprints_v1.json")
        }
    }
    
    public func get(assetID: String, modificationDate: Date?, byteCount: Int64?) -> CacheEntry? {
        ensureLoaded()
        let key = cacheKey(assetID: assetID, modificationDate: modificationDate, byteCount: byteCount)
        return entries[key]
    }
    
    public func store(
        assetID: String,
        modificationDate: Date?,
        byteCount: Int64?,
        entry: CacheEntry
    ) {
        ensureLoaded()
        let key = cacheKey(assetID: assetID, modificationDate: modificationDate, byteCount: byteCount)
        entries[key] = entry
        isDirty = true
        
        if entries.count > maxEntries {
            evictOldest()
        }
    }
    
    public func persistToDisk() {
        ensureLoaded()
        guard isDirty else { return }
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: cacheURL, options: .atomic)
            isDirty = false
        } catch {
            // Non-fatal cache write failure
        }
    }
    
    public func clear() {
        hasLoaded = true
        entries.removeAll()
        isDirty = true
        persistToDisk()
    }
    
    private func cacheKey(assetID: String, modificationDate: Date?, byteCount: Int64?) -> String {
        let modTime = modificationDate?.timeIntervalSince1970 ?? 0
        let bytes = byteCount ?? 0
        return "\(assetID):\(Int64(modTime)):\(bytes)"
    }
    
    private func ensureLoaded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheURL)
            let loaded = try JSONDecoder().decode([String: CacheEntry].self, from: data)
            for (k, v) in loaded {
                if entries[k] == nil {
                    entries[k] = v
                }
            }
        } catch {
            // Non-fatal cache decode error
        }
    }
    
    private func evictOldest() {
        let sortedKeys = entries.sorted { $0.value.timestamp < $1.value.timestamp }
        let removeCount = max(0, entries.count - (maxEntries - 5_000))
        for item in sortedKeys.prefix(removeCount) {
            entries.removeValue(forKey: item.key)
        }
    }
}
