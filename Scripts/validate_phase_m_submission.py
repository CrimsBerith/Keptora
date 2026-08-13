#!/usr/bin/env python3
from pathlib import Path
import json, sys
root=Path(__file__).resolve().parents[1]
a=root/'AppStore'
errors=[]
for f in ['APP_STORE_CONNECT_PAYLOAD_TEMPLATE.json','SCREENSHOT_SHOTLIST.json','LOCALIZATION_MATRIX.json','RELEASE_ASSET_ACCEPTANCE.md']:
    if not (a/f).exists(): errors.append('missing '+f)
p=json.loads((a/'APP_STORE_CONNECT_PAYLOAD_TEMPLATE.json').read_text())
for k in ['app_name','subtitle','category','description','support_url','privacy_policy_url','review_notes']:
    if not str(p.get(k,'')).strip(): errors.append('empty '+k)
if len(p['subtitle'])>30: errors.append('subtitle >30 chars')
if len(p['description'])<140: errors.append('description too short')
s=json.loads((a/'SCREENSHOT_SHOTLIST.json').read_text())
if len(s.get('shots',[]))<5: errors.append('need >=5 screenshot surfaces')
if not all(x.get('synthetic_data_only') is True for x in s.get('shots',[])): errors.append('screenshot data policy')
if p.get('final_icon_external_blocker') not in (True,False): errors.append('icon blocker missing')
if errors:
 print('PHASE_M_FAIL:', '; '.join(errors)); sys.exit(1)
print('PHASE_M_PASS:',p['app_name'],len(s['shots']),'screens')
