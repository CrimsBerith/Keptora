# Codex / Grok Mac Release Runbook — Cullora Phase 5Q

This runbook is designed for Codex or a human operator on a Mac with the current stable Xcode. It must be executed against the exact ZIP SHA recorded in the handoff report.

## 1. Unpack and establish a clean baseline

```bash
unzip Cullora_Phase_5Q_Archive_Review_Studio_Shell.zip
cd Cullora_Phase_5Q_Archive_Review_Studio_Shell
./Scripts/validate_phase5q_static.py
./Scripts/validate_app_store_metadata.py
./Scripts/validate_package.sh
```

The non-release static validator may warn about placeholder identifiers. Do not suppress those warnings.

## 2. Configure real identifiers

Create the App Store Connect app record and one non-consumable IAP first. Then run:

```bash
./Scripts/configure_release_identifiers.sh \
  com.example.cullora \
  YOURTEAMID \
  com.example.cullora.pro.lifetime
```

Replace all values with the actual registered identifiers. Then verify:

```bash
./Scripts/validate_phase5q_static.py --release
```

Also replace public URL, legal, contact, and review-note placeholders in `AppStore/`.

## 3. Xcode project setup

1. Open `Cullora.xcodeproj`.
2. Select the Cullora app target and the real Development Team.
3. Confirm macOS deployment target 13.0 or the approved final target.
4. Confirm App Sandbox, Hardened Runtime, User Selected File read/write, `com.apple.security.files.bookmarks.app-scope`, and `com.apple.security.personal-information.photos-library`. Do not enable broad Pictures-folder access unless a shipping workflow requires it.
5. Select `Cullora.storekit` in the Run scheme for local purchase testing only.
6. Keep strict concurrency diagnostics enabled; do not silence warnings with unsafe isolation changes.
7. Clean the build folder and resolve every compile error or warning that affects correctness.

## 4. Automated release gate

```bash
./Scripts/release_gate_on_mac.sh
```

The script performs static release validation, package validation, XCTest with coverage, static analysis, benchmark invocation, Release archive, privacy-manifest inspection, and archived-entitlement validation. Preserve outputs under `ValidationArtifacts/Mac/`.

## 5. StoreKit matrix

Test with local StoreKit configuration, sandbox/TestFlight, and a clean Apple Account state:

- Product loading and localized real price.
- Successful purchase.
- User cancellation.
- Pending/Ask to Buy.
- Relaunch after purchase.
- Offline relaunch with the latest entitlement state.
- Restore on a second Mac.
- Refund or revoked entitlement.
- Family Sharing after it is enabled in App Store Connect.
- Missing/unavailable product handling.
- Restore availability even when the user has no Pro entitlement.

Record date, account type, storefront, build, result, and evidence for every case.

## 6. Safety and recovery matrix

Use the synthetic corpus plus real anonymized libraries:

- Exact keeper protection.
- Similar groups expose no cleanup authorization.
- Safety Plan preview matches committed operations.
- Same-volume quarantine.
- Filename collision without overwrite.
- Force quit before move, during move, after move/before DB update, and during restore.
- External-drive disconnect and reconnect.
- Low-disk condition.
- Corrupt/unsupported image.
- Deleted or manually altered quarantine file.
- Restore with wrong source volume selected.
- App relaunch after interrupted migration.

No release candidate passes while any test can cause silent loss, overwrite, permanent deletion, or an unrecoverable entitlement gate.

## 7. Performance and calibration

- Run 10K, 50K, and 100K real-library tests.
- Capture cold scan, warm incremental scan, exact hashing, feature reuse, candidate generation, thumbnail memory, cancellation latency, and peak RSS.
- Test an Apple Silicon Mac and an Intel Mac only if Intel remains in the support matrix.
- Label a real-photo calibration corpus and approve precision/recall before enabling similarity by default.

## 8. Accessibility and localization

