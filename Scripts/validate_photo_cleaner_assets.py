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
for key, item in strings.items():
    if item.get('extractionState') != 'manual':
        continue
    if not (unit := item.get('localizations', {}).get('tr', {}).get('stringUnit')):
        continue
    source_placeholders = sorted(re.findall(r'%(?:\d+\$)?(?:lld|ld|@|d|f)', key))
    translation_placeholders = sorted(re.findall(r'%(?:\d+\$)?(?:lld|ld|@|d|f)', unit['value']))
    assert source_placeholders == translation_placeholders, key
print(f"PASS: {len(manifest['illustrations'])} high-resolution illustrations, every asset reference, Turkish format placeholders")
