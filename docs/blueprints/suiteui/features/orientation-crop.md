# Feature packet: orientation-crop

**Feature:** stand a photo up and crop it the way the post needs. Library gets
Rotate Left and Right, Flip Horizontal and Vertical, in the grid and the loupe,
stored with the develop settings and applied in render, thumbnails and
export; its crop aspect gains an orientation swap, so 4:5 on a landscape photo
gives a tall 4:5 instead of 5:4 (`CropAspect.ratio(for:)` follows the photo's
shape today), and a custom ratio. Photo gets Image > Flip Canvas Horizontal
and Vertical back: its blueprint's v2 line had it IN and `photo/transform`
moved it OUT without a decision (this PR restores it, pointing that packet's
"Not in this packet" line here). Both apps' crop draft geometry moves into one
kernel `Crop` module, which is #3117's follow-up to Library's reviewed
`Allow-Dup: Crop` exception.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps on the kernel track) · **Lead branch:** `lead/orientation-crop`
**Beta:** captain, 2026-10-21 (beta gaps C9). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C9, evidence in `2026-10-21-gaps-library.md` rows 1 and 2 and finding 3, and
`2026-10-21-gaps-photo.md` row 7 and finding 7; #3117 (closes when OC-z
merges); feature map row `suiteui/orientation-crop` (new); real jobs RJ-L70
and RJ-P70 (new).

**Depends on:** editor-kernel, command-catalog, adopt-command-catalog (built).
**Waits:** suite-imaging IM-z (it is the last edit of Library's
`DevelopValues.swift` before this one); clipboard-interop CB-z for the
baseline chain. No creative-core issue: core's quarter turns and `flipped` are
at the pin.

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **OC-library-m, OC-library-u:** `LibraryCommandCatalog.swift` and the id
  list chain through library/file-flow LF-m; `CropInspector.swift` and
  `LibraryWindow+Crop.swift` are library/crop's (built). Library's
  `c4-planned.json` has `every_source_file_owned`, so OC-z updates its crop
  component's paths in the same PR that deletes `LibraryCrop.swift`.
- **OC-photo-m, OC-photo-u:** `PhotoImageOps.swift` and `PhotoMask.swift`
  (its `flippedCanvas` case) follow photo/transform PT-m; the Photo catalog
  tail is photo/file-flow PF-m; `CropOptions.swift` is photo/photo-crop's
  (built).

**Rule 20.** Crop is a kernel concept with no kernel module today (#3117).
Library's `LibraryCrop.swift` (the draft: aspect, handle drags clamped to the
straightened bounds) and Photo's `PhotoCropSize.swift` (drag, typed fields,
aspect lock, Swap) are two copies of one draft; both move onto
`SuiteKernel/Crop` through `LibraryCrop+Kernel.swift` and
`PhotoCrop+Kernel.swift`, and `CropAspect` leaves `DevelopValues.swift` as a
typealias of the kernel's with the catalog's keys unchanged. Orientation
(quarter turns and flips as one value) lives beside it, so the two apps share
one meaning of "Rotate Right then Flip".

**Deleted app-local files:** `Sources/LibraryModel/LibraryCrop.swift` and
`Sources/PhotoModel/PhotoCropSize.swift`, in OC-z with
`scripts/check-dup-logic --update-baseline`: `Tests/canonical-baseline.txt`
shrinks by 2 lines.

