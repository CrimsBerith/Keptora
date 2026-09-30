# Keptora App Review Corpus

Generate the deterministic corpus on the reviewer/test Mac:

```bash
python3 Scripts/generate_app_review_corpus.py --output ~/Desktop/Keptora_Review_Corpus
```

The generated folder contains:

- Two byte-for-byte duplicate JPEG groups.
- One PNG exact-duplicate group.
- A visually similar but non-identical sunset set for Similar Review.
- A RAW/JPEG-style filename family with an XMP sidecar.
- One deliberately corrupted `.jpg` for skip/error-path testing.
- A manifest with SHA-256 values and expected relationships.

The corpus contains synthetic graphics only and no personal data. Similar-photo grouping depends on the final Vision/calibration profile; exact groups are deterministic.

Expected exact duplicate groups:

1. `Exact/Beach_Original.jpg` + `Exact/Beach_Copy.jpg`
2. `Exact/Family_Original.jpg` + `Exact/Family_Copy_1.jpg` + `Exact/Family_Copy_2.jpg`
3. `Exact/Poster.png` + `Exact/Poster copy.png`

Do not put the corpus inside the app bundle or upload it as customer content. It is a reproducible review/QA aid.
