# Feature packet: transform (Photo)

**Feature:** Photo's Free Transform, layer flips and Canvas Size. Edit > Free
Transform (⌘T) puts SuiteUI's handles, turned with the draft, over the active
layer (or the selection); dragging scales, turns and moves the draft, Return
commits one resample, Escape cancels. Edit > Transform > Flip Horizontal and
Flip Vertical mirror the layer exactly. Image > Canvas Size… grows or crops
the canvas about one of nine anchors. Every edit is a SuiteKernel transform
command (or one of Photo's three Free Transform commands), so the CLI and an
agent transform the way the canvas does. This fills PV-7's stubs
(`TransformIntent {}`, `TransformOverlay`, `TransformOptions`, the NotBuilt
`applied` and `flipped`).
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/transform`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/transform` (adopter of S7); real jobs RJ-P17
(paste a logo, scale from a corner, turn 15°, flip) and RJ-P18 (a 200 px white
border with Canvas Size).

**Depends on:** `suiteui/transform-tools` **TT-a** (cross-line: the rules,
target and specs as stubs, `TransformRows`, the turned handles); PT-5 needs
its **TT-m** (the real commands), PT-3 its **TT-u** (the real rows) for the
snapshots. creative-core's `PixelBuffer.transformed`, `flipped` and `padded`
(#434, on the pinned core). Same line: gradient-fill's **PG-m** before PT-5
(both own `PhotoCommandCatalog.swift` and `Tests/command-ids/photo.txt`).
Built: photo-seams, photo-documents, photo-edit.

**Hand-offs** (cross-line files; the lead checks each before the task):
`PhotoCommands+Edit.swift` and `PhotoCommands+Image.swift` are
adopt-command-catalog's (AC-photo): PT-2 adds three menu items after
AC-photo's `Belt-Slice-Done:`.

**Rule 20.** The draft, handle hit and drag already run on the kernel
(`LiveTransform+Kernel.swift`, AT-p1). PT-4 replaces its private `KernelBox`
turn maths with `TransformRules.local` and `matrix`, Photo's `FlipAxis`
becomes `typealias FlipAxis = FlipDirection`, and Canvas Size's anchor is the
kernel's `BoxAnchor` with `TransformRules.anchoredOrigin`. The only new Model
file is the adapter `PhotoTransform+Kernel.swift`.

**Render path.** The draft previews live through the existing layer route:
each canvas render resamples the draft's layer once with CoreRaster's
`transformed` (lanczos3, `PhotoWorkspace.transformPreview`), and the routes
composite it on PhotoCompositeCache's kept base, so only that layer and the
ones above it composite per step. Commit lays that same resample, so Return
shows exactly the last preview. Flips use `flipped` (exact).
Canvas Size pads with `padded(anchor:)`. No new route.

Blueprint sections: photo.md 4 (Edit and Image menus), 6 (canvas overlays).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PT-a | The adapter is declared as stubs and Free Transform is reachable from the Edit menu with turned handles and the transform rows on them. | PT-1, PT-2 | MJ-PT | suiteui/transform-tools TT-a (cross-line) |
| PT-u | Canvas Size's sheet works on the stubs and the transform overlay's snapshots and render budget hold. | PT-3, PT-7 | PJ-T1 | PT-a; TT-u (PT-7, cross-line) |
| PT-m | The draft scales and turns as one step per gesture, commit resamples once, flips mirror the layer in place, and Canvas Size pads or crops about its anchor. | PT-4, PT-5, PT-6 | MJ-PT | PT-a; multi-layer-select:PM-m (the catalog, PT-5); gradient-fill:PG-m (PT-5); TT-m (PT-5, cross-line) |
| PT-z | The journey turns, flips and adds a border on live services, and the feature is built. | PT-8, PT-9 | PJ-T1 | PT-u, PT-m |

PT-u waits only on PT-a (rule 18); PT-m never waits on PT-u. MJ-PT is the
Model walk in `PhotoTransformTests` (Linux).

## Journey steps

1. Open `logo-on-photo.png` (two layers), select the logo layer, choose Edit >
   Free Transform (PT-2, `PhotoTransformJourneyTests.testFreeTransformTurnFlip`):
   the handles appear on the logo's bounds; the inspector shows the transform
   rows.
2. Shift-drag the bottom-right handle out: the logo scales in proportion.
3. Type 15 in the rotation row: the box and the logo preview turn 15°.
4. Press Return: one "Free Transform" step; the handles go.
5. Edit > Transform > Flip Horizontal: the logo mirrors in place (one step).
6. Image > Canvas Size…, Width and Height +400 (relative), anchor centre, OK
   (PT-3): a 200 px border of the background colour on every side.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P17 | closes (now `photo/transform`) | C | `Tests/RealJobs/photo/free-transform/free-transform.jobs.json`: `layer.select`, `transform.begin`, `transform.scale {"sx": 0.5, "sy": 0.5, "anchor": "topLeft"}`, `transform.rotate {"degrees": 15}`, `transform.commit`, `transform.flip {"axis": "horizontal"}`, export PNG | `input/logo-on-photo.photo` (a 400 × 200 logo layer over a photo) |
| RJ-P18 | closes (now `photo/transform`) | C | `Tests/RealJobs/photo/canvas-border/canvas-border.jobs.json`: `image.canvas-size {"width": 2400, "height": 1800, "anchor": "center"}`, export PNG | `input/photo-2000x1400.png` |

Traps: P17, the scale is applied after the turn (the logo skews), or the flip
mirrors about the canvas (the logo jumps sides); P18, the border is
transparent or only on the right and bottom. Assertions: P17, the exported
logo's bounds are the turned 200 × 100 box's bounds within 1 px and its left
edge stays where it was; P18, the output is 2400 × 1800 and the 200 px band on
each side is the background colour. Mutations:
`PhotoModel.PhotoTransform+Kernel.json` (flip about the canvas →
`.flipInPlace`) and `PhotoModel.PhotoImageOps.json` (anchor ignored →
`.canvasSizeCentred`).

## Screens and states

`photo-free-transform` (handles turned 15°, light and dark), `-rows` (the
transform rows), `photo-canvas-size` (the sheet, anchor grid on centre),
`-canvas-size-crop` (a smaller size, "The canvas will be cropped.").

## Contract slice

```swift
// Sources/PhotoModel/PhotoTransform+Kernel.swift (PT-1 stubs, PT-5 bodies)
extension PhotoWorkspace: TransformTarget {
    public var transformSelection: TransformBox? { get }   // the draft's box, else the active layer's (or selection's) bounds
    public var transformHelp: String? { get }              // "Select a pixel layer to transform." / locked layer help
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws
}
extension PhotoWorkspace {
    public mutating func beginTransform() throws          // starts the draft (Free Transform)
    public mutating func commitTransform() throws         // one "Free Transform" step: resample once
    public mutating func cancelTransform()                // drops the draft, no step
    public mutating func resizeCanvas(width: Int, height: Int, anchor: BoxAnchor) throws   // one "Canvas Size" step
}
// Sources/PhotoModel/Contracts/LayerContracts.swift (PT-1)
public typealias FlipAxis = FlipDirection
```

Photo's own commands (beside the kernel's six): `transform.begin` (Free
Transform, view), `transform.commit` (Free Transform, edit), `transform.cancel`
(view), `image.canvas-size {width, height, anchor}` (Canvas Size, edit). While a
draft is up, `transform.set`, `rotate` and `scale` edit the draft: each records
one step whose undo restores the previous draft, so Undo walks back through
the draft and finally out of Free Transform.

## Pseudocode

- **setTransform.** No draft: begin one. Write the draft's `LayerTransform`
  from the box (`scaleX = box.w / bounds.w`, `degrees`, the move); a flip
  applies `flipped` to the layer's pixels at once (one step), never a draft.
- **commit.** `transformed(TransformRules.matrix(of:) as AffineMatrix,
  width:height:, .lanczos3)` into the layer's new bounds; the identity commits
  nothing and records nothing.
- **resizeCanvas.** `origin = TransformRules.anchoredOrigin(old, new, anchor)`;
  every layer's offset moves by `origin`; the background layer pads with the
  background colour through `padded(anchor:)`; a smaller size crops; selection
  and pending crop drop, as `resizeImage` does.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PT-1 | – | The adapter and Photo's four transform methods as stubs; `FlipAxis` as the kernel's `FlipDirection`; `PhotoTransformTests` written, disabled | `Sources/PhotoModel/PhotoTransform+Kernel.swift`, `Sources/PhotoModel/Contracts/LayerContracts.swift`, `Tests/PhotoModelTests/PhotoTransformTests.swift` | – | ~150, 3 |
| PT-2 | – | Free Transform on the stubs: `TransformIntent`'s cases and route (Return commits, Escape cancels), the overlay with `SelectionHandlesEditor(degrees:)`, `TransformRows` in the options, Edit > Free Transform and Flip menu items; the journey written, skipped | `Sources/PhotoApp/PhotoWindow+Transform.swift`, `Sources/PhotoApp/TransformOverlay.swift`, `Sources/PhotoApp/TransformOptions.swift`, `Sources/PhotoApp/PhotoCommands+Edit.swift`, `UITests/PhotoJourneyTests+Transform.swift` | PT-1 | ~320, 5 |
| PT-3 | – | Image > Canvas Size…: the sheet (relative and absolute sizes, the 3 × 3 anchor grid, the crop note) presented from the transform area | `Sources/PhotoApp/CanvasSizeSheet.swift`, `Sources/PhotoApp/PhotoCommands+Image.swift`, `Sources/PhotoApp/PhotoWindow+Transform.swift`, `Tests/AppSnapshotTests/PhotoCanvasSizeSheetTests.swift` | PT-2 | ~260, 4 |
| PT-4 | – | `applied` and `flipped` bodies on CoreRaster; `KernelBox`'s turn maths replaced by `TransformRules.local` and `matrix` | `Sources/PhotoModel/Live/LiveTransform+Kernel.swift`, `Tests/PhotoModelTests/LiveTransformTests.swift`, `Tests/mutations/PhotoModel.LiveTransform+Kernel.json` | PT-1 | ~220, 3 |
| PT-5 | – | Adapter bodies (draft steps, commit, cancel, flips), the kernel's six specs and Photo's three in the catalog and id list; turns on `PhotoTransformTests`; RJ-P17's job folder | `Sources/PhotoModel/PhotoTransform+Kernel.swift`, `Tests/PhotoModelTests/PhotoTransformTests.swift`, `Tests/mutations/PhotoModel.PhotoTransform+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/RealJobs/photo/free-transform/free-transform.jobs.json`, `Tests/RealJobs/photo/free-transform/input/logo-on-photo.photo` | PT-1, PT-4 | ~340, 7 |
| PT-6 | – | `resizeCanvas(width:height:anchor:)` and `image.canvas-size`'s body; RJ-P18's job folder | `Sources/PhotoModel/PhotoImageOps.swift`, `Tests/PhotoModelTests/PhotoCanvasSizeTests.swift`, `Tests/mutations/PhotoModel.PhotoImageOps.json`, `Tests/RealJobs/photo/canvas-border/canvas-border.jobs.json`, `Tests/RealJobs/photo/canvas-border/input/photo-2000x1400.png` | PT-5 | ~220, 5 |
| PT-7 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoTransformSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoTransformTests.swift` | PT-3 | ~200, 2 |
| PT-8 | – | The journey turned on, on live services | `UITests/PhotoJourneyTests+Transform.swift` | PT-7, PT-6 | ~60, 1 |
| PT-9 | – | `status: built`; `feature-done` | `docs/blueprints/photo/features/transform.wave.json` | PT-8 | ~10, 1 |

## Build waves

- Wave 1: PT-1. Independent in this wave: PT-1 alone.
- Wave 2: PT-2, PT-4. Independent in this wave: both.
- Wave 3: PT-3, PT-5. Independent in this wave: both.
- Wave 4: PT-6, PT-7. Independent in this wave: both.
- Wave 5: PT-8. Independent in this wave: PT-8 alone.
- Wave 6: PT-9 (`feature-done`, final). Independent in this wave: PT-9 alone.

Longest chain: PT-1 → PT-2 → PT-3 → PT-7 → PT-8 → PT-9 (6). Chain of 6: the draft's commands need the stubs and the resample, Canvas Size runs through the registered command, the journey runs on all three, and PT-9 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PT-1 | `PhotoTransformTests` compiles, disabled; every existing `FlipAxis` use still builds | a caller breaks | – (stub) |
| PT-2 | `PhotoInspectorSnapshots` with the draft up on the stubs: handles and rows show; Edit > Free Transform is enabled with a layer | the overlay or rows are missing | – (UI) |
| PT-3 | `PhotoCanvasSizeSheetTests`: relative +400 sets 2400 × 1800; the anchor grid emits its anchor; a smaller size shows the crop note | a size or anchor is wrong | – (UI) |
| PT-4 | `LiveTransformTests`: the identity commit gives the layer back bit for bit; a 90° turn of a 4 × 2 layer is 2 × 4; flip twice gives the input; the draft's corners equal `TransformRules.corners` | a resample, flip or corner is wrong | `PhotoModel.LiveTransform+Kernel`: matrix inverted → `.turn90Size`; flip axis swapped → `.flipHorizontal` |
| PT-5 | `PhotoTransformTests`: a scale and a turn edit the draft as one step each; commit is one "Free Transform"; cancel records nothing; a flip is one step and keeps the layer's bounds; a locked layer refuses with its help; RJ-P17 passes on Linux | a step count, a bound or a refusal is wrong | `PhotoModel.PhotoTransform+Kernel`: flip about the canvas → `.flipInPlace`; identity commit records → `.identityCommitsNothing`; locked not checked → `.lockedRefuses` |
| PT-6 | `PhotoCanvasSizeTests`: +400 about the centre moves every layer by (200, 200) and pads the background; a smaller size crops; one step; RJ-P18 passes on Linux | a border is missing or a layer drifts | `PhotoModel.PhotoImageOps`: anchor ignored → `.canvasSizeCentred`; background padded transparent → `.borderIsBackground` |
| PT-7 | `PhotoTransformSnapshots`; `RenderBudgetPhotoTransformTests.cornerDragInThreeBodies` | budget over | – (UI) |
| PT-8 | `testFreeTransformTurnFlip` steps 1 to 6 on live | a step fails | – |
| PT-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample corner drag on a 12 MP layer, draft preview | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetPhotoTransformTests.cornerDragInThreeBodies` |
| render: 120-sample rotation-row scrub | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetPhotoTransformTests.rotationScrubInThreeBodies` |
| One gesture, one step | a handle drag, a row scrub, Return, a flip, Canvas Size each one step | `PhotoTransformTests.oneStepPerGesture` |
| Commit off the main actor | the lanczos resample of a 12 MP layer runs detached | `PhotoTransformTests.commitIsDetached` |
| No dead controls; keyboard parity | Return commits, Escape cancels, Tab reaches each row and the sheet's anchors | `testFreeTransformTurnFlip` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PT-m merged-done with RJ-P17 and RJ-P18
green in the Linux job; PT-u's feel gate and `Mac-Finish:`; PT-z's journey on
live. Then `Belt-Contact-Sheet:` with `photo-free-transform-*` and
`photo-canvas-size*`.

## Not in this packet

Skew, distort, perspective and warp; transform of several layers at once;
transforming a selection's pixels without a layer. Flip Canvas (the whole
image) is back in the beta in `suiteui/orientation-crop` (OC-photo-m and
OC-photo-u), as the blueprint's v2 line had it (captain, 2026-10-21).
