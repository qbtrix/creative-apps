# Feature packet: transform (Design)

**Feature:** Design's layers turn and flip. A layer gets a rotation and two
mirror flags; the selection's handles turn with it (SuiteUI's
`SelectionHandlesEditor(degrees:)`), the rotate knob turns it (Shift snaps to
15°), the inspector's transform rows (X, Y, W, H, Rotation, Flip) edit it, and
Object > Flip Horizontal, Flip Vertical, Rotate 90° Left and Right act on the
selection. The canvas, PNG, PDF and SVG draw the turn. Every edit is one of
SuiteKernel's transform commands.
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/transform`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `design/transform` (adopter of S7); real job RJ-D15
(rotate a layer 15° with the handles).

**Depends on:** `suiteui/transform-tools` **TT-a** (cross-line); DT-5 needs
**TT-m**, DT-4 **TT-u**. Same line: gradient-fill's **DG-a** before DT-1 and
DT-2 (`DesignNode.swift`, `DesignInspector.swift`), **DG-u** before DT-3
(`DesignCanvasMarks.swift`), **DG-m** before DT-6 (`DesignSVG.swift`);
autosave-history's **DA-m** before DT-6 (the catalog and id list). Built or
earlier: design-window, style-rows, select-several, design-export.

**Hand-offs:** `DesignObjectMenu.swift` is adopt-command-catalog's (AC-design):
DT-2's four items land after AC-design's `Belt-Slice-Done:`. The cut
`design-seams-2` now waits on this feature.

**Rule 20.** No Design rotate maths: `DesignTransform+Kernel.swift` maps the
kernel's `TransformBox` onto `frame`, `rotation`, `flipX` and `flipY`, and the
hit test, canvas and SVG take their points from `TransformRules`. A turned
node's `frame` stays its unturned box, so snapping, resize and the layer list
keep working unchanged.

**Render path.** `paintArtwork` (canvas, PNG through `DesignRasterizer`, PDF)
wraps a node's drawing in `TransformRules.matrix` as a CoreGraphics
transform; SVG writes `transform="rotate(… cx cy) scale(…)"`. No new route.

Blueprint sections: design.md 5.3 (canvas editing), 6 (Properties rows), 8.2.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DT-a | Nodes carry a turn and mirrors, the adapter is declared as stubs, and the transform rows and Object items show on them. | DT-1, DT-2 | MJ-DT | gradient-fill:DG-a |
| DT-u | The canvas and the export paint turned and mirrored nodes, the handles turn with them, and the snapshots and render budget hold. | DT-3, DT-4 | J-DT | DT-a, gradient-fill:DG-u |
| DT-m | Turns and flips keep each node's centre as one step for the whole selection, a turned node is hit by its turned outline, and the SVG writes the turn. | DT-5, DT-6 | MJ-DT | DT-a, gradient-fill:DG-m, autosave-history:DA-m |
| DT-z | The journey turns and flips on live services, and the feature is built. | DT-7, DT-8 | J-DT | DT-u, DT-m |

DT-u waits only on DT-a (rule 18); DT-m never waits on DT-u. MJ-DT is the
Model walk in `DesignTransformTests` (Linux).

## Journey steps

1. Draw a rectangle, drag its rotate knob (DT-3, `DesignTransformJourneyTests.testRotateAndFlip`):
   it turns; Shift-drag lands on 15°; the inspector's Rotation reads 15°.
2. Drag the right handle along the turned edge: the box grows in its own frame.
3. Object > Flip Horizontal: the rectangle mirrors in place.
4. Type 0 in Rotation: it stands up again; one step per gesture.
5. Export SVG (DT-6): the rect carries `transform="rotate(15 …)"`.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D15 | closes (now `design/transform`) | C | `Tests/RealJobs/design/rotate-15/rotate-15.jobs.json`: `edit.select`, 60 `transform.rotate {"degrees": 0.25}` under one drag token, export SVG | `input/one-rect.design` (a 100 × 50 rect at 10, 10) |

Trap: the turn is about the rect's top-left (it swings off its spot), or 60
undo steps. Assertion: the SVG's rotate is `rotate(15 60 35)` (about the
centre) and one `edit.undo` puts it back to 0. Mutation:
`DesignModel.DesignTransform+Kernel.json` (turn about the origin →
`.turnAboutCentre`).

## Screens and states

`design-transform-turned` (light and dark), `-flipped`, `-rows` (the
inspector's transform rows).

## Contract slice

```swift
// Sources/DesignModel/DesignNode.swift (DT-1): stored, omitted from JSON at their defaults.
public var rotation: Double      // clockwise degrees about the frame's centre, (-180, 180]
public var flipX: Bool, flipY: Bool
// Sources/DesignModel/DesignTransform+Kernel.swift (DT-1 stubs, DT-5 bodies)
extension DesignWorkspace: TransformTarget {
    public var transformSelection: TransformBox? { get }   // one node: its own; several: the union, unturned
    public var transformHelp: String? { get }              // "Select a layer to transform." / locked help
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws
}
extension DesignNode {
    public var transformBox: TransformBox { get }
    public func contains(_ point: DesignPoint) -> Bool   // the turned outline; DesignNode.hit(at:) calls it (DT-1)
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DT-1 | – | `rotation`, `flipX`, `flipY` on `DesignNode` (omitted at defaults) and its hit test through `contains(_:)`; the adapter and `contains` as stubs (the unturned frame); `DesignTransformTests` written, disabled | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignTransform+Kernel.swift`, `Tests/DesignModelTests/DesignTransformTests.swift` | – | ~160, 3 |
| DT-2 | – | The transform rows in the inspector and the four Object items on the stubs; the journey written, skipped | `Sources/DesignApp/DesignInspectorTransform.swift`, `Sources/DesignApp/DesignInspector.swift`, `Sources/DesignApp/DesignObjectMenu.swift`, `UITests/DesignJourneyTests+Transform.swift` | DT-1 | ~200, 4 |
| DT-3 | – | The canvas paints turned and mirrored nodes; the selection's handles turn with them | `Sources/DesignApp/DesignCanvasMarks.swift`, `Sources/DesignApp/DesignSelectionMarks.swift`, `Tests/AppSnapshotTests/DesignTransformPaintTests.swift` | DT-2 | ~220, 3 |
| DT-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignTransformSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignTransformTests.swift` | DT-3 | ~180, 2 |
| DT-5 | – | Adapter bodies and `contains(_:)` for a turned outline; turns on `DesignTransformTests` | `Sources/DesignModel/DesignTransform+Kernel.swift`, `Tests/DesignModelTests/DesignTransformTests.swift`, `Tests/mutations/DesignModel.DesignTransform+Kernel.json` | DT-1 | ~260, 3 |
| DT-6 | – | SVG writes the turn; the six specs in the catalog and id list; RJ-D15's job folder | `Sources/DesignModel/Live/DesignSVG.swift`, `Tests/DesignModelTests/DesignSVGTests.swift`, `Tests/mutations/DesignModel.DesignSVG.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/RealJobs/design/rotate-15/rotate-15.jobs.json`, `Tests/RealJobs/design/rotate-15/input/one-rect.design` | DT-5 | ~200, 7 |
| DT-7 | – | The journey turned on, on live services | `UITests/DesignJourneyTests+Transform.swift` | DT-4, DT-6 | ~60, 1 |
| DT-8 | – | `status: built`; `feature-done` | `docs/blueprints/design/features/transform.wave.json` | DT-7 | ~10, 1 |

## Build waves

- Wave 1: DT-1. Independent in this wave: DT-1 alone.
- Wave 2: DT-2, DT-5. Independent in this wave: both.
- Wave 3: DT-3, DT-6. Independent in this wave: both.
- Wave 4: DT-4. Independent in this wave: DT-4 alone.
- Wave 5: DT-7. Independent in this wave: DT-7 alone.
- Wave 6: DT-8 (`feature-done`, final). Independent in this wave: DT-8 alone.

Longest chain: DT-1 → DT-2 → DT-3 → DT-4 → DT-7 → DT-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DT-1 | old files decode with rotation 0; `DesignTransformTests` compiles, disabled | an old file fails to open | – (stub) |
| DT-2 | `DesignInspectorSnapshots`: the transform rows show on the stubs; the four Object items are enabled with a selection | rows or items are missing | – (UI) |
| DT-3 | `DesignTransformPaintTests`: a node turned 90° paints its corners where `TransformRules.corners` says; the handles turn with it | the canvas or handles stay upright | – (UI) |
| DT-4 | `DesignTransformSnapshots`; `RenderBudgetDesignTransformTests.bodies` | budget over | – (UI) |
| DT-5 | `DesignTransformTests`: a turn keeps the centre; a flip keeps the frame; several nodes turn about the union's centre in one step; a locked node refuses; a click inside a turned node's corner gap misses it | a point, a step or a hit is wrong | `DesignModel.DesignTransform+Kernel`: turn about the origin → `.turnAboutCentre`; one step per node → `.oneStepForSeveral`; `contains` uses the unturned frame → `.hitUsesTurn` |
| DT-6 | `DesignSVGTests.turnedNode`; the six specs listed; RJ-D15 passes on Linux | the SVG drops the turn | `DesignModel.DesignSVG`: centre left out → `.rotateAboutCentre`; scale written for no flip → `.flipWritesScale` |
| DT-7 | `testRotateAndFlip` steps 1 to 5 on live | a step fails | – |
| DT-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample knob drag with the canvas live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignTransformTests.bodies` (bodies), `.timing` (p95, Tests/perf-suites.txt) |
| render: 120-sample Rotation scrub | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignTransformTests.bodies` (bodies), `.timing` (p95, Tests/perf-suites.txt) |
| One gesture, one step | a knob drag, a scrub, a flip each one step | `DesignTransformTests.oneStepPerGesture` |
| No dead controls; keyboard parity | rows by Tab, menu items with shortcuts | `testRotateAndFlip` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DT-m merged-done with RJ-D15 green in the
Linux job; DT-u's feel gate and `Mac-Finish:`; DT-z's journey on live. Then
`Belt-Contact-Sheet:` with `design-transform-*`.

## Not in this packet

Skew; rotating a frame's children with it as a group transform (a turned
frame turns its own box; children keep theirs); text on a turned box editing
in place turned (the editor opens upright).
