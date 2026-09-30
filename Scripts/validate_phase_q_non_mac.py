#!/usr/bin/env python3
from pathlib import Path
import json, plistlib, re, sys
try:
    from PIL import Image
except ImportError:
    print('FAIL Phase Q')
    print(' - Pillow is required for visual asset validation. Install it with: python3 -m pip install Pillow')
    raise SystemExit(69)
R=Path(__file__).resolve().parents[1]
A=R/'AppStore'; err=[]
APP=R/'Keptora'; IOS=R/'KeptoraiOS'; RES=APP/'Resources'
if not APP.is_dir() or not IOS.is_dir():
    print('FAIL Phase Q'); print(' - expected Keptora Mac and KeptoraiOS source directories'); raise SystemExit(1)

def need(cond,msg):
    if not cond: err.append(msg)

def jload(p):
    try: return json.loads(p.read_text())
    except Exception as e: err.append(f'{p.name} parse {e}'); return {}

required=[
 'APP_STORE_CONNECT_SUBMISSION_BUNDLE_PHASE_O.template.json','AGE_RATING_2026_RECOMMENDED.json',
 'APP_PRIVACY_RECOMMENDED.json','ACCESSIBILITY_NUTRITION_LABEL_DRAFT.md','EXPORT_COMPLIANCE_DSA_CHECKLIST.md',
 'SCREEN_AND_ASSET_BLUEPRINT.md','SCREEN_STATE_MATRIX.json','SCREENSHOT_SHOTLIST.json','WEB_SUPPORT_PATHS_PHASE_Q.json',
 'SHIPPING_SOURCE_STATIC_AUDIT_PHASE_Q.json','ASSET_COMPLETENESS_PHASE_Q.json'
]
for f in required: need((A/f).exists(),'missing '+f)

b=jload(A/'APP_STORE_CONNECT_SUBMISSION_BUNDLE_PHASE_O.template.json')
name=b.get('app',{}).get('name',''); loc=b.get('localization_en_US',{})
need(0<len(name)<=30,f'App Store name length {len(name)}')
need(0<len(loc.get('subtitle',''))<=30,'subtitle length')
need(0<len(loc.get('keywords',''))<=100,'keywords length')
need(bool(loc.get('description','').strip()),'description empty')

# Shipping source static safety and StoreKit/support wiring.
swift=list(APP.rglob('*.swift'))+list(IOS.rglob('*.swift')); source='\n'.join(p.read_text(errors='ignore') for p in swift)
for label,pat in {
 'fatalError':r'\bfatalError\s*\(','try!':r'\btry!\b','forced cast':r'\bas!\b','TODO':r'\bTODO\b','FIXME':r'\bFIXME\b','URLSession':r'\bURLSession\b'
}.items(): need(re.search(pat,source,re.I if label in ('TODO','FIXME') else 0) is None,'shipping source contains '+label)
need('import StoreKit' in source and 'Product.products' in source and '.purchase()' in source and 'Transaction.currentEntitlements' in source,'StoreKit 2 purchase/restore wiring incomplete')
need('APP_SUPPORT_URL' in source and 'APP_PRIVACY_POLICY_URL' in source,'in-app support/privacy URL wiring incomplete')

# Info.plist release fields are structurally present; real owner values intentionally injected at Mac/ASC handoff.
infos=list(RES.glob('Info.plist')); need(len(infos)==1,'Info.plist count')
if len(infos)==1:
    try:
        info=plistlib.load(infos[0].open('rb'))
        for k in ['CFBundleDisplayName','LSApplicationCategoryType','LSMinimumSystemVersion','APP_LIFETIME_PRODUCT_ID','APP_SUPPORT_URL','APP_PRIVACY_POLICY_URL','APP_MARKETING_URL']:
            need(bool(str(info.get(k,'')).strip()),f'Info.plist missing {k}')
    except Exception as e: err.append('Info.plist parse '+str(e))

# Xcode release hardening is explicit in source; real signing identity remains owner/Mac-stage input.
projects=list(R.glob('*.xcodeproj/project.pbxproj')); need(len(projects)==1,'Xcode project count')
if len(projects)==1:
    ps=projects[0].read_text(errors='ignore')
    need(re.search(r'ENABLE_HARDENED_RUNTIME\s*=\s*"?YES"?;',ps) is not None,'Hardened Runtime build setting missing')
    need(re.search(r'CODE_SIGN_STYLE\s*=\s*"?Automatic"?;',ps) is not None,'Automatic code signing style missing')

# App sandbox entitlement minimization.
ents=list(RES.glob('*.entitlements')); need(len(ents)==1,'entitlements count')
if len(ents)==1:
    try:
        ent=plistlib.load(ents[0].open('rb'))
        need(ent.get('com.apple.security.app-sandbox') is True,'App Sandbox disabled')
        need(ent.get('com.apple.security.files.user-selected.read-write') is True,'user-selected read-write entitlement missing')
        need(not (ent.get('com.apple.security.files.user-selected.read-only') and ent.get('com.apple.security.files.user-selected.read-write')),'redundant read-only + read-write entitlements')
        allowed={'com.apple.security.app-sandbox','com.apple.security.files.user-selected.read-write','com.apple.security.personal-information.photos-library','com.apple.security.files.bookmarks.app-scope'}
        unexpected=set(ent)-allowed
        need(not unexpected,'unexpected entitlement(s): '+','.join(sorted(unexpected)))
        persistent_bookmarks=bool(re.search(r'bookmarkData\s*\(',source) and re.search(r'resolvingBookmarkData',source) and re.search(r'withSecurityScope',source))
        if persistent_bookmarks: need(ent.get('com.apple.security.files.bookmarks.app-scope') is True,'persistent security-scoped bookmarks require app-scope bookmark entitlement')
    except Exception as e: err.append('entitlements parse '+str(e))

