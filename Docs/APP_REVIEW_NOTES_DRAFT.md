# App Review Notes Draft

## Product summary

Cullora is a sandboxed, local-first Mac utility for reviewing exact duplicate photo/media files in user-selected folders and external drives. It also shows visually similar images as advisory review groups. Similarity never authorizes cleanup.

## Account and network

- No account or sign-in is required.
- No photo/media upload occurs in the current build.
- No advertising or analytics SDK is present.
- StoreKit communication is used only for the non-consumable lifetime unlock and entitlement verification.

## Free and paid behavior

- Folder scanning is unlimited.
- The first 100 **unique** review decisions are free.
- Changing a decision for an already counted asset does not consume another free review.
- Cullora Pro unlocks unlimited review and Safety Plans.
- Restore remains available without a Pro entitlement so a user is never prevented from recovering their own files.

## Safety model

1. Exact groups are created only after SHA-256 confirms byte-for-byte equality.
2. One protected keeper is retained in each exact group.
3. Similar-image groups are review-only and cannot enter a Safety Plan.
4. The user reviews the full Safety Plan before any file is moved.
5. Approved files move to a reversible quarantine on the same volume.
6. Collisions do not overwrite existing files.
7. Cleanup history and signed manifests support restoration.
8. The app target contains no Apple Photos deletion API, Finder Trash command, or quarantine purge command.

## Suggested reviewer flow

1. Launch the app. Complete the three-page onboarding.
2. Click **Choose a Folder**.
3. Select the generated `Cullora_Review_Corpus` folder described in `REVIEW_CORPUS_README.md`.
4. Start a scan and open **Exact Review**.
5. Review an exact group and change a non-keeper asset to the cleanup decision.
6. Open **Similar Review** to inspect a side-by-side pair. Observe that no cleanup action is available there.
7. Return to Exact Review and open **Safety Plan**.
8. Inspect the proposed reversible moves, then commit the plan.
9. Open **History** and restore the plan.
10. Open **Settings → Diagnostics** to inspect the redacted local support export.
11. Open the Pro sheet and test the lifetime product using the StoreKit review environment.

## In-App Purchase

- Product type: Non-consumable.
- Product ID: `[REPLACE WITH FINAL PRODUCT ID]`.
- Display name draft: `Cullora Pro — Lifetime`.
- Description draft: `Unlimited review and reversible Safety Plans.`
- Family Sharing: planned; submit only after enabled and tested.
- The reviewer should not need a test account.

## Permissions

Cullora requests user-selected read/write access only after the reviewer chooses a source folder. Photo-library permission is not required for the basic review-corpus flow. Access can be revoked in macOS System Settings.

## Review contact

- Contact name: `[REVIEW CONTACT]`
- Email: `[REVIEW EMAIL]`
- Phone: `[REVIEW PHONE]`
- Notes URL or support URL: `[PUBLIC HTTPS URL]`

## Final pre-submission confirmation

- [ ] Replace every placeholder in this document.
- [ ] Confirm the exact button names against the Release build.
- [ ] Include a review screenshot for the IAP in App Store Connect.
- [ ] Verify that the corpus generator creates the same expected groups on the submitted build.
- [ ] Attach a short screen recording only when App Review needs help reproducing an edge case.
