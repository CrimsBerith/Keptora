#!/usr/bin/env python3
from pathlib import Path
import json, plistlib, re, sys
ROOT=Path(__file__).resolve().parents[1]
errors=[]
project=(ROOT/'Cullora.xcodeproj/project.pbxproj').read_text()
store=json.loads((ROOT/'Cullora/Resources/Cullora.storekit').read_text())
metadata=json.loads((ROOT/'AppStore/app_store_metadata.json').read_text())
info=plistlib.loads((ROOT/'Cullora/Resources/Info.plist').read_bytes())
purchase=(ROOT/'Cullora/Core/Purchases/StoreEntitlementController.swift').read_text()
if 'PRODUCT_BUNDLE_IDENTIFIER = "com.yourcompany.cullora"' in project: errors.append('bundle identifier placeholder')
if 'DEVELOPMENT_TEAM = ""' in project: errors.append('development team placeholder')
if 'MARKETING_VERSION = "1.0.0"' not in project or 'CURRENT_PROJECT_VERSION = "181"' not in project: errors.append('release must be 1.0.0/build 181')
product=store.get('products',[{}])[0].get('productID','')
if not product or 'yourcompany' in product.lower() or 'replace' in product.lower(): errors.append('StoreKit product identifier placeholder')
if store.get('products',[{}])[0].get('familyShareable', True): errors.append('Family Sharing must be disabled for 1.0.0')
if info.get('APP_LIFETIME_PRODUCT_ID') != product: errors.append('Info.plist lifetime product ID does not match StoreKit')
for key in ('APP_PRIVACY_POLICY_URL','APP_SUPPORT_URL','APP_MARKETING_URL'):
    value=str(info.get(key,''))
    if not value.startswith('https://') or any(x in value.lower() for x in ('your-domain','replace','example.com')):
        errors.append(f'{key} must be a real HTTPS URL')
if f'lifetimeProductID = "{product}"' not in purchase:
    errors.append('StoreEntitlementController product ID does not match StoreKit')
urls=metadata.get('urls', metadata)
for key in ('privacy_policy','support','marketing'):
    value=str(urls.get(key,'')).strip()
    if not value.startswith('https://') or any(x in value.lower() for x in ('replace-with-real-domain','.example','example.com')):
        errors.append(f'{key} must be a real HTTPS URL')
if any(token in project for token in ('com.yourcompany', 'DEVELOPMENT_TEAM = ""')): errors.append('Xcode signing identifiers are incomplete')
print('Cullora Phase 5S release-config validation')
for e in errors: print('ERROR:',e)
if errors:
    print(f'FAILED: {len(errors)} error(s)'); sys.exit(1)
print('PASS: release identifiers and HTTPS URLs configured')