# Privacy manifest + conservative source correlation for known required-reason APIs.
priv=RES/'PrivacyInfo.xcprivacy'; need(priv.exists(),'PrivacyInfo.xcprivacy missing')
if priv.exists():
    try:
        pd=plistlib.load(priv.open('rb'))
        cats={x.get('NSPrivacyAccessedAPIType'):set(x.get('NSPrivacyAccessedAPITypeReasons',[])) for x in pd.get('NSPrivacyAccessedAPITypes',[])}
        if re.search(r'\bUserDefaults\b|@AppStorage\b',source): need('NSPrivacyAccessedAPICategoryUserDefaults' in cats,'UserDefaults used without required-reason declaration')
        if re.search(r'creationDateKey|contentModificationDateKey|contentAccessDateKey|attributeModificationDateKey',source): need('NSPrivacyAccessedAPICategoryFileTimestamp' in cats,'file timestamp API used without required-reason declaration')
        if re.search(r'volumeAvailableCapacity(?:ForImportantUsage|ForOpportunisticUsage)?Key|volumeAvailableCapacity',source): need('NSPrivacyAccessedAPICategoryDiskSpace' in cats,'disk-space API used without required-reason declaration')
        if re.search(r'ProcessInfo\.processInfo\.systemUptime|mach_absolute_time|kern\.boottime',source): need('NSPrivacyAccessedAPICategorySystemBootTime' in cats,'system boot time API used without required-reason declaration')
    except Exception as e: err.append('privacy manifest parse '+str(e))

# StoreKit config.
store=list(RES.glob('*.storekit')); need(len(store)==1,'StoreKit configuration count')
if len(store)==1:
    sd=jload(store[0]); need(bool(sd),'StoreKit config empty/unparseable')

# Production-candidate icon source and complete opaque app-icon set.
master=A/'AppIcon'/'source-1024.png'; need(master.exists(),'production icon source-1024.png missing')
if master.exists():
    try:
        im=Image.open(master); need(im.size==(1024,1024),'production icon source must be 1024x1024'); need(im.mode in ('RGB','L'),'production icon source contains alpha')
    except Exception as e: err.append('production icon invalid '+str(e))
iconsets=list(RES.glob('Assets.xcassets/AppIcon.appiconset')); need(len(iconsets)==1,'AppIcon set count')
if len(iconsets)==1:
    try:
        d=jload(iconsets[0]/'Contents.json'); refs=[x['filename'] for x in d.get('images',[]) if x.get('filename')]
        need(len(refs)>=10,f'AppIcon slot count {len(refs)}')
        for fn in refs:
            p=iconsets[0]/fn; need(p.exists(),'missing icon '+fn)
            if p.exists():
                im=Image.open(p); need(im.mode in ('RGB','L'),'AppIcon alpha channel '+fn)
    except Exception as e: err.append('AppIcon '+str(e))

# Machine-checkable screen/asset contract.
sm=jload(A/'SCREEN_STATE_MATRIX.json'); screens=sm.get('screens',[])
need(len(screens)>=5,'screen matrix too small')
for s in screens:
    need(bool(s.get('screen')) and bool(s.get('required_states')) and bool(s.get('acceptance')),f'incomplete screen contract {s.get("screen","")}')
ac=jload(A/'ASSET_COMPLETENESS_PHASE_Q.json')
need(ac.get('design_time_asset_status')=='COMPLETE','design-time asset closure not complete')
need(ac.get('marketing_screenshot_status') in ('COMPLETE_2880x1800_RGB_6_SHOTS_PRESENT', 'REAL_MAC_SIGNED_RELEASE_CAPTURE_REQUIRED'),'screenshot status must remain real-Mac capture')

# Phase Q UI automation completeness: every portfolio app ships a real UI-test target.
pbx_text=(R/'Keptora.xcodeproj'/'project.pbxproj').read_text(errors='replace')
scheme_text=(R/'Keptora.xcodeproj'/'xcshareddata'/'xcschemes'/'Keptora.xcscheme').read_text(errors='replace')
ui_test=R/'KeptoraUITests'/'KeptoraUITests.swift'
need(ui_test.exists(), 'KeptoraUITests source missing')
need('com.apple.product-type.bundle.ui-testing' in pbx_text and 'KeptoraUITests' in pbx_text, 'Keptora UI-testing target missing')
need('KeptoraUITests.xctest' in scheme_text, 'Keptora scheme does not execute UI tests')
need('-portfolioUITesting' in ui_test.read_text(errors='replace') and '-keptoraScreenshotReconciliation' in ui_test.read_text(errors='replace'), 'deterministic Keptora screenshot UI test missing')
ios_ui_test=R/'KeptoraiOSUITests'/'KeptoraiOSUITests.swift'
need(ios_ui_test.exists(), 'KeptoraiOSUITests source missing')
need('KeptoraiOSUITests' in pbx_text, 'Keptora iPhone UI-testing target missing')

if err:
    print('FAIL Phase Q'); [print(' - '+e) for e in err]; sys.exit(1)
print('PASS Phase Q non-Mac completion: source/content/privacy/assets/UI automation closed; real Mac/ASC evidence only')
