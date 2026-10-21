# Feature packet: gradient-fill (Design)

**Feature:** Design's shapes, text and frames take a linear or radial
gradient fill. The inspector's Fill section gets SuiteUI's `GradientEditor`
(Solid / Linear / Radial, the stop bar, the angle row); the canvas, PNG and
PDF paint it through `GradientShading`; the SVG writes it with the kernel's
`GradientSVG`. Every edit is a fill command from SuiteKernel's
`GradientCommands`, so the CLI and an agent set gradients the way the
inspector does. The blueprint's "gradients are out of the first cut" line is
reversed (captain, 2026-10-20).
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/gradient-fill`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `design/gradient-fill` (adopter of S24); real job
RJ-D13 (two-stop linear gradient on a background, angle turned, export
matches).

**Depends on:** `suiteui/gradient-fill` **GF-a** (cross-line: the `Fill/`
module, `GradientFillTarget`, the specs, the editor and shading stubs). Every
slice starts once GF-a merges; DG-4 needs GF-m's real commands (**GF-6**),
DG-5 the real SVG writer (**GF-7**), DG-u the real view (**GF-3**) for its
snapshots. Same line: design-export's **DE-s** (it owns `DesignSVG.swift`
and its plan) before DG-5, and design-export before DG-7 (`design.md`).
Built: design-contracts, design-window, style-rows, canvas-basics,
files-history.

**Hand-offs** (cross-line files; the lead checks each before the task):
`DesignCommandCatalog.swift`, its plan and `Tests/command-ids/design.txt`
are adopt-command-catalog's (#2999): DG-4 starts after AC-design's
`Belt-Slice-Done:`. `DesignNode.swift` and `DesignCanvasMarks.swift` are also
listed by adopt-kernel-layers, adopt-kernel-transform and the cut
adopt-suiteui-chrome; DG-1 and DG-3 each add a few lines and rebase onto
whichever lands first. design-seams-2 (p3, cut) now waits on this feature.

**Rule 20.** No Design gradient type: `DesignNode.gradient` is the kernel's
`Fill` with its points in the node's unit box (0...1), so a resize never
touches it. `DesignFill+Kernel.swift` maps unit box ↔ frame and is the only
new Model file.

**Render path.** `paintArtwork` (canvas, PNG through `DesignRasterizer`, PDF)
fills with `node.gradient?.shading(in:box:)` instead of the solid colour, so
the three share one painter as today. Text fills through the same shading as
its foreground style. No new route.

Blueprint sections: design.md 1 (first cut), 5.4 (`StyleEditing`), 6
(Properties tab rows), 8.2.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DG-a | `DesignNode.gradient` exists and saves, `DesignWorkspace` conforms to `GradientFillTarget` as stubs, and the inspector's Fill section shows the switch and the editor on them. | DG-1, DG-2 | MJ-DG | suiteui/gradient-fill GF-a (cross-line) |
| DG-u | The canvas, text and the PNG and PDF exports paint a node's gradient, and the Fill section's snapshots and render budget hold. | DG-3, DG-6 | DJ-G1 | DG-a; GF-3 (DG-6, cross-line) |
| DG-m | Every fill command runs on Design's selection as one undo step, and the SVG export writes each gradient with the points the canvas draws. | DG-4, DG-5 | MJ-DG | DG-a; GF-6 and AC-design (DG-4); GF-7 and design-export:DE-s (DG-5) |
| DG-z | The journey passes on live services, and the blueprint says gradients are in the first cut. | DG-7, DG-8 | DJ-G1 | DG-u, DG-m; design-export (DG-8) |

DG-a carries the first UI task (DG-2, the Fill section on the stubs), so the screen is reachable once the contract merges; DG-u waits only on DG-a (rule 18) and DG-m never waits on DG-u. MJ-DG is the
Model walk in `DesignGradientTests` (Linux).

## Journey steps

1. Select the frame's background rectangle; in the inspector's Fill section
   pick Linear (DG-3, `DesignGradientJourneyTests.testGradientFillAngle`):
   the rectangle shows its colour fading to white, left to right.
2. Type 90 in the angle row: the fade runs top to bottom on the canvas.
3. Click the stop bar's middle, pick a colour: three stops; Undo removes the
   colour, Undo again the stop (one step each).
4. Select a text layer, pick Radial: the letters fill with the gradient.
5. Export SVG (DG-5): the file's `linearGradient` runs top to bottom.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D13 | closes (now `design/gradient-fill`) | C | `Tests/RealJobs/design/gradient-angle/gradient-angle.jobs.json`: `edit.select`, `fill.type` linear, `fill.angle` 90, export SVG | `input/background.design` (one frame, one full-size rectangle) |

Trap: the export ignores the angle (it writes the default left-to-right
line). Assertion: the SVG's `x1` equals `x2` and `y1` is the rectangle's top,
`y2` its bottom. Mutation: `DesignModel.DesignSVG.json`, the points written
from the unit box instead of the frame → `DesignSVGTests.gradientInFrameSpace`.

## Screens and states

`design-fill-linear`, `design-fill-radial-text`, `design-fill-solid-switch`
(light and dark); the snapshots of the inspector's Fill section.

## Contract slice

```swift
// Sources/DesignModel/DesignNode.swift (DG-1): one stored field, omitted from JSON when nil.
public var gradient: Fill?            // points in the node's unit box; nil paints `fill` (solid)
// Sources/DesignModel/DesignFill+Kernel.swift (DG-1 stubs, DG-4 bodies)
extension DesignWorkspace: GradientFillTarget {
    public var fillSelection: FillSelection? { get }   // the primary node's fill in its frame
    public var fillHelp: String? { get }               // "Select a layer to fill." / the locked help
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws
    public mutating func runFill(_ intent: GradientIntent)  // the intent's command through `catalog`
}
extension DesignNode { public func fill(in frame: Rect) -> Fill }   // solid or gradient, in frame space
```

## Pseudocode

- **setFill.** For each selected unlocked node: `GradientRules.mapped(fill,
  from: box, to: unit)`; a `.solid` writes `fill` (8-bit) and clears
  `gradient`. One step through the workspace's edit path (the one `setStyle`
  records with), `drag` as its fold key.
- **SVG.** A node with a gradient writes `GradientSVG.definition(gradient
  mapped to its frame, id: "g-<node id>")` into `<defs>` and
  `fill="url(#g-<node id>)"`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DG-1 | – | `DesignNode.gradient`; the conformance and `runFill` as stubs; `DesignGradientTests` written, disabled | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignFill+Kernel.swift`, `Tests/DesignModelTests/DesignGradientTests.swift` | GF-a | ~160, 3 |
