# Feature packet: layers-panel

**Feature:** a Layers panel you can organise from: rename layers and pages
in place, drag rows to reorder and nest, Object > Arrange (front, forward,
backward, back), the group row's own eye and lock, and a lock that commits
an open text edit first. (Blueprint F4.)
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/layers-panel`

**Covers:** #613 (lock mid text edit drops the typing), #589 (Design half:
the journey hides a group from its row's eye; the SuiteUI half is
lists-and-layers LL-9, which files a `line:design` follow-up: if that
issue exists when the lead starts, L-6 closes it instead and only
references #589), #288 (part: the rows' ids). The lead files at stage 1 one
`gap` issue, "Design: rename, reorder and nest layers from the panel, and
Object > Arrange" (`gap`, `line:design`, `p1`, `in-progress`; blueprint
8.1), which L-5 closes.

**Depends on:** the design-window feature issue (Arrange items, Rename
Page…, the rename presentation state in `DesignLayersPanel.swift`, and the
`moveLayer` and `run(.arrange)` actions). It does NOT wait on SuiteUI's
lists-and-layers feature (#577, #108, #73, #589, #111): until those land,
rename is by double-click only (no Return, no "Rename" action), the rows
have no context menu, and J12's group-row eye step is an `XCTSkip` naming
#589. When lists-and-layers merges, a `line:design` follow-up (filed by
LL-9; the rename keys and context menus come from LL-6, LL-7 and LL-8) adopts the rest. P3 needs #330 and #333
(suite-harness). No creative-core issue.

Blueprint sections: 4 (J12, P3), 5.4 (`LayerOrdering`), 6 (rule 5, the
Layers tab row), 7.1 (QD-S10), 7.3 item 4, 8.2 (F4).

## Journey steps

In `UITests/DesignJourneyTests+Layers.swift`, class
`DesignLayersJourneyTests`, on `two-pages`, live services:

1. **J12** `testLayersRenameReorderNest`: double-click the A row, type
   "Avatar", Return: the row reads "Avatar" ("Undo Rename Layer"); rename it
   to an empty name: refused, the row keeps "Avatar", nothing recorded;
   drag B above C (Layers lists Desktop front to back as Hidden, Locked, Pair,
   Title, C, B, A, so C starts right above B): the order reads B above C
   ("Undo Move Layer"); drag
   Title into Pair: Title is nested under Pair; select B, Object > Arrange >
   Send to Back: B is last ("Undo Send to Back"); hide Pair from its own
   row's eye and ⌘Z (`XCTSkip` naming #589 until the SuiteUI half lands);
   rename page "Mobile" to "Phone screens" with Page > Rename Page… ("Undo
   Rename Page"). Each step is one undo step.
2. **P3** `testLayerListScroll` (`+PerfLayers`, class
   `DesignPerfLayersJourneyTests`) on `crowd`: scroll Layers end to end with
   every frame expanded; report-only.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Layers, a page with no layers | "No layers on this page." in secondary text, with the Frame tool's hint | – | none |
| Row rename | – | an empty name: the row keeps its old name and the status message reads "A name can't be empty." | – |
| Drag to reorder | – | a drop the Model refuses (a layer into itself, into a rectangle) shows no insertion line and changes nothing | – |
| Object > Arrange | nothing selected: disabled with "Select a layer first."; a layer already at the front: Bring to Front and Forward disabled with "Nothing would change." | – | – |
| Lock while editing text | – | – | – (the typing is committed first, then locked: two steps "Edit Text", "Lock Layer") |

## Contract slice

`LayerOrdering` (blueprint 5.4) filled by `Sources/DesignModel/Live/LiveOrdering.swift`.
Rules beyond the fake's: `move` refuses `.intoItself(name)` for a layer
into its own subtree, `.notAContainer(name)` for a parent that is not a
frame or group, `.locked(name)` for a locked layer or target; `index`
counts the new parent's children back to front after removal; `arrange`
works within each selected layer's own parent and keeps the selected
layers' relative order; Bring Forward and Send Backward move one place;
an arrange that changes nothing is `.unchanged` (so its help says "Nothing
would change.": the help law's already-there case, as single-layer Align).

Model additions in `DesignLayerToggles.swift`:

```swift
/// The Layers rows' drop target for a drop at `row` and `position` (above, below, into).
/// `index` counts the new parent's children after `draggedID` is removed, as `LayerOrdering.move` expects.
public func layerDrop(_ draggedID: String, onto rowID: String, _ position: DesignDropPosition) -> (parentID: String?, index: Int)?
public enum DesignDropPosition: Sendable { case above, below, into }
```

and in `DesignWorkspace.swift`: `setNodeLocked` and `toggleNodeFlag(.locked)`
commit an open text edit on that node or inside it first (#613), and
`renameNode` / `renamePage` trim whitespace and refuse an empty name with
`DesignTreeError.emptyName`.

## Pseudocode

```
LiveOrdering.move(id, into p, at i, page):
  node = find(id) or .unknownID; if lockedInTree(node) → .locked(name)
  if p: guard p != id, !subtree(node).contains(p) else .intoItself(name)
        guard node(p).kind.holdsChildren else .notAContainer(name of p)
  tree = remove(id); insert at clamp(i, 0, count) in p's children (or top level)
  tree == page.nodes → .unchanged; else DesignEdit("Move Layer", selection: [id])

