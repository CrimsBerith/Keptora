#!/usr/bin/env python3
"""Reproducible format/size exports of generated masters; no creative retouching.

SVG exports embed PNGs: they are raster-backed SVGs, not vector masters.
ImageMagick performs technical OS masking, resampling and format conversion only.
Visual acceptance is recorded separately after inspecting each deliverable.
"""
from pathlib import Path
import base64
import hashlib
import json
import shutil
import struct
import subprocess
import zipfile
from PIL import Image, TiffImagePlugin

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'AppStore/SourceAssets/2026-10'
ASSETS = ROOT / 'Keptora/Resources/Assets.xcassets'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture_metadata(path, timestamp):
    """Insert explicitly fictional EXIF without decoding or modifying pixels."""
    exif = Image.Exif()
    exif[270] = 'Keptora generated fixture; fictional date and coordinates; no user photo data'
    exif[34665] = {36867: timestamp, 36868: timestamp}
    rational = TiffImagePlugin.IFDRational
    exif[34853] = {0: bytes([2, 3, 0, 0]), 1: 'N',
        2: (rational(36), rational(12), rational(0)), 3: 'E',
        4: (rational(29), rational(38), rational(0))}
    payload = exif.tobytes()
    data = path.read_bytes()
    assert data[:2] == b'\xff\xd8'
    path.write_bytes(data[:2] + b'\xff\xe1' + struct.pack('>H', len(payload) + 2) + payload + data[2:])


def encode(source, target, *options):
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['convert', str(source), *options, '-strip', str(target)], check=True)


def svg(source, target, title):
    width, height = struct.unpack('>II', source.read_bytes()[16:24])
    data = base64.b64encode(source.read_bytes()).decode()
    target.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img">'
        f'<title>{title}</title><desc>Raster-backed SVG; generated PNG source, October 2026.</desc>'
        f'<image width="{width}" height="{height}" xlink:href="data:image/png;base64,{data}"/>'
        '</svg>\n', encoding='utf-8')


def export_icons():
    directory = ROOT / 'AppStore/AppIcon'
    master = directory / 'source-1024.png'
    encode(SOURCES / 'icon.png', master, '-resize', '1024x1024!', '-alpha', 'off', '-define', 'png:color-type=2')
    mac = SOURCES / 'mac-export.png'
    subprocess.run(['convert', str(master), '-resize', '824x824',
        '(', '-size', '824x824', 'xc:black', '-fill', 'white', '-draw', 'roundrectangle 0,0 823,823 180,180', ')',
        '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', '-compose', 'Over', '-background', 'none',
        '-gravity', 'center', '-extent', '1024x1024', '-strip', str(mac)], check=True)
    mac_sizes = {16, 32, 64, 128, 256, 512, 1024}
    for path in sorted((ASSETS / 'AppIcon.appiconset').glob('icon_*.png')):
        size = int(path.stem.split('_')[1])
        is_mac = size in mac_sizes and not path.stem.endswith('_ios')
        encode(mac if is_mac else master, path, '-filter', 'Lanczos', '-resize', f'{size}x{size}!')
    # Compatibility directory refreshed at the user's explicit request.
    for path in sorted((directory / 'previous_icon_set').glob('icon_*.png')):
        size = int(path.stem.split('_')[1])
        encode(master, path, '-filter', 'Lanczos', '-resize', f'{size}x{size}!')
    logo = directory / 'logo'
    svg(master, logo / 'keptora-icon-fullbleed.svg', 'Keptora full-bleed icon')
    svg(mac, logo / 'keptora-icon-mac.svg', 'Keptora macOS icon')
    svg(SOURCES / 'mark_clean.png', logo / 'keptora-mark.svg', 'Keptora colored mark')
    svg(SOURCES / 'mono.png', logo / 'keptora-mark-mono.svg', 'Keptora monochrome mark')


def export_artwork():
    path = ROOT / 'Docs/Product/ARTWORK_MANIFEST.json'
    manifest = json.loads(path.read_text())
    for entry, source in zip(manifest['illustrations'], ['privacy', 'proof', 'restore', 'hero']):
        target = ROOT / entry['path']
        encode(SOURCES / f'{source}.png', target, '-resize', '1536x1024!')
        svg(target, ROOT / f"AppStore/Illustrations/{entry['name']}.svg", f"Keptora {entry['name']}")
        entry['sha256'] = digest(target)
        entry['source'] = f'AppStore/SourceAssets/2026-10/{source}.png'
        entry['review'] = 'Per-file review in VISUAL_REGENERATION_MANIFEST.json; native layout acceptance pending'
    manifest['app_icon'] = 'New October 2026 master and every OS size regenerated; per-file review recorded separately.'
    manifest['screenshots'] = '12 visibly labelled design previews, not native captures; not approved for App Store submission.'
    path.write_text(json.dumps(manifest, indent=2) + '\n')


