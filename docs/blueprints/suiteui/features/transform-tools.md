# Feature packet: transform-tools

**Feature:** one rotate, scale and flip for the suite. SuiteKernel's
`Transform/` module (built: `BoxMath`, `HandleHit`, `LayerTransform`) gets the
rest of what Free Transform, Design's rotate and Halo's viewer handles share:
`TransformBox` (a box, its turn and its mirrors), `TransformRules` (turn,
flip and scale about an anchor, the turned corners and bounds, a point in the
box's own frame, the drawing matrix, the canvas-size anchor), and
`TransformCommands`, the six transform commands every app registers. SuiteUI's
existing `SelectionHandlesEditor` learns to draw and drag a turned box, and a
new `TransformRows` gives the inspector X, Y, W, H, a rotation row and the two
flip buttons. The rows and handles emit `TransformIntent`s, each one a
command, and the app runs them through its catalog.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/transform-tools`
**Beta:** captain, 2026-10-20 ("everyday tools, built once and shared"). Labels `beta` and `p0` when filed.

**Covers:** feature map S7 (transform handles: rotate, scale, flip, canvas
size; the re-cut of Photo's PV-7); real job RJ-X32 (new). The adopts are
`photo/transform`, `design/transform` and `halo/transform`, each waiting on
this packet's TT-a.

**Depends on:** editor-kernel (built): `EditorHandle`, `BoxMath`,
`HandleHit`, `LayerTransform`, `History`, `CommandSpec`. canvas-marks (built):
`SelectionHandlesEditor`, `SuiteHandleGeometry`. creative-core's affine
composite, flip and canvas pad (#434, closed; `PixelBuffer.transformed`,
`flipped`, `padded` are on the pinned core) for Photo's pixels, used by the
Photo adopt, not here. In this folder: autosave-history's **AH-z** before TT-8
(both own `FakeCanvasDocument.swift`). No new creative-core issue.

**Rule 20.** `Transform` is already a canonical concept. Everything an app
needs to turn, mirror or scale a box is in `TransformRules`: Photo's
`KernelBox` (private to `LiveTransform+Kernel.swift`) turns points with the
same formula `TransformRules.local` gives, and the Photo adopt deletes it.
Adopts name their files `<X>Transform+Kernel.swift`. The flip enum is
`FlipDirection` and the anchor `BoxAnchor`, so they never clash with
CoreRaster's `FlipAxis` and `CanvasAnchor` in a Model that imports both;
Photo's own `FlipAxis` becomes a typealias of `FlipDirection` in its adopt.

**Render path.** None new. Each app draws a turned layer through the path it
has: Design and Halo map `TransformRules.matrix` into their existing draw
(SwiftUI transform, Halo's `HaloMatrix`), Photo resamples once on commit with
CoreRaster's `transformed` (lanczos3).

**C4:** `kernel-transform.json` gains `TransformRules.swift` and
`TransformCommands.swift` (TT-1). `TransformRows.swift` is a new file under
`Sources/SuiteUI/`, covered by `suiteui-sources`.

**Clean-room.** Handle behaviour from the HIG and the apps' own tests; no task
reads another product's code.

Blueprint sections: suiteui.md 2.2 (components), 2.4 (canvas marks), 7.1
(budgets); suite.md 1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| TT-a | The kernel's transform rules, target, intents and six command specs are declared as stubs, the handles take a turn, the gallery's transform-handles page is in the index, and the checks are written, disabled. | TT-1, TT-2 | SJ0 | editor-kernel (built; TT-1 edits its C4 part), canvas-marks (built) |
| TT-u | On the gallery page the knob turns the box and its handles together, a side drag grows the turned box in its own frame, the rows type a turn and flip it, every control identified, within the render budget. | TT-3, TT-4 | TJ1 | TT-a |
| TT-m | The rules turn, mirror and scale a box about its centre or an anchor and map points both ways, and every transform command records exactly one undo step (a drag one). | TT-5, TT-6 | KJ-transform | TT-a |
| TT-z | The gallery runs its intents through TransformCommands on a live target, the fake app turns and flips so RJ-X32 runs on the CLI, and the feature is built. | TT-7, TT-8, TT-9 | TJ1, KJ-transform | TT-u, TT-m; autosave-history:AH-z (TT-8) |

TT-u waits only on TT-a (rule 18); TT-m never waits on TT-u. KJ-transform is
the rules' and commands' Linux walk in `SuiteKernelTests`.

## Journey steps

1. Open the gallery index, click `transform-handles` (TT-2, SJ0): a 200 × 120
   box with its eight handles and the rotate knob, and the transform rows
   beside it (X 100, Y 80, W 200, H 120, Rotation 0°).
2. Drag the rotate knob a quarter turn clockwise
   (`SuiteTransformJourneyTests.testTransformHandlesTurnAndFlip`, TT-3): the
   box and its handles turn together; the rotation row reads 90°; the log
   shows one `transform.rotate` per sample under one drag token.
3. Drag the right handle 40 pt along the turned box's own right edge: the box
   grows in its own frame (W 240) and the opposite edge stays put.
4. Click Flip Horizontal: the box mirrors about its centre, the rotation row
   reads −90°, the log shows one `transform.flip`.
5. Type 15 in the rotation row, then Shift-drag the knob: it snaps in 15°
   steps. Every row is reachable by Tab; VoiceOver reads the knob as "Rotate,
   15 degrees" (TT-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X32 | adds, closes with S7 | C | `Tests/RealJobs/fake/turn-flip/turn-flip.jobs.json`: `rect.select`, 60 `transform.rotate {"degrees": 0.25}` under one drag token, `transform.flip {"axis": "horizontal"}`, `edit.undo`; the saved rects | `input/one.fake` (one free rect) |

Trap: the drag lands as 60 undo steps, the turn saves in radians, or the flip
mirrors about the document origin and moves the box. Assertion: after the one
undo (the flip) the rect reads `degrees` 15 with its x and y unchanged;
a second undo reads 0 (the drag was one step). Mutations:
`SuiteKernel.TransformCommands.json` (drag token not passed → `.dragIsOneStep`)
and `SuiteKernel.TransformRules.json` (flip about the origin → `.flipKeepsCentre`).

## Screens and states

`suiteui-transform-handles` (light and dark, turned 30°), `-flipped` (the
mirrored box, rotation row negated), `-rows` (the inspector rows, a value
typed), `-several` (the union box of two items, rotation row "Mixed").

## Contract slice

```swift
// Sources/SuiteKernel/Transform/TransformRules.swift (TT-1 stubs returning the input, TT-5 bodies)
public enum FlipDirection: String, Codable, CaseIterable, Sendable { case horizontal, vertical }
public enum BoxAnchor: String, Codable, CaseIterable, Sendable {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight
}
/// A layer as the transform tools see it: its unturned box in document space, its clockwise turn
/// in degrees about the box's centre, and whether it is mirrored on each axis (before the turn).
public struct TransformBox: Hashable, Sendable, Codable {
    public var box: Rect, degrees: Double, flipX: Bool, flipY: Bool
    public init(box: Rect, degrees: Double = 0, flipX: Bool = false, flipY: Bool = false)
}
public enum TransformRules {
    public static func normalized(_ degrees: Double) -> Double                       // into (-180, 180]
    public static func rotated(_ t: TransformBox, by degrees: Double) -> TransformBox
    public static func flipped(_ t: TransformBox, _ direction: FlipDirection) -> TransformBox
    public static func scaled(_ t: TransformBox, sx: Double, sy: Double, about anchor: BoxAnchor) -> TransformBox
    public static func corners(of t: TransformBox) -> [Point]                        // turned, clockwise from top-left
    public static func bounds(of t: TransformBox) -> Rect                            // the corners' axis-aligned box
    public static func local(_ p: Point, in t: TransformBox) -> Point                // a document point in the unturned frame
    public static func matrix(of t: TransformBox) -> Matrix                          // the unit box to the document
    /// Canvas Size: where content `old` wide and high lands (its top-left) in a canvas resized to `new` about `anchor`.
    public static func anchoredOrigin(old: (w: Double, h: Double), new: (w: Double, h: Double), _ anchor: BoxAnchor) -> Point
}
// Sources/SuiteKernel/Transform/TransformCommands.swift (TT-1 specs with ids, schemas and availability,
// runs throwing `TransformRules.notBuilt`; TT-6 bodies)
public protocol TransformTarget: Sendable {
    var transformSelection: TransformBox? { get }   // the selection's box; several items: their union, unturned
    var transformHelp: String? { get }              // why nothing can transform now; nil when it can
    var flipHelp: String? { get }                   // why flips can't run (a default extension returns nil)
    /// Sets every selected unlocked item from `t`, mapped from the selection's box to each one; one undo
    /// step named `name`; steps under one `drag` token fold into one.
    mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws
}
public enum TransformIntent: Hashable, Sendable {
    case set(TransformBox, drag: String?), rotate(by: Double, drag: String?)
    case scale(sx: Double, sy: Double, anchor: BoxAnchor, drag: String?), flip(FlipDirection), reset
    public var command: (id: String, params: JSONValue) { get }
}
public enum TransformCommands {
    public static func specs<T: TransformTarget>(_ target: T.Type) -> [CommandSpec<T>]
}
// Sources/SuiteUI/TransformRows.swift (TT-2 placeholder, TT-3 view)
/// X, Y, W, H, Rotation and the two flip buttons for the selection; `nil` shows the rows disabled with `help`.
public struct TransformRows: View {
    public init(selection: TransformBox?, help: String?, flipHelp: String?, onIntent: @escaping @MainActor (TransformIntent) -> Void)
}
// Sources/SuiteUI/CanvasMarks+Vector.swift (TT-2 adds the parameter, ignored; TT-3 draws and drags the turned box)
extension SelectionHandlesEditor {
    public init(rect: CGRect, degrees: Double, zoom: Double, onResize: @escaping @MainActor (CGRect) -> Void,
                onRotate: @escaping @MainActor (Double) -> Void, onEnd: @escaping @MainActor () -> Void)
}
```

Commands (all `edit` but `transform.read`; ids go in each adopter's
`Tests/command-ids/<app>.txt`):

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `transform.read` | – (query) | – → `{x, y, w, h, degrees, flipX, flipY}` | `transformHelp` |
| `transform.set` | Transform | `{x?, y?, w?, h?, degrees?, drag?}` | `transformHelp`; w or h below 1 throws "Width and height must be at least 1." |
| `transform.rotate` | Rotate | `{degrees, drag?}` (by) | `transformHelp` |
| `transform.scale` | Scale | `{sx, sy, anchor?, drag?}` | `transformHelp`; a factor ≤ 0 throws |
| `transform.flip` | Flip Horizontal / Flip Vertical | `{axis}` | `transformHelp`, then `flipHelp` |
| `transform.reset` | Reset Rotation | – (turn 0, no mirrors) | `transformHelp` |

An app adds the six with `+ TransformCommands.specs(<X>Workspace.self)` and
its `<X>Transform+Kernel.swift` conformance.

## Pseudocode

- **rotated.** `degrees = normalized(t.degrees + by)`; the box doesn't move
  (the turn is about its centre). Non-finite input returns `t`.
- **flipped.** Toggle the mirror flag and negate the turn, so the box looks
  mirrored across the turned axis through its centre; the box itself stays.
- **scaled.** The anchor point of the unturned box stays; the box's sides
  multiply; the turned anchor maps back to the same document point.
- **local.** Translate to the centre, turn by `-degrees`, mirror by the flags,
  translate back; `matrix` is the inverse composed with the unit box, so
  `local(matrix(of:t).apply(p))` is `p` within 1e-9.
- **anchoredOrigin.** `x = (new.w - old.w) · {0, ½, 1}` for left, middle and
  right anchors, the same for y.
- **commands.** Each spec reads `transformSelection`, applies one rule, calls
  `setTransform` once with its title; `drag` passes through so the target's
  `History` folds a drag into one step (`FakeCanvasDocument.MoveRect`'s
  pattern).
- **Handles.** The editor draws the box through `rotationEffect` about its
  centre, places the handles with `BoxMath.handles` on the unturned box, and
  turns each pointer sample back with `TransformRules.local` before
  `BoxMath.resized`, so a side drag grows the box in its own frame.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TT-1 | – | The contract as stubs: `FlipDirection`, `BoxAnchor`, `TransformBox`, `TransformRules`, `TransformTarget`, `TransformIntent`, the six specs with ids, schemas and availability; the C4 part's paths; the two suites written, disabled by name | `Sources/SuiteKernel/Transform/TransformRules.swift`, `Sources/SuiteKernel/Transform/TransformCommands.swift`, `Tests/SuiteKernelTests/TransformRulesTests.swift`, `Tests/SuiteKernelTests/TransformCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json` | – | ~300, 5 |
| TT-2 | – | The placeholder `TransformRows`; `SelectionHandlesEditor`'s `degrees:` initializer (ignored for now); the gallery's `transform-handles` page in `GalleryCanvas.pages` on a local box; the journey written and skipped (`XCTSkip("waits on TT-4")`) | `Sources/SuiteUI/TransformRows.swift`, `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Sources/SuiteUI/Gallery/GalleryTransform.swift`, `Sources/SuiteUI/Gallery/GalleryCanvas.swift`, `UITests/SuiteJourneyTests+Transform.swift` | TT-1 | ~220, 5 |
| TT-3 | – | The rows (X, Y, W, H, Rotation, Flip H and V, identifiers `suite.transform.*`) and the turned box: drawn turned, each sample mapped back with `TransformRules.local` | `Sources/SuiteUI/TransformRows.swift`, `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Tests/SuiteUITests/TransformRowsTests.swift`, `Tests/SuiteUITests/SelectionHandleTurnTests.swift` | TT-2 | ~340, 4 |
| TT-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteTransformSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetTransformTests.swift`, `UITests/SuiteJourneyTests+Transform.swift` | TT-3 | ~220, 3 |
| TT-5 | – | `TransformRules` bodies; turns on `TransformRulesTests` | `Sources/SuiteKernel/Transform/TransformRules.swift`, `Tests/SuiteKernelTests/TransformRulesTests.swift`, `Tests/mutations/SuiteKernel.TransformRules.json` | TT-1 | ~280, 3 |
| TT-6 | – | `TransformCommands` bodies and `TransformIntent.command`; turns on `TransformCommandsTests` on a test target | `Sources/SuiteKernel/Transform/TransformCommands.swift`, `Tests/SuiteKernelTests/TransformCommandsTests.swift`, `Tests/mutations/SuiteKernel.TransformCommands.json` | TT-5 | ~300, 3 |
| TT-7 | – | The gallery page runs each intent through `TransformCommands` on a local target with a `History`, so one undo step shows per gesture; the live test | `Sources/SuiteUI/Gallery/GalleryTransform.swift`, `Tests/SuiteUITests/TransformLiveTests.swift` | TT-4, TT-6 | ~140, 2 |
| TT-8 | – | The fake app turns and flips: `FakeRect.degrees`, `flipX`, `flipY` (omitted at their defaults, so old jobs' JSON is unchanged), `FakeCanvasDocument` conforms and lists the specs; RJ-X32's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeTransformTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/turn-flip/turn-flip.jobs.json`, `Tests/RealJobs/fake/turn-flip/input/one.fake` | TT-6 | ~200, 5 |
| TT-9 | – | The C4 part names the commands and the rows; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json`, `docs/blueprints/suiteui/features/transform-tools.wave.json` | TT-7, TT-8 | ~20, 2 |

TT-1 declares every rule and spec so TT-5 and TT-6 each fill one file.

## Build waves

- Wave 1: TT-1. Independent in this wave: TT-1 alone.
- Wave 2: TT-2, TT-5. Independent in this wave: both.
- Wave 3: TT-3, TT-6. Independent in this wave: both.
- Wave 4: TT-4, TT-8. Independent in this wave: both.
- Wave 5: TT-7. Independent in this wave: TT-7 alone.
- Wave 6: TT-9 (`feature-done`, final). Independent in this wave: TT-9 alone.

Longest chain: TT-1 → TT-2 → TT-3 → TT-4 → TT-7 → TT-9 (6). Chain of 6: the page needs the module's types, the view fills the placeholder, the budget and journey time the view, the live page runs the commands under the journey, and TT-9 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| TT-1 | the two suites compile, disabled by name; `KernelShapeTests.importsOnlyFoundationAndFlareCore` passes over `Transform/` | the module imports past FlareCore | – (stubs) |
| TT-2 | SJ0: the index lists `transform-handles`; the page opens; every existing `SelectionHandlesEditor` call still builds | the page is missing or a caller breaks | – (UI) |
| TT-3 | `TransformRowsTests`: a typed rotation emits one `.rotate`; Flip Horizontal emits one `.flip(.horizontal)`; with `flipHelp` set the buttons are disabled with it; `SelectionHandleTurnTests`: on a box turned 90° a right-handle drag of (0, 40) grows W by 40 | an intent is doubled or a turned drag grows the wrong side | – (UI) |
| TT-4 | `SuiteTransformSnapshots`; `RenderBudgetTransformTests.knobDragInThreeBodies`; `testTransformHandlesTurnAndFlip` steps 1 to 5 | budget over, or a step fails | – (UI) |
| TT-5 | `TransformRulesTests`: 190° normalizes to −170; corners of a 100 × 50 box turned 90° about (50, 25); `bounds` of a square turned 45° is √2 wider; `local(matrix·p) == p`; flip keeps the centre and negates the turn; `anchoredOrigin` for a 200 px border is (100, 100) at the centre | a point, an angle or an origin is wrong | `SuiteKernel.TransformRules`: degrees used as radians → `.cornersTurn90`; `>=` for `>` at 180 → `.normalizesHalfTurn`; flip about the origin → `.flipKeepsCentre`; centre anchor using 1 for ½ → `.anchoredCentre` |
| TT-6 | `TransformCommandsTests`: each edit records one step named its title; 60 rotates under one drag token undo in one; `transform.flip` with `flipHelp` set is unavailable with it; `transform.set` with w 0 throws its sentence; `TransformIntent.command` round-trips each case | a run records zero or two steps, or a why-not is missing | `SuiteKernel.TransformCommands`: drag not passed to `setTransform` → `.dragIsOneStep`; `flipHelp` not checked → `.flipHonoursHelp`; rotate sets instead of adds → `.rotateIsRelative` |
| TT-7 | `TransformLiveTests`: a knob drag on the page leaves one undo step; `testTransformHandlesTurnAndFlip` on live | the page stays on the local log | – (UI) |
| TT-8 | `FakeTransformTests`: a turn and flips survive save and open; a locked rect refuses with its reason; the old jobs' JSON is unchanged; RJ-X32 passes on Linux | a turn is lost, a locked rect turns, or old JSON changes | `SuiteKernel.FakeCanvasDocument`: locked check skipped in `setTransform` → `.lockedRefusesTurn`; `degrees` encoded at 0 → `.oldJSONUnchanged` |
| TT-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample rotate-knob drag on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetTransformTests.knobDragInThreeBodies` |
| render: 120-sample side-handle drag on a turned box | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetTransformTests.turnedResizeInThreeBodies` |
| render: 120-sample rotation-row scrub | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetTransformTests.rotationScrubInThreeBodies` |
| One gesture, one step | a knob drag, a handle drag, a row scrub each one undo step | `TransformCommandsTests.dragIsOneStep`, `TransformLiveTests` |
| No dead controls; keyboard and VoiceOver | every row and both flip buttons identified `suite.transform.*`, reachable by Tab; the knob reads its angle | `testTransformHandlesTurnAndFlip` |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): TT-m merged-done on the Linux job with
`Mutate:` scores clean; TT-u's feel gate (`mouse`, `taste`, `job` lenses) and
its `Mac-Finish:` line; TT-z's journey on live and RJ-X32 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suiteui-transform-*`.

## Adopted by

`photo/transform` (Free Transform, flips, Canvas Size; RJ-P17, RJ-P18),
`design/transform` (rotate and flip layers; RJ-D15), `halo/transform` (rotate
and scale handles in the viewer; RJ-H21). Each waits on TT-a.

## Not in this packet

Skew, distort and perspective handles, a movable pivot (Halo's anchor point
stays its own rows), numeric transform of several items about each one's own
centre, Flare (its stage-edit packet already turns shapes on `BoxMath`).
