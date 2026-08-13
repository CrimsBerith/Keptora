#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/ValidationArtifacts/vision_similarity_mac.json"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Apple Vision benchmark requires macOS; skipped on $(uname -s)."
  exit 0
fi
xcrun swift "$ROOT/Scripts/vision_similarity_benchmark.swift" | tee "$OUT"
echo "Wrote $OUT"
