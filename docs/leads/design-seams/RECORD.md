# design-seams lead record

Issue: #1493 · Packet: docs/blueprints/design/features/design-seams.md
Run: act-1a14ddefb3a-z1bl (re-check; built on act-1a14cd4adaa-upx1) · Session: claude/feature-lead-playbook-k74hfj · Started: 2026-10-17T15:40Z
Stage: done (Belt-Contact-Sheet posted 2026-10-17T18:26Z)
Base: 948bcbf40cb0efa747755eb338f50ca1f06012d6 (origin/main = origin/dev, 948bcbf)
Next: none; SE-a done on run 39055200176 (completed, success, contains 6f4ab53); verification belongs to the finisher

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SE-a | marquee, several-layer move and resize, Option-drag as one Duplicate step, budgets on 2,000 layers | D0-3c, D0-4b | MJ5 | design-contracts (built) | no | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39055200176 | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| D0-3c | SE-a | 1 | gesture routes: marquee rule, several-layer move/resize, Option-drag Duplicate, endDrag clears marquee; walk MJ5 | Sources/DesignModel/DesignCanvasEditing.swift; Tests/DesignModelTests/DesignGestureRouteTests.swift, DesignOptionDragTests.swift | DesignGestureRouteTests, DesignOptionDragTests, MJ5 | #2167 | merged 6f4ab53 (17:19Z, batch run 39052683567) |
| D0-4b | SE-a | 1 | QD-S8, QD-S9, QD-S11 budgets on crowd | Tests/DesignModelTests/DesignBudgetTests.swift | DesignBudgetTests | #2162 | merged 2bee63e (17:10Z) |

D0-3c and D0-4b share no file and do not call each other: one wave, both independent.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Base: a575d0351f2df6c5a0dff97d70eb59e860cc61b9 (origin/dev, a575d03)
- Pushes go to lead/design-seams (authorised in the Belt message).
- LiveMarquee.swift exists: D0-3c uses it (rule 20); the packet's note that .live's marquee answers [] is stale, fixed in the D0-3c PR (supervisor, #1493).
- No UI slice ("ui_slice": "none"); the Linux walk MJ5 is the done check.

## Open
- canvas-basics CB-2 waits on D0-3c: this wave is on the Design critical path.
