# Feature packet: export-pack (Flare)

**Feature:** Flare's File > Export… adds MP4 (H.264) and GIF beside SVG,
Lottie and PNG sequence. Both render every frame of the scene at the frame
rate, at a size from the shared Size row; GIF loops forever by default and
keeps a transparent background, MP4 is opaque on the scene's background and
even-sized. The writers are shell-media's; Flare only renders frames.
**Line:** `line:flare` · **Wave:** 6 (`waves.md`) · **Lead branch:** `lead/export-pack`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 5). Labels `beta` and `p1` when filed.

**Covers:** feature map `flare/export-pack` (adopter of S11 and of E9's
writers); real jobs RJ-F07 (a GIF for Slack) and RJ-F08 (an MP4 for social).

**Depends on:** `suiteui/export-pack` **XP-a** (cross-line); FV-3 needs
**XP-6**, FV-5 **XP-4**. shell-media **SM-a** (the contract: `MovieSettings`,
`AnimatedImageSettings`, `FrameClock`) and **SM-w** (the writers, for FV-4).
Same line: flare-export (built) is the code this extends; `gradient-fill`'s
FG-z owns `flare.md`, so FV-8 waits on it.

**Rule 20.** No Flare encoder: frames go to `services.media.movie` and
`services.media.animatedImage`; frame timing is shell-media's `FrameClock`;
size and options are `ExportOptions`. `FlareExport+Kernel.swift` stays the
adapter.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FV-a | Flare's export lists MP4 and GIF with frame rate and loop on stubs, and the sheet shows them with the shared Size row. | FV-1, FV-2 | MJ-FV | XP-a, SM-a (cross-line); flare-export (built) |
| FV-u | The sheet has snapshots and a render budget, and the journey is written. | FV-5, FV-6 | FJ-X1 | FV-a; XP-4 (FV-5, cross-line) |
| FV-m | The plan lists every frame with its time and size, GIF keeps transparency and loops, MP4 is even-sized and opaque, and the live adapter streams frames into the shared writers, deleting a cancelled file. | FV-3, FV-4 | MJ-FV | FV-a; XP-6, SM-w (cross-line) |
| FV-z | MP4 and GIF write real files on live services, the journey passes, and the blueprint has them in. | FV-7, FV-8 | FJ-X1 | FV-u, FV-m; gradient-fill:FG-z (FV-8); svg-place:PF-z (FV-8, A/C first) |

FV-u waits only on FV-a (rule 18); FV-m never waits on FV-u. MJ-FV is the Model walk in `FlareVideoExportTests` (Linux, on `FakeMedia`).

## Journey steps

1. Launch on `-FlareSample bounce` (550 × 400, 24 fps, 48 frames, scene `scene-1`), File > Export… (FV-2,
   `FlareExportPackJourneyTests.testExportLoopAsGIFAndMP4`): MP4 and GIF chips.
2. GIF, Loop forever: Export writes `scene-1.gif`, 48 frames that loop forever.
3. MP4: Export writes `scene-1.mp4` (an `ftyp` box).
4. Cancel a running MP4 export: no partial file is left.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F07 | closes (now `flare/export-pack`) | Cm | `Tests/RealJobs/flare/slack-gif/slack-gif.jobs.json`: export GIF, long edge 480, loop | `input/spinner.flare` (transparent background) |
| RJ-F08 | closes (now `flare/export-pack`) | Cm | `Tests/RealJobs/flare/social-mp4/social-mp4.jobs.json`: export MP4 at `pixels(1920, 1080)`, 30 fps | `input/bounce.flare` (2 s) |

Traps: the GIF plays once, or has a black background, or is over 2 MB; the
MP4 is one frame short or 1919 wide. Assertions: the GIF's loop count is 0
(forever), a corner pixel is transparent, its size ≤ 2 MB and its delays
sum to the scene's length within 1 cs; the MP4 is 1920 × 1080, 60 frames,
2.0 s. Mutations: `FlareModel.FlareExport+Kernel.json`, the last frame
dropped → `.everyFrame`; GIF background filled → `.gifKeepsAlpha`.

## Screens and states

`flare-export-gif` (light and dark), `flare-export-mp4`, `flare-export-running`.

## Contract slice

```swift
// Sources/FlareModel/FlareExport.swift (FV-1)
public enum FlareExportFormat { ...; case mp4, gif }   // "MP4 lands with FV-3." until FV-3
// the export options carry ExportOptions' size, fps (the scene's by default) and loop (GIF, default true)
```

## Pseudocode

- **plan.** Frames 0..<n at the scene's rate; each frame's time from
  `FrameClock`; size from `ExportRules.pixels(evenSize: format == .mp4)`.
- **write.** One sink per file; each frame rendered by `StageRasterizer` at
  the size (GIF without the background fill), appended in order; `finish()`
  at the end; Cancel calls `cancel()`, which deletes the partial file.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FV-1 | – | `.mp4` and `.gif` with frame rate and loop in the options (refused until FV-3); `FlareVideoExportTests` written, disabled | `Sources/FlareModel/FlareExport.swift`, `Tests/FlareModelTests/FlareVideoExportTests.swift` | XP-a, SM-a | ~140, 2 |
