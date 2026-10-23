# transform lead record

Issue: #3443 · Packet: docs/blueprints/halo/features/transform.md
Run: act-1a1638e0fe9-uiqj · Session: claude/halo-transform-lead-lek5s7 · continues on #3443 (#4515 closed as its duplicate)
Stage: 3 wave 3 landed (HT-m + HT-z on dev as 55d96ee via #4422); waiting on a green ci.yml dev run
Base: e382f9d7fba02ffdefc8ba2f23c9461b4774fad6
Next: when #4415 and #4422 merge, find a green halo-scoped or full run that holds them; post Belt-Slice-Done for HT-m and HT-z, then Belt-Contact-Sheet on #3443

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HT-a | adapter stubs; handles on the selected layer in the viewer | HT-1, HT-2 | MJ-HT | – | yes | 0 | merged-done (landed in #3702, 2a21273a3) | https://github.com/qbtrix/creative-apps/actions/runs/39514893774 | wanted |
| HT-u | handle drags preview live and commit once; snapshots, budget | HT-3, HT-4 | J-HT | HT-a, transform-tools:TT-u (done) | yes | 0 | building (#3811 open, head b6cba72) | – | – |
| HT-m | turn/scale keyed at the playhead as one step; catalog commands | HT-5, HT-6 | MJ-HT | HT-a, transform-tools:TT-m (done), HT-6: autosave-history:HA-m | no | 0 | HT-5 merged (#3702, 2a21273a3); HT-6 waiting | – | – |
| HT-z | journey on live; feature built | HT-7, HT-8 | J-HT | HT-u, HT-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HT-1 | HT-a | 1 | adapter stubs; HaloTransformTests disabled | Sources/HaloModel/HaloTransform+Kernel.swift, Tests/HaloModelTests/HaloTransformTests.swift | compiles, disabled | #3702 | merged (2a21273a3; #3682 closed as superseded) |
| HT-2 | HT-a | 1 | HaloViewerHandles on the stubs; journey skipped | Sources/HaloApp/HaloViewerHandles.swift, Sources/HaloApp/HaloViewer.swift, UITests/HaloJourneyTests+Transform.swift | HaloViewerSnapshots handles | #3702 | merged (2a21273a3) |
| HT-5 | HT-m | 2 | adapter bodies, keyed when animated | Sources/HaloModel/HaloTransform+Kernel.swift, Tests/HaloModelTests/HaloTransformTests.swift, Tests/mutations/HaloModel.HaloTransform+Kernel.json | HaloTransformTests; Mutate | #3702 | merged 22:41Z (2a21273a3, Mutate 3/3) |
| HT-6 | HT-m | 3 | six specs, id list, RJ-H34 | Sources/HaloModel/HaloCommandCatalog.swift, Tests/command-ids/halo.txt, Tests/HaloModelTests/HaloTransformCommandIDTests.swift, Tests/RealJobs/halo/key-turn/* | HaloTransformCommandIDTests; RJ-H34; Mutate 12/12 | #4415 | open (fast-lane) |
| HT-3 | HT-u | 2 | drags preview via HaloLiveEdit, commit once, Escape cancels | Sources/HaloApp/HaloViewerHandles.swift, Tests/AppSnapshotTests/HaloViewerHandlesTests.swift | HaloViewerHandlesTests | #3811 | merged |
| HT-4 | HT-u | 3 | snapshots, render budget | Tests/AppSnapshotTests/HaloTransformSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHaloTransformTests.swift | knobDragInThreeBodies | #3811 | merged |
| HT-7 | HT-z | 4 | journey on live | UITests/HaloJourneyTests+Transform.swift | testRotateAndScaleInViewer | #4422 | open (stacked on #4415) |
| HT-8 | HT-z | 5 | status built, feature-done | docs/blueprints/halo/features/transform.wave.json | waves render | #4422 | open (feature-done) |

Wave 1: HT-a (HT-1+HT-2, one slice PR), alongside autosave-history HA-a. Wave 2: HT-5 stacked on HT-a; HT-3 once HT-a merges.

Wave 3: HT-m as #4415 on dev 30120a8; HT-z (#4422) stacked on it at once, labelled feature-done.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- #3702 (HT-m) was stacked on HT-a, so its squash landed HT-a too; #3682 was closed as superseded, not rebased.
- Stacked PRs diff against dev with their parent included, so a stacked slice PR opens only when its diff vs dev is within 400 lines and 15 files (in practice once the parent merges); the branch is built and gated at once.
- Base is origin/dev (CLAUDE.md: never branch from main); main b3011ab9 verified at start.
- One PR per slice (rule 22): HT-1 and HT-2 ship together as HT-a, failing test first.
- HT-6 waits on autosave-history HA-6, which waits on gradient-fill HG-m (both own HaloCommandCatalog.swift and Tests/command-ids/halo.txt).

## Open
- HT-5 box under a turned or scaled parent: the parent places the centre only; the box keeps the layer's own size and turn. Check in the critic panel; file a gap if the job needs nested transforms.
- HG-m and HA-m are on dev (autosave-history built, #4397), so HT-6 is unblocked; HT-m is #4415.
- 13:58Z: #4415 and #4422 were labelled needs-rebase (dev's HK-6 stroke commands, #4400, conflicted on the catalog line, tests, golden and mutation plan). I merged origin/dev and kept both sides: #4415 head is f5e08d5 (mutate 14/14), #4422 head is e153b4b. The gate's only failure is HaloStrokeTrimKeysTests/aReasonTurnsTheKeyOffAndItsClickSendsNothing, which fails on origin/dev 20deed6 alone (dev-red #3856, from HK-6). Per CLAUDE.md it isn't fixed here, and Fast-Check reads "blocked by dev-red #3856". I asked the supervisor on #3443.
- Belt reads docs/leads/halo-transform/RECORD.md on lead/halo-transform, so the record is mirrored there; lead/transform keeps the original.
- 14:30Z: the lane ran its own Linux check on #4415 f5e08d5 (run 39792092824). It failed with 34 issues, 27 of them known, which leaves the 7 from the dev-red stroke test (#3856); nothing in the transform code failed. #4422's Linux check (run 39793757071) is still running. Dev (721ac8e) hasn't fixed HaloStrokeTrimKeysTests, and the supervisor hasn't answered on #3443 yet. Waiting.
- 14:53Z heartbeat: dev still red on HaloStrokeTrimKeysTests (HK-6 #4400); named it on #3856 for line:halo. #4415 and #4422 wait on that fix; the lane Linux run on each is red only there. The supervisor has not answered the #3443 question. Stripped an attribution footer from the #3443 comment.
- 15:21Z heartbeat: dev dc87ad2 (HK-u2 #4413 merged) still fails HaloStrokeTrimKeysTests with 7 issues (reproduced locally). #4415 and #4422 are still waiting with red Linux. No supervisor answer on #3443. Holding.
- 15:51Z stage: #4431 fixed the stroke test on dev. Merged origin/dev d96c264 into both slice branches; scripts/ci --changed prints CI: PASS on each. Markers set to Fast-Check: pass, Head 3bee765 (#4415, HT-m) and cc3ddcb (#4422, HT-z). Both are mergeable_state clean and wait on the lane batch. Told #3443 the question is moot.
- 2026-10-22T16:29Z — needs-rebase #2 (FR-8b #4407 on the catalog line, tests, golden, mutation plan): merged origin/dev 7e9f260 into HT-m, kept both (… transforms + frameRateSpecs + window; golden 92); mutate 14/14, CI: PASS, Head 300375f. HT-z merged HT-m, CI: PASS, Head d5afd56. Both bodies moved to the new heads. Waiting on the lane.
- 2026-10-22T16:37:55Z: New run act-1a16474bd28-v3ht for #4515. #4415 and #4422 bodies moved to the new Belt-Lead and Refs #4515; both clean, needs-rebase dropped by the lane, waiting on a sweep. Record stays here on lead/halo-transform (Belt reads it), mirrored from lead/transform.
- 2026-10-22T16:52Z — heartbeat. needs-rebase dropped on both; lane building macOS on 300375f (run 39817206530) and d5afd56 (run 39815522916). The duplicate lead act-1a16474bd28-v3ht (#4515, closed not planned as a duplicate of #3443 by the supervisor) had rewritten both bodies to its run id and Refs #4515; restored Belt-Lead act-1a1638e0fe9-uiqj and Refs #3443, heads unchanged.
- 17:15Z heartbeat: #4415 and #4422 clean, bodies intact, not merged; dev 5e55dc3. #4415 macOS build 39817206530 queued; #4422 build 39815522916 cancelled (lane re-dispatches/batches).
- 17:37Z heartbeat: #4415 and #4422 clean, bodies intact, not merged; dev 7e9f260. #4415 macOS build 39817206530 still queued (macOS runners saturated); lane batch 20261022173602 running without them.
- 17:59Z: #4422 (HT-z) merged 17:55Z as 55d96ee. It was stacked on HT-m, so it carries HT-m too: merging #4415 into dev is an empty diff. Closed #4415 as superseded. Next: a green ci.yml run on dev holding 55d96ee, then Belt-Slice-Done HT-m and HT-z, Mac-Finish-Wanted HT-z, Belt-Contact-Sheet.
- 18:21Z: full CI 39829329352 on dev 8f25082 (holds 55d96ee) pending; Linux check 39829394350 running
- 18:42Z: Linux check 39829394350 on dev 8f25082 (holds 55d96ee) green; full CI 39829329352 still pending (no macOS runner yet). Waiting for it, or a halo-scoped run, for the screens.
- 19:05Z: full CI 39829329352 was cancelled (superseded at 18:59Z). Now waiting on full CI 39836126860 on dev a102c34 (holds 55d96ee), pending.
- 19:27Z: full CI 39836126860 on dev a102c34 (holds 55d96ee) queued for a macOS runner. Still waiting.
- 2026-10-22T19:49:21Z: heartbeat. Full CI 39836126860 (dev a102c34, holds 55d96ee): Linux green, macOS still queued for a runner. Waiting; slice-done lines go out once macOS is green.
- 2026-10-22T20:11:58Z: heartbeat. Full CI 39836126860 (a102c34): Linux green, macOS still queued (runners backed up; scoped photo/suite runs also queued). A newer full CI 39844810755 on dev 0f8414a (holds 55d96ee) is pending and may supersede it; I'll follow whichever finishes green.
- 2026-10-22T20:33:44Z: heartbeat. Full CI 39836126860 (a102c34): Linux green, macOS still queued. Newer full CI 39844810755 (0f8414a) was cancelled as superseded. Still waiting for a green macOS run on a dev head holding 55d96ee.
- 2026-10-22T20:54:38Z: heartbeat. Full CI 39836126860 (a102c34): macOS still queued. The macOS queue is roughly 2.5 h deep (scoped library run 39830886816, queued 18:23Z, only now running). No newer full or halo-scoped dev run in progress. Waiting.
- 2026-10-22T21:16:46Z: heartbeat. Full CI 39836126860 (a102c34): macOS still queued. The halo-scoped run now on macOS (39811894403, 7e9f260) predates 55d96ee, so it can't prove HT-m/HT-z. Waiting.
- 2026-10-22T21:39:59Z: heartbeat. Full CI 39836126860 macOS still queued. New scoped halo run 39857142295 (dev 066cd28, holds 55d96ee) queued at 21:25Z; either one can close HT-m/HT-z.
- 2026-10-22T22:04:58Z: heartbeat. Full CI 39836126860 (macOS) and scoped halo 39857142295 are both still queued; no newer eligible run.
- 2026-10-22T22:27:00Z: heartbeat. Full CI 39836126860 (macOS) and scoped halo 39857142295 are both still queued; no newer eligible run.
- 2026-10-22T22:49:53Z: heartbeat. Full CI 39836126860 (dev a102c34, holds 55d96ee): Linux green, macOS job 120038247452 running since 22:40Z (scripts/ci step). Scoped halo 39857142295 still queued. Waiting for a green macOS job to post HT-m/HT-z done, Mac-Finish-Wanted and the contact sheet.
- 2026-10-22T23:12:15Z: heartbeat. Full CI 39836126860 macOS job 120038247452 still in scripts/ci (started 22:40Z). Scoped halo 39857142295 still queued. Waiting.
- 2026-10-22T23:33:48Z: heartbeat. Full CI 39836126860 macOS job 120038247452 still in scripts/ci (running ~54 min). Scoped halo 39857142295 still queued. Waiting.
- 2026-10-22T23:57:37Z: full CI 39836126860 (dev a102c34, holds 55d96ee): Linux green, macOS job 120038247452 red. Halo's HaloWindowLiveDragTests.aViewerDragRunsTheWindowAtMostThreeTimes got redrawn 23, needs at least 30. That traces to the drag pacer from #4403 and #4423 (core-loop lead), not transform: #4422 changed no HaloApp file. The rest are other lines or timing budgets (RenderBudget*, DesignToolPalette, HaloInspector stroke, ShellMedia). Posted a report-only note on dev-red #3856 (comment 6353981632, footer stripped). No transform finding filed. Still watching scoped halo 39857142295 (066cd28, queued) and full CI 39872261116 (be1ee9c, queued) and 39874681231 (5e4d678, pending), all holding 55d96ee.
- 2026-10-23T00:19:11Z: heartbeat. No green macOS run holding 55d96ee yet. Scoped halo 39857142295 still queued; full CI 39872261116 (be1ee9c) queued; 39874681231 cancelled; newest full CI 39877184360 (e854550) pending.
