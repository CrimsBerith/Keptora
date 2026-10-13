#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'An Apple host with Xcode and an iPhone simulator is required.' >&2
  exit 69
fi
KEPTORA_SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
devices = json.load(sys.stdin)["devices"]
phones = [d for runtime, items in devices.items() if "iOS" in runtime for d in items if d.get("isAvailable") and "iPhone" in d["name"]]
if not phones: raise SystemExit("No available iPhone simulator")
print(phones[0]["udid"])
')"
export KEPTORA_SIMULATOR_ID
if ! xcrun simctl list devices booted -j | python3 -c 'import json,sys; sys.exit(0 if any(d["udid"] == sys.argv[1] for ds in json.load(sys.stdin)["devices"].values() for d in ds) else 1)' "$KEPTORA_SIMULATOR_ID"; then
  xcrun simctl boot "$KEPTORA_SIMULATOR_ID"
fi
xcrun simctl bootstatus "$KEPTORA_SIMULATOR_ID" -b
xcrun simctl addmedia "$KEPTORA_SIMULATOR_ID" \
  AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Original.jpg \
  AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Copy_1.jpg \
  AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Copy_2.jpg \
  AppStore/Generated/Keptora_Review_Corpus/Exact/Beach_Original.jpg \
  AppStore/Generated/Keptora_Review_Corpus/Exact/Beach_Copy.jpg
xcodebuild -project Keptora.xcodeproj -scheme KeptoraiOS \
  -destination "platform=iOS Simulator,id=$KEPTORA_SIMULATOR_ID" \
  -derivedDataPath Build/CI CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build-for-testing
KEPTORA_APP=Build/CI/Build/Products/Debug-iphonesimulator/KeptoraiOS.app
if [[ ! -d "$KEPTORA_APP" ]]; then
  KEPTORA_APP=Build/CI/Build/Products/Debug-iphonesimulator/Keptora.app
fi
KEPTORA_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$KEPTORA_APP/Info.plist")"
xcrun simctl install "$KEPTORA_SIMULATOR_ID" "$KEPTORA_APP"
xcrun simctl privacy "$KEPTORA_SIMULATOR_ID" grant photos "$KEPTORA_BUNDLE_ID"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'KEPTORA_SIMULATOR_ID=%s\n' "$KEPTORA_SIMULATOR_ID" >> "$GITHUB_ENV"
fi
echo "Simulator prepared: $KEPTORA_SIMULATOR_ID"
