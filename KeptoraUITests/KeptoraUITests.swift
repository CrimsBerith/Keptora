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
    private func openUnifiedCopies(_ app: XCUIApplication) -> XCUIElement {
        app.typeKey("2", modifierFlags: .command)
        let category = app.buttons["mac.suggestions.copies"]
        XCTAssertTrue(category.waitForExistence(timeout: 10)); waitForEnabled(category); category.click()
        let copies = app.buttons["mac.archive.selectExtraCopies"]
        XCTAssertTrue(copies.waitForExistence(timeout: 10)); waitForEnabled(copies)
        return copies
    }
    private func confirmUnifiedRemoval(_ app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", "Remove 1 Items")).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(button); button?.click()
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
        assets.element(boundBy: 0).click(); assets.element(boundBy: 1).click()
        let count = app.staticTexts["mac.archive.selectionCount"]
        XCTAssertTrue(count.label.contains("2"))
        app.typeKey("z", modifierFlags: .command); XCTAssertTrue(count.label.contains("1"))
        app.typeKey("z", modifierFlags: .command); XCTAssertFalse(app.buttons["mac.archive.reviewSelection"].isEnabled)
        app.typeKey("z", modifierFlags: [.command, .shift]); XCTAssertTrue(count.label.contains("1"))
        app.typeKey("z", modifierFlags: [.command, .shift]); XCTAssertTrue(count.label.contains("2"))
    }
    func testNativeSettingsCanPresentProWithMainWindowClosed() {
        let app = launchUnifiedMacFixture()
        let settingsButton = app.buttons["mac.toolbar.settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10)); settingsButton.click()
        let settings = app.windows.containing(.any, identifier: "mac.page.settings").firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        app.windows["Keptora"].buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(settings.buttons["mac.settings.showPaywall"].isHittable); settings.buttons["mac.settings.showPaywall"].click()
        XCTAssertTrue(app.buttons["mac.paywall.close"].waitForExistence(timeout: 10))
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
        app.segmentedControls.buttons["Verified Copy Plans"].tap()
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
        reviewQueue.click()
        XCTAssertTrue(app.buttons["mac.review.drawer.close"].waitForExistence(timeout: 5))
        app.buttons["mac.review.drawer.close"].click()

        let more = element(withIdentifier: "mac.review.more", in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        more.click()
        let reconcile = element(withIdentifier: "mac.review.reconciliation.open", in: app)
        XCTAssertTrue(reconcile.waitForExistence(timeout: 3))
        reconcile.click()
        XCTAssertTrue(app.buttons["mac.reconciliation.close"].waitForExistence(timeout: 5))
        app.buttons["mac.reconciliation.close"].click()

        app.buttons["mac.folder.exact.selectAll"].click()
        let confirm = app.buttons["mac.folder.exact.confirmSelectAll"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.click()
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
            app.buttons["mac.sidebar.archive"].label,
            app.buttons["mac.sidebar.smartBuckets"].label,
            app.buttons["mac.sidebar.history"].label
        ]
        let supportedSets = [
            ["Photo Library", "Suggestions", "History"],
            ["Fotoğraflar", "Öneriler", "Geçmiş"],
            ["Fotos", "Vorschläge", "Verlauf"],
            ["Photothèque", "Suggestions", "Historique"]
        ]
        XCTAssertTrue(supportedSets.contains(actual), "Mixed or unsupported navigation language: \(actual)")
    }

    func testAccessibilityAuditOnMainViews() throws {
        guard #available(macOS 14.0, *) else { return }
        let app = launchSelectionFixture()
        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion]) { _ in
            // Keep genuine audit assertions active while ignoring AppKit container quirks
            return false
        }
    }

    func testAllSupportedLanguagesNavigationCompleteness() throws {
        let testCases: [(lang: String, loc: String, expected: [String])] = [
            ("en", "en_US", ["Photo Library", "Suggestions", "History"]),
            ("tr", "tr_TR", ["Fotoğraflar", "Öneriler", "Geçmiş"]),
            ("de", "de_DE", ["Fotos", "Vorschläge", "Verlauf"]),
            ("fr", "fr_FR", ["Photothèque", "Suggestions", "Historique"])
        ]

        for item in testCases {
            let app = launchSelectionFixture(language: item.lang, locale: item.loc)
            let actual = [
                app.buttons["mac.sidebar.archive"].label,
                app.buttons["mac.sidebar.smartBuckets"].label,
                app.buttons["mac.sidebar.history"].label
            ]
            XCTAssertEqual(actual, item.expected, "Navigation localization mismatch for \(item.lang)")
        }
    }
}
