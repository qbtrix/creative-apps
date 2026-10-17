# Feature packet: adopt-kernel-selection

**Feature:** Every app's selection set, marquee rule and nudge run on SuiteKernel's Selection; the app copies are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`Selection<ID>`, `Pick`, `Nudge` and `Marquee`) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-selection`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"selection") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-sel`
(`Belt-Slice-Done: EK-sel`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AS-flare:** `FlareSelection.swift` is owned by stage-edit; start after its `Belt-Slice-Done:` on the file.
- **AS-design:** `DesignSelection.swift` is owned by design-contracts (built), design-window and select-several; `DesignCanvasEditing.swift` passes design-seams → canvas-basics → select-several → snapping → design-seams-2, so this slice takes the file after design-seams-2's D2-3b.
- **AS-halo:** `HaloKeySelection.swift` is owned by Halo's easing packet (built) and shared with adopt-kernel-easing's Halo slice: the two slices chain, this one first.
- **AS-library:** `GridSelection.swift` and `ThumbnailGrid.swift` are owned by lists-and-layers (wave 2, planned): this slice waits for lists-and-layers to be built, and because it edits `Sources/SuiteUI/` it is `"ui": true` with the grid's existing render budget as its row. Library's `c4-planned.json` has `every_source_file_owned`.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AS-flare | Flare runs its selection on `Selection<ID>`, `Pick`, `Nudge` and `Marquee` behind its existing API, its tests and journeys green, and its copy is deleted. | AS-f1, AS-f2 | FlareModelTests | editor-kernel:EK-sel |
| AS-design | Design runs its selection on `Selection<ID>`, `Pick`, `Nudge` and `Marquee` behind its existing API, its tests and journeys green, and its copy is deleted. | AS-d1, AS-d2 | DesignModelTests | editor-kernel:EK-sel |
| AS-halo | Halo runs its selection on `Selection<ID>`, `Pick`, `Nudge` and `Marquee` behind its existing API, its tests and journeys green, and its copy is deleted. | AS-h1, AS-h2 | HaloModelTests | editor-kernel:EK-sel |
| AS-library | Library runs its selection on `Selection<ID>`, `Pick`, `Nudge` and `Marquee` behind its existing API, its tests and journeys green, and its copy is deleted. | AS-l1, AS-l2 | LibraryModelTests | editor-kernel:EK-sel |

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

None added: the kernel's contract is editor-kernel's `EK-sel` (its
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
| AS-f1 | – | **Flare adapter.** `FlareWorkspace.selection` is a `Selection<StageAddress>`; `select(_:extending:)`, `setSelection`, `selectAll`, `deselect`, `selectedLayerIDs`, `selectionBounds` keep their signatures; `endSelect` uses `Marquee.union`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareModel/FlareSelection.swift`, `Tests/FlareModelTests/WorkspaceWiringTests.swift`, `Tests/FlareModelTests/SymbolEditSelectionTests.swift`, `Tests/FlareModelTests/J5MarqueeAdversarialTests.swift`, `Tests/mutations/FlareModel.KernelSelectionAdapter.json` | – | ~300, 5 |
| AS-f2 | – | **Flare delete.** Removes the set logic in `FlareSelection.swift` (the file keeps the `StageAddress` hit routing); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareModel/FlareSelection.swift`, `Tests/mutations/FlareModel.FlareSelection.json` | AS-f1 | ~200, 2 |
| AS-d1 | – | **Design adapter.** `DesignWorkspace.selectedNodeIDs` is a `Selection<String>` with `canAdd` = not effectively hidden or locked; `toggleSelection`, `selectItem`, `deselect`, `selectAll`, `selectedNodeID`, `hasMultipleSelection` keep their signatures; a change calls `history.endRun()`; `nudge` uses `Nudge.delta` and `Nudge.runKey`; `beginGesture` wires `MarqueeSelecting` through `Marquee.rect` and `Marquee.union` (the engine that was never called). The app's existing tests pass unchanged; a new plan on the adapter | `Sources/DesignModel/DesignSelection.swift`, `Sources/DesignModel/DesignCanvasEditing.swift`, `Sources/DesignModel/DesignActions.swift`, `Tests/DesignModelTests/DesignMultiSelectTests.swift`, `Tests/DesignModelTests/DesignSelectionRunTests.swift`, `Tests/DesignModelTests/DesignMarqueeTests.swift`, `Tests/DesignModelTests/DesignActionsTests.swift`, `Tests/mutations/DesignModel.KernelSelectionAdapter.json` | – | ~300, 8 |
| AS-d2 | – | **Design delete.** Removes `DesignSelection.swift`'s set logic and `DesignDirection` (a typealias of `Direction`); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/DesignModel/DesignSelection.swift`, `Sources/DesignModel/DesignCanvasEditing.swift`, `Sources/DesignModel/DesignActions.swift`, `Tests/mutations/DesignModel.DesignSelection.json`, `Tests/mutations/DesignModel.DesignActions.json` | AS-d1 | ~200, 5 |
| AS-h1 | – | **Halo adapter.** `selectedKeys` is a `Selection<HaloKeyRef>` used as a set (`.toggle` for `selectKey(extending:)`, `.extend` without an order for `selectLaneKeys`), pruned with `prune(alive:)`; `pickedKeyframes`, `pickedSegment`, `clearKeySelection` keep their signatures. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/HaloModel/HaloKeySelection.swift`, `Tests/HaloModelTests/HaloKeySelectionTests.swift`, `Tests/mutations/HaloModel.KernelSelectionAdapter.json` | – | ~300, 3 |
| AS-h2 | – | **Halo delete.** Removes the set and prune code in `HaloKeySelection.swift` (the segment and handle code waits for adopt-kernel-easing); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/HaloModel/HaloKeySelection.swift`, `Tests/mutations/HaloModel.HaloKeySelection.json` | AS-h1 | ~200, 2 |
| AS-l1 | – | **Library adapter.** `LibraryCatalog.selection` is a `Selection<String>` with `anchor`; the grid reports `(id, Pick)` and the catalog calls `pick(_:_:order:)`; `move(_:order:columns:)` replaces `GridSelection.move`; `select(_:)`, `cullTargets` keep their signatures. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/LibraryModel/LibraryCatalog.swift`, `Sources/SuiteUI/GridSelection.swift`, `Sources/SuiteUI/ThumbnailGrid.swift`, `Tests/LibraryModelTests/LibraryGridTests.swift`, `Tests/LibraryModelTests/LibraryGridEdgeTests.swift`, `Tests/SuiteUITests/GridSelectionTests.swift`, `Tests/mutations/LibraryModel.KernelSelectionAdapter.json` | – | ~300, 7 |
| AS-l2 | – | **Library delete.** Removes the pick math in `Sources/SuiteUI/GridSelection.swift` (the file keeps `columns(width:minimum:spacing:)`), and `ThumbnailGrid`'s `@State` anchor; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/LibraryModel/LibraryCatalog.swift`, `Sources/SuiteUI/GridSelection.swift`, `Sources/SuiteUI/ThumbnailGrid.swift`, `Tests/mutations/LibraryModel.LibraryCatalog.json` | AS-l1 | ~200, 4 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AS-f1, AS-d1, AS-h1, AS-l1. Independent in this wave: all.
- Wave 2: AS-f2, AS-d2, AS-h2, AS-l2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AS-f1 → AS-f2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AS-f1 | `WorkspaceWiringTests`, `SymbolEditSelectionTests`, `J5MarqueeAdversarialTests` (unchanged) and `scripts/mutate --plan FlareModel.KernelSelectionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AS-f2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AS-d1 | `DesignMultiSelectTests`, `DesignSelectionRunTests`, `DesignMarqueeTests`, `DesignActionsTests` (unchanged) and `scripts/mutate --plan DesignModel.KernelSelectionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AS-d2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AS-h1 | `HaloKeySelectionTests` (unchanged) and `scripts/mutate --plan HaloModel.KernelSelectionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AS-h2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AS-l1 | `LibraryGridTests`, `LibraryGridEdgeTests`, `GridSelectionTests` (unchanged) and `scripts/mutate --plan LibraryModel.KernelSelectionAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AS-l2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
