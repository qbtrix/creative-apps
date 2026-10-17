# Feature packet: adopt-kernel-layers

**Feature:** Every app's layer list or tree runs on SuiteKernel's LayerTree; the app tree helpers are deleted. Behaviour-preserving: each app keeps its public
Model API, control ids and journeys; the kernel (`LayerTree<Payload>`, `LayerNode`, `LayerRow` and the follow link) does the work.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track) · **Lead branch:** `lead/adopt-kernel-layers`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, inventory row
"layers") and the captain's canonical-first call on #1552.

**Depends on:** the editor-kernel feature issue's slice `EK-tree`
(`Belt-Slice-Done: EK-tree`): every slice here waits on that slice and
on nothing else of editor-kernel, so the seven adopt features and the app
slices inside each run in parallel. Within an app the kernel slices that
share a file chain in the order each slice's hand-off note gives.

**Hand-offs** (files other packets own; cross-line, so not in `waits`, and
the lead checks each before its slice starts):
- **AL-design:** `DesignNode.swift` is owned by design-contracts (built) and design-seams-2: start after design-seams-2's slice on it. Panel: `DesignLayersPanel.swift` is owned by design-window, layers-panel and shell-parity (Design): start after their slices on it.
- **AL-photo:** `PhotoWorkspace.swift` and `PhotoLayerOps.swift` are owned by photo-seams and photo-adjustment-layers: start after both. Panel: `PhotoLayerList.swift` is owned by no open packet.
- **AL-halo:** `HaloKeyRules.swift` is shared with adopt-kernel-easing's Halo slice: that slice goes first and this one takes the file after it. `owned_files_planned` holds for Halo. Panel: `HaloLayerList.swift` is owned by Halo's foundation (built).
- **AL-flare:** `FlareLayers.swift` is owned by layers-files; this slice edits `Sources/FlareApp/` (the panel reads `LayerRow`), so it is `"ui": true` and its render budget row is the panel's existing one. Panel: `FlareWindow+Layers.swift` is owned by layers-files and draw-key-save (Flare): start after their slices on it.

**Clean-room.** Behaviour only; the rules come from the apps' own tests.

