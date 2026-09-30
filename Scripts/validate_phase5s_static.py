#!/usr/bin/env python3
from pathlib import Path
import argparse, plistlib, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(); parser.add_argument('--release', action='store_true'); args=parser.parse_args()
errors=[]
def require(c,m):
    if not c: errors.append(m)
def run(cmd, timeout=120):
    try:
        r=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True,timeout=timeout)
    except subprocess.TimeoutExpired:
        errors.append(f"Command timed out (not PASS): {' '.join(cmd)}")
        return None
    if r.returncode: errors.append(f"Command failed: {' '.join(cmd)}\n{r.stdout}{r.stderr}")
    return r
if args.release:
    run(['python3','Scripts/validate_phase5s_release_config.py'])
info=plistlib.loads((ROOT/'Keptora/Resources/Info.plist').read_bytes())
project=(ROOT/'Keptora.xcodeproj/project.pbxproj').read_text()
models=(ROOT/'Keptora/Core/Models/CleanupModels.swift').read_text()
coord=(ROOT/'Keptora/Core/Cleanup/QuarantineCoordinator.swift').read_text()
app=(ROOT/'Keptora/App/AppModel.swift').read_text()
ui=(ROOT/'Keptora/Features/History/HistoryView.swift').read_text()
tests=(ROOT/'KeptoraTests/QuarantineCoordinatorTests.swift').read_text()
require(info.get('CFBundleShortVersionString')=='1.0.0','Release version must be 1.0.0')
require(str(info.get('CFBundleVersion'))=='182','Release build must be 182')
require('MARKETING_VERSION = 1.0.0;' in project and 'CURRENT_PROJECT_VERSION = 182;' in project,'Xcode project must be 1.0.0/182')
require('implementationPhase: "5S"' in app,'Diagnostics phase must be 5S')
for token in ['QuarantineVerificationPhase','QuarantineVerificationState','QuarantineOperationVerificationState','QuarantineVerificationReport','QuarantineVerificationLineageRecord','QuarantineVerificationEngine']:
    require(token in models,f'Missing Phase 5S model: {token}')
require('manifestIdentityFingerprint' in models and 'reportFingerprint' in models,'Deterministic verification fingerprints missing')
require('phase: .postCommit' in coord and 'phase: .postRestore' in coord,'Automatic post-commit/post-restore verification missing')
require('func verifyLifecycle(planID:' in coord,'Explicit manual verification API missing')
require('fetchCleanupOperationStates' in coord and 'hashFile(at:' in coord,'Verification must read DB state and re-hash files')
require('QuarantineVerificationLineage.json' in app and 'appendQuarantineVerification' in app,'Append-only verification lineage store missing')
require('func verifyCleanupState' in app,'User-triggered read-only verification missing')
require('Verify State' in ui and 'keptora.history.verifyState.' in ui,'History Verify State UI/accessibility ID missing')
require('testQuarantineVerificationClassifiesUnexpectedOriginalAndTamper' in tests,'Tamper verification XCTest source missing')
require('testQuarantineVerificationLineageChainsCommitManualAndRestoreReviews' in tests,'Verification lineage XCTest source missing')
require('testQuarantineVerificationManifestFingerprintIsOperationOrderIndependent' in tests,'Manifest fingerprint XCTest source missing')
if sys.platform == 'linux':
    # Linux-only core smoke and benchmark. macOS uses Xcode build/test/archive instead.
    r=run(['bash','Scripts/validate_phase5s_core_linux.sh'])
    if r: require('keptora-phase5s-quarantine-verification-ok' in r.stdout,'Phase 5S real filesystem smoke did not complete')
    compile_cmd=['swiftc','-O','Scripts/VolumeIdentityLinuxStub.swift','Keptora/Core/Models/AssetDescriptor.swift','Keptora/Core/Models/FamilyModels.swift','Keptora/Core/Models/ReviewModels.swift','Keptora/Core/Models/RecoveryModels.swift','Keptora/Core/Models/CleanupModels.swift','Scripts/phase5s_verification_benchmark.swift','-o','/tmp/keptora_phase5s_benchmark']
    r=run(compile_cmd)
    if r and r.returncode==0:
        br=run(['/tmp/keptora_phase5s_benchmark'])
        if br: require('100k quarantine verification assessment:' in br.stdout,'Phase 5S 100K benchmark did not complete')
else:
    print('macOS: Linux-only filesystem smoke and Linux benchmark skipped; use Xcode release gate.')
print('Keptora universal Phase Q static validation')
for e in errors: print('ERROR:',e)
if errors:
    print(f'FAILED: {len(errors)} error(s)'); sys.exit(1)
print('PASS: 0 errors')
