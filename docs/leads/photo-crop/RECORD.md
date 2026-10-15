# photo-crop lead record

Issue: #1076 · Packet: docs/blueprints/photo/features/photo-crop.md
Run: act-1a13f70ddc3-29wr · Session: lead session (claude/photo-crop-feature-lead-e7vpmg) · Started: 2026-10-15T12:03Z
Stage: 4 round 4 (wave 4 still waits on photo-journey-kit #1073)
Base: 469520e8def2fe925a065aa8d5febda827851131
Next: rounds done (4 of 4). Wait for #1202 to merge and a dev run to show photo contrast at 0; when #1073 lands when #1073 closes (UITests/PhotoJourneyTests+Fixtures.swift on dev), build CP-5 and CP-7 together; meanwhile read the first dev CI run containing 469520e (#1151) for round-1 material.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| CP-1 | 1 | LiveCropSizing: typed fields, locked drag, applying and swapping an aspect | Sources/PhotoModel/Live/LiveCrop.swift, Tests/PhotoModelTests/LiveCropSizingTests.swift | LiveCropSizingTests | #1132 | merged |
| CP-2 | 2 | Workspace setCropField/setCropAspect/swapCropAspect/cropFieldsEnabled/cropFieldValue/cropAspectBadge; drag keeps lock | Sources/PhotoModel/PhotoCropSize.swift, Tests/PhotoModelTests/PhotoCropSizeTests.swift | PhotoCropSizeTests (incl. dragUpdatesEveryEvent, typedCropMatchesCropped) | #1141 | merged |
| CP-3 | 3 | Budget PB-8 (crop drag + typed field) on large | Tests/PhotoModelTests/PhotoCropBudgetTests.swift | PhotoCropBudgetTests.cropDragAndField | #1149 | merged |
| CP-4 | 3 | Crop options: 2x2 ScrubField grid, six aspect chips, Swap, Apply (no .defaultAction), Cancel; window crop intents | Sources/PhotoApp/CropOptions.swift, Sources/PhotoApp/PhotoWindow+Crop.swift, Tests/AppSnapshotTests/PhotoCropOptionsSnapshots.swift | PhotoCropOptionsSnapshots (+gridAligned) | #1151 | merged |
| CP-5 | 4 | Aspect pill on crop overlay; journey PJ-8 (feature-done) | Sources/PhotoApp/CropOverlay.swift, UITests/PhotoJourneyTests+Crop.swift | PJ-8 testTypedCropSizeAndAspect | – | waits CP-4, photo-journey-kit #1073 |
| CP-7 | 4 | Perf journeys PJ-P1 (brush, crop, pan) and PJ-P2 (Exposure scrub) | UITests/PhotoJourneyTests+Perf.swift | testCanvasDragLatency, testSliderScrubLatency | – | waits photo-journey-kit #1073 |

Waves: 1 = CP-1 (independent). 2 = CP-2 (waits CP-1). 3 = CP-3, CP-4 (independent of each other; both wait CP-2). 4 = CP-5, CP-7 (independent of each other; both wait photo-journey-kit; CP-5 waits CP-4).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38742226941 (head 20d6a1c) | red: our gridAligned (frames[photo.crop.x] nil); Halo keyedFrame6 not ours (#1163) | n/a (journeys did not run) | clarity, design, layout, controls | 5 major + 6 minor (fields read 0 px; two captions; layout shift; Swap dead under 1:1; swapped orientation unreadable; X/Y 0 refused; empty tooltips; Original unexplained; disabled reasons disagree) | r1-b1 #1164 merged (gridAligned via anchor preference), r1-b2 #1170 merged (panel clarity) | no |
| 1 check | 38746333198 (head e6490aa) | gridAligned passes; Photo green; remaining red is Halo only (keyedFrame6, HaloPlaybackDriverTests), not ours | n/a | – | – | – | – |
| 2 | 38757068610 (head 111c440) | red only on Halo keyedFrame6 (not ours); Photo green | n/a (journeys did not run) | clarity, design, layout, controls | 2 major (locked field snaps back; Apply on a whole-image crop) + minors (reasons disagree, chip group tooltip empty, caption casing) | r2-b1 #1186 merged | no |
| 3 | 38761014883 (head 86fe18c) | red only on Halo keyedFrame6 (not ours); all crop suites green | n/a (journeys did not run) | clarity, design, layout, controls | 4 minor (Swap tooltip bare; caption says 'shape'; uneven row gaps; half-width Apply/Cancel) | r3-b1 #1192 merged | yes |
| 4 | 38767265986 (head d95c756) | scripts/ci PASS on macOS; journeys ran; Photo journey testEveryToolEditsTheImage red on audit; Library/Halo journey failures not ours | photo contrast 3 over baseline 0 (dimmed X/Y labels of disabled crop fields on photo-crop-pending, photo-cropped) | clarity, design, layout, controls | panel clean: 4 minor (caption names ratio, Swap fallback title, 13 pt shift, chip-grid gaps) → gap #1203-#1205 | r4-b1 #1202 (audit contrast, combined field elements) | no (audit) |

## Decisions
- r1-b2: fields follow cropFieldsEnabled, so a locked shape with no pending crop takes typing (model supported it; matches the caption). Kept.
- r1-b2: per-chip help (Original's ratio) needs ChoiceChips help support; cropAspectHelp exists in the model, unused on screen. Minor, left.
- Round 1: X/Y accept 0 (the packet's 'under 1 is refused' meant sizes; an X/Y range starting at 0 that refuses 0 is a dead value).
- Round 1: until ScrubField has a placeholder (needs-ui), the empty fields show the whole image's rect, read with the caption.
- Round 1: light/dark crop snapshots are byte-identical because the editor shell is dark in both; outside this feature, not fixed.
- CP-4 also removed Cancel's .cancelAction (would steal Escape from a typing field); Escape on the canvas still cancels via .dismiss.
- CP-4 changed one line in UITests/PhotoJourneyTests.swift (Apply's identifier is now photo.crop.apply).
- CP-7 moved from wave 1 to wave 4: the packet's wave 1 places it there, but it waits on photo-journey-kit (#1073), still open at start; it builds once #1073 closes.
- Task branches are named lead/photo-crop-<id> (a ref lead/photo-crop/<id> cannot coexist with lead/photo-crop).
- Wave 1 has one task, so it runs as one worktree subagent, not the build-wave workflow.

## Open
- gap issues filed at the round budget: #1203 (13 pt shift), #1204 (caption/Swap wording), #1205 (chip-grid gaps), #1206 (per-chip tooltips), #1207 (status bar selection px / selection under crop).
- Round 2 minors left alone: overlay has no handles/accent edge (CP-5 / SuiteUI CropShade); status bar 'Selection 220 × 160' lacks px and a prior selection stays drawn under a pending crop (PhotoInspectorContent, not this feature's files). File as gap if still open at finish.
- #1169 needs-ui: ScrubField placeholder for a nil value.
- CropOptions.emptyCaption is unused by the view but still asserted by PhotoCropOptionsSnapshots; remove both in a later batch.
- Issue comments posted from this session get a Generated-by footer re-appended server-side (PATCH can't remove it); the #763 comment carries one. PR bodies can be cleaned.
- #1148 needs-ui: per-chip identifiers on ChoiceChips; until then PJ-8 finds aspect chips by title.
- Round 1 check: setCropField refuses X/Y 0 (contract: value under 1 is refused for every field), so X 0 beeps; judge in the critic panel.
- Round 1 check: gridAligned reads the accessibility tree of a hosting view; may need a harness fix if empty on macOS.
- The GitHub MCP PR tool appends a Generated-by footer; #1141's was removed by editing the body. Builders now strip it after opening.
- photo-journey-kit #1073 open (blocks CP-5, CP-7).
