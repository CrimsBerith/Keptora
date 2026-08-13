import Foundation

actor QuarantineCoordinator {
    enum CleanupError: LocalizedError {
        case noSelectedItems
        case sourceOutsideRoot(URL)
        case canonicalWouldBeRemoved(String)
        case sourceMissing(URL)
        case destinationOccupied(URL)
        case contentChanged(URL)
        case originalOccupied(URL)
        case manifestUnavailable(String)
        case manifestInvalid(String)
        case familyWouldBeOrphaned(String)
        case sourceVolumeUnavailable
        case sourceVolumeChanged(expected: String, actual: String)
        case staleSafetyPlan

        var errorDescription: String? {
            switch self {
            case .noSelectedItems: return "Add at least one non-canonical duplicate to the Safety Plan first."
            case .sourceOutsideRoot(let url): return "The file is outside the selected source folder: \(url.lastPathComponent)"
            case .canonicalWouldBeRemoved(let groupID): return "The protected keeper would be removed from group \(groupID). Choose another keeper first."
            case .sourceMissing(let url): return "The source file is no longer available: \(url.path)"
            case .destinationOccupied(let url): return "The quarantine destination already exists: \(url.path)"
            case .contentChanged(let url): return "The file changed after review and was not moved: \(url.lastPathComponent)"
            case .originalOccupied(let url): return "The original path is occupied, so Cullora did not overwrite it: \(url.path)"
            case .manifestUnavailable(let planID): return "The signed manifest is unavailable for plan \(planID)."
            case .manifestInvalid(let planID): return "The signed manifest failed verification for plan \(planID)."
            case .familyWouldBeOrphaned(let message): return message
            case .sourceVolumeUnavailable: return "The selected source volume is unavailable. Reconnect it before continuing."
            case .sourceVolumeChanged(let expected, let actual): return "The source path now belongs to a different volume. Expected \(expected), found \(actual)."
            case .staleSafetyPlan: return "The Safety Plan is stale because exact-review decisions changed after preparation. Regenerate it before moving files."
            }
        }
    }

    private let database: SQLiteDatabase
    private let hasher = ExactHasher()
    private let signer: ManifestSigner
    private let manifestsDirectory: URL
    private let fileMover = CoordinatedFileMover()

    init(database: SQLiteDatabase, applicationSupportDirectory: URL) {
        self.database = database
        self.manifestsDirectory = applicationSupportDirectory.appendingPathComponent("Manifests", isDirectory: true)
        self.signer = ManifestSigner(keyURL: applicationSupportDirectory.appendingPathComponent("Keys/manifest-signing.key"))
    }

    func preparePlan(sourceRoot: URL) async throws -> CleanupPlanPreview {
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else { throw CleanupError.sourceVolumeUnavailable }
        let sourceVolume = try VolumeIdentity.resolve(for: sourceRoot)
        let sourceID = SourceIdentity.folderID(for: sourceRoot, volume: sourceVolume)
        let candidates = try await database.fetchCleanupCandidates(sourceID: sourceID)
        guard !candidates.isEmpty else { throw CleanupError.noSelectedItems }

        let selectedIDs = Set(candidates.map(\.assetID))
        var warnings: [FamilySafetyIssue] = []
        var blockingMessages: [String] = []
        let families = Dictionary(grouping: candidates.compactMap { $0.family }) { $0.id }
        for (_, summaries) in families {
            guard let summary = summaries.first else { continue }
            let members = try await database.familyMembers(familyID: summary.id)
                .filter { !$0.isMissing && !$0.isQuarantined }
            let missing = members.filter { !selectedIDs.contains($0.assetID) }
            guard !missing.isEmpty else { continue }
            let issue = FamilySafetyIssue(
                id: "family-safety:\(summary.id)",
                familyID: summary.id,
                kind: summary.kind,
                message: summary.policy == .allOrNothing
                    ? "Cullora blocked a partial \(summary.kind.rawValue) move because it would separate paired components."
                    : "This edited/export family is only partially selected; Cullora will preserve the remaining derivatives.",
                missingMembers: missing.map(\.displayName)
            )
            if summary.policy == .allOrNothing {
                blockingMessages.append("\(issue.message) Missing from the plan: \(issue.missingMembers.joined(separator: ", ")).")
            } else {
                warnings.append(issue)
            }
        }
        if !blockingMessages.isEmpty {
            throw CleanupError.familyWouldBeOrphaned(blockingMessages.joined(separator: "\n"))
        }

        let planID = UUID().uuidString.lowercased()
        let quarantineRoot = sourceRoot
            .appendingPathComponent(".Cullora Quarantine", isDirectory: true)
            .appendingPathComponent(planID, isDirectory: true)
        let standardizedRoot = sourceRoot.standardizedFileURL

        let operations = try candidates.map { candidate -> CleanupOperationPreview in
            guard candidate.assetID != candidate.canonicalAssetID else {
                throw CleanupError.canonicalWouldBeRemoved(candidate.groupID)
            }
            let original = candidate.originalURL.standardizedFileURL
            guard Self.isDescendant(original, of: standardizedRoot) else {
                throw CleanupError.sourceOutsideRoot(original)
            }
            let relative = Self.relativePath(of: original, under: standardizedRoot)
            let destination = quarantineRoot.appendingPathComponent(relative, isDirectory: false)
            return CleanupOperationPreview(
                id: UUID().uuidString.lowercased(),
                groupID: candidate.groupID,
                assetID: candidate.assetID,
                displayName: candidate.displayName,
                originalURL: original,
                quarantineURL: destination,
                byteCount: candidate.byteCount,
                digest: candidate.digest,
                familyID: candidate.family?.id,
                familyKind: candidate.family?.kind,
                familyRole: candidate.family?.role,
                decisionActor: candidate.decisionActor,
                decisionReasonCode: candidate.decisionReasonCode,
                decisionUpdatedAt: candidate.decisionUpdatedAt,
                canonicalAssetID: candidate.canonicalAssetID
            )
        }

        let plan = CleanupPlanPreview(
            id: planID,
            sourceRoot: standardizedRoot,
            quarantineRoot: quarantineRoot,
            createdAt: Date(),
            operations: operations,
            sourceVolume: sourceVolume,
            familyWarnings: warnings
        )
        try await database.insertCleanupPlan(plan)
        return plan
    }

    func assessFreshness(_ plan: CleanupPlanPreview) async throws -> SafetyPlanFreshnessAssessment {
        guard FileManager.default.fileExists(atPath: plan.sourceRoot.path) else { throw CleanupError.sourceVolumeUnavailable }
        let currentVolume = try VolumeIdentity.resolve(for: plan.sourceRoot)
        if let expected = plan.sourceVolume, !expected.matches(currentVolume) {
            throw CleanupError.sourceVolumeChanged(expected: expected.stableID, actual: currentVolume.stableID)
        }
        let sourceID = SourceIdentity.folderID(for: plan.sourceRoot, volume: currentVolume)
        let candidates = try await database.fetchCleanupCandidates(sourceID: sourceID)
        let currentFingerprint = SafetyPlanDecisionFingerprint.fingerprint(candidates: candidates)
        guard let expected = plan.decisionSnapshotFingerprint else {
            return SafetyPlanFreshnessAssessment(
                state: .legacy,
                expectedFingerprint: nil,
                currentFingerprint: currentFingerprint,
                expectedOperationCount: plan.operations.count,
                currentOperationCount: candidates.count
            )
        }
        let isCurrent = expected == currentFingerprint && plan.operations.count == candidates.count
        return SafetyPlanFreshnessAssessment(
            state: isCurrent ? .current : .stale,
            expectedFingerprint: expected,
            currentFingerprint: currentFingerprint,
            expectedOperationCount: plan.operations.count,
            currentOperationCount: candidates.count
        )
    }

    func commit(_ plan: CleanupPlanPreview, appVersion: String) async throws -> CleanupCommitResult {
        let freshness = try await assessFreshness(plan)
        guard freshness.permitsCommit else { throw CleanupError.staleSafetyPlan }
        guard FileManager.default.fileExists(atPath: plan.sourceRoot.path) else { throw CleanupError.sourceVolumeUnavailable }
        let currentVolume = try VolumeIdentity.resolve(for: plan.sourceRoot)
        if let expected = plan.sourceVolume, !expected.matches(currentVolume) {
            throw CleanupError.sourceVolumeChanged(expected: expected.stableID, actual: currentVolume.stableID)
        }
        // The signed manifest is written before the first file-system mutation.
        let manifest = CleanupManifest(
            schemaVersion: 4,
            planID: plan.id,
            sourceRoot: plan.sourceRoot.path,
            quarantineRoot: plan.quarantineRoot.path,
            createdAt: plan.createdAt,
            appVersion: appVersion,
            sourceVolumeID: plan.sourceVolume?.stableID,
            decisionSnapshotFingerprint: plan.decisionSnapshotFingerprint,
            safetyPlanLineageID: plan.lineage?.lineageID,
            previousSafetyPlanLineageID: plan.lineage?.previousLineageID,
            safetyPlanRevision: plan.lineage?.revisionNumber,
            operations: plan.operations.map {
                CleanupManifestOperation(
                    operationID: $0.id,
                    groupID: $0.groupID,
                    assetID: $0.assetID.rawValue,
                    originalPath: $0.originalURL.path,
                    quarantinePath: $0.quarantineURL.path,
                    byteCount: $0.byteCount,
                    digest: $0.digest,
                    familyID: $0.familyID,
                    familyKind: $0.familyKind?.rawValue,
                    familyRole: $0.familyRole?.rawValue,
                    decisionActor: $0.decisionActor,
                    decisionReasonCode: $0.decisionReasonCode,
                    decisionUpdatedAt: $0.decisionUpdatedAt,
                    canonicalAssetID: $0.canonicalAssetID?.rawValue
                )
            }
        )
        let envelope = try await signer.seal(manifest)
        let manifestURL = manifestsDirectory.appendingPathComponent("\(plan.id).cullora-manifest.json")
        try FileManager.default.createDirectory(at: manifestsDirectory, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw CleanupError.destinationOccupied(manifestURL)
        }
        try ManifestSigner.canonicalEncoder.encode(envelope).write(to: manifestURL, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: manifestURL.path)
        try await database.storeManifest(planID: plan.id, envelope: envelope, path: manifestURL.path)
        try await database.updateCleanupPlanState(plan.id, state: .committing)
        try FileManager.default.createDirectory(at: plan.quarantineRoot, withIntermediateDirectories: true)

        var moved = 0
        var failed = 0
        for operation in plan.operations {
            var movedOnDisk = false
            do {
                try Task.checkCancellation()
                if let expected = plan.sourceVolume {
                    let operationVolume = try VolumeIdentity.resolve(for: operation.originalURL)
                    guard expected.matches(operationVolume) else {
                        throw CleanupError.sourceVolumeChanged(expected: expected.stableID, actual: operationVolume.stableID)
                    }
                }
                guard FileManager.default.fileExists(atPath: operation.originalURL.path) else {
                    throw CleanupError.sourceMissing(operation.originalURL)
                }
                guard !FileManager.default.fileExists(atPath: operation.quarantineURL.path) else {
                    throw CleanupError.destinationOccupied(operation.quarantineURL)
                }
                let current = try await hasher.hashFile(at: operation.originalURL)
                guard current.digest == operation.digest, current.byteCount == operation.byteCount else {
                    throw CleanupError.contentChanged(operation.originalURL)
                }
                try FileManager.default.createDirectory(at: operation.quarantineURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileMover.moveItem(from: operation.originalURL, to: operation.quarantineURL)
                movedOnDisk = true
                do {
                    try await database.markOperationQuarantined(
                        operationID: operation.id,
                        assetID: operation.assetID,
                        quarantinePath: operation.quarantineURL.path
                    )
                } catch {
                    // Keep database and disk in agreement when persistence fails after a move.
                    if !FileManager.default.fileExists(atPath: operation.originalURL.path) {
                        try? fileMover.moveItem(from: operation.quarantineURL, to: operation.originalURL)
                    }
                    movedOnDisk = false
                    throw error
                }
                moved += 1
            } catch {
                failed += 1
                if movedOnDisk,
                   FileManager.default.fileExists(atPath: operation.quarantineURL.path),
                   !FileManager.default.fileExists(atPath: operation.originalURL.path) {
                    try? fileMover.moveItem(from: operation.quarantineURL, to: operation.originalURL)
                }
                try? await database.markOperationFailed(operationID: operation.id, message: error.localizedDescription)
            }
        }

        let finalState: CleanupPlanState
        if moved == plan.operations.count { finalState = .committed }
        else if moved > 0 { finalState = .partiallyCommitted }
        else { finalState = .failed }
        try await database.finishCleanupCommit(plan.id, state: finalState)
        try await database.rebuildExactGroups()
        let verification = try? await verifyLifecycle(manifest: manifest, phase: .postCommit)
        return CleanupCommitResult(
            planID: plan.id,
            movedCount: moved,
            failedCount: failed,
            manifestURL: manifestURL,
            verification: verification
        )
    }

    func previewRestore(planID: String) async throws -> RestorePlanPreview {
        let manifest = try await verifiedManifest(planID: planID)
        let sourceRoot = URL(fileURLWithPath: manifest.sourceRoot)
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else { throw CleanupError.sourceVolumeUnavailable }
        if let expectedVolumeID = manifest.sourceVolumeID {
            let currentVolume = try VolumeIdentity.resolve(for: sourceRoot)
            guard currentVolume.stableID == expectedVolumeID else {
                throw CleanupError.sourceVolumeChanged(expected: expectedVolumeID, actual: currentVolume.stableID)
            }
        }

        let states = try await database.fetchCleanupOperationStates(planID: planID)
        var checks: [RestoreOperationCheck] = []
        checks.reserveCapacity(manifest.operations.count)
        for operation in manifest.operations {
            try Task.checkCancellation()
            let original = URL(fileURLWithPath: operation.originalPath)
            let quarantined = URL(fileURLWithPath: operation.quarantinePath)
            let state = states[operation.operationID]
            let readiness: RestoreOperationReadiness
            let detail: String

            if state == .restored {
                readiness = .alreadyRestored
                detail = "The database already records this file as restored."
            } else if state != .quarantined {
                readiness = .notQuarantined
                detail = "Only operations currently recorded in quarantine can be restored."
            } else if FileManager.default.fileExists(atPath: original.path) {
                readiness = .originalOccupied
                detail = "Cullora will never overwrite the existing item at the original path."
            } else if !FileManager.default.fileExists(atPath: quarantined.path) {
                readiness = .quarantineMissing
                detail = "The expected quarantine file is unavailable. Reconnect the source or inspect the manifest."
            } else {
                do {
                    let current = try await hasher.hashFile(at: quarantined)
                    if current.digest == operation.digest, current.byteCount == operation.byteCount {
                        readiness = .ready
                        detail = "Digest and byte count match the signed manifest."
                    } else {
                        readiness = .contentChanged
                        detail = "The quarantine file no longer matches the signed manifest."
                    }
                } catch {
                    readiness = .contentChanged
                    detail = "Cullora could not verify the quarantine file: \(error.localizedDescription)"
                }
            }

            checks.append(
                RestoreOperationCheck(
                    id: operation.operationID,
                    displayName: original.lastPathComponent,
                    originalURL: original,
                    quarantineURL: quarantined,
                    byteCount: operation.byteCount,
                    readiness: readiness,
                    detail: detail
                )
            )
        }

        return RestorePlanPreview(
            id: manifest.planID,
            sourceRoot: sourceRoot,
            quarantineRoot: URL(fileURLWithPath: manifest.quarantineRoot),
            createdAt: manifest.createdAt,
            operations: checks
        )
    }

    func restore(planID: String) async throws -> CleanupRestoreResult {
        let manifest = try await verifiedManifest(planID: planID)
        let sourceRoot = URL(fileURLWithPath: manifest.sourceRoot)
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else { throw CleanupError.sourceVolumeUnavailable }
        if let expectedVolumeID = manifest.sourceVolumeID {
            let currentVolume = try VolumeIdentity.resolve(for: sourceRoot)
            guard currentVolume.stableID == expectedVolumeID else {
                throw CleanupError.sourceVolumeChanged(expected: expectedVolumeID, actual: currentVolume.stableID)
            }
        }

        let states = try await database.fetchCleanupOperationStates(planID: planID)
        var restored = 0
        var failed = 0
        for operation in manifest.operations {
            guard states[operation.operationID] == .quarantined else { continue }
            let original = URL(fileURLWithPath: operation.originalPath)
            let quarantined = URL(fileURLWithPath: operation.quarantinePath)
            do {
                if let expectedVolumeID = manifest.sourceVolumeID {
                    let operationVolume = try VolumeIdentity.resolve(for: quarantined)
                    guard operationVolume.stableID == expectedVolumeID else {
                        throw CleanupError.sourceVolumeChanged(expected: expectedVolumeID, actual: operationVolume.stableID)
                    }
                }
                guard FileManager.default.fileExists(atPath: quarantined.path) else {
                    throw CleanupError.sourceMissing(quarantined)
                }
                guard !FileManager.default.fileExists(atPath: original.path) else {
                    throw CleanupError.originalOccupied(original)
                }
                let current = try await hasher.hashFile(at: quarantined)
                guard current.digest == operation.digest, current.byteCount == operation.byteCount else {
                    throw CleanupError.contentChanged(quarantined)
                }
                try FileManager.default.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileMover.moveItem(from: quarantined, to: original)
                do {
                    try await database.markOperationRestored(
                        operationID: operation.operationID,
                        assetID: AssetID(rawValue: operation.assetID),
                        originalPath: original.path
                    )
                } catch {
                    if FileManager.default.fileExists(atPath: original.path),
                       !FileManager.default.fileExists(atPath: quarantined.path) {
                        try? FileManager.default.createDirectory(at: quarantined.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? fileMover.moveItem(from: original, to: quarantined)
                    }
                    throw error
                }
                restored += 1
            } catch {
                failed += 1
                try? await database.recordOperationError(operationID: operation.operationID, message: error.localizedDescription)
            }
        }

        let remaining = try await database.countOperations(planID: planID, state: .quarantined)
        let finalState: CleanupPlanState = remaining == 0 ? .restored : .partiallyRestored
        try await database.finishCleanupRestore(planID, state: finalState)
        try await database.rebuildExactGroups()
        let verification = try? await verifyLifecycle(manifest: manifest, phase: .postRestore)
        return CleanupRestoreResult(
            planID: planID,
            restoredCount: restored,
            failedCount: failed,
            verification: verification
        )
    }

    func verifyLifecycle(planID: String, phase: QuarantineVerificationPhase = .manualReview) async throws -> QuarantineVerificationReport {
        let manifest = try await verifiedManifest(planID: planID)
        return try await verifyLifecycle(manifest: manifest, phase: phase)
    }

    private func verifyLifecycle(
        manifest: CleanupManifest,
        phase: QuarantineVerificationPhase
    ) async throws -> QuarantineVerificationReport {
        let states = try await database.fetchCleanupOperationStates(planID: manifest.planID)
        var observed: [QuarantineObservedOperationState] = []
        observed.reserveCapacity(manifest.operations.count)
        for operation in manifest.operations {
            try Task.checkCancellation()
            let original = URL(fileURLWithPath: operation.originalPath)
            let quarantined = URL(fileURLWithPath: operation.quarantinePath)
            let databaseState = states[operation.operationID]
            let originalExists = FileManager.default.fileExists(atPath: original.path)
            let quarantineExists = FileManager.default.fileExists(atPath: quarantined.path)
            var observedDigest: String?
            var observedByteCount: Int64?
            let verificationURL: URL?
            switch databaseState {
            case .quarantined where quarantineExists:
                verificationURL = quarantined
            case .restored where originalExists:
                verificationURL = original
            default:
                verificationURL = nil
            }
            if let verificationURL {
                do {
                    let current = try await hasher.hashFile(at: verificationURL)
                    observedDigest = current.digest
                    observedByteCount = current.byteCount
                } catch {
                    observedDigest = nil
                    observedByteCount = nil
                }
            }
            observed.append(QuarantineObservedOperationState(
                operationID: operation.operationID,
                databaseState: databaseState,
                originalExists: originalExists,
                quarantineExists: quarantineExists,
                observedDigest: observedDigest,
                observedByteCount: observedByteCount
            ))
        }
        return QuarantineVerificationEngine.report(
            manifest: manifest,
            phase: phase,
            observed: observed
        )
    }


    private func verifiedManifest(planID: String) async throws -> CleanupManifest {
        guard let record = try await database.fetchManifestRecord(planID: planID) else {
            throw CleanupError.manifestUnavailable(planID)
        }
        guard FileManager.default.fileExists(atPath: record.path) else {
            throw CleanupError.manifestUnavailable(planID)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: record.path))
        let envelope = try ManifestSigner.canonicalDecoder.decode(SignedCleanupManifest.self, from: data)
        guard await signer.verify(envelope) else { throw CleanupError.manifestInvalid(planID) }
        let manifest = try await signer.decodedManifest(from: envelope)
        guard manifest.planID == planID else { throw CleanupError.manifestInvalid(planID) }
        return manifest
    }

    private static func isDescendant(_ url: URL, of root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return url.path == root.path || url.path.hasPrefix(rootPath)
    }

    private static func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return String(url.path.dropFirst(rootPath.count))
    }
}
