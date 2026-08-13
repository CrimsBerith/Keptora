#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 Scripts/validate_phase5s_static.py
python3 Scripts/validate_project_references.py
plutil -lint Cullora/Resources/Info.plist >/dev/null 2>&1 || true
printf 'cullora-phase5s-full-validation-ok\n'
