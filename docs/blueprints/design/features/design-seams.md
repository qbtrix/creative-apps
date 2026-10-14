# Feature packet: design-seams

**Feature:** the Model seam every later Design feature builds on: the style
schema, the use-case contracts, `DesignServices` with `NotBuilt` and the
fixture fakes, the live stubs, the workspace actions and gesture routes, the
fixtures and the shared budget rows. Model code only, all of it tested on
Linux. (Blueprint wave 0, tasks D0-1 to D0-4. The window half, D0-5a to D0-7,
is the next feature, `design-window.md`.)
**Line:** `line:design` · **Wave:** 0a (`waves.md`) · **Lead branch:** `lead/design-seams`

**Covers:** no open issue closes here. The lead files one `gap` issue at
stage 1, "Design: a public `DesignPage` init for fixtures and fakes", labels
`gap`, `line:design`, `p1`, `in-progress` (blueprint 8.1), and D0-1 closes it.
#288 is not touched (no view here).

**Depends on:** PR #753 (corner radius: `cornerRadius` on `DesignNode`,
`DesignCorners.swift`, `DesignTreeError.noCorners`). It touches six files
wave 0 owns (`DesignNode`, `DesignFile`, `DesignIntent`, `DesignWindow`,
`DesignInspector`, `DesignCanvasMarks`) and was CONFLICTING against `dev` at
review, so it is rebased and merged first. D0-1 builds on its field and
keeps its name. No SuiteUI issue, no creative-core issue.

Blueprint sections it builds on: 5 (all of it: the rules, 5.1 to 5.7), 4
(fixtures), 7.1 (QD-S8, QD-S9, QD-S11), 7.4 (QD-V1), 8.2 (wave 0).

