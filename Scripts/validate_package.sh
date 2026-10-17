#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PYTHON="${PYTHON:-python3}"
# Only current photo-cleaner sources belong to the release gate.
"$PYTHON" - <<'PY'
import json, plistlib
from pathlib import Path
root = Path.cwd()
for folder in (root / "Keptora/Resources", root / "KeptoraiOS/Resources"):
    for pattern in ("*.plist", "*.entitlements", "*.xcprivacy"):
        for path in folder.glob(pattern):
            plistlib.loads(path.read_bytes())
for path in (root / "Keptora/Resources").rglob("Contents.json"):
    json.loads(path.read_text())
for name in ("Localizable.xcstrings", "Keptora.storekit"):
    json.loads((root / "Keptora/Resources" / name).read_text())
print("Shipping plist and JSON resources parsed.")
PY
if [[ "$(uname -s)" == Darwin ]]; then
  plutil -lint Keptora.xcodeproj/project.pbxproj
  for lang in en tr de fr; do
    plutil -lint "KeptoraiOS/Resources/$lang.lproj/InfoPlist.strings"
  done
fi
for validator in validate_project_references validate_photo_cleaner_assets \
  validate_regenerated_visuals validate_mac_localization \
  validate_app_store_metadata validate_universal_release; do
  "$PYTHON" "Scripts/$validator.py"
done
swift test --package-path Packages/KeptoraCore
echo 'Current package validation passed. Native UI, signed archives and device acceptance are separate gates.'
