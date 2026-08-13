# App Privacy Answers — Cullora 1.0.0 (181)

**Basis:** Current Phase 5K source only. Re-answer these questions if analytics, crash reporting, cloud sync, accounts, support SDKs, or any network service is added.

## App Store Connect privacy label draft

### Does this app collect data?

**No — for the current local-only build.**

Cullora reads user-selected folders, photo/video files, metadata, hashes, thumbnails, review decisions, cleanup plans, bookmarks, and local diagnostics on the device. The current source does not transmit those items to the developer or a third party. On-device access is not represented here as developer collection.

### Tracking

- Tracking: **No**
- Data used to track the user: **None**
- Advertising identifier: **Not used**
- Third-party advertising or analytics SDK: **None in the current project**

### Data linked to the user

**None collected by the developer.** The app has no account system.

### Data not linked to the user

**None collected by the developer.** User-created diagnostic exports remain local until the user explicitly saves or shares them.

## Local data processed by the app

Cullora may locally store:

- Security-scoped bookmarks for folders the user selected.
- A SQLite index containing source identity, file metadata, exact fingerprints, feature-print references, review decisions, plans, and history.
- Thumbnail cache entries.
- Signed cleanup manifests and reversible quarantine state.
- The set of unique recommendations counted toward the first 100 free reviews.
- Onboarding and preference values in UserDefaults.

This is application data on the user’s Mac, not off-device collection by the developer.

## Purchases

Purchases are processed by Apple through StoreKit. Cullora requests product information and reads verified current entitlement transactions. Do not claim that payment-card details are received by Cullora.

## Diagnostics

The Diagnostics screen can generate a JSON support snapshot. The export excludes image bytes and hashes and redacts home-directory and source paths by default. The user controls whether to save or share the file.

## Privacy manifest alignment

The bundled `PrivacyInfo.xcprivacy` currently declares:

- Tracking disabled.
- No collected data types.
- File timestamp required-reason APIs for user-selected files and app-container files.
- App-only UserDefaults access.

Before every upload, inspect the archive privacy report and re-check all linked SDKs. A future SDK can change the App Privacy answers even if Cullora’s own code does not.

## Required public fields before submission

- [ ] Real privacy policy URL.
- [ ] Legal entity or individual developer name.
- [ ] Support contact.
- [ ] Current effective date.
- [ ] A documented process to update the label when functionality changes.
