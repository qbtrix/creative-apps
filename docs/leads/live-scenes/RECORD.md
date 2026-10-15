# live-scenes lead record

Issue: #800 · Packet: docs/blueprints/flare/features/live-scenes.md
Run: act-1a13ca4f89e-0ft1 · Session: claude/live-scenes-lead-d0sj3t · Started: 2026-10-14
Stage: 4 round 1
Base: 62395be0c94c10861eaa7518dc7a7fa0d6143447
Next: read the dev CI run triggered by #886 (feature-done, 62395be); judge round 1 on it

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| SN-1 | 1 | `LiveScenes` struct: newDocument, addScene, removeScene (never the last) | Sources/FlareModel/Live/LiveScenes.swift, Tests/FlareModelTests/LiveScenesTests.swift | LiveScenesTests | #876 | merged |
| SN-2 | 2 | renameScene, reorderScene on LC-8 RenameScene/ReorderScene, clamped index | Live/LiveScenes+Order.swift, LiveScenesOrderTests.swift | LiveScenesOrderTests | #879 | merged |
| SN-3 | 2 | setCanvas (LC-8 SetSceneCanvas), setTiming | Live/LiveScenes+Canvas.swift, LiveScenesCanvasTests.swift | LiveScenesCanvasTests | #880 | merged |
| SN-4 | 2 | guides add/remove; drag is one merged MoveGuide (LC-10); QB-L7 budget | Live/LiveScenes+Guides.swift, LiveScenesGuidesTests.swift | LiveScenesGuidesTests | #882 | merged |
| SN-5 | 3 | SceneEditing conformance, model journey steps 1-4, refusalsArePlainText, liveEqualsFake (feature-done) | Live/LiveScenes+SceneEditing.swift, LiveScenesJourneyTests.swift | LiveScenesJourneyTests | #886 | merged |

Journeys (model half, SN-5): J2 new from preset, J16 scenes, J14 guides; steps 1-4 of the packet.
Quality bars: QB-F3 one gesture one step, QB-L7 <= 10 ms per moveGuide step (median of 50), QB-F2 plain refusals.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Base moved from the brief's aa166cb to bfd0328 (one SuiteUI snapshot test on top; aa166cb is an ancestor).
- Issue says Depends on: none (LC-8, LC-10 on creative-core main 98be31a); Package.swift tracks creative-core main.
- Waves follow the packet: SN-1 alone, then SN-2/3/4 in parallel (separate extension files), then SN-5 with feature-done.
- No Flare screen changes: the live type is not wired until IN-4, so the Anatomy loop judges on CI + audit, not new screens.

## Open
- dev-red #763 open before this feature: macOS fails in SuiteUI (SnapshotHost, FrameProbe, ControlInventory, GoldenImage) and Photo (PhotoBrushLatency); no Flare or LiveScenes test in run 38654031210 failed.
