# Feature packet: shape-tools (Design)

**Feature:** Design gets a Shape tool (U) for polygons, stars, lines and
arrows, beside its Rectangle and Ellipse tools. The tool's options (SuiteUI's
`ShapeToolOptions`) show in the inspector while it is active; a drag draws a
new `shape` layer whose `ShapeSpec` is saved, so a resize redraws it. The
Rectangle and Ellipse tools draw through the same kernel drag rule. The
canvas, PNG, PDF and SVG paint the spec's path.
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/shape-tools`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `design/shape-tools` (adopter of S19); real job RJ-D35
(new: a five-point star badge exported to SVG).

**Depends on:** `suiteui/shape-tools` **SH-a** (cross-line); DS-5 needs
**SH-m**, DS-4 **SH-u**. Same line: eyedropper's **DY-a** before DS-1 (both
own `DesignWorkspace.swift`) and transform's **DT-a** (`DesignNode.swift`,
`DesignInspector.swift`); transform's **DT-u** before DS-3
(`DesignCanvasMarks.swift`); eyedropper's **DY-m** before DS-6 (the catalog,
the id list and, through DT-m, `DesignSVG.swift`). Built or earlier:
canvas-basics (the drawing tools), design-window, style-rows, design-export.

**Hand-offs:** the cut `design-seams-2` now waits on this feature.

**Rule 20.** `DesignDrawing.swift`'s rectangle-from-a-drag maths is replaced
by `ShapeRules.dragged` (the copy SH named); the path is
`ShapeRules.path(spec, in: frame)`. The adapter is
`DesignShape+Kernel.swift`.

**Render path.** `paintArtwork` fills and strokes the spec's `Path` as it
does an ellipse's; SVG writes it as a `<path d=…>`. No new route.

Blueprint sections: design.md 5.2 (tools), 3 (node kinds).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DS-a | Shape nodes and the Shape tool exist, the adapter is declared as stubs, and the tool's options show in the inspector. | DS-1, DS-2 | MJ-DS | transform:DT-a, eyedropper:DY-a |
| DS-u | The canvas paints a shape node's path and redraws it on resize, and the snapshots and render budget hold. | DS-3, DS-4 | J-DS | DS-a, transform:DT-u |
| DS-m | A drag draws one shape node as one step through the kernel's drag rule, the spec round-trips through the file, and the SVG writes its path. | DS-5, DS-6 | MJ-DS | DS-a, transform:DT-m, eyedropper:DY-m |
| DS-z | The journey draws a star and an arrow on live services, and the feature is built. | DS-7, DS-8 | J-DS | DS-u, DS-m |

DS-u waits only on DS-a (rule 18); DS-m never waits on DS-u. MJ-DS is the
Model walk in `DesignShapeTests` (Linux).

## Journey steps

1. Press U (DS-2, `DesignShapeJourneyTests.testDrawStarAndArrow`): the Shape
   tool is active; the inspector shows the kind chips on Star, Points 5.
2. Shift-drag on the page: a five-point star in a square box, selected.
3. Drag its corner handle wider: the star stretches with its box.
4. Pick Arrow, drag: an arrow from the press to the release.
5. Export SVG: the star is a `<path>` with ten vertices (DS-6).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D35 | adds, closes with `design/shape-tools` | C | `Tests/RealJobs/design/star-badge/star-badge.jobs.json`: `shape.draw {"kind": "star", "points": 5, "innerRatio": 0.5, "x": 0, "y": 0, "w": 100, "h": 100}`, save, reopen, export SVG | `input/blank.design` |

Trap: the star reopens as a plain rectangle (the spec isn't saved), or the
SVG writes its box. Assertion: the reopened node is kind `shape` with the same
spec and the SVG path has ten vertices, the first at (50, 0). Mutation:
`DesignModel.DesignShape+Kernel.json` (spec dropped → `.specSaved`).

## Screens and states

`design-shape-options` (the chips in the inspector, light and dark),
`design-shape-star`, `design-shape-arrow`.

## Contract slice

```swift
// Sources/DesignModel/DesignNode.swift (DS-1): DesignNodeKind gains `.shape`; a stored spec, nil for other kinds.
public var shape: ShapeSpec?
// Sources/DesignModel/DesignWorkspace.swift (DS-1): DesignTool gains `.shape`; the tool's current options.
public var shapeTool: ShapeSpec
// Sources/DesignModel/DesignShape+Kernel.swift (DS-1 stubs, DS-5 bodies)
extension DesignWorkspace: ShapeTarget {
    public var shapeHelp: String? { get }
    public mutating func pickShapeTool(_ spec: ShapeSpec)
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String
}
extension DesignNode { public func path(in frame: DesignRect) -> Path? }   // the spec's path; nil for other kinds
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DS-1 | – | `DesignNodeKind.shape`, `DesignNode.shape`, `DesignTool.shape` and `shapeTool`; the adapter as stubs; `DesignShapeTests` written, disabled | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignWorkspace.swift`, `Sources/DesignModel/DesignShape+Kernel.swift`, `Tests/DesignModelTests/DesignShapeTests.swift` | – | ~180, 4 |
| DS-2 | – | The Shape tool on the palette (U) and its options in the inspector on the stubs; the journey written, skipped | `Sources/DesignApp/DesignIntent.swift`, `Sources/DesignApp/DesignShapeOptions.swift`, `Sources/DesignApp/DesignInspector.swift`, `UITests/DesignJourneyTests+Shapes.swift` | DS-1 | ~180, 4 |
| DS-3 | – | The canvas paints a shape node's path in its frame | `Sources/DesignApp/DesignCanvasMarks.swift`, `Tests/AppSnapshotTests/DesignShapePaintTests.swift` | DS-2 | ~140, 2 |
| DS-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignShapeSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignShapeTests.swift` | DS-3 | ~160, 2 |
| DS-5 | – | Adapter bodies; drawing through `ShapeRules.dragged` for every drawing tool (the local box maths deleted); the tool's dispatch; turns on `DesignShapeTests` | `Sources/DesignModel/DesignShape+Kernel.swift`, `Sources/DesignModel/DesignDrawing.swift`, `Sources/DesignModel/DesignCanvasEditing.swift`, `Tests/DesignModelTests/DesignShapeTests.swift`, `Tests/mutations/DesignModel.DesignShape+Kernel.json`, `Tests/mutations/DesignModel.DesignDrawing.json` | DS-1 | ~280, 6 |
| DS-6 | – | SVG writes a shape's path; the two specs in the catalog and id list; RJ-D35's job folder | `Sources/DesignModel/Live/DesignSVG.swift`, `Tests/DesignModelTests/DesignSVGTests.swift`, `Tests/mutations/DesignModel.DesignSVG.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/RealJobs/design/star-badge/star-badge.jobs.json`, `Tests/RealJobs/design/star-badge/input/blank.design` | DS-5 | ~180, 7 |
| DS-7 | – | The journey turned on, on live services | `UITests/DesignJourneyTests+Shapes.swift` | DS-4, DS-6 | ~50, 1 |
| DS-8 | – | `status: built`; `feature-done` | `docs/blueprints/design/features/shape-tools.wave.json` | DS-7 | ~10, 1 |

