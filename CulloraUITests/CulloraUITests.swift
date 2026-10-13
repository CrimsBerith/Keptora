import XCTest

@MainActor
final class KeptoraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testArchiveReviewStudioLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-portfolioUITesting"]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["CULLORA"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CULLORA"].exists) // brand mark always visible
    }

    func testReconciliationScreenshotModeLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-portfolioUITesting", "-keptoraScreenshotReconciliation"]
        app.launch()

        XCTAssertTrue(app.staticTexts["keptora.reconciliation.title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["keptora.reconciliation.subtitle"].exists || app.staticTexts["WHY THIS CHANGED"].exists)
    }
}
