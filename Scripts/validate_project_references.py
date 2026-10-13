#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
project = (root / "Keptora.xcodeproj/project.pbxproj").read_text()
missing = []
for folder in (root / "Keptora", root / "KeptoraTests", root / "KeptoraUITests", root / "KeptoraiOS", root / "KeptoraiOSTests", root / "KeptoraiOSUITests"):
    for path in sorted(folder.rglob("*.swift")):
        if path.name not in project:
            missing.append(str(path.relative_to(root)))
if missing:
    print("Swift files missing from Xcode project:")
    print("\n".join(f"- {item}" for item in missing))
    sys.exit(1)
print("All Swift sources are referenced by the Xcode project.")
