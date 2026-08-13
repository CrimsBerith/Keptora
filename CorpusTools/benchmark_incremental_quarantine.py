#!/usr/bin/env python3
"""Cross-platform smoke benchmark for Cullora Phase 5H semantics.

This does not execute the macOS Swift target. It independently validates the expected
incremental-index and reversible-quarantine invariants using deterministic files,
SQLite, SHA-256, and Ed25519 signatures.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat


@dataclass(frozen=True)
class ScanStats:
    discovered: int
    hashed: int
    reused: int
    missing: int


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def init_db(path: Path) -> sqlite3.Connection:
    db = sqlite3.connect(path)
    db.executescript(
        """
        PRAGMA journal_mode=WAL;
        CREATE TABLE assets(
            path TEXT PRIMARY KEY,
            size INTEGER NOT NULL,
            mtime_ns INTEGER NOT NULL,
            digest TEXT NOT NULL,
            last_seen_scan TEXT,
            is_missing INTEGER NOT NULL DEFAULT 0,
            is_quarantined INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    return db


def scan(root: Path, db: sqlite3.Connection, scan_id: str) -> ScanStats:
    files = sorted(
        p for p in root.rglob("*")
        if p.is_file() and ".Cullora Quarantine" not in p.parts
    )
    hashed = reused = 0
    for path in files:
        stat = path.stat()
        row = db.execute(
            "SELECT size,mtime_ns,digest,is_quarantined FROM assets WHERE path=?",
            (str(path),),
        ).fetchone()
        if row and row[0] == stat.st_size and row[1] == stat.st_mtime_ns and row[2] and row[3] == 0:
            reused += 1
            digest = row[2]
        else:
            hashed += 1
            digest = sha256(path)
        db.execute(
            """
            INSERT INTO assets(path,size,mtime_ns,digest,last_seen_scan,is_missing,is_quarantined)
            VALUES(?,?,?,?,?,0,0)
            ON CONFLICT(path) DO UPDATE SET
                size=excluded.size,mtime_ns=excluded.mtime_ns,digest=excluded.digest,
                last_seen_scan=excluded.last_seen_scan,is_missing=0,is_quarantined=0
            """,
            (str(path), stat.st_size, stat.st_mtime_ns, digest, scan_id),
        )
    db.execute(
        """
        UPDATE assets SET is_missing=1
        WHERE is_quarantined=0 AND COALESCE(last_seen_scan,'')<>? AND is_missing=0
        """,
        (scan_id,),
    )
    missing = db.execute("SELECT changes()").fetchone()[0]
    db.commit()
    return ScanStats(len(files), hashed, reused, missing)


def create_fixture(root: Path, count: int) -> None:
    root.mkdir(parents=True, exist_ok=True)
    for index in range(count):
        payload = hashlib.sha256(f"base-{index}".encode()).digest() * 32
        (root / f"asset-{index:04d}.jpg").write_bytes(payload)
    # Three exact pairs in addition to the base set.
    for pair in range(3):
        payload = (root / f"asset-{pair:04d}.jpg").read_bytes()
        (root / f"exact-{pair:02d}-copy.jpg").write_bytes(payload)


def quarantine_and_restore(root: Path, db: sqlite3.Connection) -> dict[str, object]:
    source = root / "exact-00-copy.jpg"
    original_digest = sha256(source)
    plan_id = "phase5h-smoke-plan"
    quarantine = root / ".Cullora Quarantine" / plan_id / source.name
    payload = {
        "schemaVersion": 2,
        "planID": plan_id,
        "sourceRoot": str(root),
        "quarantineRoot": str(quarantine.parent),
        "createdAt": int(time.time() * 1000),
        "appVersion": "smoke",
        "operations": [{
            "operationID": "op-1",
            "assetID": str(source),
            "originalPath": str(source),
            "quarantinePath": str(quarantine),
            "byteCount": source.stat().st_size,
            "digest": original_digest,
        }],
    }
    canonical_payload = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    private_key = Ed25519PrivateKey.generate()
    signature = private_key.sign(canonical_payload)
    public_key = private_key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)

    quarantine.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(source, quarantine)
    db.execute(
        "UPDATE assets SET path=?,is_quarantined=1,is_missing=0 WHERE path=?",
        (str(quarantine), str(source)),
    )
    db.commit()

    private_key.public_key().verify(signature, canonical_payload)
    assert sha256(quarantine) == original_digest
    assert not source.exists() and quarantine.exists()

    source.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(quarantine, source)
    db.execute(
        "UPDATE assets SET path=?,is_quarantined=0,is_missing=0 WHERE path=?",
        (str(source), str(quarantine)),
    )
    db.commit()
    assert source.exists() and not quarantine.exists()
    assert sha256(source) == original_digest

    return {
        "plan_id": plan_id,
        "signature_base64": base64.b64encode(signature).decode(),
        "public_key_base64": base64.b64encode(public_key).decode(),
        "restored": True,
    }


def run(count: int) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix="cullora-phase5h-") as temporary:
        root = Path(temporary) / "Library"
        create_fixture(root, count)
        db = init_db(Path(temporary) / "index.sqlite")

        first = scan(root, db, "scan-1")
        second = scan(root, db, "scan-2")
        assert first.hashed == first.discovered
        assert second.hashed == 0 and second.reused == second.discovered

        # Mutate three, remove two, and add one. The next pass should hash four.
        for index in range(3):
            path = root / f"asset-{index + 10:04d}.jpg"
            path.write_bytes(path.read_bytes() + b"changed")
            os.utime(path, ns=(path.stat().st_atime_ns, path.stat().st_mtime_ns + 1_000_000))
        (root / "asset-0020.jpg").unlink()
        (root / "asset-0021.jpg").unlink()
        (root / "new-asset.jpg").write_bytes(b"new")
        third = scan(root, db, "scan-3")
        assert third.hashed == 4, third
        assert third.missing == 2, third

        recovery = quarantine_and_restore(root, db)
        return {
            "first_scan": first.__dict__,
            "warm_scan": second.__dict__,
            "delta_scan": third.__dict__,
            "quarantine_restore": recovery,
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=250)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    result = run(args.count)
    encoded = json.dumps(result, indent=2, sort_keys=True)
    if args.out:
        args.out.write_text(encoded + "\n")
    print(encoded)


if __name__ == "__main__":
    main()
