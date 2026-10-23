# fill-heal lead record

Issue: #3778 (#4513 closed as duplicate) · Packet: docs/blueprints/suiteui/features/fill-heal.md
Run: act-1a1693a401e-chyn · Started: 2026-10-23T14:10Z (prior: act-1a164697376-dv7u)
Stage: 3 wave 1
Base: cb79cbb (dev, verify HEAD)
Next: FH-r slice-done once a green suiteui/full ci.yml run on dev holds a05d7be; FH-c #4577 and FH-u #4889/#4896 in lane; poll lane and dev CI every 20 min; FH-photo waits checked each poll

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FH-a | rules, commands and dab coverage as stubs, checks disabled | FH-1, FH-2 | MJ-FH | suite-imaging:IM-a, brush-keys:BK-m (FH-1 only) | false | 0 | done (Belt-Slice-Done posted) | 39957675362 | – |
| FH-u | palette Paint Bucket, Spot Heal, Remove on the stubs | FH-3, FH-4 | PJ-FH1 | FH-a, AB-photo, AL-photo, AX-photo, AU-photo, AC-colour, BK-photo | true | 0 | building (FH-3 #4889 in lane, head ccf9d81; FH-4 next) | – | – |
| FH-r | bucket and heal bodies over core | FH-5b, FH-5h | MJ-FH | FH-a | false | 0 | merged a05d7be (#4574); awaiting green suiteui/full run | – | – |
| FH-c | dab coverage body, commands one undo step | FH-5k, FH-6 | MJ-FH | FH-a, FH-r | false | 0 | lane (#4577 base dev, head 7d32ede) | – | – |
| FH-photo | Photo adopts live, old tone-match heal gone, jobs pass | FH-7, FH-8, FH-9, FH-10 | PJ-FH1, PJ-FH2, MJ-FH-photo, MJ-FH | FH-c, FH-u, AJ-photo, BK-photo | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FH-1 | FH-a | 2+ | stubs + disabled checks | Sources/SuiteImaging/Retouch/*, Sources/SuiteKernel/Stroke/DabCoverage.swift, tests, C4 parts | suites compile, disabled | #4556 | merged (in green full run 39957675362) |
| FH-2 | FH-a | 1 | RJ-P51 folder, RJ-P04/P07 re-pointed, disabled waits_on FH-6 | Tests/RealJobs/photo/{bucket-background,dust-spots,remove-passerby}/* | RealJobs decode check | #3845 | merged (in green dev Linux run 39808732641) |
| FH-3 | FH-u | 3 | palette Paint Bucket, Spot Heal, Remove disabled with help; bucket options | Sources/PhotoModel/*, Sources/PhotoApp/*, Tests/PhotoModelTests/PhotoRetouchToolsTests.swift, UITests/PhotoJourneyTests+Retouch.swift | PhotoRetouchToolsTests, photo.list-commands golden | #4889 | lane |
| FH-4..FH-10 | – | later | see packet | see packet | see packet | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
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
- 2026-10-23T16:59Z: FH-4 PR #4896 (stacked on #4889, head 57c9396, gate pass); #4895 filed (needs-ui stroke-trail mark; MotionPathMarks placeholder).
- 2026-10-23T16:08Z: FH-u/FH-photo waits unchanged 3 polls; question for the supervisor on #3778 (comment 6369264328).
- 2026-10-23T14:10Z: waits: AB-photo building (adopt-kernel-brush lead record, last push 10-19), BK-photo blocked (#4531), AJ-photo waiting (#3777); AL, AX, AU, AC done. FH-u and FH-photo stay blocked.
- suite-imaging #3715: no lead branch, no slice done, Sources/SuiteImaging absent on dev (2026-10-21T02:36Z). Blocks FH-1, so every later slice.
- brush-keys #3758: BK-m not done. Blocks FH-1.
- 2026-10-21T04:29Z: run act-1a15c4e2e3b-zh3u was released by Belt at 04:25Z; act-1a15cb4e0f5-ipbr carries its state (lead branches, open slice PRs) rather than redoing it. The supervisor (04:24Z, #3778): wait, do not build IM-a or BK-m; the p0 issues start next shift; release at 06:30Z if nothing has landed.
- 2026-10-22T16:40Z: FH-u and FH-photo wait on Photo adopts AB-photo, AL-photo, AX-photo, AU-photo, AC-colour, BK-photo, AJ-photo; checked each wave.

