import XCTest
@testable import Keptora

final class DiagnosticsRedactionTests: XCTestCase {
    func testRedactsSelectedSourceAndHomeDirectory() {
        let value = "Failed at /Users/alex/Pictures/Private/IMG_0001.jpg"
        let redacted = DiagnosticsRedactor.redact(
            value,
            sensitivePaths: ["/Users/alex/Pictures/Private", "/Users/alex"]
        )

        XCTAssertFalse(redacted.contains("alex"))
        XCTAssertFalse(redacted.contains("Private"))
        XCTAssertTrue(redacted.contains("<redacted-path>"))
    }

    func testLeavesNonPathErrorTextUntouched() {
        let value = "The selected volume is disconnected."
        XCTAssertEqual(DiagnosticsRedactor.redact(value, sensitivePaths: []), value)
    }
}
