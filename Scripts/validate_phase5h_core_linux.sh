#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only Phase 5H coordinator smoke skipped."
  exit 0
fi
if [[ ! -f /usr/include/sqlite3.h ]]; then
  echo "sqlite3 development header unavailable; coordinator smoke skipped." >&2
  exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/module.modulemap" <<'MAP'
module SQLite3 [system] {
  header "/usr/include/sqlite3.h"
  link "sqlite3"
  export *
}
MAP
swiftc -I "$TMP" \
  "$ROOT/Cullora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Cullora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Cullora/Core/Models/FamilyModels.swift" \
  "$ROOT/Cullora/Core/Models/CleanupModels.swift" \
  "$ROOT/Cullora/Core/Models/RecoveryModels.swift" \
  "$ROOT/Cullora/Core/Models/ReviewModels.swift" \
  "$ROOT/Cullora/Core/Models/ScanModels.swift" \
  "$ROOT/Cullora/Core/Models/SimilarityModels.swift" \
  "$ROOT/Cullora/Core/Similarity/PerceptualCandidateIndex.swift" \
  "$ROOT/Scripts/CoreLinuxHasherStub.swift" \
  "$ROOT/Cullora/Core/Scanning/FolderEnumerator.swift" \
  "$ROOT/Cullora/Core/Families/AssetFamilyGraphBuilder.swift" \
  "$ROOT/Cullora/Core/Persistence/SQLiteDatabase.swift" \
  "$ROOT/Cullora/Core/Scanning/ScanCoordinator.swift" \
  "$ROOT/Cullora/Core/Cleanup/ReconciliationCoordinator.swift" \
  "$ROOT/Scripts/phase5h_core_smoke.swift" \
  -lsqlite3 -o "$TMP/phase5h-core-smoke"
"$TMP/phase5h-core-smoke"
