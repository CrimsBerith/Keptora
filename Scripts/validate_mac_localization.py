#!/usr/bin/env python3
"""Check fixed Mac UI strings and destructive-operation error messages in EN/TR/FR/DE.

Interpolated/plural formatting and rendered layout still require native/device acceptance.
"""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalogue = json.loads((root / "Keptora/Resources/Localizable.xcstrings").read_text())["strings"]
paths = list((root / "Keptora/App").glob("*.swift")) + list((root / "Keptora/Features").rglob("*.swift"))
paths += [root / "Keptora/Core/Models" / name for name in ("ReviewModels.swift", "CleanupModels.swift")]
patterns = [r'(?:Text|Label|Button|Menu|Toggle|Picker|ProgressView|DisclosureGroup|Section|CommandMenu|L10n\.tr|L10n\.format|ReviewText\.tr|ReviewText\.format|\.alert|\.navigationTitle|\.accessibilityLabel|\.accessibilityHint|\.help)\("([^"\n]*)"', r'String\(localized:\s*"([^"\n]*)"']
keys = set()
for path in paths:
    for pattern in patterns:
        keys.update(re.findall(pattern, path.read_text()))
for name in ("FolderQuarantineExecutor.swift", "PhotoLibrarySourceAdapter.swift"):
    path = root / "Packages/KeptoraCore/Sources/KeptoraCore" / name
    keys.update(re.findall(r'cleanupNotPermitted\("([^"\n]*)"\)', path.read_text()))
# Follow known text-producing mappings. Never scan all return literals: SF Symbol
# names, internal identifiers and algorithm versions are not translation keys.
for name, properties in {
    "AnalysisModels.swift": ("titleKey", "keeperReason"),
    "QualityAssessment.swift": ("titleKey",),
    "LibraryWorkflow.swift": ("statusKey",),
}.items():
    source = (root / "Packages/KeptoraCore/Sources/KeptoraCore" / name).read_text()
    for property_name in properties:
        for match in re.finditer(r'(?:var|func)\s+' + property_name + r'\b[^\{]*\{', source):
            start = match.end(); depth = 1; end = start
            while depth and end < len(source):
                depth += (source[end] == "{") - (source[end] == "}"); end += 1
            keys.update(re.findall(r'return\s+"([^"\n]*)"', source[start:end]))
keys.update(("Preserve Original and Save Current Session", "Retry Saving"))
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
print(f"PASS: {len(keys)} fixed and mapped Mac UI/error keys checked in EN/TR/FR/DE")
