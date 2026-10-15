# photo-crop lead record

Issue: #1076 · Packet: docs/blueprints/photo/features/photo-crop.md
Run: act-1a13f70ddc3-29wr · Session: lead session (claude/photo-crop-feature-lead-e7vpmg) · Started: 2026-10-15T12:03Z
Stage: 3 wave 1
Base: 7f6125962f93be8898cec4fd2a78e75bac280b39
Next: wait for CP-1's PR to merge, then build wave 2 (CP-2) on the new origin/dev.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| CP-1 | 1 | LiveCropSizing: typed fields, locked drag, applying and swapping an aspect | Sources/PhotoModel/Live/LiveCrop.swift, Tests/PhotoModelTests/LiveCropSizingTests.swift | LiveCropSizingTests | – | building |
| CP-2 | 2 | Workspace setCropField/setCropAspect/swapCropAspect/cropFieldsEnabled/cropFieldValue/cropAspectBadge; drag keeps lock | Sources/PhotoModel/PhotoCropSize.swift, Tests/PhotoModelTests/PhotoCropSizeTests.swift | PhotoCropSizeTests (incl. dragUpdatesEveryEvent, typedCropMatchesCropped) | – | waits CP-1 |
| CP-3 | 3 | Budget PB-8 (crop drag + typed field) on large | Tests/PhotoModelTests/PhotoCropBudgetTests.swift | PhotoCropBudgetTests.cropDragAndField | – | waits CP-2 |
| CP-4 | 3 | Crop options: 2x2 ScrubField grid, six aspect chips, Swap, Apply (no .defaultAction), Cancel; window crop intents | Sources/PhotoApp/CropOptions.swift, Sources/PhotoApp/PhotoWindow+Crop.swift, Tests/AppSnapshotTests/PhotoCropOptionsSnapshots.swift | PhotoCropOptionsSnapshots (+gridAligned) | – | waits CP-2 |
| CP-5 | 4 | Aspect pill on crop overlay; journey PJ-8 (feature-done) | Sources/PhotoApp/CropOverlay.swift, UITests/PhotoJourneyTests+Crop.swift | PJ-8 testTypedCropSizeAndAspect | – | waits CP-4, photo-journey-kit #1073 |
| CP-7 | 4 | Perf journeys PJ-P1 (brush, crop, pan) and PJ-P2 (Exposure scrub) | UITests/PhotoJourneyTests+Perf.swift | testCanvasDragLatency, testSliderScrubLatency | – | waits photo-journey-kit #1073 |

Waves: 1 = CP-1 (independent). 2 = CP-2 (waits CP-1). 3 = CP-3, CP-4 (independent of each other; both wait CP-2). 4 = CP-5, CP-7 (independent of each other; both wait photo-journey-kit; CP-5 waits CP-4).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- CP-7 moved from wave 1 to wave 4: the packet's wave 1 places it there, but it waits on photo-journey-kit (#1073), still open at start; it builds once #1073 closes.
- Task branches are named lead/photo-crop-<id> (a ref lead/photo-crop/<id> cannot coexist with lead/photo-crop).
- Wave 1 has one task, so it runs as one worktree subagent, not the build-wave workflow.

## Open
- photo-journey-kit #1073 open (blocks CP-5, CP-7).
