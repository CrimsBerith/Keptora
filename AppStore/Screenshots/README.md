# Native App Store screenshots

Captured from the shipping app, not design previews. They replace the design previews in
`AppStore/Generated/Screenshots`, which must not be submitted.

## iPhone 6.9" (1320 × 2868)

`iPhone-6.9/en` and `iPhone-6.9/tr`:

1. `01_library` — library after a scan, with the "Extra copies" result.
2. `02_copies_selected` — exact copies with the extra copies selected.
3. `03_preview` — touch-and-hold preview with Select and Protect.
4. `04_review` — final review before removal.

The photos are the fictional review corpus (`AppStore/Generated/Keptora_Review_Corpus`); no user photos.

### How they were made

1. Create an iPhone 17 Pro Max simulator (iOS 26.5) and set a clean status bar:
   `xcrun simctl status_bar <id> override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`
2. Add the corpus photos with `xcrun simctl addmedia` (Exact, Similar and Families folders; not EdgeCases).
3. Run `TEST_RUNNER_KEPTORA_STORE_SCREENSHOTS=1 xcodebuild test … -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testAppStoreScreenshotsWithRealPhotos` on that simulator and export the xcresult attachments. Without the variable the test skips.

## Still needed

- Mac screenshots (2880 × 1800).
- German and French sets if those App Store localizations are published.
