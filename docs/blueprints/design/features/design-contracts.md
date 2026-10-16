# Feature packet: design-contracts

**Feature:** everything every other Design feature compiles against: the
style schema (with the corner radius from PR #753), the use-case contracts,
`DesignServices` with `NotBuilt`, the fixture fakes, one live stub per
tier-1 slot, the workspace actions the views call, the fixtures and the
budget helper. Model code only, all of it tested on Linux, so it finishes in
hours. (Blueprint wave 0, D0-1 to D0-3b and D0-4a; the gesture routes and the
shared budgets stay in `design-seams.md`.)
**Line:** `line:design` · **Wave:** 0a (`waves.md`) · **Lead branch:** `lead/design-contracts`

**Covers:** the lead files one `gap` issue at stage 1, "Design: a public
`DesignPage` init for fixtures and fakes", labels `gap`, `line:design`,
`p1`, `in-progress` (blueprint 8.1), and D0-1 closes it. #532 (Model part):
D0-0 carries it with "see #532"; style-rows ST-6 closes #532 once the
inspector row and J10's radius step land.

**Depends on:** nothing. PR #753 (corner radius) is not waited on: its
Model half is task D0-0 here, rebuilt from #753's diff on `dev` without
its `docs/c4/model.json` edit; its inspector row and canvas drawing are
style-rows ST-4 and ST-5, and its journey step is J10's radius step
(ST-6). The intent `.setCornerRadius` it adds is covered by design-window
D0-5a's `.setStyle(DesignStyleChange)` (`.cornerRadius` is a case of
`DesignStyleChange`). No SuiteUI issue, no creative-core issue.

Blueprint sections it builds on: 5 (5.1 to 5.7), 4 (fixtures), 7.4 (QD-V1,
QD-V4 to QD-V6 on the fakes), 7.5 (the help law), 8.2 (wave 0).

**What changed from design-seams (the v3 re-cut, 2026-10-16):**

- The contract tasks D0-2.1 to D0-2.6 left `design-seams.md` for this
  packet, with what every other feature compiles against: D0-1 (the schema
  and the public `DesignPage` init), D0-2b (the live stubs each wave-1
  feature fills), D0-3a and D0-3b (the actions every view and every
  through-the-workspace test calls) and the fixtures half of D0-4a. None of
  them makes the chain longer: D0-2b, D0-3a and D0-4a hang off tasks that
  were already in it.
- D0-0 is new: PR #753's Model half, since no task built `cornerRadius` and
  D0-1, D0-3b and style-rows all assume it.
