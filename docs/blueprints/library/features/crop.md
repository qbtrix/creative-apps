# Feature packet: crop

**Feature:** crop and straighten the loupe photo: aspect presets and a free
crop, a typed or nudged straighten angle, Auto to level a horizon, Reset Crop.
The crop is an edit instruction in `DevelopSettings`, never pixels, and the
loupe, the grid thumbnails and export all apply it through `LiveDevelop`.
Applying a crop is one undo step; drags, aspect changes and Cancel record
nothing.
**Line:** `line:library` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/crop`

**Covers:** #425 (closes with CR-7). Its catalog half (the crop survives a
save and restore) landed with persist; CR-7's step 10 proves it on real files.

**Depends on:** the develop feature issue (`LiveDevelop.swift` passes to crop
once develop closes; crop adds the crop after tone). From wave 2 it builds on
loupe-viewport's `LibraryLoupeImage.swift` and `LibraryLoupe.swift`,
thumbnails' `invalidateThumbnail(_:)`, import's live importer (IM-6) for the
(L) steps, and persist for step 10. **Spine follow-up** (to file with
develop's, `line:library`, for the spine lead while #1044 is open):
`LibraryMenu.Photo` gains `var crop = Crop()`, the `+Crop` stub declares an
empty `extension LibraryMenu { struct Crop {} }`, and the window's menu
merge copies `photo.crop = crop.crop` (three lines in three spine files).
Crop can't make the window edit itself: `LibraryWindow.swift` is also
filters-collections' and metadata-more's (wave 5), with no dependency path
to crop. CR-5 waits on it; CR-6 also waits on develop's own follow-up that
hands `menu` to `DevelopInspector`. SuiteUI: S-L3 `CropHandles` (unfiled: the
lead files it at stage 1, labels `needs-ui`, `line:suiteui`; the overlay draws
plain SwiftUI handles with 28 pt hit targets until it lands, so nothing waits
on it); #782 (S-L8) for P5 only; #330 and #333 are closed. creative-core: one
new issue for Auto on real photos (below), which only CR-10 waits on.
Export's QB-V4 task (a cropped photo exports at the crop's size) waits on
`crop:CR-b`, the slice that builds the live pixels.

Blueprint sections: 2.2 (`library-crop`), 2.3 (`library-app-crop`), 4.2 J6,
4.3 P5, 5.1 (`CropGeometry`), 5.2 (`CropSettings`, `CropAspect`,
`CropHandle`), 5.6 (`cropDraft`), 5.7 (the J6 row), 6.1 (Crop mode), 6.2
(Photo menu, Crop mode), 6.3, 6.4 (S-L3), 7.1 (QB-L1), 7.4 (QB-LIB-V4).

**Complaints this fixes** (tier 1 row 8; behaviour described from public
how-to material, nothing copied):

- Straightening leaves blank corners: the frame always sits inside
  CoreRaster's `straightenCrop` rect, so no transparent pixel can reach the
  output (QB-LIB-V4).
- A crop can't be undone later: it is stored as an angle and a unit rect, so
  R reopens it on the whole photo, Reset Crop clears it, and the file is
  never touched.
- No idea what size the result will be: the frame reads its output size in
  pixels ("4000 × 4000 at 1000, 0") while you drag.
- Precise leveling by mouse is fiddly: Straighten takes a typed angle to 0.1°,
  arrows nudge the frame 1 px (Shift 10).
- Undo history fills with drag noise: one "Crop" step per apply.

**From the future:** Auto (level the horizon from the pixels; on fakes now,
on real photos once core ships the detector); the crop follows the photo
into thumbnails and export with no extra step. Later, not in this packet:
level by drawing a line along the horizon (two points to an angle, Model
only), and an aspect change that keeps the current framing instead of
re-centering.

**Reuse.** Photo's crop (photo-crop, closed) is a destructive pixel crop:
`PhotoModel.CropSizing` works in `PixelRect` with no angle, in another line's
target, so nothing can be imported or lifted. What is shared: the CoreRaster
calls (`rotated(degrees:filter:)`, `straightenCrop`, `cropped`) that Photo's
Straighten also uses, SuiteUI's `CropShade` and `SelectionOutline` that
Photo's `CropOverlay` draws, `ChoiceChips` for the aspects, and the
handle anatomy S-L3 will give both apps.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CR-a | On the fakes, R opens a crop draft on the loupe photo, chips, drags and a typed angle reshape it, Return stores it as one "Crop" step, and Cancel, drags and leaving the photo record nothing. | CR-1, CR-2 | MJ6 | develop (the feature) |
| CR-b | On real pixels the frame stays inside the straightened photo, and the loupe, thumbnails and export get the turned and cropped picture. | CR-3, CR-4 | MJ6L | CR-a |
| CR-c | In the loupe, Photo > Crop shows the frame with handles, the aspect chips, Straighten, Auto, Apply and Cancel, all reachable from the keyboard. | CR-5, CR-6 | J6 | CR-a; the spine follow-up (CR-5) and develop's inspector follow-up (CR-6) |
| CR-d | On real files the 1:1 frame straightened 5° is 3545 px and survives a relaunch, and a corner drag stays within its frame budget. | CR-7, CR-8 | J6, P5 | CR-b (CR-7), CR-c |
| CR-e | Auto levels a tilted horizon on a real photo. | CR-9, CR-10 | MJ6A | CR-a (CR-9), CR-b (CR-10); creative-core issue and its bump (CR-10) |

CR-a is the contract: the catalog methods every view calls and the Auto
slot (`CropLeveling`), all on the spine's `FakeCrop`. CR-b and CR-c build
side by side on it. CR-e can close with gaps if core's detector hasn't
shipped when the rest is done (Done check).

## Journey steps

Model walks (Linux, run among `LibraryModelTests`):

- **MJ6** · `LibraryCropTests.walkJ6OnFakes` (CR-1): J6 steps 1–5, 7 and 9
  against a catalog on `.fake()` with the `shoot` fixture.
- **MJ6L** · `LibraryCropRenderTests.walkJ6Live` (CR-3, enabled by CR-4):
  on `LiveCrop` and `LiveDevelop`, a 6000 × 4000 photo at 1:1 gives a
  4000 × 4000 frame, at 5° a 3545 × 3545 one; a 600 × 400 gradient rendered
  at 1:1 and 5° comes out square with alpha 1 in every pixel.
- **MJ6A** · `LibraryCropLevelTests.walkAutoStraighten` (CR-9, enabled by
  CR-10): a 1200 × 800 two-tone buffer whose horizon rises 3° to the right;
  `beginCrop`, `levelAngle` on it, `levelCrop(by:)`; Straighten reads 3.0
  (±0.3), the frame shrank, Apply records "Crop".

**J6 · `testCropAndStraighten`** (`UITests/LibraryJourneyTests+Crop.swift`,
`extension LibraryJourneyTests` as `+Import.swift` is). CR-5 writes steps
1–9 skipped (`XCTSkip("waits on CR-6")`), CR-6 enables the (F) run, CR-7 adds
the (L) run and step 10.

1. (F) Launch on `-LibraryFixture shoot`; (L) live on `writeShoot` with
   `-LibraryImportOnLaunch`. Both with `-LibraryTestValues`. Sort by Name;
   open `IMG_0001` (6000 × 4000); click the inspector's Develop tab; Photo >
   Crop (R). Shot `crop`. Expect `library.crop.frame` whose value starts
   "6000 × 4000", six chips `library.crop.aspect.<title>`, Straighten
   `library.crop.straighten` at 0, `library.crop.auto`, `library.crop.apply`,
   `library.crop.cancel`; the Photo menu item reads "Done Cropping".
2. (F, L) Click **1:1**. Expect the frame's value to start "4000 × 4000".
3. (F, L) Focus Straighten, type 5, Return. Shot `crop-straighten`. Expect
   the frame's width under 4000 and Straighten 5.0. (L) The width is 3545
   (±1).
4. (F, L) Click the photo, press Return. Shot `crop-applied`. Expect the
   loupe value's size square; Escape: `IMG_0001`'s cell value size is square
   (before S-L2: reopen it and read the loupe value); Undo reads "Undo
   Crop".
5. (F, L) Undo; R; drag the frame's top-left handle 200 pt in; Escape.
   Expect the loupe value's size back to 3:2 and Redo still reading "Redo
   Crop" (the draft and Cancel recorded nothing and cleared no redo).
6. (F) Layout: the six chips have equal widths within 0.5 pt.
7. (F) R; click 1:1; focus the frame; Right three times. Expect the value
   to end "at 1003, 0"; Shift-Right: "at 1013, 0". Escape.
8. (F) R; click **Auto**. Expect Straighten 2.5 (`FakeCrop`'s fixed tilt).
   Escape. On live before CR-10, Auto is disabled with help "Auto-straighten
   isn't connected yet (crop)."
9. (F, L) Crop `IMG_0002` to 1:1 and apply; Photo > Reset Crop. Expect its
   loupe value's size back to 3:2 and Undo "Undo Reset Crop"; on an
   uncropped photo Reset Crop is disabled with help "This photo isn't
   cropped."
10. (L, CR-7) Crop `IMG_0001` to 1:1, apply, wait for `library.catalog` =
   `saved`, relaunch on the same `-LibraryCatalogDir`: the cell is still
   square.

States: in the grid, Crop is disabled with help "Open a photo in the loupe
to crop it."; the live services before CR-4 disable it with `LiveCrop`'s
reason.

**P5 · `testCropDragLatency`** (`UITests/LibraryJourneyTests+PerfCrop.swift`,
CR-8): (F) `shoot` with `-LibraryPerfProbe`; open `IMG_0001`, R, 1:1; a
velocity drag of the top-left handle in and out, three times. Attaches
`perf-crop.json`; asserts only ≥ 60 samples (report-only, QB-L1).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Loupe, crop mode | – (Crop needs a loupe photo; in the grid it is disabled with its help) | a frame that can't be worked out (a 0 × 0 photo) never opens: `cropHelp` "This photo has no pixel size." | the loupe's own `preview` render while the straightened picture renders (loupe-viewport) |
| Develop tab, CROP section | shown only while cropping | Auto that finds no horizon leaves the angle as it was (open question 7) | – |

Snapshots (`Tests/AppSnapshotTests/LibraryCropSnapshots.swift`, Light and
Dark): `library-crop` (the loupe and the CROP section at 1:1),
`library-crop-straightened` (1:1 at 5°, the frame inside the turned photo).

## Contract slice

From the spine: `CropGeometry`, `CropSettings` (`angle`, `rect` in 0...1 of
the photo's `straightenCrop` rect, `aspect`), `CropAspect.ratio(for:)`,
`CropHandle`, `FakeCrop`, the `LiveCrop` stub, `cropDraft`,
`DevelopSettings.setting(crop:)`, `LibraryKey.crop` and `.confirm`, and
`LibraryMenu.Photo`'s `toggleCrop`, `cropTitle`, `applyCrop`, `resetCrop`.

CR-1 adds, in `LibraryCrop.swift`:

```swift
extension LibraryCatalog {
    /// Why Crop can't start: the services' "crop" reason, "Open a photo in the
    /// loupe to crop it.", "This photo has no pixel size."; nil when it can.
    public var cropHelp: String? { get }
    /// "Done Cropping" while a draft is open, else "Crop".
    public var cropTitle: String { get }
    /// A draft on the loupe photo: its stored crop, else Original at 0°. Records nothing.
    public mutating func beginCrop()
    /// R and Photo > Crop: begins, or applies while cropping.
    public mutating func toggleCrop()
    /// `services.crop.initial(aspect, draft angle)`: centered, as large as fits.
    public mutating func setCropAspect(_ aspect: CropAspect)
    /// Handle drags and arrow nudges, in photo pixels. Records nothing.
    public mutating func dragCrop(_ handle: CropHandle, dx: Double, dy: Double)
    /// Clamped to `CropSettings.angleRange`; NaN and infinity change nothing.
    public mutating func setCropAngle(_ degrees: Double)
    /// Adds a `levelAngle` result to the draft's angle; nil changes nothing.
    public mutating func levelCrop(by delta: Double?)
    /// Stores the draft on the loupe photo as one "Crop" step (angle 0 with
    /// the whole rect stores nil), closes it, and drops the photo's thumbnail.
    public mutating func applyCrop()
    /// Closes the draft. Records nothing.
    public mutating func cancelCrop()
    /// While cropping: the draft back to Original at 0°, no step. Otherwise
    /// the loupe photo's crop cleared as one "Reset Crop" step.
    public mutating func resetCrop()
    /// "This photo isn't cropped." with nothing to reset; nil when Reset Crop can act.
    public var resetCropHelp: String? { get }
    /// The draft's frame in the straightened photo's pixels, and that
    /// straightened photo's size (the frame of the whole rect); nil when not cropping.
    public var cropFrame: PixelRect? { get }
    public var cropCanvas: PixelSize? { get }
    /// `library.crop.frame`'s value: "4000 × 4000 at 1000, 0".
    public var cropFrameValue: String? { get }
    /// What the loupe renders while cropping: the photo's tone, the draft's
    /// angle, the whole straightened photo. Nil when not cropping.
    public var cropLoupeSettings: DevelopSettings? { get }
    /// `photo`'s size after its stored crop; its own size without one.
    public func croppedSize(_ photo: PhotoItem) -> PixelSize
}
```

CR-1 also edits two lines of loupe-viewport's `LibraryLoupeImage.swift`:
`loupeRequest` sends `cropLoupeSettings ?? photo.develop`, and
`loupeFocusChanged()` sets `cropDraft = nil`, so stepping to another photo
or back to the grid closes the draft instead of applying it to the wrong
photo.

CR-2 adds the Auto slot as its own protocol in a new file,
`Contracts/CropLeveling.swift`, rather than new requirements on
`CropGeometry`: `LibraryContracts.swift` is also raw's (wave 5), with no
dependency path to crop. A crop service that can level conforms to both:

```swift
public protocol CropLeveling: Sendable {
    /// The clockwise turn, in degrees, that levels the horizon in `image`;
    /// nil when it finds none.
    func levelAngle(_ image: PixelBuffer) throws -> Double?
}
extension LibraryCatalog {
    /// `services.crop` when it can level; nil until it does.
    public var leveler: (any CropLeveling)? { services.crop as? any CropLeveling }
    /// Why Auto can't run: nil when `leveler` is set, else
    /// "Auto-straighten isn't connected yet (crop)."
    public var levelHelp: String? { get }
}
```

`FakeCrop` conforms in `Fakes/FakeCropLeveling.swift`: 2.5 for any image that isn't one flat color,
nil for a flat one. CR-10 makes `LiveCrop` conform over core; until then the
live services' Auto is disabled with that help.

The views get their values and closures from `LibraryMenu.Crop`, which CR-5
fills in `LibraryWindow+Crop.swift` (the spine follow-up declares it empty
and merges it into `menu.photo.crop`), the way develop's `LibraryMenu.Develop`
works:

```swift
extension LibraryMenu {
    struct Crop {
        var draft: CropSettings?
        var frame: PixelRect?, canvas: PixelSize?, frameValue: String?
        var artboard: PixelSize?           // the loupe photo's croppedSize
        var resetHelp: String?, levelHelp: String?
        var setAspect: (@MainActor (CropAspect) -> Void)?
        var drag: (@MainActor (CropHandle, Double, Double) -> Void)?
        var setAngle: (@MainActor (Double) -> Void)?
        var level, apply, cancel, reset: Action?
    }
}
```

The spine embedded `LibraryCropOverlay(cropDraft:)` and
`CropInspector(cropDraft:)` with the draft only. CR-6 changes both inits to
`(crop: LibraryMenu.Crop)` and their two call sites: `LibraryLoupe.swift`
(which already takes `menu`) and `DevelopInspector.swift` (which takes
`menu` after develop's follow-up).

## Pseudocode

```
beginCrop():                                                      # CR-1
  guard cropHelp == nil, let photo = loupeItem else return
  cropDraft = photo.develop.crop ?? try? services.crop.initial(.original, 0, photo.pixelSize)
