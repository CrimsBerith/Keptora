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
7. Cleanup history and signed manifests support a read-only restore dry run before any restore mutation.
8. Restore is blocked when an original path is occupied, a quarantine file is missing, or content no longer matches the signed manifest.
9. The app target contains no Apple Photos deletion API, Finder Trash command, or quarantine purge command.

## Suggested reviewer flow

1. Launch the app and complete the three-page onboarding.
2. On **Library Health**, click **Choose Folder** and select the prepared review corpus.
3. Cullora generates synthetic photos inside its own Application Support container and runs the real incremental scanner. No network or account is used.
4. Open **Review Studio**. Use `⌘]` to move between exact groups and `⌥→` to move focus between photos.
5. Use `⌘2` on a focused non-keeper or click **Plan Exact Extras**. Observe that the protected keeper is never included.
6. Leave the app or navigate away, then use the Home resume card or `⌥⌘R` to return to the saved review checkpoint.
7. Open **Review Insights** to inspect local-only progress, planned recovery, and review pace.
8. Open **Similar** review. Observe that no Safety Plan action is available for visually similar photos.
9. Return to Exact review and prepare the **Safety Plan**.
10. Commit quarantine in the StoreKit review environment, open **Quarantine & Restore**, choose **Review Restore**, inspect the signed-manifest verification results, confirm, and restore the plan.
11. Open **Diagnostics** and export the redacted local support file.
12. Open the Pro sheet and test the non-consumable lifetime product.

For a manual-folder alternative, the generated `Cullora_Review_Corpus` described in `REVIEW_CORPUS_README.md` remains included in the handoff package.

## In-App Purchase

- Product type: Non-consumable.
- Product ID: `[REPLACE WITH FINAL PRODUCT ID]`.
- Display name draft: `Cullora Pro — Lifetime`.
- Description draft: `Unlimited review and reversible Safety Plans.`
- Family Sharing: disabled for 1.0.0.
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

## Phase 5P reviewer note — decision provenance

In Exact review, focus a reviewed photo and open **Decision Evidence**. Cullora explains the stored review action, reason, protected keeper, and SHA-256 exact-copy proof. When a Safety Plan is committed, this provenance is sealed into the signed schema-3 manifest. Similar-photo suggestions remain review-only and cannot enter a Safety Plan.

## Phase 5Q navigation note

The submitted build uses a horizontal **Workspace Shelf** rather than a permanent navigation sidebar. In Review Studio, **Queue** and **Evidence** open temporary edge drawers over the full-width review floor. Exact-photo actions are also available in the bottom **Decision Shelf**. Similar-photo mode replaces that action shelf with review-only language and exposes no cleanup action.

## Phase 5R Safety Plan freshness
Cullora snapshots the exact-review decision set when a Safety Plan is prepared. Immediately before quarantine commit, the app re-queries the current exact-review cleanup candidate set. If plan membership, the protected keeper, exact digest, decision reason/actor, or decision timestamp differs from the prepared snapshot, the plan is marked stale and no file move begins. The user must regenerate the Safety Plan. Similar-photo suggestions remain review-only and never enter the cleanup decision path.

## Phase 5S quarantine verification note
After a Safety Plan move or restore, Cullora independently re-reads its local operation state and re-hashes the expected file against the signed manifest. The History **Verify State** button is read-only: it does not move, delete, restore, or reclassify any file. “Verified” here means only that Cullora's recorded local state and SHA/byte-count evidence match the signed cleanup manifest at the time of that check; it is not a backup guarantee or external certification.
