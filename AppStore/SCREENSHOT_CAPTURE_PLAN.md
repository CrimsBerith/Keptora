# Mac App Store Screenshot Capture Plan

## Delivery format

Use a single 16:10 size consistently across all launch screenshots. Preferred master size:

- **2880 × 1800 PNG**, no alpha channel.

Apple also accepts 1280 × 800, 1440 × 900, and 2560 × 1600 for Mac screenshots. The product page accepts one to ten screenshots. Capture the real Release build; do not fabricate unavailable UI or composite features that are not present.

## Capture environment

- Release or App Store-equivalent build with the final app icon and name.
- Light appearance for the primary set; optionally test a separate dark-mode marketing set before choosing one.
- Standard macOS wallpaper or a neutral desktop with no personal files, user name, notifications, menu-bar secrets, or unrelated apps.
- Window size fixed across all shots.
- Use `Scripts/generate_app_review_corpus.py` to create deterministic, non-personal demo files.
- Reset onboarding, trial state, and database before the capture session when needed.
- Do not show placeholder product IDs, placeholder URLs, developer diagnostics, test labels, or fake price strings.

## Recommended six-shot sequence

| # | Screen | English overlay/caption | Turkish overlay/caption | Required state |
|---:|---|---|---|---|
| 1 | Home after scan | **See the clutter before you touch it** | **Dokunmadan önce karmaşayı görün** | Corpus selected, exact groups and recoverable space visible |
| 2 | Exact review group | **Exact means byte-for-byte verified** | **Tam kopya, birebir doğrulanır** | Protected keeper, evidence, file metadata, review controls |
| 3 | Similar comparison | **Compare similar shots side by side** | **Benzer kareleri yan yana karşılaştırın** | Synchronized zoom/pan and advisory-only language visible |
| 4 | Safety Plan | **Review every move before it happens** | **Her taşıma işlemini önceden inceleyin** | Destinations, collisions, recoverability, no permanent-delete wording |
| 5 | History and restore | **Restore from an auditable history** | **Denetlenebilir geçmişten geri yükleyin** | Signed manifest/history and Restore action |
| 6 | Privacy / Pro | **Local by design. No subscription.** | **Yerel tasarım. Abonelik yok.** | No-account/no-upload copy and the real localized lifetime price |

## Screenshot QA

- [ ] All screenshots are from the same shipping build and localization.
- [ ] Exactly 2880 × 1800, RGB, no alpha channel.
- [ ] No personal filenames, paths, account names, mounted-volume names, or photo faces.
- [ ] No promise that similar photos are automatically deleted.
- [ ] No promise of direct permanent deletion from Apple Photos.
- [ ] No unconfigured price, trial, or Family Sharing claim.
- [ ] Text remains legible at App Store thumbnail size.
- [ ] Screens reflect current navigation and terminology.
- [ ] Turkish copy reviewed by a fluent human.
- [ ] Screenshots uploaded in the intended order for both localizations.

## Phase 5P candidate screenshot

Capture one Exact Review state with a non-keeper selected and **Decision Evidence** open. The image should clearly show a protected keeper, the "Verified exact copy" state, human-readable decision reason, and the existing reversible Safety Plan language. Do not show personal file-system paths or claim that similarity suggestions are safe to delete automatically.

## Phase 5Q shell-alignment screenshot

Capture Exact Review with both transient drawers **closed** so the full-width Review Floor and bottom Decision Shelf are unmistakable. A second candidate may show the temporary Evidence drawer open. Do not submit a screenshot that makes Cullora look like a permanent three-column admin dashboard. Verify clipped Archive Plate geometry and the horizontal Workspace Shelf are visible at thumbnail size.

## Phase 5R Safety Plan screenshot
Capture the real Safety Plan sheet showing the plan revision and `Current` freshness state, plus exact decision proof. For a QA-only alternate capture, use a controlled stale-plan fixture to show `Stale — regenerate` and the Regenerate Plan action; do not imply that stale plans can be committed.

## Phase I identity lock
Final compact, standard and expansive captures must preserve **Archive Review Studio** as the dominant silhouette.
