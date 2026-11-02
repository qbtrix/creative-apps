# Feature packet: adjust-everywhere

**Feature:** the everyday adjustments every image app reaches for, built once.
SuiteImaging gets two adjustment kinds, **Black & White** (with red, yellow,
green, cyan, blue and magenta weights) and **Invert**, as steps of the one
live program, and five **filters** that read neighbours and so run once over
a layer's pixels: Gaussian Blur, Motion Blur, Sharpen (unsharp), Reduce Noise
and Add Noise, each optionally inside a selection's coverage. A **look** is a
named snapshot of tone, adjustment and kind values; SuiteImaging ships the
built-in looks and SuiteModel gets one **preset store** that keeps the saved
ones under the suite support folder. SuiteUI gets one `FilterSheet` (any
kind's or filter's sliders, Preview, OK and Cancel) and one `LookGrid` (on
`PresetGrid`: built-in looks, saved looks, Save Look…, Delete). Every action is a
catalog command (`adjust.*`, `filter.*`, `look.*`), so the menus, the
`afterglow` CLI and MCP run one path, and each is one undo step.
Photo adopts all of it (a Filter menu, Image > Adjustments, B&W and Invert
adjustment layers, looks in the Adjust tab), Library the whole-photo half
(B&W and looks in Develop; no filters, no local adjustments), and Halo the
filters and kinds as a live, editable list on any layer.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps) · **Lead branch:** `lead/adjust-everywhere`
**Beta:** captain, 2026-10-21 (beta gaps cluster C8). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C8 (Photo audit rows 9 and 10, Library audit row 3); feature map S15 (the
preset store and looks; brush, effect, animation and export presets stay
later rows of S15) and the wiring half of E3 and E4; real jobs RJ-X60, RJ-P50
and RJ-H50 (new). **Not here:** Brightness (finding #3527) is a TONE slider in
`tone-controls` (re-cut in this PR, so there is one tone home); Library local
adjustments (captain's call); layer styles (`layer-styles`).

**Depends on:** suite-imaging **IM-a** (the target; AJ-1), **IM-m** (the one
step list and the route; AJ-5), **IM-photo** (`AdjustmentSettings.swift`;
AJ-8) and **IM-z** (`DevelopValues.swift`; AJ-11); tone-controls **TC-m**
(`ToneSettings`, which a look snapshots; AJ-6); shared-thumbnails **ST-m**
(`LibraryCommandCatalog.swift`; AJ-11). The pinned creative-core `2258b62`
has every engine: `blackAndWhite(GrayMix)`, `inverted()`, `gaussianBlur`,
`unsharpMask`, `denoised`, `motionBlurred`, and `ToneProgram.Operation.matrix`
for B&W on the GPU. Add Noise has no core op: AJ-5 writes it in SuiteImaging
as a seeded, deterministic pass (a creative-core issue can lift it later).

**Hand-offs** (files other lines own; cross-line, so not in `waits`; the lead
checks each before the slice starts):
- **AJ-u, AJ-photo:** `PhotoCommands.swift` (one line adds the Filter menu),
  `PhotoCommandCatalog.swift` (one line appends `adjustCommands`) and
  `Tests/command-ids/photo.txt` are photo/tone-controls' and photo/file-flow's
  too: start after their last task on them, or before with the owner told.
- **AJ-library:** `DevelopInspector.swift` and `LibraryCommandCatalog.swift`
  are library/tone-controls' too (LT-m); AJ-11 starts after LT-m.
- **AJ-halo:** `HaloLayer.swift` and `HaloLayerInspector.swift` are Halo's
  transform and gradient-fill packets' too; `LiveFrameRendering.swift` is
  halo/core-loop's. HaloModel links SuiteImaging through layer-styles'
  widening of IM-1; if that hasn't merged, AJ-12 adds the one link line in
  `Package.swift` and `project.yml` as a supervisor merge.

**Rule 20.** One home per concept: kinds, filters and looks in
`Sources/SuiteImaging/Adjust/`, the store in `Sources/SuiteModel/Presets/`,
the views in SuiteUI. Each app keeps one adapter (`PhotoAdjust+Kernel.swift`,
`LibraryLooks+Kernel.swift`, `HaloFilters+Kernel.swift`). Library's
`ExportPresets.swift` (baselined under Export) is a second preset list; it
moves onto the store in export-pack's re-cut, not here, and this packet adds
no third. Photo's whole-image blur (`AdjustmentKind.blur`, composite only)
stays as the adjustment-layer kind it is; the filter is the per-layer one.

**Render path.** B&W and Invert are program steps (`matrix` and an inverted
`levels` with `encoding: .linear`), appended after `ImagingProgram`'s list, so a weight drag is
one display write on the live route. Filters are one CPU pass over one
layer's pixels when the person clicks OK (Photo) or when a Halo frame draws
that layer; the sheet's Preview runs the same pass on a downsampled copy
(longest side 1024 px) so a slider step stays under budget.

**C4:** new component parts `suite-imaging/imaging-adjust-kinds.json`
(`Sources/SuiteImaging/Adjust/` kinds, filters, looks; AJ-1) and
`suite-model/suite-presets.json` (`Sources/SuiteModel/Presets/`; AJ-2). The
SuiteUI views are new files inside `suiteui-sources`.

**Clean-room.** Names and slider ranges from the apps' blueprints and the HIG;
the maths is creative-core's. No task reads another product's code.

Blueprint sections: photo.md 4 (adjustments), library.md (Develop), halo.md
(layers), suite.md 2.6 (store).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AJ-a | SuiteImaging declares the kinds, filters, looks and their commands and SuiteModel the preset store, as stubs, with every Model check written and disabled. | AJ-1, AJ-2 | MJ-AJ | suite-imaging:IM-a |
| AJ-u | Photo's Filter menu and Image > Adjustments open the shared FilterSheet on the stubs, and its Adjust tab shows the LookGrid, every control identified and within the render budget. | AJ-3, AJ-4 | PJ-AJ1 | AJ-a; orientation-crop:OC-photo-u (shared app file) |
| AJ-k | B&W and Invert render on the GPU and the CPU alike, and the five filters run over core inside a selection's coverage, outside pixels unchanged. | AJ-5, AJ-5f | MJ-AJ | AJ-a; suite-imaging:IM-m |
| AJ-c | Looks apply and round-trip through the suite's preset store, and every adjust, filter and look command is one undo step with its reason when it can't run. | AJ-6, AJ-7 | MJ-AJ | AJ-a, AJ-k (AJ-6); tone-controls:TC-m (AJ-6) |
| AJ-photo | In Photo the filters run on the selected pixel layer inside the selection as one undo step, B&W and Invert are adjustments and adjustment-layer kinds, and looks apply and save, all through the catalog. | AJ-8, AJ-9 | PJ-AJ1, PJ-AJ2, MJ-AJ-photo | AJ-c, AJ-u; suite-imaging:IM-photo (`AdjustmentSettings.swift`); brush-keys:BK-photo (shared app file) |
| AJ-library | In Library the Develop panel gets Black & White with its weights and the look grid, whole photo only, kept in the catalog under new keys and run on the GPU route. | AJ-10, AJ-11 | LJ-AJ, MJ-AJ-library | AJ-c, AJ-u; suite-imaging:IM-z (`DevelopValues.swift`); shared-thumbnails:ST-m (`LibraryCommandCatalog.swift`); orientation-crop:OC-library-m (shared app file) |
| AJ-halo | In Halo any layer carries an editable list of filters and kinds, drawn live in the viewer and the render, each change one undo step through the catalog. | AJ-12, AJ-13 | HJ-AJ, MJ-AJ-halo | AJ-c, AJ-u; layer-styles' IM-1 link (cross-line); anchor-parenting:AN-halo (shared app file) |
| AJ-z | RJ-X60 runs the same look in Photo and Library by command and both exports match, the C4 parts name the adopters, and the feature is built. | AJ-14, AJ-15 | MJ-AJ, PJ-AJ2, LJ-AJ, HJ-AJ | AJ-photo, AJ-library, AJ-halo |

**Screen early.** AJ-u builds Photo's real menus and sheet on AJ-a's stubs
(each command on `PendingAdjustTarget` in `Sources/SuiteUI/PendingAdjustTarget.swift`,
so it is unavailable with the reason "Filters arrive with AJ-5.") and
waits on nothing but AJ-a, beside AJ-k and AJ-c. The adopt slices then swap the stubs
for live and turn the journeys on. Library and Halo reuse AJ-u's two views.

**Shared files.** Inside the suiteui line the checker holds the chains:
`AdjustmentSettings.swift` after suite-imaging IM-photo, `DevelopValues.swift`
after IM-z, `LibraryCommandCatalog.swift` and `Tests/command-ids/library.txt`
after shared-thumbnails ST-m. The photo and halo catalog files are the
hand-offs above.

## Journey steps

Linux walks first, then the apps' journeys on the scoped run after each slice's last PR:
- `MJ-AJ`: `AdjustKindsTests`, `FilterRulesTests`, `AdjustCommandsTests` (SuiteImaging) and `PresetStoreTests` (SuiteModel).
- `MJ-AJ-photo`, `MJ-AJ-library`, `MJ-AJ-halo`: `PhotoAdjustTests`, `LibraryLooksTests`, `HaloFiltersTests`.
1. Photo: marquee the background, Filter > Blur > Gaussian Blur…, radius 8, OK; inside is soft, outside unchanged; Undo once restores it (AJ-3, AJ-9; `PJ-AJ1`, `PhotoFilterJourneyTests.testGaussianBlurInsideSelection`).
2. Photo: Adjust tab, click the High Contrast B&W look (`bw-high-contrast`), Save Look… "Mine", open a second image, click Mine (AJ-4, AJ-9; `PJ-AJ2`, `PhotoFilterJourneyTests.testApplyAndSaveLook`).
3. Library: select three photos, click the B&W look; the grid and the loupe go grey; Undo once restores all three (AJ-11; `LJ-AJ`, `LibraryLooksJourneyTests.testBlackAndWhiteLook`).
4. Halo: select a title layer, Add Filter > Gaussian Blur, radius 6; scrub; change it to 2; hide it (AJ-13; `HJ-AJ`, `HaloFilterJourneyTests.testBlurTitleLayer`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X60 | adds, closes with `suiteui/adjust-everywhere` | C | `Tests/RealJobs/photo/same-look-two-apps/`: `look.apply` "bw-high-contrast" on `street.png` in Photo and in Library, `look.save` "Mine", `file.export` PNG from each | `input/street.png` |
| RJ-P50 | adds, closes with `suiteui/adjust-everywhere` | C | `Tests/RealJobs/photo/blur-background/`: `select.rect` the top half, `filter.gaussian-blur` radius 8, export | `input/portrait.png` |
| RJ-H50 | adds, closes with `suiteui/adjust-everywhere` | C | `Tests/RealJobs/halo/blur-title/`: `filter.gaussian-blur` 6 on the title layer, then 2, `render.frame` 12 | `input/title.halo` |

Traps and assertions. RJ-X60: the two apps' B&W differ (one desaturates, one
mixes); both exports have r = g = b within 1 level on every pixel and match
each other within 1 level, and `look.list` names Mine after a relaunch.
RJ-P50: the blur leaks past the selection edge; every pixel of the bottom half
equals the input byte for byte and the top half's local variance drops by more
than half. RJ-H50: the second edit adds a second blur instead of changing the
first; the frame equals a single radius-2 blur within 1 level. Mutations:
`SuiteImaging.FilterRules` (`.outsideUnchanged`), `SuiteImaging.AdjustKinds`
(`.greyStaysInRange`), `HaloModel.HaloFilters+Kernel` (`.editChangesInPlace`).
Each check is written by its slice's first code task and stays disabled with
`waits_on` until it.

## Screens and states

`photo-filter-sheet` (Gaussian Blur, Preview on), `photo-adjust-looks` (the
grid with one saved look), `library-develop-bw` (B&W on, weights shown),
`halo-inspector-filters` (two filters, one hidden). Light and dark where the
app follows the system.

## Contract slice

```swift
// Sources/SuiteImaging/Adjust/AdjustKinds.swift (AJ-1 stubs, AJ-5 bodies). Linux-safe.
public struct GrayWeights: Hashable, Codable, Sendable {      // -200...300 each, the six hue weights
    public var red, yellow, green, cyan, blue, magenta: Double
    public static let neutral: GrayWeights                       // 40, 60, 40, 60, 20, 80
}
public enum ImagingKind: Hashable, Codable, Sendable { case blackAndWhite(GrayWeights), invert
    public var title: String { get } }
public enum AdjustKinds {
    public static func program(_ kinds: [ImagingKind]) -> [ToneProgram.Operation]   // appended after ImagingProgram's
    public static func adjustments(_ kinds: [ImagingKind]) -> [ToneAdjustment]      // the CPU twin
}
public enum ImagingFilter: Hashable, Codable, Sendable {
    case gaussianBlur(radius: Double)                              // 0...250 px
    case motionBlur(degrees: Double, distance: Double)             // 0...360, 0...500 px
    case sharpen(amount: Double, radius: Double, threshold: Double)// 0...500 %, 0.1...250 px, 0...255
    case reduceNoise(strength: Double, detail: Double)             // 0...100 each
    case addNoise(amount: Double, monochrome: Bool, seed: UInt64)  // 0...100 %
    public var id: String { get }        // "gaussian-blur", the command suffix
    public var title: String { get }     // "Gaussian Blur"
    public static func defaults(_ id: String) -> ImagingFilter?
}
// Sources/SuiteImaging/Adjust/FilterRules.swift (AJ-1 stubs, AJ-5 bodies)
public enum FilterRules {
    /// One pass over `pixels`; only where `coverage` is above 0, mixed by it. nil coverage: everywhere.
    public static func apply(_ f: ImagingFilter, to pixels: PixelBuffer, coverage: Mask?) throws -> PixelBuffer
    public static func preview(_ f: ImagingFilter, to pixels: PixelBuffer, coverage: Mask?, longestSide: Int) throws -> PixelBuffer
}
// Sources/SuiteImaging/Adjust/LookPresets.swift (AJ-2 data, AJ-6 apply)
public struct LookPreset: Hashable, Codable, Sendable, Identifiable {
    public var id: String; public var name: String; public var builtIn: Bool
    public var tone: ToneSettings; public var adjust: AdjustSettings; public var kinds: [ImagingKind]
}
public enum BuiltInLooks { public static let all: [LookPreset] }   // bw, bw-high-contrast, warm, cool, fade, vivid
// Sources/SuiteImaging/Adjust/AdjustCommands.swift (AJ-1 specs with real ids, runs throwing NotBuilt; AJ-6 bodies)
public protocol AdjustTarget: Sendable {
    var adjustHelp: String? { get }                       // why nothing can run now
    var filterHelp: String? { get }                       // why filters can't (Library: "Filters are in Photo.")
    var currentLook: LookPreset { get }                   // the target's values as an unsaved look
    var kinds: [ImagingKind] { get }
    mutating func setKinds(_ k: [ImagingKind], name: String) throws
    mutating func applyFilter(_ f: ImagingFilter, name: String) throws   // the selected layer, inside the selection
    mutating func applyLook(_ l: LookPreset, name: String) throws
    var looks: any PresetStoring { get }
}
public enum AdjustCommands { public static func specs<T: AdjustTarget>(_ t: T.Type) -> [CommandSpec<T>] }
// Sources/SuiteModel/Presets/PresetStore.swift (AJ-2 stubs, AJ-7 body)
public protocol PresetStoring: Sendable {
    func list(kind: String) -> [PresetRecord]
    func save(_ r: PresetRecord) throws(SuiteError)        // refuses a taken name, ignoring case
    func delete(id: String, kind: String) throws(SuiteError)
}
public struct PresetRecord: Hashable, Codable, Sendable { public var id, name, kind: String; public var payload: Data }
public struct PresetStore: PresetStoring { public init(folder: String) }   // one revisioned presets/looks.json for every kind; the app window passes SuiteLocations.processSupportFolder
```

Commands (ids go in each adopter's `Tests/command-ids/<app>.txt`):

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `adjust.black-and-white` | Black & White | `{weights?}` (nil removes it) | `adjustHelp` |
| `adjust.invert` | Invert | – (toggles) | `adjustHelp` |
| `filter.<id>` (five) | the filter's title | the case's fields | `adjustHelp`, `filterHelp`; no pixel layer selected |
| `look.list` | – (query) | – → `[{id, name, builtIn}]` | – |
| `look.apply` | Apply Look | `{id}` | `adjustHelp`; unknown id |
| `look.save` | – (not a document edit) | `{name}` → `{id}` | a taken name |
| `look.delete` | – | `{id}` | a built-in |

## Pseudocode

- **B&W on the GPU.** The six weights become one 3x3 `matrix`: each output
  row is the luminance-weighted mix of the hue weights for that pixel's
  dominant hue pair, normalised so neutral weights keep mid grey. The CPU twin
  is core's `blackAndWhite(GrayMix)` with the same weights;
  `AdjustKindsTests.gpuMatchesCpu` renders both on a hue-wheel fixture.
- **Invert.** `levels(inBlack 0, inWhite 1, gamma 1, outBlack 1, outWhite 0, encoding: .linear)`;
  the test holds it against core's `inverted()` within 1 level.
- **Filters in a selection.** `apply` runs the core op on the layer's bounds
  padded by the op's reach (3 sigma for blur, the distance for motion), then
  mixes result and input by the coverage. Coverage 0 pixels are copied, never
  recomputed, so they stay byte for byte.
- **Add Noise.** A counter-based hash of (x, y, seed) per channel (one value
  for all three when monochrome), uniform in ±amount, added in sRGB and
  clamped. The seed is a command param, so a script repeats exactly.
- **Looks.** `look.apply` replaces tone, adjust and kinds in one step; a
  value the target can't hold (Library has no curve points beyond its own)
  is kept as the target's nearest. `look.save` encodes `LookPreset` into a
  `PresetRecord` of kind `look`.
- **Halo.** A layer's list runs in order on its rendered pixels before its
  blend and opacity, each frame; the viewer caches the filtered layer by
  (layer, frame, list) so a scrub that doesn't change the list reuses it.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AJ-1 | – | **Checks first, then the stubs.** `AdjustKindsTests`, `FilterRulesTests` and `AdjustCommandsTests` written, disabled by name (`waits on AJ-5`, `AJ-6`); `ImagingKind`, `ImagingFilter` with ranges and neutral values, `FilterRules` and `AdjustCommands` (real ids, schemas and availability, runs throwing `NotBuilt`); the C4 part | `Sources/SuiteImaging/Adjust/AdjustKinds.swift`, `Sources/SuiteImaging/Adjust/FilterRules.swift`, `Sources/SuiteImaging/Adjust/AdjustCommands.swift`, `Tests/SuiteImagingTests/AdjustKindsTests.swift`, `Tests/SuiteImagingTests/FilterRulesTests.swift`, `Tests/SuiteImagingTests/AdjustCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-imaging/imaging-adjust-kinds.json` | – | ~240, 7 |
| AJ-2 | – | Looks and the store as stubs: `LookPreset` and `BuiltInLooks` (the six looks as data), `PresetStoring` with `PresetStore` over `FileStore` (`presets/looks.json`) and `FakePresetStore`; `PresetStoreTests` written, disabled (`waits on AJ-7`); the C4 part | `Sources/SuiteImaging/Adjust/LookPresets.swift`, `Sources/SuiteModel/Presets/PresetStore.swift`, `Sources/SuiteModel/Fakes/FakePresetStore.swift`, `Tests/SuiteModelTests/PresetStoreTests.swift`, `docs/c4/parts/creative-apps/suite-model/suite-presets.json` | – | ~170, 5 |
| AJ-3 | – | **Reachable first.** Photo's Filter menu (Blur > Gaussian Blur…, Motion Blur…; Sharpen…; Noise > Reduce Noise…, Add Noise…) and Image > Adjustments > Black & White…, Invert, each a catalog command; SuiteUI `FilterSheet` on `SuiteSheet`, one `InspectorSliderRow` per range of the kind (Preview, OK, Cancel; emits one intent); `PhotoFilterJourneyTests` written, skipped until AJ-8 | `Sources/SuiteUI/FilterSheet.swift`, `Sources/PhotoApp/PhotoCommands+Filter.swift`, `Sources/PhotoApp/PhotoCommands.swift`, `UITests/PhotoJourneyTests+Filter.swift`, `Tests/SuiteUITests/FilterSheetTests.swift` | AJ-1 | ~220, 5 |
| AJ-4 | – | SuiteUI `LookGrid` on `PresetGrid`: built-in looks, then saved ones, Save Look… (name field), Delete with a confirm; shown in Photo's Adjust tab on the fake store; render budget test | `Sources/SuiteUI/LookGrid.swift`, `Sources/PhotoApp/PhotoAdjustTab.swift`, `Tests/SuiteUITests/LookGridTests.swift`, `Tests/AppSnapshotTests/RenderBudgetAdjustTests.swift` | AJ-3 | ~170, 4 |
| AJ-5 | – | `AdjustKinds` bodies: B&W as a `matrix` step and core's `blackAndWhite` on the CPU, Invert as an inverted linear `levels` and core's `inverted()`; turns on `AdjustKindsTests` | `Sources/SuiteImaging/Adjust/AdjustKinds.swift`, `Tests/SuiteImagingTests/AdjustKindsTests.swift`, `Tests/mutations/SuiteImaging.AdjustKinds.json` | AJ-1 | ~150, 3 |
| AJ-5f | – | `FilterRules` bodies: the five filters over core on the layer's padded bounds, mixed by a coverage `Mask`; the seeded Add Noise; the 1024 px preview; turns on `FilterRulesTests` | `Sources/SuiteImaging/Adjust/FilterRules.swift`, `Tests/SuiteImagingTests/FilterRulesTests.swift`, `Tests/mutations/SuiteImaging.FilterRules.json` | AJ-1 | ~200, 3 |
| AJ-6 | – | `AdjustCommands` bodies over `AdjustTarget`: `adjust.black-and-white`, `adjust.invert`, `filter.<id>`, `look.apply`, `look.save`, `look.delete`, `look.list`; a look snapshots `ToneSettings`, `AdjustSettings` and kinds; turns on `AdjustCommandsTests` | `Sources/SuiteImaging/Adjust/AdjustCommands.swift`, `Sources/SuiteImaging/Adjust/LookPresets.swift`, `Tests/SuiteImagingTests/AdjustCommandsTests.swift`, `Tests/mutations/SuiteImaging.AdjustCommands.json` | AJ-5, AJ-5f | ~230, 4 |
| AJ-7 | #4867 (merged) | `PresetStore` body: revisioned `presets/looks.json` under `SuiteLocations`, names unique ignoring case, a damaged file set aside, never a built-in overwritten; turns on `PresetStoreTests` | `Sources/SuiteModel/Presets/PresetStore.swift`, `Tests/SuiteModelTests/PresetStoreTests.swift`, `Tests/mutations/SuiteModel.PresetStore.json` | AJ-2 | ~150, 3 |
| AJ-8 | – | **Test first.** `PhotoAdjustTests` (filters on a layer and in a selection, kinds as layers, the `.ora` round trip of the new kinds); `PhotoAdjust+Kernel.swift` conforms `PhotoWorkspace` to `AdjustTarget`; `AdjustmentSettings` stores `kinds: [ImagingKind]` (B&W and Invert; `AdjustmentKind` keeps its five sections), and PhotoModel's own enum is renamed `PhotoAdjustTarget` so the suite's `AdjustTarget` protocol is unambiguous; the catalog appends `adjustCommands`; ids in the ledger; RJ-P50's job folder | `Tests/PhotoModelTests/PhotoAdjustTests.swift`, `Sources/PhotoModel/PhotoAdjust+Kernel.swift`, `Sources/PhotoModel/AdjustmentSettings.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/mutations/PhotoModel.PhotoAdjust+Kernel.json`, `Tests/RealJobs/photo/blur-background/blur-background.jobs.json`, `Tests/RealJobs/photo/blur-background/input/portrait.png` | AJ-6 | ~250, 8 |
| AJ-9 | – | The UI on live: the sheet's Preview on a 1024 px copy, OK runs the command; the look grid on the live store; `PhotoFilterJourneyTests` turned on | `Sources/PhotoApp/PhotoWindow+Filter.swift`, `UITests/PhotoJourneyTests+Filter.swift` | AJ-8, AJ-4 | ~150, 2 |
| AJ-10 | – | **Test first.** `LibraryLooksTests` (B&W and Invert stored under `bw` and `invert`, old catalogs open unchanged, a look applied to 40 photos is one step); `LibraryLooks+Kernel.swift` conforms the catalog to `AdjustTarget` (kinds and looks only: the filter commands are unavailable with "Filters are in Photo."); the catalog appends the specs; ids in the ledger | `Tests/LibraryModelTests/LibraryLooksTests.swift`, `Sources/LibraryModel/LibraryLooks+Kernel.swift`, `Sources/LibraryModel/Contracts/DevelopValues.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/mutations/LibraryModel.LibraryLooks+Kernel.json` | AJ-6 | ~250, 6 |
| AJ-11 | – | Develop's BLACK & WHITE section (a switch and six weights) and the look grid above the tone rows; the loupe appends the kinds to its live program; `LibraryLooksJourneyTests` | `Sources/LibraryApp/DevelopInspector.swift`, `Sources/LibraryApp/LibraryDevelopLooks.swift`, `UITests/LibraryJourneyTests+Looks.swift` | AJ-10, AJ-4 | ~150, 3 |
| AJ-12 | – | **Test first.** `HaloFiltersTests` (a layer's list draws in `renderFrame`, round-trips in `.halo`, an empty list writes no key); `HaloFilters+Kernel.swift` conforms the project to `AdjustTarget` per selected layer; `HaloLayer` gains `filters`; `LiveFrameRendering` runs the list on the layer's pixels before its blend; the specs and ids; RJ-H50's job folder | `Tests/HaloModelTests/HaloFiltersTests.swift`, `Sources/HaloModel/HaloFilters+Kernel.swift`, `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/mutations/HaloModel.HaloFilters+Kernel.json`, `Tests/RealJobs/halo/blur-title/blur-title.jobs.json`, `Tests/RealJobs/halo/blur-title/input/title.halo` | AJ-6 | ~260, 9 |
| AJ-13 | – | Halo's FILTERS inspector section: Add Filter menu, one row per filter (its sliders, a hide switch, remove), reorder by drag; `HaloFilterJourneyTests` | `Sources/HaloApp/HaloLayerInspector.swift`, `Sources/HaloApp/HaloFilterSection.swift`, `UITests/HaloJourneyTests+Filter.swift` | AJ-12, AJ-3 | ~150, 3 |
| AJ-14 | – | RJ-X60's job (the B&W look in both apps by `look.apply`, both exported) and its check, enabled | `Tests/RealJobs/photo/same-look-two-apps/same-look-two-apps.jobs.json`, `Tests/RealJobs/photo/same-look-two-apps/input/street.png` | AJ-8, AJ-10 | ~90, 2 |
| AJ-15 | – | The C4 parts name Photo, Library and Halo; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-imaging/imaging-adjust-kinds.json`, `docs/blueprints/suiteui/features/adjust-everywhere.wave.json` | AJ-14, AJ-9, AJ-11, AJ-13 | ~30, 2 |

## Build waves

- Wave 1: AJ-1, AJ-2. Independent in this wave: both.
- Wave 2: AJ-3, AJ-5, AJ-5f, AJ-7. Independent in this wave: all.
- Wave 3: AJ-4, AJ-6. Independent in this wave: both.
- Wave 4: AJ-8, AJ-10, AJ-12. Independent in this wave: all.
- Wave 5: AJ-9, AJ-11, AJ-13, AJ-14. Independent in this wave: all.
- Wave 6: AJ-15. Independent in this wave: AJ-15 alone.

Longest chain: AJ-1 → AJ-5 → AJ-6 → AJ-8 → AJ-14 → AJ-15 (6). Chain of 6: the stubs before the bodies, the bodies before the commands that call them, the commands before an app adopts them, and an app's Model before its window.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AJ-1 | the three suites compile, disabled by name; `swift build` on Linux | a signature the adopters call is missing | – (stubs) |
| AJ-2 | compiles, disabled by name; the built-in looks decode | a look the grid lists has no data | – (stubs) |
| AJ-3 | `FilterSheetTests`: every slider's range and step come from the kind; Cancel emits nothing; OK emits one intent with the values; the menu items exist with their command ids | a slider ignores its range, Cancel applies, or an item has no command | – (view; render budget row) |
| AJ-4 | `LookGridTests`: built-ins first, saved after, a built-in has no Delete; `RenderBudgetAdjustTests.lookHoverInTwoBodies` | a built-in can be deleted, or hover re-renders the window | – (view; render budget row) |
| AJ-5 | `AdjustKindsTests`: B&W gives r = g = b within 1 level and the weights move a red patch's grey; the GPU program and the CPU list match within 1 level on a hue wheel; Invert twice is the input | B&W keeps colour, or the two routes drift | `SuiteImaging.AdjustKinds`: weights summed without normalising → `.greyStaysInRange`; levels not inverted → `.invertTwiceIsInput` |
| AJ-5f | `FilterRulesTests`: pixels outside the coverage are unchanged byte for byte; blur radius 0 is the input; Add Noise with one seed is the same twice and differs with another; a preview's longest side is 1024 | a filter leaks outside the selection, or noise isn't repeatable | `SuiteImaging.FilterRules`: coverage ignored (whole layer filtered) → `.outsideUnchanged`; seed not used → `.noiseIsSeeded`; padding dropped (a hard edge at the bounds) → `.blurReachesPastBounds` |
| AJ-6 | `AdjustCommandsTests` on a test target: each command is one undo step; `look.apply` then undo restores every value; a look saved and applied to a second target gives the same values; a filter with no layer is unavailable with the reason | a command records two steps or none, or a look drops a value | `SuiteImaging.AdjustCommands`: undo step not recorded for `look.apply` → `.lookIsOneStep`; tone not captured in `look.save` → `.lookKeepsTone` |
| AJ-7 | `PresetStoreTests`: save, relaunch (a new store on the folder), list; a second "mine" is refused; a damaged file reads as empty and is kept aside | a saved look is lost on relaunch or a duplicate name is kept | `SuiteModel.PresetStore`: case-sensitive name check → `.namesUniqueIgnoringCase`; write without the revision → `.relaunchKeepsLooks` |
| AJ-8 | `PhotoAdjustTests`; `scripts/mutate --plan PhotoModel.PhotoAdjust+Kernel`; RJ-P50 on Linux | a filter changes another layer or pixels outside the selection, or an old `.ora` opens differently | `PhotoModel.PhotoAdjust+Kernel`: filter applied to the composite instead of the layer → `.otherLayersUnchanged`; selection coverage dropped → `.insideSelectionOnly` |
| AJ-9 | `PJ-AJ1`, `PJ-AJ2` | OK doesn't change the layer, or Preview changes the document | – (window wiring; AJ-8's plan covers the logic) |
| AJ-10 | `LibraryLooksTests`; `scripts/mutate --plan LibraryModel.LibraryLooks+Kernel` | a catalog written before this opens with different values, or a look on a selection is many steps | `LibraryModel.LibraryLooks+Kernel`: look applied to the active photo only → `.wholeSelection`; neutral `bw` written as a key → `.oldCatalogBytesUnchanged` |
| AJ-11 | `LJ-AJ`; Library's develop snapshots unchanged when B&W is off | the loupe stays in colour with B&W on, or the panel changes for a photo without it | – (view) |
| AJ-12 | `HaloFiltersTests`; RJ-H50 on Linux | a filter draws on the wrong layer, is lost on save, or an old project changes bytes | `HaloModel.HaloFilters+Kernel`: list applied after the blend → `.filterBeforeBlend`; empty list encoded → `.oldProjectBytesUnchanged` |
| AJ-13 | `HJ-AJ`; Halo's inspector snapshots unchanged for a layer with no filters | a row edits another layer, or the section shows for no selection | – (view) |
| AJ-14 | `scripts/jobs check`; RJ-X60 green on Linux | the two apps' B&W differ | – (job; AJ-5's plan holds the trap) |
| AJ-15 | `scripts/waves render --dry-run`; `scripts/c4-assemble --check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: look grid hover in Photo's Adjust tab | 120-sample hover ≤ 2 window bodies | `RenderBudgetAdjustTests.lookHoverInTwoBodies` |
| render: Gaussian Blur radius drag with Preview on, 8K layer | 120-sample drag ≤ 3 window bodies; preview step p95 ≤ 50 ms | `RenderBudgetAdjustTests.blurPreviewDrag` |
| render: B&W weight drag in Library's loupe | ≤ 3 window bodies; one display write per step | `RenderBudgetLibraryDevelopTests.exposureDragInThreeBodies` (pattern, new test `bwWeightDrag`) |
| render: Halo scrub with a blurred layer | 120 frames ≤ 3 window bodies each | `RenderBudgetHaloTests.scrubWithFilter` |
| one gesture, one step | a filter, a look, a weight drag: one undo step each | `AdjustCommandsTests`, `PhotoAdjustTests`, `LibraryLooksTests`, `HaloFiltersTests` |
| no dead controls | every new item is a catalog command; nothing joins `Tests/command-path-baseline/` | `CommandPathTests` |
| keyboard parity | Image > Adjustments > Invert ⌘I; every sheet field reachable by Tab | `PhotoFilterJourneyTests` |
| behaviour preserved | old `.ora`, catalog and `.halo` files open with the same bytes on re-save | `PhotoAdjustTests`, `LibraryLooksTests`, `HaloFiltersTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): AJ-a, AJ-k and AJ-c green on the Linux job with
`Mutate:` scores clean; AJ-u, AJ-photo, AJ-library and AJ-halo through the
feel gate (`mouse`, `taste`, `perf`: drag a blur radius on an 8K layer, a
B&W weight in the loupe, scrub a filtered Halo layer) with their `Mac-Finish:`
lines; RJ-P50 and RJ-H50 green on Linux at merged-done, RJ-X60 at AJ-z. Then
`Belt-Contact-Sheet:` with the four screens.
