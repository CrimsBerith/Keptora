# Phase 5M App Review & Release Test Matrix

| ID | Scenario | Required result | Blocking |
|---|---|---|---|
| M-01 | Fresh launch | Safety onboarding appears once and can be reopened from Help | Yes |
| M-02 | Choose Folder | Prepared local review corpus is selected and the real scan begins | Yes |
| M-03 | Exact identity | Every exact group is byte-identical and keeps one protected canonical asset | Yes |
| M-04 | Similar boundary | Similar-photo mode exposes no cleanup or batch-plan action | Yes |
| M-05 | Focus shortcuts | `⌥←/⌥→` changes focused photo; `⌘1/2/3` uses the same model decision path as buttons | Yes |
| M-06 | Group shortcuts | `⌘[/⌘]` changes exact groups without losing persisted decisions | Yes |
| M-07 | Batch entitlement | A batch that would cross the free limit is rejected before any partial write | Yes |
| M-08 | Session checkpoint | Inactive/background state saves source, group, focused asset, and local progress | Yes |
| M-09 | Resume | Home card and `⌥⌘R` restore a valid checkpoint only for the same source identity | Yes |
| M-10 | Stale checkpoint | Missing group or changed source invalidates the checkpoint without changing decisions | Yes |
| M-11 | Safety Plan preview | Keeper, family, volume, collision, and manifest checks are visible before commit | Yes |
| M-12 | Quarantine commit | Only approved exact extras move to reversible same-volume quarantine | Yes |
| M-13 | Restore without Pro | Existing cleanup history can be restored even when entitlement is absent | Yes |
| M-14 | External volume disconnect | Scan/commit stops safely and does not reinterpret a replacement volume | Yes |
| M-15 | Diagnostics | Export redacts selected paths by default and contains no photo bytes | Yes |
| M-16 | StoreKit purchase | Non-consumable unlock, pending, cancel, verification failure, restore, refund/revocation are tested | Yes |
| M-17 | VoiceOver | Group state, focused photo, keeper, decisions, progress, and Safety Plan are announced | Yes |
| M-18 | Full Keyboard Access | Every action is reachable with visible focus and no keyboard trap | Yes |
| M-19 | Real corpus 10K/50K/100K | Memory remains bounded; pause/resume and restart preserve correctness | Yes |
| M-20 | App Store archive | Release archive includes privacy manifest, correct entitlements, signing, and final IDs | Yes |

## Evidence to retain

- `xcresult` for XCTest/UI tests
- static analyzer log
- release archive and exported entitlements
- StoreKit sandbox screenshots/log
- VoiceOver and Full Keyboard Access checklist
- real-library benchmark JSON/CSV
- App Review demo screen recording when needed