| FV-2 | – | The sheet: MP4 and GIF chips, the frame rate and loop rows in the options slot, the shared Size row | `Sources/FlareApp/FlareExportSheetAdapter.swift` | FV-1 | ~120, 1 |
| FV-3 | – | The frame plan for MP4 and GIF (times, even size, alpha); RJ-F07's and RJ-F08's job folders; turns on `FlareVideoExportTests` | `Sources/FlareModel/FlareExport+Kernel.swift`, `Tests/FlareModelTests/FlareVideoExportTests.swift`, `Tests/mutations/FlareModel.FlareExport+Kernel.json`, `Tests/RealJobs/flare/slack-gif/`, `Tests/RealJobs/flare/social-mp4/` | FV-1, XP-6 | ~260, 5 |
| FV-4 | – | The live adapter streams rasterized frames into `services.media` sinks, cancel deletes the partial file; the fake records sinks | `Sources/FlareModel/Live/LiveExportAdapter.swift`, `Sources/FlareModel/Fakes/FakeExport.swift`, `Tests/FlareModelTests/FlareVideoWriteTests.swift`, `Tests/mutations/FlareModel.LiveExportAdapter.json` | FV-1, SM-w | ~220, 4 |
| FV-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/FlareExportPackSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareExportPackTests.swift` | FV-2, XP-4 | ~140, 2 |
| FV-6 | – | The journey written and skipped (`XCTSkip("waits on FV-7")`) | `UITests/FlareJourneyTests+ExportPack.swift` | FV-2 | ~100, 1 |
| FV-7 | – | Live: the journey turned on, on live services | `UITests/FlareJourneyTests+ExportPack.swift` | FV-6, FV-3, FV-4 | ~40, 1 |
| FV-8 | – | flare.md: MP4 and GIF in Export; `status: built`; `feature-done` | `docs/blueprints/flare.md`, `docs/blueprints/flare/features/export-pack.wave.json` | FV-7, FV-5, gradient-fill:FG-z | ~30, 2 |

## Build waves

- Wave 1: FV-1. Independent in this wave: FV-1 alone.
- Wave 2: FV-2, FV-3, FV-4. Independent in this wave: all three.
- Wave 3: FV-5, FV-6. Independent in this wave: both.
- Wave 4: FV-7. Independent in this wave: FV-7 alone.
- Wave 5: FV-8 (`feature-done`, final). Independent in this wave: FV-8 alone.

Longest chain: FV-1 → FV-2 → FV-6 → FV-7 → FV-8 (5). Chain of 5: the sheet needs the formats, the journey drives the sheet, FV-7 turns it on live, FV-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FV-1 | compiles; existing export tests pass; MP4 is refused with its reason | an existing export changes | – (stub) |
| FV-2 | `FlareExportPackSnapshots.gif` (FV-5's, first in the slice PR) | a chip or row is missing | – (UI) |
| FV-3 | `FlareVideoExportTests`: a 2 s scene at 30 fps plans 60 frames; MP4 at 1081 wide plans 1080; GIF frames carry alpha; GIF delays sum to 200 cs; RJ-F07's and F08's plan halves pass on Linux | a frame, a size or a delay is wrong | `FlareModel.FlareExport+Kernel`: last frame dropped → `.everyFrame`; GIF background filled → `.gifKeepsAlpha`; even rounding skipped → `.mp4IsEven` |
| FV-4 | `FlareVideoWriteTests` (on `FakeMedia`): frames reach the sink in order, `finish` once; Cancel calls `cancel` and reports no file | a frame is out of order or a cancelled file is reported | `FlareModel.LiveExportAdapter`: cancel not forwarded → `.cancelDeletes`; frames appended after finish → `.finishLast` |
| FV-5 | `FlareExportPackSnapshots`; `RenderBudgetFlareExportPackTests.progressInOneBodyPerTick` | budget over | – (UI) |
| FV-6 | compiles, skipped | – | – |
| FV-7 | `FlareExportPackJourneyTests.testExportLoopAsGIFAndMP4` steps 1 to 4; RJ-F07 and RJ-F08 green on macOS | a step fails | – |
| FV-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: export progress | ≤ 1 window body per progress tick | `RenderBudgetFlareExportPackTests.progressInOneBodyPerTick` |
| Export cost | a 2 s 1080p MP4 in ≤ 4 s on the Mac finisher (reported) | `FlareVideoWriteTests.cost` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): FV-m merged-done; FV-u's feel gate and `Mac-Finish:`; FV-z's journey on live and RJ-F07, F08 green on macOS. Then `Belt-Contact-Sheet:` with `flare-export-*`.

## Not in this packet

HEVC, ProRes and APNG from Flare (the writers have them; Flare's sheet offers the two everyday ones), audio, a GIF palette choice.
