# Feature packet: core-loop

**Feature:** The core loop, live, measured. One person, one sitting: a new
composition, a solid, a Position X key, a drag that keys frame 24, Ease Out
on the first key, Play, a text layer, Undo and Redo, File > Render… to a PNG
sequence, ⌘S, relaunch on the file. Every step on live services, driven with
the mouse, in one journey (H-J12, the `XCTSkip` in `HaloJourneyTests.swift`).
Around it: the five perf journeys H-P1 to H-P5 on the frame probe, layout
L3 to L5, every Halo journey moved from `-HaloFixture` (fake services) to
`-HaloSample` (live), and Halo's render job and sheet moved onto the shared
kernel: SuiteKernel's `ExportRun<HaloRenderSettings>` and SuiteUI's
`ExportSheet`, through one adapter file. No app-local export engine, no
onboarding (the suite's onboarding packet owns first launch on SuiteUI and
SuiteShell; Halo adds none).
**Line:** `line:halo` · **Wave:** W3 (`waves.md`) · **Lead branch:** `lead/core-loop`

**Covers:** the H-J12 `XCTSkip` (closes with CL-13); H-P1 to H-P5 and
L3 to L5 (blueprint 4 and 7); Halo's half of the kernel-export adoption
(`lead.md` rule 20; adopt-kernel-export has slices for Flare, Photo and
Library and none for Halo, so it lives here). In the captain's beta cut
(`paw-workspace/docs/design/drafts/2026-10-17-afterglow-beta-cut.md`, Halo
row and §5's Halo chain "comp → keys → ease → play → text → render → reopen").

**Depends on:** every W1 and W2 Halo feature issue (viewer-playback #1035,
layer-keys #1036, history-files #1037, layer-panel #1038, easing #1333,
render-out, text-layers): this packet edits their journey files and their
render files, so its issue is filed once the last of them closes and its
one `Depends on:` line names that one. #333 is done (`project.yml` compiles
`UITests/Halo*.swift`), and #330 is done (`Sources/SuiteUI/FrameProbe.swift`,
`-SuitePerfProbe`, `Journey.perf()`), so neither is carried.

**Hand-offs** (files and slices other lines own; cross-line, so they are
prose here and in `waits_on`, never in the `.wave.json` `waits`, which only
names Halo features and this packet's own slices; the lead checks each
before the task starts):
- **editor-kernel EK-a** (`Sources/SuiteKernel/Export/ExportRun.swift` stub,
  `Package.swift` makes every Model depend on SuiteKernel): CL-1 and CL-2
  import it. **EK-run** (the body): CL-6. **EK-chrome**
  (`Sources/SuiteUI/ExportSheet.swift`): CL-4.
