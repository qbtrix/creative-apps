# Feature packet: multi-layer-select (Photo)

**Feature:** Photo selects several layers at once and acts on all of them.
The Layers list picks with Shift-click (a range, in stack order) and ⌘-click
(toggle), Select > All Layers (⌥⌘A) picks every layer, and the selection is
SuiteKernel's `Selection<PhotoLayer.ID>`, primary last. Move (the Move tool
and arrow nudges), Hide and Show, Delete and Opacity apply to every selected
layer, each as one undo step through the kernel `History`, and each is a
catalog command, so the CLI and an agent do it the way the panel does. A last,
separable slice groups the selected layers (⌘G).
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/multi-layer-select`
**Beta:** captain, 2026-10-20 (the stress gate, PR #3499: "Photo selects one
layer at a time"). Labels `beta` and `p1` when filed. The group slice (PM-g)
is the captain's call for the beta cut (Open).

**Covers:** feature map `photo/multi-layer-select` (Photo becomes an adopter
of `suiteui/adopt-kernel-selection`); real job RJ-P43 (new).

**Depends on:** `photo/gradient-fill` **PG-a** (same line: it owns
`PhotoWorkspace.swift`, `PhotoIntent.swift` and `PhotoStroke.swift` first),
**PG-m** (the catalog, before PM-5) and **PG-z** (`photo.md`, before PM-10).
Built: editor-kernel (`Selection`, `LayerTree`, `History`), photo-edit,
photo-seams, shell-parity (the panel on `LayerTreeList`).

**Hand-offs** (cross-line files; the lead checks each before the task):
`Sources/SuiteUI/LayerTreeList.swift` is editor-kernel's (built) and every
app's layers panel: PM-1's change is additive (old callers compile and draw as
before), and Halo, Flare and Design adopt multi-select later on their own
lines. `PhotoLayerList.swift` is also adopt-kernel-layers' (AL-photo merged as
AL-p3); `PhotoWindow.swift` is adopt-kernel-brush's and adopt-suiteui-chrome's;
`PhotoCommandCatalog.swift` and `Tests/command-ids/photo.txt` are
adopt-command-catalog's (#2999, AC-photo): PM-5 starts after AC-photo's
`Belt-Slice-Done:`. Among Photo's packets the catalog passes PG-m → PM-m →
transform's PT-m, and `photo.md` passes PG-z → PM-z → place-image's PP-z.
`UITests/PhotoJourneyTests+StressPerf.swift` comes from PR #3499: PM-9 waits
on its merge.

**Rule 20.** No Photo selection logic: the pick, the Shift range (from the
anchor through `layers.map(\.id)`), the toggle, Select All and the prune are
the kernel `Selection`; hide, show and delete run on the kernel `LayerTree`
through `PhotoLayers+Kernel`'s `kernelEdited`; each step is the kernel
`History` through Photo's `record`. `selectedLayerID` stays as the primary
(`layerSelection.primary`; setting it replaces the selection), so its 52
callers keep compiling and still mean "the layer the inspector and the brush
act on". The shared half (several rows picked in the one layers panel) goes
in SuiteUI's `LayerTreeList` (rule 16), not in a Photo list.

Blueprint sections: photo.md (Layers panel, Layer menu, Move tool), suite.md
2 (the kernel's `Selection`).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PM-a | `LayerTreeList` draws and reports several picked rows with the click's mode, Photo keeps a kernel `Selection` of layers behind `selectedLayerID`, and the Layers list, Select > All Layers and the intents pick several layers on stubbed actions. | PM-1, PM-2, PM-3 | MJ-PM | gradient-fill:PG-a (PM-2); shell-parity (built, PM-3) |
| PM-u | Several picked rows, the menus and a range click look right and stay inside their render budget, with the journey written. | PM-7, PM-8 | PJ-M1 | PM-a |
| PM-m | Picks follow the kernel rules, and Move, Hide and Show, Delete and Opacity act on every selected layer as one step each, by panel, menu, tool or command. | PM-4, PM-5, PM-6 | MJ-PM | PM-a; gradient-fill:PG-m (PM-5) |
| PM-z | The journey and the stress gate's Photo layer gestures pass on live with several layers selected, and the blueprint says Photo selects several layers. | PM-9, PM-10 | PJ-M1 | PM-u, PM-m; gradient-fill:PG-z (PM-10); PR #3499 (PM-9) |
| PM-g | Group Layers (⌘G) puts the selected layers in one group layer the list nests, the render composites as one, and the file saves; Ungroup takes it apart; one step each. | PM-11, PM-12, PM-13 | PJ-M2 | PM-m; PM-a (PM-13); photo-render-adopt (built, PM-12); text-layers:TX-m (PM-11: `PhotoLayer.swift` and `PhotoDocumentFile.swift`, re-cut 2026-10-21) |

PM-a carries the first UI task (PM-3: the Layers list and Select > All
Layers on the stubs), so the feature is reachable with the mouse once the
contract merges; PM-u waits only on PM-a (rule 18) and PM-m never waits on
PM-u. MJ-PM is the Model walk in `PhotoLayerSelectionTests` and
`PhotoSeveralLayersTests` (Linux). PJ-M1 is
`PhotoMultiLayerJourneyTests.testSelectSeveralLayers`, PJ-M2
`PhotoMultiLayerJourneyTests.testGroupLayers`.

## Journey steps

On the `layered` fixture (four layers; rows counted from the top), in
`PhotoMultiLayerJourneyTests` (PM-8 writes it skipped, PM-9 turns it on):

1. Click row 1, Shift-click row 3: rows 1 to 3 draw picked; the inspector
   shows row 3's layer, the primary (PM-3, PM-4).
2. ⌘-click row 2: rows 1 and 3 stay picked.
3. Click row 1's eye: rows 1 and 3 hide in one "Hide Layers" step (PM-5).
4. Drag the Opacity slider to 50 %: both are at 50 %, one "Layer Opacity"
   step (PM-5).
5. Move tool, drag the canvas 40 px right: both move, one "Move Layers" step;
   ⌘Z puts both back (PM-6).
6. ⌥⌘A (Select > All Layers): all four rows picked (PM-3, PM-4).
7. Delete Layer: refused with "At least one layer must stay."; ⌘-click row 4
   off, Delete Layers: three go in one step; ⌘Z puts them back (PM-5).
8. (PM-g, `testGroupLayers`) Pick rows 1 and 2, ⌘G: one "Group 1" row with
   the two inside, the canvas unchanged; Ungroup: back as before.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P43 | adds (`photo/multi-layer-select`) | C | `Tests/RealJobs/photo/fade-layers/fade-layers.jobs.json`: `layer.pick` ×3 (replace, extend, extend), `layer.set-opacity` 50, `layer.move-by` 40 0, export PNG | `input/four-layers.photo` (four opaque squares, one per layer) |

Trap: only the last-clicked layer changes. Assertion: the export's three
picked squares are at half alpha and 40 px right, the fourth unchanged (pixels,
tolerance 2). Mutations: `PhotoModel.PhotoSeveralLayers+Kernel`, the primary
alone changed → `PhotoSeveralLayersTests.opacityAppliesToEvery`; the move
applied per layer as its own step → `.oneStepForSeveral`.

## Screens and states

`photo-layers-several-picked`, `photo-layers-all-picked`,
`photo-select-menu-all-layers`, `photo-layers-delete-refused`,
`photo-layers-group` (PM-g) (light and dark).

## Contract slice

```swift
// Sources/SuiteUI/LayerTreeList.swift (PM-1): additive; the single-selection init is unchanged.
public init(rows:, childCount:, selected: Set<String>, naming:, header:, options:, decorations:,
            onPick: @escaping @MainActor (String, Pick) -> Void, onRename:, onAction:)
