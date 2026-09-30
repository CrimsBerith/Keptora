# Corpus and Performance — Phase 5I

## Deterministic 100K candidate benchmark

Run:

```bash
./CorpusTools/benchmark_similarity_100k.py --output ValidationArtifacts/similarity_100k.json
```

The benchmark creates 100,000 synthetic 64-bit visual hashes, including 15,000 planted near pairs. It measures the dual-offset band index, not Apple Vision execution.

Current container result is stored in `ValidationArtifacts/similarity_100k.json`. The candidate stage reduced the theoretical 4,999,950,000 all-pairs space to tens of thousands of candidates, with planted recall above 99% in this synthetic distribution.

## macOS Vision benchmark

```bash
./Scripts/benchmark_vision_on_mac.sh
```

This generates transformed-positive and unrelated-negative images, measures revision-1 feature-print distances, and writes `ValidationArtifacts/vision_similarity_mac.json`. It is a smoke/calibration aid, not a substitute for a labeled real-library benchmark.

## Release gates still required

- 10K, 50K, and 100K real-library runs on Apple silicon.
- Peak RSS, thermal state, wall time, cancellation latency, and database size.
- RAW/HEIC/JPEG decode failure rates and retry behavior across macOS versions.
- Precision/recall from human-labeled pairs across screenshots, bursts, edits, crops, and unrelated lookalikes.
