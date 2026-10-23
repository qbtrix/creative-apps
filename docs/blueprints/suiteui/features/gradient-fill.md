# Feature packet: gradient-fill

**Feature:** one gradient fill for the whole suite. SuiteKernel gets a
`Fill/` module: FlareCore's `Fill` and `GradientStop` promoted under kernel
names, the stop and angle rules, the fill commands every app registers, and
the SVG writer. SuiteUI gets one `GradientEditor`: a stop bar (click to add,
drag to move, drag off or Delete to remove), the selected stop's colour in the
suite's colour row, an angle row, and a Solid / Linear / Radial switch. The
editor never edits a document: it emits `GradientIntent`s, each one a fill
command, and the app runs them through its catalog.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/gradient-fill`
**Beta:** captain, 2026-10-20 ("an everyday feature"). Labels `beta` and `p0` when filed.

**Covers:** feature map S24 (new: gradient fills, the shared half; S17 keeps
strokes, dashes and trim paths); the gradient half of S17's "suiteui gradient
rows"; real job RJ-X30 (new). The four adopts are packets on their own lines:
`design/gradient-fill`, `flare/gradient-fill`, `halo/gradient-fill`,
`photo/gradient-fill`, each waiting on this packet's GF-a.

**Depends on:** command-catalog (#2996): GF-6 waits on its **CC-run** (a
catalog run records exactly one undo step per edit, the drag-token fold),
GF-2 on **CC-u** (it owns `SuiteGallery.swift` before this page lands), GF-9
on **CC-a** (it owns `FakeCanvasDocument.swift`). editor-kernel (built):
`History`, `CommandSpec`, `Rect`. suite-harness and editor-in-window (built)
for the gallery. font-picker's FP-a waits on CC-u, and GF-2 also waits on FP-a, so GF-2's one
`SuiteGallery.swift` line lands after both. No creative-core issue: `Fill`,
`GradientStop` and `Color` are on the pinned core.

**Rule 20.** One gradient model: FlareCore's `Fill`, which Flare already
stores, every exporter already writes and every app Model can reach through
SuiteKernel. No app declares its own gradient or stop type. GF-1 adds
`Gradient: Gradient` to `Tests/canonical-concepts.txt`, so
`scripts/check-dup-logic` fails an app file named for one; the adopts' files
are `<X>Fill+Kernel.swift` adapters. One known copy: `GradientSVG` writes
what FlareCore's internal `SVGExporter.gradient(_:id:)` writes, because
that function isn't public. Follow-up on creative-core: make it public, then
the kernel calls it and drops its body. The angle, stop and box rules live once,
in `GradientRules`, so the vector path (canvas, SVG) and the raster path
(CoreRaster) take their points from the same function.

**Render path.** No new route and no new CPU path. Each app draws through the
path it has: Design and Flare through SwiftUI and CoreGraphics shading
(`GradientShading`, one bridge, sRGB like `StageRasterizer`), Halo through its
CoreRaster frame renderer, Photo as a pixel edit composited through its
`RenderDispatcher` route. The pixel engine is creative-core's
`PixelBuffer.gradient` (`RasterGradient`, dithered). `docs/render-contract.md`
is not on `dev`; `RenderOp` has no gradient family and needs none (a gradient
is generated once, then composited by existing ops). A Metal gradient op is a
creative-core follow-up, not this packet.

**C4:** new component part `suite-kernel/kernel-fill.json` (GF-1).
`GradientEditor.swift` and `GradientShading.swift` are new files in
`Sources/SuiteUI/`, covered by `suiteui-sources`.

**Clean-room.** Stop-bar behaviour from the HIG and SVG 1.1's gradient
semantics; no task reads another product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets), 7.5 (feel);
suite.md 1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| GF-a | The kernel's `Fill/` module declares every type, rule, intent and command spec as stubs, the gallery's `gradient-editor` page is in the index, and the checks are written, disabled. | GF-1, GF-2 | SJ0 | editor-kernel:EK-u, suite-harness, editor-in-window, command-catalog:CC-u and font-picker:FP-a (GF-2) |
| GF-u | On the gallery page a click adds a stop, a drag moves it, dragging it off removes it, the colour row recolours the selected stop, the angle row turns a linear fill and the switch changes type, every control identified, within the render budget. | GF-3, GF-4 | GJ1 (`SuiteGradientJourneyTests.testGradientEditorEditsAFill`) | GF-a |
| GF-m | The rules keep stops sorted in 0...1 with at least two, turn the line about the box centre so the corners land on 0 and 1, and every fill command records exactly one undo step (a drag one), and the SVG writer emits the same points. | GF-5, GF-6, GF-7 | KJ-fill | GF-a; command-catalog:CC-run (GF-6) |
| GF-z | The gallery runs its intents through `GradientCommands` on a live target, the fake app takes fills so RJ-X30 runs on the CLI, and the feature is built. | GF-8, GF-9, GF-10 | GJ1, KJ-fill | GF-u, GF-m; command-catalog:CC-a (GF-9) |

GF-u waits only on GF-a (rule 18); GF-m never waits on GF-u. KJ-fill is the
rules' and commands' Linux walk in `SuiteKernelTests`.

## Journey steps

1. Open the gallery index, click `gradient-editor` (GF-2, SJ0): the editor
   shows a two-stop linear fill, blue to white, 0°.
2. Click the bar at its middle (GF-3, `testGradientEditorEditsAFill`): a third
   stop appears there in the colour the bar showed; it is selected.
3. Pick red in the colour row: the stop and the preview turn red; the page's
   log shows one `fill.stop-color`.
4. Drag the stop to 25%: the log shows one `fill.stop-move` per sample, all
   under one drag token (one undo step once live, GF-8).
5. Type 45 in the angle row, switch to Radial (the angle row hides), back to
   Linear (45° kept), then drag the red stop off the bar: two stops remain.
6. With two stops the remove gesture does nothing and the stop's help reads
   "A gradient needs at least two stops." Every control works by keyboard
   (arrows move the selected stop 1%, Delete removes it) and VoiceOver reads
   "Stop 2 of 3, 50 percent, red" (GF-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X30 | adds, closes with S24 | C | `Tests/RealJobs/fake/gradient-fill/gradient-fill.jobs.json`: `fill.gradient` (three stops, 45°), 120 `fill.stop-move` under one drag token, `edit.undo` once; the saved rects | `input/one.fake` (one free rect) |

Trap: the 120 moves land as 120 undo steps, or the angle saves in radians.
Assertion: after the undo the middle stop is back at 0.5 (one step), and the
saved line's points are the 45° endpoints `GradientRules.rotated` gives for the
rect (x1 < x2 and y1 < y2, equal spans for a square). Its mutations sit in
`SuiteKernel.GradientCommands.json` (the drag token not passed to the fold)
and `SuiteKernel.GradientRules.json` (degrees used as radians).

## Screens and states

`suiteui-gradient-editor` (linear, light and dark), `-radial` (no angle row),
`-three-stops` (middle stop selected), `-solid` (the bar hidden, the colour row
alone), `-two-stops-help` (the remove help shown).

## Contract slice

```swift
// Sources/SuiteKernel/Fill/Fill.swift (GF-1): the suite's fill is FlareCore's, under kernel names.
public typealias Fill = FlareCore.Fill                 // .solid(Color), .linear(stops,start,end), .radial(stops,center,radius)
public typealias GradientStop = FlareCore.GradientStop // offset 0...1, color
public typealias FillColor = FlareCore.Color           // sRGB 0...1, straight alpha (SwiftUI owns `Color`)
public enum FillType: String, Codable, CaseIterable, Sendable { case solid, linear, radial }
/// The primary selected layer's fill, its points in `box`'s space (Design and Halo store a unit box and map it).
public struct FillSelection: Hashable, Sendable { public var fill: Fill; public var box: Rect }
public protocol GradientFillTarget: Sendable {
    var fillSelection: FillSelection? { get }  // nil: nothing fillable selected
    var fillHelp: String? { get }              // why the fill commands can't run now, nil when they can
    /// Sets every selected fillable layer, mapped from `box` to its own box; one undo step named `name`,
    /// steps under one `drag` token fold into one.
    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws
}
// Sources/SuiteKernel/Fill/GradientRules.swift (GF-1 stubs returning the input, GF-5 bodies)
public enum GradientRules {
    public static let maxStops = 64, stopHelp = "A gradient needs at least two stops."
    public static func type(of fill: Fill) -> FillType
    public static func converted(_ fill: Fill, to type: FillType, in box: Rect) -> Fill
    public static func angle(of fill: Fill) -> Double?                       // degrees in [0, 360), 0 left to right, 90 top to bottom
    public static func rotated(_ fill: Fill, to degrees: Double, in box: Rect) -> Fill
    public static func color(of fill: Fill, at offset: Double) -> FillColor
    public static func addingStop(_ fill: Fill, at offset: Double) -> (fill: Fill, index: Int)?
    public static func movingStop(_ fill: Fill, index: Int, to offset: Double) -> (fill: Fill, index: Int)
    public static func removingStop(_ fill: Fill, index: Int) -> Fill?       // nil with two stops left
    public static func recoloring(_ fill: Fill, index: Int, to color: FillColor) -> Fill
    public static func mapped(_ fill: Fill, from: Rect, to: Rect) -> Fill
}
// Sources/SuiteKernel/Fill/GradientCommands.swift (GF-1 specs with real ids, schemas and availability, runs throwing
// `GradientRules.notBuilt`; GF-6 bodies)
public enum GradientIntent: Hashable, Sendable {
    case type(FillType), add(offset: Double), move(index: Int, offset: Double, drag: String)
    case remove(index: Int), color(index: Int, FillColor, drag: String?), angle(Double, drag: String?)
    public var command: (id: String, params: JSONValue) { get }   // the editor's gesture as the command it is
}
public enum GradientCommands {
    public static func specs<T: GradientFillTarget>(_ target: T.Type) -> [CommandSpec<T>]
}
// Sources/SuiteKernel/Fill/GradientSVG.swift (GF-1 stub returning "", GF-7 body)
public enum GradientSVG { public static func definition(_ fill: Fill, id: String) -> String }
// Sources/SuiteUI/GradientEditor.swift (GF-2 placeholder, GF-3 view)
/// `showsAngle: false` for a tool whose drag sets the line (Photo's Gradient tool); `types` limits the switch.
public struct GradientEditor: View {
    public init(fill: Fill, box: Rect, showsAngle: Bool = true, types: [FillType] = FillType.allCases,
                onIntent: @escaping (GradientIntent) -> Void) }
