#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFTC="swiftc"
if [[ "$(uname -s)" == "Darwin" ]]; then
  SWIFTC="xcrun swiftc"
fi

plutil -lint "$ROOT/Keptora.xcodeproj/project.pbxproj"
plutil -lint "$ROOT/Keptora/Resources/Info.plist"
plutil -lint "$ROOT/Keptora/Resources/Keptora.entitlements"
plutil -lint "$ROOT/Keptora/Resources/PrivacyInfo.xcprivacy"
plutil -lint "$ROOT/KeptoraiOS/Resources/Info.plist"
plutil -lint "$ROOT/KeptoraiOS/Resources/KeptoraiOS.entitlements"
for LANG in en tr de fr; do
  plutil -lint "$ROOT/KeptoraiOS/Resources/$LANG.lproj/InfoPlist.strings"
done

python3 - <<PY
import json
from pathlib import Path
root = Path(r"$ROOT")
for path in [
    root / "Keptora/Resources/Localizable.xcstrings",
    root / "Keptora/Resources/Keptora.storekit",
    root / "Keptora/Resources/Assets.xcassets/Contents.json",
    root / "Keptora/Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
    root / "Keptora/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
]:
    json.loads(path.read_text())
print("JSON resources parsed.")
PY

PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/keptora-python-cache" python3 -m py_compile \
  "$ROOT/CorpusTools/generate_corpus.py" \
  "$ROOT/CorpusTools/benchmark_exact.py" \
  "$ROOT/CorpusTools/benchmark_incremental_quarantine.py" \
  "$ROOT/CorpusTools/benchmark_family_recovery.py" \
  "$ROOT/CorpusTools/benchmark_similarity_100k.py" \
  "$ROOT/Scripts/validate_project_references.py" \
  "$ROOT/Scripts/validate_phase5o_static.py" \
  "$ROOT/Scripts/validate_phase5p_static.py" \
  "$ROOT/Scripts/validate_phase5q_static.py" \
  "$ROOT/Scripts/validate_phase5r_static.py" \
  "$ROOT/Scripts/validate_phase5s_static.py" \
  "$ROOT/Scripts/validate_phase5s_release_config.py" \
  "$ROOT/Scripts/add_phase5o_files_to_project.py"

SWIFT_FILES=()
while IFS= read -r file; do
  SWIFT_FILES+=("$file")
done < <(find "$ROOT/Keptora" "$ROOT/KeptoraTests" "$ROOT/KeptoraiOS" "$ROOT/KeptoraiOSTests" -name '*.swift' -type f | sort)
$SWIFTC -frontend -parse "${SWIFT_FILES[@]}" >/dev/null

python3 "$ROOT/Scripts/validate_project_references.py"
python3 "$ROOT/Scripts/validate_phase5s_static.py"
python3 "$ROOT/Scripts/validate_universal_release.py" --allow-owner-placeholders
python3 "$ROOT/CorpusTools/benchmark_incremental_quarantine.py" --count 100 --out /tmp/keptora-phase5h-validation.json >/dev/null
python3 "$ROOT/CorpusTools/benchmark_family_recovery.py" --project-root "$ROOT" --out /tmp/keptora-phase5h-family-recovery.json >/dev/null
if [[ "$(uname -s)" == "Linux" ]]; then
  "$ROOT/Scripts/validate_database_core_linux.sh"
  "$ROOT/Scripts/validate_family_graph_linux.sh"
  if [[ "${CULLORA_FULL_LINUX_SMOKE:-0}" == "1" ]]; then
    "$ROOT/Scripts/validate_phase5h_core_linux.sh"
  else
    echo "Heavy Phase 5H coordinator smoke skipped (set CULLORA_FULL_LINUX_SMOKE=1 to run)."
  fi
  "$ROOT/Scripts/validate_similarity_core_linux.sh"
  "$ROOT/Scripts/validate_review_session_core_linux.sh"
  "$ROOT/Scripts/validate_source_exclusion_core_linux.sh"
  "$ROOT/Scripts/validate_restore_preview_core_linux.sh"
else
  echo "macOS: Linux-only core smoke scripts skipped; use the Xcode macOS build/test gate."
fi
python3 "$ROOT/CorpusTools/benchmark_similarity_100k.py" --size 10000 --output /tmp/keptora-phase5i-similarity-smoke.json >/dev/null
python3 - <<PY
import json
from pathlib import Path
result = json.loads((Path(r"$ROOT") / "ValidationArtifacts/similarity_100k.json").read_text())
assert result["catalogSize"] == 100000
assert result["plantedRecall"] >= 0.99
assert result["candidatePairs"] < result["naivePairs"]
print("Stored 100K similarity benchmark verified.")
PY

echo "Universal Phase Q package structure, Mac/iPhone syntax, privacy, exact-decision provenance, reversible cleanup, Photos/Files separation, StoreKit/localization consistency, SQLite, similarity review boundaries, and stored benchmarks passed."
