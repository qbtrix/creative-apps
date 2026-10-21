# fill-heal lead record

Issue: #3778 · Packet: docs/blueprints/suiteui/features/fill-heal.md
Run: act-1a15c4e2e3b-zh3u · Session: claude/fill-heal-adjust-everywhere-t5hvqe · Started: 2026-10-21T02:36Z
Stage: 3 wave 1
Base: 2ab0eb96320db973b5aad0644449ee5ed3980ab9
Next: blocked poll 2/3 at 04:00Z (#3715 IM-a, #3758 BK-m open, no PRs, dev 842e62ec1); #3845 in lane; at 3/3 ask the supervisor on #3778

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FH-a | rules, commands and dab coverage as stubs, checks disabled | FH-1, FH-2 | MJ-FH | suite-imaging:IM-a, brush-keys:BK-m (FH-1 only) | false | 0 | building (FH-2) | – | – |
| FH-u | palette Paint Bucket, Spot Heal, Remove on the stubs | FH-3, FH-4 | PJ-FH1 | FH-a, AB-photo, AL-photo, AX-photo, AU-photo, AC-colour, BK-photo | true | 0 | waiting | – | – |
| FH-r | bucket and heal bodies over core | FH-5b, FH-5h | MJ-FH | FH-a | false | 0 | waiting | – | – |
| FH-c | dab coverage body, commands one undo step | FH-5k, FH-6 | MJ-FH | FH-a, FH-r | false | 0 | waiting | – | – |
| FH-photo | Photo adopts live, old tone-match heal gone, jobs pass | FH-7, FH-8, FH-9, FH-10 | PJ-FH1, PJ-FH2, MJ-FH-photo, MJ-FH | FH-c, FH-u, AJ-photo, BK-photo | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FH-1 | FH-a | 2+ | stubs + disabled checks | Sources/SuiteImaging/Retouch/*, Sources/SuiteKernel/Stroke/DabCoverage.swift, tests, C4 parts | suites compile, disabled | – | blocked (IM-a, BK-m) |
| FH-2 | FH-a | 1 | RJ-P51 folder, RJ-P04/P07 re-pointed, disabled waits_on FH-6 | Tests/RealJobs/photo/{bucket-background,dust-spots,remove-passerby}/* | RealJobs decode check | #3845 | in lane (Fast-Check pass, clean) |
| FH-3..FH-10 | – | later | see packet | see packet | see packet | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base dev, not main: CLAUDE.md and the lane retarget main to dev.
- Status mirrored to lead/suiteui-fill-heal (docs/leads/suiteui-fill-heal/), the branch name Belt's nudge read; lead/fill-heal kept, per the brief.
- FH-2 has no wait of its own (the slice waits list FH-1 only), so it ships in wave 1 while FH-1 waits on IM-a and BK-m.

## Open
- suite-imaging #3715: no lead branch, no slice done, Sources/SuiteImaging absent on dev (2026-10-21T02:36Z). Blocks FH-1, so every later slice.
- brush-keys #3758: BK-m not done. Blocks FH-1.