nonisolated public static func pick(shift: Bool, command: Bool) -> Pick   // ⇧ .extend, ⌘ .toggle, else .replace
// rows draw selected for every id in `selected`; a row click reads the event's modifiers once, on press

// Sources/PhotoModel/PhotoWorkspace.swift (PM-2)
var layerSelection: Selection<PhotoLayer.ID>                 // stored; replaces the stored selectedLayerID
public internal(set) var selectedLayerID: PhotoLayer.ID? { get set }   // primary; set replaces the selection
// Sources/PhotoModel/PhotoLayerSelection+Kernel.swift (PM-2 stubs, PM-4 bodies)
extension PhotoWorkspace {
    public var selectedLayerIDs: [PhotoLayer.ID] { get }       // top-first
    public mutating func pickLayer(_ id: PhotoLayer.ID, _ pick: Pick)
    public mutating func selectAllLayers()
}
// Sources/PhotoModel/PhotoSeveralLayers+Kernel.swift (PM-2 stubs, PM-5 and PM-6 bodies)
extension PhotoWorkspace {
    public mutating func removeSelectedLayers()                // refuses taking every layer
    public var removeSelectedHelp: String? { get }             // "At least one layer must stay." / nil
    public mutating func moveSelectedLayers(dx: Int, dy: Int)  // layer.move-by and arrow nudges
}
// Existing calls that now act on the selection when `id` is selected: toggleVisibility(_:), setOpacity(_:percent:).
// Sources/PhotoApp/PhotoIntent.swift (PM-3): case pickLayer(PhotoLayer.ID, Pick), selectAllLayers
// Catalog ids (PM-5, PM-6): layer.pick {id, mode}, layer.select-all, layer.set-opacity {percent}, layer.move-by {dx, dy};
// layer.delete and layer.toggle-visibility keep their ids and act on every selected layer.
```

Stubs: `pickLayer` replaces with the clicked row (today's behaviour) and
`selectAllLayers` picks every layer, so the list works on the stubs;
`removeSelectedLayers` and `moveSelectedLayers` act on the primary only until
PM-5 and PM-6.

## Pseudocode

```
pickLayer(id, pick):                                            # PM-4
  layerSelection.pick(id, pick, order: layers.map(\.id))       # kernel: anchor range, toggle, replace
  layerSelection.primary == nil: layerSelection.replace([top layer])   # never empty while there are layers
