# Feature packet: tone-controls (Photo)

**Feature:** Photo's Adjust panel gets the suite's tone rows: White Balance
(temperature, tint), Tone (Contrast, Highlights, Shadows, Whites, Blacks,
Auto), Presence (Vibrance, Saturation) and Sharpen (amount, radius,
threshold), on the image and on a selected adjustment layer. Every slider
step renders through the shared live GPU route (suite-imaging's
`LiveToneSurface`, which took over #3144's) as part of the one tone program
the display write runs; Sharpen is one GPU unsharp pass on the resident base.
An agent runs the same thing as the `tone.*` commands.
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/tone-controls`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 2). Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/tone-controls` (adopter of S1); real jobs
RJ-P12 (white balance), RJ-P13 (shadows/highlights and contrast), RJ-P14
(sharpen for web).

**Depends on:** `suiteui/tone-controls` **TC-a** (cross-line: `ToneSettings`,
`ToneRules`, `ToneTarget`, the `ToneRows` stub); PT-3 needs **TC-5** (the real
rules), PT-4 **TC-6** (the real commands), PT-5 **TC-3** (the real view).
suiteui **suite-imaging** IM-photo (cross-line): Photo's adjustments and
canvas on SuiteImaging. PT-3 edits its adapter `PhotoAdjust+Imaging.swift`
and starts once IM-photo is done (re-cut 2026-10-20: #3144's
`PhotoLiveTone.swift` is deleted by IM-8d, its route now `LiveToneSurface`). Same line:
`gradient-fill`'s PG-m owns `PhotoCommandCatalog.swift` and
`Tests/command-ids/photo.txt`, so PT-4 waits on it.

**Rule 20.** No Photo tone type: `AdjustmentSettings` holds the kernel's
`ToneSettings` as its `tone` section, and `PhotoTone+Kernel.swift` is the
adapter. Photo's own Exposure section stays (stops, already live), so the
rows hide the kernel's Exposure (`hidden: [.exposure]`) and the image never
has two exposure values.

**Render path.** No new route. `AdjustmentSettings.toneOperations`
(`PhotoAdjust+Imaging.swift`, through `ImagingProgram.program(_:tone:)`) puts
`ToneRules.program(tone)` first, then Photo's
exposure, levels, curves and hue/saturation, so a tone slider step is the
same one display write #3144 measured. Sharpen is one
`unsharpMask` GPU pass over the cached base composite, before that write;
the CPU path (`PhotoRender`'s `applied(to:)`) runs `ToneRules.unsharp` then
`ToneRules.adjustments` in the same order, so export matches the canvas. An
adjustment layer takes tone (its program step) but not Sharpen (it reads
neighbours; the row is off on a layer with help "Sharpen is for the image.").

Blueprint sections: photo.md 6 (Adjust), 8.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PT-a | `AdjustmentSettings` holds a `tone` section, the adapter conforms on stubs, and the Adjust panel shows the tone rows on them. | PT-1, PT-2 | MJ-PT | suiteui/tone-controls TC-a (cross-line) |
| PT-u | The rows have snapshots and a render budget, and the journey is written. | PT-5, PT-6 | PJ-T1 | PT-a; TC-3 (PT-5, cross-line) |
| PT-m | Each tone step renders in the live display write and the same on export, Sharpen is one GPU pass, and every tone command is one undo step on the image or the selected adjustment layer. | PT-3, PT-4 | MJ-PT | PT-a; suite-imaging:IM-photo (PT-3, cross-line); TC-5, TC-6 (cross-line); gradient-fill:PG-m (PT-4); transform:PT-m (PT-4, A/C first); history-panel:PH-m (PT-4, A/C first); eyedropper:PE-m (PT-4, A/C first); place-image:PP-m (PT-4, A/C first) |
| PT-z | The rows run on live services, the journey passes on live, and the blueprint has them in. | PT-7, PT-8 | PJ-T1 | PT-u, PT-m; gradient-fill:PG-z (PT-8, photo.md); place-image:PP-z (PT-8, A/C first) |

PT-u waits only on PT-a (rule 18); PT-m never waits on PT-u. MJ-PT is the
Model walk in `PhotoToneTests` (Linux).

## Journey steps

1. Open the tungsten sample, the Adjust panel (PT-2,
   `PhotoToneJourneyTests.testWarmShadowsAndSharpen`): WHITE BALANCE, TONE,
   PRESENCE and SHARPEN under Exposure; no second Exposure row.
2. Drag Temperature to −25: the canvas cools while dragging; Undo once puts
   it back.
3. Set Shadows +40 and Highlights −30, click Auto: one "Auto Tone" step.
4. Add a Levels adjustment layer, select it, set Contrast +20: only the
   layer's tone changes; Sharpen is off with its help.
5. Select the image again, Sharpen Amount 80: the canvas sharpens; export
   PNG and the file matches the canvas.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P12 | closes (now `photo/tone-controls`) | C | `Tests/RealJobs/photo/white-balance/white-balance.jobs.json`: `tone.set` temperature −30 and tint 5, export PNG | `input/tungsten-grey.png` (a grey card under 3200 K) |
| RJ-P13 | closes (now `photo/tone-controls`) | C | `Tests/RealJobs/photo/backlit/backlit.jobs.json`: `tone.set` shadows 50, highlights −40, contrast 15, on an adjustment layer, export PNG | `input/backlit.png` |
| RJ-P14 | closes (now `photo/tone-controls`) | C | `Tests/RealJobs/photo/sharpen-web/sharpen-web.jobs.json`: `image.resize` to 1200 px, `tone.set` sharpenAmount 80, radius 0.8, export JPEG | `input/soft-edge.png` |

Traps: white balance works only on the whole image, not on an adjustment
layer (RJ-P12's); the export differs from the canvas because the CPU path
runs a different order; Sharpen also sharpens the flat sky (no threshold).
Assertions: the grey card's mean reads neutral (|R−B| ≤ 3/255) in the
export; RJ-P13 runs on an adjustment layer and the pixel layer under it is
unchanged; the exported edge contrast rises by at least 20% while a flat
patch's variance stays within 1/255. Mutations:
`PhotoModel.PhotoAdjust+Imaging.json`, tone appended after hue/saturation →
`.toneFirst`; `PhotoModel.PhotoRender.json`, unsharp after tone →
`.exportMatchesCanvas`; `PhotoModel.PhotoTone+Kernel.json`, a layer's tone
written to the image → `.layerTone`.

## Screens and states

`photo-adjust-tone` (light and dark), `photo-adjust-tone-layer` (an
adjustment layer selected, Sharpen off), `photo-tone-warm` (the canvas after
step 2).

## Contract slice

```swift
// Sources/PhotoModel/AdjustmentSettings.swift (PT-1)
public enum AdjustmentEdit { ...; case tone(ToneSettings) }   // one edit, one History step
public struct AdjustmentSettings { ...; public private(set) var tone: ToneSettings = .neutral }  // key "tone", omitted when neutral
// Sources/PhotoModel/PhotoTone+Kernel.swift (PT-1 stubs returning the fake's value, PT-4 bodies)
extension PhotoWorkspace: ToneTarget {
    public var toneSettings: ToneSettings? { get }   // the selected adjustment layer's, else the image's; nil with no image
    public var toneHelp: String? { get }
    public mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws
    public func autoToneSuggestion() throws -> AutoTone   // from the shown composite's histogram
}
```

## Pseudocode

- **toneOperations.** `ToneRules.program(tone)` + the existing exposure,
  levels, curves and hue/saturation operations; nil (dispatcher route) only
  in the existing cases.
- **sharpen.** With `ToneRules.unsharp(tone)` non-nil, the live stack runs
  one `unsharpMask` over the cached base before the display write, and caches
  that result per region until the base or the sharpen values change.
- **setTone.** Routes to the selected adjustment layer's settings when one is
  selected, else to the image's, as one `AdjustmentEdit.tone` through the
  workspace's History; a drag token folds.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PT-1 | – | `AdjustmentSettings.tone` and `AdjustmentEdit.tone`; the adapter as stubs; `PhotoToneTests` written, disabled | `Sources/PhotoModel/AdjustmentSettings.swift`, `Sources/PhotoModel/PhotoTone+Kernel.swift`, `Tests/PhotoModelTests/PhotoToneTests.swift` | TC-a | ~160, 3 |
| PT-2 | – | The Adjust panel shows `ToneRows` (Exposure hidden) under Exposure, intents to the workspace's catalog | `Sources/PhotoApp/AdjustmentsInspector.swift` | PT-1 | ~80, 1 |
| PT-3 | – | The live route and the export path: tone first in `toneOperations`, the unsharp pass on the base, `applied(to:)` in the same order; turns on `PhotoToneTests` | `Sources/PhotoModel/PhotoAdjust+Imaging.swift`, `Sources/PhotoModel/PhotoRender.swift`, `Tests/PhotoModelTests/PhotoToneTests.swift`, `Tests/mutations/PhotoModel.PhotoAdjust+Imaging.json`, `Tests/mutations/PhotoModel.PhotoRender.json` | PT-1, suite-imaging IM-8d, TC-5 | ~300, 5 |
| PT-4 | – | The adapter's bodies (image or adjustment layer, Auto from the composite); `ToneCommands.specs` in the catalog; the ids; the three job folders | `Sources/PhotoModel/PhotoTone+Kernel.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoToneCommandTests.swift`, `Tests/mutations/PhotoModel.PhotoTone+Kernel.json`, `Tests/RealJobs/photo/white-balance/`, `Tests/RealJobs/photo/backlit/`, `Tests/RealJobs/photo/sharpen-web/` | PT-1, TC-6, gradient-fill:PG-m | ~300, 8 |
| PT-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoToneSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoToneTests.swift` | PT-2, TC-3 | ~160, 2 |
| PT-6 | – | The journey written and skipped (`XCTSkip("waits on PT-7")`) | `UITests/PhotoJourneyTests+Tone.swift` | PT-2 | ~120, 1 |
| PT-7 | – | Live: the journey turned on, on live services | `UITests/PhotoJourneyTests+Tone.swift` | PT-6, PT-3, PT-4 | ~40, 1 |
| PT-8 | – | photo.md: the tone rows in the Adjust panel; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/tone-controls.wave.json` | PT-7, PT-5, gradient-fill:PG-z | ~30, 2 |

## Build waves

- Wave 1: PT-1. Independent in this wave: PT-1 alone.
- Wave 2: PT-2, PT-3, PT-4. Independent in this wave: all three.
- Wave 3: PT-5, PT-6. Independent in this wave: both.
- Wave 4: PT-7. Independent in this wave: PT-7 alone.
- Wave 5: PT-8 (`feature-done`, final). Independent in this wave: PT-8 alone.

Longest chain: PT-1 → PT-2 → PT-6 → PT-7 → PT-8 (5). Chain of 5: the panel needs the section, the journey drives the panel, PT-7 turns it on live, PT-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PT-1 | compiles; an old document without `tone` opens neutral; `PhotoToneTests` disabled by name | an old file fails to open | – (stub) |
| PT-2 | `PhotoToneSnapshots.panel` (PT-5's, first in the slice PR) | the rows are missing or Exposure shows twice | – (UI) |
| PT-3 | `PhotoToneTests`: temperature −30 on the tungsten fixture reads neutral; a tone step on the live route composites, uploads and reads back nothing (`stepIsOneWrite`); the live picture equals `applied(to:)` within 2 levels with Sharpen on; Blur on still falls back | a step costs a readback, or export differs from the canvas | `PhotoModel.PhotoAdjust+Imaging`: tone after hue/saturation → `.toneFirst`; the unsharp parameters not passed to `LiveToneSurface` → `.sharpenOnCanvas`; `PhotoModel.PhotoRender`: unsharp after tone → `.exportMatchesCanvas` |
| PT-4 | `PhotoToneCommandTests`: `tone.set` on a selected adjustment layer changes the layer only; a drag is one step; Sharpen on a layer is unavailable with its help; the id list matches the catalog; RJ-P12, P13 and P14 pass on Linux | the image changes for a layer edit, or a step is doubled | `PhotoModel.PhotoTone+Kernel`: layer selection ignored → `.layerTone`; drag token dropped → `.dragIsOneStep` |
| PT-5 | `PhotoToneSnapshots`; `RenderBudgetPhotoToneTests.temperatureDragInThreeBodies` | budget over | – (UI) |
| PT-6 | compiles, skipped | – | – |
| PT-7 | `PhotoToneJourneyTests.testWarmShadowsAndSharpen` steps 1 to 5 | a step fails | – |
| PT-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Temperature drag | ≤ 3 window bodies; p95 ≤ 16 ms at 8K on the GPU route (reported) | `RenderBudgetPhotoToneTests.temperatureDragInThreeBodies` |
| No CPU route per step | a tone step composites, uploads and reads back nothing | `PhotoToneTests.stepIsOneWrite` |
| One gesture, one step | a slider drag, Auto and a reset are each one step | `PhotoToneCommandTests` |
| No dead controls | Sharpen on a layer and Vibrance say why | `PhotoToneCommandTests` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PT-m merged-done with RJ-P12, P13 and P14
green in the Linux job; PT-u's feel gate and `Mac-Finish:`; PT-z's journey
on live. Then `Belt-Contact-Sheet:` with `photo-adjust-tone-*`.

## Not in this packet

Tone on a masked adjustment layer's live route (#3144 sends those to the
dispatcher), HSL and Black & White rows, Clarity, local brushes.
