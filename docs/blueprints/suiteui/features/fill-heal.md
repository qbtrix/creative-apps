# Feature packet: fill-heal

**Feature:** the fill and repair tools a photo editor is judged on in week one,
on engines creative-core already has. SuiteImaging gets a `Retouch/` module:
the **paint bucket** (a seed point, a tolerance, contiguous or not, this layer
or all layers, always inside the selection), **spot heal** (one click: a round
patch filled from texture the engine finds nearby), **heal** (a brush stroke
from an Option-clicked source, the engine's blend instead of Photo's per-dab
tone match) and **remove** (paint over an object, or use the selection, and it
is filled from its surroundings). SuiteKernel gets the one piece of stroke
geometry they share: the coverage a dab stroke paints (`DabCoverage`, over
`DabSpacer`). Every action is a catalog command (`fill.bucket`,
`retouch.spot-heal`, `retouch.heal`, `retouch.remove`), one undo step each.
Photo adopts first: Paint Bucket (G), Spot Heal (J) and Remove tools in the
palette with their options; its Heal tool keeps its place and gets the true heal.
Library (dust spots) adopts later, after the beta.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps) · **Lead branch:** `lead/fill-heal`
**Beta:** captain, 2026-10-21 (beta gaps cluster C10). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` C10; Photo audit rows 3 and 4;
feature map E6 (fill tools) and E7 (retouch), their Photo adopter; RJ-P04 and
RJ-P07 (closed by this packet now, `needs` keep E6 and E7) and RJ-P51 (new).

**Depends on:** suite-imaging **IM-a** (FH-1). The pinned creative-core
`2258b62` has `floodMask(from:tolerance:contiguous:)` and `ColorRange`
(fill-tools #435), `healed(offset:through:)`, `filledFromSurroundings(_:seed:)`,
`PatchSearch` and `HealSolver` (retouch-heal #436, RH-8 built). No core issue.
editor-kernel (built): `DabSpacer`, `BrushSettings`, `History`, `CommandSpec`.

**Hand-offs** (cross-line; the lead checks each before its slice starts):
- **FH-u:** `PhotoPaletteTool.swift` is photo/eyedropper PE-a's and
  `PhotoToolOptions.swift` photo/gradient-fill PG-a's too.
- **FH-photo:** `PhotoCommandCatalog.swift` and `Tests/command-ids/photo.txt`
  follow the photo packets' last task on them (tone-controls PT-4, file-flow).

**Rule 20.** One home for fill and repair: the rules and commands in
`Sources/SuiteImaging/Retouch/`, the dab coverage in SuiteKernel's `Stroke/`
(Foundation only, so `KernelShapeTests` holds), the engines in creative-core.
Photo keeps one adapter, `PhotoRetouch+Kernel.swift`. `PhotoRetouch.swift`
keeps the clone stamp (its own concept until a later packet lifts it) and loses
its tone-match heal (`toneShift`), which FH-7 deletes. Photo's
`edit.fill-selection` stays the "fill the whole selection" command; the
bucket is the seeded one and calls the same fill colour path.

**Render path.** Each tool is one CPU pass over the target layer's bounding
tiles when the click or stroke ends (the stroke's live preview is the brush
cursor and the dab outline, not pixels). A spot heal at 8K stays inside one
frame budget because the engine works on the patch's bounds plus its search
radius, never the layer.

**C4:** new component parts `suite-imaging/imaging-retouch.json` (FH-1) and
an edit to `suite-kernel/kernel-stroke.json` (FH-1 names `DabCoverage`).

**Clean-room.** Tool names and shortcuts from the HIG and Photo's blueprint;
the engines are creative-core's. No task reads another product's code.

Blueprint sections: photo.md 4 (tools), suiteui.md 2 (kernel tiers).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FH-a | SuiteImaging declares the bucket, heal and remove rules and commands, and SuiteKernel the dab coverage, as stubs, with every Model check written and disabled. | FH-1, FH-2 | MJ-FH | suite-imaging:IM-a; brush-keys:BK-m (shared app file) |
| FH-u | Photo's palette shows Paint Bucket, Spot Heal and Remove with their options on the stubs, each tool reachable by click and key, every control identified, within the render budget. | FH-3, FH-4 | PJ-FH1 | FH-a; adopt-kernel-brush:AB-photo, adopt-kernel-layers:AL-photo, adopt-kernel-export:AX-photo, adopt-kernel-undo:AU-photo, adopt-suiteui-chrome:AC-colour (`PhotoWorkspace.swift`, `PhotoToolOptions.swift`); brush-keys:BK-photo (shared app file) |
| FH-r | The bucket fills exactly the seeded region inside the selection, and spot heal, heal and remove fill from texture through creative-core. | FH-5b, FH-5h | MJ-FH | FH-a |
| FH-c | The dab coverage matches the brush, and every fill and heal command is one undo step with its reason when it can't run. | FH-5k, FH-6 | MJ-FH | FH-a, FH-r |
| FH-photo | In Photo the bucket, spot heal, heal and remove change the selected pixel layer through the catalog as one undo step each, the old tone-match heal is gone, RJ-P04, RJ-P07 and RJ-P51 pass, and the feature is built. | FH-7, FH-8, FH-9, FH-10 | PJ-FH1, PJ-FH2, MJ-FH-photo, MJ-FH | FH-c, FH-u; adjust-everywhere:AJ-photo (Photo's catalog and ledger); brush-keys:BK-photo (shared app file) |

**Screen early.** FH-u builds Photo's real palette entries and options on
FH-a's stubs and waits on no slice of this feature but FH-a, beside FH-r and FH-c.
FH-photo swaps the stubs for live.

**Shared files.** `PhotoWorkspace.swift` (the `PhotoTool` cases) follows the
four kernel adopts that own it on this line; Photo's catalog and ledger follow
adjust-everywhere's AJ-photo, so the two packets' Photo slices never collide.

## Journey steps

Linux walks first, then Photo's journeys on the scoped run after each slice's last PR:
- `MJ-FH`: `BucketRulesTests`, `HealRulesTests`, `RetouchCommandsTests` (SuiteImaging) and `DabCoverageTests` (SuiteKernel).
- `MJ-FH-photo`: `PhotoRetouchKernelTests`.
1. Open the logo fixture, press G, Tolerance 32, click the white background: it turns the paint colour, the logo stays; Undo once (FH-3, FH-8; `PJ-FH1`, `PhotoRetouchJourneyTests.testPaintBucket`).
2. Open the sky fixture, press J, click three dust spots: each is gone in one step; Shift-J to Remove, paint over the passer-by: filled from the sand; Undo once restores the person (FH-3, FH-4, FH-8; `PJ-FH2`, `PhotoRetouchJourneyTests.testSpotHealAndRemove`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P04 | closes (re-pointed to `suiteui/fill-heal`) | C | `Tests/RealJobs/photo/dust-spots/`: 20 `retouch.spot-heal` clicks at the dust coordinates the fixture lists | its existing input |
| RJ-P07 | closes (re-pointed; `needs` adds S5 for the lasso) | C | `Tests/RealJobs/photo/remove-passerby/`: `select.lasso` round the person, `retouch.remove`, export | its existing input |
| RJ-P51 | adds, closes with `suiteui/fill-heal` | C | `Tests/RealJobs/photo/bucket-background/`: `fill.bucket` at (4, 4), tolerance 32, contiguous, red; export | `input/logo.png` |

Traps and assertions. RJ-P04: a heal leaves a soft grey smudge where the dust
was; every spot's 9×9 patch is within 4 levels of its ring's mean and no
spot's darkest pixel survives. RJ-P07: remove smears the person's colour into
the sand; no pixel inside the lasso is within 10 levels of the person's
jacket colour and the patch's local variance is within 30% of the sand's.
RJ-P51: the bucket bleeds into the anti-aliased logo edge or misses the
corners; every background pixel is red, every logo pixel unchanged. Mutations:
`SuiteImaging.HealRules` (`.removeIsRepeatable`, `.healCopiesFromSource`),
`SuiteImaging.BucketRules` (`.contiguousStopsAtEdges`). FH-2 writes the
checks; they stay disabled with `waits_on: FH-6` (RJ-P07 also waits on the
lasso command).

## Screens and states

`photo-palette-retouch` (the three new tools), `photo-options-bucket`,
`photo-remove-stroke` (the tinted stroke before release),
`photo-heal-done` (a healed sky).

## Contract slice

```swift
// Sources/SuiteKernel/Stroke/DabCoverage.swift (FH-1 stub, FH-5k body). Foundation only.
public struct CoverageGrid: Hashable, Sendable {
    public var originX, originY, width, height: Int
    public var values: [Float]                       // 0...1, row by row
}
public enum DabCoverage {
    public static func stroke(_ points: [Point], brush: BrushSettings) -> CoverageGrid
    public static func disc(at p: Point, size: Double, hardness: Double) -> CoverageGrid
}
// Sources/SuiteImaging/Retouch/BucketRules.swift (FH-1 stubs, FH-5 bodies)
public struct BucketOptions: Hashable, Codable, Sendable {
    public var tolerance: Int                        // 0...255
    public var contiguous: Bool                      // default true
    public var sampleAllLayers: Bool                 // default false
    public var antiAlias: Bool                       // default true: a one-pixel soft edge
}
public enum BucketRules {
    /// The region to fill: the seed's flood mask in `sample`, times the selection's coverage when there is one.
    public static func region(seed: (x: Int, y: Int), in sample: PixelBuffer, options: BucketOptions,
                              selection: Mask?) throws -> Mask
    public static func fill(_ pixels: PixelBuffer, region: Mask, color: RGBA) throws -> PixelBuffer
}
// Sources/SuiteImaging/Retouch/HealRules.swift (FH-1 stubs, FH-5 bodies)
public enum HealRules {
    public static func spotHeal(_ pixels: PixelBuffer, at p: (x: Int, y: Int), size: Double, seed: UInt64) throws -> PixelBuffer
    public static func heal(_ pixels: PixelBuffer, through coverage: Mask, sourceOffset: (dx: Int, dy: Int)) throws -> PixelBuffer
    public static func remove(_ pixels: PixelBuffer, through coverage: Mask, seed: UInt64) throws -> PixelBuffer
    public static func mask(_ grid: CoverageGrid) -> Mask
}
// Sources/SuiteImaging/Retouch/RetouchCommands.swift (FH-1 specs, runs throwing NotBuilt; FH-6 bodies)
public protocol RetouchTarget: Sendable {
    var retouchHelp: String? { get }                 // no image, no pixel layer, a locked layer
    var targetPixels: PixelBuffer? { get }           // the selected pixel layer
    var mergedPixels: PixelBuffer? { get }           // for All Layers
    var selectionCoverage: Mask? { get }
    var paintColor: RGBA { get }
    var cloneOffset: (dx: Int, dy: Int)? { get }
    mutating func replaceTarget(_ p: PixelBuffer, name: String) throws   // one undo step
}
public enum RetouchCommands { public static func specs<T: RetouchTarget>(_ t: T.Type) -> [CommandSpec<T>] }
```

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `fill.bucket` | Paint Bucket | `{x, y, tolerance?, contiguous?, allLayers?, color?}` | `retouchHelp` |
| `retouch.spot-heal` | Spot Heal | `{x, y, size, seed?}` | `retouchHelp` |
| `retouch.heal` | Heal | `{points, size, hardness?}` | `retouchHelp`; no source sampled ("Option-click a source first.") |
| `retouch.remove` | Remove | `{points?, size?, seed?}` | `retouchHelp`; no points and no selection |

## Pseudocode

- **Bucket.** Sample = the target layer, or the merged picture with All
  Layers. `floodMask(from: seed, tolerance: .within(t), contiguous:)` gives
  the region; multiply by the selection's coverage; with anti-alias, grow
  the mask's edge by one pixel at half coverage. Fill writes the colour
  mixed by the mask into the target only.
- **Spot heal.** The disc's coverage; `PatchSearch` finds the best source
  offset within 4 radii, outside the disc; `healed(offset:through:)` blends
  it in. The seed picks between equal candidates, so a script repeats.
- **Heal.** Photo's existing Option-click source sets `cloneOffset`; the
  stroke's `DabCoverage` becomes the mask; one `healed` call over the
  stroke's bounds when the stroke ends.
- **Remove.** Coverage from the stroke, else the selection; dilate by 2 px;
  `filledFromSurroundings(mask, seed:)`.
- **Bounds.** Every pass runs on the mask's bounds padded by the engine's
  reach, then writes those tiles back; undo keeps those tiles (Photo's
  `History` pattern), never the layer.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FH-1 | – | **Checks first, then the stubs.** `BucketRulesTests`, `HealRulesTests`, `RetouchCommandsTests` and `DabCoverageTests` written, disabled by name; `BucketOptions`, `BucketRules`, `HealRules`, `RetouchTarget` and `RetouchCommands` (real ids, schemas, availability; runs throwing `NotBuilt`); `DabCoverage` returning an empty grid; the C4 parts | `Sources/SuiteImaging/Retouch/BucketRules.swift`, `Sources/SuiteImaging/Retouch/HealRules.swift`, `Sources/SuiteImaging/Retouch/RetouchCommands.swift`, `Sources/SuiteKernel/Stroke/DabCoverage.swift`, `Tests/SuiteImagingTests/BucketRulesTests.swift`, `Tests/SuiteImagingTests/HealRulesTests.swift`, `Tests/SuiteImagingTests/RetouchCommandsTests.swift`, `Tests/SuiteKernelTests/DabCoverageTests.swift`, `docs/c4/parts/creative-apps/suite-imaging/imaging-retouch.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-stroke.json` | – | ~260, 10 |
| FH-2 | – | RJ-P51's job folder and RJ-P04's and RJ-P07's re-pointed checks, disabled (`waits_on` FH-6) | `Tests/RealJobs/photo/bucket-background/bucket-background.jobs.json`, `Tests/RealJobs/photo/bucket-background/input/logo.png`, `Tests/RealJobs/photo/dust-spots/dust-spots.jobs.json`, `Tests/RealJobs/photo/remove-passerby/remove-passerby.jobs.json` | – | ~100, 4 |
| FH-3 | – | **Reachable first.** `PhotoTool` gains `bucket`, `spotHeal` and `remove`; the palette shows them (G, J, Shift-J cycles Spot Heal, Heal, Remove); the options bar: Tolerance, Contiguous, All Layers for the bucket, Size and Hardness for the heal tools; each click calls its command (unavailable on the stubs with "Fill and heal arrive with FH-5."); `PhotoRetouchJourneyTests` written, skipped until FH-6 | `Sources/PhotoModel/PhotoWorkspace.swift`, `Sources/PhotoApp/PhotoPaletteTool.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Sources/PhotoApp/PhotoRetouchOptions.swift`, `UITests/PhotoJourneyTests+Retouch.swift` | FH-1 | ~220, 5 |
| FH-4 | – | The Remove tool's stroke outline (SuiteUI `CanvasMarks` path mark, the painted area tinted) and the spot heal's ring cursor; render budget test | `Sources/PhotoApp/PhotoCanvasOverlay.swift`, `Tests/AppSnapshotTests/RenderBudgetRetouchTests.swift` | FH-3 | ~150, 2 |
| FH-5b | – | `BucketRules` body over core: `floodMask` (sampling the layer or the merged picture) intersected with the selection's coverage, filled with the colour, the one-pixel anti-aliased edge; turns on `BucketRulesTests` | `Sources/SuiteImaging/Retouch/BucketRules.swift`, `Tests/SuiteImagingTests/BucketRulesTests.swift`, `Tests/mutations/SuiteImaging.BucketRules.json` | FH-1 | ~120, 3 |
| FH-5h | – | `HealRules` body over core: spot heal via `PatchSearch` then `healed`; heal from a source offset; remove via `filledFromSurroundings` with a seed; `mask(_:)` from a coverage grid; turns on `HealRulesTests` | `Sources/SuiteImaging/Retouch/HealRules.swift`, `Tests/SuiteImagingTests/HealRulesTests.swift`, `Tests/mutations/SuiteImaging.HealRules.json` | FH-1 | ~150, 3 |
| FH-5k | – | `DabCoverage` body: the dabs `DabSpacer` lays along the points, each a disc of the brush's size and hardness, max-combined into a coverage grid over the stroke's bounds; turns on `DabCoverageTests` | `Sources/SuiteKernel/Stroke/DabCoverage.swift`, `Tests/SuiteKernelTests/DabCoverageTests.swift`, `Tests/mutations/SuiteKernel.DabCoverage.json` | FH-1 | ~120, 3 |
| FH-6 | – | `RetouchCommands` bodies over `RetouchTarget`: `fill.bucket`, `retouch.spot-heal`, `retouch.heal`, `retouch.remove` (points, or the selection when none); each one undo step named for its tool; turns on `RetouchCommandsTests` | `Sources/SuiteImaging/Retouch/RetouchCommands.swift`, `Tests/SuiteImagingTests/RetouchCommandsTests.swift`, `Tests/mutations/SuiteImaging.RetouchCommands.json` | FH-5b, FH-5h, FH-5k | ~180, 3 |
| FH-7 | – | **Test first.** `PhotoRetouchKernelTests`; `PhotoRetouch+Kernel.swift` conforms `PhotoWorkspace` to `RetouchTarget` (the paint target, the selection's coverage, the layer's tiles for undo); the Heal tool calls `retouch.heal`; `toneShift` and its plan entries deleted from `PhotoRetouch.swift`; the catalog appends the specs; ids in the ledger; the three jobs enabled | `Tests/PhotoModelTests/PhotoRetouchKernelTests.swift`, `Sources/PhotoModel/PhotoRetouch+Kernel.swift`, `Sources/PhotoModel/PhotoRetouch.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/mutations/PhotoModel.PhotoRetouch+Kernel.json`, `Tests/mutations/PhotoModel.PhotoRetouch.json` | FH-6, FH-3 | ~300, 7 |
| FH-8 | – | The window on live: a click or a stroke ends in one command; `PhotoRetouchJourneyTests` turned on | `Sources/PhotoApp/PhotoWindow+Retouch.swift`, `UITests/PhotoJourneyTests+Retouch.swift` | FH-7, FH-4 | ~130, 2 |
| FH-9 | – | The retouch part names Photo; Library's dust-spot adopt is written down as the next adopter in the part's description | `docs/c4/parts/creative-apps/suite-imaging/imaging-retouch.json` | FH-7 | ~20, 1 |
| FH-10 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/fill-heal.wave.json` | FH-9, FH-8 | ~10, 1 |

