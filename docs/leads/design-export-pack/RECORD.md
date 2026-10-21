# export-pack (Design) lead record

Issue: #3467 · Packet: docs/blueprints/design/features/export-pack.md
Run: act-1a15bc68263-njsv · Session: line lead (design) · Started: 2026-10-21T00:00Z
Stage: 3 polling
Base: 07f754f7 (origin/dev)
Next: DX-a waits on suiteui export-pack XP-a (XP-1 merged; XP-2 waits shell-media:SM-a, XP-3 waits tone-controls:TC-a). design-export is merged-done (DE-z #3684). Blocked poll 2 of 3 (00:33Z: XP-2 waits SM-a, XP-3 waits TC-a and PL-a, no PRs).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DX-a | options hold an ExportSize and list JPEG, plan takes them on stubs, sheet shows the shared Size row and a JPEG chip | DX-1, DX-2 | MJ-DX | XP-a (cross-line); design-export (done) | yes | 0 | waiting | – | – |
| DX-u | sheet snapshots, render budget, journey written | DX-5, DX-6 | DJ-X1 | DX-a; XP-4 (DX-5) | yes | 0 | waiting | – | – |
| DX-m | exact pixels per file, JPEG flattens onto the frame's fill, rasterizer draws at that size | DX-3, DX-4 | MJ-DX, DesignRasterizerSizeTests | DX-a; XP-6 (merged), SM-w | yes | 0 | waiting | – | – |
| DX-z | real JPEG and PNG at the exact size on live, journey passes, blueprint | DX-7, DX-8 | DJ-X1 | DX-u, DX-m; gradient-fill:DG-z (DX-8); placed-images:PD-z (DX-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DX-1 | DX-a | 1 | DesignExportOptions.size and .jpeg (refused until DX-3); DesignExportPackTests disabled | Sources/DesignModel/DesignExport+Kernel.swift, Tests/DesignModelTests/DesignExportPackTests.swift | existing export tests pass with size .scale; JPEG refused | – | waiting |
| DX-2 | DX-a | 1 | Size row and JPEG chip; Metadata hidden | Sources/DesignApp/DesignExport+Kernel.swift | DesignExportPackSnapshots.pixels | – | waiting |
| DX-3 | DX-m | 2 | exact pixel sizes, JPEG refusals and flattening, RJ-D41 | Sources/DesignModel/DesignExport+Kernel.swift, Tests/DesignModelTests/DesignExportPackTests.swift, Tests/mutations/DesignModel.DesignExport+Kernel.json, Tests/RealJobs/design/exact-jpeg/ | DesignExportPackTests | – | waiting |
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
