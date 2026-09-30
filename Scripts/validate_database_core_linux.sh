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
  "$ROOT/Keptora/Core/Models/AssetDescriptor.swift" \
  "$ROOT/Keptora/Core/Models/FamilyModels.swift" \
  "$ROOT/Keptora/Core/Storage/VolumeIdentity.swift" \
  "$ROOT/Keptora/Core/Models/CleanupModels.swift" \
  "$ROOT/Keptora/Core/Models/RecoveryModels.swift" \
  "$ROOT/Keptora/Core/Models/ReviewModels.swift" \
  "$ROOT/Keptora/Core/Models/ScanModels.swift" \
  "$ROOT/Keptora/Core/Models/SimilarityModels.swift" \
  "$ROOT/Keptora/Core/Similarity/PerceptualCandidateIndex.swift" \
  "$ROOT/Scripts/ExactFingerprintLinuxStub.swift" \
  "$ROOT/Keptora/Core/Persistence/SQLiteDatabase.swift" \
  "$ROOT/Scripts/database_core_smoke.swift" \
  -lsqlite3 -o "$TMP/database-smoke"
"$TMP/database-smoke"
