# Cullora Phase 5R — Safety Plan Freshness & Supersession Lineage

## Purpose
Phase 5R closes the time-of-check/time-of-use gap between exact-duplicate review decisions and quarantine commit. A Safety Plan is now a snapshot of the exact-review decision set that created it. If the underlying plan membership, keeper identity, digest, actor/reason provenance, or decision update time changes after preparation, the plan becomes stale and file-system mutation is blocked.

## Implementation
- Marketing version: `0.9.8`
- Build: `170`
- Diagnostics implementation phase: `5R`
- Signed cleanup manifest schema: `4`
- Local lineage file: `Application Support/Cullora/SafetyPlanLineage.json`

### Decision snapshot fingerprint
`SafetyPlanDecisionFingerprint` creates an order-independent SHA-256 fingerprint from each planned exact-copy decision:
- comparison group ID
- asset ID
- protected canonical keeper ID
- exact digest
- decision actor
- decision reason code
- decision update timestamp

### Freshness gate
`QuarantineCoordinator.assessFreshness` re-queries the current cleanup candidate set from SQLite using the current source-volume identity. Commit is allowed only when both the current fingerprint and operation count match the prepared plan.

The gate exists twice by design:
1. AppModel checks freshness before invoking commit and updates the UI.
2. `QuarantineCoordinator.commit` independently checks freshness again before writing the signed manifest or moving any file.

### Plan lineage
Each prepared plan receives:
- lineage ID
- previous lineage ID
- revision number

The local lineage ledger records `prepared`, `stale`, `superseded`, `cancelled`, `committed`, or `failed` state. A regenerated plan receives a new revision referencing the preceding lineage ID.

### Signed manifest provenance
Schema 4 adds:
- `decisionSnapshotFingerprint`
- `safetyPlanLineageID`
- `previousSafetyPlanLineageID`
- `safetyPlanRevision`

These fields are signed with the existing cleanup manifest before the first file-system mutation.

## Safety boundaries retained
- Exact SHA-256 duplicates only may enter cleanup.
- Similarity suggestions remain review-only and never create cleanup decisions.
- The canonical keeper cannot be removed.
- File content is re-hashed immediately before move.
- Family all-or-nothing rules remain fail-closed.
- No permanent delete API was added.
- Restore and manifest verification behavior remains intact.
