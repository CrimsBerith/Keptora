# Cullora_Phase_5S_Quarantine_Verification_Lineage — Real Corpus & Instruments Profile

- UI identity: **Archive Review Studio**. Profiling must not replace or homogenize the product shell.
- Corpus intent: photo libraries spanning duplicates, near-duplicates, bursts, edited variants and large originals.
- Accepted extensions: .jpg, .jpeg, .heic, .png, .tif, .tiff, .dng.
- Corpus stays **outside the repository/package**. Point `CULLORA_REAL_CORPUS_PATH` or pass a directory to the inventory script.
- `Scripts/run_real_corpus_inventory.sh` writes only ordinal, extension, byte count and SHA-256; no raw filename/path is written.
- `Scripts/run_instruments_profile.sh` is a Mac-only Xcode/Instruments helper. Use a signed local Debug/Profile build and interact with the app's own workflow while the trace records.
- Run Time Profiler first, then Allocations/Leaks. Use a separate trace for hangs when needed.
- Do not claim a real-corpus PASS until the local Mac corpus and trace have actually been run.

## Signpost spans
- `CulloraEnumerateLibrary`
- `CulloraFingerprintAssets`
- `CulloraGroupSimilarity`
- `CulloraQuarantineCommit`
- `CulloraHealthSnapshot`

## Corpus tiers

1. **Small:** 20–100 representative files for correctness and interaction tracing.
2. **Medium:** 500–2,000 files or equivalent pages/items for sustained-memory behavior.
3. **Large:** product-appropriate worst-case set constrained by disk and test policy.
4. Include corrupted/permission-denied/unsupported samples only as copies; originals remain untouched.
