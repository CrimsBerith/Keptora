# App Store Submission Checklist — Cullora 1.0.0 (181)

## Legal and business

- [ ] Apple Developer Program membership active.
- [ ] Agreements, tax, and banking complete.
- [ ] DSA trader status and regional business disclosures complete where required.
- [ ] Cullora name, icon, domain, and marketing claims cleared for launch regions.
- [ ] Public privacy, support, and marketing URLs live over HTTPS.

## App record and identity

- [ ] App record created with the final bundle ID.
- [ ] Bundle ID, Team ID, App Store Connect record, Xcode project, and archive match.
- [ ] Version `1.0.0`, build `181`, copyright, categories, and age rating entered.
- [ ] Export-compliance answers reviewed for the actual binary.
- [ ] Content-rights answers reviewed.

## In-App Purchase

- [ ] Non-consumable product created with the exact source product ID.
- [ ] Localized display name and description entered.
- [ ] Price tier and launch-price timing approved.
- [ ] Family Sharing disabled for 1.0.0.
- [ ] IAP review screenshot uploaded.
- [ ] IAP submitted with the first app version.
- [ ] Sandbox purchase, cancel, pending, offline launch, restore, refund/revocation, and Family Sharing tested.

## Build quality

- [ ] `Scripts/release_gate_on_mac.sh` passes on the archived commit/package.
- [ ] XCTest, static analyzer, Release archive, privacy manifest inspection, and entitlement inspection pass.
- [ ] No placeholder identifiers or URLs remain.
- [ ] No forbidden permanent-delete API appears in the app target.
- [ ] Restore works without Pro.
- [ ] Force-quit, external-drive disconnect, low-disk, corrupted-file, and collision tests pass.
- [ ] Real 10K/50K/100K performance evidence recorded.

## Accessibility and localization

- [ ] VoiceOver, Full Keyboard Access, Increase Contrast, Reduce Motion, dark mode, and text scaling tested.
- [ ] English and Turkish UI reviewed on a real Mac.
- [ ] Accessibility nutrition-label answers entered only for features actually verified.
- [ ] Dates, file sizes, currency, and plurals use locale-aware formatting.

## Product page

- [ ] Name/subtitle/keywords validated by `Scripts/validate_app_store_metadata.py`.
- [ ] Descriptions match the actual Release build.
- [ ] Six real screenshots captured at one accepted 16:10 size.
- [ ] Screenshot copy contains no unsupported claims or personal information.
- [ ] Privacy label matches the archive and all SDK manifests.
- [ ] App Review notes contain exact reproduction steps and contact details.

## Submission and release

- [ ] Build uploaded and processing completed without warnings.
- [ ] App Store Connect build selected.
- [ ] IAP attached to the version.
- [ ] App Review notes and corpus instructions pasted.
- [ ] Manual release or phased release strategy chosen.
- [ ] Support monitoring and rollback/response plan active for launch week.