arrange(step, ids): group ids by parent; per parent, move the selected block:
  front: to the end; forward: each one place up (topmost first); backward, back: mirror

layerDrop(dragged, row, pos):
  above → (parent(row), index(row) + 1)   # rows list front to back, children back to front
  below → (parent(row), index(row))
  into  → row is a frame or group ? (row, children.count) : nil
  if dragged sits in the same parent at an index below the result: index -= 1   # counted after removal

lock(id) while editingTextID is id or inside id: commitTextEdit(); then lock    # #613
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: layers-panel`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. L-7 also
carries `feature-done`. Paths drop `Sources/DesignModel/` and
`Sources/DesignApp/`; Model tests are `Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| L-1 | gap "rename, reorder, nest, Arrange" (Model part) | `LiveOrdering`: move with its refusals; arrange | `Live/LiveOrdering.swift`; tests `DesignOrderingTests.swift` | – | ~300, 2 |
| L-2 | gap (Model part) | `layerDrop` and `DesignDropPosition` | `DesignLayerToggles.swift`; tests `DesignLayerDropTests.swift` | L-1 | ~150, 2 |
| L-3 | #613 (closes) | A lock commits an open text edit first; rename trims the name (blank names are already refused) | `DesignWorkspace.swift`; tests `DesignLockTextEditTests.swift`, `DesignRenameTests.swift` | – | ~180, 3 |
| L-4 | gap (view part); #288 (part) | Layers rows: rename on double-click through `SidebarRow`'s rename, drag to reorder and nest through `layerDrop` and `moveLayer`, the empty page state, row ids `design.layer.<id>` | `DesignLayersPanel.swift`; snapshots `DesignLayersSnapshots.swift` | L-1, L-2, L-3 | ~300, 2 |
| L-5 | gap (closes) | J12 | `UITests/DesignJourneyTests+Layers.swift` | L-4 | ~250, 1 |
| L-6 | #589 (Design half), or LL-9's follow-up | J12's group-row eye step without the skip, once lists-and-layers LL-9 has merged; until then this task waits and the lead records it as blocked in RECORD.md | `UITests/DesignJourneyTests+Layers.swift` | L-5; lists-and-layers LL-9 | ~30, 1 |
| L-7 | – | QD-S10 model budget; P3 | tests `DesignLayersBudgetTests.swift`; `UITests/DesignJourneyTests+PerfLayers.swift` | L-5 | ~150, 2; `feature-done` |

