# adopt-suiteui-chrome lead record

Issue: #1942 · Packet: docs/blueprints/suiteui/features/adopt-suiteui-chrome.md
Run: act-1a15ef870d6-3mm5 (#1942 only; slice AC-export-sheet; earlier run act-1a15ce4fb40-9k5r) · Session: claude/adopt-suiteui-chrome-w955g1 · Resumed: 2026-10-21
Stage: 0 setup (blocked on shared-codecs:SC-f)
Base: dev f2953daf (main 0dd23d65 verified)
Next: re-read shared-codecs:SC-f (SC-13 #4019 fixed at 4e6f468b, Fast-Check pass, awaiting lane macOS build + merge; then SC-14, SC-15, SC-16); start AC-e1 once SC-16 merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AC-zoom | every app clamps through ZoomMath, fits through one fit, maps through CanvasLayout | AC-z1, AC-z2 | MJ-AC-zoom | editor-kernel:EK-a, adopt-kernel-brush:AB-photo | yes | 0 | done | – | – |
| AC-colour | parse, format and pick colour through HexColor and ColorWell | AC-c1, AC-c2 | MJ-AC-colour | editor-kernel:EK-a, adopt-kernel-brush:AB-photo, AC-zoom | yes | 1 | done (per Belt brief act-1a15ef870d6-3mm5) | 39604117821 | wanted |
| AC-tools | tool letters and modifiers through ToolKeys | AC-t1, AC-t2 | MJ-AC-tools | editor-kernel:EK-chrome, AC-colour | yes | 0 | done (per Belt brief act-1a15ef870d6-3mm5) | – | – |
| AC-guides | Flare's guides draw through CanvasMarks (GuideLineMark) | AC-g1, AC-g2 | MJ-AC-guides | editor-kernel:EK-a | yes | 0 | done | – | – |
| AC-export-sheet | Photo, Library and Flare export sheets are SuiteUI's ExportSheet | AC-e1, AC-e2 | MJ-AC-export-sheet | editor-kernel:EK-chrome, adopt-kernel-export:AX-photo, AX-library, AX-flare (met), shared-codecs:SC-f (open) | yes | 0 | blocked-SC-f | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AC-z1 | AC-zoom | – | zoom adapter | per packet | DesignWindowZoomTests, PhotoWindowZoomTests, HaloKeyByDragTests, ViewerDraggingContractTests | – | parked |
| AC-z2 | AC-zoom | – | zoom delete | per packet | same + mutate --validate | – | parked |
| AC-c1 | AC-colour | – | colour adapter | per packet | HexColorParserTests, DesignStyleTests, DesignInspectorSnapshots | – | parked |
| AC-c2 | AC-colour | – | colour delete | per packet | same + mutate --validate | – | parked |
| AC-t1 | AC-tools | – | tools adapter | per packet | FlareToolsKeyTests, DesignToolsKeyTests, PhotoToolsKeyTests | – | parked |
| AC-t2 | AC-tools | – | tools delete | per packet | same + mutate --validate | – | parked |
| AC-g1 | AC-guides | – | guides adapter | per packet | FlareStageGuideSnapshots, GuideLineMarkTests | – | parked |
| AC-g2 | AC-guides | – | guides delete | per packet | same + mutate --validate | – | parked |
| AC-e1 | AC-export-sheet | – | export sheet adapter | per packet | PhotoExportSheetSnapshots, LibraryExportSnapshots, FlareExportSnapshots | – | parked |
| AC-e2 | AC-export-sheet | – | export sheet delete; `feature-done` | per packet | same + mutate --validate | – | parked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
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