**What changed from the blueprint (review of #766 and the shared-file rule):**

- D0-2 is about 954 lines of code before tests (contracts 112 + 135 + 195,
  services and `NotBuilt` 163, fakes 54 + 295), so it is split into six
  PRs, D0-2.1 to D0-2.6 (the contract law is its own PR). `NotBuilt` moves to its own file, and the tier-1
  fakes split into two files by area.
- D0-3 is split into D0-3a (command actions), D0-3b (clipboard, layer order
  and style actions, in a second file) and D0-3c (the gesture routes).
- D0-3c's Option-drag records ONE step named "Duplicate": the route mints
  the copies' ids once at gesture start and each drag step builds a single
  `DesignEdit` that duplicates at offset zero and then moves the copies,
  under its own run key (J7's "Undo Duplicate" assert depends on it).
- D0-4 is split into fixtures (D0-4a) and the budget rows (D0-4b).
- No task edits `docs/c4/model.json`: `design-model-sources` owns
  `Sources/DesignModel/` (subfolders included), and the supervisor folds the
  planned descriptions from `docs/blueprints/design/c4-planned.json` later.

## Journey steps

This feature changes no screen; the window keeps calling today's methods.
It proves the steps the journeys will take in Model tests, on the `cards`
fixture, through the actions the views will call:

1. Marquee from (80, 80) to (520, 240) inside Desktop selects A and B
   on `.fake`; over Locked and Hidden it selects nothing. (D0-3c, J5)
2. With A, B, C selected, `run(.align(.top))` records "Align Top" and
   `run(.distribute(.horizontal))` "Distribute Horizontally"; with two,
   Distribute's help is "Select three or more layers to distribute." (D0-3a, J6)
3. `run(.duplicate)` on A records "Duplicate"; an Option-drag of A by
   (0, 100) records one "Duplicate" step and leaves three A's. (D0-3a,
   D0-3c, J7)
4. Copy Pair, paste: "Paste", into Desktop, offset (10, 10), two children;
   cut B: "Cut". (D0-3b, J8)
5. With A selected and `.live` (all `NotBuilt`): delete, nudge, align, move
   and resize drags, and the X, Y, W, H, Fill and corner radius rows still
   work through today's methods. (D0-3a, D0-3b, D0-3c, the "nothing that
   works today goes off" rule)
6. A version-1 file written before D0-1 opens with the new fields at their
   defaults; every fixture round-trips byte for byte. (D0-1, D0-4a, QD-V1)

`Tests/DesignModelTests/DesignSeamsJourneyTests.swift` (D0-4a) walks steps
1 to 6 end to end on `.fake` and `.live`.

## Screens and states

No screen changes. The states this feature defines for the screens that
come next:

| State | What the Model reports |
|---|---|
| Empty (nothing selected) | every command's help is "Select a layer first."; `zoomToSelectionRect` is nil |
| Error (a refusal) | the write throws `DesignRefusal`; nothing is recorded; the help is the refusal's `help` |
| Not built (`.live` before a feature) | the help reads "<Feature> isn't built yet." and the write throws `.notBuilt`; one-layer edits keep today's methods |
| Loading | none: every use case is synchronous and in memory |

## Contract slice

Exactly blueprint section 5, compiled on Swift 6.3.3 against DesignModel.
The files and who adds them:

| File (`Sources/DesignModel/`) | Holds | Task |
|---|---|---|
| `DesignNode.swift` | `opacity`, `stroke`, `textStyle` (after #753's `cornerRadius`), `decodeIfPresent` for each, `init(id:copying:)` | D0-1 |
| `DesignWorkspace.swift` | public `DesignPage.init(id:name:frameWidth:frameHeight:nodes:)`; `public internal(set) var marquee: DesignRect?`; then `services` and `useServices` | D0-1, D0-2.3 |
| `Contracts/EditContracts.swift` | `DesignEdit`, `runKey`, `DesignRefusal` with `help`, `DesignIDMint` (5.2) | D0-2.1 |
| `Contracts/StyleTypes.swift` | 5.3, all of it (tier-2 types too, so D2-1 adds no type file) | D0-2.1 |
| `Contracts/UseCases.swift` | 5.4, tier 1 and tier 2 protocols, `DesignDocument` | D0-2.2 |
| `NotBuilt.swift` | `NotBuilt` and its conformances to every protocol (the second half of 5.6) | D0-2.3 |
| `DesignServices.swift` | the struct (first half of 5.6) with `.live` all `NotBuilt`; `.fake` from D0-2.5 | D0-2.3, D0-2.5, D0-2b |
| `Fakes/FakeSupport.swift` | 5.7's helpers | D0-2.4 |
| `Fakes/DesignSelectFakes.swift` | `FakeMarquee`, `FakeTransforming`, `FakeAligning`, `FakeFraming` | D0-2.4 |
| `Fakes/DesignArrangeFakes.swift` | `FakeDuplicating`, `FakeGrouping`, `FakeClipboard`, `FakeOrdering`, `FakeStyling`, `FakeFiling` | D0-2.5 |
| `Live/Live*.swift` (10 files) | one stub per tier-1 slot; `LiveFiling` wraps today's codec, the others forward to `NotBuilt("<feature>")` | D0-2b |
| `DesignActions.swift` | 5.5's `DesignCommand`, `help(_:)`, `run(_:)`, `zoomToSelectionRect`, `zoomToSelectionHelp`, `selectAll()`, `mint()`, `apply(_:mint:)`; plus `transformHelp: String?`, the selection's `SelectionTransforming.transformHelp` (nil with one layer: today's methods), which the canvas reads to decide whether the several-layer box shows handles | D0-3a |
| `DesignActions+Edit.swift` | 5.5's clipboard, `moveLayer`, `styleHelp`, `setStyle`, `DesignStyleChange`. `paste` follows 5.4 and #415, not 5.5's shorter comment: it passes the selected frame as `parentID` (nil without one), and the use case falls back to the parent the copies came from, then the top level | D0-3b |
| `DesignCanvasEditing.swift` | the marquee rule, several-layer move and resize, Option-drag | D0-3c |
| `DesignFixtures.swift` | `empty`, `cards`, `two-pages`, `crowd` (blueprint 4, the fixture table, exact frames) | D0-4a |

The `.fake` slots for export, pen, components and variables are
`NotBuilt` until D2-2 (`design-seams-2.md`). `.live`'s slot names are
5.6's: "Marquee selection", "Editing several layers", "Aligning several
layers", "Duplicate", "Group", "Copy and paste", "Reordering layers", "Style
editing", "Zoom to Selection", "Saving", "Export", "The Pen tool",
"Components", "Variables". `LiveFiling` is not `NotBuilt`: it wraps
`DesignFile.swift`'s codec, so Save never goes off.

## Pseudocode

```
apply(edit, mint):                                   # D0-3a
  guard var page = selectedPage else return
  before = snapshot()
  page.nodes = edit.nodes; replace page; selectedNodeIDs = edit.selection
  if let mint { heldIDs.take(mint.minted); idCounter = max(idCounter, mint.counter) }
  record(name: edit.name, before: before, coalescingKey: edit.coalescingKey)   # one step

help(command): (help law)
  ids = selectedNodeIDs; page = selectedPage
  if ids.count == 1 and command in [.delete, .nudge, .align]:
    return today's help for that one layer           # works while .live is NotBuilt
  switch command → services.<slot>.<command>Help(ids, page)

run(command):
  if ids.count == 1 and command in [.delete, .nudge, .align]: today's method; return
  var m = mint()
  edit = try services.<slot>.<command>(ids, page, &m)   # throws DesignRefusal, nothing recorded
  apply(edit, mint: m)

setStyle(change):                                    # D0-3b
  if ids.count == 1 and change is .frame/.fill/.cornerRadius:
    setNodeFrame / setFill / setCornerRadius (today's, #753's); return
  edit = try services.styling.set…(…, ids, page); apply(edit)

selection change (select, toggle, deselect, page switch):   # D0-1
  endEditRun()                                       # a run never spans two selections

drag(from, to, modifiers) on Move:                   # D0-3c
  at gesture start:
    hit = hitTest(start); handle = handle(at: start)
    if handle and selection.count > 1:   gesture = .resizeSeveral(box)
    elif hit is a selected layer and .option:
         gesture = .optionCopy(ids, mint: mint())    # ids minted ONCE, kept in the gesture
    elif hit is a selected layer:        gesture = .moveSeveral(ids)  (one layer: today's move)
    elif hit is a frame F whose point has no child under it and F is not selected:
         gesture = .marquee(parent: F.id)            # the marquee rule
    elif hit is nil:                     gesture = .marquee(parent: nil)
    else: today's click-select and move
  every step (rewind to the gesture's snapshot first, as today):
    .marquee(p):   marquee = rect(start, to)
                   selectedNodeIDs = services.marquee.layers(touching: marquee, in: p, on: page)
    .moveSeveral:  apply(services.transforming.move(ids, by: to - start))
    .resizeSeveral:apply(services.transforming.resize(ids, handle, by: to - start, modifiers))
    .optionCopy(ids, m0):
        var m = m0                                   # same ids every step
        d = services.duplicating.duplicate(ids, offset: .zero, page, &m)
        e = services.transforming.move(d.selection, by: to - start, on: d's page)
        apply(DesignEdit(name: "Duplicate", nodes: e.nodes, selection: d.selection,
                         coalescingKey: runKey("option-drag", ids)), mint: m)
    a click without movement on F's background selects F (today's click)
endDrag(): marquee = nil; endEditRun()               # one step per gesture
```

With exactly one layer selected, move and resize drags keep today's
methods whatever `services` holds. `.live`'s marquee answers `[]`, so on the
live services a marquee selects nothing until F1 (its help is not shown:
the marquee is a gesture, not a control).

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: design-seams`,
`Fast-Check: pass`, `Head:`. The last task (D0-4b) also carries
`feature-done`. Tasks run in the order of the table; a task that shares a
file with an earlier one is rebased on it (the depends-on column).

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| D0-1 | gap "public `DesignPage` init" (closes) | Style schema with version-1 files still opening; `init(id:copying:)`; public `DesignPage` init; `marquee`; every selection change ends the edit run | `DesignNode.swift`, `DesignWorkspace.swift`, `DesignSelection.swift`, `DesignFile.swift`; tests `DesignStyleSchemaTests.swift`, `DesignSelectionRunTests.swift` | #753 | ~250, 6 |
| D0-2.1 | – | `DesignEdit`, `DesignRefusal`, `DesignIDMint`; the style and tier-2 value types | `Contracts/EditContracts.swift`, `Contracts/StyleTypes.swift`; tests `DesignIDMintTests.swift`, `DesignRefusalHelpTests.swift` | D0-1 | ~360, 4 |
| D0-2.2 | – | The use-case protocols and `DesignDocument` | `Contracts/UseCases.swift`; tests `DesignDocumentTests.swift` | D0-2.1 | ~240, 2 |
| D0-2.3 | – | `NotBuilt` and its conformances; `DesignServices` with `.live`; `services` and `useServices` on the workspace | `NotBuilt.swift`, `DesignServices.swift`, `DesignWorkspace.swift`; tests `DesignNotBuiltTests.swift` | D0-2.2 | ~260, 4 |
| D0-2.4 | – | Fake helpers; the select-area fakes | `Fakes/FakeSupport.swift`, `Fakes/DesignSelectFakes.swift`; tests `DesignSelectFakesTests.swift` | D0-2.3 | ~330, 3 |
| D0-2.5 | – | The arrange-area fakes; `.fake` | `Fakes/DesignArrangeFakes.swift`, `DesignServices.swift`; tests `DesignArrangeFakesTests.swift` | D0-2.4 | ~300, 3 |
| D0-2.6 | – | The contract law over every tier-1 conformance | tests `DesignContractLawTests.swift` | D0-2.5 | ~200, 1 |
| D0-2b | – | One stub per tier-1 live type; `.live` names them; `LiveFiling` wraps today's codec | `Live/LiveMarquee.swift`, `Live/LiveTransforming.swift`, `Live/LiveAligning.swift`, `Live/LiveFraming.swift`, `Live/LiveDuplicating.swift`, `Live/LiveGrouping.swift`, `Live/LiveClipboard.swift`, `Live/LiveOrdering.swift`, `Live/LiveStyling.swift`, `Live/LiveFiling.swift`, `DesignServices.swift`; tests `DesignLiveStubTests.swift` | D0-2.6 | ~300, 12 |
| D0-3a | – | `DesignCommand`, `help`, `run`, `apply`, `mint`, Zoom to Selection, Select All; one-layer delete, nudge and align keep today's methods | `DesignActions.swift`; tests `DesignActionsTests.swift` | D0-2b | ~330, 2 |
| D0-3b | – | Copy, cut, paste, `moveLayer`, `styleHelp`, `setStyle`; one-layer frame, fill and radius keep today's methods | `DesignActions+Edit.swift`; tests `DesignActionsEditTests.swift` | D0-3a | ~300, 2 |
| D0-3c | – | Gesture routes: the marquee rule, several-layer move and resize, Option-drag as one "Duplicate" step; `endDrag` clears the marquee and ends the run | `DesignCanvasEditing.swift`; tests `DesignGestureRouteTests.swift`, `DesignOptionDragTests.swift` | D0-3b | ~380, 3 |
| D0-4a | – | Fixtures and the seams journey test | `DesignFixtures.swift`; tests `DesignFixturesTests.swift`, `DesignSeamsJourneyTests.swift` | D0-3c | ~330, 3 |
| D0-4b | – | The budget helper and QD-S8, QD-S9, QD-S11 | tests `DesignBudget.swift`, `DesignBudgetTests.swift` | D0-4a | ~180, 2; `feature-done` |

Paths drop `Sources/DesignModel/`; tests are `Tests/DesignModelTests/`.
`DesignWorkspace.swift` passes D0-1 → D0-2.3 and `DesignServices.swift`
D0-2.3 → D0-2.5 → D0-2b, all in the chain. Sizes are estimates from the
blueprint's compiled code; a task that measures over 400 lines splits by
file before it opens (the fakes by struct, the tests by area).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D0-1 | `DesignStyleSchemaTests`: a version-1 JSON string written before the fields existed decodes with `opacity == 1`, `stroke == nil`, `textStyle == .default`, `cornerRadius == 0`; a node with every field set round-trips; `DesignNode(id: "node-99", copying: n)` equals `n` in every field but `id`; `DesignPage(id:name:frameWidth:frameHeight:nodes:)` builds from another module (`import DesignModel` without `@testable`). `DesignSelectionRunTests`: nudge A, select B, nudge B gives two undo steps; nudge A twice gives one | an old file fails or changes, a copy drops a field, the init is not public, or two selections' nudges merge |
| D0-2.1 | `DesignIDMintTests`: a mint over `{node-1, node-3}` after 0 hands out node-2, node-4, node-5 and records them in `minted`; a negative counter starts at 0; 1,000 calls never repeat or hit `taken`. `DesignRefusalHelpTests`: every case's `help` equals the blueprint's sentence, `tooFew(needed: 2)` reads "Select two or more layers.", `runKey("move", ["node-4", "node-3"]) == "move-node-3,node-4"` | an id repeats, a help's words drift, or the key depends on order |
| D0-2.2 | `DesignDocumentTests`: `DesignDocument(pages:)` has empty components and variables; equality covers all three; each protocol is satisfiable by a test-local type (a compile check that the signatures are exactly 5.4's) | a signature differs from 5.4 or a default is missing |
| D0-2.3 | `DesignNotBuiltTests`: for every slot of `.live`, the help on `cards` with A selected is "<feature> isn't built yet." with the slot's 5.6 name, and the write throws `.notBuilt(name)`; `NotBuilt.decode` throws `.unreadable`; `useServices(.live)` keeps the document; a workspace on `.live` differs from the same workspace on `.fake` and equals itself | a slot names the wrong feature, a NotBuilt write succeeds, or services break workspace equality |
| D0-2.4 | `DesignSelectFakesTests` on a `cards`-shaped tree built in the test: marquee (80, 80)–(520, 240) in Desktop picks A and B (Title ends at y 72, C starts at x 700), and (380, 580)–(720, 720) picks nothing; move by (40, 0) moves A with its subtree; resize, nudge (1 and 10), delete name their steps "Resize", "Nudge", "Delete"; Align Top on A, B, C sets y 100 on all three; distribute widths 20, 40, 20 across 0…300 gives equal gaps within 1e-9 (QD-V6); two layers: `.tooFewToDistribute`; `rectToShow` of C is C's frame | a fake acts only at the top level, picks a locked or hidden layer, or a number is off |
| D0-2.5 | `DesignArrangeFakesTests`: duplicate A sits right above A, offset (10, 10), unlocked, fresh ids (QD-V5); group A and B keeps every leaf frame (QD-V4) and names "Group"; A with E1 throws `.notSameParent`; ungroup Pair gives E1, E2 selected; copy Pair, paste lands in Desktop at +10, +10 with two children; `pasteHelp` of `"hello"` bytes is "The pasteboard holds no Design layers."; move Title into Pair; send B to back; set X 300 on A and B sets both | a copy keeps an id, a group moves a leaf, or paste lands in the wrong parent |
| D0-2.6 | `DesignContractLawTests`: for every protocol, every command and every selection in {none, A, A+B, A+B+C, Locked, Hidden, Pair} on `cards`, on `.fake` and `.live`: help nil ⇒ the write throws nothing but `.unchanged`; help non-nil ⇒ it throws; a deliberately broken conformance defined in the test (help nil, write throws `.locked`) is caught, so the law test can fail | any conformance breaks the law |
| D0-2b | `DesignLiveStubTests`: `.live`'s slots are the `Live*` types (by `String(describing:)`); each tier-1 stub answers the same help and refusal as `NotBuilt` with its name; `LiveFiling` round-trips `cards` byte for byte with `DesignFile`'s encoder and refuses `not json` with `DesignFile`'s reason; the contract law still passes on `.live` | a stub is missing from `.live`, a stub acts, or saving through `LiveFiling` differs from today's bytes |
| D0-3a | `DesignActionsTests` on `cards` with `.fake`: each `DesignCommand` records exactly one step with its name, and a refusal records none; the help law holds for every command and selection (same matrix as D0-2.6, through the workspace); with `.live` and A selected, `.delete`, every `.nudge` and every single-layer `.align` work and record today's names, while with A and B they are refused with the slot's "isn't built yet."; `mint()` never hands out an id the file holds; Zoom to Selection's rect is nil with nothing selected and its help is "Select a layer first."; `selectAll()` with nothing selected selects Desktop, and with A selected selects Desktop's visible unlocked children | one-layer editing goes off on `.live`, a refusal records a step, or an id repeats |
| D0-3b | `DesignActionsEditTests`: copy Pair then paste: one "Paste" step, two new ids; `cutSelection` on B is one "Cut" step and the bytes paste back; `pasteHelp(nil)` is non-nil; `moveLayer` of Title into Pair is one "Move Layer" step; with `.live` and A selected, `setStyle(.frame(.x, 300))`, `.fill` and `.cornerRadius(12)` work through today's methods; with A and B, `.frame(.x, 300)` on `.fake` sets both in one step, and on `.live` it throws `.notBuilt("Style editing")`; two `.opacity` changes in a row on A are one step | a one-layer row goes off, a cut is two steps, or a scrub run is several steps |
| D0-3c | `DesignGestureRouteTests` on `cards` with `.fake`: a press at (80, 80) on Desktop's background dragged to (520, 240) selects A and B and records nothing; the same press with Desktop selected moves Desktop ("Move"); a click there without moving selects Desktop; a press outside the page (off every frame) marquees the top level; with A and B selected, a drag of A by 40 is one "Move" step for both, and the box's bottom-right handle by 20 is one "Resize"; `endDrag` leaves `marquee == nil`. `DesignOptionDragTests`: Option-drag A by (0, 100) in five steps gives exactly one undo step named "Duplicate", two A's (the original and one copy), the copy at A.y + 100, the same copy id after every step, and one ⌘Z restores the tree; a second Option-drag is a second step | the marquee rule picks the wrong level, an Option-drag records more than one step or mints new ids per step, or a drag outlives `endDrag` |
| D0-4a | `DesignFixturesTests`: every fixture matches the blueprint's table (names, frames, parents, Locked locked, Hidden hidden); `crowd` holds exactly 2,000 layers: 40 frames, each with 48 rectangles and one text (40 + 40 × 49); ids unique; `encode(decode(encode(f))) == encode(f)` for each (QD-V1). `DesignSeamsJourneyTests`: steps 1 to 6 above | a fixture differs from the table, a save is unstable, or a journey step fails |
| D0-4b | `DesignBudgetTests.hitTest` (QD-S8), `.applyStep` (QD-S9), `.fileRoundTrip` (QD-S11): median and p95 of 200 runs on `crowd` under the Linux debug gates; `DesignBudget` reports both and the test fails over the gate, and a self-test of the helper fails a body that sleeps past the gate | a budget is exceeded, or the helper cannot fail |

After one Option-drag the page holds two A's (the original and its copy);
J7's "three A's" also counts the ⌘D copy.

## Quality tests

| quality row | budget (device / Linux debug gate) | test |
|---|---|---|
| QD-S8 hit test per pointer move | ≤ 0.5 ms / ≤ 5 ms on 2,000 layers | `DesignBudgetTests.hitTest` |
| QD-S9 any document edit (`apply` plus one record) | ≤ 1 ms / ≤ 10 ms | `DesignBudgetTests.applyStep` |
| QD-S11 open and save `crowd` | decode and encode ≤ 50 ms / ≤ 500 ms | `DesignBudgetTests.fileRoundTrip` |
| QD-V1 save is stable, version 1 still opens | byte equality | `DesignFixturesTests.roundTripIsStable`, `DesignStyleSchemaTests.versionOneOpens` |
| QD-V4, QD-V5, QD-V6 (fake rules) | exact, ≤ 1e-9 | `DesignArrangeFakesTests`, `DesignSelectFakesTests` (the live halves are F1's and F2's) |
| QB-F3 one gesture, one step | one undo step per drag and per command | `DesignOptionDragTests`, `DesignGestureRouteTests`, `DesignActionsTests` |
| help law (7.5) | every conformance, every command | `DesignContractLawTests` |

## Done check

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green with `DesignJourneyTests` unchanged and passing (nothing here is
  wired into the window, so J0 to J3 must not regress). The lane dispatches
  that run when it merges the `feature-done` PR (CLAUDE.md, Fast lane),
  and contract rule 6 needs it green. The feature's other PRs touch no UI
  path, so the Anatomy rounds before it judge on the Linux gate and the
  latest run (lead.md stage 4, step 1), noted in RECORD.md.
- **Audit zero new:** that run's `design` counts are at or under
  `UITests/audit-baseline.json` (`identifier: 20`); this feature never
  raises a baseline.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue and notes that the Design shots are unchanged from the
  previous run.
