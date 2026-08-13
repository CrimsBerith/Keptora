#!/usr/bin/env python3
from pathlib import Path
import json, re, plistlib, sys
ROOT=Path(__file__).resolve().parents[1]
CFG=ROOT/'Release'/'phase_n_release_inputs.local.json'
if not CFG.exists():
    raise SystemExit('BLOCKED: create Release/phase_n_release_inputs.local.json from template')
cfg=json.loads(CFG.read_text())
required=['development_team','bundle_identifier','lifetime_product_id','privacy_url','support_url','marketing_url']
for k in required:
    v=str(cfg.get(k,'')).strip()
    if not v or 'REPLACE_' in v or 'yourcompany' in v or '.example' in v or 'example.com' in v:
        raise SystemExit(f'BLOCKED: unresolved {k}')
if not re.fullmatch(r'[A-Z0-9]{10}', cfg['development_team']): raise SystemExit('BLOCKED: development_team must be 10 uppercase alphanumeric characters')
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', cfg['bundle_identifier']): raise SystemExit('BLOCKED: invalid bundle_identifier')
for k in ['privacy_url','support_url','marketing_url']:
    if not str(cfg[k]).startswith('https://'): raise SystemExit(f'BLOCKED: {k} must use HTTPS')
projects=list(ROOT.glob('*.xcodeproj/project.pbxproj'))
if len(projects)!=1: raise SystemExit('BLOCKED: expected exactly one Xcode project')
pbx=projects[0]
s=pbx.read_text()
ids=[x.strip('"') for x in re.findall(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*("?[^";]+"?)\s*;',s)]
main=next((x for x in ids if not x.endswith('.tests') and not x.endswith('.uitests') and '$(' not in x),None)
if not main: raise SystemExit('BLOCKED: cannot determine current app bundle ID')
old_products=re.findall(r'APP_LIFETIME_PRODUCT_ID\s*=\s*"?([^";]+)"?\s*;',s)
old_product=old_products[0] if old_products else None
new=cfg['bundle_identifier']
s=s.replace(main+'.uitests',new+'.uitests').replace(main+'.tests',new+'.tests').replace(main,new)
s=re.sub(r'DEVELOPMENT_TEAM\s*=\s*"?"?\s*;',f'DEVELOPMENT_TEAM = {cfg["development_team"]};',s)
if old_product: s=s.replace(old_product,cfg['lifetime_product_id'])
pbx.write_text(s)
infos=list(ROOT.glob('*/Resources/Info.plist'))
if len(infos)!=1: raise SystemExit('BLOCKED: expected one Info.plist')
info_path=infos[0]
with info_path.open('rb') as f: info=plistlib.load(f)
info['APP_LIFETIME_PRODUCT_ID']=cfg['lifetime_product_id']
info['APP_PRIVACY_POLICY_URL']=cfg['privacy_url']
info['APP_SUPPORT_URL']=cfg['support_url']
info['APP_MARKETING_URL']=cfg['marketing_url']
with info_path.open('wb') as f: plistlib.dump(info,f,sort_keys=False)
for sk in ROOT.glob('*/Resources/*.storekit'):
    data=json.loads(sk.read_text())
    def walk(x):
        if isinstance(x,dict): return {k:walk(v) for k,v in x.items()}
        if isinstance(x,list): return [walk(v) for v in x]
        if isinstance(x,str) and (x==old_product or ('yourcompany' in x and x.endswith('.pro.lifetime'))): return cfg['lifetime_product_id']
        return x
    sk.write_text(json.dumps(walk(data),indent=2,ensure_ascii=False)+'\n')
for rc in [ROOT/'Release'/'release-config.json']:
    if rc.exists():
        try: d=json.loads(rc.read_text())
        except Exception: continue
        aliases={
          'bundle_id':'bundle_identifier','bundleIdentifier':'bundle_identifier',
          'development_team':'development_team','developmentTeam':'development_team','team_id':'development_team',
          'lifetime_product_id':'lifetime_product_id','lifetimeProductID':'lifetime_product_id',
          'support_url':'support_url','supportURL':'support_url','privacy_url':'privacy_url','privacyURL':'privacy_url',
          'marketing_url':'marketing_url','marketingURL':'marketing_url'}
        for rk,ck in aliases.items():
            if rk in d: d[rk]=cfg[ck]
        rc.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
print('PASS: Phase N release identity applied deterministically')