setCropAspect(a) / dragCrop(h, dx, dy) / setCropAngle(d):
  guard let draft = cropDraft, let size = loupeItem?.pixelSize else return
  cropDraft = (try? services.crop.initial(a, draft.angle, size)        # aspect
              ?? services.crop.dragged(draft, h, dx, dy, size)          # drag
              ?? services.crop.straightened(draft, clamp(d), size)) ?? draft   # angle; non-finite d: return
applyCrop():
  guard let draft = cropDraft, let id = loupeItem?.id else return
  stored = draft.angle == 0 && draft.rect == .full ? nil : draft
  recordEdit("Crop", ids: [id]) { $0.develop = $0.develop.setting(crop: stored) }   # equal: no step
  cropDraft = nil; invalidateThumbnail(id)
resetCrop():
  if cropDraft != nil: cropDraft = try? services.crop.initial(.original, 0, size); return
  guard let id = loupeItem?.id, resetCropHelp == nil else return
  recordEdit("Reset Crop", ids: [id]) { $0.develop = $0.develop.setting(crop: nil) }; invalidateThumbnail(id)
cropLoupeSettings: draft.map { photo.develop.setting(crop: CropSettings(angle: $0.angle, rect: .full, aspect: $0.aspect)) }
cropFrame: services.crop.frame(draft, photo.pixelSize)
cropCanvas: services.crop.frame(CropSettings(angle: draft.angle, rect: .full, aspect: .original), photo.pixelSize).size

