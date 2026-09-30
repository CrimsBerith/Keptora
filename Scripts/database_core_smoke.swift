#if os(Linux)
import Foundation

@main
struct DatabaseCoreSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let database = SQLiteDatabase(url: root.appendingPathComponent("smoke.sqlite"))
        try await database.initialize()
        guard try await database.schemaVersion() >= 4 else { fatalError("Schema migration failed") }
        let source = SourceID(rawValue: "source")
        for index in 0..<3 {
            let file = root.appendingPathComponent("copy-\(index).jpg")
            try Data("same".utf8).write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"),
                sourceID: source,
                stableKey: file.path,
                displayName: file.lastPathComponent,
                fileURL: file,
                mediaKind: .image,
                byteCount: 4,
                pixelWidth: nil,
                pixelHeight: nil,
                creationDate: nil,
                modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            try await database.upsert(
                asset: asset,
                fingerprint: ExactFingerprint(algorithm: "sha256-v1", digest: "same", byteCount: 4),
                scanID: "scan-1"
            )
        }

        let family = AssetFamily(
            id: "family-one",
            sourceID: source,
            kind: .editedExport,
            policy: .advisory,
            normalizedStem: "copy",
            directoryPath: root.path,
            members: [
                AssetFamilyMember(assetID: AssetID(rawValue: "asset-0"), role: .primary, displayName: "copy-0.jpg", fileURL: root.appendingPathComponent("copy-0.jpg")),
                AssetFamilyMember(assetID: AssetID(rawValue: "asset-1"), role: .edited, displayName: "copy-1.jpg", fileURL: root.appendingPathComponent("copy-1.jpg"))
            ]
        )
        try await database.replaceAssetFamilies(sourceID: source, families: [family])
        try await database.rebuildExactGroups()
        var groups = try await database.fetchDuplicateGroups()
        guard groups.count == 1, groups[0].assets.count == 3 else {
            fatalError("Exact grouping smoke failed")
        }
        guard groups[0].assets.contains(where: { $0.family?.id == "family-one" }) else {
            fatalError("Family graph persistence smoke failed")
        }
        let oldKeeper = groups[0].canonicalAssetID
        guard let newKeeper = groups[0].assets.first(where: { $0.id != oldKeeper }) else {
            fatalError("No alternate keeper")
        }
        try await database.setDecision(groupID: groups[0].id, assetID: newKeeper.id, decision: .keep)
        try await database.setDecision(groupID: groups[0].id, assetID: oldKeeper, decision: .quarantinePlan)
        try await database.rebuildExactGroups()
        groups = try await database.fetchDuplicateGroups()
        guard groups[0].canonicalAssetID == newKeeper.id else {
            fatalError("Canonical persistence smoke failed")
        }
        let candidates = try await database.fetchCleanupCandidates(sourceID: source)
        guard candidates.count == 1, candidates[0].assetID == oldKeeper else {
            fatalError("Cleanup candidate smoke failed")
        }

        let secondSource = SourceID(rawValue: "source-two")
        for index in 0..<2 {
            let file = root.appendingPathComponent("second-\(index).jpg")
            try Data("same".utf8).write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "second-asset-\(index)"),
                sourceID: secondSource,
                stableKey: file.path,
                displayName: file.lastPathComponent,
                fileURL: file,
                mediaKind: .image,
                byteCount: 4,
                pixelWidth: nil,
                pixelHeight: nil,
                creationDate: nil,
                modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            try await database.upsert(
                asset: asset,
                fingerprint: ExactFingerprint(algorithm: "sha256-v1", digest: "same", byteCount: 4),
                scanID: "scan-2"
            )
        }
        try await database.rebuildExactGroups()
        let allGroups = try await database.fetchDuplicateGroups()
        let firstSourceGroups = try await database.fetchDuplicateGroups(sourceID: source)
        let secondSourceGroups = try await database.fetchDuplicateGroups(sourceID: secondSource)
        guard allGroups.count == 2, firstSourceGroups.count == 1, secondSourceGroups.count == 1 else {
            fatalError("Source isolation smoke failed")
        }
        guard Set(firstSourceGroups[0].assets.map(\.id)).isDisjoint(with: Set(secondSourceGroups[0].assets.map(\.id))) else {
            fatalError("Cross-source grouping detected")
        }
        let scopedSummary = try await database.summary(sourceID: secondSource)
        guard scopedSummary.indexedAssets == 2, scopedSummary.duplicateGroups == 1, scopedSummary.reclaimableBytes == 4 else {
            fatalError("Source-scoped summary failed")
        }
        let resume = try await database.beginOrResumeScanSession(sourceID: source, sourcePath: root.path, volumeID: "volume-test")
        try await database.updateScanCheckpoint(id: resume.id, processed: 100, total: 300, hashed: 80, reused: 20, phase: "hashing", cursorStableKey: "/cursor/file.jpg")
        try await database.pauseScanSession(id: resume.id, processed: 100, total: 300, hashed: 80, reused: 20, cursorStableKey: "/cursor/file.jpg")
        let resumed = try await database.beginOrResumeScanSession(sourceID: source, sourcePath: root.path, volumeID: "volume-test")
        guard resumed.id == resume.id, resumed.cursorStableKey == "/cursor/file.jpg", resumed.processed == 100 else {
            fatalError("Durable cursor resume smoke failed")
        }
        let restarted = try await database.restartScanSession(
            replacing: resumed.id,
            sourceID: source,
            sourcePath: root.path,
            volumeID: "volume-test"
        )
        guard restarted.id != resumed.id, restarted.processed == 0, restarted.cursorStableKey == nil else {
            fatalError("Changed-source restart smoke failed")
        }
        let state = try await database.indexState(sourceID: source, stableKey: root.appendingPathComponent("copy-0.jpg").path)
        guard state?.lastSeenScanID == "scan-1" else {
            fatalError("Durable last-seen scan ID smoke failed")
        }
        print("Phase 5I SQLite core smoke passed: schema v4, family graph, source isolation, durable cursor resume, and safe cursor restart.")
    }
}
#endif
