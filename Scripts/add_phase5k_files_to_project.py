#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Keptora.xcodeproj/project.pbxproj"
text = PROJECT.read_text()

build_files = """
		K10000000000000000000001 /* AccessPolicy.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000001 /* AccessPolicy.swift */; };
		K10000000000000000000002 /* StoreEntitlementController.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000002 /* StoreEntitlementController.swift */; };
		K10000000000000000000003 /* DiagnosticsSnapshot.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000003 /* DiagnosticsSnapshot.swift */; };
		K10000000000000000000004 /* OnboardingView.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000004 /* OnboardingView.swift */; };
		K10000000000000000000005 /* PaywallView.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000005 /* PaywallView.swift */; };
		K10000000000000000000006 /* DiagnosticsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000006 /* DiagnosticsView.swift */; };
		K10000000000000000000007 /* AccessPolicyTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000007 /* AccessPolicyTests.swift */; };
		K10000000000000000000008 /* DiagnosticsRedactionTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = K20000000000000000000008 /* DiagnosticsRedactionTests.swift */; };
"""
file_refs = """
		K20000000000000000000001 /* AccessPolicy.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "AccessPolicy.swift"; sourceTree = "<group>"; };
		K20000000000000000000002 /* StoreEntitlementController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "StoreEntitlementController.swift"; sourceTree = "<group>"; };
		K20000000000000000000003 /* DiagnosticsSnapshot.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "DiagnosticsSnapshot.swift"; sourceTree = "<group>"; };
		K20000000000000000000004 /* OnboardingView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "OnboardingView.swift"; sourceTree = "<group>"; };
		K20000000000000000000005 /* PaywallView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "PaywallView.swift"; sourceTree = "<group>"; };
		K20000000000000000000006 /* DiagnosticsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "DiagnosticsView.swift"; sourceTree = "<group>"; };
		K20000000000000000000007 /* AccessPolicyTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "AccessPolicyTests.swift"; sourceTree = "<group>"; };
		K20000000000000000000008 /* DiagnosticsRedactionTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "DiagnosticsRedactionTests.swift"; sourceTree = "<group>"; };
"""
groups = """
		K30000000000000000000001 /* Purchases */ = {isa = PBXGroup; children = (K20000000000000000000001 /* AccessPolicy.swift */, K20000000000000000000002 /* StoreEntitlementController.swift */); path = "Purchases"; sourceTree = "<group>"; };
		K30000000000000000000002 /* Onboarding */ = {isa = PBXGroup; children = (K20000000000000000000004 /* OnboardingView.swift */); path = "Onboarding"; sourceTree = "<group>"; };
		K30000000000000000000003 /* Paywall */ = {isa = PBXGroup; children = (K20000000000000000000005 /* PaywallView.swift */); path = "Paywall"; sourceTree = "<group>"; };
		K30000000000000000000004 /* Feature Diagnostics */ = {isa = PBXGroup; children = (K20000000000000000000006 /* DiagnosticsView.swift */); path = "Diagnostics"; sourceTree = "<group>"; };
"""

if "K20000000000000000000001" not in text:
    text = text.replace("/* End PBXBuildFile section */", build_files + "/* End PBXBuildFile section */")
    text = text.replace("/* End PBXFileReference section */", file_refs + "/* End PBXFileReference section */")
    text = text.replace("/* End PBXGroup section */", groups + "/* End PBXGroup section */")

    text = text.replace(
        "67D81EB26C9B6E4AB8891E19 /* Core */ = {isa = PBXGroup; children = (",
        "67D81EB26C9B6E4AB8891E19 /* Core */ = {isa = PBXGroup; children = (K30000000000000000000001 /* Purchases */, "
    )
    text = text.replace(
        "147D2C05794D06EEEAAC0F45 /* Diagnostics */ = {isa = PBXGroup; children = (188B0D467D460915ED4D8A55 /* PerformanceRecorder.swift */);",
        "147D2C05794D06EEEAAC0F45 /* Diagnostics */ = {isa = PBXGroup; children = (188B0D467D460915ED4D8A55 /* PerformanceRecorder.swift */, K20000000000000000000003 /* DiagnosticsSnapshot.swift */);"
    )
    text = text.replace(
        "C94001D923A81127C5A56457 /* Features */ = {isa = PBXGroup; children = (",
        "C94001D923A81127C5A56457 /* Features */ = {isa = PBXGroup; children = (K30000000000000000000004 /* Feature Diagnostics */, K30000000000000000000002 /* Onboarding */, K30000000000000000000003 /* Paywall */, "
    )
    text = text.replace(
        "AA8B3A142902F2DBCB23F71E /* KeptoraTests */ = {isa = PBXGroup; children = (",
        "AA8B3A142902F2DBCB23F71E /* KeptoraTests */ = {isa = PBXGroup; children = (K20000000000000000000007 /* AccessPolicyTests.swift */, K20000000000000000000008 /* DiagnosticsRedactionTests.swift */, "
    )
    text = text.replace(
        "8682261519D15BD64A9E5D31 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (",
        "8682261519D15BD64A9E5D31 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (K10000000000000000000001 /* AccessPolicy.swift in Sources */, K10000000000000000000002 /* StoreEntitlementController.swift in Sources */, K10000000000000000000003 /* DiagnosticsSnapshot.swift in Sources */, K10000000000000000000004 /* OnboardingView.swift in Sources */, K10000000000000000000005 /* PaywallView.swift in Sources */, K10000000000000000000006 /* DiagnosticsView.swift in Sources */, "
    )
    text = text.replace(
        "29BEEA3D856852A8CC3247ED = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (",
        "29BEEA3D856852A8CC3247ED = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (K10000000000000000000007 /* AccessPolicyTests.swift in Sources */, K10000000000000000000008 /* DiagnosticsRedactionTests.swift in Sources */, "
    )

PROJECT.write_text(text)
print("Phase 5K project references ensured.")