## Build waves

- Wave 1: DS-1. Independent in this wave: DS-1 alone.
- Wave 2: DS-2, DS-5. Independent in this wave: both.
- Wave 3: DS-3, DS-6. Independent in this wave: both.
- Wave 4: DS-4. Independent in this wave: DS-4 alone.
- Wave 5: DS-7. Independent in this wave: DS-7 alone.
- Wave 6: DS-8 (`feature-done`, final). Independent in this wave: DS-8 alone.

Longest chain: DS-1 → DS-2 → DS-3 → DS-4 → DS-7 → DS-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DS-1 | old files decode with no shape; `DesignShapeTests` compiles, disabled | an old file fails to open | – (stub) |
| DS-2 | `DesignToolPaletteSnapshots`: the Shape tool shows with U; its options show in the inspector on the stubs | the tool or options are missing | – (UI) |
| DS-3 | `DesignShapePaintTests`: a star node paints its path, not its box; a resize redraws it | the canvas paints the box | – (UI) |
| DS-4 | `DesignShapeSnapshots`; `RenderBudgetDesignShapeTests.starDragInThreeBodies` | budget over | – (UI) |
| DS-5 | `DesignShapeTests`: a drag draws one node of kind `shape` as one step "Draw Star"; Rectangle and Ellipse still draw their kinds through `ShapeRules.dragged` with Shift; the spec round-trips through the file | a kind, a step or a spec is wrong | `DesignModel.DesignShape+Kernel`: spec dropped → `.specSaved`; two steps per draw → `.drawIsOneStep`; `DesignModel.DesignDrawing`: Shift ignored → `.shiftSquares` |
| DS-6 | `DesignSVGTests.shapePath`; the two specs listed; RJ-D35 passes on Linux | the SVG writes a box | `DesignModel.DesignSVG`: frame written for a shape → `.shapeWritesPath`; open line closed with `Z` → `.lineIsOpen` |
| DS-7 | `testDrawStarAndArrow` steps 1 to 5 on live | a step fails | – |
| DS-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample star drag with the canvas live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignShapeTests.starDragInThreeBodies` |
| One gesture, one step | a draw is one step | `DesignShapeTests.drawIsOneStep` |
| No dead controls; keyboard parity | U picks the tool, chips by Tab | `testDrawStarAndArrow` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DS-m merged-done with RJ-D35 green in the
Linux job; DS-u's feel gate and `Mac-Finish:`; DS-z's journey on live. Then
`Belt-Contact-Sheet:` with `design-shape-*`.

## Not in this packet

Changing a drawn shape's points or sides afterwards, corner radius on
polygons, the Pen tool.
