# Feature packet: adopt-kernel-export

**Feature:** Flare's, Photo's and Library's export state runs on SuiteKernel's ExportRun; the two app state machines and Photo's Bool are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`ExportRun<Options>`) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-export`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"export") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-run`
(`Belt-Slice-Done: EK-run`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AX-flare:** `FlareWorkspaceState.swift` is owned by Flare's stage-edit and export packets: start after their slices on it.
- **AX-photo:** `PhotoWorkspace.swift` is owned by photo-seams and shared with adopt-kernel-undo's and adopt-kernel-layers' Photo slices: the three chain in that order.
- **AX-library:** `LibraryCatalog.swift` is owned by Library's export and spine packets and shared with adopt-kernel-selection's Library slice (that one first). `every_source_file_owned` holds for Library.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AX-flare | Flare runs its export on `ExportRun<Options>` behind its existing API, its tests and journeys green, and its copy is deleted. | AX-f1, AX-f2 | MJ-AX-flare | editor-kernel:EK-run |
| AX-photo | Photo runs its export on `ExportRun<Options>` behind its existing API, its tests and journeys green, and its copy is deleted. | AX-p1, AX-p2 | MJ-AX-photo | editor-kernel:EK-run, adopt-kernel-layers:AL-photo |
| AX-library | Library runs its export on `ExportRun<Options>` behind its existing API, its tests and journeys green, and its copy is deleted. | AX-l1, AX-l2 | MJ-AX-library | editor-kernel:EK-run, adopt-kernel-selection:AS-library |

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
- `MJ-AX-flare`: `ExportScanTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AX-photo`: `PhotoExportTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AX-library`: `LibraryServicesTests` (existing), green on the Linux job after both tasks merge.

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
| AX-f1 | – | **Flare adapter.** `ExportState` is `ExportRun<ExportOptions>`; `beginExport`, `exportProgressed(_ fraction:)` (mapped to `done` of 1000), `endExport`, `dismissExport` keep their signatures. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareModel/FlareExport.swift`, `Sources/FlareModel/FlareWorkspaceState.swift`, `Tests/FlareModelTests/ExportScanTests.swift`, `Tests/mutations/FlareModel.KernelExportAdapter.json` | – | ~300, 4 |
| AX-f2 | – | **Flare delete.** Removes the run code in `FlareExport.swift` and `ExportState` in `FlareWorkspaceState.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareModel/FlareExport.swift`, `Sources/FlareModel/FlareWorkspaceState.swift`, `Tests/mutations/FlareModel.FlareExport.json` | AX-f1 | ~200, 3 |
| AX-p1 | – | **Photo adapter.** `PhotoWorkspace.exportRun: ExportRun<ExportOptions>` replaces `isExporting`; `ExportSheet` reads `.editing`/`.running` through the Model's existing readouts. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/PhotoModel/PhotoWorkspace.swift`, `Sources/PhotoModel/Contracts/OutputContracts.swift`, `Tests/PhotoModelTests/PhotoExportTests.swift`, `Tests/mutations/PhotoModel.KernelExportAdapter.json` | – | ~300, 4 |
| AX-p2 | – | **Photo delete.** Removes `isExporting` and its setters in `PhotoWorkspace.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/PhotoModel/PhotoWorkspace.swift`, `Sources/PhotoModel/Contracts/OutputContracts.swift`, `Tests/mutations/PhotoModel.OutputContracts.json` | AX-p1 | ~200, 3 |
| AX-l1 | – | **Library adapter.** `LibraryCatalog.ExportState` is `ExportRun<ExportOptions>` with `done/total` as today; `ExportSummary` is the `finished` payload. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/LibraryModel/LibraryCatalog.swift`, `Tests/LibraryModelTests/LibraryServicesTests.swift`, `Tests/LibraryModelTests/LibraryFakeRenderingTests.swift`, `Tests/mutations/LibraryModel.KernelExportAdapter.json` | – | ~300, 4 |
| AX-l2 | – | **Library delete.** Removes the `ExportState` enum in `LibraryCatalog.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/LibraryModel/LibraryCatalog.swift`, `Tests/mutations/LibraryModel.LibraryCatalog.json` | AX-l1 | ~200, 2 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AX-f1, AX-p1, AX-l1. Independent in this wave: all.
- Wave 2: AX-f2, AX-p2, AX-l2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AX-f1 → AX-f2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AX-f1 | `ExportScanTests` (unchanged) and `scripts/mutate --plan FlareModel.KernelExportAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AX-f2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AX-p1 | `PhotoExportTests` (unchanged) and `scripts/mutate --plan PhotoModel.KernelExportAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AX-p2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AX-l1 | `LibraryServicesTests`, `LibraryFakeRenderingTests` (unchanged) and `scripts/mutate --plan LibraryModel.KernelExportAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AX-l2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
