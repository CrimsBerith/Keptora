#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux-only SQLite core smoke skipped."
  exit 0
fi
if [[ ! -f /usr/include/sqlite3.h ]]; then
  echo "sqlite3 development header is unavailable; Linux database smoke skipped." >&2
  exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/module.modulemap" <<'EOF'
module SQLite3 [system] {
  header "/usr/include/sqlite3.h"
  link "sqlite3"
  export *
}
EOF
swiftc -I "$TMP" \
  "$ROOT/Cullora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Cullora/Core/Models/FamilyModels.swift" \
  "$ROOT/Cullora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Cullora/Core/Models/CleanupModels.swift" \
  "$ROOT/Cullora/Core/Models/RecoveryModels.swift" \
  "$ROOT/Cullora/Core/Models/ReviewModels.swift" \
  "$ROOT/Cullora/Core/Models/ScanModels.swift" \
  "$ROOT/Cullora/Core/Models/SimilarityModels.swift" \
  "$ROOT/Cullora/Core/Similarity/PerceptualCandidateIndex.swift" \
  "$ROOT/Scripts/ExactFingerprintLinuxStub.swift" \
  "$ROOT/Cullora/Core/Persistence/SQLiteDatabase.swift" \
  "$ROOT/Scripts/database_core_smoke.swift" \
  -lsqlite3 -o "$TMP/database-smoke"
"$TMP/database-smoke"
