import XCTest
@testable import Cullora

final class SimilaritySafetyPolicyTests: XCTestCase {
    func testSimilarGroupNeverAuthorizesCleanup() {
        let first = asset("a", name: "A.jpg")
        let second = asset("b", name: "B.jpg")
        let profile = SimilarityCalibrationProfile.conservativeBootstrap(visionRevision: 1)
        let pair = SimilarityPairRecord(
            sourceID: SourceID(rawValue: "source"),
            firstAssetID: first.id,
            secondAssetID: second.id,
            distance: 0.12,
            tier: .veryStrong,
            profileID: profile.id
        )
        let groups = SimilarityGroupBuilder().build(
            pairs: [pair],
            assets: [first.id: first, second.id: second],
            profile: profile
        )
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].allowsCleanup)
    }

    func testAnchorGroupingDoesNotChainThroughUnrelatedEndpoint() {
        let a = asset("a", name: "A.jpg")
        let b = asset("b", name: "B.jpg")
        let c = asset("c", name: "C.jpg")
        let profile = SimilarityCalibrationProfile.conservativeBootstrap(visionRevision: 1)
        let pairs = [
            SimilarityPairRecord(sourceID: SourceID(rawValue: "source"), firstAssetID: a.id, secondAssetID: b.id, distance: 0.20, tier: .strong, profileID: profile.id),
            SimilarityPairRecord(sourceID: SourceID(rawValue: "source"), firstAssetID: b.id, secondAssetID: c.id, distance: 0.20, tier: .strong, profileID: profile.id)
        ]
        let groups = SimilarityGroupBuilder().build(
            pairs: pairs,
            assets: [a.id: a, b.id: b, c.id: c],
            profile: profile
        )
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].anchorAssetID, b.id)
        XCTAssertEqual(groups[0].members.count, 3)
        XCTAssertFalse(groups[0].allowsCleanup)
    }

    private func asset(_ id: String, name: String) -> ReviewAsset {
        ReviewAsset(
            id: AssetID(rawValue: id),
            displayName: name,
            fileURL: URL(fileURLWithPath: "/tmp/\(name)"),
            byteCount: 100,
            modificationDate: nil,
            digest: id
        )
    }

    func testSensitivityPresetsNeverWidenPersistedProfile() {
        let base = SimilarityCalibrationProfile.conservativeBootstrap(visionRevision: 1)
        for preset in SimilaritySensitivityPreset.allCases {
            let adjusted = base.applying(preset)
            XCTAssertLessThanOrEqual(adjusted.veryStrongMaximum, base.veryStrongMaximum)
            XCTAssertLessThanOrEqual(adjusted.strongMaximum, base.strongMaximum)
            XCTAssertLessThanOrEqual(adjusted.reviewMaximum, base.reviewMaximum)
            XCTAssertEqual(adjusted.storageMaximum, base.storageMaximum)
        }
    }

    func testPrecisionFirstIsStrictestPreset() {
        let base = SimilarityCalibrationProfile.conservativeBootstrap(visionRevision: 1)
        XCTAssertLessThan(base.applying(.precisionFirst).reviewMaximum, base.applying(.balanced).reviewMaximum)
        XCTAssertLessThan(base.applying(.balanced).reviewMaximum, base.applying(.discovery).reviewMaximum)
    }
}
