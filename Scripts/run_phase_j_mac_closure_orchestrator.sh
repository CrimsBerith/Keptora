#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-status}"
PROJECT="Cullora.xcodeproj"
SCHEME="Cullora"
APP_NAME="Cullora"
SHELL_IDENTITY="Archive Review Studio"
DEST='platform=macOS'
JROOT="$ROOT/ValidationArtifacts/PhaseJ"
DERIVED="$JROOT/DerivedData"
TRACE_DIR="$ROOT/ValidationArtifacts/Profiling/PhaseG"
ARCHIVE_EVIDENCE="$ROOT/ValidationArtifacts/ReleaseCandidate/Evidence/phase_h_archive_evidence.txt"
FINAL_QA="$ROOT/ValidationArtifacts/PhaseI/FinalQA"
mkdir -p "$JROOT"

require_mac() {
  [[ "$(uname -s)" == "Darwin" ]] || { echo 'Phase J requires macOS/Xcode' >&2; exit 120; }
  for tool in xcodebuild xcrun codesign shasum; do command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 121; }; done
}

write_status() {
  local state="$1"
  {
    echo "APP=$APP_NAME"
    echo "SHELL_IDENTITY=$SHELL_IDENTITY"
    echo "PHASE=J"
    echo "STATE=$state"
    echo "UPDATED_AT_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$JROOT/phase_j_status.txt"
}

case "$MODE" in
  prepare)
    require_mac
    CORPUS="${2:?usage: $0 prepare /absolute/path/to/real-corpus}"
    [[ -d "$CORPUS" ]] || { echo "real corpus directory missing: $CORPUS" >&2; exit 122; }
    bash Scripts/validate_phase_g_readiness.sh
    bash Scripts/validate_phase_h_i_readiness.sh
    python3 Scripts/validate_phase_i_source_qa.py
    rm -rf "$DERIVED"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "$DEST" -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO clean build
    PROFILE_APP="$(find "$DERIVED/Build/Products" -type d -path '*Release*' -name '*.app' -print -quit)"
    [[ -n "$PROFILE_APP" ]] || { echo 'profiling build app not found' >&2; exit 123; }
    rm -rf "$TRACE_DIR"
    bash Scripts/run_phase_g_profile_suite.sh "$CORPUS" "$PROFILE_APP" "$TRACE_DIR"
    TSAN_MODE="${PHASE_J_TSAN_MODE:-required}"
    set +e
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -destination "$DEST" -derivedDataPath "$DERIVED" -enableThreadSanitizer YES test >"$JROOT/thread_sanitizer.log" 2>&1
    TSAN_RC=$?
    set -e
    if [[ $TSAN_RC -ne 0 && "$TSAN_MODE" == 'required' ]]; then
      echo 'Thread Sanitizer run failed; inspect ValidationArtifacts/PhaseJ/thread_sanitizer.log' >&2
      exit 124
    fi
    printf 'MODE=%s
RESULT=%s
EVIDENCE=%s
' "$TSAN_MODE" "$([[ $TSAN_RC -eq 0 ]] && echo PASS || echo REVIEW_REQUIRED)" "$JROOT/thread_sanitizer.log" > "$JROOT/thread_sanitizer_receipt.txt"
    bash Scripts/run_phase_h_release_candidate_macos.sh "$TRACE_DIR"
    bash Scripts/validate_phase_h_release_evidence.sh
    bash Scripts/prepare_phase_i_evidence_bundle.sh
    bash Scripts/prepare_phase_i_final_qa_bundle.sh
    write_status 'AUTOMATED_G_H_COMPLETE_MANUAL_I_EVIDENCE_PENDING'
    echo "PHASE_J_PREPARE_PASS app=$APP_NAME"
    ;;
  finalize)
    require_mac
    [[ -s "$ARCHIVE_EVIDENCE" ]] || { echo 'Phase H archive evidence missing' >&2; exit 125; }
    bash Scripts/validate_phase_i_submission_evidence.sh
    bash Scripts/validate_phase_i_final_submission.sh
    write_status 'LOCAL_G_H_I_EVIDENCE_COMPLETE_READY_FOR_APP_STORE_CONNECT_REVIEW'
    echo "PHASE_J_FINALIZE_PASS app=$APP_NAME"
    ;;
  status)
    if [[ -s "$JROOT/phase_j_status.txt" ]]; then cat "$JROOT/phase_j_status.txt"; else
      printf 'APP=%s
SHELL_IDENTITY=%s
PHASE=J
STATE=NOT_RUN
' "$APP_NAME" "$SHELL_IDENTITY"
    fi
    ;;
  *)
    echo "usage: $0 {prepare /path/to/real-corpus|finalize|status}" >&2
    exit 126
    ;;
esac