selectAllLayers(): layerSelection.selectAll(layers.map(\.id))
after delete, undo, redo, open: layerSelection.prune(alive: layer ids); empty -> replace([layers[nearest]])
Select Layer Above / Below: replace([that layer]) (unchanged meaning)
toggleVisibility(id):                                           # PM-5
  targets = layerSelection.contains(id) ? selectedLayerIDs : [id]
  hide = layers[id].isVisible                                   # every target takes the clicked row's new state
  one kernelEdited(layers) { for t in targets: tree.update(t) { isHidden = hide } } named hide ? "Hide Layers" : "Show Layers"
setOpacity(id, percent): targets as above; one step "Layer Opacity", coalesced "opacity-selection" for a slider run
removeSelectedLayers(): guard selection.count < layers.count else refuse(removeSelectedHelp)
  record(.stack) "Delete Layers"; remove each; select the layer that took the top one's place
Move tool and moveSelectedLayers (PM-6): every selected layer's offset moves by the same delta; one "Move Layers" step per drag
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PM-1 | – | `LayerTreeList`'s multi-select init and `pick(shift:command:)`; rows draw every picked id; the old init unchanged; tests first | `Sources/SuiteUI/LayerTreeList.swift`, `Sources/SuiteUI/LayerTreeList+Rows.swift`, `Tests/SuiteUITests/LayerTreeListTests.swift`, `Tests/mutations/SuiteUI.LayerTreeList.json` | – | ~220, 4 |
| PM-2 | – | `layerSelection` behind `selectedLayerID`; the selection and several-layer API as stubs; `PhotoLayerSelectionTests` and `PhotoSeveralLayersTests` written, disabled | `Sources/PhotoModel/PhotoWorkspace.swift`, `Sources/PhotoModel/PhotoLayerSelection+Kernel.swift`, `Sources/PhotoModel/PhotoSeveralLayers+Kernel.swift`, `Tests/PhotoModelTests/PhotoLayerSelectionTests.swift`, `Tests/PhotoModelTests/PhotoSeveralLayersTests.swift` | PG-a | ~240, 5 |
| PM-3 | – | The Layers list on the multi-select init, Select > All Layers (⌥⌘A), the two intents and routes; reachable from the Select menu | `Sources/PhotoApp/PhotoLayerList.swift`, `Sources/PhotoApp/PhotoIntent.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Sources/PhotoApp/PhotoCommands+Select.swift` | PM-1, PM-2 | ~160, 4 |
| PM-4 | – | Selection bodies: range, toggle, select all, never empty, prune after delete, undo and open; turns on `PhotoLayerSelectionTests` | `Sources/PhotoModel/PhotoLayerSelection+Kernel.swift`, `Tests/PhotoModelTests/PhotoLayerSelectionTests.swift`, `Tests/mutations/PhotoModel.PhotoLayerSelection+Kernel.json` | PM-2 | ~220, 3 |
| PM-5 | – | Hide and Show, Opacity and Delete on every selected layer, one step each; `layer.pick`, `layer.select-all`, `layer.set-opacity`; turns on `PhotoSeveralLayersTests` (all but the move) | `Sources/PhotoModel/PhotoSeveralLayers+Kernel.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoSeveralLayersTests.swift`, `Tests/mutations/PhotoModel.PhotoSeveralLayers+Kernel.json`, `Tests/mutations/PhotoModel.PhotoCommandCatalog.json` | PM-2, PG-m, AC-photo (hand-off) | ~320, 6 |
| PM-6 | – | The Move tool and `layer.move-by` move every selected layer, one "Move Layers" step; RJ-P43's job folder | `Sources/PhotoModel/PhotoStroke.swift`, `Sources/PhotoModel/PhotoSeveralLayers+Kernel.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoSeveralLayersTests.swift`, `Tests/RealJobs/photo/fade-layers/fade-layers.jobs.json`, `Tests/RealJobs/photo/fade-layers/input/four-layers.photo`, `Tests/RealJobs/photo/fade-layers/expected/four-layers-faded.png` | PM-5 | ~260, 8 |
| PM-7 | – | Snapshots of the four states; the render budget test | `Tests/AppSnapshotTests/PhotoMultiLayerSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoMultiLayerTests.swift` | PM-3 | ~220, 2 |
| PM-8 | – | The journey written, skipped until PM-9 | `UITests/PhotoJourneyTests+MultiSelect.swift` | PM-3 | ~180, 1 |
| PM-9 | – | Live: the journey turned on; the stress journey adds ⌥⌘A, then its eye toggles and Move drag act on every layer | `UITests/PhotoJourneyTests+MultiSelect.swift`, `UITests/PhotoJourneyTests+StressPerf.swift` | PM-4, PM-6, PM-7, PM-8, #3499 | ~120, 2 |
| PM-10 | – | `photo.md` Layers rows (several layers, All Layers, actions on all); `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/multi-layer-select.wave.json` | PM-9, PG-z | ~40, 2 |
| PM-11 | – | Group layers in the Model: a `group` layer kind holding children on the kernel `LayerTree`, Group Layers and Ungroup as one step each, `layer.group` and `layer.ungroup`, the `.photo` format's version bump with old files opening unchanged | `Sources/PhotoModel/PhotoLayer.swift`, `Sources/PhotoModel/PhotoLayers+Kernel.swift`, `Sources/PhotoModel/PhotoLayerGroup+Kernel.swift`, `Sources/PhotoModel/PhotoDocumentFile.swift`, `Tests/PhotoModelTests/PhotoLayerGroupTests.swift`, `Tests/mutations/PhotoModel.PhotoLayerGroup+Kernel.json` | PM-5, PM-6 | ~380, 6 |
| PM-12 | – | The composite draws a group as its children, pass-through, on the CPU and GPU routes; tiles and damage follow children | `Sources/PhotoModel/PhotoLayerComposite.swift`, `Sources/PhotoModel/PhotoRenderRoute.swift`, `Tests/PhotoModelTests/PhotoLayerGroupCompositeTests.swift` | PM-11 | ~300, 3 |
| PM-13 | – | The list nests groups (disclosure), Layer > Group Layers (⌘G) and Ungroup; snapshot; the journey's group step | `Sources/PhotoApp/PhotoCommands+Layer.swift`, `Tests/AppSnapshotTests/PhotoLayerGroupSnapshots.swift`, `UITests/PhotoJourneyTests+LayerGroup.swift` | PM-11, PM-3 | ~220, 3 |

