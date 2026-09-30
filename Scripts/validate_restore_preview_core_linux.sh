#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only restore preview smoke skipped."
  exit 0
fi
if [[ ! -f /usr/include/sqlite3.h ]]; then
  echo "sqlite3 development header unavailable; restore preview smoke skipped." >&2
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
  "$ROOT/Keptora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Keptora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Keptora/Core/Models/FamilyModels.swift" \
  "$ROOT/Keptora/Core/Models/CleanupModels.swift" \
  "$ROOT/Keptora/Core/Models/RecoveryModels.swift" \
  "$ROOT/Keptora/Core/Models/ReviewModels.swift" \
  "$ROOT/Keptora/Core/Models/ScanModels.swift" \
  "$ROOT/Keptora/Core/Models/SimilarityModels.swift" \
  "$ROOT/Keptora/Core/Similarity/PerceptualCandidateIndex.swift" \
  "$ROOT/Scripts/CoreLinuxHasherStub.swift" \
  "$ROOT/Scripts/ManifestSignerLinuxStub.swift" \
  "$ROOT/Scripts/CoordinatedFileMoverLinuxStub.swift" \
  "$ROOT/Keptora/Core/Families/AssetFamilyGraphBuilder.swift" \
  "$ROOT/Keptora/Core/Persistence/SQLiteDatabase.swift" \
  "$ROOT/Keptora/Core/Cleanup/QuarantineCoordinator.swift" \
  "$ROOT/Scripts/restore_preview_core_smoke.swift" \
  -lsqlite3 -o "$TMP/restore-preview-smoke"
"$TMP/restore-preview-smoke"
