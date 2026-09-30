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
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 12))
        return app
    }

    private func element(withIdentifier identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func firstElement(withIdentifierPrefix prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    func testArchiveReviewStudioLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-portfolioUITesting", "-ApplePersistenceIgnoreState", "YES"]
        app.terminate()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["KEPTORA"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["KEPTORA"].exists) // brand mark always visible
    }

    func testReconciliationScreenshotModeLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-portfolioUITesting", "-keptoraScreenshotReconciliation", "-ApplePersistenceIgnoreState", "YES"]
        app.terminate()
        app.launch()

        XCTAssertTrue(app.staticTexts["keptora.reconciliation.title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["keptora.reconciliation.subtitle"].exists || app.staticTexts["WHY THIS CHANGED"].exists)

        let close = app.buttons["mac.reconciliation.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertFalse(app.staticTexts["keptora.reconciliation.title"].waitForExistence(timeout: 1))
    }

    func testExactReviewExposesCheckboxAndSelectAll() throws {
        let app = launchSelectionFixture()

        XCTAssertTrue(app.buttons["mac.folder.exact.selectAll"].waitForExistence(timeout: 15))
        let clearSelection = app.buttons["mac.folder.exact.clearSelection"]
        if clearSelection.exists { clearSelection.tap() }

        let checkbox = firstElement(withIdentifierPrefix: "mac.folder.exact.checkbox.", in: app)
        XCTAssertTrue(checkbox.waitForExistence(timeout: 8))
        XCTAssertTrue(checkbox.isEnabled)
        checkbox.tap()
        XCTAssertTrue(app.buttons["mac.folder.exact.clearSelection"].waitForExistence(timeout: 5))
    }

    func testExactReviewCardTogglesTheSameSelectionOnce() throws {
        let app = launchSelectionFixture()

        XCTAssertTrue(app.buttons["mac.folder.exact.selectAll"].waitForExistence(timeout: 15))
        let clearSelection = app.buttons["mac.folder.exact.clearSelection"]
        if clearSelection.exists {
            clearSelection.tap()
            XCTAssertTrue(clearSelection.waitForNonExistence(timeout: 5))
        }

        let card = firstElement(withIdentifierPrefix: "mac.folder.exact.cardToggle.", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        XCTAssertTrue(clearSelection.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(clearSelection.waitForNonExistence(timeout: 5))
    }

    func testProtectedKeeperCardNeverEntersCleanupSelection() throws {
        let app = launchSelectionFixture()

        XCTAssertTrue(app.buttons["mac.folder.exact.selectAll"].waitForExistence(timeout: 15))
        let clearSelection = app.buttons["mac.folder.exact.clearSelection"]
        if clearSelection.exists { clearSelection.tap() }

        let keeperCard = firstElement(withIdentifierPrefix: "mac.folder.exact.keeper.", in: app)
        XCTAssertTrue(keeperCard.waitForExistence(timeout: 8))
        keeperCard.tap()
        XCTAssertFalse(clearSelection.waitForExistence(timeout: 1))
    }

    func testEveryPrimaryPageAndToolbarDestinationOpens() throws {
        let app = launchSelectionFixture()

        app.buttons["mac.sidebar.home"].tap()
        XCTAssertTrue(element(withIdentifier: "mac.page.library", in: app).waitForExistence(timeout: 5))

        app.buttons["mac.sidebar.review"].tap()
        XCTAssertTrue(element(withIdentifier: "keptora.review.floor", in: app).waitForExistence(timeout: 5))

        app.buttons["mac.sidebar.history"].tap()
        XCTAssertTrue(element(withIdentifier: "mac.page.history", in: app).waitForExistence(timeout: 5))

        app.buttons["mac.toolbar.insights"].tap()
        XCTAssertTrue(element(withIdentifier: "mac.page.insights", in: app).waitForExistence(timeout: 5))

        app.buttons["mac.toolbar.support"].tap()
        XCTAssertTrue(element(withIdentifier: "mac.page.diagnostics", in: app).waitForExistence(timeout: 5))

        app.buttons["mac.toolbar.settings"].tap()
        XCTAssertTrue(element(withIdentifier: "mac.page.settings", in: app).waitForExistence(timeout: 5))
    }

    func testPhotosWelcomeAndPaywallSheetsAlwaysClose() throws {
        let app = launchSelectionFixture()

        app.buttons["mac.sidebar.home"].tap()
        XCTAssertTrue(app.buttons["mac.library.photos"].waitForExistence(timeout: 5))
        app.buttons["mac.library.photos"].tap()
        XCTAssertTrue(app.buttons["mac.photos.close"].waitForExistence(timeout: 5))
        app.buttons["mac.photos.close"].tap()
        XCTAssertFalse(app.buttons["mac.photos.close"].waitForExistence(timeout: 1))

        app.buttons["mac.toolbar.settings"].tap()
        app.buttons["mac.settings.showOnboarding"].tap()
        XCTAssertTrue(app.buttons["mac.onboarding.close"].waitForExistence(timeout: 5))
        app.buttons["mac.onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["mac.onboarding.back"].waitForExistence(timeout: 3))
        app.buttons["mac.onboarding.back"].tap()
        app.buttons["mac.onboarding.close"].tap()
        XCTAssertFalse(app.buttons["mac.onboarding.close"].waitForExistence(timeout: 1))

        app.buttons["mac.settings.showPaywall"].tap()
        XCTAssertTrue(app.buttons["mac.paywall.close"].waitForExistence(timeout: 5))
        app.buttons["mac.paywall.close"].tap()
        XCTAssertFalse(app.buttons["mac.paywall.close"].waitForExistence(timeout: 1))
    }

    func testReviewDrawersReconciliationAndSafetyPlanClose() throws {
        let app = launchSelectionFixture()

        let reviewQueue = element(withIdentifier: "mac.review.queue.open", in: app)
        XCTAssertTrue(reviewQueue.waitForExistence(timeout: 12))
        reviewQueue.tap()
        XCTAssertTrue(app.buttons["mac.review.drawer.close"].waitForExistence(timeout: 4))
        app.buttons["mac.review.drawer.close"].tap()

        let more = element(withIdentifier: "mac.review.more", in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        more.tap()
        let reconcile = element(withIdentifier: "mac.review.reconciliation.open", in: app)
        XCTAssertTrue(reconcile.waitForExistence(timeout: 3))
        reconcile.tap()
        XCTAssertTrue(app.buttons["mac.reconciliation.close"].waitForExistence(timeout: 5))
        app.buttons["mac.reconciliation.close"].tap()

        app.buttons["mac.folder.exact.selectAll"].tap()
        let confirm = app.buttons["mac.folder.exact.confirmSelectAll"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        _ = confirm.waitForNonExistence(timeout: 3)

        let safetyPlanButton = element(withIdentifier: "mac.safetyPlan.open", in: app)
        XCTAssertTrue(safetyPlanButton.waitForExistence(timeout: 5))
        XCTAssertTrue(safetyPlanButton.isEnabled)
        safetyPlanButton.click()
        XCTAssertTrue(app.buttons["mac.safetyPlan.close"].waitForExistence(timeout: 8))
        app.buttons["mac.safetyPlan.close"].click()
    }

    func testFolderPickersCanBeCancelled() throws {
        let app = launchSelectionFixture()
        app.buttons["mac.sidebar.home"].tap()

        for identifier in ["mac.library.chooseFolder", "mac.library.cloudFolder"] {
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
            app.buttons[identifier].tap()
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
        }
    }

    func testPrimaryNavigationUsesOneCompleteSupportedLanguage() throws {
        let app = launchSelectionFixture()
        let actual = [
            app.buttons["mac.sidebar.home"].label,
            app.buttons["mac.sidebar.review"].label,
            app.buttons["mac.sidebar.history"].label
        ]
        let supportedSets = [
            ["Library", "Review", "History"],
            ["Arşiv", "İnceleme", "Geçmiş"],
            ["Mediathek", "Prüfen", "Verlauf"],
            ["Photothèque", "Examen", "Historique"]
        ]
        XCTAssertTrue(supportedSets.contains(actual), "Mixed or unsupported navigation language: \(actual)")
    }
}
