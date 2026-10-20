# Feature packet: placed-images (Halo)

**Feature:** a logo comes into Halo. File > Place… (⇧⌘P) and a drop on the
viewer add a solid layer holding the picture (PNG, JPEG or SVG) at its own
size, centred in the composition; with a solid selected and **Fill** on, the
picture goes into that solid instead. The picture moves, scales, turns and
fades with the layer's keys like any solid, draws in the viewer and in the
render through the same crop, and every edit is one of SuiteKernel's place
commands, so the CLI and an agent can bring a logo in too.
**Line:** `line:halo` · **Wave:** W5 (`waves.md`) · **Lead branch:** `lead/placed-images`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/placed-images` (adopter of S20 and E11); real
jobs RJ-H02 (the logo reveal, closes here) and RJ-H36 (new).

**Depends on:** `suiteui/placed-images` **PL-a** (cross-line); PH-6 needs its
**PL-7**, PH-3 its **PL-3** (`drawPlaced`, `PlacedImageRows`), PH-5 its
**PL-6** (`PlacedVector`). Same line: gradient-fill's **HG-a** (it owns
`HaloLayer.swift` and `HaloDocumentValues.swift`) before PH-1, its **HG-u**
(`HaloLayerInspector.swift`) before PH-3, its **HG-m** (`HaloDrawRules.swift`,
`LiveFrameRendering.swift`, `HaloCommandCatalog.swift`) before PH-5 and PH-6,
its **HG-z** (`halo.md`) before PH-8; core-loop's **CL-probe**
(`HaloLayerInspector.swift`) before PH-3; foundation, viewer-playback,
render-out and text-layers (built).

**Beta gaps A (#3432, merged first).** Its packets share files with this one, so these slices also wait on theirs: PH-a on `shape-tools:HS-a`, `stroke-style:HK-a`; PH-u on `transform:HT-a`, `shape-tools:HS-a`, `stroke-style:HK-a`; PH-m on `autosave-history:HA-m`, `transform:HT-m`, `shape-tools:HS-m`, `stroke-style:HK-m`.

**Hand-offs:** `HaloCommandCatalog.swift`, `HaloFileMenu.swift` and
`Tests/command-ids/halo.txt` are adopt-command-catalog's (#2999): PH-3 and
PH-6 start after AC-halo's `Belt-Slice-Done:`.

**Rule 20.** No Halo picture type and no new layer kind (every switch over
`HaloLayerKind` stays as it is): a solid stores the kernel's `PlacedAsset` and
a focus point, and `HaloPlace+Kernel.swift` maps the solid's `rect` to
`PlacedImage.box`. The viewer draws it through SuiteUI's `drawPlaced`; the
render draws it on CoreRaster in `HaloPlacedDrawing.swift`, both inside
`PlaceRules.drawnRect`. A raster is decoded once per asset id with
CoreRaster's `PNG.read` / `JPEG.read`; an SVG is `PlacedVector`, each item's
contours through `Mask.polygon` combined even-odd and filled in linear light.

**Render path.** One branch in the solid case of `LiveFrameRendering`: a
solid with a picture takes its source from `HaloPlacedDrawing` (the decoded
pixels through the item's matrix with CoreRaster's affine composite, or the
vector fill), clipped to the solid's outline coverage, in place of its colour.
No new route; the viewer and Render… stay one path each, as today.

Blueprint sections: halo.md 6 (layer inspector), 7 (render).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PH-a | A solid's picture fields, the draw item's copy and `HaloProject`'s `PlacedImageTarget` conformance exist as stubs, and the checks and job folders are written, disabled. | PH-1, PH-2 | MJ-PH | suiteui/placed-images PL-a (cross-line); gradient-fill:HG-a |
| PH-u | File > Place… and a viewer drop add a solid with the picture on the stubs, the viewer draws it by cover, and the inspector shows its rows, with snapshots, the render budget and the journey written. | PH-3, PH-4 | HJ-P1 | PH-a; gradient-fill:HG-u, core-loop:CL-probe (PH-3); PL-3 (cross-line) |
| PH-m | The render draws a solid's PNG, JPEG or SVG picture at its matrix inside its outline, and every place command runs as one undo step. | PH-5, PH-6 | MJ-PH | PH-a; gradient-fill:HG-m; PL-6, PL-7 (cross-line) |
| PH-z | The window runs on live services, the journey passes on live, and the blueprint lists pictures in solids. | PH-7, PH-8 | HJ-P1 | PH-u, PH-m; gradient-fill:HG-z (PH-8) |

PH-u waits only on PH-a and other features' slices (rule 18); PH-m never
waits on PH-u. MJ-PH is the Model walk in `HaloPlaceTests` (Linux).

## Journey steps

1. New composition, 1920 × 1080 (`HaloPlaceJourneyTests.testPlaceLogo`).
2. File > Place… (PH-3) and choose the journey kit's `logo.svg` (480 × 160):
   a solid named `logo` appears centred at 480 × 160, the logo's two colours
   on a clear solid; the inspector reads "logo.svg · SVG · 480 × 160".
3. Key Scale 0% at frame 0 and 100% at frame 30 with an overshoot ease; key
   Opacity 0 → 100: scrubbing shows the logo growing and fading in.
4. Render frame 30 to PNG (PH-5): the logo's red and blue sit where the viewer
   showed them.
5. Select a full-frame solid, Place… `photo-1200x800.jpg` with Fill on: the
   solid shows the photo by cover; ⌥-drag in the viewer pans it; Undo puts
   the pan back in one step.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H36 | adds, closes with `halo/placed-images` | C | `Tests/RealJobs/halo/place-logo/place-logo.jobs.json`: `place.image` of `logo.png` (base64, 200 × 100, a red left half and a blue right half), `timeline.scrub` 0, export the frame as PNG | `input/empty-400.halo` (one 400 × 400 composition, black background) |
| RJ-H02 | closes with `halo/placed-images` | Cm | `Tests/RealJobs/halo/logo-reveal/logo-reveal.jobs.json`: `place.image` of `logo.svg`, keys on scale (overshoot) and opacity over 5 s, `render.start` H.264 1080p | `input/empty-1080.halo` |

RJ-H36's trap: the viewer shows the logo but the render path draws the
solid's colour, or the logo is squashed to the composition. Assertion: in the
PNG the pixel at (150, 200) is within 2/255 of red and (250, 200) of blue, and
(90, 200) and (310, 200), outside the 200 × 100 logo, are background.
Mutation: `HaloModel.HaloPlacedDrawing.json`, the picture branch skipped →
`HaloPlaceRenderTests.logoPixels`. RJ-H02's trap is the same on the movie
path: frame 150's centre holds the logo's colours and frame 0 is background.

## Screens and states

`halo-place-logo` (an SVG logo on a clear solid), `halo-place-fill` (a photo
filling a solid by cover), `halo-place-inspector` (the rows), light and dark.

## Contract slice

```swift
// Sources/HaloModel/HaloLayer.swift (PH-1): solids only; other kinds keep nil. Coded only when set.
extension HaloLayer {
    public var placedAsset: PlacedAsset?
    public var placedFocus: Point
}
// Sources/HaloModel/Contracts/HaloDocumentValues.swift (PH-1)
extension HaloDrawItem { public var placedAsset: PlacedAsset?; public var placedImage: PlacedImage? }   // HaloDrawRules fills both (PH-5)
// Sources/HaloModel/HaloPlace+Kernel.swift (PH-1 stubs, PH-6 bodies)
extension HaloProject: PlacedImageTarget {
    public var placeHelp: String? { get }              // no composition; a text or null layer selected for fill
    public var placeCanvas: Rect { get }               // the composition's frame
    public var placeFillBox: Rect? { get }             // the one selected solid's rect
    public var placeFormats: Set<PlacedFormat> { get } // all three
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { get }
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size   // PNG.info, JPEG.info
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws
}
// Sources/HaloModel/Live/HaloPlacedDrawing.swift (PH-1 stub drawing nothing, PH-5 body)
enum HaloPlacedDrawing {
    static func source(_ asset: PlacedAsset, _ image: PlacedImage, matrix: HaloMatrix,
                       width: Int, height: Int, scaleX: Double, scaleY: Double) throws -> PixelBuffer?
}
```

`insertPlaced` adds a solid with a clear colour on top of the selected layer,
its `rect` the fitted box, named after the file without its extension, in
one "Place Image" step through `edit`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PH-1 | – | The solid's two fields, the draw item's copy, the conformance and `HaloPlacedDrawing` as stubs; `HaloPlaceTests` written, disabled | `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/Contracts/HaloDocumentValues.swift`, `Sources/HaloModel/HaloPlace+Kernel.swift`, `Sources/HaloModel/Live/HaloPlacedDrawing.swift`, `Tests/HaloModelTests/HaloPlaceTests.swift` | PL-a, gradient-fill:HG-a | ~220, 5 |
| PH-2 | – | Checks first for the render: `HaloPlaceRenderTests` disabled; RJ-H36's and RJ-H02's job folders with `waits_on: PH-5` | `Tests/HaloModelTests/HaloPlaceRenderTests.swift`, `Tests/RealJobs/halo/place-logo/`, `Tests/RealJobs/halo/logo-reveal/` | PH-1 | ~200, 7 |
| PH-3 | – | Reachable: File > Place… ⇧⌘P, the viewer's `placeDropTarget` at the drop point in composition space, ⌥-drag on a solid with a picture runs `place.focus` under one drag token, the viewer draws a solid's picture with `drawPlaced(..., strokes: false)`; `HaloPlaceInspector` (`PlacedImageRows` and the Fill toggle) slotted under the colour row | `Sources/HaloApp/HaloPlace.swift`, `Sources/HaloApp/HaloFileMenu.swift`, `Sources/HaloApp/HaloViewer.swift`, `Sources/HaloApp/HaloViewerCanvas.swift`, `Sources/HaloApp/HaloPlaceInspector.swift`, `Sources/HaloApp/HaloLayerInspector.swift` | PH-1, gradient-fill:HG-u, core-loop:CL-probe | ~320, 6 |
| PH-4 | – | Snapshots, the render budget test, the journey written and skipped (`XCTSkip("waits on PH-7")`) | `Tests/AppSnapshotTests/HaloPlaceSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloPlaceTests.swift`, `UITests/HaloJourneyTests+Place.swift` | PH-3 | ~220, 3 |
| PH-5 | – | `HaloDrawRules` carries the picture; `HaloPlacedDrawing` decodes once per asset id (raster) or fills `PlacedVector` (even-odd per item), through the matrix, clipped to the outline; one call in the solid branch of `LiveFrameRendering`; turns on `HaloPlaceRenderTests` and both jobs | `Sources/HaloModel/Live/HaloDrawRules.swift`, `Sources/HaloModel/Live/HaloPlacedDrawing.swift`, `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Tests/HaloModelTests/HaloPlaceRenderTests.swift`, `Tests/mutations/HaloModel.HaloPlacedDrawing.json`, `Tests/RealJobs/halo/place-logo/`, `Tests/RealJobs/halo/logo-reveal/` | PH-2, gradient-fill:HG-m | ~340, 7 |
| PH-6 | – | Conformance bodies (one step through `edit`, the drag token as the coalesce key); the five specs in the catalog and the id list; turns on `HaloPlaceTests` | `Sources/HaloModel/HaloPlace+Kernel.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/HaloModelTests/HaloPlaceTests.swift`, `Tests/mutations/HaloModel.HaloPlace+Kernel.json` | PH-1, PL-7, gradient-fill:HG-m | ~260, 5 |
| PH-7 | – | Live: the journey turned on, on live services | `UITests/HaloJourneyTests+Place.swift` | PH-4, PH-5, PH-6 | ~40, 1 |
| PH-8 | – | halo.md lists pictures in solids and Place; `status: built`; `feature-done` | `docs/blueprints/halo.md`, `docs/blueprints/halo/features/placed-images.wave.json` | PH-7, gradient-fill:HG-z | ~30, 2 |

The packet PR lists the three new Halo files in `halo/c4-planned.json` (its
`owned_files_planned` rule), as gradient-fill's did; `HaloPlacedDrawing.swift`
falls under `Live/`.

## Build waves

- Wave 1: PH-1. Independent in this wave: PH-1 alone.
- Wave 2: PH-2, PH-3, PH-6. Independent in this wave: all three.
- Wave 3: PH-4, PH-5. Independent in this wave: both.
- Wave 4: PH-7. Independent in this wave: PH-7 alone.
- Wave 5: PH-8 (shared prose, `feature-done`, final). Independent in this wave: PH-8 alone.

Longest chain: PH-1 → PH-3 → PH-4 → PH-7 → PH-8 (5). Chain of 5: the viewer
needs the fields, the journey drives the viewer, PH-7 turns it on live, PH-8
is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PH-1 | every saved Halo fixture opens and saves byte-equal (no picture keys); a duplicated solid keeps its picture; the suite compiles, disabled | an old project changes, or a copy drops the picture | – (stub) |
| PH-2 | compiles, disabled; both jobs disabled by `waits_on` | – | – |
| PH-3 | `HaloPlaceSnapshots.logo` (PH-4's, first in the slice PR) | the picture isn't drawn | – (UI) |
| PH-4 | `HaloPlaceSnapshots`; `RenderBudgetHaloPlaceTests.focusDragInThreeBodies` | budget over | – (UI) |
| PH-5 | `HaloPlaceRenderTests`: RJ-H36's four pixels; a 2× scale key doubles the logo's footprint; a picture never draws outside its solid's outline at a 30° turn; the SVG ring keeps its hole; a JPEG is decoded once for two solids showing it; RJ-H36 passes on Linux | a pixel is off by more than 2/255, or the asset decodes per frame | `HaloModel.HaloPlacedDrawing`: picture branch skipped → `.logoPixels`; matrix not applied → `.scaleKeyScalesPicture`; outline clip skipped → `.staysInsideOutline`; cache key per layer, not per asset → `.decodesOncePerAsset` |
| PH-6 | `HaloPlaceTests`: `place.image` adds a clear solid at the fitted box, on top of the selection; `fill: true` on a text layer is unavailable with its reason; 30 focus moves under one token are one step; undo of a place removes the solid and its picture | a box, refusal or step count is wrong | `HaloModel.HaloPlace+Kernel`: text layers allowed to fill → `.textRefusesFill`; drag key dropped → `.focusDragIsOneStep` |
| PH-7 | `HaloPlaceJourneyTests.testPlaceLogo` steps 1 to 5 | a step fails | – |
| PH-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample ⌥-drag on a 4000 × 3000 photo with the viewer live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHaloPlaceTests.focusDragInThreeBodies` |
| Frame cost | a full-frame 1080p photo solid adds ≤ 25 ms to a frame render after its first decode (reported) | `HaloPlaceRenderTests.fullFrameCost` |
| One gesture, one step | a place, a focus drag, a replace | `HaloPlaceTests.focusDragIsOneStep` |
| No dead controls | Place…, Fill, Replace…, Reset Size in `halo.controls` | `testPlaceLogo` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PH-m merged-done with RJ-H36 green in the
Linux job; PH-u's feel gate and `Mac-Finish:`; PH-z's journey on live and
RJ-H02 green in the scoped run (`Cm`). Then `Belt-Contact-Sheet:` with
`halo-place-*`.

## Not in this packet

Footage layers (S20's video half rides shell-media, E9), SVG strokes (no
public stroke outliner in FlareCore yet: the render skips them, the viewer
calls `drawPlaced(..., strokes: false)` so the two agree, and the inspector
shows the place report's "Strokes aren't drawn yet" line until a creative-core
issue lands), pictures in shape and text layers, track
mattes from a picture, linked assets.
