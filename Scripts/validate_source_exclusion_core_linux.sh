#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only source exclusion smoke skipped."
  exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc \
  "$ROOT/Cullora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Cullora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Cullora/Core/Scanning/FolderEnumerator.swift" \
  "$ROOT/Scripts/source_exclusion_core_smoke.swift" \
  -o "$TMP/source-exclusion-smoke"
"$TMP/source-exclusion-smoke"
