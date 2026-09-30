# Keptora — App Privacy Answers (Phase O Draft)

## Intended App Store Connect answer
- **Data collection:** Data Not Collected
- **Tracking:** No

## Fail-closed rule
This is a source-level draft, not a final App Store declaration. Reconfirm against the signed archive privacy report and every linked SDK/framework. If Mac fixes add telemetry, accounts, remote processing, crash/analytics SDKs, or user-data transmission, update the disclosure before submission.

## Verification checklist
- No analytics/ad SDK in final archive.
- No account or remote document upload introduced.
- StoreKit purchase state is handled without an independent purchaser profile.
- Support/privacy web navigation does not upload in-app documents.
- `PrivacyInfo.xcprivacy` remains consistent with required-reason API usage.
