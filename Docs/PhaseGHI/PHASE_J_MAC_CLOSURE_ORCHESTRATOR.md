# Phase J — Mac Closure Orchestrator — Cullora

Phase J adds **release tooling only**. It does not change or homogenize the visible product shell.

- Product shell remains **Archive Review Studio**.
- `Scripts/run_phase_j_mac_closure_orchestrator.sh prepare /path/to/real-corpus` executes the automatable Mac chain: Release profiling build, real-corpus Instruments suite, Thread Sanitizer gate, Phase H build/test/analyze/archive/signature evidence, then prepares Phase I evidence bundles.
- `Scripts/run_phase_j_mac_closure_orchestrator.sh finalize` succeeds only after every required Phase I evidence record contains `RESULT=PASS` plus a concrete evidence reference.
- `PHASE_J_TSAN_MODE=required` is the default. Any explicit downgrade remains visible in the receipt and is not treated as a silent pass.
- Private corpus data is never copied into the app package by this script.
- Phase J **does not auto-pass manual App Store evidence** such as TestFlight install/upgrade, VoiceOver/keyboard review, StoreKit sandbox edge cases, screenshots, or Organizer Validate App. Those remain fail-closed evidence records.

## Acceptance

1. Source gate passes on non-macOS hosts without claiming Mac execution.
2. `prepare` refuses non-macOS hosts and missing real corpus directories.
3. `prepare` cannot reach Phase H before G trace production and source-readiness gates.
4. `finalize` cannot pass while any Phase I evidence is pending or lacks a concrete evidence reference.
5. Archive Review Studio identity remains unchanged.
