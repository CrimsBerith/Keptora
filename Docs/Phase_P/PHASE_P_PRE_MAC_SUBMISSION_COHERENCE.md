# Cullora — Phase P Pre-Mac Submission Coherence

Phase P closes avoidable cross-file drift before the project reaches a real Mac. It does not fabricate developer identity or runtime evidence.

## Source-side closures
- `LSApplicationCategoryType` is aligned to the canonical App Store category: `public.app-category.utilities`.
- StoreKit product identifier is checked against `APP_LIFETIME_PRODUCT_ID`.
- Privacy manifest and entitlements must remain present.
- Every planned App Store screenshot maps to a product-specific screen/asset provenance record.
- Metadata source limits are checked before App Store Connect entry.
- Real developer identity, URLs, legal/price decisions and Mac evidence remain fail-closed.
- Existing app icon assets remain subject to final compiled visual verification on Mac.

## Gate
```bash
python3 Scripts/validate_phase_p_pre_mac.py
```