LiveCrop (CR-4); sc = PixelBuffer.straightenCrop(width, height, degrees: angle):
  initial(aspect, angle, photo): r = aspect.ratio(for: photo) / (sc.width / sc.height)
    rect = r < 1 ? (x: (1 - r) / 2, y: 0, w: r, h: 1) : (x: 0, y: (1 - 1/r) / 2, w: 1, h: 1/r); Free/Original: .full
  dragged(crop, h, dx, dy): ux = dx / sc.width, uy = dy / sc.height; move the handle's edges;
    on a locked aspect a corner keeps the ratio from the opposite corner (the larger change wins),
    an edge resizes the other side about the center; .inside moves; then each side >= 16 px, inside 0...1
  straightened(crop, angle): angle clamped; rect kept (it is relative to the new sc, so it stays inside)
  frame(crop, photo): PixelRect(sc.x + rect.x * sc.width, sc.y + rect.y * sc.height,
                                max(rect.width * sc.width, 1), max(rect.height * sc.height, 1)), rounded inward

LiveDevelop.render(buffer, settings) (CR-4), after develop's tone:
  guard let crop = settings.crop else return toned
  turned = crop.angle == 0 ? toned : try toned.rotated(degrees: crop.angle, filter: .lanczos3)
  f = try LiveCrop().frame(crop, photo: PixelSize(width: buffer.width, height: buffer.height))   # the buffer's own size
  return try turned.cropped(x: f.x, y: f.y, width: f.width, height: f.height)

