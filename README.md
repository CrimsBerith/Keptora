# Keptora

Keptora is a private photo and video cleaner for iPhone and macOS. Open Apple Photos or a chosen folder, browse all accessible media, select any items manually, and review the source and recovery conditions before removing them.

The library supports album, media, favorite and date filters, grouping, preview and selection review. WhatsApp collections use saved Photos copies and user-assigned albums; WhatsApp chat storage is managed inside WhatsApp. Similarity suggestions combine visual comparison with available capture time, location and burst context, while exact duplicates retain byte-level verification.

Photos removals use the system confirmation and Recently Deleted. Folder files move to a recovery area on the same storage; this does not free space. Disk recovery manifests preserve a recovery route across app interruptions. Manual selection, privacy and recovery are available without Pro.

See the [delivery report](Docs/Product/DELIVERY_REPORT.md), [UI/UX audit](Docs/Product/UI_UX_AUDIT.md), [product plan](Docs/Product/PHOTO_CLEANER_PLAN.md), and [new artwork](Docs/Product/ARTWORK.md).

## Development checks

```sh
rtk swift test --package-path Packages/KeptoraCore
rtk proxy python3 Scripts/validate_project_references.py
rtk proxy python3 Scripts/validate_photo_cleaner_assets.py
```

On Linux, the package tests the shared Foundation catalogue, selection and metadata policy models. Apple-only adapters and UI require macOS/Xcode. [Apple CI](.github/workflows/apple-validation.yml) runs the full core, native macOS/iPhone unit tests, focused product UI tests and simulator screenshot capture. Native validation and current screenshots must be reviewed before release.

Legacy archive-review implementation and release history remain documented in [Phase 5S](Docs/Phase_5S/PHASE_5S_IMPLEMENTATION.md). Those historical reports and screenshots do not validate the current photo-cleaner release.
