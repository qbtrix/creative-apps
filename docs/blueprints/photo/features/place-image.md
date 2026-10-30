# Feature packet: place-image (Photo)

**Feature:** Photo gets File > Place… (⇧⌘P): a PNG or JPEG comes in as a new
pixel layer above the selected one, named after the file, scaled down to fit
the canvas when it is larger (never up), centred, in one undo step. Dropping a
PNG or JPEG on an open document places it at the drop point; with no document
open a drop still opens the file, as today. It runs through SuiteKernel's
`place.image`, so the CLI and an agent place a logo too.
**Line:** `line:photo` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/place-image`
**Beta:** captain, 2026-10-20 ("Photo Place if it isn't there"; it isn't: a drop opens the file and Paste is the only way in). Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/place-image` (adopter of S20); real job RJ-P37
(new).

**Depends on:** `suiteui/placed-images` **PL-a** (cross-line); PP-5 needs its
**PL-7**, PP-3 its **PL-3** (`PlacePanel`, `placeDropTarget`). Same line:
gradient-fill's **PG-m** (it owns `PhotoCommandCatalog.swift` and
`Tests/command-ids/photo.txt`) before PP-6, its **PG-z** (`photo.md`) before
PP-8; photo-documents and photo-edit (built).

**Beta gaps A (#3432, merged first).** Its packets share files with this one, so these slices also wait on theirs: PP-m on `transform:PT-m`, `history-panel:PH-m`, `eyedropper:PE-m`.

**Hand-offs:** `PhotoCommands+File.swift` is adopt-command-catalog's (#2999)
and `PhotoEditor.swift` adopt-suiteui-chrome's (AC-tools): PP-3 starts after
both slices' `Belt-Slice-Done:`.

**Rule 20.** No Photo place logic beyond the adapter. The fit is the kernel's
`PlaceRules.fitted` (Paste keeps its own placement rule, which centres at
100%: a different gesture), the resample is CoreRaster's, and the layer insert
is the one Paste already uses, lifted out of `paste` into one internal
`insertPixelLayer(_:named:x:y:step:)` that both call, so Place and Paste can't
drift. Photo keeps no picture after a place (it becomes pixels), so
`place.replace`, `place.reset-size`, `place.focus` and `fill` are unavailable
with "A placed image becomes pixels in Photo." An SVG is drawn into pixels
at its placed size by SuiteImaging's `PlacedVectorPixels` (#6028): fills only,
a gradient as its middle colour, no strokes or text, and an SVG with no fill
is refused saying so. Any other file is refused with "Photo places PNG, JPEG
or SVG files."

**Render path.** None new: the layer is pixels, composited by Photo's
existing route.

Blueprint sections: photo.md 2 (menus), 4 (layers).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PP-a | `PhotoWorkspace`'s `PlacedImageTarget` conformance exists as stubs, and the checks and RJ-P37's job are written, disabled. | PP-1, PP-2 | MJ-PP | suiteui/placed-images PL-a (cross-line) |
| PP-u | File > Place… and a drop on an open document run `place.image` on the stubs, a drop with no document still opens, with snapshots, the render budget and the journey written. | PP-3, PP-4 | PJ-P1 | PP-a; photo-seams, photo-render-adopt, shell-parity (built; they own `PhotoCommands+File.swift` and `PhotoEditor.swift`); PL-3 (cross-line) |
| PP-m | Placing a PNG or JPEG adds a pixel layer above the selection, fitted and centred or at the drop point, as one undo step, refuses SVG with the reason, and runs from the catalog. | PP-5, PP-6 | MJ-PP | PP-a; gradient-fill:PG-m (PP-6); PL-7 (cross-line) |
| PP-z | The window runs on live services, the journey passes on live, and the blueprint lists Place. | PP-7, PP-8 | PJ-P1 | PP-u, PP-m; gradient-fill:PG-z, multi-layer-select:PM-z (PP-8) |

PP-u waits only on PP-a (rule 18); PP-m never waits on PP-u. MJ-PP is the
Model walk in `PhotoPlaceTests` (Linux).

## Journey steps

1. New Image, 800 × 600, white (`PhotoPlaceJourneyTests.testPlaceLogo`).
2. File > Place… (PP-3) and choose the journey kit's `logo.png` (200 × 100):
   a layer `logo` appears above Background, centred, at 100%.
3. Place `photo-4000x3000.jpg`: a layer at 800 × 600 (fitted, never larger
   than the canvas); the status line reads "Placed at 20%."
4. Undo: the photo layer goes in one step; the logo stays.
5. Place `notes.txt`: nothing is added; the status line reads "Photo places
   PNG, JPEG or SVG files."

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P37 | adds, closes with `photo/place-image` | C | `Tests/RealJobs/photo/place-logo/place-logo.jobs.json`: `place.image` of `logo.png` (base64, 200 × 100, red left half, blue right half), output the flattened PNG | `input/canvas.png` (800 × 600 white) |

Trap: the place opens the logo as a new document, or lands it at the top-left
corner. Assertion: the output is 800 × 600 (the canvas, not the logo), the
pixel at (350, 300) is red and (450, 300) blue within 2/255, and (250, 300)
and (550, 300) are white. Mutation: `PhotoModel.PhotoPlace+Kernel.json`, the
fitted origin dropped (the layer at 0, 0) → `PhotoPlaceTests.centredOnCanvas`.

## Screens and states

`photo-place-logo` (the logo layer centred, the Layers panel showing it),
`photo-place-refused` (the SVG note in the status line), light and dark.

## Contract slice

```swift
// Sources/PhotoModel/PhotoPlace+Kernel.swift (PP-1 stubs, PP-5 bodies)
extension PhotoWorkspace: PlacedImageTarget {
    public var placeHelp: String? { get }              // no image open: "Open or make an image to place into."
    public var placeCanvas: Rect { get }               // the canvas
    public var placeFillBox: Rect? { get }             // nil
    public var placeFormats: Set<PlacedFormat> { get } // [.png, .jpeg]
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { get }   // nil
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size                   // PNG.info, JPEG.info
    /// Decodes, resamples to `image.box`'s size when smaller than natural, inserts a pixel layer named
    /// `asset.name` without its extension above the selection at the box's origin: one step titled `name`.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws // throws
}
// Sources/PhotoModel/PhotoClipboard.swift (PP-5): the insert Paste and Place share.
extension PhotoWorkspace {
    mutating func insertPixelLayer(_ tiles: TiledPixels, named: String, x: Int, y: Int, step: String) -> String
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PP-1 | – | The conformance as stubs; `PhotoPlaceTests` written, disabled | `Sources/PhotoModel/PhotoPlace+Kernel.swift`, `Tests/PhotoModelTests/PhotoPlaceTests.swift` | PL-a | ~140, 2 |
| PP-2 | – | RJ-P37's job folder with `waits_on: PP-6`, its fixtures | `Tests/RealJobs/photo/place-logo/` | PP-1 | ~80, 4 |
| PP-3 | – | Reachable: File > Place… ⇧⌘P (the panel limited to PNG and JPEG); `PhotoEditor`'s drop: on an open document a PNG or JPEG runs `place.image` at the drop point through `placeDropTarget`, anything else or no document opens as today | `Sources/PhotoApp/PhotoPlace.swift`, `Sources/PhotoApp/PhotoCommands+File.swift`, `Sources/PhotoApp/PhotoEditor.swift` | PP-1 | ~160, 3 |
| PP-4 | – | Snapshots, the render budget test, the journey written and skipped (`XCTSkip("waits on PP-7")`) | `Tests/AppSnapshotTests/PhotoPlaceSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoPlaceTests.swift`, `UITests/PhotoJourneyTests+Place.swift` | PP-3 | ~200, 3 |
| PP-5 | – | Conformance bodies; `insertPixelLayer` lifted out of `paste`, which now calls it; turns on `PhotoPlaceTests` | `Sources/PhotoModel/PhotoPlace+Kernel.swift`, `Sources/PhotoModel/PhotoClipboard.swift`, `Tests/PhotoModelTests/PhotoPlaceTests.swift`, `Tests/mutations/PhotoModel.PhotoPlace+Kernel.json` | PP-1, PL-7 | ~260, 4 |
| PP-6 | – | The five specs in the catalog and the id list; turns on RJ-P37 | `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/RealJobs/photo/place-logo/` | PP-2, PP-5, gradient-fill:PG-m | ~40, 3 |
| PP-7 | – | Live: the journey turned on, on live services | `UITests/PhotoJourneyTests+Place.swift` | PP-4, PP-6 | ~40, 1 |
| PP-8 | – | photo.md lists Place; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/place-image.wave.json` | PP-7, gradient-fill:PG-z | ~30, 2 |

PP-6 is under 50 lines; the lead folds it into PP-5's slice PR (rule 22). It
stays its own row because it waits on gradient-fill's PG-m and PP-5 doesn't.

## Build waves

- Wave 1: PP-1. Independent in this wave: PP-1 alone.
- Wave 2: PP-2, PP-3, PP-5. Independent in this wave: all three.
- Wave 3: PP-4, PP-6. Independent in this wave: both.
- Wave 4: PP-7. Independent in this wave: PP-7 alone.
- Wave 5: PP-8 (shared prose, `feature-done`, final). Independent in this wave: PP-8 alone.

Longest chain: PP-1 → PP-3 → PP-4 → PP-7 → PP-8 (5). Chain of 5: the menu
needs the conformance, the journey drives the menu, PP-7 turns it on live,
PP-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PP-1 | the suite compiles, disabled; every existing Photo test passes | the conformance breaks the build | – (stub) |
| PP-2 | the job is listed and skipped by `waits_on` | – | – |
| PP-3 | `PhotoPlaceSnapshots.logo` (PP-4's, first in the slice PR) | the menu item or drop is missing | – (UI) |
| PP-4 | `PhotoPlaceSnapshots`; `RenderBudgetPhotoPlaceTests.placeLargeInThreeBodies` | budget over | – (UI) |
| PP-5 | `PhotoPlaceTests`: a 200 × 100 PNG on 800 × 600 adds a layer `logo` at (300, 250), above the selected layer, selected; a 4000 × 3000 JPEG lands at 800 × 600 with "Placed at 20%."; a place at a drop point near the edge stays inside; SVG and text refused with their reasons and nothing added; one undo removes the layer; Paste still places at 100% centred (its own rule) | a box, layer order, name or step count is wrong, or Paste changes | `PhotoModel.PhotoPlace+Kernel`: origin dropped → `.centredOnCanvas`; resample skipped (layer larger than canvas) → `.largeFitsCanvas`; inserted below the selection → `.aboveSelection` |
| PP-6 | `CommandPathTests` and the id ledger list the five ids; RJ-P37 passes on Linux | an id is missing, or the job fails | – (registration; the behaviour's mutations are PP-5's) |
| PP-7 | `PhotoPlaceJourneyTests.testPlaceLogo` steps 1 to 5 | a step fails | – |
| PP-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: placing a 4000 × 3000 JPEG on a live canvas | ≤ 3 window bodies; decode and resample off the main actor | `RenderBudgetPhotoPlaceTests.placeLargeInThreeBodies` |
| One gesture, one step | a place is one undo step | `PhotoPlaceTests.oneUndoStep` |
| No dead controls | Place… in `photo.controls`, disabled with its reason when no image is open | `testPlaceLogo` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PP-m merged-done with RJ-P37 green in the
Linux job; PP-u's feel gate and `Mac-Finish:`; PP-z's journey on live. Then
`Belt-Contact-Sheet:` with `photo-place-*`.

## Not in this packet

Placing as a smart object that keeps its source and rescales without loss
(needs a non-destructive layer kind), SVG strokes, gradients and text in Photo
(fills place today), Free Transform right after a place (S7's
transform pack), HEIC and TIFF (see the shared packet).
