#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
EVIDENCE_ROOT="${1:-$ROOT/ValidationArtifacts/PhaseI}"
H_EVIDENCE="${2:-$ROOT/ValidationArtifacts/ReleaseCandidate/Evidence}"
[[ -s "$H_EVIDENCE/phase_h_archive_evidence.txt" ]] || { echo "Phase H archive evidence missing" >&2; exit 72; }
grep -Fq 'RESULT=PASS' "$H_EVIDENCE/phase_h_archive_evidence.txt" || { echo "Phase H archive evidence not PASS" >&2; exit 73; }
mkdir -p "$EVIDENCE_ROOT"
write_pending() { local f="$1" label="$2"; if [[ ! -e "$EVIDENCE_ROOT/$f" ]]; then printf 'CHECK=%s
RESULT=PENDING
EVIDENCE=
' "$label" > "$EVIDENCE_ROOT/$f"; fi; }
write_pending validate_app.txt 'Xcode Organizer Validate App'
write_pending testflight_install_launch.txt 'TestFlight install and cold/warm launch'
write_pending storekit_sandbox.txt 'StoreKit sandbox purchase/restore/cancel/failure'
write_pending voiceover_keyboard_reduce_motion.txt 'VoiceOver keyboard focus Reduce Motion'
write_pending sandbox_external_resource_recovery.txt 'Sandbox bookmark external resource disconnect/reconnect recovery'
write_pending real_corpus_instruments.txt 'Real corpus Time Profiler Allocations Leaks review'
write_pending ui_identity_screenshots.txt 'Archive Review Studio compact standard expansive screenshot identity'
write_pending privacy_metadata_review.txt 'Privacy metadata support URL review notes and declarations'
printf 'APP=Cullora
SHELL_IDENTITY=Archive Review Studio
PHASE_H_EVIDENCE=%s
' "$H_EVIDENCE/phase_h_archive_evidence.txt" > "$EVIDENCE_ROOT/phase_i_context.txt"
echo "PHASE_I_EVIDENCE_BUNDLE_PREPARED app=Cullora dir=$EVIDENCE_ROOT"
