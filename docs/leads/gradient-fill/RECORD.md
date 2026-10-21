# gradient-fill lead record

Issue: #3419 · Packet: docs/blueprints/flare/features/gradient-fill.md
Run: act-1a15d4ed024-1wsg (line lead: gradient-fill #3419, export-pack #3481, file-flow #3482; resumed from act-1a1574f6742-pe5i) · Session: claude/feature-lead-playbook-ahxuto · Started: 2026-10-20T03:17Z
Stage: 3 wave 3 (FG-2 + FG-4 in #3959)
Base: b64cbb8cf55ea16b62f0a293c83e1820b3e4b572 (origin/dev)
Next: #3959 (FG-a, FG-4 folded in) in the lane; after it lands and a scoped flare run shows flare-fill-gradient, critic panel + Belt-Slice-Done FG-a and Mac-Finish-Wanted; FG-3 once GF-3 #3760 merges; FG-5 once GF-6 #3742, KS-a #3921, AC-flare

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FG-a | FlareWorkspace conforms to GradientFillTarget as stubs; PaintReadout carries the gradient; FILL shows the switch and the editor | FG-1, FG-2 | MJ-FG | suiteui GF-2 (merged #3695) | yes | 0 | building | – | – |
| FG-u | FILL snapshots, stop-drag render budget, journey written | FG-3, FG-4 | FJ-G1 | FG-a; GF-3 #3760 open (FG-3) | yes | 0 | building (FG-4) | – | – |
| FG-m | fill commands as one undo step through the engine; Mixed for differing gradients | FG-5, FG-6 | MJ-FG | FG-a; KS-a #3921 open; GF-6 #3742 open, AC-flare (FG-5) | no | 0 | blocked | – | – |
| FG-z | live services, journey on live, feature built | FG-7, FG-8 | FJ-G1 | FG-u, FG-m | yes | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FG-1 | FG-a | 1 | conformance + runFill stubs; PaintReadout.gradient; tests disabled | Sources/FlareModel/FlareFill+Kernel.swift, Sources/FlareModel/FlarePaint.swift, Tests/FlareModelTests/FlareGradientTests.swift | suite compiles disabled; old files decode | #3526 | merged 11a545e7 |
| FG-2 | FG-a | 1 | FILL shows switch + GradientEditor on stubs; refusal string gone | Sources/FlareApp/FlareInspectorFill.swift | FlareGradientSnapshots.fillGradient | – | building (wave 3) |
| FG-3 | FG-u | 2 | snapshots + render budget | Tests/AppSnapshotTests/FlareGradientSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFlareGradientTests.swift | RenderBudgetFlareGradientTests.stopDragInThreeBodies | – | waiting FG-a, GF-3 |
| FG-4 | FG-u | 2 | journey written, skipped | UITests/FlareJourneyTests+Gradient.swift | compiles, skipped | – | building (wave 3, stacked on FG-2) |
| FG-5 | FG-m | 2 | conformance bodies, specs in catalog, RJ-F31 | Sources/FlareModel/FlareFill+Kernel.swift, Tests/FlareModelTests/FlareGradientTests.swift, Tests/mutations/FlareModel.FlareFill+Kernel.json, Sources/FlareModel/FlareCommandCatalog.swift, Tests/command-ids/flare.txt, Tests/RealJobs/flare/gradient-edit/gradient-edit.jobs.json, Tests/RealJobs/flare/gradient-edit/input/gradient-circle.flare | FlareGradientTests | – | waiting FG-a, GF-6, AC-flare |
| FG-6 | FG-m | 2 | Mixed for differing gradients; solid setter replaces gradient | Sources/FlareModel/FlarePaint.swift, Tests/FlareModelTests/FlarePaintGradientTests.swift, Tests/mutations/FlareModel.FlarePaint.json | FlarePaintGradientTests | #3532 | merged a454b5c9 |
| FG-7 | FG-z | 3 | journey on live | UITests/FlareJourneyTests+Gradient.swift | FlareGradientJourneyTests.testEditImportedGradient | – | waiting FG-u, FG-m |
| FG-8 | FG-z | 4 | flare.md, status built, feature-done | docs/blueprints/flare.md, docs/blueprints/flare/features/gradient-fill.wave.json | scripts/waves render --dry-run | – | waiting FG-7 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-21 (act-1a15d4ed024-1wsg): the brief asks to rebase lead/gradient-fill onto main; the branch carried 1777 dev-side commits, so it was rebuilt as one commit on origin/main holding docs/leads/gradient-fill, pushed with --force-with-lease. PRs still target dev (the lane's BASE_BRANCH).
- FG-4 ships as its own PR stacked on FG-2, ahead of FG-3: FG-3 waits on GF-3's real view.
- Base is origin/dev, not main: the brief names main (b3011ab, verified), but the packet only exists on dev (233aff5, #3410) and CLAUDE.md says PRs target dev. The lane retargets main PRs to dev anyway.
- Slice PRs (rule 22): FG-1 and FG-2 ship as one FG-a PR, its first commit the disabled FlareGradientTests; FG-5 and FG-6 as one FG-m PR. Waves follow the packet with that grouping.
- 2026-10-20T06:2xZ: FG-a ships as two PRs, FG-1 now and FG-2 once GF-2 lands. GF-2 waits command-catalog CC-u for an unknown time, and holding FG-1 would also hold FG-6 (FG-m). The FG-a Belt-Slice-Done waits for FG-2.
- #2315 is already closed, so FG-8 references it and does not use a closing keyword.

## Open
- #3959 head 9a054aab: FG-2 + FG-4 (39-line journey folded in), 208 lines, 10 files, ci --changed PASS (Linux only; view not compiled yet). Notes for FG-7: journey assumes a `gradient-circle` Flare sample and guesses `suite.gradient.*` ids GF-3 defines. Notes for FG-3/GF-3: the FILL switch and the editor's own Type row may duplicate once GF-3 lands. The proxy re-appends a tool footer to PR bodies; the lane strips it from the squash.
- 2026-10-21T07Z: GF-2 (#3695) and GF-5 (#3705) are on dev; GF-3 is #3760 and GF-6 is #3742, both open. FG-m now also waits on key-select-all:KS-a (#3921, open). AC-flare has no Belt-Slice-Done on #2999.
- Blocked: suiteui/gradient-fill GF-a (#3418) is building (lead/suiteui-gradient-fill at d9bf033: GF-1 stubs are PR #3421 (open since 03:31Z, waiting on its lane macOS build run 39364860084, queued since 03:32Z), GF-2 blocked on command-catalog CC-u); #3421 merged 05:53Z (9a146777): the kernel Fill module is on dev, which unblocks FG-1 and FG-6. GradientEditor (GF-2) is still missing, blocking FG-2.
- FG-5 also waits on GF-6 and adopt-command-catalog's AC-flare (Belt-Slice-Done on #2999's feature issue).
- 2026-10-20T05:32Z: asked the supervisor on #3419 to re-dispatch #3421's queued macOS build or add a Mac-Check.
