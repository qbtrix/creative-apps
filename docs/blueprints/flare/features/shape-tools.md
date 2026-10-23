# Feature packet: shape-tools (Flare)

**Feature:** Flare's stage gets a Shape tool (U) for polygons, stars, lines
and arrows beside Rectangle (R) and Ellipse (E). The tool's options (SuiteUI's
`ShapeToolOptions`) show in the inspector while it is active; a drag draws a
shape layer through the kernel's drag rule, previewed as a draft like a
rectangle. Rectangle and Ellipse draw through the same rule, so `LiveShapes`'
own box maths goes. The drawn shape is FlareCore points and a `Path`, as every
Flare shape is, so it animates, morphs and exports like the rest.
**Line:** `line:flare` · **Wave:** 6 (`waves.md`) · **Lead branch:** `lead/shape-tools`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `flare/shape-tools` (adopter of S19); real job RJ-F25
(draw a five-point star for a rating animation).

**Depends on:** `suiteui/shape-tools` **SH-a** (cross-line); FS-5 needs
**SH-m**, FS-4 **SH-u**. Same line: gradient-fill's **FG-m** before FS-6
(`FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`). Built:
live-stage (`LiveShapes`), draw-key-save (the palette), inspector-timeline.

**Hand-offs:** `FlareWorkspace.swift` (the tool enum) is also
adopt-kernel-undo's (AU-flare): FS-1's one case rebases onto it.

**Rule 20.** `LiveShapes.draft`'s Shift and Option box maths is the copy
SH-5 replaces: FS-5 calls `ShapeRules.dragged` and `ShapeRules.path` and
deletes it. The adapter is `FlareShape+Kernel.swift`; Flare keeps no spec
(its shapes are paths), so a drawn star is edited by points afterwards.

**Render path.** None new: the draft and the committed shape draw through the
stage's existing path drawing and `StageRasterizer`.

Blueprint sections: flare.md 4 (stage tools).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FS-a | The Shape tool exists with its options in the inspector, and the adapter is declared as stubs. | FS-1, FS-2 | MJ-FS | – |
| FS-u | The stage previews every kind's draft, and the snapshots and render budget hold. | FS-3, FS-4 | J-FS | FS-a |
| FS-m | Every drawing tool drafts through the kernel's drag rule and path, and a draw adds one shape layer of points and a path as one step. | FS-5, FS-6 | MJ-FS | FS-a, gradient-fill:FG-m |
| FS-z | The journey draws a star and an arrow on live services, and the feature is built. | FS-7, FS-8 | J-FS | FS-u, FS-m |

FS-u waits only on FS-a (rule 18); FS-m never waits on FS-u. MJ-FS is the
Model walk in `FlareShapeToolTests` (Linux).

## Journey steps

1. Press U (FS-2, `FlareShapeJourneyTests.testDrawStarAndArrow`): the Shape
   tool is active; the inspector shows the chips on Star, Points 5.
2. Shift-drag on the stage: a five-point star draft, then a "Star" layer.
3. Key its rotation at 0 and 1 s: it spins like any shape.
4. Pick Arrow, drag: an arrow layer from the press to the release.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F25 | closes (now `flare/shape-tools`) | C | `Tests/RealJobs/flare/rating-star/rating-star.jobs.json`: `shape.draw {"kind": "star", "points": 5, "innerRatio": 0.5, "x": 0, "y": 0, "w": 100, "h": 100}`, save, export SVG | `input/blank.flare` |

