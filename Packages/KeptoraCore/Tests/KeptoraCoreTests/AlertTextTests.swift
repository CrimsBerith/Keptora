import XCTest
@testable import KeptoraCore

final class AlertTextTests: XCTestCase {
    func testFirstSentenceBecomesTitleAndRestBecomesDetail() {
        let parts = AlertText.split("Your selection changed. Review it again before removing items.")
        XCTAssertEqual(parts.title, "Your selection changed.")
        XCTAssertEqual(parts.detail, "Review it again before removing items.")
    }

    func testSingleSentenceHasNoDetail() {
        let parts = AlertText.split("Keptora Pro is unavailable right now")
        XCTAssertEqual(parts.title, "Keptora Pro is unavailable right now")
        XCTAssertNil(parts.detail)
    }

    func testTurkishAndTrailingSpacesAreHandled() {
        let parts = AlertText.split("  Seçiminiz değişti. Kaldırmadan önce tekrar inceleyin.  ")
        XCTAssertEqual(parts.title, "Seçiminiz değişti.")
        XCTAssertEqual(parts.detail, "Kaldırmadan önce tekrar inceleyin.")
    }

    func testOneSentenceEndingWithPeriodStaysWhole() {
        let parts = AlertText.split("Restore failed.")
        XCTAssertEqual(parts.title, "Restore failed.")
        XCTAssertNil(parts.detail)
    }
}
