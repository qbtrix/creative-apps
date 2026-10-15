# Feature packet: render-out

**Feature:** Render a frame and render to files. Render Frame (⌘R) renders
the selected composition at the playhead through the live renderer and shows
the pixels inside the artboard, with a note once the frame is out of date.
File > Render… (⇧⌘R) writes every frame to a PNG sequence or an H.264 movie,
off the main actor, with progress, Cancel, Reveal in Finder and a failure
that names the frame.
**Line:** `line:halo` · **Wave:** W2 (`waves.md`) · **Lead branch:** `lead/render-out`

**Covers:** #451 (closes with RO-9), #429 (closes with RO-10). The other
tasks name their part of one of them; they close through those PRs.

**Depends on:** the viewer-playback feature issue (the live renderer:
`LiveFrameDrawing`, `LiveFrameRendering`, and #457's fix so nulls are never
counted as skipped) and #333 (QH-4, journey files). The feature issue is
filed once both are closed, and its one `Depends on:` line names whichever
closed last. Only RO-9 and RO-10 need #333 (`project.yml` compiles only
`UITests/HaloJourneyTests.swift` until it lands), but the issue waits for it
anyway, so the lead can build every task. No creative-core issue: CoreRaster's
`rgba8(colorSpace:)` already exists, and the PNG and movie writers are
app-side (ImageIO, AVFoundation).

