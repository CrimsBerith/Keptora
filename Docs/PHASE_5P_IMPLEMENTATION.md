# Keptora Phase 5P — Review Confidence & Decision Provenance

**Version:** 0.9.6 (150)  
**Platform:** native macOS 13+ / SwiftUI / SQLite

## Objective

Turn the existing exact-duplicate review decisions into visible, explainable, signed provenance without weakening Keptora's existing safety model.

## Added product capability

- `PersistedReviewDecision` now reads the existing SQLite `reason_code` together with actor and timestamp.
- `ReviewDecisionEvidenceEngine` classifies each exact-review decision as:
  - protected keeper;
  - user-selected keeper;
  - verified exact planned copy;
  - reviewed skip;
  - needs review.
- Planned copies are considered verified only when they are not the current canonical keeper and their SHA-256 digest still matches the exact group digest.
- The exact Review Studio exposes a dedicated **Decision Evidence** sheet for the focused asset.
- Safety Plan rows show decision provenance instead of only file/path/size.
- Safety Plan operations carry actor, reason code, decision timestamp, and canonical keeper identity.
- Signed cleanup manifests advance to schema 3 and seal the same provenance before the first file-system mutation.

## Safety boundaries retained

- Similar-photo groups remain review-only and cannot produce cleanup evidence or operations.
- A canonical keeper remains protected.
- Source files are re-hashed immediately before quarantine.
- Family safety is checked again when the Safety Plan is prepared.
- Digest disagreement results in `needsReview`, never a verified state.
- No permanent deletion API, Finder Trash operation, account, cloud upload, analytics SDK, or AI provider was added.

## Compatibility

Existing SQLite `decisions.reason_code` data is reused; no schema migration is required for the decision evidence layer. New cleanup manifests use schema 3. Existing signed schema-2 manifests remain decodable because the new provenance fields on manifest operations are optional.

## Performance

The Phase 5P pure review-evidence executable processed 100,000 synthetic exact-review decisions in roughly 0.07 seconds in the current container. This does not measure SwiftUI rendering, SQLite I/O, hashing, thumbnails, or real macOS file-system work.
