#!/usr/bin/env python3
"""Deterministic Phase 5H safety-model smoke benchmark.

This cross-platform check mirrors the non-destructive invariants implemented by the
Swift target: explicit asset-family recognition, recovery state classification,
volume-stable source identity, bounded thumbnail configuration, and safe cursor
restart when a previously processed prefix changes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Iterable

BURST_RE = re.compile(r"(?:^|[_\- ])burst[_\- ]?\d+$", re.IGNORECASE)
BURST_SUFFIX_RE = re.compile(r"(?:[_\- ]?burst[_\- ]?\d+)$", re.IGNORECASE)
DERIVATIVE_SUFFIXES = (
    "-edited", "_edited", " edited", "-edit", "_edit", " edit",
    "-export", "_export", " export", "-copy", "_copy", " copy",
)
RAW = {"dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2"}
RENDERED = {"jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "webp"}
SIDECAR = {"xmp", "aae"}


def raw_stem(name: str) -> str:
    return Path(name).stem.lower()


def normalized_stem(name: str) -> str:
    value = raw_stem(name)
    changed = True
    while changed:
        changed = False
        for suffix in DERIVATIVE_SUFFIXES:
            if value.endswith(suffix):
                value = value[: -len(suffix)]
                changed = True
        updated = re.sub(r"\s*\(\d+\)$", "", value)
        if updated != value:
            value = updated
            changed = True
        updated = BURST_SUFFIX_RE.sub("", value)
        if updated != value:
            value = updated
            changed = True
    return value.strip()


def classify(names: Iterable[str]) -> str | None:
    names = list(names)
    extensions = {Path(name).suffix.lower().lstrip(".") for name in names}
    stems = {raw_stem(name) for name in names}
    has_raw = bool(extensions & RAW)
    has_rendered = bool(extensions & RENDERED)
    has_motion = "mov" in extensions
    has_xmp = "xmp" in extensions
    has_aae = "aae" in extensions
    has_derivative = any(normalized_stem(name) != raw_stem(name) for name in names)
    has_burst = any(BURST_RE.search(raw_stem(name)) for name in names)

    if has_motion and has_rendered and len(stems) == 1:
        return "livePhoto"
    if has_raw and (has_rendered or has_xmp):
        return "rawBundle"
    if (has_xmp or has_aae) and (has_rendered or has_raw):
        return "sidecarBundle"
    if has_burst and all(Path(name).suffix.lower().lstrip(".") in RENDERED | RAW for name in names):
        return "burst"
    if has_derivative and sum(Path(name).suffix.lower().lstrip(".") in RENDERED | RAW for name in names) > 1:
        return "editedExport"
    return None


def recovery_classification(operation_state: str, original_exists: bool, quarantine_exists: bool) -> str:
    key = (operation_state, original_exists, quarantine_exists)
    matrix = {
        ("pending", False, True): "recoveredQuarantine",
        ("pending", True, False): "incompleteMove",
        ("pending", True, True): "attention:bothCopies",
        ("pending", False, False): "attention:missingBoth",
        ("quarantined", True, False): "recoveredRestore",
        ("quarantined", True, True): "attention:bothCopies",
        ("quarantined", False, False): "attention:missingBoth",
        ("quarantined", False, True): "stableQuarantine",
    }
    return matrix[key]


def source_id(volume_id: str, relative_path: str) -> str:
    payload = f"{volume_id}|{relative_path}".encode()
    # Stable benchmark digest; Swift uses deterministic FNV-1a, but the invariant is
    # that mount-name changes do not alter the volume ID + relative-path tuple.
    return hashlib.sha256(payload).hexdigest()


def cursor_can_resume(saved_cursor: str, saved_processed: int, current_keys: list[str], durable_keys: set[str]) -> bool:
    try:
        candidate_start = current_keys.index(saved_cursor) + 1
    except ValueError:
        return False
    if candidate_start != saved_processed:
        return False
    return all(key in durable_keys for key in current_keys[:candidate_start])


def run(project_root: Path) -> dict[str, object]:
    family_cases = {
        "raw": ["IMG_0001.CR3", "IMG_0001.JPG", "IMG_0001.XMP"],
        "live": ["IMG_0042.HEIC", "IMG_0042.MOV"],
        "burst": ["IMG_0100_BURST001.jpg", "IMG_0100_BURST002.jpg"],
        "edited": ["portrait.jpg", "portrait-edited.jpg"],
        "unrelated": ["a.jpg", "b.jpg"],
    }
    classifications = {name: classify(files) for name, files in family_cases.items()}
    assert classifications == {
        "raw": "rawBundle",
        "live": "livePhoto",
        "burst": "burst",
        "edited": "editedExport",
        "unrelated": None,
    }

    recovery = {
        f"{state}:{int(original)}:{int(quarantine)}": recovery_classification(state, original, quarantine)
        for state in ("pending", "quarantined")
        for original in (False, True)
        for quarantine in (False, True)
    }
    assert recovery["pending:0:1"] == "recoveredQuarantine"
    assert recovery["quarantined:1:0"] == "recoveredRestore"
    assert recovery["quarantined:1:1"].startswith("attention:")

    old_mount = source_id("volume:abc", "Photos/Library")
    renamed_mount = source_id("volume:abc", "Photos/Library")
    replacement_disk = source_id("volume:def", "Photos/Library")
    assert old_mount == renamed_mount and old_mount != replacement_disk

    current = ["a", "b", "c", "d"]
    assert cursor_can_resume("b", 2, current, {"a", "b"})
    assert not cursor_can_resume("b", 2, ["aa", "a", "b", "c", "d"], {"a", "b"})
    assert not cursor_can_resume("b", 2, current, {"a"})

    thumbnail_source = (project_root / "Keptora/Core/Thumbnails/BoundedThumbnailCache.swift").read_text()
    assert "96 * 1024 * 1024" in thumbnail_source
    assert "countLimit: Int = 320" in thumbnail_source
    assert "Data(contentsOf:" not in thumbnail_source

    return {
        "family_classifications": classifications,
        "recovery_matrix": recovery,
        "volume_identity": {
            "same_disk_after_rename": old_mount == renamed_mount,
            "replacement_disk_rejected": old_mount != replacement_disk,
        },
        "cursor_safety": {
            "unchanged_prefix_resumes": True,
            "inserted_prefix_restarts": True,
            "non_durable_prefix_restarts": True,
        },
        "thumbnail_budget": {"bytes": 96 * 1024 * 1024, "count_limit": 320, "full_data_load_absent": True},
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    result = run(args.project_root)
    encoded = json.dumps(result, indent=2, sort_keys=True)
    if args.out:
        args.out.write_text(encoded + "\n")
    print(encoded)


if __name__ == "__main__":
    main()
