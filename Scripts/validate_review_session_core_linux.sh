#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only review session smoke skipped."
  exit 0
fi
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
swiftc \
  "$ROOT/Keptora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Keptora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Keptora/Core/Models/FamilyModels.swift" \
  "$ROOT/Keptora/Core/Models/ReviewModels.swift" \
  "$ROOT/Scripts/review_session_checkpoint_smoke.swift" \
  -o "$OUT/review-session-smoke"
"$OUT/review-session-smoke"