Blueprint sections it builds on: 2 (rendering and feel, commands and
availability, launch arguments, fixtures), 4 (H-J20, H-J21), 5
(`FrameRendering`, `RenderSink`, `CompositionRendering`, the render values,
the workspace methods table), 6 (Render sheet row, command table, D9), 7.1
(HB-12, HB-13, HB-U5), 7.4 (HF-7, HF-8), 8.3 (render-out's owned files). The
packet wins over the blueprint and over #451 and #429 where they differ; the
differences are listed under "Review notes folded in".

**Building blind.** RO-5 to RO-10 are in `Sources/HaloApp/`,
`Tests/AppSnapshotTests/` and `UITests/`, which the Linux gate never
compiles; the macOS job compiles them on `dev` after the lane merges. So:
copy the imports and shape of a HaloApp file that already builds
(`NewCompositionSheet.swift` for the sheet; Photo's `ImageIOCodec.swift`
shows ImageIO calls, but HaloApp never imports PhotoApp), check every
SwiftUI, AppKit, ImageIO, CoreVideo and AVFoundation API with the
`apple-docs` MCP before use and say so in the PR, keep views dumb (the
app-state lint), and put every decision that can be pure into RO-1 to RO-4.
One finding from that check already: `AVAssetWriterInputPixelBufferAdaptor`
is deprecated in macOS 26 in favour of
`AVAssetWriter.inputPixelBufferReceiver(for:pixelBufferAttributes:)` (macOS
26+, async). `cancelWriting()` blocks until cancelled and deletes the file it
created. RO-7 reads both pages and picks one; it must not add a warning if
the macOS job treats warnings as errors.

**Shared-file rule.** This feature owns only the Halo files in its task rows.
It never edits `Sources/SuiteUI/**`, `project.yml`, `UITests/Journey*.swift`,
`UITests/Journey+Input.swift`, `Tests/AppSnapshotTests/AppSnapshotTests.swift`,
`docs/c4/model.json` or `docs/design.md`, nor foundation's `HaloViewer.swift`,
`HaloWindow.swift`, `HaloCommands.swift`, `HaloFileMenu.swift`,
`HaloProject.swift`, `HaloCommand.swift`, `HaloViewerState.swift` or
`HaloCommandTests.swift`. The menu items (File > Render… ⇧⌘R, Render Frame ⌘R,
D9) already exist from FD-16 and turn on through the availability file; the
route exists from FD-14 and lands in `HaloWindow+Render.swift`. Viewer-playback's
`FrameRenderer.swift` (`HaloRenderedFrame`, its `note`) is read, never edited.
No other W2 feature (easing, text-layers) owns any file below.

## Journey steps

1. **H-J20** `testRenderFrame` (`UITests/HaloJourneyTests+RenderFrame.swift`,
   new class) on `-HaloSample parented`: scrub to 12; ⌘R; the viewer shows
   `halo.viewer.rendered`, its value "Rendered frame 12 at 480 × 270", and no
   `halo.viewer.renderedNote` (Rig is a null and is not counted as skipped:
   #457, fixed by viewer-playback); scrub to 13: the note reads "Rendered
   frame is out of date."; scrub back to 12: the note is gone; scrub to 13
   and ⌘R: the value reads "Rendered frame 13 at 480 × 270" and the note is
   gone. (RO-9)
2. **H-J21** `testRenderPNGSequence` (`UITests/HaloJourneyTests+Render.swift`,
   new class) on `-HaloSample keyed -HaloRenderTo <tmp>`: File > Render…; pick
   PNG sequence and Half; the summary reads "48 PNG files, 960 × 540, into a
   new folder "Bounce""; Render; the progress row reads "Frame n of 48";
   success reads "Rendered 48 frames." with Reveal in Finder; the test lists
   `<tmp>/Bounce/`: exactly 48 files `Bounce_0001.png` … `Bounce_0048.png`,
   each 960 × 540 (read with ImageIO in the test). Then quit and relaunch on
   `-HaloSample reference -HaloRenderTo <tmp>` (300 frames of 50 keyed
   layers, so the movie can't finish before the click lands); Render…,
   Movie, Full, Render, and Cancel as soon as the progress row shows "Frame
   n of 300": the result reads "Cancelled. No movie was written." and
   `<tmp>` holds no `.mp4`. (RO-10)

Both run on `-HaloSample`: the live renderer exists (viewer-playback) and
RO-1 lands `LiveCompositionRendering` before either journey. The Model half
of every step runs on Linux first: `HaloRenderFrameTests` and
`HaloRenderJobTests`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Viewer, rendered frame | no rendered frame, or one from another composition, or playback running: the vector drawing as before (`shownRenderedFrame == nil`) | a render that throws leaves no rendered frame and the vectors show; on a valid composition it cannot throw (sizes are bounded by `CompositionSettings`) | none: Render Frame at 480 × 270 is synchronous (HB-12, ≤ 50 ms) |
| Rendered-frame note | not stale and nothing skipped: no note | stale: "Rendered frame is out of date."; a text layer with no rasterizer: `HaloRenderedFrame.note` (viewer-playback's wording) | none |
| Render sheet, settings | Format (PNG sequence, Movie), Size (Full, Half), destination (the `-HaloRenderTo` folder, else a folder picker), the summary line, Render; Render disabled with no destination | a plan that throws: the failure row with its message | none |
| Render sheet, running | – | – | "Frame 12 of 48" with a determinate `ProgressView` and Cancel; shown the moment Render is pressed ("Frame 0 of 48"), QB-L9 |
| Render sheet, result | – | "Render stopped at frame 5: <reason>." and Close | "Rendered 48 frames." with Reveal in Finder and Close; "Cancelled after 12 frames." (PNG, the files stay); "Cancelled. No movie was written." (movie) |
| Menus | no composition: Render Frame and Render… disabled with "Create a composition first." | Render… while a render runs: "A render is already running." | none |

## Contract slice

No contract changes. `FrameRendering`, `RenderSink`, `CompositionRendering`,
`HaloRenderSettings`, `HaloRenderPlan` and `HaloRenderOutcome` are W0's,
copied from `docs/blueprints/halo/contracts/`. W0 stores
`renderedFrame: HaloShownFrame?` and `renderJob: HaloRenderJobState?`
(settings, plan, progress, outcome); this feature writes them only from its
two files and adds:

```swift
// HaloRenderFrame.swift (RO-2)
extension HaloProject {
    public mutating func renderCurrentFrame()                 // services.rendering at a quarter size, with services.text
    public var renderedFrameStale: Bool { get }                // computed; no stored flag
    public var shownRenderedFrame: HaloRenderedFrame? { get }  // nil for another composition or while playing
    public var renderedFrameNote: String? { get }              // stale text, else frame.note
    public var renderedFrameSummary: String? { get }           // "Rendered frame 12 at 480 × 270"
}

// HaloRenderJob.swift (RO-3)
extension HaloProject {
    public mutating func openRenderSheet()                      // renderJob = settings only (plan nil)
    public mutating func closeRenderSheet()                     // refused while running
    public func renderSummary(_ settings: HaloRenderSettings, existing: Set<String>) -> String?
    public func renderOutputName(_ settings: HaloRenderSettings, existing: Set<String>) -> String?  // "Bounce", "Bounce 2", "Bounce.mp4"
    public mutating func startRender(_ settings: HaloRenderSettings) -> (plan: HaloRenderPlan, composition: HaloComposition)?
    public mutating func renderProgress(frame: Int)             // frames written so far
    public mutating func cancelRender()
    public mutating func finishRender(_ outcome: HaloRenderOutcome)
    public var renderProgressText: String? { get }              // "Frame 48 of 240"
    public var renderOutcomeText: String? { get }
}

// Live/HaloRenderRules.swift (RO-1), internal: the plan rule and the frame
// loop, shared by FakeCompositionRendering and LiveCompositionRendering so
// the duplicate gate never sees two copies.
enum HaloRenderRules {
    static func plan(_ c: HaloComposition, _ s: HaloRenderSettings) throws -> HaloRenderPlan
    static func run(_ plan: HaloRenderPlan, of c: HaloComposition, text: (any TextRasterizing)?,
                    drawing: any FrameDrawing, rendering: any FrameRendering,
                    into sink: inout some RenderSink, isCancelled: () -> Bool) -> HaloRenderOutcome
}
```

App side: `HaloFrameImage.cgImage(_ frame: HaloRenderedFrame) -> CGImage?`
from `frame.pixels.rgba8(colorSpace:)` (sRGB, straight alpha, so
`CGImageAlphaInfo.last`; no local converter); `HaloPNGWriter: RenderSink`
(folder URL; one PNG per frame through `CGImageDestination`);
`HaloMovieWriter: RenderSink` (file URL; H.264 `.mp4` at the plan's size
and fps; `finish(cancelled: true)` cancels and removes the file).

## Pseudocode

```
renderCurrentFrame():                                    # RO-2; not an edit, records no undo
  guard let comp = selectedComposition else return
  let list = services.drawing.drawList(comp, at: comp.playheadFrame)   # the document, not the drag preview
  let w = max(1, comp.width / 4), h = max(1, comp.height / 4)          # 480 × 270 for 1080p
  renderedFrame = (try? services.rendering.render(list, width: w, height: h, text: services.text))
                    .map { HaloShownFrame(frame: $0, source: comp) }

renderedFrameStale = renderedFrame.map { $0.source != selectedComposition } ?? false
  # the playhead lives in HaloComposition, so a scrub, a tick or any edit makes it stale;
  # scrubbing back or undoing to the same composition makes it fresh again
shownRenderedFrame = renderedFrame where source.id == selectedCompositionID && !playback.playing
renderedFrameNote  = shownRenderedFrame == nil ? nil
                   : renderedFrameStale ? "Rendered frame is out of date." : frame.note

HaloRenderRules.plan(c, s):                              # RO-1
  guard c.durationFrames > 0 else throw .noComposition
  even = { max(2, $0 / 2 * 2) }
  (w, h) = s.halfSize ? (even(c.width / 2), even(c.height / 2))
         : s.format == .movie ? (even(c.width), even(c.height)) : (c.width, c.height)
  base = c.name with "/" and ":" replaced by "-"
  names = movie ? ["\(base).mp4"] : frames.map { "\(base)_\(pad4(f + 1)).png" }

HaloRenderRules.run(...):                                # RO-1
  try sink.begin(plan) else .failed(frame: plan.frames.first ?? 0, msg)
  for (i, f) in plan.frames.enumerated():
    if isCancelled() { try? sink.finish(cancelled: true); return .cancelled(frames: i) }
    do { image = try rendering.render(drawing.drawList(c, at: f), plan.width, plan.height, text)
         try sink.write(image, named: name(i)) }
    catch { try? sink.finish(cancelled: true); return .failed(frame: f, message: words(error)) }
  try sink.finish(cancelled: false) else .failed(frame: last, msg)
  return .finished(frames: plan.frames.count)
  words(e) = (e as? HaloEditError)?.message ?? (e as? CustomStringConvertible)?.description ?? "\(e)"

startRender(s):                                          # RO-3
  guard let comp = selectedComposition, renderJob?.plan == nil || renderJob?.outcome != nil else nil
  do { plan = try services.compositionRendering.plan(comp, settings: s) }
  catch { renderJob = .init(settings: s, plan: nil, progress: 0,
            outcome: .failed(frame: 0, message: (error as? HaloEditError)?.message ?? "\(error)")); return nil }
                                                         # its own wording; never calls HaloRenderRules (RO-1)
  renderJob = .init(settings: s, plan: plan, progress: 0, outcome: nil)   # "Frame 0 of 48" at once
  return (plan, comp)
renderProgress(n):  only while running and outcome == nil; progress = min(max(progress, n), plan.frames.count)
cancelRender():     running -> outcome = .cancelled(frames: progress); not started -> closeRenderSheet()
finishRender(o):    running and outcome == nil -> outcome = o
                    after cancelRender -> only a .cancelled or .failed replaces it (the exact count)

HaloWindow+Render.swift, Render… (RO-8):
  guard let (plan, comp) = model.startRender(settings) else return
  let services = model.services; let folder = destination
  task = Task.detached {                                 # off the main actor
    var sink = Progress(base: format == .movie ? HaloMovieWriter(url) : HaloPNGWriter(folder),
                        onWrite: { n in Task { @MainActor in model.renderProgress(frame: n) } })
    let outcome = services.compositionRendering.run(plan, of: comp, text: services.text,
                                                    into: &sink, isCancelled: { Task.isCancelled })
    await MainActor.run { model.finishRender(outcome) } }
  Cancel: model.cancelRender(); task.cancel()           # the sheet holds `task` in its own @State
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: render-out`, `Fast-Check:
pass`, `Head:`. RO-10 also carries `feature-done`. Sizes are estimates.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| RO-1 | #429 (part) | `HaloRenderRules` (plan: half size even and at least 2, movie sizes even at full size, names sanitized; the frame loop with cancel and sink errors); `LiveCompositionRendering` runs it on `LiveFrameDrawing` and `LiveFrameRendering` with `unavailableHelp == nil`; `FakeCompositionRendering` becomes a thin wrapper over the rules on the fakes; the contract suite runs over `[fake, live]` | `Sources/HaloModel/Live/HaloRenderRules.swift`, `Sources/HaloModel/Live/LiveCompositionRendering.swift`, `Sources/HaloModel/Fakes/FakeCompositionRendering.swift`, `Tests/HaloModelTests/CompositionRenderingContractTests.swift`, `Tests/HaloModelTests/HaloRenderPlanTests.swift` | – | ~330 |
| RO-2 | #451 (part) | `renderCurrentFrame`, the computed `renderedFrameStale`, `shownRenderedFrame`, `renderedFrameNote`, `renderedFrameSummary` | `Sources/HaloModel/HaloRenderFrame.swift`, `Tests/HaloModelTests/HaloRenderFrameTests.swift` | – | ~220 |
| RO-3 | #429 (part) | The render job: open and close the sheet, `renderSummary`, `renderOutputName`, `startRender`, `renderProgress`, `cancelRender`, `finishRender`, the progress and outcome texts | `Sources/HaloModel/HaloRenderJob.swift`, `Tests/HaloModelTests/HaloRenderJobTests.swift` | – | ~330 |
| RO-4 | #451 (part), #429 (part) | `HaloAvailability+Render.swift` answers state (no composition; a render running) then the services' own help, so both commands turn on; HB-12 and HB-13 report-only | `Sources/HaloModel/Availability/HaloAvailability+Render.swift`, `Tests/HaloModelTests/HaloRenderAvailabilityTests.swift`, `Tests/HaloModelTests/HaloRenderBudgetTests.swift` | RO-1, RO-3 | ~180 |
| RO-5 | #451 (part) | App: `HaloFrameImage` (CGImage from `rgba8(colorSpace:)`); `HaloRenderedFrameView` replaces the W0 stub (the image fills the artboard, identifier `halo.viewer.rendered` with `renderedFrameSummary` as its value; the note under it as `halo.viewer.renderedNote`); Render Frame's route calls `renderCurrentFrame()`; snapshots | `Sources/HaloApp/HaloFrameImage.swift`, `Sources/HaloApp/HaloRenderedFrameView.swift`, `Sources/HaloApp/HaloWindow+Render.swift`, `Tests/AppSnapshotTests/HaloRenderSnapshots.swift` | RO-2 | ~200 |
| RO-6 | #429 (part) | `HaloPNGWriter`: `begin` makes the folder (refuses an existing file there), `write` writes one PNG per frame, `finish` keeps written frames; HF-7 | `Sources/HaloApp/HaloPNGWriter.swift`, `Tests/AppSnapshotTests/HaloPNGWriterTests.swift` | RO-1, RO-5 | ~190 |
| RO-7 | #429 (part) | `HaloMovieWriter`: H.264 `.mp4` at the plan's size and fps, BT.709 color tagged, frame i at `CMTime(value: i, timescale: fps)`, the session ended at `frames / fps`; transparent areas become black; `finish(cancelled: true)` cancels and removes the file; HF-8 | `Sources/HaloApp/HaloMovieWriter.swift`, `Tests/AppSnapshotTests/HaloMovieWriterTests.swift` | RO-6 | ~300 |
| RO-8 | #429 (part) | `HaloRenderSheet` (system `Form`, `Picker(.segmented)` for format and size, destination from `-HaloRenderTo` or a folder picker, the summary, Render; progress row with Cancel; result with Reveal in Finder or the failure; Close); Render…'s route opens it; the detached run with a progress sink in `HaloWindow+Render.swift`; the sheet is presented from the `renderScene(_:)` hook while `renderJob != nil`; snapshots | `Sources/HaloApp/HaloRenderSheet.swift`, `Sources/HaloApp/HaloWindow+Render.swift`, `Tests/AppSnapshotTests/HaloRenderSheetSnapshots.swift` | RO-3, RO-5, RO-6, RO-7 | ~370 |
| RO-9 | #451 (closes) | Journey H-J20 on `-HaloSample parented` | `UITests/HaloJourneyTests+RenderFrame.swift` | RO-4, RO-5, #333 | ~120 |
| RO-10 | #429 (closes), `feature-done` | Journey H-J21: PNG sequence half size on `-HaloSample keyed -HaloRenderTo <tmp>`, then a cancelled movie on a relaunch with `-HaloSample reference` | `UITests/HaloJourneyTests+Render.swift` | RO-4, RO-8, #333 | ~180 |

RO-1, RO-2 and RO-3 share no file and build together. RO-3 codes against
W0's `FakeCompositionRendering`, whose plan already gives `keyed` half
960 × 540, so it doesn't wait for RO-1. RO-3 words a plan error itself
with `(error as? HaloEditError)?.message ?? "\(error)"` and never calls
`HaloRenderRules`, which is RO-1's file. RO-4 needs RO-1 (the live help is
nil) and RO-3 (a render running); RO-5 needs only RO-2's
`renderCurrentFrame()`. Both journeys need RO-4, since the commands stay
disabled until then. `HaloWindow+Render.swift` (RO-5 and RO-8) is shared only
by tasks that chain. No task edits a shared doc (`docs/c4/model.json`,
`docs/design.md`, the blueprint, `waves.md`), so RO-10, the `feature-done`
task, stays the final task and adds no docs edit.
`Tests/HaloModelTests/HaloRenderAvailabilityTests.swift` and
`HaloRenderJobTests.swift` are new files beyond the blueprint's 8.3 list;
`Sources/HaloModel/Live/HaloRenderRules.swift` and
`Sources/HaloModel/Fakes/FakeCompositionRendering.swift` are the shared-rule
helper and fake the brief allows.

**The sheet's seam.** Foundation's FD-14 gives every area file a window
hook, so `HaloWindow+Render.swift` defines `renderScene(_:)`, which
`HaloWindow.body` applies; RO-8 attaches the Render sheet there with
`.sheet(isPresented:)` while `renderJob != nil`. The `isPresented` binding
is built from `renderJob != nil` and `closeRenderSheet()`, never from
`$model`. `HaloRenderedFrameView` stays only the image and its note.

**Availability and `HaloCommandTests`.** W0's `HaloCommandTests` checks only
the invariant (enabled, or disabled with help) and the shipped commands, so
RO-4 never edits it; its own `HaloRenderAvailabilityTests` asserts Render
Frame and Render… turn on.

## Build waves

- Wave 1: RO-1, RO-2, RO-3. Independent in this wave: all three.
- Wave 2: RO-4, RO-5. Independent in this wave: both.
- Wave 3: RO-6, RO-9. Independent in this wave: both.
- Wave 4: RO-7. Independent in this wave: RO-7 alone.
- Wave 5: RO-8. Independent in this wave: RO-8 alone.
- Wave 6: RO-10 (final, `feature-done`; also waits on #333). RO-9 merged in
  wave 3, so the `feature-done` run holds both journeys.

Longest chain: RO-2 → RO-5 → RO-6 → RO-7 → RO-8 → RO-10 (6).
Chain of 6: RO-5's route calls RO-2's `renderCurrentFrame()`, RO-6's
`HaloPNGWriter` writes through RO-5's `HaloFrameImage`, RO-7's test compares
against RO-6's PNG frame 0, RO-8's run builds RO-7's `HaloMovieWriter` and
edits RO-5's `HaloWindow+Render.swift`, and RO-10's H-J21 drives RO-8's sheet.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| RO-1 | `HaloRenderPlanTests` on `.live` and `.fake`: a 2 s, 24 fps composition "Intro" sends 48 frames in order, names `Intro_0001.png` … `Intro_0048.png`; `keyed` half gives 960 × 540; 1081 × 721 gives Half 540 × 360, Movie Full 1080 × 720, PNG Full 1081 × 721; 3 × 3 Half gives 2 × 2; a movie plan has one name "Bounce.mp4"; "A/B" gives `A-B_0001.png`; `isCancelled` true once 10 frames are written gives `.cancelled(frames: 10)`, 10 writes and one `finish(cancelled: true)`; a sink throwing `HaloEditError.notBuilt("x")` at frame 5 gives `.failed(frame: 5, message: HaloEditError.notBuilt("x").message)` and no write after it; `CompositionRenderingContractTests` passes on `[fake, live]` (`fakeRenderRunsEveryFrameAtThePlanSize` included) and `HaloServices.live.compositionRendering.unavailableHelp == nil` | a frame is skipped, mis-sized, misnamed or written after cancel or an error; a movie gets an odd size; or the live type is still the stub |
| RO-2 | `HaloRenderFrameTests` on `parented` (`.fake`): at 12, `renderCurrentFrame()` gives a 480 × 270 frame 12, `renderedFrameSummary` "Rendered frame 12 at 480 × 270", no note, `history.undo` unchanged; scrub 12 → 13: stale, note "Rendered frame is out of date."; scrub back to 12 with no edit: not stale, no note; a Position X edit on Ball (or New Layer, whichever W1 method exists): stale; ⌘R again: not stale. On `two-comps`: render Intro, select Outro: `shownRenderedFrame == nil`; back to Intro: shown, not stale. Playing hides it. On `three-layers` at 30 with `services.text = nil`: the note equals `renderedFrame.frame.note` and is non-nil; with the fake rasterizer: nil | staleness misses a scrub or an edit, sticks after scrubbing back, a stale note hides, a frame from another composition shows, or Render Frame records an undo step |
| RO-3 | `HaloRenderJobTests` on `keyed` (`.fake`): `openRenderSheet` sets settings and no plan; `startRender(.pngSequence, half)` returns 48 frames at 960 × 540 and the progress text reads "Frame 0 of 48" at once; `renderProgress(frame: 12)` → "Frame 12 of 48", then 11 leaves 12, 99 caps at 48; `finishRender(.finished(frames: 48))` → "Rendered 48 frames."; `cancelRender()` at 12 → "Cancelled after 12 frames." and a late `renderProgress(frame: 13)` changes nothing, a following `.cancelled(frames: 13)` → "Cancelled after 13 frames."; a movie cancel → "Cancelled. No movie was written."; `.failed(frame: 5, message: "Disk full")` → "Render stopped at frame 5: Disk full."; a second `startRender` while running returns nil; `closeRenderSheet` while running keeps the job; `renderOutputName` gives "Bounce", then "Bounce 2" with "Bounce" existing, and "Bounce.mp4" / "Bounce 2.mp4"; `renderSummary` reads "48 PNG files, 960 × 540, into a new folder "Bounce"" and "One movie, 1920 × 1080, 24 fps, "Bounce.mp4"" | a text is wrong, progress goes back or past the end, a late hop moves a cancelled job, two renders start, or a name collides |
| RO-4 | `HaloRenderAvailabilityTests`: on `HaloProject(services: .fake)` with no composition both commands read "Create a composition first."; on `keyed` both are nil (enabled) on `.fake` and on `.live`; while a render runs Render… reads "A render is already running." and Render Frame stays enabled; with a stub `CompositionRendering` whose help is "x", Render… reads "x". `HaloRenderBudgetTests.renderPreview` (HB-12) and `.renderSequence` (HB-13) record their numbers and fail only on too few samples | a command turns on with no composition, stays off when it can act, or a second render can start |
| RO-5 | Snapshots `halo-rendered-frame-light.png`, `halo-rendered-frame-dark.png` (`HaloViewer(model:)` on a `HaloProject(services: .fake)` loaded with the `keyed` fixture, at 12 after `renderCurrentFrame()`: Ball over Floor; `HaloViewer(model:)` alone would default to live services) and `halo-rendered-frame-stale-light/dark.png` (after a scrub to 13: the note) | the image is missing, mis-placed in the artboard, or the stale note doesn't show |
| RO-6 | `HaloPNGWriterTests` (macOS, HF-7): `keyed` half through `LiveCompositionRendering` into `HaloPNGWriter`: `Bounce_0007.png` decoded with `CGImageSource` (bytes read from the image's data provider row by row, not drawn into a context, which would premultiply) equals `render` of frame 6 at 960 × 540 as `rgba8(colorSpace:)` byte for byte; a 40 × 20 composition with one 50% opaque solid over nothing round-trips its straight alpha (128) exactly; `begin` on a path that is a file throws | a byte differs, alpha is premultiplied or dropped, or a frame is written over a file |
| RO-7 | `HaloMovieWriterTests` (macOS, HF-8): `keyed` full as a movie: `AVURLAsset` loads duration exactly 2 s (48/24) and an `AVAssetReader` counts 48 video samples; frame 0 decoded is within 4/255 per channel of the PNG writer's frame 0 on at least 99% of pixels; `finish(cancelled: true)` after 3 frames leaves no file at the URL | a frame is dropped or doubled, duration drifts, colors are off beyond tolerance, or a partial movie stays |
| RO-8 | Snapshots `halo-render-sheet-light/dark.png` (settings, PNG, Half, summary), `halo-render-sheet-progress-light/dark.png` (`keyed` at "Frame 12 of 48" with Cancel), `halo-render-sheet-done-light/dark.png` (Reveal in Finder), `halo-render-sheet-failed-light/dark.png` ("Render stopped at frame 5: Disk full."); each state set through the Model's public methods | a state is missing a control, Render is enabled with no destination, or a view assigns Model state (app-state lint) |
| RO-9 | H-J20 on the `dev` CI run | any step's assert, including a skipped-layer note for Rig |
| RO-10 | H-J21 on the `dev` CI run: 48 files with exact names at 960 × 540 on `keyed`; no `.mp4` after Cancel on `reference` | a file is missing, extra, mis-sized or misnamed, or a partial movie stays |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-12 Render Frame | `FrameRendering.render` at 480 × 270 on `reference` ≤ 50 ms release; report-only | `HaloRenderBudgetTests.renderPreview` (RO-4) |
| HB-13 Render… | 48 frames at 1920 × 1080 into a counting sink on `keyed` < 5 s release; report-only, then < 10 s | `HaloRenderBudgetTests.renderSequence` (RO-4) |
| HB-U5 / QB-L9 progress within 100 ms | Model half: `startRender` sets "Frame 0 of 48" before any frame renders; UI half report-only until #330 | `HaloRenderJobTests.progressShowsAtOnce` (RO-3); H-J21's shot after Render (RO-10) |
| HF-7 PNG equals the render | exact bytes | `HaloPNGWriterTests` (RO-6) |
| HF-8 movie | frame count and duration exact; frame 0 within 4/255 on ≥ 99% of pixels | `HaloMovieWriterTests` (RO-7) |
| QB-V4 what you see is what you export | Render Frame and Render… both go through `services.rendering` on the same draw list | `HaloRenderPlanTests` (RO-1: the live run calls `LiveFrameRendering`), HF-7 |
| QB-F1 no dead controls | both commands enabled or disabled with help | `HaloRenderAvailabilityTests` (RO-4) |
| Audit | no `halo` count over baseline; every new control has a `halo.render.*` identifier through `.haloControl` | `audit-halo-*.json` on the `feature-done` run |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by RO-10's
  `feature-done` PR is green, with H-J20 and H-J21 passing and every other
  Halo and app journey unchanged.
- **Audit zero new:** no `halo` count over `UITests/audit-baseline.json`
  (the sheet's pickers and buttons carry identifiers and labels).
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per journey and the audit
  counts. Expected new shots: H-J20's rendered and stale frames, H-J21's
  sheet in settings, progress, success and cancelled states.

## Review notes folded in

From the review of the blueprint PR (#767) and the packet brief:

- **`renderedFrameStale` is computed, not stored.** The blueprint's stored
  `renderedFrameStale: Bool` "written only by `HaloRenderFrame.swift`" could
  never flip on a scrub, tick or edit, which live in other features' files.
  W0 stores `renderedFrame: HaloShownFrame?` (frame and source composition);
  `HaloRenderFrame.swift` computes `renderedFrame.map { $0.source !=
  selectedComposition } ?? false`. RO-2's test covers scrub, scrub back,
  edit and render again.
- **#457 is viewer-playback's.** This feature only proves it in H-J20 (no
  note for Rig on `parented`); `FrameRenderer.swift` is not touched.

Where the packet differs from the blueprint or the issue bodies:

- **#451** names `renderSelectedFrame(at:)`; the packet renders through
  `renderCurrentFrame()` on `services.rendering` at the playhead, with
  `services.text`. `renderSelectedFrame` stays viewer-playback's.
- **#429** names `HaloRenderPlan.swift`, puts both sinks in
  `HaloMovieWriter.swift`, edits `HaloCommands.swift` and extends
  `HaloJourneyTests.swift`. The packet uses the W0 contracts (the plan rule in
  `Live/HaloRenderRules.swift`), one file per sink, the existing W0 menu items
  and route, and `HaloJourneyTests+Render.swift`. Its snapshot names
  `halo-render-light/dark.png` become `halo-render-sheet-progress-light/dark.png`
  (the blueprint's golden name) plus the other sheet states.
- **#429's skipped-layer note** in files: with viewer-playback's live
  renderer only a text item it can't draw is skipped ("1 text layer not
  drawn."), and HaloLaunch always sets a rasterizer, so the sheet shows no
  note; Render Frame shows `HaloRenderedFrame.note` when there is one.
- **Movie sizes.** The blueprint rounds to even only at half size; H.264
  needs even sizes at full size too, so a movie plan rounds both down to
  even; a PNG sequence keeps the exact size.
- **File names.** A composition name may hold "/" or ":", which a file name
  can't; the plan replaces both with "-". PNG frames go into a new folder
  named after the composition ("Bounce", then "Bounce 2"), as #429 asks.
- **Cancel races on a short movie.** `keyed`'s 48 frames can finish before
  XCUITest clicks Cancel, so H-J21's cancel step relaunches on `reference`
  (300 frames); the PNG step stays on `keyed`.
- **RO-5's snapshot services.** It builds `HaloProject(services: .fake)`
  with the `keyed` fixture, since a bare model defaults to live services.
- **Cancel.** The run stops before the next frame; the frame being written
  finishes. PNG frames already written stay; a movie is removed.
