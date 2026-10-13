# Keptora Build Plan — 1.0.0 (182)

## Delivered in source

- Universal SwiftUI app: iPhone (iOS 17+) and Mac (macOS 13+), sharing `Packages/KeptoraCore`.
- Photo library gallery for Apple Photos and user-chosen folders, with filters, grouping, manual selection and undo.
- Exact copies (SHA-256), very similar / similar photo groups, quality findings (blur, dark, bright, low resolution), and suggestion collections (screenshots, videos by size, Live Photos).
- Final review before removal; Photos items go to Recently Deleted, folder files to a recovery folder with History restore.
- StoreKit 2 lifetime unlock; suggested batch selection is free for the first 100 items.
- Settings on both platforms (Mac: Keptora ▸ Settings…) with language, purchases, support links; Mac diagnostics export.
- English, Turkish, German and French localization; privacy manifest and App Sandbox entitlements.

## Validation

- `swift test --package-path Packages/KeptoraCore`
- `python3 Scripts/validate_project_references.py`, `validate_photo_cleaner_assets.py`, `validate_mac_localization.py`, `validate_app_store_metadata.py`
- Mac and iPhone unit and UI tests run in `.github/workflows/apple-validation.yml`.
- The Xcode project is generated from `project.yml` with XcodeGen; regenerate it after adding or removing files.

## Remaining release work

1. Fill the legal entity, support email and contact placeholders in `AppStore/PRIVACY_POLICY.md` and `AppStore/SUPPORT_PAGE.md`, and publish both pages.
2. Complete StoreKit sandbox, restore, refund/revocation, pending and offline checks on device.
3. Complete VoiceOver, Full Keyboard Access, Dynamic Type, dark/light and localization QA on device.
4. Measure 10K/50K/100K real libraries with Instruments.
5. Capture final localized screenshots, archive signed builds, validate, TestFlight and submit.
