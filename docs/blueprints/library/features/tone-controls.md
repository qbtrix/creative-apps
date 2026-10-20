# Feature packet: tone-controls (Library)

**Feature:** Library's Develop tab draws its TONE and COLOR sliders with
SuiteUI's `ToneRows`, which adds Auto and a SHARPEN section, and the loupe
draws a develop change on the GPU: the photo stays resident, a slider step is
one `ToneProgram` in the display write, Sharpen one unsharp pass. Export and
thumbnails keep the CPU path, running the same `ToneRules` list.
**Line:** `line:library` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/tone-controls`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 2). Labels `beta` and `p1` when filed.

**Covers:** feature map `library/tone-controls` (adopter of S1); real job
RJ-L41 (new: auto tone and sharpen a photo for the web).

**Depends on:** `suiteui/tone-controls` **TC-a** (cross-line); LT-3 and LT-4
need **TC-5**, LT-5 **TC-6**, LT-6 **TC-3**. Same line: `develop` (the
feature, open as #1527; it owns `DevelopValues.swift`, `LiveDevelop.swift`
and `DevelopInspector.swift`). LT-1 edits `Package.swift` after TC-1 does
(cross-line) and is a supervisor merge.

**Rule 20.** `DevelopSettings` holds the kernel's `ToneSettings` for its ten
sliders and keeps its curve, levels and crop; the JSON keys don't change,
so every catalog opens as it did. `DevelopSlider` and the TONE and COLOR
rows go: the rows are `ToneRows`, and `LiveDevelop.waiting` reads
`ToneRules.waiting` (Saturation renders now; Vibrance waits on core).
`LibraryTone+Kernel.swift` is the adapter.

**Render path.** New for Library, not a second copy: `LibraryLiveTone`
(Model, Linux-tested) plans the loupe's GPU work from the settings
(`ToneRules.unsharp`, then `ToneRules.program` with the curve and levels
appended), and `LibraryLoupe+Metal.swift` keeps the photo as a resident
CoreRender surface and writes it through `MetalBackend.display(_:into:…:
tone:)` into the shared `CanvasHost`'s resident texture (canvas-host's G1
path, which Photo already uses). LT-1 adds `CoreRender` to LibraryModel and
`CoreRenderMetal` to LibraryApp in `Package.swift`. Export, thumbnails and
the histogram stay on `LiveDevelop` (CPU), which runs
`ToneRules.adjustments`, so they match the loupe.

Blueprint sections: library.md (Develop, Loupe), 8.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LT-a | `DevelopSettings` holds `ToneSettings` with the same keys, Library links CoreRender, the adapter conforms on stubs, and Develop shows `ToneRows` on them. | LT-1, LT-2 | MJ-LT | TC-a (cross-line); develop; crop (built: it shares LiveDevelop, DevelopInspector and the loupe) |
| LT-u | The Develop rows have snapshots and a render budget, and the journey is written. | LT-6, LT-7 | LJ-T1 | LT-a; TC-3 (LT-6, cross-line) |
| LT-m | Export runs the shared list, the loupe draws each step on the GPU in one write, and every tone command is one undo step over the selected photos. | LT-3, LT-4, LT-5 | MJ-LT | LT-a; TC-5, TC-6 (cross-line); cull-finish:DR-m (LT-5, A/C first) |
| LT-z | Develop runs on live services, the journey passes on live, and the feature is built. | LT-8, LT-9 | LJ-T1 | LT-u, LT-m |

LT-u waits only on LT-a (rule 18); LT-m never waits on LT-u. LT-m is marked
`"ui": true` because LT-4 adds the loupe's Metal path. MJ-LT is the Model walk
in `LibraryToneTests` (Linux).

## Journey steps

1. Open the sample catalog, a photo in the loupe, the Develop tab (LT-2,
   `LibraryToneJourneyTests.testAutoAndSharpenInDevelop`): WHITE BALANCE,
   TONE (with Auto), PRESENCE and SHARPEN, then CURVE and LEVELS as before.
2. Click Auto: one "Auto Tone" step; the loupe updates without a placeholder.
3. Drag Shadows to +30: the loupe follows the drag.
4. Sharpen Amount 60; Sync to two more photos: all three take it as one step.
5. Export the three as JPEG: each file matches its loupe within 2 levels.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L41 | adds, closes with `library/tone-controls` | C | `Tests/RealJobs/library/auto-sharpen/auto-sharpen.jobs.json`: import, `tone.auto`, `tone.set` sharpenAmount 60, export JPEG at a 1200 px long edge | `input/flat-dim.png` (a low-contrast, dim photo) |

Trap: Auto stretches the levels but leaves a colour cast, or the export
doesn't carry Sharpen (the loupe and the file differ). Assertion: the export's
luma spans at least 0.05...0.95 and its grey patch reads neutral (|R−B| ≤
3/255); its edge contrast exceeds the unsharpened export's by 15%. Mutations:
`LibraryModel.LiveDevelop.json`, unsharp skipped → `.exportSharpens`;
`LibraryModel.LibraryTone+Kernel.json`, Auto's white balance dropped →
`.autoNeutralizes`.

## Screens and states

`library-develop-tone` (light and dark), `library-develop-sharpen`
(Sharpen on), `library-loupe-gpu` (a step drawn on the GPU path).

## Contract slice

```swift
// Sources/LibraryModel/Contracts/DevelopValues.swift (LT-1)
public struct DevelopSettings { public private(set) var tone: ToneSettings; public var curve, levels, crop ... }
// encode/decode flatten `tone` into the same container: the keys stay "exposure", "temperature", ...
// Sources/LibraryModel/LibraryTone+Kernel.swift (LT-1 stubs, LT-5 bodies)
extension LibraryCatalog: ToneTarget { ... }   // the develop targets' settings ("Mixed" stays the view's job)
// Sources/LibraryModel/Live/LibraryLiveTone.swift (LT-1 stub returning an empty plan, LT-4 body)
public struct LibraryLiveTone: Sendable {
    public static func plan(_ s: DevelopSettings) throws -> (unsharp: (amount: Double, sigma: Double, threshold: Double)?, program: ToneProgram)
}
```

## Pseudocode

- **plan.** `ToneRules.unsharp(s.tone)`, then a program of
  `ToneRules.program(s.tone)` + the curve and levels as sRGB `curves` and
  `levels` operations, each skipped at neutral (LiveDevelop's order).
- **loupe.** On a settings change: a sharpen change re-runs the unsharp pass
  into the cached base; any other change only rewrites the drawable through
  `display(…tone: plan.program)`. CPU route or no Metal device: the existing
  CPU render, unchanged.
- **setTone.** Applies to every develop target as one catalog edit through
  `CatalogHistory` (Sync's rule), a drag folding.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LT-1 | – | `DevelopSettings.tone` with flattened coding; `DevelopSlider` folded into `ToneSlider`; CoreRender and CoreRenderMetal linked; the adapter and `LibraryLiveTone` as stubs; `LibraryToneTests` written, disabled | `Package.swift`, `Sources/LibraryModel/Contracts/DevelopValues.swift`, `Sources/LibraryModel/LibraryTone+Kernel.swift`, `Sources/LibraryModel/Live/LibraryLiveTone.swift`, `Tests/LibraryModelTests/LibraryToneTests.swift` | TC-a, TC-1 (Package.swift) | ~260, 5 |
| LT-2 | – | Develop's TONE and COLOR rows become `ToneRows`; intents to the catalog's commands | `Sources/LibraryApp/DevelopInspector.swift` | LT-1 | ~120, 1 |
| LT-3 | – | `LiveDevelop` runs `ToneRules.unsharp` and `ToneRules.adjustments`, its `waiting` from `ToneRules`; the export test | `Sources/LibraryModel/Live/LiveDevelop.swift`, `Tests/LibraryModelTests/LiveDevelopToneTests.swift`, `Tests/mutations/LibraryModel.LiveDevelop.json` | LT-1, TC-5 | ~180, 3 |
| LT-4 | – | `LibraryLiveTone.plan` and the loupe's Metal path on the shared `CanvasHost` resident texture; turns on `LibraryToneTests` | `Sources/LibraryModel/Live/LibraryLiveTone.swift`, `Sources/LibraryApp/LibraryLoupe+Metal.swift`, `Sources/LibraryApp/LibraryLoupe.swift`, `Tests/LibraryModelTests/LibraryToneTests.swift`, `Tests/mutations/LibraryModel.LibraryLiveTone.json` | LT-1, TC-5 | ~340, 5 |
| LT-5 | – | The adapter's bodies (every develop target, one step; Auto from the loupe render); `ToneCommands.specs` in the catalog; the ids; RJ-L41's job folder | `Sources/LibraryModel/LibraryTone+Kernel.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/LibraryModelTests/LibraryToneCommandTests.swift`, `Tests/mutations/LibraryModel.LibraryTone+Kernel.json`, `Tests/RealJobs/library/auto-sharpen/` | LT-1, TC-6 | ~260, 6 |
| LT-6 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/LibraryToneSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetLibraryToneTests.swift` | LT-2, TC-3 | ~160, 2 |
| LT-7 | – | The journey written and skipped (`XCTSkip("waits on LT-8")`) | `UITests/LibraryJourneyTests+Tone.swift` | LT-2 | ~120, 1 |
| LT-8 | – | Live: the journey turned on, on live services | `UITests/LibraryJourneyTests+Tone.swift` | LT-7, LT-3, LT-4, LT-5 | ~40, 1 |
| LT-9 | – | `status: built`; `feature-done` (no library.md edit: `c4-planned.json` already names the new files, added with this packet) | `docs/blueprints/library/features/tone-controls.wave.json` | LT-8, LT-6 | ~10, 1 |

