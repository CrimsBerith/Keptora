# Apple profiling guidance for a 50,000-asset SwiftUI gallery

**Research date:** 2026-11-15  
**Scope:** Official Apple documentation and Apple WWDC / Tech Talks only. This is a research protocol, not a report of Keptora measurements. Apple documentation pages fetched for this note display © 2026 Apple; where Apple supplies a platform availability declaration, it is included below.

## Executive findings

- Treat end-to-end gallery latency as a pipeline: input and app/main-actor work → SwiftUI update and Core Animation commit → render-server CPU/GPU → display. Apple’s **Animation Hitches** template is the best first trace for locating late frames and separating commit from render hitches; add **Time Profiler** to identify sampled app code, **SwiftUI** to find expensive/frequent view updates, and signposts to label scan/filter/sort/thumbnail phases.
- None of the listed instruments alone proves every cause. Time Profiler is CPU sampling, not an end-to-end stopwatch or complete off-CPU scheduler trace. A hitch is an observed late frame; it does not, by itself, establish whether a main-thread bottleneck, background contention, image decode, render-server/GPU load, or memory pressure caused it.
- Apple’s frame intervals are 16.7 ms at 60 Hz and 8.3 ms at 120 Hz. These are not safe app-work budgets: pipeline stages share the interval, and Apple says the app may have less time depending on system conditions. Apple’s rough guidance is main-thread work below one refresh interval for continuous interactions, with under 5 ms often ready in time.
- A detached-worker microbenchmark only measures that isolated computation under that benchmark’s conditions. It cannot establish scrolling smoothness, commit/render hitch rate, main-actor availability, Photos thumbnail latency, cancellation behavior, memory pressure, or whole-flow latency.
- Use physical devices for shipping-performance conclusions. Apple specifically warns that Simulator memory behavior is not representative: its memory gauge stays green and macOS does not issue iOS-style memory warnings or OOM terminations.

## Source register

Apple titles and URLs are listed here so findings below can be audited against primary sources.

1. **“Understanding and improving SwiftUI performance”** — Apple Developer Documentation, Xcode, © 2026:  
   https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance
2. **“Understanding hitches in your app”** — Apple Developer Documentation, Xcode, © 2026:  
   https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app
3. **“Improving app responsiveness”** — Apple Developer Documentation, Xcode, © 2026:  
   https://developer.apple.com/documentation/xcode/improving-app-responsiveness
4. **“Analyzing responsiveness issues in your shipping app”** — Apple Developer Documentation, Xcode, © 2026:  
   https://developer.apple.com/documentation/xcode/analyzing-responsiveness-issues-in-your-shipping-app
5. **“Gathering information about memory use”** — Apple Developer Documentation, Xcode, © 2026:  
   https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use
6. **“Diagnosing performance issues early”** — Apple Developer Documentation, Xcode, © 2026:  
   https://developer.apple.com/documentation/xcode/diagnosing-performance-issues-early
7. **“Writing and running performance tests”** — Apple Developer Documentation, Xcode, © 2026:  
   https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests
8. **“Performance Tests”** — Apple Developer Documentation, XCTest, © 2026:  
   https://developer.apple.com/documentation/xctest/performance-tests
9. **“XCTHitchMetric”** — Apple Developer Documentation, XCTest; available starting iOS/iPadOS/macOS/tvOS/watchOS 26.0:  
   https://developer.apple.com/documentation/xctest/xcthitchmetric
10. **“XCTOSSignpostMetric”** — Apple Developer Documentation, XCTest; availability starts iOS/iPadOS/macCatalyst/tvOS 13.0, watchOS 7.0, visionOS 1.0:  
    https://developer.apple.com/documentation/xctest/xctossignpostmetric
11. **“XCTCPUMetric”** — Apple Developer Documentation, XCTest:  
    https://developer.apple.com/documentation/xctest/xctcpumetric
12. **“XCTMemoryMetric”** — Apple Developer Documentation, XCTest:  
    https://developer.apple.com/documentation/xctest/xctmemorymetric
13. **“task(id:name:priority:file:line:_:)”** — Apple Developer Documentation, SwiftUI; introduced iOS/iPadOS 15:  
    https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:)
14. **“cancel()”** — Apple Developer Documentation, Swift `Task`:  
    https://developer.apple.com/documentation/swift/task/cancel()
