# Feature packet: viewer-playback

**Feature:** See and play the composition. The viewer paints the draw list
at the playhead in one SwiftUI `Canvas` (solids, shapes and text as vectors,
each at its matrix, opacity and blend mode); `LiveFrameRendering` turns the
same list into CoreRaster pixels, text included; play, pause, loop, step and
go to start or end run on `PlaybackClock` from a display link; the transport
sits in the status row. It replaces the W0 stubs for drawing, the clock and
the renderer, and turns on the playback commands.
**Line:** `line:halo` · **Wave:** W1 (`waves.md`) · **Lead branch:** `lead/viewer-playback`

**Status (2026-10-15):** built on `dev`, in the lead's Anatomy loop. VP-1
to VP-12 merged (#1090, #1072, #1087, #1069, #1098, #1111, #1101, #1085,
#1099, #1125, #1097, #1102, #1124). The `feature-done` run on #1124's head
never reached the journeys: AppSnapshotTests didn't compile
(`HaloPlaybackDriverTests`' untyped `lazy var`, a circular reference), fixed
by #1136. Then the macOS test run: the driver runs on an injected link with
a fake one in tests (#1145); HF-1 renders off the main actor (#1160);
half-opaque layers mix in linear light on the canvas, as in the render
(#1163, closes #1161); the driver suite's limit covers main-actor queueing
(#1171, #1155).

**Covers:** #37, #457. #457 closes with VP-4b; #37 closes with VP-12, the
`feature-done` PR. The other tasks say "Part of #37" or "Part of the
viewer-playback feature".

**Depends on:** the foundation feature issue #777, and SuiteUI #333 (QH-4,
journey files: `project.yml` compiles only `UITests/HaloJourneyTests.swift`
today, so `UITests/HaloJourneyTests+Viewer.swift` and `+Playback.swift`
would not even compile before it). The feature issue is filed once both are
closed, and its one `Depends on:` line names whichever closed last. Only
VP-12 needs #333; every Model and view task, and VP-11 (H-J3 lives in
`HaloJourneyTests.swift`, which is compiled today), could build without it,
but the issue waits for both so the lead can build every task. No
creative-core wait: on 2026-10-14 creative-core `main` (cfad97f) has no
`Sources/FlareCore/PathBuilders.swift`, so `Path.ellipse(in:)` (creative-core
#182, closed by #281, on core `dev` only) is not usable from this repo, which
tracks `main`. Shapes use CoreRaster's `Mask.ellipse` when axis-aligned and
the four-cubic stopgap otherwise (VP-4a). SuiteUI #340 (TransportCapsule) is
not a wait: plain SF Symbol buttons stand in.

Blueprint sections it builds on: 2 (rendering and feel, coordinates, one
undo step, commands and availability, launch arguments, fixtures), 4 (H-J2,
H-J3, H-J4), 5 (`FrameDrawing`, `PlaybackClock`, `FrameRendering`,
`TextRasterizing`, the `HaloPlayback.swift` row of the workspace table), 6
(viewer, status row, command table), 7.1 (HB-2, HB-5, HB-11), 7.4 (HF-1,
HF-2), 8.3 (owned files). The packet wins over the blueprint and over #37's
body where they differ; the differences are under "Review notes folded in".

**Building blind.** VP-8 to VP-12 are in `Sources/HaloApp/`,
`Tests/AppSnapshotTests/` and `UITests/`, which the Linux gate never
compiles. Copy the shape of a view that builds: `DesignCanvasMarks.swift`
for a `Canvas` that draws text, Flare's `StagePath.swift` for document
colors as `CGColor(srgbRed:green:blue:alpha:)` (the design lint fails on
`Color(red:)` and `Color(.sRGB…)`; a variable font size passes, a literal
`.system(size: 12)` does not), Flare's `PlaybackDriver.swift` for the
display link. Write the Halo driver yourself to that shape; copying its text
trips the duplicate gate. Check `Canvas`, `GraphicsContext.blendMode`,
`drawingGroup(opaque:colorMode:)`, `ImageRenderer`,
`NSScreen.displayLink(target:selector:)`, `CADisplayLink.targetTimestamp`
and `CACurrentMediaTime` with the `apple-docs` MCP and say so in the PR.
Every decision that can be pure is in VP-1 to VP-7.

**Shared-file rule.** This feature owns only the files in its task rows. It
never edits `Sources/SuiteUI/**`, `project.yml`, `UITests/Journey*.swift`,
`UITests/Journey+Input.swift`, `Tests/AppSnapshotTests/AppSnapshotTests.swift`,
`docs/c4/model.json`, `docs/design.md`, or W0's `HaloViewer.swift`,
`HaloWindow.swift`, `HaloCommands.swift`, the menu files, `HaloProject.swift`,
`HaloCommand.swift`, `HaloViewerState.swift` and `HaloTimeline.swift`; it
fills the slots W0 left (the canvas, the transport, `HaloWindow+Viewer`,
`HaloWindow+Playback`, the playback availability file). Beyond 8.3's list it
adds `Live/HaloDrawRules.swift`, `Live/HaloOutlines.swift`,
`Live/HaloTextPlacement.swift` (helpers next to its live types), the two
fakes it turns into thin wrappers (`FakeFrameDrawing`, `FakePlaybackClock`),
and four new test files. `FakeLayerPlacing` stays layer-keys'.

## Journey steps

1. **H-J2** `testLayersDrawAtThePlayhead` (`+Viewer`, new) on `-HaloSample
   three-layers`: scrub to 12; scrub to 30; Layer > New > Solid. The
   artboard value reads "Frame 12: Background, Badge", then "Frame 30:
   Background, Badge, Title: Hello Halo", then "Frame 30: Background, Badge,
   Title: Hello Halo, Solid 2", and the layer list's first row is "Solid 2".
   Because `viewerSummary` reads the layers, not the drawing, the canvas's own
   value proves the live drawing: `halo.viewer.canvas` reads "2 layers
   drawn", "3 layers drawn", then "4 layers drawn". (VP-12)
2. **H-J3** `testScrubTheTimeline` (`HaloJourneyTests.swift`, shipped,
   extended; the blueprint calls it `testScrubAndSetInOutPoints`, and the
   shipped name stays) on `-HaloSample three-layers`: click Badge's lane;
   Home, then → 20 times; I; → 30 times; O; → 10 times. The status timecode
   (matched by prefix) reads "00:00:00:20", then "00:00:02:02"; the inspector
   header for Badge reads "Frames 20–50" (W0's `selectedLayerHeader`:
   outFrame is exclusive, so O at 50 stores 51 and the header reads
   in…out−1; lanes don't name spans until #772);
   at 60 the artboard value is "Frame 60: Background, Title: Hello Halo".
   The shipped timeline drag stays as its first step. (VP-11)
3. **H-J4** `testPlayPauseLoopAndStep` (`+Playback`, new) on `-HaloSample
   three-layers`: Space; wait 1 s; Space; ← twice; Animation > Go to End;
   click Loop; Animation > Go to Start; Space; wait 4 s. `halo.transport.play`
   reads "Playing" then "Paused"; the paused frame f is in 2…71 (the
   journey fails with a message if not); after ← ← the timecode is f − 2
   (stepping back never hits the clamp, whatever f the 1 s wait gives); at
   the end "00:00:02:23"; Loop reads "Off"; after
   4 s playback has stopped on "00:00:02:23" and the button reads "Paused".
   (VP-12)

The Model half runs on Linux first: `FrameDrawingContractTests` (H-J2's
lists), `HaloPlaybackTests` (H-J4's frames, on `.fake` and `.live`) and
`HaloPlaybackAvailabilityTests`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Viewer canvas | no layer in its span at the playhead (or none at all): the artboard background only; canvas value "No layers drawn"; artboard value "Frame n: no layers" | none: an item whose outline is degenerate or not finite draws nothing (the canvas and the renderer both skip it) | none |
| Transport (status row) | no composition: no status row (the empty state shows); Animation menu items disabled with "Create a composition first." | none | none; while playing, Play reads "Playing" and shows the pause symbol |
| Rendered frame note (data only; render-out shows it in W2) | nothing skipped: `note` is nil, nulls never count (#457) | a text item the renderer couldn't draw (no rasterizer, a mirrored matrix, a size CoreRaster refuses): "1 text layer not drawn." / "n text layers not drawn." | none |

## Contract slice

No protocol changes. What the feature adds (contracts in
`docs/blueprints/halo/contracts/Contracts/HaloContracts.swift`):

```swift
// Live/HaloDrawRules.swift (VP-1): the one draw-list rule, shared by fake and live.
enum HaloDrawRules {
    /// Bottom first; nulls and out-of-span layers left out. A nil matrix or
    /// opacity from `placing` falls back to identity and `layer.opacity`.
    static func drawList(_ c: HaloComposition, at frame: Int, placing: any LayerPlacing) -> HaloDrawList
}
extension HaloDrawList {
    public var drawnSummary: String                        // "3 layers drawn", "1 layer drawn", "No layers drawn"
    public func worldBox(of layerID: String) -> HaloLayerRect?   // axis-aligned box of the 4 transformed corners
}
public struct LiveFrameDrawing: FrameDrawing {             // unavailableHelp nil
    public init(placing: any LayerPlacing = LiveLayerPlacing())  // never a fake (a live type never creates one)
}

// Live/LivePlaybackClock.swift (VP-2): FlareCore's Timeline.playbackFrame; unavailableHelp nil.
// Live/LiveFrameRendering.swift (VP-4b, VP-5): unavailableHelp nil. ⌘R stays off until render-out.
// Live/HaloOutlines.swift (VP-4a): ellipse as four PathElement.cubic (k = 0.5523), points mapped
//   through HaloMatrix.apply before Path.flattened(tolerance: 0.25 / render scale).
// Live/HaloTextPlacement.swift (VP-5)
struct HaloTextPlacement: Equatable {                      // from an item's matrix; v1 has no skew
    var scaleX: Double; var scaleY: Double; var degrees: Double; var center: HaloPoint
    init?(_ item: HaloDrawItem)                            // nil when det(matrix) <= 0 or not finite
}

// HaloPlayback.swift (VP-3): never calls `edit`; writes only `playback` and the playhead.
extension HaloProject {
    public mutating func play(at now: Double)
    public mutating func pause()
    public mutating func togglePlay(at now: Double)
    public mutating func setLoops(_ loops: Bool)
    @discardableResult public mutating func tick(now: Double) -> Bool   // false once stopped
    public mutating func stepFrame(by frames: Int)
    public mutating func goToStart()
    public mutating func goToEnd()
    public var playLabel: String { get }                   // "Playing" / "Paused"
    public var loopLabel: String { get }                   // "On" / "Off"
}

// FrameRenderer.swift (VP-4b): HaloRenderedFrame stays here; `renderFrame(at:scale:text:)` and
// `renderSelectedFrame(at:)` become thin wrappers over LiveFrameDrawing + LiveFrameRendering
// (the selected one over services.drawing + services.rendering + services.text).

// HaloApp (VP-8, VP-10)
struct HaloViewerCanvas: View   // init(model:perform:), W0's slot (FD-14 calls it from HaloViewer.swift);
                                // reads model.viewerDrawList and model.selectedLayerID itself; never acts
@MainActor final class HaloPlaybackDriver { init(onTick: @escaping @MainActor (Double) -> Void); func start(); func stop(); func receive(target: Double) }
struct HaloTransport: View   // init(model:perform:), W0's slot; owns the driver, which sends
                             // perform(.tick(now)) each refresh while model.playback.playing
```

## Pseudocode

```
HaloDrawRules.drawList(c, f, placing):                       # VP-1
  items = c.layers.reversed().filter { $0.kind != .null && $0.isVisible(at: f) }.map { l in
    Item(l.id, l.kind, l.bounds(in: c), placing.worldMatrix(l.id, c, f) ?? .identity,
         placing.value(.opacity, l.id, c, f) ?? l.opacity, l.color, l.blendMode, l.text) }
  return HaloDrawList(c.width, c.height, f, items)

LivePlaybackClock.tick(start, elapsed, fps, n, loops):       # VP-2
  guard n > 0, fps > 0 else (frame 0, ended false)
  guard elapsed.isFinite, elapsed > 0 else (clamp(start, 0, n-1), ended false)
  frame = try? Timeline.playbackFrame(elapsed: elapsed + start / fps, fps, n, loop: loops) ?? start
  ended = !loops && frame == n - 1
  # FakePlaybackClock becomes `LivePlaybackClock().tick(...)`: one rule, no copy

play(at now):         guard comp, services.clock.unavailableHelp == nil else return
                      if !loops && playhead == last { scrub(to: 0) }
                      playback = (playing true, loops, startFrame playhead, startTime now,
                                  lastFrame playhead)   # else the first tick sees a "scrub" and re-anchors
tick(now):            guard playing, comp else { playing = false; return false }
                      guard now.isFinite else return true
                      if playhead != lastFrame { startFrame = playhead; startTime = now }   # a scrub while playing
                      pass = (n - startFrame) / fps                    # seconds to the wrap
                      while loops && now - startTime >= pass {          # re-anchor on each wrap,
                        startTime += pass; startFrame = 0; pass = n / fps }   # so Loop off mid-play ends this pass
                      t = clock.tick(startFrame, now - startTime, fps, n, loops)
                      scrub(to: t.frame); lastFrame = t.frame; if t.ended { playing = false }; return playing
stepFrame(by k):      pause(); scrub(to: clamp(playhead + k, 0, last))
goToStart / goToEnd:  pause(); scrub(to: 0) / scrub(to: last)
# none calls edit: history is untouched (QB-F3); scrub(to:) is W0's, in HaloTimeline.swift

LiveFrameRendering.render(list, w, h, text):                 # VP-4b, VP-5
  out = PixelBuffer(w, h); sx = w / list.width; sy = h / list.height; skipped = 0
  for item in list.items:                                    # bottom first
    switch item.kind
      .solid, .shape:
        if matrix is translate + positive scale only: Mask.rectangle / Mask.ellipse of the world box * (sx, sy)
        else: Mask.polygon(flatten(outline(item) mapped by matrix, then by (sx, sy)))
        source = color (linear, premultiplied) * coverage; a throw → draw nothing, not counted
      .text:
        guard let r = text, let p = HaloTextPlacement(item),
              var px = try? r.rasterize(item.text ?? HaloTextContent(), color: item.color)
        else { skipped += 1; continue }
        # the raster's top-left is the item's bounds.origin; its baseline sits at height − descent
        # (the baseline rule below), so a box from `measure` lines up with the canvas's Text
        px = try px.resized(round(px.width * |p.scaleX| * sx), round(px.height * |p.scaleY| * sy), filter: .bilinear)
        px = try px.rotated(degrees: p.degrees, filter: .bilinear)  # image center stays the center
        at = (p.center.x * sx - px.width / 2, p.center.y * sy - px.height / 2) rounded
        # any throw here → skipped += 1
    out = composite(source, onto: out, [x, y,] mode: item.blendMode, opacity: item.opacity)
  return HaloRenderedFrame(out, list.frame, skipped)        # nulls are never in the list (#457)

HaloViewerCanvas (VP-8), inside CanvasSurface, .drawingGroup(colorMode: .linear):
  list = model.viewerDrawList; selected = model.selectedLayerID   # the slot reads its model
  for item: var g = context; g.transform = matrix * fit; g.opacity = item.opacity
            g.blendMode = map(item.blendMode)                # one switch, 16 W3C cases
            solid: fill Rect(bounds); shape: fill Ellipse(in: bounds)
            text:  # baseline rule: the line box's top-left is bounds.origin; the first baseline
                   # sits at bounds.y + ascent, ascent from the same font metrics the rasterizer
                   # uses (TextRasterizing.measure height = ascent + descent; baseline at height − descent)
                   r = g.resolve(Text(content.string).font(.system(size: content.fontSize)))
                   g.draw(r, at: (bounds.x, bounds.y + ascent − r.firstBaseline(in: size)),
                          anchor: .topLeading)   # so the first baseline lands on bounds.y + ascent
  overlay SelectionOutline at list.worldBox(of: selected) * fit
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: viewer-playback`,
`Fast-Check: pass`, `Head:`. VP-12 also carries `feature-done`. Sizes are
estimates; split any task that comes out bigger.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| VP-1 | #37 (part) | Live drawing: the draw-list rule in one helper; `LiveFrameDrawing` over it with `LiveLayerPlacing()` by default; `FakeFrameDrawing` a thin wrapper passing `FakeLayerPlacing()`; `drawnSummary`, `worldBox(of:)`; the suite runs on fake and live | `Sources/HaloModel/Live/HaloDrawRules.swift`, `Sources/HaloModel/Live/LiveFrameDrawing.swift`, `Sources/HaloModel/Fakes/FakeFrameDrawing.swift`, `Tests/HaloModelTests/FrameDrawingContractTests.swift` | – | ~220 |
| VP-2 | #37 (part) | `LivePlaybackClock` on `Timeline.playbackFrame`; `FakePlaybackClock` a thin wrapper; the suite runs on fake and live | `Sources/HaloModel/Live/LivePlaybackClock.swift`, `Sources/HaloModel/Fakes/FakePlaybackClock.swift`, `Tests/HaloModelTests/PlaybackClockContractTests.swift` | – | ~150 |
| VP-3 | #37 (part) | Playback workspace methods (play, pause, toggle, loop, tick with re-anchoring, step, start, end, labels); never a step | `Sources/HaloModel/HaloPlayback.swift`, `Tests/HaloModelTests/HaloPlaybackTests.swift` | VP-2 | ~320 |
| VP-4a | #457 (part) | Outlines and masks helper: the rect and four-cubic ellipse outlines mapped through `HaloMatrix.apply`, flattened to a polygon, and the axis-aligned test that picks `Mask.rectangle` / `Mask.ellipse` instead | `Sources/HaloModel/Live/HaloOutlines.swift`, `Tests/HaloModelTests/HaloOutlinesTests.swift` | – | ~170 |
| VP-4b | #457 (closes) | `LiveFrameRendering` for solids and shapes at their matrix with blend and opacity over VP-4a's masks; `FrameRenderer.swift` moves onto it; nulls never count; the note names only text | `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Sources/HaloModel/FrameRenderer.swift`, `Tests/HaloModelTests/FrameRenderingContractTests.swift`, `Tests/HaloModelTests/LiveFrameRenderingTests.swift`, `Tests/HaloModelTests/HaloRenderTests.swift`, `Tests/HaloModelTests/HaloRenderEdgeTests.swift` | VP-1, VP-4a | ~260 |
| VP-5 | #37 (part) | Text pixels: `TextRasterizing` output resized, rotated and composited at the item's world center, its top-left at the item's `bounds.origin` with the baseline at `height − descent` (the pinned baseline rule); no rasterizer, a mirror or a refused size counts as skipped | `Sources/HaloModel/Live/HaloTextPlacement.swift`, `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Tests/HaloModelTests/LiveFrameRenderingTextTests.swift` | VP-4b | ~240 |
| VP-6 | – | Budgets HB-2, HB-5, HB-11 on `reference` with W0's `HaloBudget.swift` | `Tests/HaloModelTests/HaloViewerBudgetTests.swift` | VP-1, VP-3 | ~130 |
| VP-7 | #37 (part) | `HaloAvailability+Playback` turns on Play/Pause, Loop, Next Frame, Previous Frame, Go to Start, Go to End (In and Out keep W0's state-only answers) | `Sources/HaloModel/Availability/HaloAvailability+Playback.swift`, `Tests/HaloModelTests/HaloPlaybackAvailabilityTests.swift` | VP-2 | ~160 |
| VP-8 | #37 (part) | `HaloViewerCanvas` replaced whole in W0's slot, `init(model:perform:)` (linear light, the blend switch, text as resolved `Text` on the pinned baseline rule, `SelectionOutline` on the selected layer, `halo.viewer.canvas` with `drawnSummary`); it reads `model.viewerDrawList` and `model.selectedLayerID` itself, and W0's call site in `HaloViewer.swift` is untouched; the viewer area file keeps only its routes; #37's preview snapshots | `Sources/HaloApp/HaloViewerCanvas.swift`, `Sources/HaloApp/HaloWindow+Viewer.swift`, `Tests/AppSnapshotTests/HaloPreviewSnapshots.swift` | VP-1 | ~280 |
| VP-9 | #37 (part) | HF-1: the canvas equals the render, text included (pins the baseline rule) | `Tests/AppSnapshotTests/HaloViewerFidelityTests.swift` | VP-4b, VP-5, VP-8 | ~220 |
| VP-10 | #37 (part) | Transport (six SF Symbol buttons with `halo.transport.*` ids through `.haloControl`, play value, loop value), `HaloPlaybackDriver` on the display link calling `tick(now:)`, the playback area routes (Space, ←, →, Home, End and the Animation items, `now` from `CACurrentMediaTime()`) | `Sources/HaloApp/HaloTransport.swift`, `Sources/HaloApp/HaloPlaybackDriver.swift`, `Sources/HaloApp/HaloWindow+Playback.swift`, `Tests/AppSnapshotTests/HaloPlaybackDriverTests.swift`, `Tests/AppSnapshotTests/HaloTransportSnapshots.swift` | VP-3, VP-7 | ~350 |
| VP-11 | – | H-J3: `testScrubTheTimeline` extended, on `-HaloSample three-layers` | `UITests/HaloJourneyTests.swift` | VP-10 | ~90 |
| VP-12 | #37 (closes) (`feature-done`) | H-J2 and H-J4 on `-HaloSample three-layers` | `UITests/HaloJourneyTests+Viewer.swift`, `UITests/HaloJourneyTests+Playback.swift` | VP-6, VP-8, VP-9, VP-10, VP-11, #333 | ~220 |

A task depends on another only when it calls what that task adds, its test
needs that behavior, or it edits that task's file; "Build waves" says which
tasks run side by side. VP-3's and VP-7's `.live` runs need VP-2's
`LivePlaybackClock` (W0's stub has help and ends every tick); VP-7 reads
only state W0 ships and the clock's help, so it doesn't wait for VP-3.
VP-4b's `FrameRenderer.swift` wrappers sit on VP-1's `LiveFrameDrawing` and
VP-4a's outlines; VP-5 edits VP-4b's `LiveFrameRendering.swift`. VP-8 reads
VP-1's `drawnSummary` and `worldBox(of:)`. VP-10's routes call VP-3's
methods and its playing snapshot needs VP-7's enabled commands. VP-11's H-J3
presses Home and →, which VP-10 routes; its artboard value is W0's
`viewerSummary`, so it doesn't wait for VP-8. VP-12's journeys drive VP-8's
canvas value and VP-10's transport, and as the `feature-done` PR it also
waits for VP-6, VP-9 and VP-11. VP-1, VP-2 and VP-4a start together. The
live types land first, so every journey is written on `-HaloSample` from
its first PR; none flips later. Until layer-keys lands
`LiveLayerPlacing`, `LiveFrameDrawing()` draws every layer at its static
place (the stub's nil falls back to identity, which the W0 defaults make
exact for unkeyed layers); `three-layers` has no keys, so the journeys hold,
and `.live` gets keyed drawing with no edit here once it lands. VP-4b keeps
every existing assertion in `HaloRenderTests` and `HaloRenderEdgeTests`
except `otherLayerKindsAreSkippedWithANote`, which flips (below); the
axis-aligned `Mask.rectangle` path keeps their exact bytes. The outline
helper is split out up front (VP-4a) so VP-4b stays well under 400 lines.

## Build waves

No task edits a shared doc (`docs/c4/model.json`, `docs/design.md`, the
blueprint or `waves.md`; see the shared-file rule above), so there is no
docs task and VP-12 stays the final task.

- Wave 1: VP-1, VP-2, VP-4a. Independent in this wave: all three.
- Wave 2: VP-3, VP-4b, VP-7, VP-8. Independent in this wave: all four.
- Wave 3: VP-5, VP-6, VP-10. Independent in this wave: all three.
- Wave 4: VP-9, VP-11. Independent in this wave: both.
- Wave 5: VP-12 (`feature-done`, final; also waits for #333). Independent
  in this wave: VP-12 alone.

Longest chain: VP-1 → VP-4b → VP-5 → VP-9 → VP-12 (5); VP-4a → VP-4b →
VP-5 → VP-9 → VP-12, VP-2 → VP-3 → VP-10 → VP-11 → VP-12 and VP-2 →
VP-7 → VP-10 → VP-11 → VP-12 are the same length.

Chain of 5: VP-4b's `FrameRenderer.swift` wrappers call VP-1's
`LiveFrameDrawing` and its masks come from VP-4a's `HaloOutlines.swift`;
VP-5 adds text to VP-4b's `LiveFrameRendering.swift`; VP-9 compares VP-8's
canvas with VP-5's text pixels; VP-12 is `feature-done` and closes #37.
Chain of 5: VP-3's `.live` tests need VP-2's `LivePlaybackClock`; VP-10's
`HaloWindow+Playback.swift` routes call VP-3's `play`, `tick(now:)` and
`stepFrame(by:)`; VP-11's H-J3 presses Home and →, which VP-10 routes;
VP-12's H-J4 drives VP-10's transport, and its run must hold H-J3.
Chain of 5: VP-7's `.live` test needs VP-2's `LivePlaybackClock` help;
VP-10's playing snapshot needs VP-7's enabled commands; then VP-11 and
VP-12 as above.
Chain of 4: VP-8's canvas reads VP-1's `drawnSummary` and `worldBox(of:)`;
VP-9 compares VP-8's canvas with the render; VP-12's H-J2 drives VP-8's
canvas value.
Chain of 4: VP-3's `.live` tests need VP-2's clock; VP-6 times VP-3's
`tick(now:)` as `playbackTick`; VP-12 is `feature-done` and waits for
VP-6's budgets.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| VP-1 | `FrameDrawingContractTests`, each over `[FakeFrameDrawing(), LiveFrameDrawing(placing: FakeLayerPlacing())]`: `three-layers` at 12 lists Background, Badge (bottom first; Rig and Title absent); at 30 Background, Badge, Title with text "Hello Halo"; `keyed` at 12 maps Ball's box center to x 560 with opacity 1, at 6 to x 360 with opacity 0.5; `parented` never lists Rig. `LiveFrameDrawing()` on `three-layers` at 30 equals the fake's list; its `unavailableHelp` is nil. `drawnSummary` reads "3 layers drawn", "1 layer drawn", "No layers drawn"; `worldBox(of: Badge)` is (860, 440, 200, 200) (the default shape box) | a null or out-of-span layer is listed, order flips, a key is not sampled, or live creates a fake |
| VP-2 | `PlaybackClockContractTests` on fake and live, 24 fps, 72 frames: start 0, 1.0 s → 24; looping start 60, 1.0 s → 12; play-once start 60, 1.0 s → 71 `ended`; NaN and −1 s → 60 not ended; 0 frames → 0; 1/24 s → 1 (the epsilon) | the two disagree, a frame edge lands one early, or play-once wraps |
| VP-3 | `HaloPlaybackTests` on `three-layers`, `.fake` and `.live`: `play(at: 100)`, `tick(now: 101)` → 24; `play(at:)` from 60 sets `lastFrame` 60, and the first tick 1/24 s later shows 61 (no re-anchor); from 60 looping, `tick(now: 102)` → 36; a scrub while playing: play at 0, tick to 10, `scrub(to: 40)`, a tick 1/24 s later shows 41; from 60 Loop off, `tick(now: 101)` → 71, `playing` false, returns false; play on 71 with Loop off starts at 0; from 0 looping `tick(now: 103.5)` → 12, then `setLoops(false)`, `tick(now: 104)` → 24 still playing; `tick(now: .nan)` keeps the frame; `stepFrame(by: 2)` from 10 → 12 and pauses, by −20 → 0, by 5 from 70 → 71; `goToEnd` → 71; with no composition `tick` returns false. `history` is equal before and after 100 ticks, steps and toggles; `playLabel` and `loopLabel` read "Playing"/"Paused", "On"/"Off" | playback records a step, overruns the last frame, ends a looping play after Loop off, re-anchors on the first tick after play, drops a scrub made while playing, or stalls on NaN |
| VP-4a | `HaloOutlinesTests`: a translate + positive-scale matrix picks the axis-aligned mask with the world box; a rotated or negative-scale matrix picks the polygon; the four-cubic circle of radius 100 flattened at tolerance 0.25 stays within 0.3 of radius 100 at every point; a non-finite matrix gives no outline | an axis-aligned item takes the polygon path, the ellipse drifts off its radius, or a non-finite outline is returned |
| VP-4b | `LiveFrameRenderingTests` (HF-2) on a 40 × 20 composition: a 50% red solid in Multiply over blue gives (0, 0, 0.5, 1) linear at every pixel; a solid rotated 45° has coverage 1 at its center, 0 at the far corner and strictly between on its edge; an unrotated shape's pixels equal `Mask.ellipse`'s, and a 30°-rotated circle keeps them within one pixel. `FrameRenderingContractTests` (fake and live): the size asked for, a null counts 0, an opaque solid fills its box. `HaloRenderTests`: #457's repro (null plus solid) has `note == nil`; `otherLayerKindsAreSkippedWithANote` becomes solid + text + null on `.live` with no rasterizer: `skippedLayerCount == 1`, note "1 text layer not drawn." | a null is counted, a shape still skips, a blend value is off the W3C formula, or a shipped render byte changes |
| VP-5 | `LiveFrameRenderingTextTests` with `FakeTextRasterizer` on a 400 × 200 composition, text "Hi" at 50 (box 60 × 50 centered, so 170…230, 75…125): at full size pixel (200, 100) has the layer color and (165, 100) is clear; at half size the box is 85…115, 37…63; rotated 90° the box is 50 × 60, so (200, 72) is covered and (172, 100) is clear; at scale 2 the box is 120 × 100; the raster's top-left is the item's `bounds.origin` and a test rasterizer with descent 10 on a 50-high box puts its baseline row at y = origin + 40; with `text: nil` it is not drawn and `skippedLayerCount == 1`; scale (−1, 1) is skipped and counted | text lands off its world position, ignores scale or rotation, or is dropped silently |
| VP-6 | `HaloViewerBudgetTests`: `drawList` (fake and `LiveFrameDrawing(placing: FakeLayerPlacing())`), `playheadScrubStep`, `playbackTick` on `reference`, 200 runs | p95 over the debug gate in Quality tests |
| VP-7 | `HaloPlaybackAvailabilityTests` (`.fake` and `.live`): no composition: all six read "Create a composition first."; `three-layers` at 0: Play/Pause, Loop, Next Frame, Go to End enabled, Previous Frame "Already on the first frame.", Go to Start "Already at the start."; at 71 Next Frame "Already on the last frame.", Go to End "Already at the end."; a clock whose help is "x" makes Play/Pause and Loop read "x"; Set In / Out Point unchanged from W0 | a playback command is dead, or one turns on with nothing to do |
| VP-8 | `HaloPreviewSnapshots` on `.fake` `three-layers` through `snapshot(_:name:scheme:)`: `halo-preview-light.png`, `halo-preview-dark.png` (frame 0: Background and Badge), `halo-preview-frame-36-light.png`, `halo-preview-frame-36-dark.png` (Title "Hello Halo" over them), `halo-preview-selected-light/dark.png` (Badge selected: the outline on its box) | a layer is missing, out of order, or the outline is off the layer |
| VP-9 | `HaloViewerFidelityTests` (HF-1): `HaloViewerCanvas(model:perform: { _ in })` on a `HaloProject(services:)` built with injected services (`.live` with `drawing` = `LiveFrameDrawing(placing: FakeLayerPlacing())` and `text` = a test rasterizer that fills its measured box, ascent 40, descent 10), rendered through `ImageRenderer` at 1920 × 1080 against `LiveFrameRendering` on the same model's `viewerDrawList` at the same size, both as 8-bit sRGB: `keyed` frames 6 and 12, a Multiply solid over another, and a text item (the canvas's Text box on the pinned baseline rule against the test rasterizer's box) | a channel differs by over 2/255 on over 0.5% of pixels |
| VP-10 | `HaloPlaybackDriverTests`: the same targets through the driver and straight into `tick(now:)` land on the same frames; a paused model stops the link. `HaloTransportSnapshots`: `halo-transport-paused-light/dark.png`, `halo-transport-playing-light/dark.png` (pause symbol, Loop on) | the driver times by wall clock, keeps running when paused, or the transport overlaps the pills (L5) |
| VP-11 | H-J3 on the `dev` CI run; Badge's header reads "Frames 20–50" from W0's `selectedLayerHeader` (O at 50 stores outFrame 51) | any step's assert |
| VP-12 | H-J2, H-J4 on the `dev` CI run | any step's assert |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-2 viewer redraw | `drawList` on `reference` ≤ 2 ms device, ≤ 20 ms debug CI | `HaloViewerBudgetTests.drawList` (VP-6) |
| HB-5 playhead scrub | `scrub(to:)` + `timelineRows` + `viewerDrawList` ≤ 3 ms, ≤ 30 ms debug | `HaloViewerBudgetTests.playheadScrubStep` (VP-6) |
| HB-11 playback tick | `tick(now:)` + `viewerDrawList` ≤ 2 ms, ≤ 20 ms debug | `HaloViewerBudgetTests.playbackTick` (VP-6) |
| HF-1 viewer equals render | ≤ 2/255, ≤ 0.5% of pixels | `HaloViewerFidelityTests` (VP-9, macOS) |
| HF-2 live render | exact W3C values; rotated edge strictly in (0, 1) | `LiveFrameRenderingTests` (VP-4b, Linux) |
| QB-F1 no dead controls | the six playback commands enabled or say why | `HaloPlaybackAvailabilityTests` (VP-7); H-J13 keeps passing |
| QB-F3 one gesture, one step | playback, steps and ticks add no step | `HaloPlaybackTests` (VP-3) (on `-HaloSample` the W0 history stub records nothing, so no journey can show it) |
| QB-F4 keyboard parity | Space, ←, →, Home, End | H-J3, H-J4 |
| Audit | no `halo` count over baseline; the six transport buttons are labelled and identified | `audit-halo-*.json` on the VP-12 run |

HB-U4 (playback holds 30 fps on screen) is core-loop's H-P4. The PR bodies
of VP-8, VP-10 and VP-12 state the audit counts they expect (unchanged).

## Done check

- **Journeys green:** the macOS run on `dev` triggered by VP-12's
  `feature-done` PR is green, with H-J2, H-J3, H-J4 and every shipped Halo
  journey (H-J0, H-J1, H-J13, `testEveryMenuOpens`, `testLayoutAtWidths`)
  passing and other apps' journeys unchanged.
- **Audit zero new:** no `halo` count over `UITests/audit-baseline.json`.
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per journey and the audit
  counts. Expected new shots: `halo-` steps of H-J2 (layers appear at 12 and
  30, then Solid 2 on top), H-J3 (Badge's span 20–50), H-J4 (playing,
  paused, end); the snapshot PNGs listed under VP-8 and VP-10.

## Review notes folded in

From the review of the blueprint PR (#767) and the packet brief:

- **Text has an owner.** viewer-playback draws text both ways: as vectors in
  `HaloViewerCanvas` (resolved `Text` at the item's matrix, opacity and
  blend) and as pixels in `LiveFrameRendering` through `TextRasterizing`
  (`resized`, `rotated(degrees:)`, then `composite` at an offset; no skew).
  Linux tests use `FakeTextRasterizer`. text-layers (W2) adds only the
  CoreText rasterizer and the edits.
- **creative-core#182 is closed, but not on `main`.** `Path.ellipse(in:)`
  is on core `dev` only; this repo tracks `main` (cfad97f, checked
  2026-10-14). Rotated shapes use the four-cubic ellipse in
  `Live/HaloOutlines.swift`, written as data (not copied from Flare), with a
  comment naming #182; swapping in `Path.ellipse(in:)` once `main` has it is
  a one-function change. `Path.transformed(by:)` (named in blueprint 8.4) is
  not on `main` either, so the outline's points go through `HaloMatrix.apply`
  before flattening (an affine map keeps cubics cubic).
- **#457.** Nulls never reach the draw list, so they never count. Every v1
  kind draws from VP-5 on; only text the renderer can't draw is counted, and
  the note says "text layer", not "Only solids render for now".
- **#37's body.** Its `HaloPreviewTests` become `FrameDrawingContractTests`
  (draw list) and `HaloPlaybackTests` (playback); the packet wins. Its
  snapshot file and PNG names stay (`HaloPreviewSnapshots.swift`,
  `halo-preview-light.png`, `-dark.png`, `-frame-36-light.png`,
  `-frame-36-dark.png`). Text draws its string, not its name; Play and Loop
  live in the status-row transport and the Animation menu, not the toolbar;
  the clock is a display link, not `TimelineView(.animation)`.
- **Live never creates a fake.** `LiveFrameDrawing` takes a placing and
  defaults to `LiveLayerPlacing()`; tests inject `FakeLayerPlacing()`.
- **Fakes become thin wrappers.** `FakeFrameDrawing` calls
  `HaloDrawRules`; `FakePlaybackClock` calls `LivePlaybackClock`, so the
  duplicate gate never sees the rule twice.
- **`renderedFrame` is render-out's.** This feature neither reads nor writes
  it; the playhead moving makes it stale by render-out's own computation.
- **Undo in journeys.** H-J3 and H-J4 run on `-HaloSample`, where the W0
  history stub records nothing, so they neither press ⌘Z nor read the Undo
  title; "playback is not a step" is proven in `HaloPlaybackTests`.
- **One availability test per area.** W0's `HaloCommandTests` checks only
  the invariant (enabled, or disabled with help) and the shipped commands, so
  no W1 feature edits it; VP-7's own `HaloPlaybackAvailabilityTests` asserts
  the playback commands turn on.
- **A scrub while playing.** The blueprint left it to be overwritten by the
  next tick. W0's `HaloPlaybackState` carries `lastFrame` (the frame the last
  tick showed), and `tick` re-anchors on the playhead when it moved, so
  playback continues from wherever the person scrubbed. `HaloPlaybackTests`:
  play at 0, tick to 10, scrub to 40, tick 1/24 s later shows 41.
- **The canvas is a slot view.** `HaloViewerCanvas` has W0's one
  initializer, `init(model:perform:)` (FD-14's call site in `HaloViewer.swift`
  never changes); it reads `model.viewerDrawList` and `model.selectedLayerID`
  itself. VP-9 builds the model with injected services, not a bare list.
- **`play` sets `lastFrame`.** Otherwise the first tick after play from 60
  sees `playhead != lastFrame` and re-anchors on a stale time; VP-3 tests it.
- **The text baseline rule is pinned here.** A text item's line box top-left
  is `bounds.origin`; the canvas draws resolved `Text` with its first baseline
  at `bounds.y + ascent`, ascent from the font measured by the same rule the
  rasterizer uses (`TextRasterizing.measure` height = ascent + descent; the
  rasterizer puts the baseline at `height − descent`). VP-5 and VP-8 follow
  it and VP-9 tests it with a test rasterizer, so text-layers' TX-5 only
  checks CoreText ink inside the box and viewer against render.
- **H-J3's header.** "Frames 20–50" is W0's `selectedLayerHeader` (FD-12):
  outFrame is exclusive, so O at 50 stores 51 and the header shows in…out−1.
- **H-J4 steps back.** `→ →` from a paused f ≥ 70 would clamp at 71, so the
  journey steps back twice (f in 2…71, timecode f − 2) instead.
- **VP-4 split.** The outline helper is VP-4a, ahead of `LiveFrameRendering`
  and the `FrameRenderer` move (VP-4b, which closes #457), so neither PR
  nears 400 lines.
- **The driver's route.** The transport slot has W0's one initializer,
  `init(model:perform:)`; its driver sends `perform(.tick(now))`, which
  `HaloWindow+Playback.swift` routes to `tick(now:)`, and stops when
  `model.playback.playing` turns false. No `onTick` slot is needed in a W0
  file.
