#!/usr/bin/env python3
import json, plistlib, glob, sys, re
from pathlib import Path
root=Path(__file__).resolve().parent.parent
appstore=root/'AppStore'
manifest=json.load(open(appstore/'PRE_MAC_RELEASE_COHERENCE_PHASE_P.json'))
errors=[]

def req(cond,msg):
    if not cond: errors.append(msg)

# Required Phase P/earlier release sources.
for rel in [
 'AppStore/APP_STORE_CONNECT_SUBMISSION_BUNDLE_PHASE_O.template.json',
 'AppStore/SCREENSHOT_SHOTLIST.json','AppStore/ASSET_PROVENANCE_MANIFEST.json',
 'AppStore/PRE_MAC_RELEASE_COHERENCE_PHASE_P.json','AppStore/SCREENSHOT_ASSET_TRACEABILITY_PHASE_P.json',
 'AppStore/APP_PRIVACY_ANSWERS_PHASE_O.md','AppStore/AGE_RATING_ANSWERS_PHASE_O.md',
 'AppStore/ACCESSIBILITY_NUTRITION_LABEL_DRAFT.md','AppStore/EXPORT_COMPLIANCE_DSA_CHECKLIST.md']:
    req((root/rel).is_file(),f'missing {rel}')

plists=list(root.glob('**/Info.plist'))
req(len(plists)>=1,'missing Info.plist')
if plists:
    with open(plists[0],'rb') as f: p=plistlib.load(f)
    req(p.get('CFBundleDisplayName')==manifest['app_name'],f"display name mismatch: {p.get('CFBundleDisplayName')}")
    req(p.get('LSApplicationCategoryType')==manifest['canonical_category'],f"category mismatch: {p.get('LSApplicationCategoryType')}")
    req(bool(p.get('APP_LIFETIME_PRODUCT_ID')),'missing APP_LIFETIME_PRODUCT_ID')
    for k in ['APP_PRIVACY_POLICY_URL','APP_SUPPORT_URL','APP_MARKETING_URL']:
        req(bool(p.get(k)),f'missing {k}')

storekits=list(root.glob('**/*.storekit'))
req(len(storekits)==1,f'expected one StoreKit config, got {len(storekits)}')
if storekits and plists:
    sk=json.load(open(storekits[0]))
    ids=[x.get('productID') for x in sk.get('products',[]) if x.get('productID')]
    req(len(ids)==1,f'expected one non-consumable product id, got {ids}')
    if ids:
        req(ids[0]==p.get('APP_LIFETIME_PRODUCT_ID'),'StoreKit product ID != Info.plist APP_LIFETIME_PRODUCT_ID')

privacy=list(root.glob('**/PrivacyInfo.xcprivacy'))
req(len(privacy)>=1,'missing PrivacyInfo.xcprivacy')
ent=list(root.glob('**/*.entitlements'))
req(len(ent)>=1,'missing entitlements')

shot=json.load(open(appstore/'SCREENSHOT_SHOTLIST.json'))
trace=json.load(open(appstore/'SCREENSHOT_ASSET_TRACEABILITY_PHASE_P.json'))
prov=json.load(open(appstore/'ASSET_PROVENANCE_MANIFEST.json'))
shots=shot.get('shots',[])
req(1 <= len(shots) <= 10, f'invalid screenshot shot count {len(shots)}')
req(all(x.get('synthetic_data_only') is True for x in shots),'all screenshot shots must be synthetic_data_only')
req(len(trace.get('mappings',[]))==len(shots),'traceability mapping count != shot count')
known={x.get('screen') for x in prov.get('screens',[])}
for m in trace.get('mappings',[]):
    req(m.get('blueprint_screen') in known,f"trace mapping target absent: {m.get('blueprint_screen')}")
    req(m.get('asset_provenance_status')=='SOURCE_CONTRACT_READY','trace mapping asset provenance not ready')

# Metadata limits are source-side checks only; App Store Connect remains authoritative.
o=json.load(open(appstore/'APP_STORE_CONNECT_SUBMISSION_BUNDLE_PHASE_O.template.json'))
loc=o.get('localization_en_US',{})
req(len(loc.get('subtitle','')) <= 30,'subtitle > 30 chars')
req(len(loc.get('promotional_text','')) <= 170,'promotional text > 170 chars')
req(len(loc.get('keywords','')) <= 100,'keywords > 100 chars')
req(len(loc.get('description','')) <= 4000,'description > 4000 chars')
req(o.get('app',{}).get('category')==manifest['canonical_category'],'Phase O category drift')
req(o.get('app',{}).get('name')==manifest['app_name'],'Phase O app name drift')

# External blockers must stay explicit rather than silently replaced with fabricated values.
blockers=manifest.get('external_blockers',[])
req(len(blockers)>=1,'expected explicit external blockers')
if manifest.get('final_icon_external_blocker'):
    req(any('icon' in x.lower() for x in blockers),'icon blocker must remain explicit')

if errors:
    print('FAIL Phase P pre-Mac coherence')
    for e in errors: print(' -',e)
    sys.exit(1)
print('PASS Phase P pre-Mac coherence:',manifest['app_name'])
