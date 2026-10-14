# Feature packet: layer-panel

**Feature:** Layer housekeeping. Delete, rename, reorder and duplicate a layer
of the selected composition, each one named undo step through `edit`; the
Layer menu's Duplicate, Rename, Delete, Bring Forward and Send Backward turn
on; the inspector's layer list renames on the row, reorders by drag and
deletes with ⌫.
**Line:** `line:halo` · **Wave:** W1 (`waves.md`) · **Lead branch:** `lead/layer-panel`

**Covers:** #770 (L-1 in the blueprint). It closes through LP-4, the
`feature-done` PR; LP-1 to LP-3 say "Part of #770".

**Depends on:** foundation #777 and SuiteUI #333 (QH-4, journey files). Only
LP-4 needs #333: `project.yml` compiles only `UITests/HaloJourneyTests.swift`
today, so `UITests/HaloJourneyTests+Layers.swift` is not compiled until #333
lands. One `Depends on:` line holds one issue, so the feature issue is filed
once both #777 and #333 are closed and its line names whichever closed last
(`waves.md`, File when ready). The lead can then build every task. No
creative-core issue is needed. Nothing waits on layer-keys (same wave): the
one place this feature meets it, deleting a parent, goes through the
`PropertyKeying` contract and has a fallback for the W0 stub (Pseudocode).

