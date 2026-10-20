# gradient-fill lead record

Issue: #3419 · Packet: docs/blueprints/flare/features/gradient-fill.md
Run: act-1a1574f6742-pe5i · Session: claude/gradient-fill-lead-43ftwc · Started: 2026-10-20T03:17Z
Stage: 3 polling (wave 1 blocked)
Base: 53151b2b1c02dbb75565ab67fcdbc008c5ef9817
Next: wait for suiteui/gradient-fill GF-a (#3418) to merge (Sources/SuiteKernel/Fill/ on dev); then start wave 1 (FG-1)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FG-a | FlareWorkspace conforms to GradientFillTarget as stubs; PaintReadout carries the gradient; FILL shows the switch and the editor | FG-1, FG-2 | MJ-FG | suiteui GF-a (#3418) | yes | 0 | blocked | – | – |
| FG-u | FILL snapshots, stop-drag render budget, journey written | FG-3, FG-4 | FJ-G1 | FG-a; GF-3 (FG-3) | yes | 0 | blocked | – | – |
| FG-m | fill commands as one undo step through the engine; Mixed for differing gradients | FG-5, FG-6 | MJ-FG | FG-a; GF-6, AC-flare (FG-5) | no | 0 | blocked | – | – |
| FG-z | live services, journey on live, feature built | FG-7, FG-8 | FJ-G1 | FG-u, FG-m | yes | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FG-1 | FG-a | 1 | conformance + runFill stubs; PaintReadout.gradient; tests disabled | Sources/FlareModel/FlareFill+Kernel.swift, Sources/FlareModel/FlarePaint.swift, Tests/FlareModelTests/FlareGradientTests.swift | suite compiles disabled; old files decode | – | waiting GF-a |
| FG-2 | FG-a | 1 | FILL shows switch + GradientEditor on stubs; refusal string gone | Sources/FlareApp/FlareInspectorFill.swift | FlareGradientSnapshots.fillGradient | – | waiting FG-1 |
| FG-3 | FG-u | 2 | snapshots + render budget | Tests/AppSnapshotTests/FlareGradientSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFlareGradientTests.swift | RenderBudgetFlareGradientTests.stopDragInThreeBodies | – | waiting FG-a, GF-3 |
| FG-4 | FG-u | 2 | journey written, skipped | UITests/FlareJourneyTests+Gradient.swift | compiles, skipped | – | waiting FG-a |
| FG-5 | FG-m | 2 | conformance bodies, specs in catalog, RJ-F31 | Sources/FlareModel/FlareFill+Kernel.swift, Tests/FlareModelTests/FlareGradientTests.swift, Tests/mutations/FlareModel.FlareFill+Kernel.json, Sources/FlareModel/FlareCommandCatalog.swift, Tests/command-ids/flare.txt, Tests/RealJobs/flare/gradient-edit/gradient-edit.jobs.json, Tests/RealJobs/flare/gradient-edit/input/gradient-circle.flare | FlareGradientTests | – | waiting FG-a, GF-6, AC-flare |
| FG-6 | FG-m | 2 | Mixed for differing gradients; solid setter replaces gradient | Sources/FlareModel/FlarePaint.swift, Tests/FlareModelTests/FlarePaintGradientTests.swift, Tests/mutations/FlareModel.FlarePaint.json | FlarePaintGradientTests | – | waiting FG-a |
| FG-7 | FG-z | 3 | journey on live | UITests/FlareJourneyTests+Gradient.swift | FlareGradientJourneyTests.testEditImportedGradient | – | waiting FG-u, FG-m |
| FG-8 | FG-z | 4 | flare.md, status built, feature-done | docs/blueprints/flare.md, docs/blueprints/flare/features/gradient-fill.wave.json | scripts/waves render --dry-run | – | waiting FG-7 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main: the brief names main (b3011ab, verified), but the packet only exists on dev (233aff5, #3410) and CLAUDE.md says PRs target dev. The lane retargets main PRs to dev anyway.
- Slice PRs (rule 22): FG-1 and FG-2 ship as one FG-a PR, its first commit the disabled FlareGradientTests; FG-5 and FG-6 as one FG-m PR. Waves follow the packet with that grouping.
- #2315 is already closed, so FG-8 references it and does not use a closing keyword.

## Open
- Blocked: suiteui/gradient-fill GF-a (#3418) is building (lead/suiteui-gradient-fill at d9bf033: GF-1 stubs pushed at ed1ed79 on claude/gradient-fill-lead-1i5sqe, not merged, GF-2 blocked on command-catalog CC-u); Sources/SuiteKernel/Fill/ (Fill, FillSelection, GradientFillTarget, GradientIntent, GradientEditor) is not on dev. Every Flare task needs it.
- FG-5 also waits on GF-6 and adopt-command-catalog's AC-flare (Belt-Slice-Done on #2999's feature issue).
