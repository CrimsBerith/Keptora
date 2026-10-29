# Keptora

Keptora is a private photo and video cleaner for iPhone and macOS. Open Apple Photos or a chosen folder, browse all accessible media, select any items manually, and review the source and recovery conditions before removing them.

The library supports album, media, favorite and date filters, grouping, preview and selection review. WhatsApp collections use saved Photos copies and user-assigned albums; WhatsApp chat storage is managed inside WhatsApp. Similarity suggestions combine visual comparison with available capture time, location and burst context, while exact duplicates retain byte-level verification.

Photos removals use the system confirmation and Recently Deleted. Folder files move to a recovery area on the same storage; this does not free space. Disk recovery manifests preserve a recovery route across app interruptions. Manual selection, privacy and recovery are available without Pro.

See the [delivery report](Docs/Product/DELIVERY_REPORT.md), [UI/UX audit](Docs/Product/UI_UX_AUDIT.md), [product plan](Docs/Product/PHOTO_CLEANER_PLAN.md), and [new artwork](Docs/Product/ARTWORK.md).

Latest native quality audit: [18 October 2026](Docs/Product/PROFESSIONAL_QA_2026-10-18.md). Functional test results, full accessibility diagnostics and physical-device acceptance are reported separately.

## Development checks

```sh
rtk swift test --package-path Packages/KeptoraCore
rtk python3 Scripts/validate_project_references.py
rtk python3 Scripts/validate_photo_cleaner_assets.py
```

On Linux, the package tests the shared Foundation catalogue, selection and metadata policy models. Apple-only adapters and UI require macOS/Xcode. [Apple CI](.github/workflows/apple-validation.yml) runs the full core, native macOS/iPhone unit tests, focused product UI tests and simulator screenshot capture. Native validation and current screenshots must be reviewed before release.

Legacy archive-review implementation and release history remain documented in [Phase 5S](Docs/Phase_5S/PHASE_5S_IMPLEMENTATION.md). Those historical reports and screenshots do not validate the current photo-cleaner release.

`ReleaseTesting` uses Release optimization with test-only catalogue fixtures and testability enabled. Shipping archives use `Release`, which excludes `KEPTORA_TESTING`; Mac Debug builds use the active architecture, while Release builds support both arm64 and x86_64. Regenerate the project with `rtk xcodegen generate --spec project.yml`.

For the full local release gate, install `Scripts/requirements.txt` in a virtual environment and set `PYTHON` to its interpreter, then run `rtk env PYTHON=/absolute/path/to/venv/bin/python bash Scripts/release_gate_on_mac.sh`. Set `IOS_SIMULATOR_ID` to choose a simulator. The gate imports the fictional corpus there, runs native tests and creates signed Release archives and local exports in a new timestamped evidence folder. It does not upload builds. `XCODE_GATE_TIMEOUT_SECONDS` bounds runner startup as well as execution; a timeout fails the gate and retains its log.

The current static Keptora web pages are reproducible with `rtk python3 Scripts/build_keptora_web.py`. Upload only `AppStore/Web/publish/keptora/` to the corresponding Hostinger directory. `AppStore/Web/previous/` contains the pre-fix public pages for rollback; `manifest.json` records the publish-file hashes.
