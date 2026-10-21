# Feature packet: suite-imaging

**Feature:** one shared `SuiteImaging` target over creative-core's CoreRaster,
CoreRender and CoreRenderMetal. It holds the adjustment values every image app
edits (levels with output black and white, curves, gamma, hue and saturation),
the one mapping from those values to an ordered list of core `ToneAdjustment`
steps (CPU) and `ToneProgram.Operation`s (GPU), the route choice, and the live
GPU route: a resident picture where a slider step is one display write and
nothing is read back. Photo moves onto it (#3144's `PhotoLiveTone` becomes the
shared route), and Library's Develop moves off CPU CoreRaster onto the same
route, with a slider-to-pixels latency budget test. Only SuiteImaging may link
CoreRenderMetal or import Metal; a test holds that. It also owns the colour
pipeline (`ImagingColor`, beta scope from 2026-10-21): pictures are decoded
into one working space wider than sRGB (extended-range linear sRGB,
Float32, unclamped: a colour outside sRGB lives on as a negative or above-1
component, CoreColor's own convention, so nothing outside sRGB or above 1.0
is cut), every adjustment runs there, and
the display and output transforms run last, built on creative-core's
CoreColor profiles (#441, at the pin).
**Line:** `line:suiteui` · **Wave:** XK3 (`waves.md`, the canonical burn-down) · **Lead branch:** `lead/suite-imaging`
**Beta:** captain, 2026-10-20 (canonical burn-down, audit rank 2 and 3). Labels `beta` and `p1` when filed.

**Covers:** the canonical duplicates audit
(`paw-workspace/docs/design/drafts/2026-10-20-canonical-duplicates-audit.md`),
top-15 #2 and #3; feature map row `suiteui/suite-imaging`; real job RJ-X45
(new).

**Depends on:** suite-harness and editor-kernel (built; `project.yml` and
`Package.swift` history). **Cross-line:** photo #3144 (open, conflicting): IM-8
lifts its `PhotoLiveTone` route into `LiveToneSurface`. If #3144 closes
instead of merging, IM-5 takes the route from its head `f2c420d` and IM-8
still deletes Photo's copy. Its rebase must not move the core pin back: dev is
on `2258b62` (#3549), which already has `ToneProgram`, `ToneAdjustment` and
CoreRaster's `ColorAdjust`. No creative-core issue.

**Hand-offs** (files other packets own; cross-line, so not in `waits`; the
lead checks each before the slice starts):
- **IM-photo:** `AdjustmentSettings.swift` is photo/tone-controls PT-1's and
  `PhotoRender.swift` PT-3's; `PhotoRenderRoute.swift` is
  photo/multi-layer-select PM-g's. IM-7 and IM-8 start after those slices, or
  before them with the owner told. `PhotoLiveTone.swift` has one owner:
  IM-8d deletes it, and photo/tone-controls PT-3 now edits
  `PhotoAdjust+Imaging.swift` instead (re-cut in this PR).
- **IM-library:** `LiveDevelop.swift`, `LiveLoupeImaging.swift` and
  `DevelopValues.swift` are library/spine's (building), and raw RW-3 (`LiveLoupeImaging.swift` only) and
  tone-controls LT-a/LT-m also list them. IM-10 and IM-11 start after spine's
  feature-done. library/tone-controls LT-1 no longer edits `Package.swift` and
  LT-4 no longer adds `LibraryLoupe+Metal.swift`: its loupe step calls IM-11's
  route (re-cut in this PR).
- **tone-controls (suiteui):** its `Tone/` module (`ToneSettings`,
  `ToneRules`, `ToneCommands`) is created in `Sources/SuiteImaging/Tone/`, not
  `Sources/SuiteKernel/Tone/`, so SuiteKernel stays Foundation and FlareCore
  only and `KernelShapeTests` is not relaxed. TC-1 waits on IM-a.

**Rule 20.** One home for "settings to pixels". Photo's `AdjustmentSettings`,
`GammaTrack`, `PhotoLevelsFormat` and `HueSaturation` and Library's
`DevelopLevels`, `ToneCurve`, `DevelopCurvePoint` and `LiveDevelop.passes`
are four mappings of one concept; they become SuiteImaging's
`AdjustSettings` and `ImagingProgram`, each app keeping one adapter
(`PhotoAdjust+Imaging.swift`, `LibraryDevelop+Imaging.swift`). Where the two
apps disagree today the packet picks one rule and keeps both apps' files
opening unchanged (Pseudocode).

**Deleted app-local files:** `Sources/PhotoModel/GammaTrack.swift`,
`Sources/PhotoModel/PhotoLevelsFormat.swift`,
`Sources/PhotoModel/HueSaturation.swift` (IM-12) and
`Sources/PhotoModel/PhotoLiveTone.swift` (IM-8d: #3144 lands it with an
`Allow-Dup:` exception and a baseline line, since #3642's `LiveTone` stem
catches it; IM-8d deletes the file and that line with
`scripts/check-dup-logic --update-baseline` in the same PR). Library's
duplicate types leave `DevelopValues.swift` (IM-13); the file stays as the
catalog record. IM-12 runs `scripts/check-dup-logic --update-baseline` in the
same PR so `Tests/canonical-baseline.txt` shrinks by the deleted files' lines
(the "Tone settings" lines #3642 grandfathers).

**Colour pipeline (beta).** Library's decoder cuts every photo to 8-bit
sRGB today, so a Display P3 phone photo clips before any slider moves and a
RAW file's highlights can't come back. `ImagingColor` (IM-15) fixes the
order: decode from the file's own ICC profile (core `ColorProfile(iccData:)`,
`ProfileTransform`, both unclamped) into the working space; run
`ImagingProgram` there; then one display step (`displaySteps(to:)`, a
`channelMixer` from linear sRGB to a Display P3 screen's linear space, none
for an sRGB screen, appended last by the canvas and loupe routes, IM-8 and
IM-11) or one output transform (`toOutput`, to the file's profile at 8 or 16
bits, the profile embedded by shared-codecs' encoder). shared-codecs'
decoder and shared-raw's RAW decoder hand back working-space buffers; Photo
and Library keep them as float (shared-raw SR-6, library/raw RW-3).

**Why extended linear sRGB and not linear P3.** It is wider than sRGB in the
only sense that matters here (no colour is clipped), and every existing
consumer already assumes linear-sRGB primaries: Photo's export and `.ora`
layers, the pasteboard, the eyedropper and hex, brush and fill colours,
`ThumbnailWriter`, Library's histogram and thumbnails, and core's luma
weights. A P3 working space would need a conversion at each of those
boundaries; this one needs none, and the only new transforms are at the
two ends (the file's profile in, the display or file profile out). Where an
8-bit or sRGB consumer meets an out-of-sRGB value it clamps as it does
today, so the wide values live from decode through develop to export.

**Render path.** A slider step on the GPU route composites nothing and reads
nothing back: the base stays resident and the step's program is folded into
the display encode (the measured #3144 route: 12 to 24 ms p95 at 8K against a
30 ms budget). Export, thumbnails and the histogram run the same list on the
CPU. Library's loupe writes into the shared `CanvasHost` resident texture
(canvas-host's G1 path, which Photo already uses).

**C4:** a new container part `suite-imaging/container.json` and component
parts `imaging-adjust.json` (`Sources/SuiteImaging/Adjust/`) and
`imaging-route.json` (`Sources/SuiteImaging/Route/`), added by IM-1;
tone-controls adds `imaging-tone.json`.

**Clean-room.** Behaviour comes from the two apps' own tests and core's
documented units. No task reads another product's code.

Blueprint sections: suite.md 2 (shared tiers); photo.md 4 (adjustments);
library.md (Develop, Loupe).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| IM-a | The SuiteImaging target links CoreRaster and CoreRender everywhere and CoreRenderMetal on macOS, the dependency rule is a live test with Photo's files baselined, and the adjustment values, program, route and live surface are declared as stubs with their tests written, disabled. | IM-1, IM-2 | MJ-IM | suite-harness, editor-kernel (built, `depends`) |
| IM-m | Adjustment values clamp and round-trip both apps' files, one ordered step list drives the CPU and GPU paths alike, pictures move into a wide working space and out to the display or a file only at the end, and the live surface makes a slider step one display write with no readback. | IM-3, IM-4, IM-5, IM-15 | MJ-IM | IM-a |
| IM-photo | Photo's adjustments are SuiteImaging values behind its existing API, its canvas draws through the shared live route with no Metal import of its own, `PhotoLiveTone.swift` and its baseline line are deleted, and its 8K slider latency stays within 30 ms p95. | IM-6, IM-7, IM-8, IM-8d | MJ-IM-photo, PJ-IM | IM-a (IM-6); IM-m (IM-7, IM-8); adopt-kernel-eyedropper-photo:EP-z (IM-8d only, `canonical-baseline.txt`, A/C first); photo #3144 (IM-8, cross-line); PT-1, PT-3, PM-g hand-offs |
| IM-library | Library's develop values are SuiteImaging values with the catalog's keys unchanged, export and thumbnails run the shared CPU list, and the loupe draws each develop step on the GPU route within 30 ms p95 at 8K. | IM-9, IM-10, IM-11 | MJ-IM-library, LJ-IM | IM-a (IM-9); IM-m (IM-10, IM-11); library spine feature-done (cross-line hand-off) |
| IM-z | Photo's and Library's copies are deleted with the baseline shrunk, the dependency rule runs with no baseline and Photo's own CoreRenderMetal link removed, RJ-X45 passes, and the feature is built. | IM-12, IM-13, IM-14 | MJ-IM, PJ-IM, LJ-IM | IM-photo (also the `canonical-baseline.txt` chain), IM-library; shared-thumbnails:ST-a (IM-13, `Package.swift`, A/C first) |

There is no new screen (`"ui_slice": "none"`): the sliders are the apps' own
(and tone-controls' `ToneRows`). IM-photo and IM-library change `Sources/*App/`
canvas code, so they are `"ui": true` with render budget rows and the feel
gate. IM-m's `LiveToneSurface` builds only on macOS (`#if canImport(Metal)`):
its mutation plan runs on the supervisor's Mac before `Belt-Slice-Done:`, like
SuiteUI files (suiteui waves, Q10).

**Shared-file chains (checker rule, not code):** `Package.swift` and
`project.yml` are owned by IM-a, shared-codecs SC-a, shared-thumbnails ST-a
and IM-z, so SC-a waits on IM-a, ST-a on SC-a and IM-13 on ST-a.
`Tests/canonical-baseline.txt` is owned by one delete task per burn-down
packet, chained adopt-kernel-autosave AK-z → shared-codecs SC-z →
adopt-kernel-unsaved-prompt UP-z → adopt-kernel-eyedropper-photo EP-z →
IM-photo's IM-8d → IM-z's IM-12. IM-8d is a small delete task split out of
the canvas swap so the swap itself (IM-8) waits on no other packet. Only those single tasks wait; every other slice runs free. Each chained
task is a short pure-deletion PR, and line deletions merge cleanly, so the
chain costs minutes per link unless an earlier packet stalls; if one does, the
supervisor may reorder the chain.

## Journey steps

Linux walks, then the apps' journeys on the scoped run after each slice's last PR:
- `MJ-IM`: `SuiteImagingTests` on Linux (`AdjustSettingsTests`,
  `ImagingProgramTests`, `ImagingBoundaryTests`); `LiveToneSurfaceTests` on the
  macOS job.
- `MJ-IM-photo`: `PhotoImagingTests` (IM-6) on Linux, plus Photo's existing
  `PhotoRenderTests` unchanged.
- `MJ-IM-library`: `LibraryImagingTests` (IM-9) on Linux, plus the existing
  `LibraryCatalogTests` unchanged.
- `PJ-IM` (`PhotoJourneyTests.testAdjustmentLayer`, existing PJ-9): an
  adjustment layer added, edited, hidden and reordered; green unchanged after
  IM-8, its `photo-adjlayer-*` shots within 1 level.
- `LJ-IM` (`LibraryDevelopJourneyTests.testDevelopSlidersAndHistogram`,
  existing): the develop sliders move the loupe and the histogram; green
  unchanged after IM-11, now on the GPU route.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X45 | adds, closes with `suiteui/suite-imaging` | C | `Tests/RealJobs/photo/same-edit-two-apps/same-edit-two-apps.jobs.json`: Exposure +1 and Saturation −100 set on `beach.png` by `tone.set` in Photo and in Library (tone-controls' commands), each exported as PNG (`file.export`; Library's from export-pack); the two files compared | `input/beach.png` |

Trap: the same slider gives a different picture in each app (gamma read as its
reciprocal in one, saturation missing in Library, levels units mixed up).
Assertion: the two exports match within 1 level per channel on every pixel,
and both differ from the original by more than 20 levels in mean saturation.
Mutations: `SuiteImaging.ImagingProgram.json` (gamma passed as `1/g` →
`.gammaSameMeaning`; saturation step dropped from the CPU list →
`.cpuListEqualsGpuList`). The check is written by IM-9 and stays disabled (`waits_on: IM-9`); it also needs tone-controls' `tone.set` in both apps (PT-4, LT-5) and Library's `file.export` (library/export-pack), which its `needs` list names.

## Screens and states

None new. Photo's and Library's existing snapshots must not change beyond 1
level per channel: the Mac finisher diffs `photo-adjust-*` and
`library-develop-*` against the previous dev run.

## Contract slice

```swift
// Sources/SuiteImaging/Adjust/AdjustSettings.swift (IM-2 stubs, IM-3 bodies). Linux-safe.
/// Input and output levels on sRGB-encoded values 0...1, gamma 0.1...9.99. Library's 0...255 keys and
/// Photo's percent keys both decode into it; it encodes Library's keys.
public struct AdjustLevels: Hashable, Sendable, Codable {
    public var inputBlack, inputWhite, gamma, outputBlack, outputWhite: Double
    public static let neutral: AdjustLevels
    public init(inputBlack: Double, inputWhite: Double, gamma: Double, outputBlack: Double, outputWhite: Double)
    public func clamped() -> AdjustLevels                       // gap of 1/255 between black and white
}
public struct AdjustCurvePoint: Hashable, Sendable, Codable { public var x, y: Double }
/// A monotone curve over sRGB values, 2 to 16 points, sorted, clamped to 0...1, points closer than
/// `minGap` dropped (Library's rule); Photo's whole-list refusal becomes this repair.
public struct AdjustCurve: Hashable, Sendable, Codable {
    public static let minGap: Double                            // 1/255
    public private(set) var points: [AdjustCurvePoint]
    public init(points: [AdjustCurvePoint])
    public static let identity: AdjustCurve
}
public struct AdjustHueSaturation: Hashable, Sendable, Codable { public var hue, saturation, lightness: Double }
public struct AdjustSettings: Hashable, Sendable, Codable {
    public var exposure: Double                                 // -5...5 stops
    public var levels: AdjustLevels, curve: AdjustCurve, hueSaturation: AdjustHueSaturation
    public static let neutral: AdjustSettings
    public var isNeutral: Bool { get }
}
// Sources/SuiteImaging/Adjust/ImagingProgram.swift (IM-2 stubs, IM-4 bodies). Linux-safe.
public enum ImagingProgram {
    /// The ordered steps: `tone` first (tone-controls' `ToneRules` steps), then exposure, levels, curve,
    /// hue/saturation.
    public static func adjustments(_ s: AdjustSettings, tone: [ToneAdjustment] = []) -> [ToneAdjustment]
    public static func program(_ s: AdjustSettings, tone: [ToneProgram.Operation] = []) -> [ToneProgram.Operation]
}
// Sources/SuiteImaging/Route/ImagingRoute.swift (IM-2 stub, IM-4 body). Linux-safe.
public enum ImagingRoute: Hashable, Sendable {
    case cpu, gpu
    /// GPU unless the View > Rendering choice says CPU or a step's family is `notOnMetalYet`.
    public static func choose(preferGPU: Bool, steps: [ToneAdjustment]) -> ImagingRoute
}
// Sources/SuiteImaging/Route/LiveToneSurface.swift (IM-2 stub, IM-5 body). macOS, #if canImport(Metal).
/// One resident picture on the GPU. A step folds `program` into the display write: no composite, no readback.
public final class LiveToneSurface {
    public struct UnsharpParameters: Hashable, Sendable { public var amount, sigma, threshold: Double }
    public init(device: MTLDevice, base: TiledPixels) throws
    public func replaceBase(_ base: TiledPixels, damaged: [TileRect])   // a pixel edit; tone steps never call it
    /// `unsharp` (tone-controls' `ToneRules.unsharp`) runs once over the base and is cached until the base or
    /// its parameters change, so a tone step stays one write.
    public func draw(_ program: [ToneProgram.Operation], unsharp: UnsharpParameters?, into target: MTLTexture,
                     region: TileRect) throws
}
```

The dependency rule (IM-1, `Tests/SuiteImagingTests/ImagingBoundaryTests.swift`):

| rule | allowed | baseline until IM-13 |
|---|---|---|
| `Package.swift` names `CoreRenderMetal` | SuiteImaging's macOS deps, the `AppSnapshotTests` test target | `appEngines["Photo"]` |
| a file under `Sources/` imports `Metal`, `MetalKit`, `MetalPerformanceShaders` or `CoreRenderMetal` | `Sources/SuiteImaging/`; SuiteUI's canvas host, by name: `CanvasHostView+Metal.swift`, `CanvasTilePresenter.swift` | `Sources/PhotoApp/CanvasRenderer.swift`, `PhotoRendering.swift`, `TileCanvas.swift` (`Tests/metal-boundary-baseline.txt`, shrink-only) |

SuiteUI's canvas host is the one presenter every canvas app shares
(canvas-host, built); it presents textures and runs no imaging, so it stays
allowed by name. The audit's grep counted CoreRender imports too; CoreRender
itself stays allowed in Models (Photo's `PhotoRenderRoute` uses its CPU
dispatcher).

## Pseudocode

- **Where the apps disagree, the shared rule:** gamma 0.1...9.99 as Double
  (Photo's 10 clamps to 9.99, invisible); levels on 0...1 sRGB with a 1/255
  gap, decoded from Photo's percent (÷100) and Library's 0...255 (÷255)
  keys; output black and white for both (Photo gains them, neutral in old
  files); an invalid curve list is repaired (sorted, clamped, near points
  dropped), never refused; saturation for both (Library's
  `LiveDevelop.waiting` loses its "Saturation waits on creative-core" line,
  since core's `ColorAdjust` runs it).
- **Order:** tone (the tone module's own steps, as photo/tone-controls
  already plans) → exposure → levels → curve → hue/saturation. The CPU list and the GPU program come from one private
  step list, so they can't drift; `ImagingProgramTests.cpuEqualsGpu` renders
  both on a fixture.
- **Route:** `choose` returns `.cpu` when `preferGPU` is false or any step's
  `family` is in `RenderOp.notOnMetalYet`; otherwise `.gpu`. Blur and masked
  adjustment layers stay on Photo's existing CPU path (unchanged by this
  packet).
- **Live surface:** from #3144's `PhotoLiveTone`: per band, the composite of
  the pixel layers stays resident while unchanged; `draw` encodes the program
  into the display pass; `replaceBase` re-uploads only damaged tiles.
- **Adapters:** `PhotoAdjust+Imaging.swift` maps Photo's `AdjustmentSettings`
  fields onto `AdjustSettings` both ways and keeps Photo's API;
  `LibraryDevelop+Imaging.swift` does the same for `DevelopSettings` with the
  catalog's JSON keys unchanged, so every catalog and every `.ora` opens as
  before (the IM-6 and IM-9 fixtures prove it byte for byte).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| IM-1 | – | **The rule first, and the target.** `ImagingBoundaryTests` (live, Photo's three files and `appEngines["Photo"]` in the shrink-only baseline); the `SuiteImaging` and `SuiteImagingTests` targets in `Package.swift` and `project.yml` (SuiteKernel, SuiteModel for shared-codecs' format registry, which shared-raw's `RawFormat` reads, CoreRaster, CoreRender, CoreColor for `ImagingColor`; CoreRenderMetal inside `#if os(macOS)`); PhotoModel, LibraryModel, DesignModel, HaloModel, SuiteUI and AfterGlowCLICore link it (Design and Halo for layer-styles' model); the C4 container and parts. A supervisor merge (`Package.swift`) | `Package.swift`, `project.yml`, `Sources/SuiteImaging/SuiteImaging.swift`, `Tests/SuiteImagingTests/ImagingBoundaryTests.swift`, `Tests/metal-boundary-baseline.txt`, `docs/c4/parts/creative-apps/suite-imaging/container.json`, `docs/c4/parts/creative-apps/suite-imaging/imaging-adjust.json`, `docs/c4/parts/creative-apps/suite-imaging/imaging-route.json` | – | ~300, 8 |
| IM-2 | – | The contract as stubs: `AdjustSettings` and its parts, `ImagingProgram`, `ImagingRoute`, `LiveToneSurface` (macOS) returning neutral or throwing `notBuilt`; `AdjustSettingsTests` and `ImagingProgramTests` written, disabled by name (`waits on IM-3`, `waits on IM-4`) | `Sources/SuiteImaging/Adjust/AdjustSettings.swift`, `Sources/SuiteImaging/Adjust/ImagingProgram.swift`, `Sources/SuiteImaging/Route/ImagingRoute.swift`, `Sources/SuiteImaging/Route/LiveToneSurface.swift`, `Tests/SuiteImagingTests/AdjustSettingsTests.swift`, `Tests/SuiteImagingTests/ImagingProgramTests.swift` | IM-1 | ~350, 6 |
| IM-3 | – | `AdjustSettings` bodies: clamping, the curve repair, decoding Photo's and Library's keys, encoding Library's; turns on `AdjustSettingsTests` | `Sources/SuiteImaging/Adjust/AdjustSettings.swift`, `Tests/SuiteImagingTests/AdjustSettingsTests.swift`, `Tests/mutations/SuiteImaging.AdjustSettings.json` | IM-2 | ~280, 3 |
| IM-4 | – | `ImagingProgram` and `ImagingRoute` bodies: one private step list gives both `adjustments` and `program`; `choose`; turns on `ImagingProgramTests` | `Sources/SuiteImaging/Adjust/ImagingProgram.swift`, `Sources/SuiteImaging/Route/ImagingRoute.swift`, `Tests/SuiteImagingTests/ImagingProgramTests.swift`, `Tests/mutations/SuiteImaging.ImagingProgram.json` | IM-2 | ~300, 4 |
| IM-5 | – | `LiveToneSurface` body, lifted from #3144's `PhotoLiveTone`: resident base per band, `draw` folds the program into the display encode and caches the unsharp pass over the base, `replaceBase` re-uploads damaged tiles only; macOS tests | `Sources/SuiteImaging/Route/LiveToneSurface.swift`, `Tests/SuiteImagingTests/LiveToneSurfaceTests.swift`, `Tests/mutations/SuiteImaging.LiveToneSurface.json` | IM-4 | ~350, 3 |
| IM-15 | – | **The colour pipeline, test first.** `WideGamutTests` (Linux), then `ImagingColor`: `workingProfile` (core's `ColorProfile.linearSRGB`, read unclamped), `toWorking(_:from:)` (a buffer in a file's profile into the working space), `displaySteps(to:)` (none for sRGB, the linear-sRGB-to-P3 `channelMixer` for a P3 screen, CPU and GPU forms), `toOutput(_:profile:bitDepth:)`; the C4 part names it | `Sources/SuiteImaging/Color/ImagingColor.swift`, `Tests/SuiteImagingTests/WideGamutTests.swift`, `Tests/mutations/SuiteImaging.ImagingColor.json`, `docs/c4/parts/creative-apps/suite-imaging/imaging-adjust.json` | IM-2 | ~320, 4 |
| IM-6 | – | **Photo, test first.** `PhotoImagingTests`, disabled (`waits on IM-7`): every `.ora` fixture opens with the same adjustment values and re-saves byte for byte; Photo's settings give `ImagingProgram`'s list; old files gain neutral output levels | `Tests/PhotoModelTests/PhotoImagingTests.swift`, `Tests/PhotoModelTests/Fixtures/adjust-legacy.ora` | IM-2 | ~200, 2 |
| IM-7 | – | **Photo adapter.** `PhotoAdjust+Imaging.swift`; `AdjustmentSettings` stores `AdjustSettings` behind Photo's existing API; `PhotoRender.applied(to:)` runs `ImagingProgram.adjustments`; turns on `PhotoImagingTests` | `Sources/PhotoModel/PhotoAdjust+Imaging.swift`, `Sources/PhotoModel/AdjustmentSettings.swift`, `Sources/PhotoModel/PhotoRender.swift`, `Tests/PhotoModelTests/PhotoImagingTests.swift`, `Tests/mutations/PhotoModel.PhotoAdjust+Imaging.json` | IM-6, IM-3, IM-4 | ~350, 5 |
| IM-8 | – | **Photo canvas on the shared route.** `CanvasRenderer`, `PhotoRendering` and `TileCanvas` draw through `ImagingRoute` and `LiveToneSurface`, with `ImagingColor.displaySteps` last, and import no Metal or CoreRenderMetal; `PhotoLiveTone.swift` is no longer called and `PhotoRenderRoute`'s settings mapping is deleted; the three files leave `Tests/metal-boundary-baseline.txt`; `PhotoAdjustSliderLatencyTests` (#3144's) stays within budget | `Sources/PhotoApp/CanvasRenderer.swift`, `Sources/PhotoApp/PhotoRendering.swift`, `Sources/PhotoApp/TileCanvas.swift`, `Sources/PhotoModel/PhotoRenderRoute.swift`, `Tests/metal-boundary-baseline.txt` | IM-7, IM-5, #3144 | ~350, 6 |
| IM-8d | – | **Delete #3144's route.** Removes `PhotoLiveTone.swift` and its plan (entries moved to IM-5's `SuiteImaging.LiveToneSurface.json` or dropped); `scripts/check-dup-logic --update-baseline` drops its `Tests/canonical-baseline.txt` line (the one #3144's `Allow-Dup:` added) | `Sources/PhotoModel/PhotoLiveTone.swift`, `Tests/mutations/PhotoModel.PhotoLiveTone.json`, `Tests/PhotoModelTests/PhotoLiveToneTests.swift`, `Tests/canonical-baseline.txt` | IM-8 | ~120, 4 |
| IM-9 | – | **Library, test first.** `LibraryImagingTests` (every catalog fixture decodes to the same develop values and re-encodes byte for byte; `LiveDevelop`'s passes equal `ImagingProgram.adjustments`; Saturation renders) and `LibraryDevelopLatencyTests` (one develop step to loupe pixels at 8K, release, p95 ≤ 30 ms, target 16; perf list line), both disabled; RJ-X45's job folder (disabled until its commands exist) | `Tests/LibraryModelTests/LibraryImagingTests.swift`, `Tests/AppSnapshotTests/LibraryDevelopLatencyTests.swift`, `Tests/RealJobs/photo/same-edit-two-apps/same-edit-two-apps.jobs.json`, `Tests/RealJobs/photo/same-edit-two-apps/input/beach.png` | IM-2 | ~250, 4 |
| IM-10 | – | **Library adapter.** `LibraryDevelop+Imaging.swift`; `DevelopValues`' levels, curve and point types become typealiases of SuiteImaging's with the same keys; `LiveDevelop` runs `ImagingProgram.adjustments` for export, thumbnails and the histogram, and its Saturation waiting line goes; turns on `LibraryImagingTests` | `Sources/LibraryModel/LibraryDevelop+Imaging.swift`, `Sources/LibraryModel/Contracts/DevelopValues.swift`, `Sources/LibraryModel/Live/LiveDevelop.swift`, `Tests/LibraryModelTests/LibraryImagingTests.swift`, `Tests/mutations/LibraryModel.LibraryDevelop+Imaging.json`, `Tests/mutations/LibraryModel.LiveDevelop.json` | IM-9, IM-3, IM-4 | ~320, 6 |
| IM-11 | – | **Library loupe on the GPU route.** The loupe keeps the photo resident in a `LiveToneSurface` and writes each develop step, with `ImagingColor.displaySteps` last, into the shared `CanvasHost` resident texture; `LiveLoupeImaging` keeps decode and the histogram; the CPU route stays for the View > Rendering CPU choice; turns on `LibraryDevelopLatencyTests` | `Sources/LibraryApp/LibraryLoupe.swift`, `Sources/LibraryApp/LibraryWindow+Loupe.swift`, `Sources/LibraryModel/Live/LiveLoupeImaging.swift`, `Tests/AppSnapshotTests/LibraryDevelopLatencyTests.swift`, `Tests/mutations/LibraryModel.LiveLoupeImaging.json` | IM-10, IM-5 | ~350, 5 |
| IM-12 | – | **Photo delete.** Removes `GammaTrack.swift`, `PhotoLevelsFormat.swift` and `HueSaturation.swift` (core's `ColorAdjust` runs hue/saturation); repoints every plan `find` into them; `scripts/check-dup-logic --update-baseline` drops their lines | `Sources/PhotoModel/GammaTrack.swift`, `Sources/PhotoModel/PhotoLevelsFormat.swift`, `Sources/PhotoModel/HueSaturation.swift`, `Tests/canonical-baseline.txt`, `Tests/mutations/PhotoModel.PhotoAdjust+Imaging.json` | IM-8d | ~250, 6 |
| IM-13 | – | **Library delete and the strict rule.** Library's duplicate level, curve and histogram-normalising code leaves `DevelopValues.swift` and `LiveDevelop.swift`; `appEngines["Photo"]` goes from `Package.swift`; `Tests/metal-boundary-baseline.txt` is deleted and `ImagingBoundaryTests` runs with no baseline | `Sources/LibraryModel/Contracts/DevelopValues.swift`, `Sources/LibraryModel/Live/LiveDevelop.swift`, `Package.swift`, `Tests/metal-boundary-baseline.txt`, `Tests/SuiteImagingTests/ImagingBoundaryTests.swift`, `Tests/mutations/LibraryModel.DevelopValues.json` | IM-11, IM-8 | ~200, 6 |
| IM-14 | – | The C4 parts name the route and both adopters; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-imaging/imaging-route.json`, `docs/blueprints/suiteui/features/suite-imaging.wave.json` | IM-12, IM-13 | ~30, 2 |

IM-1 and IM-13 edit `Package.swift`, so both are supervisor merges, off the
fast lane. The latency tests are report-only on the perf list (like
#3144's): the budget fails a release run on the Mac finisher, not the Linux
job.

## Build waves

- Wave 1: IM-1. Independent in this wave: IM-1 alone.
- Wave 2: IM-2. Independent in this wave: IM-2 alone.
- Wave 3: IM-3, IM-4, IM-6, IM-9, IM-15. Independent in this wave: all.
- Wave 4: IM-5, IM-7, IM-10. Independent in this wave: all.
- Wave 5: IM-8, IM-11. Independent in this wave: both.
- Wave 6: IM-8d, IM-13. Independent in this wave: both.
- Wave 7: IM-12. Independent in this wave: IM-12 alone.
- Wave 8: IM-14. Independent in this wave: IM-14 alone.

Longest chain: IM-1 → IM-2 → IM-6 → IM-7 → IM-8 → IM-8d → IM-12 → IM-14 (8). Chain of 8: the target before the stubs, the stubs before Photo's test, the test before the adapter, the adapter and the live surface before the canvas swap, the swap before #3144's route file can go, that delete before Photo's other copies go (both edit the baseline), and the status task last.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| IM-1 | `ImagingBoundaryTests`: a fixture tree with `import Metal` in `Sources/DesignApp/X.swift` fails, one in `Sources/SuiteImaging/` passes; the real tree passes with the baseline; `swift build` on Linux builds SuiteImaging without CoreRenderMetal | a new Metal import or CoreRenderMetal link outside SuiteImaging passes, or SuiteImaging fails to build on Linux | `SuiteImaging.ImagingBoundary` (in the test's own plan): the allowlist matched as a prefix (`Sources/SuiteImagingX/` passes) → `.exactFolder`; the baseline read as allow-all → `.baselineOnlyListed` |
| IM-2 | the two suites compile, disabled by name; `ImagingBoundaryTests` still passes | a signature the adapters call is missing | – (stubs) |
| IM-3 | `AdjustSettingsTests`: gamma 10 clamps to 9.99; Photo's `{"black": 10}` percent and Library's `{"black": 25.5}` both read 0.1; a 17-point curve keeps 16; points 1/512 apart merge; NaN refused; neutral encodes to `{}` | a unit is mixed up, a bad curve is refused instead of repaired, or a value escapes its range | `SuiteImaging.AdjustSettings`: percent divided by 255 → `.photoPercentKeys`; `minGap` compared with `<=` for `<` → `.nearPointsMerge`; gamma clamp to 10 → `.gammaCeiling` |
| IM-4 | `ImagingProgramTests`: neutral gives `[]`; the order is tone, exposure, levels, curve, hue/saturation; `cpuEqualsGpu` (the CPU backend on both lists, within 1 level); a `.color` step on Metal-not-yet chooses `.cpu` | the two lists differ, the order changes, or an unsupported step goes to the GPU | `SuiteImaging.ImagingProgram`: gamma as `1/g` → `.gammaSameMeaning`; saturation dropped from the CPU list → `.cpuListEqualsGpuList`; curve before levels → `.order` |
| IM-5 | `LiveToneSurfaceTests` (macOS): a step encodes one pass and reads back zero bytes (`stepIsOneWrite`); the drawn picture equals `ImagingProgram.adjustments` on the CPU within 2 levels; a damaged tile re-uploads that tile only | a step reads back or recomposites, or the GPU picture drifts from the CPU one | `SuiteImaging.LiveToneSurface`: base re-uploaded on every draw → `.stepIsOneWrite`; program applied before the base blend → `.matchesCpu`; sharpen cache kept after a base change → `.sharpenFollowsBase` |
| IM-15 | `WideGamutTests`: Display P3 red (1, 0, 0) enters the working space as about (1.22, −0.04, −0.02) (outside sRGB, unclamped), survives Exposure +0.5 and back, and leaves `toOutput(profile: .displayP3, bitDepth: 16)` within 1/1000 of P3 red; a highlight at 1.8 stays 1.8 until `toOutput`; `displaySteps(to: .displayP3)` on the CPU equals core's `ProfileTransform` within 1/1000 and `displaySteps(to: .sRGB)` is empty; an sRGB file round-trips through `toWorking` and `toOutput(.sRGB)` within 1 level | a value outside sRGB or above 1.0 is clipped before output, or the display step drifts from core's transform | `SuiteImaging.ImagingColor`: clamp to 0...1 in `toWorking` → `.keepsWideValues`; display matrix transposed → `.displayMatchesCore`; 16-bit output rounded to 8 → `.sixteenBits` |
| IM-6 | compiles, disabled by name | – | – (test only) |
| IM-7 | `PhotoImagingTests` and Photo's existing Model tests unchanged; `scripts/mutate --plan PhotoModel.PhotoAdjust+Imaging` | an old document opens with different values, or an existing test needs editing | `PhotoModel.PhotoAdjust+Imaging`: output white not carried → `.outputLevelsRoundTrip`; hue and saturation swapped → `.hueSatFields` |
| IM-8 | `ImagingBoundaryTests` with the shorter baseline; `PhotoAdjustSliderLatencyTests` release: adjustment step p95 ≤ 30 ms at 8K (target 16), Move ≤ 80 ms; `PJ-IM` | a Photo file still imports Metal, or a step goes over budget or reads back | – (route code moved; IM-5's plan covers it) |
| IM-8d | Photo's Model tests; `scripts/check-dup-logic` (no `PhotoLiveTone.swift` line, nothing new); `scripts/mutate --validate` | the file or its baseline line survives, or a plan's `find` no longer occurs once | – (deletion) |
| IM-9 | compiles, disabled by name; the job validates (`scripts/jobs check`) | – | – (tests only) |
| IM-10 | `LibraryImagingTests` and Library's existing Model tests unchanged; `scripts/mutate --plan LibraryModel.LibraryDevelop+Imaging` | a catalog's keys change, or export differs from the shared list | `LibraryModel.LibraryDevelop+Imaging`: 0...255 keys written as 0...1 → `.catalogKeysUnchanged`; curve points not mapped → `.curveRoundTrip` |
| IM-11 | `LibraryDevelopLatencyTests` release: step p95 ≤ 30 ms at 8K; `LJ-IM`; Library's develop snapshots within 1 level | the loupe still develops on the CPU per step, or a step goes over budget | `LibraryModel.LiveLoupeImaging`: the histogram read from the GPU picture instead of the decoded base → `.histogramFromBase`; the route ignores the CPU choice → `.honoursRenderingChoice` |
| IM-12 | Photo's Model tests; `scripts/check-dup-logic` (the baseline shrank, nothing new); `scripts/mutate --validate` | a deleted symbol is still referenced, a baseline line is left for a gone file, or a plan's `find` no longer occurs once | – (deletion) |
| IM-13 | `ImagingBoundaryTests` (no baseline); Library's Model tests; `swift build` on both platforms | any file outside SuiteImaging and the canvas host imports Metal, or any target but SuiteImaging links CoreRenderMetal | – (deletion and rule) |
| IM-14 | `scripts/waves render --dry-run`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Photo adjustment slider step at 8K | p95 ≤ 30 ms (target 16), no readback; Move ≤ 80 ms | `PhotoAdjustSliderLatencyTests` (#3144's, perf list) |
| render: Library develop slider step at 8K | p95 ≤ 30 ms (target 16), one display write | `LibraryDevelopLatencyTests` (perf list) |
| render: 120-sample Exposure drag in the Library loupe | ≤ 3 window bodies | `RenderBudgetLibraryDevelopTests.exposureDragInThreeBodies` (Library's existing budget test, unchanged) |
| one gesture, one step | a slider drag is one undo step in both apps | Photo's and Library's existing undo tests, unchanged |
| dependency rule | no Metal import or CoreRenderMetal link outside SuiteImaging and the named canvas host files | `ImagingBoundaryTests` |
| kernel stays small | SuiteKernel imports only Foundation and FlareCore | `KernelShapeTests` (unchanged) |
| behaviour preserved | every `.ora` and catalog fixture round-trips byte for byte | `PhotoImagingTests`, `LibraryImagingTests` |
| wide gamut and high bit depth (beta) | a Display P3 value outside sRGB and a value above 1.0 survive decode, develop and a 16-bit TIFF export | `WideGamutTests`; shared-raw's `WideGamutRoundTripTests` (macOS) |

## Done check

Per slice (rules 6, 15, 17, 21): IM-a and IM-m green on the Linux job with
`Mutate:` scores clean (IM-5's on the supervisor's Mac); IM-photo done only when `Sources/PhotoModel/PhotoLiveTone.swift` is gone and
`Tests/canonical-baseline.txt` has no line for it (IM-8d's PR); IM-photo and
IM-library through the feel gate (`mouse`, `taste`, `perf` lenses: drag a
slider on an 8K photo) with their `Mac-Finish:` lines and the latency tests
under budget in release; IM-z with `ImagingBoundaryTests` passing with no baseline, and RJ-X45
green on Linux once tone-controls' and export-pack's commands it needs have
merged (rule 21 names the level). Then `Belt-Contact-Sheet:`
with the Photo and Library develop snapshots.
