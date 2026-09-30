#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TRACE_DIR="${1:?Phase G trace directory required}"
ARCHIVE_PATH="${2:-$ROOT/ValidationArtifacts/ReleaseCandidate/Keptora.xcarchive}"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Phase H requires macOS/Xcode" >&2; exit 40; }
command -v xcodebuild >/dev/null || { echo "xcodebuild missing" >&2; exit 41; }
command -v codesign >/dev/null || { echo "codesign missing" >&2; exit 42; }
[[ -d "$TRACE_DIR" ]] || { echo "Phase G trace directory missing" >&2; exit 43; }

require_trace() {
  local label="$1" pattern="$2" trace toc
  trace="$(find "$TRACE_DIR" -type d -name "$pattern" -print -quit)"
  [[ -n "$trace" ]] || { echo "missing Phase G trace: $label" >&2; exit 44; }
  toc="${trace%.trace}.toc.xml"
  [[ -s "$toc" ]] || { echo "missing Phase G TOC: $toc" >&2; exit 45; }
}
require_trace "Time Profiler" '*Time_Profiler*.trace'
require_trace "Allocations" '*Allocations*.trace'
require_trace "Leaks" '*Leaks*.trace'

bash Scripts/validate_phase_g_readiness.sh
if [[ -f Scripts/validate_final_hardening_wave.sh ]]; then bash Scripts/validate_final_hardening_wave.sh; fi
if [[ -f Scripts/validate_runtime_release_hardening.sh ]]; then bash Scripts/validate_runtime_release_hardening.sh; fi
bash -lc "python3 Scripts/validate_phase5s_static.py"
python3 Scripts/validate_phase5s_release_config.py

mkdir -p "$(dirname "$ARCHIVE_PATH")"
rm -rf "$ARCHIVE_PATH"
PROJECT="Keptora.xcodeproj"
SCHEME="Keptora"
DEST='platform=macOS'
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "$DEST" clean build
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -destination "$DEST" test
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "$DEST" analyze
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release archive -archivePath "$ARCHIVE_PATH"
APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name '*.app' -print -quit)"
[[ -n "$APP_PATH" ]] || { echo "archived app missing" >&2; exit 46; }
codesign --verify --deep --strict "$APP_PATH"
mkdir -p "$ROOT/ValidationArtifacts/ReleaseCandidate"
{
  echo "app=Keptora"
  echo "scheme=$SCHEME"
  echo "archive=$ARCHIVE_PATH"
  echo "app_path=$APP_PATH"
  echo "phase_g_trace_dir=$TRACE_DIR"
  echo "status=ARCHIVE_LOCAL_SIGNATURE_PASS_VALIDATE_APP_PENDING"
} > "$ROOT/ValidationArtifacts/ReleaseCandidate/phase_h_receipt.txt"
echo "PHASE_H_LOCAL_ARCHIVE_PASS app=Keptora archive=$ARCHIVE_PATH"
