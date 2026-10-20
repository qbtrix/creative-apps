# Feature packet: shape-tools

**Feature:** one set of shape tools for the suite: rectangle with corners,
ellipse, polygon, star, line and arrow. SuiteKernel gets a `Shapes/` module:
`ShapeSpec` (a shape's recipe in its box, so a resize redraws it and a file
keeps it editable), `ShapeRules` (the path for a spec in a box, built on
FlareCore's `PathBuilders`, plus the one drag rule every app draws with:
Shift for a square or a 45° line, Option from the centre) and two commands,
`shape.draw` and `tool.shape`. SuiteUI gets `ShapeToolOptions`: the kind chips
and each kind's rows (sides, points and inner ratio, corner radius, arrow
head), which emit `ShapeIntent`s.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/shape-tools`
**Beta:** captain, 2026-10-20 ("everyday tools, built once and shared"). Labels `beta` and `p1` when filed.

**Covers:** feature map S19 (shape tools: polygon, star, rounded rect, line,
arrow); real job RJ-X34 (new). The adopts are `flare/shape-tools`,
`halo/shape-tools` and `design/shape-tools`, each waiting on this packet's
SH-a.

**Depends on:** FlareCore's `PathBuilders.rectangle(in:cornerRadius:)`,
`ellipse(in:)`, `polygon(in:sides:)` and `star(in:points:innerRatio:)`, all on
the pinned core; no core bump. editor-kernel (built): `EditModifiers`,
`CommandSpec`, `History`. In this folder: eyedropper's **EY-z** before SH-8
(both own `FakeCanvasDocument.swift`).

**Rule 20.** One path type: FlareCore's `Path` (beta-80 plan section 8, "shape
tools use the existing PathBuilders"). Line and arrow are the only paths
`PathBuilders` lacks: `ShapeRules` builds them from `Path`'s own elements
(a two-point open path; the arrow adds a closed head), and names a follow-up
to move them into `PathBuilders` once a second caller needs them outside the
kernel. The drag rule exists twice today (`FlareModel/Live/LiveShapes.swift`'s
`draft`, `DesignModel/DesignDrawing.swift`'s rectangle branch); `ShapeRules.dragged`
is the one copy and the Flare and Design adopts delete theirs.

**Render path.** None new: each app draws a shape's `Path` the way it draws
its paths today (Flare's stage and `StageRasterizer`, Design's
`paintArtwork`, Halo's `HaloOutlines` polygon branch, which already flattens
a FlareCore `Path` for `Mask.polygon`).

**C4:** new component part `suite-kernel/kernel-shapes.json` (SH-1).
`ShapeToolOptions.swift` is a new file under `Sources/SuiteUI/`, covered by
`suiteui-sources`.

**Clean-room.** Shapes from SVG's and the apps' own geometry; no task reads
another product's code.

Blueprint sections: suiteui.md 2.2 (components), 2.5 (tool palette); suite.md
1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SH-a | The kernel's shape spec is complete and its rules, target, intents and two command specs are declared as stubs, the gallery's shape-tools page is in the index, and the checks are written, disabled. | SH-1, SH-2 | SJ0 | editor-kernel (built; SH-2 adds a page to its gallery area) |
| SH-u | On the gallery page the kind chips switch the rows, each row edits its option and shows why a value is out of range, every control identified, within the render budget. | SH-3, SH-4 | PJ1 | SH-a |
| SH-m | The rules build every kind's path in a box and the drag's box with Shift and Option, refuse out-of-range counts in words, and shape.draw adds one shape as one undo step. | SH-5, SH-6 | KJ-shapes | SH-a |
| SH-z | The gallery draws through shape.draw on a live target, the fake app keeps shape specs so RJ-X34 runs on the CLI, and the feature is built. | SH-7, SH-8, SH-9 | PJ1, KJ-shapes | SH-u, SH-m; eyedropper:EY-z (SH-8) |

SH-u waits only on SH-a (rule 18); SH-m never waits on SH-u. KJ-shapes is the
rules' and commands' Linux walk in `SuiteKernelTests`.

## Journey steps

1. Open the gallery index, click `shape-tools` (SH-2, SJ0): the kind chips
   (Rectangle, Ellipse, Polygon, Star, Line, Arrow) over an empty canvas.
2. Pick Star (SH-3, `SuiteShapeJourneyTests.testShapeToolsDrawStarAndArrow`):
   the rows show Points 5 and Inner ratio 50%. Drag on the canvas: a
   five-point star grows from the press; the log shows one `shape.draw`.
3. Set Points to 8, Shift-drag: an eight-point star in a square box.
4. Pick Arrow, drag left to right with Shift held near 40°: the arrow snaps
   to 45°; its head sits at the release point.
5. Pick Polygon and type 2 in Sides: the row clamps to 3 and shows "A polygon
   needs 3 to 64 sides." Every chip and row is reachable by Tab (SH-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X34 | adds, closes with S19 | C | `Tests/RealJobs/fake/draw-star/draw-star.jobs.json`: `shape.draw {"kind": "star", "points": 5, "innerRatio": 0.5, "x": 0, "y": 0, "w": 100, "h": 100}`, `shape.draw {"kind": "polygon", "sides": 2, …}`, `edit.undo`; the saved rects | `input/empty.fake` (no rects) |

Trap: an out-of-range count is silently clamped (a two-sided polygon becomes
a triangle), or the star is saved as a flat path and loses its points.
Assertion: the polygon call fails with "A polygon needs 3 to 64 sides." and
adds nothing; the saved star keeps `{"kind": "star", "points": 5,
"innerRatio": 0.5}`; the undo removes it (one step). Mutations:
`SuiteKernel.ShapeRules.json` (`help` accepts 2 → `.polygonNeedsThree`) and
`SuiteKernel.FakeCanvasDocument.json` (spec dropped on save →
`.shapeSpecSaved`).

## Screens and states

`suiteui-shape-tools` (the chips and the star's rows, light and dark),
`-polygon` (Sides), `-rectangle` (Corner radius), `-arrow` (Head), `-help`
(the out-of-range sentence under Sides).

## Contract slice

```swift
// Sources/SuiteKernel/Shapes/ShapeSpec.swift (SH-1, complete: plain values)
public enum ShapeKind: String, Codable, CaseIterable, Sendable { case rectangle, ellipse, polygon, star, line, arrow }
/// A drawn shape's recipe. Line and arrow ends are in the box's unit space (0...1), so a resize keeps them.
public struct ShapeSpec: Hashable, Sendable, Codable {
    public var kind: ShapeKind
    public var sides: Int, points: Int, innerRatio: Double   // polygon; star; star (0.1...1)
    public var cornerRadius: Double, head: Double            // rectangle, points; arrow head length, points
    public var start: Point, end: Point                      // line and arrow, unit space
    public static func defaults(_ kind: ShapeKind) -> ShapeSpec   // 5 sides, 5 points at 0.5, radius 0, head 12
}
// Sources/SuiteKernel/Shapes/ShapeRules.swift (SH-1 stubs throwing `ShapeRules.notBuilt`, SH-5 bodies)
public enum ShapeRules {
    public static let counts = 3...64, ratios = 0.1...1.0
    /// The spec's path in `box` (document space). Throws `GeometryError` from PathBuilders, or `invalid(help)`.
    public static func path(_ spec: ShapeSpec, in box: Rect) throws -> Path
    /// The box and line ends a drag from `from` to `to` draws: Shift a square (or a line in 45° steps),
    /// Option grows from the centre. Nil for a zero-length drag or a non-finite point.
    public static func dragged(_ kind: ShapeKind, from: Point, to: Point, modifiers: EditModifiers) -> (box: Rect, spec: ShapeSpec)?
    /// Why `spec` can't be drawn ("A polygon needs 3 to 64 sides."), nil when it can.
    public static func help(_ spec: ShapeSpec) -> String?
}
// Sources/SuiteKernel/Shapes/ShapeCommands.swift (SH-1 specs with ids, schemas and availability, runs throwing
// `ShapeRules.notBuilt`; SH-6 bodies)
public protocol ShapeTarget: Sendable {
    var shapeHelp: String? { get }                 // why nothing can be drawn now ("Open a document first.")
    var shapeTool: ShapeSpec { get }               // the shape tool's current options
    mutating func pickShapeTool(_ spec: ShapeSpec) // view state: picks the tool with these options
    /// Adds one shape layer from `spec` in `box`, selected, as one undo step named `name`; returns its id.
    mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String
}
public enum ShapeIntent: Hashable, Sendable {
    case kind(ShapeKind), sides(Int), points(Int), innerRatio(Double), cornerRadius(Double), head(Double)
    public func applied(to spec: ShapeSpec) -> ShapeSpec      // the options after the intent
    public var command: (id: String, params: JSONValue) { get }   // tool.shape with the new options
}
public enum ShapeCommands {
    public static func specs<T: ShapeTarget>(_ target: T.Type) -> [CommandSpec<T>]   // shape.draw, tool.shape
}
// Sources/SuiteUI/ShapeToolOptions.swift (SH-2 placeholder, SH-3 view)
public struct ShapeToolOptions: View {
    public init(spec: ShapeSpec, help: String?, onIntent: @escaping @MainActor (ShapeIntent) -> Void)
}
```

Commands (ids go in each adopter's `Tests/command-ids/<app>.txt`):

| id | title (undo step) | kind | params | unavailable when |
|---|---|---|---|---|
| `shape.draw` | Draw Star (the kind's name) | edit | `{kind, x, y, w, h, sides?, points?, innerRatio?, cornerRadius?, head?, x1?, y1?, x2?, y2?}` → `{id}` | `shapeHelp`; a spec with `help` throws it; w and h both 0 throws "Draw a shape larger than nothing." |
| `tool.shape` | – | view | `{kind, sides?, points?, innerRatio?, cornerRadius?, head?}` | `shapeHelp` |

The apps' existing `tool.rectangle` and `tool.ellipse` stay; `shape.draw`
with `rectangle` or `ellipse` draws the same layer they do. Flare's
`shape.add` (a raw FlareCore `Shape`) stays the low-level form.

## Pseudocode

- **path.** rectangle → `PathBuilders.rectangle(in:cornerRadius:)`; ellipse →
  `ellipse(in:)`; polygon → `polygon(in:sides:)`; star →
  `star(in:points:innerRatio:)`; line → move to `start` mapped into the box,
  line to `end`, open; arrow → the line, then a closed triangle at `end`
  pointing along the line, `head` long and `head · 0.8` wide, shortened when
  the line is shorter than twice the head.
- **dragged.** Box from the press to the pointer; Shift makes its sides
  equal (the larger one) for closed kinds, and for line and arrow rounds the
  angle to the nearest 45°; Option mirrors the drag about the press. Line and
  arrow keep their ends in unit space of the (possibly zero-height) box.
- **commands.** `shape.draw` builds the spec from the defaults plus the
  params, checks `help`, then calls `addShape` once with "Draw <Kind>";
  `tool.shape` calls `pickShapeTool`.
- **View.** `ChoiceChips` of the six kinds (SF Symbols `rectangle`,
  `circle`, `pentagon`, `star`, `line.diagonal`, `arrow.up.right`), then the
  kind's rows as `StudioScrubRow`s (Sides 3...64, Points 3...64, Inner ratio
  10...100 %, Corner radius 0...500 pt, Head 2...200 pt).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SH-1 | – | The contract: `ShapeKind` and `ShapeSpec` (complete), `ShapeRules`, `ShapeTarget`, `ShapeIntent`, the two specs with ids, schemas and availability as stubs; the new C4 part; the two suites written, disabled by name | `Sources/SuiteKernel/Shapes/ShapeSpec.swift`, `Sources/SuiteKernel/Shapes/ShapeRules.swift`, `Sources/SuiteKernel/Shapes/ShapeCommands.swift`, `Tests/SuiteKernelTests/ShapeRulesTests.swift`, `Tests/SuiteKernelTests/ShapeCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-shapes.json` | – | ~300, 6 |
| SH-2 | – | The placeholder `ShapeToolOptions`; the gallery's `shape-tools` page in `GalleryEditorKernel.pages`, its canvas drawing the drag's box on the stubs; the journey written and skipped (`XCTSkip("waits on SH-4")`) | `Sources/SuiteUI/ShapeToolOptions.swift`, `Sources/SuiteUI/Gallery/GalleryShapeTools.swift`, `Sources/SuiteUI/Gallery/GalleryEditorKernel.swift`, `UITests/SuiteJourneyTests+Shapes.swift` | SH-1 | ~200, 4 |
| SH-3 | – | The options: kind chips and each kind's rows, the help under an out-of-range value, identifiers `suite.shape.*` | `Sources/SuiteUI/ShapeToolOptions.swift`, `Tests/SuiteUITests/ShapeToolOptionsTests.swift` | SH-2 | ~240, 2 |
| SH-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteShapeToolsSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetShapeToolsTests.swift`, `UITests/SuiteJourneyTests+Shapes.swift` | SH-3 | ~200, 3 |
| SH-5 | – | `ShapeRules` bodies (paths through `PathBuilders`, line and arrow, the drag rule, the help sentences); turns on `ShapeRulesTests` | `Sources/SuiteKernel/Shapes/ShapeRules.swift`, `Tests/SuiteKernelTests/ShapeRulesTests.swift`, `Tests/mutations/SuiteKernel.ShapeRules.json` | SH-1 | ~300, 3 |
| SH-6 | – | `ShapeCommands` bodies and `ShapeIntent`; turns on `ShapeCommandsTests` on a test target | `Sources/SuiteKernel/Shapes/ShapeCommands.swift`, `Tests/SuiteKernelTests/ShapeCommandsTests.swift`, `Tests/mutations/SuiteKernel.ShapeCommands.json` | SH-5 | ~220, 3 |
| SH-7 | – | The gallery page draws through `shape.draw` on a local target with a `History` and paints each shape's `ShapeRules.path`; the live test | `Sources/SuiteUI/Gallery/GalleryShapeTools.swift`, `Tests/SuiteUITests/ShapeToolsLiveTests.swift` | SH-4, SH-6 | ~160, 2 |
| SH-8 | – | The fake app draws shapes: `FakeRect.shape` (omitted when nil), `FakeCanvasDocument` conforms and lists the specs; RJ-X34's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeShapeTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/draw-star/draw-star.jobs.json`, `Tests/RealJobs/fake/draw-star/input/empty.fake` | SH-6 | ~180, 5 |
| SH-9 | – | The C4 part names the commands and the options view; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-shapes.json`, `docs/blueprints/suiteui/features/shape-tools.wave.json` | SH-7, SH-8 | ~20, 2 |

SH-1 declares every rule and spec so SH-5 and SH-6 each fill one file.

## Build waves

- Wave 1: SH-1. Independent in this wave: SH-1 alone.
- Wave 2: SH-2, SH-5. Independent in this wave: both.
- Wave 3: SH-3, SH-6. Independent in this wave: both.
- Wave 4: SH-4, SH-8. Independent in this wave: both.
- Wave 5: SH-7. Independent in this wave: SH-7 alone.
- Wave 6: SH-9 (`feature-done`, final). Independent in this wave: SH-9 alone.

Longest chain: SH-1 → SH-2 → SH-3 → SH-4 → SH-7 → SH-9 (6). Chain of 6: the page needs the module's types, the view fills the placeholder, the budget and journey time the view, the live page draws through the command under the journey, and SH-9 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SH-1 | the two suites compile, disabled by name; `ShapeSpec` round-trips through JSON; `KernelShapeTests.importsOnlyFoundationAndFlareCore` passes over `Shapes/` | the module imports past FlareCore or a spec loses a field | – (stubs) |
| SH-2 | SJ0: the index lists `shape-tools`; the page opens | the page is missing | – (UI) |
| SH-3 | `ShapeToolOptionsTests`: picking Star shows Points and Inner ratio; a typed 2 in Sides emits `.sides(3)` and shows the help; each chip emits one `.kind` | a row is missing or an intent doubled | – (UI) |
| SH-4 | `SuiteShapeToolsSnapshots`; `RenderBudgetShapeToolsTests.pointsScrubInThreeBodies`; `testShapeToolsDrawStarAndArrow` steps 1 to 5 | budget over, or a step fails | – (UI) |
| SH-5 | `ShapeRulesTests`: a 5-point star in 100 × 100 has 10 vertices, the first at (50, 0); a hexagon's vertices lie on the inscribed ellipse; a line from (0,0) to (1,1) in a 100 × 50 box ends at (100, 50); an arrow's head tip is the line's end; Shift-drag of (40, 30) gives a 40 × 40 box; a Shift line at 40° snaps to 45°; `help` names 2 sides and 0.05 ratio | a vertex, a snap or a refusal is wrong | `SuiteKernel.ShapeRules`: `<=` for `<` on the count's low end → `.polygonNeedsThree`; Shift uses the smaller side → `.shiftSquaresToLarger`; arrow head at `start` → `.headAtEnd`; Option ignored → `.optionFromCentre` |
| SH-6 | `ShapeCommandsTests`: `shape.draw` star records one step "Draw Star" and returns the id; an out-of-range spec throws its help and records nothing; `tool.shape` changes the tool's spec and records nothing | a refused draw records a step, or the tool records one | `SuiteKernel.ShapeCommands`: help not checked → `.refusesBadSpec`; tool.shape records a step → `.toolIsViewOnly` |
| SH-7 | `ShapeToolsLiveTests`: a drag on the page draws through `shape.draw` on a local target with a `History` (one step); `testShapeToolsDrawStarAndArrow` on live | the page stays on the local log | – (UI) |
| SH-8 | `FakeShapeTests`: a drawn star saves and reopens with its spec; old jobs' JSON is unchanged; RJ-X34 passes on Linux | the spec is lost or old JSON changes | `SuiteKernel.FakeCanvasDocument`: spec dropped on save → `.shapeSpecSaved`; `shape` encoded when nil → `.oldJSONUnchanged` |
| SH-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Points scrub on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetShapeToolsTests.pointsScrubInThreeBodies` |
| render: 120-sample star drag on the gallery canvas | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetShapeToolsTests.starDragInThreeBodies` |
| One gesture, one step | a drag draws one shape as one undo step | `ShapeCommandsTests.drawIsOneStep` |
| No dead controls; keyboard and VoiceOver | every chip and row identified `suite.shape.*`, reachable by Tab; chips read their kind | `testShapeToolsDrawStarAndArrow` |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): SH-m merged-done on the Linux job with
`Mutate:` scores clean; SH-u's feel gate (`mouse`, `taste`, `job` lenses) and
its `Mac-Finish:` line; SH-z's journey on live and RJ-X34 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suiteui-shape-tools-*`.

## Adopted by

`flare/shape-tools` (polygon, star, line, arrow on the stage; RJ-F25),
`halo/shape-tools` (shape layers of every kind; RJ-H30's star),
`design/shape-tools` (a Shape tool and a shape layer kind; RJ-D35). Each waits
on SH-a.

## Not in this packet

Changing a drawn star's points or a polygon's sides afterwards (the spec is
saved, so a later packet adds a `shape.set-spec` row without a migration),
spirals, custom shape libraries, booleans (S18), the Pen tool.
