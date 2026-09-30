#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then echo 'Linux-only Phase 5S core smoke skipped.'; exit 0; fi
if [[ ! -f /usr/include/sqlite3.h ]]; then echo 'sqlite3 development header unavailable; Phase 5S core smoke skipped.' >&2; exit 0; fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/module.modulemap" <<'MAP'
module SQLite3 [system] {
  header "/usr/include/sqlite3.h"
  link "sqlite3"
  export *
}
MAP
COMMON=(
  "$ROOT/Scripts/VolumeIdentityLinuxStub.swift"
  "$ROOT/Keptora/Core/Models/AssetDescriptor.swift"
  "$ROOT/Keptora/Core/Models/FamilyModels.swift"
  "$ROOT/Keptora/Core/Models/CleanupModels.swift"
  "$ROOT/Keptora/Core/Models/RecoveryModels.swift"
  "$ROOT/Keptora/Core/Models/ReviewModels.swift"
  "$ROOT/Keptora/Core/Models/ScanModels.swift"
  "$ROOT/Keptora/Core/Models/SimilarityModels.swift"
  "$ROOT/Keptora/Core/Similarity/PerceptualCandidateIndex.swift"
  "$ROOT/Scripts/CoreLinuxHasherStub.swift"
  "$ROOT/Scripts/ManifestSignerLinuxStub.swift"
  "$ROOT/Scripts/CoordinatedFileMoverLinuxStub.swift"
  "$ROOT/Keptora/Core/Families/AssetFamilyGraphBuilder.swift"
  "$ROOT/Keptora/Core/Persistence/SQLiteDatabase.swift"
  "$ROOT/Keptora/Core/Cleanup/QuarantineCoordinator.swift"
)
swiftc -I "$TMP" "${COMMON[@]}" "$ROOT/Scripts/phase5s_quarantine_verification_smoke.swift" -lsqlite3 -o "$TMP/p5s-smoke"
"$TMP/p5s-smoke"
