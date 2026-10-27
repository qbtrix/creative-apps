# fill-heal lead record

Issue: #3778 (#4513 closed as duplicate) · Packet: docs/blueprints/suiteui/features/fill-heal.md
Run: act-1a17bed1eba-upw1 (line lead: area-selection, fill-heal, adjust-everywhere; resumed 2026-10-27T05:58Z on main fef52e66) · earlier: act-1a1786024b0-c5o9 (line lead: clipboard-interop, area-selection, fill-heal; resumed 2026-10-26T13:26Z) · earlier: act-1a175f7cb67-l7rh (line lead: clipboard-interop, area-selection, fill-heal; resumed 2026-10-26) · earlier: act-1a1702c56e8-b6cq (line lead: shared-raw, area-selection, fill-heal) · Session: claude/suiteui-feature-lead-run-8ka39r · Started: 2026-10-24T22:40Z (earlier act-1a16cae7989-hj12, act-1a16cae79dd-mtf2)
Stage: 3 wave 2 (wave-2 PRs open, gated; stacks in the lane)
Base: main fef52e66 (verified) / dev 5e4a0922
Next: #4889 (FH-u) re-integrated at 5a1a54b2 (merged origin/dev, scripts/ci --changed PASS, Head moved); waiting on the lane batch. When it merges retarget #4896 (add fast-lane) and #5245 to dev, then the FH-7 chain, #5109, #5251; FH-c waits on fix PRs #5121, #5129, #5137.
Polled: 2026-10-27T08:06Z · 08:05Z check-in: #4896 (FH-u) merged to dev; FH-u done awaits a main ci run containing it. #5096 #5125 #5149 ready in lane; dev-red #5818 open (revert #5827 not landed). #5093 still awaiting supervisor answer.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FH-a | rules, commands and dab coverage as stubs, checks disabled | FH-1, FH-2 | MJ-FH | suite-imaging:IM-a, brush-keys:BK-m (FH-1 only) | false | 0 | done (Belt-Slice-Done posted) | 39957675362 | – |
| FH-u | palette Paint Bucket, Spot Heal, Remove on the stubs | FH-3, FH-4 | PJ-FH1 | FH-a, AB-photo, AL-photo, AX-photo, AU-photo, AC-colour, BK-photo | true | 0 | lane (FH-3 #4889 head ccf9d81; FH-4 #4896 stacked on FH-3) | – | – |
| FH-r | bucket and heal bodies over core | FH-5b, FH-5h | MJ-FH | FH-a | false | 0 | done (Belt-Slice-Done posted) | 40005632479 | – |
| FH-c | dab coverage body, commands one undo step | FH-5k, FH-6 | MJ-FH | FH-a, FH-r | false | 0 | lane (#4577 base dev, head 7d32ede) | – | – |
| FH-photo | Photo adopts live, old tone-match heal gone, jobs pass | FH-7, FH-8, FH-9, FH-10 | PJ-FH1, PJ-FH2, MJ-FH-photo, MJ-FH | FH-c, FH-u, AJ-photo, BK-photo | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FH-1 | FH-a | 2+ | stubs + disabled checks | Sources/SuiteImaging/Retouch/*, Sources/SuiteKernel/Stroke/DabCoverage.swift, tests, C4 parts | suites compile, disabled | #4556 | merged (in green full run 39957675362) |
| FH-2 | FH-a | 1 | RJ-P51 folder, RJ-P04/P07 re-pointed, disabled waits_on FH-6 | Tests/RealJobs/photo/{bucket-background,dust-spots,remove-passerby}/* | RealJobs decode check | #3845 | merged (in green dev Linux run 39808732641) |
| FH-3 | FH-u | 3 | palette Paint Bucket, Spot Heal, Remove disabled with help; bucket options | Sources/PhotoModel/*, Sources/PhotoApp/*, Tests/PhotoModelTests/PhotoRetouchToolsTests.swift, UITests/PhotoJourneyTests+Retouch.swift | PhotoRetouchToolsTests, photo.list-commands golden | #4889 | lane (6ad2a444, base dev) |
| FH-7 | FH-photo | 4 | PhotoWorkspace: RetouchTarget, heal via retouch.heal, toneShift gone, RJ-P51 on | Sources/PhotoModel/PhotoRetouch*.swift, PhotoStroke, catalog, ids, mutations | PhotoRetouchKernelTests, Mutate 4/4 | #5245 (7a), #5107 (7b) | stacked on #4889 |
| FH-7j | FH-photo | 4 | RJ-P04 dust-spots on (split from FH-7 for the 15-file cap) | Tests/RealJobs/photo/dust-spots/* | RealJobs | #5108 | stacked on #5107 |
| FH-8..FH-10 | FH-photo | later | see packet | see packet | see packet | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-26T02:14Z: Run act-1a175f7cb67-l7rh resumed. #4889 got needs-rebase (photo.list-commands.json conflict); fixing by merging origin/dev and regenerating the golden.
- 2026-10-25T04:45Z: #4889 needs-rebase: merged origin/dev, union-merged photo.list-commands golden by id (matches command-ids ledger), scripts/ci --changed PASS, pushed 7ebd2bcf1, Head moved.
- 2026-10-25T01:45Z: FH-9 opened as #5253 (docs-only C4, on dev, head 2f2b89ff) and FH-10 as #5251 (feature-done, on FH-8, head 2043f944), both CI: PASS.
- 2026-10-25T01:15Z: wave 2: FH-9 (C4-only, on dev) and FH-10 (feature-done, on FH-8) building; 0 open findings.
- 2026-10-25T01:20Z: replay done: #5107 split into #5245 (FH-7a, 10 files, on FH-3) and #5107 (FH-7b, 7 files, on FH-7a); #5108, #5129 on FH-7; #5109 on lead/fill-heal-FH-8-base (FH-7b + FH-4 merged), retarget to dev once both land; #5121 #5137 on dev. All CI: PASS.
- 2026-10-24T23:20Z: dev was rewritten to a new root (4f00afb8, #5150); old slice branches share no history with it, so fixers replay each PR's own commits onto the new dev, split to the 400-line/15-file cap, re-gate and force-with-lease push the lead/* branches (same PR numbers).
- 2026-10-24T06:54Z: relaunch (16 h limit; captain: full capacity). FH-7 built ahead now, stacked on #4577 (FH-6) and #4889 (FH-3), rule 22/23: AJ-photo is a shared-file order wait (catalog, ledger), not code; the lane integrates the conflict if AJ-photo lands first.
- PR base stays dev: CLAUDE.md and the lane retarget main to dev (the brief's "base main" is the integration branch name, its HEAD verified).
- 2026-10-23T16:49Z: FH-3 help text names FH-8 (the slice that enables the tools), not the packet's FH-5. Shift-J cycling needs SuiteUI: #4890 (needs-ui); Remove has no key until then. Spot heal and remove share the brush's Size/Hardness.
- 2026-10-23T16:29Z: supervisor (#3778, 6369319918): AB-photo done; AJ-photo unmet (AJ-a not merged); start FH-u now on brush-keys' fakes; keep the slot while FH-r, FH-c, FH-u move; if only FH-photo is left and AJ-a is not on dev, release the run.
- 2026-10-23T14:10Z: run act-1a1693a401e-chyn takes over on #3778 (supervisor: #4513 duplicate, #4574 counts under #3778). #4574/#4577 sat on branch bases the lane does not take; dev merged in (FH-a's squash, ours kept), gate rerun, retargeted to dev.
- Base dev, not main: CLAUDE.md and the lane retarget main to dev.
- Status mirrored to lead/suiteui-fill-heal (docs/leads/suiteui-fill-heal/), the branch name Belt's nudge read; lead/fill-heal kept, per the brief.
- FH-2 has no wait of its own (the slice waits list FH-1 only), so it ships in wave 1 while FH-1 waits on IM-a and BK-m.
- 2026-10-22T16:40Z: run act-1a164697376-dv7u takes over from act-1a15cb4e0f5-ipbr on new issue #4513. FH-1 is unblocked: IM-a's SuiteImaging target is on dev (IM-1 #4028, IM-4 #4393) and BK-m is Belt-Slice-Done on #3758 (run 39661533247); #4513 carries no waiting label.
- 2026-10-22T16:40Z: FH-a, FH-r and FH-c go to one builder, stacked (lead/fill-heal-FH-a -> -FH-r -> -FH-c); each child PR bases on its parent branch and retargets to dev when the parent merges.

## Wire
- [ ] Wire: brush-keys:BK-photo (built on its fakes in FH-3/FH-4; swap in when it merges)

## Open
- 2026-10-24T07:55Z: findings filed from FH-7's build: #5093 (bucket edge tint), #5094 (feathered coverage squared), #5095 (heal throws off-canvas). Open findings: 3. RJ-P07 stays disabled (needs select.lasso).
- 2026-10-23T16:59Z: FH-4 PR #4896 (stacked on #4889, head 57c9396, gate pass); #4895 filed (needs-ui stroke-trail mark; MotionPathMarks placeholder).
- 2026-10-23T16:08Z: FH-u/FH-photo waits unchanged 3 polls; question for the supervisor on #3778 (comment 6369264328).
- 2026-10-23T14:10Z: waits: AB-photo building (adopt-kernel-brush lead record, last push 10-19), BK-photo blocked (#4531), AJ-photo waiting (#3777); AL, AX, AU, AC done. FH-u and FH-photo stay blocked.
- suite-imaging #3715: no lead branch, no slice done, Sources/SuiteImaging absent on dev (2026-10-21T02:36Z). Blocks FH-1, so every later slice.
- brush-keys #3758: BK-m not done. Blocks FH-1.
- 2026-10-21T04:29Z: run act-1a15c4e2e3b-zh3u was released by Belt at 04:25Z; act-1a15cb4e0f5-ipbr carries its state (lead branches, open slice PRs) rather than redoing it. The supervisor (04:24Z, #3778): wait, do not build IM-a or BK-m; the p0 issues start next shift; release at 06:30Z if nothing has landed.
- 2026-10-22T16:40Z: FH-u and FH-photo wait on Photo adopts AB-photo, AL-photo, AX-photo, AU-photo, AC-colour, BK-photo, AJ-photo; checked each wave.


- 2026-10-27T06:02Z: dev-red #5818 is SuiteUI home/grid/tabs snapshots, not this feature; main holds at fef52e66. #4896 ready; #5245 (FH-u) conflicted with dev (tone commands), merging dev in now; #5107/#5108/#5129/#5109/#5251 stacked.
