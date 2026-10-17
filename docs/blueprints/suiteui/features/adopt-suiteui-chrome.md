# Feature packet: adopt-suiteui-chrome

**Feature:** The apps' zoom clamps, colour types, tool-letter and modifier lookups, guide views and export sheets move onto the SuiteUI component each already has or editor-kernel adds; the app copies are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (the SuiteUI components that already exist (`ZoomMath`, `CanvasLayout`, `CanvasMarks`, `HexColor`, `ColorWell`) and the ones editor-kernel's EK-chrome adds (`ExportSheet`, `ToolKeys`)) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-suiteui-chrome`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"chrome") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-a`
(`Belt-Slice-Done: EK-a`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AC-zoom:** `DesignWindow.swift` is owned by design-window and shell-parity; `PhotoWindow.swift` by photo-seams and adopt-kernel-brush's Photo slice (that one first); `HaloViewerCanvas.swift` by Halo's foundation (built). Behaviour change to record: the minimum zoom becomes `ZoomMath.range`'s 10 % everywhere (today 5 % from one path and 10 % from the other).
- **AC-colour:** `DesignIntent.swift` is owned by design-window, canvas-basics and snapping (SN-8); `DesignCanvasMarks.swift` by design-seams-2 and design-window; `PhotoToolOptions.swift` by adopt-kernel-brush's Photo slice (that one first); `HaloViewerCanvas.swift` is shared with AC-zoom (that one first). The new test file and plan are SuiteUI's; `ColorWell.swift` itself is not edited.
- **AC-tools:** `FlareStage.swift` is owned by live-stage and stage-edit (Flare); `DesignCanvas.swift` by design-window, canvas-basics and design-seams-2; `PhotoEditor.swift` by photo-seams and shell-parity. `DesignIntent.swift` follows AC-colour.
- **AC-guides:** `FlareStageGuides.swift` is owned by live-stage (Flare): start after its slice on it. `GuideLineMark.swift` is a new SuiteUI file no feature owns.
- **AC-export-sheet:** `PhotoWindow+Export.swift` is owned by photo-seams; `LibraryWindow+Export.swift` and `LibraryExportSheet.swift` by Library's export packet; `FlareWindow+Export.swift` by Flare's export packet. Each app's run type comes from adopt-kernel-export (the `waits`).

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AC-zoom | Design's and Photo's `setZoom` clamps and Halo's second document-to-screen mapping go; every app clamps through `ZoomMath.clamped`, fits through one fit, and maps through `CanvasLayout`. | AC-z1, AC-z2 | MJ-AC-zoom | editor-kernel:EK-a, adopt-kernel-brush:AB-photo |
| AC-colour | Design, Photo, Flare and Halo keep their file-format colour types but parse, format and pick through `HexColor` and `ColorWell`; the hex parser gets its tests. | AC-c1, AC-c2 | MJ-AC-colour | editor-kernel:EK-a, adopt-kernel-brush:AB-photo, adopt-suiteui-chrome:AC-zoom |
| AC-tools | Flare, Design and Photo pick a tool from a key and read modifiers through SuiteUI's `ToolKeys`; the three letter lookups and three `NSEvent.modifierFlags` conversions are deleted. | AC-t1, AC-t2 | MJ-AC-tools | editor-kernel:EK-chrome, adopt-suiteui-chrome:AC-colour |
| AC-guides | Flare's rulers and guides toggles do something: guides draw through `CanvasMarks` and the stub view is deleted; the rulers flag is filed on canvas-marks. | AC-g1, AC-g2 | MJ-AC-guides | editor-kernel:EK-a |
| AC-export-sheet | Photo's, Library's and Flare's export sheets are SuiteUI's `ExportSheet` over each app's `ExportRun`, and the three app sheets are deleted. | AC-e1, AC-e2 | MJ-AC-export-sheet | editor-kernel:EK-chrome, adopt-kernel-export:AX-photo, adopt-kernel-export:AX-library, adopt-kernel-export:AX-flare |

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
- `MJ-AC-zoom`: `DesignWindowZoomTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AC-colour`: `HexColorParserTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AC-tools`: `FlareToolsKeyTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AC-guides`: `FlareStageGuideSnapshots` (existing), green on the Linux job after both tasks merge.
- `MJ-AC-export-sheet`: `PhotoExportSheetSnapshots` (existing), green on the Linux job after both tasks merge.

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
| AC-z1 | – | **zoom adapter.** `DesignWindow.setZoom` and `PhotoWindow.setZoom` call `ZoomMath.clamped` and `ZoomMath.zoomedIn/Out`; both fits call `ZoomMath.fit(document:in:using:)`; `HaloViewerCanvas` and `HaloViewerDrag.compositionPoint` map through a `CanvasLayout` built from the fitted artboard. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/DesignApp/DesignWindow.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Sources/HaloApp/HaloViewerCanvas.swift`, `Sources/HaloModel/HaloViewerDrag.swift`, `Tests/AppSnapshotTests/DesignWindowZoomTests.swift`, `Tests/AppSnapshotTests/PhotoWindowZoomTests.swift`, `Tests/HaloModelTests/HaloKeyByDragTests.swift`, `Tests/HaloModelTests/ViewerDraggingContractTests.swift`, `Tests/mutations/HaloModel.KernelZoomAdapter.json` | – | ~300, 9 |
| AC-z2 | – | **zoom delete.** Removes the two clamp copies, `HaloCanvasFit.scale/transform` and `compositionPoint`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/DesignApp/DesignWindow.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Sources/HaloApp/HaloViewerCanvas.swift`, `Sources/HaloModel/HaloViewerDrag.swift`, `Tests/mutations/HaloModel.HaloViewerDrag.json` | AC-z1 | ~200, 5 |
| AC-c1 | – | **colour adapter.** `DesignColor`, Photo's `ToolOptions.color`, Flare's `setFill(hex:)` string and `HaloLayerColor` convert through one `HexColor` bridge per app (`init(hex:)`, `hex`), every colour row is `InspectorColorWellRow`, and `HexColorParserTests` pins the parser (3- and 6-digit, `#` optional, invalid → nil). The app's existing tests pass unchanged; a new plan on the adapter | `Sources/DesignApp/DesignIntent.swift`, `Sources/DesignApp/DesignCanvasMarks.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Sources/FlareApp/StagePath.swift`, `Sources/HaloApp/HaloViewerCanvas.swift`, `Tests/SuiteUITests/HexColorParserTests.swift`, `Tests/DesignModelTests/DesignStyleTests.swift`, `Tests/AppSnapshotTests/DesignInspectorSnapshots.swift`, `Tests/mutations/SuiteUI.HexColor.json` | – | ~300, 9 |
| AC-c2 | – | **colour delete.** Removes the per-app hex parsing and `isLight` luma copies (`DesignCanvasMarks.swift:50`, `StagePath.cgColor`'s conversion, `HaloCanvasFit.cgColor`); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/DesignApp/DesignIntent.swift`, `Sources/DesignApp/DesignCanvasMarks.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Sources/FlareApp/StagePath.swift`, `Sources/HaloApp/HaloViewerCanvas.swift`, `Tests/mutations/SuiteUI.ColorWell.json` | AC-c1 | ~200, 6 |
| AC-t1 | – | **tools adapter.** `FlareStage`, `DesignCanvas` and `PhotoEditor` call `ToolKeys.tool(forKey:in:)` over their `PaletteTool` lists; `FlareStage`, `DesignModifiers.current` and Photo's drag routing read `KeyModifiers(nsEvent:)` and map to the app's modifier set. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareApp/FlareStage.swift`, `Sources/DesignApp/DesignCanvas.swift`, `Sources/DesignApp/DesignIntent.swift`, `Sources/PhotoApp/PhotoEditor.swift`, `Tests/AppSnapshotTests/FlareToolsKeyTests.swift`, `Tests/AppSnapshotTests/DesignToolsKeyTests.swift`, `Tests/AppSnapshotTests/PhotoToolsKeyTests.swift`, `Tests/mutations/SuiteUI.ToolKeys.json` | – | ~300, 8 |
| AC-t2 | – | **tools delete.** Removes the lookup at `FlareStage.swift:86`, `DesignCanvas.swift:85`, `PhotoEditor.swift:163` and the flag conversions at `FlareStage.swift:59`, `DesignIntent.swift:107`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareApp/FlareStage.swift`, `Sources/DesignApp/DesignCanvas.swift`, `Sources/DesignApp/DesignIntent.swift`, `Sources/PhotoApp/PhotoEditor.swift` | AC-t1 | ~200, 4 |
| AC-g1 | – | **guides adapter.** `FlareStageGuides` draws `guides` as `SelectionOutline`-family marks (a `GuideLine` mark in the CanvasMarks family, added here as `Sources/SuiteUI/GuideLineMark.swift`), `showsGuides` gates it; a `needs-ui` issue asks canvas-marks for `CanvasViewport(showsRulers:)`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareApp/FlareStageGuides.swift`, `Sources/SuiteUI/GuideLineMark.swift`, `Tests/AppSnapshotTests/FlareStageGuideSnapshots.swift`, `Tests/SuiteUITests/GuideLineMarkTests.swift`, `Tests/mutations/SuiteUI.GuideLineMark.json` | – | ~300, 5 |
| AC-g2 | – | **guides delete.** Removes the `EmptyView` in `FlareStageGuides.swift` (the file becomes the bridge); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareApp/FlareStageGuides.swift`, `Sources/SuiteUI/GuideLineMark.swift` | AC-g1 | ~200, 2 |
| AC-e1 | – | **export sheet adapter.** `PhotoWindow+Export` presents `ExportSheet(choices: [PNG, JPEG], size:, quality:, run:)`, `LibraryWindow+Export` presents it with the long-edge row and the folder, `FlareWindow+Export` with the frame range and scale rows (its first real export UI, on the fake exporter until F15a). The app's existing tests pass unchanged; a new plan on the adapter | `Sources/PhotoApp/ExportSheet.swift`, `Sources/PhotoApp/PhotoWindow+Export.swift`, `Sources/LibraryApp/LibraryExportSheet.swift`, `Sources/LibraryApp/LibraryWindow+Export.swift`, `Sources/FlareApp/FlareWindow+Export.swift`, `Tests/AppSnapshotTests/PhotoExportSheetSnapshots.swift`, `Tests/AppSnapshotTests/LibraryExportSnapshots.swift`, `Tests/AppSnapshotTests/FlareExportSnapshots.swift`, `Tests/mutations/SuiteUI.ExportSheet.json` | – | ~300, 9 |
| AC-e2 | – | **export sheet delete.** Removes `Sources/PhotoApp/ExportSheet.swift`, `Sources/LibraryApp/LibraryExportSheet.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/PhotoApp/ExportSheet.swift`, `Sources/PhotoApp/PhotoWindow+Export.swift`, `Sources/LibraryApp/LibraryExportSheet.swift`, `Sources/LibraryApp/LibraryWindow+Export.swift`, `Sources/FlareApp/FlareWindow+Export.swift` | AC-e1 | ~200, 5 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AC-z1, AC-c1, AC-t1, AC-g1, AC-e1. Independent in this wave: all.
- Wave 2: AC-z2, AC-c2, AC-t2, AC-g2, AC-e2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AC-z1 → AC-z2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AC-z1 | `DesignWindowZoomTests`, `PhotoWindowZoomTests`, `HaloKeyByDragTests`, `ViewerDraggingContractTests` (unchanged) and `scripts/mutate --plan HaloModel.KernelZoomAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AC-z2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AC-c1 | `HexColorParserTests`, `DesignStyleTests`, `DesignInspectorSnapshots` (unchanged) and `scripts/mutate --plan SuiteUI.HexColor` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AC-c2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AC-t1 | `FlareToolsKeyTests`, `DesignToolsKeyTests`, `PhotoToolsKeyTests` (unchanged) and `scripts/mutate --plan SuiteUI.ToolKeys` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AC-t2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AC-g1 | `FlareStageGuideSnapshots`, `GuideLineMarkTests` (unchanged) and `scripts/mutate --plan SuiteUI.GuideLineMark` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AC-g2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AC-e1 | `PhotoExportSheetSnapshots`, `LibraryExportSnapshots`, `FlareExportSnapshots` (unchanged) and `scripts/mutate --plan SuiteUI.ExportSheet` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AC-e2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
