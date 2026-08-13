# Accessibility and Localization QA

## Implemented foundation

- Semantic labels for image previews and synchronized comparison panes.
- Accessible comparison zoom value.
- Accessible Finder reveal controls.
- Keyboard shortcuts for folder selection, read-only scan, similarity analysis, zoom, and viewport reset.
- English source language and Turkish critical-string translations.
- English/Turkish StoreKit product metadata in the local configuration.

## Required Mac QA

- VoiceOver order through sidebar, group list, compare controls, panes, and inspector.
- Full Keyboard Access with no pointer.
- Focus visibility in both light and dark appearance.
- Increase Contrast and Differentiate Without Color.
- Reduce Motion.
- Large accessibility text and window widths from minimum to full screen.
- Turkish truncation, pluralization, date/number formatting, and menu shortcuts.
- Permission dialogs and error alerts read correctly.
- Safety Plan and restore confirmation announce irreversible/reversible consequences accurately.

## Localization rule

Do not concatenate translated sentence fragments. Dynamic counts should be migrated to plural-aware string catalog entries before final localization freeze.
