# canvas-basics lead record

Issue: #1500 · Packet: docs/blueprints/design/features/canvas-basics.md
Run: act-1a14fde5d4b-ss3f (before: act-1a14d285aef-3epc, act-1a145ed05dc-a83b) · Session: claude/design-shell-parity-wlqm8c (line lead: shell-parity, canvas-basics, files-history) · Started: 2026-10-16T18:15Z
Stage: 4 wave 4
Base: e3c46ea8e11e0ad32ee3c236edde57198f4567a2
Next: CB-a merged-done (Belt-Slice-Done posted, run 39152649677). CB-5 PR #2897 merged 20:05Z (94d162c, lane batch run 39160874078). CB-6 and CB-9 wait on style-rows SR-t (itself waiting on design-window DW-a, #2480 open) and design-window DW-a (#2899 D0-9d merged as e3859e3f). No open findings, no dev-red (checked 08:34Z: #2480 stalled, head Linux red since 10-18 00:19Z; supervisor asked on #1500 comment 6257753581).
Last check: 2026-10-18T16:45Z

## Slices
| slice | behavior | tasks | journeys | waits on | rounds | state | run |
|---|---|---|---|---|---|---|---|
| CB-a | draws, moves, resizes land on whole points; Text click-drag makes a box as wide as the drag | CB-1, CB-2, CB-3 | testDrawMoveResizeOnWholePoints, MJ9 | design-seams (CB-2, CB-3) | 0 | merged-done | Belt-Slice-Done 18:38Z, run 39152649677 |
| CB-b | text boxes fit their text (auto grows, fixed wraps), a size change refits | CB-4, CB-5, CB-6 | testTextBoxFitsItsText | CB-a, style-rows SR-m (CB-5); style-rows SR-t, design-window (CB-6) | 0 | building | |
| CB-c | layers past the page show dimmed; page width and height editable, one step each | CB-7, CB-8, CB-9 | testPageSizeAndPastThePage | design-window, CB-b (CB-9) | 0 | building | |

Gap issues (one per slice, filed at stage 1): CB-a #1521 (CB-2 closes), CB-b #1522 (CB-6 closes), CB-c #1523 (CB-9 closes).

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CB-1 | CB-a | 1 | CB-a journey, XCTSkip("waits on CB-2") | UITests/DesignJourneyTests+WholePoints.swift | journey compiles, skips by name | #1535 | merged |
| CB-4 | CB-b | 1 | CB-b journey, XCTSkip("waits on CB-6") | UITests/DesignJourneyTests+TextBox.swift | journey compiles, skips by name | #1547 | merged |
| CB-7 | CB-c | 1 | CB-c journey, XCTSkip("waits on CB-9") | UITests/DesignJourneyTests+Page.swift | journey compiles, skips by name | #1549 | merged |
| CB-8 | CB-c | 1 | setPageSize, contentBounds, isPastEdge | DesignPageSize.swift, DesignPageSizeTests.swift, Tests/mutations/DesignModel.DesignPageSize.json | DesignPageSizeTests (Mutate 6/6) | #1539 | merged |
| CB-2 | CB-a | 2 | whole points for draw, move, resize; MJ9; journey on | DesignWholePoints.swift, DesignDrawing.swift, DesignCanvasEditing.swift, DesignWholePointsTests.swift, 3 plans, +WholePoints journey | DesignWholePointsTests | #2568 | merged 7c20424 |
| CB-3 | CB-a | 3 | Text click-drag fixed-width box; fixedWidth flag | StyleTypes.swift, DesignDrawing.swift, DesignCanvasEditing.swift, DesignTextBoxDrawTests.swift, 3 plans | DesignTextBoxDrawTests | #2871 (080dea8) | merged 18:01Z (4a3e5a0) |
| CB-5 | CB-b | 4 | commitTextEdit(extent:), setTextStyle refit | DesignText.swift, Live/LiveStyling.swift, DesignTextFitTests.swift, 2 plans | DesignTextFitTests | #2897 (4269cd4) | merged 20:05Z (94d162c) |
| CB-6 | CB-b | 5 | window commits with measured extent; editor grows/wraps; journey on | DesignWindow.swift, DesignTextFont.swift, DesignTextEditor.swift, DesignTextArtwork.swift, DesignTextFitSnapshots.swift, +TextBox journey | design-text-fit snapshots, journey | | waits CB-4, CB-5, SR-t, design-window |
| CB-9 | CB-c | 6 | page rows, past-edge overlay; journey on; feature-done | DesignIntent.swift, DesignWindow.swift, DesignCanvas.swift, DesignInspectorPage.swift, DesignPastEdge.swift, DesignPageSnapshots.swift, +Page journey | design-inspector-page, design-canvas-past-edge, journey | | waits CB-6, CB-7, CB-8, design-window |

