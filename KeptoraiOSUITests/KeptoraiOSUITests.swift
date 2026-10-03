import XCTest

@MainActor
final class KeptoraiOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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
            "-hasSeenMobileOnboarding", "YES", "-Keptora.SourceSetup.iOS.v1", "YES", "-Keptora.AppLanguage", "system"
        ]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.archive"].waitForExistence(timeout: 10))
        return app
    }

    private func openComparisons(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        let comparisons = app.buttons["cleanup.comparisons"]
        for _ in 0..<6 where !comparisons.isHittable { app.swipeUp() }
        XCTAssertTrue(comparisons.waitForExistence(timeout: 5))
        comparisons.tap()
    }

    func testStartupSetupCanContinueWithDeniedPhotosAndExplainsWhatsAppAccess() {
        let app = XCUIApplication()
        app.launchArguments = ["-keptoraPhotosDeniedUITesting", "-keptoraResetSourceSetupUITesting", "-hasSeenMobileOnboarding", "YES",
            "-AppleLanguages", "(en)", "-Keptora.AppLanguage", "system"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Connect your library"].waitForExistence(timeout: 10))
        let settings = app.buttons["ios.library.openSettings"]
        for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Startup source access — denied Photos"
        attachment.lifetime = .keepAlways; add(attachment)
        let exportedFolder = app.buttons["ios.whatsapp.exportedFolder"]
        for _ in 0..<8 where !exportedFolder.isHittable { app.swipeUp() }
        XCTAssertTrue(exportedFolder.isHittable)
        XCTAssertTrue(app.staticTexts["Keptora can clean copies saved in Photos or folders you choose. It cannot access WhatsApp's private chat storage."].exists)
        app.buttons["ios.sourceSetup.continue"].tap()
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
        app.buttons["archive.selectMode"].tap()
        let item = app.buttons["archive.asset.ui-photo-keeper"]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 3))
        app.segmentedControls.buttons["Videos"].tap()
        XCTAssertTrue(app.staticTexts["1 selected outside this view"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Review Selection"].isHittable)
        app.buttons["Review Selection"].tap()
        XCTAssertTrue(app.staticTexts["Portrait Original.heic"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
    }

    func testWhatsAppGuideExplainsSavedCopiesAndChatStorage() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["WhatsApp Storage Guide"].tap()
        XCTAssertTrue(app.staticTexts["Keptora can clean copies saved in Photos or folders you choose. It cannot access WhatsApp's private chat storage."].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
    }

    func testCombinedGroupsPreserveSelectionWhenReturningToAllItems() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        app.buttons["archive.selectMode"].tap()
        app.segmentedControls["archive.resultMode"].buttons["Copies & Similar"].tap()
        let item = app.buttons["archive.asset.ui-photo-keeper"]
        for _ in 0..<8 where !item.isHittable { app.swipeUp() }
        XCTAssertTrue(item.isHittable); item.tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].waitForExistence(timeout: 3))
        for _ in 0..<8 where !app.segmentedControls["archive.resultMode"].isHittable { app.swipeDown() }
        app.segmentedControls["archive.resultMode"].buttons["All Items"].tap()
        XCTAssertTrue(app.staticTexts["Selected items: 1"].exists)
    }

    func testScanAllSourcesFindsCopiesInRealSimulatorPhotos() {
        let app = launch()
        if app.buttons["library.source.photos"].exists { app.buttons["library.source.photos"].tap() }
        let scan = app.buttons["archive.scanAll"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15)); scan.tap()
        XCTAssertTrue(scan.waitForExistence(timeout: 120), "Scan and both similarity passes must finish")
        app.segmentedControls["archive.resultMode"].buttons["Copies & Similar"].tap()
        let exact = app.staticTexts["Exact Copies"].firstMatch
        for _ in 0..<6 where !exact.isHittable { app.swipeUp() }
        XCTAssertTrue(exact.exists, "The imported corpus includes two distinct copies of identical JPEG bytes")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Unified scan — real simulator Photos results"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testCaptureCurrentPhotoLibraryScreens() {
        let app = launch()
        if app.buttons["library.source.photos"].exists { app.buttons["library.source.photos"].tap() }
        XCTAssertTrue(app.buttons["archive.selectMode"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["archive.selectMode"].isEnabled, "Imported simulator photos must be visible")
        app.buttons["archive.selectMode"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Current Library — real simulator media"
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

    func testVideoReviewSupportsCardCheckboxAndMediaFilters() {
        let app = launch(arguments: ["-keptoraVideoReviewUITesting"])

        openComparisons(app)
        XCTAssertTrue(app.segmentedControls.buttons["Exact copies"].waitForExistence(timeout: 8))
        app.segmentedControls.buttons["Videos"].tap()

        let selectAllExact = app.buttons["review.exact.selectAll"]
        XCTAssertTrue(selectAllExact.waitForExistence(timeout: 5))
        selectAllExact.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 3))
        let clearExact = app.buttons["review.exact.clearSelection"]
        XCTAssertTrue(clearExact.waitForExistence(timeout: 3))
        clearExact.tap()
        XCTAssertFalse(app.staticTexts["1 selected"].exists)

        let exactCard = app.buttons["review.exact.asset.ui-exact-copy"]
        XCTAssertTrue(exactCard.waitForExistence(timeout: 5))
        exactCard.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 3))

        let exactCheckbox = app.buttons["review.exact.checkbox.ui-exact-copy"]
        XCTAssertTrue(exactCheckbox.isHittable)
        exactCheckbox.tap()
        XCTAssertFalse(app.staticTexts["1 selected"].exists)

        app.segmentedControls.buttons["Similar"].tap()
        let selectAllSimilarVideos = app.buttons["review.similarVideo.selectAll"]
        XCTAssertTrue(selectAllSimilarVideos.waitForExistence(timeout: 5))
        XCTAssertTrue(selectAllSimilarVideos.isHittable)
        let similarCheckbox = app.buttons["review.similarVideo.checkbox.ui-similar-candidate"]
        XCTAssertTrue(similarCheckbox.waitForExistence(timeout: 5))
        similarCheckbox.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Review Cleanup"].isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Keptora Similar Video Review"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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

    func testExactPhotoCardDetailsAndCleanupConfirmation() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        openComparisons(app)

        let card = app.buttons["review.exact.asset.ui-photo-copy"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["ios.cleanup.review"].isHittable)
        app.buttons["ios.cleanup.review"].tap()
        XCTAssertTrue(app.buttons["ios.cleanup.confirm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ios.cleanup.cancel"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["ios.cleanup.cancel"].firstMatch.tap()

        card.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Why this is safe"].waitForExistence(timeout: 5))
        app.buttons["Why this is safe"].tap()
        XCTAssertTrue(app.buttons["ios.assetDetails.close"].waitForExistence(timeout: 5))
        app.buttons["ios.assetDetails.close"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }

    func testSimilarPhotoComparisonOpensResetsAndCloses() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        openComparisons(app)
        app.segmentedControls.buttons["Similar"].tap()

        XCTAssertTrue(app.buttons["ios.similarityComparison.open"].waitForExistence(timeout: 8))
        app.buttons["ios.similarityComparison.open"].tap()
        XCTAssertTrue(app.buttons["ios.similarityComparison.reset"].waitForExistence(timeout: 5))
        app.buttons["ios.similarityComparison.reset"].tap()
        app.buttons["ios.similarityComparison.close"].tap()
        XCTAssertTrue(app.buttons["ios.similarityComparison.open"].waitForExistence(timeout: 5))
    }

    func testLibraryReviewAndHistoryTabsShowFixtureContent() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"])
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.archive"].exists)

        openComparisons(app)
        XCTAssertTrue(app.segmentedControls.buttons["Exact copies"].waitForExistence(timeout: 5))

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["ios.page.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["ios.history.entry.00000000-0000-0000-0000-000000000101"].exists)
        XCTAssertTrue(app.staticTexts["Photos Recently Deleted"].exists)
        XCTAssertTrue(app.staticTexts["Keptora Safe Bin"].waitForExistence(timeout: 3) || app.staticTexts["Keptora Quarantine"].waitForExistence(timeout: 3))
    }

    func testPrimaryTabLabelsAreLocalizedInFourLanguages() {
        let expectations: [(String, String, String, String, String)] = [
            ("en", "en_US", "Library", "Cleanup", "History"),
            ("tr", "tr_TR", "Arşiv", "Temizlik", "Geçmiş"),
            ("de", "de_DE", "Mediathek", "Bereinigen", "Verlauf"),
            ("fr", "fr_FR", "Photothèque", "Nettoyage", "Historique")
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
        
        let readyToReview = app.staticTexts["Ready to review"]
        XCTAssertTrue(readyToReview.waitForExistence(timeout: 10))
        
        let screenshotLibrary = XCTAttachment(screenshot: app.screenshot())
        screenshotLibrary.name = "Keptora Library After 1000+ Items Scan"
        screenshotLibrary.lifetime = .keepAlways
        add(screenshotLibrary)
        
        let reviewTab = app.tabBars.buttons.element(boundBy: 1)
        reviewTab.tap()
        XCTAssertTrue(app.segmentedControls.buttons["Exact copies"].waitForExistence(timeout: 10))
        
        let screenshotReviewPhotos = XCTAttachment(screenshot: app.screenshot())
        screenshotReviewPhotos.name = "Keptora Review Photos Exact Duplicates"
        screenshotReviewPhotos.lifetime = .keepAlways
        add(screenshotReviewPhotos)
        
        app.segmentedControls.buttons["Videos"].tap()
        let screenshotReviewVideos = XCTAttachment(screenshot: app.screenshot())
        screenshotReviewVideos.name = "Keptora Review Videos Exact Duplicates"
        screenshotReviewVideos.lifetime = .keepAlways
        add(screenshotReviewVideos)

        app.segmentedControls.buttons["Similar"].tap()
        let screenshotSimilarVideos = XCTAttachment(screenshot: app.screenshot())
        screenshotSimilarVideos.name = "Keptora Review Similar Videos"
        screenshotSimilarVideos.lifetime = .keepAlways
        add(screenshotSimilarVideos)

        app.segmentedControls.buttons["Photos"].tap()
        let screenshotSimilarPhotos = XCTAttachment(screenshot: app.screenshot())
        screenshotSimilarPhotos.name = "Keptora Review Similar Photos"
        screenshotSimilarPhotos.lifetime = .keepAlways
        add(screenshotSimilarPhotos)
    }

    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let outDir = URL(fileURLWithPath: "/Users/khankartal/.gemini/antigravity-ide/brain/b4499e60-25cb-43bc-8b98-15b02b18bd8d/live_ui_screenshots")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let fileURL = outDir.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: fileURL)
    }

    func testCaptureLiveUIScreenshotsForVisualAnalysis() {
        let interruptionMonitor = addUIInterruptionMonitor(withDescription: "Permission Dialog") { alert in
            if alert.buttons["İzin Verme"].exists {
                alert.buttons["İzin Verme"].tap()
                return true
            } else if alert.buttons["Don’t Allow"].exists {
                alert.buttons["Don’t Allow"].tap()
                return true
            } else if alert.buttons.firstMatch.exists {
                alert.buttons.firstMatch.tap()
                return true
            }
            return false
        }

        // 1. Launch in Turkish
        let app = launch(arguments: ["-keptoraThousandsStressUITesting"], language: "tr", locale: "tr_TR")
        _ = app.tabBars.buttons.firstMatch.waitForExistence(timeout: 10)
        app.tap()
        saveScreenshot(app, name: "01_library_permission_alert")

        if app.buttons["ios.photosPermission.notNow"].waitForExistence(timeout: 3) {
            app.buttons["ios.photosPermission.notNow"].firstMatch.tap()
        } else if app.buttons["Şimdi Değil"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Şimdi Değil"].firstMatch.tap()
        } else if app.buttons["Not Now"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Not Now"].firstMatch.tap()
        }
        saveScreenshot(app, name: "01_library_dashboard_turkish")

        // 2. Open Settings
        if app.buttons["ios.library.settings"].waitForExistence(timeout: 5) {
            app.buttons["ios.library.settings"].tap()
            _ = app.buttons["ios.settings.close"].waitForExistence(timeout: 5)
            saveScreenshot(app, name: "02_settings_turkish")

            if app.buttons["ios.settings.showPaywall"].waitForExistence(timeout: 3) {
                app.buttons["ios.settings.showPaywall"].tap()
                _ = app.buttons["ios.paywall.close"].waitForExistence(timeout: 5)
                saveScreenshot(app, name: "03_paywall_turkish")
                app.buttons["ios.paywall.close"].tap()
            } else {
                app.buttons["ios.settings.close"].tap()
            }
        }

        // 3. Review Tab
        let reviewTab = app.tabBars.buttons.element(boundBy: 1)
        if reviewTab.waitForExistence(timeout: 5) {
            reviewTab.tap()
            _ = app.segmentedControls.firstMatch.waitForExistence(timeout: 8)
            saveScreenshot(app, name: "04_exact_review_turkish")

            // Switch to Videos
            if app.segmentedControls.buttons.element(boundBy: 3).waitForExistence(timeout: 3) {
                app.segmentedControls.buttons.element(boundBy: 3).tap()
                saveScreenshot(app, name: "05_exact_videos_turkish")
            }

            // Switch to Similar
            if app.segmentedControls.buttons.element(boundBy: 1).waitForExistence(timeout: 3) {
                app.segmentedControls.buttons.element(boundBy: 1).tap()

                // Switch to Photos
                if app.segmentedControls.buttons.element(boundBy: 2).waitForExistence(timeout: 3) {
                    app.segmentedControls.buttons.element(boundBy: 2).tap()
                    saveScreenshot(app, name: "06_similar_photos_turkish")

                    // Open Side by Side comparison if available
                    if app.buttons["ios.similarityComparison.open"].waitForExistence(timeout: 4) {
                        app.buttons["ios.similarityComparison.open"].tap()
                        _ = app.buttons["ios.similarityComparison.close"].waitForExistence(timeout: 5)
                        saveScreenshot(app, name: "07_side_by_side_comparison")
                        app.buttons["ios.similarityComparison.close"].tap()
                    }

                    // Open Split Loupe comparison if available
                    if app.buttons["ios.similaritySplitComparison.open"].waitForExistence(timeout: 4) {
                        app.buttons["ios.similaritySplitComparison.open"].tap()
                        _ = app.buttons["ios.splitComparison.close"].waitForExistence(timeout: 5)
                        saveScreenshot(app, name: "08_split_loupe_comparison")
                        app.buttons["ios.splitComparison.close"].tap()
                    }
                }
            }
        }

        // 4. History Tab
        let historyTab = app.tabBars.buttons.element(boundBy: 2)
        if historyTab.waitForExistence(timeout: 5) {
            historyTab.tap()
            saveScreenshot(app, name: "09_history_turkish")
        }

        removeUIInterruptionMonitor(interruptionMonitor)
    }

    func testGenerateAppStoreScreenshots() {
        let app = launch(arguments: ["-keptoraComprehensiveUITesting"], language: "tr", locale: "tr_TR")
        let outDir = URL(fileURLWithPath: "/Users/khankartal/Desktop/MAC APPS NEARLY FINISHED/Cullora_Phase_5O_Calisan_Xcode_Projesi/AppStore/Generated/Screenshots/iOS")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        func save(_ name: String) {
            let screenshot = app.screenshot()
            let fileURL = outDir.appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: fileURL)
            print("✓ Saved App Store screenshot: \(name).png")
        }

        // Screen 1: Library Overview
        XCTAssertTrue(app.tabBars.buttons.firstMatch.waitForExistence(timeout: 8))
        usleep(800_000)
        save("01_iPhone_Library")

        // Screen 2: Exact Copies Review
        let reviewTab = app.tabBars.buttons.element(boundBy: 1)
        if reviewTab.waitForExistence(timeout: 5) {
            reviewTab.tap()
            _ = app.segmentedControls["ios.review.mode"].waitForExistence(timeout: 5)
            let card = app.buttons["review.exact.asset.ui-photo-copy"]
            if card.waitForExistence(timeout: 5) {
                card.tap()
            }
            usleep(800_000)
            save("02_iPhone_Exact_Review")

            // Screen 4: Cleanup Confirmation Sheet (open while 1 copy is selected)
            if app.buttons["ios.cleanup.review"].waitForExistence(timeout: 4) {
                app.buttons["ios.cleanup.review"].tap()
                _ = app.buttons["ios.cleanup.confirm"].waitForExistence(timeout: 5)
                usleep(800_000)
                save("04_iPhone_Cleanup_Confirm")
                if app.buttons["ios.cleanup.cancel"].firstMatch.waitForExistence(timeout: 3) {
                    app.buttons["ios.cleanup.cancel"].firstMatch.tap()
                    usleep(400_000)
                }
            }

            // Screen 3: Similar Comparison
            let similarSegment = app.segmentedControls["ios.review.mode"].buttons.element(boundBy: 1)
            if similarSegment.waitForExistence(timeout: 4) {
                similarSegment.tap()
                usleep(500_000)
                if app.buttons["ios.similarityComparison.open"].waitForExistence(timeout: 4) {
                    app.buttons["ios.similarityComparison.open"].tap()
                    _ = app.buttons["ios.similarityComparison.close"].waitForExistence(timeout: 5)
                    usleep(800_000)
                    save("03_iPhone_Similar_Comparison")
                    app.buttons["ios.similarityComparison.close"].tap()
                    usleep(400_000)
                }
            }
        }

        // Screen 5: History / Quarantine
        let historyTab = app.tabBars.buttons.element(boundBy: 2)
        if historyTab.waitForExistence(timeout: 5) {
            historyTab.tap()
            usleep(800_000)
            save("05_iPhone_History")
        }

        // Screen 6: Keptora Pro Paywall
        let libraryTab = app.tabBars.buttons.element(boundBy: 0)
        if libraryTab.waitForExistence(timeout: 5) {
            libraryTab.tap()
            if app.buttons["ios.library.settings"].waitForExistence(timeout: 5) {
                app.buttons["ios.library.settings"].tap()
                if app.buttons["ios.settings.showPaywall"].waitForExistence(timeout: 4) {
                    app.buttons["ios.settings.showPaywall"].tap()
                    _ = app.buttons["ios.paywall.close"].waitForExistence(timeout: 5)
                    usleep(800_000)
                    save("06_iPhone_Paywall")
                    app.buttons["ios.paywall.close"].tap()
                }
            }
        }
    }
}
