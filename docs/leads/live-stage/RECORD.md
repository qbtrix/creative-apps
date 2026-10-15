# live-stage lead record

Issue: #798 · Packet: docs/blueprints/flare/features/live-stage.md
Run: act-1a13d374bd1-s92z · Session: claude/live-stage-lead-gljfd4 · Started: 2026-10-15T00:40Z
Stage: 1 packet
Base: 667245a43e0d09ad4262f0f68bce1a587e1f9f9c
Next: read packet and core APIs, plan waves

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| ST-1 | | LiveStage on the render list | Live/LiveStage.swift, LiveStageTests | LiveStageTests | | todo |
| ST-2 | | LiveStage nesting, editing, text | Live/LiveStage.swift, LiveStageNestingTests | LiveStageNestingTests | | todo |
| ST-3 | | LiveHits.hit | Live/LiveHits.swift, LiveHitsTests | LiveHitsTests | | todo |
| ST-4 | | marquee, bounds, StageHitTesting | Live/LiveHits+Marquee.swift, LiveHitsBoundsTests | LiveHitsBoundsTests | | todo |
| ST-5 | | LiveConformanceTests | LiveConformanceTests | itself | | todo |
| ST-6 | | LiveShapes drafts and commits | Live/LiveShapes.swift, LiveShapesTests | LiveShapesTests | | todo |
| ST-7 | | BoxGestureMath move | Live/BoxGestureMath.swift, Fakes/FakeShapes.swift, BoxGestureMathTests | BoxGestureMathTests | | todo |
| ST-8 | | boxResult, commitBox | Live/LiveShapes+Box.swift, LiveShapesBoxTests | LiveShapesBoxTests | | todo |
| ST-9 | | edits + ShapeBuilding | Live/LiveShapes+Edit.swift, LiveShapesEditTests | LiveShapesEditTests | | todo |
| ST-10 | | model journey + budgets (feature-done) | LiveStageJourneyTests, LiveStageBudgetTests | itself | | todo |

Journeys: J3 and J5 model half, steps 1-6 of the packet. Quality: QB-L5 hit <= 10 ms, QB-L6 draw list <= 20 ms, QB-L11 nested <= 40 ms, QB-V1 cubics kept, QB-F3 one gesture one step.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Depends on: none (issue body); engine issues closed on creative-core main 98be31a.
- Container has no Swift; installing Swift 6.4.1 to /opt/swift so builders can run scripts/ci.

## Open
- none
