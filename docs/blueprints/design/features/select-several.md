# Feature packet: select-several

**Feature:** select and edit several layers at once: marquee select, move,
resize, nudge and delete a multi-layer selection, align several layers to
each other and distribute them, and View > Zoom to Selection; plus the two
mid-gesture bugs on the same code path. (Blueprint F1.)
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/select-several`

**Covers:** #714 (align several, distribute), #542 (an edit mid Move or
Resize drag), #607 (arrows nudge a layer in a hidden group), #288 (part:
the views this feature owns). The lead files at stage 1, each labelled
`gap`, `line:design`, `p1`, `in-progress` (blueprint 8.1):

- "Design: marquee select" (#413 closed after Shift-click alone): S-1, S-6.
- "Design: move, resize, nudge and delete several layers": S-2, S-6.
- "Design: View > Zoom to Selection": S-4, S-7.

and one `needs-ui` issue (labels `needs-ui`, `line:suiteui`): "SuiteUI:
`CanvasViewport` scrolls to show a document rect the host passes" (no
SuiteUI packet covers it; canvas-marks does not). J4's centering assert is
an `XCTSkip` naming that issue until it lands.

**Depends on:** the design-contracts feature issue: the Model tasks (S-1
to S-4) code against its protocols, fakes, live stubs and fixtures and start
when it closes. The view and journey tasks wait on design-window's contract
slice DW-a (the canvas slots, the Align row, the menus, the launch
arguments), S-6's drag check also on DW-b (the live drag box and the
`bodyRuns` counter), and S-5, S-7 and S-8 on design-seams (the gesture
routes they guard or drive). The journey template, `perf()` and the velocity
drags P1 needs are on `dev` (#778 merged). No creative-core issue. Not blocked by SuiteUI
#273 (Q7): this feature keeps Design's own several-layer box in
`DesignSelectionMarks.swift`; adopting `SelectionHandles` is the
`line:design` task canvas-marks CM-4 files later.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Design-scoped macOS run.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SS-a | A marquee selects several layers, which then move, resize, nudge, delete, align and distribute as one step each. | S-1, S-2, S-3, S-6, S-7 | J5, J6 | design-contracts (S-1 to S-3); design-window DW-a (S-6, S-7) and DW-b (S-6); design-seams (S-7) |
| SS-b | View > Zoom to Selection frames the selection, an edit pressed mid-drag waits for the drag to end, and canvas drags keep up on 2,000 layers. | S-4, S-5, S-7b, S-8 | J4, P1 | design-contracts (S-4); design-seams (S-5, S-8); design-window DW-a (S-7b, S-8); SS-a (S-7b, S-8) |

Every drag here goes through design-window's live drag box, so the editor
body doesn't run per sample: S-6 checks it for the marquee and the
several-layer resize.

Blueprint sections: 4 (J4, J5, J6, P1), 5.4 (`MarqueeSelecting`,
`SelectionTransforming`, `LayerAligning`, `ViewFraming`), 6 (selection
marks), 7.1 (QD-S1 to QD-S5), 7.4 (QD-V6), 8.2 (F1).

## Journey steps

All on `cards`, live services (this feature's live types land before its
journeys, so no `-DesignServices fake` run is needed and none is left
behind). In `UITests/DesignJourneyTests+Select.swift`, one `XCTestCase`
class `DesignSelectJourneyTests`:

1. **J4** `testZoomPanFitAndZoomToSelection` (S-7b): read the zoom pill (the
   fitted percent f); select C; ⌘+ twice (the pill reads the second
   `ViewerZoom` stop above f); Space-drag 200 pt left (`design.canvas.selection`
   moved about 200 pt left); ⌘0 (f again); View > Zoom to Selection ⌥⌘2
   (the pill reads the stop that fits C; C's center within 2 pt of the
   canvas center: `XCTSkip` naming the `needs-ui` issue until it lands);
   Escape, then the item is disabled with "Select a layer first."
2. **J5** `testMarqueeMoveResizeSeveral` (S-7): marquee from (80, 80) to (520, 240)
   (the header reads "2 Layers": A and B);
   drag A 40 pt right ("Undo Move"); the box's bottom-right handle out 20 pt
   ("Undo Resize"); ⇧→ ("Undo Nudge"); ⌫ ("Undo Delete"); ⌘Z (all back);
   marquee (380, 580)–(720, 720) over Locked and Hidden selects nothing.
3. **J6** `testAlignAndDistributeSeveral` (S-7): select A, B, C; Align Top from
   the inspector ("Undo Align Top"); Object > Distribute Horizontally ("Undo
   Distribute Horizontally"); select A and B: Distribute is disabled with
   "Select three or more layers to distribute."
4. **P1** `testCanvasDragLatency` (`+PerfCanvas`, class
   `DesignPerfCanvasJourneyTests`) on `crowd`: four velocity drags of 600 pt
   at 300 pt/s (move, draw a rectangle, resize, marquee), one Space-pan, ⌘+
   and ⌘− ten times each; at least 60 samples per series; report-only.

J5's count, checked against the fixture: the marquee (80, 80)–(520, 240)
inside Desktop touches A (100…200, 100…180) and B (300…500, 140…220); Title
(y 40…72) ends above it and C (x 700…800) starts right of it. S-1's test
pins the same set.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Canvas, marquee | a marquee that touches nothing selects nothing (the inspector shows the page) | – | none |
| Canvas, several selected | – | a drag on a selection holding a locked or hidden-in-tree layer moves nothing and the status message reads the refusal ("Unlock Locked to change it.") | none |
| Inspector, several | – | Distribute with fewer than three: disabled with "Select three or more layers to distribute." | none |
| View > Zoom to Selection | nothing visible selected: disabled with "Select a layer first." | – | none |

## Contract slice

The four protocols of blueprint 5.4, filled by the live types:

```swift
// Sources/DesignModel/Live/LiveMarquee.swift
public struct LiveMarquee: MarqueeSelecting      // replaces D0-2b's stub body
// Sources/DesignModel/Live/LiveTransforming.swift
public struct LiveTransforming: SelectionTransforming
// Sources/DesignModel/Live/LiveAligning.swift
public struct LiveAligning: LayerAligning
// Sources/DesignModel/Live/LiveFraming.swift
public struct LiveFraming: ViewFraming
```

Their rules, beyond the fakes': the marquee never picks a layer that is
hidden or locked or inside one (5.4); move, resize, nudge and delete refuse
`.locked(name)` or `.hidden(name)` when any selected layer is locked or
hidden in the tree, and `.nothingSelected` with none; resize scales each
layer's frame inside the box (its offset and size by the box's ratio, with
Shift and Option as today, W and H at least 1); align uses the union of the
selected frames, and locked layers count toward it but do not move;
distribute keeps the outer two and spaces the rest (#714); framing is the
union of the visible selected frames.

## Pseudocode

```
LiveMarquee.layers(touching r, in p, on page):
  if let p, hiddenOrLockedInTree(p) { return [] }   # a hidden or locked parent hides its children
  level = p.map { page.nodes.node($0)?.children } ?? page.nodes
  return level.filter { !$0.isHidden && !$0.isLocked && touches($0.frame, r) }.map(\.id)
  # candidates are one level, so a hidden or locked ancestor is never crossed

