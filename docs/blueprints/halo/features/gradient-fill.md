# Feature packet: gradient-fill (Halo)

**Feature:** Halo's solid and shape layers take a linear or radial gradient
fill. The layer inspector gets SuiteUI's `GradientEditor` under the colour
row; the frame renderer, which the viewer and Render… share, draws the
gradient inside the layer's outline; every edit is one of SuiteKernel's fill
commands, so the CLI and an agent can set it.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/gradient-fill`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/gradient-fill` (adopter of S24); real job
RJ-H32 (new). RJ-H30 (a star with a gradient fill) still needs S19's shapes.

**Depends on:** `suiteui/gradient-fill` **GF-a** (cross-line); HG-6 needs
its **GF-6**, HG-3 its **GF-3**. Same line: core-loop's **CL-probe** (it owns
`HaloLayerInspector.swift`) before HG-2 and its **CL-z** (`halo.md`) before HG-9; foundation, viewer-playback,
layer-keys and text-layers (built).

**Hand-offs:** `HaloCommandCatalog.swift`, its plan and
`Tests/command-ids/halo.txt` are adopt-command-catalog's (#2999): HG-6 starts
after AC-halo's `Belt-Slice-Done:`.

**Rule 20.** `HaloLayer.gradient` is the kernel's `Fill` with its points in
the layer's unit box; no Halo gradient type. `HaloFill+Kernel.swift` maps the
unit box to the layer's rectangle (a solid's `rect` or the frame, a shape's
ellipse bounds).

**Render path.** Halo's one route, `LiveFrameRendering` on CoreRaster, gets
one change: a layer with a gradient takes its source from creative-core's
`PixelBuffer.gradient` (the line's points through the item's matrix, stops
decoded from sRGB to linear light, dithered) times the outline's coverage,
where a solid takes its colour times the coverage. The viewer and the render
read the same frame, so they can't differ. No new route.

Blueprint sections: halo.md 6 (layer inspector), 7 (render), 8.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HG-a | `HaloLayer.gradient` and the draw item's gradient exist and save, and `HaloProject` conforms to `GradientFillTarget` as stubs. | HG-1, HG-5 | MJ-HG | suiteui/gradient-fill GF-a (cross-line) |
| HG-u | The layer inspector shows the switch and the editor for solid and shape layers on the stubs, with snapshots and the render budget, and the journey is written. | HG-2, HG-3, HG-4, HG-10 | HJ-G1 | HG-a; core-loop:CL-probe (HG-2); GF-3 (HG-3, cross-line) |
| HG-m | The renderer draws a layer's gradient inside its outline at its matrix, and every fill command runs as one undo step. | HG-6, HG-7 | MJ-HG | HG-a; key-editing:KE-a (the catalog); GF-6 and AC-halo (HG-7, cross-line) |
| HG-z | The inspector runs on live services, the journey passes on live, and the blueprint lists gradient fills. | HG-8, HG-9 | HJ-G1 | HG-u, HG-m; core-loop:CL-z, key-editing:KE-z (HG-9) |

HG-u waits only on HG-a and another feature's slice (rule 18); HG-m never
waits on HG-u. MJ-HG is the Model walk in `HaloGradientTests` (Linux).

## Journey steps

1. Add a solid layer; in the inspector pick Radial
   (`HaloGradientJourneyTests.testRadialSolid`): the viewer shows the colour
   at the centre fading out to white.
2. Set the first stop white and the last black: the viewer matches.
3. Scrub Position: the gradient moves with the layer.
4. Render frame 0 to PNG (HG-6): the PNG's centre is white, its corner black.
5. Undo: the last colour change goes, in one step.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H32 | adds, closes with `halo/gradient-fill` | C | `Tests/RealJobs/halo/gradient-frame/gradient-frame.jobs.json`: select the solid, `fill.gradient` radial white to black, export frame 0 as PNG | `input/one-solid.halo` (one full-frame solid, 64 × 64) |

