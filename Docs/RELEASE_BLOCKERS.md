# Release Blockers — Keptora 1.0.0 (181)

These are mandatory blockers:

1. No real macOS SDK compile, XCTest, analyzer, or archive has run in this environment.
2. Bundle ID, Development Team, and lifetime product ID remain placeholders until configured.
3. Public privacy/support/marketing URLs, legal identity, support contact, and review contact remain placeholders.
4. App Store Connect record, agreements, tax, banking, regional business disclosures, categories, age rating, rights, and export answers are not configured here.
5. StoreKit local/sandbox purchase, pending, cancel, offline, restore, refund/revocation, second-Mac, and Family Sharing tests are incomplete.
6. Real product price and launch-price scheduling are not configured.
7. VoiceOver, Full Keyboard Access, accessibility settings, and fluent Turkish QA require a Mac/human pass.
8. Similarity thresholds still require a human-labelled real-photo approval corpus.
9. Real 10K/50K/100K performance, memory, thermal, cancellation, external-volume, low-disk, and force-quit matrices are incomplete.
10. Screenshots must be captured from the final signed-equivalent build.
11. Archive privacy report and all linked SDK manifests must be reconciled with App Privacy answers.
12. Code signing, archive export validation, upload, TestFlight/beta, and App Review submission are pending.
13. Keptora trademark/domain/App Store name clearance is pending.

The 1,045-app research metadata backfill is not a Keptora release blocker. Static validation passing is not evidence that these blockers passed.

14. Batch review actions require real XCTest/UI validation with free-limit boundaries and rapid repeated clicks.
15. New Review Insights and filters require VoiceOver, Full Keyboard Access, empty-state, and 100K-group UI responsiveness checks.
16. The on-device sample-library generator must be exercised in a sandboxed Release build and verified not to retain stale test files across upgrades.
17. Review checkpoint behavior must be tested across app inactive/background/quit, source changes, missing groups, and external-volume reconnects.
18. Global review shortcuts must be verified in exact vs. similar mode and against standard macOS menu conflicts.


19. Safety Plan JSON export requires sandboxed NSSavePanel and redaction review on a real Mac.
20. Custom exclusion rules require Unicode, case-folding, nested-volume and path-boundary UI tests.
21. Explicit confirmation and filtered 10K-operation plan preview require VoiceOver and performance validation.


22. Verified Restore must be exercised with occupied original paths, missing quarantine files, tampered quarantine content, partial restores, and external-volume replacement on a real Mac.
23. Restore Preview re-hashes every eligible file; 1K/10K operation latency, cancellation, memory, and UI responsiveness require Instruments validation.
24. The 300-row incremental rendering path requires VoiceOver focus, search/sort reset, and keyboard navigation QA.
25. Local performance history export must be reviewed for App Sandbox NSSavePanel behavior and confirmed to contain no paths or filenames in a Release build.

## Release candidate identity

- Target channel: Mac App Store.
- Marketing version/build: `1.0.0 (181)`.
- Supported platform: Apple Silicon, macOS 13+.
- Release mode: manual release with first-week monitoring.
- Family Sharing: disabled for the 1.0.0 lifetime non-consumable.