LiveTransforming.check(ids, page):
  guard nodes = find(ids), !nodes.isEmpty else throw .nothingSelected
  if let n = nodes.first(where: lockedInTree) throw .locked(n.name)
  if let n = nodes.first(where: hiddenInTree) throw .hidden(n.name)
resize(ids, handle, delta, mods):
  box = union(frames); new = box.resized(handle, by: delta, keepAspect: .shift, fromCenter: .option)
  sx = new.width / max(box.width, 1e-9); sy = …     # never divide by zero
  each layer (and its subtree): x' = new.x + (x - box.x) * sx; w' = max(w * sx, 1)
  coalescing runKey("resize", ids)

LiveAligning.align(edge, ids):
  box = ids.count == 1 ? enclosing frame or page (today's rule) : union(all selected frames, locked included)
  move each unlocked layer to the edge; locked stay
distribute(axis, ids): ≥ 3 else .tooFewToDistribute; sort by min edge; outer two stay;
  gap = (span - sum(inner sizes)) / (inner.count + 1); place inner in order

LiveFraming.rectToShow(ids) = union(visible selected frames); help nil exactly then

#542: while gesture != nil, the public entry points (deleteSelection, nudge, run,
      setStyle, cutSelection, paste, moveLayer) do nothing and record nothing, as undo()
      and redo() already do. `apply` itself has no guard: the drag steps of the
      several-layer move, resize and Option-drag call it with the gesture live
