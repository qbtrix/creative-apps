# select-several lead record

Issue: #1495 · Packet: docs/blueprints/design/features/select-several.md
Run: act-1a14ddefb3a-z1bl (resumes act-1a14a88d756-rnok) · Session: claude/feature-lead-playbook-k74hfj · Started: 2026-10-17T15:46Z
Stage: 3 wave 2
Base: cd81c77b0fa1d56822a09bb1208df52ee4548568
Next: SS-a re-done on scoped design 39107691328 (holds 148ade3e; J6 green, #2692 closed). J5 still skips at the ⇧→ nudge on two layers: finding #2706, round 2 PR #2707 head e7afea2 in the lane (root cause: arrow presses carry the numeric-pad flag, so the canvas key guard dropped every arrow). Re-done again on a run holding that fix. S-8 #2696 in the lane; S-5 waits on CB-a.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SS-a | marquee, several-layer move/resize/nudge/delete, align and distribute, on screen | S-1, S-2, S-3, S-6, S-7 | J5, J6 | design-window DW-a, DW-b (S-6); design-seams (S-7) | yes | 2 | merged (re-done on 39107691328; round 2 PR #2707 for #2706 in the lane) | 39107691328 | wanted |
| SS-b | Zoom to Selection; no edit mid-gesture; budgets | S-4, S-5, S-7b, S-8 | J4, P1 | design-seams, canvas-basics CB-a (S-5); DW-a, SS-a (S-7b, S-8) | no | 0 | building (S-8 wave 2; S-5 waits CB-a; #2538 blocked on needs-ui #2623) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| S-1 | SS-a | 0 | LiveMarquee | Sources/DesignModel/Live/LiveMarquee.swift; Tests/DesignModelTests/DesignMarqueeTests.swift | DesignMarqueeTests | (before this run) | merged |
| S-2 | SS-a | 0 | LiveTransforming several layers | Sources/DesignModel/Live/LiveTransforming.swift; Tests/DesignModelTests/DesignSeveralTransformTests.swift | DesignSeveralTransformTests | (before this run) | merged |
| S-3 | SS-a | 0 | LiveAligning distribute | Sources/DesignModel/Live/LiveAligning.swift; Tests/DesignModelTests/DesignDistributeTests.swift | DesignDistributeTests | (before this run) | merged |
| S-4 | SS-b | 0 | LiveFraming | Sources/DesignModel/Live/LiveFraming.swift; Tests/DesignModelTests/DesignFramingTests.swift | DesignFramingTests | (before this run) | merged |
| S-5 | SS-b | 3 | no edit or step while a gesture is live; no nudge of a hidden-in-tree layer | DesignCanvasEditing.swift, DesignActions.swift, DesignActions+Edit.swift; tests | DesignMidDragEditTests, DesignHiddenNudgeTests | – | waits canvas-basics CB-a (CB-3 also edits DesignCanvasEditing.swift); design-seams met; feature-done |
| S-6 | SS-a | 1 | views: several-layer handles, Distribute buttons, marquee from the Model; snapshots | DesignSelectionMarks.swift, DesignAlignBar.swift; snapshots | DesignMarqueeSnapshots, DesignAlignSnapshots, DesignMultiSelectSnapshots | – | waits DW-b |
| S-7 | SS-a | 1 | J5, J6 | UITests/DesignJourneyTests+Select.swift | J5, J6 | – | waits S-6, design-seams |
| S-7b | SS-b | 1 | J4 | UITests/DesignJourneyTests+Select.swift | J4 | – | waits S-4, S-7 |
| S-8 | SS-b | 2 | QD-S1..S4 budgets, P1 | Tests/DesignModelTests/DesignSelectBudgetTests.swift; UITests/DesignJourneyTests+PerfCanvas.swift | DesignSelectBudgetTests, P1 | – | PR #2696 open, head b1c409b (QD-S4 over gate: gap #2695) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-18 resume (act-1a14ddefb3a-z1bl): brief says base main; dev is 37 ahead of main and CLAUDE.md forbids targeting main, so PRs stay on dev. main verified at e01529f.
- design-seams' wait is met by SE-a's Belt-Slice-Done (#1493 stays open as a feature-lead issue), so S-8 starts now.
- feature-done moves from S-8 to S-5, the last SS-b task to merge (S-5 still waits on CB-a).
- Base is origin/dev, not main (CLAUDE.md). main verified at 2c5003b.
- S-1 to S-4 merged before this run (their Live files and tests are on dev, tests enabled), as the packet says for S-1 to S-3.
- No task of this feature can start in wave 1: S-6 waits on design-window DW-a and DW-b, which this lead builds first.

## Open
- #2691 closed (J6 green on 39107691328); #2692 closed as fixed by #2621 (J5 past Resize). J5 now skips at the nudge: finding #2706 (round 2; a third miss makes it a gap).
- S-8 #2696: QD-S4 marquee step is over its 10 ms gate (known issue, gap #2695 p2); DesignSelectBudgetTests in Tests/perf-suites.txt is the supervisor's call (asked in the PR body).
- S-5 waits on canvas-basics CB-a (CB-1, CB-2 merged; CB-3 building).
- #2538 (J4, SS-b) blocked on needs-ui #2623 (CanvasViewport scroller unnamed).
- Stage-1 issues filed: gaps #2144 (marquee), #2145 (several layers), #2146 (Zoom to Selection); needs-ui #2147 (CanvasViewport scroll to a rect).
- S-8 #2696 (f7d57daf) shown on scoped design https://github.com/qbtrix/creative-apps/actions/runs/39118734724 (a80ed944, success). Finding #2751 (P1 testCanvasDragLatency: unnamed 427x11 button on design-perf-canvas-zoomed-in) is SS-b round 1; fixer sent, likely the same SuiteUI scroller as needs-ui #2623.
- #2751 has the same cause as needs-ui #2623 (CanvasViewport's system horizontal scroller in SuiteUI); blocked, no Design PR. If #2623 is still open when SS-b's rounds end, #2751 joins the gaps.
- SS-a done on scoped design https://github.com/qbtrix/creative-apps/actions/runs/39122750799 (e3a4582c, holds #2707 d353fee7): J5 testMarqueeMoveResizeSeveral and J6 testAlignAndDistributeSeveral green; Belt-Slice-Done posted on #1495. J4 (#2538) and P1 (#2751) still red on the CanvasViewport scroller, needs-ui #2623.
