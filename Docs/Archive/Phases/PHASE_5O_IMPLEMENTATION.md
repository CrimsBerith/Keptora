# Phase 5O — Verified Restore Center, Large-Plan Scaling, and Local Performance History

**Version:** 0.9.5 (140)  
**Date:** 4 August 2026

## Goal

Phase 5O closes the largest trust gap left after Phase 5N: a user must be able to inspect whether a quarantine plan is actually safe to restore before any file-system mutation occurs. It also keeps 10K-operation Safety Plans responsive, hardens exclusion matching, and records bounded on-device performance samples without analytics.

## 1. Verified Restore Center

`QuarantineCoordinator.previewRestore(planID:)` performs a read-only dry run:

1. Loads the stored manifest record.
2. Verifies the signed envelope and plan ID.
3. Confirms the original source volume identity.
4. Reads the current operation states from SQLite.
5. Refuses occupied original destinations.
6. Detects missing quarantine files.
7. Re-hashes every eligible quarantine file.
8. Compares SHA-256 and byte count against the signed manifest.
9. Produces a per-file `RestoreOperationCheck` without moving anything.

Restore remains disabled when any active quarantined operation is blocked. Existing paths are never overwritten.

## 2. Quarantine & Restore Center

The History screen is now a dedicated recovery center with:

- active-plan, file-count, restorable-space, and manifest summaries;
- source/plan search;
- quarantine/restored/attention filters;
- signed-manifest reveal;
- explicit **Review Restore** entry point;
- per-operation conflict details;
- mandatory confirmation before restore.

## 3. Large Safety Plan performance

Safety Plan and Restore Preview lists render at most 300 rows initially. Users can reveal another 300 rows on demand. The full plan remains in memory for signed export and execution, but SwiftUI does not eagerly construct thousands of visible rows.

Safety Plans can be sorted by path, filename, or largest file. Plans over 1,000 operations show an explicit large-plan mode notice.

## 4. Unicode-safe source exclusions

`SourceExclusionPolicy` now:

- canonicalizes composed/decomposed Unicode;
- folds case and width predictably;
- trims leading dots from extension rules;
- compares path components rather than raw string replacement;
- keeps `.Keptora Quarantine`, `.git`, `node_modules`, and `@eaDir` protected.

New XCTest coverage checks decomposed accents, uppercase extensions, and mixed-case quarantine paths.

## 5. Telemetry-free local performance history

Keptora records at most 200 local samples for:

- exact scans;
- similarity analysis;
- quarantine commits;
- restores.

Each sample contains only a stage label, item count, elapsed time, calculated throughput, result, and timestamp. No paths, filenames, hashes, image bytes, or identifiers are recorded. Users can export the JSON history from Diagnostics.

## 6. Safety invariants retained

- No Apple Photos deletion API.
- No Finder Trash call.
- No permanent quarantine purge.
- Similarity cannot create cleanup operations.
- Keeper protection remains mandatory.
- Restore is available without Pro.
- Manifest verification and same-volume checks remain mandatory.
- Static validation still fails closed for placeholder release identifiers in release mode.

## 7. Required Mac validation

The source package still requires real macOS/Xcode validation for:

- SwiftUI/AppKit compile and link;
- Restore Preview with 1K/10K real files;
- external-volume disconnect during preview and restore;
- Unicode exclusion UI entry with Turkish/Japanese filenames;
- VoiceOver and Full Keyboard Access;
- StoreKit sandbox and signed Release archive;
- Instruments memory/CPU/thermal testing.
