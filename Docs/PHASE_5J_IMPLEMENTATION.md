# Phase 5J Implementation Notes

## 1. Synchronized Similar Comparison

`ReviewStudioView` now offers `Compare` and `Cards` layouts. Compare mode locks both panes to a shared zoom scale and pan offset, allowing crop, blur, compression, framing, and detail differences to be inspected at the same viewport. The user can select any non-anchor member, reset the viewport, reveal either source in Finder, and use keyboard zoom controls.

This feature remains evidence-only. It exposes no decision control and cannot create a Safety Plan entry.

## 2. Safe Similarity Sensitivity

Three presets are available:

- **Precision first:** strictest output; recommended default.
- **Balanced:** moderate review volume.
- **Discovery:** uses the persisted calibration envelope without widening it.

The preset modifies only review thresholds. The persisted pair-storage envelope stays unchanged so switching presets does not lose candidate pairs or require re-indexing. Every adjusted threshold is less than or equal to the calibrated/base threshold.

## 3. StoreKit 2

`StoreEntitlementController` implements:

- product loading,
- transaction-update observation,
- verified purchase completion,
- current-entitlement refresh,
- App Store sync/restore,
- revocation-aware lifetime state,
- user-visible pending, cancelled, unavailable, and error states.

The source intentionally ships with placeholder identifiers. Release validation fails until they are replaced and App Store Connect is configured.

## 4. Accessibility and Localization

Phase 5J adds semantic labels for preview images, synchronized comparison canvases, zoom level, and Finder reveal actions. Critical UI strings have Turkish catalog entries and the project declares `tr` as a known region.

This is infrastructure, not final linguistic or accessibility certification. VoiceOver traversal and clipped-layout QA require a Mac runtime.

## 5. Permanent Deletion Removal

A dormant `PhotoLibraryAdapter.delete` method used `PHAssetChangeRequest.deleteAssets`. Although not connected to UI or AppModel, it contradicted the product safety promise and was removed. Static release validation now rejects:

- `PHAssetChangeRequest.deleteAssets`
- `trashItem(`
- `FileManager.default.removeItem`

The reversible quarantine implementation uses coordinated moves and remains separate from permanent deletion.
