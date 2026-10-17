# Feature packet: adopt-kernel-undo

**Feature:** Every app's undo runs on SuiteKernel's History; the four app history engines are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`History<Payload>` and `HistoryReading`) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-undo`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"undo") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-undo`
(`Belt-Slice-Done: EK-undo`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AU-design:** `DesignHistory.swift` is owned by design-seams-2 and files-history: this slice starts once both have merged their edits to it (their `Belt-Slice-Done:` lines), and `DesignWorkspace.swift` after design-window.
- **AU-photo:** `PhotoWorkspace.swift` is owned by photo-seams: this slice starts once photo-seams has merged its edits to it.
- **AU-library:** `CatalogHistory.swift` is owned by filters-collections and spine; `LibraryReadouts.swift` has a plan whose `find` lines this slice repoints in the same PR.
- **AU-halo:** `LiveProjectHistory.swift` is owned by history-files and foundation (both built); `HaloProject.swift` by foundation. Halo's `c4-planned.json` has `owned_files_planned`, so the deleted file leaves its component's paths in the same PR.
- **AU-flare:** `FlareWorkspace.swift` is owned by Flare's stage-edit and layers-files packets: this slice starts after their `Belt-Slice-Done:` lines on the file.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AU-design | Design runs its undo on `History<Payload>` and `HistoryReading` behind its existing API, its tests and journeys green, and its copy is deleted. | AU-d1, AU-d2 | DesignModelTests | editor-kernel:EK-undo |
| AU-photo | Photo runs its undo on `History<Payload>` and `HistoryReading` behind its existing API, its tests and journeys green, and its copy is deleted. | AU-p1, AU-p2 | PhotoModelTests | editor-kernel:EK-undo |
| AU-library | Library runs its undo on `History<Payload>` and `HistoryReading` behind its existing API, its tests and journeys green, and its copy is deleted. | AU-l1, AU-l2 | LibraryModelTests | editor-kernel:EK-undo |
| AU-halo | Halo runs its undo on `History<Payload>` and `HistoryReading` behind its existing API, its tests and journeys green, and its copy is deleted. | AU-h1, AU-h2 | HaloModelTests | editor-kernel:EK-undo |
| AU-flare | Flare runs its undo on `History<Payload>` and `HistoryReading` behind its existing API, its tests and journeys green, and its copy is deleted. | AU-f1, AU-f2 | FlareModelTests | editor-kernel:EK-undo |

There is no new screen: every slice is Model-only (`"ui_slice": "none"`),
and a slice that touches `Sources/*App/` or `Sources/SuiteUI/` to keep an
existing view compiling is marked `"ui": true` with the view's existing
render budget as its row. The acceptance tests are the app's existing Model
tests and journeys, which merged long before this feature (rule 13 holds by
construction), plus a mutation plan on each adapter (rule 14).

## Journey steps

The app's existing journeys, unchanged, on the scoped run after each
slice's last PR: the app opens a document, edits with the concept
(undo, select, reorder, ease, resize, export, save), and the journey's
readouts match what they matched before.

## Screens and states

None new. The snapshots the deleted files fed must not change: the Mac
finisher diffs the app's existing PNGs against the previous dev run.

## Contract slice

None added: the kernel's contract is editor-kernel's `EK-undo` (its
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
| AU-d1 | – | **Design adapter.** `DesignHistory` becomes `History<DesignSnapshot>` behind the same `undo()`, `redo()`, `endEditRun()`, `canUndo`, `undoActionName`, `undoSwapsDocument`; the URL swap and the id-counter max stay in the apply closure. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/DesignModel/DesignHistory.swift`, `Sources/DesignModel/DesignWorkspace.swift`, `Tests/DesignModelTests/DesignUndoTests.swift`, `Tests/DesignModelTests/DesignUndoSwapEdgeTests.swift`, `Tests/DesignModelTests/DesignGestureTests.swift`, `Tests/mutations/DesignModel.KernelUndoAdapter.json` | – | ~300, 6 |
| AU-d2 | – | **Design delete.** Removes the stack, run and limit code in `DesignHistory.swift` (the file keeps the Design-specific swap step and the `HistoryReading` conformance); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/DesignModel/DesignHistory.swift`, `Sources/DesignModel/DesignWorkspace.swift`, `Tests/mutations/DesignModel.DesignHistory.json` | AU-d1 | ~200, 3 |
| AU-p1 | – | **Photo adapter.** `PhotoHistory` becomes `History<PhotoEdit>`; `apply(edit)` is the closure (it already returns the inverse); `currentStepID`, `isDirty`, `historySteps`, `historyIndex`, `jumpToHistoryStep` read the kernel; `endAdjust()` calls `endRun()`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/PhotoModel/PhotoHistory.swift`, `Sources/PhotoModel/PhotoWorkspace.swift`, `Tests/PhotoModelTests/PhotoHistoryStepsTests.swift`, `Tests/PhotoModelTests/PhotoHistoryTests.swift`, `Tests/PhotoModelTests/PhotoStepIDTests.swift`, `Tests/PhotoModelTests/PhotoSliderGestureUndoTests.swift`, `Tests/mutations/PhotoModel.KernelUndoAdapter.json` | – | ~300, 7 |
| AU-p2 | – | **Photo delete.** Removes the stack, id, base and jump code in `PhotoHistory.swift`; the run-not-ended-on-undo gap goes with it; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/PhotoModel/PhotoHistory.swift`, `Sources/PhotoModel/PhotoWorkspace.swift`, `Tests/mutations/PhotoModel.PhotoHistory.json` | AU-p1 | ~200, 3 |
| AU-l1 | – | **Library adapter.** `CatalogHistory` becomes `History<[PhotoItem]>` (before and after lists as the payload) behind `undo()`, `redo()`, `endCoalescing()`, `undoTitle`; the catalog gains the 100-step limit and reads dirty from the saved step id instead of `saveRevision`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/LibraryModel/CatalogHistory.swift`, `Sources/LibraryModel/LibraryCulling.swift`, `Sources/LibraryModel/LibraryReadouts.swift`, `Tests/LibraryModelTests/LibraryHistoryTests.swift`, `Tests/mutations/LibraryModel.KernelUndoAdapter.json` | – | ~300, 5 |
| AU-l2 | – | **Library delete.** Removes `CatalogHistory.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/LibraryModel/CatalogHistory.swift`, `Sources/LibraryModel/LibraryCulling.swift`, `Sources/LibraryModel/LibraryReadouts.swift`, `Tests/mutations/LibraryModel.LibraryReadouts.json`, `Tests/mutations/LibraryModel.CatalogHistory.json` | AU-l1 | ~200, 5 |
| AU-h1 | – | **Halo adapter.** `ProjectHistory` (live and fake) wraps `History<HaloDocumentState>`; `HaloProject.edit` records through it; `file.unsaved` reads the kernel's `isDirty`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/HaloModel/Live/HaloHistoryRules.swift`, `Sources/HaloModel/Live/LiveProjectHistory.swift`, `Sources/HaloModel/Fakes/FakeProjectHistory.swift`, `Sources/HaloModel/HaloHistory.swift`, `Sources/HaloModel/HaloProject.swift`, `Tests/HaloModelTests/ProjectHistoryContractTests.swift`, `Tests/HaloModelTests/HaloUndoTests.swift`, `Tests/HaloModelTests/HaloHistoryCommandTests.swift`, `Tests/mutations/HaloModel.KernelUndoAdapter.json` | – | ~300, 9 |
| AU-h2 | – | **Halo delete.** Removes `HaloHistoryRules.swift` and the stack code in `HaloHistory` (`HaloDocumentValues.swift`); `LiveProjectHistory` and `FakeProjectHistory` shrink to the conformance; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/HaloModel/Live/HaloHistoryRules.swift`, `Sources/HaloModel/Live/LiveProjectHistory.swift`, `Sources/HaloModel/Fakes/FakeProjectHistory.swift`, `Sources/HaloModel/HaloHistory.swift`, `Sources/HaloModel/HaloProject.swift`, `Tests/mutations/HaloModel.HaloHistory.json` | AU-h1 | ~200, 6 |
| AU-f1 | – | **Flare adapter.** `FlareWorkspace` conforms to `HistoryReading` over `CommandEngine` (`canUndo`, `undoName`, `isDirty`), so the shared Edit menu reads one protocol; `CommandEngine` stays. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareModel/FlareWorkspace.swift`, `Tests/FlareModelTests/SceneUndoSelectionTests.swift`, `Tests/FlareModelTests/FlareLiveDragTests.swift`, `Tests/mutations/FlareModel.KernelUndoAdapter.json` | – | ~300, 4 |
| AU-f2 | – | **Flare delete.** Removes nothing: Flare's engine is FlareCore's; the slice only removes the Flare-only `undoActionName`/`redoActionName` spelling in favour of the protocol's; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareModel/FlareWorkspace.swift`, `Tests/mutations/FlareModel.FlareWorkspace.json` | AU-f1 | ~200, 2 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AU-d1, AU-p1, AU-l1, AU-h1, AU-f1. Independent in this wave: all.
- Wave 2: AU-d2, AU-p2, AU-l2, AU-h2, AU-f2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AU-d1 → AU-d2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AU-d1 | `DesignUndoTests`, `DesignUndoSwapEdgeTests`, `DesignGestureTests` (unchanged) and `scripts/mutate --plan DesignModel.KernelUndoAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AU-d2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AU-p1 | `PhotoHistoryStepsTests`, `PhotoHistoryTests`, `PhotoStepIDTests`, `PhotoSliderGestureUndoTests` (unchanged) and `scripts/mutate --plan PhotoModel.KernelUndoAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AU-p2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AU-l1 | `LibraryHistoryTests` (unchanged) and `scripts/mutate --plan LibraryModel.KernelUndoAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AU-l2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AU-h1 | `ProjectHistoryContractTests`, `HaloUndoTests`, `HaloHistoryCommandTests` (unchanged) and `scripts/mutate --plan HaloModel.KernelUndoAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AU-h2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AU-f1 | `SceneUndoSelectionTests`, `FlareLiveDragTests` (unchanged) and `scripts/mutate --plan FlareModel.KernelUndoAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AU-f2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
