# Feature packet: lists-and-layers

**Feature:** the sidebar and layer rows every app's panels use: a dimmed
row for hidden or locked layers, `LayerList` (a flat panel list with eye and
lock columns, rename and drag to reorder), a rename the app can refuse
inline, rename from the keyboard, row context menus, child rows whose
toggles are their own elements, app-owned expansion, and the thumbnail grid
on its contract, with the window page, the layer and grid pages and their
journeys.
**Line:** `line:suiteui` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/lists-and-layers`

**Covers:** #146 (S15 `LayerList` and dimmed rows; closes with LL-5), #577
(refusable rename; LL-6), #108 (keyboard rename; LL-7), #73 (row context
menus; LL-8a, LL-8b), #589 and #111 (child toggles, app-owned expansion; LL-9),
#249 (nesting snapshot; LL-10), #284 (header contrast; LL-11), #308, #311
and #312 (the rename guard's behavioural journey; LL-14). LL-1 to LL-3,
LL-12, LL-13, LL-15 to LL-17 have no issue of their own (LL-4 says "Part of
#146").

**Depends on:** the suite-harness feature issue (#778): `ContractTypes.swift`
(#773), `.suiteControl` (#775), the `insertionLine` token and the
refused-rename contrast pair (#774), `SuiteWindow`'s gallery hook and the
stub `Gallery/GalleryLists.swift` (#776), the journey bundle (#333) and
goldens (#331, #332). No creative-core issue.

**This packet supersedes the "Touch only these files" list** of #146 (S15)
and adds contract, gallery and Fake-test files to each covered issue
(review of #765).

**App features it unblocks:** Flare's layers and scenes panel (F11a #350),
Halo's inline rename refusal (#139 drops its modal alert once LL-6 lands)
and its composition context menu (the follow-up of closed #35, after LL-8a),
Design's Layers group toggles and expansion (follow-ups of closed #50 and
PR #549, after LL-9).

**Kernel fold (2026-10-17, editor-kernel design).** The one layers panel
every app adopts is `LayerTreeList` (`Sources/SuiteUI/LayerTreeList.swift`),
built by editor-kernel's EK-4 and EK-5 over the kernel's `LayerRow`: nested
rows, drag into a parent, eye and lock with cascade dimming, multi-select,
thumbnails, hover, pressed and selected states, and row context menus. LL-5
and LL-8b (the flat `LayerList`) are withdrawn so the panel is not built
twice; #146 and #73's layer-row half close with EK-4 and EK-5. The row
primitives stay here (LL-4 dimming, LL-6 refusable rename, LL-7 keyboard
rename, LL-8a menus, LL-9 expansion): `LayerTreeList` composes `SidebarRow`
and takes each as it lands. LL-13's `layers` pages show `LayerTreeList`, and
LL-16's layer-list baseline is `LayerTreeList`'s. The apps' panels migrate in
`adopt-kernel-layers` (docs/blueprints/suiteui/features/adopt-kernel-layers.md).

**Not this line's:** #589's second acceptance bullet (Design's journey
hides a group from its row's eye) and #284's Design half (`Section("Pages")`
in Design's Layers panel) are Design code. LL-9 and LL-11 each file a
`line:design` issue for them and link it in the PR; the SuiteUI part closes
the issue.

Blueprint sections: 4.2 (SJ1b, SJ17, SJ18), 4.3 (SJ22), 4.4 (SP4), 5.2
(UC9, UC10), 6.2 (Layer list row), 7.1 (QB-S7), 7.4 (QB-S28), 8.3.

**File it receives from the harness:** `SuiteWindow.swift` (with its gallery
hook and toolbar identifiers, SH-6) and the stub `Gallery/GalleryLists.swift`.
The `window` page builds its inner `SuiteWindow` through the internal init
that skips the flag (SH-6); LL-13 must use that init.

**Building blind.** Every file is macOS-only; the rename and reorder rules
go in `ListEditing.swift` and `GridSelection.swift` (Foundation-only, pure,
unit-tested), and the views call them. Check every SwiftUI API with
`apple-docs` (`DisclosureGroup(isExpanded:)`, `.contextMenu`,
`.accessibilityAction(named:)`, `.onKeyPress`), and say so in the PR.

## Journey steps

In `UITests/SuiteJourneyTests+Lists.swift` (SJ22 and SP4 in
`UITests/SuiteJourneyTests+ListMenus.swift`), on the `window`, `layers`,
`layers-300`, `grid` and `grid-2000` pages:

1. **SJ1b** `testWindowShellFitsAtEveryWidth`: widths 880, 1024, 1280, 1440:
   sidebar, content and inspector inside the window (1 pt), no overlap over
   1 pt, content ≥ `contentMinimum.width`, sidebar and inspector within their
   token ranges; `offscreen`, `overlap` and `contrast` 0 (the last is #284's
   proof).
2. **SJ17** `testLayerListToggleRenameReorder`: Ball's eye logs
   `toggle eye ball`; Shadow's lock dims its row (the log says "locked");
   double-click Ball's title, `Hero` ↵ logs `rename ball Hero`; focus Shadow,
   ↵, `Taken` ↵ is refused with the page's message under the row and the
   draft stays; Escape restores "Shadow"; drag Shadow above Hero logs
   `move shadow 0`; a child row's eye is its own element and logs
   `toggle eye child` (#589). **The rename guard** (#308, #311, #312):
   double-click Ball's eye toggle and then the blank space between its title
   and toggles: no text field appears in the row, and the eye ends where it
   started.
3. **SJ18** `testThumbnailGridSelectsByClickAndKeys`: click 3, ⇧-click 6,
   ⌘-click 4, →: log `3`, `3,4,5,6`, `3,5,6`, then the anchor moves one and
   the log states the result, as `GridSelection` gives.
4. **SJ22** `testRowContextMenus`: right-click Ball, Duplicate logs
   `menu duplicate ball`; Delete is disabled and its entry carries the item's
   help (#73).
5. **SP4** `testListAndGridScroll`: scroll `layers-300` and `grid-2000` end to
   end; frame-interval p95, series `layers-scroll` and `grid-scroll`, ≥ 60
   intervals each. Report-only.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| `layers` | no rows: "No layers yet." | a refused rename: the field stays open with the typed text and the message under it in `stateError` with the exclamation symbol | none |
| A dimmed row | – | – | – (hidden or locked: title and symbol in `textSecondary`; the row stays selectable and its toggles keep their look) |
| Row context menu | a row with no actions builds no menu | a disabled action shows its reason as help | none |
| `grid` | no items: the page's `EmptyStateView` | none | an item without pixels shows its caption on the placeholder fill |
| `window` | an empty sidebar section shows its header only | none | none |

## Contract slice

LL-1 lands two files verbatim from `docs/blueprints/suiteui/contracts/Contracts.swift`:

```swift
// Contracts/GridSelecting.swift (UC9): ClickKind (.plain, .extend, .toggle), GridPick<ID>
public protocol GridSelecting: Sendable {
    func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID>
    func move<ID: Hashable & Sendable>(_ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int) -> GridPick<ID>
    func columns(width: Double, minimum: Double, spacing: Double) -> Int
}
// Contracts/ListEditing.swift (UC10): RenameOutcome (.renamed, .refused(message:draft:), .unchanged, .cancelled)
public protocol ListEditing: Sendable {
    func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome
    func cancelRename(_ draft: String, original: String) -> RenameOutcome
    func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID]
    func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int
}
```

Public API this feature adds (additive; existing calls compile unchanged):

```swift
SidebarItem(..., isDimmed: Bool = false)                                     // LL-4
LayerList(rows:, onToggle:, onRename:, onMove:)   // LL-5; contextActions: added by LL-8b
SidebarRow(..., onRename: (@MainActor (String) -> String?)?)                 // LL-6, the Void form kept
SuiteWindow(..., onRename: (@MainActor (SidebarItem.ID, String) -> String?)?,   // LL-6, an overload; the Void form kept
            contextActions: ((SidebarItem.ID) -> [ToolbarAction])? = nil,   // LL-8a
            expanded: Set<SidebarItem.ID>? = nil, onExpand: (@MainActor (SidebarItem.ID, Bool) -> Void)? = nil)  // LL-9
