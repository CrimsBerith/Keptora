# Cullora — Phase G Real Corpus + Instruments

Successor: **P6**  
Distinct shell: **Archive Review Studio**

Phase G is fail-closed: real corpus stays external and actual traces are only produced on macOS with Xcode/Instruments installed.

## Mac execution

```bash
./Scripts/validate_phase_g_readiness.sh
./Scripts/run_phase_g_profile_suite.sh /absolute/external/corpus /absolute/path/to/Cullora.app
```

The suite records Time Profiler, Allocations and Leaks, resolves `CFBundleExecutable` from the app bundle, passes the external corpus path through `CULLORA_REAL_CORPUS_PATH`, and exports a TOC XML next to every trace.

## Acceptance
- real corpus inventory succeeds;
- no user corpus is copied into the package;
- all three trace bundles are non-empty;
- each trace has a TOC export;
- the Archive Review Studio workflow is exercised without changing the product-specific shell.