LibraryWindow+Crop (CR-5, macOS):
  cropMenu: toggleCrop = enabled(model.cropHelp == nil) { model.toggleCrop(); render() }
            cropTitle = model.cropTitle
            applyCrop = enabled(model.cropDraft != nil) { model.applyCrop(); render() }    # Return routes here
            resetCrop = enabled(model.resetCropHelp == nil) { model.resetCrop(); render() }
  cropMenu.crop (LibraryMenu.Crop): the values above; every closure nil without a draft;
            setAngle and reset call render(.preview) then render(.full)
  level: image = model.loupeRender?.image; Task { delta = try? await detached { try model.leveler?.levelAngle(PixelBuffer(image)) }
                                                model.levelCrop(by: delta); render() }
  render(): the loupe area's render(_:) through its RenderQueue (loupe-viewport LV-8; develop's DV-8 calls the same)
LibraryCropOverlay (CR-6): CropShade(rect: frame, documentSize: canvas, zoom: view width / canvas width),
  SelectionOutline on the frame, eight handles and an inside drag reporting (handle, dx / zoom, dy / zoom)
  until S-L3; focused while a draft is open: Escape cancels, arrows nudge .inside 1 px (Shift 10).
  Identifier library.crop.frame, value cropFrameValue, through .libraryControl.
