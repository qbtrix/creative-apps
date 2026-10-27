# Render budgets

What each app's most-used interactions cost its real window. The harness is
`Tests/AppSnapshotTests/RenderBudgetHarness.swift`. It hosts the app's window
view on a fixture off screen and paces every step at 120 Hz. A step's time is
the event's work plus the layout and display it forced.

Budgets ratchet. A body budget is exactly what `dev` measured (Design's is the
design-window DW-b bound of 3, Halo's viewer drag the 3 of
`HaloWindowLiveDragTests`). A step-time budget sits a little above it, so the
suite is green today and fails on a regression. When a fix lowers a number,
lower its budget in the same PR. Never raise one. The target is where the row
has to end up.

- **Window bodies** come from a debug-only `bodyRuns` counter in the app's window
  file. The count is deterministic, so `RenderBudget<App>Tests/bodies` runs in
  the merge gate. Every suite that reads one of these process-global counters
  nests in `BodyCountSuites`, which is `.serialized`, so two of them never run
  at once and count each other's renders. A new counter-reading suite nests
  there too, and its `perf-suites.txt` line reads
  `AppSnapshotTests.BodyCountSuites/<Suite>`.
- **Step p95** is wall time, so `RenderBudget<App>Tests/timing` is listed in
  `Tests/perf-suites.txt`. It runs nightly on the captain's Mac (perf-nightly), one test at a
  time. The numbers below come from a debug build on an M2 Pro (max of
  3 runs). A release build is faster. Halo's were re-measured on `dev` with
  #1471 (no scrub ticks) and #1517 (live drag) in, at machine load 20 (a run at
  load ~70 gave up to 3x these); the other apps' times are the earlier ones.
- **Accessibility is on** in every run, because the harness finds controls by
  identifier. A Mac running any accessibility client pays that cost too:
  VoiceOver, a window manager, a password manager.