| DG-2 | – | The inspector's Fill section on the stubs: the switch and `GradientEditor`, each intent to `runFill`; reachable from the inspector | `Sources/DesignApp/DesignInspectorFill.swift`, `Sources/DesignApp/DesignInspector.swift` | DG-1 | ~160, 2 |
| DG-3 | – | `paintArtwork` and text fill with the shading; the journey written | `Sources/DesignApp/DesignCanvasMarks.swift`, `Sources/DesignApp/DesignTextArtwork.swift`, `Tests/AppSnapshotTests/DesignGradientPaintTests.swift`, `UITests/DesignJourneyTests+Gradient.swift` | DG-1 | ~180, 4 |
| DG-6 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignGradientSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignGradientTests.swift` | DG-2, DG-3, GF-3 | ~180, 2 |
| DG-4 | – | Adapter bodies; the eight specs in the catalog and the id list; turns on `DesignGradientTests` | `Sources/DesignModel/DesignFill+Kernel.swift`, `Tests/DesignModelTests/DesignGradientTests.swift`, `Tests/mutations/DesignModel.DesignFill+Kernel.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt` | DG-1, GF-6, AC-design | ~260, 5 |
| DG-5 | – | SVG gradients; RJ-D13's job folder | `Sources/DesignModel/Live/DesignSVG.swift`, `Tests/DesignModelTests/DesignSVGTests.swift`, `Tests/mutations/DesignModel.DesignSVG.json`, `Tests/RealJobs/design/gradient-angle/gradient-angle.jobs.json`, `Tests/RealJobs/design/gradient-angle/input/background.design` | DG-1, GF-7, design-export:DE-s | ~180, 5 |
| DG-7 | – | Live: the journey runs on live services and turned on | `UITests/DesignJourneyTests+Gradient.swift` | DG-6, DG-4 | ~60, 1 |
| DG-8 | – | `design.md` first-cut line and rows; `status: built`; `feature-done` | `docs/blueprints/design.md`, `docs/blueprints/design/features/gradient-fill.wave.json` | DG-7, DG-5, design-export | ~40, 2 |

## Build waves

- Wave 1: DG-1. Independent in this wave: DG-1 alone.
- Wave 2: DG-2, DG-3, DG-4, DG-5. Independent in this wave: all four.
- Wave 3: DG-6. Independent in this wave: DG-6 alone.
- Wave 4: DG-7. Independent in this wave: DG-7 alone.
- Wave 5: DG-8 (shared prose, `feature-done`, final). Independent in this wave: DG-8 alone.

Longest chain: DG-1 → DG-2 → DG-6 → DG-7 → DG-8 (5). Chain of 5: the
section needs the field, the budget times the section, the journey runs on
it live, DG-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DG-1 | `DesignNode` without `gradient` decodes old files; the suite compiles, disabled | an old file fails to open | – (stub) |
| DG-2 | `DesignInspectorSnapshots` Fill section on the stubs | the section is missing | – (UI) |
| DG-3 | `DesignGradientPaintTests`: a gradient node paints its first and last stop at its edges | the canvas paints the solid colour | – (UI) |
| DG-6 | `DesignGradientSnapshots`; `RenderBudgetDesignGradientTests.stopDragInThreeBodies` | budget over | – (UI) |
| DG-4 | `DesignGradientTests`: `fill.type` linear on a 200×100 rect stores (0,0.5)→(1,0.5); `fill.angle` 90 then a resize keeps the line vertical; a locked node refuses with its help; three nodes take one step | a point, a refusal or a step count is wrong | `DesignModel.DesignFill+Kernel`: locked nodes not skipped → `.lockedRefuses`; frame used as the unit box → `.resizeKeepsAngle`; one step per node → `.oneStepForSeveral` |
| DG-5 | `DesignSVGTests`: a 90° gradient writes vertical frame-space points and `fill="url(#g-…)"`; RJ-D13 passes on Linux | the export ignores the angle | `DesignModel.DesignSVG`: unit points written → `.gradientInFrameSpace`; `defs` skipped for text → `.textGradient` |
| DG-7 | `DesignGradientJourneyTests.testGradientFillAngle` steps 1 to 5 on live | a step fails | – |
| DG-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample stop drag in the inspector | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignGradientTests.stopDragInThreeBodies` |
| render: 120-sample angle scrub with the canvas live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignGradientTests.angleScrubInThreeBodies` |
| One gesture, one step | a stop drag, an angle scrub, a type switch | `DesignGradientTests.oneStepPerGesture` |
| No dead controls; keyboard parity | every Fill control identified and reachable by Tab | `testGradientFillAngle` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DG-m merged-done with RJ-D13 green in the
Linux job; DG-u's feel gate and `Mac-Finish:`; DG-z's journey on live. Then
`Belt-Contact-Sheet:` with `design-fill-*`.

## Not in this packet

Gradient strokes, on-canvas gradient handles, radial centre editing, diamond
and angular types (all deferred in the SuiteUI packet).
