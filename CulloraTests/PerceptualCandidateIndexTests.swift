import XCTest
@testable import Cullora

final class PerceptualCandidateIndexTests: XCTestCase {
    func testBandCandidatesAreRankedByHammingDistance() {
        var index = PerceptualCandidateIndex()
        let queryID = AssetID(rawValue: "query")
        let closeID = AssetID(rawValue: "close")
        let fartherID = AssetID(rawValue: "farther")
        index.insert(assetID: queryID, hash: PerceptualHash64(0x0000_0000_0000_0000))
        index.insert(assetID: closeID, hash: PerceptualHash64(0x0000_0000_0000_0003))
        index.insert(assetID: fartherID, hash: PerceptualHash64(0x0000_0000_0000_00ff))

        let candidates = index.candidates(
            for: PerceptualHash64(0x0000_0000_0000_0000),
            excluding: queryID
        )
        XCTAssertEqual(candidates.first, closeID)
        XCTAssertTrue(candidates.contains(fartherID))
    }

    func testUnrelatedHashIsRejectedBeforeVisionDistance() {
        var index = PerceptualCandidateIndex()
        let unrelatedID = AssetID(rawValue: "unrelated")
        index.insert(assetID: unrelatedID, hash: PerceptualHash64(UInt64.max))
        let candidates = index.candidates(for: PerceptualHash64(0))
        XCTAssertFalse(candidates.contains(unrelatedID))
    }
}
