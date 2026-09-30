#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTRL="$ROOT/Keptora/Core/KeptoraResiliencePerformanceController.swift"
grep -q 'enum KeptoraProfilingHooks' "$CTRL"
grep -q 'os_signpost' "$CTRL"
grep -q 'CULLORA_REAL_CORPUS_PATH' "$CTRL"
grep -q 'externalCorpusOnly' "$ROOT/Docs/Profiling/real-corpus-manifest.example.json"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/corpus"
printf 'profile-a' > "$TMP/corpus/a.jpg"
printf 'profile-b-more' > "$TMP/corpus/b.dng"
printf 'ignored' > "$TMP/corpus/ignore.bin"
"$ROOT/Scripts/run_real_corpus_inventory.sh" "$TMP/corpus" "$TMP/index.tsv" >/dev/null
[[ "$(($(wc -l < "$TMP/index.tsv") - 1))" -eq 2 ]]
! grep -qE 'a\.|b\.|/tmp|corpus' "$TMP/index.tsv"
swiftc -parse "$CTRL"
echo 'PROFILING_READINESS_PASS app=Keptora'
