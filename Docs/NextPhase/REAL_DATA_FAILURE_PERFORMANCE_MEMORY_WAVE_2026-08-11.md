# Keptora — Real-data Failure / Performance / Memory Hardening

- Real Cocoa/URL error classes map to explicit safe failure states.
- Failure copy is product-specific: **Archive Review** / **Return to Review Floor**.
- Raw file names and document contents are not retained in runtime health history.
- Failure history is bounded to 128 entries; latency samples are bounded to 512.
- Temporary operation budget: **96 MiB**, with a 70% safety window and adaptive 8–2048 item batching.
- Cancellation, timeout, disk-full, permission, missing/corrupt input and memory-pressure paths never imply successful commit.
- 100K stress fixture verifies bounded histories and batch planning.
- This is invisible infrastructure; the existing distinct shell/UI metaphor remains authoritative.
- macOS Instruments/Memory Graph and real-file corpus profiling remain Mac-only gates.
