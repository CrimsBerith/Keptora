# SCREEN_SPEC.md — Phase 5I

## Home
Premium hero, active source, physical-volume state, scan CTA, index/exact/quarantine metrics, live hash/reuse status, recovery reconciliation card, and local/reversible safety explanation. Scan is disabled for disconnected or replaced volumes.

## Review Studio
A segmented **Exact / Similar** workspace.

### Exact mode
Three panes:
- exact SHA-256 groups and persisted plan indicators;
- bounded local thumbnails, family badge, size/date evidence, Keep/Add to Plan/Skip;
- SHA-256 evidence, protected keeper, selected bytes, and Safety Plan CTA.

Strict family badges indicate paired components. The keeper cannot be skipped or quarantined.

### Similar mode
- Explicit **Analyze Similar Photos** action and cancellable progress.
- On-device indexing status: built, reused, safely skipped, and candidate-distance counts.
- Conservative anchor groups with confidence tier and direct distance evidence.
- Side-by-side local thumbnails and **Reveal in Finder** only.
- No Keep, Skip, Add to Plan, quarantine, delete, or automatic-best-photo control.
- Uncalibrated bootstrap results are visibly described as suggestions, not proof.

## Safety Plan
Shows source volume, exact original/quarantine paths, bytes, family kind/role, advisory family warnings, signed-manifest notice, and explicit Cancel / Move to Quarantine actions. Only SHA-256 exact duplicates can enter this flow. Strict partial families block plan creation before the sheet opens.

## History
Shows source, state, operation count, bytes, signed manifest, Show Manifest, and Restore. Restore is available only for committed/partial states and blocks if the original path is occupied or the physical volume differs.

## Recovery card
After launch, source-scoped reconciliation results explain recovered moves/restores and attention-required both-copy/missing-copy states. Ambiguous cases contain no automatic delete, overwrite, or merge action.

## Settings
Displays Phase 5I, schema v4, manifest v2, privacy guarantees, 96 MiB thumbnail budget, enabled on-device similarity analysis, and the disabled-by-default PhotoKit original-byte probe.
