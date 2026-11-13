# Alfago Lab website sync

- **Keptora** (iPhone and Mac) → `https://alfagolab.com/keptora`
- Privacy: `https://alfagolab.com/keptora/privacy` — source text in [AppStore/PRIVACY_POLICY.md](AppStore/PRIVACY_POLICY.md)
- Support: `https://alfagolab.com/keptora/support` — source text in [AppStore/SUPPORT_PAGE.md](AppStore/SUPPORT_PAGE.md)

The App Store marketing, privacy and support pages are maintained in the website repository (`/Users/khankartal/Desktop/alfagolab.com`, a link to the external `DATA` volume).

## Open item (13 October 2026)

The published privacy and support pages still describe the earlier Mac-only "Keptora: Duplicate Cleaner" with a quarantine workflow. Replace them with the current texts above, which cover iPhone and Mac, Recently Deleted for Photos and the recovery folder for files, before submitting to App Store review.

## When the app name changes

1. Update the app's display name in `Keptora/Resources/Info.plist` and `KeptoraiOS/Resources/Info.plist`.
2. Keep the existing URL slug unless an intentional URL migration is planned.
3. Run `cd /Users/khankartal/Desktop/alfagolab.com && npm run sync:app-names`.
4. Build and publish the website before updating App Store Connect.

All support pages use `support@alfagolab.com`. Email links include the app name in the subject.
