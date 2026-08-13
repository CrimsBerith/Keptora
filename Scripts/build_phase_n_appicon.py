#!/usr/bin/env python3
from pathlib import Path
import json, subprocess, shutil, sys, os
ROOT=Path(__file__).resolve().parents[1]
src=ROOT/'AppStore'/'AppIcon'/'source-1024.png'
if not src.exists(): raise SystemExit('BLOCKED: place final square PNG at AppStore/AppIcon/source-1024.png')
assets=list(ROOT.glob('*/Resources/Assets.xcassets'))
if len(assets)!=1: raise SystemExit('BLOCKED: expected one Assets.xcassets')
appicon=assets[0]/'AppIcon.appiconset'; appicon.mkdir(parents=True,exist_ok=True)
slots=[('16x16','1x',16),('16x16','2x',32),('32x32','1x',32),('32x32','2x',64),('128x128','1x',128),('128x128','2x',256),('256x256','1x',256),('256x256','2x',512),('512x512','1x',512),('512x512','2x',1024)]
try:
    from PIL import Image
    im=Image.open(src)
    if im.width!=im.height or im.width<1024: raise SystemExit('BLOCKED: icon must be square and >=1024px')
    for size,scale,px in slots:
        out=appicon/f'icon_{px}x{px}.png'
        im.resize((px,px),Image.Resampling.LANCZOS).save(out,'PNG',optimize=True)
except ImportError:
    sips=shutil.which('sips')
    if not sips: raise SystemExit('BLOCKED: Pillow or macOS sips is required to render icon sizes')
    for size,scale,px in slots:
        out=appicon/f'icon_{px}x{px}.png'
        subprocess.run([sips,'-z',str(px),str(px),str(src),'--out',str(out)],check=True,stdout=subprocess.DEVNULL)
images=[]
for size,scale,px in slots:
    images.append({'idiom':'mac','size':size,'scale':scale,'filename':f'icon_{px}x{px}.png'})
(appicon/'Contents.json').write_text(json.dumps({'images':images,'info':{'author':'xcode','version':1}},indent=2)+'\n')
print('PASS: production AppIcon asset set generated from source-1024.png')
