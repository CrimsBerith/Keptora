# First Mac Beta Build Checklist — Phase 5J

## Identity and build
- [ ] Replace bundle ID and choose Development Team.
- [ ] Confirm version 0.9.0, build 90, macOS 13 target.
- [ ] `./Scripts/validate_package.sh` passes.
- [ ] Debug build and all XCTest pass on current stable Xcode.
- [ ] Release Archive validates in Organizer.

## Sandbox and volumes
- [ ] Bookmark survives relaunch.
- [ ] Scope start/stop stays balanced on success, cancel, failure, similarity analysis, and restore.
- [ ] Same external disk reconnects and retains source identity.
- [ ] Volume rename retains source identity.
- [ ] Replacement disk at the same path is rejected.
- [ ] Disconnect during scan/commit/restore leaves a recoverable state.

## Exact index and families
- [ ] Cold scan hashes all; warm scan hashes none unchanged.
- [ ] Changed prefix invalidates cursor and safely restarts.
- [ ] Unchanged durable prefix resumes after force quit.
- [ ] RAW/JPEG/XMP and Live Photo strict partial plans are blocked.
- [ ] Burst and edited/export partial selections show warnings.
- [ ] Existing pre-v4 development database migrates without losing exact decisions or cleanup history.

## Similarity engine
- [ ] Feature print request runs with revision 1 and `scaleFit` on the minimum supported macOS.
- [ ] Stored archives unarchive and compare after relaunch.
- [ ] Unchanged content reuses its stored feature; changed digest rebuilds it.
- [ ] A damaged or unsupported image is counted and skipped without aborting the remaining library.
- [ ] Cancellation stops indexing/comparison promptly and does not create cleanup decisions.
- [ ] Similar results expose only evidence and Reveal in Finder.
- [ ] No similarity group can create a Safety Plan or quarantine operation.
- [ ] Candidate recall and Vision distance distributions are measured on a human-labeled corpus.
- [ ] Conservative bootstrap thresholds remain marked uncalibrated until release-quality labels exist.

## Thumbnail and UI
- [ ] RAW/HEIC/JPEG/video thumbnails render through ImageIO/Quick Look.
- [ ] Instruments confirms memory follows the 96 MiB cache budget.
- [ ] Rapid scrolling coalesces requests and does not load full files into memory.
- [ ] Exact and Similar modes remain responsive during 10K+ scanning/indexing.

## Manifest, quarantine, restore
- [ ] Manifest v2 exists and verifies before first move.
- [ ] Source is re-hashed and physical volume rechecked per operation.
- [ ] Collision never overwrites.
- [ ] Quarantine remains on the selected volume.
- [ ] Restore verifies signature/digest and exact path.
- [ ] No permanent delete, purge, Trash, or connected Photos mutation exists.

## Interruption reconciliation
- [ ] Move completed / DB pending repairs to quarantined.
- [ ] Restore completed / DB quarantined repairs to restored.
- [ ] Original-only pending becomes failed without moving a file.
- [ ] Both-copy state requires attention and preserves both.
- [ ] Neither-copy state requires attention and changes no DB asset path.
- [ ] Recovery is scoped to the active source only.

## Performance and release boundary
- [ ] `./Scripts/benchmark_vision_on_mac.sh` completes and saves its artifact.
- [ ] 10K, 50K, and 100K real-library runs record wall time, peak RSS, thermal state, cancellation latency, database size, candidate count, and decode failures.
- [ ] Network capture confirms zero core traffic.
- [ ] Release build contains no permanent deletion or automatic similar-photo action.
- [ ] App Review notes explain local analysis, advisory similarity, exact-only quarantine, restore, and no permanent deletion.

## Phase 5J comparison, StoreKit, accessibility
- [ ] Synchronized comparison holds the same zoom/pan viewport in both panes.
- [ ] Changing comparison member resets the viewport safely.
- [ ] Precision-first is the default and no preset widens persisted thresholds.
- [ ] Lifetime purchase, pending, cancel, restore, revoke, offline, and Family Sharing pass.
- [ ] VoiceOver, Full Keyboard Access, Increase Contrast, Reduce Motion, dark mode, and Turkish layouts pass.
- [ ] Static forbidden-delete scan passes.


## Phase 5O verified restore
- [ ] Restore dry run verifies the signed manifest before mutation.
- [ ] Occupied original path is blocked and never overwritten.
- [ ] Missing quarantine file is reported per operation.
- [ ] Changed digest/byte count is blocked.
- [ ] Already-restored operations are reported without re-running.
- [ ] 10K operation plan and restore lists remain responsive.
- [ ] Unicode/case-folded exclusions match user expectations.
- [ ] Local performance history contains no path or media identifiers.
