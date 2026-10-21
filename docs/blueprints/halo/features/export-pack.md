# Feature packet: export-pack (Halo)

**Feature:** Halo's File > Render… adds a Codec row (H.264, HEVC, ProRes
4444) and a "Transparent background" checkbox, on for ProRes 4444 and PNG
sequence only. With it on, frames render without the composition's
background and the movie keeps alpha, so a lower third drops onto another
clip in an editor. Halo stops writing movies itself: frames go to
shell-media's movie writer, and `HaloMovieWriter.swift` is deleted.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/export-pack`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 5). Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/export-pack` (adopter of S11 and of E9's
writers); real job RJ-H41 (new: ProRes with alpha). RJ-H07 (GIF) stays on E9.

**Depends on:** `suiteui/export-pack` **XP-a** (cross-line: `ExportOptions`,
`ExportFormats`); HX-3 needs **XP-6**. shell-media **SM-a** (`MovieCodec`,
`MovieSettings`) and **SM-w** (the writer; shell-media's packet moves
Halo's H.264 writer there, and this packet is the adoption that drops
Halo's copy). Same line: render-out (built) is the code this extends;
`gradient-fill`'s HG-z owns `halo.md`, so HX-8 waits on it.

**Rule 20.** No Halo movie writer: `services.media.movie` with
`MovieSettings(codec:)`; the alpha refusal is `ExportRules.refusal`'s.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HX-a | The render settings hold a codec and an alpha flag on stubs, and the Render sheet shows the Codec row and the checkbox. | HX-1, HX-2 | MJ-HX | XP-a, SM-a (cross-line); gradient-fill:HG-a (HX-1); placed-images:PH-a (HX-1, A/C first) |
| HX-u | The sheet has snapshots and a render budget, and the journey is written. | HX-5, HX-6 | HJ-X1 | HX-a |
| HX-m | The plan refuses alpha where the codec can't keep it, frames render without the background when asked, and the live renderer writes through the shared movie writer. | HX-3, HX-4 | MJ-HX | HX-a; XP-6, SM-w (cross-line) |
| HX-z | ProRes 4444 with alpha writes a real file on live services, the journey passes, and the blueprint has it in. | HX-7, HX-8 | HJ-X1 | HX-u, HX-m; gradient-fill:HG-z (HX-8); placed-images:PH-z (HX-8, A/C first) |

HX-u waits only on HX-a (rule 18); HX-m never waits on HX-u. HX-m is marked `"ui": true` because HX-4 deletes `HaloMovieWriter.swift` in HaloApp. MJ-HX is the Model walk in `HaloProResTests` (Linux, on `FakeMedia`).

## Journey steps

1. Open `Intro.halo`, File > Render… (HX-2,
   `HaloExportPackJourneyTests.testRenderLowerThirdWithAlpha`): Format Movie,
   Codec H.264, the checkbox off and disabled with help "H.264 can't keep
   transparency. Choose ProRes 4444."
2. Pick ProRes 4444, tick Transparent background, Render: `Intro.mov`.
3. The written movie's first frame has alpha 0 where the comp had only its
   background.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H41 | adds, closes with `halo/export-pack` | Cm | `Tests/RealJobs/halo/prores-alpha/prores-alpha.jobs.json`: render Movie, ProRes 4444, alpha on | `input/lower-third.halo` (a bar over the comp's grey background) |

Trap: alpha renders black (the background drawn anyway), or the file says
ProRes but carries no alpha channel. Assertion: the movie's track reports
ProRes 4444 with alpha, a background-only pixel decodes with alpha 0 and a
bar pixel with alpha 255. Mutations: `HaloModel.HaloRenderJob.json`, the
background drawn with alpha on → `.alphaSkipsBackground`; alpha allowed on
H.264 → `.h264RefusesAlpha`.

## Screens and states

`halo-render-prores` (light and dark), `halo-render-h264-alpha-off` (the help shown).

## Contract slice

```swift
// Sources/HaloModel/Contracts/HaloDocumentValues.swift (HX-1)
public struct HaloRenderSettings { ...; public var codec: MovieCodec = .h264; public var alpha = false }
// "ProRes 4444 lands with HX-3." on the codec row until HX-3
```

## Pseudocode

- **refusal.** Alpha with a codec whose `keepsAlpha` is false →
  `ExportRules.refusal`'s sentence; PNG sequence always may.
- **frame.** With alpha on, `HaloRenderFrame` skips the composition's
  background fill and leaves the frame premultiplied clear there.
- **write.** `services.media.movie(at:, MovieSettings(codec:, ...))`, one
  frame appended per rendered frame; cancel deletes the partial file.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HX-1 | – | `HaloRenderSettings.codec` and `.alpha` (ProRes refused until HX-3); `HaloProResTests` written, disabled | `Sources/HaloModel/Contracts/HaloDocumentValues.swift`, `Tests/HaloModelTests/HaloProResTests.swift` | XP-a, SM-a | ~100, 2 |
| HX-2 | – | The Render sheet's Codec row and Transparent background checkbox with its help | `Sources/HaloApp/HaloRenderSheet.swift` | HX-1 | ~100, 1 |
| HX-3 | – | The plan's codec and alpha rules; frames without the background when alpha is on; RJ-H41's job folder; turns on `HaloProResTests` | `Sources/HaloModel/HaloRenderJob.swift`, `Sources/HaloModel/HaloRenderFrame.swift`, `Tests/HaloModelTests/HaloProResTests.swift`, `Tests/mutations/HaloModel.HaloRenderJob.json`, `Tests/RealJobs/halo/prores-alpha/`, `Tests/mutations/HaloModel.HaloRenderFrame.json` | HX-1, XP-6 | ~220, 6 |
| HX-4 | – | The live renderer writes through `services.media.movie`; `HaloMovieWriter.swift` deleted | `Sources/HaloModel/Live/LiveCompositionRendering.swift`, `Sources/HaloApp/HaloMovieWriter.swift`, `Tests/HaloModelTests/HaloMovieSinkTests.swift`, `Tests/mutations/HaloModel.LiveCompositionRendering.json` | HX-1, SM-w | ~200, 4 |
| HX-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/HaloRenderProResSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloRenderSheetTests.swift` | HX-2 | ~120, 2 |
| HX-6 | – | The journey written and skipped (`XCTSkip("waits on HX-7")`) | `UITests/HaloJourneyTests+ExportPack.swift` | HX-2 | ~100, 1 |
| HX-7 | – | Live: the journey turned on, on live services | `UITests/HaloJourneyTests+ExportPack.swift` | HX-6, HX-3, HX-4 | ~40, 1 |
| HX-8 | – | halo.md: ProRes 4444 with alpha in Render; `status: built`; `feature-done` | `docs/blueprints/halo.md`, `docs/blueprints/halo/features/export-pack.wave.json` | HX-7, HX-5, gradient-fill:HG-z | ~30, 2 |

## Build waves

- Wave 1: HX-1. Independent in this wave: HX-1 alone.
- Wave 2: HX-2, HX-3, HX-4. Independent in this wave: all three.
- Wave 3: HX-5, HX-6. Independent in this wave: both.
- Wave 4: HX-7. Independent in this wave: HX-7 alone.
- Wave 5: HX-8 (`feature-done`, final). Independent in this wave: HX-8 alone.

Longest chain: HX-1 → HX-2 → HX-6 → HX-7 → HX-8 (5). Chain of 5: the sheet needs the settings, the journey drives the sheet, HX-7 turns it on live, HX-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HX-1 | compiles; existing render tests pass; ProRes is refused with its reason | an existing render changes | – (stub) |
| HX-2 | `HaloRenderProResSnapshots.sheet` (HX-5's, first in the slice PR) | the row or checkbox is missing | – (UI) |
| HX-3 | `HaloProResTests`: alpha with H.264 is refused with its sentence; alpha with ProRes plans `MovieSettings(codec: .prores4444)`; a frame with alpha on has alpha 0 on the background; RJ-H41's plan half passes on Linux | a refusal or a frame is wrong | `HaloModel.HaloRenderJob`: alpha allowed on H.264 → `.h264RefusesAlpha`; `HaloModel.HaloRenderFrame`: background drawn with alpha on → `.alphaSkipsBackground` |
| HX-4 | `HaloMovieSinkTests` (on `FakeMedia`): every frame reaches the sink in order; cancel deletes; no file under HaloApp writes movies | a frame is lost or the old writer is still called | `HaloModel.LiveCompositionRendering`: cancel not forwarded → `.cancelDeletes` |
| HX-5 | `HaloRenderProResSnapshots`; `RenderBudgetHaloRenderSheetTests.codecSwitchInTwoBodies` | budget over | – (UI) |
| HX-6 | compiles, skipped | – | – |
| HX-7 | `HaloExportPackJourneyTests.testRenderLowerThirdWithAlpha` steps 1 to 3; RJ-H41 green on macOS | a step fails | – |
| HX-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: switching codec in the sheet | ≤ 2 window bodies | `RenderBudgetHaloRenderSheetTests.codecSwitchInTwoBodies` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HX-m merged-done; HX-u's feel gate and `Mac-Finish:`; HX-z's journey on live and RJ-H41 green on macOS. Then `Belt-Contact-Sheet:` with `halo-render-*`.

## Not in this packet

GIF from Halo (RJ-H07, E9), HEVC with alpha, audio (S23), a render queue.
