# Keptora — Production AppIcon source

Concept: two photo frames — the translucent one behind is the duplicate that is set aside, the solid one in front with a check mark is the keeper. No letters, so it stays legible at 16 px.

- `source-1024.png`: 1024×1024 opaque RGB full-bleed master (iOS / App Store marketing icon).
- `logo/keptora-icon-fullbleed.svg`: vector master of the full-bleed icon.
- `logo/keptora-icon-mac.svg`: macOS icon (824 px squircle on a 1024 canvas, transparent margin + soft shadow).
- `logo/keptora-mark.svg`, `logo/keptora-mark-mono.svg`: standalone mark (coloured / single-colour) for web, docs, marketing.
- Asset catalog: iPhone + `ios-marketing` slots use the full-bleed art (`icon_1024_ios.png` for marketing); `mac` slots use the pre-masked squircle art (these files intentionally contain alpha).
- The previous icon set is kept in `AppStore/AppIcon/previous_icon_set/` — it is not referenced by Contents.json and can be deleted once the new icon is accepted.
- Remaining acceptance: inspect the compiled icon on a real Mac at Finder/Dock/App Store sizes.
