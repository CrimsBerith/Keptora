#!/usr/bin/env python3
from pathlib import Path
import argparse, plistlib, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(); parser.add_argument('--release', action='store_true'); args=parser.parse_args()
errors=[]
def require(cond,msg):
    if not cond: errors.append(msg)
def run(cmd):
    r=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if r.returncode: errors.append(f"Command failed: {' '.join(cmd)}\n{r.stdout}{r.stderr}")
    return r
run(['python3','Scripts/validate_phase5q_static.py'] + (['--release'] if args.release else []))
info=plistlib.loads((ROOT/'Cullora/Resources/Info.plist').read_bytes())
project=(ROOT/'Cullora.xcodeproj/project.pbxproj').read_text()
models=(ROOT/'Cullora/Core/Models/CleanupModels.swift').read_text()
coord=(ROOT/'Cullora/Core/Cleanup/QuarantineCoordinator.swift').read_text()
app=(ROOT/'Cullora/App/AppModel.swift').read_text()
ui=(ROOT/'Cullora/Features/SafetyPlan/SafetyPlanSheet.swift').read_text()
test=(ROOT/'CulloraTests/QuarantineCoordinatorTests.swift').read_text()
restore=(ROOT/'CulloraTests/RestorePreviewTests.swift').read_text()
require(info.get('CFBundleShortVersionString') in {'0.9.8','0.9.9'},'Phase 5R version must be 0.9.8 or successor 0.9.9')
require(str(info.get('CFBundleVersion')) in {'170','180'},'Phase 5R build must be 170 or successor 180')
require((('MARKETING_VERSION = "0.9.8"' in project) and ('CURRENT_PROJECT_VERSION = "170"' in project)) or (('MARKETING_VERSION = "0.9.9"' in project) and ('CURRENT_PROJECT_VERSION = "180"' in project)),'Project version/build must be 0.9.8/170 or successor 0.9.9/180')
require(('implementationPhase: "5R"' in app) or ('implementationPhase: "5S"' in app),'Diagnostics phase marker must be 5R or successor 5S')
require('SafetyPlanDecisionFingerprint' in models and 'CulloraSafetyPlanSHA256' in models,'SHA-256 decision snapshot fingerprint engine missing')
require('rows.sorted()' in models,'Decision fingerprint must be order-independent')
require('SafetyPlanLineageIdentity' in models and 'SafetyPlanLineageRecord' in models and 'SafetyPlanLineageEngine' in models,'Safety Plan lineage model missing')
require('decisionSnapshotFingerprint' in models and 'lineage: SafetyPlanLineageIdentity?' in models,'Cleanup plan does not carry freshness/lineage identity')
require('safetyPlanLineageID' in models and 'safetyPlanRevision' in models,'Signed cleanup manifest lineage fields missing')
require('func assessFreshness(_ plan: CleanupPlanPreview)' in coord and 'fetchCleanupCandidates' in coord and 'throw CleanupError.staleSafetyPlan' in coord,'Coordinator-level fail-closed freshness gate missing')
require('schemaVersion: 4' in coord,'Signed cleanup manifest must use schema 4')
require('decisionSnapshotFingerprint: plan.decisionSnapshotFingerprint' in coord,'Decision fingerprint not sealed into manifest')
require('guard freshness.permitsCommit else' in app and 'cleanupCoordinator.assessFreshness(plan)' in app,'Fail-closed pre-move freshness gate missing')
require('SafetyPlanLineage.json' in app and 'appendSafetyPlanLineage' in app and 'markSafetyPlanLineage' in app,'Local Safety Plan lineage store missing')
require('regenerateSafetyPlan' in app and '.superseded' in app,'Explicit stale-plan regeneration/supersession flow missing')
require('Stale — regenerate' in models and 'Regenerate Plan' in ui and 'safetyPlanFreshness?.permitsCommit != true' in ui,'Stale plan UI/commit disable gate missing')
require('Safety Plan lineage R' in ui and 'Revision' in ui,'Safety Plan lineage identity not visible')
require('testPreparedSafetyPlanBecomesStaleWhenReviewDecisionChanges' in test,'Freshness integration XCTest source missing')
require('testSafetyPlanFingerprintIsOrderIndependentAndDecisionSensitive' in test,'Fingerprint XCTest source missing')
require('testSafetyPlanLineageRevisionChainsPerSource' in test,'Lineage XCTest source missing')
require('manifest.schemaVersion, 4' in restore and 'manifest.decisionSnapshotFingerprint' in restore,'Schema-4 manifest provenance XCTest assertion missing')
# Compile and run the pure Foundation lineage/fingerprint core on Linux.
compile_cmd=['swiftc','-O','Scripts/VolumeIdentityLinuxStub.swift','Cullora/Core/Models/AssetDescriptor.swift','Cullora/Core/Models/FamilyModels.swift','Cullora/Core/Models/ReviewModels.swift','Cullora/Core/Models/RecoveryModels.swift','Cullora/Core/Models/CleanupModels.swift','Scripts/phase5r_safety_plan_lineage_smoke.swift','-o','/tmp/cullora_phase5r_lineage']
run(compile_cmd)
if not errors:
    r=run(['/tmp/cullora_phase5r_lineage'])
    require('cullora-phase5r-safety-plan-lineage-ok' in r.stdout,'Phase 5R lineage smoke/benchmark did not complete')
print('Cullora Phase 5R static validation')
for e in errors: print('ERROR:',e)
if errors:
    print(f'FAILED: {len(errors)} error(s)'); sys.exit(1)
print('PASS: 0 errors')
