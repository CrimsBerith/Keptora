#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only review session smoke skipped."
  exit 0
fi
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
swift build --package-path "$ROOT/Packages/KeptoraCore"
CORE_BIN="$(swift build --package-path "$ROOT/Packages/KeptoraCore" --show-bin-path)"
# Linux validates checkpoint models, not Apple localization. The real language
# behavior is checked by AppModelTests on macOS.
cat > "$OUT/LinuxLocalization.swift" <<'SWIFT'
import Foundation
extension String {
    init(localized value: String) { self = value }
}
SWIFT
swiftc \
  -I "$CORE_BIN/Modules" \
  "$CORE_BIN"/KeptoraCore.build/*.swift.o \
  "$OUT/LinuxLocalization.swift" \
  "$ROOT/Keptora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Keptora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Keptora/Core/Models/FamilyModels.swift" \
  "$ROOT/Keptora/Core/Models/ReviewModels.swift" \
  "$ROOT/Scripts/review_session_checkpoint_smoke.swift" \
  -o "$OUT/review-session-smoke"
"$OUT/review-session-smoke"
