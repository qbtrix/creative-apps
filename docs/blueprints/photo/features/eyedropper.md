# Feature packet: eyedropper (Photo)

**Feature:** Photo's Eyedropper tool (I) works: a click on the image sets the
brush colour from the composite at that pixel, averaged over the sample size
(Point, 3 × 3, 5 × 5) chosen in the tool's options; SuiteUI's `SampleLoupe`
follows the pointer with the colour under it. Holding Option with the Brush
picks the same way without switching tools. `color.sample` gives an agent the
same reading. This fills PV-9's stubs (`SampleIntent {}`, `SampleOptions`,
the NotBuilt `LiveSampling`).
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/eyedropper`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/eyedropper` (adopter of S13); real jobs RJ-P22
(pick a colour from the photo for a title) and RJ-P36 (new: sample a 5 × 5
mean by command).

**Depends on:** `suiteui/eyedropper` **EY-a** (cross-line: `SampleSize`,
`SampleTarget`, the spec, `SampleLoupe`, `SampleSizeChips` as stubs); PE-5
needs **EY-m** (the real mean), PE-3 **EY-u** for its snapshots. Same line:
history-panel's **PH-m** before PE-6 (both own `PhotoCommandCatalog.swift` and
`photo.txt`). Built: photo-seams, photo-edit (the brush colour).

**Hand-offs:** `Contracts/OutputContracts.swift` is adopt-kernel-export's
(AX-photo): PE-1's one-line `SampleSize` typealias rebases onto it.

**Rule 20.** `SampleSize` becomes `typealias SampleSize = SuiteKernel.SampleSize`;
`ColorSampling`'s live body is `SampleRules.mean` over a reader on the
composite `PixelBuffer`, so Photo writes no averaging of its own. The adapter
is `PhotoSample+Kernel.swift`.

**Render path.** None: sampling reads the composite the canvas already has
(`flatten` of the visible region, one tile around the point).

Blueprint sections: photo.md 5 (tools), 6 (canvas overlays).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PE-a | The adapter is declared as stubs and the Eyedropper tool is enabled on the palette with its size chips. | PE-1, PE-2 | MJ-PE | suiteui/eyedropper EY-a (cross-line) |
| PE-u | The loupe follows the pointer over the canvas, a click and an Option-click pick, and the snapshots and render budget hold. | PE-3, PE-4 | PJ-E1 | PE-a; EY-u (PE-4, cross-line) |
| PE-m | The live sampler averages the centred square of the composite, a pick sets the brush colour as tool state, and color.sample reads it for an agent. | PE-5, PE-6 | MJ-PE | PE-a; history-panel:PH-m (PE-6); EY-m (cross-line) |
| PE-z | The journey picks the sky's colour on live services, and the feature is built. | PE-7, PE-8 | PJ-E1 | PE-u, PE-m |

PE-u waits only on PE-a (rule 18); PE-m never waits on PE-u. MJ-PE is the
Model walk in `PhotoSampleTests` (Linux).

## Journey steps

1. Open `sunset.jpg`, press I (PE-2, `PhotoEyedropperJourneyTests.testPickSkyColor`):
   the Eyedropper is active; its options show the size chips on Point.
2. Move over the sky: the loupe shows the sky's colour and its hex.
3. Click: the brush colour in the tool options becomes that colour.
4. Pick 5 × 5, click a noisy patch: the brush colour is the patch's mean.
5. Press B, hold Option, click the sun: the brush colour is the sun's; the
   Brush stays active.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P22 | closes (now `photo/eyedropper`) | J | `testPickSkyColor` steps 1 to 3 | `sunset.jpg` |
| RJ-P36 | adds, closes with `photo/eyedropper` | C | `Tests/RealJobs/photo/sample-mean/sample-mean.jobs.json`: `color.sample {"x": 10, "y": 10, "size": 5}` on a checkerboard of red and blue pixels, and at (−5, −5) | `input/checker-red-blue.png` (20 × 20) |

Traps: the sample reads the active layer rather than what is seen, or the
5 × 5 square is anchored at its corner. Assertions: P36, the mean is the
13-red, 12-blue mix of the centred square (within 1 per channel) and the
outside point reads `null`; P22, the brush colour equals the sky pixel's
composite, not the empty top layer's. Mutation:
`PhotoModel.PhotoSample+Kernel.json` (active layer read instead of the
composite → `.samplesComposite`).

## Screens and states

