#!/usr/bin/env python3
from pathlib import Path
import argparse, csv, json, plistlib, re, subprocess, sys

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
for path in sorted(list((ROOT/'Keptora').rglob('*.swift')) + list((ROOT/'KeptoraTests').rglob('*.swift'))):
    run(['swiftc','-frontend','-parse',str(path.relative_to(ROOT))])
run(['python3','Scripts/validate_project_references.py'])
run(['python3','Scripts/validate_app_store_metadata.py'])

# Structured resources.
resources = {}
for rel in ['Keptora/Resources/Localizable.xcstrings','Keptora/Resources/Keptora.storekit']:
    try: resources[rel]=json.loads((ROOT/rel).read_text())
    except Exception as e: errors.append(f'{rel}: {e}')
try: info=plistlib.loads((ROOT/'Keptora/Resources/Info.plist').read_bytes())
except Exception as e: errors.append(f'Info.plist: {e}'); info={}
try: entitlements=plistlib.loads((ROOT/'Keptora/Resources/Keptora.entitlements').read_bytes())
except Exception as e: errors.append(f'Keptora.entitlements: {e}'); entitlements={}
try: privacy=plistlib.loads((ROOT/'Keptora/Resources/PrivacyInfo.xcprivacy').read_bytes())
except Exception as e: errors.append(f'PrivacyInfo.xcprivacy: {e}'); privacy={}

project=(ROOT/'Keptora.xcodeproj/project.pbxproj').read_text()
purchase_source=(ROOT/'Keptora/Core/Purchases/StoreEntitlementController.swift').read_text()
access_source=(ROOT/'Keptora/Core/Purchases/AccessPolicy.swift').read_text()
store=resources.get('Keptora/Resources/Keptora.storekit', {'products':[{'productID':''}]})
store_id=store['products'][0]['productID']
source_id=str(info.get('APP_LIFETIME_PRODUCT_ID', '')).strip()

require(store_id == source_id, f'StoreKit product mismatch: config={store_id}, source={source_id}')
require(info.get('CFBundleShortVersionString') == '1.0.0', 'Info.plist version must be 1.0.0')
require(str(info.get('CFBundleVersion')) == '181', 'Info.plist build must be 181')
require('MARKETING_VERSION = "1.0.0"' in project, 'Project marketing version must be 1.0.0')
require('CURRENT_PROJECT_VERSION = "181"' in project, 'Project build must be 181')
require('knownRegions = (en, tr, Base);' in project, 'English/Turkish known regions missing')
require(len(resources.get('Keptora/Resources/Localizable.xcstrings',{}).get('strings',{})) >= 90, 'Launch localization catalog is unexpectedly small')
require(project.count('MACOSX_DEPLOYMENT_TARGET = \"13.0\"') >= 2, 'Declared macOS 13 deployment target changed unexpectedly')
require(not any('ContentUnavailableView' in path.read_text() for path in (ROOT/'Keptora').rglob('*.swift')), 'Newer ContentUnavailableView dependency remains despite macOS 13 target')
try:
    with (ROOT/'AppStore/COMPETITOR_MATRIX_2026.csv').open(encoding='utf-8-sig', newline='') as handle:
        competitors=list(csv.DictReader(handle))
    require(len(competitors) >= 22, 'Competitor register must contain at least 22 researched products')
    require(all(row.get('source','').startswith('https://') for row in competitors), 'Every competitor row must include an HTTPS source')
