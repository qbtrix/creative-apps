# export-pack (Flare) lead record

Issue: #3481 · Packet: docs/blueprints/flare/features/export-pack.md
Run: act-1a15d4ed024-1wsg · Session: claude/feature-lead-playbook-ahxuto · Started: 2026-10-21T02:26Z (line lead: gradient-fill #3419, file-flow #3482, export-pack #3481; resumed from act-1a15c47678d-i2ih)
Stage: 2 plan (blocked)
Base: b64cbb8c (origin/dev)
Next: check whether shell-media SM-a (MovieSettings, AnimatedImageSettings, FrameClock) is on dev. When it is, build FV-1, then FV-2 for the FV-a slice PR.

Loop: v3 (the packet has a `## Slices` table).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FV-a | MP4 and GIF with frame rate and loop on stubs; sheet chips and Size row | FV-1, FV-2 | MJ-FV | XP-a, shell-media SM-a | yes | 0 | blocked (SM-a) | | |
| FV-u | snapshots, render budget, journey written | FV-5, FV-6 | FJ-X1 | FV-a; XP-4 | yes | 0 | waiting | | |
| FV-m | frame plan, alpha, even size; live adapter streams to the writers | FV-3, FV-4 | MJ-FV | FV-a; XP-6 (merged), SM-w | no | 0 | waiting | | |
| FV-z | real files on live, journey passes, blueprint | FV-7, FV-8 | FJ-X1 | FV-u, FV-m; gradient-fill:FG-z; svg-place:PF-z | no | 0 | waiting | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FV-1 | FV-a | 1 | .mp4 and .gif with fps and loop, refused until FV-3 | Sources/FlareModel/FlareExport.swift, Tests/FlareModelTests/FlareVideoExportTests.swift | export tests pass; MP4 refused | – | blocked (SM-a) |

## Decisions
- 2026-10-21T07Z (act-1a15d4ed024-1wsg): resumed. SM-a still not on dev and not filed as a PR; the 02:32Z question on #3481 stands, so no second question until three identical polls.
- Belt watches lead/export-pack, which the suiteui export-pack lead (#3477) also uses for docs/leads/export-pack. This record lives at docs/leads/flare-export-pack/ so neither lead overwrites the other.
- PRs target dev (CLAUDE.md), as for file-flow.
- Rule 20: no Flare encoder and no local copy of MovieSettings or FrameClock, so FV-1 does not start until SM-a is on dev.

## Open
- shell-media (docs/blueprints/suite/features/shell-media.md) is `planned` with feature_issue "file when ready"; SM-a and SM-w are not on dev. All four slices wait on it. Noted on #3481.
- suiteui export-pack #3477 is labelled needs-human; XP-4 (FV-5) waits there.
- 2026-10-21T08:17Z: Parked per supervisor 08:01Z on #3481: SM-a #3711 waits for a Belt slot; not building SM-a.
- 2026-10-21T08:38Z: Still parked: SM-a #3711 has no slice PR yet.
- 2026-10-21T08:58Z: Still parked: SM-a #3711 has no slice PR.
- 2026-10-21T09:18Z: Still parked: SM-a #3711 has no slice PR.
- 2026-10-21T09:39Z: Still parked: SM-a #3711 has no slice PR.
- 2026-10-21T10:00Z: Still parked: SM-a #3711 has no slice PR.
- 10:20Z: Heartbeat: still parked; SM-a (#3711) has no slice PR.
- 10:40Z: Heartbeat: still parked; SM-a (#3711) has no slice PR.
- 11:00Z: Heartbeat: still parked; SM-a (#3711) has no slice PR.
- 11:19Z: Heartbeat: still parked; SM-a (#3711) has no slice PR.
- 11:40Z: Parked: SM-a #3711 still has no slice PR.
- 12:00Z: Parked: SM-a (shell-media #3711) still has no slice PR.
- 12:26Z: Parked: SM-a (shell-media #3711) still has no slice PR.
- 12:46Z: 
- 13:08Z: SM-a #4034 #4035 still open on lane.
- 13:28Z: SM-a #4034 #4035 still open on lane.
- 14:45Z: Records moved to lead/flare-export-pack. Still blocked on SM-a PRs #4034 and #4035; re-polled, both open.
- 15:06Z: #4034, #4035 still open in lane; waiting.
- 15:26Z: #4034, #4035 still open in lane; waiting.
- 15:46Z: #4034, #4035 still open in lane; waiting.
- 16:09Z: #4034, #4035 still open in lane. Note: macOS Xcode builds on dev fail on a project.yml core-pin mismatch; gradient-fill lead has a fixer on it.
- 16:28Z: #4034, #4035 still open in lane; waiting.
- 16:48Z: #4034, #4035 still open in lane; waiting.
- 17:11Z: heartbeat: waiting on SM-a #4034 #4035 (open in lane)
- 17:31Z: heartbeat: waiting on SM-a #4034 #4035 (open in lane)
- 17:51Z: Still waiting on SM-a #4034 #4035 (open in lane).
- 18:12Z: Waiting on SM-a #4034 (now needs-rebase, owner's to fix) and #4035.
- 18:32Z: Waiting on SM-a #4034 #4035 (in lane; #4034 needs-rebase cleared).
- 18:54Z: Waiting on SM-a #4034 and #4035 in the lane.
- 19:14Z: Waiting on SM-a #4034 and #4035 (open, fast-lane).
- 19:36Z: SM-a #4034 head 880c41ce sent to lane macOS build 19:27Z; #4035 open.
- 19:59Z: Waiting on SM-a #4034 (lane macOS build of 880c41ce) and #4035, both open.
- 20:21Z: No change: SM-a #4034 and #4035 open in the lane.
- 20:43Z: #4034 new head 8ca7a2e7: lane macOS build (every app) dispatched 20:26Z. #4035 open.
- 21:05Z: No change: #4034 (macOS build of 8ca7a2e7) and #4035 open.
- 21:26Z: No change: #4034 and #4035 open.
- 21:48Z: No change: #4034 and #4035 open.
