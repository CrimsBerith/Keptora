#!/usr/bin/env python3
from pathlib import Path
import json
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

def need(condition, message):
    if not condition:
        errors.append(message)

project = (ROOT / "Keptora.xcodeproj/project.pbxproj").read_text(errors="replace")
spec = (ROOT / "project.yml").read_text(errors="replace")
metadata = json.loads((ROOT / "AppStore/app_store_metadata.json").read_text())
storekit = json.loads((ROOT / "Keptora/Resources/Keptora.storekit").read_text())
mac_info = plistlib.loads((ROOT / "Keptora/Resources/Info.plist").read_bytes())
ios_info = plistlib.loads((ROOT / "KeptoraiOS/Resources/Info.plist").read_bytes())

need(metadata.get("release", {}).get("marketing_version") == "1.0.0", "metadata version must be 1.0.0")
need(str(metadata.get("release", {}).get("build_number")) == "182", "metadata build must be 182")
need('MARKETING_VERSION: 1.0.0' in spec, "Xcode spec version must be 1.0.0")
need('CURRENT_PROJECT_VERSION: "182"' in spec, "Xcode spec build must be 182")
need('deploymentTarget: "17.0"' in spec, "iOS minimum must be 17.0")
need('TARGETED_DEVICE_FAMILY: "1"' in spec, "iOS target must be iPhone-only for 1.0")
need("KeptoraiOS" in project and "KeptoraiOSTests" in project and "KeptoraiOSUITests" in project, "iOS app/test targets missing")
need("KeptoraCore" in project, "shared KeptoraCore package missing")

product = storekit.get("products", [{}])[0]
product_id = product.get("productID", "")
need(product_id == "com.keptora.app.pro.lifetime", "lifetime Product ID mismatch")
need(product.get("type") == "NonConsumable", "lifetime product must be non-consumable")
need(product.get("familyShareable") is False, "Family Sharing must be disabled")
need(mac_info.get("APP_LIFETIME_PRODUCT_ID") == product_id, "Mac Product ID mismatch")
need(ios_info.get("APP_LIFETIME_PRODUCT_ID") == product_id, "iPhone Product ID mismatch")

for info, label in ((mac_info, "Mac"), (ios_info, "iPhone")):
    need(info.get("CFBundleDisplayName") in ("Keptora", "Keptora"), f"{label} visible name must be Keptora")
    for key in ("APP_PRIVACY_POLICY_URL", "APP_SUPPORT_URL", "APP_MARKETING_URL"):
        value = str(info.get(key, ""))
        need(value.startswith("https://alfagolab.com/keptora"), f"{label} {key} is not configured")

need("com.apple.security.app-sandbox" in (ROOT / "Keptora/Resources/Keptora.entitlements").read_text(), "Mac sandbox entitlement missing")
need("com.apple.security.files.bookmarks.app-scope" in (ROOT / "Keptora/Resources/Keptora.entitlements").read_text(), "Mac bookmark entitlement missing")
need("disable-library-validation" not in (ROOT / "Keptora/Resources/Keptora.entitlements").read_text(), "unnecessary library-validation exception present")

for lang in ("en", "tr", "de", "fr"):
    info_strings = ROOT / f"KeptoraiOS/Resources/{lang}.lproj/InfoPlist.strings"
    need(info_strings.exists(), f"iPhone {lang} InfoPlist.strings missing")

catalog_path = ROOT / "Keptora/Resources/Localizable.xcstrings"
need(catalog_path.exists(), "shared Localizable.xcstrings catalog missing")
catalog_memberships = re.findall(r"^\s+[A-F0-9]+ /\* Localizable\.xcstrings in Resources \*/,", project, re.MULTILINE)
need(len(catalog_memberships) == 2, "shared catalog must belong to both Mac and iPhone resource phases")
need("Localizable.strings in Resources" not in project, "legacy iPhone Localizable.strings is still in a resource phase")

placeholder_pattern = re.compile(r"%(?:\d+\$)?(lld|ld|d|f|@)")
placeholder_token = r"%(?:\d+\$)?(?:lld|ld|d|f|@)"
localized_letter = r"[A-Za-zÀ-ÖØ-öø-ÿĞİŞğışÇçÖöÜü]"
joined_placeholder_pattern = re.compile(
    rf"(?:{localized_letter}{placeholder_token}|{placeholder_token}{localized_letter})"
)
if catalog_path.exists():
    catalog = json.loads(catalog_path.read_text())
    retained = catalog.get("strings", {})
    need(catalog.get("sourceLanguage") == "en", "shared catalog source language must be English")
    # Validate every retained key. Swift package and dynamic localization keys can
    # be marked stale by Xcode extraction while still being used at runtime.
    for key, entry in retained.items():
        source = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value", key)
        source_placeholders = sorted(placeholder_pattern.findall(source))
        for lang in ("tr", "de", "fr"):
            unit = entry.get("localizations", {}).get(lang, {}).get("stringUnit", {})
            value = str(unit.get("value", ""))
            need(unit.get("state") == "translated" and bool(value.strip()), f"{lang} translation missing or empty: {key}")
            need(sorted(placeholder_pattern.findall(value)) == source_placeholders, f"{lang} placeholder mismatch: {key}")
            need(value.count("\n") == source.count("\n"), f"{lang} unexpected line break: {key}")
            if not joined_placeholder_pattern.search(source):
                need(not joined_placeholder_pattern.search(value), f"{lang} placeholder joined to a word: {key}")

shipping_ui = "\n".join(
    path.read_text(errors="ignore")
    for folder in (ROOT / "Keptora/App", ROOT / "Keptora/Features", ROOT / "KeptoraiOS/UI")
    for path in folder.rglob("*.swift")
)
raw_value_ui_lines = [
    line.strip() for line in shipping_ui.splitlines()
    if ".rawValue" in line
    and ("Text(" in line or "Label(" in line)
    and "LocalizedStringKey(" not in line
    and ".tag(" not in line
]
need(not raw_value_ui_lines, "UI renders an enum rawValue directly: " + " | ".join(raw_value_ui_lines[:3]))

for token in ("Family Sharing included", "on your Macs", "Local only"):
    shipping = "\n".join(path.read_text(errors="ignore") for folder in (ROOT / "Keptora", ROOT / "KeptoraiOS") for path in folder.rglob("*.swift"))
    need(token not in shipping, f"obsolete visible claim remains: {token}")

owner_blockers = []
if "com.yourcompany" in spec:
    owner_blockers.append("real Bundle IDs")
if re.search(r'DEVELOPMENT_TEAM:\s*""', spec):
    owner_blockers.append("Apple Development Team")

print("Keptora universal Phase Q release validation")
for error in errors:
    print("ERROR:", error)
if owner_blockers:
    print("OWNER INPUT REQUIRED:", ", ".join(owner_blockers))
if errors:
    print(f"FAILED: {len(errors)} implementation error(s)")
    sys.exit(1)
print("PASS: universal source, safety, localization, StoreKit and metadata contracts")
if owner_blockers:
    print("RELEASE BLOCKED: signing identifiers must remain fail-closed until supplied by the account owner")
    if "--allow-owner-placeholders" not in sys.argv:
        sys.exit(69)
