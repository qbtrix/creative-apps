# adopt-suiteui-chrome lead record

Issue: #1942 · Packet: docs/blueprints/suiteui/features/adopt-suiteui-chrome.md
Run: act-1a15ce4fb40-9k5r (line lead for #1942, #1939, #1935) · Session: claude/feature-lead-playbook-0t4ks3 · Resumed: 2026-10-21
Stage: heartbeat
Base: dev a6f45c18
Next: AC-colour,AC-tools merge

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AC-zoom | every app clamps through ZoomMath, fits through one fit, maps through CanvasLayout | AC-z1, AC-z2 | MJ-AC-zoom | editor-kernel:EK-a, adopt-kernel-brush:AB-photo | yes | 0 | done | – | – |
| AC-colour | parse, format and pick colour through HexColor and ColorWell | AC-c1, AC-c2 | MJ-AC-colour | editor-kernel:EK-a, adopt-kernel-brush:AB-photo, AC-zoom | yes | 0 | lane | – | – |
| AC-tools | tool letters and modifiers through ToolKeys | AC-t1, AC-t2 | MJ-AC-tools | editor-kernel:EK-chrome, AC-colour | yes | 0 | lane | – | – |
| AC-guides | Flare's guides draw through CanvasMarks (GuideLineMark) | AC-g1, AC-g2 | MJ-AC-guides | editor-kernel:EK-a | yes | 0 | done | – | – |
| AC-export-sheet | Photo, Library and Flare export sheets are SuiteUI's ExportSheet | AC-e1, AC-e2 | MJ-AC-export-sheet | editor-kernel:EK-chrome, adopt-kernel-export:AX-photo, AX-library, AX-flare | yes | 0 | blocked-SC-f | – | – |

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
