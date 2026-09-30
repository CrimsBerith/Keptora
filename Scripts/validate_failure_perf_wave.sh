#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Keptora/Core/KeptoraResiliencePerformanceController.swift"
PROJ="$ROOT/Keptora.xcodeproj/project.pbxproj"
FIX="$ROOT/Scripts/failure_perf_fixture.swift"
TMP="${TMPDIR:-/tmp}/Cullora-failure-perf-$$"
trap 'rm -f "$TMP"' EXIT
grep -Fq -- 'KeptoraResiliencePerformanceController.swift in Sources' "$PROJ"
swiftc -parse "$SRC"
swiftc "$SRC" "$FIX" -o "$TMP"
"$TMP"
echo FAILURE_PERF_WAVE_PASS
