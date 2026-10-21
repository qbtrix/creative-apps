# photo gradient-fill lead record

Issue: #3416 · Packet: docs/blueprints/photo/features/gradient-fill.md
Run: act-1a15e2da54d-qlg1 (resumed; earlier act-1a15a9f4eba-h30y) · Session: claude/feature-lead-playbook-t69dpt · Started: 2026-10-20T18:40Z
Stage: 3 wave 4 (PG-z)
Base: 965a76be767734bcfbd1a2bf916a7b7802e728ef (origin/dev at resume)
Next: #3977 PG-6 merges (mac build 39586117070 green); open PG-z PR (PG-7 + PG-8 folded, feature-done); Belt-Slice-Done PG-a/PG-m once a green run holds #3927/#3922 (dev-red #3856, not ours)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PG-a | PhotoTool.gradient in the palette with help, options hold a Fill, Tool Options shows the editor on stubs | PG-1, PG-2 | MJ-PG | – | yes | 0 | merged (#3681, #3927); waits a green run | – | – |
| PG-u | drag line on canvas, options snapshots and render budget, journey written | PG-5, PG-6 | PJ-G1 | – | yes | 0 | PG-5 merged #3975; PG-6 #3977 in lane (mac build green) | – | – |
| PG-m | drag draws dithered gradient into the layer inside the selection as one step; options take each intent | PG-3, PG-4 | MJ-PG | – | no | 0 | merged (#3923 PG-4, #3922 PG-3 last); waits a green run | – | – |
| PG-z | live services, journey on live, blueprint, built | PG-7, PG-8 | PJ-G1 | PG-u | yes | 0 | building: branch photo-gradient-fill/PG-7 (PG-7 journey on, PG-5 tests on, PG-8 docs folded in), gate running | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PG-1 | PG-a | 1 | PhotoTool.gradient (help, symbol, G), drag to stub, ToolOptions.gradient, adapter stubs, tool.gradient id, PhotoGradientToolTests disabled | Sources/PhotoModel/PhotoWorkspace.swift, Sources/PhotoModel/PhotoStroke.swift, Sources/PhotoModel/ToolOptions.swift, Sources/PhotoModel/PhotoGradientTool+Kernel.swift, Sources/PhotoApp/PhotoIntent.swift, Sources/PhotoApp/PhotoToolOptions.swift, Tests/command-ids/photo.txt, Tests/PhotoModelTests/PhotoToolsTests.swift, Tests/PhotoModelTests/PhotoGradientToolTests.swift | PhotoToolsTests | #3681 | merged #3681 |
| PG-2 | PG-a | – | PhotoFillToolOptions: GradientEditor in Tool Options | Sources/PhotoApp/PhotoFillToolOptions.swift | PhotoGradientSnapshots.options | – | merged #3927 (7dcfd8287) |
| PG-3 | PG-m | 1 (stacked on PG-1) | drawGradient bodies, dithered, through editSelection; image.gradient spec; RJ-P19 | Sources/PhotoModel/PhotoGradientTool+Kernel.swift, Sources/PhotoModel/PhotoSelection.swift, Tests/PhotoModelTests/PhotoGradientToolTests.swift, Tests/mutations/PhotoModel.PhotoGradientTool+Kernel.json, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/RealJobs/photo/sky-gradient/sky-gradient.jobs.json, Tests/RealJobs/photo/sky-gradient/input/grey-256.png | PhotoGradientToolTests | – | merged #3922 (7d2121302) |
| PG-4 | PG-m | – | runGradientOption through GradientRules | Sources/PhotoModel/ToolOptions.swift, Tests/PhotoModelTests/PhotoGradientOptionsTests.swift, Tests/mutations/PhotoModel.ToolOptions.json | PhotoGradientOptionsTests | – | merged #3923 (896cafe3c) |
| PG-5 | PG-u | – | snapshots, render budget | Tests/AppSnapshotTests/PhotoGradientSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoGradientTests.swift | RenderBudgetPhotoGradientTests.gradientDragInThreeBodies | – | merged #3975 (119194068) |
| PG-6 | PG-u | – | drag line overlay; journey written, skipped | Sources/PhotoApp/PhotoCanvasOverlay.swift, UITests/PhotoJourneyTests+Gradient.swift | compiles, skipped | – | #3977 open, head 3192c019, mac build green, lane merges next sweep |
| PG-7 | PG-z | – | journey on live | UITests/PhotoJourneyTests+Gradient.swift | PhotoGradientJourneyTests.testSkyGradient | – | branch photo-gradient-fill/PG-7; folded with PG-8 into one PG-z PR (PG-7 is 7 lines); also turns on PhotoGradientSnapshots.radialOptions/done and RenderBudgetPhotoGradientTests.gradientDragInThreeBodies |
| PG-8 | PG-z | – | photo.md, status built, feature-done | docs/blueprints/photo.md, docs/blueprints/photo/features/gradient-fill.wave.json | scripts/waves render --dry-run | – | folded into the PG-z PR, feature-done |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is lead/photo-<feature> and the record lives in docs/leads/photo-<feature>/: the packet names lead/<feature>, but lead/gradient-fill, lead/export-pack and lead/file-flow already belong to the Flare, SuiteUI and Suite features of the same names, and are active. Earlier Photo leads use the photo- prefix (lead/photo-seams, lead/photo-documents).
- Base and PR target are origin/dev, not main: the brief names main (b3011ab9, verified), but the packets exist only on dev, CLAUDE.md sends crew PRs to dev and the lane retargets main PRs to dev.
- One PR per task, stacked: PRs stay under the 400-line cap, and each slice PR opens with its failing or disabled test as the first commit.
- PG-1 waits only on GF-1 (kernel Fill types, merged #3421), not the whole GF-a: PG-1 needs Fill and GradientIntent, not the editor view. PG-2 waits on GF-2 (GradientEditor, not on dev). The Flare lead reads FG-1 the same way.
- PG-3 needs only PG-1's merged code (packet task table), so it stacks on PG-1 in wave 1.

## Open
- Unverified report (PG-1 fixer, 19:3xZ): `scripts/ci --changed` printed CI: PASS while `listCommandsMatchesItsGolden(app: "photo")` printed a ✘. Builders now read AfterGlowCLITests output themselves; file an issue if it reproduces.
- GF-2 (SuiteUI GradientEditor) is not on dev: blocks PG-2, so PG-a's Belt-Slice-Done waits on it. GF-5 (GradientRules bodies; GradientRules.swift is still stubs) blocks PG-4; GF-3 blocks PG-5.
- PG-3 held (branch photo-gradient-fill/PG-3, head a8cc61cf): open its PR when #3681 merges. Snapshots: photo-gradient-tool-light/dark.png. It also adds `select.rect` (RJ-P19 needs it to select the top half), which is outside the owned list and in no menu. `expected/grey-256-sky.png` was generated from this implementation, so it guards against regressions only. `noBanding` skips pure black and white rows, because OKLab leaves about 100 rows at 0 next to the black stop. The builder also ran full `scripts/ci` and the AfterGlowCLITests: PASS, with no ✘ (the PG-1 false-pass did not reproduce).
- Supervisor (19:54Z, #3416): stack PG-2 on #3695 (GF-2) and PG-4 on #3705 (GF-5); rebase when they merge; GF-3 and GF-6 next from the local Mac crew. Belt-Slice-Done only on a green dev Linux run containing the slice's last PR.
