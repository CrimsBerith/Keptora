import Foundation

struct SimilarityCalibrator: Sendable {
    struct Requirements: Hashable, Sendable {
        let minimumPositiveSamples: Int
        let minimumNegativeSamples: Int
        let veryStrongPrecision: Double
        let strongPrecision: Double
        let reviewPrecision: Double
        let reviewMaximumFalsePositiveRate: Double

        static let phase5I = Requirements(
            minimumPositiveSamples: 30,
            minimumNegativeSamples: 30,
            veryStrongPrecision: 0.995,
            strongPrecision: 0.98,
            reviewPrecision: 0.90,
            reviewMaximumFalsePositiveRate: 0.10
        )
    }

    let requirements: Requirements

    init(requirements: Requirements = .phase5I) {
        self.requirements = requirements
    }

    func calibrate(
        samples: [LabeledSimilaritySample],
        visionRevision: Int,
        cropScale: String = "scaleFit"
    ) -> SimilarityCalibrationProfile {
        let finite = samples.filter { $0.distance.isFinite && $0.distance >= 0 }
        let positives = finite.filter(\.isSimilar)
        let negatives = finite.filter { !$0.isSimilar }
        guard positives.count >= requirements.minimumPositiveSamples,
              negatives.count >= requirements.minimumNegativeSamples else {
            return .conservativeBootstrap(visionRevision: visionRevision)
        }

        let candidates = Array(Set(finite.map(\.distance))).sorted()
        let veryStrong = selectThreshold(
            candidates: candidates, positives: positives, negatives: negatives,
            minimumPrecision: requirements.veryStrongPrecision, maximumFalsePositiveRate: 0.01
        )
        let strong = selectThreshold(
            candidates: candidates, positives: positives, negatives: negatives,
            minimumPrecision: requirements.strongPrecision, maximumFalsePositiveRate: 0.03
        )
        let review = selectThreshold(
            candidates: candidates, positives: positives, negatives: negatives,
            minimumPrecision: requirements.reviewPrecision,
            maximumFalsePositiveRate: requirements.reviewMaximumFalsePositiveRate
        )

        guard let veryStrong, let strong, let review else {
            return .conservativeBootstrap(visionRevision: visionRevision)
        }

        let orderedVeryStrong = min(veryStrong, strong, review)
        let orderedStrong = min(max(strong, orderedVeryStrong), review)
        let storage = max(review + 0.12, review * 1.30)
        return SimilarityCalibrationProfile(
            id: "calibrated-r\(visionRevision)-\(Int(Date().timeIntervalSince1970))",
            visionRevision: visionRevision,
            cropScale: cropScale,
            veryStrongMaximum: orderedVeryStrong,
            strongMaximum: orderedStrong,
            reviewMaximum: review,
            storageMaximum: storage,
            positiveSampleCount: positives.count,
            negativeSampleCount: negatives.count,
            generatedAt: Date(),
            isCalibrated: true
        )
    }

    private func selectThreshold(
        candidates: [Float],
        positives: [LabeledSimilaritySample],
        negatives: [LabeledSimilaritySample],
        minimumPrecision: Double,
        maximumFalsePositiveRate: Double
    ) -> Float? {
        var selected: Float?
        for threshold in candidates {
            let truePositives = positives.reduce(0) { $0 + ($1.distance <= threshold ? 1 : 0) }
            let falsePositives = negatives.reduce(0) { $0 + ($1.distance <= threshold ? 1 : 0) }
            guard truePositives > 0 else { continue }
            let precision = Double(truePositives) / Double(truePositives + falsePositives)
            let falsePositiveRate = Double(falsePositives) / Double(max(1, negatives.count))
            if precision >= minimumPrecision && falsePositiveRate <= maximumFalsePositiveRate {
                selected = threshold
            }
        }
        return selected
    }
}
