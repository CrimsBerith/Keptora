# Phase 5I Implementation

**App:** 0.8.0 (80)  
**Database:** schema v4  
**Similarity policy:** on-device, read-only, review-only

## Pipeline

1. Read active image assets from the selected source.
2. Reuse a stored feature only when SHA-256 digest, pinned Vision revision, and crop policy match.
3. Decode a bounded 1024-pixel thumbnail with orientation transform.
4. Generate `VNFeaturePrintObservation` using revision 1 and `scaleFit`.
5. Archive the secure-coding observation and compute a 64-bit difference hash. Damaged or unsupported images are counted and skipped without modifying the file or aborting the remaining library.
6. Insert eight 16-bit lookup bands: four normal and four rotated by eight bits.
7. Measure Vision distance only for dHash candidates within Hamming distance 14, capped at 400 per asset.
8. Persist distances below the profile storage maximum.
9. Build conservative anchor groups; every member must have a direct measured edge to the anchor.
10. Present suggestions without cleanup controls.

## Calibration

`SimilarityCalibrator` derives monotonic thresholds from labeled positive and negative pairs using target precision and false-positive-rate gates. Insufficient labels return an explicitly uncalibrated bootstrap profile. Bootstrap labels are never represented as proof or used for automatic removal.

## 100K benchmark scope

The cross-platform benchmark validates only candidate generation. Apple Vision throughput, energy, GPU/ANE behavior, and feature-print distance distributions require macOS hardware and labeled real images.