except Exception as exc:
    errors.append(f'Competitor matrix: {exc}')

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
require((ROOT/'Keptora/Features/Onboarding/OnboardingView.swift').exists(), 'Onboarding view missing')
require((ROOT/'Keptora/Features/Paywall/PaywallView.swift').exists(), 'Paywall view missing')
require((ROOT/'Keptora/Features/Diagnostics/DiagnosticsView.swift').exists(), 'Diagnostics view missing')
require((ROOT/'Keptora/Features/Insights/ReviewInsightsView.swift').exists(), 'Review Insights view missing')
require('authorizeReviews' in purchase_source and 'recordReviews' in purchase_source, 'Atomic batch review entitlement support missing')
require('applyExactGroupAction' in (ROOT/'Keptora/Core/Persistence/SQLiteDatabase.swift').read_text(), 'Exact-only batch action persistence missing')
require('Select All Safe Copies' in (ROOT/'Keptora/Features/ReviewStudio/ReviewStudioView.swift').read_text(), 'Exact review batch action UI missing')
require('authorizeReview' in purchase_source and 'authorizeSafetyPlan' in purchase_source, 'App-wide entitlement enforcement missing')
require('DiagnosticsRedactor' in (ROOT/'Keptora/Diagnostics/DiagnosticsSnapshot.swift').read_text(), 'Diagnostics redaction missing')
require('final class StoreEntitlementController' not in (ROOT/'Keptora/Features/Settings/SettingsView.swift').read_text(), 'Store controller implementation must not live inside SettingsView')

# Safety contract: no permanent deletion API in app target.
for pattern in [r'PHAssetChangeRequest\.deleteAssets', r'\.trashItem\s*\(', r'FileManager\.default\.removeItem\s*\(']:
    for path in (ROOT/'Keptora').rglob('*.swift'):
        if re.search(pattern, path.read_text()): errors.append(f'Forbidden permanent-delete API in {path.relative_to(ROOT)}: {pattern}')

# Release/package documents.
for rel in [
    'AppStore/APP_STORE_METADATA.md', 'AppStore/APP_PRIVACY_ANSWERS.md',
    'AppStore/PRIVACY_POLICY.md', 'AppStore/SCREENSHOT_CAPTURE_PLAN.md',
    'AppStore/APP_REVIEW_NOTES.md', 'Docs/PHASE_5M_IMPLEMENTATION.md', 'Docs/APP_REVIEW_DEMO_GUIDE.md',
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


# Phase 5M continuity, keyboard, and demo contract.
app_model=(ROOT/'Keptora/App/AppModel.swift').read_text()
app_source=(ROOT/'Keptora/App/KeptoraApp.swift').read_text()
review_source=(ROOT/'Keptora/Features/ReviewStudio/ReviewStudioView.swift').read_text()
require((ROOT/'Keptora/Adapters/FileSystemAdapter/DemoLibraryFactory.swift').exists(), 'Demo library factory missing')
require((ROOT/'KeptoraTests/ReviewSessionCheckpointTests.swift').exists(), 'Review session checkpoint tests missing')
require('ReviewSessionCheckpoint' in (ROOT/'Keptora/Core/Models/ReviewModels.swift').read_text(), 'Review session checkpoint model missing')
require('checkpointReviewSession' in app_model and 'resumeReviewSession' in app_model, 'Review checkpoint lifecycle missing')
require('loadDemoLibrary' in app_model and 'DemoLibraryFactory.prepare' in app_model, 'Real scanner demo library path missing')
require('CommandMenu("Review")' in app_source, 'Keyboard review command menu missing')
for shortcut in ['Previous Exact Group','Next Exact Group','Keep Focused Photo','Select All Safe Copies']:
    require(shortcut in app_source, f'Missing keyboard command: {shortcut}')
require('isFocused: model.selectedReviewAssetID == asset.id' in review_source, 'Focused review asset UI missing')
require('Local review session' in (ROOT/'Keptora/Features/Insights/ReviewInsightsView.swift').read_text(), 'Local session metrics missing')

print('Phase 5M static validation')
for w in warnings: print('WARNING:', w)
for e in errors: print('ERROR:', e)
if errors:
    print(f'FAILED: {len(errors)} error(s), {len(warnings)} warning(s)')
    sys.exit(1)
print(f'PASS: 0 errors, {len(warnings)} warning(s)')
