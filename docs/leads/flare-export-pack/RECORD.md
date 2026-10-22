# export-pack (Flare) lead record

Issue: #3481 · Packet: docs/blueprints/flare/features/export-pack.md
Run: act-1a160bffba1-bvv3 · Session: claude/feature-lead-playbook-ahxuto · Started: 2026-10-21T02:26Z (line lead: gradient-fill #3419, file-flow #3482, export-pack #3481; resumed from act-1a15c47678d-i2ih) · resumed from act-1a15d4ed024-1wsg at 23:2xZ
Stage: 3 build
Base: 8c55f0bf9 (origin/dev)
Next: FV-2 once XP-3 is on dev, then the FV-a PR

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
- 23:30Z: Resumed as act-1a160bffba1-bvv3. SM-a #4034 #4035 still open; SM-m #4119 #4123, SM-w #4125 #4237, SM-r #4128 #4239 also open. Parked.
- 2026-10-21T23:58Z: 23:58Z: SM-1 #4034 merged 23:32Z; SM-2 #4035 still open, so the SM-a slice isn't merged yet.
- 2026-10-22T00:36Z: heartbeat: #4035 still open in lane
- 2026-10-22T01:00Z: SM-2 #4035 failed lane macOS build (run 39698491954), owned by the shell-media lead
- 2026-10-22T01:24Z: heartbeat 01:24Z: #4259 lane rebuild 39703409910 still queued; #4257 not merged yet (build green); #4035 open; full run 39700185524 Linux red on FormatListRatchetTests.realTreePasses (SuiteModel Media.swift, not ours), no slice credit
- 2026-10-22T01:35Z: Records now also live on lead/flare-* (the branches Belt watches); every stage pushes there.
- 2026-10-22T01:44Z: Heartbeat: #4259 build 39703409910 still queued (macOS runners busy); #4257, #4035 open; no green-Linux run containing FG-m yet.
- 2026-10-22T02:16Z: No change: #4035 open.
- 2026-10-22T03:12Z: Heartbeat: #4259 (593d9118) and #4257 (d417a35f) wait on lane macOS builds; #4035 too. dev Linux green at 66a84588.
- 2026-10-22T03:39Z: Heartbeat: #4259 macOS build queued, #4257 macOS build running; #4035 macOS+Linux green, awaiting lane merge.
- 2026-10-22T04:02Z: SM-2 #4035 merged 03:53Z, so SM-a is on dev; XP-1/XP-6 on dev, XP-3 not. FV-1 started on lead/export-pack-fva; the FV-a PR opens with FV-2 once XP-3 is on dev
- 2026-10-22T04:18Z: FV-1 done on lead/export-pack-fva at ed2293cc (+140/-10, 8 files, gate PASS); the sheet hides unbuilt formats until FV-2. XP-3 not on dev yet.
- 2026-10-22T04:24Z: XP-3 still not on dev; FV-2 waits
- 2026-10-22T04:52Z: XP-3 still not on dev; FV-2 waits
- 2026-10-22T05:19Z: XP-3 still not on dev; FV-2 waits
- 2026-10-22T06:06Z: FV-1 still held on lead/export-pack-fva (ed2293cc); XP-3 not on dev yet.
- 2026-10-22T06:35Z: XP-3 still not on dev.
