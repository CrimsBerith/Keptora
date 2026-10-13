# Keptora 1.0.0 (182) App Review Notes

## Product and platforms

Keptora is a universal iPhone and Mac photo and video cleaner. People browse their Apple Photos library or a folder they choose, select any items by hand or with suggestions (exact copies, very similar shots, screenshots, large videos, Live Photos, blurry or dark photos), review the selection, and remove it. The same non-consumable Keptora Pro entitlement is used on both platforms. There is no account, advertising, analytics SDK or photo upload.

## Safety rules

1. Exact copies require SHA-256 verification of the original resource bytes.
2. Suggested batch actions (Select Extra Copies, Select Others) keep one suggested item in every group and never select protected items.
3. Similar-photo suggestions are never removed automatically; the user must select them.
4. Nothing is removed until the user confirms the final review screen, which lists every item, its source and how it can be recovered.
5. Selections persist and can be undone; the review screen also lets the user take items out of the selection.

## Removal and recovery

- **Apple Photos:** after Keptora’s review screen, iOS/macOS shows Apple’s own deletion confirmation. Items move to Recently Deleted (up to 30 days). With iCloud Photos the change syncs to the user’s other devices. Recovery happens in the Photos app; History links there.
- **Folders:** files move to a recovery folder on the same storage and are recorded in History. **Restore Files** puts them back and stops instead of overwriting if the original path is occupied.

## iCloud and permissions

- Photos permission is requested only after the user chooses Apple Photos. Limited access is supported and offers Manage Access.
- iCloud-only originals are not downloaded during a normal scan. **Include Cloud Originals** asks for separate confirmation.
- Folder access uses the system folder picker and security-scoped bookmarks.

## Suggested review flow

### iPhone

1. Skip or finish the three-page introduction. On the source screen, choose **Open Photos** (or choose a folder) and allow access.
2. In **Photo Library**, tap **Start Scan**. Results appear while the scan runs.
3. Tap **Exact Copies**, then **Select Extra Copies**. The suggested photo in each group stays unselected and is labeled.
4. Touch and hold any photo to see it larger; tap photos to add or remove them from the selection.
5. Tap **Review Selection**, check the list, then **Remove**. Confirm Apple’s Photos prompt.
6. Open **History** to see the entry, or the **Suggestions** tab for screenshots, large videos and other categories.

### Mac

1. In the startup sheet, connect Apple Photos or choose **Add Folder…** (⌘O). Folders can also be dragged onto the window.
2. Choose **Start Scan** (⌘R).
3. Switch the library view to **Exact Copies** and choose **Select Extra Copies**, or click photos to select them.
4. Choose **Review Selection**, then **Remove** and confirm.
5. For folder items, open **History** and choose **Restore Files**.
6. **Keptora ▸ Settings…** contains Restore Purchases, language, support links and diagnostics export.

## In-App Purchase

- Type: Non-consumable.
- Product ID: `com.keptora.app.pro.lifetime`.
- Display name: `Keptora Pro Lifetime`.
- What it unlocks: automatic selection of suggestions beyond the first 100 items. Browsing, manual selection, removal and recovery are free.
- Family Sharing: disabled.
- Restore Purchases is available on the Pro screen and in Settings on both platforms.

## Owner-supplied submission fields still required

- Review contact name, email and phone.
- Signed Mac/iPhone archive validation, TestFlight build, IAP review screenshot and final localized screenshots.

Support: `https://alfagolab.com/keptora/support`
Privacy: `https://alfagolab.com/keptora/privacy`
