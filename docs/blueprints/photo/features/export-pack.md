# Feature packet: export-pack (Photo)

**Feature:** Photo's File > Export… moves onto SuiteUI's `SuiteExportSheet`
(Photo's own `ExportSheet.swift` is deleted) with the shared Size row (Scale,
Pixels, Long edge) and HEIC and TIFF beside PNG and JPEG. "1080 × 1350" on a
cropped 4:5 image writes exactly that; Pixels at another shape is refused
unless stretched. An agent exports the same way with `export` and the shared
options.
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/export-pack`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 5). Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/export-pack` (adopter of S11); real job
RJ-P01 (crop to 1080 × 1350 and export JPEG). RJ-P30 (WebP) stays on S11:
the pinned macOS can't write WebP. RJ-P11 and RJ-X02 (no metadata) stay on
S11: Photo writes pixels only today, so they hold; a metadata row for Photo
is a later S11 row.

**Depends on:** `suiteui/export-pack` **XP-a** (cross-line); PX-3 needs
**XP-6**, PX-5 **XP-4**. `suiteui/adopt-kernel-export` **AX-photo**
(cross-line: Photo's export state on `ExportRun`, which `SuiteExportSheet`
reads). shell-media **SM-w** (cross-line: HEIC and TIFF through
`services.media.still`, replacing `ImageIOCodec`'s encode half). Same line:
`tone-controls`'s PT-z owns `photo.md`, so PX-8 waits on it.

**Rule 20.** No Photo sheet and no Photo size rule: `SuiteExportSheet` and
`ExportRules.pixels`; `PhotoExport+Kernel.swift` maps Photo's scope (the
flattened image) onto `ExportOptions`. The still bytes come from shell-media.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PX-a | Photo's export reads `ExportOptions` on stubs, and Export… opens `SuiteExportSheet` with the Size row and four formats. | PX-1, PX-2 | MJ-PX | XP-a, AX-photo (cross-line) |
| PX-u | The sheet has snapshots and a render budget, and the journey is written. | PX-5, PX-6 | PJ-X1 | PX-a; XP-4 (PX-5, cross-line) |
| PX-m | Export resamples the flattened image to the exact size and writes PNG, JPEG, HEIC or TIFF through the shared encoder, headless and in the app. | PX-3, PX-4 | MJ-PX | PX-a; XP-6, SM-w (cross-line) |
| PX-z | Export runs on live services, the journey passes, and the blueprint has it in. | PX-7, PX-8 | PJ-X1 | PX-u, PX-m; tone-controls:PT-z (PX-8); place-image:PP-z (PX-8, A/C first) |

PX-u waits only on PX-a (rule 18); PX-m never waits on PX-u. PX-m is marked `"ui": true` because PX-4 changes `ImageIOCodec` in PhotoApp. MJ-PX is the Model walk in `PhotoExportPackTests` (Linux).

## Journey steps

1. Open the 6000 × 4000 sample, crop to 4:5 (existing), File > Export…
   (PX-2, `PhotoExportPackJourneyTests.testExportForInstagram`): the suite's
   sheet with PNG, JPEG, HEIC, TIFF.
2. JPEG, Size > Pixels 1080: height reads 1350; Export: `photo.jpg` is
   1080 × 1350.
3. HEIC at Long edge 2048: the file is 1638 × 2048.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P01 | closes (now `photo/export-pack`) | Cm | `Tests/RealJobs/photo/instagram/instagram.jobs.json`: `image.crop` to 4:5, export JPEG with `{"size":{"pixels":[1080,1350]},"quality":0.85}` | `input/landscape-6000.jpg` (6000 × 4000) |

Trap: the export keeps the crop's 3200 × 4000 pixels, or squashes the
landscape into 4:5. Assertion: the JPEG is exactly 1080 × 1350 and a marker
pixel at the crop's centre lands at the file's centre within 2 px.
Mutations: `PhotoModel.PhotoExport+Kernel.json`, the size ignored →
`.exportsAtSize`; resampled before the crop → `.cropThenSize`.

## Screens and states

`photo-export-sheet` (Pixels, light and dark), `photo-export-heic`.

## Contract slice

```swift
// Sources/PhotoModel/PhotoExport+Kernel.swift (PX-1 stubs, PX-3 bodies)
extension PhotoWorkspace {
    public static let exportFormats: [ExportFormatSpec]   // png, jpeg, heic, tiff from ExportFormats.all
    public func exportOptionsDefault() -> ExportOptions
    public func exportPixels(_ o: ExportOptions) throws -> DecodedImage   // flattened, resampled to ExportRules.pixels
}
```

## Pseudocode

- **exportPixels.** Flatten as today, then `ExportRules.pixels(of: image,
  o.size, evenSize: false)`; resample with CoreRaster's Lanczos when the size
  differs; refusal from `ExportRules.refusal`.
