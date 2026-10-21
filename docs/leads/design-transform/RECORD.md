# transform lead record

Issue: #3436 · Packet: docs/blueprints/design/features/transform.md
Run: act-1a15da1b26c-9qo6 · Session: claude/design-feature-lead-run-1k035k · Started: 2026-10-21T08:46:56Z (prior run act-1a15ac70747-ky1f)
Stage: 3 DT-u waiting on #4159 (lane macOS build queued, no runner); #4188 fix on fix/design-rotate-knob (c1dfd3d6) held for #4187; round 2: findings #4223 (turned resize) + #4224 (several, no knob) filed, fixes built: fix/design-turned-resize (9ab21935, on rotate-knob, +136/−2, Mutate 33/33 DesignCanvasEditing) and fix/design-knob-several (00e7a2ca, on turned-resize, +137/−10, Mutate 38/38 DesignCanvasEditing + 25/25 DesignCanvasHints; snapshots design-transform-turned-several-light/dark.png); PRs held for their bases; DT-m: #4187 open, DT-6 on feat/design-transform-dt6 (31b8bc73) held for #4189+#4187; DT-z: DT-7 journey pushed on feat/design-transform-dt7-journey (c36b6b1a, off dev, +162/−6, 1 file; PR after #4188 fix, DT-6 and #4223 fix merge)
Base: 896cafe3 (origin/dev); main verified at 0dd23d65
Next: #4159, #4187, #4188-fix merge -> Belt-Slice-Done + Mac-Finish-Wanted DT-u on a green design run; DT-6 after DG-m merges (shares DesignSVG, catalog; must update turnHelp snapshots: DesignInspectorSnapshots.transformRows, objectItemsSayWhyTheyAreOff, DesignSeveralInspectorSnapshots) and DA-m re-read

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
| DT-3 | DT-u | 2 | canvas paints turned nodes | Sources/DesignApp/DesignCanvasMarks.swift, Sources/DesignApp/DesignSelectionMarks.swift, Tests/AppSnapshotTests/DesignTransformPaintTests.swift | DesignTransformPaintTests | #3983 | merged (564e6562) |
| DT-4 | DT-u | 2 | snapshots, render budget | Tests/AppSnapshotTests/DesignTransformSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignTransformTests.swift | RenderBudgetDesignTransformTests | – | waiting |
| DT-5 | DT-m | 2 | adapter bodies, contains | Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift, Tests/mutations/DesignModel.DesignTransform+Kernel.json | DesignTransformTests | – | waiting |
| DT-6 | DT-m | 3 | SVG turn, specs, RJ-D15 | Sources/DesignModel/Live/DesignSVG.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt, Tests/RealJobs/design/rotate-15/ | DesignSVGTests.turnedNode, RJ-D15 | – | waiting |
| DT-7 | DT-z | 4 | journey on live | UITests/DesignJourneyTests+Transform.swift | DesignTransformJourneyTests | – | pushed, PR held |
| DT-8 | DT-z | 5 | design.md, status built | docs/blueprints/design.md, docs/blueprints/design/features/transform.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev (CLAUDE.md, lane retargets main to dev); brief's main HEAD b3011ab9 verified, work branches from origin/dev a48992b7.
- One combined wave plan across transform, placed-images, file-flow (rule 19); DT-a is the first wave for this feature and blocks PD-a.

## Open
- DT-a Belt-Slice-Done and Mac-Finish-Wanted posted on #3436 (run 39569221486).

## Run act-1a15fcdd869-ck2o (2026-10-21T18:55Z)

- Relaunched. TT-u #3513 merged as 7347ed80, so DT-4 (the DT-u snapshots and render budget) is unblocked and is next. DT-m still waits on gradient-fill DG-m and autosave-history DA-m.
