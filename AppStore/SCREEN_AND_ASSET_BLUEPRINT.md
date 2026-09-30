# Keptora — Screen Design & Asset Blueprint (Phase K)

**Portfolio identity:** Archive Review Studio  
**Rule:** shell, hierarchy, interaction rhythm, typography and screenshot composition must remain product-specific; never collapse into a shared three-column dashboard.

## Every shipping screen / major surface

| # | Screen / surface | Design composition | Required states | Image / asset requirements |
|---:|---|---|---|---|
| 1 | **Archive Review Studio** | Top masthead + ticket workspace shelf + full-width review floor + bottom Decision Shelf | no source / scanning / exact groups / similar review / committed | Synthetic photo corpus with EXIF stripped |
| 2 | **Exact Review Group** | Byte-identical evidence-focused comparison | keeper chosen / protected / quarantine plan | Small demo thumbnails only |
| 3 | **Similar Comparison** | Side-by-side visual compare with synchronized zoom | strong / review / uncertain | Synthetic non-personal image pairs |
| 4 | **Safety Plan** | Pre-commit movement/recoverability review | collision / blocked / ready | No raster |
| 5 | **History & Restore** | Signed manifest history + restore | empty / committed / restored / drift | Deterministic manifests |
| 6 | **Quarantine Verification Lineage** | Read-only verification lineage | current / changed / missing | No raster |
| 7 | **Onboarding** | Local-only safety promise | first launch / complete | SF Symbols |
| 8 | **Settings & Pro** | Scanning, exclusions, calibration, license/support | locked / unlocked / invalid URL | No raster |

## Global asset package
- **App icon:** editable 1024×1024 master, no baked macOS corner mask; Xcode AppIcon set; visually unique from the other nine apps.
- **Screenshot fixtures:** deterministic, synthetic, non-personal corpus matching `SCREENSHOT_PLAN.md`; no conceptual mockups.
- **Marketing screenshots:** capture from the signed Release build; 1–10 Mac screenshots, PNG/JPEG, no alpha.
- **Typography:** system fonts only unless a font license and embedded-font plan are explicitly added.
- **Symbols:** prefer SF Symbols for controls/status; never depend on symbol color alone for meaning.
- **Backgrounds/textures:** native SwiftUI materials/shapes preferred. Any raster texture must have @2x source and remain decorative/non-semantic.
- **Empty/error/loading assets:** use product-specific native composition and SF Symbols; do not add generic stock illustrations across the portfolio.

## Asset acceptance gate
1. No personal data, third-party trademarks, faces, real customer paths, serials or coordinates in fixtures/screenshots.
2. Every visible asset has a Retina-quality source and legal usage rights.
3. Dark/light/high-contrast behavior is checked where the app supports those appearances.
4. Screenshots must match the shipping UI exactly and preserve the **Archive Review Studio** silhouette.
