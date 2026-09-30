#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Keptora.xcodeproj/project.pbxproj"
text = PROJECT.read_text()

build_files = """
		O10000000000000000000001 /* RestorePreviewSheet.swift in Sources */ = {isa = PBXBuildFile; fileRef = O20000000000000000000001 /* RestorePreviewSheet.swift */; };
		O10000000000000000000002 /* SourceExclusionPolicyTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = O20000000000000000000002 /* SourceExclusionPolicyTests.swift */; };
		O10000000000000000000003 /* RestorePreviewTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = O20000000000000000000003 /* RestorePreviewTests.swift */; };
"""
file_refs = """
		O20000000000000000000001 /* RestorePreviewSheet.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "RestorePreviewSheet.swift"; sourceTree = "<group>"; };
		O20000000000000000000002 /* SourceExclusionPolicyTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "SourceExclusionPolicyTests.swift"; sourceTree = "<group>"; };
		O20000000000000000000003 /* RestorePreviewTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "RestorePreviewTests.swift"; sourceTree = "<group>"; };
"""

if "O20000000000000000000001" not in text:
    text = text.replace("/* End PBXBuildFile section */", build_files + "/* End PBXBuildFile section */")
    text = text.replace("/* End PBXFileReference section */", file_refs + "/* End PBXFileReference section */")
    text = text.replace(
        "B84F9CA255C98F13967848B4 /* History */ = {isa = PBXGroup; children = (7FA39D3612A27CC7C623E5F4 /* HistoryView.swift */);",
        "B84F9CA255C98F13967848B4 /* History */ = {isa = PBXGroup; children = (7FA39D3612A27CC7C623E5F4 /* HistoryView.swift */, O20000000000000000000001 /* RestorePreviewSheet.swift */);"
    )
    text = text.replace(
        "AA8B3A142902F2DBCB23F71E /* KeptoraTests */ = {isa = PBXGroup; children = (",
        "AA8B3A142902F2DBCB23F71E /* KeptoraTests */ = {isa = PBXGroup; children = (O20000000000000000000002 /* SourceExclusionPolicyTests.swift */, O20000000000000000000003 /* RestorePreviewTests.swift */, "
    )
    text = text.replace(
        "8682261519D15BD64A9E5D31 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (",
        "8682261519D15BD64A9E5D31 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (O10000000000000000000001 /* RestorePreviewSheet.swift in Sources */, "
    )
    text = text.replace(
        "29BEEA3D856852A8CC3247ED = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (",
        "29BEEA3D856852A8CC3247ED = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (O10000000000000000000002 /* SourceExclusionPolicyTests.swift in Sources */, O10000000000000000000003 /* RestorePreviewTests.swift in Sources */, "
    )

PROJECT.write_text(text)
print("Phase 5O project references ensured.")