- **SuiteUI probe recorder** (`needs-ui`, filed by the lead at stage 1, see
  "Issues this packet files"): today `SuiteProbesModifier` keeps its
  `SuiteFrameProbe` in a private `@State`, nothing constructs a `ProbeSample`
  anywhere under `Sources/`, and `timelineFadeMark` is internal, so an app
  view has no way to record a sample. CL-8 waits on it; until it merges,
  H-P1 to H-P5's latency half is report-only from
  `HaloViewerLatencyTests` (the blueprint's fallback, 7.1).
- **switching A-HA-1** (#865) owns `Sources/HaloApp/HaloApp.swift` and edits
  `UITests/HaloJourneyTests.swift` (`testSwitchToMenu`): CL-12 and CL-13
  start after it merges. "New composition from the home" is its journey
  (the home's New Composition tile hands `.new` to Halo, which opens the New
  Composition sheet); H-J12 starts where that hand-off lands, at the sheet.
- **render-out RO-3 and RO-8** build an app-local render state machine
  (`HaloRenderJob.swift`) and sheet (`HaloRenderSheet.swift`), both
  pre-rule-20. This packet's CL-run and CL-ui replace them whichever lands
  first (the delete is real when render-out merged first, a no-op when it
  was re-cut). Cheaper: re-cut RO-3 onto `ExportRun` once EK-run lands; see
  "Issues this packet files".
- **text-layers TX-7** edits `docs/blueprints/halo/c4-planned.json`; this
  packet's data edit to the same file (two paths added) merges key by key
  through the JSON merge driver.

**Clean-room.** Behaviour only; every rule comes from Halo's own tests and
the kernel's contract. No product names.

**Most-used first.** The tier-1 order of the blueprint's usage map (3):
create, layers, key, play, render; text and the measurements after. The
slices below run in that order where they chain, and side by side where
they don't.

Blueprint sections it builds on: 2 (launch arguments, fixtures `reference`
and `crowd`), 4 (H-J12, H-P1 to H-P5), 5 (`CompositionRendering`,
`HaloRenderSettings`, `HaloRenderPlan`, `HaloRenderOutcome`,
`HaloRenderJobState`), 6 (Render sheet row, D9: Halo says Render…, not
Export), 7.1 (HB-U1 to HB-U5), 7.3 (L3 to L5), 8.3 (core-loop's owned
files), suiteui's editor-kernel packet (EK-run, EK-chrome: `ExportRun`,
`ExportSheet`). The packet wins over the blueprint where they differ
("Review notes folded in").

**Building blind.** CL-4, CL-5, CL-8, CL-9, CL-11 and CL-13 are in
`Sources/HaloApp/`, `Tests/AppSnapshotTests/` and `UITests/`, which the
Linux gate never compiles. Copy the shape of a HaloApp file that builds
(`HaloWindow+File.swift` for a sheet presented from an area hook,
`HaloViewerGestures.swift` for a gesture that reads an environment value),
check every SwiftUI and AppKit API with `apple-docs` and say so in the PR
(`Unverified API:` lines for what it couldn't check), keep views dumb (the
app-state lint), read `docs/engineering/swiftui-rules.md` before any UI
task, and put every decision that can be pure into CL-6 and CL-7.

**Shared-file rule.** This feature owns only the files in its task rows. It
never edits `Sources/SuiteUI/**`, `Sources/SuiteKernel/**`, `Package.swift`,
`project.yml`, `Tests/perf-suites.txt`, `UITests/Journey*.swift`,
`Sources/HaloModel/HaloProject.swift` (the stored `renderJob:
HaloRenderJobState?` stays as W0 shaped it; the adapter projects it),
`HaloCommand.swift`, `HaloCommands.swift`, `HaloFileMenu.swift`,
`HaloWindow.swift`, `docs/c4/model.json`, `docs/design.md` or a `waves.md`.
File > Render… (⇧⌘R) and Render Frame (⌘R) exist from FD-16 and turn on
through `HaloAvailability+Render.swift`.

## Slices

A slice is the unit of done: its tasks merged, its journeys green on a
Halo-scoped run (`ci.yml` with `app=halo`) that contains its last PR, no
open `finding`, and for CL-ui and CL-probe the feel gate and a `Mac-Finish:`
line. CL-a publishes the checks and the stubs; CL-ui, CL-run and CL-probe
run beside each other on them; CL-measure needs the probe; CL-z integrates.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CL-a | The loop's checks exist before its code: the Linux walk of the whole loop on live services, the kernel-run tests, the five perf journeys and the L3 to L5 layout tests (disabled until their tasks), plus the `HaloRenderJob+Kernel` stubs the sheet compiles against. | CL-1, CL-2, CL-3 | MJ-CL1 | editor-kernel EK-a (CL-1, CL-2; cross-line) |
| CL-ui (`"ui": true`) | File > Render… (⇧⌘R) opens SuiteUI's `ExportSheet` over the kernel run's readouts on the stubs, with Halo's format and size rows, the destination and Reveal in Finder, and progress, done and failed states; render-out's `HaloRenderSheet` is gone and H-J21 drives the new sheet. | CL-4, CL-5 | H-J21 | CL-a (CL-4, CL-5); editor-kernel EK-chrome (CL-4; cross-line) |
| CL-run | Halo's render job runs on `ExportRun<HaloRenderSettings>`: every transition goes through the kernel (progress never back, clamped to the plan, cancel to idle), availability reads the run, and render-out's app-local state machine and its tests are deleted. | CL-6, CL-7 | MJ-CL2 | CL-a (CL-6, CL-7); editor-kernel EK-run (CL-6; cross-line) |
| CL-probe (`"ui": true`) | Under `-SuitePerfProbe` the viewer drag, inspector bar scrub, playhead drag, playback ticks and the lane and layer-list scroll record their input samples and drawn frames into the window's probe, so `suite.perf` carries HB-U1 to HB-U5's series, and recording adds no window body. | CL-8, CL-9 | H-P1, H-P4 | CL-a (CL-8, CL-9); the SuiteUI probe recorder `needs-ui` (CL-8; cross-line) |
| CL-measure | H-P1 to H-P5 run on `reference` and `crowd` with the probe and attach their series against HB-U1 to HB-U5, L3 to L5 hold in the hosted views, `HaloViewerLatencyTests` writes its `HALO-LATENCY` line, and every Halo journey launches on live services. | CL-10, CL-11, CL-12 | H-P1 to H-P5 | CL-a (all three); CL-probe (CL-10); switching A-HA-1 (CL-12; cross-line) |
| CL-z | H-J12 walks the whole loop live with the mouse, from New Composition… through layers, keys, ease, play, text, undo, Render… to PNG files, save and relaunch, and the feature is built. | CL-13, CL-14 | H-J12 | CL-ui, CL-run, CL-probe, CL-measure (CL-13) |

Screen early (rule 18): CL-ui and CL-probe own `Sources/HaloApp/` files, wait
within this feature only on CL-a, and run beside CL-run. CL-ui's first task
(CL-4) reaches the sheet from the existing File > Render… item and the
toolbar-less ⇧⌘R on CL-2's stubs, which return the fake's values (a
`.editing` run with `keyed`'s plan of 48 frames at 960 × 540) so the sheet
is clickable end to end before CL-6. CL-probe's visible controls are the
viewer, the inspector bars, the ruler, the transport and the lists that
already exist; it adds no control.

## Journey steps

Each class and file is its own (`project.yml` compiles `UITests/Halo*.swift`).
Every step is done with the mouse; the keyboard appears only as a parity
check next to the mouse step that it mirrors. Fractions on `drag(on:from:to:)`
are of the element's size; `velocityDrag` draws enough samples for `perf()`
(60 or more).

**MJ-CL1 · `HaloCoreLoopTests.walk`** (Linux Model walk, CL-1; slice CL-a,
turned on by CL-6 for its render step). On `HaloProject(services:
.live)` with `services.text = FakeTextRasterizer()` (the live set has no
rasterizer until HaloApp sets one): `newComposition(CompositionSettings(name:
"Loop", framesPerSecond: 24, durationSeconds: 2))` is true, 48 frames;
`newLayer(.solid)`; `toggleAnimation(.x)` at 0 keys x at 0 and 47
(`HaloKeyRules.toggleAnimation` keys the playhead and the last frame);
`scrub(to: 24)`; `beginViewerDrag` at the solid's centre, `moveViewerDrag`
by +300 x, `endViewerDrag`: x keys at 0, 24, 47, the key at 24 reads the
start value + 300, `history.undo.count` grew by exactly one and
`undoTitle == "Undo Move"`; `selectKey(HaloKeyRef(layerID:, property: .x,
frame: 0), extending: false)`, `setEasing(.easeOut)`: the 0 → 24 segment's
easing is Ease Out, `undoTitle == "Undo Keyframe Easing"`; `play(at: 0)`,
`tick(now: 0.5)`: the playhead is in 1…47, `pause()`; `newLayer(.text)`,
`setText("Hello")` (text-layers' method) → `undoTitle == "Undo Edit Text"`;
`undo()` then `redo()` round-trip the document (`==`); `beginRender(.init(
format: .pngSequence, halfSize: true))`, `startRender()` returns a plan of 48
frames at 960 × 540 and `renderRun` reads `.running(_, done: 0, total: 48)`;
`renderProgressed(done: 48)`, `endRender(.finished(frames: 48))` →
`.finished`; `dismissRender()` → `.idle`; `fileData()` round-trips through
`services.files.decode` and `restore(_:)`: compositions, layers, keys and
easing equal, history empty. The render step is `@Test(.disabled("waits
on CL-6"))` as its own test, `walkRenders`, until CL-6 turns it on.

**MJ-CL2 · `HaloRenderRunTests`** (Linux, CL-1; slice CL-run, turned on by
CL-6): every transition of `HaloProject`'s render job through the adapter,
on `keyed` with `.fake`: `beginRender` from idle → `.editing`; `beginRender`
again → false, unchanged; `startRender()` → `.running(done: 0, total: 48)`
and a plan; `renderProgressed(done: 12)` → 12, then 11 keeps 12, 99 keeps
48; a second `startRender()` while running → nil; `endRender(.finished(
frames: 48))` → `.finished(settings, names)` with 48 names `Bounce_0001.png`…;
`endRender(.failed(frame: 5, message: "Disk full"))` from running →
`.failed(settings, "Render stopped at frame 5: Disk full.")`;
`endRender(.cancelled(frames: 12))` → `.idle` and `renderJob == nil`;
`cancelRender()` from editing → `.idle`; `dismissRender()` from finished →
`.idle`; `renderProgressText` reads "Frame 12 of 48" while running and nil
otherwise; `startRender()` yields "Frame 0 of 48" before any frame is written
(`progressShowsAtOnce`, HB-U5's Model half). All `@Test(.disabled("waits on
CL-6"))` in CL-1.

**H-J21 · `HaloJourneyTests.testRenderPNGSequence`**
(`UITests/HaloJourneyTests+Render.swift`, render-out's journey under the class
name its wave data gives; if RO-10 declares its own class, CL-4 keeps it and
fixes the name in this feature's data; re-pointed by CL-4; slice CL-ui). On `-HaloSample keyed -HaloRenderTo <tmp>`: File >
Render… (menu, mouse); the sheet is SuiteUI's (`suite.export.*`
identifiers as EK-30 names them; the destination row and Reveal in Finder
keep `halo.render.destination` and `halo.render.reveal`); click PNG
sequence, click Half; the summary reads "48 PNG files, 960 × 540, into a new
folder "Bounce""; click Render; the progress row reads "Frame n of 48"; the
done line reads "Rendered 48 frames." with Reveal in Finder; `<tmp>/Bounce/`
holds exactly `Bounce_0001.png` … `Bounce_0048.png`, each 960 × 540. Then
relaunch on `-HaloSample reference -HaloRenderTo <tmp>`, Render…, Movie,
Full, Render, click Cancel as soon as "Frame n of 300" shows: the sheet is
gone (cancel returns the run to idle; the kernel's contract) and `<tmp>`
holds no `.mp4`. The cancelled-count text render-out's sheet showed is not
asserted any more ("Review notes folded in").

**H-J12 · `HaloJourneyTests.testKeyLayerAndSave`** (`HaloJourneyTests.swift`,
replaces the `XCTSkip`; CL-13; slice CL-z). Launch with no sample (live
services, the empty state) and `-HaloSaveTo <tmp>/Loop.halo -HaloRenderTo
<tmp>`:
1. Click the toolbar's New Composition… (`halo.composition.new`); in the
   sheet type `Loop` in Name, pick 24 fps, type `2` in Duration; click
   Create (`halo.composition.sheet.create`). Shot `loop-new`. Expect the
   inspector header "1920 × 1080" and "24 fps · 2 s", sidebar row "Loop".
2. Layer > New > Solid (menu bar, mouse, as H-J9 clicks Layer items). Shot
   `loop-solid`. Expect the layer list's first row "Solid 1" and
   `halo.viewer.drawn` "1 layer drawn".
3. Click the Position X stopwatch (`halo.inspector.key.x`). Shot
   `loop-stopwatch`. Expect its value "Keyed at this frame" and Edit >
   "Undo Animate Position X".
4. Scrub to 24: drag on `halo.timeline` from dx 0.02 to dx 0.5 at dy 0.05
   (the ruler), then → or ← until the timecode reads `00:00:01:00`
   (keyboard parity for the exact frame; the drag is the mouse step). Shot
   `loop-frame-24`.
5. Drag the solid 300 px right from its centre in the artboard
   (`ViewerDragSteps.drag`, +Drag.swift's helper). Shot `loop-dragged`.
   Expect Position X = 960 + 300 within `ViewerDragSteps.tolerance()`, key
   state "Keyed at this frame", Edit > "Undo Move".
6. In EASING click the row "Position X 0 → 24" (`halo.easing.row.*`), click
   the Ease Out chip in `halo.easing.presets`. Shot `loop-ease-out`. Expect
   the row reads "Ease Out" and Edit > "Undo Keyframe Easing".
7. Click `halo.transport.play`; wait 1 s; click it again. Shot
   `loop-paused`. Expect the button's value "Playing" then "Paused" and the
   artboard's frame in 1…47. Space twice is the parity check (not asserted
   twice; one press pair, same reads).
8. Layer > New > Text; type `Hello` in the TEXT field and Return (text-
   layers' H-J22 steps). Shot `loop-text`. Expect `halo.viewer.summary` ends
   "Text 1: Hello" and Edit > "Undo Edit Text".
9. Edit > Undo (menu, mouse): the summary loses "Hello"; Edit > Redo: it is
   back. Shot `loop-undo-redo`. Expect the Edit menu titles flip to "Redo
   Edit Text" and back.
10. File > Render…: click PNG sequence, Half, Render; wait for "Rendered 48
    frames."; click Close. Shot `loop-rendered`. Expect `<tmp>/Loop/` holds
    `Loop_0001.png` … `Loop_0048.png` at 960 × 540.
11. ⌘S (File > Save by menu is the mouse step; ⌘S the parity). Shot
    `loop-saved`. Expect the window title "Loop" with no unsaved dot and
    `<tmp>/Loop.halo` on disk.
12. Quit; relaunch with `-HaloOpenFile <tmp>/Loop.halo`. Shot
    `loop-reopened`. Expect two layers, Solid 1's x keys at 0, 24 and 47
    (the EASING list's rows "Position X 0 → 24" reading "Ease Out" and
    "Position X 24 → 47" reading "Linear"), the text layer "Hello" drawn at
    0, and Undo disabled with "Nothing to undo.".

**H-P1 to H-P5 · `HaloPerfJourneyTests`** (`UITests/HaloJourneyTests+Perf.swift`,
own class, `PerfBudgeted`; CL-3 adds them as `XCTSkip("waits on CL-10")`,
CL-10 turns them on; slices CL-probe, CL-measure). Each launches with
`-SuitePerfProbe` and ends with `perf()`, which attaches `perf-<test>` and
checks the class's `perfBudgets` (every gate report-only: `limit` the 7.1
placeholder, `enforced: false`).
- **H-P1** `testViewerDragLatency`, `-HaloSample reference`: select a layer
  from its lane; four `velocityDrag(on: "halo.viewer.canvas", …)` legs of
  600 pt at 300 pt/s; series `viewer-drag`, HB-U1, at least 60 samples per
  leg.
- **H-P2** `testInspectorScrubLatency`, `reference`: `velocityDrag` across
  `halo.inspector.row.rotation`'s bar; series `inspector-scrub`, HB-U2.
- **H-P3** `testPlayheadScrubLatency`, `reference`: `velocityDrag` on
  `halo.timeline` from dx 0.02 to dx 0.98 at dy 0.05; series
  `playhead-scrub`, HB-U3.
- **H-P4** `testPlaybackHoldsRate`, `reference`: click Play, wait 5 s, click
  Pause; series `playback` (intervals), HB-U4.
- **H-P5** `testTimelineAndLayerListScroll`, `-HaloSample crowd`: scroll
  `halo.timeline`'s lanes and `halo.layer.list` end to end with the scroll
  wheel; series `lanes-scroll`, `layers-scroll` (intervals), QB-L10's UI
  half.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Render sheet (SuiteUI `ExportSheet`), editing | Format (PNG sequence, Movie) and Size (Full, Half) rows, Halo's destination row (the `-HaloRenderTo` folder, else a folder picker), the summary line, Render; Render disabled with "Choose a folder first." until a destination is set | a plan that throws: the run goes `.failed` with the plan error's words and Close | none |
| Render sheet, running | – | – | "Frame 12 of 48" progress bar with Cancel, shown the moment Render is pressed ("Frame 0 of 48", HB-U5); the `progress-shown` mark once EK-30 records it |
| Render sheet, finished or failed | – | "Render stopped at frame 5: Disk full." and Close | "Rendered 48 frames." with Reveal in Finder and Close |
| Render sheet, cancelled | the sheet closes (the run is idle); PNG frames written so far stay, a movie is removed | – | – |
| Menus | no composition: Render Frame and Render… disabled with "Create a composition first." | Render… while a render runs: "A render is already running." | none |
| `suite.perf` | absent without `-SuitePerfProbe` | – | – |
| Layout L3 to L5 | the playhead on its frame at 600, 900 and 1400 pt; TRANSFORM bars aligned at the inspector's minimum, ideal and maximum widths; status row transport left, pills right at the content minimum | – | – |

No other screen changes. Snapshots: `halo-render-sheet-light/dark.png`
(editing), `halo-render-sheet-progress-light/dark.png`,
`halo-render-sheet-done-light/dark.png`, `halo-render-sheet-failed-light/dark.png`
(render-out's names, now of the SuiteUI sheet; CL-4).

## Contract slice

The Halo types below are the adapter's; `ExportRun` and `ExportSheet` are
editor-kernel's (its Contract slice) and are used as declared there. CL-2
declares every signature as a stub that returns the fake's value, so CL-4
compiles and clicks before CL-6; CL-6 fills the bodies and never changes a
signature.

```swift
// HaloRenderJob+Kernel.swift (CL-2 stubs, CL-6 bodies). An adapter onto
// SuiteKernel.ExportRun: the stored `renderJob: HaloRenderJobState?` keeps
// W0's shape, and every transition builds the kernel value from it, applies
// the kernel's rule, and writes the result back.
import SuiteKernel
extension HaloProject {
    public var renderRun: ExportRun<HaloRenderSettings> { get }      // idle | editing | running(done, total) | finished(names) | failed(message)
    public mutating func beginRender(_ settings: HaloRenderSettings) -> Bool   // idle → editing (opens the sheet); false otherwise
    public mutating func setRenderSettings(_ settings: HaloRenderSettings)     // editing only
    public mutating func startRender() -> (plan: HaloRenderPlan, composition: HaloComposition)?
                                                                     // editing → running(0, frames.count) through services.compositionRendering.plan; nil otherwise
    public mutating func renderProgressed(done: Int)                 // running only; the kernel keeps max(done, old) clamped to total
    public mutating func cancelRender()                              // editing or running → idle (the app cancels its task)
    public mutating func endRender(_ outcome: HaloRenderOutcome)     // .finished → finished(fileNames); .failed → failed(words); .cancelled → idle
    public mutating func dismissRender()                             // finished or failed → idle
    public var renderProgressText: String? { get }                   // "Frame 12 of 48" while running
    public var renderOutcomeText: String? { get }                    // "Rendered 48 frames." / "Render stopped at frame 5: Disk full."
}

// HaloRenderJob.swift (render-out's file, CL-6 trims it): keeps the pure
// helpers renderSummary(_:existing:) and renderOutputName(_:existing:);
// loses openRenderSheet, closeRenderSheet, startRender(_:), renderProgress,
// cancelRender, finishRender and their texts (the adapter has them).

// HaloAvailability+Render.swift (CL-7): renderHelp reads renderRun.
//   .renderFrame: no composition → "Create a composition first."; else services.rendering.unavailableHelp
//   .openRenderSheet: no composition → the same; .running → "A render is already running."; else services.compositionRendering.unavailableHelp
//   .startRender, .cancelRender, .closeRenderSheet: nil only in the state they act in

// HaloProbe.swift (CL-8, HaloApp): one recorder every Halo input site reads
// from the environment SuiteUI's needs-ui adds; nil records nothing.
@MainActor struct HaloProbe {
    static let viewerDrag = "viewer-drag", inspectorScrub = "inspector-scrub", playheadScrub = "playhead-scrub"
    static let playback = "playback", lanesScroll = "lanes-scroll", layersScroll = "layers-scroll"
    func sample(_ series: String, event: Double, shownAt: Double)   // → ProbeSample
    func drew(_ series: String, at: Double)                         // playback: one per frame shown
    func mark(_ name: String, series: String)                       // "preview-before-mouse-up" on viewer-drag
}

// HaloJourneyTests+Perf.swift (CL-3): the gates, every row report-only.
extension HaloPerfJourneyTests: PerfBudgeted {
    static let viewerDrag    = PerfBudget(row: "HB-U1", series: ["viewer-drag"],    measure: .latency,   limit: 3)
    static let inspectorScrub = PerfBudget(row: "HB-U2", series: ["inspector-scrub"], measure: .latency,  limit: 3)
    static let playheadScrub = PerfBudget(row: "HB-U3", series: ["playhead-scrub"], measure: .latency,   limit: 3)
    static let playback      = PerfBudget(row: "HB-U4", series: ["playback"],       measure: .intervals, limit: 1.5)
    static let scroll        = PerfBudget(row: "QB-L10", series: ["lanes-scroll", "layers-scroll"], measure: .intervals, limit: nil)
    static let perfBudgets = [viewerDrag, inspectorScrub, playheadScrub, playback, scroll]
}
```

The sheet (CL-4): `ExportSheet` over `renderRun`'s readouts, with
`HaloRenderSettings.Format.allCases` as its format choices (titles "PNG
sequence", "Movie"), the Half toggle as its size row, no quality row,
Halo's destination row and Reveal in Finder in the sheet's content slot,
the primary button titled "Render" (D9), presented from `renderScene(_:)`
while `renderRun != .idle`, its `isPresented` built from `renderRun` and
`cancelRender()` / `dismissRender()`, never from `$model`. What EK-30's
sheet can't take (no quality row, a custom verb, a content slot, the
`progress-shown` mark) goes in the `needs-ui` below and gets a plain
SwiftUI placeholder row meanwhile, never an app copy of the sheet.

## Pseudocode

```
renderRun:                                             # CL-6, pure projection
  guard let job = renderJob else .idle
  job.plan == nil && job.outcome == nil           → .editing(job.settings)
  let plan, job.outcome == nil                    → .running(job.settings, done: job.progress, total: plan.frames.count)
  .finished(n)                                    → .finished(job.settings, plan.fileNames)
  .failed(f, m)                                   → .failed(job.settings, "Render stopped at frame \(f): \(m).")
  .cancelled                                      → never stored: endRender(.cancelled) sets renderJob = nil

transition(_ body: (inout ExportRun<HaloRenderSettings>) -> Void):   # every mutating method
  var run = renderRun; body(&run); write(run)     # the kernel decides; Halo stores the shape
write(run):   .idle → renderJob = nil
              .editing(s) → renderJob = .init(settings: s)
              .running(s, done, total) → renderJob.progress = done   (plan kept)
              .finished / .failed → renderJob.outcome from the kernel case

startRender():                                         # CL-6
  guard case .editing(let s) = renderRun, let comp = selectedComposition else nil
  do { plan = try services.compositionRendering.plan(comp, settings: s) }
  catch { transition { $0.end(.failure(error)) }; return nil }      # failed(words(error))
  renderJob?.plan = plan; transition { _ = $0.start(total: plan.frames.count) }
  return (plan, comp)
renderProgressed(done):  transition { $0.progressed(done: done) }   # ignored unless running; never back; ≤ total
endRender(o):  .finished → transition { $0.end(.success(plan.fileNames)) }
               .failed(f, m) → transition { $0.end(.failure(HaloEditError.notBuilt("Render stopped at frame \(f): \(m).")) }   # words only
               .cancelled → transition { $0.dismiss() }            # idle; files already written stay (PNG), the movie writer removed its file
cancelRender(): transition { $0.dismiss() }                        # the app cancels its Task first

HaloWindow+Render.swift, Render… (CL-4):               # the run loop stays render-out's HaloRenderRules via services.compositionRendering
  .openRenderSheet: _ = model.beginRender(.init(format: .pngSequence))
  Render: guard let (plan, comp) = model.startRender() else return
          task = Task.detached { var sink = Progress(base: writer(format, destination),
                                   onWrite: { n in Task { @MainActor in model.renderProgressed(done: n) } })
                                 let outcome = services.compositionRendering.run(plan, of: comp, text: services.text,
                                                                                 into: &sink, isCancelled: { Task.isCancelled })
                                 await MainActor.run { model.endRender(outcome) } }
  Cancel: task.cancel(); model.cancelRender()
  Close:  model.dismissRender()

HaloProbe (CL-8), where each sample is taken:
  viewer drag:   HaloViewerGestures.onChanged → live.show(...); sample("viewer-drag", event: event.timestamp, shownAt: nextRefreshTarget)
                 first sample also mark("preview-before-mouse-up", series: "viewer-drag")  (QB-F2)
  inspector bar: HaloLayerInspector's scrub onChange → sample("inspector-scrub", …)
  playhead:      HaloTimelineView's ruler drag → sample("playhead-scrub", …)
  playback:      HaloPlaybackDriver.receive(target:) → after onTick, drew("playback", at: target) when the frame changed
  scroll:        HaloTimelineView lanes / HaloLayerList scroll events → drew("lanes-scroll" / "layers-scroll", at: now)
  shownAt is the display link's next target timestamp when one runs, else now + refreshInterval (SuiteFrameProbe.fallbackRefreshInterval)
  nothing recorded without -SuitePerfProbe; the recorder is nil and every call returns at once
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: core-loop`, `Slice: <id>`,
`Fast-Check: pass`, `Head:`, and `Mutate: n/n <plan>` where a task owns a
plan. CL-14 also carries `feature-done`. Sizes are estimates.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CL-1 | – | **Checks first.** `HaloCoreLoopTests.walk` (MJ-CL1, enabled: every method it calls exists) and `.walkRenders` (disabled "waits on CL-6"); `HaloRenderRunTests` (MJ-CL2, every test disabled "waits on CL-6") | `Tests/HaloModelTests/HaloCoreLoopTests.swift`, `Tests/HaloModelTests/HaloRenderRunTests.swift` | – (EK-a, cross-line) | ~260, 2 |
| CL-2 | – | **Stubs.** `HaloRenderJob+Kernel.swift` with every signature of the Contract slice, each returning the fake's value (`renderRun` `.editing` once `beginRender` ran, `startRender` the fake plan, texts from a 48-frame run) with doc comments | `Sources/HaloModel/HaloRenderJob+Kernel.swift` | – (EK-a, cross-line) | ~120, 1 |
| CL-3 | – | **Checks first (macOS).** `HaloPerfJourneyTests` with `perfBudgets` and the five tests as `XCTSkip("waits on CL-10")`; `HaloLayoutTests` L3, L4, L5 (`@Test(.disabled("waits on CL-11"))`); `HaloViewerLatencyTests` scaffold (disabled the same); the two render budget suites `RenderBudgetHaloRenderTests` (disabled "waits on CL-5") and `RenderBudgetHaloProbeTests` (disabled "waits on CL-9") in `BodyCountSuites`, their rows written against the Quality table | `UITests/HaloJourneyTests+Perf.swift`, `Tests/AppSnapshotTests/HaloLayoutTests.swift`, `Tests/AppSnapshotTests/HaloViewerLatencyTests.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloRenderTests.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloProbeTests.swift` | – | ~300, 5 |
| CL-4 | – | **The sheet on the stubs.** `HaloWindow+Render.swift` presents SuiteUI's `ExportSheet` over `renderRun` from File > Render…, with Halo's rows and the detached run (the pseudocode); `HaloRenderSheet.swift` deleted when present; snapshots re-made of the SuiteUI sheet; H-J21 re-pointed at the sheet's identifiers and the idle-on-cancel state | `Sources/HaloApp/HaloWindow+Render.swift`, `Sources/HaloApp/HaloRenderSheet.swift`, `Tests/AppSnapshotTests/HaloRenderSheetSnapshots.swift`, `UITests/HaloJourneyTests+Render.swift` | CL-2 (EK-chrome, cross-line) | ~320, 4 |
| CL-5 | – | **Render budget, sheet.** Turns on `RenderBudgetHaloRenderTests.bodies` against the sheet CL-4 built: open Render… ≤ 2 window bodies; 48 `renderProgressed` ticks ≤ 48 bodies (gate); `timing` stays disabled until the supervisor lists it in `Tests/perf-suites.txt` (asked for in the PR body) | `Tests/AppSnapshotTests/RenderBudgetHaloRenderTests.swift` | CL-3, CL-4 | ~60, 1 |
| CL-6 | – | **Adapter body and delete.** Fills `HaloRenderJob+Kernel.swift` (the pseudocode), turns on `walkRenders` and `HaloRenderRunTests`, its mutation plan; trims `HaloRenderJob.swift` to the pure helpers and `HaloRenderJobTests.swift` to their tests | `Sources/HaloModel/HaloRenderJob+Kernel.swift`, `Sources/HaloModel/HaloRenderJob.swift`, `Tests/HaloModelTests/HaloRenderJobTests.swift`, `Tests/HaloModelTests/HaloRenderRunTests.swift`, `Tests/mutations/HaloModel.HaloRenderJob+Kernel.json` | CL-1, CL-2 (EK-run, cross-line) | ~300, 5 |
| CL-7 | – | **Availability over the run.** `renderHelp` reads `renderRun` (no composition; running; the sheet's own commands only in their state), its tests and plan | `Sources/HaloModel/Availability/HaloAvailability+Render.swift`, `Tests/HaloModelTests/HaloRenderAvailabilityTests.swift`, `Tests/mutations/HaloModel.HaloAvailability+Render.json` | CL-6 | ~150, 3 |
| CL-8 | – | **Probe feeding.** `HaloProbe.swift` reads SuiteUI's recorder from the environment; the viewer gesture, inspector scrub, ruler drag, playback driver and the two scroll views record their series (the pseudocode); nothing without `-SuitePerfProbe` | `Sources/HaloApp/HaloProbe.swift`, `Sources/HaloApp/HaloViewerGestures.swift`, `Sources/HaloApp/HaloPlaybackDriver.swift`, `Sources/HaloApp/HaloTimelineView.swift`, `Sources/HaloApp/HaloLayerList.swift`, `Sources/HaloApp/HaloLayerInspector.swift` | – (the probe `needs-ui`, cross-line) | ~260, 6 |
| CL-9 | – | **Render budget, probe.** Turns on `RenderBudgetHaloProbeTests.bodies` against CL-8's recording: with the probe on, a 120-sample viewer drag ≤ 3 window bodies and 1 s of playback ≤ 24 + 6 (gate); `timing` stays disabled until listed in `Tests/perf-suites.txt` | `Tests/AppSnapshotTests/RenderBudgetHaloProbeTests.swift` | CL-3, CL-8 | ~60, 1 |
| CL-10 | – | **H-P1 to H-P5 on.** Replaces the five `XCTSkip`s with the journeys above, each ending in `perf()` | `UITests/HaloJourneyTests+Perf.swift` | CL-3, CL-8 | ~240, 1 |
| CL-11 | – | **L3 to L5 and latency on.** Enables `HaloLayoutTests` (hosting `HaloTimelineView` at 600, 900, 1400 pt; `HaloLayerInspector` at its minimum, ideal and maximum widths; the status row at the content minimum) and `HaloViewerLatencyTests` (one `HALO-LATENCY` line to `.build/snapshots/halo-latency.txt`, like `PhotoBrushLatencyTests`); a miss is a `finding` on the view's owner, not a fix here | `Tests/AppSnapshotTests/HaloLayoutTests.swift`, `Tests/AppSnapshotTests/HaloViewerLatencyTests.swift` | CL-3 | ~200, 2 |
| CL-12 | – | **Live everywhere.** `-HaloFixture` → `-HaloSample` in `testEveryControlActsOrSaysWhy`, `testLayoutAtWidths` (HaloJourneyTests.swift), H-J5 (+Drag), H-J6 (+Inspector), the parent journey (+Parent) and H-J9 (+Layers); each journey's reads re-checked against live values | `UITests/HaloJourneyTests.swift`, `UITests/HaloJourneyTests+Drag.swift`, `UITests/HaloJourneyTests+Inspector.swift`, `UITests/HaloJourneyTests+Parent.swift`, `UITests/HaloJourneyTests+Layers.swift` | – (A-HA-1, cross-line) | ~60, 5 |
| CL-13 | the H-J12 `XCTSkip` | **H-J12 live.** `testKeyLayerAndSave` replaces the skip with the twelve steps above | `UITests/HaloJourneyTests.swift` | CL-4, CL-7, CL-12 | ~260, 1 |
| CL-14 | `feature-done` | **Shared prose.** `status: built` in the wave data; `waves.in.md`'s "core-loop (W3, packet to write)" row and the file-when-ready note; blueprint 8.3's core-loop owned-file list and 4's H-J12 row (2 s, 48 frames, the text and Render… steps) | `docs/blueprints/halo/features/core-loop.wave.json`, `docs/blueprints/halo/waves.in.md`, `docs/blueprints/halo.md` | CL-5, CL-9, CL-10, CL-11, CL-13 | ~80, 3 |

CL-1, CL-2, CL-3, CL-8 and CL-12 share no file and build together. CL-4
codes against CL-2's stubs and never waits on CL-6; CL-6 fills the stubs
without changing a signature, so CL-4 needs no second PR. CL-5 and CL-9 are
two files, not one, because CL-ui and CL-probe run at once; CL-3 writes
both disabled (checks first), so each slice's acceptance test is owned by a
task before its first code task. CL-10 needs
CL-8's samples (a probe with no Halo series gives `valid: false` and nothing
to attach). CL-12 and CL-13 both edit `HaloJourneyTests.swift`, so CL-13
waits. No task edits `docs/c4/model.json`; the two new `Sources/` files
(`HaloRenderJob+Kernel.swift`, `HaloProbe.swift`) were added to
`docs/blueprints/halo/c4-planned.json` with this packet (halo-render-out and
halo-viewer), so every owned source has one owner there and no C4 part
changes (both sit in folders `docs/c4/parts/creative-apps/halo-*` already
cover).

**Order safety.** `depends` on render-out means its files exist when this
packet starts; CL-4 and CL-6 then delete and trim. If render-out is re-cut
onto the kernel first (recommended, "Issues this packet files"), CL-4 and
CL-6 shrink to the sheet's Halo rows and the availability change; the slice
behaviour and the tests don't move.

## Build waves

- Wave 1: CL-1, CL-2, CL-3, CL-8, CL-12. Independent in this wave: all five
  (CL-1 and CL-2 once EK-a has merged; CL-8 once the probe `needs-ui` has;
  CL-12 once A-HA-1 has).
- Wave 2: CL-4, CL-6, CL-9, CL-10, CL-11. Independent in this wave: all five
  (CL-4 once EK-chrome has merged; CL-6 once EK-run has).
- Wave 3: CL-5, CL-7. Independent in this wave: both.
- Wave 4: CL-13. Independent in this wave: CL-13 alone.
- Wave 5: CL-14 (final, `feature-done`).

Longest chain: CL-2 → CL-6 → CL-7 → CL-13 → CL-14 (5). Chain of 5: CL-6
fills the stubs CL-2 declares, CL-7's "A render is already running" test
needs CL-6's real `.running`, CL-13's Render… step needs CL-7 to turn the
command on, and CL-14 flips `status` only after CL-13's journey is in.

## Acceptance test per task

Checks first (rule 13): CL-1 and CL-3 merge every slice's tests (the walk,
the run tests, the perf journeys, the layout and latency tests, the two
render budget suites) before any code task of those slices; a test ahead of its code is disabled by task id and
that task enables it. Mutations (rule 14) target Model code; a UI or test
task has none.

| id | test | fails when | mutations |
|---|---|---|---|
| CL-1 | `HaloCoreLoopTests.walk` green on `.live` (Linux); `walkRenders` and `HaloRenderRunTests` compile, disabled | a built feature's live method refuses or records the wrong step on the real services (the first proof the loop holds end to end on live) | – (tests) |
| CL-2 | `HaloCoreLoopTests.walkRenders` compiles against the stubs; `swift build` on Linux links HaloModel with SuiteKernel | a signature is missing or differs from the Contract slice | – (stubs) |
| CL-3 | the five files compile in the macOS build-only run; `HaloPerfJourneyTests.perfBudgets.count == 5`; both render budget suites nest in `BodyCountSuites` | a budget names a series no test records, or a test isn't skipped or disabled by task id | – (tests) |
| CL-4 | `HaloRenderSheetSnapshots` (editing, progress at "Frame 12 of 48", done, failed; each state set through the Model's methods on CL-2's stubs); H-J21 re-pointed; `scripts/ci`'s app-state lint | the sheet binds `$model`, a state lacks its control, Render is enabled with no destination, or `HaloRenderSheet.swift` still exists | – (UI) |
| CL-5 | `RenderBudgetHaloRenderTests.bodies`: open ≤ 2, 48 ticks ≤ 48 | a tick runs the window more than once, or opening the sheet runs it three times | – (UI) |
| CL-6 | `HaloRenderRunTests` (all on), `HaloCoreLoopTests.walkRenders`, `scripts/mutate --plan HaloModel.HaloRenderJob+Kernel` 4/4; `HaloRenderJobTests` keeps only the helper tests | a transition skips the kernel, progress goes back or past the end, two renders start, cancel leaves a job, or the state-machine half of `HaloRenderJob.swift` is still referenced | `renderProgressed` writes `done` straight to `renderJob.progress` → `HaloRenderRunTests.progressNeverBack`; `endRender(.cancelled)` keeps the job → `.cancelReturnsToIdle`; `startRender` accepted while running → `.secondStartRefused`; `beginRender` returns true from `.running` → `.beginRefusedWhileRunning` |
| CL-7 | `HaloRenderAvailabilityTests`: no composition → "Create a composition first." on both; `keyed` on `.fake` and `.live` → nil; `.running` → Render… "A render is already running.", Render Frame nil; `.finished` → Render… nil; `.cancelRender` nil only while running; `scripts/mutate --plan HaloModel.HaloAvailability+Render` 2/2 | a command turns on in the wrong state or stays off when it can act | `.running` help dropped → `.renderDisabledWhileRunning`; `.finished` treated as running → `.renderEnabledAfterFinish` |
| CL-8 | `RenderBudgetHaloProbeTests` (CL-9) and `HaloPerfJourneyTests` (CL-10) are its oracle; on its own PR: the macOS build-only run and the app-state lint (the recorder is environment-provided, never Model state) | a site writes the Model per sample to record, or records without the probe | – (UI) |
| CL-9 | `RenderBudgetHaloProbeTests.bodies`: viewer drag ≤ 3, playback 1 s ≤ 30, probe on | recording a sample runs the window | – (UI) |
| CL-10 | H-P1 to H-P5 on the Halo-scoped run: each `perf-<test>` attachment has its series with `valid: true` (≥ 60 samples or intervals); `perf-budgets-<test>` lists every row, none enforced | a series is missing or short, or a gate is enforced before ten green runs | – (journeys) |
| CL-11 | `HaloLayoutTests.playheadOnItsFrame` (≤ 1 pt at 0, last/2, last at 600, 900, 1400 pt), `.transformBarsAlign` (≤ 0.5 pt, buttons in one column, no truncation), `.statusRowNeverOverlaps` (0 pt at the content minimum); `HaloViewerLatencyTests` writes its line | a rule breaks (then a `finding` on the view's feature) or the line isn't written | – (tests) |
| CL-12 | the six journeys green on `-HaloSample` in the scoped run | a read that held on the fake differs on live | – (journeys) |
| CL-13 | H-J12 on the scoped run: twelve shots, every assert, the 48 PNGs, `Loop.halo` reopened with keys 0, 24, 47 and Ease Out on the first | any step's assert; a step that needs the keyboard to be reached | – (journey) |
| CL-14 | `scripts/waves check halo` and `render --dry-run` clean; `status: built` | the data or prose is out of step with the tasks | – (docs) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-U1 viewer drag on screen | p95 ≤ 2 frames late; placeholder 3, report-only | H-P1 (CL-10), series `viewer-drag` |
| HB-U2 inspector bar on screen | p95 ≤ 2 frames late; placeholder 3, report-only | H-P2, `inspector-scrub` |
| HB-U3 playhead on screen | p95 ≤ 2 frames late; placeholder 3, report-only | H-P3, `playhead-scrub` |
| HB-U4 playback holds rate | 0 dropped, jitter p95 < 2 ms; placeholder ≤ 1.5 refreshes, report-only | H-P4, `playback` |
| QB-L10 UI half, lanes and list scroll | p95 interval ≤ 1.5 refreshes; gate set from CI | H-P5, `lanes-scroll`, `layers-scroll` |
| HB-U5 Render… to progress shown | ≤ 100 ms; Model half: `startRender` yields "Frame 0 of 48" at once | `HaloRenderRunTests.progressShowsAtOnce` (CL-6); the `progress-shown` mark once EK-30 records it |
| render: open Render… (⇧⌘R) | ≤ 2 window bodies; p95 ≤ 33 ms report-only | `RenderBudgetHaloRenderTests.bodies` / `.timing` (CL-5) |
| render: 48 progress ticks | ≤ 48 window bodies (one per Model write), p95 step ≤ 8.3 ms report-only | `RenderBudgetHaloRenderTests.bodies` / `.timing` (CL-5) |
| render: probe on, 120-sample viewer drag | ≤ 3 window bodies (RenderBudgetHaloTests' bound, unchanged by recording); 1 s playback ≤ 24 + 6 | `RenderBudgetHaloProbeTests.bodies` (CL-9) |
| L3 playhead on its frame | ≤ 1 pt | `HaloLayoutTests.playheadOnItsFrame` (CL-11) |
| L4 TRANSFORM rows align | ≤ 0.5 pt; labels never truncate | `HaloLayoutTests.transformBarsAlign` (CL-11) |
| L5 status row | 0 pt overlap; timecode never truncates | `HaloLayoutTests.statusRowNeverOverlaps` (CL-11) |
| QB-F1 no dead controls | every sheet control enabled or disabled with help; Render… and Render Frame say why | `HaloRenderAvailabilityTests` (CL-7); H-J13's control sweep on the sheet |
| One gesture, one step | the viewer drag lands as one "Move"; Render Frame and Render… record no step | `HaloCoreLoopTests.walk` (CL-1); H-J12 step 5 |
| Keyboard parity | every H-J12 mouse step has its key (→ for the frame, Space, ⌘Z, ⇧⌘Z, ⌘S); none is needed to reach a screen | H-J12 (CL-13); the `mouse` lens |
| Mouse-only first-time user | every sheet state can be entered and left with the mouse (Cancel, Close, Reveal in Finder) | the feel gate on CL-ui; H-J21 |
| Taste | the sheet is SuiteUI's; Halo adds rows, no look of its own | the `taste` lens on CL-ui's snapshots |
| Audit | no `halo` count over `UITests/audit-baseline.json`; the sheet's identifiers are SuiteUI's plus `halo.render.destination`, `halo.render.reveal` | `audit-halo-*.json` on the scoped runs |

## Done check

Per slice, the Verified level (`lead.md` rule 6):
- **CL-a:** `HaloCoreLoopTests.walk` green on the dev Linux job containing
  CL-3; `Belt-Slice-Done: CL-a`.
- **CL-ui:** H-J21 green on a Halo-scoped run containing CL-5;
  `RenderBudgetHaloRenderTests.bodies` green; the feel gate (mouse and taste
  lenses, `ui: true` from the first review); `Mac-Finish: CL-ui` with the
  timing row measured on a release build; `Belt-Slice-Done: CL-ui`.
- **CL-run:** `HaloRenderRunTests` and `walkRenders` green on Linux, `Mutate:
  4/4 HaloModel.HaloRenderJob+Kernel` and `2/2 HaloModel.HaloAvailability+Render`
  in the PR bodies; `Belt-Slice-Done: CL-run`.
- **CL-probe:** `RenderBudgetHaloProbeTests.bodies` green on a scoped run
  containing CL-9; the feel gate; `Mac-Finish: CL-probe`; `Belt-Slice-Done:
  CL-probe`.
- **CL-measure:** H-P1 to H-P5 green with valid series attached, L3 to L5
  green, the `HALO-LATENCY` line in the snapshots artifact, the six flipped
  journeys green; `Belt-Slice-Done: CL-measure`.
- **CL-z:** H-J12 green on the scoped run containing CL-13 with its twelve
  shots; `status: built`; `Belt-Slice-Done: CL-z`, then
  `Belt-Contact-Sheet: <run url>` with one line per journey (H-J12's twelve
  shots, H-J21's sheet states, the five perf attachments) and the audit
  counts.

Beta gate (the cut's §5): H-J12 is Halo's tier-1 chain on the assembled
`AfterGlow.app`; HB-U1 to HB-U5 move from report-only to gating in that run
once ten green runs set their limits.

## Issues this packet files

The lead files these at stage 1 (labels in brackets) and the packet does
not wait on their closing except where a slice says so:

1. **SuiteUI: a public probe recorder for app views** (`needs-ui`,
   `line:suiteui`): an environment value the window's `.suiteProbes()` sets
   (`suiteProbeRecorder`, nil without `-SuitePerfProbe`) with `record(_
   sample: ProbeSample)`, `drew(_ series:at:)` and `mark(_:series:)`, so an
   app's gesture can report input-to-refresh latency; today the probe is a
   private `@State` and nothing under `Sources/` constructs a `ProbeSample`.
   Also `ExportSheet` marking `progress-shown` on its series when its
   progress row first appears (HB-U5, QB-L9). CL-8 waits on the recorder.
2. **SuiteUI ExportSheet: hide the quality row, name the verb, a content
   slot** (`needs-ui`, `line:suiteui`, against editor-kernel EK-30): Halo
   has no quality setting, calls the action Render (D9), and needs a
   destination row and Reveal in Finder inside the sheet. Placeholder rows
   meanwhile; never an app copy of the sheet.
3. **render-out: re-cut RO-3 and RO-8 onto the kernel** (`gap`, `line:halo`,
   `p1`): `HaloRenderJob.swift`'s state machine and `HaloRenderSheet.swift`
   are app-local export logic under rule 20; once EK-run and EK-chrome land,
   RO-3 should write the adapter this packet's CL-2/CL-6 describe and RO-8
   present `ExportSheet`, so core-loop deletes nothing. If render-out builds
   first as written, this packet's CL-4 and CL-6 do the move.
4. **adopt-kernel-export: no Halo slice** (`finding`, `line:suiteui`, note
   only): its packet covers Flare, Photo and Library; Halo's adoption is
   here. One line in that packet's Hand-offs pointing at core-loop.
5. **No creative-core issue.** The run loop stays render-out's
   `HaloRenderRules` on `LiveFrameRendering`; the kernel holds state only.

## Review notes folded in

Where the packet differs from the blueprint, the existing wave data or
render-out:

- **H-J12 is 2 s at 24 fps, not the default 10 s at 30.** The default
  composition's 300 half-size frames take long enough that the Render…
  step's wait would dominate the journey and race XCUITest's idle timer; 48
  frames render in seconds, as `keyed` does in H-J21. The keys are at 0, 24
  and 47 instead of 0, 24 and 299; the rule proved is the same (the
  stopwatch keys the playhead and the last frame).
- **H-J12 gains a text layer and a Render… step.** The beta cut's §5 names
  Halo's chain as comp → keys → ease → play → text → render → reopen; the
  blueprint's row stopped at save. Text uses text-layers' H-J22 steps.
- **Cancel shows no count.** render-out's sheet read "Cancelled after 12
  frames." / "Cancelled. No movie was written."; the kernel's `ExportRun`
  returns to idle on cancel and SuiteUI's sheet closes, so H-J21 asserts the
  sheet is gone and the disk state (PNG frames stay, no `.mp4`), not a text.
  `HaloRenderOutcome.cancelled` stays as the run loop's return value and is
  mapped to idle.
- **The failed text is built by the adapter, not the kernel.** `ExportRun`
  carries a message string; Halo words it ("Render stopped at frame 5: Disk
  full.") when it maps `.failed(frame:message:)`, so the sheet shows
  render-out's sentence unchanged.
- **The stored shape is kept.** `renderJob: HaloRenderJobState?` stays in
  `HaloProject.swift` as W0 wrote it (plan, progress, outcome): the adapter
  projects it to `ExportRun` and routes every change through the kernel's
  transitions, so no foundation file is edited and the plan's size and
  frames keep a home. This is the smaller of the two shapes the review
  weighed; storing the kernel value would mean owning `HaloProject.swift`.
- **#330 and #333 are done,** so the wave data no longer waits on them; the
  real wait for H-P1 to H-P5's latency half is the probe recorder (issue 1
  above), which the old data misnamed as #330.
- **Owned files shrink to what the tasks touch.** The old wave data listed
  every W1 and W2 journey file; +Files, +FileErrors, +Viewer, +Playback,
  +History, +Easing, +Text and +RenderFrame already launch on `-HaloSample`
  and are not edited, so they are not owned. +Render is owned by CL-4 (the
  sheet's identifiers change); +Drag, +Inspector, +Parent and +Layers by
  CL-12 (the flip). `HaloJourneyTests.swift` is owned by CL-12 and CL-13, in
  slices that chain.
- **Cross-line waits are prose.** `scripts/waves` resolves a `waits` key
  against the app's own features, so editor-kernel's slices, the SuiteUI
  `needs-ui` and switching's A-HA-1 are in `waits_on`, the two cells, the
  Slices table and the Hand-offs list, not in the JSON `waits`.
- **The `timing` tests merge disabled.** Only the supervisor edits
  `Tests/perf-suites.txt`; CL-5 and CL-9 ask for their line in the PR body
  and the supervisor's one-line PR enables the test, so a busy runner never
  reds the gate.
