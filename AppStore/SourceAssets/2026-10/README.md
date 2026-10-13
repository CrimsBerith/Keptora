# Keptora October 2026 generated masters

27 original generated PNG masters, plus one deterministic macOS mask export. Created using OpenAI image generation for this task. Fictional photographic scenes and people; no user photo data. Generation/refinement used image generation; local export performs only encoding, proportional resizing and OS icon masking. Date/GPS fixture metadata is explicitly fictional.

`sources.json` records source hashes and actual pixel dimensions. The original 67 deliverable paths, hashes, individual review notes and native-capture limitations are in `Docs/Product/VISUAL_REGENERATION_MANIFEST.json`.

Requirements: Python 3, Pillow 12.3.0 for EXIF metadata and inspection, ImageMagick 7.1.1-43 for reproducible exports. CairoSVG was used only to render the 8 SVG files for visual inspection; native capture requires macOS/Xcode.

```bash
python3 Scripts/export_regenerated_visuals.py
python3 Scripts/build_visual_review_gallery.py
python3 Scripts/validate_regenerated_visuals.py
python3 Scripts/validate_photo_cleaner_assets.py
```

Run from the repository root. The gallery embeds review metadata, loads repository-relative image files, and needs the entire repository checkout. Open `Docs/Product/VISUAL_GALLERY.html` to navigate each file. Gallery navigation is ancillary to the individual image inspection recorded in the manifest.

12 screen masters are labelled DESIGN PREVIEWS, not native application captures or production screenshots. `python3 Scripts/validate_regenerated_visuals.py --for-app-store` rejects them until true native screenshots receive acceptance. Retain actual source pixel dimensions in provenance; increasing output canvas dimensions does not add photographic detail.
