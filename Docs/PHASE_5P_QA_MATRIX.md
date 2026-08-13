# Cullora Phase 5P — QA Matrix

| Area | Required check | Expected result |
|---|---|---|
| Exact review | Add non-keeper to plan | Decision Evidence = Verified exact copy |
| Keeper safety | Focus canonical keeper | Keeper shown protected; quarantine controls disabled |
| Keeper replacement | Select another keeper | New keeper becomes protected; previous keeper history remains reasoned |
| Digest safety | Change reviewed content before commit | Existing pre-move re-hash blocks mutation |
| Batch review | Plan Exact Extras | Every extra gets batch reason code; keeper excluded |
| Skip | Skip an exact copy | Evidence identifies reviewed skip; no cleanup candidate |
| Safety Plan | Prepare plan | Every operation has provenance count and human-readable reason |
| Export | Export plan JSON | Actor/reason/timestamp/canonical keeper encoded |
| Signed manifest | Commit | Schema 3 carries same decision provenance |
| Restore | Open old/new manifests | Existing schema-2 restore remains decodable; schema-3 restore verifies |
| Similarity | Review visually similar photos | No cleanup authorization or decision-evidence path |
| Family safety | Partial all-or-nothing family | Plan remains blocked |
| Accessibility | VoiceOver + Full Keyboard Access | Decision Evidence reachable and labels meaningful |
| Windowing | Small/large Mac windows | Sheet and review controls remain usable without clipping |
| Performance | 100K evidence smoke | Linear behavior; no O(n²) decision lookup |
| Release | Placeholder identifiers | Fail closed |
| Release | Real-format disposable identifiers | Static release gate passes |

## Mac-only mandatory checks

- Xcode semantic compile/link.
- XCTest/XCUITest execution.
- Product > Analyze.
- VoiceOver, Full Keyboard Access, Increase Contrast, Reduce Motion.
- Real 10K/50K/100K photo libraries and external-volume tests.
- StoreKit sandbox purchase/restore/revocation.
- Archive, Validate App, TestFlight.
