#!/usr/bin/env python3
"""Check actual artwork, catalog references and translated format placeholders."""
from pathlib import Path
import hashlib
import json
import re
import struct

root = Path(__file__).resolve().parents[1]
assets = root / 'Keptora/Resources/Assets.xcassets'
manifest = json.loads((root / 'Docs/Product/ARTWORK_MANIFEST.json').read_text())
for entry in manifest['illustrations']:
    path = root / entry['path']
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    dimensions = struct.unpack('>II', data[16:24])
    assert dimensions == tuple(entry['pixels']), (path, dimensions)
    assert min(dimensions) >= 1024, (path, dimensions)
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], path
for catalog in assets.rglob('Contents.json'):
    for item in json.loads(catalog.read_text()).get('images', []):
        if filename := item.get('filename'):
            assert (catalog.parent / filename).is_file(), (catalog, filename)
strings = json.loads((root / 'Keptora/Resources/Localizable.xcstrings').read_text())['strings']
def placeholders(value):
    """Compare argument identity and type, allowing grammatical reordering."""
    result, implicit = [], 1
    pattern = r'%%|%(?:(\d+)\$)?[-+#0 ]*(?:\d+)?(?:\.\d+)?(lld|llu|ld|lu|@|d|i|u|f|g|s)'
    for match in re.finditer(pattern, value):
        if match.group(0) == '%%':
            continue
        position = int(match.group(1)) if match.group(1) else implicit
        if not match.group(1):
            implicit += 1
        result.append((position, match.group(2)))
    return sorted(result)

assert placeholders('%lld of %lld') == placeholders('%2$lld öğeden %1$lld')
assert placeholders('%@ %lld') != placeholders('%2$@ %1$lld')
assert placeholders('100%% · %.1f') == placeholders('%.1f · 100%%')
for key, item in strings.items():
    if item.get('extractionState') != 'manual':
        continue
    for language in ['en', 'tr', 'fr', 'de']:
        if not (unit := item.get('localizations', {}).get(language, {}).get('stringUnit')):
            continue
        assert placeholders(key) == placeholders(unit['value']), (key, language)
print(f"PASS: {len(manifest['illustrations'])} high-resolution illustrations, every asset reference, EN/TR/FR/DE format arguments")
