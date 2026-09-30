# Alfago Lab website name sync

- **Cullora: Duplicate Cleaner** → `https://alfagolab.com/keptora`

## Consolidation status

Cullora is the active product for the former **AtlasTrace GPX** and **Aurelio Metadata** workflows. GPX journey/photo matching and metadata inspection/cleanup should be integrated here as separate photo-library modules.

Before App Store submission, confirm the native build contains every capability claimed on the website. Keep `/Users/khankartal/Desktop/alfagolab.com/PORTFOLIO_CONSOLIDATION.md` synchronized when scope or naming changes.

The App Store marketing, privacy and support pages are maintained in `/Users/khankartal/Desktop/alfagolab.com`.

If a shipping app name changes:

1. Update the app's real display name in its source project.
2. Keep the existing URL slug unless an intentional URL migration is planned.
3. Run `cd /Users/khankartal/Desktop/alfagolab.com && npm run sync:app-names`.
4. Build and publish the website before updating App Store Connect.

All support pages use `support@alfagolab.com`. Email links include the app name in the subject.