15. **“PHCachingImageManager”** — Apple Developer Documentation, Photos:  
    https://developer.apple.com/documentation/photos/phcachingimagemanager
16. **“Demystify SwiftUI performance”** — WWDC23 session 10160:  
    https://developer.apple.com/videos/play/wwdc2023/10160/
17. **“Analyze hangs with Instruments”** — WWDC23 session 10248:  
    https://developer.apple.com/videos/play/wwdc2023/10248/
18. **“Visualize and optimize Swift concurrency”** — WWDC22 session 110350:  
    https://developer.apple.com/videos/play/wwdc2022/110350/
19. **“Explore UI animation hitches and the render loop”** — Apple Tech Talks:  
    https://developer.apple.com/videos/play/tech-talks/10855/
20. **“Find and fix hitches in the commit phase”** — Apple Tech Talks:  
    https://developer.apple.com/videos/play/tech-talks/10856/
21. **“Make blazing fast lists and collection views”** — WWDC21 session 10252:  
    https://developer.apple.com/videos/play/wwdc2021/10252/
22. **“System Trace in Depth”** — WWDC16 session 411:  
    https://developer.apple.com/videos/play/wwdc2016/411/
23. **“Reducing your app’s battery use”** — Apple Developer Documentation, Xcode:  
    https://developer.apple.com/documentation/xcode/reducing-your-app-s-battery-use

## What each instrument can and cannot distinguish

| Tool / track | What it validly tells you | What it cannot establish alone |
|---|---|---|
| **Animation Hitches template / Hitches instrument** | Identifies frames that arrived later than expected; Apple’s render-loop tracks expose frame lifetime, user events, commits, render work/GPU and display timing. Hitch type helps localize a delay to app commit versus render-server rendering. Apple’s 2023 commit-phase Tech Talk says the template includes Time Profiler. | A hitch is the symptom, not the root cause. One hitch record does not prove which app function, worker, image operation, or allocation caused it. |
| **SwiftUI template** | SwiftUI lanes show Update Groups, Long View Body Updates, Long Platform View Updates and Other Long Updates. Current docs mark view body calculations over 500 μs orange and over 1,000 μs red. Selecting a slow update and using Time Profiler can reveal sampled call stacks; Update Groups and cause graphs identify repeated/causally related updates. | Orange/red are diagnostic thresholds, not a per-frame pass/fail gate. A fast body can still update too often; a SwiftUI update track does not measure all render-server/GPU work. |
| **Time Profiler** | Samples CPU work and exposes call trees/flame graphs for selected time ranges and threads. Use it around the hitch or signposted operation, inspect the main thread first, then inspect worker threads/process CPU activity. It can show whether a busy main thread is executing gallery work. | It samples on-CPU execution; a call tree is not end-to-end wall time and does not by itself explain why a thread was not scheduled or was blocked. To prove runnable delay, CPU saturation, or thread-state/scheduling contention, add a scheduler/System Trace view and/or Swift Concurrency template. |
| **Core Animation / Animation Hitches render-loop tracks** | Use to inspect commit/layout/display work and correlate the app’s Core Animation commit with render-server CPU/GPU and display timing. Apple distinguishes commit hitch (app process misses commit deadline) from render hitch (render server misses its deadline). | A Core Animation label or high GPU interval alone does not establish a specific SwiftUI view or thumbnail as cause. Follow the relevant frame through the tracks and correlate with app stacks/signposts. |
| **Allocations** | Counts and sizes heap and anonymous VM allocations, categories, allocation times and allocation stacks; generations isolate allocations across a feature interval. Useful for detecting per-cell churn, growing live allocation, caches retaining too much, or decode bursts. | Allocation volume is not equivalent to resident/physical memory, memory pressure, jetsam risk, or the causal source of a hitch. Pair with device memory report/high-water behavior, warnings/jetsam evidence, and optionally memory graph/VM tools. |
| **Points of Interest / `os_signpost`** | Marks explicit phase boundaries and intervals (for example scan, sort, filter, PhotoKit request, image-ready, UI-apply). In Instruments, it lets a trace align app-defined work with hitches, CPU samples, and SwiftUI updates. `XCTOSSignpostMetric` measures elapsed time between a matching begin/end pair for a named region. | Signposts only report what code marks. They do not measure screen presentation or prove causality unless their intervals are correlated with system tracks. Missing/mismatched begin/end events produce no `XCTOSSignpostMetric` result. |
| **Energy / Energy Log** | Use as a separate sustained-work run to assess energy impact; Apple’s battery-use guidance discusses energy-efficient scheduling/QoS. XCTest also offers `XCTCPUMetric`; `XCTMemoryMetric` measures physical-memory delta across the measured block. | Energy is not an explanation for a particular late frame and does not substitute for hitch traces. Do not infer frame-time or battery-life outcomes from a short detached sort benchmark. |
| **Swift Concurrency template** | Swift Tasks/Actors views expose running/alive/total tasks, task states, creation backtraces, main-thread execution, and waiting for actors; useful to spot main-actor blocking, actor serialization/contention, excess task creation, or tasks that outlive useful work. | Task count/actor wait is not a frame-presentation metric. Correlate with Animation Hitches and Time Profiler to determine user-visible impact. |