Blueprint sections it builds on: 2 (`edit`, one undo step, coordinates,
commands and availability, fixtures), 4 (H-J9 and its states), 5 (the
`HaloLayerEdits.swift` row of the workspace methods, `PropertyKeying.setParent`),
6 (inspector order, the Layer menu, the command table), 7.2 (audit), 7.5
(QB-F1, QB-F3, QB-F4), 8.3 (layer-panel's owned files). The packet wins over
the blueprint and over #770's body where they differ; see "Review notes
folded in".

**Building blind.** LP-2's window file, LP-3 and LP-4 are in
`Sources/HaloApp/`, `Tests/AppSnapshotTests/` and `UITests/`, which the Linux
gate never compiles; the macOS job compiles them on `dev` after the lane
merges. So: copy the shape of the W0 stubs they replace, check every SwiftUI
and AppKit API with the `apple-docs` MCP before use (`List`, `.onMove`,
`.onDeleteCommand`, `NSAlert.beginSheetModal(for:)`; say so in the PR), keep
views dumb (no assignment or binding to Model state), and put every decision
in LP-1 and LP-2's Model files: names, indexes, the move offset, selection
after a delete, and every reason a command is off.

**Shared-file rule.** This feature owns only the files in its task rows. It
never edits `Sources/SuiteUI/**`, `project.yml`, `UITests/Journey*.swift`,
`UITests/Journey+Input.swift`, `Tests/AppSnapshotTests/AppSnapshotTests.swift`,
`docs/c4/model.json` or `docs/design.md`, nor W0's `HaloProject.swift`,
`HaloCommand.swift`, `HaloViewerState.swift`, `HaloWindow.swift`,
`HaloViewer.swift`, `HaloCommands.swift` or any menu file. It does not own
`HaloTimelineView.swift` (W0's, then easing's in W2),
`Availability/HaloAvailability+History.swift` or `HaloHistory.swift`
(history-files). The layer menu's key equivalents (⇧⌘D, ⌘], ⌘[) are W0's
menu file, from section 6; the plain ⌫ is routed by W0's `HaloViewer` to
`perform(.deleteLayer)`. This feature fills the routes.

## Journey steps

**H-J9** `testLayerHousekeeping` in `UITests/HaloJourneyTests+Layers.swift`,
own `XCTestCase`, on `-HaloFixture three-layers` (Intro, 24 fps, 72 frames,
playhead 0; layers top first Title, Badge, Background, Rig). One shot per
step, named `halo-layers-<step>`. "Edit menu reads X" means: open Edit, the
first item's title is X, Escape. Undo stays disabled until history-files
lands, so the journey reads titles and never presses ⌘Z (LP-4):

1. Click "Badge" in the layer list (`halo.layers.list`). It is selected.
2. Layer > Duplicate. Rows top to bottom: Title, Badge copy, Badge,
   Background, Rig; "Badge copy" is selected; Edit menu reads "Undo
   Duplicate Layer".
3. Double-click "Badge copy"'s title, type `Badge 2`, Return. The row reads
   "Badge 2"; Edit menu reads "Undo Rename Layer".
4. Layer > Rename…, clear the field, Rename. The row still reads "Badge 2"
   and "Enter a name." shows under it (`halo.layers.refusal`); Edit menu
   still reads "Undo Rename Layer" (a refused edit is not a step).
5. Drag the "Badge 2" row below "Rig" (`press(forDuration:thenDragTo:)`).
   Rows: Title, Badge, Background, Rig, Badge 2; the refusal caption is gone;
   `halo.viewer.artboard` reads "Frame 0: Badge 2, Background, Badge"
   (drawn first; Title is out of span, Rig is a null); Edit menu reads "Undo
   Move Layer".
6. Open Layer: Send Backward is disabled with help "This layer is already at
   the bottom."; choose Bring Forward. Rows: Title, Badge, Background,
   Badge 2, Rig; Edit menu reads "Undo Move Layer".
7. Layer > Delete. Rows: Title, Badge, Background, Rig; Rig is selected (it
   took Badge 2's place); artboard "Frame 0: Background, Badge"; Edit menu
   reads "Undo Delete Layer".
8. Click Rig's lane in the timeline (selects Rig, focuses the timeline), then
   ⌫ three times and once more. Rows go to Title, Badge, Background, then
   Title, Badge, then Title, then none; the list shows "No layers yet. Add one
   from Layer > New." (`halo.layers.empty`); the artboard reads "Frame 0: no
   layers"; Layer > Delete is disabled with "Select a layer first.".

The Model half of every step runs on Linux first in `HaloLayerEditsTests`
and `HaloLayerAvailabilityTests`, including undo of each edit.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Layer list (inspector, LAYERS) | a composition with no layers: "No layers yet. Add one from Layer > New." in `SuiteFont.caption`, secondary text, `halo.layers.empty`; no composition: the list is not shown (W0's "No Selection") | a refused rename: the old name stays and `refusal.message` ("Enter a name.") shows in `SuiteFont.caption` under the row whose id `refusal.control` names (`halo.layers.row.<layer id>`) | none |
| Rename prompt (Layer > Rename…) | the field holds the current name, selected | an empty or blank name closes the prompt and shows the row's refusal above | none |
| Layer menu | no composition: Duplicate, Rename, Delete, Bring Forward, Send Backward disabled with "Create a composition first."; no layer: "Select a layer first." | top layer: Bring Forward "This layer is already at the top."; bottom layer: Send Backward "This layer is already at the bottom." | none |
| Viewer and timeline | after the last delete: "Frame 0: no layers"; the timeline shows its ruler and no lanes (its own empty text is easing's, see Review notes) | none | none |

## Contract slice

No new protocol and no service: layer housekeeping is engine-direct
(section 2). Everything below is new in HaloModel; command case names are
the ones W0's `HaloCommand` gives Layer > Duplicate, Rename, Delete, Bring
Forward and Send Backward (written here as `.duplicateLayer`, `.renameLayer`,
`.deleteLayer`, `.bringLayerForward`, `.sendLayerBackward`).

```swift
// HaloLayerEdits.swift (LP-1). Every write is one `edit` step; all act on
// the selected composition and throw `.noComposition` without one.
extension HaloProject {
    public mutating func deleteSelectedLayer()                     // "Delete Layer", control "halo.layers.list"
    public mutating func renameLayer(_ id: String, to name: String) // "Rename Layer", control "halo.layers.row.<id>"
    public mutating func moveLayer(_ id: String, to index: Int)     // "Move Layer"; index top first, clamped
    public mutating func moveLayer(fromOffset: Int, toOffset: Int)  // `.onMove`'s offsets, converted by `moveTarget`
    public mutating func bringSelectedLayerForward()               // "Move Layer", one place toward the top
    public mutating func sendSelectedLayerBackward()               // "Move Layer", one place toward the bottom
    public mutating func duplicateSelectedLayer()                  // "Duplicate Layer"
    /// `.onMove` offsets to the final index: a row moved down lands one
    /// above the offset it was dropped at. Nil when `from` is out of range.
    public static func moveTarget(from: Int, toOffset: Int, count: Int) -> Int?
}

// Availability/HaloAvailability+Layers.swift (LP-2), replacing W0's stub.
extension HaloProject {
    func layersHelp(_ command: HaloCommand) -> String?   // called by unavailableHelp(for:)
}
```

`HaloEditError.emptyName` ("Enter a name."), `.noLayerSelected` ("Select a
layer first.") and `.unknownLayer` already exist (W0). The two top and bottom
reasons are availability text only: the Model methods do nothing (no step,
no refusal) at the ends, because the menu never sends them there.

## Pseudocode

```
duplicateSelectedLayer():
  guard comp, sel = selectedLayerID else edit throws .noLayerSelected
  newID = takeLayerID(in: comp.id)            # before edit, so undo keeps the
                                              # bumped counter: ids never repeat
  edit("Duplicate Layer", control: "halo.layers.list") { doc in
    i = index of sel; copy = layers[i].withID(newID)    # keys, parent, text, span,
    copy.name = layers[i].name + " copy"                # opacity, blend copied
    layers.insert(copy, at: i)                          # directly above
    doc.selectedLayerID = newID }

renameLayer(id, name):
  edit("Rename Layer", control: "halo.layers.row.\(id)") { doc in
    clean = name normalized as FD-19 stores composition names (trimmed,
            inner whitespace runs to one space, format characters dropped)
    guard !clean.isEmpty else throw .emptyName       # old name stays
    guard layer id exists else throw .unknownLayer(id)
    layer.name = clean }                              # same name: no-op, no step
  # layer names need not be unique (no taken-name check)

moveLayer(id, to: index):
  edit("Move Layer", control: "halo.layers.list") { doc in
    from = index of id; to = clamp(index, 0, count - 1)
    layers.move(from, to) }                           # same place: no step
moveTarget(from, toOffset, count) = from in 0..<count ? (toOffset > from ? toOffset - 1 : toOffset) clamped : nil
bring forward = moveLayer(sel, to: i - 1) if i > 0; send backward = moveLayer(sel, to: i + 1) if i < last

deleteSelectedLayer():
  edit("Delete Layer", control: "halo.layers.list") { doc in
    guard sel else throw .noLayerSelected
    for child in layers where child.parentID == sel:         # before removing the parent
      do { try services.keying.setParent(nil, of: child.id, at: comp.playheadFrame, in: &comp) }
      catch HaloEditError.notBuilt { child.parentID = nil }  # W0 live stub: clear, keep values
    remove sel at i
    doc.selectedLayerID = layers[safe: i]?.id ?? layers.last?.id }   # nil when empty
```

Why `keying.setParent(nil, …)` and not `services.placing` directly:
`PropertyKeying.setParent` is the contract's "clear the parent and keep the
place on screen" (built on `LayerPlacing` in both fake and live), and the
rewrite of x and y must follow the not-animated rule, which is
`PropertyKeying`'s. Writing the tracks here would copy that rule into a
second file (the duplicate-code gate) and break the one home of each value.
The place kept is the child's anchor point at the playhead, as H-J23's
Parent → None keeps it; an animated child gets a key there. On `.fake` and
once layer-keys' live type lands, the child stays put; on `.live` before
then, `LivePropertyKeying` throws `.notBuilt("Parenting")` and the fallback
clears `parentID` and leaves every value as it was. Any other error refuses
the whole delete.

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: layer-panel`, `Fast-Check:
pass`, `Head:`. LP-4 also carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LP-1 | #770 (part) | The four edits, the two one-place moves and `moveTarget`, each one named step through `edit`; duplicate selects the copy; delete un-parents children through `services.keying.setParent(nil, …)` with the `.notBuilt` fallback and selects the layer that took its place | `Sources/HaloModel/HaloLayerEdits.swift`, `Tests/HaloModelTests/HaloLayerEditsTests.swift` | – | ~360 |
| LP-2 | #770 (part) | Turn the Layer commands on: `HaloAvailability+Layers.swift` answers state for Duplicate, Rename, Delete, Bring Forward, Send Backward (New stays as W0 wrote it); `HaloWindow+Layers.swift` routes each to LP-1 (⌫ from the viewer and timeline included) and shows Layer > Rename… as a window-modal `NSAlert` with an `NSTextField` accessory, titled "Rename Layer", buttons Rename and Cancel, whose Rename calls `renameLayer` (needs no state in a W0 file); the edit budget rows | `Sources/HaloModel/Availability/HaloAvailability+Layers.swift`, `Sources/HaloApp/HaloWindow+Layers.swift`, `Tests/HaloModelTests/HaloLayerAvailabilityTests.swift`, `Tests/HaloModelTests/HaloLayerEditsBudgetTests.swift` | LP-1 | ~260 |
| LP-3 | #770 (part) | `HaloLayerList` replaces W0's stub: a system `List` of `SidebarRow`s (rename on the row through `onRename`, select), `.onMove` calling `moveLayer(fromOffset:toOffset:)`, `.onDeleteCommand` sending `.deleteLayer`, the refusal caption under the named row, the empty text; each row `halo.layers.row.<id>` through `.haloControl`; snapshots | `Sources/HaloApp/HaloLayerList.swift`, `Tests/AppSnapshotTests/HaloLayersSnapshots.swift` | LP-1 | ~240 |
| LP-4 | #770 (closes; `feature-done`) | H-J9 `testLayerHousekeeping`, eight steps above, on `-HaloFixture three-layers` | `UITests/HaloJourneyTests+Layers.swift` | LP-2, LP-3, #333 | ~170 |

LP-2 and LP-3 touch disjoint files and can build side by side after LP-1.
LP-2 lands its availability file and its routes in one PR so no Layer item
is ever enabled before it acts (QB-F1). LP-3 keeps the init that W0's one call
site in `HaloCompositionInspector.swift` uses; FD-15 replaces the list whole
by design, so the stub's init is the seam. The lead reads the merged stub at
stage 1: if it can't reach rename, move and delete (no `model` and no
action closures), the lead files that on this feature issue before LP-3 and
routes the actions through `HaloWindow+Layers.swift`, the area file W0
created for exactly this, rather than editing a W0 file. The H-J9 journey
stays on `-HaloFixture`: no live service changes what it reads, and core-loop
(W3) flips it and adds ⌘Z.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| LP-1 | `HaloLayerEditsTests` on `three-layers` (`.fake`), Badge selected: Duplicate gives names Title, Badge copy, Badge, Background, Rig; the copy is selected, its id is new and not among the ids before, its tracks, `parentID`, text, span, opacity and blend equal Badge's; `history.undoTitle` reads "Undo Duplicate Layer" and `services.history.undo(document, in: &history)` returns the four-layer document. Duplicate, undo that way, duplicate again: the second copy's id differs from the first. `renameLayer(badge, to: "  Badge\t2 ")` stores "Badge 2", one step "Rename Layer"; to `"   "` keeps "Badge", sets `refusal` to (`halo.layers.row.<badge id>`, "Enter a name.") and records nothing; to "Badge" records nothing. `moveLayer(badge, to: 3)` gives Title, Background, Rig, Badge, one step "Move Layer", and `viewerSummary` reads "Frame 0: Badge, Background"; `to: 99` clamps to 3; `moveTarget(from: 1, toOffset: 4, count: 4)` is 3, `(from: 2, toOffset: 0)` is 0, `(from: 7, …)` nil; Bring Forward on Title and Send Backward on Rig record nothing. Delete Badge leaves Title, Background, Rig with Background selected, "Undo Delete Layer"; delete Rig (bottom) selects Background; deleting all four leaves no selection and "Frame 0: no layers"; delete with nothing selected sets "Select a layer first." and records nothing. On `parented`, scrub to 12, parent Ball to Rig with `services.keying.setParent`, select Rig, delete: Ball's `parentID` is nil, its world anchor point equals the one before the delete within 1e-6 and its Position X at 12 reads 560.0; one step; undo returns Rig and Ball's parent. The same with `keying` replaced by a test-local stub that throws `.notBuilt("Parenting")`: Ball's `parentID` is nil and its `tracks` are unchanged. On `.live` the delete succeeds and Ball's `parentID` is nil (true with the stub or layer-keys' live type) | a copy reuses an id or lands below, a blank name is stored or recorded, a move lands off by one, a delete leaves a dangling `parentID`, moves a child on screen on `.fake`, or fails on `.live` before layer-keys |
| LP-2 | `HaloLayerAvailabilityTests` on `.fake` and `.live`: `HaloProject()` with no composition gives "Create a composition first." for the five; `empty` gives "Select a layer first."; `three-layers` with Badge selected gives nil for all five; Title selected: Bring Forward "This layer is already at the top.", Send Backward nil; Rig selected: Send Backward "This layer is already at the bottom."; Layer > New is nil whenever a composition exists. `title(for: .undo)` on `.fake` reads "Undo Duplicate Layer", "Undo Rename Layer", "Undo Move Layer", "Undo Delete Layer" after each edit. W0's `HaloCommandTests` still passes (every command enabled or disabled with help) | a Layer command is on with nothing selected, off when it can act, at an end with no reason, or still reads "Not built yet (#770)." |
| LP-3 | Snapshots (macOS) on `three-layers` built as `-HaloFixture` builds it: `halo-layer-list-light/dark.png` (four rows, Badge selected), `halo-layer-list-refused-light/dark.png` ("Enter a name." under Badge after `renameLayer(badge, to: "")`), `halo-layer-list-empty-light/dark.png` (every layer deleted: the empty text). `halo-layers-light/dark.png` from W0 stay as they are unless the row look changed (list them if so) | the caption sits under the wrong row or is missing, the empty text is missing, or the list hides while a layer is selected |
| LP-4 | H-J9 on the `dev` CI run: every assert in steps 1 to 8 | any step's assert |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-F1 no dead controls | the five Layer commands enabled exactly when they act, else disabled with help | `HaloLayerAvailabilityTests` (LP-2); H-J9 steps 6 and 8; W0's `HaloCommandTests` and H-J13 stay green |
| QB-F3 one gesture, one named step | each edit records exactly one step with its name; refused and no-op edits record none | `HaloLayerEditsTests` (LP-1) |
| QB-F4 keyboard parity | ⌫ in the viewer, timeline and list deletes; ⇧⌘D, ⌘], ⌘[ from W0's menu act | H-J9 step 8 (⌫); LP-2's routes for the menu keys |
| HB-9 any edit (feature rows) | `duplicateSelectedLayer` and `deleteSelectedLayer` on `crowd`, each ≤ 2 ms device, ≤ 20 ms debug CI, median and p95 over 200 runs with W0's `HaloBudget` helper | `HaloLayerEditsBudgetTests.duplicateCrowd`, `.deleteCrowd` (LP-2) |
| Audit, all six checks | no `halo` count over `UITests/audit-baseline.json`; new controls carry `halo.layers.*` identifiers, so `identifier` and `unnamed` don't rise | `audit-halo-*.json` on the `feature-done` run; LP-3's and LP-4's PR bodies state the counts they expect |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by LP-4's
  `feature-done` PR is green, with H-J9 passing and W0's H-J0, H-J1, H-J13,
  `testEveryMenuOpens` and `testLayoutAtWidths` unchanged.
- **Audit zero new:** no `halo` count over `UITests/audit-baseline.json`.
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per H-J9 step and the audit
  counts. Expected new shots: `halo-layers-<step>` for the eight steps; the
  rename prompt sheet in step 4; the snapshot PNGs from LP-3.

## Review notes folded in

From the review of the blueprint PR (#767) and of this packet, where they
change this feature:

- **H-J9 drops ⌘Z.** The blueprint's H-J9 ends "Layer > Delete; ⌘Z" and
  asserts the layer comes back. Undo stays disabled until history-files
  lands (`HaloAvailability+History.swift` and `HaloHistory.swift` are
  history-files' files; W0's stub says "Not built yet (#208)."). So H-J9
  reads each step's Edit menu title ("Undo Duplicate Layer", "Undo Rename
  Layer", "Undo Move Layer", "Undo Delete Layer"), which W0's `title(for:)`
  reads from `history.undoTitle` on fakes, and never asserts whether Undo is
  enabled. "⌘Z brings it back" moves to core-loop (W3), which owns `+Layers`
  once every W1 and W2 feature is done. LP-1 proves undo of each edit on
  `.fake` by calling `services.history.undo(_:in:)` on the recorded history,
  not `HaloProject.undo()`.
- **Deleting a parent goes through `PropertyKeying.setParent(nil, …)`**, not
  through `LayerPlacing` directly (Pseudocode says why), with a `.notBuilt`
  fallback for the W0 live stub, tested with a test-local stub so the test
  holds whichever of layer-panel and layer-keys lands first. #770's "leaves
  its children where they are on screen" means at the playhead.
- **The empty text lives in the layer list.** H-J9's empty state names "the
  timeline's empty text", but `HaloTimelineView.swift` is W0's and then
  easing's, and W0's FD-15 doesn't add it (today's view has none). The list
  (this feature's file) shows "No layers yet. Add one from Layer > New." and
  H-J9 reads it there; the timeline's own copy of the line is for easing's
  packet to add when it replaces `HaloTimelineView`.
- **The empty-name error comes from Layer > Rename….** `SidebarRow`'s inline
  rename trims the name and drops an empty one before calling `onRename`
  (`SidebarRow.commitRename`), so the row can never send "". The refusal is
  reached through the Rename prompt, and its message shows under the row as a
  Halo caption (W0's refusal pattern) until SuiteUI #577 gives rows a
  message slot.
- **The prompt is an `NSAlert`.** Layer > Rename… needs a text prompt, and an
  area file can't add SwiftUI state to `HaloWindow`. A window-modal system
  alert from `HaloWindow+Layers.swift` needs none. If W0's `HaloWindow`
  already carries a layer-rename presentation flag, LP-2 uses a SwiftUI
  `.alert` with a `TextField` through it instead.
- **Extra files beyond 8.3's seven:** `HaloLayerAvailabilityTests.swift` and
  `HaloLayerEditsBudgetTests.swift` (new, unique names). #770's body names
  only `HaloLayerEditsTests`; the packet wins.
- **⇧⌘D for Layer > Duplicate** (D6): ⌘D stays Composition > Duplicate until
  the captain answers Q7.
- **Selection after a delete** (not in the blueprint): the layer now at the
  deleted index, else the new bottom layer, else none, so repeated ⌫ empties
  the list in H-J9 step 8.