## Build waves

- Wave 1: PM-1, PM-2. Independent in this wave: both.
- Wave 2: PM-3, PM-4, PM-5. Independent in this wave: all three (PM-5 waits on PG-m and AC-photo too).
- Wave 3: PM-6, PM-7, PM-8. Independent in this wave: all three.
- Wave 4: PM-9, PM-11. Independent in this wave: both.
- Wave 5: PM-10 (shared prose, `feature-done`), PM-12. Independent in this wave: both.
- Wave 6: PM-13. Independent in this wave: PM-13 alone.

Longest chain: PM-2 → PM-5 → PM-6 → PM-11 → PM-12 (5), and PM-1 → PM-3 →
PM-7 → PM-9 → PM-10 (5). Chain of 5: the move and the group each build on the
step and selection the task before adds (PM-5 and PM-6 share
`PhotoSeveralLayers+Kernel.swift` and the catalog); the UI chain draws the list
PM-3 wires, the journey runs it live, PM-10 is the prose. `feature-done` is
PM-10: PM-g is separable, and when the captain keeps it in the beta its last
task (PM-13) moves `feature-done` to itself.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PM-1 | `LayerTreeListTests`: `pick(shift:command:)` gives `.extend`, `.toggle`, `.replace`; with `selected` = two ids both rows read selected; the old `selection:` init draws one; `LayerListSnapshots` unchanged | Shift gives toggle, or an old caller changes | `SuiteUI.LayerTreeList`: Shift and ⌘ swapped → `.pickModes`; `isSelected` reads only the primary → `.severalSelected` |
| PM-2 | `PhotoWorkspaceTests` and every caller of `selectedLayerID` green; `selectedLayerID = id` leaves one layer selected; the two suites compile, disabled | a caller's meaning changes | – (stub) |
| PM-3 | `PhotoLayerListSnapshots` with two picked rows; `PhotoEditMenuTests` finds All Layers ⌥⌘A, ⌘A still the pixel Select All | ⌘A changes meaning, or the list draws one row | – (UI) |
| PM-4 | `PhotoLayerSelectionTests`: Shift from Layer 1 to 3 picks 1–3 top-first, the primary 3; a second Shift from the same anchor to 2 takes 3 back; ⌘ toggles; All picks four; deleting the primary leaves the rest with a new primary; undo restores a layer and the selection keeps only live ids; never empty | the range uses the wrong order, a stale id survives, or the selection empties | `PhotoModel.PhotoLayerSelection+Kernel`: the order passed bottom-first → `.rangeTopFirst`; prune skipped after undo → `.pruneAfterUndo`; the empty guard dropped → `.neverEmpty` |
| PM-5 | `PhotoSeveralLayersTests`: an eye click on a picked row hides every picked layer in one step, on an unpicked row only that one; opacity 50 sets all picked, a slider run is one step (`opacityAppliesToEvery`); Delete with all picked refuses with its help; three picked delete in one step and undo puts them back in order; `PhotoCommandCatalogTests` finds the three new ids | a layer is left out, a run is several steps, or the last layer goes | `PhotoModel.PhotoSeveralLayers+Kernel`: the primary alone changed → `.opacityAppliesToEvery`; per-layer steps → `.oneStepForSeveral`; the refusal guard `<=` for `<` → `.deleteRefusesAll` |
| PM-6 | `PhotoSeveralLayersTests.moveMovesEvery`: a Move drag with two picked moves both by the same delta, one "Move Layers" step; `layer.move-by` the same; RJ-P43 passes on Linux | one layer stays, or two steps | `PhotoModel.PhotoSeveralLayers+Kernel`: only the primary's offset moved → `.moveMovesEvery`; `PhotoModel.PhotoStroke`: `layersBefore` taken per layer → `.oneStepForSeveral` |
| PM-7 | `PhotoMultiLayerSnapshots` (four states); `RenderBudgetPhotoMultiLayerTests.rangeClickInThreeBodies`, `.selectAllInOneBody` | a state is missing, over budget | – (UI) |
| PM-8 | the journey compiles, skipped "waits on PM-9" | – | – (UI) |
| PM-9 | `PhotoMultiLayerJourneyTests.testSelectSeveralLayers` steps 1 to 7 on live; `PhotoStressPerfJourneyTests.testStress` with ⌥⌘A (perf run) | a step fails, or a gesture misses the gate | – |
| PM-10 | `scripts/waves render --dry-run` | status not built | – |
| PM-11 | `PhotoLayerGroupTests`: Group Layers of two picked makes one group holding them in order, one step; Ungroup restores; a version-1 file opens unchanged and a grouped file round-trips | a child changes order, two steps, or an old file fails | `PhotoModel.PhotoLayerGroup+Kernel`: children reversed → `.groupKeepsOrder`; Ungroup drops the group's opacity onto nothing → `.ungroupKeepsLook` |
| PM-12 | `PhotoLayerGroupCompositeTests`: a group of two draws pixel-equal to the two ungrouped on CPU and GPU (tolerance 2); a hidden group hides its children | the group changes the picture | `PhotoModel.PhotoLayerComposite`: a hidden group's children drawn → `.hiddenGroupHides` |
| PM-13 | `PhotoLayerGroupSnapshots`; `PhotoMultiLayerJourneyTests.testGroupLayers` | the menu or the nesting is missing | – (UI) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Shift-click a 50-row range in the 100-layer `stress` list | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetPhotoMultiLayerTests.rangeClickInThreeBodies` |
| render: ⌥⌘A on the 100-layer `stress` document | ≤ 1 window body; p95 ≤ 16 ms | `RenderBudgetPhotoMultiLayerTests.selectAllInOneBody` |
| Stress gate: ⌥⌘A on `stress` (`select-layers`) | a11y answer ≤ 2 s; main-thread surface allocation ≤ 20 %; idle CPU < 10 % 3 s after | `PhotoStressPerfJourneyTests.testStress` (perf run, `Tests/render-budgets.md`) |
| Stress gate: every eye on screen toggled with all 100 layers selected (`toggle-visibility`) | each click one "Hide Layers" or "Show Layers" step; a11y ≤ 2 s; idle CPU < 10 % | `PhotoStressPerfJourneyTests.testStress` |
| Stress gate: Move tool drag with all 100 layers selected, ⌘Z (`move`, series `canvas-drag`) | step p95 ≤ 33 ms; main-thread surface allocation ≤ 20 %; a11y ≤ 2 s; idle CPU < 10 % | `PhotoStressPerfJourneyTests.testStress` |
| Model: one Move step with 100 layers selected (`stress`) | ≤ 8 ms on Linux | `PhotoSeveralLayersTests.moveHundredInBudget` |
| One gesture, one step | eye click, slider run, Move drag, Delete, Group | `PhotoSeveralLayersTests.oneStepForSeveral` |
| No dead controls; mouse and keyboard parity | All Layers in the Select menu and ⌥⌘A; Delete disabled with its help | `testSelectSeveralLayers` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PM-m merged-done with RJ-P43 green in the
Linux job; PM-u's feel gate and `Mac-Finish:` (and PM-a's, which changes
SuiteUI's layers panel: the finisher diffs Halo's, Flare's and Design's panel
snapshots too); PM-z's journey and the stress gate's three gestures on live.
Then `Belt-Contact-Sheet:` with `photo-layers-*`. PM-g, when kept, ends with
its own `Belt-Slice-Done:` and `testGroupLayers`.

## Open

- **Group in the beta.** Photo has no container layer today (two layer kinds,
  `holdsChildren` false, a flat list). PM-g adds one: a layer kind, a file
  format version, and a pass-through composite on both render routes. It is
  separable and runs last; the captain decides whether the beta takes it or a
  follow-up does. Clipping groups, group masks and group blend modes other
  than pass-through are out either way.

## Not in this packet

Marquee or lasso picking of layers on the canvas, auto-select on the canvas
(a click picks the layer under the pointer), Mixed values in the inspector
(it shows the primary's), link layers, and multi-select in Halo's, Flare's and
Design's layers panels (each adopts PM-1 on its own line).
