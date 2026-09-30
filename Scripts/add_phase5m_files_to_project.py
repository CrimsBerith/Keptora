#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Keptora.xcodeproj/project.pbxproj"
text = PROJECT.read_text()

build_files = """
		M10000000000000000000001 /* DemoLibraryFactory.swift in Sources */ = {isa = PBXBuildFile; fileRef = M20000000000000000000001 /* DemoLibraryFactory.swift */; };
		M10000000000000000000002 /* ReviewSessionCheckpointTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = M20000000000000000000002 /* ReviewSessionCheckpointTests.swift */; };
"""
file_refs = """
		M20000000000000000000001 /* DemoLibraryFactory.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "DemoLibraryFactory.swift"; sourceTree = "<group>"; };
		M20000000000000000000002 /* ReviewSessionCheckpointTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "ReviewSessionCheckpointTests.swift"; sourceTree = "<group>"; };
"""

if "M20000000000000000000001" not in text:
    text = text.replace("/* End PBXBuildFile section */", build_files + "/* End PBXBuildFile section */")
    text = text.replace("/* End PBXFileReference section */", file_refs + "/* End PBXFileReference section */")
    text = text.replace(
        "75F1834D604FE98185A44914 /* FileSystemAdapter */ = {isa = PBXGroup; children = (",
        "75F1834D604FE98185A44914 /* FileSystemAdapter */ = {isa = PBXGroup; children = (M20000000000000000000001 /* DemoLibraryFactory.swift */, "
    )
    text = text.replace(
        "AA8B3A142902F2DBCB23F71E /* KeptoraTests */ = {isa = PBXGroup; children = (",
        "AA8B3A142902F2DBCB23F71E /* KeptoraTests */ = {isa = PBXGroup; children = (M20000000000000000000002 /* ReviewSessionCheckpointTests.swift */, "
    )
    text = text.replace(
        "8682261519D15BD64A9E5D31 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (",
        "8682261519D15BD64A9E5D31 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (M10000000000000000000001 /* DemoLibraryFactory.swift in Sources */, "
    )
    text = text.replace(
        "29BEEA3D856852A8CC3247ED = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (",
        "29BEEA3D856852A8CC3247ED = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (M10000000000000000000002 /* ReviewSessionCheckpointTests.swift in Sources */, "
    )

PROJECT.write_text(text)
print("Phase 5M project references ensured.")
