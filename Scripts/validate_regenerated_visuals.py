#!/usr/bin/env python3
"""Verify reviewed files, icon opacity, fixture semantics and preview release gate.

This validates recorded acceptance; it cannot replace visual/native inspection.
Pillow is used for inspection only, not to create or edit image pixels.
"""
from collections import Counter
from io import BytesIO
from pathlib import Path
import argparse
import base64
import hashlib
import json
import sys
import xml.etree.ElementTree as ET
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--for-app-store', action='store_true', help='Reject previews pending actual native capture')
args = parser.parse_args()
manifest = json.loads((ROOT / 'Docs/Product/VISUAL_REGENERATION_MANIFEST.json').read_text())
entries = manifest['assets']
assert len(entries) == len({a['path'] for a in entries}) == 67
assert Counter(a['kind'] for a in entries) == {'icon': 34, 'illustration': 8, 'corpus': 13, 'screen': 12}
statuses = Counter()
for entry in entries:
    path = ROOT / entry['path']
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    review = entry['visual_review']
    assert digest == entry['sha256'] == review['reviewed_sha256'], path
    assert digest != entry['before_sha256'], path
    assert len(data) == entry['bytes'], path
    statuses[review['status']] += 1
    if path.name == 'Corrupted.jpg':
        assert review['status'] == 'accepted_negative_fixture'
        try:
            Image.open(BytesIO(data)).load()
        except (OSError, ValueError):
            pass
        else:
            raise AssertionError('Negative fixture unexpectedly decodes')
        continue
    if path.suffix == '.svg':
        svg = ET.fromstring(data)
        embedded = svg.find('{http://www.w3.org/2000/svg}image')
        uri = embedded.get('{http://www.w3.org/1999/xlink}href')
        assert uri.startswith('data:image/png;base64,')
        data = base64.b64decode(uri.split(',', 1)[1], validate=True)
        assert 'Raster-backed SVG' in ''.join(svg.itertext())
    with Image.open(BytesIO(data)) as image:
        image.load()
        assert list(image.size) == entry['pixels'], path
        if entry['before_pixels'] and path.suffix != '.svg':
            assert entry['pixels'] == entry['before_pixels'], path
        if entry['kind'] == 'icon':
            # Catch blank black or fully transparent exports, including small sizes.
            if 'mono' not in path.name:
                extrema = image.convert('RGBA').convert('RGB').getextrema()
                assert max(hi for lo, hi in extrema) >= 180, path
            if 'A' in image.getbands():
                assert image.getchannel('A').getextrema()[1] > 0, path
        if entry['kind'] == 'screen':
            assert review['status'] == 'accepted_design_preview_only'
            assert entry['native_capture'] is False and entry['app_store_approved'] is False
assert statuses == {'accepted_asset': 54, 'accepted_design_preview_only': 12, 'accepted_negative_fixture': 1}

catalog = ROOT / 'Keptora/Resources/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((catalog / 'Contents.json').read_text())['images']:
    with Image.open(catalog / item['filename']) as image:
        alpha = image.convert('RGBA').getchannel('A')
        if item['idiom'] in ('iphone', 'ios-marketing'):
            assert alpha.getextrema() == (255, 255), item
        elif item['idiom'] == 'mac':
            assert alpha.getextrema() == (0, 255), item
            assert alpha.getpixel((0, 0)) == 0, item

sources = ROOT / 'AppStore/SourceAssets/2026-10'
for source in json.loads((sources / 'sources.json').read_text())['sources'].values():
    path = sources / source['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256'], path
    with Image.open(path) as image:
        assert list(image.size) == source['pixels'], path

corpus = ROOT / 'AppStore/Generated/Keptora_Review_Corpus'
def sha(relative):
    return hashlib.sha256((corpus / relative).read_bytes()).hexdigest()

for group in [['Exact/Beach_Original.jpg', 'Exact/Beach_Copy.jpg'],
              ['Exact/Family_Original.jpg', 'Exact/Family_Copy_1.jpg', 'Exact/Family_Copy_2.jpg'],
              ['Exact/Poster.png', 'Exact/Poster copy.png']]:
    assert len({sha(p) for p in group}) == 1, group
assert len({sha(f'Similar/Sunset_{i}.jpg') for i in range(1, 4)}) == 3
assert sha('Families/DSC_0001.jpg') != sha('Families/DSC_0001_Edit.jpg')
timestamps = []
coordinates = []
for index in range(1, 4):
    with Image.open(corpus / f'Similar/Sunset_{index}.jpg') as image:
        exif = image.getexif()
        assert 'fictional' in exif[270]
        timestamps.append(exif.get_ifd(34665)[36867])
        gps = exif.get_ifd(34853)
        coordinates.append((tuple(gps[2]), tuple(gps[4])))
assert timestamps == [f'2026:09:15 18:42:0{i}' for i in range(1, 4)]
assert len(set(coordinates)) == 1
for entry in json.loads((corpus / 'manifest.json').read_text())['files']:
    assert sha(entry['path']) == entry['sha256']
    assert (corpus / entry['path']).stat().st_size == entry['bytes']
with zipfile.ZipFile(ROOT / 'AppStore/Keptora_App_Review_Corpus.zip') as archive:
    expected = {str(Path(corpus.name) / p.relative_to(corpus)): p.read_bytes()
                for p in corpus.rglob('*') if p.is_file()}
    assert set(archive.namelist()) == set(expected)
    for name, data in expected.items():
        assert archive.read(name) == data, name

print('PASS: all 67 paths changed; reviewed hashes, sizes, SVG payloads, icons, sources, exact/near/family fixtures, fictional EXIF and ZIP match.')
print('Acceptance: 54 assets; 12 design previews only; 1 intentionally invalid negative fixture.')
if args.for_app_store:
    sys.exit('BLOCKED: 12 generated design previews are not native captures or App Store-approved screenshots.')
