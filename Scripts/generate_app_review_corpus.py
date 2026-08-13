#!/usr/bin/env python3
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFilter

parser = argparse.ArgumentParser()
parser.add_argument('--output', default='AppStore/Generated/Cullora_Review_Corpus')
args = parser.parse_args()
root = Path(args.output).expanduser().resolve()
if root.exists():
    shutil.rmtree(root)
(root / 'Exact').mkdir(parents=True)
(root / 'Similar').mkdir()
(root / 'Families').mkdir()
(root / 'EdgeCases').mkdir()


def save_scene(path: Path, palette, label: str, shift: int = 0, quality: int = 92):
    width, height = 1600, 1000
    image = Image.new('RGB', (width, height), palette[0])
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        color = tuple(int(palette[0][i] * (1 - t) + palette[1][i] * t) for i in range(3))
        draw.line((0, y, width, y), fill=color)
    draw.ellipse((150 + shift, 120, 520 + shift, 490), fill=palette[2])
    draw.rectangle((0, 710, width, height), fill=palette[3])
    for x in range(-100, width, 180):
        draw.polygon(
            [(x + shift, 780), (x + 90 + shift, 620), (x + 180 + shift, 780)],
            fill=palette[4],
        )
    draw.text((48, 48), label, fill=(245, 245, 245))
    image.save(path, quality=quality, optimize=True)
    return image


# Exact JPEG groups. Copies preserve identical bytes.
save_scene(
    root / 'Exact' / 'Beach_Original.jpg',
    [(22, 65, 108), (242, 166, 93), (255, 225, 120), (24, 88, 105), (238, 190, 114)],
    'Synthetic Beach',
)
shutil.copy2(root / 'Exact' / 'Beach_Original.jpg', root / 'Exact' / 'Beach_Copy.jpg')

save_scene(
    root / 'Exact' / 'Family_Original.jpg',
    [(42, 37, 74), (170, 94, 137), (244, 190, 92), (61, 45, 82), (235, 153, 93)],
    'Synthetic Family',
)
for name in ['Family_Copy_1.jpg', 'Family_Copy_2.jpg']:
    shutil.copy2(root / 'Exact' / 'Family_Original.jpg', root / 'Exact' / name)

poster = Image.new('RGB', (1200, 1200), (240, 235, 224))
draw = ImageDraw.Draw(poster)
draw.rounded_rectangle((140, 140, 1060, 1060), radius=96, fill=(25, 52, 77))
draw.ellipse((360, 300, 840, 780), fill=(230, 167, 72))
draw.text((400, 900), 'CULLORA QA', fill=(255, 255, 255))
poster.save(root / 'Exact' / 'Poster.png', optimize=True)
shutil.copy2(root / 'Exact' / 'Poster.png', root / 'Exact' / 'Poster copy.png')

# Non-identical but visually similar set.
for index, (shift, quality) in enumerate([(0, 93), (12, 90), (-9, 88)], start=1):
    path = root / 'Similar' / f'Sunset_{index}.jpg'
    image = save_scene(
        path,
        [(32, 37, 86), (242, 111, 90), (255, 205, 91), (30, 49, 76), (115, 67, 90)],
        f'Synthetic Sunset {index}',
        shift=shift,
        quality=quality,
    )
    if index == 3:
        image.filter(ImageFilter.GaussianBlur(radius=0.6)).save(path, quality=quality)

# Filename family and sidecar.
save_scene(
    root / 'Families' / 'DSC_0001.jpg',
    [(29, 53, 58), (124, 162, 140), (239, 199, 118), (47, 81, 70), (154, 122, 80)],
    'RAW/JPEG Family',
)
(root / 'Families' / 'DSC_0001.xmp').write_text(
    '<?xpacket begin=""?><x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF '
    'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/></x:xmpmeta>'
    '<?xpacket end="w"?>',
    encoding='utf-8',
)
shutil.copy2(root / 'Families' / 'DSC_0001.jpg', root / 'Families' / 'DSC_0001_Edit.jpg')

# Deliberately invalid image for skip/error-path testing.
(root / 'EdgeCases' / 'Corrupted.jpg').write_bytes(b'not-a-valid-jpeg' + bytes([0, 1]))

manifest = []
for path in sorted(root.rglob('*')):
    if path.is_file():
        manifest.append(
            {
                'path': str(path.relative_to(root)),
                'bytes': path.stat().st_size,
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )
(root / 'manifest.json').write_text(
    json.dumps({'schema': 1, 'synthetic': True, 'files': manifest}, indent=2) + '\n',
    encoding='utf-8',
)
(root / 'README.txt').write_text(
    'Synthetic Cullora QA corpus. No personal data. See AppStore/REVIEW_CORPUS_README.md.\n',
    encoding='utf-8',
)
print(root)
