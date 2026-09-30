#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
need=(
  Scripts/run_instruments_profile.sh
  Scripts/run_phase_g_profile_suite.sh
  Scripts/run_real_corpus_inventory.sh
  Scripts/validate_profiling_readiness.sh
  Docs/Profiling/real-corpus-manifest.example.json
  Docs/Profiling/README.md
)
for f in "${need[@]}"; do [[ -f "$f" ]] || { echo "missing $f" >&2; exit 20; }; done
bash -n Scripts/run_instruments_profile.sh
bash -n Scripts/run_phase_g_profile_suite.sh
bash -n Scripts/run_real_corpus_inventory.sh
bash ./Scripts/validate_profiling_readiness.sh >/dev/null
grep -Fq 'CFBundleExecutable' Scripts/run_instruments_profile.sh
grep -Fq -- '--env "CULLORA_REAL_CORPUS_PATH=$CORPUS"' Scripts/run_instruments_profile.sh
grep -Fq -- '--launch -- "$TARGET"' Scripts/run_instruments_profile.sh
grep -Fq 'xctrace export "$OUT" --toc' Scripts/run_instruments_profile.sh
grep -Fq 'Time Profiler' Scripts/run_phase_g_profile_suite.sh
grep -Fq 'Allocations' Scripts/run_phase_g_profile_suite.sh
grep -Fq 'Leaks' Scripts/run_phase_g_profile_suite.sh
printf 'PHASE_G_READINESS_PASS app=%s successor=%s
' 'Keptora' 'P6'
