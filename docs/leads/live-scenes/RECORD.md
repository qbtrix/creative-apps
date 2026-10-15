# live-scenes lead record

Issue: #800 · Packet: docs/blueprints/flare/features/live-scenes.md
Run: act-1a13ca4f89e-0ft1 · Session: claude/live-scenes-lead-d0sj3t · Started: 2026-10-14
Stage: 5 finish
Base: cba1813739a5be03f353698cc2c61e76bc8c6103
Next: watch dev CI runs (ci.yml, branch dev) newer than 38671960461; on the first green one, comment Belt-Contact-Sheet on #800 and mark done. Red only on SuiteUI = not ours (dev-red #763).

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
| 1 | 38657968912 | red (SuiteUI SnapshotHostTests only, #763) | not run (journeys skipped after scripts/ci failed) | clarity, journey, quality, contract, tests | 1 major (QB-F2 refusals from LiveScenes show case names), 3 minor (setCanvas group breaks drag coalescing on refusal, empty-name divergence unpinned, drag budget prints no p50/p95) | #890 #889 #896 #892 (all merged) | no |
| 2 | 38660293042 + Linux gate c111439 | red (SuiteUI SnapshotHostTests only, #763); Linux PASS | not run | clarity, journey, quality, contract, tests | 1 major (#890 catch-all hides NotBuilt reasons), 3 minor (specific engine causes and fake sentences hidden; J16 select step missing) | #905 #908 (merged) | no |
| 3 | Linux gate a7429dc | Linux PASS; latest macOS 38662225263 predates fixes | not run | clarity, journey, quality, contract, tests | 1 major (#905 NotBuilt test passes without the fix), 1 minor (NaN background guard untested) | #911 #910 (merged) | no |
| 4 | Linux gate cba1813 | Linux PASS | not run | clarity, journey, quality, contract, tests | 1 minor (refusalsArePlainText reuses a stale layerError) | #914 (feature-done, merged) | yes |

## Decisions
- Base moved from the brief's aa166cb to bfd0328 (one SuiteUI snapshot test on top; aa166cb is an ancestor).
- Issue says Depends on: none (LC-8, LC-10 on creative-core main 98be31a); Package.swift tracks creative-core main.
- Waves follow the packet: SN-1 alone, then SN-2/3/4 in parallel (separate extension files), then SN-5 with feature-done.
- Round 2 judged on the Linux gate: the round-1 fixes touched no UI path, so the lane dispatched no CI for them.
- Round critics review code, not PNGs: no Flare screen changes, and the panel prompt says so (critic-code.js, a copy of critic-panel.js).
- Empty-name divergence: documented and pinned, not changed (packet: the workspace refuses it first).
- No Flare screen changes: the live type is not wired until IN-4, so the Anatomy loop judges on CI + audit, not new screens.

## Open
- Feature-done run 38667087530 (c3fd66f) red only on SuiteUI SnapshotHostTests/TokensTests (dev-red #763, triaged twice); waiting on the SuiteUI line for a green dev run. Status comment on #800.
- Round budget used: 4 rounds (round 4 clean); no gap issues left open.
- dev-red #763 open before this feature: macOS fails in SuiteUI (SnapshotHost, FrameProbe, ControlInventory, GoldenImage) and Photo (PhotoBrushLatency); no Flare or LiveScenes test in run 38654031210 failed.