CropInspector (CR-6): CROP section: ChoiceChips of CropAspect.allCases (3 columns, 2 rows),
  InspectorSliderRow Straighten (-45...45, decimals 1, unit °), Auto (InspectorAction, levelHelp),
  Apply (primary) and Cancel, Reset Crop (resetHelp).
LibraryLoupe (CR-6): LibraryCropOverlay(crop: menu.photo.crop); artboard = crop.canvas while cropping,
  else crop.artboard (the photo's croppedSize).
DevelopInspector (CR-6): CropInspector(crop: menu.photo.crop) while cropDraft is set (one line).
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: crop`, `Slice: <slice>`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. Model tasks
end the body with their `Mutate:` line. PRs say `Part of #425`; CR-7 says
`Closes #425`. The feature's last PR carries `feature-done` (CR-10 if core's
detector is on `dev` by then, otherwise the later of CR-7 and CR-8).

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CR-1 | #425 (part) | The catalog's crop: draft, aspect, drag, angle, apply, cancel, reset, help, frame value, loupe settings; the draft closes on a focus change; MJ6 | `Sources/LibraryModel/LibraryCrop.swift`, `Sources/LibraryModel/LibraryLoupeImage.swift`, `Tests/LibraryModelTests/LibraryCropTests.swift`, `Tests/mutations/LibraryModel.LibraryCrop.json`, `Tests/mutations/LibraryModel.LibraryLoupeImage.json` | – | ~380, 5 |
| CR-2 | – | The Auto slot: `CropLeveling`, `leveler`, `FakeCrop`'s conformance | `Sources/LibraryModel/Contracts/CropLeveling.swift`, `Sources/LibraryModel/Fakes/FakeCropLeveling.swift`, `Tests/LibraryModelTests/LibraryCropLevelingTests.swift`, `Tests/mutations/LibraryModel.FakeCropLeveling.json` | – | ~120, 4 |
| CR-3 | – | CR-b's checks, written first and disabled: live geometry, the render (QB-LIB-V4, MJ6L) and the budgets | `Tests/LibraryModelTests/LibraryLiveCropTests.swift`, `Tests/LibraryModelTests/LibraryCropRenderTests.swift`, `Tests/LibraryModelTests/LibraryCropBudgetTests.swift` | CR-1 | ~300, 3 |
| CR-4 | #425 (part) | `LiveCrop` over `straightenCrop` (`unavailable` nil); `LiveDevelop` turns and crops after tone; enables CR-3's tests | `Sources/LibraryModel/Live/LiveCrop.swift`, `Sources/LibraryModel/Live/LiveDevelop.swift`, `Tests/LibraryModelTests/LibraryLiveCropTests.swift`, `Tests/LibraryModelTests/LibraryCropRenderTests.swift`, `Tests/LibraryModelTests/LibraryCropBudgetTests.swift`, `Tests/mutations/LibraryModel.LiveCrop.json`, `Tests/mutations/LibraryModel.LiveDevelop.json` | CR-3 | ~300, 7 |
| CR-5 | #425 (part) | The crop area: Photo > Crop and Reset Crop, R and Return, renders after a change, `LibraryMenu.Crop` filled; J6 written and skipped | `Sources/LibraryApp/LibraryWindow+Crop.swift`, `UITests/LibraryJourneyTests+Crop.swift` | CR-1, CR-2; the spine follow-up | ~320, 2 |
| CR-6 | #425 (part) | The frame overlay, the CROP section, their two call sites, the loupe's artboard at the cropped size; snapshots; J6 (F) enabled | `Sources/LibraryApp/LibraryCropOverlay.swift`, `Sources/LibraryApp/CropInspector.swift`, `Sources/LibraryApp/LibraryLoupe.swift`, `Sources/LibraryApp/DevelopInspector.swift`, `Tests/AppSnapshotTests/LibraryCropSnapshots.swift`, `UITests/LibraryJourneyTests+Crop.swift` | CR-5; develop's inspector follow-up | ~370, 6 |
| CR-7 | #425 (closes) | J6 (L) run and step 10 | `UITests/LibraryJourneyTests+Crop.swift` | CR-4, CR-6 | ~120, 1 |
| CR-8 | – | P5 `testCropDragLatency` (perf, report-only) | `UITests/LibraryJourneyTests+PerfCrop.swift` | CR-6, #782 | ~120, 1 |
| CR-9 | – | CR-e's check, written first and disabled: MJ6A on a tilted two-tone buffer | `Tests/LibraryModelTests/LibraryCropLevelTests.swift` | CR-2 | ~120, 1 |
| CR-10 | – | `LiveCrop` conforms to `CropLeveling` over core's horizon detector, so Auto works live; enables MJ6A | `Sources/LibraryModel/Live/LiveCrop.swift`, `Tests/LibraryModelTests/LibraryCropLevelTests.swift`, `Tests/mutations/LibraryModel.LiveCrop.json` | CR-4, CR-9; creative-core issue and its bump | ~100, 3 |