// Sources/SuiteUI/GradientShading.swift (GF-2 stub drawing the first stop's colour, GF-3 body)
extension Fill { public func shading(in rect: CGRect, box: Rect) -> GraphicsContext.Shading }
```

Commands (all `edit` but `fill.read`; ids go in each adopter's
`Tests/command-ids/<app>.txt`):

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `fill.read` | – (query) | – → `{type, stops, angle?}` | `fillHelp` |
| `fill.type` | Fill Type | `{type}` | `fillHelp` |
| `fill.gradient` | Set Gradient | `{type, stops: [{offset, r, g, b, a}], angle?}` | `fillHelp`; fewer than 2 or more than 64 stops |
| `fill.stop-add` | Add Gradient Stop | `{offset}` | solid; 64 stops |
| `fill.stop-move` | Move Gradient Stop | `{index, offset, drag?}` | solid |
| `fill.stop-remove` | Remove Gradient Stop | `{index}` | solid; two stops (`stopHelp`) |
| `fill.stop-color` | Gradient Stop Color | `{index, r, g, b, a, drag?}` | solid |
| `fill.angle` | Gradient Angle | `{degrees, drag?}` | not linear ("Angle is for a linear gradient.") |

Every spec reads and writes through `GradientFillTarget`, so an app adds the
eight with one line (`+ GradientCommands.specs(<X>Workspace.self)`) and its
`<X>Fill+Kernel.swift` conformance.

## Pseudocode

- **rotated.** `θ` in radians from degrees (y down); `c` the box centre;
  `half = (|w·cos θ| + |h·sin θ|) / 2`; start `c − half·(cos θ, sin θ)`, end
  `c + half·(cos θ, sin θ)`. Non-finite degrees return the fill unchanged.
- **angle.** `atan2(end.y − start.y, end.x − start.x)` in degrees, into
  `[0, 360)`; nil for solid or radial.
- **converted.** solid → linear: `[colour @ 0, white @ 1]` at 0°; solid →
  radial: same stops, centre `c`, radius half the box diagonal; linear ↔
  radial keeps the stops; any → solid keeps the first stop's colour.
- **color(at:).** Clamp to the end stops; between two stops a straight sRGB
  lerp of each channel and alpha (SVG's and CoreGraphics' default); two stops
  at one offset make a hard edge (the later wins at that offset).
- **movingStop.** Clamp to 0...1, re-sort stably, return the moved stop's
  new index so the editor's selection follows it.
- **commands.** Each spec reads `fillSelection`, applies one rule in its box,
  and calls `setFill` once with its title; `drag` passes through, so the
  target's `History` folds a drag into one step (`FakeCanvasDocument.MoveRect`'s
  pattern).
- **View.** The bar is one `Canvas` of the fill's shading with stop handles
  over it; pointer input stays local to the bar until the gesture ends, and
  each sample emits one intent (the app's live copy shows it, rule 18). The
  colour row is `InspectorColorWellRow`; the angle row `StudioScrubRow`
  0...359 with a `°` unit; the switch `ChoiceChips`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| GF-1 | – | The kernel `Fill/` module as stubs: typealiases, `FillType`, `FillSelection`, `GradientFillTarget`, `GradientRules`, `GradientIntent`, the eight specs with ids, schemas and availability, `GradientSVG`; the concept line; the C4 part; the three suites written, disabled by name | `Sources/SuiteKernel/Fill/Fill.swift`, `Sources/SuiteKernel/Fill/GradientRules.swift`, `Sources/SuiteKernel/Fill/GradientCommands.swift`, `Sources/SuiteKernel/Fill/GradientSVG.swift`, `Tests/SuiteKernelTests/GradientRulesTests.swift`, `Tests/SuiteKernelTests/GradientCommandsTests.swift`, `Tests/SuiteKernelTests/GradientSVGTests.swift`, `Tests/canonical-concepts.txt`, `docs/c4/parts/creative-apps/suite-kernel/kernel-fill.json` | – | ~380, 9 |
| GF-2 | – | The placeholder `GradientEditor` and `GradientShading` stub, the gallery's `gradient-editor` page in `SuiteGallery.areas` on a local fill, the journey written and skipped (`XCTSkip("waits on GF-4")`) | `Sources/SuiteUI/GradientEditor.swift`, `Sources/SuiteUI/GradientShading.swift`, `Sources/SuiteUI/Gallery/GalleryGradientEditor.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `UITests/SuiteJourneyTests+Gradient.swift` | GF-1 | ~220, 5 |
| GF-3 | – | The view: stop bar (add, move, drag-off remove, keyboard), colour row, angle row, type switch, identifiers `suite.gradient.*`; `shading` body | `Sources/SuiteUI/GradientEditor.swift`, `Sources/SuiteUI/GradientShading.swift`, `Tests/SuiteUITests/GradientEditorTests.swift` | GF-2 | ~360, 3 |
| GF-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteGradientEditorSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetGradientEditorTests.swift`, `UITests/SuiteJourneyTests+Gradient.swift` | GF-3 | ~220, 3 |
| GF-5 | – | `GradientRules` bodies; turns on `GradientRulesTests` | `Sources/SuiteKernel/Fill/GradientRules.swift`, `Tests/SuiteKernelTests/GradientRulesTests.swift`, `Tests/mutations/SuiteKernel.GradientRules.json` | GF-1 | ~300, 3 |
| GF-6 | – | `GradientCommands` bodies and `GradientIntent.command`; turns on `GradientCommandsTests` on a test target (one step per run, a drag one step, every why-not) | `Sources/SuiteKernel/Fill/GradientCommands.swift`, `Tests/SuiteKernelTests/GradientCommandsTests.swift`, `Tests/mutations/SuiteKernel.GradientCommands.json` | GF-5, command-catalog:CC-run | ~330, 3 |
| GF-7 | – | `GradientSVG.definition` body (user-space points, stop offsets, `stop-opacity` only below 1); turns on `GradientSVGTests` | `Sources/SuiteKernel/Fill/GradientSVG.swift`, `Tests/SuiteKernelTests/GradientSVGTests.swift`, `Tests/mutations/SuiteKernel.GradientSVG.json` | GF-1 | ~140, 3 |
| GF-8 | – | The gallery page runs each intent through `GradientCommands` on a local target with a `History`, so the log and one undo step show; the live test | `Sources/SuiteUI/Gallery/GalleryGradientEditor.swift`, `Tests/SuiteUITests/GradientEditorLiveTests.swift` | GF-4, GF-6 | ~120, 2 |
| GF-9 | – | The fake app takes fills: `FakeRect.fill` (omitted when nil, so the old jobs' JSON is unchanged), `FakeCanvasDocument` conforms and lists the specs; RJ-X30's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeCanvasFillTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/gradient-fill/gradient-fill.jobs.json`, `Tests/RealJobs/fake/gradient-fill/input/one.fake` | GF-6, command-catalog:CC-a | ~200, 5 |
| GF-10 | – | The C4 part names the commands and the editor; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-fill.json`, `docs/blueprints/suiteui/features/gradient-fill.wave.json` | GF-8, GF-9, GF-7 | ~20, 2 |

GF-1 declares every rule and spec so GF-5, GF-6 and GF-7 each fill one file.
No `suiteui.md` edit: the C4 part and the adopts' blueprint lines carry it.

## Build waves

- Wave 1: GF-1. Independent in this wave: GF-1 alone.
- Wave 2: GF-2, GF-5, GF-7. Independent in this wave: all three.
- Wave 3: GF-3, GF-6. Independent in this wave: both.
- Wave 4: GF-4, GF-9. Independent in this wave: both.
- Wave 5: GF-8. Independent in this wave: GF-8 alone.
- Wave 6: GF-10 (`feature-done`, final). Independent in this wave: GF-10 alone.

Longest chain: GF-1 → GF-2 → GF-3 → GF-4 → GF-8 → GF-10 (6). Chain of 6:
the page needs the module's types, the view fills the placeholder, the budget
and journey time the view, the live page swaps the log under the journey, and
GF-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| GF-1 | the three suites compile, disabled by name; `KernelShapeTests.importsOnlyFoundationAndFlareCore` still passes over `Fill/`; `check-dup-logic` passes with the new concept line | the module imports past FlareCore, or an app file is already named for the concept | – (stubs) |
| GF-2 | SJ0: the index lists `gradient-editor`; the page opens | the page is missing | – (UI) |
| GF-3 | `GradientEditorTests`: a click on the bar emits one `.add` at its offset; a drag emits `.move`s under one token; dragging 40 pt off emits `.remove`; the angle row hides for radial | an intent is wrong or doubled | – (UI) |
| GF-4 | `SuiteGradientEditorSnapshots`; `RenderBudgetGradientEditorTests.stopDragInThreeBodies`; `testGradientEditorEditsAFill` steps 1 to 6 | budget over, or a step fails | – (UI) |
| GF-5 | `GradientRulesTests`: 45° on a 100×100 box gives (0,0)→(100,100); 0° on 200×100 gives (0,50)→(200,50); `angle` reads back 45; a move past 1 clamps and the index follows; removing from two returns nil; `color(at: 0.5)` of black→white is 0.5 grey; `mapped` unit→frame scales points | a point, clamp or index is wrong | `SuiteKernel.GradientRules`: degrees not converted to radians → `GradientRulesTests.rotated45`; `half` without `abs` → `.rotated135`; `<= 2` for `< 2` in remove → `.removeKeepsTwo`; no re-sort after move → `.moveResorts` |
| GF-6 | `GradientCommandsTests`: each edit run records one step named its title; 120 `fill.stop-move` under one drag token undo in one; `fill.angle` on radial is unavailable with its reason; `fill.stop-remove` at two stops is unavailable with `stopHelp`; `GradientIntent.command` round-trips each case | a run records zero or two steps, or a why-not is missing | `SuiteKernel.GradientCommands`: drag not passed to `setFill` → `.dragIsOneStep`; angle allowed on radial → `.angleNeedsLinear`; `setFill` called twice in `fill.gradient` → `.oneStepPerRun` |
| GF-7 | `GradientSVGTests`: a 45° fill writes `x1="0" y1="0" x2="100" y2="100"` in user space; alpha 1 writes no `stop-opacity`; a radial writes `cx`, `cy`, `r` | the SVG drops the angle or an alpha | `SuiteKernel.GradientSVG`: start written for end → `.linearPoints`; opacity written at 1 → `.opaqueStopHasNoOpacity` |
| GF-8 | `GradientEditorLiveTests`: a stop drag on the page leaves one undo step; `testGradientEditorEditsAFill` on live | the page stays on the local log | – (UI) |
| GF-9 | `FakeCanvasFillTests`: a fill survives save and open; a locked rect refuses with its reason; the old `add-rect` job's JSON is unchanged; RJ-X30 passes on Linux | a fill is lost, a locked rect takes it, or old JSON changes | `SuiteKernel.FakeCanvasDocument`: locked check skipped in `setFill` → `.lockedRefusesFill`; `fill` encoded when nil → `.oldJSONUnchanged` |
| GF-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample stop drag on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetGradientEditorTests.stopDragInThreeBodies` |
| render: 120-sample angle scrub | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetGradientEditorTests.angleScrubInThreeBodies` |
| One gesture, one step | a stop drag, a colour-panel session, an angle scrub each one undo step | `GradientCommandsTests.dragIsOneStep`, `GradientEditorLiveTests` |
| No dead controls | every control registers in `suite.controls` | `testGradientEditorEditsAFill` |
| Keyboard and VoiceOver parity | arrows move the selected stop, Delete removes, Tab reaches each row; stops read "Stop n of m, p percent, colour" | `testGradientEditorEditsAFill` step 6 |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): GF-m merged-done on the Linux job with
`Mutate:` scores clean; GF-u's feel gate (`mouse`, `taste`, `job` lenses) and
its `Mac-Finish:` line; GF-z's journey on live and RJ-X30 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suiteui-gradient-editor-*`.

## Adopted by

`design/gradient-fill` (fill type on shapes, text and frames; RJ-D13),
`flare/gradient-fill` (editable gradients, #2315), `halo/gradient-fill`
(solid and shape layer fills), `photo/gradient-fill` (the Gradient tool;
RJ-P19). Each waits on GF-a and runs its UI on these stubs.

## Not in this packet

Diamond and angular gradients (a new `Fill` case changes FlareCore's coding
and every exporter; CoreRaster already has the pixel shapes), on-canvas
gradient handles, radial centre and radius editing (the commands keep the box
centre and the corner radius), OKLab interpolation for vector fills, a Metal
gradient op, gradient presets.
