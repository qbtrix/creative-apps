# design-window lead record

Issue: #1494 · Packet: docs/blueprints/design/features/design-window.md
Run: act-1a14801a0f5-htqa · Session: 2f69baa5-b59f-5f22-b23e-b03fb33d3e02 · Started: 2026-10-17T03:58Z
Stage: 3 wave 1
Base: 0e3c08ea52648f6654e583a64ddf07ccb5aa328c (origin/dev; moved from c5efa4eb by #1965, #1966, #1967, #1968, #1969, #1943, #1932, none touching Design or SuiteUI)
Next: wave 1 PRs (D0-5a, D0-5b, D0-9a, D0-9b) to merge through the lane, then wave 2

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DW-a | tier-1 commands in menus, inspector and canvas, wired to actions, "isn't built yet." on live | D0-5a, D0-5b, D0-5c, D0-5d, D0-6 | J1 | design-contracts (built); shell-parity (SP2 built, SuiteWindow on Design verified in code) | yes | 0 | building | – | wanted after done |
| DW-b | canvas drag redraws only the canvas; editor body ≤3 runs over 120 samples | D0-8a, D0-8b | J3 | DW-a | yes | 0 | planned | – | – |
| DW-d | hover outline, size badge, pointers, Text preview | D0-9a, D0-9b, D0-9c, D0-9d | testCanvasFeedback | DW-a (D0-9c); DW-b (D0-9d); canvas-basics CB-a (D0-9d) | yes | 0 | planned | – | – |
| DW-c | every enabled control acts, every disabled says why; layout at widths | D0-7a, D0-7b | J15, testLayoutAtWidths | DW-b (D0-7a); DW-a, DW-d (D0-7b) | yes | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| D0-5a | DW-a | 1 | DesignWindowOptions, openFixture, DesignControlID, intents, launch args, zoom to selection, selection count, DesignSaveStatus slot | Sources/DesignModel/DesignWindowOptions.swift, Sources/DesignApp/{DesignIntent,DesignWindow,DesignEditor,DesignSaveStatus}.swift | Tests/DesignModelTests/DesignWindowOptionsTests.swift | – | ready |
| D0-5b | DW-a | 1 | canvas marks, selection marks, frame-label and text slots, feedback slot, show param | Sources/DesignApp/{DesignCanvas,DesignCanvasMarks,DesignSelectionMarks,DesignFrameLabels,DesignTextArtwork,DesignCanvasFeedback}.swift | Tests/AppSnapshotTests/DesignCanvasSeamSnapshots.swift | – | ready |
| D0-9a | DW-d | 1 | testCanvasFeedback written, XCTSkip until D0-9d | UITests/DesignJourneyTests+Feedback.swift | the journey (skipped) | – | ready |
| D0-9b | DW-d | 1 | DesignCanvasHints: pointer, hover, badge text | Sources/DesignModel/DesignCanvasHints.swift | Tests/DesignModelTests/DesignCanvasHintsTests.swift | – | ready |
| D0-5c | DW-a | 2 | several-layer inspector shell, Align row, Mixed rows | Sources/DesignApp/{DesignInspector,DesignAlignBar,DesignInspectorText,DesignInspectorPage}.swift | DesignSeveralInspectorSnapshots.swift | – | waits D0-5a |
| D0-5d | DW-a | 2 | pasteboard bridge, copy/cut/paste hooks, Layers rename state, close prompt slot | Sources/DesignApp/{DesignPasteboardBridge,DesignWindow,DesignCanvas,DesignLayersPanel,DesignClosePrompt}.swift | DesignPasteboardBridgeTests.swift | – | waits D0-5a, D0-5b |
| D0-6 | DW-a | 2 | menus: Duplicate, Rename Page, Group/Ungroup/Arrange/Distribute, Zoom to Selection, disabled help | Sources/DesignApp/{DesignCommands,DesignEditMenu,DesignObjectMenu}.swift; UITests/DesignJourneyTests.swift | DesignEditMenuSnapshots.swift, DesignPageMenuSnapshots.swift | – | waits D0-5a |
| D0-9c | DW-d | 2 | hover outline and pointers in the feedback slot | Sources/DesignApp/DesignCanvasFeedback.swift | DesignCanvasHoverTests.swift | – | waits D0-5b, D0-9b |
| D0-8a | DW-b | 3 | live drag box in DesignLiveDrag | Sources/DesignApp/{DesignLiveDrag,DesignCanvas,DesignWindow}.swift | DesignLiveDragTests.swift | – | waits D0-5d |
| D0-8b | DW-b | 4 | bodyRuns counter, 120-sample drag check | Sources/DesignApp/DesignEditor.swift | DesignWindowDragTests.swift | – | waits D0-8a |
| D0-7a | DW-c | 5 | window control ids and suiteControl registrations | Sources/DesignApp/{DesignWindow,DesignEditor,DesignCanvas}.swift; DesignWindowOptions.swift | DesignControlIDTests.swift | – | waits D0-8b |
| D0-9d | DW-d | 5 | size badge from live box, Text placement preview, turns journey on | Sources/DesignApp/DesignCanvasFeedback.swift; badge snapshots | DesignCanvasBadgeTests.swift | – | waits D0-8b, D0-9a, D0-9c, canvas-basics CB-a (not merged) |
| D0-7b | DW-c | 6 | J15 sweep and layout journey; feature-done | UITests/DesignJourneyTests+EveryControl.swift, +Layout.swift | the journeys | – | waits D0-6, D0-7a, D0-9d |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Branch base is origin/dev (CLAUDE.md: never branch from or target main). The brief's "integration branch: main" is read as "main is the verified base the packet names"; dev contains it.
- RECORD and timeline live on claude/design-window-lead-6b46nb, the branch the session was given. Belt reads lead/design-window; that branch is not created without permission.
- Builders run as Agent-tool subagents in worktrees, one per task, not via build-wave.js (the Workflow tool was not opted into for this run).
- Wave 1 is D0-5a, D0-5b, D0-9a, D0-9b (all independent; D0-5a's shell-parity wait is met: SuiteWindow is on Design's window in code).
- D0-9d waits on canvas-basics CB-a, which has not merged (canvas-basics status: planned). This holds D0-9d, D0-7b and the feature-done step until it merges.

## Open
- Blocked: D0-9d and everything after it (D0-7b, feature-done) until canvas-basics CB-a merges.
- The packet's needs-ui issue ("SuiteUI: a mixed state on ScrubField") is not yet filed; file at stage 1 per packet.
- Nothing on this feature has been built on macOS; all UI tasks are built blind and need the lane's build-only run and the Mac finisher.
- Base moved to 0e3c08ea (dev). Builders from wave 1 attempt 1 stopped on the base check with no work, so wave 1 is relaunched from 0e3c08ea.
