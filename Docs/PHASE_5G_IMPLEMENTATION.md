# Cullora Phase 5G — Incremental Index and Reversible Safety Plan

## Delivered user flow
1. Open `Cullora.xcodeproj` and run the macOS app.
2. Choose a user-authorized folder through `NSOpenPanel`.
3. Run an incremental scan.
4. Cullora hashes only new or changed files; unchanged files reuse their stored SHA-256 fingerprint when size and modification time match.
5. Exact groups open in Review Studio with one protected keeper.
6. Review decisions are written to SQLite and survive relaunch and group rebuilds.
7. Add non-keeper copies to the Safety Plan.
8. Review the exact file list, paths, and byte estimate.
9. Cullora writes a signed precommit manifest before the first move.
10. Each selected file is re-hashed and then moved into `.Cullora Quarantine/<plan-id>/…` under the selected source.
11. History shows the plan and signed manifest. Restore verifies the manifest and file digest before moving the file back.

## Incremental index
SQLite schema v2 adds:
- `assets.last_seen_scan_id`
- `assets.is_missing`
- `assets.is_quarantined`
- `scan_sessions.hashed`
- `scan_sessions.reused`
- `scan_sessions.missing`

Warm reuse requires:
- the same source and stable path key;
- the same byte count;
- the same modification timestamp;
- an existing exact digest;
- an asset that is not quarantined.

Files not observed in the completed scan are marked missing instead of being deleted from audit history. Quarantined files are excluded from missing-file pruning and exact grouping.

Exact groups are source-scoped. Identical bytes found under two separately authorized folder roots produce separate groups, decisions, summaries, and Safety Plan candidates. The active dashboard and Review Studio query only the currently selected source; global cleanup history remains available for recovery.

## Canonical protection and decisions
Schema v2 adds `comparison_groups.canonical_asset_id` and the `decisions` table. The group rebuild order is deterministic. A user-selected keeper has priority; otherwise the prior keeper is retained if still present; otherwise Cullora chooses the oldest/shortest deterministic path candidate.

A canonical file cannot be marked Skip or Add to Plan. Selecting another keeper first changes the protected canonical file and persists that choice.

## Signed precommit manifest
`ManifestSigner` uses CryptoKit `Curve25519.Signing.PrivateKey`, whose signing operation is Ed25519-compatible. The private key is generated locally, stored inside Cullora Application Support, and assigned owner-only POSIX permissions where supported. The manifest envelope contains:
- canonical JSON payload encoded with sorted keys;
- signature;
- public key;
- algorithm revision.

The manifest is stored before any file-system mutation and then made read-only where supported. Restore refuses a missing, altered, or unverifiable manifest.

## Quarantine adapter
The quarantine destination is inside the selected source root:

```text
<Selected Folder>/.Cullora Quarantine/<plan-id>/<relative-original-path>
```

This design keeps the move on the source volume and preserves the original relative path. Cullora blocks destination collisions and never overwrites an existing file. The hidden quarantine directory is skipped by the scanner.

Before quarantine and restore, the full SHA-256 and byte count must still match the manifest. If database persistence fails immediately after a move, Cullora attempts to move the file back so disk and database state remain aligned.

## History and recovery
History records Draft, Committing, Quarantined, Partially Quarantined, Restored, Partially Restored, and Needs Attention states. Restore only processes operations recorded as quarantined. It will not overwrite an occupied original path.

## Tests added
- unchanged index reuse and missing-file lifecycle;
- canonical selection persistence across group rebuilds;
- review decision persistence;
- signed manifest creation;
- quarantine and restore integration flow;
- cross-platform 250-file warm/delta scan and Ed25519 recovery smoke benchmark.

## Known Phase 5G limits
- Full macOS SDK build and XCTest execution still require Xcode on a Mac.
- Crash reconciliation during the exact instant between file move and database update is rollback-oriented but does not yet have a startup reconciliation wizard.
- Security-scoped bookmarks are stored for one active folder source; multi-source bookmark persistence is planned.
- RAW/JPEG/XMP, Live Photo, and burst family blockers are not implemented yet.
- Thumbnail loading is still simple and unbounded.
- Photos byte hashing and Photos mutation are not connected.
- There is no permanent delete, quarantine purge, Finder Trash, or Photos deletion UI.

## Mac validation commands
```bash
./Scripts/validate_package.sh
./Scripts/build_and_test_on_mac.sh
```
