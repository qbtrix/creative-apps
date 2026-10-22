# adopt-suiteui-chrome lead record

Issue: #1942 · Packet: docs/blueprints/suiteui/features/adopt-suiteui-chrome.md
Run: act-1a160ca3d68-sbnc (#1942 only; slices AC-tools, AC-export-sheet; earlier runs act-1a15ef870d6-3mm5, act-1a15ce4fb40-9k5r) · Session: claude/adopt-suiteui-chrome-fhl6sx · Resumed: 2026-10-21
Stage: 3 build (AC-tools p2 #4002 in lane; AC-export-sheet blocked on shared-codecs:SC-f)
Base: dev be9aa35b
Next: #4002 (head cbada801) merges via the lane, then a green ci.yml run (app=suiteui or full) containing it gives AC-tools Belt-Slice-Done + Mac-Finish-Wanted; re-read shared-codecs:SC-f (SC-14 #4238 open; SC-15, SC-16 not yet opened) and start AC-e1 once SC-16 merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AC-zoom | every app clamps through ZoomMath, fits through one fit, maps through CanvasLayout | AC-z1, AC-z2 | MJ-AC-zoom | editor-kernel:EK-a, adopt-kernel-brush:AB-photo | yes | 0 | done | – | – |
| AC-colour | parse, format and pick colour through HexColor and ColorWell | AC-c1, AC-c2 | MJ-AC-colour | editor-kernel:EK-a, adopt-kernel-brush:AB-photo, AC-zoom | yes | 1 | done (per Belt brief act-1a15ef870d6-3mm5) | 39604117821 | wanted |
| AC-tools | tool letters and modifiers through ToolKeys | AC-t1, AC-t2 | MJ-AC-tools | editor-kernel:EK-chrome, AC-colour | yes | 0 | building: p1 #3952 merged, p2 #4002 (head cbada801) in lane | – | – |
| AC-guides | Flare's guides draw through CanvasMarks (GuideLineMark) | AC-g1, AC-g2 | MJ-AC-guides | editor-kernel:EK-a | yes | 0 | done | – | – |
| AC-export-sheet | Photo, Library and Flare export sheets are SuiteUI's ExportSheet | AC-e1, AC-e2 | MJ-AC-export-sheet | editor-kernel:EK-chrome, adopt-kernel-export:AX-photo, AX-library, AX-flare (met), shared-codecs:SC-f (open) | yes | 0 | blocked-SC-f | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AC-z1 | AC-zoom | – | zoom adapter | per packet | DesignWindowZoomTests, PhotoWindowZoomTests, HaloKeyByDragTests, ViewerDraggingContractTests | – | parked |
| AC-z2 | AC-zoom | – | zoom delete | per packet | same + mutate --validate | – | parked |
| AC-c1 | AC-colour | – | colour adapter | per packet | HexColorParserTests, DesignStyleTests, DesignInspectorSnapshots | – | parked |
| AC-c2 | AC-colour | – | colour delete | per packet | same + mutate --validate | – | parked |
| AC-t1 | AC-tools | – | tools adapter | per packet | FlareToolsKeyTests, DesignToolsKeyTests, PhotoToolsKeyTests | #3952, #4002 | #3952 merged; #4002 in lane |
| AC-t2 | AC-tools | – | tools delete | per packet | same + mutate --validate | #4002 | in lane |
| AC-g1 | AC-guides | – | guides adapter | per packet | FlareStageGuideSnapshots, GuideLineMarkTests | – | parked |
| AC-g2 | AC-guides | – | guides delete | per packet | same + mutate --validate | – | parked |
| AC-e1 | AC-export-sheet | – | export sheet adapter | per packet | PhotoExportSheetSnapshots, LibraryExportSnapshots, FlareExportSnapshots | – | parked |
| AC-e2 | AC-export-sheet | – | export sheet delete; `feature-done` | per packet | same + mutate --validate | – | parked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22T06:36Z: Run finished; awaiting release. Hand-off comment posted on #1942 (issuecomment-6333984264) asking the supervisor to release the run. Re-checked: no supervisor reply yet; SC-15/SC-16 still have no PRs, so AC-export-sheet stays unstarted for the next lead. Nothing further for this run to build.
- 2026-10-22T05:34Z: AC-tools DONE. Scoped suiteui 39719142992 (e02f36c, contains 74b34fc) succeeded; posted Belt-Slice-Done: AC-tools (issuecomment-6333563012) and Mac-Finish-Wanted: AC-tools (issuecomment-6333563320) on #1942, no gaps. Run ends here: SC-15 and SC-16 still have no PRs, so per the supervisor (issuecomment-6329700665) AC-export-sheet is left UNSTARTED for the next lead. No Belt-Contact-Sheet (not all slices done).
- 2026-10-22T05:02Z: AC-tools proof: scoped suiteui 39719142992 (e02f36c, contains 74b34fc) now in progress on macOS; full CI 39725694977 (b2794c2) queued as a fallback. AC-export-sheet stays unstarted (SC-15/SC-16 have no PRs).
- 2026-10-22T04:30Z: AC-tools still waits on its proof. Full CI 39714642994 on 66a8458 was cancelled. Scoped suiteui 39719142992 on e02f36c (contains 74b34fc) is still queued for a macOS runner. No other completed scoped-suiteui or full run contains 74b34fc. AC-export-sheet stays unstarted (SC-15/SC-16 have no PRs).
- 2026-10-22T04:00Z: AC-tools waits on its proof. The scoped suiteui run 39709885898 is green, but its head e993311 predates 74b34fc. Two runs that contain 74b34fc are pending: full CI 39714642994 on 66a8458 and scoped suiteui 39719142992 on e02f36c. SC-15/SC-16 still have no PRs, so AC-export-sheet stays unstarted for the next lead (supervisor, issuecomment-6329700665). Next poll in ~30 min.
- 2026-10-22T03:30Z: no completed scoped-suiteui or full ci.yml run on dev contains 74b34fc yet (latest completed scoped runs are on 6a06063/6ccc77a; scoped runs take 1.5-2 h in the macOS queue). Still waiting to post Belt-Slice-Done for AC-tools.
- 2026-10-22T03:03Z: #4002 merged to dev as 74b34fc (AC-tools' last PR). Waiting for a completed, successful ci.yml run on dev (scoped suiteui or full) containing 74b34fc; none yet (scoped runs on older heads still queued for macOS). Then Belt-Slice-Done and Mac-Finish-Wanted for AC-tools. SC-15/SC-16 have no PRs: AC-export-sheet stays unstarted per the supervisor, for the next lead.
- 2026-10-22T02:39Z: #4002 still open, no new lane comment; dev unchanged since b5a6e7e (02:10Z). SC-15/SC-16 still have no PRs; AC-export-sheet stays unstarted.
- 2026-10-22T02:14Z: #4002 still open and clean (macOS build 39704298251 green), waiting for a lane sweep; no needs-fix or needs-rebase. SC-14 #4238 merged to dev (6603b0f). SC-15 and SC-16 have no PRs, so AC-export-sheet stays unstarted per the supervisor.
- 2026-10-22T01:46Z: #4002's lane macOS build run 39704298251 succeeded (01:24Z). Open and clean, waiting for a lane sweep to merge it. SC-f unchanged; AC-export-sheet stays unstarted per the supervisor.
- 2026-10-22T01:24Z: #4002 head 0c0e686b: lane macOS build run 39704298251 passed `swift build` (journey bundles still running). Supervisor answered (#1942 issuecomment-6329700665): don't hold the run; finish AC-tools; if SC-15 and SC-16 haven't merged by then, leave AC-export-sheet unstarted and say so here for the next lead. SC-f today: SC-14 #4238 open (on the local Mac gate), SC-15/SC-16 no PRs. AC-export-sheet is unstarted.
- 2026-10-22T01:01Z: #4002's lane macOS build (run 39695603914) failed only in RenderBudgetPhotoPlaceTests.swift:35, a dev test fixed by #4215. Merged origin/dev 6ccc77ad, scripts/ci --changed PASS, pushed head 0c0e686b, moved the Head line. Waiting on the lane's rebuild. AC-export-sheet still blocked on SC-f (SC-14 #4238 open, SC-15/16 no PRs).
- 2026-10-22T00:31Z: poll: #4002 lane macOS build 39695603914 in progress (started 00:25Z) on cbada801, not merged, no needs-fix. SC-f unchanged (#4238 open, SC-15/16 not opened): blocked poll 3 of 3, so asked the supervisor on #1942 to hold or release AC-export-sheet
- 2026-10-22T00:04Z: poll: #4002 lane macOS build 39695603914 queued on cbada801 (apps design,photo), not merged, no needs-fix. SC-f unchanged: #4238 (SC-14) open, SC-15/16 not opened; blocked poll 2 of 3 on AC-export-sheet
- 2026-10-22T00:00Z: run act-1a160ca3d68-sbnc resumed from this record (Belt: status lives on this branch). AC-tools corrected from "done" to building: #4002 (AC-t1 Design/Photo + AC-t2 deletes) never merged. Merged origin/dev be9aa35b into #4002 (brings #4250's fix for dev's #3856 baseline), scripts/ci --changed PASS, pushed cbada801, Head line moved; mergeable clean, fast-lane. SC-f re-read: #4238 (SC-14) open and clean, SC-15/16 not opened; AC-e1 still waits
- 2026-10-21T22:51Z: SC-14 opened as #4238 (open); SC-15, SC-16 not yet opened; no supervisor reply; AC-e1 still waits
- 2026-10-21T22:20Z: #4019 (SC-13) merged into dev 22:09Z (lane note: dev red on its own, run 39682547538); no SC-14..16 PR yet; no supervisor reply; AC-e1 still waits
- 2026-10-21T21:49Z: #4019 (SC-13) still open, unchanged since 19:48Z (macOS build green); no SC-14..16 PR; no supervisor reply; AC-e1 still waits
- 2026-10-21T21:18Z: #4019 (SC-13) still open on 4e6f468b (macOS build green, Fast-Check pass, no red check) while the lane merged #3770, #4073, #4167; lane run 39677404511 in progress; no SC-14..16 PR; no supervisor reply; AC-e1 still waits
- 2026-10-21T20:47Z: #4019 (SC-13) macOS build 39664805180 green on 4e6f468b, mergeable clean, waiting for a lane sweep to merge; no SC-14..16 PR; no supervisor reply; AC-e1 still waits
- 2026-10-21T20:16Z: #4019 (SC-13) macOS build dispatched by the lane at 19:48Z on 4e6f468b, not merged yet; no SC-14..16 PR; AC-e1 still waits
- 2026-10-21T19:45Z: #4019 (SC-13) pushed 4e6f468b at 19:36Z with Fast-Check pass for that head, clean, fast-lane; lane's macOS build and merge to follow. SC-14..16 still to come, so AC-e1 still waits
- 2026-10-21T19:14Z: SC-f unchanged on dev ef3edb2b: #4019 Linux red on 85c365cf since 12:30Z, no push; no SC-14..16 PR; no supervisor reply on #1942
- 2026-10-21T18:43Z: SC-f unchanged on dev 363d3ea9: #4019 Linux red on 85c365cf since 12:30Z, no push; no SC-14..16 PR; no supervisor reply on #1942 yet
- 2026-10-21T18:10Z: SC-f unchanged on dev 15f7bad1: #4019 Linux red on 85c365cf since 12:30Z, no push; no SC-14..16 PR. Escalated on #1942 for the supervisor
- 2026-10-21T17:38Z: SC-f unchanged on dev af840a6d: #4019 still Linux red on 85c365cf, no push since 12:30Z; no SC-14..16 PR. Supervisor hold/release call still open
- 2026-10-21T17:07Z: SC-f unchanged on dev 0f44e804: #4019 still Linux red on 85c365cf, no push since 12:30Z; no SC-14..16 PR. Still waiting on the supervisor's hold/release call
- 2026-10-21T16:36Z: SC-f unchanged on dev b70dcb71. #4019 (SC-13) sits because its Linux check is red on 85c365cf (lane: waiting, CI is red, since 12:30Z); shared-codecs lead owns it, not fixed here. Asked the supervisor to hold or release this run
- 2026-10-21T16:04Z: re-read SC-f on dev b70dcb71: unchanged (SC-13 #4019 open+clean, no SC-14..16 PR); AC-e1 still waits
- 2026-10-21T15:32Z: run act-1a15ef870d6-3mm5 does AC-export-sheet only (brief: AC-zoom, AC-colour, AC-tools, AC-guides done). Waits re-read: EK-chrome met (Sources/SuiteUI/ExportSheet.swift on dev); AX-photo, AX-library, AX-flare done. shared-codecs:SC-f not met: SC-13 #4019 open, SC-14 stacked, SC-15 (PhotoWindow+Export.swift) and SC-16 (Library ExportFormat) planned. Real wait on the files AC-e1 adapts; nothing else in the brief can start. Blocked note on #1942 (issuecomment-6319193997). Slice PRs go to dev (CLAUDE.md; the lane retargets main).
- 2026-10-21T13:39Z: AC-colour fix round 1 PR #4089 head c6707931 (tests + 4 mutation plans, App targets unscored on Linux)
- 2026-10-21T13:31Z: AC-colour review (code-only, lenses design/first-use/mouse/taste/job/correctness) on 45c81070: 1 finding #4086 (bridges untested); fixer launched, round 1
- 2026-10-21T13:30Z: AC-colour Belt-Slice-Done + Mac-Finish-Wanted on Linux check 39604117821 (5bec8089); critic panel started
- 2026-10-21T13:08Z: #4002 Linux red is dev's #3976 failure only; no fix in our PR
- 2026-10-21T12:43Z: -
- 2026-10-21T12:23Z: -
- 2026-10-21T11:59Z: -
- 2026-10-21T11:38Z: -
- 2026-10-21T11:15Z: -
- 2026-10-21T10:50Z: -
- 2026-10-21T10:35Z: AC-tools p2 PR #4002 head d2037179 (stacked on #3952); mutate unscored on Linux, macOS gate scores
- 2026-10-21T10:27Z: AC-colour #3943 merged 45c81070; AC-tools p2 builder launched on slice/ac-tools-2
- 2026-10-21T10:06Z: -
- 2026-10-21T09:45Z: #3943 #3952 clean, waiting for batch; dev Linux red on a6f45c18 (#3856)
- 2026-10-21T09:25Z: Linux check 39571804700 green contains AC-zoom f886c912
- 2026-10-21T09:04Z: wait, never block on CI
- 2026-10-21T08:56Z: stopped #3952 at dev 896cafe3: dev 296186f4 fails mutate --validate (DesignCanvasEditing plan, #3889); reported on #3856
- 2026-10-21T08:43Z: fixer merges origin/dev, no rebase
- 2026-10-21T08:21Z: wait on lane
- 2026-10-21T07:59Z: lane batching older PRs first
- 2026-10-21T07:37Z: wait on lane
- 2026-10-21T07:14Z: wait on lane
- 2026-10-21T07:08Z: AC-tools split at the 15-file cap of the stack
- 2026-10-21T06:59Z: AC-tools stacked on AC-colour; ToolKeys/KeyModifiers on dev
- 2026-10-21T06:51Z: Fast-Check on #3941 verified
- 2026-10-21T06:48Z: stack AC-colour on AC-zoom
- 2026-10-21T06:44Z: AC-zoom ships with departures listed (packet names absent files; no Model code to mutate)
- 2026-10-21T05:25Z: AC-guides done with no PR: #3309 (cf120143) had already shipped ViewportGuideMarks guides, the showsRulers flag and FlareGuideDrag with its plan. Belt-Slice-Done on run 39401676163 (#1942 6308762859), plus Mac-Finish-Wanted.
- 2026-10-21T05:25Z: Resumed: Belt's brief for run act-1a15ce4fb40-9k5r names this feature and its five slices, which postdates the captain's 2026-10-17 park, so the lead treats it as resumed. Waits re-read: EK-a, EK-chrome done (#1933); AB-photo done (#3011, #3030 on main); SC-f not started.
- Parked, not started: the captain's issue comment postdates the feature issue and Belt's brief, and no PR or branch of this feature exists. The lead works editor-kernel (#1933, p1, beta) instead.
- Even once resumed, only AC-guides can start after editor-kernel's EK-a: AC-zoom and AC-colour wait on adopt-kernel-brush AB-photo (itself waiting on EK-stroke and EK-chrome), AC-tools on AC-colour, and AC-export-sheet on adopt-kernel-export's three app slices (waiting on EK-run and other adopt features). None of those features has started.

## Open
- Waits on the captain lifting the beta cut, then on editor-kernel EK-a (every slice) and the adopt-kernel-* slices named above.
