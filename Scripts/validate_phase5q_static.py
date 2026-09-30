#!/usr/bin/env python3
from pathlib import Path
import argparse, plistlib, subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--release', action='store_true')
args=parser.parse_args()
errors=[]

def require(cond,msg):
    if not cond: errors.append(msg)

def run(cmd):
    result=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if result.returncode:
        errors.append(f"Command failed: {' '.join(cmd)}\n{result.stdout}{result.stderr}")
    return result

info=plistlib.loads((ROOT/'Keptora/Resources/Info.plist').read_bytes())
project=(ROOT/'Keptora.xcodeproj/project.pbxproj').read_text()
root_ui=(ROOT/'Keptora/App/MainRootView.swift').read_text()
review=(ROOT/'Keptora/Features/ReviewStudio/ReviewStudioView.swift').read_text()
design=(ROOT/'Keptora/DesignSystem/DesignTokens.swift').read_text()
app=(ROOT/'Keptora/App/AppModel.swift').read_text()

require(info.get('CFBundleShortVersionString') == '1.0.0','Release version must be 1.0.0')
require(str(info.get('CFBundleVersion')) == '182','Release build must be 182')
require('MARKETING_VERSION = 1.0.0;' in project and 'CURRENT_PROJECT_VERSION = 182;' in project,'Project must be 1.0.0/182')
require('implementationPhase: "5S"' in app,'Diagnostics phase marker must be the current Phase 5S flow')

# Portfolio master-lock alignment.
require('NavigationSplitView' not in root_ui,'Permanent NavigationSplitView remains in root shell')
require('WorkspaceTicket' in root_ui and 'Archive Review Studio' in root_ui,'Horizontal Workspace Shelf identity missing')
require('TicketShape' in root_ui,'Keptora-specific ticket geometry missing')
require('HSplitView' not in review,'Permanent three-panel HSplitView remains in Review Studio')
require('.listStyle(.sidebar)' not in review,'Sidebar list style remains in Review Studio')
require('isQueuePresented' in review and 'isEvidencePresented' in review,'Transient queue/evidence drawer state missing')
require('Open the temporary review queue' in review,'Temporary review queue affordance missing')
require('Open the temporary evidence drawer' in review,'Temporary evidence drawer affordance missing')
require('.overlay(alignment: .leading)' in review and '.overlay(alignment: .trailing)' in review,'Transient edge drawers missing')
require('Decision Shelf' in review,'Bottom Decision Shelf accessibility identity missing')
require('.safeAreaInset(edge: .bottom)' in review,'Decision Shelf is not anchored as bottom workflow surface')
require('Similarity suggestions never enter this evidence path' in review,'Phase 5P similarity evidence safety boundary regressed')
require('ticketSelected' in design and 'reviewFloor' in design and 'drawerSurface' in design,'Phase 5Q design tokens missing')

# macOS 13 parse/runtime compatibility guard.
require('ContentUnavailableView' not in ''.join(p.read_text() for p in (ROOT/'Keptora').rglob('*.swift')),'macOS 13-incompatible ContentUnavailableView introduced')
print('Keptora Phase 5Q static validation')
for e in errors: print('ERROR:',e)
if errors:
    print(f'FAILED: {len(errors)} error(s)')
    sys.exit(1)
print('PASS: 0 errors')
