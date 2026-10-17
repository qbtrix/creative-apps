# Feature packet: adopt-kernel-transform

**Feature:** Design's, Photo's and Flare's box transform math runs on SuiteKernel's BoxMath; the app copies are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`EditorHandle`, `BoxMath`, `HandleHit` and `LayerTransform`) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-transform`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"transform") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-box`
(`Belt-Slice-Done: EK-box`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AT-design:** `DesignNode.swift` is shared with adopt-kernel-layers' Design slice (that one first); `DesignCanvasEditing.swift` is taken after design-seams-2 and adopt-kernel-selection's Design slice.
- **AT-photo:** all three files are owned by photo-seams: start after its slice on them.
- **AT-flare:** `BoxGestureMath.swift` is owned by Flare's stage-edit: start after its slice on it.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AT-design | Design runs its transform on `EditorHandle`, `BoxMath`, `HandleHit` and `LayerTransform` behind its existing API, its tests and journeys green, and its copy is deleted. | AT-d1, AT-d2 | DesignModelTests | editor-kernel:EK-box |
| AT-photo | Photo runs its transform on `EditorHandle`, `BoxMath`, `HandleHit` and `LayerTransform` behind its existing API, its tests and journeys green, and its copy is deleted. | AT-p1, AT-p2 | PhotoModelTests | editor-kernel:EK-box |
| AT-flare | Flare runs its transform on `EditorHandle`, `BoxMath`, `HandleHit` and `LayerTransform` behind its existing API, its tests and journeys green, and its copy is deleted. | AT-f1, AT-f2 | FlareModelTests | editor-kernel:EK-box |

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

None added: the kernel's contract is editor-kernel's `EK-box` (its
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
| AT-d1 | – | **Design adapter.** `DesignHandle` is `EditorHandle` (the eight cases), `DesignRect.resized(_:by:keepAspect:fromCenter:)` calls `BoxMath.resized` with `EditModifiers`, `handles(size:)` calls `BoxMath.handles`, `handle(at:)` calls `HandleHit.handle` with `handleTolerance`, `LiveTransforming.scaled` calls `BoxMath.scaled`; `DesignModifiers` is `EditModifiers`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/Live/LiveTransforming.swift`, `Sources/DesignModel/DesignCanvasEditing.swift`, `Tests/DesignModelTests/DesignResizeTests.swift`, `Tests/DesignModelTests/DesignSeveralTransformTests.swift`, `Tests/DesignModelTests/DesignCompactSelectionTests.swift`, `Tests/DesignModelTests/DesignCanvasTests.swift`, `Tests/mutations/DesignModel.KernelTransformAdapter.json` | – | ~300, 8 |
| AT-d2 | – | **Design delete.** Removes the box math in `DesignNode.swift` (`resized`, `handles`), `scaled` in `LiveTransforming.swift`, the handle hit in `DesignCanvasEditing.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/Live/LiveTransforming.swift`, `Sources/DesignModel/DesignCanvasEditing.swift`, `Tests/mutations/DesignModel.LiveTransforming.json`, `Tests/mutations/DesignModel.DesignNode.json` | AT-d1 | ~200, 5 |
| AT-p1 | – | **Photo adapter.** `TransformHandle` is `EditorHandle`, `LayerTransform` is the kernel's, `LayerTransforming.handle(at:in:tolerance:)` calls `HandleHit`, `dragged` calls `BoxMath.resized` and `snappedDegrees`; `LiveTransform` stays `NotBuilt` for `applied`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/PhotoModel/PhotoTransform.swift`, `Sources/PhotoModel/Live/LiveTransform.swift`, `Sources/PhotoModel/Contracts/PhotoContractTypes.swift`, `Tests/PhotoModelTests/PhotoMoveTests.swift`, `Tests/PhotoModelTests/PhotoDragRoutingTests.swift`, `Tests/mutations/PhotoModel.KernelTransformAdapter.json` | – | ~300, 6 |
| AT-p2 | – | **Photo delete.** Removes `PhotoTransform.swift`'s no-op and the handle enum in `Contracts/CropContracts.swift`'s neighbour `PhotoContractTypes.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/PhotoModel/PhotoTransform.swift`, `Sources/PhotoModel/Live/LiveTransform.swift`, `Sources/PhotoModel/Contracts/PhotoContractTypes.swift`, `Tests/mutations/PhotoModel.PhotoTransform.json` | AT-p1 | ~200, 4 |
| AT-f1 | – | **Flare adapter.** `BoxGestureMath` keeps its FlareCore placement and oblique fit but takes handle numbering, the mirror and zero-size guards from `EditorHandle` and `BoxMath` (#655/#688/#698 stay as its tests). The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareModel/Live/BoxGestureMath.swift`, `Tests/FlareModelTests/BoxGestureMathTests.swift`, `Tests/FlareModelTests/LiveShapesBoxTests.swift`, `Tests/mutations/FlareModel.KernelTransformAdapter.json` | – | ~300, 4 |
| AT-f2 | – | **Flare delete.** Removes the handle index arithmetic and guards in `BoxGestureMath.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareModel/Live/BoxGestureMath.swift`, `Tests/mutations/FlareModel.BoxGestureMath.json` | AT-f1 | ~200, 2 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AT-d1, AT-p1, AT-f1. Independent in this wave: all.
- Wave 2: AT-d2, AT-p2, AT-f2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AT-d1 → AT-d2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AT-d1 | `DesignResizeTests`, `DesignSeveralTransformTests`, `DesignCompactSelectionTests`, `DesignCanvasTests` (unchanged) and `scripts/mutate --plan DesignModel.KernelTransformAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AT-d2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AT-p1 | `PhotoMoveTests`, `PhotoDragRoutingTests` (unchanged) and `scripts/mutate --plan PhotoModel.KernelTransformAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AT-p2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AT-f1 | `BoxGestureMathTests`, `LiveShapesBoxTests` (unchanged) and `scripts/mutate --plan FlareModel.KernelTransformAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AT-f2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
