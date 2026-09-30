#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
EVIDENCE_ROOT="${1:-$ROOT/ValidationArtifacts/PhaseI/FinalQA}"
H_EVIDENCE="${2:-$ROOT/ValidationArtifacts/ReleaseCandidate/Evidence/phase_h_archive_evidence.txt}"
[[ -s "$H_EVIDENCE" ]] || { echo "Phase H evidence missing" >&2; exit 90; }
grep -Fq 'RESULT=PASS' "$H_EVIDENCE" || { echo "Phase H evidence not PASS" >&2; exit 91; }
mkdir -p "$EVIDENCE_ROOT"
write_pending() { local f="$1" label="$2"; if [[ ! -e "$EVIDENCE_ROOT/$f" ]]; then printf 'CHECK=%s\nRESULT=PENDING\nEVIDENCE=\n' "$label" > "$EVIDENCE_ROOT/$f"; fi; }
write_pending organizer_validate_app.txt 'Organizer Validate App'
write_pending testflight_clean_install.txt 'TestFlight clean install + first launch'
write_pending testflight_upgrade_migration.txt 'TestFlight upgrade + persisted-state migration'
write_pending storekit_purchase_restore_edges.txt 'StoreKit purchase restore cancel failure offline edges'
write_pending accessibility_full_pass.txt 'VoiceOver keyboard focus Full Keyboard Access Reduce Motion contrast'
write_pending window_matrix_identity.txt 'Archive Review Studio compact standard expansive window identity'
write_pending file_bookmark_disconnect_recovery.txt 'Security-scoped bookmark disconnect reconnect stale permission recovery'
write_pending real_corpus_profile_review.txt 'Real corpus Time Profiler Allocations Leaks review'
write_pending offline_relaunch_recovery.txt 'Offline cold relaunch crash-safe recovery and cancellation resume'
write_pending privacy_manifest_entitlements.txt 'Archived privacy manifest entitlements sandbox declaration review'
write_pending metadata_urls_review_notes.txt 'Metadata privacy support URLs review notes export declaration'
write_pending screenshots_final_inventory.txt 'Final App Store screenshot inventory with no private data'
printf 'APP=Keptora\nSHELL_IDENTITY=Archive Review Studio\nPHASE=I\nPHASE_H_EVIDENCE=%s\n' "$H_EVIDENCE" > "$EVIDENCE_ROOT/context.txt"
( cd "$EVIDENCE_ROOT" && shasum -a 256 *.txt > evidence_preflight.sha256 )
echo 'PHASE_I_FINAL_QA_BUNDLE_PREPARED app=Keptora'
