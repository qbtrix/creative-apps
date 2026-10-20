# Feature packet: shape-tools (Halo)

**Feature:** Halo's shape layers take every shape kind: rectangle with
corners, ellipse (today's only shape), polygon, star, line and arrow. A Shape
button by the viewer picks the kind and its options (SuiteUI's
`ShapeToolOptions` in a popover); a drag in the viewer draws a new shape layer
whose `ShapeSpec` is saved, so a resize redraws it. The frame renderer draws
the spec's path through `HaloOutlines`' polygon branch, which already
flattens a FlareCore `Path`.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/shape-tools`
**Beta:** captain, 2026-10-20 (map weight high). Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/shape-tools` (adopter of S19); real job RJ-H35
(new: a six-point star layer by command, rendered). RJ-H30 (a star with a
gradient fill and a stroke) closes with `halo/stroke-style`.

**Depends on:** `suiteui/shape-tools` **SH-a** (cross-line); HS-5 needs
**SH-m**, HS-4 **SH-u**. Same line: gradient-fill's **HG-a** and transform's
**HT-a** before HS-1 and HS-2 (`HaloLayer.swift`, `HaloViewer.swift`);
transform's **HT-m** before HS-6 (the catalog and id list). Built: foundation,
viewer-playback, layer-keys, core-loop.

**Rule 20.** No Halo shape geometry: `HaloLayer.shape` is the kernel's
`ShapeSpec` (nil keeps today's ellipse, so old projects draw unchanged), the
path is `ShapeRules.path`, the drag is `ShapeRules.dragged`. The adapter is
`HaloShape+Kernel.swift`.

**Render path.** `HaloOutlines.outline(of:)` returns the spec's flattened
polygon for a shape layer with a spec; the rest of `LiveFrameRendering` is
unchanged, so the viewer and Render… draw the same.

Blueprint sections: halo.md 4 (layers), 5 (viewer), 7 (render).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HS-a | Shape layers carry a spec, the adapter is declared as stubs, and the Shape button and its options show by the viewer. | HS-1, HS-2 | MJ-HS | gradient-fill:HG-a, transform:HT-a |
| HS-u | A viewer drag draws a shape layer with a live draft, and the snapshots and render budget hold. | HS-3, HS-4 | J-HS | HS-a |
| HS-m | A draw adds one shape layer as one step and the renderer draws its spec's path, today's ellipse kept for old layers. | HS-5, HS-6 | MJ-HS | HS-a, transform:HT-m |
| HS-z | The journey draws and renders a star layer on live services, and the feature is built. | HS-7, HS-8 | J-HS | HS-u, HS-m |

HS-u waits only on HS-a (rule 18); HS-m never waits on HS-u. MJ-HS is the
Model walk in `HaloShapeTests` (Linux).

## Journey steps

1. Click the Shape button by the viewer, pick Star, Points 6 (HS-2,
   `HaloShapeJourneyTests.testDrawStarLayer`).
2. Drag in the viewer: a new "Star" shape layer, selected, drawn as a star.
3. Scrub its Scale X in the inspector: the star stretches.
4. Render frame 0 (HS-6): the PNG shows the star.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H35 | adds, closes with `halo/shape-tools` | C | `Tests/RealJobs/halo/star-layer/star-layer.jobs.json`: `shape.draw {"kind": "star", "points": 6, "innerRatio": 0.5, "x": 760, "y": 340, "w": 400, "h": 400}`, `render.frame {"frame": 0}` | `input/empty-1080p.halo` |

Trap: the shape renders as an ellipse (the spec is ignored by the renderer).
Assertion: the frame's pixel at the star's top point (960, 345) is the layer
colour and the pixel between two outer points on the ellipse's rim is not.
Mutation: `HaloModel.HaloOutlines.json` (spec ignored → `.specDrawsPath`).

## Screens and states

`halo-shape-tool` (the popover, light and dark), `halo-shape-star` (the
viewer).

## Contract slice

```swift
// Sources/HaloModel/HaloLayer.swift (HS-1): stored, omitted when nil (today's ellipse).
public var shape: ShapeSpec?
// Sources/HaloModel/HaloShape+Kernel.swift (HS-1 stubs, HS-5 bodies)
extension HaloProject: ShapeTarget {
    public var shapeHelp: String? { get }                   // "Make a composition first."
    public var shapeTool: ShapeSpec { get }
    public mutating func pickShapeTool(_ spec: ShapeSpec)
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HS-1 | – | `HaloLayer.shape` (omitted when nil); the adapter as stubs; `HaloShapeTests` written, disabled | `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/HaloShape+Kernel.swift`, `Tests/HaloModelTests/HaloShapeTests.swift` | – | ~140, 3 |
| HS-2 | – | The Shape button and its options popover by the viewer on the stubs; the journey written, skipped | `Sources/HaloApp/HaloShapeTool.swift`, `Sources/HaloApp/HaloViewer.swift`, `UITests/HaloJourneyTests+Shapes.swift` | HS-1 | ~160, 3 |
| HS-3 | – | A viewer drag with the tool on draws on release; the draft previews; Escape cancels | `Sources/HaloApp/HaloShapeTool.swift`, `Tests/AppSnapshotTests/HaloShapeToolTests.swift` | HS-2 | ~180, 2 |
| HS-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/HaloShapeSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloShapeTests.swift` | HS-3 | ~160, 2 |
| HS-5 | – | Adapter bodies and `HaloOutlines` drawing the spec's path; turns on `HaloShapeTests` | `Sources/HaloModel/HaloShape+Kernel.swift`, `Sources/HaloModel/Live/HaloOutlines.swift`, `Tests/HaloModelTests/HaloShapeTests.swift`, `Tests/mutations/HaloModel.HaloShape+Kernel.json`, `Tests/mutations/HaloModel.HaloOutlines.json` | HS-1 | ~240, 5 |
| HS-6 | – | The two specs in the catalog and id list; RJ-H35's job folder | `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/HaloModelTests/HaloShapeCommandIDTests.swift`, `Tests/RealJobs/halo/star-layer/star-layer.jobs.json`, `Tests/RealJobs/halo/star-layer/input/empty-1080p.halo` | HS-5 | ~120, 5 |
| HS-7 | – | The journey turned on, on live services | `UITests/HaloJourneyTests+Shapes.swift` | HS-4, HS-6 | ~50, 1 |
| HS-8 | – | `status: built`; `feature-done` | `docs/blueprints/halo/features/shape-tools.wave.json` | HS-7 | ~10, 1 |

## Build waves

- Wave 1: HS-1. Independent in this wave: HS-1 alone.
- Wave 2: HS-2, HS-5. Independent in this wave: both.
- Wave 3: HS-3, HS-6. Independent in this wave: both.
- Wave 4: HS-4. Independent in this wave: HS-4 alone.
- Wave 5: HS-7. Independent in this wave: HS-7 alone.
- Wave 6: HS-8 (`feature-done`, final). Independent in this wave: HS-8 alone.

Longest chain: HS-1 → HS-2 → HS-3 → HS-4 → HS-7 → HS-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HS-1 | old projects decode with no spec; `HaloShapeTests` compiles, disabled | an old project fails | – (stub) |
| HS-2 | `HaloViewerSnapshots`: the Shape button and its popover show on the stubs | the button is missing | – (UI) |
| HS-3 | `HaloShapeToolTests`: a viewer drag with the tool on emits one draw on release; Escape cancels | a draw is doubled | – (UI) |
| HS-4 | `HaloShapeSnapshots`; `RenderBudgetHaloShapeTests.starDragInThreeBodies` | budget over | – (UI) |
| HS-5 | `HaloShapeTests`: `addShape` adds one shape layer as one step at the playhead's span; `HaloOutlines` gives a 12-vertex polygon for a six-point star and today's ellipse for no spec | a layer, a step or an outline is wrong | `HaloModel.HaloOutlines`: spec ignored → `.specDrawsPath`; `HaloModel.HaloShape+Kernel`: two steps → `.drawIsOneStep` |
| HS-6 | the two specs listed; RJ-H35 passes on Linux | an id is missing | – (registration) |
| HS-7 | `testDrawStarLayer` steps 1 to 4 on live | a step fails | – |
| HS-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample star drag in the viewer | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetHaloShapeTests.starDragInThreeBodies` |
| One gesture, one step | a draw is one step | `HaloShapeTests.drawIsOneStep` |
| No dead controls; keyboard parity | the button and popover rows by Tab | `testDrawStarLayer` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HS-m merged-done with RJ-H35 green in the
Linux job; HS-u's feel gate and `Mac-Finish:`; HS-z's journey on live. Then
`Belt-Contact-Sheet:` with `halo-shape-*`.

## Not in this packet

Keyframed shape morphs (E14), changing a drawn star's points afterwards.
