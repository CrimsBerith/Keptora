#!/usr/bin/env python3
"""Deterministic 100K-catalog benchmark for Keptora Phase 5I candidate generation.

This benchmark validates the sub-quadratic dHash band index. It does not execute
Apple Vision; the Vision feature-print benchmark is intentionally macOS-only.
"""
from __future__ import annotations

import argparse
import json
import random
import time
import tracemalloc
from collections import defaultdict
from pathlib import Path


def bands(value: int, width: int = 16, offsets: tuple[int, ...] = (0, 8)) -> list[int]:
    mask = (1 << width) - 1
    result: list[int] = []
    for offset in offsets:
        rotated = value if offset == 0 else ((value >> offset) | (value << (64 - offset))) & ((1 << 64) - 1)
        result.extend((rotated >> (index * width)) & mask for index in range(64 // width))
    return result


def hamming(a: int, b: int) -> int:
    # Python 3.9 on supported macOS/Xcode environments has no int.bit_count().
    return bin(a ^ b).count("1")


def build_catalog(size: int, seed: int) -> tuple[list[int], set[tuple[int, int]]]:
    rng = random.Random(seed)
    clustered = min(size // 5, 20_000)
    cluster_count = clustered // 4
    hashes: list[int] = []
    planted: set[tuple[int, int]] = set()
    for _ in range(cluster_count):
        base_index = len(hashes)
        base = rng.getrandbits(64)
        hashes.append(base)
        for variant in range(1, 4):
            candidate = base
            # Flip a few deterministic bits while preserving most 16-bit bands.
            for _ in range(variant + 1):
                candidate ^= 1 << rng.randrange(64)
            hashes.append(candidate)
            planted.add((base_index, base_index + variant))
    while len(hashes) < size:
        hashes.append(rng.getrandbits(64))
    return hashes, planted


def benchmark(size: int, seed: int, max_candidates: int = 400, max_hamming: int = 14) -> dict:
    hashes, planted = build_catalog(size, seed)
    tracemalloc.start()
    build_started = time.perf_counter()
    buckets: dict[tuple[int, int], list[int]] = defaultdict(list)
    for asset_id, value in enumerate(hashes):
        for band_index, band_value in enumerate(bands(value)):
            buckets[(band_index, band_value)].append(asset_id)
    build_seconds = time.perf_counter() - build_started

    query_started = time.perf_counter()
    total_candidates = 0
    maximum_bucket_union = 0
    recovered_planted = 0
    planted_by_anchor: dict[int, set[int]] = defaultdict(set)
    for first, second in planted:
        planted_by_anchor[first].add(second)

    for asset_id, value in enumerate(hashes):
        union: set[int] = set()
        for band_index, band_value in enumerate(bands(value)):
            union.update(buckets[(band_index, band_value)])
        union.discard(asset_id)
        maximum_bucket_union = max(maximum_bucket_union, len(union))
        ranked = sorted(
            ((candidate, hamming(value, hashes[candidate])) for candidate in union),
            key=lambda item: (item[1], item[0]),
        )
        accepted = [candidate for candidate, distance in ranked if distance <= max_hamming][:max_candidates]
        total_candidates += len(accepted)
        if asset_id in planted_by_anchor:
            recovered_planted += len(planted_by_anchor[asset_id].intersection(accepted))

    query_seconds = time.perf_counter() - query_started
    _, peak_bytes = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    naive_pairs = size * (size - 1) // 2
    candidate_pairs = total_candidates // 2
    return {
        "phase": "5I",
        "catalogSize": size,
        "bandCount": 8,
        "bandBitWidth": 16,
        "rotationOffsets": [0, 8],
        "maximumHammingDistance": max_hamming,
        "maximumCandidatesPerAsset": max_candidates,
        "bucketCount": len(buckets),
        "buildSeconds": round(build_seconds, 4),
        "querySeconds": round(query_seconds, 4),
        "peakMemoryMiB": round(peak_bytes / 1024 / 1024, 2),
        "maximumRawBucketUnion": maximum_bucket_union,
        "averageAcceptedCandidates": round(total_candidates / max(1, size), 4),
        "candidatePairs": candidate_pairs,
        "naivePairs": naive_pairs,
        "pairReductionFactor": round(naive_pairs / max(1, candidate_pairs), 2),
        "plantedNearPairs": len(planted),
        "recoveredPlantedNearPairs": recovered_planted,
        "plantedRecall": round(recovered_planted / max(1, len(planted)), 6),
        "scopeNote": "Synthetic dHash candidate benchmark only; Apple Vision throughput must be measured on macOS hardware.",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, default=100_000)
    parser.add_argument("--seed", type=int, default=51)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = benchmark(args.size, args.seed)
    payload = json.dumps(result, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
    print(payload)


if __name__ == "__main__":
    main()
