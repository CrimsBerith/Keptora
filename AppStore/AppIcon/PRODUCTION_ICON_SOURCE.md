# Current Keptora icon source

October 2026: `AppStore/SourceAssets/2026-10/icon.png` is the new generated master. `source-1024.png` is its opaque 1024 export. All 34 original icon/logo paths were regenerated and individually inspected.

The icon depicts a photo frame, mountain/sun and selection check. macOS exports retain a transparent margin and rounded tile; iPhone and marketing exports are opaque. The compatibility `previous_icon_set` directory was refreshed at the user's explicit request and is not a rollback snapshot.

`logo/*.svg` files are raster-backed SVG wrappers, not native vector masters. The colored and monochrome transparent marks were generated separately from the icon reference and individually rendered on white for review.

Use `python3 Scripts/export_regenerated_visuals.py` for the complete export, or `python3 Scripts/build_phase_n_appicon.py` for icons only. Python 3, Pillow (metadata only) and ImageMagick are required. Historical procedural Swift generators do not reproduce the approved October design.

[Per-file acceptance](../../Docs/Product/VISUAL_REGENERATION_REVIEW.md) and [source checksums](../SourceAssets/2026-10/sources.json). Native OS rendering acceptance remains pending Apple validation.