```

## Pseudocode

```
SuiteListEditing : ListEditing                                    # LL-2
  commitRename(draft, original, validate):
    name = draft.trimmed; if name.isEmpty || name == original -> .unchanged
    if let m = validate(name) -> .refused(message: m, draft: draft)        # draft kept as typed
    -> .renamed(name)
  cancelRename -> .cancelled
  reordered(order, id, index): guard order.contains(id) else order; rest = order - id; insert at clamp(index, 0...rest.count)
  dropIndex(y, h, n): guard h > 0, y finite else 0; clamp(Int((y / h).rounded()), 0...n)

SidebarRow rename (LL-6, LL-7)
  begin: double-click on title or icon (today), Return on the focused row, or the "Rename" accessibility action
  commit: switch editing.commitRename(draft, item.title, validate: onRename) {
            .renamed: close; .unchanged: close; .refused(m, d): keep field open, draft = d, message = m }
  typing clears message; Escape -> cancelRename -> close, title restored; focus lost while refused -> cancel (no loop)

LayerList (LL-5)
  List(.plain) of SidebarRow; eye and lock in their fixed column; drag: dropIndex -> reordered -> onMove(id, index);
  insertion line `insertionLine` pt in accent at the drop index; probe drew("layers-scroll") per drawn frame while scrolling

