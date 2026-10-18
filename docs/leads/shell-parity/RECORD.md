# shell-parity lead record

Issue: #1325 · Packet: docs/blueprints/design/features/shell-parity.md
Run: act-1a14d285aef-3epc (before: act-1a149c0c306-8ckd, act-1a1487bf8e3-hwdj; first run act-1a14478b134-5to5) · Session: claude/design-shell-parity-lead-0l668u · Started: 2026-10-16T12:00Z
Stage: done
Base: 0e3c08ea52648f6654e583a64ddf07ccb5aa328c
Next: nothing. Feature done: DP-a done (38956034097), DP-b done with gaps #1452 #1572 #1573 #1617 #1618 #1877 #1878 #1993 #1994 (38971702274), Belt-Contact-Sheet posted on #1325. The gaps close when SuiteUI #1456 lands. This branch was recut onto main on 2026-10-17 (Belt: 290 commits behind).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DP-a | The toolbar's eight commands each act or say why, and Add Page and Delete Page sit in a row under the pages. | DS-1, DS-2 | J3 | editor-in-window APIs (on dev) | no | 2 | done | 38956034097 | – |
| DP-b | Design opens in the suite window with pages and layers in the sidebar, Properties in the inspector and the floating tool box over the canvas, in light and dark. | DS-3, DS-4 | J0, DS-J1..DS-J5 | DP-a (DS-3) | no | 2 | done-with-gaps (#1452 #1572 #1573 #1617 #1618 #1877 #1878 #1993 #1994 #2519 #2520) | 38971702274 | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DS-1 | DP-a | 1 | DesignToolbarItem: eight commands, titles, symbols, identifiers, reasons | Sources/DesignModel/DesignToolbarItems.swift, Tests/DesignModelTests/DesignToolbarItemsTests.swift, Tests/mutations/DesignModel.DesignToolbarItems.json | DesignToolbarItemsTests + Mutate 6/6 | #1335 | merged |
| DS-2 | DP-a | 1 | Page actions under Pages become a SidebarActionRow | Sources/DesignApp/DesignLayersPanel.swift, Tests/AppSnapshotTests/DesignLayersSnapshots.swift, UITests/DesignJourneyTests.swift | core journey asserts design.page.add/delete; DesignLayersSnapshots | #1329 | merged |
| DS-3 | DP-b | 2 | DesignEditor on SuiteWindow + EditorDetail, floating palette; DesignTopBar/DesignPanel tabs go | DesignEditor, DesignPanel, DesignIntent, DesignWindow, DesignApp, DesignJourneyTests, 3 snapshot files | every Design journey on the scoped run | #1391 | merged |
| DS-4 | DP-b | 1 | Shell journey steps 1-5 with geometry, merged skipped ("waits on DS-3") | UITests/DesignJourneyTests+Shell.swift | DesignJourneyTests+Shell on the scoped run, once DS-3 enables it | #1330 | merged |
| DS-5 | DP-b | 3 | feature-done: wave.json status built + feature issue | docs/blueprints/design/features/shell-parity.wave.json | scripts/ci renders waves | #1610 | merged (c97f2782) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| DP-a | 38906785154 | b2e5453c | clarity, journey, design, layout, controls, oracle | #1385 (major), #1386, #1387 | 0 |
| DP-b | 38917492060 (CI lens: failed journeys) | fb72b7e5 | journey (CI) | #1443 (blocker), #1444 | 0 |
| DP-a, DP-b | 38931490731 (CI: failed journeys) | 82b239c9 | journey, layout (CI) | #1451 (DP-a), #1452 (DP-b) | 1 |
| DP-b | 38991865764 (CI findings) | 6c4ad16a | journey (CI) | #1877, #1878 (same geometry as #1456) | 2 (cap reached: relabelled gap) |

## Decisions
- 2026-10-18T04:00Z (run act-1a14d285aef-3epc): Belt asked again for this branch to be rebased onto main (126 behind). It carried 1134 old dev commits, so it was recut from main 0965457c with docs/leads/shell-parity and photo-shell-parity carried over, and pushed with --force-with-lease. Findings #2519/#2520 (window 2pt over the visible frame, SuiteUI #2524) relabelled `gap`: DP-b is past its 2 rounds. This lead also runs canvas-basics (#1500) and files-history (#1499) as line lead (rule 19).
- 2026-10-17T13:30Z: CI findings #1993/#1994 (DesignShellJourneyTests light/dark at 93c2103, run 39033633296) repeat #1877/#1878 (SuiteUI #1456). DP-b is past its 2 rounds, so both relabelled `gap` and added to the gap list. No new Design PR.
- 2026-10-17 relaunch: CI findings #1877 and #1878 (DesignShellJourneyTests light/dark, `suite.inspector` 280 under 304 and the column overlaps) repeat #1572/#1573 at a newer commit. DP-b has used its 2 fix rounds and the cause is SuiteUI's #1456, so both are relabelled `gap` under rule 11 and added to DP-b's gap list. No new Design PR.
- Belt asked for lead/shell-parity to be rebased onto main: the branch was recut from main 0e3c08e with the docs/leads records carried over (shell-parity, and photo-shell-parity which an earlier lead kept on this branch); docs/leads/switching keeps main's copy.
- DP-a done on run 38956034097 (successful under the 18:13 policy: journeys report findings, don't fail the run). CI filed #1572/#1573 for DP-b's shell journeys; both relabelled gap (round cap) with #1452. DP-b closes with gaps on the run that contains DS-5 #1610, per the supervisor's "macOS journeys never hold you". #1337 (switcher) merged on dev at 72c5aeab.
- Supervisor note 18:13: CI now blocks only on compile and Model tests; journeys report findings and never hold a slice. Our slices carry no "ui": true, so rules 15/17 (feel gate, Mac finisher) don't apply.
- Wave 1: DS-1 and DS-2 independent (disjoint files). Wave 2: DS-3 waits on DS-1 and DS-2. DS-4 moved to wave 1 under contract rule 13 (acceptance journey before code), merged with `throw XCTSkip("waits on DS-3")`; DS-3 removed the skips. The feature-done label moved to a small DS-5 (wave.json status) after DS-3.
- DP-a's wait on editor-in-window (#1079): every API this feature uses was on dev at the base, so the wait was met for code.
- PRs target dev (CLAUDE.md; the lane retargets main to dev). Builder branches were sp/<task>.
- Fixers were briefed directly (Agent per finding), not via fix-batch.js (branch-name collision with lead/shell-parity).

## Open
- gap #1452, #1572, #1573, #1617, #1618, #1877, #1878 (DP-b): all SuiteUI's needs-ui #1456 (EditorDetail regions bleed under the floating sidebar/inspector, suite.inspector lands inside SuiteWindow's padding at 280 vs 304). DP-b's geometry assertions stay until it lands; the next green shell journey closes them through CI's findings job.
- gap #1561 (from the editor-in-window lead): fixed by #1655 (e16a3edd).
- #1079 editor-in-window still open (needs-human); not blocking code.
- 2026-10-17T14:04Z heartbeat: dev 25b220e4; no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked. CI findings #2074 #2075 #2083-#2087 (scoped design run 39037761414 at d2c4fa21) all fail at launch: 'Application org.creativesuite.design does not have a process ID'. App-launch infra (bundle packaging, cf #2099 line:suite, after #2073), not in this feature's files and carry no Feature: line; not counted as this feature's findings, not fixed here.
- 2026-10-17T14:20Z heartbeat: dev 8c05d002 (Flare merges only); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39036875578 macOS still running; no new line:design findings.
- 2026-10-17T14:36Z heartbeat: dev 8c05d002 unchanged; no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39036875578 macOS still running; no new line:design findings.
- 2026-10-17T14:52Z heartbeat: dev 2c5003b5 (Flare/Halo merges only); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39036875578 macOS still running; no new line:design findings.
- 2026-10-17T15:09Z heartbeat: dev 6dcb79e5 (#2131 bundle fix, should clear the launch-failure CI findings); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39036875578 cancelled (its Linux job was already green on d2c4fa21, so ST-7 stays merged-done); no new line:design findings.
- 2026-10-17T15:26Z heartbeat: dev f50448c4 (no Design merges); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39043153763 on 2c5003b5 in progress; no new line:design findings.
- 2026-10-17T15:43Z heartbeat: dev dd7ec767 (merges since f50448c4 are flare inspector-timeline and halo text-layers only); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39043153763 Linux green, macOS running; no new line:design findings.
- 2026-10-17T16:00Z heartbeat: dev d6187654 (merges since dd7ec767: flare inspector-timeline, halo render-out only); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39043153763 Linux green, macOS running; no new line:design findings.
- 2026-10-17T16:18Z check: dev 0b50c70f (merges since d6187654: flare inspector-timeline, halo render-out only). DW-a PRs opened by design-window lead act-1a14a88d756-rnok: #2168 (window launch options, intents, status selection count) and #2163 (canvas marquee mark, selection marks, overlay slots); both fast-lane, clean, not merged yet, so DW-a is not merged-done. Tasks gated on DW-a stay queued until it merges. Nothing on EK-tree or LL-9. Full CI 39043153763: Linux green, macOS running. No new line:design findings.
- 2026-10-17T16:32Z check: dev 4cc9e6f4 (merges since 0b50c70f: flare inspector-timeline only). DW-a PRs #2168 and #2163 still open, waiting on their fast-lane macOS build runs (dispatched 16:19 and 16:10). DW-a gated tasks stay queued. Nothing on EK-tree or LL-9. Full CI 39043153763 macOS still running; 39047162437 cancelled. No new line:design findings.
- 2026-10-17T16:46Z check: dev 1a4e5e89 (merges since 4cc9e6f4: flare inspector-timeline only). DW-a PRs #2168 and #2163 still open on their fast-lane macOS builds. DW-a has 5 tasks (D0-5a..D0-5d, D0-6), so these two alone do not finish it; DW-a-gated tasks wait for the whole slice on dev. Nothing on EK-tree or LL-9. Full CI 39043153763 was cancelled (Linux green on 2c5003b5); dev CI 39049627028 on 4cc9e6f4 running. No new line:design findings.
- 2026-10-17T17:07Z check: dev dd568918; DW-a 3/5 tasks merged, #2168 #2163 open; no EK-tree/LL-9 PR; no new findings; dev red #2191 (Linux): DesignStyleBudgetTests/scrubStep 5.119ms vs 5ms gate, a style-rows ST-7 timing test under load, perf-suites listing asked of supervisor
- 2026-10-17T17:25Z check: dev ec0e979b; DW-a: #2168 and #2163 merged, still missing inspector/pasteboard/edit-menu files (DesignSeveralInspectorSnapshots, DesignPasteboardBridge, DesignClosePrompt, DesignEditMenu, DesignInspectorText/Page), no open DW-a PR, so DW-a-gated tasks wait (17:07 record's '3/5 merged' was wrong: 0 of 5 were in then); no EK-tree/LL-9 PR; no new findings; dev-red #2191 open, no supervisor reply; scoped flare/halo green, full CI on 4cc9e6f4 still running
- 2026-10-17T17:41Z check: dev c3dbf73c (9 non-Design merges since ec0e979b); DW-a still misses inspector/pasteboard/close-prompt/edit-menu files, no open DW-a PR, so DW-a-gated tasks wait; no EK-tree/LL-9 PR; no new findings; dev-red #2191 open, no supervisor reply; full CI 39049627028 still running, 39050873494 cancelled
- 2026-10-17T17:57Z check: dev 57486e5e (2 Flare merges); DW-a remainder now in open PRs #2217 (several inspector), #2214 (pasteboard, close prompt), #2213 (menu items), not merged, so DW-a-gated tasks still wait; no EK-tree/LL-9 PR; no new findings; dev-red #2191: lane bisect names #2150 (Flare) as first red commit, our timing-miss note stands, no supervisor reply; CI 39055838504/39055200176 queued
- 2026-10-17T18:14Z check: dev e17b68f9 (1 Halo merge); DW-a remainder PRs #2217 #2214 #2213 still open (fast-lane), DW-a-gated tasks wait; no EK-tree/LL-9 PR; no new findings; dev-red #2191 closed: green at b04e50c7 (run 39055200176), main promoted; DesignStyleBudgetTests not yet in perf-suites (supervisor's call), may flake again
- 2026-10-17T18:31Z check: dev@13911964; DW-a #2217 and #2214 merged, only #2213 (DesignEditMenu) still open; no EK-tree/LL-9 PRs; no dev-red; no new line:design findings; SR-a/L-4/L-5 still wait on DW-a; next check ~18:50
- 2026-10-17T19:03Z check: dev@b2942150: done; no new findings on its slices.
- 2026-10-17T19:21Z check: dev@19206653: done; nothing new.
- 2026-10-17T19:38Z check: dev@0c8e4a71: done; nothing new.
- 2026-10-17T19:56Z check: dev@8f0fa099: done. New shell-geometry findings #2283 (testShellDark) and #2075 (testShellLight), on 6ad373ab (#2258, SuiteUI); not reopening the feature.
- 2026-10-17T20:19Z check: dev@8f0fa099: done.
- 2026-10-17T20:36Z check: dev@df60ad73: done.
- 2026-10-17T20:52Z check: dev@056214c4: done. #2352 testShellDark (shell geometry) is another CI finding; not reopening.
- 2026-10-17T21:13Z check: dev 32c676c1. Done; shell-geometry findings #2352/#2075 stay with SuiteUI #2258; #2302 waits on SuiteUI #2263 (open).
- 2026-10-17T21:33Z check: dev c2a70dd8. Done; #2352/#2075 stay with SuiteUI #2258; #2302 waits on SuiteUI #2263 (open).
- 2026-10-17T21:53Z check: dev bc252a71. Done; #2352/#2075 stay with SuiteUI #2258; #2302 waits on SuiteUI #2263 (open).
- 2026-10-17T22:11:21Z check: check: done; #2352 #2075 wait on SuiteUI #2258, #2302 on #2263 (open); new dev findings #2406 #2410 #2411 are not shell-parity's
- 2026-10-17T22:28:25Z check: check: done; #2302 waits on #2263 (open); new findings #2438-#2443 are select-several's
- 2026-10-17T22:45:28Z check: check: done; #2302 waits on #2263; no new shell findings
- 2026-10-17T23:03:16Z check: check: done; #2302 waits on #2263; no new shell findings
- 2026-10-17T23:21:18Z check: scoped 39077269207 at 59c435a6: testShellDark (#2352) now also hits a new unnamed 11x204 button at x=998 in the inspector, from #2349 (no lead); testShellLight (#2075) undo; #2263 open. Left to red-triage/owner.
- 2026-10-17T23:37:49Z check: #2352/#2075 still open (unnamed inspector button from #2349, undo); #2263 open. No action from this lead.
- 2026-10-17T23:53:56Z check: #2075 testShellLight not in the open findings now; DS-J4 #2464 on dev. #2352 open (unnamed button), #2263 open.
- 2026-10-18T00:10:50Z check: #2468 (81f6e0af) removed the inspector's legacy scroller, the unnamed button that failed testShellDark #2352; the next scoped design run verifies it. #2263 open.
- 2026-10-18T00:27:55Z check: new findings #2508 testShellDark and #2482 testShellLight (red-triage, a6150139); #2352 closed by #2468. Owners outside this lead; #2263 open.
- 2026-10-18T00:44:25Z check: new findings #2506 testAlignALayer and #2507 testEditDelete: an unnamed button at x 986, seen at a6150139, before #2468 (81f6e0af), which removed that scroller. Verify on scoped run 39083023668 (d3cd7d9f, contains #2468). #2508/#2482 are open; #2263 is open.
- 2026-10-18T01:00:58Z check: scoped run 39083023668 passes testShellLight/testShellDark/testAlignALayer/testEditDelete; findings #2482/#2506/#2507/#2508 closed (the bot's 'passes on run'). Nothing open for shell-parity except SuiteUI #2263.
- 2026-10-18T01:18:15Z check: no change; only SuiteUI #2263 open.
- 2026-10-18T01:35:29Z check: no change; only SuiteUI #2263 open.
- 2026-10-18T01:53:19Z check: no change; only SuiteUI #2263 open
- 2026-10-18T02:11:32Z check: findings #2519/#2520 (shell geometry, full run 39082226458): window 2pt over a 677pt visible frame, SuiteUI sizer; filed #2524 needs-ui; passes on scoped run 39083023668
- 2026-10-18T02:31:59Z check: dev 948bcbf4 green (#2509 closed, quarantine renewed by #2523). #2519/#2520 wait on SuiteUI #2524; #2263 open.
- 2026-10-18T02:49:16Z check: no change: #2519/#2520 wait on SuiteUI #2524; #2263 open.
- 2026-10-18T03:06:26Z check: no change: #2519/#2520 wait on SuiteUI #2524; #2263 open.
- 2026-10-18T03:23:06Z check: no change: #2519/#2520 wait on SuiteUI #2524; #2263 open.
- 2026-10-18T03:41:01Z check: no change; #2263 open, #2519/#2520 wait on SuiteUI #2524
- 2026-10-18T04:04:13Z check: no change; #2263, #2519/#2520 open, wait on SuiteUI #2524
- 2026-10-18T04:22:08Z check: waiting on SuiteUI #2524 (findings #2519 #2520) and #2263; all open
- 2026-10-18T04:39:19Z check: waiting on SuiteUI #2524 (findings #2519 #2520) and #2263; all open
- 2026-10-18T04:56:52Z check: waiting on SuiteUI #2524 (findings #2519 #2520) and #2263; all open
- 2026-10-18T05:14:25Z check: waiting on SuiteUI #2524 (findings #2519 #2520) and #2263; all open
- 2026-10-18T05:30:36Z check: waiting on SuiteUI #2524 (findings #2519 #2520) and #2263; all open
- 2026-10-18T05:47:29Z check: blocked: #2524 (#2519/#2520) and #2263 open; no dev-red; 12 open design findings
- 2026-10-18T06:04:22Z check: blocked: #2524 (#2519/#2520) and #2263 open; no dev-red; 12 open design findings
- 2026-10-18T06:21:32Z check: blocked: #2524 (#2519/#2520) and #2263 open; no dev-red; 12 open design findings
- 2026-10-18T06:39:04Z check: blocked: #2524 (#2519/#2520) and #2263 open; dev-red #2667 open (Linux: LibraryLoupeBudgetTests focusChangeWithinBudget, not ours; not fixing); 13 open design findings, new #2657-#2661 from macOS run 39098181461; #2660 P2 now a contrast hit with no Design/SuiteUI change between scoped-green d3a4f16e7 and e01529f43
- 2026-10-18T06:56:57Z check: blocked: #2524 #2519 #2520 #2263 open; dev-red #2667 not ours; 13 design findings open
- 2026-10-18T07:14:08Z check: blocked: #2524 #2519 #2520 #2263 open; dev-red #2667 not ours; 13 design findings open
- 2026-10-18T07:31:04Z check: blocked: #2524 #2519 #2520 #2263 open; dev-red #2667 not ours; 12 design findings open
- 2026-10-18T07:48:54Z check: findings #2519/#2520 closed as dups of gaps #1572/#1573 (open); still blocked on SuiteUI #2524 and #2263; dev-red #2667 not ours; 10 design findings open
- 2026-10-18T08:06:04Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); dev-red #2667 not ours; 10 design findings open
- 2026-10-18T08:23:32Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); dev-red #2667 not ours; 9 design findings open
- 2026-10-18T08:40:21Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); dev-red #2667 not ours; 9 design findings open
- 2026-10-18T08:56:41Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); dev-red #2667 not ours; 9 design findings open
- 2026-10-18T09:12:39Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); dev-red #2667 closed, dev green; 9 design findings open
- 2026-10-18T09:28:46Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 9 design findings open
- 2026-10-18T09:44:58Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 9 design findings open
- 2026-10-18T10:02:14Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 9 design findings open
- 2026-10-18T10:19:08Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 9 design findings open
- 2026-10-18T10:36:07Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 7 design findings open
- 2026-10-18T10:53:49Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 7 design findings open
- 2026-10-18T11:12:08Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 7 design findings open
- 2026-10-18T11:28:36Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 9 design findings open
- 2026-10-18T11:45:11Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 9 design findings open
- 2026-10-18T12:02:36Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 9 design findings open
- 2026-10-18T12:19:07Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 8 design findings open
- 2026-10-18T12:36:17Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 8 design findings open
- 2026-10-18T12:52:52Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 8 design findings open
- 2026-10-18T13:10:27Z check: blocked: #2524 #2263 open (gaps #1572/#1573 open); no dev-red; 8 design findings open
