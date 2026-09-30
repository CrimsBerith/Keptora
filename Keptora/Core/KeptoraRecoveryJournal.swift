// Recovery / cancellation hardening wave — 2026-08-11
// Shared only as invisible infrastructure; UI shell remains product-specific.

import Foundation

enum KeptoraRecoveryState: String, Codable, Sendable {
    case started
    case committed
    case cancelled
    case failed
}

struct KeptoraRecoveryRecord: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let operation: String
    let startedAt: Date
    var updatedAt: Date
    let payloadDigest: String
    var state: KeptoraRecoveryState
    var note: String?

    init(id: UUID = UUID(), operation: String, startedAt: Date = Date(), updatedAt: Date? = nil, payloadDigest: String, state: KeptoraRecoveryState = .started, note: String? = nil) {
        self.id = id
        self.operation = operation
        self.startedAt = startedAt
        self.updatedAt = updatedAt ?? startedAt
        self.payloadDigest = payloadDigest
        self.state = state
        self.note = note
    }
}

struct KeptoraRecoveryJournal: Sendable {
    let directory: URL
    let defaultStaleAfter: TimeInterval

    init(directory: URL, defaultStaleAfter: TimeInterval = 15 * 60) {
        self.directory = directory
        self.defaultStaleAfter = max(1, defaultStaleAfter)
    }

    private var recordsDirectory: URL { directory.appendingPathComponent("records", isDirectory: true) }
    private var corruptDirectory: URL { directory.appendingPathComponent("corrupt", isDirectory: true) }
    private var archivedDirectory: URL { directory.appendingPathComponent("archived", isDirectory: true) }

    func prepare() throws {
        try FileManager.default.createDirectory(at: recordsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: corruptDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archivedDirectory, withIntermediateDirectories: true)
    }

    func record(_ record: KeptoraRecoveryRecord) throws {
        try prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        try data.write(to: recordURL(record.id), options: .atomic)
    }

    func begin(operation: String, payloadDigest: String, now: Date = Date()) throws -> KeptoraRecoveryRecord {
        let value = KeptoraRecoveryRecord(operation: operation, startedAt: now, payloadDigest: payloadDigest)
        try record(value)
        return value
    }

    @discardableResult
    func transition(id: UUID, to state: KeptoraRecoveryState, note: String? = nil, now: Date = Date()) throws -> KeptoraRecoveryRecord? {
        guard var value = try load(id: id) else { return nil }
        value.state = state
        value.updatedAt = now
        value.note = note
        try record(value)
        return value
    }

    func load(id: UUID) throws -> KeptoraRecoveryRecord? {
        let url = recordURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try decode(Data(contentsOf: url))
        } catch {
            try quarantine(url)
            return nil
        }
    }

    func loadAll() -> [KeptoraRecoveryRecord] {
        do { try prepare() } catch { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(at: recordsDirectory, includingPropertiesForKeys: nil)) ?? []
        var values: [KeptoraRecoveryRecord] = []
        values.reserveCapacity(urls.count)
        for url in urls where url.pathExtension == "json" {
            do { values.append(try decode(Data(contentsOf: url))) }
            catch { try? quarantine(url) }
        }
        return values.sorted {
            if $0.updatedAt == $1.updatedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.updatedAt < $1.updatedAt
        }
    }

    func recoverableOperations(now: Date = Date(), staleAfter: TimeInterval? = nil) -> [KeptoraRecoveryRecord] {
        let threshold = max(1, staleAfter ?? defaultStaleAfter)
        return loadAll().filter { $0.state == .started && now.timeIntervalSince($0.updatedAt) >= threshold }
    }

    func classifyRecoverable(_ records: [KeptoraRecoveryRecord], now: Date, staleAfter: TimeInterval? = nil) -> [KeptoraRecoveryRecord] {
        let threshold = max(1, staleAfter ?? defaultStaleAfter)
        return records.filter { $0.state == .started && now.timeIntervalSince($0.updatedAt) >= threshold }
    }

    func remove(id: UUID) throws {
        try prepare()
        let url = recordURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let destination = archivedDirectory
            .appendingPathComponent("\(id.uuidString.lowercased())-\(UUID().uuidString.lowercased())")
            .appendingPathExtension("json")
        try FileManager.default.moveItem(at: url, to: destination)
    }

    private func recordURL(_ id: UUID) -> URL { recordsDirectory.appendingPathComponent(id.uuidString.lowercased()).appendingPathExtension("json") }

    private func decode(_ data: Data) throws -> KeptoraRecoveryRecord {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(KeptoraRecoveryRecord.self, from: data)
    }

    private func quarantine(_ url: URL) throws {
        try FileManager.default.createDirectory(at: corruptDirectory, withIntermediateDirectories: true)
        let destination = corruptDirectory.appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString.lowercased()).appendingPathExtension("json")
        try FileManager.default.moveItem(at: url, to: destination)
    }
}
