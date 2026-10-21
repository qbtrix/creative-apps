# Feature packet: pen-paths (Design)

**Feature:** Design's Pen (P) works. Click for corners, drag for smooth
points, click the first anchor to close, Return to leave a path open; the
path becomes a Design layer with the fill and stroke rows every shape has.
Double-click a path (or press Return with it selected) to edit its points:
drag anchors and handles, Option-drag to break a handle, click the path with
the Pen to add a point, Delete to remove one. All of it is SuiteKernel's
`PenRules`, `AnchorEdit` and `PathCommands` drawn by SuiteUI's
`PathEditOverlay`, so the CLI and an agent draw and edit paths the way the
canvas does. Paths paint on the canvas, in PNG and PDF, and export to SVG.
The blueprint's "Pen (P) is disabled" line is reversed (captain, 2026-10-20).
**Line:** `line:design` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/pen-paths`
**Beta:** captain, 2026-10-20 ("the Pen goes into the beta for Design").
Labels `beta` and `p1` when filed.

**Covers:** feature map `design/pen-paths` (adopter of S25); real job RJ-D06
(draw a logo with the pen, close it, move one point; re-placed from `J` to
`C`, since its outcome is the saved path); design.md's Pen rows (Tools,
"Tier 2, wave 3", the S5 gap row).

**Depends on:** `suiteui/pen-paths` **PN-a** (cross-line: the `Paths/`
module, `PathEditTarget`, the specs, the overlay and marks stubs). DP-6
needs its real commands (**PN-7**), DP-4 the real overlay (**PN-3**) for its
snapshots, and every task the core bump PN-1 waits on. **DP-7 waits on a
creative-core issue (to file): make `SVGExporter.pathData(_:)` public** (it is
`static` and internal on the pin and on core `dev`), then a core bump; no
copy of it here. Same line, the last owner of each shared file:
placed-images **PD-a** (`DesignNode.swift`), **PD-u**
(`DesignCanvasMarks.swift`), **PD-m** (`DesignSVG.swift`); shape-tools
**DS-a** (`DesignWorkspace.swift`) and **DS-m** (`DesignCanvasEditing.swift`);
stroke-style **DK-m** (`StyleTypes.swift`, `UseCases.swift`); design-export
**DE-a** (`DesignServices.swift`); file-flow **DF-m** (the catalog and its id
list) and **DF-z** (`design.md`). design-seams-2 (p3, cut) now waits on this
feature: its S2-a and S2-b reopen four of these files.

**Hand-offs** (cross-line files; the lead checks each before the task):
`DesignCommandCatalogTests.swift` is adopt-command-catalog's AC-design and
`DesignDocumentTests.swift` adopt-kernel-session's AD-design: DP-1 starts
after AC-design's `Belt-Slice-Done:`, DP-2 after AD-design's.

**Rule 20.** No Design path model. `DesignAnchor`, `DesignPath`, the
`PathDrawing` protocol, its `NotBuilt` conformance and `DesignServices.pen`
are deleted in DP-2: they were the tier-2 seam's guess at a pen, a second
anchors type beside FlareCore's. `DesignNode.path` is the kernel's
`VectorPath` (FlareCore's `Path`) and `DesignPen+Kernel.swift` is the only new
Model file.

**Geometry.** A path node stores its path relative to its frame's origin;
the frame is `Path.bounds` (FlareCore, at the pin: the curves' extrema, not
the handles), so the selection box hugs the curve. A resize maps the path
from the old frame to the new (an axis with zero extent, a straight
horizontal line, keeps that axis). Hit testing on the canvas is FlareCore's
`Shape.hits` for a filled path and `Path.nearest` within the hit slop for an
open one.

**Render path.** `paintArtwork` (canvas, PNG through `DesignRasterizer`, PDF)
adds a `.path` branch that fills and strokes `node.path` with the node's
fill (and gradient, gradient-fill's DG-3) and stroke (stroke-style's DK-*),
so the three share one painter as today. SVG writes `<path d>` from
FlareCore's path data writer once public.

Blueprint sections: design.md 1 (first cut), 2 (Tools), 5.4, 8.2 (the
`PathDrawing` contract, replaced), the gap table.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DP-a | `DesignNodeKind.path` and `DesignNode.path` exist and save, `DesignWorkspace` conforms to `PathEditTarget` as stubs, the old path seam is gone, and P is enabled with the overlay drawing on the stubs. | DP-1, DP-2, DP-3 | MJ-DP | suiteui/pen-paths PN-a (cross-line); placed-images:PD-a, shape-tools:DS-a (DP-1); stroke-style:DK-m, design-export:DE-a (DP-2); shape-tools:DS-m, placed-images:PD-u (DP-3) |
| DP-u | The canvas, PNG and PDF paint path nodes, point editing shows on double-click, and the pen's snapshots and render budget hold. | DP-4, DP-5 | DJ-P1 | DP-a; PN-3 (DP-4, cross-line) |
| DP-m | Every path command runs on Design's page as one undo step and the SVG export writes each path with the points the canvas draws. | DP-6, DP-7 | MJ-DP | DP-a; PN-7 (DP-6, cross-line); file-flow:DF-m (DP-6); placed-images:PD-m and the core path-data issue (DP-7) |
| DP-z | The journey passes on live services, and the blueprint says the Pen is in the first cut. | DP-8, DP-9 | DJ-P1 | DP-u, DP-m; file-flow:DF-z (DP-9) |

DP-a carries the first UI task (DP-3: P on the rail, drawing on the stubs);
DP-u waits only on DP-a (rule 18) and DP-m never waits on DP-u. MJ-DP is the
Model walk in `DesignPenTests` (Linux).

## Journey steps

1. Press P (DP-3, `DesignPenJourneyTests.testDrawLogoAndMovePoint`): the Pen
   is chosen, no "isn't built yet" tooltip.
2. Click three corners and drag a fourth into a curve inside the frame: the
   rubber band follows the pointer; the curve's handles show.
3. Click the first anchor: the path closes, it is selected as "Path 1" in
   the layers panel, and the tool returns to Move (Design's one-shape rule).
4. Double-click the path: its four anchors show. Drag the smooth one 30 pt:
   its handles move with it, the rest stay. Undo: one step.
5. Fill it red from the Fill row; export SVG (DP-7): the file's `<path>` is
   closed (`Z`) with four anchors.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D06 | closes (now `S25`; re-placed `J` → `C`) | C | `Tests/RealJobs/design/pen-logo/pen-logo.jobs.json`: three `path.pen-add`, one with an out handle, a fourth corner, `path.close`, `path.anchor-select` the smooth anchor, `path.anchor-move` 30, 0; save | `input/blank.design` (one page, one 400 × 300 frame) |

Trap: closing adds a duplicate point at the start, so the saved path has five
anchors and a zero-length segment. Assertion: the saved node's path has one
closed contour of exactly four anchors, the moved anchor's handles moved by
the same 30 pt, and the other three anchors are unchanged. Mutations: the trap itself is
caught in the shared rules, `SuiteKernel.PenRules.json`'s "close appends the
first point" → `PenRulesTests.closeAddsNoPoint` (suiteui PN-5); Design's own
is `DesignModel.DesignPen+Kernel.json`'s "the path stored in page space, not
node space" → `DesignPenTests.moveKeepsPath`, which fails the "others
unchanged" assertion.

## Screens and states

`design-pen-drawing` (three anchors and the rubber band), `design-pen-closed`
(the closed path selected), `design-pen-edit-points` (point editing, one
anchor selected with handles), light and dark.

## Contract slice

```swift
// Sources/DesignModel/DesignNode.swift (DP-1): one kind, one stored field, omitted from JSON when nil.
public enum DesignNodeKind { ... case path }            // icon "point.bottomleft.forward.to.point.topright.scurvepath"
public var path: VectorPath?                            // relative to frame.origin; nil for every other kind
// Sources/DesignModel/DesignWorkspace.swift (DP-1): the pen and point-edit state, view state outside History.
public internal(set) var penDraft: PenDraft?
public internal(set) var anchorSelection: Selection<AnchorRef>
public private(set) var editingPathID: String?          // the path whose points show; nil outside point editing
// Sources/DesignModel/DesignPen+Kernel.swift (DP-1 stubs, DP-6 bodies)
extension DesignWorkspace: PathEditTarget {
    public var pathInEdit: PathInEdit? { get }          // editingPathID's node, toDocument = translate(frame.origin)
    public var pathHelp: String? { get }                // "Unlock <layer> to draw on it." / no page
    public mutating func addPath(_ path: VectorPath, name: String) throws -> String
    public mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws
    public mutating func runPath(_ intent: PathIntent)  // the intent's command through `catalog`
    public mutating func editPoints(_ id: String?)      // enter (a path id) or leave (nil) point editing
}
extension DesignNode { public static func pathNode(_ path: VectorPath, id: String, name: String) -> DesignNode? } // frame = bounds
```

## Pseudocode

- **addPath.** `bounds = path.bounds` (nil or non-finite: refuse with
  `PenRules.degenerate`); store `path` translated by `-bounds.origin`; frame
  `bounds`; insert above the selected layer inside its frame (Design's draw
  rule); select it; tool back to Move; one "Add Path" step.
- **setPath.** Map the path from document to node space; recompute the frame
  from `bounds`; one step through the workspace's edit path, `drag` as its
  fold key. A locked node refuses with its help.
- **resize.** In the existing resize path, a `.path` node maps its points by
  the frame's scale per axis (zero-extent axis kept).
- **SVG.** A path node writes `<path d="…" transform="translate(x y)"/>`
  with its fill and stroke attributes, `d` from FlareCore's public writer.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DP-1 | – | `.path` kind and `DesignNode.path`; the pen and point-edit state; the conformance, `runPath` and `editPoints` as stubs; the `tool.pen` help line on; `DesignPenTests` and `DesignSVGPathTests` written, disabled | `Sources/DesignModel/DesignNode.swift`, `Tests/mutations/DesignModel.DesignNode.json`, `Sources/DesignModel/DesignWorkspace.swift`, `Tests/mutations/DesignModel.DesignWorkspace.json`, `Sources/DesignModel/DesignPen+Kernel.swift`, `Tests/DesignModelTests/DesignCommandCatalogTests.swift`, `Tests/DesignModelTests/DesignPenTests.swift`, `Tests/DesignModelTests/DesignSVGPathTests.swift` | PN-a, placed-images:PD-a, shape-tools:DS-a | ~280, 8 |
| DP-2 | – | The old path seam goes: `DesignAnchor`, `DesignPath`, `PathDrawing`, its `NotBuilt` conformance and `services.pen`; the contract test's pen lines and the `UseCases` plan's `PathDrawing` entry go with them | `Sources/DesignModel/Contracts/StyleTypes.swift`, `Tests/mutations/DesignModel.StyleTypes.json`, `Sources/DesignModel/Contracts/UseCases.swift`, `Tests/mutations/DesignModel.UseCases.json`, `Sources/DesignModel/NotBuilt.swift`, `Tests/mutations/DesignModel.NotBuilt.json`, `Sources/DesignModel/DesignServices.swift`, `Tests/mutations/DesignModel.DesignServices.json`, `Tests/DesignModelTests/DesignDocumentTests.swift` | stroke-style:DK-m, design-export:DE-a | ~120, 9 |
| DP-3 | – | P enabled: the canvas's pen route and double-click to edit points go to `runPath` and `editPoints` on the stubs; `PathEditOverlay` in the canvas marks; `DesignPathArtwork` as a stub that strokes the path in the ink colour, called from `paintArtwork` | `Sources/DesignModel/DesignCanvasEditing.swift`, `Tests/mutations/DesignModel.DesignCanvasEditing.json`, `Sources/DesignApp/DesignCanvasMarks.swift`, `Sources/DesignApp/DesignPathArtwork.swift`, `Tests/DesignModelTests/DesignPenRouteTests.swift` | DP-1, shape-tools:DS-m, placed-images:PD-u | ~220, 5 |
| DP-4 | – | `paintArtwork` paints `.path` nodes (fill, gradient, stroke) for canvas, PNG and PDF; the journey written | `Sources/DesignApp/DesignPathArtwork.swift`, `Tests/AppSnapshotTests/DesignPenPaintTests.swift`, `UITests/DesignJourneyTests+Pen.swift` | DP-3, PN-3 | ~200, 3 |
| DP-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignPenSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignPenTests.swift` | DP-4 | ~180, 2 |
| DP-6 | – | Adapter bodies (add, set, resize, bounds); the twelve specs in the catalog, the id list and the CLI golden; RJ-D06's job folder; turns on `DesignPenTests` | `Sources/DesignModel/DesignPen+Kernel.swift`, `Tests/DesignModelTests/DesignPenTests.swift`, `Tests/mutations/DesignModel.DesignPen+Kernel.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/mutations/DesignModel.DesignCommandCatalog.json`, `Tests/command-ids/design.txt`, `Tests/AfterGlowCLITests/Golden/apps/design.list-commands.json`, `Tests/RealJobs/design/pen-logo/pen-logo.jobs.json`, `Tests/RealJobs/design/pen-logo/input/blank.design` | DP-1, PN-7, file-flow:DF-m | ~320, 9 |
| DP-7 | – | SVG paths through FlareCore's public path data; turns on `DesignSVGPathTests` | `Sources/DesignModel/Live/DesignSVG.swift`, `Tests/DesignModelTests/DesignSVGPathTests.swift`, `Tests/mutations/DesignModel.DesignSVG.json` | DP-1, placed-images:PD-m, core path-data issue | ~120, 3 |
| DP-8 | – | Live: the journey runs on live services and turned on | `UITests/DesignJourneyTests+Pen.swift` | DP-5, DP-6 | ~60, 1 |
| DP-9 | – | `design.md`: the Pen rows say built, the tier-2 line and the gap row move; `status: built`; `feature-done` | `docs/blueprints/design.md`, `docs/blueprints/design/features/pen-paths.wave.json` | DP-8, DP-7, file-flow:DF-z | ~40, 2 |

