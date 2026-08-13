import XCTest
@testable import Cullora

final class SimilarityCalibratorTests: XCTestCase {
    func testCalibratorProducesMonotonicProfileWithEnoughLabels() {
        let positives = (0..<60).map { index in
            LabeledSimilaritySample(distance: 0.06 + Float(index) * 0.002, isSimilar: true)
        }
        let negatives = (0..<60).map { index in
            LabeledSimilaritySample(distance: 0.50 + Float(index) * 0.003, isSimilar: false)
        }
        let profile = SimilarityCalibrator().calibrate(
            samples: positives + negatives,
            visionRevision: 1
        )
        XCTAssertTrue(profile.isCalibrated)
        XCTAssertLessThanOrEqual(profile.veryStrongMaximum, profile.strongMaximum)
        XCTAssertLessThanOrEqual(profile.strongMaximum, profile.reviewMaximum)
        XCTAssertGreaterThan(profile.storageMaximum, profile.reviewMaximum)
    }

    func testInsufficientLabelsFallBackToReviewOnlyBootstrap() {
        let profile = SimilarityCalibrator().calibrate(
            samples: [LabeledSimilaritySample(distance: 0.1, isSimilar: true)],
            visionRevision: 1
        )
        XCTAssertFalse(profile.isCalibrated)
        XCTAssertEqual(profile.id, "bootstrap-v1-r1")
    }
}
