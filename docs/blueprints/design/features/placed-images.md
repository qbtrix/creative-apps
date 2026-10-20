# Feature packet: placed-images (Design)

**Feature:** Design takes pictures. A rectangle or a frame can hold a picture
(PNG, JPEG or SVG) that fills its box by cover. File > Place… (⇧⌘P) and a
drop on the canvas add a rectangle holding the picture at its own size; with
a frame or rectangle selected and **Fill** on, the picture goes into that
layer instead, so a photo in a rounded frame keeps its aspect and ⌥-drag moves
it inside the crop. The picture draws on the canvas, in PNG and PDF export
(the same artwork) and in SVG export (`<image>` clipped to the box).
Every edit is one of SuiteKernel's place commands, so the CLI and an agent
can place, replace and move a picture too.
**Line:** `line:design` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/placed-images`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `design/placed-images` (adopter of S20 and E11);
real job RJ-D12 (closes here). RJ-D01 (the Instagram post) also needs S10's
frame presets and stays on S10.

**Depends on:** `suiteui/placed-images` **PL-a** (cross-line); PD-5 needs its
**PL-7**, PD-4 its **PL-3** (`drawPlaced`). Same line: gradient-fill's **DG-a**
(it owns `DesignNode.swift` and `DesignInspector.swift`) before PD-1 and PD-4,
its **DG-u** (`DesignCanvasMarks.swift`) before PD-3, its **DG-m**
(`DesignCommandCatalog.swift`, `DesignSVG.swift`) before PD-5 and PD-6, its
**DG-z** (`design.md`) before PD-8; design-export's **DE-u**
(`DesignCommands.swift`) before PD-3 and **DE-s** (`DesignSVG.swift`) before
PD-6. design-seams-2 (p3) now waits on this packet's slices, since both own
`DesignNode.swift`, `DesignCanvas.swift` and `DesignCanvasMarks.swift`.

**Beta gaps A (#3432, merged first).** Its packets share files with this one, so these slices also wait on theirs: PD-a on `transform:DT-a`, `shape-tools:DS-a`, `stroke-style:DK-m`; PD-u on `autosave-history:DA-a`, `transform:DT-a`, `transform:DT-u`, `shape-tools:DS-a`, `shape-tools:DS-u`, `stroke-style:DK-u`; PD-m on `autosave-history:DA-m`, `transform:DT-m`, `eyedropper:DY-m`, `shape-tools:DS-m`, `stroke-style:DK-m`.

**Hand-offs:** `DesignCommandCatalog.swift` and `Tests/command-ids/design.txt`
are adopt-command-catalog's (#2999): PD-5 starts after AC-design's
`Belt-Slice-Done:`.

**Rule 20.** No Design picture type and no new node kind (every switch over
`DesignNodeKind` stays as it is). A rectangle or frame stores the kernel's
`PlacedAsset` and a focus point; `DesignPlace+Kernel.swift` maps the node's
`frame` to `PlacedImage.box`, so the frame stays the one source of the box,
and the node's fill shows only where a transparent picture lets it. The canvas and the PNG and PDF export draw through SuiteUI's
`drawPlaced`; the SVG writer takes its rectangle from `PlaceRules.drawnRect`.
**Design's Model links CoreRaster** (PD-1, one line in `Package.swift`: a
product of the package it already pins, no new dependency) for
`PNG.info`/`JPEG.info` in `rasterSize`, so the CLI places on Linux. That task
touches a protected path: the supervisor merges it after the macOS build.

**Each node stores its own asset.** `DesignDocument` is pages only, and
`DesignWorkspace.swift` and `DesignFile.swift` belong to design-seams-2, so
the asset rides on the node (duplicate and paste copy it with
`init(id:copying:)`). ponytail: one copy per node with a picture; share through
`PlacedAssets` in the document when files with repeated pictures grow.

Blueprint sections: design.md 3 (canvas), 4 (inspector), 6 (export).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PD-a | The picture fields on rectangles and frames and the `PlacedImageTarget` conformance exist as stubs, CoreRaster is linked, and the checks and RJ-D12's job are written, disabled. | PD-1, PD-2 | MJ-PD | suiteui/placed-images PL-a (cross-line); gradient-fill:DG-a |
| PD-u | File > Place… and a canvas drop add a picture on the stubs, the canvas draws it by cover, and the inspector shows its rows, with snapshots, the render budget and the journey written. | PD-3, PD-4 | DJ-P1 | PD-a; gradient-fill:DG-u, design-export:DE-u (PD-3); gradient-fill:DG-a (PD-4); PL-3 (cross-line) |
| PD-m | Placing fits inside the selected frame or covers it with Fill, a focus move the picture inside its box as one undo step, and SVG export writes the same crop. | PD-5, PD-6 | MJ-PD | PD-a; gradient-fill:DG-m; design-export:DE-s (PD-6); PL-7 (cross-line) |
| PD-z | The window runs on live services, the journey passes on live, and the blueprint lists pictures in rectangles and frames. | PD-7, PD-8 | DJ-P1 | PD-u, PD-m; gradient-fill:DG-z (PD-8) |

PD-u waits only on PD-a and other features' slices (rule 18); PD-m never
waits on PD-u. MJ-PD is the Model walk in `DesignPlaceTests` (Linux).

## Journey steps

1. Draw a 400 × 400 frame and set its corner radius to 24
   (`DesignPlaceJourneyTests.testPlacePhotoInFrame`).
2. With the frame selected, File > Place… (PD-3): the panel takes PNG, JPEG
   and SVG; choose the journey kit's `photo-1200x800.jpg` with Fill on. The
   picture fills the frame, its sides cropped, corners rounded; no new layer.
3. ⌥-drag right inside the picture: it pans inside the frame; one undo step.
4. Drag the frame's right edge out to 600: the picture still covers it, no
   squash; the inspector reads "photo-1200x800.jpg · JPEG · 1200 × 800 px".
5. Reset Size: the frame goes back to 3:2. Undo, Undo: the size and the pan
   go back one step each. Place… again with nothing selected: a new rectangle
   named `photo-1200x800` at 1200 × 800 fitted into the page.
6. Export > SVG (PD-6): the file's `<image>` sits in a clip of the node's box
   with the same crop the canvas shows.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D12 | closes with `design/placed-images` | C | `Tests/RealJobs/design/place-in-frame/place-in-frame.jobs.json`: `edit.select` the frame, `place.image` (`photo.png`, 1200 × 800, base64) with `fill: true`, `place.focus` 0.2, 0.5, `file.save`; the saved file and `place.read` | `input/rounded-frame.design` (one 400 × 400 frame, radius 24), `input/photo.png` |

Trap: the image is stretched to the frame. Assertion: `place.read`'s `drawn`
is 600 × 400 (3:2 kept) with x at the focus' offset, the saved frame keeps
its box and radius, and the page has no new node. Mutations: `DesignModel.DesignPlace+Kernel.json`,
`fill` box taken from the image's natural size instead of the frame →
`DesignPlaceTests.fillTakesTheFrame`.

## Screens and states

`design-image-fitted` (a new rectangle at the picture's size),
`design-image-in-frame` (cover, rounded), `design-image-svg` (a placed SVG
logo), `design-image-inspector` (the rows),
`design-place-drop` (the canvas highlight), light and dark.

## Contract slice

```swift
// Sources/DesignModel/DesignNode.swift (PD-1): rectangles and frames only; every other kind keeps nil.
extension DesignNode {
    public var placedAsset: PlacedAsset?               // coded only when set; copied by init(id:copying:)
    public var placedFocus: Point                      // coded only when not the centre
}
// Sources/DesignModel/DesignPlace+Kernel.swift (PD-1 stubs, PD-5 bodies)
extension DesignWorkspace: PlacedImageTarget {
    public var placeHelp: String? { get }              // no page; a locked parent
    public var placeCanvas: Rect { get }               // the selected frame, else the frame under the view centre, else the page
    public var placeFillBox: Rect? { get }             // the one selected frame or rectangle, unlocked
    public var placeFormats: Set<PlacedFormat> { get } // all three
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { get }
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws
}
```

`insertPlaced` adds a rectangle (fill clear) inside the selected frame (or
the frame the box falls in, else at the top), named after the file without
its extension. `setPlaced` with an asset on a layer without one is Fill.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PD-1 | – | The two node fields (rectangles and frames; coded only when set, copied by `init(id:copying:)`), the conformance as stubs, CoreRaster on DesignModel; `DesignPlaceTests` written, disabled | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignPlace+Kernel.swift`, `Package.swift`, `Tests/DesignModelTests/DesignPlaceTests.swift` | PL-a, gradient-fill:DG-a | ~200, 4 |
| PD-2 | – | Checks first for SVG and the job: `DesignPlaceSVGTests` disabled; RJ-D12's job folder with `waits_on: PD-6` | `Tests/DesignModelTests/DesignPlaceSVGTests.swift`, `Tests/RealJobs/design/place-in-frame/` | PD-1 | ~140, 4 |
| PD-3 | – | Reachable: File > Place… ⇧⌘P (panel, then `place.image`), the canvas `placeDropTarget` at the drop point in page space (onto a selected frame with Fill on: `fill: true`), ⌥-drag on a node with a picture runs `place.focus` under one drag token, a rectangle's or frame's picture drawn by `drawPlaced` over its fill with its corner radius | `Sources/DesignApp/DesignPlace.swift`, `Sources/DesignApp/DesignCommands.swift`, `Sources/DesignApp/DesignCanvas.swift`, `Sources/DesignApp/DesignCanvasMarks.swift` | PD-1, gradient-fill:DG-u, design-export:DE-u | ~200, 4 |
| PD-4 | – | Inspector: `DesignInspectorImage` (`PlacedImageRows`, plus a Fill toggle the next Place reads) slotted for a node with a picture, and Place… in the rectangle and frame sections; snapshots, the render budget, the journey written and skipped (`XCTSkip("waits on PD-7")`) | `Sources/DesignApp/DesignInspectorImage.swift`, `Sources/DesignApp/DesignInspector.swift`, `Tests/AppSnapshotTests/DesignPlaceSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignPlaceTests.swift`, `UITests/DesignJourneyTests+Place.swift` | PD-1, gradient-fill:DG-a | ~300, 5 |
| PD-5 | – | Conformance bodies; the five specs in the catalog and the id list; turns on `DesignPlaceTests` | `Sources/DesignModel/DesignPlace+Kernel.swift`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/DesignModelTests/DesignPlaceTests.swift`, `Tests/mutations/DesignModel.DesignPlace+Kernel.json` | PD-1, PL-7, gradient-fill:DG-m | ~300, 5 |
| PD-6 | – | `DesignSVG` writes a rectangle's or frame's picture as a `<clipPath>` of its rounded box and an `<image href="data:…">` at `drawnRect`, after its fill; turns on `DesignPlaceSVGTests` and RJ-D12 | `Sources/DesignModel/Live/DesignSVG.swift`, `Tests/DesignModelTests/DesignPlaceSVGTests.swift`, `Tests/mutations/DesignModel.DesignSVG.json`, `Tests/RealJobs/design/place-in-frame/` | PD-2, gradient-fill:DG-m, design-export:DE-s | ~180, 4 |
| PD-7 | – | Live: the journey turned on, on live services | `UITests/DesignJourneyTests+Place.swift` | PD-3, PD-4, PD-5, PD-6 | ~40, 1 |
| PD-8 | – | design.md lists pictures in rectangles and frames and Place; `status: built`; `feature-done` | `docs/blueprints/design.md`, `docs/blueprints/design/features/placed-images.wave.json` | PD-7, gradient-fill:DG-z | ~30, 2 |

## Build waves

- Wave 1: PD-1. Independent in this wave: PD-1 alone.
- Wave 2: PD-2, PD-3, PD-4, PD-5. Independent in this wave: all four.
- Wave 3: PD-6. Independent in this wave: PD-6 alone.
- Wave 4: PD-7. Independent in this wave: PD-7 alone.
- Wave 5: PD-8 (shared prose, `feature-done`, final). Independent in this wave: PD-8 alone.

Longest chain: PD-1 → PD-2 → PD-6 → PD-7 → PD-8 (5). Chain of 5: the SVG
test needs the node fields, the writer turns it on, the live journey needs
the export, PD-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PD-1 | every saved Design fixture decodes and re-encodes byte-equal (no `placedAsset` key); a duplicated or pasted frame keeps its picture and focus; the suite compiles, disabled | an old file changes, or a copy drops the picture | – (stub) |
| PD-2 | compiles, disabled; RJ-D12 disabled by `waits_on` | – | – |
| PD-3 | `DesignPlaceSnapshots.inFrame` (PD-4's, first in the slice PR) | the node isn't drawn | – (UI) |
| PD-4 | `DesignPlaceSnapshots`; `RenderBudgetDesignPlaceTests.focusDragInThreeBodies` | budget over | – (UI) |
| PD-5 | `DesignPlaceTests`: a place with a frame selected adds a rectangle inside it, fitted; with `fill: true` the frame itself takes the picture and no node is added; an ellipse or text selected refuses `fill` with its reason; a JPEG's size comes from its header; a locked frame refuses; 30 focus moves under one token are one step; Reset Size restores 3:2 | a box, parent, size or step count is wrong | `DesignModel.DesignPlace+Kernel`: fill box from natural size → `.fillTakesTheFrame`; parent ignored → `.landsInSelectedFrame`; drag token dropped → `.focusDragIsOneStep` |
| PD-6 | `DesignPlaceSVGTests`: a frame with a picture writes one `clipPath` with `rx` and an `<image>` at `drawnRect`'s x, y, width, height; a PNG's href is `data:image/png;base64,`; RJ-D12 passes on Linux | the export stretches, loses the clip or the crop | `DesignModel.DesignSVG`: box written for `drawnRect` → `.imageKeepsAspect`; clip omitted → `.imageClipsToBox` |
| PD-7 | `DesignPlaceJourneyTests.testPlacePhotoInFrame` steps 1 to 6 | a step fails | – |
| PD-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample ⌥-drag inside a 4000 × 3000 photo | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignPlaceTests.focusDragInThreeBodies` |
| render: 120-sample frame resize with a covered photo | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignPlaceTests.resizeCoveredInThreeBodies` |
| One gesture, one step | a place, a focus drag, a Reset Size | `DesignPlaceTests.focusDragIsOneStep` |
| No dead controls | Place…, Fill, Replace…, Reset Size in `design.controls` | `testPlacePhotoInFrame` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PD-m merged-done with RJ-D12 green in the
Linux job; PD-u's feel gate and `Mac-Finish:`; PD-z's journey on live. Then
`Belt-Contact-Sheet:` with `design-image-*`.

## Not in this packet

Editable vectors from an SVG (Design has no path node: S19 and E11 for
Design), pictures in ellipses and text, masks, filters on images, linked assets, HEIC and TIFF (see the shared
packet).
