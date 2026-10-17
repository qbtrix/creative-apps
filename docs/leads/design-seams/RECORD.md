# design-seams lead record

Issue: #1493 · Packet: docs/blueprints/design/features/design-seams.md
Run: act-1a1465d47db-qxmg · Session: this session · Started: 2026-10-16T20:49Z
Stage: 2 plan
Base: 1d68b2288cfe9c31e6b7cea460f5eb1ada5ddd18 (origin/dev, 1d68b22)
Next: install or locate a Swift toolchain (none on PATH), then build wave 1 (D0-3c, D0-4b) on `lead/design-seams`

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SE-a | marquee, several-layer move and resize, Option-drag as one Duplicate step, budgets on 2,000 layers | D0-3c, D0-4b | MJ5 | design-contracts (built) | no | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| D0-3c | SE-a | 1 | gesture routes: marquee rule, several-layer move/resize, Option-drag Duplicate, endDrag clears marquee; walk MJ5 | Sources/DesignModel/DesignCanvasEditing.swift; Tests/DesignModelTests/DesignGestureRouteTests.swift, DesignOptionDragTests.swift | DesignGestureRouteTests, DesignOptionDragTests, MJ5 | – | planned |
| D0-4b | SE-a | 1 | QD-S8, QD-S9, QD-S11 budgets on crowd | Tests/DesignModelTests/DesignBudgetTests.swift | DesignBudgetTests | – | planned |

D0-3c and D0-4b share no file and do not call each other: one wave, both independent.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Base: origin/dev, not main. CLAUDE.md says never branch from or target main; the brief names main at 8b414fc. Supervisor to confirm.
- Pushes go to lead/design-seams (authorised in the Belt message).
- Premise to verify before D0-3c: Sources/DesignModel/Live/LiveMarquee.swift already exists, so the packet's note that .live's marquee answers [] until select-several S-1 may be stale.
- No UI slice ("ui_slice": "none"); the Linux walk MJ5 is the done check.

## Open
- No Swift toolchain on PATH, so scripts/ci --changed cannot run here; wave 1 cannot be gated yet.
- Feature status in design-contracts.wave.json is "built"; this feature's own wave file still says "planned".
