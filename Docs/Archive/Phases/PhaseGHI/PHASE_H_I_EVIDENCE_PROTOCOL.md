# Phase H–I Evidence Protocol — Keptora

## Product identity lock
- Shell: **Archive Review Studio**.
- Release fixes must preserve this product-specific silhouette, navigation rhythm, focus order and terminology.
- Do not replace it with a portfolio-generic sidebar, dashboard, card grid, onboarding, paywall or inspector shell.

## Phase H archive evidence
After the existing Phase H macOS runner creates the local archive, run `Scripts/validate_phase_h_release_evidence.sh`. The gate verifies the archived app rather than source assumptions: real bundle/version values, strict code signature, App Sandbox entitlement and embedded privacy manifest. It writes `ValidationArtifacts/ReleaseCandidate/Evidence/phase_h_archive_evidence.txt` and captures signature/entitlement evidence.

## Phase I evidence bundle
Run `Scripts/prepare_phase_i_evidence_bundle.sh` only after Phase H archive evidence is PASS. It creates eight fail-closed evidence records. Each record must be changed to `RESULT=PASS` and include a concrete `EVIDENCE=` reference produced during the real Mac/TestFlight/App Store QA run.

## Final submission evidence gate
`Scripts/validate_phase_i_submission_evidence.sh` refuses completion if any required record is missing, pending, or lacks an evidence reference. A PASS means the local evidence set is complete; it does not override App Store Review.
