# Cullora Phase 5Q — Archive Review Studio Shell Alignment

## Objective

Bring the inherited Phase 5O/5P visible shell into the locked ten-app Cullora identity without changing the proven exact-duplicate, quarantine, restore, similarity, persistence, or StoreKit safety architecture.

## Implemented

- Replaced the root `NavigationSplitView` with a horizontal **Workspace Shelf** below a compact Cullora archive masthead.
- Replaced the Review Studio permanent `HSplitView` with a full-width **Review Floor**.
- Exact/similar group navigation now lives in a **temporary Review Queue drawer** opened by explicit user command.
- Exact/similar evidence now lives in a **temporary Evidence drawer** rather than a permanent inspector.
- Added a bottom **Decision Shelf** for focused exact-photo Keep / Add to Plan / Skip actions, photo navigation, planned-count/recovery summary, and Safety Plan continuation.
- Similar-photo mode has a distinct review-only bottom shelf and continues to expose no cleanup authorization.
- Converted generic rounded `PremiumCard` containers to asymmetric clipped **Archive Plate** geometry.
- Preserved Phase 5P Decision Evidence and signed schema-3 decision provenance.
- Preserved all keyboard commands and checkpoint/recovery behavior.

## Explicitly unchanged safety contracts

- Exact cleanup authority requires SHA-256 exact groups.
- One canonical keeper remains protected.
- Similarity never creates cleanup operations.
- Safety Plan is reviewed before commit.
- Source files are re-hashed before movement.
- Quarantine is reversible and restore never overwrites an occupied original path.
- No permanent-delete API is introduced.

## Release identity

- Marketing version: `0.9.7`
- Build: `160`
- Diagnostics implementation phase: `5Q`
