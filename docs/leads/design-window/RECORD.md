# design-window lead record

Issue: #1494 · Packet: docs/blueprints/design/features/design-window.md
Run: act-1a14a88d756-rnok · Session: claude/design-feature-lead-7saqm8 · Started: 2026-10-17T15:46Z
Stage: 3 wave 3
Base: 6ad373ab37fb612a8e7b185f902c263211f1197b
Next: lane: #2468 (#2455 #2406 #2352), #2464 (#2075), #2462 (#2411); #2302 waits SuiteUI #2263; then a scoped design run proves them; D0-7b held until findings <=5

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DW-a | launch options, control ids, canvas and inspector slots, pasteboard bridge, menus | D0-5a, D0-5b, D0-5c, D0-5d, D0-6 | J1 | – | yes | 1 | merged; check waits on run 39062516417 (39061216116 cancelled) | – | – |
| DW-b | the live drag box; editor body counter and 120-sample drag check | D0-8a, D0-8b | J3 | DW-a | yes | 0 | building | – | – |
| DW-d | canvas feedback: hover, pointers, size badge, text preview | D0-9a, D0-9b, D0-9c, D0-9d | testCanvasFeedback | DW-a, DW-b; canvas-basics CB-a (D0-9d) | yes | 1 | building (fix round 1: #2280 macOS build) | – | – |
| DW-c | probes and ids on every window control; J15 sweep, layout journey | D0-7a, D0-7b | J15, testLayoutAtWidths | DW-a, DW-b, DW-d | yes | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| D0-9a | DW-d | 0 | testCanvasFeedback, XCTSkip("waits on D0-9d") | UITests/DesignJourneyTests+Feedback.swift | journey compiles, skips | #1979 | merged |
| D0-9b | DW-d | 0 | DesignCanvasHints model | Sources/DesignModel/DesignCanvasHints.swift; Tests/DesignModelTests/DesignCanvasHintsTests.swift; Tests/mutations/DesignModel.DesignCanvasHints.json | DesignCanvasHintsTests | #1980 | merged |
| D0-5a | DW-a | 1 | DesignWindowOptions, openFixture, DesignControlID, new intents and perform, launch args | Sources/DesignModel/DesignWindowOptions.swift; Sources/DesignApp/DesignIntent.swift, DesignWindow.swift, DesignEditor.swift, DesignSaveStatus.swift; Tests/DesignModelTests/DesignWindowOptionsTests.swift; Tests/AppSnapshotTests/DesignStatusSnapshots.swift; Tests/mutations/DesignModel.DesignWindowOptions.json | DesignWindowOptionsTests, design-status-two-layers | #2168 | merged ac6fac76 |
| D0-5b | DW-a | 1 | canvas slots: marquee mark, selection marks, DesignFrameLabels, DesignTextArtwork, empty DesignCanvasFeedback | Sources/DesignApp/DesignCanvas.swift; Sources/DesignApp/DesignCanvasMarks.swift; Sources/DesignApp/DesignSelectionMarks.swift; Sources/DesignApp/DesignFrameLabels.swift; Sources/DesignApp/DesignTextArtwork.swift; Sources/DesignApp/DesignCanvasFeedback.swift; Tests/AppSnapshotTests/DesignCanvasSeamSnapshots.swift | DesignCanvasSeamSnapshots | #2163 | merged 53e3127e |
| D0-5c | DW-a | 2 | several-layer inspector shell, Mixed rows, ids | per packet | DesignSeveralInspectorSnapshots | #2217 | merged 18:15Z |
| D0-5d | DW-a | 2 | DesignPasteboardBridge, copy/cut/paste hooks, rename state, DesignClosePrompt | per packet | DesignPasteboardBridgeTests | #2214 | merged 18:26Z |
| D0-6 | DW-a | 2 | menus: Duplicate, Rename Page, Group, Ungroup, Arrange, Distribute, Zoom to Selection | DesignCommands.swift, DesignEditMenu.swift, DesignObjectMenu.swift; snapshots; J1 | DesignEditMenuSnapshots, J1 | #2213 | merged 18:59Z (b2942150) |
| D0-8a | DW-b | 3 | DesignLiveDrag box | DesignLiveDrag.swift, DesignCanvas.swift, DesignWindow.swift; DesignLiveDragTests | DesignLiveDragTests | #2282 | open (head 7a79105b), waits on the lane |
| D0-9c | DW-d | 3 | hover outline and pointers in DesignCanvasFeedback | DesignCanvasFeedback.swift; snapshots; DesignCanvasHoverTests | DesignCanvasFeedbackSnapshots | #2280 | open; build 39062505918 failed (switch with a multi-statement case lost implicit returns), fixed in c76da704, waits on the lane |
| D0-8b | DW-b | 4 | editor bodyRuns counter, 120-sample drag check | DesignEditor.swift; DesignWindowDragTests | DesignWindowDragTests | – | waits D0-8a |
| D0-7a | DW-c | 5 | suiteProbes and ids on window controls | DesignWindow.swift, DesignEditor.swift, DesignCanvas.swift, DesignControlID.swift; DesignControlIDTests | DesignControlIDTests | – | waits DW-b |
| D0-9d | DW-d | 5 | size badge from the live box, text preview; testCanvasFeedback on | DesignCanvasFeedback.swift; snapshots; DesignCanvasBadgeTests; +Feedback journey | DesignCanvasBadgeTests | – | waits D0-8b, D0-9c, canvas-basics CB-a |
| D0-7b | DW-c | 6 | J15 sweep and layout journey; feature-done | UITests/DesignJourneyTests+EveryControl.swift, +Layout.swift | J15, testLayoutAtWidths | – | waits D0-6, D0-7a, D0-9d |

Wave 1: D0-5a and D0-5b are independent (disjoint files; neither calls the other's code: the canvas slots read only the existing Model). C-2 (copy-group) runs beside them.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main (CLAUDE.md: never branch from or target main; the lane retargets main to dev). main was verified at 2c5003b as the brief asks.
- D0-9a (#1979) and D0-9b (#1980) already merged; DW-d continues at D0-9c.
- Builder branches are lead/design-window-<task>: a lead/design-window/<task> ref can't sit beside the lead/design-window branch.
- gh CLI has no valid token in this container; agents use the GitHub MCP tools for issues and PRs.
- Rule 20, #2168: DesignWindowOptions.size(_:) repeats SuiteUI's six-line WxH parse. Accepted: it is not a kernel concept, the packet requires the test to run on Linux, and SuiteUI is macOS-only. Gap #2171 (line:suiteui) moves the parse into SuiteModel so every app shares one copy.
- Rule 20, #2163: DesignSelectionMarks.swift (view marks only, a filename the packet names) goes through lead.md's exception path, with an Allow-Dup line and a canonical-baseline entry. Accepted. Its C4 part description edit is needed for the ownership rule.
- The PR tool appends an attribution footer. The lead stripped it from #2166, #2168 and #2163, and build-wave builders now strip it themselves.

## Open
- D0-9d (so DW-d, and D0-7b, so DW-c) waits on canvas-basics CB-a, which waits on design-seams D0-3c. design-seams (#1493) has not built wave 1; its RECORD stalls on a missing Swift toolchain.
- needs-ui #2148: SuiteUI ScrubField mixed state; D0-5c uses plain "Mixed" text meanwhile.
- #2282 (D0-8a) adds Sources/DesignModel/DesignLiveEdit.swift, its Linux tests and a 6-mutation plan beyond the packet's four files. Accepted: the lead's brief told the builder to put the replay logic in DesignModel with a test and a plan (CLAUDE.md: logic in the Model); DesignLiveDrag in DesignApp only wraps it. The contract check's file-scope flag is answered by this note.
- #2280 (D0-9c) leaves the DesignEditor body-count assertion as TODO(D0-8b): the counter arrives with D0-8b. It asserts DesignWindow body runs 0 and canvas reads at most 1 now. D0-8b's builder turns the TODO into an assertion.
