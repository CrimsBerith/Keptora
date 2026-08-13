# Cullora Feature Gap Roadmap

## Shipped through Phase 5M

| Gap | Implementation | Safety rule |
|---|---|---|
| Large queues are hard to navigate | Search, state filters, storage/copy/name sorting | Filtering never changes decisions |
| Group-by-group review is slow | Exact-only Plan Extras and Skip Extras | Keeper excluded; SHA-256 exact groups only; atomic persistence |
| Progress is invisible | Review Insights and group progress | Similar groups never count as cleanup-ready |
| Default keeper is opaque | Deterministic keeper explanation and Finder reveal | User can override with Keep |
| Batch free-tier behavior could partially apply | Batch entitlement authorization | Entire group succeeds or paywall opens before persistence |
| Review position is lost between sessions | Source-bound local checkpoint and resume banner | Checkpoint is rejected when source/group identity no longer matches |
| Exact review is mouse-heavy | Group, photo, decision, and batch keyboard commands | Commands call the same entitlement/database paths as buttons |
| App Review needs deterministic data | On-device synthetic sample library using the real scanner | No network, no personal photos, no mocked cleanup state |
| Product quality could imply telemetry | Local session progress and pace | Metrics stay on-device and are never uploaded |

## Phase 5N candidates — after real Xcode build

1. Date, extension, and source scan presets with a scan-session schema migration.
2. Read-only Photos Library source adapter before any mutation capability.
3. XMP read/write compatibility tests for professional RAW workflows.
4. User-labelled calibration corpus and precision/recall report.
5. Optional on-device face close-up, sharpness, and eyes-open evidence with explicit opt-in.
6. Optional folder monitor with energy budget, pause state, and notification controls.
7. Screenshot automation after UI is confirmed on target Mac hardware.

## Not planned for V1

Permanent Photos deletion, cloud AI, automatic similar-photo cleanup, subscription, photo editing, video compression, cross-platform sync, collaboration, and a general-purpose DAM.
