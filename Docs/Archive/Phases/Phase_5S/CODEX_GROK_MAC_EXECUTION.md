# Codex / Grok Mac Handoff — Keptora Phase 5S

Canonical package: **Keptora 0.9.9 (180) — Quarantine Verification Lineage**.

## Start on the Mac
```bash
python3 Scripts/validate_phase5s_static.py
./Scripts/validate_phase5s_core_linux.sh   # Linux CI only; harmless skip elsewhere
python3 Scripts/validate_phase5r_static.py # predecessor safety regression
```
Do not count any combined-script timeout as PASS.

## Xcode acceptance
```bash
open Keptora.xcodeproj
xcodebuild -project Keptora.xcodeproj -scheme Keptora -configuration Debug clean build
xcodebuild -project Keptora.xcodeproj -scheme Keptora test
xcodebuild -project Keptora.xcodeproj -scheme Keptora -configuration Release analyze
```
Then test commit → Verify State → tamper/reappeared-original → restore using an internal SSD and an external APFS/exFAT volume.

## Phase 5S must-not-break invariants
1. Phase 5R stale-plan checks run before every quarantine mutation.
2. Post-commit verification re-reads DB state and file bytes; it cannot infer success from the move counter.
3. Verification failure does not rewrite history as success and does not silently undo a completed move.
4. Manual **Verify State** is read-only.
5. Restore verification uses the signed manifest digest/byte count and requires quarantine absence after successful restore.
6. Similarity remains review-only and cannot enter the exact cleanup path.
7. Verification lineage is append-only and stores no raw file paths.

## Release configuration
Use real values only on the release branch:
```bash
./Scripts/configure_release_identifiers.sh \
  <bundle-id> <team-id> <lifetime-product-id> \
  <privacy-https-url> <support-https-url> <marketing-https-url>
python3 Scripts/validate_phase5s_static.py --release
```
The source handoff intentionally fails this release gate while placeholders remain.

Signing, StoreKit sandbox, VoiceOver, Archive/Validate, TestFlight, and real-volume interruption testing remain mandatory Mac gates.
