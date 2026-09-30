#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RECEIPT="${1:-$ROOT/ValidationArtifacts/ReleaseCandidate/phase_h_receipt.txt}"
OUT_DIR="${2:-$ROOT/ValidationArtifacts/ReleaseCandidate/Evidence}"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Phase H evidence validation requires macOS" >&2; exit 60; }
for tool in codesign plutil xcodebuild; do command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 61; }; done
[[ -s "$RECEIPT" ]] || { echo "missing Phase H receipt: $RECEIPT" >&2; exit 62; }
grep -Fq 'status=ARCHIVE_LOCAL_SIGNATURE_PASS_VALIDATE_APP_PENDING' "$RECEIPT" || { echo "Phase H receipt is not in expected state" >&2; exit 63; }
ARCHIVE_PATH="$(awk -F= '$1=="archive"{print substr($0,index($0,"=")+1)}' "$RECEIPT" | tail -1)"
APP_PATH="$(awk -F= '$1=="app_path"{print substr($0,index($0,"=")+1)}' "$RECEIPT" | tail -1)"
[[ -d "$ARCHIVE_PATH" ]] || { echo "archive missing: $ARCHIVE_PATH" >&2; exit 64; }
[[ -d "$APP_PATH" ]] || { echo "archived app missing: $APP_PATH" >&2; exit 65; }
INFO="$APP_PATH/Contents/Info.plist"
[[ -s "$INFO" ]] || { echo "Info.plist missing" >&2; exit 66; }
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$INFO")"
SHORT_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO")"
BUILD_VERSION="$(plutil -extract CFBundleVersion raw -o - "$INFO")"
[[ -n "$BUNDLE_ID" && -n "$SHORT_VERSION" && -n "$BUILD_VERSION" ]] || { echo "bundle/version metadata incomplete" >&2; exit 67; }
case "$BUNDLE_ID" in *example*|*yourcompany*|*placeholder*|*REPLACE*|*replace*) echo "placeholder bundle id: $BUNDLE_ID" >&2; exit 68;; esac
codesign --verify --deep --strict "$APP_PATH"
mkdir -p "$OUT_DIR"
codesign -dv --verbose=4 "$APP_PATH" >"$OUT_DIR/codesign_details.txt" 2>&1 || true
codesign -d --entitlements :- "$APP_PATH" >"$OUT_DIR/entitlements.plist" 2>/dev/null || true
[[ -s "$OUT_DIR/entitlements.plist" ]] || { echo "archived entitlements missing" >&2; exit 69; }
SANDBOX="$(plutil -extract com.apple.security.app-sandbox raw -o - "$OUT_DIR/entitlements.plist" 2>/dev/null || true)"
[[ "$SANDBOX" == "true" || "$SANDBOX" == "1" ]] || { echo "App Sandbox entitlement missing/false" >&2; exit 70; }
PRIVACY_COUNT="$(find "$APP_PATH" -name 'PrivacyInfo.xcprivacy' -type f | wc -l | tr -d ' ')"
[[ "$PRIVACY_COUNT" -ge 1 ]] || { echo "PrivacyInfo.xcprivacy not embedded in archive" >&2; exit 71; }
{
  echo "APP=Keptora"
  echo "SHELL_IDENTITY=Archive Review Studio"
  echo "PROJECT=Keptora.xcodeproj"
  echo "SCHEME=Keptora"
  echo "BUNDLE_ID=$BUNDLE_ID"
  echo "SHORT_VERSION=$SHORT_VERSION"
  echo "BUILD_VERSION=$BUILD_VERSION"
  echo "PRIVACY_MANIFEST_COUNT=$PRIVACY_COUNT"
  echo "CODESIGN_STRICT=PASS"
  echo "APP_SANDBOX=PASS"
  echo "RESULT=PASS"
} >"$OUT_DIR/phase_h_archive_evidence.txt"
echo "PHASE_H_ARCHIVE_EVIDENCE_PASS app=Keptora"
