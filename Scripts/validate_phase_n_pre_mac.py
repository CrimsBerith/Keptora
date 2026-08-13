#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
errors=[]
for p in ['Release/phase_n_release_inputs.template.json','Scripts/apply_phase_n_release_inputs.py','Scripts/build_phase_n_appicon.py','Docs/Phase_N/PHASE_N_RELEASE_IDENTITY_AND_ICON_HANDOFF.md','AppStore/AppIcon/INGEST_FINAL_ICON.md']:
    if not (ROOT/p).exists(): errors.append('missing '+p)
pbxs=list(ROOT.glob('*.xcodeproj/project.pbxproj'))
if len(pbxs)!=1: errors.append('expected one xcode project')
else:
    t=pbxs[0].read_text()
    if 'SWIFT_STRICT_CONCURRENCY' not in t: errors.append('strict concurrency setting missing')
infos=list(ROOT.glob('*/Resources/Info.plist'))
if len(infos)!=1: errors.append('expected one Info.plist')
else:
    import plistlib
    with infos[0].open('rb') as f: info=plistlib.load(f)
    if not info.get('APP_LIFETIME_PRODUCT_ID'): errors.append('lifetime product Info.plist key missing')
if errors:
    print('FAIL: Phase N source gate')
    [print(' - '+e) for e in errors]
    raise SystemExit(1)
print('PASS: Phase N source gate')
local=ROOT/'Release'/'phase_n_release_inputs.local.json'
if not local.exists():
    print('RELEASE_BLOCKED: developer identity/domain inputs intentionally unresolved')
else:
    c=json.loads(local.read_text())
    bad=[k for k,v in c.items() if isinstance(v,str) and ('REPLACE_' in v or 'yourcompany' in v or '.example' in v or 'example.com' in v)]
    print('RELEASE_BLOCKED: unresolved '+','.join(bad) if bad else 'RELEASE_INPUTS_READY')
req=ROOT/'AppStore'/'AppIcon'/'PRODUCTION_ICON_REQUIREMENT.md'
source=ROOT/'AppStore'/'AppIcon'/'source-1024.png'
if req.exists() and not source.exists(): print('RELEASE_BLOCKED: final 1024x1024 AppIcon artwork not supplied')
