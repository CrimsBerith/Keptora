#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/validate_phase_m_submission.py
