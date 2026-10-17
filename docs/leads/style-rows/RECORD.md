# style-rows lead record

Issue: #1497 · Packet: docs/blueprints/design/features/style-rows.md
Run: act-1a1487bf8e3-hwdj · Session: claude/design-shell-parity-lead-0l668u · Started: 2026-10-17T06:08Z
Stage: 3 wave 1
Base: fe0f5f176a95336c77a1d0cff7162e584db1d24c
Next: wave 1 (ST-1, ST-2, ST-3, ST-6b beside layers-panel L-3, L-7) is building; when its PRs merge, run the check and start wave 2 (ST-7 at once; ST-4b, ST-5f, ST-5 once design-window DW-a has merged, ST-4 once DW-b has)

Line lead (rule 19) over #1325 shell-parity (done), #1498 layers-panel and #1497 style-rows. One wave plan across the three.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SR-m | On the live services every style setter refuses, skips and clamps as blueprint 5.4 says, the inspector's shared values read "Mixed" only when layers differ, and the inline editor's scale follows the zoom. | ST-1, ST-2, ST-3 | MJ8 | design-contracts (built) | no | 0 | building | – | – |
| SR-t | Text family, size, weight and alignment rows set a text layer, the canvas and the inline editor draw its text in that style, committed text doesn't jump at any zoom, and top-level frame names sit above their frames. | ST-6b, ST-4b, ST-5t, ST-5f | J11 | SR-m (ST-4b, ST-5t); design-window DW-a (ST-4b, ST-5t, ST-5f) | yes | 0 | building (ST-6b) | – | – |
| SR-a | Layer opacity, corner radius and stroke rows set one or several layers in one step per scrub, read "Mixed" when the layers differ, show the locked hint in the value column, and keep each scrub step inside its budget. | ST-4, ST-6, ST-7 | J10 | SR-m (ST-4, ST-7); design-window DW-a (ST-4, ST-6) and DW-b (ST-4) | yes | 0 | planned | – | – |
| SR-b | The canvas draws radius, stroke and opacity as stored, and scrubs and typing keep up on 2,000 layers. | ST-5, ST-8 | P2 | design-window DW-a (ST-5, ST-8); SR-a, SR-t (ST-8) | yes | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| ST-1 | SR-m | 1 | `LiveStyling`: every setter over ids with the refusals and clamps (reads `DesignCorners` help); walk MJ8; retires the stub's entries in DesignLiveStubTests and the plan | Sources/DesignModel/Live/LiveStyling.swift, Tests/DesignModelTests/DesignStyleTests.swift, Tests/DesignModelTests/DesignLiveStubTests.swift, Tests/mutations/DesignModel.LiveStyling.json | DesignStyleTests + Mutate 4+/n | – | building |
| ST-2 | SR-m | 1 | `sharedValue`, `opacityPercentText`, the locked hint's text per row | Sources/DesignModel/DesignInspectorContent.swift, Tests/DesignModelTests/DesignInspectorSharedValueTests.swift, Tests/mutations/DesignModel.DesignInspectorContent.json | DesignInspectorSharedValueTests + Mutate 2+/n | – | building |
| ST-3 | SR-m | 1 | `textEditScale` follows the zoom (no floor at 1) | Sources/DesignModel/DesignText.swift, Tests/DesignModelTests/DesignTextScaleModelTests.swift, Tests/DesignModelTests/DesignCompactSelectionTests.swift, Tests/mutations/DesignModel.DesignText.json | DesignTextScaleModelTests + Mutate 2+/n | – | building |
| ST-6b | SR-t | 1 | J11 written from the packet, `XCTSkip("waits on ST-5t")` | UITests/DesignJourneyTests+Text.swift | compiles on the lane's macOS build; skips by name | – | building |
| ST-7 | SR-a | 2 | QD-S6, QD-S7 model budgets | Tests/DesignModelTests/DesignStyleBudgetTests.swift | DesignStyleBudgetTests under the Linux gates | – | waits on ST-1 |
| ST-4b | SR-t | 2 | Text rows in DW-a's Text section slot | Sources/DesignApp/DesignInspectorText.swift, Tests/AppSnapshotTests/DesignTextStyleSnapshots.swift | DesignTextStyleSnapshots | – | waits on ST-1, ST-2, DW-a |
| ST-5f | SR-t | 2 | Top-level frame names above their frames in the unclipped overlay | Sources/DesignApp/DesignFrameLabels.swift, Sources/DesignModel/DesignFrameLabel.swift, Tests/DesignModelTests/DesignFrameLabelTests.swift, Tests/mutations/DesignModel.DesignFrameLabel.json, Tests/AppSnapshotTests/DesignFrameLabelSnapshots.swift | DesignFrameLabelTests + snapshots | – | waits on DW-a |
| ST-5 | SR-b | 2 | Artwork draws radius, stroke and opacity | Sources/DesignApp/DesignCanvasMarks.swift, Tests/AppSnapshotTests/DesignArtworkPathTests.swift | DesignArtworkPathTests | – | waits on DW-a |
| ST-4 | SR-a | 2 | Style rows (Opacity, Corner radius, Stroke), the hint in the value column, scrubs through the live box | Sources/DesignApp/DesignInspector.swift, Sources/DesignApp/DesignInspectorStyle.swift, Tests/AppSnapshotTests/DesignInspectorSnapshots.swift, Tests/AppSnapshotTests/DesignStyleSnapshots.swift, Tests/AppSnapshotTests/DesignStyleScrubTests.swift | snapshots + DesignStyleScrubTests | – | waits on ST-1, ST-2, DW-a, DW-b |
| ST-5t | SR-t | 3 | Artwork and editor draw text in its style; turns J11 on | Sources/DesignApp/DesignTextFont.swift, Sources/DesignApp/DesignTextArtwork.swift, Sources/DesignApp/DesignTextEditor.swift, Tests/AppSnapshotTests/DesignTextSnapshots.swift, Tests/AppSnapshotTests/DesignTextScaleTests.swift, Tests/AppSnapshotTests/DesignTextDrawTests.swift, UITests/DesignJourneyTests+Text.swift | DesignTextDrawTests, DesignTextScaleTests, J11 | – | waits on ST-3, ST-4b, ST-6b, DW-a |
| ST-6 | SR-a | 3 | J10 | UITests/DesignJourneyTests+Style.swift | J10 | – | waits on ST-4 |
| ST-8 | SR-b | 4 | P2; `feature-done` | UITests/DesignJourneyTests+PerfScrub.swift, docs/blueprints/design/features/style-rows.wave.json | P2 writes perf-design-scrub.json | – | waits on ST-5, ST-5f, ST-5t, ST-6, ST-7 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target `dev`: the fast lane's base is `dev` (scripts/fast-lane.sh, CLAUDE.md) and it retargets a PR based on `main`; main is a promoted dev SHA. The brief's "main" is read as the integration branch the lane feeds.
- Builder branches are `wave/<feature>-<task>`: git can't hold `lead/style-rows/<task>` beside `lead/style-rows`.
- Wave 1 = SR-m (ST-1, ST-2, ST-3) plus ST-6b (rule 13: J11 before SR-t's code), all disjoint files, beside layers-panel L-3 and L-7 (rule 19, one build-wave call). ST-1 also edits DesignLiveStubTests (the LiveStyling stub entries go with the stub); ST-3 edits DesignCompactSelectionTests (its `textEditScale(zoom: 0.43) == 1` assert becomes 0.43).
- ST-7 waits only on ST-1 (it times `LiveStyling`), so it runs in wave 2 whether or not DW-a has merged; the packet's wave 2 is otherwise kept (ST-4b, ST-5f, ST-5 after design-window DW-a; ST-4 after DW-b).
- Rule 18: the UI slices can't start before DW-a because their files are DW-a's slots (DesignInspectorText, DesignTextArtwork, DesignFrameLabels, DesignInspectorStyle don't exist on dev yet). The Model signatures the UI calls (`sharedValue`, `opacityPercentText`, `textEditScale`) are SR-m's wave-1 tasks, so nothing further to stub.
- Rule 20: style setters, shared values and the edit scale are Design-only concepts (no kernel module plans them); no extraction needed.
- Filed the packet's `p3` gap: #1988 (Auto Layout). ST-6's PR body says #752 closes with that bullet moved there.

## Open
- design-window DW-a (#1494) not merged: SR-t, SR-a and SR-b's view tasks wait on it (their files are its slots). DW-d PRs are at the lane; DW-a's aren't visible yet.
- `InspectorColorWellRow`'s `onEnd` is #718 (inspector-controls IC-3, open): ST-4 keeps Design's local end gesture (#749) until it lands.
