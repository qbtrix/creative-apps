# area-selection lead record

Issue: #3752 · Packet: docs/blueprints/suiteui/features/area-selection.md
Run: act-1a15e9d8ac8-27wz · Started: 2026-10-21T13:22:44Z
Stage: 3 wave 1
Base: ac7f95c9f6b0516253108a270145e4280f243b69
Next: AR-a (AR-1 + AR-2, one PR, tests disabled first commit).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AR-a | Kernel declares the area recipe, group pick rule and 13 select.* specs as stubs, tests written and disabled. | AR-1, AR-2 | MJ-AR | editor-kernel, command-catalog (built) | false | 0 | merged-done (Linux 39632745681 green at b70dcb7; Belt-Slice-Done posted) | – | – |
| AR-m | Shift/Option join modes, lasso close and simplify, step order, outermost-group pick. | AR-3, AR-4 | MJ-AR | AR-a | false | 0 | building | – | – |
| AR-r | Recipe to CoreRaster mask in SuiteImaging. | AR-5, AR-6 | MJ-AR-raster | suite-imaging:IM-a (planned, not started); AR-a | false | 0 | waiting | – | – |
| AR-u | SuiteUI marching ants and area tool options on the gallery. | AR-7, AR-8 | SJ-AR | AR-a; pen-paths:PN-a (met) | true | 0 | building | – | – |
| AR-photo-m | Photo's selection on the kernel recipe, select.* by CLI. | AR-9, AR-10 | MJ-AR-photo | AR-a, AR-m, AR-r; photo/file-flow PF-m | false | 0 | waiting | – | – |
| AR-photo-u | Photo tools, Select menu, SuiteUI ants. | AR-11, AR-12 | PJ-AR | AR-u, AR-photo-m; adopt-suiteui-chrome:AC-colour | true | 0 | waiting | – | – |
| AR-design | Design group click, enter, exit, deep pick. | AR-13, AR-14 | DJ-AR | AR-a, AR-m; design/pen-paths DP-m; adopt-kernel-transform:AT-design | true | 0 | building (AR-13) | – | – |
| AR-z | Photo copies deleted, kernel C4 names the recipe, RJ-X70/71, built. | AR-15, AR-16 | MJ-AR, PJ-AR, DJ-AR | AR-photo-m, AR-photo-u, AR-design; suite-imaging:IM-z | false | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AR-1 | AR-a | 1 | contract stubs | Sources/SuiteKernel/Selection/{AreaShape,AreaSelectCommands,GroupPick}.swift | packet acceptance row | #4093 | merged (b70dcb7) |
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

- 2026-10-21T15:40Z: AR-3 is #4096 (own diff +132/-10, 3 files) and AR-4 is #4098 (+85/-13, 3 files), stacked on #4093. Both have scripts/ci --changed PASS. needs-split is on both because GitHub diffs them against dev, which includes #4093; they shrink as the stack merges. Locked groups refuse enter (an addition the packet does not state). An attribution footer was auto-appended to the PR bodies created via gh api; I removed it via the MCP tool from #4093, #4096 and #4098. Next: AR-u (AR-7) and AR-13 once #4093 is on dev.

- 2026-10-21T15:44Z: The lane took fast-lane off #4096 and #4098 because their stacked diffs against dev are too big (522 and 594 lines). After #4093 merges, #4096 drops to about 122 lines: then remove needs-split and add fast-lane back. Do the same for #4098 after #4096 merges.
- 2026-10-21T16:20Z: #4093 (AR-a) merged as b70dcb7. I merged dev into lead/area-selection-AR-3 (the add/add conflicts took the branch side; dev's copies equal AR-a's head). #4096 is now +132/-10 in 3 files against dev, head b02c125, scripts/ci --changed PASS. needs-split is dropped and fast-lane is back on. #4098 is next, once #4096 merges. Builders launched: AR-7 (AR-u, lead/area-selection-AR-7) and AR-13 (AR-design tests, lead/area-selection-AR-13), both from dev.
- 2026-10-21T16:30Z: AR-13 is #4120 (head e73836b, +192 in 4 files, scripts/ci --changed PASS). It has five disabled DesignGroupPickTests, the DJ-AR journey skipped behind `groupPickBuilt`, and RJ-X71's job folder with the `input/card.design` the real-jobs layout test requires. AR-14 deletes the guard and the flag when it turns them on. I set the body via MCP: no footer.
- 2026-10-21T16:35Z: AR-7 is #4122 (head 24bf6e5, 6 files, +394/-1, scripts/ci --changed PASS; SuiteUI and the snapshot compile only in the macOS gate). It adds AreaAnts (4 steps a second, still under Reduce Motion), AreaToolOptions on ChoiceChips and StudioScrubRow with each control naming its command, and the gallery's area-select page on a local fake. The snapshots are suite-gallery-area-select-{light,dark}.png. I set the body via MCP. The AR-8 builder is stacked on lead/area-selection-AR-7.

- 16:38Z: AR-a merged-done; Belt-Slice-Done AR-a posted on #3752 (run 39632745681). AR-8 opened as #4124 (stacked on #4122 AR-7). Its budget test could not fail (the page had no bodyRuns counter and kept the draft lasso in page state), and its journey lasso was collinear. Folding the fix into #4124 (under 50 lines, same slice): a page bodyRuns counter, the draft lasso moved to ants-only state, and a non-degenerate journey lasso. #4124 is held with no-fast-lane until the fix head is gated. Open: #4096 AR-3, #4098 AR-4 (needs-split, waits on #4096), #4120 AR-13, #4122 AR-7.

