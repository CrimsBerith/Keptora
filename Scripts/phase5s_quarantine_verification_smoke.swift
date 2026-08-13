#if os(Linux)
import Foundation

@main
struct Phase5SQuarantineVerificationSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("phase5s.sqlite"))
        try await database.initialize()
        let volume = try VolumeIdentity.resolve(for: source)
        let sourceID = SourceIdentity.folderID(for: source, volume: volume)
        let hasher = ExactHasher()
        let bytes = Data("phase-5s-identical".utf8)
        for index in 0..<2 {
            let url = source.appendingPathComponent("copy-\(index).jpg")
            try bytes.write(to: url)
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"), sourceID: sourceID, stableKey: url.path,
                displayName: url.lastPathComponent, fileURL: url, mediaKind: .image,
                byteCount: Int64(values.fileSize ?? 0), pixelWidth: nil, pixelHeight: nil,
                creationDate: nil, modificationDate: values.contentModificationDate
            )
            try await database.upsert(asset: asset, fingerprint: try await hasher.hashFile(at: url), scanID: "scan")
        }
        try await database.rebuildExactGroups()
        guard let group = try await database.fetchDuplicateGroups().first,
              let selected = group.assets.first(where: { $0.id != group.canonicalAssetID }) else {
            fatalError("duplicate setup failed")
        }
        try await database.setDecision(groupID: group.id, assetID: selected.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        let plan = try await coordinator.preparePlan(sourceRoot: source)
        let commit = try await coordinator.commit(plan, appVersion: "0.9.9")
        guard commit.movedCount == 1, commit.failedCount == 0,
              let commitVerification = commit.verification,
              commitVerification.phase == .postCommit,
              commitVerification.state == .verified,
              commitVerification.verifiedCount == 1 else {
            fatalError("post-commit verification failed: \(String(describing: commit.verification))")
        }

        let manual = try await coordinator.verifyLifecycle(planID: plan.id)
        guard manual.phase == .manualReview, manual.state == .verified else { fatalError("manual verification failed") }

        guard let op = plan.operations.first else { fatalError("missing operation") }
        try bytes.write(to: op.originalURL)
        let duplicated = try await coordinator.verifyLifecycle(planID: plan.id)
        guard duplicated.state == .reviewRequired,
              duplicated.checks.first?.state == .originalUnexpectedlyPresent else {
            fatalError("reappeared original was not detected")
        }
        try FileManager.default.removeItem(at: op.originalURL)

        let restore = try await coordinator.restore(planID: plan.id)
        guard restore.restoredCount == 1, restore.failedCount == 0,
              let restoreVerification = restore.verification,
              restoreVerification.phase == .postRestore,
              restoreVerification.state == .verified,
              restoreVerification.checks.first?.state == .verifiedRestored else {
            fatalError("post-restore verification failed: \(String(describing: restore.verification))")
        }

        let first = QuarantineVerificationEngine.lineageRecord(report: commitVerification, existing: [])
        let second = QuarantineVerificationEngine.lineageRecord(report: duplicated, existing: [first])
        let third = QuarantineVerificationEngine.lineageRecord(report: restoreVerification, existing: [first, second])
        guard second.identity.previousRecordID == first.id,
              third.identity.previousRecordID == second.id,
              third.identity.revisionNumber == 3 else { fatalError("verification lineage failed") }

        print("cullora-phase5s-quarantine-verification-ok")
    }
}
#endif
