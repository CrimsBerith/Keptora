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

# Syntax parse every Swift source without requiring macOS frameworks.
for path in sorted(list((ROOT/'Keptora').rglob('*.swift')) + list((ROOT/'KeptoraTests').rglob('*.swift'))):
    run(['swiftc','-frontend','-parse',str(path.relative_to(ROOT))])
run(['python3','Scripts/validate_project_references.py'])

# Structured files.
for rel in ['Keptora/Resources/Localizable.xcstrings','Keptora/Resources/Keptora.storekit']:
    try: json.loads((ROOT/rel).read_text())
    except Exception as e: errors.append(f'{rel}: {e}')
try:
    info=plistlib.loads((ROOT/'Keptora/Resources/Info.plist').read_bytes())
except Exception as e:
    errors.append(f'Info.plist: {e}'); info={}
try:
    plistlib.loads((ROOT/'Keptora/Resources/Keptora.entitlements').read_bytes())
    plistlib.loads((ROOT/'Keptora/Resources/PrivacyInfo.xcprivacy').read_bytes())
except Exception as e: errors.append(f'plist parse: {e}')

project=(ROOT/'Keptora.xcodeproj/project.pbxproj').read_text()
settings=(ROOT/'Keptora/Features/Settings/SettingsView.swift').read_text()
store=json.loads((ROOT/'Keptora/Resources/Keptora.storekit').read_text())
store_id=store['products'][0]['productID']
source_match=re.search(r'lifetimeProductID = "([^"]+)"', settings)
source_id=source_match.group(1) if source_match else ''
require(store_id == source_id, f'StoreKit product mismatch: config={store_id}, source={source_id}')
require(info.get('CFBundleShortVersionString') == '0.9.0', 'Info.plist version must be 0.9.0')
require(str(info.get('CFBundleVersion')) == '90', 'Info.plist build must be 90')
require('MARKETING_VERSION = "0.9.0"' in project, 'Project marketing version must be 0.9.0')
require('CURRENT_PROJECT_VERSION = "90"' in project, 'Project build must be 90')
require('knownRegions = (en, tr, Base);' in project, 'English/Turkish known regions missing')
require(len(json.loads((ROOT/'Keptora/Resources/Localizable.xcstrings').read_text())['strings']) >= 20, 'Critical localization catalog is unexpectedly small')

# Safety contract: no permanent deletion API in app target.
for pattern in [r'PHAssetChangeRequest\.deleteAssets', r'\.trashItem\s*\(', r'FileManager\.default\.removeItem\s*\(']:
    for path in (ROOT/'Keptora').rglob('*.swift'):
        if re.search(pattern, path.read_text()): errors.append(f'Forbidden permanent-delete API in {path.relative_to(ROOT)}: {pattern}')

placeholders=[]
if 'PRODUCT_BUNDLE_IDENTIFIER = "com.yourcompany.cullora"' in project: placeholders.append('bundle identifier')
if 'DEVELOPMENT_TEAM = ""' in project: placeholders.append('development team')
if 'yourcompany' in store_id: placeholders.append('StoreKit product identifier')
if placeholders:
    message='Release identifiers still placeholders: ' + ', '.join(placeholders)
    (errors if args.release else warnings).append(message)

print('Phase 5J static validation')
for w in warnings: print('WARNING:', w)
for e in errors: print('ERROR:', e)
if errors:
    print(f'FAILED: {len(errors)} error(s), {len(warnings)} warning(s)')
    sys.exit(1)
print(f'PASS: 0 errors, {len(warnings)} warning(s)')
