# Cullora Phase 5S — Quarantine Verification Lineage

Version **0.9.9 (180)** adds a post-mutation evidence layer without changing Cullora's exact-only cleanup authority.

## What changed
- Every successful commit is re-read from SQLite and the file system after the move loop finishes.
- Each quarantined destination is re-hashed against the signed schema-4 manifest; unexpected originals, missing quarantine files, changed bytes, and DB-state disagreement are explicit review states.
- Restore receives the same independent post-restore verification.
- **Verify State** is a read-only user action in History. It never moves, deletes, restores, or reclassifies a file.
- Verification results form an append-only per-plan revision chain in `Application Support/Cullora/QuarantineVerificationLineage.json`.
- Lineage records store fingerprints/counts/state, not raw source or quarantine paths.

## Safety boundary
A file move/restore result and its later verification result are separate facts. A missing verification record is never treated as verified. Similarity remains review-only and cannot authorize cleanup.
