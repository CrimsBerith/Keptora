#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORPUS="${1:-${CULLORA_REAL_CORPUS_PATH:-}}"
OUT="${2:-$ROOT/ValidationArtifacts/Profiling/real_corpus_inventory.tsv}"
[[ -n "$CORPUS" && -d "$CORPUS" ]] || { echo "usage: $0 /external/corpus [output.tsv]" >&2; exit 2; }
mkdir -p "$(dirname "$OUT")"
printf 'index\textension\tbytes\tsha256\n' > "$OUT"
count=0; total=0
size_of() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }
while IFS= read -r -d '' f; do
  ext="${f##*.}"; ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in jpg|jpeg|heic|png|tif|tiff|dng) ;; *) continue ;; esac
  bytes="$(size_of "$f")"
  hash="$(shasum -a 256 "$f" | awk '{print $1}')"
  count=$((count+1)); total=$((total+bytes))
  printf '%s\t%s\t%s\t%s\n' "$count" "$ext" "$bytes" "$hash" >> "$OUT"
done < <(find "$CORPUS" -type f -print0)
[[ "$count" -gt 0 ]] || { echo "no accepted corpus files" >&2; exit 3; }
printf 'REAL_CORPUS_INDEX_PASS app=Keptora files=%s bytes=%s output=%s\n' "$count" "$total" "$OUT"
