# design-window lead record

Issue: #1494 · Packet: docs/blueprints/design/features/design-window.md
Run: act-1a14644dd70-3gpr · Session: unknown · Started: 2026-10-16T19:53Z
Stage: 2 plan (blocked)
Base: origin/dev 98414eb83d8f326ece464f1637a61c30450a1372 (the brief names main 8b414fc; CLAUDE.md says dev is the only integration base, so PRs target dev)
Next: resolve DW-a's wait on shell-parity (D0-5a, D0-5d, D0-6) and confirm which DW-a tasks are already on dev; then start the first unblocked DW-a task

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DW-a | every tier-1 command in menus, inspector and canvas; "<Feature> isn't built yet." on live | D0-5a, D0-5b, D0-5c, D0-5d, D0-6 | J1 | design-contracts (built); shell-parity (D0-5a, D0-5d, D0-6) | true | 0 | blocked | - | wanted at merged-done |
| DW-b | canvas-only redraw on drag; body runs at most 3 times over 120 samples | D0-8a, D0-8b | J3 | DW-a | true | 0 | blocked | - | - |
| DW-d | canvas feedback: pick preview, W×H badge, pointer over handles, Text box | D0-9a..d | testCanvasFeedback | DW-a (D0-9c); DW-b (D0-9d); canvas-basics CB-a (D0-9d) | true | 0 | blocked | - | - |
| DW-c | every enabled control acts, disabled ones say why, layout at every width | D0-7a, D0-7b | J15, testLayoutAtWidths | DW-b (D0-7a); DW-a, DW-d (D0-7b) | true | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| D0-5a..D0-6 | DW-a | 1 | intents, menus, canvas slots, inspector shell | DesignApp/DesignIntent.swift, DesignWindow.swift, DesignCanvas.swift and others per packet | snapshots, J1 | - | DesignIntent.swift and DesignWindow.swift present on dev; per-task merge status not verified |
| D0-8a, D0-8b | DW-b | 2 | drag redraws canvas only | DesignWindowOptions.swift (missing on dev), DesignCanvas.swift | J3, body-count test | - | waiting on DW-a |
| D0-9a..d | DW-d | 2 | canvas feedback | DesignCanvas*.swift, DesignSelectionMarks.swift, DesignFrameLabels.swift | testCanvasFeedback | - | waiting on DW-a, DW-b, CB-a |
| D0-7a, D0-7b | DW-c | 3 | control sweep, layout widths | DesignWindow.swift and inspector files | J15, testLayoutAtWidths | - | waiting on DW-b, DW-a, DW-d |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main (same reason as copy-group).
- Recorded on the designated branch claude/design-line-lead-nq14ye, not lead/design-window (same reason as copy-group).
- All four slices are UI slices (ui: true). The mouse and taste lenses run only after a slice's first clean review, so none run yet.
- DesignWindowOptions.swift is absent on dev, which fits DW-b, D0-8a not having merged.

## Open
- shell-parity is "planned" in its wave.json and DW-a depends on it.
- canvas-basics CB-a and design-seams are "planned"; DW-d and DW-c depend on them.
- No PRs, no reviews, no Belt-Slice-Done lines posted.
