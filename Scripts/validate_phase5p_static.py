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

# Phase 5O is the cumulative regression gate; it accepts 5P as a declared successor.
base=['python3','Scripts/validate_phase5o_static.py'] + (['--release'] if args.release else [])
run(base)

info=plistlib.loads((ROOT/'Cullora/Resources/Info.plist').read_bytes())
project=(ROOT/'Cullora.xcodeproj/project.pbxproj').read_text()
review=(ROOT/'Cullora/Core/Models/ReviewModels.swift').read_text()
database=(ROOT/'Cullora/Core/Persistence/SQLiteDatabase.swift').read_text()
cleanup=(ROOT/'Cullora/Core/Models/CleanupModels.swift').read_text()
coordinator=(ROOT/'Cullora/Core/Cleanup/QuarantineCoordinator.swift').read_text()
app=(ROOT/'Cullora/App/AppModel.swift').read_text()
review_ui=(ROOT/'Cullora/Features/ReviewStudio/ReviewStudioView.swift').read_text()
safety_ui=(ROOT/'Cullora/Features/SafetyPlan/SafetyPlanSheet.swift').read_text()

require(info.get('CFBundleShortVersionString') in {'0.9.6','0.9.7','0.9.8','0.9.9'},'Phase 5P version must be 0.9.6 or successor 0.9.7')
require(str(info.get('CFBundleVersion')) in {'150','160','170','180'},'Phase 5P build must be 150 or successor 160')
require(('MARKETING_VERSION = "0.9.6"' in project) or ('MARKETING_VERSION = "0.9.7"' in project) or ('MARKETING_VERSION = "0.9.8"' in project) or ('MARKETING_VERSION = "0.9.9"' in project),'Project marketing version must be 0.9.6 or successor 0.9.8')
require(('CURRENT_PROJECT_VERSION = "150"' in project) or ('CURRENT_PROJECT_VERSION = "160"' in project) or ('CURRENT_PROJECT_VERSION = "170"' in project) or ('CURRENT_PROJECT_VERSION = "180"' in project),'Project build must be 150 or successor 170')
require(('implementationPhase: "5P"' in app) or ('implementationPhase: "5Q"' in app) or ('implementationPhase: "5R"' in app) or ('implementationPhase: "5S"' in app),'Diagnostics phase marker must be 5P or successor 5R')

require('ReviewDecisionEvidence' in review and 'ReviewDecisionEvidenceEngine' in review,'Decision evidence model/engine missing')
require('verifiedExactPlan' in review and 'needsReview' in review,'Fail-closed evidence states missing')
require('reasonCode: String' in review,'Persisted review decision reason code missing')
require('d.reason_code' in database and 'decisionReasonCode' in database,'Decision reason is not propagated from SQLite')
require('decisionUpdatedAt' in cleanup and 'canonicalAssetID' in cleanup,'Safety Plan provenance fields missing')
require(('schemaVersion: 3' in coordinator) or ('schemaVersion: 4' in coordinator),'Signed cleanup manifest must use schema 3 or successor 4 for decision provenance')
require('decisionReasonCode: $0.decisionReasonCode' in coordinator,'Decision reason not sealed into cleanup manifest')
require('DecisionEvidenceSheet' in review_ui and 'Decision Evidence…' in review_ui,'Decision Evidence UI missing')
require('Similarity suggestions never enter this evidence path' in review_ui,'Similarity safety boundary missing from evidence UI')
require('Decision proof' in safety_ui and 'provenanceCount' in safety_ui,'Safety Plan provenance summary missing')
require('signed manifest' in safety_ui.lower(),'Safety Plan does not explain sealed provenance')
require('ContentUnavailableView' not in ''.join(p.read_text() for p in (ROOT/'Cullora').rglob('*.swift')),'macOS 13-incompatible ContentUnavailableView introduced')
require('ReviewDecisionEvidenceTests' in (ROOT/'CulloraTests/ReviewSessionCheckpointTests.swift').read_text(),'Decision evidence XCTest source missing')
require('reasonCode == "user-batch-added-exact-extras"' in (ROOT/'CulloraTests/SQLiteDatabaseTests.swift').read_text(),'Batch provenance DB assertion missing')
require(('manifest.schemaVersion, 3' in (ROOT/'CulloraTests/RestorePreviewTests.swift').read_text()) or ('manifest.schemaVersion, 4' in (ROOT/'CulloraTests/RestorePreviewTests.swift').read_text()),'Signed manifest provenance assertion missing')

run(['swiftc','-typecheck','Scripts/VolumeIdentityLinuxStub.swift','Cullora/Core/Models/AssetDescriptor.swift','Cullora/Core/Models/FamilyModels.swift','Cullora/Core/Models/ReviewModels.swift'])
run(['swiftc','-O','Scripts/VolumeIdentityLinuxStub.swift','Cullora/Core/Models/AssetDescriptor.swift','Cullora/Core/Models/FamilyModels.swift','Cullora/Core/Models/ReviewModels.swift','Scripts/phase5p_review_evidence_smoke.swift','-o','/tmp/cullora_phase5p_review_evidence'])
if not errors:
    result=run(['/tmp/cullora_phase5p_review_evidence'])
    require('cullora-phase5p-review-evidence-ok' in result.stdout,'Phase 5P review evidence smoke did not complete')

print('Cullora Phase 5P static validation')
for e in errors: print('ERROR:',e)
if errors:
    print(f'FAILED: {len(errors)} error(s)')
    sys.exit(1)
print('PASS: 0 errors')
