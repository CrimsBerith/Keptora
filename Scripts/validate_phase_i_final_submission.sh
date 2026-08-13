#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
EVIDENCE_ROOT="${1:-$ROOT/ValidationArtifacts/PhaseI/FinalQA}"
H_EVIDENCE="${2:-$ROOT/ValidationArtifacts/ReleaseCandidate/Evidence/phase_h_archive_evidence.txt}"
[[ -s "$H_EVIDENCE" ]] || { echo 'missing Phase H evidence' >&2; exit 100; }
grep -Fq 'RESULT=PASS' "$H_EVIDENCE" || { echo 'Phase H evidence not PASS' >&2; exit 101; }
python3 Scripts/validate_phase_i_source_qa.py
checks=(organizer_validate_app.txt testflight_clean_install.txt testflight_upgrade_migration.txt storekit_purchase_restore_edges.txt accessibility_full_pass.txt window_matrix_identity.txt file_bookmark_disconnect_recovery.txt real_corpus_profile_review.txt offline_relaunch_recovery.txt privacy_manifest_entitlements.txt metadata_urls_review_notes.txt screenshots_final_inventory.txt)
for f in "${checks[@]}"; do
  p="$EVIDENCE_ROOT/$f"
  [[ -s "$p" ]] || { echo "missing evidence: $p" >&2; exit 102; }
  grep -Eq '^RESULT=PASS$' "$p" || { echo "not PASS: $p" >&2; exit 103; }
  grep -Eq '^EVIDENCE=.+$' "$p" || { echo "missing evidence reference: $p" >&2; exit 104; }
  if grep -Eiq 'EVIDENCE=(TBD|TODO|PENDING|N/A|NONE|PLACEHOLDER)$' "$p"; then echo "invalid evidence reference: $p" >&2; exit 105; fi
done
# Preserve product identity explicitly in final screenshot evidence.
grep -Fq 'Archive Review Studio' "$EVIDENCE_ROOT/window_matrix_identity.txt" || { echo 'shell identity missing from window evidence' >&2; exit 106; }
{
 echo 'APP=Cullora'
 echo 'SHELL_IDENTITY=Archive Review Studio'
 echo 'PHASE=I'
 echo 'RESULT=PASS'
 echo 'STATUS=LOCAL_EVIDENCE_COMPLETE_READY_FOR_FINAL_APP_STORE_CONNECT_REVIEW'
} > "$EVIDENCE_ROOT/final_phase_i_receipt.txt"
( cd "$EVIDENCE_ROOT" && shasum -a 256 *.txt > final_phase_i_evidence.sha256 )
echo 'PHASE_I_FINAL_CLOSURE_PASS app=Cullora'
