import Foundation

actor SimilarityCoordinator {
    enum CoordinatorError: LocalizedError {
        case featureFlagDisabled

        var errorDescription: String? {
            switch self {
            case .featureFlagDisabled: return "Enable on-device similar photo analysis in Settings first."
            }
        }
    }

    private let database: SQLiteDatabase
    private let engine: SimilarityEngine
    private let groupBuilder = SimilarityGroupBuilder()
    private let candidateConfiguration = CandidateIndexConfiguration.phase5I
    private let pairingRevision = 1

    init(database: SQLiteDatabase, engine: SimilarityEngine = SimilarityEngine()) {
        self.database = database
        self.engine = engine
    }

    func analyze(
        sourceID: SourceID,
        sensitivity: SimilaritySensitivityPreset = .precisionFirst,
        progress: @escaping @Sendable (SimilarityProgress) async -> Void
    ) async throws -> SimilarityOutcome {
        guard KeptoraFeatureFlags.similarityPipelineEnabled else {
            throw CoordinatorError.featureFlagDisabled
        }
        try await database.initialize()
        try await database.prunePerceptualState(sourceID: sourceID)
        let assets = try await database.fetchSimilarityAssets(sourceID: sourceID)
        let profile = (try await database.fetchSimilarityCalibrationProfile(visionRevision: SimilarityEngine.pinnedRevision)
            ?? .conservativeBootstrap(visionRevision: SimilarityEngine.pinnedRevision))
            .applying(sensitivity)

        var indexed = 0
        var reused = 0
        var failed = 0
        for (offset, asset) in assets.enumerated() {
            try Task.checkCancellation()
            if let existing = try await database.perceptualFeature(
                assetID: asset.assetID,
                contentDigest: asset.exactDigest,
                visionRevision: SimilarityEngine.pinnedRevision,
                cropScale: SimilarityEngine.cropScaleName
            ) {
                _ = existing
                reused += 1
            } else {
                do {
                    let payload = try await engine.feature(for: asset.fileURL)
                    try await database.upsertPerceptualFeature(
                        asset: asset,
                        payload: payload,
                        pairingRevision: 0,
                        configuration: candidateConfiguration
                    )
                    try await database.deleteSimilarityPairs(involving: asset.assetID)
                    indexed += 1
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // A damaged or currently unsupported image must not abort the whole library.
                    // It remains untouched and can be retried by a later app/runtime version.
                    failed += 1
                }
            }
            await progress(
                SimilarityProgress(
                    phase: .indexing,
                    processed: offset + 1,
                    total: assets.count,
                    indexed: indexed,
                    reused: reused,
                    failed: failed,
                    comparedPairs: 0,
                    currentItem: asset.displayName,
                    message: "\(indexed) visual features built · \(reused) reused · \(failed) safely skipped"
                )
            )
        }

        let pending = try await database.fetchFeaturesNeedingPairing(
            sourceID: sourceID,
            pairingRevision: pairingRevision
        )
        var comparedPairs = 0
        var storedPairs = 0
        for (offset, feature) in pending.enumerated() {
            try Task.checkCancellation()
            let candidates = try await database.fetchPerceptualCandidates(
                sourceID: sourceID,
                feature: feature,
                configuration: candidateConfiguration
            )
            for candidate in candidates {
                try Task.checkCancellation()
                guard feature.assetID.rawValue != candidate.assetID.rawValue,
                      feature.contentDigest != candidate.contentDigest else { continue }
                if try await database.similarityPairExists(feature.assetID, candidate.assetID) { continue }
                let distance = try await engine.distance(
                    featureArchive: feature.featureArchive,
                    to: candidate.featureArchive
                )
                comparedPairs += 1
                if distance <= profile.storageMaximum {
                    let pair = SimilarityPairRecord(
                        sourceID: sourceID,
                        firstAssetID: feature.assetID,
                        secondAssetID: candidate.assetID,
                        distance: distance,
                        tier: profile.tier(for: distance),
                        profileID: profile.id
                    )
                    try await database.upsertSimilarityPair(pair)
                    storedPairs += 1
                }
            }
            try await database.markFeaturePaired(assetID: feature.assetID, pairingRevision: pairingRevision)
            await progress(
                SimilarityProgress(
                    phase: .comparing,
                    processed: offset + 1,
                    total: pending.count,
                    indexed: indexed,
                    reused: reused,
                    failed: failed,
                    comparedPairs: comparedPairs,
                    currentItem: nil,
                    message: "\(comparedPairs) candidate distances measured · \(storedPairs) retained"
                )
            )
        }

        await progress(
            SimilarityProgress(
                phase: .grouping,
                processed: pending.count,
                total: pending.count,
                indexed: indexed,
                reused: reused,
                failed: failed,
                comparedPairs: comparedPairs,
                currentItem: nil,
                message: "Building conservative anchor groups"
            )
        )
        let groups = try await fetchGroups(sourceID: sourceID, profile: profile)
        return SimilarityOutcome(
            groups: groups,
            discoveredImages: assets.count,
            indexed: indexed,
            reused: reused,
            failed: failed,
            comparedPairs: comparedPairs,
            storedPairs: storedPairs
        )
    }

    func fetchGroups(sourceID: SourceID, sensitivity: SimilaritySensitivityPreset = .precisionFirst) async throws -> [SimilarityReviewGroup] {
        let profile = (try await database.fetchSimilarityCalibrationProfile(visionRevision: SimilarityEngine.pinnedRevision)
            ?? .conservativeBootstrap(visionRevision: SimilarityEngine.pinnedRevision))
            .applying(sensitivity)
        return try await fetchGroups(sourceID: sourceID, profile: profile)
    }

    private func fetchGroups(
        sourceID: SourceID,
        profile: SimilarityCalibrationProfile
    ) async throws -> [SimilarityReviewGroup] {
        let pairs = try await database.fetchSimilarityPairs(sourceID: sourceID, maximumDistance: profile.reviewMaximum)
        let assetIDs = Set(pairs.flatMap { [$0.firstAssetID, $0.secondAssetID] })
        let assets = try await database.fetchReviewAssets(assetIDs: assetIDs)
        return groupBuilder.build(pairs: pairs, assets: assets, profile: profile)
    }
}
