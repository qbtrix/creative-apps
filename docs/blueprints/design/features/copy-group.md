# Feature packet: copy-group

**Feature:** duplicate and Option-drag, group and ungroup, and cut, copy
and paste of layers, also between files. The menus, keys, pasteboard
bridge, focus hooks and the Option-drag route are already in place from
wave 0 and show "<Feature> isn't built yet."; this feature fills the three
live types and proves them. (Blueprint F2.)
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/copy-group`

**Covers:** #414 (duplicate and Option-drag), #416 (group and ungroup),
#415 (cut, copy, paste), #288 (part: none of its controls are new here, so
only if the audit names one). Each closes through the task PR that names
it below.

**This packet supersedes the "(c) Journey" lines of #414, #415 and #416:**
their steps go in `UITests/DesignJourneyTests+Arrange.swift` (J7, J8, J9),
not `UITests/DesignJourneyTests.swift`, so no two wave-1 features share a
journey file. #415's "rename a layer, then ⌘C and ⌘V in the field" step uses
the inspector's X field instead (rename is layers-panel's), as J8 says.

**Depends on:** the design-contracts feature issue: C-1 to C-3 fill its
live stubs against its fakes and start when it closes. C-1 and C-5 also
wait on design-seams (the Option-drag route as one "Duplicate" step,
D0-3c); C-4 and C-5 wait on design-window's contract slice DW-a (Edit >
Duplicate and Object > Group and Ungroup, D0-6; the pasteboard bridge and
the copy, cut and paste hooks, D0-5d), and C-4's drag check on DW-b. The
copy pointer shown while Option is held over a layer is design-window
DW-d's (D0-9b decides it, D0-9c draws it); J7 doesn't assert it, so no
task here waits on DW-d. The new group's row expanding after Group is
design-contracts D0-3a. No SuiteUI and no creative-core issue. The lead
checks each piece is on `dev` before the task that needs it; a missing one
becomes a `line:design` issue, not a task here.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Design-scoped macOS run.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CG-a | Duplicate and Option-drag a layer, group and ungroup several, and cut, copy and paste layers, also between files, each one step. | C-1, C-2, C-3, C-4, C-5 | J7, J8, J9 | design-contracts (C-1 to C-3); design-seams (C-1, C-5); design-window DW-a (C-4, C-5) and DW-b (C-4) |

One slice: the three use cases share the journey file and the menus, and
five tasks fit. An Option-drag goes through design-window's live drag box,
so the editor body doesn't run per sample; C-4 checks it.

Blueprint sections: 4 (J7, J8, J9), 5.4 (`LayerDuplicating`,
`LayerGrouping`, `LayerClipboard`), 7.4 (QD-V4, QD-V5), 8.2 (F2).

## Journey steps

In `UITests/DesignJourneyTests+Arrange.swift`, class
`DesignArrangeJourneyTests`, on `cards`, live services:

1. **J7** `testDuplicateAndOptionDrag`: nothing selected, Duplicate is
   disabled with "Select a layer first."; select A; ⌘D ("Undo Duplicate");
   Option-drag A 100 pt down ("Undo Duplicate", one step); Layers shows A
   three times; select Locked from Layers; ⌘D: the copy is unlocked.
2. **J8** `testCutCopyPasteAcrossFiles`: select Pair; ⌘C; ⌘V: the pasted
   Pair lands in Desktop, offset 10, 10, with two children ("Undo Paste");
   select B; ⌘X ("Undo Cut"); relaunch with `-DesignFixture empty`; ⌘V: the
   file holds B (the pasteboard outlives the app); select the pasted B,
   click the inspector's X field, ⌘A, ⌘C, ⌘V, Return: the layer count is
   unchanged (the field acted on its text); put plain text on the
   pasteboard: Edit > Paste with the canvas focused is disabled.
3. **J9** `testGroupAndUngroup`: select A and B; ⌘G: a group row with two
   children, expanded ("Undo Group"); ⇧⌘G: the row is gone ("Undo
   Ungroup"); select A, then Shift-click E1 in Layers (inside Pair): Group
   is disabled with "Select layers that share a parent."

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Edit > Duplicate, Object > Group / Ungroup | nothing selected: disabled with "Select a layer first." | Group across parents: "Select layers that share a parent."; Ungroup with no group selected: "<name> isn't a group." | none |
| Edit > Cut, Copy | nothing selected: disabled (system item, no tooltip; `copyHelp` is "Select a layer first.") | – | none |
| Edit > Paste | the pasteboard holds no Design layers: disabled; `pasteHelp` "The pasteboard holds no Design layers." | bytes of our type that don't decode: Paste does nothing and records nothing | none |
| Canvas after paste | – | – | – (the pasted layers are selected) |

## Contract slice

```swift
// Sources/DesignModel/Live/LiveDuplicating.swift
public struct LiveDuplicating: LayerDuplicating     // copySubtree is public: the clipboard reuses it (#414)
// Sources/DesignModel/Live/LiveGrouping.swift
public struct LiveGrouping: LayerGrouping
// Sources/DesignModel/Live/LiveClipboard.swift
public struct LiveClipboard: LayerClipboard {
    public var pasteboardType: String { "org.creativesuite.design.layers" }
}
/// What Copy puts on the pasteboard: DesignFile's node encoding plus where the layers came from.
struct LayerPayload: Codable { var version: Int; var parentID: String?; var nodes: [DesignNode] }
```

Rules beyond the fakes', from the issues: duplicate copies locked layers
too, unlocked (#414); the group is named "Group N", the lowest N ≥ 1 no
layer on the page uses (#416), takes the topmost member's place, and its
frame is the union; ungroup is refused for a non-group with
`.notAGroup(name)`; paste goes into the selected frame, else the parent the
copies came from when it is on this page, else the top level, offset (10,
10) only when a copy would land exactly on a layer with the same name and
frame (#415); the payload carries `version: 1`, and a payload with a newer
version or no nodes is `.unreadable`.

## Pseudocode

```
LiveDuplicating.duplicate(ids, offset, page, &mint):
  guard nodes = find(ids) nonEmpty else throw .nothingSelected
  for each original (in paint order):
    copy = copySubtree(original, &mint); copy.translate(by: offset); copy.isLocked = false
    insert copy right above original in original's parent
  return DesignEdit("Duplicate", nodes, selection: copies)
