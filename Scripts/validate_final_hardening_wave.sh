#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -parse "$ROOT/Cullora/Core/CulloraLifecycleCoordinator.swift" "$ROOT/Cullora/Core/CulloraWindowStressContract.swift"
swiftc -O "$ROOT/Cullora/Core/CulloraLifecycleCoordinator.swift" "$ROOT/Cullora/Core/CulloraWindowStressContract.swift" "$ROOT/Scripts/final_hardening_fixture.swift" -o "$TMP/final_hardening"
"$TMP/final_hardening"
grep -Eq 'SWIFT_STRICT_CONCURRENCY[[:space:]]*=[[:space:]]*complete' "$ROOT/Cullora.xcodeproj/project.pbxproj"
echo "FINAL_HARDENING_GATE_PASS Cullora"
