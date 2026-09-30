# Keptora — Phase 5S Quarantine Verification Lineage

Keptora is a native macOS archive-review app. Release candidate target: **1.0.0 (181)** for Apple Silicon on macOS 13+.

Phase 5S adds independent post-commit/post-restore verification and append-only verification lineage on top of Phase 5R's stale Safety Plan protection. A successful move is not automatically called verified: Keptora re-reads SQLite state, file presence and signed-manifest digest/byte count. History also exposes a read-only **Verify State** action.

Safety remains fail-closed: exact cleanup requires SHA-256 proof; similar photos stay review-only; similar videos require explicit manual selection and a fresh byte-level recheck; every group protects a keeper; folder cleanup uses reversible quarantine; Photos uses Apple's Recently Deleted flow.

Start with `CODEX_GROK_MAC_HANDOFF.md`, `Docs/Phase_5S/PHASE_5S_IMPLEMENTATION.md`, and `VALIDATION_REPORT_PHASE_5S.md`.


## Phase G Mac profiling closure
- Static readiness: `./Scripts/validate_phase_g_readiness.sh`
- Real Mac trace suite: `./Scripts/run_phase_g_profile_suite.sh <external-corpus> <built-app>`
- Product shell remains **Archive Review Studio**; real corpus remains external.


## Phase H–I Mac closure automation
- Static readiness: `./Scripts/validate_phase_h_i_readiness.sh`
- Phase H Mac runner: `./Scripts/run_phase_h_release_candidate_macos.sh <phase-g-trace-dir>`
- Phase I checklist: `AppStore/PHASE_I_FINAL_QA_CHECKLIST.md`
- Preserve **Archive Review Studio** through final screenshots and TestFlight QA.