The painter goes in a new `DesignPathArtwork.swift` (rule (b): split the
file rather than chain DP-4 behind every `DesignCanvasMarks.swift` owner);
DP-3 adds it as a stub and its one call, DP-4 fills it.

## Build waves

- Wave 1: DP-1, DP-2. Independent in this wave: both.
- Wave 2: DP-3, DP-6, DP-7. Independent in this wave: all three.
- Wave 3: DP-4. Independent in this wave: DP-4 alone.
- Wave 4: DP-5. Independent in this wave: DP-5 alone.
- Wave 5: DP-8. Independent in this wave: DP-8 alone.
- Wave 6: DP-9 (shared prose, `feature-done`, final). Independent in this wave: DP-9 alone.

Longest chain: DP-1 → DP-3 → DP-4 → DP-5 → DP-8 → DP-9 (6). Chain of 6: the
route needs the field and the stubs, the painter draws what the route
commits, the budget times the painter, the journey runs on it live, DP-9 is
the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DP-1 | old files decode (no `path` key); `DesignNode` with a path round-trips; `DesignCommandCatalogTests` reads `tool.pen` on; `DesignPenTests` compiles, disabled | an old file fails to open, or P still says "isn't built yet" | – (stub) |
| DP-2 | the Design Model and its tests build with no `DesignPath`, `DesignAnchor` or `PathDrawing` left (`git grep` in the PR is empty); `scripts/mutate --validate` passes over the four plans | a reference or a stale plan anchor is left | – (deletion) |
| DP-3 | `DesignCanvasHintsTests` (existing) and `DesignPenRouteTests`: a P click on the stubs calls `runPath(.penAdd)`, a double-click on a path node calls `editPoints` with its id | the route stays a no-op | – (UI) |
| DP-4 | `DesignPenPaintTests`: a closed red path paints red inside and the page colour outside its curve, and its stroke along an open path | the painter skips `.path` | – (UI) |
| DP-5 | `DesignPenSnapshots`; `RenderBudgetDesignPenTests.anchorDragInThreeBodies` | budget over | – (UI) |
| DP-6 | `DesignPenTests`: `path.close` after four adds stores four anchors and selects "Path 1"; the frame equals `Path.bounds` for a curve whose handles reach outside it; a resize keeps the anchors in place relative to the frame; a locked parent refuses with its help; an anchor drag of 120 samples is one step; RJ-D06 passes on Linux | a frame, a step count or a refusal is wrong | `DesignModel.DesignPen+Kernel`: frame from control points → `.frameHugsCurve`; path stored in page space, not node space → `.moveKeepsPath`; drag token dropped → `.dragIsOneStep` |
| DP-7 | `DesignSVGPathTests`: a closed path writes `d` ending in `Z` with its four anchors and the node's translate; an open one has no `Z` | the export drops a path or closes an open one | `DesignModel.DesignSVG`: translate not written → `.pathAtItsFrame`; `Z` always written → `.openPathStaysOpen` |
| DP-8 | `DesignPenJourneyTests.testDrawLogoAndMovePoint` steps 1 to 5 on live | a step fails | – |
| DP-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample anchor drag in point editing | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignPenTests.anchorDragInThreeBodies` |
| render: 120-sample pen rubber band | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignPenTests.rubberBandInThreeBodies` |
| One gesture, one step | a pen path (close or Return), an anchor drag, a handle drag | `DesignPenTests.dragIsOneStep` |
| No dead controls; keyboard parity | P works, Return and Escape end a path, arrows nudge points | `testDrawLogoAndMovePoint` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DP-m merged-done with RJ-D06 green in the
Linux job; DP-u's feel gate and `Mac-Finish:`; DP-z's journey on live. Then
`Belt-Contact-Sheet:` with `design-pen-*`.

## Not in this packet

Booleans (S18, RJ-D07), outline stroke, a pencil, path text, a Direct Select
tool on Design's rail (point editing is the double-click mode), components
holding paths beyond what nodes already do.
