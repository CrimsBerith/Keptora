import XCTest
@testable import Keptora

final class QuarantineCoordinatorTests: XCTestCase {
    func testCommitCreatesSignedManifestAndRestoreMovesFileBack() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceRoot = directory.appendingPathComponent("Library", isDirectory: true)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()
        let sourceVolume = try VolumeIdentity.resolve(for: sourceRoot)
        let source = SourceIdentity.folderID(for: sourceRoot, volume: sourceVolume)
        let content = Data("byte-identical".utf8)
        for index in 0..<2 {
            let file = sourceRoot.appendingPathComponent("copy-\(index).jpg")
            try content.write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"), sourceID: source, stableKey: file.path,
                displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                byteCount: Int64(content.count), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            let fingerprint = try await ExactHasher().hashFile(at: file)
            try await database.upsert(asset: asset, fingerprint: fingerprint, scanID: "scan")
        }
        try await database.rebuildExactGroups()
        let groups = try await database.fetchDuplicateGroups()
        let group = try XCTUnwrap(groups.first)
        let selected = try XCTUnwrap(group.assets.first { $0.id != group.canonicalAssetID })
        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        let plan = try await coordinator.preparePlan(sourceRoot: sourceRoot)
        let result = try await coordinator.commit(plan, appVersion: "test")
        XCTAssertEqual(result.movedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: selected.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.manifestURL.path))

        let history = try await database.fetchCleanupHistory()
        XCTAssertEqual(history.first?.state, .committed)
        let restore = try await coordinator.restore(planID: plan.id)
        XCTAssertEqual(restore.restoredCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: selected.fileURL.path))
        let restoredHistory = try await database.fetchCleanupHistory()
        XCTAssertEqual(restoredHistory.first?.state, .restored)
    }


    func testPreparedSafetyPlanBecomesStaleWhenReviewDecisionChanges() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceRoot = directory.appendingPathComponent("Library", isDirectory: true)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()
        let sourceVolume = try VolumeIdentity.resolve(for: sourceRoot)
        let source = SourceIdentity.folderID(for: sourceRoot, volume: sourceVolume)
        let content = Data("freshness-identical".utf8)
        for index in 0..<2 {
            let file = sourceRoot.appendingPathComponent("freshness-\(index).jpg")
            try content.write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "freshness-\(index)"), sourceID: source, stableKey: file.path,
                displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                byteCount: Int64(content.count), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            try await database.upsert(asset: asset, fingerprint: try await ExactHasher().hashFile(at: file), scanID: "scan")
        }
        try await database.rebuildExactGroups()
        let groups = try await database.fetchDuplicateGroups()
        let group = try XCTUnwrap(groups.first)
        let selected = try XCTUnwrap(group.assets.first { $0.id != group.canonicalAssetID })
        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        let plan = try await coordinator.preparePlan(sourceRoot: sourceRoot)
        let initialFreshness = try await coordinator.assessFreshness(plan)
        XCTAssertEqual(initialFreshness.state, .current)

        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .skip)
        let stale = try await coordinator.assessFreshness(plan)
        XCTAssertEqual(stale.state, .stale)
        XCTAssertFalse(stale.permitsCommit)
        XCTAssertNotEqual(stale.expectedFingerprint, stale.currentFingerprint)
    }

    func testSafetyPlanFingerprintIsOrderIndependentAndDecisionSensitive() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        func operation(_ id: String, reason: String) -> CleanupOperationPreview {
            CleanupOperationPreview(
                id: "op-\(id)", groupID: "group", assetID: AssetID(rawValue: id), displayName: id,
                originalURL: URL(fileURLWithPath: "/tmp/\(id)"), quarantineURL: URL(fileURLWithPath: "/tmp/q/\(id)"),
                byteCount: 12, digest: "digest", decisionActor: "user", decisionReasonCode: reason,
                decisionUpdatedAt: date, canonicalAssetID: AssetID(rawValue: "keeper")
            )
        }
        let a = operation("a", reason: "user-added-to-plan")
        let b = operation("b", reason: "user-added-to-plan")
        XCTAssertEqual(
            SafetyPlanDecisionFingerprint.fingerprint(operations: [a, b]),
            SafetyPlanDecisionFingerprint.fingerprint(operations: [b, a])
        )
        XCTAssertNotEqual(
            SafetyPlanDecisionFingerprint.fingerprint(operations: [a, b]),
            SafetyPlanDecisionFingerprint.fingerprint(operations: [a, operation("b", reason: "changed")])
        )
    }

    func testSafetyPlanLineageRevisionChainsPerSource() {
        let source = URL(fileURLWithPath: "/tmp/library")
        let first = SafetyPlanLineageEngine.nextIdentity(records: [], sourceRoot: source)
        let record = SafetyPlanLineageRecord(
            lineage: first, planID: "plan-1", sourceRoot: source.standardizedFileURL.path,
            decisionSnapshotFingerprint: "abc", operationCount: 1, createdAt: Date(), state: .committed
        )
        let second = SafetyPlanLineageEngine.nextIdentity(records: [record], sourceRoot: source)
        XCTAssertEqual(second.revisionNumber, 2)
        XCTAssertEqual(second.previousLineageID, first.lineageID)
    }
}

