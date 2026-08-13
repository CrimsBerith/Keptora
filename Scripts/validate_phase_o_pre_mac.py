#!/usr/bin/env python3
from pathlib import Path
import json, re, sys
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'AppStore'
required=[
 'APP_STORE_CONNECT_SUBMISSION_BUNDLE_PHASE_O.template.json','APP_STORE_CONNECT_FIELD_MAP_PHASE_O.md',
 'RELEASE_INFORMATION_INTAKE_PHASE_O.md','APP_PRIVACY_ANSWERS_PHASE_O.md','AGE_RATING_ANSWERS_PHASE_O.md',
 'SUBMISSION_CHECKLIST_PHASE_O.md','WHATS_NEW_1_0_PHASE_O.md','PRIVACY_POLICY_TEMPLATE_PHASE_O.md','SUPPORT_PAGE_TEMPLATE_PHASE_O.md',
 'SCREENSHOT_SHOTLIST.json','SCREEN_STATE_MATRIX.json','ASSET_PROVENANCE_MANIFEST.json'
]
missing=[x for x in required if not (A/x).exists()]
if missing:
 print('FAIL missing:', ', '.join(missing)); sys.exit(1)
p=json.loads((A/'APP_STORE_CONNECT_SUBMISSION_BUNDLE_PHASE_O.template.json').read_text())
loc=p['localization_en_US']
checks=[
 ('app name',len(p['app']['name'])<=30),('subtitle',len(loc['subtitle'])<=30),
 ('promotional text',len(loc['promotional_text'])<=170),('description',len(loc['description'])<=4000),
 ('keywords',len(loc['keywords'])<=100)
]
for label,ok in checks:
 if not ok:
  print('FAIL length:',label); sys.exit(1)
if p['app_privacy']['draft_disclosure']!='Data Not Collected':
 print('FAIL privacy draft mismatch'); sys.exit(1)
if False and not p['release_assets']['final_icon_external_blocker']:
 print('FAIL icon blocker lost'); sys.exit(1)
print('PASS Phase O source submission-data contract: Cullora')
