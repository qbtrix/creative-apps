# adopt-suiteui-chrome lead record

Issue: #1942 · Packet: docs/blueprints/suiteui/features/adopt-suiteui-chrome.md
Run: act-1a1483c0771-g24c · Session: claude/task-52830u · Started: 2026-10-17T06:04Z
Stage: 0 setup
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745
Next: parked: the captain's comment on #1942 (2026-10-17 03:08 UTC) takes this feature out of the beta cut ("resumes after beta; finish the slice in flight, then stop") and nothing is in flight; a lead resumes at stage 1 when the supervisor says so

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AC-zoom | every app clamps through ZoomMath, fits through one fit, maps through CanvasLayout | AC-z1, AC-z2 | MJ-AC-zoom | editor-kernel:EK-a, adopt-kernel-brush:AB-photo | yes | 0 | parked | – | – |
| AC-colour | parse, format and pick colour through HexColor and ColorWell | AC-c1, AC-c2 | MJ-AC-colour | editor-kernel:EK-a, adopt-kernel-brush:AB-photo, AC-zoom | yes | 0 | parked | – | – |
| AC-tools | tool letters and modifiers through ToolKeys | AC-t1, AC-t2 | MJ-AC-tools | editor-kernel:EK-chrome, AC-colour | yes | 0 | parked | – | – |
| AC-guides | Flare's guides draw through CanvasMarks (GuideLineMark) | AC-g1, AC-g2 | MJ-AC-guides | editor-kernel:EK-a | yes | 0 | parked | – | – |
| AC-export-sheet | Photo, Library and Flare export sheets are SuiteUI's ExportSheet | AC-e1, AC-e2 | MJ-AC-export-sheet | editor-kernel:EK-chrome, adopt-kernel-export:AX-photo, AX-library, AX-flare | yes | 0 | parked | – | – |

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
- Parked, not started: the captain's issue comment postdates the feature issue and Belt's brief, and no PR or branch of this feature exists. The lead works editor-kernel (#1933, p1, beta) instead.
- Even once resumed, only AC-guides can start after editor-kernel's EK-a: AC-zoom and AC-colour wait on adopt-kernel-brush AB-photo (itself waiting on EK-stroke and EK-chrome), AC-tools on AC-colour, and AC-export-sheet on adopt-kernel-export's three app slices (waiting on EK-run and other adopt features). None of those features has started.

## Open
- Waits on the captain lifting the beta cut, then on editor-kernel EK-a (every slice) and the adopt-kernel-* slices named above.