copySubtree(node, &mint): children first, then DesignNode(id: mint.nextNodeID(), copying: node)

LiveGrouping.group(ids, page, &mint):
  members = find(ids); guard nonEmpty else .nothingSelected
  parent = sharedParent(ids) or throw .notSameParent
  n = lowest N with no "Group N" on the page
  group = DesignNode(id: mint.next, name: "Group \(n)", kind: .group, frame: union(members))
  group.children = members in their sibling order; put group at the topmost member's index
ungroup(ids): for each selected group, replace it by its children in place; select them

LiveClipboard.encode(ids, page): payload(version: 1, parentID: parent of the first, nodes: find(ids))
paste(data, into p, page, &mint):
  payload = decode or throw .unreadable; guard payload.version <= 1, !nodes.isEmpty else .unreadable
  target = p ?? (payload.parentID if on page) ?? nil
  copies = payload.nodes.map { copySubtree($0, &mint) }
  if any copy equals a layer of target by (name, frame): translate all by (10, 10)
  append to target; select copies; "Paste"
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: copy-group`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. C-5 also
carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| C-1 | #414 (Model part) | `LiveDuplicating` | `Sources/DesignModel/Live/LiveDuplicating.swift`; `Tests/DesignModelTests/DesignDuplicateTests.swift` | design-seams | ~200, 2 |
| C-2 | #416 (Model part) | `LiveGrouping` | `Sources/DesignModel/Live/LiveGrouping.swift`; `Tests/DesignModelTests/DesignGroupTests.swift` | – | ~260, 2 |
| C-3 | #415 (Model part) | `LiveClipboard` and its payload | `Sources/DesignModel/Live/LiveClipboard.swift`; `Tests/DesignModelTests/DesignPasteboardTests.swift` | C-1 (reuses `copySubtree`) | ~280, 2 |
| C-4 | – | The three snapshots the issues name; the Option-drag check | `Tests/AppSnapshotTests/DesignDuplicateSnapshots.swift`, `Tests/AppSnapshotTests/DesignGroupSnapshots.swift`, `Tests/AppSnapshotTests/DesignPasteboardSnapshots.swift`, `Tests/AppSnapshotTests/DesignArrangeDragTests.swift` | C-1, C-2, C-3; design-window DW-a, DW-b | ~240, 4 |
| C-5 | #414, #415, #416 (close all three) | J7, J8, J9 | `UITests/DesignJourneyTests+Arrange.swift` | C-1, C-2, C-3; design-seams; design-window DW-a | ~300, 1; `feature-done` |

C-1 and C-2 run side by side (C-2 once design-contracts closes, C-1 once
design-seams has too, since its Option-drag test runs through the route);
C-3 follows C-1. C-4 and C-5 each need the
live behavior of all three Model tasks, not each other; C-5 carries
`feature-done`, so the lead merges it after C-4. No task edits a view: every
control these issues need is wave 0's. No task edits a shared doc
(`docs/c4/model.json`, `docs/design.md`, the blueprint, `waves.md`): the new
`Live/` files sit in the DesignModel folder, which its C4 component already
covers.

## Build waves

- Wave 1: C-1, C-2. Independent in this wave: both.
- Wave 2: C-3.
- Wave 3: C-4, C-5 (`feature-done`, final). Independent in this wave: both.

Longest chain: C-1 → C-3 → C-4 (3).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| C-1 | `DesignDuplicateTests` (#414 (a), through the workspace on `.live`): duplicating a frame with two children gives three new ids, none equal to an existing one, at +10, +10, directly above the original; Undo removes all three and restores the selection; an Option-drag by (40, 0) leaves the original in place and the copy at +40, one step; Duplicate with nothing selected changes nothing and records no step; duplicating Locked gives an unlocked copy; a file saved after duplicating opens again with no repeated id; the copy equals the original except ids, offset and lock (QD-V5) | an id repeats, a copy lands in the wrong parent or place, keeps the lock, or two steps are recorded |
| C-2 | `DesignGroupTests` (#416 (a)): grouping two of three rectangles gives a group whose frame is their union, at the topmost one's index, named "Group 1", children unmoved (every leaf frame equal, QD-V4); a second group is "Group 2"; ungroup puts them back at the same indexes and positions; A with E1 is refused with "Select layers that share a parent." and changes nothing; moving the group by (5, 5) moves both children by (5, 5); Undo after Group restores the tree and selection; a saved file with a group opens again; Ungroup on A throws `.notAGroup("A")` | a leaf moves, the order changes, a cross-parent group is made, or a name repeats |
| C-3 | `DesignPasteboardTests` (#415 (a)): copy then paste a frame with children gives new ids and the same names, fills and relative positions; paste into a selected frame nests the copies there; pasting over the original offsets by (10, 10), and pasting where nothing matches does not; cut removes and Undo restores with the selection; bytes from `copySelection()` paste into a second `DesignWorkspace` (another file, built in the test with no node whose id is the source parent's) into its top level; garbage bytes, a payload with `version: 2` and an empty payload throw `.unreadable` and change nothing; `pasteHelp` of plain-text bytes is "The pasteboard holds no Design layers." | a pasted id collides, the destination rule is wrong, or bad bytes change anything |
| C-4 | `DesignDuplicateSnapshots`: `design-duplicate-light.png`, `design-duplicate-dark.png` (original and copy); `DesignGroupSnapshots`: `design-group-light.png`, `design-group-dark.png` (a group of two selected, canvas and Layers rows); `DesignPasteboardSnapshots`: `design-paste-light.png`, `design-paste-dark.png` (a frame with two children pasted beside the original). `DesignArrangeDragTests` (design-window D0-8b's `dragSamples`): a 120-sample Option-drag of A on `cards` runs `DesignEditor`'s body 3 times or fewer and ends with one "Duplicate" step | a PNG is missing or shows the wrong tree, or the editor body runs per sample |
| C-5 | J7, J8, J9 pass on the macOS run; J7 fails if an Option-drag records two steps; J8 fails if ⌘V in the X field adds a layer; J9 fails if the cross-parent Group is enabled | any undo name, count or disabled reason differs |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QD-V4 group and ungroup move nothing | every leaf frame equal | `DesignGroupTests.groupMovesNothing`, `.ungroupMovesNothing` |
| QD-V5 duplicate and paste copy faithfully | equal but ids, offset, lock | `DesignDuplicateTests.copyIsFaithful`, `DesignPasteboardTests.pasteIsFaithful` |
| QD-S9 any document edit | ≤ 1 ms / ≤ 10 ms (design-seams' `DesignBudgetTests.applyStep` covers duplicate, group and paste on `crowd`) | `DesignBudgetTests.applyStep` |
| QB-F1 no dead controls | Duplicate, Group, Ungroup, Cut, Copy, Paste act or say why | J7, J8, J9; J15 |
| QB-F3 one gesture, one step | ⌘D, Option-drag, ⌘G, ⇧⌘G, ⌘X, ⌘V one step each | J7, J8, J9 |
| the editor body doesn't run per sample | ≤ 3 `DesignEditor` body runs over a 120-sample Option-drag | `DesignArrangeDragTests` (C-4) |
| text fields keep system Cut, Copy, Paste | the X field's ⌘C and ⌘V act on text | J8 |

## Done check

CG-a, the only slice, is done when J7, J8 and J9 pass on the Design-scoped
run after C-5; that is also the feature's done:

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J7, J8, J9 new; J1 and J15 still pass (J15 now finds Duplicate,
  Group and Ungroup enabled on a selection).
- **Audit zero new:** that run's `design` counts are at or under the
  baseline.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey and the audit counts.
