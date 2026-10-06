#!/usr/bin/env python3
"""Check fixed Mac UI strings and destructive-operation error messages in EN/TR/FR/DE.

Interpolated strings and dynamic enum keys still require native/device acceptance.
"""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalogue = json.loads((root / "Keptora/Resources/Localizable.xcstrings").read_text())["strings"]
paths = list((root / "Keptora/App").glob("*.swift")) + list((root / "Keptora/Features").rglob("*.swift"))
patterns = [r'(?:Text|Label|Button|Menu|Toggle|Picker|ProgressView|DisclosureGroup|Section|CommandMenu|L10n\.tr|L10n\.format|\.alert|\.navigationTitle|\.accessibilityLabel|\.accessibilityHint|\.help)\("([^"\n]*)"']
keys = set()
for path in paths:
    for pattern in patterns:
        keys.update(re.findall(pattern, path.read_text()))
for name in ("FolderQuarantineExecutor.swift", "PhotoLibrarySourceAdapter.swift"):
    path = root / "Packages/KeptoraCore/Sources/KeptoraCore" / name
    keys.update(re.findall(r'cleanupNotPermitted\("([^"\n]*)"\)', path.read_text()))
missing = []
for key in sorted(keys):
    if not key or "\\(" in key or key.isnumeric():
        continue
    for language in ("en", "tr", "fr", "de"):
        if language == "en" and key in catalogue:
            # xcstrings uses its English source key when no explicit EN override exists.
            continue
        if not catalogue.get(key, {}).get("localizations", {}).get(language, {}).get("stringUnit", {}).get("value"):
            missing.append(f"{language}: {key}")
if missing:
    raise SystemExit("Incomplete fixed-string translations:\n" + "\n".join(missing))
print(f"PASS: {len(keys)} fixed Mac UI/error keys checked in EN/TR/FR/DE")
