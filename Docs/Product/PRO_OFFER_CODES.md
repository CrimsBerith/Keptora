# Keptora Pro offer codes

Keptora uses Apple StoreKit offer codes for its existing lifetime, non-consumable Pro
purchase. Codes are created and distributed in App Store Connect; Keptora does not
embed a shared secret, collect codes in a custom text field, or require a Keptora account.

## Create and distribute codes

1. In App Store Connect, open Keptora’s existing lifetime in-app purchase.
2. Create an offer code for that product. Choose one-time-use codes or a custom code,
   configure the offer as free, and set availability and expiration as needed.
3. Download and distribute the codes from App Store Connect. Keep unused code exports private.
4. Test with sandbox codes before distributing production codes.

Customers can redeem through **Redeem Pro Code** in Keptora on iOS and macOS 15 or later.
On macOS 13–14, redeem on an iPhone or iPad with the same Apple Account, then choose
**Restore Purchases** in Keptora.
StoreKit delivers the verified lifetime transaction; Keptora’s transaction listener and
current-entitlement check unlock Pro for the same Apple Account.

Offer codes do not add a subscription or alter the lifetime product. Code creation,
expiration, and distribution remain App Store Connect operations and are not performed by
the app or this repository.

## Apple references

- [Supporting offer codes in your app](https://developer.apple.com/documentation/storekit/supporting-offer-codes-in-your-app)
- [SwiftUI offer-code redemption sheet](https://developer.apple.com/documentation/swiftui/view/offercoderedemption(ispresented:oncompletion:))
- [Create offer codes for Apple In-App Purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-offer-codes-for-in-app-purchases)
