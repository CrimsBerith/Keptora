# Cullora Release Information Intake

Complete this file with real values before running the release gate. Do not invent legal, financial, contact, trademark, or URL information.

## Developer account and identity

- Apple Developer Team legal name: `REQUIRED`
- Team ID: `REQUIRED`
- App Store Connect provider/account: `REQUIRED`
- Seller/trader status and DSA contact: `REQUIRED`
- Copyright holder and year: `REQUIRED`
- Support owner: `REQUIRED`
- Support email: `REQUIRED`
- Review contact full name: `REQUIRED`
- Review contact phone: `REQUIRED`
- Review contact email: `REQUIRED`

## App identity

- Final app name clearance: `REQUIRED`
- Final bundle ID: `REQUIRED`
- SKU: `REQUIRED`
- Primary language: `English (U.S.)` proposed
- Primary category: `Photo & Video` proposed
- Secondary category: `Utilities` proposed; confirm functionally
- Minimum macOS: `macOS 13` currently configured; confirm with real build/device matrix

## Public URLs

- Marketing URL: `REQUIRED HTTPS`
- Support URL: `REQUIRED HTTPS`
- Privacy Policy URL: `REQUIRED HTTPS`
- Accessibility URL: `RECOMMENDED HTTPS`
- Terms/EULA URL or Apple standard EULA decision: `REQUIRED DECISION`

## StoreKit lifetime product

- Reference name: `Cullora Pro Lifetime` proposed
- Product ID: `REQUIRED`
- Type: `Non-Consumable`
- Display name EN/TR: `REQUIRED FINAL COPY`
- Description EN/TR: `REQUIRED FINAL COPY`
- Base price: `$24.99 proposed; choose actual App Store price point`
- Launch promotion: `$19.99 for first 14 days proposed; schedule manually`
- Family Sharing: `Disabled for 1.0.0`
- Review screenshot: `REQUIRED FROM FINAL BUILD`

## App Store version metadata

- Final name/subtitle/keywords: review `APP_STORE_METADATA.md`
- Description EN/TR: final proofread required
- Promotional text: final proofread required
- Version release notes: review `WHATS_NEW_1_0_DRAFT.md`
- Six final Mac screenshots: capture from signed-equivalent release build
- App preview video: optional; decide after screenshots

## Compliance declarations

- App Privacy responses: reconcile with archive privacy report and every linked SDK
- Privacy manifest: inspect final archive copy
- Encryption/export compliance: answer App Store Connect questionnaire; Cullora uses Apple cryptographic APIs for manifest integrity and StoreKit transport is system-provided
- Content rights: confirm rights to every screenshot/corpus image
- Age rating: complete current questionnaire; 4+ is proposed, not guaranteed
- Accessibility nutrition label: complete only after VoiceOver, keyboard, contrast and motion testing
- Korea/China/Vietnam regional declarations: confirm if distributing there
- Tax category, agreements, banking and paid-app contracts: required before selling IAP

## Build and review

- Real Xcode version: `REQUIRED`
- macOS versions tested: `REQUIRED`
- Apple Silicon devices tested: `REQUIRED`
- Intel Mac tested or explicitly unsupported: `REQUIRED DECISION`
- TestFlight group and testers: `REQUIRED`
- App Review demo instructions: no account; provide a deterministic test folder and exact workflow
- Known limitations disclosed to review: similar photos are review-only; no permanent Photos deletion

## Official Apple references

- Required fields: https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
- App privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- Upload builds: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Age rating: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
- Export compliance: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- Family Sharing: https://developer.apple.com/documentation/storekit/supporting-family-sharing-in-your-app