- D0-4a keeps the fixtures and gains the budget helper (`DesignBudget`,
  formerly D0-4b's), so the wave-1 budget tests compile against this
  feature alone. The seams journey test is gone: each slice proves itself
  with a Model walk (MJ1 to MJ4 below), and the gesture walk is
  design-seams' MJ5.

## Slices

A slice is the unit of done: its tasks have merged and its walk passes on
the Linux gate. Every slice here is Linux-only.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CT-a | A file saved before the new style fields still opens with every field at its default, and a rectangle's corner radius saves and reopens. | D0-0, D0-2.1, D0-1 | MJ1 | nothing |
| CT-b | On the fake services every tier-1 use case acts, and on the live services each one says "<Feature> isn't built yet." and changes nothing. | D0-2.2, D0-2.3, D0-2.4, D0-2.5 | MJ2 | CT-a (D0-2.2, D0-2.3, D0-2.5) |
| CT-c | The help law holds on every fake and every live stub, and the four fixtures open exactly as the blueprint lists them. | D0-2.6, D0-2b, D0-4a | MJ3 | CT-b (D0-2.6, D0-2b); CT-a (D0-4a) |
| CT-d | Every workspace command records one named step or says why, and one-layer delete, nudge, align, frame, fill and radius edits keep today's methods on the live services. | D0-3a, D0-3b | MJ4 | CT-b (D0-3a) |

## Journey steps

This feature changes no screen. Each slice's walk is a Model journey on
Linux, one test method in a test file the slice already owns:

1. **MJ1** `DesignStyleSchemaTests.testOldFileAndCornersWalk` (D0-1): a
   version-1 string written before D0-0 and D0-1 opens with `cornerRadius`
   0, `opacity` 1, `stroke` nil and `textStyle` `.default`; set A's corner
   radius to 12; save and reopen: 12, every other field unchanged.
2. **MJ2** `DesignArrangeFakesTests.testFakesWalk` (D0-2.5), on a
   `cards`-shaped tree built in the test: on `.fake`, a marquee from (80, 80)
   to (520, 240) inside Desktop picks A and B; Align Top on A, B and C;
   duplicate A; group A and B; copy Pair and paste it; each edit is named.
   The same calls on `.live` throw `.notBuilt` with 5.6's names.
3. **MJ3** `DesignLiveStubTests.testLiveStubsWalk` (D0-2b): open `cards`
   from `DesignFixtures`; every `.live` slot answers its `NotBuilt` help
   and refusal, except `LiveFiling`, which saves and reopens `cards` byte for
   byte.
4. **MJ4** `DesignActionsEditTests.testCommandsWalk` (D0-3b): with A, B and
   C selected on `.fake`, `run(.align(.top))` records "Align Top" and
   `run(.distribute(.horizontal))` "Distribute Horizontally"; with two,
   Distribute's help is "Select three or more layers to distribute."; copy
   Pair, paste: "Paste", into Desktop, offset (10, 10), two children; cut
   B: "Cut"; on `.live` with A selected, delete, nudge, align and the X,
   Fill and corner radius rows work through today's methods.

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

Exactly blueprint section 5, compiled on Swift 6.3.3 against DesignModel:

| File (`Sources/DesignModel/`) | Holds | Task |
|---|---|---|
| `DesignNode.swift` | `cornerRadius` (#753) and `DesignTreeError.noCorners`; then `opacity`, `stroke`, `textStyle`, `decodeIfPresent` for each, `init(id:copying:)` | D0-0, D0-1 |
| `DesignCorners.swift` | #753's `hasCorners`, `cornerlessHelp`, `maxCornerRadius`, `drawnCornerRadius`, `setCornerRadius` (clamped to half the shorter side, coalescing on `radius-<id>`), `cornerRadiusHelp` | D0-0 |
| `DesignFile.swift` | a negative or non-finite radius is refused as `invalidNumber` (D0-0); the new fields decode with defaults (D0-1) | D0-0, D0-1 |
| `DesignWorkspace.swift` | public `DesignPage.init(id:name:frameWidth:frameHeight:nodes:)`; `public internal(set) var marquee: DesignRect?`; then `services` and `useServices` | D0-1, D0-2.3 |
| `Contracts/EditContracts.swift` | `DesignEdit`, `runKey`, `DesignRefusal` with `help`, `DesignIDMint` (5.2) | D0-2.1 |
| `Contracts/StyleTypes.swift` | 5.3, all of it (tier-2 types too) | D0-2.1 |
| `Contracts/UseCases.swift` | 5.4, tier 1 and tier 2 protocols, `DesignDocument` | D0-2.2 |
| `NotBuilt.swift` | `NotBuilt` and its conformances to every protocol | D0-2.3 |
| `DesignServices.swift` | the struct with `.live` (all `NotBuilt`, then the `Live*` stubs); `.fake` | D0-2.3, D0-2.5, D0-2b |
| `Fakes/FakeSupport.swift`, `Fakes/DesignSelectFakes.swift` | 5.7's helpers; `FakeMarquee`, `FakeTransforming`, `FakeAligning`, `FakeFraming` | D0-2.4 |
| `Fakes/DesignArrangeFakes.swift` | `FakeDuplicating`, `FakeGrouping`, `FakeClipboard`, `FakeOrdering`, `FakeStyling`, `FakeFiling` | D0-2.5 |
| `Live/Live*.swift` (10 files) | one stub per tier-1 slot, forwarding to `NotBuilt("<feature>")`; `LiveFiling` wraps today's codec. Each wave-1 feature takes its stub file over and fills it | D0-2b |
| `DesignActions.swift` | 5.5's `DesignCommand`, `help(_:)`, `run(_:)`, `zoomToSelectionRect`, `zoomToSelectionHelp`, `selectAll()`, `mint()`, `apply(_:mint:)`, `transformHelp` | D0-3a |
| `DesignActions+Edit.swift` | 5.5's clipboard, `moveLayer`, `styleHelp`, `setStyle`, `DesignStyleChange`; `paste` passes the selected frame as `parentID` (#415) | D0-3b |
| `DesignFixtures.swift` | `empty`, `cards`, `two-pages`, `crowd` (blueprint 4, exact frames) | D0-4a |

`Tests/DesignModelTests/DesignBudget.swift` (D0-4a) is the budget helper:
median and p95 of N runs against a Linux debug gate. design-seams D0-4b and
the wave-1 budget tasks (S-8, ST-7, L-7) call it.

The `.fake` slots for export, pen, components and variables are `NotBuilt`
until design-seams-2 D2-2. `.live`'s slot names are 5.6's: "Marquee
selection", "Editing several layers", "Aligning several layers",
"Duplicate", "Group", "Copy and paste", "Reordering layers", "Style
editing", "Zoom to Selection", "Saving", "Export", "The Pen tool",
"Components", "Variables".

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
    setNodeFrame / setFill / setCornerRadius (today's, D0-0's); return
  edit = try services.styling.set…(…, ids, page); apply(edit)

selection change (select, toggle, deselect, page switch):   # D0-1
  endEditRun()                                       # a run never spans two selections
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: design-contracts`,
`Fast-Check: pass`, `Head:`. Whichever of D0-2b and D0-3b merges last
carries `feature-done`. Paths drop `Sources/DesignModel/`; tests are
`Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| D0-0 | #532 (Model part, see PR #753) | Corner radius on rectangles and frames, from #753's Model half: `cornerRadius` with old files opening at 0, `DesignCorners.swift`, the file check | `DesignNode.swift`, `DesignCorners.swift`, `DesignFile.swift`; tests `DesignCornerRadiusTests.swift` | – | ~210, 4 |
| D0-1 | gap "public `DesignPage` init" (closes) | Style schema with version-1 files still opening; `init(id:copying:)`; public `DesignPage` init; `marquee`; every selection change ends the edit run; walk MJ1 | `DesignNode.swift`, `DesignWorkspace.swift`, `DesignSelection.swift`, `DesignFile.swift`; tests `DesignStyleSchemaTests.swift`, `DesignSelectionRunTests.swift` | D0-0, D0-2.1 | ~280, 6 |
| D0-2.1 | – | `DesignEdit`, `DesignRefusal`, `DesignIDMint`; the style and tier-2 value types | `Contracts/EditContracts.swift`, `Contracts/StyleTypes.swift`; tests `DesignIDMintTests.swift`, `DesignRefusalHelpTests.swift` | – | ~360, 4 |
| D0-2.2 | – | The use-case protocols and `DesignDocument` | `Contracts/UseCases.swift`; tests `DesignDocumentTests.swift` | D0-2.1 | ~240, 2 |
| D0-2.3 | – | `NotBuilt` and its conformances; `DesignServices` with `.live`; `services` and `useServices` on the workspace | `NotBuilt.swift`, `DesignServices.swift`, `DesignWorkspace.swift`; tests `DesignNotBuiltTests.swift` | D0-1, D0-2.2 | ~260, 4 |
| D0-2.4 | – | Fake helpers; the select-area fakes | `Fakes/FakeSupport.swift`, `Fakes/DesignSelectFakes.swift`; tests `DesignSelectFakesTests.swift` | D0-2.2 | ~330, 3 |
| D0-2.5 | – | The arrange-area fakes; `.fake`; walk MJ2 | `Fakes/DesignArrangeFakes.swift`, `DesignServices.swift`; tests `DesignArrangeFakesTests.swift` | D0-1, D0-2.3, D0-2.4 | ~340, 3 |
| D0-2.6 | – | The contract law over every tier-1 conformance | tests `DesignContractLawTests.swift` | D0-2.5 | ~200, 1 |
| D0-2b | – | One stub per tier-1 live type; `.live` names them; `LiveFiling` wraps today's codec; walk MJ3 | `Live/LiveMarquee.swift`, `Live/LiveTransforming.swift`, `Live/LiveAligning.swift`, `Live/LiveFraming.swift`, `Live/LiveDuplicating.swift`, `Live/LiveGrouping.swift`, `Live/LiveClipboard.swift`, `Live/LiveOrdering.swift`, `Live/LiveStyling.swift`, `Live/LiveFiling.swift`, `DesignServices.swift`; tests `DesignLiveStubTests.swift` | D0-2.3, D0-2.5, D0-2.6, D0-4a | ~340, 12 |
| D0-3a | – | `DesignCommand`, `help`, `run`, `apply`, `mint`, Zoom to Selection, Select All; one-layer delete, nudge and align keep today's methods | `DesignActions.swift`; tests `DesignActionsTests.swift` | D0-2.5 | ~330, 2 |
| D0-3b | – | Copy, cut, paste, `moveLayer`, `styleHelp`, `setStyle`; one-layer frame, fill and radius keep today's methods; walk MJ4 | `DesignActions+Edit.swift`; tests `DesignActionsEditTests.swift` | D0-3a | ~340, 2 |
| D0-4a | – | The four fixtures, and the budget helper with a self-test | `DesignFixtures.swift`; tests `DesignFixturesTests.swift`, `DesignBudget.swift`, `DesignBudgetHelperTests.swift` | D0-1 | ~320, 4 |

`DesignNode.swift` and `DesignFile.swift` pass D0-0 → D0-1;
`DesignWorkspace.swift` D0-1 → D0-2.3; `DesignServices.swift` D0-2.3 →
D0-2.5 → D0-2b; each is a depends-on link. D0-1 also waits on D0-2.1
because `stroke` and `textStyle` are `DesignStroke` and `DesignTextStyle`
from `StyleTypes.swift`. D0-2b waits on D0-2.6 (its test reruns the law on
the stubs) and on D0-4a (MJ3 opens `cards`). D0-2.3's test compares `.live`
with a `DesignServices` built in the test, not `.fake`, which lands in
D0-2.5. The fakes and the actions tests build their `cards`-shaped trees in
the test (DesignPage's memberwise init under `@testable`), so they don't wait
on the fixtures. This packet edits no shared doc, so it has no docs task.
A task that measures over 400 lines splits by file before it opens.

## Build waves

- Wave 1: D0-0, D0-2.1. Independent in this wave: both.
- Wave 2: D0-1, D0-2.2. Independent in this wave: both.
- Wave 3: D0-2.3, D0-2.4, D0-4a. Independent in this wave: all three.
- Wave 4: D0-2.5. Independent in this wave: D0-2.5 alone.
- Wave 5: D0-2.6, D0-3a. Independent in this wave: both.
- Wave 6: D0-2b, D0-3b (the later one carries `feature-done`). Independent in this wave: both.

Longest chain: D0-2.1 → D0-2.2 → D0-2.3 → D0-2.5 → D0-2.6 → D0-2b (6), and
D0-0 → D0-1 → D0-2.3 → D0-2.5 → D0-3a → D0-3b (6).

Chain of 6: `UseCases.swift` uses D0-2.1's types; `NotBuilt` conforms to
D0-2.2's protocols and `services` sits in D0-1's `DesignWorkspace.swift`;
`.fake` goes in D0-2.3's `DesignServices.swift`; the law runs on `.fake`;
the stubs rerun the law; and on the other branch the actions run on
`.fake` and `DesignActions+Edit.swift` calls D0-3a's `apply` and `mint`.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D0-0 | `DesignCornerRadiusTests` (#753's, rebased): the clamp to half the shorter side, negative, NaN and infinity; the drawn radius after a shrink; a 20-edit run is one undo step and undo and redo restore it; frames take a radius; an ellipse and a group refuse with `noCorners`; a layer inside a locked group refuses and nothing changes; each `cornerRadiusHelp` reason; a file without `cornerRadius` opens with 0; save and reopen; a negative radius in a file is refused | the clamp, a refusal or a reason differs, or an old file fails |
| D0-1 | `DesignStyleSchemaTests`: a version-1 JSON string decodes with `opacity == 1`, `stroke == nil`, `textStyle == .default`, `cornerRadius == 0`; a node with every field set round-trips; `DesignNode(id: "node-99", copying: n)` equals `n` in every field but `id`; `DesignPage(id:name:frameWidth:frameHeight:nodes:)` builds from another module (`import DesignModel` without `@testable`); MJ1. `DesignSelectionRunTests`: nudge A, select B, nudge B gives two undo steps; nudge A twice gives one | an old file fails or changes, a copy drops a field, the init is not public, or two selections' nudges merge |
| D0-2.1 | `DesignIDMintTests`: a mint over `{node-1, node-3}` after 0 hands out node-2, node-4, node-5 and records them in `minted`; a negative counter starts at 0; 1,000 calls never repeat or hit `taken`. `DesignRefusalHelpTests`: every case's `help` equals the blueprint's sentence, `tooFew(needed: 2)` reads "Select two or more layers.", `runKey("move", ["node-4", "node-3"]) == "move-node-3,node-4"` | an id repeats, a help's words drift, or the key depends on order |
| D0-2.2 | `DesignDocumentTests`: `DesignDocument(pages:)` has empty components and variables; equality covers all three; each protocol is satisfiable by a test-local type | a signature differs from 5.4 or a default is missing |
| D0-2.3 | `DesignNotBuiltTests`: for every slot of `.live`, the help on a `cards`-shaped tree with A selected is "<feature> isn't built yet." with the slot's 5.6 name, and the write throws `.notBuilt(name)`; `NotBuilt.decode` throws `.unreadable`; `useServices(.live)` keeps the document; a workspace on `.live` differs from the same workspace on a `DesignServices` built in the test and equals itself | a slot names the wrong feature, a NotBuilt write succeeds, or services break workspace equality |
| D0-2.4 | `DesignSelectFakesTests`: marquee (80, 80)–(520, 240) in Desktop picks A and B, and (380, 580)–(720, 720) picks nothing; move by (40, 0) moves A with its subtree; resize, nudge (1 and 10), delete name their steps "Resize", "Nudge", "Delete"; Align Top on A, B, C sets y 100 on all three; distribute widths 20, 40, 20 across 0…300 gives equal gaps within 1e-9 (QD-V6); two layers: `.tooFewToDistribute`; `rectToShow` of C is C's frame | a fake acts only at the top level, picks a locked or hidden layer, or a number is off |
| D0-2.5 | `DesignArrangeFakesTests`: duplicate A sits right above A, offset (10, 10), unlocked, fresh ids (QD-V5); group A and B keeps every leaf frame (QD-V4) and names "Group"; A with E1 throws `.notSameParent`; ungroup Pair gives E1, E2 selected; copy Pair, paste lands in Desktop at +10, +10 with two children; `pasteHelp` of `"hello"` bytes is "The pasteboard holds no Design layers."; move Title into Pair; send B to back; set X 300 on A and B sets both; MJ2 | a copy keeps an id, a group moves a leaf, or paste lands in the wrong parent |
| D0-2.6 | `DesignContractLawTests`: for every protocol, every command and every selection in {none, A, A+B, A+B+C, Locked, Hidden, Pair}, on `.fake` and `.live`: help nil ⇒ the write throws nothing but `.unchanged`; help non-nil ⇒ it throws; a deliberately broken conformance defined in the test is caught | any conformance breaks the law |
| D0-2b | `DesignLiveStubTests`: `.live`'s slots are the `Live*` types; each tier-1 stub answers the same help and refusal as `NotBuilt` with its name; `LiveFiling` round-trips `cards` byte for byte with `DesignFile`'s encoder and refuses `not json` with `DesignFile`'s reason; the law still passes on `.live`; MJ3 | a stub is missing from `.live`, a stub acts, or saving through `LiveFiling` differs from today's bytes |
| D0-3a | `DesignActionsTests` with `.fake`: each `DesignCommand` records exactly one step with its name, and a refusal records none; the help law holds for every command and selection through the workspace; with `.live` and A selected, `.delete`, every `.nudge` and every single-layer `.align` work and record today's names, while with A and B they are refused with the slot's "isn't built yet."; `mint()` never hands out an id the file holds; Zoom to Selection's rect is nil with nothing selected and its help is "Select a layer first."; `selectAll()` with nothing selected selects Desktop, and with A selected selects Desktop's visible unlocked children | one-layer editing goes off on `.live`, a refusal records a step, or an id repeats |
| D0-3b | `DesignActionsEditTests`: copy Pair then paste: one "Paste" step, two new ids; `cutSelection` on B is one "Cut" step and the bytes paste back; `pasteHelp(nil)` is non-nil; `moveLayer` of Title into Pair is one "Move Layer" step; with `.live` and A selected, `setStyle(.frame(.x, 300))`, `.fill` and `.cornerRadius(12)` work through today's methods; with A and B, `.frame(.x, 300)` on `.fake` sets both in one step, and on `.live` it throws `.notBuilt("Style editing")`; two `.opacity` changes in a row on A are one step; MJ4 | a one-layer row goes off, a cut is two steps, or a scrub run is several steps |
| D0-4a | `DesignFixturesTests`: every fixture matches the blueprint's table (names, frames, parents, Locked locked, Hidden hidden); `crowd` holds exactly 2,000 layers: 40 frames, each with 48 rectangles and one text; ids unique; `encode(decode(encode(f))) == encode(f)` for each (QD-V1). `DesignBudgetHelperTests`: the helper reports median and p95 of N runs and fails a body that sleeps past its gate | a fixture differs from the table, a save is unstable, or the helper cannot fail |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QD-V1 save is stable, version 1 still opens | byte equality | `DesignFixturesTests.roundTripIsStable`, `DesignStyleSchemaTests.versionOneOpens`, `DesignCornerRadiusTests` |
| QD-V4, QD-V5, QD-V6 (fake rules) | exact, ≤ 1e-9 | `DesignArrangeFakesTests`, `DesignSelectFakesTests` (the live halves are the wave-1 features') |
| QB-F3 one command, one step | one undo step per command | `DesignActionsTests`, `DesignActionsEditTests` |
| help law (7.5) | every conformance, every command | `DesignContractLawTests` |

No drag or scrub here: the gesture routes are design-seams', and the rule
that the editor body doesn't run per sample is design-window's DW-b.

## Done check

Linux-only. Each slice is done when its tasks have merged and its walk
(MJ1 to MJ4) passes on the Linux gate; the feature is done when all four
are. Nothing here is compiled only on macOS, so no macOS run decides it.
The lead comments `Belt-Contact-Sheet:` on the feature issue with the
Linux gate run of the last PR and a line saying no screen changed. A red
J0 to J3 on the next Design-scoped macOS run is a finding against the slice
that touched the file, not a block on done.