Why each link: CR-3's budget test calls CR-1's `dragCrop`. CR-4 enables
CR-3's files. CR-5 calls CR-1's methods and CR-2's `leveler`. CR-6 reads
CR-5's `LibraryMenu.Crop` and edits its journey file. CR-7 edits that
file and needs CR-4's live pixels. CR-8 drags CR-6's handles. CR-9 calls
CR-2's `CropLeveling`. CR-10 edits CR-4's `LiveCrop.swift` and enables CR-9's
test. CR-2 needs nothing of CR-1.

No task edits `docs/c4/model.json`, `docs/design.md`, the blueprint or
`waves.md`, so there is no docs task. Every source file sits in a component
`c4-planned.json` already names (`library-crop`, `library-loupe`,
`library-develop`, `library-contracts`, `library-fakes`, `library-app-crop`,
`library-app-areas`, `library-app-browse`, `library-app-inspector`).
`LibraryLoupe.swift` and `LibraryLoupeImage.swift` (loupe-viewport), and
`DevelopInspector.swift` and `LiveDevelop.swift` (develop) come from earlier
waves; crop takes the lines it needs. It owns no file a wave-5 feature
owns, so later features never wait on it.

## Build waves

- Wave 1: CR-1, CR-2 (slice CR-a). Independent in this wave: both.
- Wave 2: CR-3, CR-5, CR-9. Independent in this wave: all three.
- Wave 3: CR-4, CR-6. Independent in this wave: both.
- Wave 4: CR-7, CR-8, CR-10 (CR-10 also waits on core's bump;
  `feature-done` on the last to merge). Independent in this wave: all three.

Longest chain: CR-1 → CR-5 → CR-6 → CR-7 (4), and CR-1 → CR-3 → CR-4 → CR-7 (4).
Chain of 4: CR-5 calls CR-1's catalog methods, CR-6 draws CR-5's `LibraryMenu.Crop`
and unskips its journey, and CR-7 extends that journey with live steps that
need CR-4's pixels; on the other path CR-3's budget calls CR-1's
`dragCrop` and CR-4 enables CR-3's tests.

## Acceptance test per task

