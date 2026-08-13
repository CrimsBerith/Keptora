# Phase 5H Implementation

**Date:** 3 August 2026  
**App version:** 0.7.0 (70)  
**Database:** schema v3  
**Manifest:** schema v2

## Delivered

### Asset-family graph
`AssetFamilyGraphBuilder` recognizes conservative filename/directory relationships:
- RAW + rendered JPEG/HEIC/TIFF + XMP;
- image + MOV Live Photo exports with the same stem;
- XMP/AAE sidecar bundles;
- filenames with explicit `BURST###` markers;
- edited/export/copy derivatives.

RAW/sidecar and Live Photo families use `allOrNothing`; burst and edited/export families are advisory. Family metadata is persisted and shown on Review cards and Safety Plan operations.

### Resumable exact index
The scan session stores a stable-key cursor every 100 processed files. Resume occurs only when the cursor still exists, the prefix count is unchanged, every prefix asset was written by the same session, and size/mtime still match. Any inserted, removed, or changed prefix starts a fresh scan session rather than skipping uncertain files.

### External-volume identity
The app stores volume UUID/name/root metadata with the bookmark. Source IDs derive from physical volume ID plus relative folder path, so renaming the mount does not split the index. A different disk mounted at the saved path is rejected. Volume notifications trigger bookmark re-resolution and UI state refresh.

### Bounded thumbnails
`BoundedThumbnailCache` first downsamples with ImageIO and falls back to Quick Look. It coalesces in-flight requests and uses `NSCache` limits of 96 MiB and 320 entries. The Review Studio no longer loads complete file bytes into `Data` for thumbnails.

### Coordinated mutation and recovery
Quarantine and restore use coordinated two-location moves. The physical volume is checked before the plan and again before every operation. Startup reconciliation is source-scoped and handles:
- move completed before database update;
- restore completed before database update;
- original remained and quarantine is absent;
- both copies exist;
- neither copy exists.

Only digest-verified unambiguous states repair the database automatically. Both-copy and missing-copy states require attention and leave disk contents untouched.

### PhotoKit and similarity boundaries
A read-only PhotoKit probe can enumerate original resources and measure locally readable bytes with network access disabled by default. The delete adapter remains unreferenced by AppModel/views. Similarity and PhotoKit byte probes are disabled feature flags.

## Compatibility note
Phase 5H changes development source IDs from path-only to volume-stable v2 IDs. An index created by Phase 5G may be rebuilt once. This does not move or delete originals; prior cleanup history and manifests remain available.

## Not claimed
This Linux environment cannot run the macOS SDK, App Sandbox, Quick Look, PhotoKit, AppKit, asset catalog compiler, code signing, or `xcodebuild`. A successful Mac binary is therefore not claimed. Use `./Scripts/build_and_test_on_mac.sh` on a Mac before beta distribution.
