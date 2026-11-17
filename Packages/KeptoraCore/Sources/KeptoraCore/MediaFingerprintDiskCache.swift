import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(SQLite3)
import SQLite3
#endif

#if canImport(SQLite3)
/// Revision- and algorithm-scoped cache. Unknown revisions are never reused.
///
/// Stored in SQLite: a lookup reads one row instead of decoding the whole cache, so the
/// budget can cover large libraries and nothing has to load before a scan starts.
/// Writes are batched in a transaction that commits every few hundred changes and on
/// `persistToDisk()`; an unreadable file is replaced, since every entry can be recomputed.
public actor MediaFingerprintDiskCache {
    public static let shared = MediaFingerprintDiskCache()

    #if os(iOS)
    public static let defaultMaximumEntries = 50_000
    public static let defaultMaximumBytes = 384 * 1_048_576
    #else
    public static let defaultMaximumEntries = 150_000
    public static let defaultMaximumBytes = 1_024 * 1_048_576
    #endif

    private let url: URL
    private let legacyURLs: [URL]
    private let maxEntries: Int
    private let maximumBytes: Int
    private var db: OpaquePointer?
    private var didOpen = false
    private var inTransaction = false
    private var pendingWrites = 0
    private var entryCount = 0
    private var totalCost = 0
    private var accessTick: Int64 = 0
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(customCacheURL: URL? = nil, maximumEntries: Int = MediaFingerprintDiskCache.defaultMaximumEntries,
                maximumBytes: Int = MediaFingerprintDiskCache.defaultMaximumBytes) {
        self.maxEntries = max(1, maximumEntries)
        self.maximumBytes = max(1, maximumBytes)
        if let customCacheURL {
            url = customCacheURL
            legacyURLs = []
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let folder = base.appendingPathComponent("KeptoraCache", isDirectory: true)
            url = folder.appendingPathComponent("media_fingerprints_v6.sqlite")
            legacyURLs = [folder.appendingPathComponent("media_fingerprints_v4.json"),
                          folder.appendingPathComponent("media_fingerprints_v5.plist")]
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    /// Opens the database before a scan so the first lookup does not pay for it.
    public func prewarm() async {
        _ = openIfNeeded()
    }

    public func get(asset: UniversalMediaAsset, algorithm: String) async -> CacheEntry? {
        guard let key = Self.storageKey(for: asset, algorithm: algorithm), openIfNeeded() else { return nil }
        let row: (meta: Data, feature: Data?)? = withStatement("SELECT meta, feature FROM entries WHERE key = ?") { statement -> (meta: Data, feature: Data?)? in
            sqlite3_bind_text(statement, 1, key, -1, Self.transient)
            guard sqlite3_step(statement) == SQLITE_ROW, let meta = Self.blob(statement, 0) else { return nil }
            return (meta, Self.blob(statement, 1))
        }
        guard let row, let meta = try? decoder.decode(CacheEntry.self, from: row.meta) else { return nil }
        touch(key)
        return meta.with(featurePrintData: row.feature)
    }

    public func store(
        asset: UniversalMediaAsset,
        algorithm: String,
        entry: CacheEntry
    ) async {
        guard let key = Self.storageKey(for: asset, algorithm: algorithm), openIfNeeded(),
              let meta = try? encoder.encode(entry.with(featurePrintData: nil)) else { return }
        let cost = Self.cost(key: key, entry: entry)
        let previousCost: Int? = withStatement("SELECT cost FROM entries WHERE key = ?") { statement -> Int? in
            sqlite3_bind_text(statement, 1, key, -1, Self.transient)
            return sqlite3_step(statement) == SQLITE_ROW ? Int(sqlite3_column_int64(statement, 0)) : nil
        }
        beginIfNeeded()
        accessTick += 1
        let tick = accessTick
        let stored: Bool = withStatement("INSERT OR REPLACE INTO entries (key, meta, feature, cost, last_access) VALUES (?, ?, ?, ?, ?)") { statement -> Bool? in
            sqlite3_bind_text(statement, 1, key, -1, Self.transient)
            Self.bind(meta, to: statement, at: 2)
            if let feature = entry.featurePrintData { Self.bind(feature, to: statement, at: 3) } else { sqlite3_bind_null(statement, 3) }
            sqlite3_bind_int64(statement, 4, Int64(cost))
            sqlite3_bind_int64(statement, 5, tick)
            return sqlite3_step(statement) == SQLITE_DONE
        } ?? false
        guard stored else { return }
        if let previousCost { totalCost -= previousCost } else { entryCount += 1 }
        totalCost += cost
        noteWrite()
        evictIfNeeded()
    }

    public func persistToDisk() async {
        commit()
    }

    public func clear() async {
        guard openIfNeeded() else { return }
        commit()
        if exec("DELETE FROM entries") {
            entryCount = 0
            totalCost = 0
        }
    }

    // MARK: Storage

    private static var transient: sqlite3_destructor_type { unsafeBitCast(-1, to: sqlite3_destructor_type.self) }

    private func openIfNeeded() -> Bool {
        if didOpen { return db != nil }
        didOpen = true
        for legacy in legacyURLs { try? FileManager.default.removeItem(at: legacy) }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !openDatabase() {
            closeDatabase()
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
            if !openDatabase() { closeDatabase() }
        }
        return db != nil
    }

    private func openDatabase() -> Bool {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            return false
        }
        db = handle
        sqlite3_busy_timeout(handle, 2_000)
        guard exec("PRAGMA journal_mode=WAL"), exec("PRAGMA synchronous=NORMAL"),
              exec("CREATE TABLE IF NOT EXISTS entries (key TEXT PRIMARY KEY NOT NULL, meta BLOB NOT NULL, feature BLOB, cost INTEGER NOT NULL, last_access INTEGER NOT NULL)"),
              exec("CREATE INDEX IF NOT EXISTS entries_last_access ON entries(last_access)") else { return false }
        let totals: (Int, Int, Int64)? = withStatement("SELECT COUNT(*), COALESCE(SUM(cost), 0), COALESCE(MAX(last_access), 0) FROM entries") { statement -> (Int, Int, Int64)? in
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return (Int(sqlite3_column_int64(statement, 0)), Int(sqlite3_column_int64(statement, 1)), sqlite3_column_int64(statement, 2))
        }
        guard let totals else { return false }
        entryCount = totals.0
        totalCost = totals.1
        accessTick = totals.2
        evictIfNeeded()
        commit()
        return true
    }

    private func closeDatabase() {
        if let db { sqlite3_close(db) }
        db = nil
        inTransaction = false
        pendingWrites = 0
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        guard let db else { return false }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func withStatement<T>(_ sql: String, _ body: (OpaquePointer) -> T?) -> T? {
        guard let db else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return nil }
        defer { sqlite3_finalize(statement) }
        return body(statement)
    }

    private static func bind(_ data: Data, to statement: OpaquePointer, at index: Int32) {
        _ = data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), transient)
        }
    }

    private static func blob(_ statement: OpaquePointer, _ column: Int32) -> Data? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        let count = Int(sqlite3_column_bytes(statement, column))
        guard count > 0, let bytes = sqlite3_column_blob(statement, column) else { return Data() }
        return Data(bytes: bytes, count: count)
    }

    private func beginIfNeeded() {
        guard !inTransaction else { return }
        inTransaction = exec("BEGIN IMMEDIATE")
    }

    private func noteWrite() {
        pendingWrites += 1
        if pendingWrites >= 400 { commit() }
    }

    private func commit() {
        guard inTransaction else { return }
        exec("COMMIT")
        inTransaction = false
        pendingWrites = 0
    }

    /// Recording reads lets eviction keep what rescans use (least recently used goes first).
    private func touch(_ key: String) {
        beginIfNeeded()
        accessTick += 1
        let tick = accessTick
        _ = withStatement("UPDATE entries SET last_access = ? WHERE key = ?") { statement -> Bool? in
            sqlite3_bind_int64(statement, 1, tick)
            sqlite3_bind_text(statement, 2, key, -1, Self.transient)
            return sqlite3_step(statement) == SQLITE_DONE
        }
        noteWrite()
    }

    /// Evicts down to 90% of both limits, least recently used first.
    private func evictIfNeeded() {
        guard entryCount > maxEntries || totalCost > maximumBytes else { return }
        let entryTarget = maxEntries - maxEntries / 10, byteTarget = maximumBytes - maximumBytes / 10
        beginIfNeeded()
        while entryCount > entryTarget || totalCost > byteTarget {
            let victims: [(String, Int)] = withStatement("SELECT key, cost FROM entries ORDER BY last_access ASC LIMIT 256") { statement -> [(String, Int)]? in
                var rows: [(String, Int)] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    guard let text = sqlite3_column_text(statement, 0) else { continue }
                    rows.append((String(cString: text), Int(sqlite3_column_int64(statement, 1))))
                }
                return rows
            } ?? []
            guard !victims.isEmpty else { break }
            for (key, cost) in victims {
                guard entryCount > entryTarget || totalCost > byteTarget else { break }
                let deleted = withStatement("DELETE FROM entries WHERE key = ?") { statement -> Bool? in
                    sqlite3_bind_text(statement, 1, key, -1, Self.transient)
                    return sqlite3_step(statement) == SQLITE_DONE
                } ?? false
                if deleted {
                    entryCount -= 1
                    totalCost -= cost
                }
            }
        }
        noteWrite()
    }

    private static func cost(key: String, entry: CacheEntry) -> Int {
        key.utf8.count + entry.assetID.utf8.count + entry.digest.utf8.count + 256 + (entry.featurePrintData?.count ?? 0)
    }
}
#else
/// Portable fallback (Linux): the whole cache in memory, saved as one binary property list.
public actor MediaFingerprintDiskCache {
    public static let shared = MediaFingerprintDiskCache()
    
    private var entries: [String: CacheEntry] = [:]
    /// Least-recently-used order. A scan reads entries far more often than it writes
    /// them, so eviction by write time alone dropped the entries a rescan needs.
    private var lastAccess: [String: UInt64] = [:]
    private var accessTick: UInt64 = 0
    private var currentCost = 0
    private var isDirty = false
    private var hasLoaded = false
    private var loadTask: Task<[String: CacheEntry], Never>?
    private var writeTask: Task<Bool, Never>?
    private let cacheURL: URL
    private let legacyURL: URL?
    private let maxEntries: Int
    private let maximumBytes: Int

    #if os(iOS)
    public static let defaultMaximumEntries = 30_000
    public static let defaultMaximumBytes = 96 * 1_048_576
    #else
    public static let defaultMaximumEntries = 80_000
    public static let defaultMaximumBytes = 256 * 1_048_576
    #endif

    public init(customCacheURL: URL? = nil, maximumEntries: Int = MediaFingerprintDiskCache.defaultMaximumEntries,
                maximumBytes: Int = MediaFingerprintDiskCache.defaultMaximumBytes) {
        self.maxEntries = max(1, maximumEntries)
        self.maximumBytes = max(1, maximumBytes)
        if let custom = customCacheURL {
            self.cacheURL = custom
            self.legacyURL = nil
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let folder = base.appendingPathComponent("KeptoraCache", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // v5 is a binary property list: feature prints stay raw bytes instead of base64
            // JSON, which roughly halves the file and the decode time.
            self.cacheURL = folder.appendingPathComponent("media_fingerprints_v5.plist")
            self.legacyURL = folder.appendingPathComponent("media_fingerprints_v4.json")
        }
    }

    /// Starts reading the cache file off the actor. Call before a scan so the first
    /// lookup does not wait for the whole file to decode.
    public func prewarm() async {
        await ensureLoaded()
    }

    public func get(asset: UniversalMediaAsset, algorithm: String) async -> CacheEntry? {
        await ensureLoaded()
        guard let key = Self.storageKey(for: asset, algorithm: algorithm), let entry = entries[key] else { return nil }
        touch(key)
        return entry
    }

    public func store(
        asset: UniversalMediaAsset,
        algorithm: String,
        entry: CacheEntry
    ) async {
        await ensureLoaded()
        guard let key = Self.storageKey(for: asset, algorithm: algorithm) else { return }
        if let previous = entries[key] { currentCost -= cost(key: key, entry: previous) }
        entries[key] = entry
        currentCost += cost(key: key, entry: entry)
        touch(key)
        isDirty = true

        evictOldest()
    }

    /// Encoding and writing run off the actor so lookups continue meanwhile.
    /// Writes are chained so an older snapshot never lands after a newer one.
    public func persistToDisk() async {
        await ensureLoaded()
        guard isDirty else { return }
        let snapshot = entries, url = cacheURL, previous = writeTask
        isDirty = false
        let task = Task.detached(priority: .utility) { () -> Bool in
            _ = await previous?.value
            return Self.write(snapshot, to: url)
        }
        writeTask = task
        if !(await task.value) { isDirty = true }
    }

    public func clear() async {
        hasLoaded = true
        entries.removeAll()
        lastAccess.removeAll()
        currentCost = 0
        isDirty = true
        await persistToDisk()
    }

    private func touch(_ key: String) {
        accessTick &+= 1
        lastAccess[key] = accessTick
    }

    private func ensureLoaded() async {
        guard !hasLoaded else { return }
        let task: Task<[String: CacheEntry], Never>
        if let loadTask {
            task = loadTask
        } else {
            let url = cacheURL, legacy = legacyURL, limit = maximumBytes * 2
            task = Task.detached(priority: .utility) {
                if let legacy { try? FileManager.default.removeItem(at: legacy) }
                return Self.read(from: url, maximumFileBytes: limit)
            }
            loadTask = task
        }
        let loaded = await task.value
        // Another caller, or clear(), may have finished while this one waited.
        guard !hasLoaded else { return }
        hasLoaded = true
        loadTask = nil
        for (k, v) in loaded where entries[k] == nil {
            entries[k] = v
            currentCost += cost(key: k, entry: v)
        }
        evictOldest()
    }

    private static func read(from url: URL, maximumFileBytes: Int) -> [String: CacheEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maximumFileBytes, let data = try? Data(contentsOf: url) else { return [:] }
        if let value = try? PropertyListDecoder().decode([String: CacheEntry].self, from: data) { return value }
        // Caches written before v5 (or by tests with a custom URL) used JSON.
        return (try? JSONDecoder().decode([String: CacheEntry].self, from: data)) ?? [:]
    }

    private static func write(_ entries: [String: CacheEntry], to url: URL) -> Bool {
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data: Data
            if let binary = try? encoder.encode(entries) { data = binary } else { data = try JSONEncoder().encode(entries) }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            // Non-fatal cache write failure
            return false
        }
    }

    /// Evicts down to 90% of both limits in one pass, least recently used first.
    /// Entries loaded from disk and not yet read this session go first, oldest first.
    private func evictOldest() {
        guard entries.count > maxEntries || currentCost > maximumBytes else { return }
        let entryTarget = maxEntries - maxEntries / 10, byteTarget = maximumBytes - maximumBytes / 10
        let sortedKeys = entries.sorted {
            let lhs = lastAccess[$0.key] ?? 0, rhs = lastAccess[$1.key] ?? 0
            if lhs != rhs { return lhs < rhs }
            return $0.value.timestamp < $1.value.timestamp
        }
        for item in sortedKeys {
            guard entries.count > entryTarget || currentCost > byteTarget else { break }
            currentCost -= cost(key: item.key, entry: item.value)
            entries.removeValue(forKey: item.key)
            lastAccess.removeValue(forKey: item.key)
            isDirty = true
        }
    }
    private func cost(key: String, entry: CacheEntry) -> Int {
        key.utf8.count + entry.assetID.utf8.count + entry.digest.utf8.count + 256 + (entry.featurePrintData?.count ?? 0)
    }
}
#endif

extension MediaFingerprintDiskCache {
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

        /// The same entry with another feature print; SQLite keeps that blob in its own column.
        func with(featurePrintData data: Data?) -> CacheEntry {
            var copy = CacheEntry(assetID: assetID, digest: digest, byteCount: byteCount, coarseHash: coarseHash,
                                  featurePrintData: data, sharpnessScore: sharpnessScore, exposureScore: exposureScore,
                                  compositeScore: compositeScore, timestamp: timestamp)
            copy.quality = quality
            return copy
        }
    }

    /// The revision key is about 1 KB of JSON per item. Storing its SHA-256 keeps the
    /// same identity in 70 bytes, so the size budget holds more fingerprints.
    static func storageKey(for asset: UniversalMediaAsset, algorithm: String) -> String? {
        guard let key = MediaRevisionPolicy.fingerprintKey(for: asset, algorithm: algorithm) else { return nil }
        #if canImport(CryptoKit)
        return algorithm + ":" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        #else
        return key
        #endif
    }
}
