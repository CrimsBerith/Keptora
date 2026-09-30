# Cullora integration sources

Cullora is the only shipping application in this product family.

| Module | Source project | Native destination |
|---|---|---|
| Journey Match | `Codex_Standalone_10_Apps_Phase_Q_2026-08-11/AtlasTrace_GPX` | `Cullora/Modules/JourneyMatch` |
| Metadata Tools | `Codex_Standalone_10_Apps_Phase_Q_2026-08-11/Aurelio_Metadata` | `Cullora/Modules/MetadataTools` |

Do not copy app entry points, bundle identifiers, commerce stores, global design systems or duplicate persistence layers. Journey and metadata modules must operate through Cullora's selected-library access, reversible-action model and recovery journal. Port core code, then adapters, UI and tests; do not claim either module is shipped until its tests run inside the Cullora target.
