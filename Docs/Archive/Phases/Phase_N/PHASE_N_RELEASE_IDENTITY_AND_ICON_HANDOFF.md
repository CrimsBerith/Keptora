# Phase N — Release Identity + Final Asset Intake

Phase N removes avoidable manual edits before the Mac handoff. It adds a deterministic developer-input contract, one-command bundle/team/IAP/URL application, and a final AppIcon intake pipeline.

## Operator flow
1. Copy `Release/phase_n_release_inputs.template.json` to `Release/phase_n_release_inputs.local.json`.
2. Fill only confirmed Apple Developer / developer-owned HTTPS values. Never invent them.
3. If this package has an external final-icon blocker, place approved 1024×1024 artwork at `AppStore/AppIcon/source-1024.png`.
4. Run `./Scripts/prepare_phase_n_for_mac.sh`.
5. Run all existing Phase I/J/K/L/M gates, then proceed to the Mac/Xcode closure runbook.

## Safety
The source package remains fail-closed while Team ID, bundle ID, IAP ID, developer URLs or final artwork are unresolved. Phase N does not claim signing, Archive, Instruments, StoreKit sandbox, App Store Connect acceptance or final visual approval.
