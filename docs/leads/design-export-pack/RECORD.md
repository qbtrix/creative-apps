# export-pack (Design) lead record

Issue: #3467 · Packet: docs/blueprints/design/features/export-pack.md
Run: act-1a15bc68263-njsv · Session: line lead (design) · Started: 2026-10-21T00:00Z
Stage: 3 wave 1
Base: 07f754f7 (origin/dev)
Next: DX-1 and DX-3 merged together in #3834's squash (c1d0a7be, 08:08Z; DX-1's commits were ancestors of DX-3's head), #3833 closed as superseded. DX-a still needs DX-2 (waits XP-3); DX-m still needs DX-4 (waits SM-w, no shell-media packet or lead yet). Polling on (2026-10-21T08:13Z: unchanged;)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DX-a | options hold an ExportSize and list JPEG, plan takes them on stubs, sheet shows the shared Size row and a JPEG chip | DX-1, DX-2 | MJ-DX | XP-a (cross-line); design-export (done) | yes | 0 | building | – | – |
| DX-u | sheet snapshots, render budget, journey written | DX-5, DX-6 | DJ-X1 | DX-a; XP-4 (DX-5) | yes | 0 | waiting | – | – |
| DX-m | exact pixels per file, JPEG flattens onto the frame's fill, rasterizer draws at that size | DX-3, DX-4 | MJ-DX, DesignRasterizerSizeTests | DX-a; XP-6 (merged), SM-w | yes | 0 | building | – | – |
| DX-z | real JPEG and PNG at the exact size on live, journey passes, blueprint | DX-7, DX-8 | DJ-X1 | DX-u, DX-m; gradient-fill:DG-z (DX-8); placed-images:PD-z (DX-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DX-1 | DX-a | 1 | DesignExportOptions.size and .jpeg (refused until DX-3); DesignExportPackTests disabled | Sources/DesignModel/DesignExport+Kernel.swift, Tests/DesignModelTests/DesignExportPackTests.swift | existing export tests pass with size .scale; JPEG refused | #3833 → #3834 | merged (c1d0a7be, via #3834) |
| DX-2 | DX-a | 1 | Size row and JPEG chip; Metadata hidden | Sources/DesignApp/DesignExport+Kernel.swift | DesignExportPackSnapshots.pixels | – | waiting |
| DX-3 | DX-m | 2 | exact pixel sizes, JPEG refusals and flattening, RJ-D41 | Sources/DesignModel/DesignExport+Kernel.swift, Tests/DesignModelTests/DesignExportPackTests.swift, Tests/mutations/DesignModel.DesignExport+Kernel.json, Tests/RealJobs/design/exact-jpeg/ | DesignExportPackTests | #3834 | merged (c1d0a7be) |
| DX-4 | DX-m | 2 | rasterizer at planned size onto the fill | Sources/DesignApp/DesignRasterizer.swift, Tests/AppSnapshotTests/DesignRasterizerSizeTests.swift | DesignRasterizerSizeTests | – | waiting |
| DX-5 | DX-u | 2 | snapshots, render budget | Tests/AppSnapshotTests/DesignExportPackSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignExportPackTests.swift | typingWidthInTwoBodies | – | waiting |
| DX-6 | DX-u | 2 | journey written, skipped | UITests/DesignJourneyTests+ExportPack.swift | compiles, skipped | – | waiting |
| DX-7 | DX-z | 3 | journey live | UITests/DesignJourneyTests+ExportPack.swift | testExportPostAtExactSize | – | waiting |
| DX-8 | DX-z | 4 | design.md, status built, feature-done | docs/blueprints/design.md, docs/blueprints/design/features/export-pack.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev (CLAUDE.md); brief's main HEAD b3011ab9 verified, work branches from origin/dev 07f754f7.
- lead/export-pack holds the SuiteUI export-pack lead's record, so this record lives on lead/design-export-pack (the lead/design-* convention).
- Waits read per rule 12: XP-a is met once XP-1, XP-2 and XP-3 have merged. DX-1 only needs XP-1's SuiteExportSize (on dev); if XP-a is still open at blocked poll 3, the supervisor question proposes starting DX-1 on XP-1 alone.

## Open
- DX-a blocked: XP-a not merged (XP-2, XP-3 open).
- 2026-10-21T00:39Z Belt nudged on lead/export-pack and lead/pen-paths, which belong to the SuiteUI run act-1a15821c836-93pf. Not written to. Supervisor asked to watch lead/design-export-pack (#3467 comment 6305070606).
- 2026-10-21T00:54Z Supervisor (#3467, 00:44Z): start DX-1 on XP-1's SuiteExportSize and ExportRules from dev; XP-3 is the only wait for DX-2. The Belt branch watch is a Belt bug; keep lead/design-*.
- 2026-10-21T01:05Z DX-1 (#3833) touched StyleTypes.swift (.jpeg lives in DesignExportFormat), EditContracts.swift (DesignRefusal.notYet for the packet wording), the export sheet note, and its mutation plan; all DesignModel/DesignApp. The JPEG chip already shows (refused), so export-sheet snapshots likely change ahead of DX-2.
- 2026-10-21T01:05Z DX-3 started stacked on DX-1: its task waits are DX-1 and XP-6 (merged); the slice's SM-w wait applies to DX-4.
- 2026-10-21T01:23Z DX-3 (#3834): JPEG files carry the frame fill as background (white with no frame); RJ-D41 plan half runs on Linux, the job folder is pending DX-7 with platforms []; the render .jpeg case refuses until DX-4. Repointed one stale anchor in DesignModel.DesignExportSheet+Kernel.json.
- 2026-10-21T08:13Z #3834 merged at 08:08Z (batch of 8, run 39564910498) carrying DX-1's commits; #3833 closed as superseded with one comment (6311297787), so the macOS re-run question is moot. Neither DX-a nor DX-m is whole yet (DX-2, DX-4 wait).
