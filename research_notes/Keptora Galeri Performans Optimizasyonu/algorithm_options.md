# Gallery Projection Optimization Algorithm Options

## Which optimization addresses a measured 130 ms projection?

### Takeaway

For 45,000 items, repeated sorting is the first high-value hypothesis to test: sorting once per data revision and sort descriptor can remove repeated `O(N log N)` work. It does not prove sorting dominates a 130 ms projection; separately measure filtering, sort-key extraction/comparison, date grouping, quality/review derivation, search, allocation, and UI application before selecting a fix.

### Cited Findings

- Apple documents `Sequence.sorted(by:)` as `O(n log n)` and stable; its comparator must be a strict weak ordering. Stable sorting preserves relative order for elements the comparator does not order. [Apple `sorted(by:)`](https://developer.apple.com/documentation/swift/array/sorted(by:).md)
- Apple describes `LazyVGrid` as creating child views only as needed, and says to use it when profiling shows a regular `Grid` loads too many views at once. This concerns view creation, not the cost of computing a fully filtered or sorted input array. [Apple `LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid.md)
- Apple describes `OSSignposter` as a way to measure task intervals and view those intervals on an Instruments timeline. [Apple `OSSignposter`](https://developer.apple.com/documentation/os/ossignposter.md)

### Inferences

- `45,000 × log₂(45,000)` is about 0.70 million comparison-scale operations. That is not a time estimate: comparator work, key extraction, ARC, memory locality, other projection stages, and device all affect elapsed time.
- If a projection repeats the same ordering for unchanged data, cache an ordered sequence of stable IDs or source indices, keyed by source revision and sort descriptor. Filtering can then walk that order and append matching IDs in `O(N)` while preserving display order; avoid sorting each newly filtered subset unless the sort key/order changed.
- Profile the comparator and key extraction separately. Comparing strings, repeatedly normalizing fields, computing derived quality values, or doing date/calendar work inside a comparator can make “sort time” include much more than sorting.
- Establish current behavior as the correctness oracle: exact item membership, order, date-section boundaries, review/quality states, and search matches must remain unchanged. No optimization should remove or suppress records.

### Gaps

- No supplied trace, device/build configuration, or phase timings establish that sorting accounts for the reported 130 ms. Treat that number as a workload observation to reproduce, not a published benchmark.
- Apple’s API documentation gives asymptotic complexity, not a timing prediction for this app or device.

## Which data structures and projection strategies merit benchmarks?

### Takeaway

Start with reusable ordered IDs, precomputed projection/search fields, and indexed date ranges. Add predicate bitsets or incremental candidate sets only when representative filter workloads show repeated scans are material. Lazy UI construction is complementary: it does not by itself make a global filter/sort projection lazy.

### Cited Findings

- Apple’s sorting API provides a stable result and `O(n log n)` complexity, which supports reusing an order and relying on stable tie behavior only when the input order is itself deterministic. [Apple `sorted(by:)`](https://developer.apple.com/documentation/swift/array/sorted(by:).md)
- Apple says `LazyVGrid` creates child views only as needed; a regular `Grid` creates all its children immediately. [Apple `LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid.md)

### Inferences

| Approach | Work and memory model | Correctness hazards / when to test |
|---|---|---|
| Sort once, reuse ordered IDs/indices | Initial `O(N log N)` per source revision + sort descriptor; reuse requires `O(N)` filtering scan. An `Int64` ID/index array is about 8 bytes/item (~360 KB for 45K, excluding array capacity and related storage). | Invalidate when any sort key, source membership, or ordering policy changes. Stable sorting preserves current input tie order, not a canonical order if input enumeration is unstable; use a deterministic tie-breaker only if consistent with existing semantics. |
| Predicate bitsets / facet indexes | A dense bitset of 45K entries uses about 5.5 KiB (`ceil(45,000/8)`); intersection/union is roughly `O(N/wordSize)`. An `Int64` posting list can use about 8 bytes per matching entry, plus container overhead. | Fast combination of indexed predicates; may still scan the ordered IDs to emit the result. Benchmark for frequently used categorical or boolean facets (e.g. review state) with reusable indexes. Mask unused tail bits, define AND/OR/NOT semantics exactly, and invalidate every affected index. |
| Incremental candidate filtering | Apply a newly added restrictive predicate to current candidates in `O(M)` rather than all `N`, where `M` is current candidate count. | Only valid when new query is a logical restriction of the old one. Removing/changing a filter, changing OR groups, or changing base data must recompute from a sufficiently broad valid candidate set. Compare full query identity, not just the “last changed filter.” |
| Precomputed normalized search fields | Normalize/case-fold searchable fields once per relevant content/policy revision; each query still scans candidates and searches the cached representation. Memory is proportional to normalized text length. | Preserve current locale, case/diacritic, token/substring, and field-combination behavior. Locale or normalization-policy changes invalidate normalized strings. A token inverted index can reduce candidate work for repeated token queries but costs postings memory and may not preserve substring or localized search semantics. |
| Date-sorted index + binary-search bounds | Sort timestamps once (`O(N log N)`); each range lookup is `O(log N + K)` to find and enumerate `K` matching dates. | A date index only directly emits date order. If display sort differs, use it to create a membership set then traverse the display order, or restore the established ordering. Define half-open range endpoints, missing dates, calendar, time zone, and daylight-saving transitions to match existing section semantics. |
| One-pass date sectioning | Group already-filtered, correctly ordered results in `O(K)`; avoid per-item repeated formatting or sorting sections. | Section key must use the same calendar/time zone and day-boundary rules as the existing UI. Cache invalidation must account for calendar/time-zone changes if they affect labels or membership. |
| Quality/review derived projection | Derive each stable display/filter field once per relevant metadata revision; optional facet indexes then avoid re-deriving or scanning all records. | Identify every input to the derivation (review state, metadata, user choices, algorithm version). A stale cached classification can alter membership, so preserve existing logic and invalidate on each input change. |
| Lazy projection / paging | Compute visible cells or bounded pages on demand; total retained result may be less than a materialized view. The UI can avoid creating offscreen views. | SwiftUI lazy containers defer child-view creation, not arbitrary precomputed `filter`/`sorted` work done before constructing the view. Paging must not change total results or silently omit records; preserve global order and section behavior. |
| Cache completed projections | Reuse work for the exact same query over the same source/policy revisions; memory grows with retained result arrays and any derived indexes. Bound cache count/cost and measure hit rate. | Key omissions cause stale/wrong galleries. Include every result-affecting input, not only visible filter toggles. Do not publish an older in-flight result after a newer query or mutation. |
| Cancellation-aware work | Cancellation checks at phase/chunk boundaries stop obsolete filtering/grouping promptly; a synchronous sort is not interrupted merely because its task is cancelled. | Check cancellation before and after non-interruptible phases, and periodically in long loops. Debounce rapid text edits if appropriate; do not treat cancellation as a substitute for validating the result’s generation at publication. |

#### Cache key and invalidation design

- Represent a projection request with immutable values: `sourceRevision`, `sortDescriptor`, canonical filter state, normalized search query and search-policy/locale revision, date-range/calendar/time-zone inputs, and quality/review algorithm or metadata revisions. Include only inputs that can affect this projection, but include all such inputs.
- Increment a monotonic source revision for insertions, removals, and changes to any field consumed by filtering, sorting, sectioning, quality/review, or search. Separate revisions by derived-data domain only if dependency tracking is explicit and tested.
- Snapshot value-type, immutable inputs for worker computation. Apple defines `Sendable` as a thread-safe type whose values can cross concurrency domains without data races; immutable value snapshots are a natural boundary. [Apple `Sendable`](https://developer.apple.com/documentation/swift/sendable.md)
- Associate each request with a generation/query identity. Before applying its result, verify that it is not cancelled and that its source revision and requested query still match current state. This prevents a slow old result overwriting a newer query or post-mutation gallery.
- Keep cache correctness independent from cache hit: the uncached path remains authoritative. Test mutation of each field in the dependency set, filter relaxation, locale/time-zone changes where relevant, and out-of-order completion.

### Inferences

- Candidate architecture worth controlled comparison: (A) current implementation; (B) sort-once/reusable ordering; (C) sort-once plus precomputed sort keys; (D) cached normalized fields; (E) date index/bounds; (F) selective bitset facet indexes; then selected combinations. Keep each variant behavior-equivalent.
- An ordered array plus scan is often the lowest-complexity baseline. Dense masks cost little for 50K records, but add maintenance and invalidation complexity; use only for predicates queried repeatedly or where profiling shows membership checks/scans are significant.
- For quality/review filters, derive/index only values the app already computes. Do not change criteria, result count, or protection rules to improve speed.
- Search should first benchmark normalized-field caching against current exact semantics. An inverted index is not automatically equivalent to localized substring matching.

### Gaps

- Actual field sizes, filter selectivity, query frequency, object ownership, mutation rates, and current search semantics are unknown; therefore memory totals and best index choice need measurement on representative data.
- No benchmark evidence establishes that a full-text inverted index or bitset is worthwhile for this 50,000-item workload.

## How should correctness, cancellation, and performance measurement be verified?

### Takeaway

Measure worker execution, main-thread delivery/application, and scrolling/render behavior as separate signals. Use signposted phase intervals and Instruments traces for attribution; use repeatable release-like runs and concurrent scrolling for user impact. Report distributions and cache state, not only one total duration.

### Cited Findings

- `OSSignposter` records named task intervals that Instruments displays on a timeline, and supports measuring a closure or explicit begin/end interval. [Apple `OSSignposter`](https://developer.apple.com/documentation/os/ossignposter.md)
- `Task.checkCancellation()` throws `CancellationError` when the task was cancelled. [Apple `Task.checkCancellation()`](https://developer.apple.com/documentation/swift/task/checkcancellation().md)
- `Sendable` values may safely pass between concurrency domains subject to the type’s semantic requirements; mutable state must be absent, protected, or actor-isolated. [Apple `Sendable`](https://developer.apple.com/documentation/swift/sendable.md)
- SwiftUI’s `LazyVGrid` defers child-view creation until needed, but Apple distinguishes this from projection computation. [Apple `LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid.md)

### Inferences

#### Separate these measurements

1. **Worker cost:** end-to-end projection wall time from immutable snapshot start to completed result; also signpost filtering, sort/key creation, date sectioning, quality/review derivation, and search separately. Record item counts/candidate counts and cache hit/miss. Keep phase timers non-overlapping or identify nested intervals.
2. **Main-thread latency:** time from user input/request to the result becoming applicable, and separately the duration of main-actor result application/state update. Use signposts around request, worker phases, result handoff, and state application; include stale/cancelled outcomes. A fast worker can still feel slow if queueing or main-thread application is delayed.
3. **Rendering and concurrent-scroll performance:** run the same query while scrolling a representative gallery. Record frame-time/hitch/FPS evidence independently from projection duration; track whether scrolling continues smoothly while work runs off-main and while results update. A 130 ms worker interval does not equal a 130 ms UI stall, and a short main-thread update does not prove smooth frames.

#### Controlled benchmark plan

- Use the same synthetic/approved 50K corpus, OS/device, build configuration, warm-up, and interaction script for every variant. Include cold and warm cache runs, same-query repeat, sort changes, restrictive filters, filter removal/relaxation, date windows, review/quality toggles, short and long search text, and rapid successive queries.
- Collect p50/p95 projection duration, main-thread request-to-apply and apply duration, counts visited/returned, comparator/key invocations, cache hit ratio, allocated/retained bytes, cancelled/stale result count, and scrolling frame/hitch measures.
- Run baseline and single-change variants before combinations, repeat runs, and inspect Instruments allocation/time traces. Avoid claiming a gain from a single noisy run; verify result IDs, stable order, sections, and search/filter behavior against the baseline for every case.
- For cancellation, check periodically in worker loops and around synchronous boundaries; the API documents that `checkCancellation()` throws, but the code must call it. Revalidate request generation/revision before publication even after cancellation checks.

### Gaps

- Exact Xcode Instruments template names, frame metrics, and device targets depend on the app’s deployment platforms and supported hardware; the cited signposter documentation establishes interval measurement, not a specific FPS acceptance threshold.
- No evidence here provides a universal acceptable projection latency or frame-rate threshold. Set thresholds from the app’s supported refresh rates and product requirements, then measure on target devices.
