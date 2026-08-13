# Cullora Phase 5F — Working Xcode Project

## Delivered vertical slice
1. Open `Cullora.xcodeproj` directly in Xcode.
2. Select a Development Team and replace `com.yourcompany.cullora`.
3. Run the `Cullora` scheme on My Mac.
4. Choose a folder through `NSOpenPanel`.
5. Start a read-only scan.
6. The app enumerates supported media, streams SHA-256 over each file, persists assets/fingerprints/checkpoints in SQLite WAL mode, rebuilds deterministic exact groups, and opens Review Studio.
7. Review decisions are in-memory only in Phase 5F. There is deliberately no destructive commit path.

## Implemented source areas
- Real `.xcodeproj`, shared scheme, App Sandbox entitlements, privacy manifest, StoreKit test configuration.
- SQLite schema v1 and migration.
- Exact hashing vertical slice with cancellation and checkpoint updates.
- Security-scoped folder bookmark restoration.
- Premium SwiftUI Library Health and three-pane Review Studio.
- PhotoKit enumeration benchmark harness; mutation code remains isolated.
- Exact hasher and SQLite grouping tests.
- Expanded deterministic corpus generator: exact, recompression, resize, rotation, crop, watermark, color edit, metadata copy, RAW/JPEG/XMP and Live Photo fixtures.

## Safety status
Phase 5F cannot delete files. `PhotoLibraryAdapter.delete` exists as an isolated future adapter spike but is not reachable from UI, ScanCoordinator, Review Studio, or commands. Before Phase 5G, add signed precommit manifests, availability checks, family blockers, quarantine/Trash adapter, explicit confirmation, and integration tests.

## Xcode setup
- Xcode: use a current stable Xcode that supports the installed macOS SDK.
- Deployment target: macOS 13.0.
- Signing: choose your team; use automatic signing.
- Bundle ID: change placeholder in target Build Settings.
- Photos description is included in `Info.plist`.
- App Sandbox and user-selected read/write access are included in `Cullora.entitlements`.
- StoreKit product is test-only until App Store Connect creates the matching non-consumable.

## Validation commands
```bash
python3 CorpusTools/generate_corpus.py --out /tmp/cullora-corpus --count 1000 --seed 42
python3 CorpusTools/benchmark_exact.py --corpus /tmp/cullora-corpus --out /tmp/cullora-benchmark.json
xcodebuild -project Cullora.xcodeproj -scheme Cullora -configuration Debug build
xcodebuild -project Cullora.xcodeproj -scheme Cullora -destination 'platform=macOS' test
```

## Known Phase 5F limits
- No Photos-byte hashing yet; only folder/external-volume files enter the working vertical slice.
- No incremental skip based on unchanged size/mtime yet; files are rehashed on each scan.
- Removed files are not pruned from the index yet.
- Thumbnail loading is intentionally simple; Phase 5G should add bounded thumbnail cache and Quick Look/ImageIO downsampling.
- Review decisions are not persisted.
- No Safety Plan, quarantine, Trash, manifest signing, restore, StoreKit entitlement UI, or App Store release claim.
- Privacy manifest contains no required-reason declarations; run Xcode privacy report and fill exact Apple-approved reasons before release.