Slice checks come first (rule 13): CR-1 carries MJ6; CR-3 carries CR-b's
tests disabled with `waits on CR-4`; CR-5 carries J6 with `XCTSkip("waits on
CR-6")`; CR-9 carries MJ6A disabled with `waits on CR-10`. Mutations go in
the plan named in the task's owned files (`scripts/mutate --plan
LibraryModel.<File>`).

| id | test | fails when | mutations |
|---|---|---|---|
| CR-1 | `LibraryCropTests` on `.fake()`, `shoot`: in the grid `cropHelp` is "Open a photo in the loupe to crop it." and `beginCrop` does nothing; in the loupe on `IMG_0001` the draft is `.full` at 0°, `cropFrameValue` "6000 × 4000 at 0, 0", `cropTitle` "Done Cropping"; 1:1 gives "4000 × 4000 at 1000, 0"; `dragCrop(.inside, 3, 0)` gives "at 1003, 0"; `setCropAngle(60)` gives 45 and `.nan` changes nothing; `applyCrop` is one step "Crop" and the photo's `develop.crop` equals the draft; applying an untouched draft records nothing and stores nil; `cancelCrop`, aspect, drag and angle leave `history` unchanged; `resetCrop` outside crop mode is one "Reset Crop" step, and `resetCropHelp` is "This photo isn't cropped." on an uncropped photo; `levelCrop(by: 2.5)` adds 2.5 and `nil` changes nothing; `cropLoupeSettings` has the draft's angle and `.full`; `loupeFocusChanged()` after `stepLoupe(by: 1)` leaves `cropDraft` nil and `IMG_0002` uncropped; `loupeRequest` while cropping carries `cropLoupeSettings`; `walkJ6OnFakes` (MJ6) | a gesture records a step or two, a draft leaks to another photo, a bad angle gets through, or the loupe renders the stored crop while cropping | `LibraryCrop`: apply never clears the draft (`cropDraft = nil` dropped); the untouched check stores the draft (`&&` → `\|\|`); the angle clamp dropped. `LibraryLoupeImage`: the request ignores `cropLoupeSettings`; `loupeFocusChanged` keeps the draft |
| CR-2 | `LibraryCropLevelingTests`: `FakeCrop().levelAngle` is 2.5 on a gradient and nil on a flat buffer; on `.fake()` `leveler` is set and `levelHelp` nil; with a test `CropGeometry` that doesn't level, `leveler` is nil and `levelHelp` is "Auto-straighten isn't connected yet (crop)." | the fake stops showing Auto's change, or the live stub claims to work | `FakeCropLeveling`: the flat check dropped (always 2.5); 2.5 → -2.5 |
| CR-3 | Disabled `waits on CR-4`. `LibraryLiveCropTests`: `initial(.square, 0, 6000 × 4000)` frames 4000 × 4000 at (1000, 0); at 5° the frame is 3545 (±1) square and lies inside `straightenCrop`; a 3:2 on 4000 × 6000 is portrait; a corner drag on 1:1 stays square; no drag makes a side under 16 px or leaves 0...1; `straightened` keeps the rect. `LibraryCropRenderTests` (QB-LIB-V4): a 600 × 400 gradient at rect width 0.5 renders 300 px wide; at 1:1 and 10° every pixel's alpha is 1; neutral settings with no crop return the buffer unchanged; `walkJ6Live` (MJ6L). `LibraryCropBudgetTests`: `dragCrop` on 6000 × 4000 on the live services ≤ 2 ms (debug gate, 0.2 ms release); `setCropAngle` ≤ 2 ms; a 2048 px render at 1:1 and 5° reported (report-only in debug, ≤ 120 ms release) | (once enabled) a frame leaves the straightened photo, the size is off, a corner shows transparent, or a drag is over budget | – (tests only) |
| CR-4 | CR-3's three files pass with their `disabled` removed; `LiveCrop.unavailable == nil` | the same | `LiveCrop`: `initial` compares the ratio the wrong way (`<` → `>`); the 16 px floor dropped; `frame` drops the `straightenCrop` offset. `LiveDevelop`: the turn skipped (`crop.angle == 0` → `true`); the frame taken from the buffer's sides swapped |
| CR-5 | J6 compiles and skips by name; `LibraryControls` lists `library.crop.*` on the macOS build; the Photo menu's Crop is disabled in the grid with its help (J10 still passes) | a key or menu item reaches nothing, or a disabled item has no reason | – (view code; J6 is its check) |
| CR-6 | `LibraryCropSnapshots`: `library-crop`, `library-crop-straightened`, Light and Dark; J6 steps 1–9 (F) pass on the macOS run | a chip, handle or row is missing, the frame isn't over the photo, or Escape and the arrows don't reach the overlay | – (view code; J6 is its check) |
| CR-7 | J6 (L) steps 1–5, 9 and 10 pass on the macOS run | the live frame isn't 3545 px, the cell isn't square, or the crop is lost on relaunch | – (journey) |
| CR-8 | P5 attaches ≥ 60 samples | fewer samples (invalid) | – (journey) |
| CR-9 | Disabled `waits on CR-10`. `LibraryCropLevelTests`: on `LiveCrop`, a 1200 × 800 two-tone buffer whose edge rises 3° to the right gives 3.0 (±0.3), falling 7° gives -7.0 (±0.3), a flat buffer gives nil; `walkAutoStraighten` (MJ6A) | (once enabled) Auto turns the wrong way or invents a horizon | – (tests only) |
| CR-10 | CR-9's file passes with `disabled` removed; on the live services `leveler` is set and `levelHelp` nil | the same | `LiveCrop`: the detector's sign flipped; a nil result turned into 0 |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-L1 model half | `dragCrop` on 6000 × 4000, live ≤ 2 ms (0.2 ms release); `setCropAngle` ≤ 2 ms | `LibraryCropBudgetTests.dragWithinBudget`, `.angleWithinBudget` (CR-3, CR-4) |
| QB-L1 probe | p95 ≤ 2 frames late on a corner drag; report-only | P5 (CR-8) |
| Cropped render | 2048 px at 1:1 and 5° ≤ 120 ms release (QB-LIB-6's full render); report-only in debug (pixel loop, decision D8), gated by `swift test -c release --filter Budget` recorded in CR-4's PR | `LibraryCropBudgetTests.croppedRenderReport` |
| QB-LIB-V4 | 300 px wide; 4000 × 4000; alpha 1 everywhere at 10° | `LibraryCropRenderTests` |
| QB-F1 | Crop, Reset Crop and Auto are enabled or say why | `LibraryCropTests`, J6 steps 8–9, J11 |
| QB-F3 | Apply is one "Crop" step, Reset Crop one "Reset Crop"; drags, chips, angle and Cancel none | `LibraryCropTests`, J6 steps 4, 5, 9 |
| QB-F4 | R, Return, Escape; arrows nudge 1 px, Shift 10 | J6 steps 1, 4, 5, 7 |
| QB-V5 | `library-crop`, `library-crop-straightened`, Light and Dark | `LibraryCropSnapshots` |

## Done check

Per slice (`lead.md` rule 6): its journeys green on a scoped run
(`ci.yml` with `app=library`) containing its last merged PR, every app
built, no open `finding` for the slice, and every mutation in its plans
caught. CR-a and CR-b are Linux-only: MJ6 and MJ6L run among
`LibraryModelTests` in that run. Then `Belt-Slice-Done: <slice> <run url>`
on the feature issue.

CR-e: if core's detector isn't on `dev` when CR-a to CR-d are done, the
lead relabels CR-10 a `gap` issue ("Library: Auto-straighten on real
photos", `Depends on:` the core issue), posts `Belt-Slice-Done: CR-e <run
url> gaps: #<n>`, and CR-7 or CR-8 carries `feature-done`. Auto stays
disabled with its reason on live until then.

