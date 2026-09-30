# Keptora Phase 5K Implementation

**Version:** 0.9.1  
**Build:** 100  
**Goal:** Convert the Phase 5J engineering prototype into a fail-closed App Store handoff with enforceable free/Pro behavior, first-run education, privacy declarations, redacted support diagnostics, and submission assets.

## Added in Phase 5K

### Entitlement and free-tier architecture

- `StoreEntitlementController` moved into `Core/Purchases` as an application-wide service.
- `AccessPolicy` defines 100 free **unique** review decisions.
- Re-editing the same asset does not consume another review.
- Entitlement checks occur in `AppModel` as well as the UI.
- Safety Plan authorization is checked before preparation and again before commit.
- File restoration is deliberately not gated by the purchase state.
- StoreKit 2 transaction updates and `Transaction.currentEntitlements` refresh the non-consumable entitlement.

### Premium onboarding and paywall

- Three-page first-run flow explains local processing, exact versus similar evidence, and reversible cleanup.
- The final onboarding action opens the user-selected folder picker.
- Paywall copy describes the lifetime product, no-subscription model, privacy boundary, free-review limit, and restore behavior.
- Placeholder product configuration remains visible during development rather than failing silently.

### Diagnostics and support

- New Diagnostics screen with build, operating-system, architecture, scan, database, recovery, and entitlement state.
- JSON export and clipboard copy use a central redactor.
- Source paths, home-directory paths, and user names are redacted by default.
- No image bytes or exact fingerprints are placed in the support snapshot.

### Privacy and sandbox

- Privacy manifest declares tracking disabled and no off-device data collection for the current source.
- Required-reason API entries cover user-selected/app-container file timestamps and app-only UserDefaults.
- App Sandbox, Hardened Runtime, user-selected read/write, app-scoped security bookmarks, and the dedicated Photos Library entitlement are declared.
- App Store privacy-answer draft and full privacy-policy draft are included.

### App Store delivery assets

- English and Turkish metadata in JSON and Markdown.
- Automated metadata length/UTF-8-byte validation.
- Screenshot plan, review notes, age-rating draft, support page, and submission checklist.
- Deterministic synthetic App Review corpus generator.
- Mac release runbook and expanded release gate.

### Localization and accessibility

- English/Turkish string catalog expanded to at least 100 keys.
- New onboarding, paywall, diagnostics, free-tier, and support labels use localized string keys where implemented.
- Important images and comparison controls have accessibility labels from the previous phase; final VoiceOver testing remains Mac-only work.

## Safety invariants

- Only exact SHA-256 groups can authorize a Safety Plan.
- Similar-photo groups remain advisory.
- A protected keeper cannot silently enter cleanup.
- No permanent-delete API, Finder Trash call, or quarantine purge is allowed in the app target.
- Collisions do not overwrite.
- Restore does not require Pro.
- Diagnostics do not auto-send.

## Validation available in this environment

- Swift parser pass for all app and test sources.
- Xcode project reference validation.
- Plist, JSON, privacy manifest, entitlement, metadata, StoreKit-ID, and localization checks.
- Static forbidden-delete scan.
- Linux-compatible SQLite, family, recovery, hashing, and similarity smoke suites.
- Deterministic corpus generation and SHA manifest.

## Not completed here

- A real macOS SDK compile or XCTest run.
- Signing, archive, Organizer validation, notarization/distribution, or App Store upload.
- StoreKit sandbox, refund/revocation, pending purchase, offline entitlement, and Family Sharing tests.
- VoiceOver/Full Keyboard Access audit.
- Real 10K/50K/100K photo-library performance and Instruments profiling.
- Human-labelled similarity calibration approval.
- Final legal identity, public URLs, trademark clearance, or App Store record configuration.
