# canvas-host lead record

Issue: #1596 · Packet: docs/blueprints/suiteui/features/canvas-host.md
Run: act-1a147c4ddc0-fouq · Session: n/a (cloud session on claude/canvas-host-lead-quy2t1) · Started: 2026-10-17T02:51Z
Stage: 3 wave 1 (CH-1 open as #1978; CH-2, CH-6, CH-8 wait on it)
Base: b1ec04755cc52d9fc0588046dbc5d088a12e8dd7 (origin/main, the brief's SHA); origin/dev is ef3dfdb7f0f772723deaf139bd09f4625a1e9090
Next: wait for #1978 to merge (lane build-only run), then wave 2 (CH-2, CH-6, CH-8); base is dev, status stays on this branch.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CH-a | contracts, fakes, stubbed store, placeholder pages | CH-1, CH-2 | SJ0 | canvas-marks (feature, planned, no slices yet) | yes | 0 | building | – | wanted after done |
| CH-b | host on fakes, rendering pane on fakes | CH-3, CH-4, CH-5 | SJ27, SJ28, SP11 | CH-a (CH-3, CH-4) | yes | 0 | waiting | – | – |
| CH-c | hit map, tile set, live store | CH-6, CH-7, CH-8 | SJ27 | CH-a (CH-6, CH-7, CH-8) | yes | 0 | waiting | – | – |
| CH-d | integrate on live, Metal path, blueprint | CH-9, CH-10, CH-11 | SJ27, SJ28, SP11 | CH-b (CH-9, CH-10); CH-c (CH-9) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CH-1 | CH-a | 1 | CanvasHosting contracts, FakeCanvasContent, FakeRenderingPreference | Sources/SuiteUI/Contracts/CanvasHosting.swift, Tests/SuiteUITests/CanvasHostFakeTests.swift | CanvasHostFakeTests | #1978 | open, swift build unverified here |
| CH-2 | CH-a | 2 | RenderingPreference stub, control ids, placeholder pages, first-check skips | Sources/SuiteUI/RenderingPreference.swift, Tests/SuiteUITests/RenderingPreferenceTests.swift, Tests/mutations/SuiteUI.RenderingPreference.json, Sources/SuiteUI/Gallery/GalleryCanvasHost.swift, Sources/SuiteUI/Gallery/GalleryRenderingPane.swift, UITests/SuiteJourneyTests+CanvasHost.swift, Tests/AppSnapshotTests/RenderBudgetCanvasHostTests.swift | RenderingPreferenceTests | – | waits CH-1 |
| CH-6 | CH-c | 2 | CanvasHitMap | Sources/SuiteUI/CanvasHitMap.swift, Tests/SuiteUITests/CanvasHitMapTests.swift, Tests/mutations/SuiteUI.CanvasHitMap.json | CanvasHitMapTests | – | waits CH-1 |
| CH-8 | CH-c | 2 | CanvasTileSet | Sources/SuiteUI/CanvasTileSet.swift, Tests/SuiteUITests/CanvasTileSetTests.swift, Tests/mutations/SuiteUI.CanvasTileSet.json | CanvasTileSetTests | – | waits CH-1 |
| CH-3 | CH-b | 3 | CanvasHostView and CanvasHost; canvas-host page on fakes | Sources/SuiteUI/CanvasHostView.swift, Sources/SuiteUI/CanvasHost.swift, Sources/SuiteUI/Gallery/GalleryCanvasHost.swift, Tests/SuiteUITests/CanvasHostTests.swift, Tests/AppSnapshotTests/SuiteCanvasHostSnapshots.swift | CanvasHostTests | – | waits CH-2 |
| CH-4 | CH-b | 3 | RenderingSettingsPane on the fake preference | Sources/SuiteUI/RenderingSettingsPane.swift, Sources/SuiteUI/Gallery/GalleryRenderingPane.swift, Tests/SuiteUITests/RenderingSettingsPaneTests.swift, Tests/AppSnapshotTests/SuiteRenderingPaneSnapshots.swift | RenderingSettingsPaneTests | – | waits CH-2 |
| CH-7 | CH-c | 3 | Live preference store, device-loss note | Sources/SuiteUI/RenderingPreference.swift, Tests/SuiteUITests/RenderingPreferenceLiveTests.swift, Tests/mutations/SuiteUI.RenderingPreference.json | RenderingPreferenceLiveTests | – | waits CH-2 |
| CH-5 | CH-b | 4 | Enable SJ27, SJ28, SP11, render budget on fakes; baselines | UITests/SuiteJourneyTests+CanvasHost.swift, Tests/AppSnapshotTests/RenderBudgetCanvasHostTests.swift, Tests/AppSnapshotTests/Golden/canvas-host/ | SJ27, SJ28 | – | waits CH-3, CH-4 |
| CH-10 | CH-d | 4 | CAMetalLayer path behind the preference | Sources/SuiteUI/CanvasHostView+Metal.swift, Tests/SuiteUITests/CanvasHostMetalTests.swift, Tests/mutations/SuiteUI.CanvasHostView+Metal.json | CanvasHostMetalTests | – | waits CH-3 |
| CH-9 | CH-d | 5 | Integrate on live store, hit map, tile set; CanvasViewport+Host | Sources/SuiteUI/CanvasViewport+Host.swift, Sources/SuiteUI/Gallery/GalleryCanvasHost.swift, Sources/SuiteUI/Gallery/GalleryRenderingPane.swift, Tests/SuiteUITests/CanvasHostIntegrationTests.swift, Tests/AppSnapshotTests/SuiteCanvasHostSnapshots.swift | CanvasHostIntegrationTests | – | waits CH-5, CH-6, CH-7, CH-8 |
| CH-11 | CH-d | 6 | Blueprint prose, status built, feature-done | docs/blueprints/suiteui.md, docs/blueprints/suiteui/features/canvas-host.wave.json | scripts/waves check | – | waits CH-9, CH-10 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Waves are the packet's Build waves (1 to 6). Wave 2 and wave 3 tasks are independent of each other within their wave; CH-2 and CH-6/CH-8 can share wave 2 only after CH-1 merges.
- Slice CH-a's wait on the canvas-marks feature is recorded but CH-1 has no task-level wait and only creates new files, so it starts first. CH-2 and CH-6 wait on CH-1 by task.
- Lead does not write feature code. Builders take each task.
- Git identity: the repo-local identity per contract rule 9 (Prakash Dalai, 86671543+prakashUXtech@users.noreply.github.com) is set from stage 2 on. The first commit (lead record, stages 0-2) was made with the default `Claude` identity before this was set.

## Open
1. **Integration branch conflict.** The Belt brief says base `main` and check out main. CLAUDE.md says branch from `dev` and never target `main`, and the fast lane merges only into `dev`. This run has not opened any PR. Needs the supervisor's call; the default here is `dev`.
2. **Designated branch.** Work and status are pushed to `claude/canvas-host-lead-quy2t1`, not `lead/canvas-host`, as the session's git instructions require. The Belt status channel reads `lead/canvas-host`; the supervisor must confirm that is the right place.
3. **canvas-marks not built.** Its wave.json is `planned` with no slices. CH-a's feature-level wait on it is unmet; CH-1 and CH-2 are not blocked by it at task level. Confirm before CH-a's wave 1 merges.
4. **No macOS here.** The UI slices (CH-b, CH-c, CH-d) cannot be compiled or snapshotted on this Linux worker. Their journeys and render budgets need the lane's build-only run and the Mac finisher.
5. **No PRs opened yet.** The session rules say not to open a PR unless asked, so the swarm stops at wave 1 until the supervisor confirms that PRs with the `fast-lane` label are wanted.
