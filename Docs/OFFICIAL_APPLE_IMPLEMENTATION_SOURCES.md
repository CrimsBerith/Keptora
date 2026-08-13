# Official Apple Implementation Sources

Verified for the Phase 5K handoff on 4 August 2026.

## StoreKit

- StoreKit testing configuration: https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode
- Testing in-app purchases in Xcode: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode
- Sandbox testing: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox
- `AppStore.sync()`: https://developer.apple.com/documentation/storekit/appstore/sync()
- Transaction current entitlements: https://developer.apple.com/documentation/storekit/transaction/currententitlements
- Transaction updates: https://developer.apple.com/documentation/storekit/transaction/updates

## Privacy manifests

- Describing required-reason API use: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Approved reason values: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
- TN3183 manifest structure: https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest

Cullora currently declares:

- `3B52.1` for metadata of files/directories the user explicitly selected.
- `C617.1` for metadata inside the app container.
- `CA92.1` for app-only `UserDefaults`.

The archived app privacy report must still be reconciled before submission.

## App Store product page

- App information and 30-character name/subtitle limits: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Description, promotional-text and keyword limits: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Mac screenshot sizes: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications

## Photos

- PhotoKit change requests: https://developer.apple.com/documentation/photos/phassetchangerequest

These are implementation references, not evidence that the Mac/Xcode release blockers passed.
