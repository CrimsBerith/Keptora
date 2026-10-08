import XCTest

@MainActor
final class KeptoraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchSelectionFixture(language: String = "en", locale: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-portfolioUITesting",
            "-keptoraSelectionUITesting",
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launchEnvironment["AppleLanguages"] = "(\(language))"
        app.launchEnvironment["AppleLocale"] = locale
        app.terminate()
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 12))
        return app
    }

    func testStartupSetupCanContinueWithDeniedPhotos() {
        let app = XCUIApplication()
        app.launchArguments = ["-keptoraPhotosDeniedUITesting", "-keptoraResetSourceSetupUITesting", "-Keptora.Onboarding.Completed.v1", "YES",
            "-AppleLanguages", "(en)", "-Keptora.AppLanguage", "system"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Connect your library"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["mac.sourceSetup.openSettings"].exists)
        XCTAssertTrue(app.buttons["mac.sourceSetup.folders"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Mac startup source access — denied Photos"
        attachment.lifetime = .keepAlways; add(attachment)
        let continueButton = app.buttons["mac.sourceSetup.continue"]
        XCTAssertTrue(continueButton.isHittable)
        XCTAssertGreaterThanOrEqual(continueButton.frame.height, 32)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(continueButton.frame))
        continueButton.tap()
        XCTAssertFalse(app.buttons["mac.sourceSetup.continue"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.windows.firstMatch.exists)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-keptoraResetSourceSetupUITesting" }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["mac.sourceSetup.continue"].waitForExistence(timeout: 2))
    }

    private func launchUnifiedMacFixture(conflict: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-portfolioUITesting", "-keptoraUnifiedMacUITesting", "-keptoraPhotosDeniedUITesting", "-AppleLanguages", "(en)", "-Keptora.AppLanguage", "system"]
        if conflict { app.launchArguments.append("-keptoraRestoreConflictUITesting") }
        app.launchEnvironment["KEPTORA_MAC_FIXTURE_ID"] = UUID().uuidString
        app.launch(); app.activate()
        XCTAssertTrue(app.windows["Keptora"].waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Unified Mac fixture startup"; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTAssertTrue(app.buttons["mac.archive.scanAll"].waitForExistence(timeout: 15))
        waitForEnabled(app.buttons["mac.archive.scanAll"])
        return app
    }
    private func waitForEnabled(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
    }
    private func waitForSelectionCount(_ expected: Int, in app: XCUIApplication) {
        let count = app.staticTexts["mac.archive.selectionCount"]
        let title = "Selected items: \(expected)"
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            count.exists && (count.label == title || count.value as? String == title)
        }, object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }
    private func openUnifiedCopies(_ app: XCUIApplication) -> XCUIElement {
        app.typeKey("2", modifierFlags: .command)
        let category = app.buttons["mac.suggestions.copies"]
        XCTAssertTrue(category.waitForExistence(timeout: 10)); waitForEnabled(category); category.click()
        let copies = app.buttons["mac.archive.selectExtraCopies"]
        XCTAssertTrue(copies.waitForExistence(timeout: 10)); waitForEnabled(copies)
        return copies
    }
    private func confirmUnifiedRemoval(_ app: XCUIApplication) {
        let button = app.buttons["mac.archive.review.confirmRemoval"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isHittable); button.click()
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !app.buttons["mac.archive.review.remove"].exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 15), .completed)
    }

    func testUnifiedMacScanSelectionReviewUndoAndRestore() {
        let app = launchUnifiedMacFixture()
        // Command-R and the gallery button share the production session and actual JPEG adapters.
        app.typeKey("r", modifierFlags: .command)
        let copies = openUnifiedCopies(app)
        copies.click()
        let review = app.buttons["mac.archive.reviewSelection"]
        XCTAssertTrue(review.waitForExistence(timeout: 5)); review.click()
        let exclude = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mac.archive.review.exclude.")).firstMatch
        XCTAssertTrue(exclude.waitForExistence(timeout: 5)); exclude.click()
        let undo = app.buttons["mac.archive.review.undo"]
        XCTAssertTrue(undo.isEnabled); undo.click()
        app.buttons["mac.archive.review.remove"].click()
        confirmUnifiedRemoval(app)
        app.typeKey("3", modifierFlags: .command)
        let restore = app.buttons["Restore Files"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10)); restore.click()
        XCTAssertTrue(app.staticTexts["Restored"].waitForExistence(timeout: 10))
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.buttons["mac.archive.scanAll"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Unified Mac gallery after actual restore"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testUnifiedMacRestoreFailureIsVisibleAndDoesNotOverwriteOriginal() {
        let app = launchUnifiedMacFixture(conflict: true)
        app.buttons["mac.archive.scanAll"].click()
        let copies = openUnifiedCopies(app); copies.click()
        app.buttons["mac.archive.reviewSelection"].click(); app.buttons["mac.archive.review.remove"].click()
        confirmUnifiedRemoval(app); app.typeKey("3", modifierFlags: .command)
        let restore = app.buttons["Restore Files"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10)); restore.click()
        XCTAssertTrue(app.staticTexts["Restore stopped because an original path is occupied or quarantine content is missing."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Restored"].exists)
    }

    func testUnifiedMacSearchDoesNotLoseSelectionOrHijackTextUndo() {
        let app = launchUnifiedMacFixture()
        let asset = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mac.archive.asset.")).firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 10)); asset.click()
        let search = app.textFields["Search filenames"]
        search.click(); search.typeText("missing")
        XCTAssertTrue(app.buttons["mac.archive.reviewSelection"].exists)
        app.typeKey("z", modifierFlags: .command)
        XCTAssertNotEqual(search.value as? String, "missing")
        XCTAssertTrue(app.buttons["mac.archive.reviewSelection"].exists)
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(search.value as? String, "missing")
        app.typeKey("a", modifierFlags: .command); search.typeText("holiday")
        app.typeKey("3", modifierFlags: .command); app.typeKey("1", modifierFlags: .command)
        XCTAssertEqual(search.value as? String, "holiday")
        app.buttons["mac.archive.reviewSelection"].click()
        XCTAssertTrue(app.staticTexts["Review Selection"].waitForExistence(timeout: 5))
    }

    func testUnifiedMacGallerySupportsMultiStepKeyboardUndoRedo() {
        let app = launchUnifiedMacFixture()
        let assets = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mac.archive.asset."))
        XCTAssertTrue(assets.firstMatch.waitForExistence(timeout: 10)); XCTAssertGreaterThanOrEqual(assets.count, 2)
        let firstID = assets.element(boundBy: 0).identifier, secondID = assets.element(boundBy: 1).identifier
        XCTAssertNotEqual(firstID, secondID)
        app.buttons[firstID].click(); waitForSelectionCount(1, in: app)
        app.buttons[secondID].click(); waitForSelectionCount(2, in: app)
        app.typeKey("z", modifierFlags: .command); waitForSelectionCount(1, in: app)
        app.typeKey("z", modifierFlags: .command); waitForSelectionCount(0, in: app)
        XCTAssertFalse(app.buttons["mac.archive.reviewSelection"].isEnabled)
        app.typeKey("z", modifierFlags: [.command, .shift]); waitForSelectionCount(1, in: app)
        app.typeKey("z", modifierFlags: [.command, .shift]); waitForSelectionCount(2, in: app)
    }

    private func element(withIdentifier identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func firstElement(withIdentifierPrefix prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

}
