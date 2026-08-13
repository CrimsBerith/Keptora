#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORPUS="${1:?external corpus directory required}"
APP_INPUT="${2:?built .app bundle or executable path required}"
TEMPLATE="${3:-Time Profiler}"
SAFE_TEMPLATE="$(printf '%s' "$TEMPLATE" | tr ' /' '__' | tr -cd '[:alnum:]_.-')"
OUT="${4:-$ROOT/ValidationArtifacts/Profiling/Cullora_${SAFE_TEMPLATE}_$(date +%Y%m%d-%H%M%S).trace}"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Mac-only profiling gate" >&2; exit 4; }
command -v xcrun >/dev/null || { echo "xcrun missing" >&2; exit 5; }
[[ -d "$CORPUS" ]] || { echo "corpus path invalid" >&2; exit 6; }

if [[ -d "$APP_INPUT" && "$APP_INPUT" == *.app ]]; then
  INFO="$APP_INPUT/Contents/Info.plist"
  [[ -f "$INFO" ]] || { echo "app Info.plist missing" >&2; exit 7; }
  EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO" 2>/dev/null || true)"
  [[ -n "$EXECUTABLE" ]] || { echo "CFBundleExecutable missing" >&2; exit 8; }
  TARGET="$APP_INPUT/Contents/MacOS/$EXECUTABLE"
else
  TARGET="$APP_INPUT"
fi
[[ -x "$TARGET" ]] || { echo "profile target is not executable: $TARGET" >&2; exit 9; }

"$ROOT/Scripts/run_real_corpus_inventory.sh" "$CORPUS"
if ! xcrun xctrace list templates | grep -Fq "$TEMPLATE"; then
  echo "Instruments template unavailable: $TEMPLATE" >&2
  exit 10
fi
mkdir -p "$(dirname "$OUT")"
TOC="${OUT%.trace}.toc.xml"
echo "Recording $TEMPLATE for Cullora. Exercise the Archive Review Studio real-corpus workflow while the trace runs."
xcrun xctrace record --template "$TEMPLATE" --time-limit "${TRACE_LIMIT:-45s}" --output "$OUT" --env "CULLORA_REAL_CORPUS_PATH=$CORPUS" --launch -- "$TARGET"
xcrun xctrace export "$OUT" --toc --output "$TOC"
[[ -s "$TOC" ]] || { echo "trace TOC export missing" >&2; exit 11; }
echo "INSTRUMENTS_TRACE_CAPTURED app=Cullora template=$TEMPLATE output=$OUT toc=$TOC"
