# Keptora 1.0.0 (182) App Review Notes

## Product and platforms

Keptora is a universal Mac and iPhone utility for finding byte-for-byte exact photo/video copies, reviewing visually similar photos, and manually reviewing similar-video suggestions. The same non-consumable Keptora Pro entitlement is used on both platforms. No account, advertising, analytics SDK, or photo upload is present.

## Exact-copy safety

1. Exact groups require SHA-256 verification of original resource bytes.
2. Live Photo, RAW/JPEG, and paired original resources are fingerprinted as a deterministic composite asset.
3. Every exact group retains a protected keeper.
4. Favorites, hidden or adjusted Photos assets, shared sources, and user-album members are excluded from global safe selection.
5. Similar photos expose no cleanup action. Similar-video suggestions require explicit manual selection and never receive automatic cleanup authority.
6. The selected content is re-hashed immediately before a folder move or Photos removal.

## Cleanup behavior

- Mac and iPhone folders: when the selected volume/File Provider supports safe coordinated writes, approved exact copies move to `.Keptora Quarantine`. Restore stops if the original path is occupied, quarantine content is missing, or its digest changed.
- Apple Photos: approved exact copies are removed only after Keptora's summary and Apple's system confirmation. They appear in Recently Deleted. With iCloud Photos, the change synchronizes to the user's other devices. Recovery occurs in Apple Photos, not inside Keptora.
- Keptora never offers cleanup for visually similar photos.
- Similar videos are never auto-selected. The reviewer must tap each candidate or use the clearly labeled safe-selection action; Keptora protects one keeper and metadata-sensitive assets, then rehashes every selected original before requesting cleanup.

## iCloud and permissions

- Photos permission is requested only after the user selects Apple Photos.
- Limited Photos access is supported and includes a Manage Access action.
- iCloud-only originals are not downloaded during the default scan. Network access requires a separate confirmation.
- iPhone folder access uses the system directory picker and a security-scoped bookmark. The scan checkpoints when the app leaves the foreground and resumes after source access is restored.

## Suggested review flow

### Mac

1. Choose the supplied review corpus from Library.
2. Open Review and inspect Exact and Similar modes.
3. Select safe copies; confirm the protected keeper remains unselected.
4. Review and commit the Safety Plan, then use History to verify and restore the quarantine record.

### iPhone

1. Choose Apple Photos or a folder through Files.
2. Run Scan and open Review.
3. Switch between Photos and Videos, then use card, checkbox, group, and safe-all selection on an exact group.
4. Verify similar photos have no cleanup control. In Similar > Videos, manually select a non-keeper candidate and verify the keeper remains locked.
5. For Photos, continue through Apple's system deletion confirmation and recover from Photos > Recently Deleted. For Files, use Keptora History to restore a quarantine record.

## In-App Purchase

- Type: Non-consumable.
- Product ID: `com.keptora.app.pro.lifetime`.
- Display name: `Keptora Pro Lifetime`.
- Family Sharing: disabled.
- Restore Purchases remains visible on both platforms.

## Owner-supplied submission fields still required

- Real Bundle ID and Apple Development Team.
- Review contact name, email, and phone.
- Signed Mac/iPhone archive validation, TestFlight build, IAP review screenshot, and final localized screenshots.

Support: `https://alfagolab.com/keptora/support`
Privacy: `https://alfagolab.com/keptora/privacy`