#607: nudge on one layer returns early when isHiddenInTree(id) (no step)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: select-several`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. S-8 also
carries `feature-done`. Paths drop `Sources/DesignModel/` and
`Sources/DesignApp/`; Model tests are `Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| S-1 | gap "marquee select" (part) | `LiveMarquee` | `Live/LiveMarquee.swift`; tests `DesignMarqueeTests.swift` | – | ~150, 2 |
| S-2 | gap "several layers" (part) | `LiveTransforming`: move, resize in the box, nudge, delete; lock and hidden refusals | `Live/LiveTransforming.swift`; tests `DesignSeveralTransformTests.swift` | – | ~310, 2 |
| S-3 | #714 (Model part) | `LiveAligning`: align to the union with locked layers fixed; distribute | `Live/LiveAligning.swift`, `DesignAlign.swift` (the one-layer help reused, no behaviour change); tests `DesignDistributeTests.swift` | – | ~260, 3 |
| S-4 | gap "Zoom to Selection" (part) | `LiveFraming` | `Live/LiveFraming.swift`; tests `DesignFramingTests.swift` | – | ~90, 2 |
| S-5 | #542, #607 (closes both) | No edit or step while a gesture is live; no nudge of a hidden-in-tree layer | `DesignCanvasEditing.swift`, `DesignActions.swift`, `DesignActions+Edit.swift`; tests `DesignMidDragEditTests.swift`, `DesignHiddenNudgeTests.swift`, `DesignHeldIDsFuzzTests.swift` (existing: gains the `history.undo` check) | design-seams | ~240, 6 |
| S-6 | gaps "marquee select", "several layers" (close); #714 (closes); #288 (part) | Views: the several-layer box's handles (the canvas gesture already routes them to `resize`); the Align row's Distribute buttons and their ids; the marquee drawn from the Model; snapshots; the drag check | `DesignSelectionMarks.swift`, `DesignAlignBar.swift`; snapshots `DesignMarqueeSnapshots.swift`, `DesignAlignSnapshots.swift`, `DesignMultiSelectSnapshots.swift`; `Tests/AppSnapshotTests/DesignSelectDragTests.swift` | S-1, S-2, S-3; design-window DW-a, DW-b | ~320, 6 |
| S-7 | – | J5, J6 | `UITests/DesignJourneyTests+Select.swift` | S-6; design-seams | ~240, 1 |
| S-7b | gap "Zoom to Selection" (closes) | J4, in the same file after S-7 | `UITests/DesignJourneyTests+Select.swift` | S-4, S-7 | ~80, 1 |
| S-8 | – | QD-S1 to QD-S4 model budgets; P1 | tests `DesignSelectBudgetTests.swift`; `UITests/DesignJourneyTests+PerfCanvas.swift` | S-7b; design-seams | ~220, 2; `feature-done` |

S-1 to S-5 touch disjoint files and run side by side: S-1 to S-4 once
design-contracts has closed, S-5 once design-seams has (it guards
design-seams' `DesignCanvasEditing.swift` and design-contracts' action
files, which pass to this feature then). Only S-6 edits views, and only the
two files design-window's DW-a hands over (`DesignSelectionMarks.swift`,
`DesignAlignBar.swift`): `DesignCanvas.swift` stays design-window's. If the
`CanvasViewport` show-rect input lands in SuiteUI, a `line:design` follow-up
the lead files passes `show` on from `DesignCanvas.swift` and drops J4's
skip. S-2's old check that a several-layer drag keeps working mid-gesture
moved to S-5, which owns the gesture guard.

S-6 needs S-1, S-2 and S-3 for its live snapshots: the marquee on `.live`
picks through `LiveMarquee`, the box shows its handles only when
`LiveTransforming.transformHelp` is nil, and the aligned row comes from
`LiveAligning`. It does not need S-5: its files and snapshots don't touch
the mid-gesture guard. No task edits a shared doc (`docs/c4/model.json`,
`docs/design.md`, the blueprint or `waves.md`): the new `Live/` files sit in
the `DesignModel` component already.

## Build waves

- Wave 1: S-1, S-2, S-3, S-4, S-5. Independent in this wave: all five.
- Wave 2: S-6. Independent in this wave: S-6 alone.
- Wave 3: S-7. Independent in this wave: S-7 alone.
- Wave 4: S-7b. Independent in this wave: S-7b alone.
- Wave 5: S-8 (`feature-done`, final). Independent in this wave: S-8 alone.

Longest chain: S-1 → S-6 → S-7 → S-7b → S-8 (5).
Chain of 5: S-6 draws the marquee from `LiveMarquee` (S-1); J5 in S-7
drives S-6's box handles; S-7b adds J4 to S-7's journey file; S-8 carries
`feature-done`, whose run must hold J4 to J6, and P1's resize drag uses
S-6's handles.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| S-1 | `DesignMarqueeTests` on `cards`: (80, 80)–(520, 240) in Desktop gives [A, B] in paint order; (380, 580)–(720, 720) gives []; (880, 380)–(1220, 520) at the top level gives [Desktop] (the top level's only candidate, and it touches every rect on the page); inside Pair (its id as parent) gives [E1, E2]; with Pair hidden or locked, a marquee inside Pair gives []; a rect of zero size on an edge touches (closed intervals) | a hidden or locked layer, or one inside them, is picked, or the level is wrong |
| S-2 | `DesignSeveralTransformTests`: A and B moved by (40, 0) both move with their subtrees, one step "Move" with `runKey("move", [A, B])`; the box (100, 100)–(500, 220) resized by the bottom-right handle (20, 0) moves B from x 300 to 310 (its offset 200 in the box scales by 420/400 to 210) and makes its width 210; Shift keeps the ratio; a zero-width box never divides by zero; nudge 1 and 10; delete A and B is one "Delete" step; A with Locked throws `.locked("Locked")`, with Pair hidden (the test hides it), E1 throws `.hidden("E1")` (the selected layer is named, not the hidden ancestor); the contract law on `.live` | a layer moves without its subtree, a locked layer moves, a box of zero size crashes, or a refusal records |
| S-3 | `DesignDistributeTests` (QD-V6): three rectangles at x 10, 50, 200 aligned left all have x 10; with the middle one locked, the other two go to 10 and it stays, and the union still counts it; widths 20, 40, 20 spanning 0…300 distribute to equal gaps within 1e-9; two layers throw `.tooFewToDistribute` and change nothing; Align Top on A, B, C of `cards` gives y 100 on all three; one layer keeps today's `alignLayer` result | a number is off, a locked layer moves, or one-layer align changes |
| S-4 | `DesignFramingTests`: C alone gives C's frame; A and C give their union; Hidden alone gives nil and the help "Select a layer first."; nothing selected gives nil | a hidden layer is framed, or the help and rect disagree |
| S-5 | `DesignMidDragEditTests`: #542's repro (a delete mid-move, then the move and two undos) passes: the rectangle survives, the undo names are "Undo Move" then "Undo Add Rectangle"; the same with a nudge, `run(.align(.left))` and `setStyle(.frame(.x, 5))`; a several-layer drag on a selection the gesture already moved keeps working (the guard is not on `apply`); the seeded fuzz in `DesignHeldIDsFuzzTests` gains a check that `history.undo` holds no step taken mid-gesture. `DesignHiddenNudgeTests`: #607's repro gives an unchanged frame and "Undo Hide Layer" | a mid-gesture edit records a step, or a hidden layer moves |
| S-6 | `DesignMarqueeSnapshots`: `design-marquee` (mid-marquee over A and B, live); `DesignAlignSnapshots`: `design-align-light.png`, `design-align-dark.png` show three rectangles after Align Top (#714); `DesignMultiSelectSnapshots`: two of three selected now shows the 8 handles on the box (design-window drew the box with no handles while resize was not built; this task owns the PNG change); the journey guard in J5 (S-7) covers the gesture. `DesignSelectDragTests` (design-window D0-8b's `dragSamples`): a 120-sample marquee and a 120-sample several-layer resize on `crowd` each run `DesignEditor`'s body 3 times or fewer | a PNG lacks the box handles or the aligned row, or the editor body runs per sample |
| S-7 | J5 and J6 pass on the macOS run; J5 fails if the first marquee's count is not 2 or any undo name differs; J6 fails if Distribute with two is enabled | a step's name, count or disabled reason differs |
| S-7b | J4 passes on the macOS run, its centering assert skipped by name until the `needs-ui` issue lands | the pill or the disabled reason differs |
| S-8 | `DesignSelectBudgetTests.moveStep`, `.drawStep`, `.resizeStep`, `.marqueeStep` under the Linux debug gates on `crowd`; P1 records ≥ 60 samples per series and writes `perf-design-canvas.json` (report-only until ten green runs set its gate) | a model step is over its gate, or P1 has fewer than 60 samples |

## Quality tests

| quality row | budget (device / Linux debug gate; screen half) | test |
|---|---|---|
| QD-S1 Move step on a frame with 50 children | ≤ 1 ms / ≤ 10 ms; p95 ≤ 2 frames late | `DesignSelectBudgetTests.moveStep`; P1 move |
| QD-S2 draw step | ≤ 1 ms / ≤ 10 ms; p95 ≤ 2 frames late | `DesignSelectBudgetTests.drawStep`; P1 draw |
| QD-S3 resize step, 1 and 20 layers | ≤ 1 ms / ≤ 10 ms; p95 ≤ 2 frames late | `DesignSelectBudgetTests.resizeStep`; P1 resize |
| QD-S4 marquee step on 2,000 layers | ≤ 1 ms / ≤ 10 ms; p95 ≤ 2 frames late | `DesignSelectBudgetTests.marqueeStep`; P1 marquee |
| QD-S5 Space-pan and zoom keys | view state; pan p95 ≤ 2 frames late, a zoom key repaints within 2 frames | P1 pan, zoom |
| QD-V6 align and distribute exact | ≤ 1e-9 | `DesignDistributeTests` |
| QB-F3 one gesture, one step | each drag and command one step | J5, J6, `DesignSeveralTransformTests` |
| the editor body doesn't run per sample | ≤ 3 `DesignEditor` body runs over a 120-sample marquee or resize | `DesignSelectDragTests` (S-6) |

The screen halves are report-only (blueprint 7, "How gates are set") until
ten green CI runs give them a gate; the lead records each P1 series in
RECORD.md.

## Done check

Per slice: SS-a is done when J5 and J6 pass on the Design-scoped run after
S-7; SS-b when J4 and P1 do after S-8. The feature is done when both are:

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J4, J5, J6 and P1 new; J0 to J3, J1 and J15 still pass (J15 now
  clicks the enabled Distribute and marquee-backed controls).
- **Audit zero new:** that run's `design` counts are at or under the
  baseline; `identifier` falls for the controls S-6 touches.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey (J4, J5, J6, P1 with its p95
  per series) and the audit counts.