Feature: no `library` count over `UITests/audit-baseline.json`; the crop
controls carry identifiers; `Belt-Contact-Sheet: <run url>` once every slice
has its line.

### creative-core issue to file (needs-core)

**CoreRaster: the tilt of a photo's horizon.** `PixelBuffer.horizonAngle(maxDegrees: Double = 45) throws -> Double?`:
the clockwise turn in degrees (the sense of `rotated(degrees:filter:)`) that
levels the strongest long near-horizontal edge, within ±`maxDegrees`; nil
when no edge is strong enough. Deterministic, Linux-safe, one pass over a
buffer the caller has already downsized (Library passes its ≤ 2048 px loupe
picture). Acceptance: a 1200 × 800 image, sky over ground, the boundary
rising 3° to the right gives 3.0 ± 0.1; falling 7° gives -7.0 ± 0.1; a flat
color or uniform noise gives nil; a vertical edge only gives nil. CR-10 waits
on it and on the `scripts/bump-core` PR that brings it to `dev`.

Conditional, only if the cropped-render row misses 120 ms in release:
"CoreRaster: `rotated(degrees:filter:)` splits its rows across tasks" (the
`ponytail:` note in `Rotate.swift` already names this upgrade), output
byte-equal to the one-thread result.

### Open questions

1. The loupe's re-render after a crop change goes through the loupe area's
   `render(_:)` and its `RenderQueue` (loupe-viewport LV-8), the same call
   develop's DV-8 makes. Crop adds no render path of its own.
2. Thumbnails hold an image until `invalidateThumbnail`; apply and reset
   call it, but undo and redo of "Crop" go through `CatalogHistory`, which
   doesn't. Develop's slider undo has the same gap. Once thumbnails lands,
   check that `ThumbnailToken.of` hashes `crop` and that the grid redraws
   after Undo Crop; if not, file a `finding` on thumbnails.
3. While cropping, Edit > Undo still undoes the last catalog step (a rating,
   say) under the open draft. Recommend: leave it (the draft is not history);
   revisit if a critic finds it confusing.
4. Pressing R opens the CROP section only on the Develop tab (the tab is the
   inspector's own state, spine's file). J6 clicks the tab first. Switching
   the tab on R is a one-line follow-up in `LibraryInspector.swift`.
5. The loupe renders the straightened photo again on each angle change
   (`.preview` while typing or scrubbing, then `.full`). If that is too slow
   with a large photo, the cheaper preview is to turn the shown picture with
   a rotation effect and render only on apply; it needs the frame mapped
   through the turned bounds, and `FakeCrop.frame` ignores the angle, so the
   fakes would draw it slightly off.
6. packets.md asks for one `XCTestCase` per `+Area` file; every Library
   journey on `dev` (`+Import.swift`) and every sibling `.wave.json` uses
   `extension LibraryJourneyTests`. This packet follows the Library code.
7. Auto that finds no horizon changes nothing and says nothing: the catalog
   can't add a stored message (the spine declares every stored property).
   Recommend: the crop area keeps a "No horizon found." line in
   `CropAreaState` for the CROP section, macOS-only and proved by a
   snapshot; or accept the silent no-op for v1.
