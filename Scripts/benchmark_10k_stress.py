#!/usr/bin/env python3
import os
import sys
import time
import shutil
import hashlib
from pathlib import Path

def make_valid_jpeg(identifier: str, width=64, height=64) -> bytes:
    # Generates a valid JPEG with unique byte markers and content
    header = bytes.fromhex('ffd8ffe000104a46494600010101004800480000ffdb004300080606070605080707070909080a0c140d0c0b0b0c1912130f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d38323c2e333432ffc0000b080040004001012200ffda0008010100003f00')
    payload = identifier.encode('utf-8') + os.urandom(64)
    footer = bytes.fromhex('ffd9')
    return header + payload + footer

def generate_10k_corpus(dest_path: Path):
    if dest_path.exists():
        shutil.rmtree(dest_path)
    dest_path.mkdir(parents=True, exist_ok=True)
    
    print(f"Generating 10,000 test files at: {dest_path}")
    t0 = time.time()
    
    # Subdirectories
    dirs = [
        dest_path / "Vacation_2025" / "Day_1",
        dest_path / "Vacation_2025" / "Day_2",
        dest_path / "Portraits",
        dest_path / "Camera_RAW",
        dest_path / "Screenshots" / "2026",
        dest_path / "Duplicates_Folder_A",
        dest_path / "Duplicates_Folder_B",
        dest_path / "Bursts" / "Action_01",
        dest_path / "Archive" / "Sub_1",
        dest_path / "Archive" / "Sub_2"
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
        
    created = 0
    duplicate_sets = 0
    unique_count = 0
    family_count = 0
    
    # 1. 1,500 Duplicate Sets (yielding ~3,800 duplicate copies across folders)
    for i in range(1500):
        data = make_valid_jpeg(f"dup_set_{i}")
        dir_a = dirs[i % len(dirs)]
        dir_b = dirs[(i + 3) % len(dirs)]
        
        # Keeper
        with open(dir_a / f"IMG_{i:05d}.jpg", "wb") as f:
            f.write(data)
        created += 1
        
        # Copy 1
        with open(dir_b / f"IMG_{i:05d}_copy.jpg", "wb") as f:
            f.write(data)
        created += 1
        
        # Some sets have a 3rd copy (800 of them)
        if i < 800:
            dir_c = dirs[(i + 5) % len(dirs)]
            with open(dir_c / f"IMG_{i:05d}_backup.jpg", "wb") as f:
                f.write(data)
            created += 1
        duplicate_sets += 1
        
    # 2. 4,500 Unique Photos
    for i in range(4500):
        data = make_valid_jpeg(f"unique_{i}_{time.time()}")
        target_dir = dirs[i % len(dirs)]
        ext = "jpg" if i % 5 != 0 else "png"
        with open(target_dir / f"Photo_{i:05d}.{ext}", "wb") as f:
            f.write(data)
        created += 1
        unique_count += 1
        
    # 3. 500 RAW + JPEG + XMP Families (1,500 files)
    cam_dir = dest_path / "Camera_RAW"
    for i in range(500):
        jpeg_data = make_valid_jpeg(f"raw_pair_{i}")
        raw_name = f"DSC_{i:04d}.CR2"
        jpg_name = f"DSC_{i:04d}.jpg"
        xmp_name = f"DSC_{i:04d}.xmp"
        
        with open(cam_dir / jpg_name, "wb") as f:
            f.write(jpeg_data)
        with open(cam_dir / raw_name, "wb") as f:
            f.write(jpeg_data + b"_raw_meta")
        with open(cam_dir / xmp_name, "w") as f:
            f.write(f'<?xpacket begin=""?><x:xmpmeta><rdf:RDF><rdf:Description cullora:rating="{i%5}"/></rdf:RDF></x:xmpmeta>')
        created += 3
        family_count += 1
        
    # 4. Remaining files up to 10,000
    remainder = 10000 - created
    for i in range(remainder):
        data = make_valid_jpeg(f"fill_{i}")
        with open(dirs[0] / f"Extra_{i:04d}.jpg", "wb") as f:
            f.write(data)
        created += 1
        
    elapsed = time.time() - t0
    print(f"Generated {created} files in {elapsed:.2f}s:")
    print(f"  - {duplicate_sets} duplicate sets ({3800} duplicate files)")
    print(f"  - {unique_count} unique files")
    print(f"  - {family_count} RAW+JPEG+XMP family sets (1,500 files)")
    print(f"  - Total file count: {created}")

if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/keptora_stress_corpus_10k")
    generate_10k_corpus(target)
