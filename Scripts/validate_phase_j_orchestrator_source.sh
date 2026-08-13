#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
need=(
  Scripts/run_phase_j_mac_closure_orchestrator.sh
  Scripts/run_phase_g_profile_suite.sh
  Scripts/run_phase_h_release_candidate_macos.sh
  Scripts/validate_phase_h_release_evidence.sh
  Scripts/prepare_phase_i_evidence_bundle.sh
  Scripts/prepare_phase_i_final_qa_bundle.sh
  Scripts/validate_phase_i_submission_evidence.sh
  Scripts/validate_phase_i_final_submission.sh
  Docs/PhaseGHI/PHASE_J_MAC_CLOSURE_ORCHESTRATOR.md
)
for f in "${need[@]}"; do [[ -e "$f" ]] || { echo "missing $f" >&2; exit 130; }; done
bash -n Scripts/run_phase_j_mac_closure_orchestrator.sh
grep -Fq 'PHASE_J_TSAN_MODE' Scripts/run_phase_j_mac_closure_orchestrator.sh
grep -Fq 'run_phase_g_profile_suite.sh' Scripts/run_phase_j_mac_closure_orchestrator.sh
grep -Fq 'run_phase_h_release_candidate_macos.sh' Scripts/run_phase_j_mac_closure_orchestrator.sh
grep -Fq 'validate_phase_h_release_evidence.sh' Scripts/run_phase_j_mac_closure_orchestrator.sh
grep -Fq 'prepare_phase_i_final_qa_bundle.sh' Scripts/run_phase_j_mac_closure_orchestrator.sh
grep -Fq 'validate_phase_i_final_submission.sh' Scripts/run_phase_j_mac_closure_orchestrator.sh
grep -Fq 'Archive Review Studio' Docs/PhaseGHI/PHASE_J_MAC_CLOSURE_ORCHESTRATOR.md
grep -Fq 'does not auto-pass manual App Store evidence' Docs/PhaseGHI/PHASE_J_MAC_CLOSURE_ORCHESTRATOR.md
printf 'PHASE_J_SOURCE_GATE_PASS app=%s
' 'Cullora'
