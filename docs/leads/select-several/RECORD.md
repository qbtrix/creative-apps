# select-several lead record

Issue: #1495 · Packet: docs/blueprints/design/features/select-several.md
Run: act-1a14a88d756-rnok · Session: claude/design-feature-lead-7saqm8 · Started: 2026-10-17T15:46Z
Stage: 3 wave 1
Base: dd7ec767cc0afab91b35ff4f208351dd866028d8
Next: S-6 #2373 through the lane; then S-7; S-5 waits on CB-a

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SS-a | marquee, several-layer move/resize/nudge/delete, align and distribute, on screen | S-1, S-2, S-3, S-6, S-7 | J5, J6 | design-window DW-a, DW-b (S-6); design-seams (S-7) | yes | 0 | building | – | – |
| SS-b | Zoom to Selection; no edit mid-gesture; budgets | S-4, S-5, S-7b, S-8 | J4, P1 | design-seams, canvas-basics CB-a (S-5); DW-a, SS-a (S-7b, S-8) | no | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| S-1 | SS-a | 0 | LiveMarquee | Sources/DesignModel/Live/LiveMarquee.swift; Tests/DesignModelTests/DesignMarqueeTests.swift | DesignMarqueeTests | (before this run) | merged |
| S-2 | SS-a | 0 | LiveTransforming several layers | Sources/DesignModel/Live/LiveTransforming.swift; Tests/DesignModelTests/DesignSeveralTransformTests.swift | DesignSeveralTransformTests | (before this run) | merged |
| S-3 | SS-a | 0 | LiveAligning distribute | Sources/DesignModel/Live/LiveAligning.swift; Tests/DesignModelTests/DesignDistributeTests.swift | DesignDistributeTests | (before this run) | merged |
| S-4 | SS-b | 0 | LiveFraming | Sources/DesignModel/Live/LiveFraming.swift; Tests/DesignModelTests/DesignFramingTests.swift | DesignFramingTests | (before this run) | merged |
| S-5 | SS-b | – | no edit or step while a gesture is live; no nudge of a hidden-in-tree layer | DesignCanvasEditing.swift, DesignActions.swift, DesignActions+Edit.swift; tests | DesignMidDragEditTests, DesignHiddenNudgeTests | – | waits design-seams, CB-a |
| S-6 | SS-a | – | views: several-layer handles, Distribute buttons, marquee from the Model; snapshots | DesignSelectionMarks.swift, DesignAlignBar.swift; snapshots | DesignMarqueeSnapshots, DesignAlignSnapshots, DesignMultiSelectSnapshots | – | waits DW-b |
| S-7 | SS-a | – | J5, J6 | UITests/DesignJourneyTests+Select.swift | J5, J6 | – | waits S-6, design-seams |
| S-7b | SS-b | – | J4 | UITests/DesignJourneyTests+Select.swift | J4 | – | waits S-4, S-7 |
| S-8 | SS-b | – | QD-S1..S4 budgets, P1; feature-done | Tests/DesignModelTests/DesignSelectBudgetTests.swift; UITests/DesignJourneyTests+PerfCanvas.swift | DesignSelectBudgetTests, P1 | – | waits S-7b, design-seams |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main (CLAUDE.md). main verified at 2c5003b.
- S-1 to S-4 merged before this run (their Live files and tests are on dev, tests enabled), as the packet says for S-1 to S-3.
- No task of this feature can start in wave 1: S-6 waits on design-window DW-a and DW-b, which this lead builds first.

## Open
- S-5, S-7, S-8 wait on design-seams (#1493), which has not built wave 1 (D0-3c); S-5 also waits on canvas-basics CB-a.
- Stage-1 issues filed: gaps #2144 (marquee), #2145 (several layers), #2146 (Zoom to Selection); needs-ui #2147 (CanvasViewport scroll to a rect).
