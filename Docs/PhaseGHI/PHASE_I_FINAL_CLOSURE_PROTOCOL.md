# Cullora — Phase I Final Closure Protocol

## Identity lock
The final submission must preserve **Archive Review Studio** as the dominant product silhouette. No generic portfolio shell may replace it during release fixes.

## Source gate
Run `python3 Scripts/validate_phase_i_source_qa.py`. It fails on missing App Store artifacts, obvious draft placeholders, metadata budget violations, or loss of the product-specific screenshot identity.

## Real evidence bundle
After Phase H archive evidence is PASS, run `Scripts/prepare_phase_i_final_qa_bundle.sh`. Twelve records are created as `PENDING`; none may be auto-promoted. Record concrete Mac/TestFlight/App Store evidence before marking PASS.

## Final gate
Run `Scripts/validate_phase_i_final_submission.sh`. It requires Organizer validation, clean install and upgrade migration, StoreKit edge cases, accessibility, three-size window identity, bookmark recovery, real-corpus profiling, offline/relaunch recovery, privacy/entitlement review, metadata/URL/review-note verification and final screenshot inventory.

A local PASS means the evidence package is internally complete; Apple App Review remains authoritative.
