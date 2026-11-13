# Keptora Phase 5Q QA Matrix

## Shell and usability

- Verify no permanent left navigation sidebar at 1240×800, 1440×900, 1728×1117, and a large external display.
- Verify Workspace Shelf remains horizontally usable without truncating the active route beyond recognition.
- Open/close Queue and Evidence drawers repeatedly; only one drawer should remain open at a time.
- Verify drawers do not resize the Review Floor and return focus sensibly when closed.
- Verify Decision Shelf remains reachable with Full Keyboard Access and never obscures the focused card.
- Verify narrow-window behavior before shipping; do not solve clipping by reintroducing permanent split panes.

## Exact review

- Select groups via Queue, close Queue, and complete review entirely on the full-width floor.
- Test `⌘[`, `⌘]`, `⌥←`, `⌥→`, `⌘1`, `⌘2`, `⌘3`, `⇧⌘P`, and `⇧⌘S`.
- Change keeper, inspect Decision Evidence, prepare Safety Plan, commit, then restore.
- Confirm digest mismatch before commit fails closed.

## Similar review

- Verify Queue and Evidence are available as transient review surfaces.
- Verify Decision Shelf is replaced by review-only language with no Keep/Add to Plan/Skip action.
- Verify synchronized zoom/pan and Reset View.

## Accessibility

- VoiceOver order: masthead → Workspace Shelf → Review command deck → Review Floor → Decision Shelf → transient drawer when opened.
- Drawer close buttons have explicit labels.
- Selected workspace and focused review asset announce selected state.
- Test Increase Contrast, Reduce Motion, light/dark appearance, and Full Keyboard Access.

## Visual master-lock rejection

Reject the release if the final Mac build again resembles a persistent left-sidebar + center-content + right-inspector admin shell, or if the full-width Review Floor ceases to be the dominant silhouette.
