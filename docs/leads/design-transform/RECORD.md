# transform lead record

Issue: #3436 · Packet: docs/blueprints/design/features/transform.md
Run: act-1a15da1b26c-9qo6 · Session: claude/design-feature-lead-run-1k035k · Started: 2026-10-21T08:46:56Z (prior run act-1a15ac70747-ky1f)
Stage: 3 DT-u waiting on #4159 (lane macOS build queued, no runner); #4188 fix: #4187 merged, dev merged into fix/design-rotate-knob (875e12aa, 15 files +243/−62), gate running, PR next; round 2: findings #4223 (turned resize) + #4224 (several, no knob) filed, fixes built: fix/design-turned-resize (9ab21935, on rotate-knob, +136/−2, Mutate 33/33 DesignCanvasEditing) and fix/design-knob-several (00e7a2ca, on turned-resize, +137/−10, Mutate 38/38 DesignCanvasEditing + 25/25 DesignCanvasHints; snapshots design-transform-turned-several-light/dark.png); PRs held for their bases; DT-m: #4187 merged (8684d700f); DT-6 rebuilt on dev (cherry-pick, 487ff70e), gate running, PR next; DT-z: DT-7 journey pushed on feat/design-transform-dt7-journey (c36b6b1a, off dev, +162/−6, 1 file; PR after #4188 fix, DT-6 and #4223 fix merge)
Base: 896cafe3 (origin/dev); main verified at 0dd23d65
Next: #4159, #4187, #4188-fix merge -> Belt-Slice-Done + Mac-Finish-Wanted DT-u on a green design run; DT-6 after DG-m merges (shares DesignSVG, catalog; must update turnHelp snapshots: DesignInspectorSnapshots.transformRows, objectItemsSayWhyTheyAreOff, DesignSeveralInspectorSnapshots) and DA-m re-read

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DT-a | rotation/flip fields on DesignNode, TransformTarget stubs, inspector rows and Object items on the stubs | DT-1, DT-2 | MJ-DT | TT-a (merged #3485/#3486); gradient-fill:DG-a (#3687 open) | yes | 0 | done | 39569221486 | wanted |
| DT-u | canvas paints turned nodes, handles turn; snapshots and render budget | DT-3, DT-4 | DJ-T1 | DT-a; gradient-fill:DG-u | yes | 0 | building | – | – |
| DT-m | adapter bodies, turned hit test, SVG turn, catalog specs, RJ-D15 | DT-5, DT-6 | MJ-DT | DT-a; gradient-fill:DG-m; autosave-history:DA-m | no | 0 | waiting | – | – |
| DT-z | journey on live, status built, feature-done | DT-7, DT-8 | DJ-T1 | DT-u, DT-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DT-1 | DT-a | 1 | node fields + adapter stubs, tests disabled | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift | DesignTransformTests (disabled), fixtures byte-equal | #3751 | merged (e6430cfa) |
| DT-2 | DT-a | 1 | inspector transform rows, Object items, journey skipped | Sources/DesignApp/DesignInspectorTransform.swift, Sources/DesignApp/DesignInspector.swift, Sources/DesignApp/DesignObjectMenu.swift, UITests/DesignJourneyTests+Transform.swift | snapshot rows | #3751 | merged (e6430cfa) |
| DT-3 | DT-u | 2 | canvas paints turned nodes | Sources/DesignApp/DesignCanvasMarks.swift, Sources/DesignApp/DesignSelectionMarks.swift, Tests/AppSnapshotTests/DesignTransformPaintTests.swift | DesignTransformPaintTests | #3983 | merged (564e6562) |
| DT-4 | DT-u | 2 | snapshots, render budget | Tests/AppSnapshotTests/DesignTransformSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignTransformTests.swift | RenderBudgetDesignTransformTests | – | waiting |
| DT-5 | DT-m | 2 | adapter bodies, contains | Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift, Tests/mutations/DesignModel.DesignTransform+Kernel.json | DesignTransformTests | – | waiting |
| DT-6 | DT-m | 3 | SVG turn, specs, RJ-D15 | Sources/DesignModel/Live/DesignSVG.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt, Tests/RealJobs/design/rotate-15/ | DesignSVGTests.turnedNode, RJ-D15 | – | waiting |
| DT-7 | DT-z | 4 | journey on live | UITests/DesignJourneyTests+Transform.swift | DesignTransformJourneyTests | – | pushed, PR held |
| DT-8 | DT-z | 5 | design.md, status built | docs/blueprints/design.md, docs/blueprints/design/features/transform.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev (CLAUDE.md, lane retargets main to dev); brief's main HEAD b3011ab9 verified, work branches from origin/dev a48992b7.
- One combined wave plan across transform, placed-images, file-flow (rule 19); DT-a is the first wave for this feature and blocks PD-a.

## Open
- DT-a Belt-Slice-Done and Mac-Finish-Wanted posted on #3436 (run 39569221486).

## Run act-1a15fcdd869-ck2o (2026-10-21T18:55Z)

- Relaunched. TT-u #3513 merged as 7347ed80, so DT-4 (the DT-u snapshots and render budget) is unblocked and is next. DT-m still waits on gradient-fill DG-m and autosave-history DA-m.

- 2026-10-21T23:22Z: opened #4254 (the #4188 knob fix, DT-u round 1, head 875e12aa) and #4255 (DT-6, DT-m, head 487ff70e). Both fast-lane, both passed the gate. The round-2 fixes for #4223 and #4224 follow once #4254 merges. DT-7 is held until #4254, #4255 and the #4223 fix merge. #4159 (DT-4) is still in the lane; its macOS gate is queued. There is no green design or full run yet: dev-red #3856 is open and its Linux runs are red from before #4187.

- 2026-10-21T23:54Z: #4159 (DT-4) merged as 9829685ee. #4254 and #4255 still merge cleanly against dev and are waiting for a lane batch.

- 2026-10-22T00:35Z Lane macOS builds red on dev's RenderBudgetPhotoPlaceTests (PhotoPlaceIntent.files), fixed on dev by #4215; merged origin/dev into #4254 and #4255; regating.

- 2026-10-22T00:36Z Gate CI: PASS after the dev merge; pushed #4254→f9c5b8ac,#4255→5d611ef3 and moved Head: lines. Waiting on the lane.

- 2026-10-22T01:03Z Heartbeat: #4254 (macOS build 39700862805) and #4255 (39700883014) queued for runners.

- 2026-10-22T01:29Z #4255 (DT-6) macOS build 39700883014 green; waits on the lane sweep. #4254 build 39700862805 still queued.

- 2026-10-22T01:57Z #4254 and #4255 macOS builds green. #4255: Lane Linux check red on FormatListRatchetTests.realTreePasses (Sources/SuiteModel/Values/Media.swift, from SM-1 #4034); dev is red on the same test (dev-red #3856), fix #4258 in the lane. Not ours; merge dev again once #4258 lands.

- 2026-10-22T02:29Z Merged dev (b5a6e7e0a) into #4255, CI: PASS, pushed f5833163, Head moved. #4254 still open at f9c5b8ac, clean. Scoped design run 39693638859 (be9aa35bc) failed on the old RenderBudgetPhotoPlaceTests break (fixed on dev by #4215), so no done lines yet; next design run is 39709889487. #4258 closed: #4238 (SC-14) fixed dev's ratchet.

- 2026-10-22T02:59Z #4254 Linux check was red on the old ratchet test; merged dev (now green at b5a6e7e0a), CI: PASS, pushed e62d759d, Head moved. #4255 at f5833163 waits on its lane macOS build. Design run 39709889487 still queued.

- 2026-10-22T03:26Z Heartbeat: #4254 (e62d759d) and #4255 (f5833163) lane macOS builds queued. Design run 39709889487 still queued; dev Linux green at 66a845885.

- 2026-10-22T03:52Z Heartbeat: #4255 macOS build green (waits for batch); #4254 macOS build still queued. Design run 39709889487 in progress.
- 2026-10-22T04:17Z heartbeat: #4254 (knob, e62d759d) and #4255 (DT-6, f5833163) are macOS green, clean, waiting for their batch. #4223/#4224 fixes are held until #4254 merges, then DT-7.
- 2026-10-22T04:39Z DT-6 (#4255) merged as aa66f0e7e (batch run 39719953891); DT-m built (DT-5, DT-6; ui false). Its done line waits on full CI run 39722978870 (71987f724, contains aa66f0e7e), queued. #4254 (knob) is clean and green, waiting for the next batch; #4223/#4224 stay held behind it.
