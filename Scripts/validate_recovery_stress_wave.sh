#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Cullora/Core/CulloraRecoveryJournal.swift"
PROJ="$ROOT/Cullora.xcodeproj/project.pbxproj"
FIX="$ROOT/Scripts/recovery_stress_fixture.swift"
TMP="${TMPDIR:-/tmp}/Cullora-recovery-wave-$$"
trap 'rm -f "$TMP"' EXIT
grep -Fq 'CulloraRecoveryJournal.swift in Sources' "$PROJ"
swiftc -parse "$SRC"
swiftc "$SRC" "$FIX" -o "$TMP"
"$TMP"
echo RECOVERY_WAVE_PASS
