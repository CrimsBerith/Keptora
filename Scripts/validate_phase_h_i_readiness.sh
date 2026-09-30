#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
need=(
  "Scripts/run_phase_h_release_candidate_macos.sh"
  "Scripts/validate_phase_g_readiness.sh"
  "Scripts/validate_phase5s_release_config.py"
  "Keptora.xcodeproj"
  "Keptora.xcodeproj/xcshareddata/xcschemes/Keptora.xcscheme"
  "Docs/PhaseGHI/PHASE_G_REAL_CORPUS_INSTRUMENTS.md"
  "AppStore/APP_STORE_METADATA.md"
  "AppStore/APP_REVIEW_NOTES.md"
  "AppStore/SCREENSHOT_CAPTURE_PLAN.md"
  "Docs/PhaseGHI/PHASE_H_RELEASE_CANDIDATE.md"
  "Docs/PhaseGHI/PHASE_I_APP_STORE_FINAL_QA.md"
  "AppStore/PHASE_I_FINAL_QA_CHECKLIST.md"
)
for f in "${need[@]}"; do [[ -e "$f" ]] || { echo "missing $f" >&2; exit 50; }; done
bash -n Scripts/run_phase_h_release_candidate_macos.sh
bash -n Scripts/validate_phase_g_readiness.sh
grep -Fq 'xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "$DEST" clean build' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq ' test' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq ' analyze' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq ' archive -archivePath "$ARCHIVE_PATH"' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq 'codesign --verify --deep --strict' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq 'Time Profiler' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq 'Allocations' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq 'Leaks' Scripts/run_phase_h_release_candidate_macos.sh
grep -Fq "Archive Review Studio" Docs/PhaseGHI/PHASE_H_RELEASE_CANDIDATE.md
grep -Fq "Archive Review Studio" Docs/PhaseGHI/PHASE_I_APP_STORE_FINAL_QA.md

# Strict Phase H/I evidence-closure source contract
for f in Scripts/validate_phase_h_release_evidence.sh Scripts/prepare_phase_i_evidence_bundle.sh Scripts/validate_phase_i_submission_evidence.sh Docs/PhaseGHI/PHASE_H_I_EVIDENCE_PROTOCOL.md; do
  [[ -e "$f" ]] || { echo "missing $f" >&2; exit 51; }
done
bash -n Scripts/validate_phase_h_release_evidence.sh
bash -n Scripts/prepare_phase_i_evidence_bundle.sh
bash -n Scripts/validate_phase_i_submission_evidence.sh
grep -Fq 'CODESIGN_STRICT=PASS' Scripts/validate_phase_h_release_evidence.sh
grep -Fq 'APP_SANDBOX=PASS' Scripts/validate_phase_h_release_evidence.sh
grep -Fq 'PrivacyInfo.xcprivacy' Scripts/validate_phase_h_release_evidence.sh
grep -Fq 'validate_app.txt' Scripts/validate_phase_i_submission_evidence.sh
grep -Fq 'testflight_install_launch.txt' Scripts/validate_phase_i_submission_evidence.sh
grep -Fq 'Archive Review Studio' Docs/PhaseGHI/PHASE_H_I_EVIDENCE_PROTOCOL.md
printf 'PHASE_H_I_READINESS_PASS app=%s
' "Keptora"
# Phase I final closure source hardening
for f in Scripts/validate_phase_i_source_qa.py Scripts/prepare_phase_i_final_qa_bundle.sh Scripts/validate_phase_i_final_submission.sh Docs/PhaseGHI/PHASE_I_FINAL_CLOSURE_PROTOCOL.md AppStore/PHASE_I_SUBMISSION_EVIDENCE_MATRIX.md; do
  [[ -e "$f" ]] || { echo "missing $f" >&2; exit 52; }
done
python3 Scripts/validate_phase_i_source_qa.py
bash -n Scripts/prepare_phase_i_final_qa_bundle.sh
bash -n Scripts/validate_phase_i_final_submission.sh
grep -Fq 'Archive Review Studio' Docs/PhaseGHI/PHASE_I_FINAL_CLOSURE_PROTOCOL.md
grep -Fq 'testflight_upgrade_migration.txt' Scripts/validate_phase_i_final_submission.sh
grep -Fq 'offline_relaunch_recovery.txt' Scripts/validate_phase_i_final_submission.sh

