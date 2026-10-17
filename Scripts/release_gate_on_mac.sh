#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS and Xcode are required.' >&2; exit 69; }
PYTHON="${PYTHON:-python3}"
command -v xcodebuild >/dev/null || { echo 'xcodebuild not found' >&2; exit 69; }
# Each run owns its output; never delete existing archives or test evidence.
OUTPUT="${RELEASE_OUTPUT_ROOT:-$ROOT/ValidationArtifacts/Mac/run-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT/DerivedData}"
IOS_SIMULATOR_ID="${IOS_SIMULATOR_ID:-$(xcrun simctl list devices available -j | "$PYTHON" -c 'import json,sys; print(next(d["udid"] for runtime, devices in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in devices if d.get("isAvailable") and "iPhone" in d["name"]))')}"
IOS_DESTINATION="platform=iOS Simulator,id=$IOS_SIMULATOR_ID"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT/Release/ExportOptions-AppStore.plist}"
[[ -f "$EXPORT_OPTIONS_PLIST" ]] || { echo "Missing export options: $EXPORT_OPTIONS_PLIST" >&2; exit 69; }
run_xcode() {
  local label="$1"
  shift
  "$PYTHON" Scripts/run_bounded.py --timeout "${XCODE_GATE_TIMEOUT_SECONDS:-1200}" \
    --log "$OUTPUT/$label.log" -- xcodebuild "$@"
}
common=(-project Keptora.xcodeproj -derivedDataPath "$DERIVED_DATA_PATH")
tests=(-parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 360)
bash Scripts/validate_package.sh
xcodebuild -version > "$OUTPUT/xcode_version.txt"
sw_vers > "$OUTPUT/macos_version.txt"
# Release optimization and test-only hooks; shipping archives use plain Release.
run_xcode mac-unit "${common[@]}" -scheme Keptora -configuration ReleaseTesting \
  -destination 'platform=macOS' "${tests[@]}" -only-testing:KeptoraTests \
  -resultBundlePath "$OUTPUT/MacTests.xcresult" test
# Native PhotoKit integration tests require actual imported media and permission.
KEPTORA_SIMULATOR_ID="$IOS_SIMULATOR_ID" KEPTORA_DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
  KEPTORA_TEST_CONFIGURATION=ReleaseTesting bash Scripts/prepare_photo_cleaner_simulator.sh > "$OUTPUT/simulator-setup.log" 2>&1
run_xcode ios-permission "${common[@]}" -scheme KeptoraiOS -configuration ReleaseTesting \
  -destination "$IOS_DESTINATION" "${tests[@]}" \
  -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testGrantPhotosAccessForRealMedia \
  -resultBundlePath "$OUTPUT/iPhonePermission.xcresult" test-without-building
run_xcode ios-unit "${common[@]}" -scheme KeptoraiOS -configuration ReleaseTesting \
  -destination "$IOS_DESTINATION" "${tests[@]}" -only-testing:KeptoraiOSTests \
  -resultBundlePath "$OUTPUT/iPhoneTests.xcresult" test
run_xcode mac-ui "${common[@]}" -scheme Keptora -configuration Debug \
  -destination 'platform=macOS' "${tests[@]}" \
  -only-testing:KeptoraUITests/KeptoraUITests/testStartupSetupCanContinueWithDeniedPhotos \
  -only-testing:KeptoraUITests/KeptoraUITests/testUnifiedMacScanSelectionReviewUndoAndRestore \
  -only-testing:KeptoraUITests/KeptoraUITests/testUnifiedMacRestoreFailureIsVisibleAndDoesNotOverwriteOriginal \
  -only-testing:KeptoraUITests/KeptoraUITests/testUnifiedMacSearchDoesNotLoseSelectionOrHijackTextUndo \
  -only-testing:KeptoraUITests/KeptoraUITests/testUnifiedMacGallerySupportsMultiStepKeyboardUndoRedo \
  -only-testing:KeptoraUITests/KeptoraUITests/testSettingsWindowOffersLanguagePurchasesAndSupport \
  -resultBundlePath "$OUTPUT/MacUITests.xcresult" test
run_xcode ios-ui "${common[@]}" -scheme KeptoraiOS -configuration Debug \
  -destination "$IOS_DESTINATION" "${tests[@]}" \
  -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testSelectionActionsHaveAccessibleTargetsAndDoNotOverlap \
  -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testFinalReviewRemovalCanBeUndoneEvenWhenEmpty \
  -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testSettingsReplacesItselfWithPaywallAndBothCanClose \
  -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testPrimaryTabLabelsAreLocalizedInFourLanguages \
  -resultBundlePath "$OUTPUT/iPhoneUITests.xcresult" test
run_xcode mac-analyze "${common[@]}" -scheme Keptora -configuration Release -destination 'platform=macOS' analyze
run_xcode ios-analyze "${common[@]}" -scheme KeptoraiOS -configuration Release -destination 'generic/platform=iOS' analyze
KEPTORA_BENCHMARK_ITEMS="${KEPTORA_BENCHMARK_ITEMS:-3000}" \
  KEPTORA_BENCHMARK_OUTPUT="$OUTPUT/native-analysis-benchmark.json" \
  swift test --package-path Packages/KeptoraCore --filter NativeAnalysisBenchmarkTests > "$OUTPUT/benchmark.log" 2>&1
run_xcode mac-archive "${common[@]}" -scheme Keptora -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$OUTPUT/Keptora.xcarchive" archive
run_xcode ios-archive "${common[@]}" -scheme KeptoraiOS -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUTPUT/Keptora-iOS.xcarchive" archive
run_xcode mac-export -exportArchive -archivePath "$OUTPUT/Keptora.xcarchive" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" -exportPath "$OUTPUT/AppStoreExport" -allowProvisioningUpdates
run_xcode ios-export -exportArchive -archivePath "$OUTPUT/Keptora-iOS.xcarchive" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" -exportPath "$OUTPUT/iOSAppStoreExport" -allowProvisioningUpdates
APP="$OUTPUT/Keptora.xcarchive/Products/Applications/Keptora.app"
test -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
test -f "$OUTPUT/Keptora-iOS.xcarchive/Products/Applications/Keptora.app/PrivacyInfo.xcprivacy"
codesign -d --entitlements :- "$APP" > "$OUTPUT/archive_entitlements.plist" 2> "$OUTPUT/codesign.log"
plutil -lint "$OUTPUT/archive_entitlements.plist"
printf 'Release gate passed. Evidence: %s\nPhysical device, real StoreKit sandbox and App Review acceptance remain separate.\n' "$OUTPUT"
