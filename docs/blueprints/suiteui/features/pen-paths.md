# Feature packet: pen-paths

**Feature:** one Pen and one point editor for the suite. SuiteKernel gets a
`Paths/` module: FlareCore's anchors view (`PathAnchor`, `PathContour`,
`AnchorKind`) under kernel names, `PenRules` (Flare's working Pen moved in:
click a corner, drag a smooth point, click the first anchor to close, Return
to finish), `AnchorEdit` (move points with their handles, drag a handle with
its partner kept, Option to break it, insert, remove and convert points on
FlareCore's path ops), `AnchorIndex` (hover, hit and marquee over thousands of
anchors in constant time per query), and `PathCommands`, the twelve path
commands every app registers. SuiteUI gets one `PathEditOverlay`: the pen's
rubber band, the anchors and handles with hover and selected states, the
cursor hints, and the gestures, which emit `PathIntent`s, each one a path
command the app runs through its catalog.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/pen-paths`
**Beta:** captain, 2026-10-20 (the Pen goes into the beta for Design, shared
from Flare). Labels `beta` and `p1` when filed.

**Covers:** feature map S25 (new: the Pen and point editing; S18 keeps the
booleans); real job RJ-X37 (new). The adopts are `design/pen-paths` (enable
P, paths as Design nodes, SVG and PDF; closes RJ-D06) and `flare/pen-paths`
(Flare's Pen onto the kernel, behaviour unchanged; Direct Select drags
anchors; closes RJ-F27), each waiting on this packet's PN-a. Halo has no
adopt: it draws no paths (its polygons are masks, shape-tools' adopt).
adopt-kernel-brush's line "Design's pen ... on the same module" means a
freehand pencil on the brush stroke model, not this tool.

**Depends on:**
- **creative-core path-geometry (#430, built) and a core bump in
  creative-apps to ≥ `e09c6c30`.** The pinned core (`0de5687d`) has no
  `Sources/FlareCore/PathOps/`; core `dev` has it from `87b122b7` (#723: the
  anchors view, `nearest`, `inserting`, `removingAnchor`, `converting`)
  through `e09c6c30` (#755). PN-1 waits on the bump (a `chore(core): bump
  creative-core` PR like #3126); stroke-style's SS-7 shares it. Exact curve
  bounds are already at the pin (`Path.bounds`, `ShapeBounds.swift`: the
  extrema, not the handles), so Design's "needs exact curve bounds" blocker
  is met.
- In this folder: command-catalog's **CC-run** before PN-7 (a catalog run
  records one undo step per edit, the drag-token fold); export-pack's
  **XP-a** before PN-2 (the last owner of `SuiteGallery.swift`, after
  tone-controls' TC-a, the last owner of `Tests/canonical-concepts.txt`);
  export-pack's **XP-z** before PN-9 (the last owner of
  `FakeCanvasDocument.swift`). editor-kernel (built): `Selection`,
  `History`, `CommandSpec`, `SnapLines`. canvas-marks (built): `PathMarks`.

**Rule 20.** One path model: FlareCore's `Path` and its anchors view, which
Flare already stores, every exporter already writes, and the beta-80 kernel
decision 2 keeps in FlareCore (SuiteKernel and DesignModel link it). The
kernel adds the tool, not a type. Two copies go: Flare's pen rules
(`LiveShapes.pen`, its handle helpers and the fake's pen half) move into
`PenRules`, and Design's `DesignAnchor`, `DesignPath` and `PathDrawing` are
deleted by its adopt. PN-2 adds `Pen: PenDraft PenRules PenTool` to
`Tests/canonical-concepts.txt` (dry-run on `dev`: no file matches today), so
`scripts/check-dup-logic` fails an app pen copy; the adopts' files are
`<X>Pen+Kernel.swift`. SuiteUI's mark-only `PathAnchor` (CGPoint, corner or
smooth) stays for its snapshots; `PathMarks` gains an init from the kernel's
contours, the only one the apps call. Snapping is the kernel's `SnapLines`
with each other anchor as a zero-size candidate; no anchor snap code.

**Perf (the VectorCraft lesson).** Selecting many anchors must stay fast.
`Selection.contains` is `ordered.contains` today, linear, so a marquee over
5,000 anchors that checks each one is 25 million compares. PN-6 keeps a `Set`
beside `ordered` in the kernel's `Selection` (every app benefits) and puts
hover, hit and marquee on `AnchorIndex`, a 64-point grid built once per
gesture. The budget is 5,000 anchors, the size of `FlareFixtures.stress`
(500 ten-point stars) on branch `test/stress-perf-journeys`, whose real-app
gate fails a gesture over a 33 ms step p95; the Flare adopt runs it on anchors.

**Render path.** None new. The overlay draws marks only (`PathMarks`,
CoreGraphics in a `Canvas`); each app paints the path itself the way it
paints shapes now (Flare's stage and `StageRasterizer`, Design's
`paintArtwork`), with stroke from stroke-style (SS-*) and fill from
gradient-fill (GF-*). SVG path data is FlareCore's job: `SVGExporter.pathData`
is internal on the pin and on core `dev`, so a core issue makes it public
(Design's DP-6 waits on it); this packet writes no copy.

**C4:** new component part `suite-kernel/kernel-paths.json` (PN-1).
`PathEditOverlay.swift` and the gallery page are new files in
`Sources/SuiteUI/`, covered by `suiteui-sources`.

**Clean-room.** Pen behaviour from Flare's own code and the HIG; geometry
from FlareCore. No task reads another product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets), 7.5 (feel);
suite.md 1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PN-a | The kernel's `Paths/` module declares every type, rule, intent and command spec as stubs, the gallery's `pen-paths` page is in the index, and the checks are written, disabled. | PN-1, PN-2 | SJ0 | core bump (PN-1, cross-repo); export-pack:XP-a (PN-2) |
| PN-u | On the gallery page the Pen draws corners and smooth points with a rubber band and closes on the first anchor, and a selected path shows its anchors and handles with hover and selected states, every control identified, within the render budget. | PN-3, PN-4 | PJ1 (`SuitePenPathsJourneyTests.testPenDrawsAndEditsAPath`) | PN-a |
| PN-m | The pen rules match Flare's today, anchor edits keep handles with their points and smooth handles collinear, selecting and moving 5,000 anchors stays inside its budget, and every path command records exactly one undo step (a drag one). | PN-5, PN-6, PN-7 | KJ-paths | PN-a; command-catalog:CC-run (PN-7) |
| PN-z | The gallery runs its intents through `PathCommands` on a live target, the fake app takes paths so RJ-X37 runs on the CLI, and the feature is built. | PN-8, PN-9, PN-10 | PJ1, KJ-paths | PN-u, PN-m; export-pack:XP-z (PN-9) |

PN-u waits only on PN-a (rule 18); PN-m never waits on PN-u. KJ-paths is the
rules' and commands' Linux walk in `SuiteKernelTests`.

## Journey steps

1. Open the gallery index, click `pen-paths` (PN-2, SJ0): an empty canvas
   with the Pen chosen and a sample path beside it.
2. Click three places (PN-3, `testPenDrawsAndEditsAPath`): three corner
   anchors joined by lines; the rubber band follows the pointer from the last
   one. The log shows three `path.pen-add`.
3. Press and drag at a fourth place: a smooth anchor with mirrored handles.
4. Hover the first anchor (the close ring shows), click it: the path closes;
   the log shows one `path.close` and one undo step named "Add Path".
5. Marquee two anchors of the sample path: both fill; drag one of them 20 pt:
   both move with their handles (one `path.anchor-move` per sample under one
   drag token, one undo step once live, PN-8).
6. Drag a smooth anchor's out-handle: the in-handle turns with it; Option-drag
   breaks it (corner). Click a segment with the Pen: a point is added there
   and the shape doesn't move; select it and press Delete: it goes.
7. Keyboard: arrows nudge the selected anchors 1 pt (Shift 10), Return
   finishes an open pen path, Escape drops it; VoiceOver reads "Anchor 2 of 5,
   smooth, selected" (PN-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X37 | adds, closes with S25 | C | `Tests/RealJobs/fake/pen-path/pen-path.jobs.json`: four `path.pen-add` (one with an out handle), `path.close`, `path.anchor-select` the smooth anchor, 120 `path.handle-move` under one drag token, `edit.undo` once; the saved rects | `input/blank.fake` (no rects) |

Trap: closing adds a duplicate anchor at the start (RJ-D06's trap), or the 120
handle moves land as 120 undo steps. Assertion: the saved path has one closed
contour of exactly four anchors, the smooth anchor's handles stay collinear
and opposite at every sample, and after one undo its out handle is where the
pen left it. Mutations: `SuiteKernel.PenRules.json` (the close appends the
first point again) and `SuiteKernel.PathCommands.json` (the drag token not
passed to `setPath`).

## Screens and states

`suiteui-pen-paths` (empty, light and dark), `-drawing` (three corners and
the rubber band), `-smooth` (a dragged anchor with its handles),
`-close-hover` (the close ring on the first anchor), `-selected` (two of five
anchors filled, handles shown), `-stress` (5,000 anchors, half selected).

## Contract slice

```swift
// Sources/SuiteKernel/Paths/Paths.swift (PN-1): the suite's path is FlareCore's, under kernel names
// (SuiteUI has its own mark-only `PathAnchor`).
public typealias VectorPath = FlareCore.Path
public typealias VectorAnchor = FlareCore.PathAnchor      // point, handleIn?, handleOut?, kind
public typealias VectorContour = FlareCore.PathContour    // anchors, closed
public typealias AnchorKind = FlareCore.AnchorKind        // corner, smooth, symmetric
/// One anchor of a path: its contour and its place in it.
public struct AnchorRef: Hashable, Comparable, Sendable { public var contour: Int; public var index: Int }
public enum HandleEnd: String, Codable, Sendable { case handleIn = "in", handleOut = "out" }
/// What a pointer is over, nearest first: a handle, then an anchor, then a segment.
public enum PathHit: Hashable, Sendable { case handle(AnchorRef, HandleEnd), anchor(AnchorRef), segment(FlareCore.PathLocation) }
/// The open Pen path, document space. `scale` is view points per document point at the latest press, so the
/// tolerances are on screen (Flare #619).
public struct PenDraft: Hashable, Sendable { public var contour: VectorContour; public var scale: Double }
/// The path whose points are edited, in its own space, and the matrix to document space.
public struct PathInEdit: Hashable, Sendable { public var id: String; public var path: VectorPath; public var toDocument: Matrix }
public protocol PathEditTarget: Sendable {
    var penDraft: PenDraft? { get set }
    var pathInEdit: PathInEdit? { get }
    var anchorSelection: Selection<AnchorRef> { get set }
    var pathHelp: String? { get }                       // why path edits can't run now (no document, a locked layer)
    /// "Add Path": a new path layer above the selected one, selected; one undo step. Returns its id.
    mutating func addPath(_ path: VectorPath, name: String) throws -> String
    /// Replaces `pathInEdit`'s path; one undo step named `name`, steps under one `drag` token fold into one.
    mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws
}
// Sources/SuiteKernel/Paths/PenRules.swift (PN-1 stubs returning the draft, PN-5 bodies)
public enum PenRules {
    public static let closeDistance = 4.0, anchorTolerance = 1.0     // view points, Flare's values
    public static let degenerate = "Click at least two separate places to draw a path."
    public static func add(_ point: Point, handleOut: Point?, to draft: PenDraft?, scale: Double) -> PenDraft
    public static func closes(_ point: Point, _ draft: PenDraft) -> Bool  // within closeDistance of the first, 3+ distinct
    public static func closed(_ draft: PenDraft) -> PenDraft
    public static func finishHelp(_ draft: PenDraft?) -> String?     // Flare's two reasons, verbatim
    public static func path(_ draft: PenDraft) throws -> VectorPath  // throws `degenerate` under anchorTolerance
}
// Sources/SuiteKernel/Paths/AnchorEdit.swift (PN-1 stubs returning the input, PN-5 bodies)
public enum AnchorEdit {
    public static func moved(_ path: VectorPath, _ anchors: Set<AnchorRef>, dx: Double, dy: Double) -> VectorPath
    public static func movingHandle(_ path: VectorPath, _ ref: AnchorRef, _ end: HandleEnd, to: Point,
                                    breaking: Bool) -> VectorPath
    public static func inserting(_ path: VectorPath, at location: FlareCore.PathLocation) throws -> (path: VectorPath, ref: AnchorRef)
    public static func removing(_ path: VectorPath, _ anchors: Set<AnchorRef>) throws -> VectorPath
    public static func converting(_ path: VectorPath, _ anchors: Set<AnchorRef>, to kind: AnchorKind) throws -> VectorPath
    public static func snapped(_ point: Point, moving: Set<AnchorRef>, in path: VectorPath, lines: SnapLines,
                               tolerance: Double) -> Point
}
// Sources/SuiteKernel/Paths/AnchorIndex.swift (PN-1 stub answering nil and [], PN-6 body)
public struct AnchorIndex: Sendable {
    public static let cell = 64.0                                 // document points per grid cell
    public init(_ path: VectorPath, toDocument: Matrix)
    public func hit(_ point: Point, reach: Double, selected: Selection<AnchorRef>) -> PathHit?  // handles of selected anchors only
    public func inside(_ rect: Rect) -> [AnchorRef]               // sorted
    public var count: Int { get }
}
// Sources/SuiteKernel/Paths/PathCommands.swift (PN-1 specs with real ids, schemas and availability, runs throwing
// `PenRules.notBuilt`; PN-7 bodies)
public enum PathIntent: Hashable, Sendable {
    case penAdd(Point, handleOut: Point?), close, finish, cancel
    case select(anchors: [AnchorRef]?, rect: Rect?, extend: Bool), selectAll
    case move(dx: Double, dy: Double, drag: String?), handle(AnchorRef, HandleEnd, to: Point, breaking: Bool, drag: String?)
    case insert(Point), remove, convert(AnchorKind)
    public var command: (id: String, params: JSONValue) { get }
}
public enum PathCommands { public static func specs<T: PathEditTarget>(_ target: T.Type) -> [CommandSpec<T>] }
// Sources/SuiteKernel/Selection/Selection.swift (PN-6): `contains` reads a stored Set kept beside `ordered`.
// Sources/SuiteUI/PathEditOverlay.swift (PN-2 placeholder drawing the path only, PN-3 view)
public struct PathEditOverlay: View {
    public init(draft: PenDraft?, path: PathInEdit?, selection: Selection<AnchorRef>, tool: PenTool,
                zoom: Double, onIntent: @escaping (PathIntent) -> Void) }