### Direct Apple guidance behind those distinctions

- SwiftUI bodies must finish before the next frame render; slow bodies or excessive updates cause hitches. Apple advises using the SwiftUI template, then Time Profiler on a selected slow update; move expensive calculations out of view bodies and cache results. The documented long-body markers are **>500 μs** (orange) and **>1,000 μs** (red). These are triage markers, not app-level acceptance thresholds. [“Understanding and improving SwiftUI performance”](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)
- Apple explains commit and render hitches as separate stages. A 120-Hz display can update every 8.3 ms; 60 Hz every 16.7 ms. Apple’s `Improving app responsiveness` calls **< one display refresh interval** a rough target for main-thread/continuous-interaction work and says **<5 ms** is usually ready in time. It explicitly cautions that actual available time depends on conditions and may be less than the full interval. These are guidance, not a promise that 5 ms always prevents hitches. [“Understanding hitches in your app”](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app); [“Improving app responsiveness”](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)
- Apple’s current Xcode Organizer guidance defines hitch rate in **milliseconds of pause per second (ms/s)** across animated interactions, not just scrolling: **≤10 ms/s good; ≤25 warning; ≤50 critical; >50 immediate attention**. Apple’s Tech Talk “Explore UI animation hitches and the render loop” gives a stricter experience target: **<5 ms/s good**, 5–10 noticeable, >10 investigate immediately. These are not contradictory measurements: they are different guidance contexts and thresholds. Report the measured value, name the source/metric, and choose a regression gate explicitly rather than silently mixing bands. [“Understanding hitches in your app”](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app); [Tech Talk 10855](https://developer.apple.com/videos/play/tech-talks/10855/)
- Apple describes animation hitch time ratio as total hitch time divided by measured interval duration, normalized to ms/s. A frame drop is one possible effect, not a synonym: not every hitch drops a frame. [Tech Talk 10855](https://developer.apple.com/videos/play/tech-talks/10855/); [“Understanding hitches in your app”](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)
- The SwiftUI template records a time profile alongside SwiftUI-specific tracks; update causes and view names help distinguish one long body calculation from many small/redundant updates. Apple warns that SwiftUI recreates views and recalculates bodies, so complex work belongs in model/business logic rather than view initializers, `body`, `onAppear`, or state-changing modifiers. [“Understanding and improving SwiftUI performance”](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)
- Apple’s commit-phase Tech Talk explicitly describes image decoding and color-format conversion in the prepare phase as potentially time- and memory-intensive, and recommends profiling the hitching commit with Time Profiler. It also recommends lightweight views, reuse, and avoiding expensive/redundant layout. [Tech Talk 10856](https://developer.apple.com/videos/play/tech-talks/10856/)
- Apple describes System Trace as capturing scheduling activity, system calls, and virtual-memory operations; the session recommends correlating traces with app-level activity. This is the appropriate next diagnostic when Time Profiler’s on-CPU samples do not explain worker contention, preemption, locking, or virtual-memory effects. [WWDC16 “System Trace in Depth”](https://developer.apple.com/videos/play/wwdc2016/411/)
- Energy observations are a separate efficiency dimension: use Apple’s battery-use guidance alongside explicit CPU/memory/hitch measurements, not as a substitute for them. [“Reducing your app’s battery use”](https://developer.apple.com/documentation/xcode/reducing-your-app-s-battery-use)
- For a PhotoKit-backed grid, `PHCachingImageManager` is explicitly designed to preload preview thumbnails for large asset collections: warm images for the upcoming visible region using the same target size/content mode/options as requests, and stop caching assets no longer needed. This is a Photos-framework thumbnail strategy, not proof the gallery’s own disk/cache/decode pipeline is fast. [“PHCachingImageManager”](https://developer.apple.com/documentation/photos/phcachingimagemanager)

## Actor isolation, prioritization, and cancellation

- A `Task {}` created from a main-actor SwiftUI context inherits that actor context. It does **not** make synchronous CPU-heavy work background work. Apple recommends putting expensive work in an `async`, non-actor-isolated function so it runs off the main actor; if a legacy synchronous function cannot be made async, Apple documents `Task.detached` as an explicit opt-out. Detached tasks do not inherit priority by default (default `.medium`), so choose priority deliberately. Keep UI state mutation on `MainActor`. [“Improving app responsiveness”](https://developer.apple.com/documentation/xcode/improving-app-responsiveness); [WWDC23 “Analyze hangs with Instruments”](https://developer.apple.com/videos/play/wwdc2023/10248/)
- Swift Concurrency is not equivalent to parallel execution. Apple’s Instruments session explains that actors serialize access; large computations inside a shared actor can erase parallelism. Inspect actor waits/running tasks and keep actor-isolated sections limited to state access. [WWDC22 “Visualize and optimize Swift concurrency”](https://developer.apple.com/videos/play/wwdc2022/110350/)
- SwiftUI `.task(id:)` cancels and restarts when the observed ID changes and may cancel after the view disappears. This is appropriate for filter/sort query replacement, but cancellation is cooperative: `Task.cancel()` flags the task and runs handlers; arbitrary synchronous code does not stop unless it checks/handles cancellation. Ensure a long scan/filter loop checks cancellation and prevent stale results from being applied after a newer query. [SwiftUI `task(id:...)`](https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:)); [Swift `Task.cancel()`](https://developer.apple.com/documentation/swift/task/cancel())
- Apple’s SwiftUI performance guidance recommends caching expensive calculations to avoid repeated recomputation. For scrolling image grids, Apple PhotoKit’s caching image manager prepares thumbnails asynchronously for batches. [SwiftUI performance documentation](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance); [PhotoKit `PHCachingImageManager`](https://developer.apple.com/documentation/photos/phcachingimagemanager)

## Reproducible 50,000-asset stress protocol

The steps and run counts below are **recommended experimental design**, not Apple-prescribed numbers or measured Keptora results.

### 1. Fix and disclose the environment

Record device model/chip, OS build, Xcode/Instruments version, app commit/build configuration, screen mode/refresh capability, battery/charging state, Low Power Mode, thermal state, available storage, and whether images are locally available or require iCloud download. Use at least one lower-performance supported physical device and one high-refresh-rate device if the app targets both; do not assume the nominal maximum refresh rate is active in every run. Run in a consistent foreground/brightness/network condition. Repeat separate trials rather than comparing one run from different machines.

Use the same app data snapshot and stable asset identifiers every run. Keep both representative metadata distributions and a documented media mix (photo/video, file size and pixel dimensions, date/location/favorite/album metadata where appropriate). For privacy, use a generated/authorized test corpus for repeatable data; to validate actual PhotoKit fetch and thumbnail behavior, separately test on-device with explicit Photos permission and authorized library contents. Do not make a synthetic in-memory array stand in for PhotoKit, disk, decode, or iCloud behavior.

### 2. Define end-to-end scenario and phase markers

From a clean app launch or controlled cache state:

1. Start a full scan/index of exactly **50,000** assets. Measure first usable gallery, scan completion, batches/sec, and peak/live memory; don’t count only detached compute time.
2. Begin a deterministic scroll interaction (fixed path, duration, direction, and approximate velocity). During uninterrupted scrolling, issue a fixed series of real UI filter and sort changes; keep scanning active or apply incremental scan batches at a controlled cadence. Ensure the scenario exercises actual view updates and visible thumbnails.
3. Include separate cold-thumbnail and warmed-cache passes. Warm the same PhotoKit target size/content mode/options used by visible cells; do not mix these results.
4. Continue long enough to reveal accumulation/task backlogs and memory growth (suggestion: 60–90 seconds per scenario); return to the same start state for each trial.
5. Repeat each case several times (suggestion: ≥5), report median and tail values (p95/p99 where sample count permits), run-to-run spread, and failures/canceled/stale work. Preserve full trace files and exact setup; avoid presenting one best run as general performance.

Add matching signpost intervals, e.g. `Gallery.Scan`, `Gallery.Filter`, `Gallery.Sort`, `Gallery.VisibleThumbnailRequest`, `Gallery.ThumbnailReady`, `Gallery.ApplySnapshot`, `Gallery.FirstUsableContent`, and `Gallery.ScrollScenario`. Include counts (assets scanned, visible requests, cache hit/miss if available) as metadata without logging personal photo names/paths/EXIF. Signposts should mark the actual operation boundaries, not only the caller’s enqueue point.

### 3. Record complementary traces

- **Pass A — user-visible frame path:** Instruments **Animation Hitches** while executing the scenario. Inspect hitch duration/type, commit and render/render-server/GPU tracks, user events, and display/vsync track. Save one trace for each device/refresh class.
- **Pass B — SwiftUI work:** Record the **SwiftUI** template during the same scripted scenario. Inspect long body/platform/other updates and update-group frequency/cause graphs. Use Time Profiler on representative slow intervals.
- **Pass C — CPU and scheduling:** Record **Time Profiler** with the hitch/operation range selected; inspect the app main thread and worker threads. If main is idle but interaction still stalls, or workers show apparent contention, add **Swift Concurrency** and/or **System Trace** to inspect task/actor states and thread scheduling. CPU sample totals alone cannot show off-CPU wait/runnable delay conclusively.
- **Pass D — memory:** Run **Allocations** (mark generations around scan, filter/sort, and scrolling). Record live/peak allocation trends and allocation stacks. Separately observe the device’s memory gauge/high-water behavior and warning/termination evidence. Do not equate total allocation churn with memory pressure.
- **Pass E — energy:** Run Energy/energy diagnostics separately, with the same workload, to assess sustained cost. Do not use this pass to explain an individual hitch without the frame/CPU trace.

Use single-purpose passes where possible: collecting many instruments simultaneously can perturb a timing-sensitive workload. Keep any instrument/debug diagnostics identical between before/after comparisons and verify the result in a minimally instrumented release-like run.

### 4. Thresholds and how to interpret them

| Measurement | Apple-grounded threshold or meaning | Practical interpretation |
|---|---|---|
| Refresh interval | 60 Hz = 16.67 ms; 120 Hz = 8.33 ms. | This is the frame cadence, **not** a guaranteed full interval for app code. Track the actual frame/hitch result. |
| Main-thread continuous-interaction work | Apple’s rough target: less than one refresh interval; under 5 ms is “usually” ready in time. | Treat <5 ms as a useful target for app-attributable update work, not a universal proof of smoothness. Validate on the target device and by hitch trace. |
| XCTest/UI hitch metric | `XCTHitchMetric(application:)` measures hitch count in the app’s UI; current API availability starts at OS 26.0. | Report count alongside scenario duration and scroll activity; for normalized rate use an explicit duration denominator or Organizer’s hitch-rate data. Check deployment/runtime availability before depending on this metric. |
| Hitch-rate quality | Current Xcode Organizer article: ≤10 ms/s good, ≤25 warning, ≤50 critical, >50 immediate attention. Apple’s 2023 Tech Talk says <5 ms/s good, 5–10 noticeable, >10 investigate. | Prefer a stricter product target where justified, but state which recommendation is the gate. Target zero hitches in principle; not a claim that zero is always measurable/reproducible. |
| SwiftUI body updates | >500 μs orange; >1,000 μs red in SwiftUI template. | Investigation triggers only; aggregate repeated updates and correlate with frame hitches. |
| UI response | <100 ms is Apple’s rough goal for synchronous work on a discrete interaction. | Useful for filter-tap acknowledgement/first feedback, distinct from continuous scrolling’s per-frame requirement. |

No evidence found in these Apple sources establishes a universal acceptable scan-completion time for **50,000** assets or a single memory ceiling suitable for every device. Define app-specific gates per device class and product experience; report scan completion, first content, query latency, hitch rate, CPU, and memory separately.

## What XCTest / simulator / detached benchmarks can establish

### XCTest

- XCTest performance tests can repeat measured code, gather selected metrics, compare against a baseline and accepted maximum standard deviation, and profile a failing test in Instruments. Apple recommends **Release** build-for-testing, **Debug executable off**, and code coverage/runtime sanitization off to better reproduce device conditions. [“Writing and running performance tests”](https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests)
- `XCTClockMetric`/default measurement is elapsed time for the measured block; `XCTCPUMetric` reports target CPU time/cycles/instructions; `XCTMemoryMetric` reports the physical memory difference before and after the block; `XCTOSSignpostMetric` measures a named signpost region; `XCTHitchMetric` measures UI hitch count. These metrics answer different questions; do not present CPU time as wall latency or memory delta as a peak-memory/pressure result. [XCTest Performance Tests](https://developer.apple.com/documentation/xctest/performance-tests); [XCTCPUMetric](https://developer.apple.com/documentation/xctest/xctcpumetric); [XCTMemoryMetric](https://developer.apple.com/documentation/xctest/xctmemorymetric); [XCTHitchMetric](https://developer.apple.com/documentation/xctest/xcthitchmetric)
- A tight `measure` block around `sorted()` is a useful component regression test, but it excludes setup/teardown if outside the measured interval and excludes UI rendering/Photos unless they are actually part of the measured app flow. Separate component tests from full UI/scroll tests. XCTest’s aggregate mean/baseline is not a substitute for tail latency or actual hitch-trace analysis.
- UI automation can drive a repeatable scenario, but ensure app work continues during the measured scroll; do not serialize scan → filter → sort → scroll when the product must handle them concurrently. Use signpost-defined subintervals plus hitch metrics rather than one giant test duration.

### Simulator

- Simulator is useful for deterministic functional tests and some memory-object diagnosis, but is not a source of production-device performance claims. Apple explicitly says Simulator’s memory gauge remains green because macOS does not issue the same memory warnings or OOM terminations; green does not mean safe on iOS. [“Gathering information about memory use”](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)
- Apple also notes code can behave differently across Apple devices because hardware capabilities/performance vary, and recommends device filtering in Organizer to expose device-specific problems. Use simulator timings only as local directional signals; do not compare a Mac simulator’s CPU/GPU/refresh or Photos behavior to a physical iPhone/iPad as if equivalent. [“Analyzing responsiveness issues in your shipping app”](https://developer.apple.com/documentation/xcode/analyzing-responsiveness-issues-in-your-shipping-app)
- Run the end-to-end acceptance scenario on real hardware. Simulator may help investigate object graphs or memory retention, but it cannot validate device memory pressure, thermal behavior, or actual display deadline behavior.

### Detached-worker microbenchmarks

A benchmark that starts `Task.detached` and times filtering/sorting a 50,000-element array validly answers a narrow question: how that isolated function performs with that data, optimization level, device/simulator, system load, and measurement method. It cannot establish:

- whether the UI initiated work on MainActor or kept it free;
- whether the app or render server hit 60/120-Hz deadlines;
- whether SwiftUI body/update frequency or layer layout is costly;
- whether sorting races with scrolling or adds worker CPU contention;
- whether superseded requests cancel promptly or stale results reach UI;
- whether PhotoKit fetches, image decode/color conversion, caching, or iCloud downloads are fast;
- whether allocation growth becomes device memory pressure or jetsam;
- end-to-end first-content/query/scan latency under concurrent user activity.

Those claims require actual app interactions with the real pipeline on physical target hardware, correlated signposts and system traces.

## Evidence limits and cautions

- This review found no Apple source that states “50,000 assets” as a standard gallery benchmark size or prescribes a specific 50k test duration, run count, metadata distribution, or performance budget. Those elements above are an experimental recommendation, not an Apple requirement.
- Apple’s SwiftUI and hitches articles document available instruments and metric interpretation. They do not establish that any particular Keptora code path has a hitch, nor provide empirical Keptora measurements.
- Hitches can arise from either app-process commit work or render-server work; high worker CPU can contend with the render path without showing the main thread as the CPU hotspot. Use scheduler/concurrency analysis to test that hypothesis rather than inferring it from a detached benchmark.
- At profiling time, record actual tool/OS versions. XCTest’s `XCTHitchMetric` API is declared available from OS 26.0, while other metric types have earlier availability; older deployment targets need availability checks or a separate on-device Instruments procedure.

