#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORPUS="${1:?external corpus directory required}"
APP="${2:?built .app bundle or executable path required}"
OUTDIR="${3:-$ROOT/ValidationArtifacts/Profiling/PhaseG}"
mkdir -p "$OUTDIR"
stamp="$(date +%Y%m%d-%H%M%S)"
for template in "Time Profiler" "Allocations" "Leaks"; do
  safe="$(printf '%s' "$template" | tr ' /' '__')"
  "$ROOT/Scripts/run_instruments_profile.sh" "$CORPUS" "$APP" "$template" "$OUTDIR/Cullora_${safe}_${stamp}.trace"
done
printf 'PHASE_G_TRACE_SUITE_COMPLETE app=%s output=%s
' 'Cullora' "$OUTDIR"
