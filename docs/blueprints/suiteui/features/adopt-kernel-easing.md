# Feature packet: adopt-kernel-easing

**Feature:** Flare's and Halo's keyframe and easing rules run on SuiteKernel's Keys; the two copies of the handle math and the key rules are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`KeyRef`, `Segment`, `KeyState`, `EasePreset`, `EaseCurve` and `KeyRules`) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-easing`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"easing") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-keys`
(`Belt-Slice-Done: EK-keys`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AE-flare:** these files are owned by inspector-timeline and live-keys (Flare): start after their slices on them.
- **AE-halo:** `HaloKeySelection.swift` follows adopt-kernel-selection's Halo slice; `HaloKeyRules.swift` is taken before adopt-kernel-layers' Halo slice. `owned_files_planned` holds for Halo.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AE-flare | Flare runs its easing on `KeyRef`, `Segment`, `KeyState`, `EasePreset`, `EaseCurve` and `KeyRules` behind its existing API, its tests and journeys green, and its copy is deleted. | AE-f1, AE-f2 | FlareModelTests | editor-kernel:EK-keys |
| AE-halo | Halo runs its easing on `KeyRef`, `Segment`, `KeyState`, `EasePreset`, `EaseCurve` and `KeyRules` behind its existing API, its tests and journeys green, and its copy is deleted. | AE-h1, AE-h2 | HaloModelTests | editor-kernel:EK-keys, adopt-kernel-selection:AS-halo |

There is no new screen (`"ui_slice": "none"`); a slice that touches
`Sources/*App/` (a layers panel becoming `LayerTreeList`, an autosave file) is
marked `"ui": true` with the view's existing render budget as its row, and
waits on editor-kernel's EK-u for the SuiteUI half. A slice that edits a file
another adopt slice also edits waits on that slice (the `waits` data). The acceptance tests are the app's existing Model
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

None added: the kernel's contract is editor-kernel's `EK-keys` (its
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
| AE-f1 | – | **Flare adapter.** `EasingSegment` is `Segment<String>`, `KeyRef` is the kernel's with `.all` for the summary key, `EasingPreset` is `EasePreset`; `EasingCurve` calls `EaseCurve`; `LiveEasing`, `FakeEasing`, `LiveKeyframes+Edit`, `LiveKeyframes+Frames` compute with `KeyRules` and emit FlareCore commands; `FakeKeyframes` runs on the same rules. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareModel/EasingEditing.swift`, `Sources/FlareModel/Live/LiveEasing.swift`, `Sources/FlareModel/Fakes/FakeEasing.swift`, `Sources/FlareModel/Live/LiveKeyframes+Edit.swift`, `Sources/FlareModel/Live/LiveKeyframes+Frames.swift`, `Sources/FlareModel/Fakes/FakeKeyframes.swift`, `Tests/FlareModelTests/EasingEditingContractTests.swift`, `Tests/FlareModelTests/FlareEasingTests.swift`, `Tests/FlareModelTests/LiveEasingTests.swift`, `Tests/FlareModelTests/LiveKeyframesEditTests.swift`, `Tests/FlareModelTests/LiveKeyframesFramesTests.swift`, `Tests/FlareModelTests/MoveKeysPastEndTests.swift`, `Tests/mutations/FlareModel.KernelEasingAdapter.json` | – | ~300, 13 |
| AE-f2 | – | **Flare delete.** Removes `EasingCurve` in `EasingEditing.swift`, the summary-key logic repeated in `FakeEasing`/`LiveEasing`, and the rule bodies in `LiveKeyframes+Edit.swift`, `LiveKeyframes+Frames.swift`, `FakeKeyframes.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareModel/EasingEditing.swift`, `Sources/FlareModel/Live/LiveEasing.swift`, `Sources/FlareModel/Fakes/FakeEasing.swift`, `Sources/FlareModel/Live/LiveKeyframes+Edit.swift`, `Sources/FlareModel/Live/LiveKeyframes+Frames.swift`, `Sources/FlareModel/Fakes/FakeKeyframes.swift`, `Tests/mutations/FlareModel.LiveEasing.json`, `Tests/mutations/FlareModel.LiveKeyframes+Edit.json` | AE-f1 | ~200, 8 |
| AE-h1 | – | **Halo adapter.** `HaloKeySegment` wraps `Segment<HaloProperty>`, `HaloKeyRef` is `KeyRef<HaloProperty>` (still `Codable`, same keys), `HaloEasingPreset` is `EasePreset` with Halo's five shown; `HaloEasing.handles`/`movingHandle` call `EaseCurve`; `HaloKeyRules` toggle, remove and state call `KeyRules` with `.propertyGoesStatic`, opacity's home and clamping stay as Halo hooks. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/HaloModel/HaloKeySelection.swift`, `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/HaloEasingRules.swift`, `Sources/HaloModel/Contracts/HaloValues.swift`, `Tests/HaloModelTests/KeyEasingContractTests.swift`, `Tests/HaloModelTests/HaloEasingTests.swift`, `Tests/HaloModelTests/HaloKeySelectionTests.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift`, `Tests/HaloModelTests/HaloKeyToggleTests.swift`, `Tests/mutations/HaloModel.KernelEasingAdapter.json` | – | ~300, 10 |
| AE-h2 | – | **Halo delete.** Removes the handle math in `HaloKeySelection.swift`, `HaloEasingPreset`, and the rule bodies in `HaloKeyRules.swift` and `HaloEasingRules.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/HaloModel/HaloKeySelection.swift`, `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/HaloEasingRules.swift`, `Sources/HaloModel/Contracts/HaloValues.swift`, `Tests/mutations/HaloModel.HaloKeySelection.json`, `Tests/mutations/HaloModel.HaloKeyRules.json` | AE-h1 | ~200, 6 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AE-f1, AE-h1. Independent in this wave: all.
- Wave 2: AE-f2, AE-h2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AE-f1 → AE-f2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AE-f1 | `EasingEditingContractTests`, `FlareEasingTests`, `LiveEasingTests`, `LiveKeyframesEditTests`, `LiveKeyframesFramesTests`, `MoveKeysPastEndTests` (unchanged) and `scripts/mutate --plan FlareModel.KernelEasingAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AE-f2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AE-h1 | `KeyEasingContractTests`, `HaloEasingTests`, `HaloKeySelectionTests`, `PropertyKeyingContractTests`, `HaloKeyToggleTests` (unchanged) and `scripts/mutate --plan HaloModel.KernelEasingAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AE-h2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