| App | Interaction | Bodies dev / budget / target | Step p95 dev / budget / target | Fix that should bring it to target |
|---|---|---|---|---|
| Halo | select a layer (click Ball's row) | 1 / 1 / 1 | 108 / 130 / 33 ms | was 1018 ms; #1471 removed the scrub rows' per-step accessibility ticks. Left: the selection's layout passes |
| Halo | drag the inspector divider, 120 samples, Ball selected | 0 / 0 / 0 | 97 / 130 / 8.3 ms | was 1057 ms (same fix). Still ~70 ms median per step; its SuiteWindow min-size change is the candidate for the rest, not measured yet |
| Halo | play 1 s at 120 Hz (24 fps), `HaloWindowPlaybackTests` | 24 / 24 (spec 12-30) / 24 | 17.0 / 27 / 8.3 ms | #1517 skips the lanes and rows a frame leaves unchanged (0 lanes, at most 96 rows per second, both asserted); the step time is mostly the window's own 24 bodies |
| Halo | drag Floor in the viewer, 120 samples | 2 / 3 / 3 | 2.9 / 4 / 8.3 ms | none: at the `haloViewerTakesActivationClicks` bound (3); could tighten to 2 |
| Design | drag a shape on `crowd`, 120 samples | 3 / 3 / 3 | 4.1 / 6 / 8.3 ms | none in flight; at design-window DW-b's bound |
| Design | marquee select on `crowd`, 120 samples | 3 / 3 / 3 | 2.7 / 4 / 8.3 ms | none in flight; at DW-b's bound |
| Library | scroll the grid, 120 steps of 12 pt (`samples`) | 0 / 0 / 0 | 6.6 / 10 / 8.3 ms | none in flight |
| Library | step the Develop tab's Midtones handle 120 times at 120 Hz (`samples`, first photo in the loupe; `RenderBudgetLibraryLevelsTests`) | 120 / 120 / 0 | 24.7 ms p95, printed, not judged | each step reruns the window body once; a Levels edit should only touch the inspector and the loupe. The histogram is counted once per loupe render off the main thread (`LibraryHistogramBudgetTests`) |
| Library | select, 10 clicks on grid cells | 10 / 10 / 10 | 80 / 120 / 33 ms | none in flight |
| Library | loupe step | not driven | not driven | the loupe's arrow keys need a key window, which a test process can't have |
| Flare | step the easing X1 scrub row 60 times | 60 / 60 / 60 | 11–13 ms p95 release, 12 ms debug / 20 / 8.3 ms | #1471 removed the per-step ticks; measured on the finisher's Mac (busy, not quiet), over the 8.3 ms target and under the 20 ms report bound |
| Flare | draw an ellipse on the canvas, 120 samples (Rectangle is not connected yet, IN-1) | 1 / 3 / 3 (debug; 122 before #1792) | p95 2.3–2.5 ms release, 2.3–2.5 debug / 20 / 8.3 ms | #1792 runs the samples on the stage's FlareLiveDrag; the window runs once, at mouse-up |
| Flare | drag a star with the Shape tool, 120 samples (`RenderBudgetFlareShapeTests/starDragInThreeBodies`; the draw waits on shape-tools FS-6) | not yet / 3 / 3 | not timed (packet: p95 ≤ 8 ms; its `timing` test is disabled until the supervisor lists it in Tests/perf-suites.txt) / 20 / 8 ms | first measured by the macOS run after shape-tools FS-4; the draft runs on the stage's FlareLiveDrag |
| Photo | brush stroke, 120 samples (`large`), `PhotoWindowStrokeTests` | 0 / 1 / 1 | 7.1 / 11 / 8.3 ms | none in flight; the body bound is the stroke's existing one (`PhotoWindowStrokeTests`, measured 0) |
| SuiteUI | stroke pad on the editor-kernel chrome panel, 120 samples, `RenderBudgetEditorKernelStrokeTests` | not yet / 1 / 0 | not yet / not gated / 8.3 ms | first measured by the macOS run after EK-31; the pad's samples stay in its own state, paced by `SuiteStrokePacer` |
| SuiteUI gallery `editor-kernel` | drag Card 7 onto Header in the 200-row layer tree, 120 samples (`RenderBudgetEditorKernelTests`) | not yet / 3 / 1 | not timed | first measured by the macOS run after EK-6; the drop's log line and move should be the one body |
| AI access (afterglow-mcp) | a demo request's approval sheet appears on Flare's window, then Allow Once (`RenderBudgetAIAccessTests/sheet`) | not yet / 2 / 0 | not timed (packet: p95 ≤ 8 ms, report-only once the supervisor lists a `timing` test) | first measured by the macOS run after MC-13; the sheet is its own window, so the app window should not run |
| AI access (afterglow-mcp) | Flare's ellipse drag, 120 samples, with the "Controlled by" chip in the title bar (`RenderBudgetAIAccessTests/chip`) | not yet / no more than the same drag without the chip, and 3 / 3 | not timed | first measured by the macOS run after MC-13; the chip is its own hosting view and adds 0 bodies |
| AfterGlow onboarding | click Continue (page 1 to 2) | 1 / 1 / 1 | 14 ms debug (31 ms on a cold first run) / 35 / 16 ms | none in flight; at target bodies. Release not measured: `swift test -c release` fails to link SuiteUITests (#2714) |
| AfterGlow onboarding | click the Photos focus chip | 0 / 0 / 0 | 9.5 ms debug (24 ms cold) / 30 / 16 ms | none in flight. The click focuses the chip, and the system focus ring animates in: ~700–800 layout passes (~55 ms) over the 100 ms after the step, off the step time |
| AfterGlow onboarding | move the pointer across the first starter row, 120 samples | 0 / 0 / 0 | 0.09 / 1 / 8.3 ms | none in flight; under target |

Bodies for Flare's scrub row and Library's selection count one per edit: each
step changes the model once. Their target is that count, not 3. Halo's
playback bound comes from #1296: at least `fps / 2` and at most `fps + 6`.

## Photo at 8K, CPU against GPU (recorded, no budget yet)

`PhotoRenderBudgetTests` (perf list, report only) draws a 7680 x 4320
document with three layers (white Background, a full fill at 50 %, a Paint
layer with one stroke) through `PhotoRenderer.update` on each route: the CPU,
the GPU uploading every tile it composites and reading the bytes back, and the
GPU with resident layer tiles writing the picture into a texture (the canvas
presenter's), which is what the app draws on. It times the first picture of a
just-opened document, a full redraw (an adjustment) and a brush frame (one
64 px brush segment, its damaged tiles). These are records, not budgets; the
large-image gate (beta-80 row G1) sets those. M2 Pro, optimized
(`swift build -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG`), the
median of three runs, each the median of 3 full pictures and 10 brush frames
(max: the worst brush frame over the three runs), 2026-10-19 on a loaded Mac
(another Photo running):

| Route | First picture | Full redraw | Brush frame (2 tiles) |
|---|---|---|---|
| CPU (CoreRender's CPU backend, tiles in parallel) | 74 ms | 74 ms | 1.0 ms (max 1.5) |
| GPU, uploads and readback every frame (before) | 281 ms | 276 ms | 3.3 ms (max 8.7) |
| GPU, resident tiles into the presenter's texture | 166 ms | 31 ms | 1.4 ms (max 3.2) |

Before creative-core #620 the resident row was 192 ms, 35 ms and 1.7 ms (max
2.3); on 2026-10-18, before #553/#554/#559, the GPU row was 325 ms and 4.6 ms.
The resident route uploads each of the 1053 non-clear layer tiles once (the
first picture) and then only the tiles a stroke wrote (14 over the 10 brush
frames). A full redraw uploads nothing, and no frame reads pixels back.

Where a resident brush frame goes now: the batched composite is committed
with no wait (about 0.05 ms); a changed 256 px tile uploads in about 0.2 ms
(the dirty check is storage identity and the Float16 conversion vectorizes),
the region's tiles across the cores; a blank backdrop is about 0.1 ms per
tile. The rest is the display into the texture, which waits for the GPU
(about 0.55 ms) because the canvas presenter draws that texture from its own
queue. That wait is what keeps the GPU 0.3 to 0.4 ms behind the CPU, whose
1.0 ms has no round trip at all. A debug build is 20x to 400x slower, so
read these rows.

## Photo at 8K: pan and slider by zoom

`PhotoZoomSweepTests` (#2942, perf list) pans the 8K document 120 frames at each
zoom on both backends and times each frame's scroll, layout, display and Core
Animation commit. Release, M2 Pro, pan frame p50 / p95:

| Zoom | CPU before | CPU after | GPU before | GPU after |
|---|---|---|---|---|
| 25 % | 23.7 / 25.4 ms | 2.1 / 3.2 ms | 23.9 / 26.7 ms | 2.2 / 3.0 ms |
| 50 % | 84.9 / 100.5 ms | 2.9 / 6.4 ms | 87.1 / 89.2 ms | 2.5 / 3.7 ms |
| 75 % | 191.8 / 241.7 ms | 3.1 / 7.0 ms | 190.4 / 222.8 ms | 4.1 / 8.5 ms |
| 100 % | 490.4 / 764.3 ms | 3.1 / 7.8 ms | 397.0 / 708.3 ms | 2.8 / 5.8 ms |
| 150 % | 1.9 / 2.6 ms | 2.7 / 3.6 ms | 1.9 / 2.5 ms | 2.9 / 3.6 ms |
| 200 % | 2.0 / 5.2 ms | 4.4 / 10.6 ms | 1.8 / 2.9 ms | 2.5 / 3.6 ms |
| 300 % | 2.0 / 2.6 ms | 2.3 / 3.5 ms | 1.6 / 2.2 ms | 4.0 / 7.4 ms |
| 400 % | 2.2 / 4.1 ms | 2.5 / 3.5 ms | 1.8 / 2.6 ms | 2.7 / 3.7 ms |

The first draw at 100 % went from 529 ms (CPU) and 456 ms (GPU) to 12 ms and
6 ms. The cause was the checkerboard (#3019). CanvasViewport filled it in
SwiftUI at the artboard's size and rasterized it whole on the CPU, on every pan
frame, until that backing store passed Core Animation's size limit at about
150 %. It is now a pattern-coloured layer.

`PhotoZoomBudgetTests` (perf list) hosts the real PhotoWindow and drags the
exposure slider 30 steps at 120 Hz. A main-queue Dispatch heartbeat records how
long the main thread was busy past each beat. Slider at 100 %, longest stall /
total:

| | CPU | GPU |
|---|---|---|
| dev before | 210 ms / 3.4 s | 290 ms / 2.1 s |
| tiles as IOSurfaces made off main (#3025) | 52 ms / 1.1 s | 67 ms / 2.1 s |
| plus resident GPU tiles | 59 ms / 1.2 s | 56 ms / 1.5 s |

Before, each picture that landed spent its time in Core Animation's commit,
colour-converting every sRGB tile image on the main thread.

## Real-app perf journeys (`scripts/ui-test perf`)

Everything above runs models and views inside a test process, so it never
sees what the real app does to the machine. The `<X>RealPerfJourneyTests`
journeys (`UITests/Journey+Health.swift`) launch the bundled app (a copy at
`.build/realperf/AfterGlow.app` whose helpers' bundle ids end in
`.realperf`, so an app the user has open never blocks the launch), drive real
gestures for about 3 s each and judge every gesture from outside the
process:

| Check | How | Fails when |
|---|---|---|
| step p95 | the `suite.perf` samples the gesture added (event to the turn that showed it) | over 33 ms |
| main thread | `/usr/bin/sample <pid> 3` during the gesture, `scripts/sample-surfaces` | over 20% of main-thread samples under `IOSurfaceCreate` / `SurfacePool::alloc` |
| hang | an XCUITest window query right after | no answer within 2 s |
| idle CPU | 3 s after, CPU over two 1 s windows (`ps -o time=`) | both over 10% |

The UI test runner is sandboxed, so `scripts/realperf-watch` (started by
`scripts/ui-test perf` beside xcodebuild) runs `sample` and `ps` for it and
writes the 8K photo (7680 x 4320) Photo opens. Pan and zoom have no
`suite.perf` series, so their round trips (which include XCUITest's own
overhead) are recorded, not gated; neither are Design's and Flare's canvas
drags, which publish no `canvas-drag` samples on dev, so those gate on the
other three checks. Pinch isn't driven: XCUITest on macOS can't make a
magnify gesture, so ⌘= / ⌘− stand in. Photo runs with Metal on and off
(`-suite.rendering gpu|cpu`); Design and Flare have no switch. The journeys
move the mouse, so they run only in perf-nightly.sh at 04:30, never in a
daytime loop; a plain `scripts/ui-test` skips them.

First run, dev `17dc84c7` (2026-10-19, M2 Pro, daytime load), step p95 / idle CPU (the two 1 s readings):

| App | Gesture | Metal on | Metal off |
|---|---|---|---|
| Photo 8K | Levels (Black slider) | 225 ms / 0%, 133% | 171 ms / 1%, 175% |
| Photo 8K | Hue/Saturation (Hue slider) | 333 ms / 0%, 107% | 499 ms / 165%, 121% |
| Photo 8K | Move tool, 3 s drag | n/a / 102%, 213% | n/a / 169%, 108% |
| Photo 8K | pan at 300% (round trip) | 535 ms / 0%, 1% | 1032 ms / 0%, 1% |
| Photo 8K | ⌘= / ⌘− (round trip) | 243 ms / 0%, 0% | 914 ms / 1%, 0% |
| Design `crowd` | Move a rectangle | n/a / 0%, 0% | |
| Design `crowd` | Opacity bar | 284 ms / 0%, 0% | |
| Design `crowd` | pan / zoom (round trip) | 1234 / 1093 ms | |
| Flare `bounce` | Rotation bar | 487 ms / 0%, 0% | |
| Flare `bounce` | pan / zoom (round trip) | 470 / 153 ms | |

No gesture hung (every window query answered in under 0.1 s) and none spent
over 0.1% of its main-thread samples in surface allocation on this build. The
Move rows stay busy 3 to 5 s after the drag ends on both backends; what keeps
them busy (the autosave of an 8K document is a candidate) isn't measured yet.
In a second run Photo with Metal on crashed while opening the 8K photo
(SIGABRT: `CanvasTilePresenter.present` asks MPS for a texture 30238 px
high, over Metal's 16384 limit); direct launches hit it 5 times in 5. The
journey's failure names those frames.

## What the harness can't drive

The test process is never the active app. Every press it sends is a
window-activation click, and a SwiftUI gesture ignores those unless it opts in
with `allowsWindowActivationEvents`. Two kinds of view handle them anyway:
SwiftUI's canvases (CanvasViewport) and AppKit controls (lists, split views).
Inspector scrub rows don't. (Halo's viewer does when the window is hosted with `haloViewerTakesActivationClicks`, which `RenderBudgetHaloTests` does.) So Flare's scrub row steps
through its accessibility slider, the way VoiceOver and XCUI adjust it, not
through a drag.

NSSplitView tracks a divider drag in a modal loop that a test can't pace, so
the divider moves through `setPosition(_:ofDividerAt:)`, which is what that
loop calls. A wheel event made in a test carries no phase, so the grid scrolls
its clip view directly.

## Photo at 8K: one adjustment step, before and after the live route

`PhotoAdjustSliderLatencyTests` (perf list) times one step on the 8K document,
from the edit to the canvas texture holding the picture, through the canvas
renderer's route. Release, M2 Pro, p50 / p95 per step, 30 steps:

| Step | GPU before | GPU after | CPU (unchanged route) |
|---|---|---|---|
| Hue/Saturation, Saturation | 636 / 661 ms | 12.4 / 13.4 ms | 102 / 105 ms |
| Levels, Gamma | 79 / 93 ms | 18.8 / 24.2 ms | 107 / 109 ms |
| Curves, midpoint | 79 / 113 ms | 17.8 / 19.2 ms | 102 / 124 ms |
| Levels adjustment layer, Gamma | 820 / 869 ms | 18.0 / 22.2 ms | 110 / 120 ms |
| Hue/Saturation adjustment layer | 816 / 839 ms | 12.5 / 13.9 ms | 104 / 151 ms |
| Move tool, top layer | 35 / 41 ms | 33 / 69 ms (busy machine) | 92 / 97 ms |

Before, Hue/Saturation had no GPU op: each band of the picture was read back,
run through Photo's per-pixel colour matrix on the CPU and uploaded again. Any
visible adjustment layer sent every redraw, a Move or a brush frame included,
down the same read-back path. The live route (PhotoLiveTone.swift) keeps each
band's composite of the pixel layers on the GPU while they are unchanged. It
runs adjustment layers as CoreRender tone-program passes and writes the picture
through the image's adjustments in the same pass as the display encode. A
slider step composites nothing and reads nothing back. The budget is 30 ms
p95 for an adjustment step and 80 ms for a Move, and the target is 16 ms.
Levels and Curves still build their tables on the CPU each step (about 2.5 ms),
and a Move composites every layer again, so those rows sit over the target.
Blur, a masked adjustment layer and the CPU route keep the old path.

## Photo: a Move step on a many-layer picture

A Move step used to damage the whole canvas and composite every visible layer
over it again, on both routes. On the stress document (3840 x 2160, 100
layers, a quarter adjustment layers and a quarter masked) one render took
seconds, so the drag's renders ran on after the release and the stress gate
read 472% / 489% CPU 3 s after it (#3663). The dispatcher route now keeps each
region's composite of the layers the stack still shares with the last render
(PhotoCompositeCache.composite) and composites only the changed layer and the
ones above it, and a Move damages only where the layer was and is.
`IdleWorkTests` (AppSnapshotTests) reports what a 30-sample drag leaves
running; debug build, 1024 x 576 in 60 layers (the dev rows are from a
1280 x 720, 100-layer run, where the dev build never finished one GPU render):

| Route | Layer composites in the drag | Pictures in the drag | Rendering in the gate's readings |
|---|---|---|---|
| GPU, dev | 69, the first render still running 12 s later | 0 | yes, 12 s later too |
| GPU, now | 9 (one per region, 9 cache hits) | 2 | none |
| CPU, dev | 1556 | 0 | the queued render, 22 regions |
| CPU, now | 96 (one per region, 96 hits) | 7 | none |

What ran after the release was the Curves histogram recount (one row at a
time through every layer, one core for seconds; a masked layer's tile is now
masked only over the row, not the whole 256 px tile) and the autosave 5 s
after the last edit.

The histogram now keeps each sampled row's composite in a PhotoCompositeCache
of the inspector's own (`curvesHistogram(composites:)`): a Levels or Exposure
step recounts the kept rows with no layer composited, and a layer change lays
that layer and the ones above it on each row's kept base. Its work counts as
the reference path's (`rows`, `rowLayers`), apart from the canvas's regions
and layers. `IdleWorkTests` drives the stress journey's Levels drag and eye
toggles and the real-perf journey's Hue drag on the same document, debug
build, both routes, and gates counts: it waits for the canvas's renders to
drain and the counters to hold still, then checks the gesture's work and that
3 s more show no region, picture, row or row layer:

| Gesture | Histogram after the release, dev | now (GPU / CPU) |
|---|---|---|
| Levels Black, 30 steps | 192 rows x 60 layers, 7 to 17 rows a second for about 20 s on one core | 229 / 296 rows, 0 row layers (gated: no layer) |
| Hue, 30 steps | no count (outside the key) | 0 rows (gated) |
| 4 eyes hidden then shown | a count per click, the last 192 rows x 60 layers, about 20 s | 593 / 378 rows, 623 / 249 row layers over all the clicks' counts |

Those tests drop the window's autosave after the gesture: it still flattens
the picture through the reference path 5 s after the last edit, which would
read as a recount.
