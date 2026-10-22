# transform lead record

Issue: #3436 · Packet: docs/blueprints/design/features/transform.md
Run: act-1a16208b93a-24w0 · Session: claude/feature-lead-playbook-wngeeb · Started: 2026-10-21T08:46:56Z (relaunched 2026-10-22T05:40Z; prior runs act-1a15ac70747-ky1f, act-1a15da1b26c-9qo6, act-1a15fcdd869-ck2o)
Stage: 3 verify, DT-z fix round 1 (#4401 in the lane)
Base: 80aba474 (origin/dev at 08:10Z)
Next: #4401 merges; wait for a completed, successful design-scoped or full ci.yml run on dev at or after dcfcb6b0 (and #4401 if timing still gates) -> Belt-Slice-Done DT-z, Mac-Finish-Wanted DT-z, Belt-Contact-Sheet on #3436

Last check: 2026-10-22T11:57Z. Runs containing dcfcb6b0: CI 39769927851 (a332b3e2) pending/-; scoped: design 39769473910 (a332b3e2) queued/-; CI 39766612022 (5da8c329) completed/cancelled; CI 39763986545 (ba8009b0) completed/cancelled; CI 39758044934 (1896483c) completed/cancelled; CI 39755561688 (06d331b0) completed/cancelled; CI 39752648221 (06d331b0) completed/cancelled; CI 39750872878 (cc0a7944) queued/-; CI 39748952777 (9933cf8e) completed/cancelled; scoped: design 39747588205 (2b31ba4c) completed/failure; CI 39746443459 (80aba474) completed/cancelled; transform findings: none.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DT-a | rotation/flip fields on DesignNode, TransformTarget stubs, inspector rows and Object items on the stubs | DT-1, DT-2 | MJ-DT | TT-a (merged #3485/#3486); gradient-fill:DG-a (#3687 open) | yes | 0 | done | 39569221486 | wanted |
| DT-u | canvas paints turned nodes, handles turn; snapshots and render budget | DT-3, DT-4 | DJ-T1 | DT-a; gradient-fill:DG-u | yes | 2 | done (per Belt brief; round 2 #4223/#4224 in flight) | – | – |
| DT-m | adapter bodies, turned hit test, SVG turn, catalog specs, RJ-D15 | DT-5, DT-6 | MJ-DT | DT-a; gradient-fill:DG-m; autosave-history:DA-m | no | 0 | done (per Belt brief) | – | – |
| DT-z | journey on live, status built, feature-done | DT-7, DT-8, DT-z-r1 | DJ-T1 | DT-u, DT-m | yes | 1 | fix round 1, verifying | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DT-1 | DT-a | 1 | node fields + adapter stubs, tests disabled | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift | DesignTransformTests (disabled), fixtures byte-equal | #3751 | merged (e6430cfa) |
| DT-2 | DT-a | 1 | inspector transform rows, Object items, journey skipped | Sources/DesignApp/DesignInspectorTransform.swift, Sources/DesignApp/DesignInspector.swift, Sources/DesignApp/DesignObjectMenu.swift, UITests/DesignJourneyTests+Transform.swift | snapshot rows | #3751 | merged (e6430cfa) |
| DT-3 | DT-u | 2 | canvas paints turned nodes | Sources/DesignApp/DesignCanvasMarks.swift, Sources/DesignApp/DesignSelectionMarks.swift, Tests/AppSnapshotTests/DesignTransformPaintTests.swift | DesignTransformPaintTests | #3983 | merged (564e6562) |
| DT-4 | DT-u | 2 | snapshots, render budget | Tests/AppSnapshotTests/DesignTransformSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignTransformTests.swift | RenderBudgetDesignTransformTests | #4159 | merged (9829685e) |
| DT-5 | DT-m | 2 | adapter bodies, contains | Sources/DesignModel/DesignTransform+Kernel.swift, Tests/DesignModelTests/DesignTransformTests.swift, Tests/mutations/DesignModel.DesignTransform+Kernel.json | DesignTransformTests | #4187 | merged (8684d700) |
| DT-6 | DT-m | 3 | SVG turn, specs, RJ-D15 | Sources/DesignModel/Live/DesignSVG.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt, Tests/RealJobs/design/rotate-15/ | DesignSVGTests.turnedNode, RJ-D15 | – | waiting |
| DT-7 | DT-z | 6 | journey on live | UITests/DesignJourneyTests+Transform.swift | DesignTransformJourneyTests | #4323 | merged (dcfcb6b0) |
| R2 | DT-u | 6 | fix #4223 turned resize + #4224 knob over several | Sources/DesignModel/DesignCanvasEditing.swift, Sources/DesignModel/DesignCanvasHints.swift, their tests and plans | DesignTurnedResizeTests, knob-several test | #4324 | merged (80aba474) |
| DT-z-r1 | DT-z | 7 | split transform render budget into bodies/timing | Tests/AppSnapshotTests/RenderBudgetDesignTransformTests.swift, docs/blueprints/design/features/transform.md | RenderBudgetDesignTransformTests.bodies | #4401 | open (f3291c20) |
| DT-8 | DT-z | 6 | status built | docs/blueprints/design/features/transform.wave.json | scripts/waves render --dry-run | #4323 | merged (dcfcb6b0, with DT-7) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| DT-z | 39747588205 (scoped design) | 2b31ba4c | macOS (design) tests | knob p95 21.43 ms > 8; scrub 119 bodies (fixed by #4354); DesignTransformSnapshots.rows (fixed by #4379) | 0 -> round 1 #4401 |

## Decisions
- PRs target dev (CLAUDE.md, lane retargets main to dev); brief's main HEAD b3011ab9 verified, work branches from origin/dev a48992b7.
- One combined wave plan across transform, placed-images, file-flow (rule 19); DT-a is the first wave for this feature and blocks PD-a.

- Run act-1a16208b93a-24w0: record stays on lead/design-transform (lead/transform is Halo's transform lead, #3443); the brief's lead/transform path would overwrite it.
- Run act-1a16208b93a-24w0: this run's brief covers #3436 slice DT-z only; gradient-fill #3415 has its own lead and is left alone.
- Wave 6: R2 and DT-z run in parallel, on disjoint files (Sources/DesignModel vs UITests + wave.json). DT-z is not stacked on R2: it would go over the 400-line cap, and journeys are report-only. R2's PR opens first, so the lane merges it first.

- PR bodies: the tooling appends a generic "Generated by" footer on every body edit and it can't be removed from here; the session link was stripped and the lane strips the footer from the squash commit.
- #4323 journey step 2 needs #4224/#4223's fix (#4324); #4324 was opened second, so if a journey runs before it merges, step 2 is expected red.

## Open
- Findings open: none (#4223, #4224 closed by #4324).
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

## Run act-1a16208b93a-24w0 (2026-10-22T05:40Z)

- Relaunched. #4254 (knob) merged 04:40Z; DT-a/DT-u/DT-m done per the brief. Open findings: #4223, #4224 (DT-u, round 2). Wave 6 started: R2 fix PR + DT-z slice PR, builders in parallel.

- 2026-10-22T11:37Z Scoped design run 39747588205 (2b31ba4c) red: knob-drag p95 21.43 ms, scrub 119 bodies (fixed on dev by #4354), rows turnHelp (fixed by #4379). Round 1: #4401 splits RenderBudgetDesignTransformTests into gating `bodies` and report-only `timing` (RenderBudgetDesignTests' pattern); asked the supervisor on #3436 to list `timing` in Tests/perf-suites.txt. Runs 39769473910 (design) and 39769927851 (full) on a332b3e2 carry #4354/#4379.