L-1 and L-3 run side by side; L-2 follows L-1 (its test reads
`LiveOrdering`'s refusals). L-6 is the only task that waits on another
line. When LL-9 has merged by the time L-5 lands, L-7 depends on L-6 so the
`feature-done` PR is the last; if LL-9 has not merged when L-7 is ready,
L-7 ships with `feature-done` and L-6 becomes a `line:design` issue the lead files
("Design: J12 hides a group from its row's eye", `Depends on:` the
lists-and-layers feature issue), so the feature does not stall on SuiteUI.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| L-1 | `DesignOrderingTests` on `cards`, `.live`: move B to index 2 of Desktop puts it above C (after B is removed, Desktop's children are A, C, Title, …); move Title into Pair at 2 nests it last; A into E1 throws `.notAContainer("E1")`; Pair into its own child throws `.intoItself("Pair")`; Locked throws `.locked("Locked")`; a move to the same place throws `.unchanged`; Send to Back on B makes it Desktop's first child; Bring Forward on A and B keeps their relative order; Send to Back on A (already Desktop's first child) is `.unchanged` and its help is "Nothing would change."; each is one named step; the contract law on `.live` | a refusal is missing, the order is wrong, or a cycle is created |
| L-2 | `DesignLayerDropTests`: above, below and into on a frame row, a group row and a rectangle row give the documented targets; into a rectangle is nil; dragging A (Desktop's first child) above B gives (Desktop, 1), which after A's removal lands right above B; dragging C below A gives (Desktop, 0); a drop onto the dragged row's own child is refused by `moveLayerHelp` on `.live` (L-1's type) | a drop maps to the wrong parent or index |
| L-3 | `DesignLockTextEditTests`: #613's repro: lock the group mid edit: the text reads "Typed", the undo names are "Undo Lock Layer" then "Undo Edit Text", `editingTextID == nil`. `DesignRenameTests`: "  Avatar " becomes "Avatar" for a layer and a page (the new part: `renameNode` and `renamePage` already refuse blank names on `dev`, which the test keeps covering); a rename to the same trimmed name records nothing | the typing is lost, a name keeps its spaces, or a no-op rename records a step |
| L-4 | `DesignLayersSnapshots` adds `design-layers-renaming` (the A row in rename) and `design-layers-nested` (Title inside Pair, expanded); today's `design-layers-*` PNGs unchanged otherwise; 7.3 item 4 (eye and lock columns share one x at every depth) asserted on the hosted view's frames | the columns drift with depth, or a row is missing |
| L-5 | J12 passes on the macOS run with its group-row step skipped by name; it fails if a step records more than one undo step or the empty rename changes the row | an undo name, order or name differs |
| L-6 | J12's group-row step runs: Pair's eye hides Pair ("Undo Hide Layer"), ⌘Z shows it | the eye is not its own element |
| L-7 | `DesignLayersBudgetTests.layerRows` (QD-S10): building 2,000 expanded rows on `crowd` ≤ 50 ms under the Linux debug gate; P3 writes `perf-design-layers.json` (report-only) | the row build is over its gate |

## Quality tests

| quality row | budget (device / Linux debug gate; screen half) | test |
|---|---|---|
| QD-S10 Layers list, 2,000 rows expanded | row build ≤ 5 ms / ≤ 50 ms; scroll p95 frame interval ≤ 1.5 refreshes (QB-L10) | `DesignLayersBudgetTests.layerRows`; P3 |
| 7.3 item 4 toggle columns | one x for eyes, one for locks, any depth, to 0.5 pt | `DesignLayersSnapshots`, `testLayoutAtWidths` |
| QB-F3 one gesture, one step | rename, drag, Arrange one step each | J12 |
| no lost work | a lock mid edit keeps the typing | `DesignLockTextEditTests` |

## Done check

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J12 and P3 new (J12's group-row step skipped by name until L-6);
  J3's Layers eye step and J15 still pass.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline; every row carries `design.layer.<id>`.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey, the audit counts, and L-6's
  state (done, or the follow-up issue number).
