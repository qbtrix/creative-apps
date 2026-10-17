# Feature packet: adopt-kernel-brush

**Feature:** Photo's brush runs on SuiteKernel's stroke model and SuiteUI's pacer, pressure capture and cursor mark; Flare's pencil and Design's pen are built on the same module later, never as copies. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`StrokeSmoother`, `DabSpacer`, `BrushSettings`, `BrushPreset` and `LiveCopy`) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-brush`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"brush") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-stroke`
(`Belt-Slice-Done: EK-stroke`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AB-photo:** `PhotoStroke.swift`, `PhotoRetouch.swift` and `PhotoWindow.swift` are owned by photo-seams and photo-edit: start after their slices on them. The slice edits `Sources/PhotoApp/`, so it is `"ui": true`; its render budget rows are the brush's existing `PhotoBrushInkLatencyTests` and `PhotoWindowStrokeTests` (perf-suites rows 17, 22 to 25 stay). Flare's pencil (blueprint G49 area) and Design's `.pen` are future features that wait on `editor-kernel:EK-stroke`; they add no slice here.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AB-photo | Photo's brush, eraser, clone and heal sample through `StrokeSmoother` and `DabSpacer`, keep their options in `BrushSettings`, draw on `LiveCopy<PhotoWorkspace>` through SuiteUI's `StrokePacer`, `PointerPressure` and `BrushCursorMark`, and the Photo copies are deleted; the per-pixel capsule stays until creative-core's stamp op lands. | AB-p1, AB-p2 | MJ-AB-photo | editor-kernel:EK-stroke, editor-kernel:EK-chrome |

There is no new screen (`"ui_slice": "none"`); a slice that touches
`Sources/*App/` (a layers panel becoming `LayerTreeList`, an autosave file) is
marked `"ui": true` with the view's existing render budget as its row, and
waits on editor-kernel's EK-u for the SuiteUI half. A slice that edits a file
another adopt slice also edits waits on that slice (the `waits` data). The acceptance tests are the app's existing Model
tests and journeys, which merged long before this feature (rule 13 holds by
construction), plus a mutation plan on each adapter (rule 14).

## Journey steps

One Linux walk per slice, each an existing Model test file kept green
unchanged (rule 13 holds by construction), then the app's existing journeys
on the scoped run after the slice's last PR:
- `MJ-AB-photo`: `PhotoBrushTests` (existing), green on the Linux job after both tasks merge.

## Screens and states

None new. The snapshots the deleted files fed must not change: the Mac
finisher diffs the app's existing PNGs against the previous dev run.

## Contract slice

None added: the kernel's contract is editor-kernel's `{f['slice']}` (its
packet, Contract slice). Each adapter is one file in `<App>Model` that
conforms the app's types to the kernel and keeps the app's signatures.

## Pseudocode

- Adapter: `typealias <AppType> = <KernelType><Payload>` where the shapes
  match; otherwise a thin struct holding the kernel value and forwarding
  each app method to one kernel call, mapping the kernel's refusal to the
  app's existing error or help text.
- Delete: remove the body the adapter replaced; where a mutation plan's
  `find` pointed into it, move the entry to the adapter's plan or drop it
  when the kernel's own plan covers the bug (`scripts/mutate --validate`).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AB-p1 | – | **Photo adapter.** `PhotoStroke.Sample` is `StrokeSample`, `curve` and the 4-sample window route to `StrokeSmoother`, `dabCenters` to `DabSpacer`, `ToolOptions` to `BrushSettings` (`ToolOptionEdit` maps to `BrushEdit`; the two option sets stay as two settings values; a `BrushPreset` list is added behind the existing options view), `LiveStroke` to `LiveCopy<PhotoWorkspace>`; the capsule, falloff and max-coverage blend stay in `PhotoStroke` behind the same `paint` call, and the slice files the `needs-core` issue for a CoreRaster stamp op with the capsule's numbers as its acceptance test. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/PhotoModel/PhotoStroke.swift`, `Sources/PhotoModel/PhotoRetouch.swift`, `Sources/PhotoModel/ToolOptions.swift`, `Sources/PhotoApp/LiveStroke.swift`, `Sources/PhotoApp/StrokePacer.swift`, `Sources/PhotoApp/PointerPressure.swift`, `Sources/PhotoApp/BrushCursorOverlay.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Tests/PhotoModelTests/PhotoBrushTests.swift`, `Tests/PhotoModelTests/PhotoLiveStrokeTests.swift`, `Tests/PhotoModelTests/PhotoDragBatchTests.swift`, `Tests/PhotoModelTests/PhotoBrushArcTests.swift`, `Tests/PhotoModelTests/PhotoRetouchDabTests.swift`, `Tests/AppSnapshotTests/PhotoStrokePacerTests.swift`, `Tests/AppSnapshotTests/PhotoWindowStrokeTests.swift`, `Tests/mutations/PhotoModel.KernelBrushAdapter.json` | – | ~300, 17 |
| AB-p2 | – | **Photo delete.** Removes the sampling, curve and dab code in `PhotoStroke.swift` and `PhotoRetouch.swift`, `ToolOptions.swift`, and the app files `LiveStroke.swift`, `StrokePacer.swift`, `PointerPressure.swift`, `BrushCursorOverlay.swift` (SuiteUI's `StrokePacer`, `PointerPressure`, `BrushCursorMark` replace them; `PhotoToolOptions` reads `BrushSettings`); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/PhotoModel/PhotoStroke.swift`, `Sources/PhotoModel/PhotoRetouch.swift`, `Sources/PhotoModel/ToolOptions.swift`, `Sources/PhotoApp/LiveStroke.swift`, `Sources/PhotoApp/StrokePacer.swift`, `Sources/PhotoApp/PointerPressure.swift`, `Sources/PhotoApp/BrushCursorOverlay.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Tests/mutations/PhotoModel.PhotoStroke.json` | AB-p1 | ~200, 10 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AB-p1. Independent in this wave: all.
- Wave 2: AB-p2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AB-p1 → AB-p2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AB-p1 | `PhotoBrushTests`, `PhotoLiveStrokeTests`, `PhotoDragBatchTests`, `PhotoBrushArcTests`, `PhotoRetouchDabTests`, `PhotoStrokePacerTests`, `PhotoWindowStrokeTests` (unchanged) and `scripts/mutate --plan PhotoModel.KernelBrushAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AB-p2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| behaviour preserved | zero test edits in the app's existing test files (the diff touches no `Tests/<App>ModelTests/*` line) | the PR's `git diff --stat`, checked by the critic panel |
| copy deleted | the deleted symbols occur nowhere under `Sources/` | `scripts/ci` jscpd and `grep -rn <symbol> Sources` in the delete task's PR body |
| plans consistent | every `find` occurs exactly once | `scripts/mutate --validate` (in `scripts/ci`) |
| size | no app binary grows past its `SizeGate` budget from the new link | `Tests/SuiteModelTests/Packaging` size report on the macOS run |

## Done check

Per slice: both tasks merged, the app's Model tests green on the newest dev
Linux run containing the delete PR, the adapter's mutations caught, the
app's journeys green on the next scoped run, no open `finding`; then
`Belt-Slice-Done: <slice>`, and the contact sheet once every app slice is done.
