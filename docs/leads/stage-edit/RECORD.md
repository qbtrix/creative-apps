# stage-edit lead record

Issue: #1514 · Packet: docs/blueprints/flare/features/stage-edit.md
Run: act-1a157ad4612-4xcw · Session: claude/feature-lead-playbook-dp4pbl · Started: 2026-10-16T18:20Z (resumed 2026-10-19T12:00Z; resumed 2026-10-20 under act-1a157ad4612-4xcw, line lead: stage-edit #1514, stroke-style #3452)
Stage: SE-5b waiting
Base: 18464f26 (origin/dev)
Next: gate #3312's head a0054178, move its Head: line, lift no-fast-lane; Belt-Contact-Sheet on #1514 after it merges and dev CI is green

## Slices
No `## Slices` table: v2 packet, v2 loop applies.

## Tasks
| task | wave | behavior | files | waits on | PR | state |
|---|---|---|---|---|---|---|
| SE-4 | 1 | bringForward / sendBackward / orderHelp over the existing moveLayer; refusals "Already at the front." and "Background is locked." | Sources/FlareModel/FlareEditOrder.swift, Tests/FlareModelTests/FlareEditOrderTests.swift | – | #2534 | merged |
| SE-2a | 1 | FlareZoom steps and readout, guideReadout (Model half of SE-2) | Sources/FlareModel/FlareViewMath.swift, Tests/FlareModelTests/FlareViewMathTests.swift | – | #2532 | merged |
| SE-0 | 3 | handle hit-test and box drag | FlareBoxDrag.swift, FlareDrag.swift, FlareSelection.swift, FlareBoxDragTests | EK-box | #2740 | merged |
| SE-1 | 3 | SelectionReadout and FlareStageSelection | packet | SE-0, #273 | #2774 | merged (bf3ee823) |
| SE-2b | – | guides view, ruler toggle, J14, snapshots | FlareStageGuides.swift, FlareStage.swift, FlareWindow+View.swift, FlareViewSnapshots, UITests +View | SE-2a, #995 | #3309 (35a92cb) | merged |
| SE-3 | 2 | Edit actions via pasteboard, stage context menu, J15 | packet | SE-4 | #2565 | merged |
| SE-5a | 4 | J3 extended on -FlareSample empty, FlareEditOrderJourneys.testSelectAllOrderAndEscape; Fixes #2485 | UITests/FlareJourneyTests+Draw.swift, UITests/FlareJourneyTests+EditOrder.swift | SE-1, SE-3 | #2945 | merged a46ef519 21:16Z |
| SE-5b | – | status line built; feature-done | docs/blueprints/flare/features/stage-edit.md, stage-edit.wave.json | SE-2b, SE-5a | #3312 (a0054178) | open, no-fast-lane; diff vs dev is the two docs files |

## Reviews
None.

## Decisions
- SE-5a outcome: J3 picks tools by palette clicks (mouse finding #1863; testKeys covers letters); the smooth-anchor check ends J3 with XCTSkip("waits on #390"), no anchor-kind readout on dev. Order journey runs on -FlareSample bounce (Ball, Shadow, locked Background). #2485's remaining audit overlap needs #1789 (timelineIdentifierPrefix public), commented there.
- 2026-10-18T19:52Z SE-5 split: SE-5a (journeys, now: needs only SE-1 and SE-3, merged) and SE-5b (status line + feature-done, after SE-2b). Files disjoint.
- Supervisor (2026-10-17T06:06Z): draw-key-save.wave.json `built` satisfies Depends on; stage 0 re-run passes.
- Rule 20: SE-0's handle hit-test and box transform are Transform/HandleHit/BoxMath kernel concepts (EK-19, EK-20 on #1933), not merged; SE-0 waits on them rather than building an app-local copy.
- SE-4 reorders through Flare's existing `moveLayer(from:to:)`, no new layer-tree logic; it moves onto SuiteKernel Layers when that lands.
- SE-2 split: SE-2a (Model: zoom steps, readouts) now; SE-2b (views) when #273 and #995 close.

## Open
- 2026-10-20 resume (act-1a157ad4612-4xcw): #3309 merged. The quarantine.json commit b364e971 on #3312 is already on dev; the PR's diff against dev is only stage-edit.md and stage-edit.wave.json (docs tier, no size cap). The lane's "too big" comment was about the earlier diff. lead/stage-edit was rebuilt as origin/dev plus this record (dev, not main, per CLAUDE.md).
- 2026-10-18T19:52Z: #995 open (SE-2b waits); #2768 (J15 identifier audit) waits on #2622 (halo, makes timelineIdentifierPrefix public), fix round 1 spent. Fixes #2639, #2733 merged (#2618, #2730 closed). Gap #2775 filed; #2741 SuiteKernel turn helper.
- #273 (S12 SelectionHandles, guide marks) open; #995 (ruler toggle, drag-out guides) open; editor-kernel EK-box not merged.
- SE-3 pasteboard (rule 20): Clipboard is canonical and SuiteModel already has PasteboardCoding with SuiteTypeID.flareLayers, and SuiteShell has PasteboardSlot, which FlareApp links. FlarePasteboard is a thin adapter over those, not the packet's private com.qbtrix.flare.items type.
- CI findings (report-only macOS, run 39093972830): every Flare journey is red, mostly the overlap audit (e.g. #2490: keyframe buttons overlap in the timeline), outside this feature's files. #2485 (testDrawShapesWithEachTool, J3) is in UITests/FlareJourneyTests+Draw.swift, which SE-5 owns, so SE-5 takes it (Fixes #2485). None of them carries Feature: stage-edit, so the rule-10 count for this feature is 0.
- SE-3 outcome: SuiteShell PasteboardSlot wraps FakePasteboard only and never reaches the system pasteboard, so FlarePasteboard writes NSPasteboard.general under SuiteTypeID.flareLayers (the suite id, not a private type), in the shape of DesignPasteboardBridge. It also edits FlareCommands.swift (5 lines: Paste reason refresh) and the flare-app C4 part. J15 uses menu clicks, not the keyboard; the 10 pt paste offset is not checked in the journey.
- Finding #2618 (05:07Z, scoped run 39098049090 on e01529f4): J15 step 1 fails "Edit > Copy is disabled" after clicking Ball in LAYERS. Suspects: FlareEdit.editHelp(.copy) returns the shapes service's .select unavailableHelp even with a target, or the menu bar not re-reading after a LAYERS pick. Fix round 1 of 2. Open findings for stage-edit: 1.
- #2618 root cause: FlareMenu (the focused scene value the menu bar reads) carried only undo titles, recents and Loop, so a LAYERS pick never re-rendered the menu and Copy kept its launch reason. Fix #2639 publishes FlareWorkspace.editHelps and the selection reasons in FlareMenu; tests FlareEditHelpsTests. Full scripts/ci PASS; J15 proof waits on the next macOS run.
- 2026-10-19T18:05Z SE-2b opened as #3309 (head 35a92cb): 11 files, 400 changed lines, `FlareModel.FlareGuideDrag` 5/5. Deviations:
  - J14 reads a hidden `flare.stage.zoom` element, because the pill text is blocked by #1452.
  - A guide is added when the drag is released, so the whole drag is one undo step.
  - Onion skin and motion path are disabled with a reason.
  - The goldens are light only.
  Left for SE-5b or gaps: keyboard guide placement, dark goldens, and the onion skin and motion path drawing.
- 2026-10-19T18:20Z SE-5b opened as #3312 (docs: status built, wave status built and feature_issue #1514). It is stacked on #3309 with labels fast-lane, feature-done and no-fast-lane; the hold comes off once #3309 merges. Gaps filed: #3310 (keyboard guides) and #3311 (dark view goldens). Onion skin and motion path stay with #386.
