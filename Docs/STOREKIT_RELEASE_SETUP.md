# StoreKit and App Store Connect Setup

## Required identifiers

The package contains placeholders:

- App bundle: `com.yourcompany.cullora`
- Lifetime product: `com.yourcompany.cullora.pro.lifetime`
- Development team: empty

Replace them with:

```bash
./Scripts/configure_release_identifiers.sh \
  <APP_BUNDLE_ID> \
  <DEVELOPMENT_TEAM_ID> \
  <LIFETIME_PRODUCT_ID>
```

The script updates the Xcode project, test bundle ID, StoreKit configuration, and StoreKit 2 source constant together.

## App Store Connect product

Create a **Non-Consumable** product with the exact configured product ID.

Recommended working configuration:

- Reference name: Cullora Pro Lifetime
- US price target: USD 24.99
- Family Sharing: disabled for 1.0.0; do not enable in App Store Connect.
- English and Turkish display metadata
- Review screenshot showing the upgrade surface

The final price, territories, tax category, agreements, and banking status must be confirmed in App Store Connect.

## Required StoreKit test matrix

- Local StoreKit configuration purchase
- Sandbox purchase
- User cancellation
- Ask to Buy / pending
- Network unavailable during product load
- Network unavailable after verified transaction
- Restore on a clean install
- Same Apple Account on another Mac
- Revoked/refunded transaction
- Family Sharing entitlement
- App launch while offline with prior entitlement
- Product not approved or unavailable in storefront

Do not gate user-owned files, restore, diagnostics, or safety recovery behind the purchase state. Entitlement should control premium limits only.