Trap: the viewer draws the gradient but the render path still fills the old
solid colour. Assertion: the PNG's centre pixel is within 2/255 of white and
its corner within 2/255 of black. Mutation:
`HaloModel.LiveFrameRendering.json`, the gradient branch skipped →
`HaloGradientRenderTests.radialCentreAndCorner`.

## Screens and states

`halo-fill-radial`, `halo-fill-linear`, `halo-fill-text-layer` (the editor
hidden: text keeps its colour row) (light and dark).

## Contract slice

```swift
// Sources/HaloModel/HaloLayer.swift (HG-1): coded under "gradient" only when set.
public var gradient: Fill?                          // unit box; nil fills `color`
// Sources/HaloModel/Contracts/HaloDocumentValues.swift (HG-1)
extension HaloDrawItem { public var gradient: Fill? }   // carried by HaloDrawRules (HG-6)
// Sources/HaloModel/HaloFill+Kernel.swift (HG-1 stubs, HG-7 bodies)
extension HaloProject: GradientFillTarget {
    public var fillSelection: FillSelection? { get }    // solid and shape layers; nil for text and null
    public var fillHelp: String? { get }                // the colour row's refusals
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws
    public mutating func runFill(_ intent: GradientIntent)
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HG-1 | – | `HaloLayer.gradient`, the draw item's field, the conformance and `runFill` as stubs; `HaloGradientTests` written, disabled | `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/Contracts/HaloDocumentValues.swift`, `Sources/HaloModel/HaloFill+Kernel.swift`, `Tests/HaloModelTests/HaloGradientTests.swift` | GF-a | ~180, 4 |
| HG-5 | – | Checks first for the renderer: `HaloGradientRenderTests`, disabled by name | `Tests/HaloModelTests/HaloGradientRenderTests.swift` | HG-1 | ~120, 1 |
| HG-2 | – | `HaloFillInspector` (switch and editor, intents to `runFill`) slotted under the colour row | `Sources/HaloApp/HaloFillInspector.swift`, `Sources/HaloApp/HaloLayerInspector.swift` | HG-1, core-loop:CL-probe | ~150, 2 |
| HG-3 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/HaloGradientSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloGradientTests.swift` | HG-2, GF-3 | ~160, 2 |
| HG-4 | – | The journey, written and skipped (`XCTSkip("waits on HG-8")`) | `UITests/HaloJourneyTests+Gradient.swift` | HG-2 | ~100, 1 |
| HG-6 | – | `HaloDrawRules` carries the gradient; `LiveFrameRendering` draws it times coverage; RJ-H32's job folder; turns on `HaloGradientRenderTests` | `Sources/HaloModel/Live/HaloDrawRules.swift`, `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Tests/HaloModelTests/HaloGradientRenderTests.swift`, `Tests/mutations/HaloModel.LiveFrameRendering.json`, `Tests/RealJobs/halo/gradient-frame/gradient-frame.jobs.json`, `Tests/RealJobs/halo/gradient-frame/input/one-solid.halo` | HG-5 | ~260, 6 |
| HG-7 | – | Conformance bodies (one "Change Fill" step through `edit`, the drag token as the coalesce key); the specs in the catalog and the id list; turns on `HaloGradientTests` | `Sources/HaloModel/HaloFill+Kernel.swift`, `Tests/HaloModelTests/HaloGradientTests.swift`, `Tests/mutations/HaloModel.HaloFill+Kernel.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt` | HG-1, GF-6, AC-halo | ~240, 5 |
| HG-8 | – | Live: the journey turned on, on live services | `UITests/HaloJourneyTests+Gradient.swift` | HG-4, HG-7, HG-6 | ~40, 1 |
| HG-9 | – | halo.md lists gradient fills on solid and shape layers; `status: built`; `feature-done` | `docs/blueprints/halo.md`, `docs/blueprints/halo/features/gradient-fill.wave.json` | HG-8, HG-3, core-loop:CL-z | ~30, 2 |
| HG-10 | – | The layer colour row switches to `InspectorColorWellRow`'s opacity init and `HaloLayerColor` carries alpha (old projects open at 1), so a picked alpha reaches the layer; it also stores the kernel's `FillMemory` beside the fill and saves it, so linear → radial → linear keeps the angle (gap audit C3) | `Sources/HaloApp/HaloTextInspector.swift`, `Sources/HaloModel/HaloLayer.swift`, `Tests/HaloModelTests/HaloLayerAlphaTests.swift`, `Tests/mutations/HaloModel.HaloLayer.json` | HG-1, suiteui gradient-fill C3 (the opacity colour row and the kernel's opt-in no fill, cross-line) | ~160, 4 |

## Build waves

- Wave 1: HG-1. Independent in this wave: HG-1 alone.
- Wave 2: HG-2, HG-5, HG-7. Independent in this wave: all three.
- Wave 3: HG-3, HG-4, HG-6. Independent in this wave: all three.
- Wave 4: HG-8. Independent in this wave: HG-8 alone.
- Wave 5: HG-9 (shared prose, `feature-done`, final). Independent in this wave: HG-9 alone.
- With its slice (gap audit C3, added 2026-10-21): HG-10, after HG-1 and the suiteui C3 pull request.

Longest chain: HG-1 → HG-2 → HG-4 → HG-8 → HG-9 (5). Chain of 5: the
inspector needs the field, the journey drives the inspector, HG-8 turns it
on live, HG-9 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HG-1 | old projects decode; the suite compiles, disabled | a project fails to open | – (stub) |
| HG-5 | compiles, disabled | – | – |
| HG-2 | `HaloGradientSnapshots.radialSolid` (HG-3's, first in the slice PR) | the section is missing | – (UI) |
| HG-3 | `HaloGradientSnapshots`; `RenderBudgetHaloGradientTests.stopDragInThreeBodies` | budget over | – (UI) |
| HG-4 | compiles, skipped | – | – |
| HG-6 | `HaloGradientRenderTests`: a radial white-to-black solid renders white at its centre and black at its corners; a moved layer moves its gradient; nothing draws outside the ellipse of a shape; RJ-H32 passes on Linux | a pixel is off by more than 2/255 | `HaloModel.LiveFrameRendering`: gradient branch skipped → `.radialCentreAndCorner`; points not through the matrix → `.gradientMovesWithLayer`; coverage not applied → `.staysInsideEllipse` |
| HG-7 | `HaloGradientTests`: `fill.type` radial on a solid stores a unit-box fill; a text layer is unavailable with its reason; a 120-move drag is one step | a fill, refusal or step count is wrong | `HaloModel.HaloFill+Kernel`: text layers allowed → `.textRefuses`; drag key dropped → `.dragIsOneStep` |
| HG-8 | `HaloGradientJourneyTests.testRadialSolid` steps 1 to 5 | a step fails | – |
| HG-9 | `scripts/waves render --dry-run` | status not built | – |
| HG-10 | `HaloLayerAlphaTests`: a project without alpha opens at 1; a 50% layer colour saves and opens at 0.5; a linear fill at 45° switched to radial and back reads 45° after a save and open | the alpha is lost on save | `HaloModel.HaloLayer`: alpha not encoded → `.alphaRoundTrips`; alpha clamped to 1 on decode → `.oldProjectsOpaque` |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample stop drag with the viewer live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHaloGradientTests.stopDragInThreeBodies` |
| Frame cost | a full-frame 1080p gradient solid adds ≤ 20 ms to a frame render (reported) | `HaloGradientRenderTests.fullFrameCost` |
| One gesture, one step | a stop drag, a colour session, a type switch | `HaloGradientTests.dragIsOneStep` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HG-m merged-done with RJ-H32 green in the
Linux job; HG-u's feel gate and `Mac-Finish:`; HG-z's journey on live. Then
`Belt-Contact-Sheet:` with `halo-fill-*`.

## Not in this packet

Gradient text fills (text keeps its colour row), animated gradient stops,
gradient strokes, on-viewer gradient handles.
