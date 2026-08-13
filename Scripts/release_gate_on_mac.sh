#!/usr/bin/env bash
set -euo pipefail
set -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This release gate requires macOS and Xcode." >&2
  exit 69
fi
command -v xcodebuild >/dev/null || { echo "xcodebuild not found" >&2; exit 69; }
./Scripts/validate_phase5s_static.py --release
./Scripts/validate_package.sh
mkdir -p ValidationArtifacts/Mac
mkdir -p Build
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/Build/DerivedData}"
rm -rf "$DERIVED_DATA_PATH" ValidationArtifacts/Mac/CulloraTests.xcresult
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT/Release/ExportOptions-AppStore.plist}"
if [[ ! -f "$EXPORT_OPTIONS_PLIST" ]]; then
  echo "Missing real App Store export options: $EXPORT_OPTIONS_PLIST" >&2
  echo "Copy Release/ExportOptions-AppStore.template.plist, set the real Team ID, and retry." >&2
  exit 69
fi
xcodebuild -version | tee ValidationArtifacts/Mac/xcode_version.txt
sw_vers | tee ValidationArtifacts/Mac/macos_version.txt
xcodebuild \
  -project Cullora.xcodeproj \
  -scheme Cullora \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -enableCodeCoverage YES \
  -resultBundlePath ValidationArtifacts/Mac/CulloraTests.xcresult \
  clean test | tee ValidationArtifacts/Mac/xcode_test.log
xcodebuild \
  -project Cullora.xcodeproj \
  -scheme Cullora \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  analyze | tee ValidationArtifacts/Mac/xcode_analyze.log
./Scripts/benchmark_vision_on_mac.sh | tee ValidationArtifacts/Mac/vision_benchmark.log
xcodebuild \
  -project Cullora.xcodeproj \
  -scheme Cullora \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ROOT/Build/Cullora.xcarchive" \
  archive | tee ValidationArtifacts/Mac/xcode_archive.log
rm -rf "$ROOT/Build/AppStoreExport"
xcodebuild -exportArchive \
  -archivePath "$ROOT/Build/Cullora.xcarchive" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$ROOT/Build/AppStoreExport" | tee ValidationArtifacts/Mac/xcode_export.log
APP="$ROOT/Build/Cullora.xcarchive/Products/Applications/Cullora.app"
test -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy" || { echo "Privacy manifest missing from archived app." >&2; exit 1; }
codesign -d --entitlements :- "$APP" > ValidationArtifacts/Mac/archive_entitlements.plist 2>&1
plutil -lint ValidationArtifacts/Mac/archive_entitlements.plist
printf '\nRelease gate completed. Inspect StoreKit sandbox, VoiceOver, real-library benchmarks, screenshots, App Store metadata, and TestFlight before submission.\n'