`photo-eyedropper-loupe` (light and dark), `photo-eyedropper-options` (the
size chips), `-outside` (the hollow loupe past the image's edge).

## Contract slice

```swift
// Sources/PhotoModel/PhotoSample+Kernel.swift (PE-1 stubs, PE-6 bodies)
extension PhotoWorkspace: SampleTarget {
    public var sampleHelp: String? { get }                     // "Open an image first."
    public func sampledColor(at point: Point, size: SampleSize) -> FillColor?   // the composite, canvas pixels
    public mutating func pickBrushColor(at point: Point) throws // samples with the tool's size, sets the brush colour
}
```

## Pseudocode

- **sampledColor.** Round to the pixel; flatten the visible stack over the
  square's bounds (one tile, never the whole image); `SampleRules.mean` with a
  reader over that buffer (straight alpha, sRGB).
- **pickBrushColor.** Tool state, not a document edit: no undo step, as
  picking a colour in the brush's colour row is today.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PE-1 | – | The adapter as stubs; `SampleSize` as the kernel's; `PhotoSampleTests` written, disabled | `Sources/PhotoModel/PhotoSample+Kernel.swift`, `Sources/PhotoModel/Contracts/OutputContracts.swift`, `Tests/PhotoModelTests/PhotoSampleTests.swift` | – | ~110, 3 |
| PE-2 | – | The tool on the stubs: `SampleIntent`'s cases and route, the size chips in its options, the tool enabled on the palette; the journey written, skipped | `Sources/PhotoApp/PhotoWindow+Sample.swift`, `Sources/PhotoApp/SampleOptions.swift`, `Sources/PhotoApp/PhotoPaletteTool.swift`, `UITests/PhotoJourneyTests+Eyedropper.swift` | PE-1 | ~180, 4 |
| PE-3 | – | The loupe over the canvas in the sample area, a click picks, Option-click with the Brush picks | `Sources/PhotoApp/PhotoWindow+Sample.swift`, `Sources/PhotoApp/LiveStroke.swift`, `Tests/AppSnapshotTests/PhotoEyedropperOverlayTests.swift` | PE-2 | ~180, 3 |
| PE-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoEyedropperSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoEyedropperTests.swift` | PE-3 | ~180, 2 |
| PE-5 | – | The live `ColorSampling` on `SampleRules.mean`; the NotBuilt stand-in removed | `Sources/PhotoModel/Live/LiveSampling.swift`, `Sources/PhotoModel/Live/NotBuilt.swift`, `Tests/PhotoModelTests/LiveSamplingTests.swift`, `Tests/mutations/PhotoModel.LiveSampling.json` | PE-1 | ~140, 4 |
| PE-6 | – | Adapter bodies (the composite tile, the brush pick); `color.sample` in the catalog and id list; turns on `PhotoSampleTests`; RJ-P36's job folder | `Sources/PhotoModel/PhotoSample+Kernel.swift`, `Tests/PhotoModelTests/PhotoSampleTests.swift`, `Tests/mutations/PhotoModel.PhotoSample+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/RealJobs/photo/sample-mean/sample-mean.jobs.json`, `Tests/RealJobs/photo/sample-mean/input/checker-red-blue.png` | PE-5 | ~240, 7 |
| PE-7 | – | The journey turned on, on live services | `UITests/PhotoJourneyTests+Eyedropper.swift` | PE-4, PE-6 | ~50, 1 |
| PE-8 | – | `status: built`; `feature-done` | `docs/blueprints/photo/features/eyedropper.wave.json` | PE-7 | ~10, 1 |

## Build waves

- Wave 1: PE-1. Independent in this wave: PE-1 alone.
- Wave 2: PE-2, PE-5. Independent in this wave: both.
- Wave 3: PE-3, PE-6. Independent in this wave: both.
- Wave 4: PE-4. Independent in this wave: PE-4 alone.
- Wave 5: PE-7. Independent in this wave: PE-7 alone.
- Wave 6: PE-8 (`feature-done`, final). Independent in this wave: PE-8 alone.

Longest chain: PE-1 → PE-2 → PE-3 → PE-4 → PE-7 → PE-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PE-1 | `PhotoSampleTests` compiles, disabled; every `SampleSize` use still builds | a caller breaks | – (stub) |
| PE-2 | `PhotoInspectorSnapshots`: the Eyedropper's options show the chips on the stubs; I picks the tool and the tool is enabled | the options or the tool are missing | – (UI) |
| PE-3 | `PhotoEyedropperOverlayTests`: the loupe tracks the pointer and shows nil past the edge; a click emits one `.pick(at:)` | a pick is doubled or the loupe stalls | – (UI) |
| PE-4 | `PhotoEyedropperSnapshots`; `RenderBudgetPhotoEyedropperTests.loupeTrackInThreeBodies` | budget over | – (UI) |
| PE-5 | `LiveSamplingTests`: the live `ColorSampling` returns the mean of the centred square; transparent pixels are skipped; nil outside | a mean is wrong | `PhotoModel.LiveSampling`: centre offset dropped → `.squareCentred`; alpha-0 pixel counted → `.skipsTransparent` |
| PE-6 | `PhotoSampleTests`: `sampledColor` reads the composite through an empty top layer; `pickBrushColor` sets the brush and records no step; RJ-P36 passes on Linux | the layer, the step or the mean is wrong | `PhotoModel.PhotoSample+Kernel`: active layer read → `.samplesComposite`; a step recorded → `.pickIsToolState` |
| PE-7 | `testPickSkyColor` steps 1 to 5 on live | a step fails | – |
| PE-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample loupe track over a 12 MP image | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetPhotoEyedropperTests.loupeTrackInThreeBodies` |
| Sample cost | one tile flattened per sample, never the whole image | `PhotoSampleTests.flattensOneTile` |
| No dead controls; keyboard parity | I picks the tool, Option-click with the Brush picks, chips reachable by Tab | `testPickSkyColor` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PE-m merged-done with RJ-P36 green in the
Linux job; PE-u's feel gate and `Mac-Finish:`; PE-z's journey on live and
RJ-P22 green in the scoped run. Then `Belt-Contact-Sheet:` with
`photo-eyedropper-*`.

## Not in this packet

Sampling the current layer only, a colour sampler readout panel, sampling
into the background colour.