extension QuarantineCoordinatorTests {
    func testQuarantineVerificationClassifiesUnexpectedOriginalAndTamper() {
        let operation = CleanupManifestOperation(
            operationID: "op", groupID: "group", assetID: "asset",
            originalPath: "/tmp/original", quarantinePath: "/tmp/quarantine",
            byteCount: 10, digest: "abc"
        )
        let originalReappeared = QuarantineVerificationEngine.classify(
            expected: operation,
            observed: QuarantineObservedOperationState(
                operationID: "op", databaseState: .quarantined,
                originalExists: true, quarantineExists: true,
                observedDigest: "abc", observedByteCount: 10
            )
        )
        XCTAssertEqual(originalReappeared.state, .originalUnexpectedlyPresent)

        let changed = QuarantineVerificationEngine.classify(
            expected: operation,
            observed: QuarantineObservedOperationState(
                operationID: "op", databaseState: .quarantined,
                originalExists: false, quarantineExists: true,
                observedDigest: "changed", observedByteCount: 10
            )
        )
        XCTAssertEqual(changed.state, .quarantineContentChanged)
    }

    func testQuarantineVerificationLineageChainsCommitManualAndRestoreReviews() {
        let manifest = CleanupManifest(
            schemaVersion: 4, planID: "plan", sourceRoot: "/source", quarantineRoot: "/source/.Keptora Quarantine/plan",
            createdAt: Date(timeIntervalSince1970: 1), appVersion: "test", decisionSnapshotFingerprint: "decision",
            safetyPlanLineageID: "safety-1", safetyPlanRevision: 1,
            operations: [CleanupManifestOperation(
                operationID: "op", groupID: "group", assetID: "asset", originalPath: "/source/a",
                quarantinePath: "/source/.Keptora Quarantine/plan/a", byteCount: 5, digest: "digest"
            )]
        )
        let observed = [QuarantineObservedOperationState(
            operationID: "op", databaseState: .quarantined,
            originalExists: false, quarantineExists: true,
            observedDigest: "digest", observedByteCount: 5
        )]
        let report1 = QuarantineVerificationEngine.report(manifest: manifest, phase: .postCommit, observed: observed)
        XCTAssertEqual(report1.state, .verified)
        let first = QuarantineVerificationEngine.lineageRecord(report: report1, existing: [])
        let report2 = QuarantineVerificationEngine.report(manifest: manifest, phase: .manualReview, observed: observed)
        let second = QuarantineVerificationEngine.lineageRecord(report: report2, existing: [first])
        XCTAssertEqual(second.identity.revisionNumber, 2)
        XCTAssertEqual(second.identity.previousRecordID, first.id)
        XCTAssertEqual(first.manifestFingerprint, second.manifestFingerprint)
    }

    func testQuarantineVerificationManifestFingerprintIsOperationOrderIndependent() {
        func op(_ id: String) -> CleanupManifestOperation {
            CleanupManifestOperation(
                operationID: id, groupID: "g", assetID: id,
                originalPath: "/s/\(id)", quarantinePath: "/q/\(id)", byteCount: 2, digest: "d-\(id)"
            )
        }
        let a = CleanupManifest(schemaVersion: 4, planID: "p", sourceRoot: "/s", quarantineRoot: "/q", createdAt: .now, appVersion: "x", operations: [op("a"), op("b")])
        let b = CleanupManifest(schemaVersion: 4, planID: "p", sourceRoot: "/s", quarantineRoot: "/q", createdAt: .now, appVersion: "x", operations: [op("b"), op("a")])
        XCTAssertEqual(QuarantineVerificationEngine.manifestIdentityFingerprint(a), QuarantineVerificationEngine.manifestIdentityFingerprint(b))
    }

    func testRestoredFileIsNotSilentlyPlannedAgain() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceRoot = directory.appendingPathComponent("Library", isDirectory: true)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        try await database.initialize()
        let sourceVolume = try VolumeIdentity.resolve(for: sourceRoot)
        let source = SourceIdentity.folderID(for: sourceRoot, volume: sourceVolume)
        let content = Data("restore-then-review".utf8)
        for index in 0..<2 {
            let file = sourceRoot.appendingPathComponent("again-\(index).jpg")
            try content.write(to: file)
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "again-\(index)"), sourceID: source, stableKey: file.path,
                displayName: file.lastPathComponent, fileURL: file, mediaKind: .image,
                byteCount: Int64(content.count), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: Date(timeIntervalSince1970: Double(index))
            )
            try await database.upsert(asset: asset, fingerprint: try await ExactHasher().hashFile(at: file), scanID: "scan")
        }
        try await database.rebuildExactGroups()
        let group = try XCTUnwrap(try await database.fetchDuplicateGroups().first)
        let selected = try XCTUnwrap(group.assets.first { $0.id != group.canonicalAssetID })
        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        let plan = try await coordinator.preparePlan(sourceRoot: sourceRoot)
        _ = try await coordinator.commit(plan, appVersion: "test")
        _ = try await coordinator.restore(planID: plan.id)
        try await database.rebuildExactGroups()

        let candidates = try await database.fetchCleanupCandidates(sourceID: source)
        XCTAssertTrue(candidates.isEmpty, "A restored file must be reviewed again before it can re-enter a plan")
    }
}
