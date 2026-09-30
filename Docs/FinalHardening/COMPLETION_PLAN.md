# Keptora — P6 Completion Hardening

- Visible shell remains **Archive Review Studio**; no shared portfolio shell is allowed.
- Async ownership: `KeptoraLifecycleCoordinator` invalidates stale callbacks on suspend/resource loss.
- Cancellation: results may commit only while their epoch/token remains current.
- External-resource lifecycle: resume requires explicit resource/bookmark revalidation before adapters mark readiness.
- Window stress: `KeptoraWindowStressContract` preserves the product-specific primary region `reviewFloor` and compact behavior `collapseTicketShelf`.
- Linux/source gate: `./Scripts/validate_final_hardening_wave.sh`.
- Mac-only closure still required: real compact/large window screenshots, background/resume with real files/volumes, Xcode Thread Sanitizer where applicable, Instruments trace, VoiceOver/keyboard runtime, StoreKit sandbox, signing, Archive/Validate/TestFlight.

This is a source hardening contract, not a claim that Mac-only release gates have passed.
