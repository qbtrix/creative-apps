# Feature packet: design-seams

**Feature:** the gesture routes every canvas drag goes through (the
marquee rule, several-layer move and resize, Option-drag as one "Duplicate"
step) and the shared Model budget rows. Model code only, tested on Linux.
(Blueprint wave 0, D0-3c and D0-4b. The contracts, actions and fixtures it
builds on are `design-contracts.md`; the window half is `design-window.md`.)
**Line:** `line:design` · **Wave:** 0b (`waves.md`) · **Lead branch:** `lead/design-seams`

**Covers:** no open issue closes here. #288 is not touched (no view).

**Depends on:** the design-contracts feature issue (`DesignWorkspace`'s
`marquee`, the actions' `apply` and `mint`, the services, the fakes, the
fixtures and the budget helper). No SuiteUI issue, no creative-core issue.
PR #753 is no longer waited on: its Model half is design-contracts D0-0.

Blueprint sections it builds on: 5.5 (the gesture routes), 7.1 (QD-S8,
QD-S9, QD-S11), 8.2 (wave 0).

**What changed in the v3 re-cut (2026-10-16):** D0-0 to D0-3b and the
fixtures half of D0-4a moved to `design-contracts.md`, the feature every
other one compiles against. What stays is what only the canvas gestures and
the shared budgets need. The seams journey test is replaced by one walk per
slice: MJ1 to MJ4 in design-contracts, MJ5 here.

## Slices

A slice is the unit of done: its tasks have merged and its walk passes on
the Linux gate.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SE-a | A marquee selects inside the frame under the pointer, a drag moves or resizes several layers as one step, an Option-drag is one Duplicate step, and hit test, edit and save stay inside their budgets on 2,000 layers. | D0-3c, D0-4b | MJ5 | design-contracts (the feature) |

No UI slice (`"ui_slice": "none"` in the `.wave.json`): gesture routes and
budgets in the Model only; the canvas that drives them is design-window's.

## Journey steps

1. **MJ5** `DesignGestureRouteTests.testGesturesWalk` (D0-3c), Linux, on
   `cards` with `.fake`: a marquee from (80, 80) to (520, 240) inside
   Desktop selects A and B; drag A 40 pt right: one "Move" step for both;
   drag the box's bottom-right handle out 20 pt: one "Resize"; Option-drag A
   by (0, 100) in five steps: one "Duplicate" step and two A's; a marquee
   over Locked and Hidden selects nothing; `endDrag` leaves `marquee` nil.

The XCUITest journeys that drive these routes on screen are select-several's
J5 and copy-group's J7.

## Screens and states

No screen changes. Mid-gesture, `marquee` holds the rectangle the canvas
draws; after `endDrag` it is nil and the gesture has recorded at most one
step.

## Contract slice

| File (`Sources/DesignModel/`) | Holds | Task |
|---|---|---|
| `DesignCanvasEditing.swift` | the marquee rule, several-layer move and resize, Option-drag as one "Duplicate" step, `endDrag` clearing the marquee and ending the run | D0-3c |

`Tests/DesignModelTests/DesignBudgetTests.swift` (D0-4b) holds QD-S8,
QD-S9 and QD-S11, timed with design-contracts' `DesignBudget` helper.

Every step rewinds to the gesture's snapshot before it applies, so the
document after N samples equals the document after the last sample alone.
design-window's live drag box (D0-8a) relies on that: it replays only the
last sample at mouse-up. D0-3c's test pins it.

## Pseudocode

```
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
methods whatever `services` holds. `.live`'s marquee is `LiveMarquee`, which
already picks the visible, unlocked layers the rectangle touches at that
level, so a marquee selects on the live services too; where `.live`'s
Duplicate isn't built, an Option-drag stays a plain move.

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: design-seams`,
`Fast-Check: pass`, `Head:`. The one that merges last carries
`feature-done`. Paths drop `Sources/DesignModel/`; tests are
`Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| D0-3c | – | Gesture routes: the marquee rule, several-layer move and resize, Option-drag as one "Duplicate" step; `endDrag` clears the marquee and ends the run; walk MJ5 | `DesignCanvasEditing.swift`; tests `DesignGestureRouteTests.swift`, `DesignOptionDragTests.swift` | design-contracts | ~390, 3 |
| D0-4b | – | QD-S8, QD-S9, QD-S11 on `crowd` | tests `DesignBudgetTests.swift` | design-contracts | ~150, 1 |

D0-3c and D0-4b share no file and call nothing of each other. Both build
on the whole of design-contracts (its feature issue is this one's
`Depends on:`), which is why it is a feature dependency and not a slice
wait. This packet edits no shared doc.

## Build waves

- Wave 1: D0-3c, D0-4b. Independent in this wave: both.

Longest chain: 1.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D0-3c | `DesignGestureRouteTests` on `cards` with `.fake`: a press at (80, 80) on Desktop's background dragged to (520, 240) selects A and B and records nothing; the same press with Desktop selected moves Desktop ("Move"); a click there without moving selects Desktop; a press outside the page marquees the top level; with A and B selected, a drag of A by 40 is one "Move" step for both, and the box's bottom-right handle by 20 is one "Resize"; `endDrag` leaves `marquee == nil`; a move fed 120 samples and the same move fed only its last sample end with equal documents and one undo step; MJ5. `DesignOptionDragTests`: Option-drag A by (0, 100) in five steps gives exactly one undo step named "Duplicate", two A's, the copy at A.y + 100, the same copy id after every step, and one ⌘Z restores the tree; a second Option-drag is a second step | the marquee rule picks the wrong level, an Option-drag records more than one step or mints new ids per step, a drag outlives `endDrag`, or the last sample alone gives a different document |
| D0-4b | `DesignBudgetTests.hitTest` (QD-S8), `.applyStep` (QD-S9), `.fileRoundTrip` (QD-S11): median and p95 of 200 runs on `crowd` under the Linux debug gates, through `DesignBudget` | a budget is exceeded |

## Quality tests

| quality row | budget (device / Linux debug gate) | test |
|---|---|---|
| QD-S8 hit test per pointer move | ≤ 0.5 ms / ≤ 5 ms on 2,000 layers | `DesignBudgetTests.hitTest` |
| QD-S9 any document edit (`apply` plus one record) | ≤ 1 ms / ≤ 10 ms | `DesignBudgetTests.applyStep` |
| QD-S11 open and save `crowd` | decode and encode ≤ 50 ms / ≤ 500 ms | `DesignBudgetTests.fileRoundTrip` |
| QB-F3 one gesture, one step | one undo step per drag | `DesignOptionDragTests`, `DesignGestureRouteTests` |
| a drag's samples can be replayed from the last one | the last sample alone gives the same document | `DesignGestureRouteTests` (the rule design-window's DW-b builds on) |

## Done check

Linux-only. SE-a is done when D0-3c and D0-4b have merged and MJ5 passes on
the Linux gate. The lead comments `Belt-Contact-Sheet:` on the feature
issue with that run and a line saying no screen changed. A red J0 to J3 on
the next Design-scoped macOS run is a finding against this slice, not a
block on done.