public enum PenTool: Sendable { case pen, directSelect }
// Sources/SuiteUI/CanvasMarks+Path.swift (PN-2 stub mapping to the existing init, PN-3 states)
extension PathMarks {
    public init(contours: [VectorContour], toView: Matrix, selected: Set<AnchorRef>, hovered: PathHit?, zoom: Double) }
```

Commands (ids go in each adopter's `Tests/command-ids/<app>.txt`):

| id | kind | title (undo step) | params | unavailable when |
|---|---|---|---|---|
| `path.read` | query | – | – → `{contours: [{closed, anchors: [{x, y, inX?, inY?, outX?, outY?, kind}]}], selected: [[c, i]]}` | no `pathInEdit` and no draft |
| `path.draw` | edit | Add Path | `{contours: [...]}` as `path.read` writes them | `pathHelp`; fewer than 2 anchors; non-finite |
| `path.pen-add` | view | – (the draft) | `{x, y, outX?, outY?}` | `pathHelp` |
| `path.close` | edit | Add Path | – | no draft, or fewer than 3 distinct anchors |
| `path.finish` | edit | Add Path | – | `PenRules.finishHelp` |
| `path.cancel` | view | – | – | no draft |
| `path.anchor-select` | view | – | `{anchors?: [[c, i]], rect?: {x, y, width, height}, extend?, all?}` | no `pathInEdit` |
| `path.anchor-move` | edit | Move Points | `{dx, dy, drag?}` | no anchor selected |
| `path.handle-move` | edit | Move Handle | `{contour, index, end, x, y, breaking?, drag?}` | the anchor has no handle at `end` and `breaking` is false |
| `path.anchor-insert` | edit | Add Point | `{x, y}` | no segment within reach ("Click on the path to add a point.") |
| `path.anchor-remove` | edit | Delete Points | – | no anchor selected |
| `path.anchor-convert` | edit | Convert Points | `{kind}` | no anchor selected |

One coordinate rule: every param (`dx`/`dy`, a handle's `x`/`y`, an insert
point, a select rect, a Pen point) and `path.read`'s contours are in document
space. `PathCommands` maps them into the path's own space through
`toDocument` once (a delta through its linear part only), so an app never
maps them itself, and a layer scaled to nothing refuses point edits.

Every spec reads and writes through `PathEditTarget`, so an app adds the
twelve with one line (`+ PathCommands.specs(<X>Workspace.self)`) and its
`<X>Pen+Kernel.swift` conformance. Each app keeps its own `tool.pen` and
`tool.direct-select` ids.

## Pseudocode

- **add** (Flare's `LiveShapes.pen`, moved): a press within
  `anchorTolerance / scale` of the last anchor changes nothing; else append
  an anchor at `point`, a corner, or with `handleOut` (when the press was a
  drag) and `handleIn` mirrored through the point, kind `symmetric`. The
  first anchor alone keeps its out handle.
- **closes / closed:** 3 or more anchors more than `anchorTolerance` apart,
  and `point` within `closeDistance / scale` of the first (inclusive): set
  `closed`, append nothing (the first anchor is the end; no duplicate).
- **path(draft):** `VectorPath(contours: [draft.contour])`; its extent under
  `anchorTolerance / scale` throws `degenerate`. A segment is a line when
  both facing handles are nil, else a cubic with a missing handle at its own
  point, which is what Flare's draft emits today.
- **movingHandle:** set the handle; if the anchor is smooth or symmetric and
  not `breaking`, turn the other handle to the opposite direction (smooth
  keeps its length, symmetric takes the new length); `breaking` makes it a
  corner with both handles kept.
- **moved:** each selected anchor and its handles shift by (dx, dy) in the
  path's own space (`PathCommands` maps the document offset through the
  inverse of `toDocument`'s linear part).
- **inserting / removing / converting:** FlareCore's `inserting(at:)`,
  `removingAnchor`, `converting`; `inserting` returns the new anchor's ref by
  walking elements to `location.element` (a `move` starts a contour) so the
  editor selects it. Removing several goes high index to low.
- **snapped:** `lines.offset(.x, for: [p.x], tolerance:)` and `.y`, the
  `SnapLines` built once per gesture from every unmoved anchor as a
  zero-size `SnapCandidate` plus the app's frame candidates.
- **AnchorIndex:** buckets keyed by `Int(floor(v / cell))` on both axes, each
  anchor once; `hit` reads the 3 × 3 cells around the point and returns the
  nearest within `reach` (handles first, then anchors), else
  `path.nearest(to:tolerance:)` within `reach` as a segment; `inside` reads
  the cells the rect covers and checks each anchor once.
- **commands:** each edit spec reads `pathInEdit` or `penDraft`, applies one
  rule, and calls `setPath` or `addPath` once with its title; `drag` passes
  through so the target's `History` folds a drag into one step.
- **View.** One `Canvas` for the marks (`PathMarks`), one gesture that hit
  tests through `AnchorIndex` on press and keeps pointer samples local until
  the gesture ends; each sample emits one intent. Hover sets the cursor hint:
  pen add, close ring on the first anchor, add point over a segment, remove
  over an anchor with the Pen.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PN-1 | – | The kernel `Paths/` module as stubs: typealiases, `AnchorRef`, `HandleEnd`, `PathHit`, `PenDraft`, `PathInEdit`, `PathEditTarget`, `PenRules`, `AnchorEdit`, `AnchorIndex`, `PathIntent`, the twelve specs with ids, schemas and availability; the C4 part; the 5,000-anchor fixture; the six suites written, disabled by name | `Sources/SuiteKernel/Paths/Paths.swift`, `Sources/SuiteKernel/Paths/PenRules.swift`, `Sources/SuiteKernel/Paths/AnchorEdit.swift`, `Sources/SuiteKernel/Paths/AnchorIndex.swift`, `Sources/SuiteKernel/Paths/PathCommands.swift`, `Tests/SuiteKernelTests/PenRulesTests.swift`, `Tests/SuiteKernelTests/AnchorEditTests.swift`, `Tests/SuiteKernelTests/AnchorIndexTests.swift`, `Tests/SuiteKernelTests/PathCommandsTests.swift`, `Tests/SuiteKernelTests/AnchorStressFixture.swift`, `Tests/SuiteKernelTests/AnchorBudgetTests.swift`, `Tests/SuiteKernelTests/FakeCanvasPathTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-paths.json` | core bump | ~400, 13 |
| PN-2 | – | The placeholder `PathEditOverlay` and `PenTool`, the `PathMarks` contour init as a stub, the gallery's `pen-paths` page in `SuiteGallery.areas` on a local path, the concept line, the journey written and skipped (`XCTSkip("waits on PN-4")`) | `Sources/SuiteUI/PathEditOverlay.swift`, `Sources/SuiteUI/CanvasMarks+Path.swift`, `Sources/SuiteUI/Gallery/GalleryPenPaths.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/canonical-concepts.txt`, `UITests/SuiteJourneyTests+PenPaths.swift` | PN-1, export-pack:XP-a | ~240, 6 |
| PN-3 | – | The view: rubber band, anchor and handle marks with hover and selected states, the close ring, cursor hints, the gesture to intents, keyboard (arrows, Shift-arrows, Delete, Return, Escape), identifiers `suite.path.*` | `Sources/SuiteUI/PathEditOverlay.swift`, `Sources/SuiteUI/CanvasMarks+Path.swift`, `Tests/SuiteUITests/PathEditOverlayTests.swift` | PN-2 | ~380, 3 |
| PN-4 | – | Snapshots, the render budget tests (an anchor drag, a marquee over 5,000 anchors), the journey turned on | `Tests/AppSnapshotTests/SuitePenPathsSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPenPathsTests.swift`, `UITests/SuiteJourneyTests+PenPaths.swift` | PN-3 | ~240, 3 |
| PN-5 | – | `PenRules` (Flare's rules and numbers, verbatim) and `AnchorEdit` bodies; turns on `PenRulesTests` and `AnchorEditTests` | `Sources/SuiteKernel/Paths/PenRules.swift`, `Sources/SuiteKernel/Paths/AnchorEdit.swift`, `Tests/SuiteKernelTests/PenRulesTests.swift`, `Tests/SuiteKernelTests/AnchorEditTests.swift`, `Tests/mutations/SuiteKernel.PenRules.json`, `Tests/mutations/SuiteKernel.AnchorEdit.json` | PN-1 | ~380, 6 |
| PN-6 | – | `AnchorIndex` body; `Selection` keeps a `Set` beside `ordered` (`contains`, `unique`, the extend loop and `prune` use it); turns on `AnchorIndexTests` and `AnchorBudgetTests` | `Sources/SuiteKernel/Paths/AnchorIndex.swift`, `Sources/SuiteKernel/Selection/Selection.swift`, `Tests/SuiteKernelTests/AnchorIndexTests.swift`, `Tests/SuiteKernelTests/AnchorBudgetTests.swift`, `Tests/mutations/SuiteKernel.AnchorIndex.json`, `Tests/mutations/SuiteKernel.Selection.json` | PN-1 | ~300, 6 |
| PN-7 | – | `PathCommands` bodies and `PathIntent.command`; turns on `PathCommandsTests` on a test target (one step per run, a drag one step, every why-not) | `Sources/SuiteKernel/Paths/PathCommands.swift`, `Tests/SuiteKernelTests/PathCommandsTests.swift`, `Tests/mutations/SuiteKernel.PathCommands.json` | PN-5, PN-6, command-catalog:CC-run | ~360, 3 |
| PN-8 | – | The gallery page runs each intent through `PathCommands` on a local target with a `History`, so the log and one undo step show; the live test | `Sources/SuiteUI/Gallery/GalleryPenPaths.swift`, `Tests/SuiteUITests/PathEditOverlayLiveTests.swift` | PN-4, PN-7 | ~140, 2 |
| PN-9 | – | The fake app takes paths: `FakeRect.path` (omitted when nil, so the old jobs' JSON is unchanged), `FakeCanvasDocument` conforms and lists the specs; RJ-X37's job folder; turns on `FakeCanvasPathTests` | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeCanvasPathTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/pen-path/pen-path.jobs.json`, `Tests/RealJobs/fake/pen-path/input/blank.fake` | PN-7, export-pack:XP-z | ~220, 5 |
| PN-10 | – | The C4 part names the commands and the overlay; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-paths.json`, `docs/blueprints/suiteui/features/pen-paths.wave.json` | PN-8, PN-9 | ~20, 2 |

PN-1 declares every rule and spec so PN-5, PN-6 and PN-7 each fill their
own files. No `suiteui.md` edit: the C4 part and the adopts' blueprint lines
carry it.

## Build waves

- Wave 1: PN-1. Independent in this wave: PN-1 alone.
- Wave 2: PN-2, PN-5, PN-6. Independent in this wave: all three.
- Wave 3: PN-3, PN-7. Independent in this wave: both.
- Wave 4: PN-4, PN-9. Independent in this wave: both.
- Wave 5: PN-8. Independent in this wave: PN-8 alone.
- Wave 6: PN-10 (`feature-done`, final). Independent in this wave: PN-10 alone.

Longest chain: PN-1 → PN-2 → PN-3 → PN-4 → PN-8 → PN-10 (6). Chain of 6:
the page needs the module's types, the view fills the placeholder, the budget
and journey time the view, the live page swaps the log under the journey, and
PN-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PN-1 | the six suites compile, disabled by name; `KernelShapeTests.importsOnlyFoundationAndFlareCore` still passes over `Paths/`; every spec's id is in the catalog with its schema | the module imports past FlareCore, or a spec is missing | – (stubs) |
| PN-2 | SJ0: the index lists `pen-paths`; the page opens; `scripts/check-dup-logic` passes with the concept line | the page is missing, or an app file is already named for the concept | – (UI) |
| PN-3 | `PathEditOverlayTests`: a click emits one `.penAdd`; a press-drag emits `.penAdd` with a handle; a click within 4 pt of the first anchor emits `.close`, never a fourth `.penAdd`; a press on a selected anchor then drag emits `.move`s under one token; Option on a handle sets `breaking`; Delete emits `.remove` | an intent is wrong, doubled, or a close adds a point | – (UI) |
| PN-4 | `SuitePenPathsSnapshots`; `RenderBudgetPenPathsTests.anchorDragInThreeBodies`, `.marqueeOver5000InThreeBodies`; `testPenDrawsAndEditsAPath` steps 1 to 7 | budget over, or a step fails | – (UI) |
| PN-5 | `PenRulesTests` (ported from Flare's `FlarePenCloseRadiusTests`, `FlarePenToleranceTests`, `FlarePenStageScaleTests`, `FlarePenDegenerateTests`, same inputs and numbers): a close at 4.0 / scale closes, 4.01 doesn't; a press within 1 / scale of the last is ignored; a closed draft has no duplicate anchor; `path` of a corner-smooth pair is one cubic with the corner's control at its point. `AnchorEditTests`: moving one anchor moves its two handles and nothing else; a smooth handle drag keeps the partner collinear and its length, symmetric mirrors it, `breaking` keeps it put; inserting at t 0.5 keeps the flattened outline within 1e-9 and returns the new ref; removing two anchors leaves the rest in order | a tolerance, a duplicate point, a handle or a ref is wrong | `SuiteKernel.PenRules`: close appends the first point → `PenRulesTests.closeAddsNoPoint`; `<` for `<=` on the close distance → `.closeIsInclusive`; tolerance not divided by scale → `.toleranceIsOnScreen`. `SuiteKernel.AnchorEdit`: partner handle left alone → `AnchorEditTests.smoothKeepsPartner`; handles not moved with the point → `.moveCarriesHandles`; removal low to high → `.removeSeveralInOrder` |
| PN-6 | `AnchorIndexTests`: a hit at a handle beats the anchor under it; handles of unselected anchors don't hit; `inside` returns exactly the anchors in a rect across cell edges; an anchor on a cell edge is found from both sides. `AnchorBudgetTests` (`.serialized`; times reported in release): on `AnchorStressFixture` (500 ten-point stars, 5,000 anchors, `FlareFixtures.stress`'s layout) a marquee over all ≤ 4 ms, one move sample of 5,000 selected ≤ 4 ms, one hover ≤ 0.1 ms; gated: a marquee over 10,000 takes under 3 × the 5,000 time (min of 5 runs), and `Selection.replace` of 5,000 then 5,000 `contains` under 3 × a 2,500 run | a hit or a rect is wrong, or a pass turns quadratic | `SuiteKernel.AnchorIndex`: `floor` for a truncating `Int(v / cell)` (negative cells shift) → `AnchorIndexTests.negativeCells`; edge cell not read → `.edgeAnchorFound`. `SuiteKernel.Selection`: `contains` back to `ordered.contains` → `AnchorBudgetTests.selectionIsLinear`; the set not updated on `toggle` → `SelectionTests` (existing) |
| PN-7 | `PathCommandsTests`: each edit run records one step named its title; 120 `path.handle-move` under one drag token undo in one; `path.close` with two anchors is unavailable with its reason; `path.anchor-insert` off the path is unavailable; `path.draw` round-trips `path.read`; `PathIntent.command` round-trips each case | a run records zero or two steps, or a why-not is missing | `SuiteKernel.PathCommands`: drag not passed to `setPath` → `.dragIsOneStep`; close allowed with two anchors → `.closeNeedsThree`; `setPath` called per anchor in `anchor-move` → `.oneStepPerRun` |
| PN-8 | `PathEditOverlayLiveTests`: an anchor drag on the page leaves one undo step; `testPenDrawsAndEditsAPath` on live | the page stays on the local log | – (UI) |
| PN-9 | `FakeCanvasPathTests`: a path survives save and open; a locked rect refuses with its reason; the old `add-rect` job's JSON is unchanged; RJ-X37 passes on Linux | a path is lost, a locked rect takes it, or old JSON changes | `SuiteKernel.FakeCanvasDocument`: locked check skipped in `setPath` → `.lockedRefusesPath`; `path` encoded when nil → `.oldJSONUnchanged` |
| PN-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample anchor drag on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetPenPathsTests.anchorDragInThreeBodies` |
| render: 120-sample marquee over 5,000 anchors | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetPenPathsTests.marqueeOver5000InThreeBodies` |
| Many anchors (VectorCraft) | 5,000 anchors: marquee ≤ 4 ms, move sample ≤ 4 ms, hover ≤ 0.1 ms; linear, not quadratic (gated) | `AnchorBudgetTests` |
| One gesture, one step | an anchor drag, a handle drag, a pen path (close or finish) each one undo step | `PathCommandsTests.dragIsOneStep`, `PathEditOverlayLiveTests` |
| No dead controls | every control registers in `suite.controls` | `testPenDrawsAndEditsAPath` |
| Keyboard and VoiceOver parity | arrows nudge, Delete removes, Return finishes, Escape cancels; anchors read "Anchor n of m, kind, selected" | `testPenDrawsAndEditsAPath` step 7 |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PN-m merged-done on the Linux job with
`Mutate:` scores clean and `AnchorBudgetTests` gated rows green; PN-u's feel
gate (`mouse`, `taste`, `job` lenses) and its `Mac-Finish:` line; PN-z's
journey on live and RJ-X37 green in the Linux job. Then `Belt-Contact-Sheet:`
with `suiteui-pen-paths-*`.

## Adopted by

`design/pen-paths` (enable P, path nodes, edit points, SVG and PDF; RJ-D06)
and `flare/pen-paths` (Pen onto the kernel, Direct Select drags anchors, the
5,000-anchor stress gate; RJ-F27). Each waits on PN-a and runs its UI on
these stubs.

## Not in this packet

Booleans (S18, on core's `Path.combine`), outline stroke as a command, a
pencil or freehand tool (adopt-kernel-brush), curvature or B-spline pens,
path animation and shape keys (Flare's `shape-key.*` keep working on the
stored path), point snapping to curves, text on a path.