def export_corpus(output=None):
    corpus = Path(output).resolve() if output else ROOT / 'AppStore/Generated/Keptora_Review_Corpus'
    for subdir in ['Exact', 'Similar', 'Families', 'EdgeCases']:
        (corpus / subdir).mkdir(parents=True, exist_ok=True)
    for name in ['Beach', 'Family']:
        target = corpus / f'Exact/{name}_Original.jpg'
        encode(SOURCES / f'{name.lower()}.png', target, '-quality', '97', '-sampling-factor', '4:4:4')
        fixture_metadata(target, '2026:09:14 14:30:00' if name == 'Beach' else '2026:09:16 12:30:00')
        copies = [f'{name}_Copy.jpg'] if name == 'Beach' else ['Family_Copy_1.jpg', 'Family_Copy_2.jpg']
        for copy in copies:
            shutil.copyfile(target, corpus / 'Exact' / copy)
    target = corpus / 'Exact/Poster.png'
    encode(SOURCES / 'poster.png', target, '-resize', '1200x1200!')
    shutil.copyfile(target, corpus / 'Exact/Poster copy.png')
    for index, source in enumerate(['sunset', 'sunset2', 'sunset3'], 1):
        target = corpus / f'Similar/Sunset_{index}.jpg'
        encode(SOURCES / f'{source}.png', target, '-quality', '97', '-sampling-factor', '4:4:4')
        fixture_metadata(target, f'2026:09:15 18:42:0{index}')
    for name, source in [('DSC_0001', 'dsc'), ('DSC_0001_Edit', 'dsc_edit')]:
        target = corpus / f'Families/{name}.jpg'
        encode(SOURCES / f'{source}.png', target, '-quality', '97', '-sampling-factor', '4:4:4')
        fixture_metadata(target, '2026:09:15 16:30:00')
    (corpus / 'Families/DSC_0001.xmp').write_text(
        '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
        '<rdf:Description xmlns:xmp="http://ns.adobe.com/xap/1.0/" '
        'xmp:Label="Fictional generated original/edit family" xmp:CreateDate="2026-09-15T16:30:00+03:00"/>'
        '</rdf:RDF></x:xmpmeta>\n')
    (corpus / 'EdgeCases/Corrupted.jpg').write_bytes((corpus / 'Exact/Beach_Original.jpg').read_bytes()[:64])
    (corpus / 'README.txt').write_text(
        'Keptora generated QA corpus, October 2026. Fictional scenes and people; no user photo data.\n'
        'Three exact groups; three distinct near-burst sunset frames; distinct original/edit family; one intentionally truncated JPEG.\n'
        'Visual review: Docs/Product/VISUAL_REGENERATION_REVIEW.md.\n')
    files = [{'path': str(p.relative_to(corpus)), 'bytes': p.stat().st_size, 'sha256': digest(p)}
        for p in sorted(corpus.rglob('*')) if p.is_file() and p.name != 'manifest.json']
    (corpus / 'manifest.json').write_text(json.dumps({'schema': 2, 'synthetic': True,
        'origin': 'OpenAI image generation, fictional photo fixtures, 2026-10-03', 'files': files}, indent=2) + '\n')
    if not output:
        with zipfile.ZipFile(ROOT / 'AppStore/Keptora_App_Review_Corpus.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(corpus.rglob('*')):
                if path.is_file():
                    info = zipfile.ZipInfo(str(Path(corpus.name) / path.relative_to(corpus)), (2026, 10, 3, 0, 0, 0))
                    info.compress_type = zipfile.ZIP_DEFLATED
                    info.external_attr = 0o100644 << 16
                    archive.writestr(info, path.read_bytes())
    return corpus


def export_previews():
    manifest = json.loads((ROOT / 'Docs/Product/VISUAL_REGENERATION_MANIFEST.json').read_text())
    screens = [item for item in manifest['assets'] if item['kind'] == 'screen']
    for platform, prefix in [('Mac', 'mac'), ('iOS', 'ios')]:
        paths = sorted(item['path'] for item in screens if f'/{platform}/' in item['path'])
        dimensions = '2880x1800' if platform == 'Mac' else '1206x2622'
        for index, path in enumerate(paths, 1):
            encode(SOURCES / f'{prefix}{index}.png', ROOT / path, '-filter', 'Lanczos',
                '-resize', dimensions, '-background', '#f5f3ff', '-gravity', 'center', '-extent', dimensions, '-alpha', 'off')
    (ROOT / 'AppStore/Generated/Screenshots/README.md').write_text(
        '# Design previews — not native screenshots\n\n'
        'All 12 PNGs here are generated conceptual design previews, visibly labelled TASARIM ÖNİZLEMESİ. '
        'They are not evidence of implemented UI, native rendering, accessibility, purchases or deletion behavior. '
        'Do not submit them to App Store Connect. Replace with native captures after Apple CI/device validation.\n\n'
        'Per-file visual review: Docs/Product/VISUAL_REGENERATION_MANIFEST.json.\n')


if __name__ == '__main__':
    export_icons()
    export_artwork()
    export_corpus()
    export_previews()
    print('Exported 67 existing paths; visual acceptance must be recorded separately.')
