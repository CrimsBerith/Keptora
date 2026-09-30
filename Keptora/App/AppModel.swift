import UniformTypeIdentifiers
@preconcurrency import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedRoute: SidebarRoute? = .home
    @Published private(set) var sourceName = "No folder selected"
    @Published private(set) var sourceProvider = "Choose a local or cloud folder"
    @Published private(set) var sourceURL: URL?
    @Published private(set) var scanProgress = ScanProgress.idle
    @Published private(set) var duplicateGroups: [ReviewGroup] = []
    @Published private(set) var similarityGroups: [SimilarityReviewGroup] = []
    @Published var selectedSimilarityGroupID: String?
    @Published private(set) var similarityProgress = SimilarityProgress.idle
    @Published private(set) var lastSimilarityOutcome: SimilarityOutcome?
    @Published var selectedGroupID: String?
    @Published var selectedReviewAssetID: AssetID?
    @Published private(set) var decisions: [AssetID: ReviewDecision] = [:]
    @Published private(set) var decisionEvidence: [AssetID: ReviewDecisionEvidence] = [:]
    @Published private(set) var reviewSessionCheckpoint: ReviewSessionCheckpoint?
    @Published private(set) var isPreparingDemoLibrary = false
    @Published private(set) var reviewModeIsExact = true
    @Published var isShowingError = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var databaseSummary = DatabaseSummary.empty
    @Published private(set) var cleanupHistory: [CleanupHistoryItem] = []
    @Published var pendingPlan: CleanupPlanPreview?
    @Published private(set) var safetyPlanFreshness: SafetyPlanFreshnessAssessment?
    @Published private(set) var safetyPlanLineage: [SafetyPlanLineageRecord] = []
    @Published private(set) var quarantineVerificationLineage: [QuarantineVerificationLineageRecord] = []
    @Published var isShowingSafetyPlan = false
    @Published private(set) var isCommittingCleanup = false
    @Published private(set) var restoringPlanID: String?
    @Published private(set) var verifyingCleanupPlanID: String?
    @Published private(set) var isPreparingRestorePreview = false
    @Published var isShowingRestorePreview = false
    @Published private(set) var restorePreview: RestorePlanPreview?
    @Published private(set) var restorePreviewItem: CleanupHistoryItem?
    @Published private(set) var performanceSamples: [PerformanceSample] = []
    @Published private(set) var lastScanOutcome: ScanOutcome?
    @Published private(set) var sourceAvailability: SourceAvailability = .noSource
    @Published private(set) var recoveryIssues: [ReconciliationIssue] = []
    @Published var isShowingOnboarding = false

    private let bookmarkStore = SecurityScopedBookmarkStore()
    private let applicationSupportDirectory: URL
    private let database: SQLiteDatabase
    private let cleanupCoordinator: QuarantineCoordinator
    private let reconciliationCoordinator: ReconciliationCoordinator
    private let similarityCoordinator: SimilarityCoordinator
    private var scanTask: Task<Void, Never>?
    private var similarityTask: Task<Void, Never>?
    private var activeBatchTask: Task<Void, Never>?
    private let volumeObservers = WorkspaceObserverBag()
    private var expectedVolume: VolumeIdentity?
    private let bookmarkDefaultsKey = "Keptora.SourceBookmark.v1"
    private let volumeDefaultsKey = "Keptora.SourceVolume.v1"
    private let onboardingCompletedKey = "Keptora.Onboarding.Completed.v1"
    private let reviewCheckpointDefaultsKey = "Keptora.ReviewCheckpoint.v1"

    private var currentSimilaritySensitivity: SimilaritySensitivityPreset {
        SimilaritySensitivityPreset.stored()
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Keptora", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        applicationSupportDirectory = directory
        safetyPlanLineage = Self.loadSafetyPlanLineage(from: directory)
        quarantineVerificationLineage = Self.loadQuarantineVerificationLineage(from: directory)
        database = SQLiteDatabase(url: directory.appendingPathComponent("Keptora.sqlite"))
        cleanupCoordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: directory)
        reconciliationCoordinator = ReconciliationCoordinator(database: database)
        similarityCoordinator = SimilarityCoordinator(database: database)
        performanceSamples = PerformanceRecorder.read(in: directory)
        installVolumeObservers()
    }

    var canStartScan: Bool {
        sourceURL != nil && sourceAvailability.isAvailable && !scanProgress.isRunning && !isCommittingCleanup
    }

    func latestQuarantineVerification(for planID: String) -> QuarantineVerificationLineageRecord? {
        quarantineVerificationLineage
            .filter { $0.planID == planID }
            .max { $0.identity.revisionNumber < $1.identity.revisionNumber }
    }

    var selectedGroup: ReviewGroup? {
        guard let selectedGroupID else { return duplicateGroups.first }
        return duplicateGroups.first { $0.id == selectedGroupID }
    }

    var selectedSimilarityGroup: SimilarityReviewGroup? {
        guard let selectedSimilarityGroupID else { return similarityGroups.first }
        return similarityGroups.first { $0.id == selectedSimilarityGroupID }
    }

    var selectedReviewAsset: ReviewAsset? {
        guard let selectedReviewAssetID else { return selectedGroup?.assets.first }
        return selectedGroup?.assets.first { $0.id == selectedReviewAssetID }
    }

    var canNavigateExactGroups: Bool { selectedRoute == .review && reviewModeIsExact && duplicateGroups.count > 1 }
    var currentExactGroupIndex: Int {
        guard let selectedGroupID else { return 0 }
        return duplicateGroups.firstIndex(where: { $0.id == selectedGroupID }) ?? 0
    }
    var exactGroupPositionLabel: String {
        guard !duplicateGroups.isEmpty else { return "" }
        return "Set \(currentExactGroupIndex + 1) of \(duplicateGroups.count)"
    }

    var currentSimilarityGroupIndex: Int {
        guard let selectedSimilarityGroupID else { return 0 }
        return similarityGroups.firstIndex(where: { $0.id == selectedSimilarityGroupID }) ?? 0
    }
    var similarityGroupPositionLabel: String {
        guard !similarityGroups.isEmpty else { return "" }
        return "Group \(currentSimilarityGroupIndex + 1) of \(similarityGroups.count)"
    }
    var canNavigateSimilarityGroups: Bool { selectedRoute == .review && !reviewModeIsExact && similarityGroups.count > 1 }

    var canApplySelectedGroupBatch: Bool { selectedRoute == .review && reviewModeIsExact && (selectedGroup?.assets.count ?? 0) > 1 }
    var canApplyAllExactGroups: Bool {
        selectedRoute == .review && reviewModeIsExact && duplicateGroups.contains { group in
            group.assets.contains { asset in asset.id != group.canonicalAssetID }
        }
    }
    var canApplyFocusedReviewDecision: Bool { selectedRoute == .review && reviewModeIsExact && selectedReviewAsset != nil }

    var hasResumableReviewSession: Bool {
        guard let checkpoint = reviewSessionCheckpoint,
              checkpoint.sourceID == currentSourceID() else { return false }
        return duplicateGroups.contains { $0.id == checkpoint.groupID }
    }

    var reviewedCount: Int { decisions.filter { $0.value != .keep }.count }

    var plannedAssets: [ReviewAsset] {
        duplicateGroups.flatMap(\.assets).filter { decisions[$0.id] == .quarantinePlan }
    }

    var plannedBytes: Int64 { plannedAssets.reduce(0) { $0 + $1.byteCount } }

    var allSafeCopyCount: Int {
        duplicateGroups.reduce(0) { total, group in
            total + group.assets.filter { $0.id != group.canonicalAssetID }.count
        }
    }

    var allSafeCopyBytes: Int64 {
        duplicateGroups.reduce(0) { total, group in
            total + group.assets
                .filter { $0.id != group.canonicalAssetID }
                .reduce(0) { $0 + $1.byteCount }
        }
    }

    func evidence(for assetID: AssetID) -> ReviewDecisionEvidence? {
        decisionEvidence[assetID]
    }

    var selectedDecisionEvidence: ReviewDecisionEvidence? {
        guard let assetID = selectedReviewAsset?.id else { return nil }
        return decisionEvidence[assetID]
    }

    func progress(for group: ReviewGroup) -> ReviewGroupProgress {
        let extras = group.assets.filter { $0.id != group.canonicalAssetID }
        let planned = extras.filter { decisions[$0.id] == .quarantinePlan }.count
        let skipped = extras.filter { decisions[$0.id] == .skip }.count
        return ReviewGroupProgress(
            totalExtras: extras.count,
            planned: planned,
            skipped: skipped,
            undecided: max(0, extras.count - planned - skipped)
        )
    }

    var reviewInsights: ReviewInsights {
        let progress = duplicateGroups.map { self.progress(for: $0) }
        return ReviewInsights(
            totalGroups: duplicateGroups.count,
            unreviewedGroups: progress.filter { $0.state == .unreviewed }.count,
            inProgressGroups: progress.filter { $0.state == .inProgress }.count,
            plannedGroups: progress.filter { $0.state == .planned }.count,
            completeGroups: progress.filter { $0.state == .complete }.count,
            totalPotentialBytes: duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes },
            plannedBytes: plannedBytes,
            exactAssets: duplicateGroups.reduce(0) { $0 + $1.assets.count },
            similarGroups: similarityGroups.count
        )
    }

    private var isPrepared = false

    func prepare() async {
        // The SwiftUI window and the AppKit fallback window both call this; run it once.
        guard !isPrepared else { return }
        isPrepared = true
        let isPortfolioUITesting = ProcessInfo.processInfo.arguments.contains("-portfolioUITesting")
        isShowingOnboarding = !isPortfolioUITesting && !UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        do {
            try await database.initialize()
            // An unresolvable bookmark (folder deleted or moved) leaves no source selected;
            // it must not prevent history and decisions from loading.
            try? restoreBookmarkIfPresent()
            refreshSourceAvailability()
            if let sourceURL, sourceAvailability.isAvailable {
                recoveryIssues = try await bookmarkStore.withAccess(to: sourceURL) {
                    try await reconciliationCoordinator.reconcile(sourceRoot: sourceURL)
                }
            }
            try await reloadDatabaseState()
            restoreReviewCheckpointIfPresent()
            if ProcessInfo.processInfo.arguments.contains("-keptoraSelectionUITesting") {
                loadDemoLibrary()
            }
        } catch {
            isPrepared = false
            present(error)
        }
    }

    func chooseFolder() {
        chooseFolder(startingAt: nil)
    }

    func chooseCloudFolder() {
        chooseFolder(startingAt: FolderSourcePicker.cloudStartURL())
    }

    func connectFolderURL(_ url: URL) {
        do {
            let bookmark = try bookmarkStore.makeBookmark(for: url)
            UserDefaults.standard.set(bookmark, forKey: bookmarkDefaultsKey)
            sourceURL = url
            sourceName = url.lastPathComponent
            sourceProvider = FolderSourcePicker.providerLabel(for: url)
            selectedReviewAssetID = nil
            dismissReviewSession()
            expectedVolume = try VolumeIdentity.resolve(for: url)
            if let encoded = try? JSONEncoder().encode(expectedVolume) {
                UserDefaults.standard.set(encoded, forKey: volumeDefaultsKey)
            }
            refreshSourceAvailability()
            Task { [weak self] in
                try? await self?.reloadDatabaseState()
            }
        } catch {
            present(error)
        }
    }

    private func chooseFolder(startingAt directoryURL: URL?) {
        guard let url = FolderSourcePicker.chooseFolder(startingAt: directoryURL) else { return }
        connectFolderURL(url)
    }

    func startScan() {
        refreshSourceAvailability()
        guard let url = sourceURL, sourceAvailability.isAvailable, !scanProgress.isRunning else {
            if sourceURL != nil { present(SimpleAppError(message: sourceAvailability.label)) }
            return
        }
        scanTask?.cancel()
        selectedRoute = .home

        scanTask = Task { [weak self] in
            guard let self else { return }
            let startedAt = Date()
            do {
                let coordinator = ScanCoordinator(database: database)
                let keeperPolicy = KeeperSelectionPolicy(rawValue: UserDefaults.standard.string(forKey: KeeperSelectionPolicy.defaultsKey) ?? "") ?? .preserve
                let outcome = try await self.bookmarkStore.withAccess(to: url) {
                    try await coordinator.scan(folder: url, keeperPolicy: keeperPolicy) { progress in
                        await self.updateScanProgress(progress)
                    }
                }
                lastScanOutcome = outcome
                recordPerformance(label: "Exact scan", itemCount: outcome.discovered, startedAt: startedAt)
                duplicateGroups = outcome.groups
                selectedGroupID = outcome.groups.first?.id
                selectedReviewAssetID = outcome.groups.first?.canonicalAssetID
                scanProgress = .completed(outcome: outcome)
                try await reloadDatabaseState()
                if !outcome.groups.isEmpty {
                    selectedRoute = .review
                    checkpointReviewSession()
                }
            } catch is CancellationError {
                recordPerformance(label: "Exact scan", itemCount: scanProgress.processed, startedAt: startedAt, result: "cancelled")
                scanProgress = .cancelled
            } catch {
                recordPerformance(label: "Exact scan", itemCount: scanProgress.processed, startedAt: startedAt, result: "failed")
                scanProgress = .failed(message: error.localizedDescription)
                present(error)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    func startSimilarityAnalysis() {
        refreshSourceAvailability()
        guard let sourceURL, let sourceID = currentSourceID(), sourceAvailability.isAvailable, !similarityProgress.isRunning else {
            if self.sourceURL != nil { present(SimpleAppError(message: sourceAvailability.label)) }
            return
        }
        similarityTask?.cancel()
        selectedRoute = .review
        similarityTask = Task { [weak self] in
            guard let self else { return }
            let startedAt = Date()
            let sensitivity = self.currentSimilaritySensitivity
            do {
                let outcome = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.similarityCoordinator.analyze(sourceID: sourceID, sensitivity: sensitivity) { progress in
                        await self.updateSimilarityProgress(progress)
                    }
                }
                lastSimilarityOutcome = outcome
                recordPerformance(label: "Similarity analysis", itemCount: outcome.discoveredImages, startedAt: startedAt)
                similarityGroups = outcome.groups
                selectedSimilarityGroupID = outcome.groups.first?.id
                similarityProgress = SimilarityProgress(
                    phase: .completed, processed: outcome.discoveredImages, total: outcome.discoveredImages,
                    indexed: outcome.indexed, reused: outcome.reused, failed: outcome.failed,
                    comparedPairs: outcome.comparedPairs, currentItem: nil,
                    message: "\(outcome.groups.count) review-only similar sets ready · \(outcome.failed) safely skipped"
                )
            } catch is CancellationError {
                recordPerformance(label: "Similarity analysis", itemCount: similarityProgress.processed, startedAt: startedAt, result: "cancelled")
                similarityProgress = SimilarityProgress(
                    phase: .cancelled, processed: 0, total: 0, indexed: 0, reused: 0, failed: 0,
                    comparedPairs: 0, currentItem: nil, message: "Similarity analysis was cancelled safely"
                )
            } catch {
                recordPerformance(label: "Similarity analysis", itemCount: similarityProgress.processed, startedAt: startedAt, result: "failed")
                similarityProgress = SimilarityProgress(
                    phase: .failed, processed: 0, total: 0, indexed: 0, reused: 0, failed: 0,
                    comparedPairs: 0, currentItem: nil, message: error.localizedDescription
                )
                present(error)
            }
        }
    }

    func cancelSimilarityAnalysis() {
        similarityTask?.cancel()
        similarityTask = nil
    }

    func refreshSimilarityGroupsForCurrentSensitivity() {
        guard let sourceID = currentSourceID(), !similarityProgress.isRunning else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                similarityGroups = try await self.similarityCoordinator.fetchGroups(sourceID: sourceID, sensitivity: self.currentSimilaritySensitivity)
                if !similarityGroups.contains(where: { $0.id == self.selectedSimilarityGroupID }) { selectedSimilarityGroupID = similarityGroups.first?.id }
            } catch { present(error) }
        }
    }

    func reveal(_ asset: ReviewAsset) {
        NSWorkspace.shared.activateFileViewerSelecting([asset.fileURL])
    }

    func reloadDatabaseState() async throws {
        if let sourceURL {
            let selectedVolume: VolumeIdentity?
            if case .available(let volume) = sourceAvailability { selectedVolume = volume }
            else { selectedVolume = expectedVolume }
            let selectedSourceID = selectedVolume.map { SourceIdentity.folderID(for: sourceURL, volume: $0) }
                ?? SourceIdentity.folderID(for: sourceURL)
            duplicateGroups = try await database.fetchDuplicateGroups(sourceID: selectedSourceID)
            similarityGroups = try await similarityCoordinator.fetchGroups(sourceID: selectedSourceID, sensitivity: currentSimilaritySensitivity)
            let stored = try await database.fetchReviewDecisions(sourceID: selectedSourceID)
            decisions = Dictionary(stored.map { ($0.assetID, $0.decision) }, uniquingKeysWith: { _, newer in newer })
            let recordByAsset = Dictionary(stored.map { ($0.assetID, $0) }, uniquingKeysWith: { _, newer in newer })
            var evidenceByAsset: [AssetID: ReviewDecisionEvidence] = [:]
            evidenceByAsset.reserveCapacity(recordByAsset.count)
            for group in duplicateGroups {
                for asset in group.assets {
                    if let record = recordByAsset[asset.id] {
                        evidenceByAsset[asset.id] = ReviewDecisionEvidenceEngine.evidence(
                            group: group,
                            asset: asset,
                            record: record
                        )
                    }
                }
            }
            decisionEvidence = evidenceByAsset
            databaseSummary = try await database.summary(sourceID: selectedSourceID)
        } else {
            duplicateGroups = []
            similarityGroups = []
            decisions = [:]
            decisionEvidence = [:]
            databaseSummary = .empty
        }
        cleanupHistory = try await database.fetchCleanupHistory()
        if let selectedGroupID, !duplicateGroups.contains(where: { $0.id == selectedGroupID }) {
            self.selectedGroupID = duplicateGroups.first?.id
        } else if selectedGroupID == nil {
            selectedGroupID = duplicateGroups.first?.id
        }
        if let selectedSimilarityGroupID, !similarityGroups.contains(where: { $0.id == selectedSimilarityGroupID }) {
            self.selectedSimilarityGroupID = similarityGroups.first?.id
        } else if selectedSimilarityGroupID == nil {
            selectedSimilarityGroupID = similarityGroups.first?.id
        }
        ensureReviewFocus()
    }

    func setDecision(_ decision: ReviewDecision, for assetID: AssetID, access: StoreEntitlementController) {
        guard access.authorizeReview(assetID) else { return }
        guard let group = duplicateGroups.first(where: { group in group.assets.contains(where: { $0.id == assetID }) }) else { return }
        // The canonical keeper can never be queued for quarantine.
        if decision == .quarantinePlan, assetID == group.canonicalAssetID { return }
        decisions[assetID] = decision
        activeBatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await database.setDecision(groupID: group.id, assetID: assetID, decision: decision)
                // Only count against the free allowance once the decision is durably stored.
                access.recordReview(assetID)
                try await reloadDatabaseState()
                checkpointReviewSession()
            } catch {
                await rollbackOptimisticDecisions()
                present(error)
            }
        }
    }

    /// Replaces optimistic in-memory decisions with what the database actually holds.
    private func rollbackOptimisticDecisions() async {
        do { try await reloadDatabaseState() } catch { present(error) }
    }

    func applyBatchAction(_ action: ExactGroupBatchAction, to groupID: String, access: StoreEntitlementController) {
        guard let group = duplicateGroups.first(where: { $0.id == groupID }) else { return }
        let extras = group.assets.filter { $0.id != group.canonicalAssetID }
        guard !extras.isEmpty else { return }
        let assetIDs = extras.map(\.id)
        guard access.authorizeReviews(assetIDs) else { return }
        let decision: ReviewDecision = action == .planSafeExtras ? .quarantinePlan : .skip
        for id in assetIDs {
            decisions[id] = decision
        }

        activeBatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await database.applyExactGroupAction(
                    groupID: group.id,
                    keeperAssetID: group.canonicalAssetID,
                    extraAssetIDs: assetIDs,
                    action: action
                )
                access.recordReviews(assetIDs)
                try await reloadDatabaseState()
                checkpointReviewSession()
            } catch {
                await rollbackOptimisticDecisions()
                present(error)
            }
        }
    }

    func applyBatchActionToSelected(_ action: ExactGroupBatchAction, access: StoreEntitlementController) {
        guard let groupID = selectedGroup?.id else { return }
        applyBatchAction(action, to: groupID, access: access)
    }

    func applyBatchActionToAllExactGroups(_ action: ExactGroupBatchAction, access: StoreEntitlementController) {
        let eligibleGroups = duplicateGroups.filter { group in
            group.assets.contains { $0.id != group.canonicalAssetID }
        }
        let allAssetIDs = eligibleGroups.flatMap { group in
            group.assets.filter { $0.id != group.canonicalAssetID }.map(\.id)
        }
        guard !allAssetIDs.isEmpty, access.authorizeReviews(allAssetIDs) else { return }
        let decision: ReviewDecision = action == .planSafeExtras ? .quarantinePlan : .skip
        for id in allAssetIDs {
            decisions[id] = decision
        }

        activeBatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                for group in eligibleGroups {
                    let extras = group.assets.filter { $0.id != group.canonicalAssetID }.map(\.id)
                    guard !extras.isEmpty else { continue }
                    try await database.applyExactGroupAction(
                        groupID: group.id,
                        keeperAssetID: group.canonicalAssetID,
                        extraAssetIDs: extras,
                        action: action
                    )
                }
                access.recordReviews(allAssetIDs)
                try await reloadDatabaseState()
                checkpointReviewSession()
            } catch {
                await rollbackOptimisticDecisions()
                present(error)
            }
        }
    }

    func applyFocusedDecision(_ decision: ReviewDecision, access: StoreEntitlementController) {
        guard let assetID = selectedReviewAsset?.id else { return }
        setDecision(decision, for: assetID, access: access)
    }

    func applySwipeDecisions(cleanupAssetIDs: [AssetID], access: StoreEntitlementController) {
        // Invariant: Protected keepers and canonical assets can NEVER be queued for quarantine
        var safeAssetIDs: [AssetID] = []
        for id in cleanupAssetIDs {
            if let group = duplicateGroups.first(where: { g in g.assets.contains(where: { $0.id == id }) }) {
                if id != group.canonicalAssetID {
                    safeAssetIDs.append(id)
                }
            }
        }

        guard !safeAssetIDs.isEmpty, access.authorizeReviews(safeAssetIDs) else { return }

        for id in safeAssetIDs {
            decisions[id] = .quarantinePlan
        }

        activeBatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                for id in safeAssetIDs {
                    if let group = self.duplicateGroups.first(where: { g in g.assets.contains(where: { $0.id == id }) }) {
                        try await self.database.setDecision(groupID: group.id, assetID: id, decision: .quarantinePlan)
                        access.recordReview(id)
                    }
                }
                try await self.reloadDatabaseState()
                self.checkpointReviewSession()
            } catch {
                await self.rollbackOptimisticDecisions()
                self.present(error)
            }
        }
    }

    func selectPreviousExactGroup() { navigateExactGroup(offset: -1) }
    func selectNextExactGroup() { navigateExactGroup(offset: 1) }

    func selectPreviousSimilarityGroup() {
        guard !similarityGroups.isEmpty else { return }
        let current = similarityGroups.firstIndex { $0.id == selectedSimilarityGroupID } ?? 0
        let target = max(0, current - 1)
        selectedSimilarityGroupID = similarityGroups[target].id
    }
    func selectNextSimilarityGroup() {
        guard !similarityGroups.isEmpty else { return }
        let current = similarityGroups.firstIndex { $0.id == selectedSimilarityGroupID } ?? 0
        let target = min(similarityGroups.count - 1, current + 1)
        selectedSimilarityGroupID = similarityGroups[target].id
    }

    func focusPreviousReviewAsset() { navigateReviewAsset(offset: -1) }
    func focusNextReviewAsset() { navigateReviewAsset(offset: 1) }

    func setReviewModeExact(_ exact: Bool) { reviewModeIsExact = exact }

    func ensureReviewFocus() {
        guard let group = selectedGroup else {
            selectedReviewAssetID = nil
            return
        }
        if !group.assets.contains(where: { $0.id == selectedReviewAssetID }) {
            selectedReviewAssetID = group.canonicalAssetID
        }
    }

    func checkpointReviewSession() {
        guard let sourceID = currentSourceID(),
              let group = selectedGroup,
              let index = duplicateGroups.firstIndex(where: { $0.id == group.id }) else { return }
        let now = Date()
        let startedAt = reviewSessionCheckpoint?.sourceID == sourceID
            ? reviewSessionCheckpoint?.startedAt ?? now
            : now
        let completedGroups = duplicateGroups.filter { progress(for: $0).state != .unreviewed && progress(for: $0).undecided == 0 }.count
        let checkpoint = ReviewSessionCheckpoint(
            sourceID: sourceID,
            sourceName: sourceName,
            groupID: group.id,
            focusedAssetID: selectedReviewAssetID,
            groupPosition: index + 1,
            totalGroups: duplicateGroups.count,
            reviewedAssets: reviewedCount,
            completedGroups: completedGroups,
            plannedBytes: plannedBytes,
            startedAt: startedAt,
            updatedAt: now
        )
        reviewSessionCheckpoint = checkpoint
        if let data = try? JSONEncoder().encode(checkpoint) {
            UserDefaults.standard.set(data, forKey: reviewCheckpointDefaultsKey)
        }
    }

    func resumeReviewSession() {
        guard let checkpoint = reviewSessionCheckpoint,
              checkpoint.sourceID == currentSourceID(),
              duplicateGroups.contains(where: { $0.id == checkpoint.groupID }) else { return }
        selectedGroupID = checkpoint.groupID
        selectedReviewAssetID = checkpoint.focusedAssetID
        ensureReviewFocus()
        reviewModeIsExact = true
        selectedRoute = .review
        checkpointReviewSession()
    }

    func dismissReviewSession() {
        reviewSessionCheckpoint = nil
        UserDefaults.standard.removeObject(forKey: reviewCheckpointDefaultsKey)
    }

    func loadDemoLibrary() {
        guard !isPreparingDemoLibrary && !scanProgress.isRunning else { return }
        isPreparingDemoLibrary = true
        Task { [weak self] in
            guard let self else { return }
            defer { isPreparingDemoLibrary = false }
            do {
                let url = try DemoLibraryFactory.prepare(in: applicationSupportDirectory)
                // Keep the user's real bookmark unless the demo bookmark was created successfully.
                if let bookmark = try? bookmarkStore.makeBookmark(for: url) {
                    UserDefaults.standard.set(bookmark, forKey: bookmarkDefaultsKey)
                }
                sourceURL = url
                sourceName = "Keptora Demo Library"
                sourceProvider = "Keptora Sample Library"
                expectedVolume = try VolumeIdentity.resolve(for: url)
                if let encoded = try? JSONEncoder().encode(expectedVolume) {
                    UserDefaults.standard.set(encoded, forKey: volumeDefaultsKey)
                }
                selectedReviewAssetID = nil
                dismissReviewSession()
                refreshSourceAvailability()
                startScan()
            } catch {
                present(error)
            }
        }
    }

    private func navigateExactGroup(offset: Int) {
        guard !duplicateGroups.isEmpty else { return }
        let current = duplicateGroups.firstIndex { $0.id == selectedGroupID } ?? 0
        let target = min(max(current + offset, 0), duplicateGroups.count - 1)
        selectedGroupID = duplicateGroups[target].id
        selectedReviewAssetID = duplicateGroups[target].canonicalAssetID
        selectedRoute = .review
        checkpointReviewSession()
    }

    private func navigateReviewAsset(offset: Int) {
        guard let group = selectedGroup, !group.assets.isEmpty else { return }
        let current = group.assets.firstIndex { $0.id == selectedReviewAssetID } ?? 0
        let target = min(max(current + offset, 0), group.assets.count - 1)
        selectedReviewAssetID = group.assets[target].id
        checkpointReviewSession()
    }

    private func restoreReviewCheckpointIfPresent() {
        guard let data = UserDefaults.standard.data(forKey: reviewCheckpointDefaultsKey),
              let checkpoint = try? JSONDecoder().decode(ReviewSessionCheckpoint.self, from: data),
              checkpoint.sourceID == currentSourceID(),
              duplicateGroups.contains(where: { $0.id == checkpoint.groupID }) else {
            reviewSessionCheckpoint = nil
            return
        }
        reviewSessionCheckpoint = checkpoint
    }

    func prepareSafetyPlan(access: StoreEntitlementController) {
        guard access.authorizeSafetyPlan(assetIDs: plannedAssets.map(\.id)) else { return }
        guard let sourceURL else { return }
        Task { [weak self] in
            guard let self else { return }
            if let active = self.activeBatchTask {
                _ = await active.value
            }
            do {
                let plan = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.cleanupCoordinator.preparePlan(sourceRoot: sourceURL)
                }
                let lineage = SafetyPlanLineageEngine.nextIdentity(records: safetyPlanLineage, sourceRoot: plan.sourceRoot)
                let enriched = plan.withLineage(lineage)
                appendSafetyPlanLineage(for: enriched, state: .prepared)
                pendingPlan = enriched
                safetyPlanFreshness = SafetyPlanFreshnessAssessment(
                    state: .current,
                    expectedFingerprint: enriched.decisionSnapshotFingerprint,
                    currentFingerprint: enriched.decisionSnapshotFingerprint ?? "",
                    expectedOperationCount: enriched.operations.count,
                    currentOperationCount: enriched.operations.count
                )
                isShowingSafetyPlan = true
                try await reloadDatabaseState()
            } catch {
                present(error)
            }
        }
    }

    func refreshSafetyPlanFreshness() {
        guard let plan = pendingPlan, !isCommittingCleanup else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let assessment = try await self.bookmarkStore.withAccess(to: plan.sourceRoot) {
                    try await self.cleanupCoordinator.assessFreshness(plan)
                }
                safetyPlanFreshness = assessment
                if !assessment.permitsCommit { markSafetyPlanLineage(plan, state: .stale) }
            } catch {
                present(error)
            }
        }
    }

    func regenerateSafetyPlan(access: StoreEntitlementController) {
        guard let oldPlan = pendingPlan, !isCommittingCleanup else { return }
        guard access.authorizeSafetyPlan(assetIDs: plannedAssets.map(\.id)) else { return }
        markSafetyPlanLineage(oldPlan, state: .superseded)
        pendingPlan = nil
        safetyPlanFreshness = nil
        Task { [weak self] in
            guard let self else { return }
            try? await database.discardDraftCleanupPlan(oldPlan.id)
            guard let sourceURL else { return }
            do {
                let plan = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.cleanupCoordinator.preparePlan(sourceRoot: sourceURL)
                }
                let lineage = SafetyPlanLineageEngine.nextIdentity(records: safetyPlanLineage, sourceRoot: plan.sourceRoot)
                let enriched = plan.withLineage(lineage)
                appendSafetyPlanLineage(for: enriched, state: .prepared)
                pendingPlan = enriched
                safetyPlanFreshness = SafetyPlanFreshnessAssessment(
                    state: .current,
                    expectedFingerprint: enriched.decisionSnapshotFingerprint,
                    currentFingerprint: enriched.decisionSnapshotFingerprint ?? "",
                    expectedOperationCount: enriched.operations.count,
                    currentOperationCount: enriched.operations.count
                )
                isShowingSafetyPlan = true
                try await reloadDatabaseState()
            } catch {
                present(error)
            }
        }
    }


    func exportPendingSafetyPlan() {
        guard let plan = pendingPlan else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Keptora-Safety-Plan-\(plan.id.prefix(8)).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(plan).write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            present(error)
        }
    }

    func cancelSafetyPlan() {
        guard let plan = pendingPlan, !isCommittingCleanup else {
            isShowingSafetyPlan = false
            return
        }
        markSafetyPlanLineage(plan, state: .cancelled)
        pendingPlan = nil
        safetyPlanFreshness = nil
        isShowingSafetyPlan = false
        Task { [weak self] in
            guard let self else { return }
            try? await database.discardDraftCleanupPlan(plan.id)
            try? await reloadDatabaseState()
        }
    }

    func commitSafetyPlan(access: StoreEntitlementController) {
        guard let plan = pendingPlan else { return }
        guard access.authorizeSafetyPlan(assetIDs: plan.operations.map(\.assetID)) else {
            isShowingSafetyPlan = false
            return
        }
        refreshSourceAvailability()
        guard let sourceURL, sourceAvailability.isAvailable, !isCommittingCleanup else {
            if pendingPlan != nil { present(SimpleAppError(message: sourceAvailability.label)) }
            return
        }
        isCommittingCleanup = true
        Task { [weak self] in
            guard let self else { return }
            let startedAt = Date()
            defer { isCommittingCleanup = false }
            do {
                let freshness = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.cleanupCoordinator.assessFreshness(plan)
                }
                safetyPlanFreshness = freshness
                guard freshness.permitsCommit else {
                    markSafetyPlanLineage(plan, state: .stale)
                    present(SimpleAppError(message: "This Safety Plan is stale because exact-review decisions changed after it was prepared. Regenerate the plan before moving any files."))
                    return
                }
                let result = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.cleanupCoordinator.commit(plan, appVersion: self.appVersion)
                }
                recordPerformance(label: "Quarantine commit", itemCount: result.movedCount + result.failedCount, startedAt: startedAt, result: result.failedCount == 0 ? "completed" : "partial")
                if let verification = result.verification { appendQuarantineVerification(verification) }
                markSafetyPlanLineage(plan, state: result.movedCount > 0 ? .committed : .failed)
                pendingPlan = nil
                safetyPlanFreshness = nil
                isShowingSafetyPlan = false
                try await reloadDatabaseState()
                selectedRoute = .history
            } catch {
                markSafetyPlanLineage(plan, state: .failed)
                present(error)
            }
        }
    }


    func prepareRestorePreview(_ item: CleanupHistoryItem) {
        refreshSourceAvailability()
        guard sourceAvailability.isAvailable else {
            present(SimpleAppError(message: sourceAvailability.label))
            return
        }
        guard let sourceURL, sourceURL.standardizedFileURL.path == URL(fileURLWithPath: item.sourcePath).standardizedFileURL.path else {
            present(SimpleAppError(message: "Choose the original source folder before reviewing this restore."))
            return
        }
        guard !isPreparingRestorePreview, restoringPlanID == nil else { return }
        restorePreviewItem = item
        isPreparingRestorePreview = true
        Task { [weak self] in
            guard let self else { return }
            defer { isPreparingRestorePreview = false }
            do {
                let preview = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.cleanupCoordinator.previewRestore(planID: item.id)
                }
                restorePreview = preview
                restorePreviewItem = item
                isShowingRestorePreview = true
            } catch {
                restorePreviewItem = nil
                present(error)
            }
        }
    }

    func cancelRestorePreview() {
        restorePreview = nil
        restorePreviewItem = nil
        isShowingRestorePreview = false
    }

    func confirmRestorePreview() {
        guard let item = restorePreviewItem, restorePreview?.canRestore == true else { return }
        isShowingRestorePreview = false
        restorePreview = nil
        restorePreviewItem = nil
        restore(item)
    }

    func restore(_ item: CleanupHistoryItem) {
        refreshSourceAvailability()
        guard sourceAvailability.isAvailable else {
            present(SimpleAppError(message: sourceAvailability.label))
            return
        }
        guard let sourceURL, sourceURL.standardizedFileURL.path == URL(fileURLWithPath: item.sourcePath).standardizedFileURL.path else {
            present(SimpleAppError(message: "Choose the original source folder before restoring this plan."))
            return
        }
        restoringPlanID = item.id
        Task { [weak self] in
            guard let self else { return }
            let startedAt = Date()
            defer { restoringPlanID = nil }
            do {
                let result = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.cleanupCoordinator.restore(planID: item.id)
                }
                recordPerformance(label: "Restore", itemCount: result.restoredCount + result.failedCount, startedAt: startedAt, result: result.failedCount == 0 ? "completed" : "partial")
                if let verification = result.verification { appendQuarantineVerification(verification) }
                try await reloadDatabaseState()
            } catch {
                present(error)
            }
        }
    }

    func verifyCleanupState(_ item: CleanupHistoryItem) {
        refreshSourceAvailability()
        guard sourceAvailability.isAvailable else {
            present(SimpleAppError(message: sourceAvailability.label))
            return
        }
        guard let sourceURL, sourceURL.standardizedFileURL.path == URL(fileURLWithPath: item.sourcePath).standardizedFileURL.path else {
            present(SimpleAppError(message: "Choose the original source folder before verifying this quarantine record."))
            return
        }
        guard verifyingCleanupPlanID == nil, !isCommittingCleanup, restoringPlanID == nil else { return }
        verifyingCleanupPlanID = item.id
        Task { [weak self] in
            guard let self else { return }
            defer { verifyingCleanupPlanID = nil }
            do {
                let report = try await self.bookmarkStore.withAccess(to: sourceURL) {
                    try await self.cleanupCoordinator.verifyLifecycle(planID: item.id, phase: .manualReview)
                }
                appendQuarantineVerification(report)
            } catch {
                present(error)
            }
        }
    }

    func revealManifest(_ item: CleanupHistoryItem) {
        guard let path = item.manifestPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    var displayVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "182"
        return "\(version) (\(build))"
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        isShowingOnboarding = false
    }

    func showOnboarding() { isShowingOnboarding = true }

    func copyDiagnostics() {
        do {
            try DiagnosticsExporter.copy(makeDiagnosticsSnapshot())
        } catch {
            present(error)
        }
    }

    func exportDiagnostics() {
        do {
            if let url = try DiagnosticsExporter.export(makeDiagnosticsSnapshot()) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            present(error)
        }
    }

    func exportPerformanceHistory() {
        do {
            if let url = try PerformanceRecorder.export(performanceSamples) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            present(error)
        }
    }

    func makeDiagnosticsSnapshot() -> DiagnosticsSnapshot {
        let showPaths = UserDefaults.standard.bool(forKey: "Keptora.ShowFilePaths")
        let paths = [sourceURL?.path, NSHomeDirectory()].compactMap { $0 }
        let sourceReference: String
        if let sourceURL { sourceReference = showPaths ? sourceURL.path : "<selected-folder-redacted>" }
        else { sourceReference = "none" }
        let scanSummary = lastScanOutcome.map {
            "discovered=\($0.discovered), hashed=\($0.hashed), reused=\($0.reused), missing=\($0.missing)"
        } ?? "none"
        let similaritySummary = lastSimilarityOutcome.map {
            "images=\($0.discoveredImages), indexed=\($0.indexed), reused=\($0.reused), failed=\($0.failed), compared=\($0.comparedPairs), groups=\($0.groups.count)"
        } ?? "none"
        let rawError = errorMessage.map { DiagnosticsRedactor.redact($0, sensitivePaths: paths) }
        return DiagnosticsSnapshot(
            generatedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "182",
            implementationPhase: "5S",
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: Self.architectureLabel,
            scanState: scanProgress.label,
            similarityState: similarityProgress.label,
            sourceState: sourceAvailability.label,
            sourceReference: sourceReference,
            indexedAssets: databaseSummary.indexedAssets,
            activeAssets: databaseSummary.activeAssets,
            duplicateGroups: databaseSummary.duplicateGroups,
            quarantinedAssets: databaseSummary.quarantinedAssets,
            recoveryIssueCount: recoveryIssues.count,
            lastScanSummary: scanSummary,
            lastSimilaritySummary: similaritySummary,
            recentPerformance: Array(performanceSamples.suffix(10)),
            error: rawError
        )
    }

    private func recordPerformance(label: String, itemCount: Int, startedAt: Date, result: String = "completed") {
        let sample = PerformanceSample(
            label: label,
            itemCount: itemCount,
            elapsedSeconds: Date().timeIntervalSince(startedAt),
            result: result
        )
        do {
            performanceSamples = try PerformanceRecorder.append(sample, in: applicationSupportDirectory)
        } catch {
            // Performance history is diagnostic-only and must never block user work.
        }
    }

    private static var architectureLabel: String {
#if arch(arm64)
        return "arm64"
#elseif arch(x86_64)
        return "x86_64"
#else
        return "unknown"
#endif
    }

    private func currentSourceID() -> SourceID? {
        guard let sourceURL else { return nil }
        let selectedVolume: VolumeIdentity?
        if case .available(let volume) = sourceAvailability { selectedVolume = volume }
        else { selectedVolume = expectedVolume }
        return selectedVolume.map { SourceIdentity.folderID(for: sourceURL, volume: $0) }
            ?? SourceIdentity.folderID(for: sourceURL)
    }

    private static func loadQuarantineVerificationLineage(from directory: URL) -> [QuarantineVerificationLineageRecord] {
        let url = directory.appendingPathComponent("QuarantineVerificationLineage.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QuarantineVerificationLineageRecord].self, from: data)) ?? []
    }

    private func persistQuarantineVerificationLineage() {
        let url = applicationSupportDirectory.appendingPathComponent("QuarantineVerificationLineage.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(quarantineVerificationLineage).write(to: url, options: .atomic)
        } catch {
            present(error)
        }
    }

    private func appendQuarantineVerification(_ report: QuarantineVerificationReport) {
        let record = QuarantineVerificationEngine.lineageRecord(
            report: report,
            existing: quarantineVerificationLineage
        )
        quarantineVerificationLineage.append(record)
        persistQuarantineVerificationLineage()
    }

    private static func loadSafetyPlanLineage(from directory: URL) -> [SafetyPlanLineageRecord] {
        let url = directory.appendingPathComponent("SafetyPlanLineage.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SafetyPlanLineageRecord].self, from: data)) ?? []
    }

    private func persistSafetyPlanLineage() {
        let url = applicationSupportDirectory.appendingPathComponent("SafetyPlanLineage.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(safetyPlanLineage).write(to: url, options: .atomic)
        } catch {
            present(error)
        }
    }

    private func appendSafetyPlanLineage(for plan: CleanupPlanPreview, state: SafetyPlanLineageState) {
        guard let lineage = plan.lineage, let fingerprint = plan.decisionSnapshotFingerprint else { return }
        safetyPlanLineage.append(SafetyPlanLineageRecord(
            lineage: lineage,
            planID: plan.id,
            sourceRoot: plan.sourceRoot.standardizedFileURL.path,
            decisionSnapshotFingerprint: fingerprint,
            operationCount: plan.operations.count,
            createdAt: plan.createdAt,
            state: state
        ))
        persistSafetyPlanLineage()
    }

    private func markSafetyPlanLineage(_ plan: CleanupPlanPreview, state: SafetyPlanLineageState) {
        guard let lineageID = plan.lineage?.lineageID,
              let index = safetyPlanLineage.lastIndex(where: { $0.lineage.lineageID == lineageID }) else { return }
        safetyPlanLineage[index].state = state
        persistSafetyPlanLineage()
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private func restoreBookmarkIfPresent() throws {
        guard let data = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else { return }
        let resolved = try bookmarkStore.resolve(data)
        sourceURL = resolved.url
        sourceName = resolved.url.lastPathComponent
        sourceProvider = FolderSourcePicker.providerLabel(for: resolved.url)
        if let data = UserDefaults.standard.data(forKey: volumeDefaultsKey) {
            expectedVolume = try? JSONDecoder().decode(VolumeIdentity.self, from: data)
        }
        if resolved.stale {
            // Best effort: a failed refresh must not stop the database state from loading.
            if let refreshed = try? bookmarkStore.makeBookmark(for: resolved.url) {
                UserDefaults.standard.set(refreshed, forKey: bookmarkDefaultsKey)
            }
        }
    }

    func refreshSourceAvailability() {
        guard let sourceURL else {
            sourceAvailability = .noSource
            return
        }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            sourceAvailability = .disconnected(expected: expectedVolume)
            return
        }
        do {
            let actual = try VolumeIdentity.resolve(for: sourceURL)
            if let expectedVolume, !expectedVolume.matches(actual) {
                sourceAvailability = .replaced(expected: expectedVolume, actual: actual)
            } else {
                sourceAvailability = .available(actual)
                if expectedVolume == nil {
                    expectedVolume = actual
                    if let encoded = try? JSONEncoder().encode(actual) {
                        UserDefaults.standard.set(encoded, forKey: volumeDefaultsKey)
                    }
                }
            }
        } catch {
            sourceAvailability = .disconnected(expected: expectedVolume)
        }
    }

    private func installVolumeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    try? self?.restoreBookmarkIfPresent()
                    self?.refreshSourceAvailability()
                    if self?.sourceAvailability.isAvailable == true {
                        try? await self?.reloadDatabaseState()
                    }
                }
            }
            volumeObservers.append(token)
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }

    private func updateScanProgress(_ progress: ScanProgress) {
        scanProgress = progress
    }

    private func updateSimilarityProgress(_ progress: SimilarityProgress) {
        similarityProgress = progress
    }
}

private struct SimpleAppError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private final class WorkspaceObserverBag: @unchecked Sendable {
    private let center = NSWorkspace.shared.notificationCenter
    private var tokens: [NSObjectProtocol] = []

    func append(_ token: NSObjectProtocol) {
        tokens.append(token)
    }

    deinit {
        tokens.forEach { center.removeObserver($0) }
    }
}
