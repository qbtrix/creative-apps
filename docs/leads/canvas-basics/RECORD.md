# canvas-basics lead record

Issue: #1500 · Packet: docs/blueprints/design/features/canvas-basics.md
Run: act-1a145ed05dc-a83b · Session: claude/canvas-basics-lead-hkd6he · Started: 2026-10-16T18:15Z
Stage: 3 polling
Base: ee450291321d932aa3559298c4fe079089626552
Next: when design-seams (#1493) has merged D0-3c into dev, start wave 2: CB-2 alone, via docs/factory/workflows/build-wave.js copied to the scratchpad with the builder branch patched to `lead/canvas-basics-<task>` (a `lead/canvas-basics/<task>` ref can't sit beside this branch). CB-2's task text is the packet's CB-2 row and Acceptance row, mutations in the three plans it owns, Refs #1500, Closes #1521. Until then poll every 20 min and rewrite this file each time.
Last check: 2026-10-17T01:46Z, nothing to start. Run ended at its 8 h wall clock; a relaunched lead continues from Next.

## Slices
| slice | behavior | tasks | journeys | waits on | rounds | state | run |
|---|---|---|---|---|---|---|---|
| CB-a | draws, moves, resizes land on whole points; Text click-drag makes a box as wide as the drag | CB-1, CB-2, CB-3 | testDrawMoveResizeOnWholePoints, MJ9 | design-seams (CB-2, CB-3) | 0 | building | |
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
| CB-2 | CB-a | 2 | whole points for draw, move, resize; MJ9; journey on | DesignWholePoints.swift, DesignDrawing.swift, DesignCanvasEditing.swift, DesignWholePointsTests.swift, 3 plans, +WholePoints journey | DesignWholePointsTests | | waits design-seams, CB-1 |
| CB-3 | CB-a | 3 | Text click-drag fixed-width box; fixedWidth flag | StyleTypes.swift, DesignDrawing.swift, DesignCanvasEditing.swift, DesignTextBoxDrawTests.swift, 3 plans | DesignTextBoxDrawTests | | waits CB-2 |
| CB-5 | CB-b | 4 | commitTextEdit(extent:), setTextStyle refit | DesignText.swift, Live/LiveStyling.swift, DesignTextFitTests.swift, 2 plans | DesignTextFitTests | | waits CB-3, style-rows SR-m |
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
- v3 loop: the packet has a Slices table and this run started after #1302 merged.
- PRs target dev (CLAUDE.md, lead contract rule 4); the brief's "main" at 2e0f7df was verified, but the packet exists only on dev, and the lane retargets main to dev anyway.
- design-contracts counts as met: its wave.json reads "built" on dev and #1500 says so, though #1324 is still open waiting on its contact sheet.
- Status pushes go to lead/canvas-basics (contract rule 3); builder branches are lead/canvas-basics-<task> (a `lead/canvas-basics/<task>` ref cannot sit beside the `lead/canvas-basics` branch; the template copy is patched).
- The supervisor's 2026-10-16 note on #1500 (build UI and logic in parallel, the wave data may be re-sliced) is followed by reading the wave.json again before each wave; slice ids already reported done stay.
- Journey tasks (CB-1, CB-4, CB-7) are written blind and skipped by name; `-DesignFixture cards` isn't a launch argument yet (design-window brings it), which the skip covers.

## Open
- Hand-off 2026-10-17T01:46Z: wave 1 merged (#1535, #1539, #1547, #1549); waves 2 to 6 not started, all waiting on other features. A new container needs `bash scripts/cloud-setup.sh` for Swift before any builder runs scripts/ci.
- Belt nudged at 00:53Z and 01:45Z although the branch had commits 2 and 10 min earlier; worth a look at the stall check.
- The PR tools append a 'Generated by' footer; the lead strips it with the GitHub MCP update_pull_request (gh api PATCH re-adds it).
- design-seams (#1493) lead started 2026-10-16T20:49Z (lead/design-seams), D0-3c planned in its wave 1, blocked on a missing Swift toolchain; pointed at scripts/cloud-setup.sh on #1493 (21:59Z), no reply. style-rows (#1497) and design-window (#1494) not started. Waves 2 to 6 wait on them.
- Belt nudge at 00:53Z although the last push was 00:51Z; RECORD.md is now rewritten on every check, not only the timeline.
