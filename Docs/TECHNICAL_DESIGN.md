# TECHNICAL_DESIGN.md — Phase 5I

## Source access and identity
- `NSOpenPanel` creates a persisted security-scoped bookmark.
- Finder-mounted File Provider locations are supported, including iCloud Drive and providers exposed under `~/Library/CloudStorage`.
- Cloud access is folder-based and local/read-only; Keptora does not implement provider account login, upload, or cloud synchronization.
- Access is balanced around scan, recovery, similarity analysis, commit, and restore.
- `VolumeIdentity` captures UUID, name, root, removable/local flags.
- `SourceIdentity` uses `volume stable ID + relative folder path`, with path fallback only when volume metadata is unavailable.
- Mount/unmount/rename notifications refresh the bookmark and availability state.

## Exact index and cursor
1. Enumerate supported media, RAW, video, XMP, and AAE while skipping hidden quarantine.
2. Compare source-scoped stable key, size, mtime, digest availability, and active state.
3. Stream SHA-256 for new/changed files; reuse unchanged fingerprints.
4. Store `last_seen_scan_id` and cursor every 100 files.
5. Resume only after validating the entire saved prefix belongs to the same session and still matches metadata.
6. Supersede uncertain sessions and restart safely.
7. Mark unseen active assets missing and rebuild source-isolated exact groups.

## SQLite schema v4
Schema v3 family/recovery tables remain. Phase 5I adds:
- `perceptual_features`: secure Vision archive, dHash, dimensions, revision, crop policy, content digest, pairing revision;
- `perceptual_bands`: eight lookup entries per feature;
- `similarity_pairs`: canonical asset pair, measured distance, tier/profile, evaluation time;
- `similarity_calibration_profiles`: thresholds, sample counts, generated time, calibrated state.

Foreign keys cascade stale perceptual state when an asset disappears. A feature is reused only when exact content digest, Vision revision, and crop policy all match.

## Perceptual pipeline
1. Load active image assets only from the selected source.
2. Create an orientation-correct, bounded 1024-pixel ImageIO thumbnail.
3. Generate a pinned revision-1 Vision feature print with `scaleFit`.
4. Securely archive the observation and calculate a 64-bit grayscale dHash.
5. Index four normal 16-bit bands and four bands after an 8-bit rotation.
6. Query same-source bucket candidates, filter by Hamming distance 14, and cap at 400 candidates per asset.
7. Measure Vision distance only for those candidates and persist values below the storage threshold.
8. Mark a feature paired only after its candidate pass completes.
9. Build anchor groups where every displayed member has a direct measured edge to the anchor.

A damaged or unsupported image is left untouched, counted as safely skipped, and does not abort the library. It is not given a synthetic feature or inferred group membership.

## Calibration and confidence
- `SimilarityCalibrator` derives monotonic thresholds from labeled positive/negative examples using precision and false-positive-rate gates.
- Insufficient labels produce an explicitly uncalibrated conservative bootstrap profile.
- Distance tiers rank review evidence only. They never authorize cleanup.
- Feature-print revision and crop policy are part of the persisted compatibility boundary.

## Family policy
- `rawBundle`, `livePhoto`, `sidecarBundle`: strict all-or-nothing Safety Plan validation.
- `burst`, `editedExport`: advisory warnings.
- Family protection applies to exact cleanup. Similarity relationships do not override family rules.

## Keeper and cleanup protocol
1. Persist exact-review decisions separately from rebuilt groups.
2. Protect a deterministic/user-selected keeper.
3. Validate source scope, strict family completeness, and physical volume.
4. Persist draft operations and signed manifest v2 before mutation.
5. Re-hash each source and coordinate its same-volume move.
6. Persist operation state or attempt inverse compensation.
7. Rebuild exact groups and expose restore history.

Similarity groups cannot call this protocol.

## Reconciliation state machine
Pending/quarantined operations are queried only for the active source. Digest-verified `pending + quarantine-only` repairs to quarantined; `quarantined + original-only` repairs to restored. Both paths or neither path are never resolved destructively. Plan state is recomputed after reconciliation.

## Thumbnail architecture
ImageIO thumbnail creation is preferred. Quick Look handles unsupported formats. A 96 MiB / 320-entry `NSCache` and in-flight task map bound memory and duplicate work.

## Feature boundaries
- PhotoKit original-resource probing is read-only and network-disabled by default.
- Photos deletion is not wired to the app.
- Similarity analysis is on-device and explicitly initiated.
- Similarity is review-only: no Keep, Skip, plan, quarantine, or automatic-best-photo decisions.
- No permanent deletion, Finder Trash, or quarantine purge exists.