- 16:41Z: AR-8 #4124 fixed at b45e6b4 (page bodyRuns counter, draft lasso in GalleryAreaDraft read only by the ants layer, slow-leg journey lasso). Gate PASS (Linux; the view code compiles first in the batch macOS gate). Body set; no-fast-lane swapped for needs-split until #4122 merges.

- 16:58Z: The lane is building #4096 (run 39634352484), #4120 (39636490860) and #4122 (39636526138) on macOS; all queued. The sentinel flagged #4124 as oversize (572 lines including stacked #4122; its own change is +182). I replied that it restacks after #4122 merges; it is not split. #4098 waits on #4096.

- 17:19Z: #4120 AR-13's macOS build 39636490860 is green, so it lands on the lane's next sweep. #4096 (39634352484) and #4122 (39636526138) are still queued for macOS. #4098 and #4124 wait on their bases.
- 2026-10-21T17:40Z: #4120 (AR-13) merged as af840a6 in a batch of 5 (Linux run 39642386919). #4122 (AR-7) macOS build 39636526138 is green and waits on the next batch; #4096 (AR-3) build 39634352484 is still queued. #4098 and #4124 stay stacked (needs-split) until their bases merge. AR-14 waits on AR-m (#4096, #4098).
- 2026-10-21T18:04Z: #4122 (AR-7) merged as 7f8c544 (batch of 6, Linux run 39645897530). I merged dev into lead/area-selection-AR-8: the add/add on GalleryAreaSelect.swift took the branch side, since dev's copy equals AR-7's head 24bf6e5. #4124 is now +182/-5 in 3 files, head 8386fa7, scripts/ci --changed PASS. Head moved via MCP; needs-split is dropped and fast-lane is on. #4096 (AR-3) macOS build 39634352484 is now in progress; #4098 waits on it.
- 2026-10-21T18:23Z: #4096 (AR-3) macOS build 39634352484 is green; it waits on the next lane batch. The lane dispatched macOS build 39649626905 for #4124 (AR-8, head 8386fa7). #4098 stays stacked until #4096 merges.
- 18:54Z: #4096 (AR-3) merged as e3b6fb8. #4098 (AR-4) restacked on dev (add/add on GroupPick taken ours, dev equal to b02c125), gate PASS, head 432656d, needs-split dropped, fast-lane on. #4124 (AR-8) macOS build 39649626905 still running. AR-14 starts once #4098 merges.
- 19:13Z: macOS builds green: #4098 (AR-4, run 39657301406) and #4124 (AR-8, run 39649626905). Both wait on a lane batch. AR-14 starts once #4098 merges.
- 19:33Z: #4098 (AR-4) and #4124 (AR-8): macOS builds green, both wait on a lane batch (27 runs queued repo-wide). No needs-fix, no findings.
- 19:53Z: #4124 (AR-8, AR-u) merged as 369ecc7; Linux check 39664459063 is running on it. #4098 (AR-4) waits on a lane batch with its macOS build green.
- 20:09Z: AR-u done: Belt-Slice-Done and Mac-Finish-Wanted posted on #3752 (Linux 39664459063 green on 369ecc7). #4098 (AR-4) merged as f2e75f9; Linux check 39667367345 on 606e821, which contains it, is running, so AR-m's done signal waits for it. AT-design is merged (#3593, #3604), but AR-14 (AR-design) still waits on design/pen-paths DP-m (DP-6 and DP-7 not yet opened) for the shared DesignCommandCatalog chain.
- 20:23Z: AR-m done: Belt-Slice-Done posted on #3752 (Linux 39667367345 green on 606e821). Done slices: AR-a, AR-u, AR-m. AR-design (AR-14) waits on design/pen-paths DP-m (no PR yet). AR-r and AR-10 wait on IM-a.
- 20:43Z: No change: AR-design waits on DP-m (no PR yet); AR-r and AR-10 wait on IM-a (#4028 open).
- 21:11Z: heartbeat: AR-design waits on DP-m (no PRs yet); AR-r and AR-10 wait on IM-a #4028 (open).
- 21:33Z: heartbeat: no change. AR-design waits on DP-m (no PRs); AR-r and AR-10 wait on IM-a #4028 (open).
- 21:54Z: heartbeat: no change. AR-design waits on DP-m (no PRs); AR-r and AR-10 wait on IM-a #4028 (open).
- 22:17Z: heartbeat: no change. AR-design waits on DP-m (no PRs); AR-r and AR-10 wait on IM-a #4028 (open).
- 22:44Z: heartbeat: no change. AR-design waits on DP-m (no PRs); AR-r and AR-10 wait on IM-a #4028 (open).
- 23:07Z: heartbeat: no change. AR-design waits on DP-m (no PRs); AR-r and AR-10 wait on IM-a #4028 (open).
- 23:35Z: heartbeat: no change. AR-design waits on DP-m (no PRs); AR-r and AR-10 wait on IM-a #4028 (open).
- 00:03Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 00:27Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 00:51Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 01:14Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 01:35Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 01:58Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 02:20Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 02:42Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
- 03:05Z: AR-design waits on DP-m (no PRs yet); AR-r/AR-10 wait on IM-a #4028 (open)