## Build waves

- Wave 1: LT-1. Independent in this wave: LT-1 alone.
- Wave 2: LT-2, LT-3, LT-4, LT-5. Independent in this wave: all of them.
- Wave 3: LT-6, LT-7. Independent in this wave: both.
- Wave 4: LT-8. Independent in this wave: LT-8 alone.
- Wave 5: LT-9 (`feature-done`, final). Independent in this wave: LT-9 alone.

Longest chain: LT-1 → LT-2 → LT-7 → LT-8 → LT-9 (5). Chain of 4: the journey drives the rows on the settings, LT-8 turns it on live, LT-9 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LT-1 | every catalog fixture under `Tests/LibraryModelTests/Fixtures/` decodes to the same develop values and re-encodes byte for byte; `LibraryToneTests` disabled by name | a catalog's keys change | – (stub) |
| LT-2 | `LibraryToneSnapshots.develop` (LT-6's, first in the slice PR) | the rows are missing | – (UI) |
| LT-3 | `LiveDevelopToneTests`: neutral returns the input; Saturation 40 renders (no waiting error); Sharpen 60 raises edge contrast; the order matches `ToneRules.adjustments` | export drops a step | `LibraryModel.LiveDevelop`: unsharp skipped → `.exportSharpens`; saturation still waiting → `.saturationRenders` |
| LT-4 | `LibraryToneTests`: the plan's program on the CPU (`ToneProgram.map`) equals `LiveDevelop` within 2 levels; a shadows step changes only the program (`stepIsOneWrite`); a sharpen step re-runs the base once | the loupe and export differ, or a step re-renders on the CPU | `LibraryModel.LibraryLiveTone`: curve appended before tone → `.matchesExport`; sharpen re-run on every step → `.stepIsOneWrite` |
| LT-5 | `LibraryToneCommandTests`: `tone.set` over three targets is one step; Auto is one "Auto Tone"; the ids match; RJ-L41 passes on Linux | a target is skipped or steps double | `LibraryModel.LibraryTone+Kernel`: only the first target set → `.allTargets`; Auto's white balance dropped → `.autoNeutralizes` |
| LT-6 | `LibraryToneSnapshots`; `RenderBudgetLibraryToneTests.shadowsDragInThreeBodies` | budget over | – (UI) |
| LT-7 | compiles, skipped | – | – |
| LT-8 | `LibraryToneJourneyTests.testAutoAndSharpenInDevelop` steps 1 to 5 | a step fails | – |
| LT-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Shadows drag in Develop | ≤ 3 window bodies; p95 ≤ 16 ms on a 24 MP photo (reported) | `RenderBudgetLibraryToneTests.shadowsDragInThreeBodies` |
| No CPU route per step | a tone step in the loupe re-renders nothing on the CPU | `LibraryToneTests.stepIsOneWrite` |
| One gesture, one step | a drag, Auto and Sync are each one step | `LibraryToneCommandTests` |
| Audit | zero new over Library's baseline | `audit-library-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): LT-m merged-done with RJ-L41 green in the
Linux job; LT-u's and LT-m's feel gate and `Mac-Finish:`; LT-z's journey on
live. Then `Belt-Contact-Sheet:` with `library-develop-tone-*`.

## Not in this packet

GPU thumbnails and GPU export (they stay on the CPU path), HSL, presets.
