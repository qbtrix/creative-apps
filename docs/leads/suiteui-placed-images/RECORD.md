# placed-images lead record

Issue: #3457 · Packet: docs/blueprints/suiteui/features/placed-images.md
Run: act-1a157ad4600-c6w5 · Session: 1dda8f22-4f7f-5e83-a997-571c40aa1288 · Started: 2026-10-20T05:01:16Z
Stage: 3 wave 1
Base: 854a3b52c66aaa12582e9190f404265b84594a05
Next: #3942 (PL-4, on dev, head 227f061). PL-u done once #3942 is in a green Linux run (Belt-Slice-Done + Mac-Finish-Wanted). PL-8 after PL-4; PL-9 waits on gradient-fill:GF-z.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PL-a | The kernel's Place module declares every type, rule and command spec as stubs, SuiteUI's panel, drop target, view and rows exist as placeholders on the gallery's place-image page, and the checks are written, disabled. | PL-1, PL-2 | SJ0 | gradient-fill:GF-a (PL-1, PL-2); editor-kernel (PL-1); suite-harness (PL-2); editor-in-window (PL-2); autosave-history:AH-a (PL-1, PL-2) | true | 0 | done | 39571804700 | wanted |
| PL-u | On the gallery page a dropped, chosen or sample PNG, JPEG or SVG shows in its box at its own aspect, the drop highlights only for files it takes, and the rows show the file and size with Replace… and Reset Size, every control identified, within the render budget. | PL-3, PL-4 | PJ1 | PL-a (PL-3) | true | 0 | merged-done | https://github.com/qbtrix/creative-apps/actions/runs/39617481529 | wanted |
| PL-m | The rules sniff the format, refuse what they can't take with a reason, fit a new image inside the canvas without upscaling, crop by cover around the focus so nothing stretches, flatten an SVG into paint, and every place command records exactly one undo step (a focus drag one). | PL-5, PL-6, PL-7 | KJ-place | PL-a (PL-5, PL-6, PL-7); command-catalog:CC-run (PL-7) | false | 0 | done | 39473997761 | – |
| PL-z | The gallery runs its intents through PlaceCommands on a live target, the fake app takes placed images so RJ-X36 runs on the CLI, and the feature is built. | PL-8, PL-9, PL-10 | PJ1, KJ-place | PL-u (PL-8); PL-m (PL-8, PL-9); gradient-fill:GF-z (PL-9); autosave-history:AH-z (PL-8, PL-9, PL-10); transform-tools:TT-z (PL-8, PL-9, PL-10); eyedropper:EY-z (PL-8, PL-9, PL-10); shape-tools:SH-z (PL-8, PL-9, PL-10); stroke-style:SS-d (PL-8, PL-9, PL-10) | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PL-1 | PL-a | 1 | see packet task table (waits: gradient-fill:GF-a) | Sources/SuiteKernel/Place/Placed.swift, Sources/SuiteKernel/Place/PlaceRules.swift, Sources/SuiteKernel/Place/PlaceVector.swift, Sources/SuiteKernel/Place/PlaceCommands.swift, Tests/SuiteKernelTests/PlaceRulesTests.swift, Tests/SuiteKernelTests/PlaceVectorTests.swift, Tests/SuiteKernelTests/PlaceCommandsTests.swift, Tests/canonical-concepts.txt, docs/c4/parts/creative-apps/suite-kernel/kernel-place.json | packet acceptance row | #3578 | merged 11:20 (lane batch, Linux run 39412675839) |
| PL-2 | PL-a | 2 | see packet task table (waits: PL-1, gradient-fill:GF-a) | Sources/SuiteUI/PlacePanel.swift, Sources/SuiteUI/PlaceDrop.swift, Sources/SuiteUI/PlacedImageView.swift, Sources/SuiteUI/PlacedImageRows.swift, Sources/SuiteUI/Gallery/GalleryPlaceImage.swift, Sources/SuiteUI/SuiteGallery.swift, UITests/SuiteJourneyTests+Place.swift | packet acceptance row | #3931 | merged (605a8bf) |
| PL-3 | PL-u | – | see packet task table (waits: PL-2) | Sources/SuiteUI/PlacePanel.swift, Sources/SuiteUI/PlaceDrop.swift, Sources/SuiteUI/PlacedImageView.swift, Sources/SuiteUI/PlacedImageRows.swift, Tests/SuiteUITests/PlaceDropTests.swift | packet acceptance row | #3940 | merged (564422f) |
| PL-4 | PL-u | – | see packet task table (waits: PL-3) | Tests/AppSnapshotTests/SuitePlaceSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPlaceTests.swift, UITests/SuiteJourneyTests+Place.swift | packet acceptance row | #3942 | merged (541cab6) |
| PL-5 | PL-m | – | see packet task table (waits: PL-1) | Sources/SuiteKernel/Place/PlaceRules.swift, Tests/SuiteKernelTests/PlaceRulesTests.swift, Tests/mutations/SuiteKernel.PlaceRules.json | packet acceptance row | #3598 | merged 13:02 (lane batch 39425106447) |
| PL-6 | PL-m | – | see packet task table (waits: PL-1) | Sources/SuiteKernel/Place/PlaceVector.swift, Tests/SuiteKernelTests/PlaceVectorTests.swift, Tests/mutations/SuiteKernel.PlaceVector.json, Tests/SuiteKernelTests/Fixtures/place/ | packet acceptance row | #3599 | merged 13:59 (squash c76647d, batch 39433379397) |
| PL-7 | PL-m | – | see packet task table (waits: PL-5, PL-6, command-catalog:CC-run) | Sources/SuiteKernel/Place/PlaceCommands.swift, Tests/SuiteKernelTests/PlaceCommandsTests.swift, Tests/mutations/SuiteKernel.PlaceCommands.json | packet acceptance row | #3626 | merged 18:18 (squash 299a29c) |
| PL-8 | PL-z | – | see packet task table (waits: PL-4, PL-7) | Sources/SuiteUI/Gallery/GalleryPlaceImage.swift, Sources/SuiteUI/PlacedImageView.swift, Tests/SuiteUITests/PlaceLiveTests.swift | packet acceptance row | – | waiting |
| PL-9 | PL-z | – | see packet task table (waits: PL-7, gradient-fill:GF-z) | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeCanvasPlaceTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/place-image/ | packet acceptance row | – | waiting |
| PL-10 | PL-z | – | see packet task table (waits: PL-8, PL-9) | docs/c4/parts/creative-apps/suite-kernel/kernel-place.json, docs/blueprints/suiteui/features/placed-images.wave.json | packet acceptance row | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target is `dev` (CLAUDE.md, lead.md), not the brief's "base main": main b3011ab is an ancestor of dev, and the packets exist only on dev (#3426, #3432).
- v3 loop: the packet has a `## Slices` table; fix rounds capped at 2 per slice (contract rule 11).
- The contract slice waits on gradient-fill:GF-a (#3421 open, GF-2 not opened); a cross-feature wait is met only once its tasks merge (rule 12), so no task starts on an unmerged branch.
- GF-1 (#3421) merged on dev 9a14677. The packets give each gradient-fill:GF-a wait a per-task reason GF-1 alone meets (AH-1, PL-1: Tests/canonical-concepts.txt; SS-1: the Fill/ module and FillColor); GF-2 shares no file with them, so AH-1, SS-1 and PL-1 count GF-a's wait met. PL-2 still waits on GF-2 (SuiteGallery.swift). PL-1 runs after AH-1 (both edit canonical-concepts.txt). A slice is not one PR: AH-a is ~530 lines, over the 400 cap, so each task is its own PR and the first carries the disabled acceptance tests.

- 2026-10-20T08:49Z: PL-1 (#3578) folds some packet tests together to stay under 400 lines; place.reset-size and place.focus report nothing to do until PL-5 makes them act.

- PL-5 (#3598) hashes asset bytes with an inline FNV-1a: SuiteKernel links only Foundation and FlareCore, SuiteModel's fileKey hashes strings and CoreAsset's FNV is not linked; check-dup-logic passes. A zero natural size returns the canvas or box unchanged (no division by zero).

- PL-6 (#3599) flattens a placed SVG via core SVGImport then RenderList at frame 0, tolerance 0.25; stroke width follows the matrix scale; `skipped` also names text and clip-path, which the flattened paint does not draw. Fixtures are read through #filePath (no Package.swift change).

## Open
- PL-a also waits on autosave-history:AH-a (#3432 note); PL-7 on command-catalog:CC-run; PL-z on AH-z, transform-tools:TT-z, eyedropper:EY-z, shape-tools:SH-z, stroke-style:SS-d and GF-z.
- PL-2's waits met 2026-10-21: GF-2 merged (#3695), AH-a merged (#3568, #3629). Earlier heartbeats saying AH-a was not on dev were wrong.

- PL-m slice-done posted 2026-10-20 18:40 (Linux check 39473997761 on 299a29c, green). ui:false, so no Mac-Finish-Wanted.

## Run act-1a15b23f1eb-iz6h
Relaunched 2026-10-20T21:07Z. No slice is buildable: PL-2 still waits on GF-2 and AH-a.

- 2026-10-21T06:50Z: PL-2 opened as #3931 (296 lines, 7 files, scripts/ci --changed PASS on 3d5b67e). Place… is disabled with PlacePanel.unbuiltHelp until PL-3. The journey skips ("waits on PL-4").
- 2026-10-21: PL-3 opened as #3940 (397 lines vs PL-2, 6 files: the gallery page is wired so Place… isn't dead; scripts/ci --changed PASS on 2e8f630). Stacked on lead/placed-images-PL-2 because PL-2 + PL-3 against dev is over the 400-line cap. Retarget to dev once #3931 merges.
- 2026-10-21T06:46:10Z: the server re-appends a footer line to every PR body after the Head: line, even after a PATCH removes it; the lane strips it from the squash and still reads the marker (it dispatched the macOS build), so it is left as is.
- 2026-10-21T06:54:17Z: PL-4 #3942 leaves out journey steps 4 and 5 (edge and focus drags need PL-8's live page), the p95 timing test (perf-suites.txt is supervisor-only) and resizeLargeInThreeBodies (not in PL-4's acceptance).

## Run act-1a15e9d8ac8-27wz
Relaunched 2026-10-21T13:22:56Z. The lead branch was rebuilt on main 0dd23d6 (record files only). PL-4 #3942 (head 227f061) has a green macOS build (39601667831) and waits for a lane batch. PL-8 starts once #3942 merges. PL-9 waits on GF-z.

- 2026-10-21T15:00Z: The lead dir moved to docs/leads/suiteui-placed-images on lead/suiteui-placed-images, the names Belt reads. #3942 merged as 541cab6, and Linux check https://github.com/qbtrix/creative-apps/actions/runs/39617481529 on dev 08b378bc8 is green, so PL-u is merged-done. Belt-Slice-Done and Mac-Finish-Wanted are posted on #3457. PL-8 still waits on the PL-z slice deps (SH-z, TT-z, EY-z, AH-z, SS-d), none done yet. PL-9 waits on GF-z. No open findings carry Feature: placed-images.

- 16:38Z: heartbeat. Unchanged: waiting on upstream slices (see above); no open findings.

- 16:58Z: heartbeat. PL-z waits on upstream (SH-z, TT-z, EY-z, AH-z, SS-d, GF-z).

- 17:19Z: heartbeat. No change; still waiting (see the previous note).
- 2026-10-21T17:40Z: PL-8, PL-9 and PL-10 still wait on SH-z, TT-z, EY-z, AH-z and SS-d (PL-9 also on GF-z). No open findings.
- 2026-10-21T18:04Z: No change: PL-8, PL-9 and PL-10 still wait on their upstream slices. No open findings.
- 2026-10-21T18:23Z: No change: PL-8, PL-9 and PL-10 still wait on their upstream slices. No open findings.
- 18:54Z: No change: PL-8/9/10 wait on SH-z, TT-z, EY-z, AH-z, SS-d (PL-9 also GF-z).
- 19:13Z: No change: PL-8/9/10 wait on SH-z, TT-z, EY-z, AH-z, SS-d (PL-9 also GF-z).
