# Keptora — Recovery / Cancellation / Stress / Focus Wave

- Product surface: **Archive Review Studio → Reconciliation Drawer**
- Crash-safe JSON operation journal is compiled into the app target.
- Writes are atomic; malformed journal entries are quarantined instead of silently reused.
- Started work can be detected as stale without converting cancelled/failed/committed work into resumable work.
- Cancellation is explicit and persisted.
- 100K classification fixture validates deterministic recovery filtering.
- Focus-order contract remains product-specific: `archive.masthead → workspace.shelf → review.floor → reconciliation.drawer → decision.shelf`.
- Shared recovery code is invisible infrastructure only; no portfolio UI shell is shared.
- Mac-only Xcode build/runtime/VoiceOver validation remains required.
