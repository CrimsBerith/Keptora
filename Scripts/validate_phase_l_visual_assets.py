#!/usr/bin/env python3
from pathlib import Path
import json, re, struct, sys
ROOT=Path(__file__).resolve().parents[1]
APPSTORE=ROOT/'AppStore'
errors=[]; warnings=[]

def fail(msg): errors.append(msg)
def warn(msg): warnings.append(msg)

bp=APPSTORE/'SCREEN_AND_ASSET_BLUEPRINT.md'
ar=APPSTORE/'ASSET_REQUIREMENTS.json'
sm=APPSTORE/'SCREEN_STATE_MATRIX.json'
pm=APPSTORE/'ASSET_PROVENANCE_MANIFEST.json'
ac=APPSTORE/'VISUAL_ACCEPTANCE_CHECKLIST.md'
for p in (bp,ar,sm,pm,ac):
    if not p.exists(): fail(f'missing {p.relative_to(ROOT)}')

if not errors:
    req=json.loads(ar.read_text())
    matrix=json.loads(sm.read_text())
    prov=json.loads(pm.read_text())
    screens=req.get('screens',[])
    if not screens: fail('asset requirements has no screens')
    if len(matrix.get('screens',[])) != len(screens): fail('screen-state matrix count mismatch')
    if len(prov.get('screens',[])) != len(screens): fail('asset provenance screen count mismatch')
    names=[s.get('screen') for s in screens]
    mnames=[s.get('screen') for s in matrix.get('screens',[])]
    if names != mnames: fail('screen ordering/name mismatch')
    if len(names)!=len(set(names)): fail('duplicate screen names')
    if not all(s.get('required_states') for s in matrix.get('screens',[])): fail('screen missing required states')
    rules=req.get('rules',{})
    if rules.get('no_personal_data') is not True: fail('no_personal_data rule missing')
    if rules.get('no_shared_shell_assets') is not True: fail('no_shared_shell_assets rule missing')
    identity=req.get('identity','').strip()
    if not identity: fail('missing UI identity')

# AppIcon static integrity: validate when present; explicit blocker otherwise.
iconsets=list(ROOT.glob('**/Assets.xcassets/AppIcon.appiconset'))
if iconsets:
    iconset=iconsets[0]
    cj=iconset/'Contents.json'
    if not cj.exists(): fail('AppIcon Contents.json missing')
    else:
        data=json.loads(cj.read_text())
        images=data.get('images',[])
        refs=[x.get('filename') for x in images if x.get('filename')]
        if len(refs)<10: fail(f'AppIcon references only {len(refs)} files')
        for fn in refs:
            p=iconset/fn
            if not p.exists(): fail(f'missing AppIcon file {fn}')
            elif p.suffix.lower()=='.png':
                b=p.read_bytes()[:24]
                if len(b)<24 or b[:8]!=b'\x89PNG\r\n\x1a\n': fail(f'invalid PNG {fn}')
                else:
                    w,h=struct.unpack('>II',b[16:24])
                    if w!=h: fail(f'non-square AppIcon {fn}: {w}x{h}')
else:
    marker=APPSTORE/'AppIcon'/'PRODUCTION_ICON_REQUIREMENT.md'
    if not marker.exists(): fail('no AppIcon set and no explicit production icon blocker')
    else: warn('EXTERNAL_BLOCKER: final production AppIcon artwork required')

# Support/privacy source contract exists and is configurable rather than silently omitted.
source='\n'.join(p.read_text(errors='ignore') for p in ROOT.glob('**/*.swift'))
if 'privacy' not in source.lower(): warn('privacy link not discoverable in Swift source text')
if 'support' not in source.lower(): warn('support link not discoverable in Swift source text')

print(f'Phase L visual/asset gate: {"PASS" if not errors else "FAIL"}')
for w in warnings: print('WARN:',w)
for e in errors: print('ERROR:',e)
sys.exit(1 if errors else 0)