Waves (packet's Build waves, checked against dev b01e722):
- Wave 1: CB-1, CB-4, CB-7, CB-8. All independent (disjoint new files; design-contracts is built).
- Wave 2: CB-2 alone. Waits on design-seams (D0-3c owns the gesture routes in DesignCanvasEditing.swift) and CB-1 (turns its journey on).
- Wave 3: CB-3 alone. Waits on CB-2: same DesignDrawing.swift and DesignCanvasEditing.swift.
- Wave 4: CB-5 alone. Waits on CB-3 (reads its fixedWidth flag) and style-rows SR-m (DesignText.swift, LiveStyling.swift).
- Wave 5: CB-6 alone. Waits on CB-4, CB-5 (calls commitTextEdit(extent:)), style-rows SR-t and all of design-window.
- Wave 6: CB-9 alone, feature-done. Waits on CB-6 (DesignWindow.swift's perform switch), CB-7, CB-8 and all of design-window.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-18T04:02Z (run act-1a14d285aef-3epc): resumed as line lead. design-seams is done (D0-3c #2167 merged), so CB-2 starts, alongside files-history FH-2 (disjoint files). style-rows SR-m is done (CB-5 can go after CB-3); SR-t and design-window DW-b/DW-c/DW-d are still building, so CB-6 and CB-9 wait. This branch is 15 commits behind dev; it holds only docs/leads/canvas-basics, so it is left as is.
- v3 loop: the packet has a Slices table and this run started after #1302 merged.
- PRs target dev (CLAUDE.md, lead contract rule 4); the brief's "main" at 2e0f7df was verified, but the packet exists only on dev, and the lane retargets main to dev anyway.
- design-contracts counts as met: its wave.json reads "built" on dev and #1500 says so, though #1324 is still open waiting on its contact sheet.
- Status pushes go to lead/canvas-basics (contract rule 3); builder branches are lead/canvas-basics-<task> (a `lead/canvas-basics/<task>` ref cannot sit beside the `lead/canvas-basics` branch; the template copy is patched).
- The supervisor's 2026-10-16 note on #1500 (build UI and logic in parallel, the wave data may be re-sliced) is followed by reading the wave.json again before each wave; slice ids already reported done stay.
- Journey tasks (CB-1, CB-4, CB-7) are written blind and skipped by name; `-DesignFixture cards` isn't a launch argument yet (design-window brings it), which the skip covers.
- 2026-10-18T17:36Z: CB-3 keeps a tall drag's height (packet pseudocode: height >= default), not a fixed 24; test aTallDragKeepsItsHeight pins it.
- 2026-10-18T18:40Z: CB-5 notes from the builder, accepted: committing an existing text node records "Edit Text" when only its fitted frame changes; a same-size style change leaves the frame; setTextStyle keeps each node's fixedWidth, so only the Text drag (CB-3) sets it.

## Open
- 2026-10-18T17:36Z: CB-3 PR #2871 opened 17:04Z, fast-lane label, body clean (no attribution). CB-5 builder brief must say: setTextStyle keeps the node's fixedWidth (copy the node's style, don't build a new one; several layers keep each their own flag).
- 2026-10-18T16:45Z (run act-1a14fde5d4b-ss3f): resumed. CB-2 merged (#2568, closed #1521). No open findings. design-window D0-9d and select-several S-5 wait on CB-a (CB-3), so CB-3 goes now. Brief says base main; PRs still target dev (every lane merge today is to dev; main is promoted from dev).
- Hand-off 2026-10-17T01:46Z: wave 1 merged (#1535, #1539, #1547, #1549); waves 2 to 6 not started, all waiting on other features. A new container needs `bash scripts/cloud-setup.sh` for Swift before any builder runs scripts/ci.
- Belt nudged at 00:53Z and 01:45Z although the branch had commits 2 and 10 min earlier; worth a look at the stall check.
- The PR tools append a 'Generated by' footer; the lead strips it with the GitHub MCP update_pull_request (gh api PATCH re-adds it).
- design-seams (#1493) lead started 2026-10-16T20:49Z (lead/design-seams), D0-3c planned in its wave 1, blocked on a missing Swift toolchain; pointed at scripts/cloud-setup.sh on #1493 (21:59Z), no reply. style-rows (#1497) and design-window (#1494) not started. Waves 2 to 6 wait on them.
- Belt nudge at 00:53Z although the last push was 00:51Z; RECORD.md is now rewritten on every check, not only the timeline.