- VoiceOver navigation and spoken labels.
- Full Keyboard Access and all documented shortcuts.
- Increase Contrast, Reduce Motion, dark/light mode, and text scaling.
- English and Turkish truncation, grammar, plural, date, byte, and currency formatting.
- Publish accessibility nutrition labels only for capabilities actually verified.

## 9. Product-page and privacy completion

- Run `Scripts/validate_app_store_metadata.py` after final text edits.
- Capture real 2880 × 1800 screenshots according to `AppStore/SCREENSHOT_CAPTURE_PLAN.md`.
- Publish the final privacy and support pages.
- Compare the archived PrivacyInfo.xcprivacy and SDK manifests with the App Privacy answers.
- Complete age rating, export compliance, content rights, DSA/trader, IAP review screenshot, and App Review contact.

## 10. Archive and submission

1. Increment build if any binary change occurs.
2. Run the complete release gate again.
3. Archive in Xcode Organizer.
4. Validate the archive.
5. Upload to App Store Connect.
6. Review processing warnings and privacy reports.
7. Select the build and attach the non-consumable IAP.
8. Paste final App Review notes and verify all URLs.
9. Submit only after a final test from the uploaded/TestFlight-equivalent build.

## Release evidence record

Update `VALIDATION_REPORT.md` with:

- Mac model and architecture.
- macOS and Xcode versions.
- Project ZIP SHA and source revision.
- Test totals and failures.
- Static analyzer result.
- Archive/validation result.
- StoreKit matrix.
- Safety/recovery matrix.
- Accessibility/localization result.
- Performance numbers.
- Remaining defects and the release decision.


## Phase 5O restore and scale validation

1. Commit a sample exact-duplicate plan.
2. Open **Quarantine & Restore** and verify that **Review Restore** hashes every eligible quarantine file.
3. Recreate one original-path file and confirm restore is blocked without overwrite.
4. Remove the conflict, tamper with one quarantine file, and confirm digest mismatch blocks restore.
5. Restore an unmodified plan and verify SQLite/history/manifest state.
6. Generate a 1K and 10K operation plan; confirm 300-row incremental rendering, search, sort, and memory behavior.
7. Enter composed/decomposed Unicode folder exclusions and mixed-case extensions.
8. Export local performance history and confirm it contains no paths, filenames, hashes, or image data.


## Phase 5P review confidence and provenance validation

1. Create a 3+ member exact SHA-256 group and inspect **Decision Evidence** for the protected keeper.
2. Add one non-keeper to the Safety Plan and confirm the evidence state is **Verified exact copy** with a human-readable reason.
3. Change the keeper and verify the former keeper decision is recorded separately; no canonical keeper may enter quarantine.
4. Use **Plan Exact Extras** and confirm each planned extra has `user-batch-added-exact-extras` provenance.
5. Export the Safety Plan JSON and verify each operation includes decision actor, reason, decision timestamp, and canonical keeper ID.
6. Commit the plan and decode the signed manifest; it must be schema 3 and preserve the same decision provenance.
7. Modify a reviewed source file before commit and confirm the existing re-hash gate blocks the move.
8. Confirm similar-photo review never exposes Decision Evidence as cleanup authorization and never produces cleanup operations.
9. Run the Phase 5P 100K review-evidence smoke and record its result.


## Phase 5Q shell-alignment validation

1. Confirm there is no permanent root navigation sidebar; switch every route through the horizontal Workspace Shelf.
2. At 1240×800, review an exact set with both drawers closed and verify the Review Floor remains the dominant composition.
3. Open Queue, select another group, close it, then open Evidence; verify only one transient drawer is open at once.
4. Complete Keep / Add to Plan / Skip using only the Decision Shelf and keyboard equivalents.
5. Switch to Similar and verify the bottom shelf exposes review-only language and no cleanup authorization.
6. Test clipped Archive Plate geometry in light/dark mode and Increase Contrast.
7. Run VoiceOver in the order documented in `Docs/Phase_5Q/PHASE_5Q_QA_MATRIX.md`.
8. Reject any visual fix that recreates a permanent left-sidebar + center + right-inspector shell.
