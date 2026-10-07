import XCTest

@MainActor
final class KeptoraiOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let hierarchy = XCTAttachment(string: XCUIApplication().debugDescription)
            hierarchy.name = "Failed iPhone app hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        }
    }

    private func launch(
        arguments: [String] = [],
        language: String = "en",
        locale: String = "en_US"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments + [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-hasSeenMobileOnboarding", "YES", "-Keptora.SourceSetup.iOS.v1", "YES", "-Keptora.AppLanguage", "system",
            "-Keptora.ScanSources.Excluded.iOS.v1", "()"
        ]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.archive"].waitForExistence(timeout: 10))
        return app
    }


    private func reveal(_ element: XCUIElement, in app: XCUIApplication, scrollDown: Bool = false) {
        for _ in 0..<10 {
            var viewport = app.frame
            if let navigation = app.navigationBars.allElementsBoundByIndex.last {
                viewport.origin.y = max(viewport.minY, navigation.frame.maxY)
                viewport.size.height = app.frame.maxY - viewport.minY
            }
            var hasModalFooter = false
            // Only the frontmost sheet limits its content. The gallery's bar
            // remains in the AX tree underneath a review sheet.
            for id in ["archive.review.actions", "ios.sourceSetup.actions", "archive.selectionBar"] {
                let footer = app.descendants(matching: .any)[id].firstMatch
                if footer.exists, footer.frame.height > 0 {
                    viewport.size.height = max(1, min(viewport.maxY, footer.frame.minY) - viewport.minY)
                    hasModalFooter = id != "archive.selectionBar"
                    break
                }
            }
            if !hasModalFooter, app.tabBars.firstMatch.exists {
                viewport.size.height = max(1, min(viewport.maxY, app.tabBars.firstMatch.frame.minY) - viewport.minY)
            }
            var down = scrollDown
            if element.exists {
                if element.isHittable && viewport.contains(element.frame) { break }
                if element.frame.minY < viewport.minY { down = true }
                else if element.frame.maxY > viewport.maxY { down = false }
            }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.minY + viewport.height * (down ? 0.2 : 0.8)))
            let end = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.minY + viewport.height * (down ? 0.8 : 0.2)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
    }
    private func connectRealPhotos(_ app: XCUIApplication) {
        // PhotoKit's permission sheet can be hosted outside SpringBoard's
        // accessibility tree. Let XCTest handle the actual system interruption.
        let permissionMonitor = addUIInterruptionMonitor(withDescription: "Photos full-access permission") { alert in
            let allow = alert.buttons["Allow Full Access"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(permissionMonitor) }
        if app.buttons["library.source.photos"].exists { app.buttons["library.source.photos"].tap() }
        if !app.buttons["archive.selectAll"].waitForExistence(timeout: 3) {
            // A user interaction is required to invoke registered interruption
            // monitors; querying an unrelated application's buttons is not.
            app.tap()
        }
        XCTAssertTrue(app.buttons["archive.selectAll"].waitForExistence(timeout: 20))
    }
    func testGrantPhotosAccessForRealMedia() {
        let app = launch()
        connectRealPhotos(app)
        XCTAssertTrue(app.buttons["archive.selectAll"].isEnabled)
    }

    private func assertTouchTarget(_ button: XCUIElement, in app: XCUIApplication, minimumHeight: CGFloat = 44,
                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(button.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.height, minimumHeight, file: file, line: line)
        XCTAssertTrue(app.frame.contains(button.frame), "Action must remain inside the screen", file: file, line: line)
    }

    func testSelectionActionsHaveAccessibleTargetsAndDoNotOverlap() {
        for accessibleText in [false, true] {
            var arguments = ["-keptoraComprehensiveUITesting"]
            if accessibleText { arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
            let app = launch(arguments: arguments, language: accessibleText ? "tr" : "en", locale: accessibleText ? "tr_TR" : "en_US")
            let scan = app.buttons["archive.scanAll"]
            reveal(scan, in: app, scrollDown: true)
            assertTouchTarget(scan, in: app, minimumHeight: 52)

            let photo = app.buttons["archive.asset.ui-photo-copy"]
            reveal(photo, in: app); photo.tap()
            let undo = app.buttons["archive.undoSelection"]
            let clear = app.buttons["archive.clearSelection"]
            let review = app.buttons["archive.reviewSelection"]
            assertTouchTarget(undo, in: app)
            assertTouchTarget(clear, in: app)
            assertTouchTarget(review, in: app, minimumHeight: 52)
            XCTAssertTrue(undo.frame.intersection(clear.frame).isEmpty)
            XCTAssertGreaterThanOrEqual(review.frame.minY - max(undo.frame.maxY, clear.frame.maxY), 7)
            if accessibleText { XCTAssertGreaterThanOrEqual(clear.frame.minY - undo.frame.maxY, 7) }
            let galleryAttachment = XCTAttachment(screenshot: app.screenshot())
            galleryAttachment.name = accessibleText ? "Selection actions — Turkish accessibility text" : "Selection actions — standard text"
            galleryAttachment.lifetime = .keepAlways; add(galleryAttachment)

            review.tap()
            let exclude = app.buttons["archive.review.exclude.ui-photo-copy"]
            reveal(exclude, in: app)
            assertTouchTarget(exclude, in: app)
            assertTouchTarget(app.buttons["archive.review.remove"], in: app, minimumHeight: 52)
            let reviewAttachment = XCTAttachment(screenshot: app.screenshot())
            reviewAttachment.name = accessibleText ? "Final review — Turkish accessibility text" : "Final review — standard text"
            reviewAttachment.lifetime = .keepAlways; add(reviewAttachment)
            app.terminate()
        }
    }

    func testStartupSetupCanContinueWithDeniedPhotosAndConnectFiles() {
        let app = XCUIApplication()
        app.launchArguments = ["-keptoraPhotosDeniedUITesting", "-keptoraResetSourceSetupUITesting", "-hasSeenMobileOnboarding", "YES",
            "-AppleLanguages", "(en)", "-Keptora.AppLanguage", "system"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Connect your library"].waitForExistence(timeout: 10))
        let setup = app.descendants(matching: .any)["ios.sourceSetup"].firstMatch
        let settings = setup.buttons["ios.library.openSettings"]
        for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Startup source access — denied Photos"
        attachment.lifetime = .keepAlways; add(attachment)
        let files = setup.buttons["library.source.files"]
        reveal(files, in: app)
        XCTAssertTrue(files.isHittable)
        app.buttons["ios.sourceSetup.continue"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !app.buttons["ios.sourceSetup.continue"].exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.archive"].waitForExistence(timeout: 5))
        app.buttons["ios.library.options"].tap()
        app.buttons["Sources"].firstMatch.tap()
        XCTAssertTrue(app.buttons["library.source.files"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.removeAll { $0 == "-keptoraResetSourceSetupUITesting" }
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.archive"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["ios.sourceSetup.continue"].waitForExistence(timeout: 1))
    }

    func testManualArchiveSelectionRetainsItemsWhenFiltering() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        let item = app.buttons["archive.asset.ui-photo-keeper"]
        for _ in 0..<8 where !item.isHittable { app.swipeUp() }
        XCTAssertTrue(item.isHittable); item.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 3))
        app.segmentedControls.buttons["Videos"].tap()
        XCTAssertTrue(app.staticTexts["1 selected outside this view"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["archive.reviewSelection"].isHittable)
        app.buttons["archive.reviewSelection"].tap()
        XCTAssertTrue(app.staticTexts["Portrait Original.heic"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
    }

    func testSourceCheckboxesPreserveManualSelectionAndPersist() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        let item = app.buttons["archive.asset.ui-photo-keeper"]
        for _ in 0..<8 where !item.isHittable { app.swipeUp() }
        XCTAssertTrue(item.isHittable); item.tap()
        let sources = app.buttons["archive.sourcesSummary"]
        for _ in 0..<10 where !sources.isHittable { app.swipeDown() }
        sources.tap()
        let source = app.buttons["sources.source.ui-test"]
        for _ in 0..<10 where !source.isHittable { app.swipeDown() }
        XCTAssertTrue(source.isHittable)
        XCTAssertEqual(source.value as? String, "Selected")
        source.tap()
        XCTAssertEqual(source.value as? String, "Not selected")
        XCTAssertTrue(app.staticTexts["sources.emptySelection"].waitForExistence(timeout: 3))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertFalse(app.buttons["archive.scanAll"].isEnabled)
        XCTAssertTrue(app.staticTexts["1 selected outside this view"].exists)
        app.buttons["archive.reviewSelection"].tap()
        XCTAssertTrue(app.staticTexts["Portrait Original.heic"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
        app.terminate()
        if let index = app.launchArguments.firstIndex(of: "-Keptora.ScanSources.Excluded.iOS.v1") {
            app.launchArguments.removeSubrange(index...index + 1)
        }
        app.launch()
        XCTAssertTrue(app.buttons["archive.sourcesSummary"].waitForExistence(timeout: 10))
        app.buttons["archive.sourcesSummary"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertEqual(source.value as? String, "Not selected")
        app.buttons["sources.selectAll"].tap()
        XCTAssertEqual(source.value as? String, "Selected")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["archive.scanAll"].isEnabled)
    }


    func testVerySimilarKeeperAndSelectOthersWorkInsideGallery() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        let filter = app.buttons["archive.finding.verySimilar"]
        reveal(filter, in: app, scrollDown: true); filter.tap()
        let keep = app.buttons["archive.keep.ui-similar-photo-b"]
        reveal(keep, in: app); keep.tap()
        reveal(app.staticTexts["Chosen by You"].firstMatch, in: app)
        let others = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "archive.others.")).firstMatch
        reveal(others, in: app); others.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(others.isEnabled)
        XCTAssertEqual(app.buttons["archive.asset.ui-similar-photo-b"].value as? String, "Not selected")
        XCTAssertFalse(app.buttons["Compare Group"].exists)
        app.buttons["archive.undoSelection"].tap()
        XCTAssertFalse(app.buttons["archive.reviewSelection"].exists)
        XCTAssertTrue(others.isEnabled)
    }

    func testPhotoTapSelectsWithoutMagnifierAndCanBeUndone() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        let item = app.buttons["archive.asset.ui-photo-copy"]
        reveal(item, in: app); item.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Close Preview"].exists)
        XCTAssertFalse(app.buttons["archive.preview.ui-photo-copy"].exists)
        reveal(item, in: app); item.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 0"].waitForExistence(timeout: 5))
        app.buttons["archive.undoSelection"].tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
    }

    func testBulkCopySelectionUsesVisiblePhotoFilterAndCanBeUndone() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        app.segmentedControls.buttons["Photos"].tap()
        let copies = app.buttons["archive.finding.copies"]
        reveal(copies, in: app, scrollDown: true); copies.tap()
        let select = app.buttons["archive.selectExtraCopies"]
        reveal(select, in: app, scrollDown: true)
        XCTAssertTrue(select.isEnabled)
        XCTAssertEqual(select.label, "Select Extra Copies (1)")
        select.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 5))
        XCTAssertEqual(select.label, "Extra Copies Selected"); XCTAssertFalse(select.isEnabled)
        app.buttons["archive.undoSelection"].tap()
        XCTAssertFalse(app.buttons["archive.reviewSelection"].exists)
        XCTAssertTrue(select.isEnabled)
    }

    func testCombinedGroupsPreserveSelectionWhenReturningToAllItems() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        app.buttons["archive.finding.copies"].tap()
        let item = app.buttons["archive.asset.ui-photo-keeper"]
        for _ in 0..<8 where !item.isHittable { app.swipeUp() }
        XCTAssertTrue(item.isHittable); item.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 3))
        for _ in 0..<8 where !app.buttons["archive.finding.all"].isHittable { app.swipeDown() }
        app.buttons["archive.finding.all"].tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
    }

    func testScanAllSourcesFindsCopiesInRealSimulatorPhotos() {
        let app = launch()
        connectRealPhotos(app)
        let scan = app.buttons["archive.scanAll"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15)); scan.tap()
        XCTAssertTrue(scan.waitForExistence(timeout: 120), "Scan and both similarity passes must finish")
        app.buttons["archive.finding.copies"].tap()
        let exact = app.staticTexts["Exact Copies"].firstMatch
        for _ in 0..<6 where !exact.isHittable { app.swipeUp() }
        XCTAssertTrue(exact.exists, "The imported corpus includes two distinct copies of identical JPEG bytes")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Unified scan — real simulator Photos results"
        attachment.lifetime = .keepAlways; add(attachment)
    }


    func testCaptureCurrentPhotoLibraryScreens() {
        let app = launch()
        connectRealPhotos(app)
        XCTAssertTrue(app.buttons["archive.selectAll"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["archive.selectAll"].isEnabled, "Imported simulator photos must be visible")
        let photos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "archive.asset."))
        let firstPhoto = photos.firstMatch
        reveal(firstPhoto, in: app)
        assertTouchTarget(firstPhoto, in: app)
        XCTAssertEqual(firstPhoto.frame.width, firstPhoto.frame.height, accuracy: 1,
                       "Landscape originals must not expand square gallery cells")
        let firstRow = photos.allElementsBoundByIndex.filter {
            $0.exists && abs($0.frame.minY - firstPhoto.frame.minY) < 1
        }
        for (index, photo) in firstRow.enumerated() {
            XCTAssertTrue(app.frame.contains(photo.frame), "Photo controls must stay inside the screen")
            for other in firstRow.dropFirst(index + 1) {
                XCTAssertTrue(photo.frame.intersection(other.frame).isEmpty, "Neighboring photo controls must not overlap")
            }
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Current Library — tap selection and visible group actions"
        attachment.lifetime = .keepAlways; add(attachment)
        app.tabBars.buttons.element(boundBy: 1).tap()
        let hub = XCTAttachment(screenshot: app.screenshot())
        hub.name = "Current Cleanup Collections"; hub.lifetime = .keepAlways; add(hub)
    }

    func testLaunchShowsKeptoraLibrary() {
        let app = launch()
        let photosSource = app.buttons["library.source.photos"]
        XCTAssertTrue(photosSource.waitForExistence(timeout: 8))
        XCTAssertTrue(photosSource.isHittable)
        XCTAssertEqual(app.tabBars.buttons.count, 3)
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 1).isHittable)
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 2).isHittable)
    }


    func testVideoSelectionUsesSameGalleryAndBasket() {
        let app = launch(arguments: ["-keptoraVideoReviewUITesting"])
        app.segmentedControls.buttons["Videos"].tap()
        let copy = app.buttons["archive.asset.ui-exact-copy"]
        reveal(copy, in: app); copy.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 3))
        app.buttons["archive.clearSelection"].tap()
        XCTAssertTrue(app.staticTexts["Selected items: 0"].exists)
        app.buttons["archive.undoSelection"].tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
        app.buttons["archive.reviewSelection"].tap()
        XCTAssertTrue(app.buttons["archive.review.remove"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
    }

    func testSettingsReplacesItselfWithPaywallAndBothCanClose() {
        let app = launch()

        let settings = app.buttons["ios.library.settings"]
        app.buttons["ios.library.options"].tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        XCTAssertTrue(app.buttons["ios.settings.close"].waitForExistence(timeout: 5))

        let showPaywall = app.buttons["ios.settings.showPaywall"]
        XCTAssertTrue(showPaywall.waitForExistence(timeout: 5))
        showPaywall.tap()
        XCTAssertTrue(app.buttons["ios.paywall.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ios.settings.close"].exists)

        app.buttons["ios.paywall.close"].tap()
        XCTAssertTrue(app.buttons["library.source.photos"].waitForExistence(timeout: 5))

        app.buttons["ios.library.options"].tap()
        settings.tap()
        XCTAssertTrue(app.buttons["ios.settings.close"].waitForExistence(timeout: 5))
        app.buttons["ios.settings.close"].tap()
        XCTAssertTrue(app.buttons["library.source.photos"].waitForExistence(timeout: 5))
    }

    func testDeniedPhotosPermissionHelpCanOpenRepeatedly() {
        let app = launch(arguments: ["-keptoraPhotosDeniedUITesting"])

        let photos = app.buttons["library.source.photos"]
        photos.tap()
        XCTAssertTrue(app.alerts["Photos Access Needed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ios.photosPermission.openSettings"].exists)
        app.buttons["ios.photosPermission.notNow"].firstMatch.tap()
        XCTAssertFalse(app.alerts["Photos Access Needed"].waitForExistence(timeout: 1))

        photos.tap()
        XCTAssertTrue(app.alerts["Photos Access Needed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ios.photosPermission.openSettings"].exists)
        app.buttons["ios.photosPermission.notNow"].firstMatch.tap()
    }

    func testFilesPickerOpensAndCanBeCancelled() {
        let app = launch()
        app.buttons["library.source.files"].tap()

        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        cancel.tap()
        XCTAssertTrue(app.buttons["library.source.files"].waitForExistence(timeout: 5))
    }


    func testExactPhotoSelectionAndFinalReviewCanBeCancelled() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        let copy = app.buttons["archive.asset.ui-photo-copy"]
        reveal(copy, in: app); copy.tap()
        app.buttons["archive.reviewSelection"].tap()
        XCTAssertTrue(app.staticTexts["Portrait Copy.heic"].waitForExistence(timeout: 5))
        app.buttons["archive.review.remove"].tap()
        XCTAssertTrue(app.alerts["Remove selected items?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Portrait Copy.heic"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
    }

    func testFinalReviewRemovalCanBeUndoneEvenWhenEmpty() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        let copy = app.buttons["archive.asset.ui-photo-copy"]
        reveal(copy, in: app); copy.tap()
        app.buttons["archive.reviewSelection"].tap()
        let exclude = app.buttons["archive.review.exclude.ui-photo-copy"]
        reveal(exclude, in: app); exclude.tap()
        XCTAssertTrue(app.staticTexts["No items selected."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["archive.review.remove"].isEnabled)
        XCTAssertTrue(app.staticTexts["Selected items: 0"].exists)
        app.buttons["archive.review.undo"].tap()
        XCTAssertTrue(app.staticTexts["Portrait Copy.heic"].exists)
        XCTAssertTrue(app.buttons["archive.review.remove"].isEnabled)
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
        XCTAssertFalse(app.buttons["archive.review.undo"].exists)
        app.buttons["archive.review.close"].tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
    }

    func testLibraryReviewAndHistoryTabsShowFixtureContent() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.archive"].exists)

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["cleanup.collection.Duplicates & Similar Photos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cleanup.comparisons"].exists)

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["ios.history.entry.00000000-0000-0000-0000-000000000101"].exists)
        XCTAssertTrue(app.staticTexts["Photos Recently Deleted"].exists)
        XCTAssertTrue(app.staticTexts["Recovery Folder"].waitForExistence(timeout: 3))
    }

    func testRemovingOneFilterPreservesOtherFiltersAndSelection() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        let copy = app.buttons["archive.asset.ui-photo-copy"]
        reveal(copy, in: app); copy.tap()
        let copies = app.buttons["archive.finding.copies"]
        reveal(copies, in: app, scrollDown: true); copies.tap()
        app.segmentedControls.buttons["Photos"].tap()
        XCTAssertTrue(app.buttons["archive.filter.remove.finding"].exists)
        XCTAssertTrue(app.buttons["archive.filter.remove.media"].exists)
        let chip = app.buttons["archive.filter.remove.finding"]
        reveal(chip, in: app); chip.tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: chip)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["archive.filter.remove.media"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Photos"].isSelected)
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
        let similar = app.buttons["archive.asset.ui-similar-photo-a"]
        reveal(similar, in: app)
        XCTAssertTrue(similar.exists, "Removing the finding filter restores other photos")
        XCTAssertFalse(app.buttons["archive.asset.ui-exact-copy"].exists, "The Photos filter is preserved")
    }

    func testPrimaryTabLabelsAreLocalizedInFourLanguages() {
        let expectations: [(String, String, String, String, String)] = [
            ("en", "en_US", "Photo Library", "Suggestions", "History"),
            ("tr", "tr_TR", "Fotoğraflar", "Öneriler", "Geçmiş"),
            ("de", "de_DE", "Fotos", "Vorschläge", "Verlauf"),
            ("fr", "fr_FR", "Photothèque", "Suggestions", "Historique")
        ]

        for (language, locale, library, review, history) in expectations {
            let app = launch(language: language, locale: locale)
            XCTAssertTrue(app.tabBars.buttons[library].exists)
            XCTAssertTrue(app.tabBars.buttons[review].exists)
            XCTAssertTrue(app.tabBars.buttons[history].exists)
            app.terminate()
        }
    }


    func testThousandsOfMediaStressLiveScan() {
        let app = launch(arguments: ["-keptoraThousandsStressUITesting"])
        XCTAssertTrue(app.buttons["archive.selectAll"].waitForExistence(timeout: 10))
        let copies = app.buttons["archive.finding.copies"]
        reveal(copies, in: app, scrollDown: true); copies.tap()
        saveScreenshot(app, name: "Stress — copies together in one gallery")
        app.segmentedControls.buttons["Videos"].tap()
        saveScreenshot(app, name: "Stress — video copies in shared gallery")
        app.segmentedControls.buttons["Photos"].tap()
        saveScreenshot(app, name: "Stress — photo copies in shared gallery")
    }


    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }


    func testCaptureLiveUIScreenshotsForVisualAnalysis() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"], language: "tr", locale: "tr_TR")
        saveScreenshot(app, name: "01_library_turkish")
        let copies = app.buttons["archive.finding.copies"]
        reveal(copies, in: app, scrollDown: true); copies.tap()
        saveScreenshot(app, name: "02_copies_grid_turkish")
        let item = app.buttons["archive.asset.ui-photo-copy"]
        reveal(item, in: app); item.tap()
        saveScreenshot(app, name: "03_selection_bar_turkish")
        app.buttons["archive.reviewSelection"].tap()
        saveScreenshot(app, name: "04_final_review_turkish")
        app.buttons["archive.review.close"].tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        saveScreenshot(app, name: "05_cleanup_collections_turkish")
        app.tabBars.buttons.element(boundBy: 2).tap()
        saveScreenshot(app, name: "06_history_turkish")
    }

    func testGenerateAppStoreScreenshots() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"], language: "tr", locale: "tr_TR")
        saveScreenshot(app, name: "01_iPhone_Library")
        let copies = app.buttons["archive.finding.copies"]
        reveal(copies, in: app, scrollDown: true); copies.tap()
        let card = app.buttons["archive.asset.ui-photo-copy"]
        reveal(card, in: app); card.tap()
        saveScreenshot(app, name: "02_iPhone_Copies_Selection")
        app.buttons["archive.reviewSelection"].tap()
        saveScreenshot(app, name: "03_iPhone_Selection_Review")
        app.buttons["archive.review.close"].tap()
        let similar = app.buttons["archive.finding.verySimilar"]
        reveal(similar, in: app, scrollDown: true); similar.tap()
        let keep = app.buttons["archive.keep.ui-similar-photo-b"]
        reveal(keep, in: app)
        saveScreenshot(app, name: "04_iPhone_Related_Photos")
        app.tabBars.buttons.element(boundBy: 2).tap()
        saveScreenshot(app, name: "05_iPhone_History")
    }
}