Trap: the star is drawn as a polygon with five points (the inner ratio lost)
or offset by the stage's origin. Assertion: the saved shape has ten points,
the first at (50, 0), and the SVG path matches. Mutation:
`FlareModel.FlareShape+Kernel.json` (spec's box ignored → `.drawsInBox`).

## Screens and states

`flare-shape-options` (light and dark), `flare-shape-star-draft`.

## Contract slice

```swift
// Sources/FlareModel/FlareWorkspace.swift (FS-1): FlareTool gains `.shape`; the tool's current options.
public var shapeTool: ShapeSpec
// Sources/FlareModel/FlareShape+Kernel.swift (FS-1 stubs, FS-6 bodies)
extension FlareWorkspace: ShapeTarget {
    public var shapeHelp: String? { get }
    public mutating func pickShapeTool(_ spec: ShapeSpec)
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String   // a layer of points and a Path
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FS-1 | – | `FlareTool.shape` and `shapeTool`; the adapter as stubs; `FlareShapeToolTests` written, disabled | `Sources/FlareModel/FlareWorkspace.swift`, `Sources/FlareModel/FlareShape+Kernel.swift`, `Tests/FlareModelTests/FlareShapeToolTests.swift` | – | ~130, 3 |
| FS-2 | – | The Shape tool on the palette (U) and its options in the inspector on the stubs; the journey written, skipped | `Sources/FlareApp/FlareToolItems.swift`, `Sources/FlareApp/FlareShapeOptions.swift`, `Sources/FlareApp/FlareWindow+Inspector.swift`, `UITests/FlareJourneyTests+Shapes.swift` | FS-1 | ~180, 4 |
| FS-3 | – | The stage previews every kind's draft during the drag | `Sources/FlareApp/FlareStageOverlay.swift`, `Tests/AppSnapshotTests/FlareShapeDraftTests.swift` | FS-2 | ~120, 2 |
| FS-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/FlareShapeSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareShapeTests.swift` | FS-3 | ~160, 2 |
| FS-5 | – | `LiveShapes.draft` on `ShapeRules.dragged` and `path` for every kind (its box maths deleted) | `Sources/FlareModel/Live/LiveShapes.swift`, `Tests/FlareModelTests/LiveShapesKernelTests.swift`, `Tests/mutations/FlareModel.LiveShapes.json` | FS-1 | ~200, 3 |
| FS-6 | – | Adapter bodies; the two specs in the catalog and id list; turns on `FlareShapeToolTests`; RJ-F25's job folder | `Sources/FlareModel/FlareShape+Kernel.swift`, `Tests/FlareModelTests/FlareShapeToolTests.swift`, `Tests/mutations/FlareModel.FlareShape+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/RealJobs/flare/rating-star/rating-star.jobs.json`, `Tests/RealJobs/flare/rating-star/input/blank.flare` | FS-5 | ~220, 7 |
| FS-7 | – | The journey turned on, on live services | `UITests/FlareJourneyTests+Shapes.swift` | FS-4, FS-6 | ~50, 1 |
| FS-8 | – | `status: built`; `feature-done` | `docs/blueprints/flare/features/shape-tools.wave.json` | FS-7 | ~10, 1 |

## Build waves

- Wave 1: FS-1. Independent in this wave: FS-1 alone.
- Wave 2: FS-2, FS-5. Independent in this wave: both.
- Wave 3: FS-3, FS-6. Independent in this wave: both.
- Wave 4: FS-4. Independent in this wave: FS-4 alone.
- Wave 5: FS-7. Independent in this wave: FS-7 alone.
- Wave 6: FS-8 (`feature-done`, final). Independent in this wave: FS-8 alone.

Longest chain: FS-1 → FS-2 → FS-3 → FS-4 → FS-7 → FS-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FS-1 | `FlareShapeToolTests` compiles, disabled; the tool enum has `.shape` | – | – (stub) |
| FS-2 | `FlareToolPaletteSnapshots`: the Shape tool shows with U; its options show in the inspector on the stubs | the tool or options are missing | – (UI) |
| FS-3 | `FlareShapeDraftTests`: a star draft previews on the stage during the drag | the draft is a box | – (UI) |
| FS-4 | `FlareShapeSnapshots`; `RenderBudgetFlareShapeTests.starDragInThreeBodies` | budget over | – (UI) |
| FS-5 | `LiveShapesKernelTests`: every kind's draft is `ShapeRules.path` of `ShapeRules.dragged`; Rectangle with Shift still squares; existing `LiveShapesTests` pass unchanged | a draft differs or an old test breaks | `FlareModel.LiveShapes`: Option ignored → `.optionFromCentre`; line drawn closed → `.lineIsOpen` |
| FS-6 | `FlareShapeToolTests`: `addShape` adds one layer as one step with the path's points; the two specs listed; RJ-F25 passes on Linux | a point, a step or an id is wrong | `FlareModel.FlareShape+Kernel`: box ignored → `.drawsInBox`; two steps → `.drawIsOneStep` |
| FS-7 | `testDrawStarAndArrow` steps 1 to 4 on live | a step fails | – |
| FS-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample star drag on the stage | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetFlareShapeTests.starDragInThreeBodies` |
| One gesture, one step | a draw is one step | `FlareShapeToolTests.drawIsOneStep` |
| No dead controls; keyboard parity | U picks the tool, chips by Tab | `testDrawStarAndArrow` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): FS-m merged-done with RJ-F25 green in the
Linux job; FS-u's feel gate and `Mac-Finish:`; FS-z's journey on live. Then
`Belt-Contact-Sheet:` with `flare-shape-*`.

## Not in this packet

A parametric star whose points key over time (shape morph covers it, E14),
spirals.
