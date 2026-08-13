#!/usr/bin/env python3
from pathlib import Path
import argparse, json, plistlib, re, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--release', action='store_true', help='Fail on placeholder signing/product identifiers.')
args = parser.parse_args()
errors=[]; warnings=[]

def require(condition, message):
    if not condition: errors.append(message)

def run(cmd):
    result=subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        errors.append(f"Command failed: {' '.join(cmd)}\n{result.stdout}{result.stderr}")

# Syntax parse every Swift source without resolving macOS-only frameworks.
for path in sorted(list((ROOT/'Cullora').rglob('*.swift')) + list((ROOT/'CulloraTests').rglob('*.swift'))):
    run(['swiftc','-frontend','-parse',str(path.relative_to(ROOT))])
run(['python3','Scripts/validate_project_references.py'])
run(['python3','Scripts/validate_app_store_metadata.py'])

# Structured resources.
resources = {}
for rel in ['Cullora/Resources/Localizable.xcstrings','Cullora/Resources/Cullora.storekit']:
    try: resources[rel]=json.loads((ROOT/rel).read_text())
    except Exception as e: errors.append(f'{rel}: {e}')
try: info=plistlib.loads((ROOT/'Cullora/Resources/Info.plist').read_bytes())
except Exception as e: errors.append(f'Info.plist: {e}'); info={}
try: entitlements=plistlib.loads((ROOT/'Cullora/Resources/Cullora.entitlements').read_bytes())
except Exception as e: errors.append(f'Cullora.entitlements: {e}'); entitlements={}
try: privacy=plistlib.loads((ROOT/'Cullora/Resources/PrivacyInfo.xcprivacy').read_bytes())
except Exception as e: errors.append(f'PrivacyInfo.xcprivacy: {e}'); privacy={}

project=(ROOT/'Cullora.xcodeproj/project.pbxproj').read_text()
purchase_source=(ROOT/'Cullora/Core/Purchases/StoreEntitlementController.swift').read_text()
access_source=(ROOT/'Cullora/Core/Purchases/AccessPolicy.swift').read_text()
store=resources.get('Cullora/Resources/Cullora.storekit', {'products':[{'productID':''}]})
store_id=store['products'][0]['productID']
source_match=re.search(r'lifetimeProductID = "([^"]+)"', purchase_source)
source_id=source_match.group(1) if source_match else ''

require(store_id == source_id, f'StoreKit product mismatch: config={store_id}, source={source_id}')
require(info.get('CFBundleShortVersionString') == '0.9.1', 'Info.plist version must be 0.9.1')
require(str(info.get('CFBundleVersion')) == '100', 'Info.plist build must be 100')
require('MARKETING_VERSION = "0.9.1"' in project, 'Project marketing version must be 0.9.1')
require('CURRENT_PROJECT_VERSION = "100"' in project, 'Project build must be 100')
require('knownRegions = (en, tr, Base);' in project, 'English/Turkish known regions missing')
require(len(resources.get('Cullora/Resources/Localizable.xcstrings',{}).get('strings',{})) >= 90, 'Launch localization catalog is unexpectedly small')

# Privacy and sandbox contract.
require(privacy.get('NSPrivacyTracking') is False, 'Privacy manifest must declare tracking disabled')
require(privacy.get('NSPrivacyCollectedDataTypes') == [], 'Privacy manifest must declare no collected data for this local-only build')
api_entries={entry.get('NSPrivacyAccessedAPIType'): set(entry.get('NSPrivacyAccessedAPITypeReasons',[])) for entry in privacy.get('NSPrivacyAccessedAPITypes',[])}
require('3B52.1' in api_entries.get('NSPrivacyAccessedAPICategoryFileTimestamp',set()), 'User-selected file timestamp reason 3B52.1 missing')
require('C617.1' in api_entries.get('NSPrivacyAccessedAPICategoryFileTimestamp',set()), 'App-container file timestamp reason C617.1 missing')
require('CA92.1' in api_entries.get('NSPrivacyAccessedAPICategoryUserDefaults',set()), 'App-only UserDefaults reason CA92.1 missing')
require(entitlements.get('com.apple.security.app-sandbox') is True, 'App Sandbox entitlement missing')
require(entitlements.get('com.apple.security.files.user-selected.read-write') is True, 'User-selected read/write entitlement missing')
require(entitlements.get('com.apple.security.files.bookmarks.app-scope') is True, 'App-scoped security bookmark entitlement missing')
require(entitlements.get('com.apple.security.personal-information.photos-library') is True, 'Photos Library entitlement missing for PhotoKit adapter')
require(entitlements.get('com.apple.security.assets.pictures.read-write') is not True, 'Broad Pictures-folder entitlement should not be enabled; use user-selected folders')
require(project.count('ENABLE_HARDENED_RUNTIME = \"YES\"') >= 2, 'Hardened Runtime must be enabled for Debug and Release')

# Access model and UX contract.
require('freeReviewLimit = 100' in access_source, 'Free review limit must remain 100')
require((ROOT/'Cullora/Features/Onboarding/OnboardingView.swift').exists(), 'Onboarding view missing')
require((ROOT/'Cullora/Features/Paywall/PaywallView.swift').exists(), 'Paywall view missing')
require((ROOT/'Cullora/Features/Diagnostics/DiagnosticsView.swift').exists(), 'Diagnostics view missing')
require('authorizeReview' in purchase_source and 'authorizeSafetyPlan' in purchase_source, 'App-wide entitlement enforcement missing')
require('DiagnosticsRedactor' in (ROOT/'Cullora/Diagnostics/DiagnosticsSnapshot.swift').read_text(), 'Diagnostics redaction missing')
require('final class StoreEntitlementController' not in (ROOT/'Cullora/Features/Settings/SettingsView.swift').read_text(), 'Store controller implementation must not live inside SettingsView')

# Safety contract: no permanent deletion API in app target.
for pattern in [r'PHAssetChangeRequest\.deleteAssets', r'\.trashItem\s*\(', r'FileManager\.default\.removeItem\s*\(']:
    for path in (ROOT/'Cullora').rglob('*.swift'):
        if re.search(pattern, path.read_text()): errors.append(f'Forbidden permanent-delete API in {path.relative_to(ROOT)}: {pattern}')

# Release/package documents.
for rel in [
    'AppStore/APP_STORE_METADATA.md', 'AppStore/APP_PRIVACY_ANSWERS.md',
    'AppStore/PRIVACY_POLICY.md', 'AppStore/SCREENSHOT_CAPTURE_PLAN.md',
    'AppStore/APP_REVIEW_NOTES.md', 'Docs/PHASE_5K_IMPLEMENTATION.md',
    'Docs/CODEX_MAC_RELEASE_RUNBOOK.md'
]:
    require((ROOT/rel).exists(), f'Missing release document: {rel}')

placeholders=[]
if 'PRODUCT_BUNDLE_IDENTIFIER = "com.yourcompany.cullora"' in project: placeholders.append('bundle identifier')
if 'DEVELOPMENT_TEAM = ""' in project: placeholders.append('development team')
if 'yourcompany' in store_id: placeholders.append('StoreKit product identifier')
if placeholders:
    message='Release identifiers still placeholders: ' + ', '.join(placeholders)
    (errors if args.release else warnings).append(message)

print('Phase 5K static validation')
for w in warnings: print('WARNING:', w)
for e in errors: print('ERROR:', e)
if errors:
    print(f'FAILED: {len(errors)} error(s), {len(warnings)} warning(s)')
    sys.exit(1)
print(f'PASS: 0 errors, {len(warnings)} warning(s)')
