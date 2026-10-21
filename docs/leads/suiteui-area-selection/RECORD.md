# area-selection lead record

Issue: #3752 · Packet: docs/blueprints/suiteui/features/area-selection.md
Run: act-1a15e9d8ac8-27wz · Started: 2026-10-21T13:22:44Z
Stage: 3 wave 1
Base: ac7f95c9f6b0516253108a270145e4280f243b69
Next: AR-a (AR-1 + AR-2, one PR, tests disabled first commit).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AR-a | Kernel declares the area recipe, group pick rule and 13 select.* specs as stubs, tests written and disabled. | AR-1, AR-2 | MJ-AR | editor-kernel, command-catalog (built) | false | 0 | building | – | – |
| AR-m | Shift/Option join modes, lasso close and simplify, step order, outermost-group pick. | AR-3, AR-4 | MJ-AR | AR-a | false | 0 | building | – | – |
| AR-r | Recipe to CoreRaster mask in SuiteImaging. | AR-5, AR-6 | MJ-AR-raster | suite-imaging:IM-a (planned, not started); AR-a | false | 0 | waiting | – | – |
| AR-u | SuiteUI marching ants and area tool options on the gallery. | AR-7, AR-8 | SJ-AR | AR-a; pen-paths:PN-a (planned, not started) | true | 0 | waiting | – | – |
| AR-photo-m | Photo's selection on the kernel recipe, select.* by CLI. | AR-9, AR-10 | MJ-AR-photo | AR-a, AR-m, AR-r; photo/file-flow PF-m | false | 0 | waiting | – | – |
| AR-photo-u | Photo tools, Select menu, SuiteUI ants. | AR-11, AR-12 | PJ-AR | AR-u, AR-photo-m; adopt-suiteui-chrome:AC-colour | true | 0 | waiting | – | – |
| AR-design | Design group click, enter, exit, deep pick. | AR-13, AR-14 | DJ-AR | AR-a, AR-m; design/pen-paths DP-m; adopt-kernel-transform:AT-design | true | 0 | waiting | – | – |
| AR-z | Photo copies deleted, kernel C4 names the recipe, RJ-X70/71, built. | AR-15, AR-16 | MJ-AR, PJ-AR, DJ-AR | AR-photo-m, AR-photo-u, AR-design; suite-imaging:IM-z | false | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AR-1 | AR-a | 1 | contract stubs | Sources/SuiteKernel/Selection/{AreaShape,AreaSelectCommands,GroupPick}.swift | packet acceptance row | #4093 | open (head 772d765) |
| AR-2 | AR-a | 1 | disabled tests | Tests/SuiteKernelTests/{AreaShape,GroupPick}Tests.swift | packet acceptance row | #4093 | open (head 772d765) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target is `dev` (CLAUDE.md, lead.md): main 0dd23d6 is an ancestor of dev and the packet exists only on dev. The status branch is cut from main per the brief.
- v3 loop (packet has `## Slices`); fix rounds capped at 2 per slice.
- AR-1 and AR-2 ship as one PR (slice AR-a, ~380 lines, 5 files), tests first.

## Open
- AR-r waits on suite-imaging:IM-a; AR-u on pen-paths:PN-a. Neither slice has started on dev (2026-10-21T13:22:44Z).
- 2026-10-21T13:23:56Z: pen-paths PN-a's tasks are on dev (PN-1 #3643, PN-2 #3553), so AR-u's PN-a wait is met; AR-7 starts once AR-a merges. suite-imaging IM-a has no merged task and dev has no SuiteImaging target, so AR-r (and AR-photo-m's AR-10) stays blocked.
- Plan: wave 2 stacks AR-m (AR-3 + AR-4, ~370 lines) on lead/area-selection-AR-a; AR-u (AR-7), AR-9 and AR-13 follow once AR-a is on dev.

- 2026-10-21T15:00Z: The lead dir moved to docs/leads/suiteui-area-selection on lead/suiteui-area-selection. The worker restarted, and the AR-a builder had pushed 2 commits to lead/area-selection-AR-a but opened no PR, so I relaunched it to gate, push and open the PR. AR-m stacks on it next. PN-a is merged, so AR-u (AR-7) and AR-13 follow AR-a. AR-r waits on IM-a.

- 2026-10-21T15:10Z: AR-a is PR #4093 (head 772d765, 400 lines and 5 files, scripts/ci --changed PASS). The AreaCombine EditModifiers mapping landed in it rather than in AR-3. The target protocols are Sendable value types with a mutating setter, following PlaceCommands. GroupPickTarget is added. AR-m builder launched: AR-3 then AR-4 as two stacked PRs on lead/area-selection-AR-a, with mutation plans SuiteKernel.AreaShape and SuiteKernel.GroupPick.