SidebarNode (LL-8a, LL-9); LayerList rows take the same menu (LL-8b)
  .contextMenu { ForEach(actions) { Button(title, systemImage).disabled(!enabled).help(help) } } only when actions non-empty
  DisclosureGroup(isExpanded: expanded.map { Binding(get: contains(id), set: onExpand?(id, $0)) } ?? own @State)
  parent row: label split so its toggles are separate accessibility elements (apple-docs: accessibilityElement(children:),
  accessibilityChildren); proven by SJ17's child-eye step, not by assumption

SuiteGridSelecting : GridSelecting (LL-3): wraps GridSelection.click / move / columns unchanged
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: lists-and-layers`,
`Fast-Check: pass`, `Head:`. LL-17 carries `feature-done`. Each component
task's snapshot test also calls `assertGolden` through `SnapshotHost` in the four appearances (QB-V5), so the baseline tasks at the end have recorded actuals to commit. Each component task registers its controls with `.suiteControl` (eye, lock, rename field,
menu items; a test that each reason equals its `.help`) and emits its
interval series. No task edits `docs/c4/model.json`, `docs/design.md`,
`Tokens.swift` or `project.yml`.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| LL-1 | – | The two list contracts and their Fakes | `Sources/SuiteUI/Contracts/GridSelecting.swift`, `Sources/SuiteUI/Contracts/ListEditing.swift`, `Tests/SuiteUITests/ListFakeTests.swift` | – |
| LL-2 | – | `SuiteListEditing`: rename outcomes, reorder, drop index (QB-S14) | `Sources/SuiteUI/ListEditing.swift`, `Tests/SuiteUITests/ListEditingTests.swift`, `Tests/SuiteUITests/ListBudgetTests.swift` | LL-1 |
| LL-3 | – | `SuiteGridSelecting` over `GridSelection`; the 40-sequence reference (QB-S28) and QB-S12 | `Sources/SuiteUI/GridSelection.swift`, `Tests/SuiteUITests/GridSelectionReferenceTests.swift`, `Tests/SuiteUITests/ListBudgetTests.swift` | LL-2 |
| LL-4 | #146 (part) | `SidebarItem.isDimmed`; `SidebarRow` dims title and symbol | `Sources/SuiteUI/SidebarRow.swift`, `Tests/SuiteUITests/SidebarTests.swift`, `Tests/AppSnapshotTests/SuiteSidebarSnapshots.swift` | – |
| LL-5 | #146 (closes with editor-kernel EK-4) | Withdrawn: the layer panel is `LayerTreeList` (editor-kernel EK-4, EK-5) | – | – |
| LL-6 | #577 | A rename the app can refuse: the draft stays, the message shows inline; threaded through `SidebarSection` and `SuiteWindow` | `Sources/SuiteUI/SidebarRow.swift`, `Sources/SuiteUI/SidebarSection.swift`, `Sources/SuiteUI/SuiteWindow.swift`, `Tests/SuiteUITests/SidebarRenameRefusalTests.swift`, `Tests/AppSnapshotTests/SuiteSidebarSnapshots.swift` | LL-2, LL-4 |
| LL-7 | #108 | Rename from Return on the focused row and from a "Rename" accessibility action | `Sources/SuiteUI/SidebarRow.swift`, `Tests/SuiteUITests/SidebarKeyboardRenameTests.swift` | LL-6 |
| LL-8a | #73 (part) | Row context menus from `ToolbarAction`s, disabled with help, on `SuiteWindow`'s sidebar rows | `Sources/SuiteUI/SidebarSection.swift`, `Sources/SuiteUI/SuiteWindow.swift`, `Tests/SuiteUITests/SidebarContextMenuTests.swift` | LL-6 |
| LL-8b | #73 (closes with editor-kernel EK-5) | Withdrawn: row context menus land on `LayerTreeList` in editor-kernel EK-5 | – | – |
| LL-9 | #589, #111 (closes both) | App-owned expansion; a parent row's toggles are their own elements; files the `line:design` follow-up for #589's Design journey | `Sources/SuiteUI/SidebarSection.swift`, `Sources/SuiteUI/SuiteWindow.swift`, `Tests/SuiteUITests/SidebarNestingTests.swift` | LL-8a |
| LL-10 | #249 | The nesting snapshot draws through `SidebarNode` in a sidebar `List`, expanded through LL-9's seam, so reverting the two-level cap changes the PNG | `Tests/AppSnapshotTests/SuiteSidebarNestingSnapshots.swift` | LL-9 |
| LL-11 | #284 | The section header's text stays `SuiteColor.textSecondary` (from #599, `SidebarSection.swift:31`; not `secondaryText`, the system grey #284 measured) and a test pins it; files the `line:design` issue for Design's `Section("Pages")` | `Sources/SuiteUI/SidebarSection.swift`, `Tests/SuiteUITests/SidebarEdgeTests.swift` | LL-9 |
| LL-12 | – | `ThumbnailGrid` through `SuiteGridSelecting`; `grid-scroll`; item registration; goldens of both grid sizes | `Sources/SuiteUI/ThumbnailGrid.swift`, `Tests/AppSnapshotTests/SuiteGridSnapshots.swift`, `Tests/AppSnapshotTests/SuiteGridSmallSnapshots.swift` | LL-3 |
| LL-13 | – | The `window`, `layers`, `layers-300`, `grid` and `grid-2000` gallery pages, their log and the Fakes path | `Sources/SuiteUI/Gallery/GalleryLists.swift` | LL-5, LL-8b, LL-9, LL-12 |
| LL-14 | #308, #311, #312 (closes all three) | SJ1b, SJ17 (with the rename-guard steps), SJ18 | `UITests/SuiteJourneyTests+Lists.swift` | LL-7, LL-11, LL-13 |
| LL-15 | – | SJ22, SP4 | `UITests/SuiteJourneyTests+ListMenus.swift` | LL-13 |
| LL-16 | – | Baselines: sidebar row (plain, dimmed, refused), layer list, nesting in four appearances | `Tests/AppSnapshotTests/Golden/lists/` (12 PNGs) | LL-5, LL-10 (the CI run after both merged) |
| LL-17 | – | Baselines: grid, small grid in four appearances; `feature-done` | `Tests/AppSnapshotTests/Golden/lists/` (8 PNGs) | LL-12's CI run, LL-14, LL-15, LL-16 |

Sizes: LL-1 ~200 lines; LL-2 ~260; LL-3 ~300 (the reference is data);
LL-4 ~90; LL-5 ~330; LL-6 ~340; LL-7 ~150; LL-8a ~150; LL-8b ~70; LL-9 ~280; LL-10
~120; LL-11 ~60; LL-12 ~150; LL-13 ~380 (if it passes 400, the `grid` pages move to LL-13b in the same file, chained); LL-14 ~360; LL-15 ~200.

Links (rule (b), see `docs/factory/packets.md`): `SidebarRow.swift` LL-4 → LL-6 → LL-7, and
`SuiteSidebarSnapshots.swift` LL-4 → LL-6; LL-6 and LL-5 call LL-2's
`SuiteListEditing`; LL-5 uses LL-6's refusable rename; `SidebarSection.swift`
and `SuiteWindow.swift` LL-6 → LL-8a → LL-9 → LL-11; `LayerList.swift`
LL-5 → LL-8b, which reuses LL-8a's menu and test file; `ListBudgetTests.swift`
LL-2 → LL-3; LL-12 calls LL-3's `SuiteGridSelecting`; LL-13's pages call
`LayerList` (LL-5, LL-8b), the expansion seam (LL-9) and `ThumbnailGrid`
(LL-12); SJ17 needs LL-7's Return rename and SJ1b LL-11's header pin, so
LL-14 waits for them; SJ22 and SP4 have their own journey file, so LL-15
needs only LL-13's pages. LL-16 and LL-17 commit the actuals of a macOS run
on `dev` after their snapshot tasks: LL-16 commits LL-4's, LL-5's, LL-6's
and LL-10's (LL-4 and LL-6 are ancestors of LL-5 and LL-10), and LL-17
LL-12's; LL-17 carries `feature-done`, so its
run must hold every journey.
`SuiteSidebarToggleColumnSnapshots.swift`, `SuiteWindowLaunchSnapshots.swift`,
`SuiteWindowMinimumSnapshots.swift` and the other `Sidebar*`/`GridSelection*`
tests are this feature's in wave 2 and must keep passing unchanged.

## Build waves

The packet edits no shared doc (`docs/c4/model.json`, `docs/design.md`, a
blueprint or `waves.md`), so no docs task is added.

- Wave 1: LL-1, LL-4. Independent in this wave: both.
- Wave 2: LL-2. Independent in this wave: LL-2 alone.
- Wave 3: LL-3, LL-6. Independent in this wave: both.
- Wave 4: LL-5, LL-7, LL-8a, LL-12. Independent in this wave: all four.
- Wave 5: LL-8b, LL-9. Independent in this wave: both.
- Wave 6: LL-10, LL-11, LL-13. Independent in this wave: all three.
- Wave 7: LL-14, LL-15, LL-16. Independent in this wave: all three.
- Wave 8: LL-17 (`feature-done`, final).

Longest chain: LL-1 → LL-2 → LL-6 → LL-5 → LL-8b → LL-13 → LL-14 → LL-17 (8);
LL-1 → LL-2 → LL-6 → LL-8a → LL-9 → LL-13 → LL-14 → LL-17 is as long.
Chain of 8: `SuiteListEditing` (LL-2) conforms to LL-1's `ListEditing`;
`SidebarRow`'s rename (LL-6) commits through `SuiteListEditing`; `LayerList`
(LL-5) renames through LL-6's refusable `String?` form; LL-8b adds
`contextActions:` to LL-5's `LayerList.swift`; the `layers` page (LL-13)
passes those menus; SJ17 and SJ18 (LL-14) drive LL-13's pages; LL-17's
`feature-done` run is the done check for LL-14's journeys. The other path
has LL-8a and LL-9 edit `SidebarSection.swift` and `SuiteWindow.swift`
after LL-6, and the `window` page pass LL-9's `expanded:`/`onExpand:`.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| LL-1 | `ListFakeTests`: each Fake gives `main.swift`'s literal result with its gap (single selection only; never refuses, never trims) | a Fake loses its gap |
| LL-2 | `ListEditingTests`: `"  Hero "` → `.renamed("Hero")`; `""` and the same title → `.unchanged`; `validate` returning "Taken." → `.refused("Taken.", draft: "Taken")` with the draft as typed; reorder of `[a,b,c]` moving c to 0 → `[c,a,b]`, to 99 → `[a,b,c]`, an unknown id → unchanged; drop at y 50 with rows of 28 over 3 rows → 2, NaN → 0, height 0 → 0 | a refusal loses the draft, a reorder drops or duplicates an id, or a zero divides |
| LL-3 | `GridSelectionReferenceTests` (QB-S28): 40 click and arrow sequences from a written table give the table's selection and anchor through `SuiteGridSelecting`; the existing `GridSelection*Tests` pass unchanged | a sequence differs |
| LL-4 | `SidebarTests`: an item built the old way is not dimmed; a dimmed row draws its title in `textSecondary` and stays selectable; `SuiteSidebarSnapshots` shows a dimmed row beside a normal one | a default item dims, or dimming changes a toggle |
| LL-5 | `LayerListTests`: a drop index maps through `reordered` to one `onMove(id, index)`; eye and lock toggles call `onToggle` with their ids; `SuiteLayerListSnapshots` shows rows, a dimmed row and the insertion line; Design's sidebar still renders (its snapshots unchanged); jscpd stays under 0.8 % (`scripts/ci`) | a drop moves the wrong row, or LayerList duplicates `SidebarRow` code |
| LL-6 | `SidebarRenameRefusalTests`: a refused commit keeps the draft and sets the message; typing clears the message; an accepted commit closes the field; Escape and focus loss both cancel and clear; the `Void` `onRename` form still renames; `SuiteSidebarSnapshots` adds the refused row in Light and Dark | the field closes on a refusal, or the old form stops compiling |
| LL-7 | `SidebarKeyboardRenameTests`: Return on the focused row starts a rename only when `onRename` is set; the row exposes an accessibility action named "Rename"; a double-click on a toggle still never renames (the existing `SidebarRenameGestureTests` pass) | Return renames a row without `onRename`, or the action is missing |
| LL-8a | `SidebarContextMenuTests`: an item with no actions builds no menu; a disabled action is disabled with its `unavailableHelp` as help; existing `SuiteWindow` initializers compile unchanged | a menu appears with no actions, or a disabled item has no reason |
| LL-8b | `SidebarContextMenuTests`, the `LayerList` cases: a row with no actions builds no menu; a disabled action is disabled with its `unavailableHelp` as help; the `LayerList(rows:onToggle:onRename:onMove:)` call compiles unchanged | a menu appears with no actions, or a disabled item has no reason |
| LL-9 | `SidebarNestingTests`: with `expanded` given, the disclosure follows it and a click calls `onExpand(id, true)`; with `onExpand` nil the group keeps its own state; the two-level cap holds; the parent row's toggles are separate accessibility children (checked in a hosted view's accessibility tree) | the app's set is ignored, or the toggles merge into one element |
| LL-10 | `SuiteSidebarNestingSnapshots` renders the real `SidebarNode` with Level 1 expanded: the chevron, the system indent and Level 3 lined up with Level 2; changing `secondLevelRows` back to `children` in `SidebarSection.swift` changes the PNG (stated in the PR, checked on the CI artifact) | the snapshot still hand-draws rows |
| LL-11 | `SidebarEdgeTests`: the section header's foreground is `SuiteColor.textSecondary`; SJ1b's `contrast` count on the `window` page is 0 | the header falls back to the list's own faint style |
| LL-12 | `SuiteGridSnapshots` unchanged except the registered identifiers; a unit test that the grid's click path calls `SuiteGridSelecting` and gives SJ18's three selections | the grid bypasses the rule |
| LL-13 | SJ0 opens all five list pages with `violations()` empty; each builds with `-SuiteGalleryFakes` | a control is unregistered or reasonless |
| LL-14 | SJ1b, SJ17 (including the rename-guard steps), SJ18 pass on CI | any 4.2 assert, or a double-click on a toggle or the blank space opens the field |
| LL-15 | SJ22 passes; SP4 holds ≥ 60 intervals per series | an assert fails or a series is short |
| LL-16, LL-17 | The next CI run's goldens pass against the baselines; no `lists` known issue left | a baseline is missing or differs |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S7 layer list (300 rows) and grid (2,000 items) scroll | frame interval p95 ≤ 1.5 refreshes (set from CI), report-only | SP4 |
| QB-S12 `GridSelecting.click` with ⇧ over 10,000 ids | ≤ 1 ms (debug ≤ 10 ms) | `ListBudgetTests.gridExtendWithinBudget` |
| QB-S14 `ListEditing.reordered` over 10,000 ids | ≤ 1 ms (debug ≤ 10 ms) | `ListBudgetTests.reorderWithinBudget` |
| QB-S28 selection equals a reference | 40 sequences exact | `GridSelectionReferenceTests` |
| QB-S17 window shell regions | inside, no overlap, token ranges | SJ1b |
| QB-F4 keyboard parity | rename from Return, reorder and select from keys | SJ17, SJ18 |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by LL-17 is green:
  SJ1b, SJ17, SJ18, SJ22, SP4 present, SJ0 and SJ25 on the list pages.
- **Audit zero new:** `suiteui` stays 0; no app's count rises. Flare's,
  Halo's and Library's `SuiteWindow` sidebars change with this feature, so
  read their `audit-*.json` on the same run (section 7.2).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  listing `suiteui-window-*`, `suiteui-layers-*`, `suiteui-grid-*` and the
  app sidebar shots that changed.
