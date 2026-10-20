# Feature packet: placed-images

**Feature:** one way to bring a picture into any AfterGlow document. SuiteKernel
gets a `Place/` module: the placed asset (PNG, JPEG or SVG bytes, its natural
size, a content id), the placed-image value an app layer stores (the asset id,
its box and a focus point), the fit and crop rules, the SVG flattening every
vector draw uses, and the place commands every app registers. SuiteUI gets the
shared pieces around it: a `Place…` open panel, a drop target for the canvas,
the view that draws a placed asset in a box without ever stretching it, and the
inspector rows (file, natural size, Replace…, Reset Size). A picture is a
fill: an app lets the layers that already have a box (Design's rectangles and
frames, Halo's solids) carry a `PlacedImage`, so no app adds a layer kind or
touches every switch over its kinds. Place adds a new such layer at the
picture's size; Place with **Fill** puts the picture into the selected layer.
An app adds one `<X>Place+Kernel.swift` conformance; it never writes its own
picture model, fit maths or drop handling.
**Line:** `line:suiteui` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/placed-images`
**Beta:** captain, 2026-10-20 ("everyday tools, built once and shared"). Labels `beta` and `p0` when filed.

**Covers:** feature map S20 (placed images, image fills, crop in frame; the
shared half) and the shared half of E11's app adoption (SVG art into Design,
Halo and Flare); real job RJ-X36 (new). The adopts are packets on their own
lines: `design/placed-images`, `halo/placed-images`, `flare/svg-place`,
`photo/place-image`, each waiting on this packet's PL-a.

**Depends on:** gradient-fill (suiteui wave 4): PL-1 waits on its **GF-a**
(`Tests/canonical-concepts.txt`) and PL-2 too (`SuiteGallery.swift`); PL-9 on
its **GF-z** (`FakeCanvasDocument.swift`); the vector draw reuses its
`Fill.shading` (GF-3). command-catalog (#2996): PL-7 waits on **CC-run** (one
undo step per run, the drag-token fold). editor-kernel (built): `History`,
`CommandSpec`, `Rect`. suite-harness and editor-in-window (built) for the
gallery. creative-core: nothing new. `SVGImport.scene(from:name:)` (vector-import
#439), `Path.flattened(tolerance:)`, `RenderList` and CoreRaster's `PNG.info`,
`JPEG.info` (image-codecs #562) are all on the pinned core `0de5687d`.

**Beta gaps A (#3432, merged first).** Its packets share files with this one, so these slices also wait on theirs: PL-a on `autosave-history:AH-a`; PL-z on `autosave-history:AH-z`, `transform-tools:TT-z`, `eyedropper:EY-z`, `shape-tools:SH-z`, `stroke-style:SS-d`.

**Where the pieces live (rule 20).** SuiteKernel links FlareCore and nothing
else (`KernelShapeTests.importsOnlyFoundationAndFlareCore`), so:

- The kernel holds the value, the rules and the commands. A raster asset is
  bytes plus pixel size (the shape `SuiteClipItem.image` already uses); a
  vector asset is SVG bytes read through FlareCore's `SVGImport`, flattened
  once into `PlacedVector` (polygons with their paint), which every vector
  draw takes. The fit, the cover crop and the reset are one function each.
- Raster pixel size comes from the target (`rasterSize(_:format:)`): the apps
  that draw pixels link CoreRaster and call `PNG.info` / `JPEG.info`, a header
  read, no decode. Design's Model links CoreRaster for this in its adopt.
- SuiteModel's `SuiteClipItem` and `AssetEnvelope` stay the pasteboard and
  drag transport; the drop target turns them into `(name, data)` for the
  place command. The suite asset library (`SuiteAsset`, `AssetLinking`) is
  not this packet: a placed asset is embedded in its document.
- PL-1 adds `Placed image: PlacedImage|PlacedAsset|ImageLayer|PlaceImage` to
  `Tests/canonical-concepts.txt`, so `scripts/check-dup-logic` fails an app
  file named for one. Photo's `.dropDestination(for: URL.self)` in
  `PhotoEditor.swift` is the one app-local drop target today; its adopt
  swaps it for `placeDropTarget`.

**Render path.** No new route. SuiteUI's `PlacedImageView` draws a raster
asset through ImageIO into a `CGImage` (cached by asset id) and a vector asset
as SwiftUI paths from `PlacedVector` (even-odd fills, solid or through
gradient-fill's `Fill.shading`; strokes at their width). Halo and Photo draw
pixels on CoreRaster through their own frame path (their adopts). Every draw
takes its rectangle from `PlaceRules.drawnRect`, so the canvas, the export and
the render can't disagree about the crop.

**C4:** new component part `suite-kernel/kernel-place.json` (PL-1).
`PlaceDrop.swift`, `PlacePanel.swift`, `PlacedImageView.swift` and
`PlacedImageRows.swift` are new files in `Sources/SuiteUI/`, covered by
`suiteui-sources`.

**Clean-room.** The cover and contain rules from CSS `object-fit` and SVG's
`preserveAspectRatio`; the drop from the HIG's drag-and-drop page. No task
reads another product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets), 7.5 (feel);
suite.md 1.5 (commands), 5.2 (assets).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PL-a | The kernel's `Place/` module declares every type, rule and command spec as stubs, SuiteUI's panel, drop target, view and rows exist as placeholders on the gallery's `place-image` page, and the checks are written, disabled. | PL-1, PL-2 | SJ0 | gradient-fill:GF-a, editor-kernel, suite-harness, editor-in-window |
| PL-u | On the gallery page a dropped or chosen PNG, JPEG or SVG shows in its box at its own aspect, the drop highlights only for files it takes, and the rows show the file and size with Replace… and Reset Size, every control identified, within the render budget. | PL-3, PL-4 | PJ1 (`SuitePlaceJourneyTests.testPlaceImageOnGallery`) | PL-a |
| PL-m | The rules sniff the format, refuse what they can't take with a reason, fit a new image inside the canvas without upscaling, crop by cover around the focus so nothing stretches, flatten an SVG into paint, and every place command records exactly one undo step (a focus drag one). | PL-5, PL-6, PL-7 | KJ-place | PL-a; command-catalog:CC-run (PL-7) |
| PL-z | The gallery runs its intents through `PlaceCommands` on a live target, the fake app takes placed images so RJ-X36 runs on the CLI, and the feature is built. | PL-8, PL-9, PL-10 | PJ1, KJ-place | PL-u, PL-m; gradient-fill:GF-z (PL-9) |

PL-u waits only on PL-a (rule 18); PL-m never waits on PL-u. KJ-place is the
rules' and commands' Linux walk in `SuiteKernelTests`.

## Journey steps

1. Open the gallery index, click `place-image` (PL-2, SJ0): an empty 800 × 600
   canvas with "Drop an image here, or choose Place…", a `Place…` button and
   two sample buttons, `Wide PNG` and `Logo SVG` (the page makes their bytes
   in code, so the journey never drives a file panel or Finder).
2. Click `Wide PNG` (PL-3, `testPlaceImageOnGallery`), which runs the same
   `.place` intent a panel or a drop runs: a 1200 × 400 picture appears
   fitted, 800 × 267, centred; the rows read "wide.png · PNG · 1200 × 400 px".
3. Click `Logo SVG`: a second image at its natural 240 × 80, red and blue
   parts in their colours.
4. Drag the wide image's right edge in to make its box square: the picture
   stays 3:1 and is cropped by its box (cover), never squashed.
5. Drag inside the picture with ⌥ held (Move Inside): the crop pans; the log
   shows `place.focus` per sample under one drag token (one undo step on live,
   PL-8).
6. Click Reset Size: the box goes back to 3:1 at its width. Every control
   works by keyboard (Tab to Place…, the samples, Replace…, Reset Size;
   Return runs) and VoiceOver reads "Image, wide.png, 1200 by 400 pixels"
   (PL-4).

The panel and the drop are proven below the journey: `PlaceDropTests` feeds
the drop target's item loader file URLs and pasteboard data, and the Mac
finisher drags a file from Finder once per slice (rule 17).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X36 | adds, closes with S20 | C | `Tests/RealJobs/fake/place-image/place-image.jobs.json`: `rect.select` the square, `place.image` of `wide.png` (base64) with `fill: true`, `place.focus` 0.25, 0.5 under one drag token in 30 samples, `edit.undo` once; the saved rects | `input/one.fake` (an 800 × 600 canvas holding one 300 × 300 rect), `input/wide.png` (1200 × 400) |

Trap: the picture stretches to fill the square, or the 30 focus samples land as
30 undo steps. Assertion: the saved image's drawn rect (from `place.read`) is
900 × 300 inside the 300 × 300 box (3:1 kept), and after the one undo its focus
is back at 0.5, 0.5. Its mutations sit in `SuiteKernel.PlaceRules.json` (cover
computed with `min` for `max`, the stretch) and `SuiteKernel.PlaceCommands.json`
(the drag token not passed to the target).

## Screens and states

`suiteui-place-empty` (the drop prompt), `-wide` (the fitted PNG, rows shown),
`-cover` (the square box cropping the 3:1 picture), `-svg` (the flattened logo),
`-drop-target` (the highlight), `-refused` (the "Place takes PNG, JPEG or SVG
files." note), light and dark.

## Contract slice

```swift
// Sources/SuiteKernel/Place/Placed.swift (PL-1)
public enum PlacedFormat: String, Codable, CaseIterable, Sendable { case png, jpeg, svg }
/// The bytes one document embeds once, however many layers show them.
public struct PlacedAsset: Codable, Hashable, Sendable, Identifiable {
    public var id: String            // PlaceRules.assetID(of: data): same bytes, same id
    public var name: String          // the file name, "logo.svg"
    public var format: PlacedFormat
    public var natural: Size         // pixels for PNG and JPEG, user units for SVG
    public var data: Data
}
/// What an app's layer with a picture stores. `box` is in the app's space; `focus` (unit, 0.5 centre) is
/// the point of the asset the cover crop keeps in view.
public struct PlacedImage: Codable, Hashable, Sendable {
    public var assetID: String; public var box: Rect; public var focus: Point = Point(x: 0.5, y: 0.5)
}
/// A document's assets: `adding` keeps one copy per id; `pruned(keeping:)` drops what no layer shows (on save).
public struct PlacedAssets: Codable, Hashable, Sendable {
    public private(set) var byID: [String: PlacedAsset]
    public func adding(_ asset: PlacedAsset) -> PlacedAssets
    public func pruned(keeping ids: Set<String>) -> PlacedAssets
}
/// An SVG flattened for drawing: one item per painted shape, in paint order, in the asset's units.
public struct PlacedVector: Hashable, Sendable {
    public struct Item: Hashable, Sendable {
        public var contours: [[Point]]        // even-odd
        public var fill: Fill?                // gradient-fill's kernel Fill; nil: no fill
        public var strokeColor: FillColor?; public var strokeWidth: Double   // nil or 0: no stroke
        public var opacity: Double
    }
    public var size: Size; public var items: [Item]; public var skipped: [String]   // SVGImport's report
}
// Sources/SuiteKernel/Place/PlaceRules.swift (PL-1 stubs, PL-5 bodies)
public enum PlaceRules {
    public static let maxBytes = 32 << 20
    public static let formatHelp = "Place takes PNG, JPEG or SVG files."
    public static let sizeHelp = "Place takes files up to 32 MB."
    public static func format(of data: Data) -> PlacedFormat?
    public static func assetID(of data: Data) -> String                        // FNV-1a 64 hex + byte count
    public static func fitted(natural: Size, in canvas: Rect, at point: Point?) -> Rect  // contain, never upscale
    public static func drawnRect(_ image: PlacedImage, natural: Size) -> Rect  // cover around focus; may exceed box
    public static func resetBox(_ image: PlacedImage, natural: Size) -> Rect   // same width and centre, natural aspect
}
// Sources/SuiteKernel/Place/PlaceVector.swift (PL-1 stub returning an empty vector of size 0, PL-6 body)
extension PlaceRules { public static func vector(_ data: Data, name: String) throws -> PlacedVector }
// Sources/SuiteKernel/Place/PlaceCommands.swift (PL-1 specs with real ids, schemas and availability, runs
// throwing `PlaceRules.notBuilt`; PL-7 bodies)
public protocol PlacedImageTarget: Sendable {
    var placeHelp: String? { get }                 // why nothing can be placed now (no document, a locked parent)
    var placeCanvas: Rect { get }                  // what a new image fits inside (artboard, comp, image)
    var placeFillBox: Rect? { get }                // the selected layer `fill: true` fills (Design's frame or
                                                   // rectangle, Halo's solid); nil refuses it with "Select a frame to fill."
    var placeFormats: Set<PlacedFormat> { get }    // Flare: [.svg]; Photo: [.png, .jpeg]
    var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { get }
    func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size   // CoreRaster's info; Flare refuses
    /// Adds a layer that has a box (a rectangle, a solid) showing `asset` in `image.box`, selects it,
    /// one undo step named `name`; returns its id.
    mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String
    /// Sets the selected layer's picture (focus, box or asset; a fill puts one into a layer without one);
    /// steps under one `drag` token fold into one.
    mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws
}
public enum PlaceIntent: Hashable, Sendable {
    case place(name: String, data: Data, at: Point?), replace(name: String, data: Data)
    case resetSize, focus(Point, drag: String)
    public var command: (id: String, params: JSONValue) { get }
}
public enum PlaceCommands {
    public static func specs<T: PlacedImageTarget>(_ target: T.Type) -> [CommandSpec<T>]
}
// Sources/SuiteUI/PlacePanel.swift (PL-2 placeholder, PL-3 body)
public enum PlacePanel { @MainActor public static func choose(formats: Set<PlacedFormat>) async -> [(name: String, data: Data)] }
// Sources/SuiteUI/PlaceDrop.swift (PL-2 placeholder, PL-3 body)
extension View {
    /// Files and image or SVG data dropped from Finder or another app; `onPlace` gets each with the drop point.
    public func placeDropTarget(formats: Set<PlacedFormat>,
                                onPlace: @escaping @MainActor ([(name: String, data: Data)], CGPoint) -> Bool) -> some View
}
// Sources/SuiteUI/PlacedImageView.swift (PL-2 grey box with the name, PL-3 raster body, PL-8 vector body)
/// The one draw: a SwiftUI `Canvas` renderer (Design's artwork, the gallery) calls it directly;
/// `PlacedImageView` wraps it. Clips to `image.box` with `cornerRadius`, draws `drawnRect`.
extension GraphicsContext {
    /// `strokes: false` draws an SVG's fills only (Halo, whose CoreRaster render has no stroker yet).
    public func drawPlaced(_ asset: PlacedAsset, _ image: PlacedImage, cornerRadius: Double = 0, scale: Double = 1,
                           strokes: Bool = true)
}
public struct PlacedImageView: View { public init(asset: PlacedAsset, image: PlacedImage, cornerRadius: Double = 0) }
// Sources/SuiteUI/PlacedImageRows.swift (PL-2 placeholder, PL-3 view)
public struct PlacedImageRows: View {
    public init(asset: PlacedAsset, formats: Set<PlacedFormat>, onIntent: @escaping (PlaceIntent) -> Void)
}
```

Commands (all `edit` but `place.read`; ids go in each adopter's
`Tests/command-ids/<app>.txt`):

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `place.read` | – (query) | – → `{name, format, width, height, box, focus, drawn}` | no placed image selected |
| `place.image` | Place Image | `{name, base64, x?, y?, fill?}` → `{id}` | `placeHelp`; format not in `placeFormats` (`formatHelp`); over `maxBytes` (`sizeHelp`); `fill` with no `placeFillBox` |
| `place.replace` | Replace Image | `{name, base64}` | no placed image selected; the same format rules |
| `place.reset-size` | Reset Size | – | no placed image selected; already its natural aspect |
| `place.focus` | Move Inside | `{x, y, drag?}` (unit) | no placed image selected; the picture fits its box (nothing to move) |

An app adds the five with one line (`+ PlaceCommands.specs(<X>Workspace.self)`)
and its `<X>Place+Kernel.swift` conformance. Every adopter puts **File > Place…
⇧⌘P** on `place.image` (no app uses ⇧⌘P today) and the drop target on its
canvas, so the gesture is the same in every app.

## Pseudocode

- **format.** PNG: the 8-byte signature. JPEG: `FF D8 FF`. SVG: after an
  optional UTF-8 BOM and whitespace, `<?xml` or `<svg`, and `<svg` within the
  first 4 KB. Anything else nil. Size is checked before the sniff.
- **fitted.** `s = min(1, canvas.w / n.w, canvas.h / n.h)`; size `n × s`;
  centred on `point` (else the canvas centre), then moved by the least amount
  that keeps it inside the canvas.
- **drawnRect.** `s = max(box.w / n.w, box.h / n.h)`; size `n × s`; its origin
  puts the asset's `focus` point on the box's matching point, clamped so the
  drawn rect always covers the box. A box at the natural aspect gives the box.
- **resetBox.** Same centre and width, height `width × n.h / n.w`; focus back
  to the centre.
- **vector.** `SVGImport.scene` → `RenderList` of frame 0; each item's path
  `flattened(tolerance: 0.25)` in asset units; its fill and stroke mapped to
  the kernel's `Fill` (gradient-fill's typealias), the stroke kept as width and
  colour; `skipped` is the import report plus "stroke outline" nowhere (the
  draw strokes natively). Throws `ImportError` as its reason text.
- **place.image.** Decode base64; size and format checks; `natural` from
  `vector(...).size` for SVG, else `target.rasterSize`; with `fill`,
  `setPlaced` once on the selected layer with box `placeFillBox` (the cover
  crop does the rest) and returns its id; else `fitted` in `placeCanvas` at
  `(x, y)` and `insertPlaced` once. Either is one step titled Place Image.
- **place.focus.** Clamp to 0...1; `setPlaced` with the drag token so the
  target's `History` folds a drag into one step.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PL-1 | – | The kernel `Place/` module as stubs: values, `PlaceRules`, the target protocol, `PlaceIntent`, the five specs with ids, schemas and availability; the concept line; the C4 part; the three suites written, disabled by name | `Sources/SuiteKernel/Place/Placed.swift`, `Sources/SuiteKernel/Place/PlaceRules.swift`, `Sources/SuiteKernel/Place/PlaceVector.swift`, `Sources/SuiteKernel/Place/PlaceCommands.swift`, `Tests/SuiteKernelTests/PlaceRulesTests.swift`, `Tests/SuiteKernelTests/PlaceVectorTests.swift`, `Tests/SuiteKernelTests/PlaceCommandsTests.swift`, `Tests/canonical-concepts.txt`, `docs/c4/parts/creative-apps/suite-kernel/kernel-place.json` | gradient-fill:GF-a | ~380, 9 |
| PL-2 | – | SuiteUI placeholders (panel, drop target, view, rows), the gallery's `place-image` page on a local log, the two sample buttons (bytes made in code), the journey written and skipped (`XCTSkip("waits on PL-4")`) | `Sources/SuiteUI/PlacePanel.swift`, `Sources/SuiteUI/PlaceDrop.swift`, `Sources/SuiteUI/PlacedImageView.swift`, `Sources/SuiteUI/PlacedImageRows.swift`, `Sources/SuiteUI/Gallery/GalleryPlaceImage.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `UITests/SuiteJourneyTests+Place.swift` | PL-1, gradient-fill:GF-a | ~280, 7 |
| PL-3 | – | The views: panel (`NSOpenPanel` limited to `formats`), drop target (file URLs and pasteboard image or SVG data, highlight only for takeable items, reads off the main actor), the raster draw by `drawnRect` with the corner clip, the rows; identifiers `suite.place.*` | `Sources/SuiteUI/PlacePanel.swift`, `Sources/SuiteUI/PlaceDrop.swift`, `Sources/SuiteUI/PlacedImageView.swift`, `Sources/SuiteUI/PlacedImageRows.swift`, `Tests/SuiteUITests/PlaceDropTests.swift` | PL-2 | ~360, 5 |
| PL-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuitePlaceSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPlaceTests.swift`, `UITests/SuiteJourneyTests+Place.swift` | PL-3 | ~220, 3 |
| PL-5 | – | `PlaceRules` bodies but `vector`: format, id, fitted, drawnRect, resetBox; turns on `PlaceRulesTests` | `Sources/SuiteKernel/Place/PlaceRules.swift`, `Tests/SuiteKernelTests/PlaceRulesTests.swift`, `Tests/mutations/SuiteKernel.PlaceRules.json` | PL-1 | ~260, 3 |
| PL-6 | – | `PlaceRules.vector`'s body in `PlaceVector.swift` (SVGImport, RenderList, flatten, paint mapping); turns on `PlaceVectorTests` | `Sources/SuiteKernel/Place/PlaceVector.swift`, `Tests/SuiteKernelTests/PlaceVectorTests.swift`, `Tests/mutations/SuiteKernel.PlaceVector.json`, `Tests/SuiteKernelTests/Fixtures/place/` | PL-1 | ~240, 4 |
| PL-7 | – | `PlaceCommands` bodies and `PlaceIntent.command`; turns on `PlaceCommandsTests` on a test target (one step per run, a focus drag one step, every why-not) | `Sources/SuiteKernel/Place/PlaceCommands.swift`, `Tests/SuiteKernelTests/PlaceCommandsTests.swift`, `Tests/mutations/SuiteKernel.PlaceCommands.json` | PL-5, PL-6, command-catalog:CC-run | ~320, 3 |
| PL-8 | – | The gallery page runs each intent through `PlaceCommands` on a local target with a `History`; `PlacedImageView` draws vectors from `PlacedVector`; the live test | `Sources/SuiteUI/Gallery/GalleryPlaceImage.swift`, `Sources/SuiteUI/PlacedImageView.swift`, `Tests/SuiteUITests/PlaceLiveTests.swift` | PL-4, PL-7 | ~200, 3 |
| PL-9 | – | The fake app takes placed images: `FakeRect.placed` and `FakeCanvasDocument.assets` (omitted when empty, so old jobs' JSON is unchanged), the conformance and the specs; RJ-X36's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeCanvasPlaceTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/place-image/` | PL-7, gradient-fill:GF-z | ~220, 4 |
| PL-10 | – | The C4 part names the commands and the views; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-place.json`, `docs/blueprints/suiteui/features/placed-images.wave.json` | PL-8, PL-9 | ~20, 2 |

PL-1 declares every rule and spec, so PL-5, PL-6 and PL-7 each fill one file
(`vector` sits in its own `PlaceVector.swift`, so PL-5 and PL-6 never share a file). No
`suiteui.md` edit: the C4 part and the adopts' blueprint lines carry it.

## Build waves

- Wave 1: PL-1. Independent in this wave: PL-1 alone.
- Wave 2: PL-2, PL-5, PL-6. Independent in this wave: all three.
- Wave 3: PL-3, PL-7. Independent in this wave: both.
- Wave 4: PL-4, PL-9. Independent in this wave: both.
- Wave 5: PL-8. Independent in this wave: PL-8 alone.
- Wave 6: PL-10 (`feature-done`, final). Independent in this wave: PL-10 alone.

Longest chain: PL-1 → PL-2 → PL-3 → PL-4 → PL-8 → PL-10 (6). Chain of 6: the
page needs the module's types, the views fill the placeholders, the budget and
journey time the views, the live page swaps the log under the journey, and
PL-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PL-1 | the three suites compile, disabled by name; `KernelShapeTests.importsOnlyFoundationAndFlareCore` passes over `Place/`; `check-dup-logic` passes with the new concept line | the module imports past FlareCore, or an app file is already named for the concept | – (stubs) |
| PL-2 | SJ0: the index lists `place-image`; the page opens | the page is missing | – (UI) |
| PL-3 | `PlaceDropTests`: a `.png` URL and SVG data are taken, a `.txt` URL is refused without a highlight, a 40 MB file is refused with `sizeHelp`, the drop point is passed through | a file it can't take highlights, or one it can is dropped | – (UI) |
| PL-4 | `SuitePlaceSnapshots`; `RenderBudgetPlaceTests.focusDragInThreeBodies`; `testPlaceImageOnGallery` steps 1 to 6 | budget over, or a step fails | – (UI) |
| PL-5 | `PlaceRulesTests`: PNG, JPEG, SVG with BOM and `<?xml` sniffed, text nil; equal bytes give equal ids, one changed byte a new id; 1200 × 400 fits 800 × 600 as 800 × 267 centred and 240 × 80 stays 240 × 80 (no upscale); a fit at a point near the edge stays inside; a 300 × 300 box over 1200 × 400 draws 900 × 300 with focus 0.5 centred and focus 0 left-aligned; `resetBox` keeps width and centre | a sniff, fit, crop or reset is wrong | `SuiteKernel.PlaceRules`: `max` for `min` in fitted's scale cap (upscales) → `.neverUpscales`; `min` for `max` in cover (stretch shows gaps) → `.coverKeepsAspect`; clamp dropped in drawnRect → `.focusEdgeCovers`; BOM not skipped → `.svgWithBOM` |
| PL-6 | `PlaceVectorTests` on fixtures `two-groups.svg` (a red and a blue group), `ring.svg` (a hole), `gradient.svg`: two items with their colours in paint order; the ring's two contours (even-odd leaves the hole); the gradient item's `Fill` is linear with the SVG's stops; `size` from the viewBox; a `filter` lands in `skipped`; a damaged file throws its reason | a colour is lost, a hole fills, or groups merge into one item | `SuiteKernel.PlaceVector`: fill mapped to black → `.keepsColours`; only the first contour kept → `.ringKeepsHole`; skipped report dropped → `.reportsSkipped` |
| PL-7 | `PlaceCommandsTests`: `place.image` records one step named "Place Image" and returns the id; 30 `place.focus` under one drag token undo in one; `fill: true` puts the picture into the selected layer at `placeFillBox` (no new layer) and with none is unavailable with its reason; `place.image` with text bytes is unavailable with `formatHelp`, over 32 MB with `sizeHelp`, an SVG on a raster-only target with `formatHelp`; `place.focus` on a box at the natural aspect is unavailable; `PlaceIntent.command` round-trips each case | a run records zero or two steps, or a why-not is missing | `SuiteKernel.PlaceCommands`: drag not passed to `setPlaced` → `.focusDragIsOneStep`; `fill` adds a layer instead of filling the selected one → `.fillUsesTheSelectedLayer`; format set not checked → `.refusesUnlistedFormat`; size check after decode skipped → `.refusesOver32MB` |
| PL-8 | `PlaceLiveTests`: a focus drag on the page leaves one undo step; the SVG draws its two colours; `testPlaceImageOnGallery` on live | the page stays on the local log, or a vector draws grey | – (UI) |
| PL-9 | `FakeCanvasPlaceTests`: a placed image and its asset survive save and open; two rects showing one file store one asset; a locked rect refuses with its reason; the old `add-rect` job's JSON is unchanged; RJ-X36 passes on Linux | an asset is lost or doubled, a locked rect takes it, or old JSON changes | `SuiteKernel.FakeCanvasDocument`: assets encoded when empty → `.oldJSONUnchanged`; locked check skipped in `setPlaced` → `.lockedRefuses`; prune keeps orphans → `.saveDropsOrphanAssets` |
| PL-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample focus drag on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetPlaceTests.focusDragInThreeBodies` |
| render: 120-sample box resize of a 4000 × 3000 JPEG | ≤ 3 window bodies; p95 ≤ 8 ms (the `CGImage` decoded once, never per frame) | `RenderBudgetPlaceTests.resizeLargeInThreeBodies` |
| Large file | a 30 MB PNG places without blocking the main actor over 50 ms (read and decode off it) | `PlaceDropTests.largeFileOffMain` |
| One gesture, one step | a focus drag, a place, a replace each one undo step | `PlaceCommandsTests.focusDragIsOneStep`, `PlaceLiveTests` |
| No dead controls | every control registers in `suite.controls` | `testPlaceImageOnGallery` |
| Keyboard and VoiceOver parity | Place…, Replace… and Reset Size reachable by Tab; the image reads its name and size | `testPlaceImageOnGallery` step 6 |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PL-m merged-done on the Linux job with
`Mutate:` scores clean; PL-u's feel gate (`mouse`, `taste`, `job` lenses) and
its `Mac-Finish:` line; PL-z's journey on live and RJ-X36 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suiteui-place-*`.

## Adopted by

`design/placed-images` (pictures in rectangles and frames, by cover, RJ-D12),
`halo/placed-images` (a picture in a solid layer from PNG, JPEG or SVG, RJ-H02),
`flare/svg-place` (SVG art as editable layers, RJ-F06), `photo/place-image`
(File > Place… and canvas drop as a new layer, RJ-P37). Each waits on PL-a
and runs its UI on these stubs.

## Not in this packet

HEIC, TIFF, WebP, PDF and GIF sources (ImageIO decodes them, but CoreRaster's
header read and the Linux path don't; a follow-up adds them to `PlacedFormat`
behind the platform decoder), linked (not embedded) assets and relink, the suite
asset library, footage (S20's video half rides shell-media, E9), Flare raster
layers (FlareCore has no image shape: a creative-core issue), drawing SVG
strokes in CoreRaster (no public stroke outliner in FlareCore yet: Halo lists
them as skipped), and masks from images.
