import CryptoKit
import Foundation
import XCTest
@testable import Keptora

final class ReconciliationCoordinatorTests: XCTestCase {
    func testRepairsMoveThatFinishedBeforeDatabaseUpdate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = source.appendingPathComponent("copy.jpg")
        let bytes = Data("same bytes".utf8)
        try bytes.write(to: original)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()

        let sourceID = SourceIdentity.folderID(for: source)
        let asset = AssetDescriptor(
            id: AssetID(rawValue: "asset"), sourceID: sourceID, stableKey: original.path,
            displayName: original.lastPathComponent, fileURL: original, mediaKind: .image,
            byteCount: Int64(bytes.count), pixelWidth: nil, pixelHeight: nil,
            creationDate: nil, modificationDate: try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )
        try await database.upsert(asset: asset, fingerprint: ExactFingerprint(algorithm: "sha256", digest: digest, byteCount: Int64(bytes.count)))

        let planID = "plan"
        let quarantine = source.appendingPathComponent(".Keptora Quarantine/plan/copy.jpg")
        let operation = CleanupOperationPreview(
            id: "operation", groupID: "group", assetID: asset.id, displayName: asset.displayName,
            originalURL: original, quarantineURL: quarantine, byteCount: Int64(bytes.count), digest: digest
        )
        let plan = CleanupPlanPreview(
            id: planID, sourceRoot: source, quarantineRoot: quarantine.deletingLastPathComponent(),
            createdAt: Date(), operations: [operation], sourceVolume: try VolumeIdentity.resolve(for: source)
        )
        try await database.insertCleanupPlan(plan)
        try await database.updateCleanupPlanState(planID, state: .committing)
        try FileManager.default.createDirectory(at: quarantine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: original, to: quarantine)

        let issues = try await ReconciliationCoordinator(database: database).reconcile(sourceRoot: source)
        XCTAssertTrue(issues.contains(where: { $0.kind == .recoveredQuarantine }))
        let states = try await database.fetchCleanupOperationStates(planID: planID)
        XCTAssertEqual(states[operation.id], .quarantined)
    }

    func testQuarantinedStateWithBothCopiesRequiresAttention() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = source.appendingPathComponent("copy.jpg")
        let quarantine = source.appendingPathComponent(".Keptora Quarantine/plan/copy.jpg")
        let bytes = Data("same bytes".utf8)
        try bytes.write(to: original)
        try FileManager.default.createDirectory(at: quarantine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: quarantine)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()
        let sourceID = SourceIdentity.folderID(for: source)
        let asset = AssetDescriptor(
            id: AssetID(rawValue: "asset"), sourceID: sourceID, stableKey: original.path,
            displayName: original.lastPathComponent, fileURL: original, mediaKind: .image,
            byteCount: Int64(bytes.count), pixelWidth: nil, pixelHeight: nil,
            creationDate: nil, modificationDate: try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )
        try await database.upsert(asset: asset, fingerprint: ExactFingerprint(algorithm: "sha256", digest: digest, byteCount: Int64(bytes.count)))
        let operation = CleanupOperationPreview(
            id: "operation", groupID: "group", assetID: asset.id, displayName: asset.displayName,
            originalURL: original, quarantineURL: quarantine, byteCount: Int64(bytes.count), digest: digest
        )
        let plan = CleanupPlanPreview(
            id: "plan", sourceRoot: source, quarantineRoot: quarantine.deletingLastPathComponent(),
            createdAt: Date(), operations: [operation], sourceVolume: try VolumeIdentity.resolve(for: source)
        )
        try await database.insertCleanupPlan(plan)
        try await database.updateCleanupPlanState(plan.id, state: .committed)
        try await database.markOperationQuarantined(operationID: operation.id, assetID: asset.id, quarantinePath: quarantine.path)

        let issues = try await ReconciliationCoordinator(database: database).reconcile(sourceRoot: source)
        XCTAssertTrue(issues.contains(where: { $0.kind == .ambiguousDiskState && $0.needsUserAttention }))
    }

    func testDraftPlanIsNotMarkedFailedAtStartup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = source.appendingPathComponent("copy.jpg")
        let bytes = Data("draft bytes".utf8)
        try bytes.write(to: original)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()

        let quarantine = source.appendingPathComponent(".Keptora Quarantine/draft/copy.jpg")
        let operation = CleanupOperationPreview(
            id: "draft-op", groupID: "group", assetID: AssetID(rawValue: "asset"), displayName: "copy.jpg",
            originalURL: original, quarantineURL: quarantine, byteCount: Int64(bytes.count), digest: digest
        )
        let plan = CleanupPlanPreview(
            id: "draft", sourceRoot: source, quarantineRoot: quarantine.deletingLastPathComponent(),
            createdAt: Date(), operations: [operation], sourceVolume: try VolumeIdentity.resolve(for: source)
        )
        // Inserted but never committed: still a draft.
        try await database.insertCleanupPlan(plan)

        let issues = try await ReconciliationCoordinator(database: database).reconcile(sourceRoot: source)
        XCTAssertTrue(issues.isEmpty)
        let states = try await database.fetchCleanupOperationStates(planID: "draft")
        XCTAssertEqual(states[operation.id], .pending)
    }
}
