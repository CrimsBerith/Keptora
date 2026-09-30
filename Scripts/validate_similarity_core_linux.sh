#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only similarity core smoke skipped."
  exit 0
fi
if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc unavailable; similarity core smoke skipped."
  exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc \
  "$ROOT/Keptora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Keptora/Core/Models/FamilyModels.swift" \
  "$ROOT/Keptora/Core/Models/ReviewModels.swift" \
  "$ROOT/Keptora/Core/Models/SimilarityModels.swift" \
  "$ROOT/Keptora/Core/Similarity/PerceptualCandidateIndex.swift" \
  "$ROOT/Keptora/Core/Similarity/SimilarityCalibrator.swift" \
  "$ROOT/Scripts/VolumeIdentityLinuxStub.swift" \
  "$ROOT/Scripts/similarity_core_smoke.swift" \
  -o "$TMP/similarity_core_smoke"
"$TMP/similarity_core_smoke"
