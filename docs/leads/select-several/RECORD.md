# select-several lead record

Issue: #1495 · Packet: docs/blueprints/design/features/select-several.md
Run: act-1a14644dd70-3gpr · Session: unknown · Started: 2026-10-16T19:53Z
Stage: 2 plan (blocked)
Base: origin/dev 98414eb83d8f326ece464f1637a61c30450a1372 (the brief names main 8b414fc; CLAUDE.md says dev is the only integration base, so PRs target dev)
Next: wait for design-window DW-a and DW-b, design-seams and canvas-basics CB-a to merge; then S-6, S-5, S-7, S-7b, S-8

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SS-a | marquee select; move, resize, nudge, delete, align, distribute as one step each | S-1, S-2, S-3, S-6, S-7 | J5, J6 | design-window DW-a, DW-b; design-seams | true | 0 | building | - | wanted at merged-done |
| SS-b | Zoom to Selection; mid-drag edit waits; 2,000-layer drag budget | S-4, S-5, S-7b, S-8 | J4, P1 | design-seams; canvas-basics CB-a; SS-a | false | 0 | building | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| S-1 | SS-a | 1 | LiveMarquee | Live/LiveMarquee.swift; DesignMarqueeTests.swift | DesignMarqueeTests | - | file present on dev (packet says merged); tests not verified (no Swift toolchain here) |
| S-2 | SS-a | 1 | LiveTransforming | Live/LiveTransforming.swift; DesignSeveralTransformTests.swift | DesignSeveralTransformTests | - | file present on dev (packet says merged); tests not verified |
| S-3 | SS-a | 1 | LiveAligning and distribute | Live/LiveAligning.swift, DesignAlign.swift; DesignDistributeTests.swift | DesignDistributeTests | - | packet says merged; file on dev not verified |
| S-4 | SS-b | 1 | LiveFraming | Live/LiveFraming.swift; DesignFramingTests.swift | DesignFramingTests | - | file present on dev; tests not verified |
| S-5 | SS-b | 2 | mid-gesture edit guard, hidden nudge | DesignCanvasEditing.swift, DesignActions*.swift; mid-drag tests | DesignMidDragEditTests | - | waiting: design-seams, canvas-basics CB-a |
| S-6 | SS-a | 2 | views: marquee, selection handles, Distribute row, snapshots | DesignSelectionMarks.swift, DesignAlignBar.swift, snapshots | snapshots | - | waiting: S-1..S-3, DW-a, DW-b |
| S-7 | SS-a | 3 | J5, J6 | UITests/DesignJourneyTests+Select.swift | journeys | - | waiting: S-6, design-seams |
| S-7b | SS-b | 4 | J4 | UITests/DesignJourneyTests+Select.swift | journey | - | waiting: S-4, S-7 |
| S-8 | SS-b | 4 | QD-S1..S4 budgets, P1; carries feature-done | DesignSelectBudgetTests.swift, DesignJourneyTests+PerfCanvas.swift | budgets | - | waiting: S-7b, design-seams |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main (same reason as copy-group).
- Recorded on the designated branch claude/design-line-lead-nq14ye, not lead/select-several (same reason as copy-group).
- SS-a is the UI slice (ui: true): its feel gate and Mac finish are beta-hardening work, not a blocker for the slice line.
- No builder swarm started: S-6 needs DW-a and DW-b, which aren't verified on dev, and nothing here can be compiled.

## Open
- design-window DW-a and DW-b not verified on dev; design-seams and canvas-basics show "planned".
- No PRs, no reviews, no Belt-Slice-Done lines posted.
