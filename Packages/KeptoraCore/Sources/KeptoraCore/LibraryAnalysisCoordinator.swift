import Foundation

public enum LibraryAnalysisUpdate: Sendable {
    case catalogue([UniversalMediaAsset], [LibrarySourceCoverage], LibrarySourceCatalogue)
    case progress(AnalysisStage, AnalysisStageProgress)
    case exact([UniversalExactGroup], [String: UniversalExactFingerprint], [UniversalMediaAsset], [AnalysisIssue])
    case photoGroups([UniversalSimilarityGroup])
    case exactGroups([UniversalExactGroup])
    case photos([UniversalSimilarityGroup], [String: QualityAssessment], [AnalysisIssue])
    case findings([String: QualityAssessment], [AnalysisIssue])
    case videos([UniversalSimilarityGroup], [AnalysisIssue])
    case failure(AnalysisStage, String)
    case metrics(AnalysisStage, AnalysisWorkMetrics)
    case finished(AnalysisSessionProgress)
}

/// Three bounded passes share one catalogue. Each photo is decoded once for both
/// quality and similarity. Large original hashing cannot hold back preview results.
public actor LibraryAnalysisCoordinator {
    private var session = AnalysisSessionProgress()
    private var lastProgress: [AnalysisStage: Date] = [:]
    private let receive: @Sendable (LibraryAnalysisUpdate) async -> Void
    private var configuration = LibraryConfiguration()
    private var control: LibraryAnalysisControl?
    public init(receive: @escaping @Sendable (LibraryAnalysisUpdate) async -> Void) { self.receive = receive }

    private func progress(_ stage: AnalysisStage, done: Int, total: Int) async {
        guard session.stages[stage]?.isTerminal != true else { return }
        let now = Date()
        guard done == 0 || done == total || now.timeIntervalSince(lastProgress[stage] ?? .distantPast) >= 0.1 else { return }
        lastProgress[stage] = now
        let value = AnalysisStageProgress(status: .running, processed: done, total: total)
        session.update(stage, value); await receive(.progress(stage, value))
    }
    private func complete(_ stage: AnalysisStage, count: Int, issues: [AnalysisIssue]) async {
        let value = AnalysisStageProgress(status: issues.isEmpty ? .completed : .partial, processed: count, total: count)
        session.update(stage, value); await receive(.progress(stage, value))
    }
    private func fail(_ stage: AnalysisStage, error: Error) async {
        let value = AnalysisStageProgress(status: .failed)
        session.update(stage, value); await receive(.progress(stage, value))
        await receive(.failure(stage, error.localizedDescription))
    }
    public func run(adapter: UnifiedLibraryAdapter, allowNetwork: Bool,
                    configuration: LibraryConfiguration = .init(), control: LibraryAnalysisControl? = nil,
                    checkpoint: UniversalScanCheckpoint? = nil,
                    checkpointUpdate: @escaping @Sendable (UniversalScanCheckpoint) -> Void = { _ in }) async throws {
        self.configuration = configuration; self.control = control
        try await control?.waitIfPaused()
        await progress(.catalogue, done: 0, total: 0)
        let assets = try await adapter.enumerateAssets(onSourceBatch: { items, coverage, catalogue in
            await self.receive(.catalogue(items, coverage, catalogue))
        })
        let coverage = await adapter.coverage
        await receive(.catalogue(assets, coverage, await adapter.catalogue))
        let catalogueStatus = AnalysisStageProgress(status: coverage.contains { $0.error != nil } ? .partial : .completed,
                                                   processed: assets.count, total: assets.count)
        session.update(.catalogue, catalogueStatus); await receive(.progress(.catalogue, catalogueStatus))
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.exact(assets, adapter: adapter, allowNetwork: allowNetwork, checkpoint: checkpoint, checkpointUpdate: checkpointUpdate) }
                group.addTask { try await self.photos(assets, adapter: adapter, allowNetwork: allowNetwork) }
                if configuration.similarityEnabled {
                    group.addTask { try await self.videos(assets, adapter: adapter, allowNetwork: allowNetwork) }
                } else {
                    await complete(.videos, count: 0, issues: [])
                }
                try await group.waitForAll()
            }
            try Task.checkCancellation()
            await MediaFingerprintDiskCache.shared.persistToDisk()
            await receive(.finished(session))
        } catch {
            session.cancel()
            await MediaFingerprintDiskCache.shared.persistToDisk()
            throw error
        }
    }
    private func exact(_ assets: [UniversalMediaAsset], adapter: UnifiedLibraryAdapter, allowNetwork: Bool,
                       checkpoint: UniversalScanCheckpoint?, checkpointUpdate: @escaping @Sendable (UniversalScanCheckpoint) -> Void) async throws {
        do {
            let scanner = UniversalExactScanner()
            let result = try await scanner.scan(adapter: adapter, allowNetwork: allowNetwork,
                fingerprintAllAssets: true, preloadedAssets: assets, resuming: checkpoint, control: control,
                checkpointInterval: configuration.checkpointInterval, checkpointUpdate: checkpointUpdate, groupsUpdate: { groups in Task { await self.exactGroups(groups) } }) { done, total, _ in
                    Task { await self.progress(.exact, done: done, total: total) }
                }
            try Task.checkCancellation()
            await receive(.exact(configuredExact(result.groups), result.fingerprintsByAssetID, result.assets, result.issues))
            await receive(.metrics(.exact, await scanner.metrics))
            await complete(.exact, count: assets.count, issues: result.issues)
        } catch is CancellationError { throw CancellationError() }
        catch { await fail(.exact, error: error) }
    }
    private func photos(_ assets: [UniversalMediaAsset], adapter: UnifiedLibraryAdapter, allowNetwork: Bool) async throws {
        let analyzer = VisualSimilarityAnalyzer()
        do {
            let groups = try await analyzer.analyze(assets: assets, provider: adapter, allowNetwork: allowNetwork,
                threshold: configuration.visualThreshold, control: control, similarityEnabled: configuration.similarityEnabled,
                groupsUpdate: { groups in Task { await self.photoGroups(groups) } },
                findings: { quality, issues in Task { await self.photoFindings(quality, issues) } }) { done, total in
                    Task { await self.progress(.photos, done: done, total: total) }
                }
            try Task.checkCancellation()
            let issues = await analyzer.issues
            await receive(.photos(configuredSimilar(groups), await analyzer.qualityAssessments, issues))
            await receive(.metrics(.photos, await analyzer.metrics))
            await complete(.photos, count: assets.filter { $0.mediaKind == .image }.count, issues: issues)
        } catch is CancellationError { throw CancellationError() }
        catch { await fail(.photos, error: error) }
    }
    private func photoGroups(_ groups: [UniversalSimilarityGroup]) async {
        guard session.stages[.photos]?.isTerminal != true else { return }
        await receive(.photoGroups(configuredSimilar(groups)))
    }
    private func exactGroups(_ groups: [UniversalExactGroup]) async {
        guard session.stages[.exact]?.isTerminal != true else { return }
        await receive(.exactGroups(configuredExact(groups)))
    }
    private func photoFindings(_ quality: [String: QualityAssessment], _ issues: [AnalysisIssue]) async {
        guard session.stages[.photos]?.isTerminal != true else { return }
        await receive(.findings(quality, issues))
    }
    private func videos(_ assets: [UniversalMediaAsset], adapter: UnifiedLibraryAdapter, allowNetwork: Bool) async throws {
        let analyzer = VideoSimilarityAnalyzer()
        do {
            let groups = try await analyzer.analyze(assets: assets, provider: adapter, allowNetwork: allowNetwork, control: control) { done, total in
                Task { await self.progress(.videos, done: done, total: total) }
            }
            try Task.checkCancellation()
            let issues = await analyzer.issues
            await receive(.videos(configuredSimilar(groups), issues))
            await complete(.videos, count: assets.filter { $0.mediaKind == .video }.count, issues: issues)
        } catch is CancellationError { throw CancellationError() }
        catch { await fail(.videos, error: error) }
    }
    private func configuredExact(_ groups: [UniversalExactGroup]) -> [UniversalExactGroup] {
        groups.map { .init(digest: $0.digest, assets: $0.assets, keeperID: configuration.keeperID(in: $0.assets)) }
    }
    private func configuredSimilar(_ groups: [UniversalSimilarityGroup]) -> [UniversalSimilarityGroup] {
        guard configuration.similarityEnabled else { return [] }
        return groups.map { .init(id: $0.id, assets: $0.assets, maximumDistance: $0.maximumDistance, strength: $0.strength,
                          mediaKind: $0.mediaKind, keeperID: configuration.keeperID(in: $0.assets)) }
    }
}
