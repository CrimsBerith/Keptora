#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Keptora/Core/KeptoraRecoveryJournal.swift"
PROJ="$ROOT/Keptora.xcodeproj/project.pbxproj"
FIX="$ROOT/Scripts/recovery_stress_fixture.swift"
TMP="${TMPDIR:-/tmp}/Keptora-recovery-wave-$$"
trap 'rm -f "$TMP"' EXIT
grep -Fq 'KeptoraRecoveryJournal.swift in Sources' "$PROJ"
swiftc -parse "$SRC"
swiftc "$SRC" "$FIX" -o "$TMP"
"$TMP"
echo RECOVERY_WAVE_PASS