**AI-accessible first.** `image.rotate-cw`, `image.rotate-ccw`,
`image.rotate-180` (Photo's ids, now kernel specs), `image.flip {direction}`,
`crop.set-aspect {ratio | free | original, orientation}`, `crop.swap`,
`crop.set-frame`, `crop.apply`, `crop.reset`. Each has a menu item and, in the
crop tool, a control (the orientation toggle, X).

**C4:** OC-1 adds `docs/c4/parts/creative-apps/suite-kernel/kernel-crop.json`
(`Sources/SuiteKernel/Crop/`, crop and orientation).

Blueprint sections: suite.md 2 (the kernel tier); library.md (Develop, Crop);
photo.md (Image menu, crop).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| OC-a | The kernel declares Orientation, CropFrame, CropAspect with an orientation, the crop rules and the image and crop command specs as stubs, with their tests written and disabled. | OC-1, OC-2 | MJ-OC | editor-kernel, command-catalog (built, `depends`) |
| OC-m | Four right turns are no turn, a turn then a flip equals the matching flip then turn, a 4:5 portrait crop fits a landscape photo at its largest size, and a handle drag keeps the aspect inside the bounds. | OC-3, OC-4 | MJ-OC | OC-a |
| OC-u | SuiteUI has one crop aspect picker with an orientation toggle and a custom ratio, reachable from the gallery on the fakes. | OC-5, OC-6 | SJ-OC | OC-a; shared files, after document-setup:DS-u (OC-5) |
| OC-library-m | Library stores a photo's orientation with its develop settings and applies it before the crop in the loupe, thumbnails and export, its crop draft runs on the kernel, and every old catalog opens unchanged. | OC-7, OC-8 | MJ-OC-library | OC-a (OC-7); OC-m and suite-imaging:IM-z (OC-8, `DevelopValues.swift`); library/file-flow LF-m (cross-line); shared files, after clipboard-interop:CB-library (OC-8) |
| OC-library-u | Library's Photo menu, grid and loupe have Rotate Left and Right and Flip, and its crop inspector uses the shared aspect picker with the orientation toggle and a custom ratio. | OC-9, OC-10 | LJ-OC | OC-u, OC-library-m |
| OC-photo-m | Photo flips the whole canvas horizontally or vertically as one undo step with every layer keeping its place, its quarter turns run through the kernel's Orientation, and its crop sizing runs on the kernel's rules. | OC-11, OC-12 | MJ-OC-photo | OC-a (OC-11); OC-m (OC-12); photo/transform PT-m and photo/file-flow PF-m (cross-line); shared files, after document-setup:DS-photo (OC-12) |
| OC-photo-u | Photo's Image menu has Flip Canvas Horizontal and Vertical, and its crop options use the shared aspect picker. | OC-13, OC-14 | PJ-OC | OC-u, OC-photo-m; shared files, after area-selection:AR-photo-u (OC-13) |
| OC-z | Library's and Photo's crop draft copies are deleted with the baseline shrunk by two lines, #3117 closes, RJ-L70 and RJ-P70 pass, and the feature is built. | OC-15, OC-16 | MJ-OC, LJ-OC, PJ-OC | OC-library-u, OC-photo-u; clipboard-interop:CB-z (OC-15, `canonical-baseline.txt`) |

**Slice size.** Each slice is one PR of 150 to 400 lines with its test commit first (lead.md rule 22). OC-z is smaller than that; the lead folds it into whichever adopt slice merges last, as rule 22 says for a same-feature change under 50 lines.

## Journey steps

- `MJ-OC`: `OrientationTests` and `CropRulesTests` on Linux.
- `SJ-OC` (`SuiteCropJourneyTests.testAspectSwapInGallery`, OC-6): pick 4:5, press X; the frame turns portrait; type Custom 7:3.
- `MJ-OC-library`: `LibraryOrientationTests` on Linux.
- `LJ-OC` (`LibraryJourneyTests.testRotateFlipAndPortraitCrop`, OC-10): select the sideways scan, Photo > Rotate Right; the thumbnail stands up; open the loupe's crop, pick 4:5 portrait on a landscape photo; the frame is tall.
- `MJ-OC-photo`: `PhotoOrientationTests` on Linux.
- `PJ-OC` (`PhotoCropJourneyTests.testFlipCanvasAndPortraitCrop`, OC-14): open the two-layer fixture, Image > Flip Canvas Horizontal; both layers mirror; Edit > Undo once restores both; crop at 4:5 portrait.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L70 | adds, closes with `suiteui/orientation-crop` | C | `Tests/RealJobs/library/stand-up-and-crop/stand-up-and-crop.jobs.json`: import `sideways.jpg` (4000×3000, no orientation tag), `image.rotate-cw`, `crop.set-aspect {ratio: "4:5", orientation: portrait}`, export JPEG | `input/sideways.jpg` |
| RJ-P70 | adds, closes with `suiteui/orientation-crop` | C | `Tests/RealJobs/photo/flip-canvas/flip-canvas.jobs.json`: open `two-layers.ora`, `image.flip {direction: horizontal}`, export PNG | `input/two-layers.ora` |

RJ-L70. Trap: 4:5 on the landscape original gives 5:4, or export ignores the
turn. Assertion: the JPEG is 3000×3750 (the largest portrait 4:5 of the
turned 3000×4000) and its top row matches the scan's left column within 2 levels.
Mutations: `SuiteKernel.Crop` `.orientationWins`, `LibraryModel.LibraryCrop+Kernel`
`.orientBeforeCrop`. Written by OC-7, disabled (`waits_on: OC-8`).

RJ-P70. Trap: only the selected layer flips, or the top layer keeps its old
offset so the composite shifts. Assertion: the PNG equals the original PNG
mirrored, pixel for pixel. Mutation: `PhotoModel.PhotoOrientation+Kernel`
`.offsetsMirror`. Written by OC-11, disabled (`waits_on: OC-12`).

## Screens and states

- `suite-gallery-crop-{light,dark}.png` (OC-5): 4:5 picked, portrait on.
- `library-loupe-crop-portrait-{light,dark}.png` (OC-9).
- `photo-image-menu-flip-canvas-{light,dark}.png` (OC-13).

## Contract slice

```swift
// Sources/SuiteKernel/Crop/Orientation.swift (OC-1 stubs, OC-3 bodies). Foundation and FlareCore only.
/// The eight ways an image can face, as EXIF numbers them: up (1) through the mirrored turns.
public enum Orientation: Int, Hashable, Sendable, Codable, CaseIterable {
    case up = 1, upMirrored, down, downMirrored, leftMirrored, right, rightMirrored, left
    public func rotated(clockwise: Bool) -> Orientation
    public func flipped(_ d: FlipDirection) -> Orientation       // the kernel's existing FlipDirection
    public func then(_ next: Orientation) -> Orientation
    public func size(_ w: Int, _ h: Int) -> (width: Int, height: Int)
    public var matrix: Matrix { get }                             // for a unit square, for previews
}
public protocol OrientationTarget: AnyObject { var orientation: Orientation { get }; func setOrientation(_ o: Orientation) throws }
// Sources/SuiteKernel/Crop/Crop.swift (OC-1 stubs, OC-4 bodies).
public enum CropOrientation: String, Hashable, Sendable, Codable { case landscape, portrait }
public enum CropAspect: Hashable, Sendable, Codable {
    case free, original, ratio(width: Int, height: Int)      // 4:5 is ratio(4, 5); raw values "Free", "Original", "4:5" for Library's keys
    public func ratio(for size: (width: Double, height: Double), orientation: CropOrientation?) -> Double?   // nil orientation: follow the photo
}
public struct CropFrame: Hashable, Sendable, Codable { public var rect: Rect; public var angle: Double }   // rect in 0...1 of the oriented image
public enum CropRules {
    public static func largest(_ aspect: CropAspect, orientation: CropOrientation?, in bounds: Rect) -> Rect
    public static func drag(_ frame: Rect, handle: EditorHandle, to p: Point, aspect: Double?, bounds: Rect) -> Rect
    public static func swapped(_ frame: Rect, in bounds: Rect) -> Rect
    public static func nudged(_ frame: Rect, _ d: Direction, large: Bool, bounds: Rect) -> Rect
}
// Sources/SuiteKernel/Crop/CropCommands.swift (OC-1 stubs, OC-3 and OC-4 bodies).
public protocol CropTarget: AnyObject { var cropFrame: CropFrame? { get }; var cropBounds: Rect { get }; func setCropFrame(_ f: CropFrame?) throws; func applyCrop() throws }
public enum CropCommands { public static let specs: [CommandSpec] }   // image.rotate-cw, -ccw, -180, image.flip, crop.set-aspect, crop.swap, crop.set-frame, crop.apply, crop.reset
```

## Pseudocode

- **Orientation group:** represent each value as (turns 0...3, mirrored);
  `rotated` adds a turn (a mirrored value turns the other way); `flipped(.horizontal)`
  toggles mirror; `.vertical` is horizontal then two turns. `then` composes by
  the same two rules, so every sequence of menu commands is one value and one
  resample at render time (Library) or one exact pixel op (Photo).
- **Aspect with orientation:** `ratio(width:height:)` is landscape when
  width ≥ height; a chosen orientation flips it to match; nil orientation
  keeps Library's old rule (follow the photo), which is what old catalogs
  decode to, so their crops don't move.
- **Library order:** decode → orient → straighten → crop → develop, in render,
  thumbnails and export; the crop rect is stored in the oriented image's
  space, so turning a cropped photo turns the crop with it.
- **Photo flip:** every layer's pixels `flipped`, its offset mirrored about
  the canvas centre, masks and the selection flipped (`PhotoMask`'s
  `flippedCanvas`); one undo step that keeps the stack.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| OC-1 | – | **Contract as stubs.** `Orientation` (the eight values, rotate, flip, compose, the oriented size), `CropFrame`, `CropAspect` (free, original, ratio, orientation), `CropRules`, `OrientationTarget`, `CropTarget` and their specs; the C4 part | `Sources/SuiteKernel/Crop/Orientation.swift`, `Sources/SuiteKernel/Crop/Crop.swift`, `Sources/SuiteKernel/Crop/CropCommands.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-crop.json` | – | ~240, 4 |
| OC-2 | – | `OrientationTests` and `CropRulesTests` written, disabled (`waits on OC-3`, `waits on OC-4`) | `Tests/SuiteKernelTests/OrientationTests.swift`, `Tests/SuiteKernelTests/CropRulesTests.swift` | OC-1 | ~160, 2 |
| OC-3 | – | `Orientation` bodies and the image commands' run; turns on `OrientationTests` | `Sources/SuiteKernel/Crop/Orientation.swift`, `Tests/SuiteKernelTests/OrientationTests.swift`, `Tests/mutations/SuiteKernel.Orientation.json` | OC-1, OC-2 | ~170, 3 |
| OC-4 | – | `Crop` and `CropCommands` bodies, lifted from Library's draft and Photo's sizing: the aspect's ratio for a size and orientation, the largest frame of an aspect in bounds, a handle drag clamped with the aspect kept, swap, nudge; turns on `CropRulesTests` | `Sources/SuiteKernel/Crop/Crop.swift`, `Sources/SuiteKernel/Crop/CropCommands.swift`, `Tests/SuiteKernelTests/CropRulesTests.swift`, `Tests/mutations/SuiteKernel.Crop.json` | OC-1, OC-2 | ~230, 4 |
| OC-5 | – | **Reachable first:** the gallery's Crop page on the fakes; `CropAspectPicker` (`ChoiceChips` Free, Original, 1:1, 4:5, 3:2, 16:9, Custom with W and H fields, and a landscape/portrait toggle bound to X), each control naming its `crop.*` command; `CropAspectPickerTests` first | `Sources/SuiteUI/CropAspectPicker.swift`, `Sources/SuiteUI/Gallery/GalleryCrop.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/CropAspectPickerTests.swift` | OC-1, OC-2 | ~240, 4 |
| OC-6 | – | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+Crop.swift`, `Tests/AppSnapshotTests/RenderBudgetCropPickerTests.swift` | OC-5 | ~110, 2 |
| OC-7 | – | **Library, test first.** `LibraryOrientationTests`, disabled: rotate and flip compose and survive a catalog round trip; an old catalog decodes with orientation up and re-encodes byte for byte; export of a turned photo is portrait; RJ-L70's job folder, disabled | `Tests/LibraryModelTests/LibraryOrientationTests.swift`, `Tests/RealJobs/library/stand-up-and-crop/stand-up-and-crop.jobs.json`, `Tests/RealJobs/library/stand-up-and-crop/input/sideways.jpg` | OC-1, OC-2 | ~150, 3 |
| OC-8 | – | `LibraryCrop+Kernel.swift` (the draft on `CropRules`); `DevelopValues`' `CropAspect` becomes the kernel's (same raw values) and the settings gain `orientation` (omitted when up); render, thumbnails and export orient before cropping; the image and crop specs in Library's catalog; turns on the tests | `Sources/LibraryModel/LibraryCrop+Kernel.swift`, `Sources/LibraryModel/Contracts/DevelopValues.swift`, `Sources/LibraryModel/Live/LiveCrop.swift`, `Tests/LibraryModelTests/LibraryOrientationTests.swift`, `Tests/mutations/LibraryModel.LibraryCrop+Kernel.json`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/AfterGlowCLITests/Golden/apps/library.list-commands.json` | OC-7, OC-3, OC-4 | ~250, 8 |
| OC-9 | – | Photo > Rotate Left (⌘[), Rotate Right (⌘]), Flip Horizontal, Flip Vertical in the menu and the grid's context menu; the loupe redraws turned; `CropInspector` uses `CropAspectPicker` | `Sources/LibraryApp/LibraryCommands.swift`, `Sources/LibraryApp/CropInspector.swift`, `Sources/LibraryApp/LibraryGrid.swift`, `Tests/command-path-baseline/library.txt` | OC-5, OC-6, OC-7, OC-8 | ~220, 4 |
| OC-10 | – | The journey and the render budget row | `UITests/LibraryJourneyTests+Crop.swift`, `Tests/AppSnapshotTests/RenderBudgetLibraryTests.swift` | OC-9 | ~120, 2 |
| OC-11 | – | **Photo, test first.** `PhotoOrientationTests`, disabled: Flip Canvas mirrors a two-layer image with offsets mirrored and masks flipped; turn then flip equals the kernel's product; crop Swap uses the kernel; RJ-P70's job folder, disabled | `Tests/PhotoModelTests/PhotoOrientationTests.swift`, `Tests/RealJobs/photo/flip-canvas/flip-canvas.jobs.json`, `Tests/RealJobs/photo/flip-canvas/input/two-layers.ora` | OC-1, OC-2 | ~150, 3 |
| OC-12 | – | `PhotoOrientation+Kernel.swift` (rotate and the new flip through `Orientation`, each layer's pixels by core's `flipped` and offsets mirrored); `PhotoCrop+Kernel.swift` (the drag, fields and Swap on `CropRules`); `image.flip` in the catalog; turns on the tests | `Sources/PhotoModel/PhotoOrientation+Kernel.swift`, `Sources/PhotoModel/PhotoCrop+Kernel.swift`, `Sources/PhotoModel/PhotoImageOps.swift`, `Tests/PhotoModelTests/PhotoOrientationTests.swift`, `Tests/mutations/PhotoModel.PhotoOrientation+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/AfterGlowCLITests/Golden/apps/photo.list-commands.json` | OC-11, OC-3, OC-4 | ~250, 8 |
| OC-13 | – | Image > Flip Canvas Horizontal and Vertical; `CropOptions` uses `CropAspectPicker` (4:5 joins the chips, which RJ-P01's trap names) | `Sources/PhotoApp/PhotoCommands.swift`, `Sources/PhotoApp/CropOptions.swift`, `Sources/PhotoApp/PhotoIntent.swift`, `Tests/command-path-baseline/photo.txt` | OC-5, OC-6, OC-11, OC-12 | ~180, 4 |
| OC-14 | – | The journey and the render budget row | `UITests/PhotoJourneyTests+Crop.swift`, `Tests/AppSnapshotTests/PhotoRenderBudgetTests.swift` | OC-13 | ~120, 2 |
| OC-15 | – | **Delete the drafts.** Removes `LibraryCrop.swift` and `PhotoCropSize.swift`; repoints plan `find`s; Library's `c4-planned.json` crop component names the adapter; `scripts/check-dup-logic --update-baseline` drops their 2 lines; `Fixes #3117` | `Sources/LibraryModel/LibraryCrop.swift`, `Sources/PhotoModel/PhotoCropSize.swift`, `docs/blueprints/library/c4-planned.json`, `Tests/canonical-baseline.txt` | OC-9, OC-10, OC-13, OC-14 | ~220, 4 |
| OC-16 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/orientation-crop.wave.json` | OC-15 | ~10, 1 |

## Build waves

- Wave 1: OC-1. Independent in this wave: OC-1 alone.
- Wave 2: OC-2. Independent in this wave: OC-2 alone.
- Wave 3: OC-3, OC-4, OC-5, OC-7, OC-11. Independent in this wave: all.
- Wave 4: OC-6, OC-8, OC-12. Independent in this wave: all.
- Wave 5: OC-9, OC-13. Independent in this wave: both.
- Wave 6: OC-10, OC-14. Independent in this wave: both.
- Wave 7: OC-15. Independent in this wave: OC-15 alone.
- Wave 8: OC-16. Independent in this wave: OC-16 alone.

Longest chain: OC-1 → OC-2 → OC-5 → OC-6 → OC-9 → OC-10 → OC-15 → OC-16 (8). Chain of 8: each link is a slice waiting on the slice whose types or files it needs (the stubs before the bodies, the bodies before an app's adapter, the adapter before its screen, the delete and the status last); only the named tasks wait, so the other slices run beside it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| OC-1 | the kernel builds; `CommandShapeTests` with the nine specs; `scripts/c4-assemble --check` | a spec has no schema | – (stubs) |
| OC-2 | compile, disabled | – | – (tests only) |
| OC-3 | `OrientationTests`: the eight values form a group (every product is one of them); cw×4 is up; cw then flip-h equals flip-v then cw; a 6000×4000 photo turned is 4000×6000; EXIF values 1 to 8 map both ways | two sequences that should match differ, or the size doesn't swap | `SuiteKernel.Orientation`: flip composed on the wrong side → `.flipThenTurn`; size not swapped for odd turns → `.sizeSwaps` |
| OC-4 | `CropRulesTests`: 4:5 portrait on 6000×4000 is 3200×4000 centred; swap gives 5:4 at 6000×4800 clamped to 5000×4000; a corner drag past the edge stops at it with the ratio within 1 px; custom 7:3 holds | the ratio follows the photo's shape instead of the chosen orientation, or a drag leaves the bounds | `SuiteKernel.Crop`: orientation ignored when the photo is landscape → `.orientationWins`; clamp with `<` for `<=` at the edge → `.clampToEdge` |
| OC-5 | `CropAspectPickerTests`: each chip sends its command; the toggle is disabled for Free and 1:1; the custom fields refuse 0 with a sentence | a chip is bare or the toggle shows for 1:1 | – (SuiteUI view) |
| OC-6 | `SuiteCropJourneyTests.testAspectSwapInGallery`; `RenderBudgetCropPickerTests.swapInOneBody` | – | – |
| OC-7 | compile, disabled; `scripts/jobs check` | – | – (tests only) |
| OC-8 | `LibraryOrientationTests`; `LibraryCropTests` unchanged | an old catalog changes, or export ignores the turn | `LibraryModel.LibraryCrop+Kernel`: crop applied before orientation → `.orientBeforeCrop`; `orientation` written when up → `.oldCatalogsUnchanged` |
| OC-9 | `CommandPathTests`; Library's Model tests unchanged | a new item is bare | – (app wiring) |
| OC-10 | `LibraryJourneyTests.testRotateFlipAndPortraitCrop`; `RenderBudgetLibraryTests.rotateInLoupe` | – | – |
| OC-11 | compile, disabled; `scripts/jobs check` | – | – (tests only) |
| OC-12 | `PhotoOrientationTests`; Photo's crop and rotate tests unchanged | a layer lands at its old offset after a flip, or undo takes two steps | `PhotoModel.PhotoOrientation+Kernel`: offset not mirrored → `.offsetsMirror`; the mask left unflipped → `.masksFlip` |
| OC-13 | `CommandPathTests` | a new item is bare | – (app wiring) |
| OC-14 | `PhotoCropJourneyTests.testFlipCanvasAndPortraitCrop`; `PhotoRenderBudgetTests.flipCanvasInOneBody` | – | – |
| OC-15 | both apps' Model tests; `scripts/check-dup-logic` (baseline shrank by 2); `scripts/waves check library` | a draft copy survives | – (deletion) |
| OC-16 | `scripts/waves check`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: aspect swap in the gallery | ≤ 1 window body per press | `RenderBudgetCropPickerTests.swapInOneBody` |
| render: Library rotate in the loupe (24 MP) | ≤ 2 window bodies; the turned preview from the resident texture, p95 ≤ 30 ms | `RenderBudgetLibraryTests.rotateInLoupe` |
| render: Photo Flip Canvas on an 8K two-layer image | ≤ 2 window bodies; the flip runs detached | `PhotoRenderBudgetTests.flipCanvasInOneBody` |
| one gesture, one step | a turn, a flip, a swap each one undo step | `OrientationTests.oneStep`, `PhotoOrientationTests.oneStep` |
| behaviour preserved | old catalogs and `.ora` files round-trip byte for byte | `LibraryOrientationTests`, `PhotoOrientationTests` |
| no dead controls; keyboard parity | every new item has a command; X toggles orientation in both crop tools | `CommandPathTests`; `SJ-OC` |

## Done check

Per slice (rules 6, 15, 17, 21): OC-a and OC-m green on Linux with clean
`Mutate:` scores; OC-u, OC-library-u and OC-photo-u through the feel gate
(`mouse`, `taste`, `job`: stand up a sideways scan and crop it for a portrait
post, mouse only) with their `Mac-Finish:` lines; OC-z with RJ-L70 and RJ-P70
green on Linux and #3117 closed. Then `Belt-Contact-Sheet:`.
