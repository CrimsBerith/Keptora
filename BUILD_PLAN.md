# Keptora Build Plan — Phase 5O / 1.0.0 (181)

## Delivered in source

- Native macOS 13+ SwiftUI project.
- Incremental exact hashing, protected keeper, SQLite schema v4, resumable scan, bounded thumbnails, external-volume identity, asset-family safety, reversible quarantine, signed manifest, restore/reconciliation, and review-only similarity.
- Synchronized side-by-side similarity comparison and conservative calibration presets.
- App-wide StoreKit 2 lifetime entitlement service.
- Unlimited scan + 100 unique free reviews policy with non-UI enforcement.
- Safety onboarding, lifetime paywall, diagnostics screen, and redacted JSON export.
- Privacy manifest, App Sandbox/file entitlements, English/Turkish metadata, screenshot plan, support/privacy/review documents, and deterministic review corpus.
- Fail-closed release scripts and static deletion-API scan.

## Current validation status

- Phase 5O static validation passes with only the intentional release-identity warning.
- Unsigned Debug build, XCTest, XCUITest, Analyze, and unsigned Release archive are the local verification targets.
- Release signing identifiers and public URLs remain intentionally deferred until final release configuration.

## Required Mac-only work

1. Run a clean Xcode build, XCTest, static analyzer, and Release archive.
2. Resolve every SDK/concurrency warning without weakening safety or actor isolation.
3. Configure real bundle/team/IAP IDs and all public/legal placeholders.
4. Complete StoreKit local, sandbox, restore, refund/revocation, pending, offline, and Family Sharing tests.
5. Complete VoiceOver, Full Keyboard Access, contrast, motion, dark/light, and localization QA.
6. Approve a human-labelled similarity calibration corpus.
7. Measure 10K/50K/100K real libraries with Instruments and interruption tests.
8. Complete App Store privacy, age, rights, export, business, screenshot, and review fields.
9. Upload, validate, TestFlight/beta test, and submit.

The project is a release-handoff source package, not a signed production binary.
