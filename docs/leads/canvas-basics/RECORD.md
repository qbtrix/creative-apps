# canvas-basics lead record

Issue: #1500 · Packet: docs/blueprints/design/features/canvas-basics.md
Run: act-1a153722cda-w61s (before: act-1a14fde5d4b-ss3f, act-1a14d285aef-3epc, act-1a145ed05dc-a83b) · Session: claude/design-shell-parity-wlqm8c (line lead: shell-parity, canvas-basics, files-history) · Started: 2026-10-16T18:15Z
Stage: 3 wave 6
Base: 25f6d3376f816cbc2639b02044ae8ff475be6fb9
Next: fix round 1 (wf_2c06ed4c-eff) on findings #3334-#3345; review again after its PRs merge; round 2 max; leftovers become gaps; then Belt-Contact-Sheet.
Last check: 2026-10-19T21:16Z: critic panels done. CB-b filed #3334-#3339 (9 confirmed, 4 refuted), CB-c filed #3340-#3345 (9 confirmed, 1 refuted). 12 open findings; fix round 1 started on dev cd44f3e.

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
| CB-6 | CB-b | 5 | window commits with measured extent; editor grows/wraps; journey on | DesignWindow.swift, DesignTextFont.swift, DesignTextEditor.swift, DesignTextArtwork.swift, DesignTextFitSnapshots.swift, +TextBox journey | design-text-fit snapshots, journey | #3208 | merged c6ad68f (#3208, 11:15Z) |
| CB-9 | CB-c | 6 | page rows, past-edge overlay; journey on; feature-done | DesignIntent.swift, DesignWindow.swift, DesignCanvas.swift, DesignInspectorPage.swift, DesignPastEdge.swift, DesignPageSnapshots.swift, +Page journey | design-inspector-page, design-canvas-past-edge, journey | #3224 | merged 15:18Z as a0de43b (fix round 1: @MainActor paintArtwork; macOS build 39258144713 green); awaiting a green design-scoped or full run |

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
- #3224 (CB-9) is based on lead/canvas-basics-CB-6 while #3208 is open: against dev it measured 17 files / 465 lines (CB-6 + CB-9), over the lane's 15/400 hard cap, which would strip fast-lane as not eligible. A non-dev base is skipped quietly by the lane. Alone it is 12 files, +210/-41.
- CB-9 snapshot is named design-inspector-page-size (design-inspector-page already existed); past-edge drawing reuses the canvas loop moved into paintArtwork in DesignCanvasMarks.swift; a pending-commit row is a check-dup-views exception (Allow-Dup-View line) with needs-ui #3223 for InspectorSliderRow(commit: .onEnd).
- 2026-10-19 (run act-1a153722cda-w61s): resumed. Waits met: design-window done (all of DW-a..DW-d), style-rows done (SR-t closed with gap #2545, a journey red, not missing code: DesignTextFont/Editor/Artwork carry ST-5t). The supervisor's 10-19 08:40Z note (CB-6 waits on #2480) predates reading style-rows' contact sheet; #2480 is a mac-finish PR on Align/Distribute and touches none of CB-6's files, so CB-6 doesn't wait on it. PRs still target dev (main 6f9a2b8 is behind dev; the lane's base is dev).
- CB-9 is stacked on CB-6's branch (rule 22) since both edit DesignWindow.swift's perform switch.
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
- needs-ui #3223 (line:suiteui): commit-on-end inspector row; CB-9's app-local row is a baselined exception until it lands.
- 2026-10-18T17:36Z: CB-3 PR #2871 opened 17:04Z, fast-lane label, body clean (no attribution). CB-5 builder brief must say: setTextStyle keeps the node's fixedWidth (copy the node's style, don't build a new one; several layers keep each their own flag).
- 2026-10-18T16:45Z (run act-1a14fde5d4b-ss3f): resumed. CB-2 merged (#2568, closed #1521). No open findings. design-window D0-9d and select-several S-5 wait on CB-a (CB-3), so CB-3 goes now. Brief says base main; PRs still target dev (every lane merge today is to dev; main is promoted from dev).
- Hand-off 2026-10-17T01:46Z: wave 1 merged (#1535, #1539, #1547, #1549); waves 2 to 6 not started, all waiting on other features. A new container needs `bash scripts/cloud-setup.sh` for Swift before any builder runs scripts/ci.
- Belt nudged at 00:53Z and 01:45Z although the branch had commits 2 and 10 min earlier; worth a look at the stall check.
- The PR tools append a 'Generated by' footer; the lead strips it with the GitHub MCP update_pull_request (gh api PATCH re-adds it).
- design-seams (#1493) lead started 2026-10-16T20:49Z (lead/design-seams), D0-3c planned in its wave 1, blocked on a missing Swift toolchain; pointed at scripts/cloud-setup.sh on #1493 (21:59Z), no reply. style-rows (#1497) and design-window (#1494) not started. Waves 2 to 6 wait on them.
- Belt nudge at 00:53Z although the last push was 00:51Z; RECORD.md is now rewritten on every check, not only the timeline.
