# adopt-suiteui-chrome lead record

Issue: #1942 · Packet: docs/blueprints/suiteui/features/adopt-suiteui-chrome.md
Run: act-1a160ca3d68-sbnc (#1942; slices AC-tools, AC-export-sheet) · Session: claude/adopt-suiteui-chrome-fhl6sx · Resumed: 2026-10-21T23:30Z
Stage: 3 build (AC-tools in lane; AC-export-sheet blocked)
Base: dev be9aa35b (main 0dd23d65 verified)
Next: #4002 (AC-tools p2) head cbada801 in the lane (Fast-Check pass), then lane merge and a green scoped suiteui or full run; re-read shared-codecs SC-f (SC-13 #4019 merged, SC-14 #4238 open, SC-15 and SC-16 not opened); start AC-e1 once SC-16 merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AC-zoom | every app clamps through ZoomMath, fits through one fit, maps through CanvasLayout | AC-z1, AC-z2 | MJ-AC-zoom | editor-kernel:EK-a, adopt-kernel-brush:AB-photo | yes | 0 | done | – | – |
| AC-colour | parse, format and pick colour through HexColor and ColorWell | AC-c1, AC-c2 | MJ-AC-colour | editor-kernel:EK-a, adopt-kernel-brush:AB-photo, AC-zoom | yes | 1 | done | 39604117821 | wanted |
| AC-tools | tool letters and modifiers through ToolKeys | AC-t1, AC-t2 | MJ-AC-tools | editor-kernel:EK-chrome, AC-colour | yes | 0 | building: p1 #3952 merged, p2 #4002 in lane | – | – |
| AC-guides | Flare's guides draw through CanvasMarks (GuideLineMark) | AC-g1, AC-g2 | MJ-AC-guides | editor-kernel:EK-a | yes | 0 | done | – | – |
| AC-export-sheet | Photo, Library and Flare export sheets are SuiteUI's ExportSheet | AC-e1, AC-e2 | MJ-AC-export-sheet | editor-kernel:EK-chrome (met), adopt-kernel-export:AX-photo, AX-library, AX-flare (met), shared-codecs:SC-f (open) | yes | 0 | blocked-SC-f | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AC-z1 | AC-zoom | – | zoom adapter | per packet | DesignWindowZoomTests, PhotoWindowZoomTests, HaloKeyByDragTests, ViewerDraggingContractTests | – | parked |
| AC-z2 | AC-zoom | – | zoom delete | per packet | same + mutate --validate | – | parked |
| AC-c1 | AC-colour | – | colour adapter | per packet | HexColorParserTests, DesignStyleTests, DesignInspectorSnapshots | – | parked |
| AC-c2 | AC-colour | – | colour delete | per packet | same + mutate --validate | – | parked |
| AC-t1 | AC-tools | 1 | tools adapter | per packet | FlareToolsKeyTests, DesignToolsKeyTests, PhotoToolsKeyTests | #3952, #4002 | p1 merged, p2 in lane |
| AC-t2 | AC-tools | 1 | tools delete | per packet | same + mutate --validate | #4002 | in lane |
| AC-g1 | AC-guides | – | guides adapter | per packet | FlareStageGuideSnapshots, GuideLineMarkTests | – | parked |
| AC-g2 | AC-guides | – | guides delete | per packet | same + mutate --validate | – | parked |
| AC-e1 | AC-export-sheet | – | export sheet adapter | per packet | PhotoExportSheetSnapshots, LibraryExportSnapshots, FlareExportSnapshots | – | parked |
| AC-e2 | AC-export-sheet | – | export sheet delete; `feature-done` | per packet | same + mutate --validate | – | parked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22T00:10Z: #4002 head cbada801 (merge of dev be9aa35b) passed scripts/ci --changed; pushed, Head and Belt-Lead lines moved. The lane batches it with its macOS gate.
- 2026-10-21T23:30Z: run act-1a160ca3d68-sbnc resumed for AC-tools and AC-export-sheet. AC-tools is not done: no Belt-Slice-Done line exists and #4002 is unmerged, so the earlier record's "done (per Belt brief)" is corrected to building. #4002 was held on a red Linux check that only failed dev's inherited CommandPath baseline (#3856); #4250 fixed that on dev be9aa35b, so origin/dev is merged into slice/ac-tools-2 (no rebase) and the gate rerun.
- 2026-10-21T23:30Z: SC-f re-read: SC-13 #4019 merged, SC-14 #4238 open and clean, SC-15 and SC-16 not opened. AC-e1 stays unstarted.
- 2026-10-21T15:00Z: run act-1a15ef870d6-3mm5 resumed for AC-export-sheet only. Waits re-read: EK-chrome met (Sources/SuiteUI/ExportSheet.swift on dev); AX-flare, AX-photo, AX-library done (lead/adopt-kernel-export RECORD). shared-codecs:SC-f not met: SC-13 #4019 open, SC-14..16 unstarted. The wait is real: SC-15 owns PhotoWindow+Export.swift and SC-16 replaces Library's ExportFormat the sheet lists, so AC-e1 does not start and nothing is built around it.
- 2026-10-21T15:00Z: Belt brief names main as base; dev's CLAUDE.md makes dev the integration branch and the lane retargets fast-lane PRs from main to dev, so slice PRs go to dev.
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
- AC-tools waits on #4002's merge and a green ci.yml run that contains it.
- AC-export-sheet waits on shared-codecs:SC-f (#3718; SC-14 #4238, then SC-15, SC-16).
