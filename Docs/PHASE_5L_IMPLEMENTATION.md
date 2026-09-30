# Keptora Phase 5L Implementation

**Version:** 0.9.2  
**Build:** 110  
**Goal:** Expand the evidence base with direct and adjacent applications, then convert only safe, high-value workflow gaps into the native Mac product.

## Product additions

### Review queue intelligence

- Search exact groups by file name or path.
- Filter by All, Unreviewed, In Progress, Planned, and Reviewed.
- Sort by recoverable storage, copy count, or name.
- Display group state and decided/extra counts in the sidebar.

### Exact-only batch review

- `Plan Exact Extras` marks every non-keeper in a SHA-256 exact group for reversible quarantine.
- `Skip Extras` marks every non-keeper reviewed without adding it to the plan.
- Batch access is authorized before database persistence.
- The database applies the group action in one transaction.
- The protected keeper cannot be included.
- Similar groups have no batch decision path.

### Review Insights

- Exact group pipeline: unreviewed, in progress, planned and reviewed.
- Total potential versus currently planned recovery.
- Exact-asset and similar-set counts.
- Direct navigation back to Review Studio.

### Keeper explanation

- Default keeper explains the deterministic policy: oldest modification date, then shortest stable path.
- A user-selected keeper is identified as an override.
- The keeper can be revealed in Finder.

## Research additions

- 22-product competitor matrix across direct Mac cleaners, Photos-library managers, professional culling tools, editing-suite incumbents, and mobile-adjacent products.
- Adopt/defer/reject decision ledger.
- Release information intake and App Store Connect field map.
- Feature gap roadmap with Phase 5M candidates.

## New tests

- Batch free-tier authorization counts only new assets.
- Batch authorization fails before partial application when allowance is insufficient.
- Exact batch persistence keeps the canonical asset and plans only non-keeper members.

## Safety invariants retained

- Exact SHA-256 proof is required for cleanup authorization.
- Similar photos remain advisory.
- No permanent-delete API, Finder Trash action, or quarantine purge.
- Family and volume checks remain in the commit path.
- Restore remains available without Pro.

## Remaining Mac-only work

Real Xcode compile/test/analyze/archive, signing, StoreKit sandbox, accessibility QA, real-photo calibration, real-library benchmarks, screenshot capture, trademark clearance, public URLs, App Store Connect configuration and submission.
## Additional hardening completed

- Expanded the structured competitor register from 16 to 22 products, adding Cisdem Duplicate Finder, Nektony Duplicate File Finder, Duplicate Photos Fixer Pro, Mylio Photos, PicArrange, and PhotoSort.
- Replaced all `ContentUnavailableView` usages with `KeptoraUnavailableView` so the declared macOS 13 deployment target does not depend on a newer empty-state component.
- Added Turkish translations for the compatibility empty states.
- Kept visual maps, aesthetic scores, and similar-photo evidence outside exact-cleanup authorization.

