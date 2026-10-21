# placed-images lead record

Issue: #3454 · Packet: docs/blueprints/design/features/placed-images.md
Run: act-1a15da1b26c-9qo6 · Session: claude/design-feature-lead-run-1k035k · Started: 2026-10-21T08:46:56Z (prior run act-1a15ac70747-ky1f)
Stage: 3 PD-a #3759 open (supervisor-queued, Package.swift)
Base: 896cafe3 (origin/dev); main verified at 0dd23d65
Next: PD-a merge by supervisor; PD-u and PD-m build additively from dev after it (supervisor)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PD-a | picture fields and PlacedImageTarget stubs, CoreRaster linked, checks and RJ-D12 written disabled | PD-1, PD-2 | MJ-PD | PL-a; gradient-fill:DG-a; transform:DT-a; shape-tools:DS-a; stroke-style:DK-m | no | 0 | waiting | – | – |
| PD-u | Place… and drop on the stubs, canvas draws by cover, inspector rows | PD-3, PD-4 | DJ-P1 | PD-a; DG-u; DE-u; PL-3; DA-a; DT-a; DT-u; DS-a; DS-u; DK-u | yes | 0 | waiting | – | – |
| PD-m | fill into frame, focus as one step, SVG crop | PD-5, PD-6 | MJ-PD | PD-a; DG-m; DE-s; PL-7; DA-m; DT-m; DY-m; DS-m; DK-m | no | 0 | waiting | – | – |
| PD-z | live journey, blueprint, feature-done | PD-7, PD-8 | DJ-P1 | PD-u, PD-m; DG-z | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PD-1 | PD-a | 2 | node fields, conformance stubs, CoreRaster link | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignPlace+Kernel.swift, Package.swift, Tests/DesignModelTests/DesignPlaceTests.swift | fixtures byte-equal; copy keeps picture | – | waiting |
| PD-2 | PD-a | 2 | SVG checks and RJ-D12 disabled | Tests/DesignModelTests/DesignPlaceSVGTests.swift, Tests/RealJobs/design/place-in-frame/ | compiles, disabled | – | waiting |
| PD-3 | PD-u | 3 | Place…, drop, ⌥-drag focus, drawPlaced | Sources/DesignApp/DesignPlace.swift, Sources/DesignApp/DesignCommands.swift, Sources/DesignApp/DesignCanvas.swift, Sources/DesignApp/DesignCanvasMarks.swift | DesignPlaceSnapshots.inFrame | – | waiting |
| PD-4 | PD-u | 3 | inspector image rows, snapshots, budget, journey skipped | Sources/DesignApp/DesignInspectorImage.swift, Sources/DesignApp/DesignInspector.swift, Tests/AppSnapshotTests/DesignPlaceSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignPlaceTests.swift, UITests/DesignJourneyTests+Place.swift | DesignPlaceSnapshots | – | waiting |
| PD-5 | PD-m | 3 | conformance bodies, specs | Sources/DesignModel/DesignPlace+Kernel.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt, Tests/DesignModelTests/DesignPlaceTests.swift, Tests/mutations/DesignModel.DesignPlace+Kernel.json | DesignPlaceTests | – | waiting |
| PD-6 | PD-m | 4 | SVG image with clip | Sources/DesignModel/Live/DesignSVG.swift, Tests/DesignModelTests/DesignPlaceSVGTests.swift, Tests/mutations/DesignModel.DesignSVG.json, Tests/RealJobs/design/place-in-frame/ | DesignPlaceSVGTests, RJ-D12 | – | waiting |
| PD-7 | PD-z | 5 | journey on live | UITests/DesignJourneyTests+Place.swift | testPlacePhotoInFrame | – | waiting |
| PD-8 | PD-z | 6 | design.md, status built | docs/blueprints/design.md, docs/blueprints/design/features/placed-images.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev (CLAUDE.md); brief's main HEAD b3011ab9 verified, work branches from origin/dev a48992b7.
- PD-1 touches Package.swift (protected): the packet says the supervisor merges it after the macOS build; the PR will say so.

## Open
- PD-a blocked: suiteui placed-images PL-a not merged (kernel Place stubs #3578 and bodies #3626 merged; SuiteUI slice not yet), gradient-fill DG-a (#3687 open), transform DT-a (this run, waits on DG-a), shape-tools DS-a and stroke-style DK-m (no PR found).
