#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/validate_phase_n_pre_mac.py
