# Feature packet: adopt-kernel-session

**Feature:** Every app's dirty rule, save status, autosave timing, recovery offer and version probe run on SuiteKernel's DocumentSession; the five copies are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`DocumentSession`, `SaveStatus`, `RecoveryOffer` and `VersionedJSON`) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-session`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"session") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-doc`
(`Belt-Slice-Done: EK-doc`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AD-flare:** `FlareFiles.swift` is owned by layers-files; this slice edits `Sources/FlareApp/FlareAutosave.swift`, so it is `"ui": true` with no new screen (the budget row is the file menu's existing one).
- **AD-photo:** all three are owned by photo-seams: start after its slice on them.
- **AD-halo:** all three are owned by history-files (built). `owned_files_planned` holds for Halo.
- **AD-design:** both files are owned by files-history: start after its slice on them.
- **AD-library:** `LibraryReadouts.swift` is shared with adopt-kernel-undo's Library slice (that one first); `LiveCatalogCoding.swift` is owned by spine. `every_source_file_owned` holds for Library.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AD-flare | Flare runs its session on `DocumentSession`, `SaveStatus`, `RecoveryOffer` and `VersionedJSON` behind its existing API, its tests and journeys green, and its copy is deleted. | AD-f1, AD-f2 | MJ-AD-flare | editor-kernel:EK-doc |
| AD-photo | Photo runs its session on `DocumentSession`, `SaveStatus`, `RecoveryOffer` and `VersionedJSON` behind its existing API, its tests and journeys green, and its copy is deleted. | AD-p1, AD-p2 | MJ-AD-photo | editor-kernel:EK-doc |
| AD-halo | Halo runs its session on `DocumentSession`, `SaveStatus`, `RecoveryOffer` and `VersionedJSON` behind its existing API, its tests and journeys green, and its copy is deleted. | AD-h1, AD-h2 | MJ-AD-halo | editor-kernel:EK-doc |
| AD-design | Design runs its session on `DocumentSession`, `SaveStatus`, `RecoveryOffer` and `VersionedJSON` behind its existing API, its tests and journeys green, and its copy is deleted. | AD-d1, AD-d2 | MJ-AD-design | editor-kernel:EK-doc |
| AD-library | Library runs its session on `DocumentSession`, `SaveStatus`, `RecoveryOffer` and `VersionedJSON` behind its existing API, its tests and journeys green, and its copy is deleted. | AD-l1, AD-l2 | MJ-AD-library | editor-kernel:EK-doc, adopt-kernel-undo:AU-library |

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
- `MJ-AD-flare`: `FlareFilesTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AD-photo`: `PhotoRecoveryTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AD-halo`: `HaloFileTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AD-design`: `DesignFileTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AD-library`: `LibraryCatalogTests` (existing), green on the Linux job after both tasks merge.

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
| AD-f1 | – | **Flare adapter.** `FlareFiles` reads `isDirty` from a `DocumentSession` whose tokens are the engine's step count, `autosaveDue(lastEdit:now:)` calls the kernel with a 30 s delay, recents go through `RecentsList`, the recovery prompt is a `RecoveryOffer`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareModel/FlareFiles.swift`, `Sources/FlareApp/FlareAutosave.swift`, `Tests/FlareModelTests/FlareFilesTests.swift`, `Tests/FlareModelTests/FlareAutosaveDueTests.swift`, `Tests/FlareModelTests/FlareRecoveryRestoreTests.swift`, `Tests/mutations/FlareModel.KernelSessionAdapter.json` | – | ~300, 6 |
| AD-f2 | – | **Flare delete.** Removes the dirty, due and recents code in `FlareFiles.swift` and `FlareAutosave.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareModel/FlareFiles.swift`, `Sources/FlareApp/FlareAutosave.swift`, `Tests/mutations/FlareModel.FlareFiles.json` | AD-f1 | ~200, 3 |
| AD-p1 | – | **Photo adapter.** `PhotoRecovery`'s `autosaveDue(lastEdit:lastAutosave:now:delay:)` and `RecoveryOffer` are the kernel's; `PhotoSaveStatus` maps to `SaveStatus`; dirty reads the session whose tokens are the history step ids; `LiveArchive`'s version probe calls `VersionedJSON.probe`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/PhotoModel/PhotoRecovery.swift`, `Sources/PhotoModel/Live/LiveArchive.swift`, `Sources/PhotoModel/PhotoSaveStatusHelp.swift`, `Tests/PhotoModelTests/PhotoRecoveryTests.swift`, `Tests/PhotoModelTests/LiveRecoveryTests.swift`, `Tests/PhotoModelTests/PhotoDocumentFileTests.swift`, `Tests/PhotoModelTests/PhotoSaveStatusHelpTests.swift`, `Tests/mutations/PhotoModel.KernelSessionAdapter.json` | – | ~300, 8 |
| AD-p2 | – | **Photo delete.** Removes the due and offer code in `PhotoRecovery.swift`, the `VersionEntry` probe in `LiveArchive.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/PhotoModel/PhotoRecovery.swift`, `Sources/PhotoModel/Live/LiveArchive.swift`, `Sources/PhotoModel/PhotoSaveStatusHelp.swift`, `Tests/mutations/PhotoModel.PhotoRecovery.json` | AD-p1 | ~200, 4 |
| AD-h1 | – | **Halo adapter.** `HaloFiles` reads `file.unsaved` from a `DocumentSession` over the history step id, `saveStatus`/`windowSubtitle` from `SaveStatus`, recents through `RecentsList`; `HaloFileEnvelope` probes with `VersionedJSON.probe` and words errors with `VersionedJSON.words`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/HaloModel/HaloFiles.swift`, `Sources/HaloModel/Live/HaloFileEnvelope.swift`, `Sources/HaloModel/Live/HaloFileValidation.swift`, `Tests/HaloModelTests/HaloFileTests.swift`, `Tests/HaloModelTests/HaloFileValidationTests.swift`, `Tests/HaloModelTests/ProjectFilesContractTests.swift`, `Tests/mutations/HaloModel.KernelSessionAdapter.json` | – | ~300, 7 |
| AD-h2 | – | **Halo delete.** Removes the unsaved flag, recents and probe code in `HaloFiles.swift`, `HaloFileEnvelope.swift`, `HaloFileValidation.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/HaloModel/HaloFiles.swift`, `Sources/HaloModel/Live/HaloFileEnvelope.swift`, `Sources/HaloModel/Live/HaloFileValidation.swift`, `Tests/mutations/HaloModel.HaloFiles.json` | AD-h1 | ~200, 4 |
| AD-d1 | – | **Design adapter.** `DesignFile` probes with `VersionedJSON.probe`; the workspace gains a `DocumentSession` over the history step id, so `isDirty` exists for #270 and `didSave(to:)` sets the saved token. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/DesignModel/DesignFile.swift`, `Sources/DesignModel/Live/LiveFiling.swift`, `Tests/DesignModelTests/DesignFileTests.swift`, `Tests/DesignModelTests/DesignDocumentTests.swift`, `Tests/mutations/DesignModel.KernelSessionAdapter.json` | – | ~300, 5 |
| AD-d2 | – | **Design delete.** Removes `DesignFileHeader`'s probe in `DesignFile.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/DesignModel/DesignFile.swift`, `Sources/DesignModel/Live/LiveFiling.swift`, `Tests/mutations/DesignModel.LiveFiling.json` | AD-d1 | ~200, 3 |
| AD-l1 | – | **Library adapter.** `LibraryReadouts` reads dirty from a `DocumentSession` whose tokens are the history step ids instead of `saveRevision`; `LiveCatalogCoding` probes with `VersionedJSON.probe`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/LibraryModel/LibraryReadouts.swift`, `Sources/LibraryModel/Live/LiveCatalogCoding.swift`, `Tests/LibraryModelTests/LibraryCatalogTests.swift`, `Tests/LibraryModelTests/LibraryReadoutsTests.swift`, `Tests/mutations/LibraryModel.KernelSessionAdapter.json` | – | ~300, 5 |
| AD-l2 | – | **Library delete.** Removes `saveRevision`/`savedRevision` in `LibraryReadouts.swift` and the catalog; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/LibraryModel/LibraryReadouts.swift`, `Sources/LibraryModel/Live/LiveCatalogCoding.swift`, `Tests/mutations/LibraryModel.LibraryReadouts.json` | AD-l1 | ~200, 3 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AD-f1, AD-p1, AD-h1, AD-d1, AD-l1. Independent in this wave: all.
- Wave 2: AD-f2, AD-p2, AD-h2, AD-d2, AD-l2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AD-f1 → AD-f2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AD-f1 | `FlareFilesTests`, `FlareAutosaveDueTests`, `FlareRecoveryRestoreTests` (unchanged) and `scripts/mutate --plan FlareModel.KernelSessionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AD-f2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AD-p1 | `PhotoRecoveryTests`, `LiveRecoveryTests`, `PhotoDocumentFileTests`, `PhotoSaveStatusHelpTests` (unchanged) and `scripts/mutate --plan PhotoModel.KernelSessionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AD-p2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AD-h1 | `HaloFileTests`, `HaloFileValidationTests`, `ProjectFilesContractTests` (unchanged) and `scripts/mutate --plan HaloModel.KernelSessionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AD-h2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AD-d1 | `DesignFileTests`, `DesignDocumentTests` (unchanged) and `scripts/mutate --plan DesignModel.KernelSessionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AD-d2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AD-l1 | `LibraryCatalogTests`, `LibraryReadoutsTests` (unchanged) and `scripts/mutate --plan LibraryModel.KernelSessionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AD-l2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