- **headless.** `PhotoHeadless.export(format, options:)` builds
  `ExportOptions(json:defaults:)` and calls the same path.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PX-1 | – | `PhotoExport+Kernel.swift` as stubs; `PhotoExportPackTests` written, disabled | `Sources/PhotoModel/PhotoExport+Kernel.swift`, `Tests/PhotoModelTests/PhotoExportPackTests.swift` | XP-a, AX-photo | ~100, 2 |
| PX-2 | – | Export… opens `SuiteExportSheet` (idPrefix `photo.export`) with the Size row and the four formats; Photo's `ExportSheet.swift` deleted | `Sources/PhotoApp/PhotoWindow+Export.swift`, `Sources/PhotoApp/ExportSheet.swift` | PX-1 | ~160, 2 |
| PX-3 | – | `exportPixels` and the headless export on `ExportOptions`; RJ-P01's job folder; turns on `PhotoExportPackTests` | `Sources/PhotoModel/PhotoExport+Kernel.swift`, `Sources/PhotoModel/PhotoHeadless.swift`, `Tests/PhotoModelTests/PhotoExportPackTests.swift`, `Tests/mutations/PhotoModel.PhotoExport+Kernel.json`, `Tests/RealJobs/photo/instagram/` | PX-1, XP-6 | ~240, 5 |
| PX-4 | – | The app writes HEIC and TIFF (and PNG, JPEG) through `services.media.still`; `ImageIOCodec` keeps only its decode half | `Sources/PhotoApp/ImageIOCodec.swift`, `Tests/AppSnapshotTests/PhotoExportFormatsTests.swift` | PX-1, SM-w | ~140, 2 |
| PX-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoExportPackSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoExportPackTests.swift` | PX-2, XP-4 | ~140, 2 |
| PX-6 | – | The journey written and skipped (`XCTSkip("waits on PX-7")`) | `UITests/PhotoJourneyTests+ExportPack.swift` | PX-2 | ~100, 1 |
| PX-7 | – | Live: the journey turned on, on live services | `UITests/PhotoJourneyTests+ExportPack.swift` | PX-6, PX-3, PX-4 | ~40, 1 |
| PX-8 | – | photo.md: export at a size, HEIC and TIFF; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/export-pack.wave.json` | PX-7, PX-5, tone-controls:PT-z | ~30, 2 |

## Build waves

- Wave 1: PX-1. Independent in this wave: PX-1 alone.
- Wave 2: PX-2, PX-3, PX-4. Independent in this wave: all three.
- Wave 3: PX-5, PX-6. Independent in this wave: both.
- Wave 4: PX-7. Independent in this wave: PX-7 alone.
- Wave 5: PX-8 (`feature-done`, final). Independent in this wave: PX-8 alone.

Longest chain: PX-1 → PX-2 → PX-6 → PX-7 → PX-8 (5). Chain of 5: the sheet needs the options, the journey drives the sheet, PX-7 turns it on live, PX-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PX-1 | compiles; the existing export tests pass; `PhotoExportPackTests` disabled by name | an existing export changes | – (stub) |
| PX-2 | `PhotoExportPackSnapshots.sheet` (PX-5's, first in the slice PR); `check-dup-views` baseline shrinks by Photo's sheet | the app sheet survives | – (UI) |
| PX-3 | `PhotoExportPackTests`: a 4:5 crop at `pixels(1080, 1350)` gives 1080 × 1350; a 3:2 image at the same Pixels is refused; `longEdge(2048)` on 6000 × 4000 gives 2048 × 1365; the headless JSON path equals the sheet path; RJ-P01's plan half passes on Linux | a size or a refusal is wrong | `PhotoModel.PhotoExport+Kernel`: size ignored → `.exportsAtSize`; resample before crop → `.cropThenSize` |
| PX-4 | `PhotoExportFormatsTests` (macOS): HEIC and TIFF files decode at the exported size | a format fails or changes size | – (macOS) |
| PX-5 | `PhotoExportPackSnapshots`; `RenderBudgetPhotoExportPackTests.typingWidthInTwoBodies` | budget over | – (UI) |
| PX-6 | compiles, skipped | – | – |
| PX-7 | `PhotoExportPackJourneyTests.testExportForInstagram` steps 1 to 3; RJ-P01 green on macOS | a step fails | – |
| PX-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: typing a width in the sheet | ≤ 2 window bodies per keystroke | `RenderBudgetPhotoExportPackTests.typingWidthInTwoBodies` |
| Export cost | an 8K image to 1080 × 1350 JPEG in ≤ 1.5 s (reported) | `PhotoExportPackTests.eightKCost` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PX-m merged-done; PX-u's feel gate and `Mac-Finish:`; PX-z's journey on live and RJ-P01 green on macOS. Then `Belt-Contact-Sheet:` with `photo-export-*`.

## Not in this packet

WebP, a metadata row for Photo, export presets, per-layer export.
