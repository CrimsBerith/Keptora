#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/apply_phase_n_release_inputs.py
if [ -f AppStore/AppIcon/source-1024.png ]; then python3 Scripts/build_phase_n_appicon.py; fi
python3 Scripts/validate_phase_n_pre_mac.py
echo "PASS: Phase N local developer inputs prepared; continue with existing Mac closure runbook."