Blueprint sections: suite.md 2 (the kernel tier); each app's blueprint
section the deleted file served (unchanged behaviour).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AL-design | Design runs its layers on `LayerTree<Payload>`, `LayerNode`, `LayerRow` and the follow link behind its existing API, its tests and journeys green, and its copy is deleted, and its layers panel is `LayerTreeList`. | AL-d1, AL-d2, AL-d3 | MJ-AL-design | editor-kernel:EK-tree, editor-kernel:EK-u |
| AL-photo | Photo runs its layers on `LayerTree<Payload>`, `LayerNode`, `LayerRow` and the follow link behind its existing API, its tests and journeys green, and its copy is deleted, and its layers panel is `LayerTreeList`. | AL-p1, AL-p2, AL-p3 | MJ-AL-photo | editor-kernel:EK-tree, adopt-kernel-undo:AU-photo, editor-kernel:EK-u |
| AL-halo | Halo runs its layers on `LayerTree<Payload>`, `LayerNode`, `LayerRow` and the follow link behind its existing API, its tests and journeys green, and its copy is deleted, and its layers panel is `LayerTreeList`. | AL-h1, AL-h2, AL-h3 | MJ-AL-halo | editor-kernel:EK-tree, adopt-kernel-easing:AE-halo, editor-kernel:EK-u |
| AL-flare | Flare runs its layers on `LayerTree<Payload>`, `LayerNode`, `LayerRow` and the follow link behind its existing API, its tests and journeys green, and its copy is deleted, and its layers panel is `LayerTreeList`. | AL-f1, AL-f2, AL-f3 | MJ-AL-flare | editor-kernel:EK-tree, editor-kernel:EK-u |

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
- `MJ-AL-design`: `DesignTreeTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AL-photo`: `PhotoLayersTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AL-halo`: `HaloLayerEditsTests` (existing), green on the Linux job after both tasks merge.
- `MJ-AL-flare`: `FlareLayersTests` (existing), green on the Linux job after both tasks merge.

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
| AL-d3 | – | **Design panel.** `DesignLayersPanel` becomes one `LayerTreeList` over the adapter's `rows(expanded:)`; the nested `DisclosureGroup` tree and `layerToggles` go; the app's layer snapshots show the same rows (render budget: the panel's existing drag row) | `Sources/DesignApp/DesignLayersPanel.swift`, `Tests/AppSnapshotTests/DesignLayersPanelSnapshots.swift` | AL-d1 | ~220, 2 |
| AL-d1 | – | **Design adapter.** `DesignPage.nodes` is a `LayerTree<DesignNodePayload>`; `DesignNode` becomes `LayerNode<DesignNodePayload>` by typealias, `DesignRow` is `LayerRow`; `rows(expanded:)`, `ancestors`, `hit`, `deepestFrame`, `frontToBack`, `anyInTree` route to the kernel; `LiveOrdering`, `LiveGrouping`, `LiveDuplicating` become live over `move`, `arrange`, `group`, `ungroup`, `duplicate` (the fakes' behaviour, now in production). The app's existing tests pass unchanged; a new plan on the adapter | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignLocking.swift`, `Sources/DesignModel/Live/LiveOrdering.swift`, `Sources/DesignModel/Live/LiveGrouping.swift`, `Sources/DesignModel/Live/LiveDuplicating.swift`, `Sources/DesignModel/Fakes/DesignArrangeFakes.swift`, `Tests/DesignModelTests/DesignTreeTests.swift`, `Tests/DesignModelTests/DesignTreeEdgeTests.swift`, `Tests/DesignModelTests/DesignArrangeFakesTests.swift`, `Tests/DesignModelTests/DesignLayerTogglesTests.swift`, `Tests/mutations/DesignModel.KernelLayersAdapter.json` | – | ~300, 11 |
| AL-d2 | – | **Design delete.** Removes the `extension [DesignNode]` helpers in `DesignNode.swift`, `DesignLocking.anyInTree`, and the tree code in `FakeOrdering`, `FakeGrouping`, `FakeDuplicating`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignLocking.swift`, `Sources/DesignModel/Live/LiveOrdering.swift`, `Sources/DesignModel/Live/LiveGrouping.swift`, `Sources/DesignModel/Live/LiveDuplicating.swift`, `Sources/DesignModel/Fakes/DesignArrangeFakes.swift`, `Tests/mutations/DesignModel.DesignNode.json`, `Tests/mutations/DesignModel.DesignArrangeFakes.json` | AL-d1 | ~200, 8 |
| AL-p3 | – | **Photo panel.** `PhotoLayerList` becomes one `LayerTreeList` (single level, thumbnails from the composite); the hand-rolled rows go; the app's layer snapshots show the same rows (render budget: the panel's existing drag row) | `Sources/PhotoApp/PhotoLayerList.swift`, `Tests/AppSnapshotTests/PhotoLayerListSnapshots.swift` | AL-p1 | ~220, 2 |
| AL-p1 | – | **Photo adapter.** `PhotoWorkspace.layers` is a single-level `LayerTree<PhotoLayer>` (`holdsChildren` false); `moveLayers(fromOffsets:toOffset:)`, `bring/sendSelectedLayerForward/Backward`, `duplicateSelectedLayer`, `removeLayer`, `toggleVisibility` route to `move`, `arrange`, `duplicate`; `PhotoLayer` is the payload; top-first order is the adapter's view of the tree. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/PhotoModel/PhotoLayerOps.swift`, `Sources/PhotoModel/PhotoWorkspace.swift`, `Tests/PhotoModelTests/PhotoLayersTests.swift`, `Tests/PhotoModelTests/PhotoLayersEdgeTests.swift`, `Tests/PhotoModelTests/PhotoLayerOpsTests.swift`, `Tests/mutations/PhotoModel.KernelLayersAdapter.json` | – | ~300, 6 |
| AL-p2 | – | **Photo delete.** Removes the order code in `PhotoLayerOps.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/PhotoModel/PhotoLayerOps.swift`, `Sources/PhotoModel/PhotoWorkspace.swift`, `Tests/mutations/PhotoModel.PhotoLayerOps.json` | AL-p1 | ~200, 3 |
| AL-h3 | – | **Halo panel.** `HaloLayerList` becomes one `LayerTreeList` (single level; the parent picker stays in the inspector); the hand-rolled rows go; the app's layer snapshots show the same rows (render budget: the panel's existing drag row) | `Sources/HaloApp/HaloLayerList.swift`, `Tests/AppSnapshotTests/HaloLayerListSnapshots.swift` | AL-h1 | ~220, 2 |
| AL-h1 | – | **Halo adapter.** `HaloComposition.layers` is a single-level `LayerTree<HaloLayer>` whose `followsID` is today's `parentID` (the file format keeps the key); `moveLayer`, `bring/send`, `duplicateSelectedLayer`, `deleteSelectedLayer` (un-parents followers keeping their place) route to the kernel; `HaloKeyRules.worldMatrix` and `follows` call `worldPlacement` and `follows`; `setParent` calls `setFollow(keepingPlace:)`. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/HaloModel/HaloLayerEdits.swift`, `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LiveLayerPlacing.swift`, `Tests/HaloModelTests/HaloLayerEditsTests.swift`, `Tests/HaloModelTests/HaloLayersTests.swift`, `Tests/HaloModelTests/LayerPlacingContractTests.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift`, `Tests/mutations/HaloModel.KernelLayersAdapter.json` | – | ~300, 8 |
| AL-h2 | – | **Halo delete.** Removes the order code in `HaloLayerEdits.swift` and the parent-chain walk in `HaloKeyRules.swift`; repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/HaloModel/HaloLayerEdits.swift`, `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LiveLayerPlacing.swift`, `Tests/mutations/HaloModel.HaloLayerEdits.json` | AL-h1 | ~200, 4 |
| AL-f3 | – | **Flare panel.** the layers `SidebarSection` becomes one `LayerTreeList` over the tree projection; `FlareLayerItems.swift` is deleted; the app's layer snapshots show the same rows (render budget: the panel's existing drag row) | `Sources/FlareApp/FlareWindow+Layers.swift`, `Tests/AppSnapshotTests/FlareLayersPanelSnapshots.swift`, `Sources/FlareApp/FlareLayerItems.swift` | AL-f1 | ~220, 3 |
| AL-f1 | – | **Flare adapter.** `FlareLayers.swift` projects the owner's FlareCore `Layer` list into a `LayerTree<FlareLayerPayload>` for `layers`, `FlareLayerItems` and the panel's rows (`LayerRow`), and maps `moveLayer(from:to:)` through `LayerTree.move` before issuing `ReorderLayer`; edits stay commands. The app's existing tests pass unchanged; a new plan on the adapter | `Sources/FlareModel/FlareLayers.swift`, `Sources/FlareApp/FlareLayerItems.swift`, `Sources/FlareApp/FlareWindow+Layers.swift`, `Tests/FlareModelTests/FlareLayersTests.swift`, `Tests/FlareModelTests/LiveScenesOrderTests.swift`, `Tests/mutations/FlareModel.KernelLayersAdapter.json` | – | ~300, 6 |
| AL-f2 | – | **Flare delete.** Removes `FlareLayerItems.swift`'s row shaping (rows come from the tree); repoints or removes every `find` in the plans it owns; C4 part updated if a file leaves a component | `Sources/FlareModel/FlareLayers.swift`, `Sources/FlareApp/FlareLayerItems.swift`, `Sources/FlareApp/FlareWindow+Layers.swift`, `Tests/mutations/FlareModel.FlareLayers.json` | AL-f1 | ~200, 4 |

Each app's two tasks share that app's files, so the delete waits on the
adapter; no two apps share a file. Shared prose: none (the blueprints
already describe the behaviour; editor-kernel's EK-26 names the tier).

## Build waves

- Wave 1: AL-d1, AL-p1, AL-h1, AL-f1. Independent in this wave: all.
- Wave 2: AL-d3, AL-d2, AL-p3, AL-p2, AL-h3, AL-h2, AL-f3, AL-f2 (the last one carries `feature-done`). Independent in this wave: all.

Longest chain: AL-d1 → AL-d3 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AL-d3 | the app's layer-panel snapshots and journeys (unchanged names); `RenderBudgetDesignTests` panel drag row | a row, toggle or menu the old panel had is missing; bodies over budget | – (UI, rows in, closures out) |
| AL-d1 | `DesignTreeTests`, `DesignTreeEdgeTests`, `DesignArrangeFakesTests`, `DesignLayerTogglesTests` (unchanged) and `scripts/mutate --plan DesignModel.KernelLayersAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AL-d2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AL-p3 | the app's layer-panel snapshots and journeys (unchanged names); `RenderBudgetPhotoTests` panel drag row | a row, toggle or menu the old panel had is missing; bodies over budget | – (UI, rows in, closures out) |
| AL-p1 | `PhotoLayersTests`, `PhotoLayersEdgeTests`, `PhotoLayerOpsTests` (unchanged) and `scripts/mutate --plan PhotoModel.KernelLayersAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AL-p2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AL-h3 | the app's layer-panel snapshots and journeys (unchanged names); `RenderBudgetHaloTests` panel drag row | a row, toggle or menu the old panel had is missing; bodies over budget | – (UI, rows in, closures out) |
| AL-h1 | `HaloLayerEditsTests`, `HaloLayersTests`, `LayerPlacingContractTests`, `PropertyKeyingContractTests` (unchanged) and `scripts/mutate --plan HaloModel.KernelLayersAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AL-h2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |
| AL-f3 | the app's layer-panel snapshots and journeys (unchanged names); `RenderBudgetFlareTests` panel drag row | a row, toggle or menu the old panel had is missing; bodies over budget | – (UI, rows in, closures out) |
| AL-f1 | `FlareLayersTests`, `LiveScenesOrderTests` (unchanged) and `scripts/mutate --plan FlareModel.KernelLayersAdapter` | an app signature changed, or a test needs editing to pass | the adapter drops the forward to `endRun()` (a run spans two gestures); the adapter maps the kernel's refusal to success |
| AL-f2 | the same tests, `scripts/mutate --validate` | a deleted symbol is still referenced; a plan's `find` no longer occurs exactly once | – (deletion) |

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
