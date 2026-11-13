# Keptora — Phase H Release Candidate Closure

Successor: **P6 — Quarantine Decision Reconciliation**  
Distinct shell: **Archive Review Studio**

Phase H begins only after the three Phase G traces and TOC exports exist. The Mac runner fails closed until real release identifiers/URLs/StoreKit values satisfy the product release validator.

Mac command:
```bash
./Scripts/run_phase_h_release_candidate_macos.sh /absolute/PhaseG/trace-directory
```

Acceptance: predecessor + hardening gates, real release configuration validation, Release build, tests, Analyze, Archive, and local code-signature verification. Xcode Organizer **Validate App** remains required before Phase H is marked complete.


## Archived-product evidence hardening
The release-candidate archive must pass `Scripts/validate_phase_h_release_evidence.sh`. Source configuration alone is insufficient. The archived Keptora bundle must retain the **Archive Review Studio** identity, a strict valid signature, App Sandbox, non-placeholder bundle/version metadata, and an embedded privacy manifest.
