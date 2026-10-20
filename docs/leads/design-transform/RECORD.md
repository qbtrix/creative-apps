# transform lead record

Issue: #3436 · Packet: docs/blueprints/design/features/transform.md
Run: act-1a15ac70747-ky1f · Session: line lead (design) · Started: 2026-10-20T19:27Z
Stage: 3 polling
Base: a48992b7c85ded3959e12683f50bd5fe7531b011
Next: DT-a #3751 head 18116b8 clean, 397/14, fast-lane, in the lane. DT-u still waits on DG-u (not open or merged yet); DT-m on DG-m and DA-m (#3710 open). Critic round: +Kernel inspector name (no maths), Rotate symbols unverified, Select-a-layer wording.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DT-a | rotation/flip fields on DesignNode, TransformTarget stubs, inspector rows and Object items on the stubs | DT-1, DT-2 | MJ-DT | TT-a (merged #3485/#3486); gradient-fill:DG-a (#3687 open) | yes | 0 | waiting | – | – |
| DT-u | canvas paints turned nodes, handles turn; snapshots and render budget | DT-3, DT-4 | DJ-T1 | DT-a; gradient-fill:DG-u | yes | 0 | waiting | – | – |
| DT-m | adapter bodies, turned hit test, SVG turn, catalog specs, RJ-D15 | DT-5, DT-6 | MJ-DT | DT-a; gradient-fill:DG-m; autosave-history:DA-m | no | 0 | waiting | – | – |
| DT-z | journey on live, status built, feature-done | DT-7, DT-8 | DJ-T1 | DT-u, DT-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DT-1 | DT-a | 1 | node fields + adapter stubs, tests disabled | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift | DesignTransformTests (disabled), fixtures byte-equal | – | waiting |
| DT-2 | DT-a | 1 | inspector transform rows, Object items, journey skipped | Sources/DesignApp/DesignInspectorTransform.swift, Sources/DesignApp/DesignInspector.swift, Sources/DesignApp/DesignObjectMenu.swift, UITests/DesignJourneyTests+Transform.swift | snapshot rows | – | waiting |
| DT-3 | DT-u | 2 | canvas paints turned nodes | Sources/DesignApp/DesignCanvasMarks.swift, Sources/DesignApp/DesignSelectionMarks.swift, Tests/AppSnapshotTests/DesignTransformPaintTests.swift | DesignTransformPaintTests | – | waiting |
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
- DT-a waits on gradient-fill DG-a (#3687, open): it owns DesignNode.swift and DesignInspector.swift.
