#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -parse "$ROOT/Keptora/Core/KeptoraLifecycleCoordinator.swift" "$ROOT/Keptora/Core/KeptoraWindowStressContract.swift"
swiftc -O "$ROOT/Keptora/Core/KeptoraLifecycleCoordinator.swift" "$ROOT/Keptora/Core/KeptoraWindowStressContract.swift" "$ROOT/Scripts/final_hardening_fixture.swift" -o "$TMP/final_hardening"
"$TMP/final_hardening"
grep -Eq 'SWIFT_STRICT_CONCURRENCY[[:space:]]*=[[:space:]]*complete' "$ROOT/Keptora.xcodeproj/project.pbxproj"
echo "FINAL_HARDENING_GATE_PASS Cullora"
