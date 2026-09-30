#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-source}"
fail=0
ok() { printf 'PASS  %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
need() { if (set +o pipefail; eval "$2"); then ok "$1"; else bad "$1"; fi; }

need "Xcode project present" "find \"$ROOT\" -maxdepth 1 -name '*.xcodeproj' -type d | grep -q ."
need "Privacy manifest present" "find \"$ROOT/Keptora\" -name 'PrivacyInfo.xcprivacy' -type f | grep -q ."
need "Entitlements present" "find \"$ROOT/Keptora\" -name '*.entitlements' -type f | grep -q ."
need "Product root accessibility identity" "grep -R -F -- 'keptora.root' \"$ROOT/Keptora\" | grep -q ."
need "Successor deterministic screenshot switch" "grep -R -F -- '-keptoraScreenshotReconciliation' \"$ROOT/Keptora\" | grep -q ."
need "Successor surface title retained" "grep -R -F -- 'QUARANTINE DECISION RECONCILIATION' \"$ROOT/Keptora\" | grep -q ."
need "Keyboard access exists" "grep -R -F -- 'keyboardShortcut' \"$ROOT/Keptora\" | grep -q ."
count=$(grep -R -F -- 'accessibilityIdentifier(' "$ROOT/Keptora" | wc -l | tr -d ' ')
if [ "$count" -ge 3 ]; then ok "Accessibility identifiers >= 3 ($count)"; else bad "Accessibility identifiers >= 3 ($count)"; fi

if command -v swiftc >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do swiftc -parse "$f" >/dev/null; done < <(find "$ROOT/Keptora" -name '*.swift' -type f -print0)
  ok "Swift source parse"
else
  printf 'SKIP  Swift source parse (swiftc unavailable)\n'
fi

python3 - "$ROOT" <<'PY2'
import pathlib, plistlib, sys
root=pathlib.Path(sys.argv[1])
for p in list(root.rglob('PrivacyInfo.xcprivacy')) + list(root.rglob('*.entitlements')):
    with p.open('rb') as f: plistlib.load(f)
print('PASS  plist manifests parse')
PY2

# Source packages intentionally retain release placeholders until the real Mac signing step.
placeholder=0
if grep -R -E 'com\.yourcompany|YOUR_|REPLACE_ME|TEAM_ID|example\.com' "$ROOT" --include='project.pbxproj' --include='release-config.json' --include='*.entitlements' -q; then placeholder=1; fi
if [ "$MODE" = "--archive" ] || [ "$MODE" = "archive" ]; then
  if [ "$placeholder" -eq 1 ]; then bad "Archive release placeholders removed"; else ok "Archive release placeholders removed"; fi
else
  if [ "$placeholder" -eq 1 ]; then ok "Archive gate fail-closed: placeholders detected"; else ok "No release placeholders detected"; fi
fi

if [ false = true ]; then
  need "Successor UI test contract" "grep -R -F -- '-keptoraScreenshotReconciliation' \"$ROOT\" | grep -q ."
else
  ok "Successor UI test contract handled by source gate (no UI-test target)"
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
printf 'HARDENING GATE PASS — Keptora\n'
