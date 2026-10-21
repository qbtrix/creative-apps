# transform lead record

Issue: #3436 · Packet: docs/blueprints/design/features/transform.md
Run: act-1a15da1b26c-9qo6 · Session: claude/design-feature-lead-run-1k035k · Started: 2026-10-21T08:46:56Z (prior run act-1a15ac70747-ky1f)
Stage: 3 DT-a done (#3751, e6430cfa; Linux green on run 39569221486); DT-u building: DT-3 #3983 open (stacked on DG-u #3978); DT-4 next
Base: 896cafe3 (origin/dev); main verified at 0dd23d65
Next: DT-a critics on a scoped design run; DT-u once DG-u merges (both own DesignCanvasMarks.swift); DT-m waits DG-m, DA-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DT-a | rotation/flip fields on DesignNode, TransformTarget stubs, inspector rows and Object items on the stubs | DT-1, DT-2 | MJ-DT | TT-a (merged #3485/#3486); gradient-fill:DG-a (#3687 open) | yes | 0 | done | 39569221486 | wanted |
| DT-u | canvas paints turned nodes, handles turn; snapshots and render budget | DT-3, DT-4 | DJ-T1 | DT-a; gradient-fill:DG-u | yes | 0 | building | – | – |
| DT-m | adapter bodies, turned hit test, SVG turn, catalog specs, RJ-D15 | DT-5, DT-6 | MJ-DT | DT-a; gradient-fill:DG-m; autosave-history:DA-m | no | 0 | waiting | – | – |
| DT-z | journey on live, status built, feature-done | DT-7, DT-8 | DJ-T1 | DT-u, DT-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DT-1 | DT-a | 1 | node fields + adapter stubs, tests disabled | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift | DesignTransformTests (disabled), fixtures byte-equal | #3751 | merged (e6430cfa) |
| DT-2 | DT-a | 1 | inspector transform rows, Object items, journey skipped | Sources/DesignApp/DesignInspectorTransform.swift, Sources/DesignApp/DesignInspector.swift, Sources/DesignApp/DesignObjectMenu.swift, UITests/DesignJourneyTests+Transform.swift | snapshot rows | #3751 | merged (e6430cfa) |
| DT-3 | DT-u | 2 | canvas paints turned nodes | Sources/DesignApp/DesignCanvasMarks.swift, Sources/DesignApp/DesignSelectionMarks.swift, Tests/AppSnapshotTests/DesignTransformPaintTests.swift | DesignTransformPaintTests | #3983 | open |
| DT-4 | DT-u | 2 | snapshots, render budget | Tests/AppSnapshotTests/DesignTransformSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignTransformTests.swift | RenderBudgetDesignTransformTests | – | waiting |
| DT-5 | DT-m | 2 | adapter bodies, contains | Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift, Tests/mutations/DesignModel.DesignTransform+Kernel.json | DesignTransformTests | – | waiting |
| DT-6 | DT-m | 3 | SVG turn, specs, RJ-D15 | Sources/DesignModel/Live/DesignSVG.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt, Tests/RealJobs/design/rotate-15/ | DesignSVGTests.turnedNode, RJ-D15 | – | waiting |
| DT-7 | DT-z | 4 | journey on live | UITests/DesignJourneyTests+Transform.swift | DesignTransformJourneyTests | – | waiting |
| DT-8 | DT-z | 5 | design.md, status built | docs/blueprints/design.md, docs/blueprints/design/features/transform.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev (CLAUDE.md, lane retargets main to dev); brief's main HEAD b3011ab9 verified, work branches from origin/dev a48992b7.
- One combined wave plan across transform, placed-images, file-flow (rule 19); DT-a is the first wave for this feature and blocks PD-a.

## Open
- DT-a Belt-Slice-Done and Mac-Finish-Wanted posted on #3436 (run 39569221486).
