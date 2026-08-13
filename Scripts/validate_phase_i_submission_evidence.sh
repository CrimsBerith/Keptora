#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
EVIDENCE_ROOT="${1:-$ROOT/ValidationArtifacts/PhaseI}"
H_EVIDENCE="${2:-$ROOT/ValidationArtifacts/ReleaseCandidate/Evidence/phase_h_archive_evidence.txt}"
[[ -s "$H_EVIDENCE" ]] || { echo "missing Phase H evidence" >&2; exit 80; }
grep -Fq 'RESULT=PASS' "$H_EVIDENCE" || { echo "Phase H evidence not PASS" >&2; exit 81; }
checks=(validate_app.txt testflight_install_launch.txt storekit_sandbox.txt voiceover_keyboard_reduce_motion.txt sandbox_external_resource_recovery.txt real_corpus_instruments.txt ui_identity_screenshots.txt privacy_metadata_review.txt)
for f in "${checks[@]}"; do
  p="$EVIDENCE_ROOT/$f"
  [[ -s "$p" ]] || { echo "missing Phase I evidence: $p" >&2; exit 82; }
  grep -Eq '^RESULT=PASS$' "$p" || { echo "Phase I evidence not PASS: $p" >&2; exit 83; }
  grep -Eq '^EVIDENCE=.+$' "$p" || { echo "Phase I evidence reference missing: $p" >&2; exit 84; }
done
printf 'APP=Cullora
SHELL_IDENTITY=Archive Review Studio
RESULT=PASS
STATUS=READY_FOR_APP_STORE_SUBMISSION_AFTER_REVIEW
' > "$EVIDENCE_ROOT/final_submission_gate_receipt.txt"
echo "PHASE_I_FINAL_SUBMISSION_EVIDENCE_PASS app=Cullora"
