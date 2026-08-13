#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only family graph smoke skipped."
  exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc \
  "$ROOT/Cullora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Cullora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Cullora/Core/Models/FamilyModels.swift" \
  "$ROOT/Cullora/Core/Families/AssetFamilyGraphBuilder.swift" \
  "$ROOT/Scripts/family_graph_smoke.swift" \
  -o "$TMP/family-smoke"
"$TMP/family-smoke"
