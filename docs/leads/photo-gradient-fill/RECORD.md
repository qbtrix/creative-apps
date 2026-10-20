# photo gradient-fill lead record

Issue: #3416 · Packet: docs/blueprints/photo/features/gradient-fill.md
Run: act-1a15a9f4eba-h30y · Session: claude/feature-lead-playbook-djd69t · Started: 2026-10-20T18:40Z
Stage: 3 wave 1
Base: e382f9d7fba02ffdefc8ba2f23c9461b4774fad6
Next: PG-1 builder (stubs, PhotoTool.gradient, ToolOptions.gradient) then PG-3 stacked on it; PG-2 waits GF-2 (GradientEditor), PG-4 GF-5 (GradientRules bodies), PG-5 GF-3

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PG-a | PhotoTool.gradient in the palette with help, options hold a Fill, Tool Options shows the editor on stubs | PG-1, PG-2 | MJ-PG | suiteui GF-1 (merged, PG-1); GF-2 (PG-2); AC-photo (built) | yes | 0 | building | – | – |
| PG-u | drag line on canvas, options snapshots and render budget, journey written | PG-5, PG-6 | PJ-G1 | PG-a; GF-3 (PG-5) | yes | 0 | waiting | – | – |
| PG-m | drag draws dithered gradient into the layer inside the selection as one step; options take each intent | PG-3, PG-4 | MJ-PG | PG-a (PG-1 only for PG-3); GF-5 (PG-4) | no | 0 | building (PG-3 stacked on PG-1) | – | – |
| PG-z | live services, journey on live, blueprint, built | PG-7, PG-8 | PJ-G1 | PG-u, PG-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PG-1 | PG-a | 1 | PhotoTool.gradient (help, symbol, G), drag to stub, ToolOptions.gradient, adapter stubs, tool.gradient id, PhotoGradientToolTests disabled | Sources/PhotoModel/PhotoWorkspace.swift, Sources/PhotoModel/PhotoStroke.swift, Sources/PhotoModel/ToolOptions.swift, Sources/PhotoModel/PhotoGradientTool+Kernel.swift, Sources/PhotoApp/PhotoIntent.swift, Sources/PhotoApp/PhotoToolOptions.swift, Tests/command-ids/photo.txt, Tests/PhotoModelTests/PhotoToolsTests.swift, Tests/PhotoModelTests/PhotoGradientToolTests.swift | PhotoToolsTests | – | building |
| PG-2 | PG-a | – | PhotoFillToolOptions: GradientEditor in Tool Options | Sources/PhotoApp/PhotoFillToolOptions.swift | PhotoGradientSnapshots.options | – | waits GF-2 |
| PG-3 | PG-m | 1 (stacked on PG-1) | drawGradient bodies, dithered, through editSelection; image.gradient spec; RJ-P19 | Sources/PhotoModel/PhotoGradientTool+Kernel.swift, Sources/PhotoModel/PhotoSelection.swift, Tests/PhotoModelTests/PhotoGradientToolTests.swift, Tests/mutations/PhotoModel.PhotoGradientTool+Kernel.json, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/RealJobs/photo/sky-gradient/sky-gradient.jobs.json, Tests/RealJobs/photo/sky-gradient/input/grey-256.png | PhotoGradientToolTests | – | building |
| PG-4 | PG-m | – | runGradientOption through GradientRules | Sources/PhotoModel/ToolOptions.swift, Tests/PhotoModelTests/PhotoGradientOptionsTests.swift, Tests/mutations/PhotoModel.ToolOptions.json | PhotoGradientOptionsTests | – | waits GF-5 |
| PG-5 | PG-u | – | snapshots, render budget | Tests/AppSnapshotTests/PhotoGradientSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoGradientTests.swift | RenderBudgetPhotoGradientTests.gradientDragInThreeBodies | – | waits PG-2, GF-3 |
| PG-6 | PG-u | – | drag line overlay; journey written, skipped | Sources/PhotoApp/PhotoCanvasOverlay.swift, UITests/PhotoJourneyTests+Gradient.swift | compiles, skipped | – | waits PG-2 |
| PG-7 | PG-z | – | journey on live | UITests/PhotoJourneyTests+Gradient.swift | PhotoGradientJourneyTests.testSkyGradient | – | waits PG-6, PG-3, PG-4 |
| PG-8 | PG-z | – | photo.md, status built, feature-done | docs/blueprints/photo.md, docs/blueprints/photo/features/gradient-fill.wave.json | scripts/waves render --dry-run | – | waits PG-7, PG-5 |

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
- GF-2 (SuiteUI GradientEditor) is not on dev: blocks PG-2, so PG-a's Belt-Slice-Done waits on it. GF-5 (GradientRules bodies; GradientRules.swift is still stubs) blocks PG-4; GF-3 blocks PG-5.
