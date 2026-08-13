import Foundation

@main
struct SimilarityCoreSmoke {
    static func main() {
        var index = PerceptualCandidateIndex()
        let anchor = AssetID(rawValue: "anchor")
        let close = AssetID(rawValue: "close")
        let far = AssetID(rawValue: "far")
        index.insert(assetID: anchor, hash: PerceptualHash64(0))
        index.insert(assetID: close, hash: PerceptualHash64(3))
        index.insert(assetID: far, hash: PerceptualHash64(UInt64.max))
        let candidates = index.candidates(for: PerceptualHash64(0), excluding: anchor)
        guard candidates.first == close, !candidates.contains(far) else {
            fatalError("Candidate index filtering failed")
        }

        let positives = (0..<40).map { LabeledSimilaritySample(distance: 0.05 + Float($0) * 0.002, isSimilar: true) }
        let negatives = (0..<40).map { LabeledSimilaritySample(distance: 0.45 + Float($0) * 0.003, isSimilar: false) }
        let profile = SimilarityCalibrator().calibrate(samples: positives + negatives, visionRevision: 1)
        guard profile.isCalibrated,
              profile.veryStrongMaximum <= profile.strongMaximum,
              profile.strongMaximum <= profile.reviewMaximum else {
            fatalError("Threshold calibration failed")
        }

        let precision = profile.applying(.precisionFirst)
        let balanced = profile.applying(.balanced)
        let discovery = profile.applying(.discovery)
        guard precision.reviewMaximum < balanced.reviewMaximum,
              balanced.reviewMaximum < discovery.reviewMaximum,
              discovery.reviewMaximum == profile.reviewMaximum,
              precision.storageMaximum == profile.storageMaximum,
              balanced.storageMaximum == profile.storageMaximum else {
            fatalError("Phase 5J sensitivity safety failed")
        }
        print("Phase 5J similarity core smoke passed: candidate filtering, calibration monotonicity, strict presets, and stable pair storage.")
    }
}