## Build waves

- Wave 1: FH-1, FH-2. Independent in this wave: both.
- Wave 2: FH-3, FH-5b, FH-5h, FH-5k. Independent in this wave: all.
- Wave 3: FH-4, FH-6. Independent in this wave: both.
- Wave 4: FH-7. Independent in this wave: FH-7 alone.
- Wave 5: FH-8, FH-9. Independent in this wave: both.
- Wave 6: FH-10. Independent in this wave: FH-10 alone.

Longest chain: FH-1 → FH-5b → FH-6 → FH-7 → FH-9 → FH-10 (6). Chain of 6: the stubs before the bodies, the rules before the commands that call them, the commands before Photo's adapter, and the adapter before the window and the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FH-1 | the four suites compile, disabled by name; `KernelShapeTests` (unchanged) | a signature the adopter calls is missing, or the kernel imports CoreRaster | – (stubs) |
| FH-2 | `scripts/jobs check` | a job names a command the catalog lacks | – (jobs) |
| FH-3 | the palette and options exist with their ids; G selects the bucket; `PJ-FH1` skipped by name | a tool has no key or an option no id | – (view; render budget row) |
| FH-4 | `RenderBudgetRetouchTests.removeStrokeInThreeBodies` | the stroke re-renders the window per sample | – (view; render budget row) |
| FH-5b | `BucketRulesTests`: tolerance 0 fills one colour's region exactly; contiguous off fills every match; nothing outside the selection changes; All Layers samples the merged picture but writes the target layer | a fill leaks or ignores the selection | `SuiteImaging.BucketRules`: selection intersection skipped → `.insideSelectionOnly`; contiguous flag ignored → `.contiguousStopsAtEdges` |
| FH-5h | `HealRulesTests`: a dot on flat sky heals to within 3 levels of the sky; remove of a square on a texture leaves no pixel of the square's colour; the same seed gives the same pixels | heal leaves the spot, or remove isn't repeatable | `SuiteImaging.HealRules`: seed not passed → `.removeIsRepeatable`; source offset sign flipped → `.healCopiesFromSource` |
| FH-5k | `DabCoverageTests`: one dab of size 10, hardness 1 covers a disc of radius 5 exactly; two overlapping dabs keep the max, not the sum; the grid's bounds hold every dab | coverage adds up past 1, or a dab is cut at the bounds | `SuiteKernel.DabCoverage`: max replaced by sum → `.overlapKeepsMax`; bounds not padded by the radius → `.boundsHoldDabs` |
| FH-6 | `RetouchCommandsTests` on a test target: one step each; undo restores the layer byte for byte; `retouch.remove` with no points and no selection is unavailable with the reason; a locked layer refuses | a command is two steps, undo is inexact, or remove runs on nothing | `SuiteImaging.RetouchCommands`: undo snapshot taken after the edit → `.undoRestoresBytes`; selection fallback missing → `.removeUsesSelection` |
| FH-7 | `PhotoRetouchKernelTests`; Photo's existing clone tests unchanged; RJ-P04, RJ-P07, RJ-P51 on Linux | a tool edits another layer, heal still tone-matches per dab, or clone changes | `PhotoModel.PhotoRetouch+Kernel`: target taken from the composite → `.editsSelectedLayer`; coverage of a hidden selection used → `.selectionCoverageOnly` |
| FH-8 | `PJ-FH1`, `PJ-FH2` | a click doesn't fill, or a stroke makes several undo steps | – (window wiring) |
| FH-9 | `scripts/c4-assemble --check` | the part names no adopter | – |
| FH-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Remove stroke, 120 samples on an 8K layer | ≤ 3 window bodies; release to pixels p95 ≤ 300 ms | `RenderBudgetRetouchTests.removeStrokeInThreeBodies` |
| render: palette tool switch | ≤ 2 window bodies | `RenderBudgetRetouchTests.toolSwitch` |
| one gesture, one step | a click or a stroke is one undo step | `RetouchCommandsTests`, `PhotoRetouchKernelTests` |
| no dead controls | every tool and option is a catalog command or a command param | `CommandPathTests` |
| keyboard parity | G, J, Shift-J; Tolerance and Size typed | `PhotoRetouchJourneyTests` |
| kernel stays small | SuiteKernel imports only Foundation and FlareCore | `KernelShapeTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): FH-a, FH-r and FH-c green on Linux with
`Mutate:` scores clean; FH-u and FH-photo through the feel gate (`mouse`,
`taste`, `perf`: a bucket click and a Remove stroke on an 8K photo) with their
`Mac-Finish:` lines; RJ-P04, RJ-P07 (once the lasso exists) and RJ-P51 green
on Linux at FH-photo's merged-done. Then `Belt-Contact-Sheet:`.
