# pen-paths (Design) lead record

Issue: #3517 · Packet: docs/blueprints/design/features/pen-paths.md
Run: act-1a15bc68263-njsv · Session: line lead (design) · Started: 2026-10-21T00:00Z
Stage: 3 polling
Base: 07f754f7 (origin/dev)
Next: DP-a waits: DP-1 on placed-images:PD-a (#3759, supervisor lands it) and shape-tools:DS-a (merged via #3857, 08:34Z); DP-2 on stroke-style:DK-m (waiting) and adopt-kernel-session AD-design's Belt-Slice-Done (ready, not built); DP-3 on DS-m and PD-u. Blocked poll 3 of 3; supervisor answered (00:44Z): #3759 lands in the supervisor's local Mac queue; core issue filed (creative-core#787). Polling on (2026-10-21T10:47Z: unchanged; only PD-a #3759 left for DP-1).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DP-a | .path kind and pen state as stubs; old path seam removed; P routes to the stubs, PathEditOverlay drawn | DP-1, DP-2, DP-3 | MJ-DP | PN-a (done); PD-a, DS-a (DP-1); DK-m, DE-a (done), AD-design (DP-2); DS-m, PD-u (DP-3) | yes | 0 | waiting | – | – |
| DP-u | painter draws .path nodes; snapshots, budget, journey written | DP-4, DP-5 | DJ-DP | DP-a; PN-3 (DP-4) | yes | 0 | waiting | – | – |
| DP-m | adapter bodies, specs, RJ-D06; SVG path data | DP-6, DP-7 | MJ-DP | DP-a; file-flow:DF-m, PN-7 (DP-6); placed-images:PD-m, core path-data (DP-7) | no | 0 | waiting | – | – |
| DP-z | journey live; built | DP-8, DP-9 | DJ-DP | DP-u, DP-m; file-flow:DF-z (DP-9) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DP-1 | DP-a | 1 | .path kind, node path, pen state, conformance stubs | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignWorkspace.swift, Sources/DesignModel/DesignPen+Kernel.swift, Tests/DesignModelTests/DesignPenTests.swift, ... | old files decode; path round-trips | – | waiting |
| DP-2 | DP-a | 1 | old path seam deleted | Sources/DesignModel/Contracts/StyleTypes.swift, Sources/DesignModel/Contracts/UseCases.swift, Sources/DesignModel/NotBuilt.swift, Sources/DesignModel/DesignServices.swift, ... | git grep empty; mutate --validate | – | waiting |
| DP-3 | DP-a | 2 | P route and double-click to runPath and editPoints; overlay; artwork stub | Sources/DesignModel/DesignCanvasEditing.swift, Sources/DesignApp/DesignCanvasMarks.swift, Sources/DesignApp/DesignPathArtwork.swift, Tests/DesignModelTests/DesignPenRouteTests.swift | DesignPenRouteTests | – | waiting |
| DP-4 | DP-u | 3 | paintArtwork paints .path; journey written | Sources/DesignApp/DesignPathArtwork.swift, Tests/AppSnapshotTests/DesignPenPaintTests.swift, UITests/DesignJourneyTests+Pen.swift | DesignPenPaintTests | – | waiting |
| DP-5 | DP-u | 4 | snapshots, budget | Tests/AppSnapshotTests/DesignPenSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignPenTests.swift | anchorDragInThreeBodies | – | waiting |
| DP-6 | DP-m | 3 | adapter bodies, twelve specs, RJ-D06 | Sources/DesignModel/DesignPen+Kernel.swift, Sources/DesignModel/DesignCommandCatalog.swift, ... | DesignPenTests | – | waiting |
| DP-7 | DP-m | 3 | SVG path data | Sources/DesignModel/Live/DesignSVG.swift, Tests/DesignModelTests/DesignSVGPathTests.swift, Tests/mutations/DesignModel.DesignSVG.json | DesignSVGPathTests | – | waiting |
| DP-8 | DP-z | 5 | journey live | UITests/DesignJourneyTests+Pen.swift | testDrawLogoAndMovePoint | – | waiting |
| DP-9 | DP-z | 6 | design.md, status built, feature-done | docs/blueprints/design.md, docs/blueprints/design/features/pen-paths.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev (CLAUDE.md); brief's main HEAD b3011ab9 verified, work branches from origin/dev 07f754f7.
- lead/pen-paths holds the SuiteUI pen-paths lead's record, so this record lives on lead/design-pen-paths.
- DP-7 needs FlareCore's `SVGExporter.pathData(_:)` public; a needs-core issue on qbtrix/creative-core is outside this session's GitHub scope, so the supervisor question asks for it to be filed.

## Open
- DP-a blocked: PD-a (#3759), DS-a, DK-m, AD-design not merged.
- DP-7 waits creative-core#787 (SVGExporter.pathData public), filed by the supervisor.
- 2026-10-21T00:39Z Belt nudged on lead/export-pack and lead/pen-paths, which belong to the SuiteUI run act-1a15821c836-93pf. Not written to. Supervisor asked to watch lead/design-pen-paths (#3517 comment 6305071320).
- 2026-10-21T00:54Z Supervisor (#3517, 00:44Z): #3759 needs no captain (supervisor lands it from the local Mac queue); filed qbtrix/creative-core#787; Belt watch bug acknowledged, keep lead/design-pen-paths.
