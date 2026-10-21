# export-pack (Flare) lead record

Issue: #3481 · Packet: docs/blueprints/flare/features/export-pack.md
Run: act-1a15c47678d-i2ih · Session: session_01KmedgAV8daBEtcQfR1LURr · Started: 2026-10-21T02:26Z (line lead: stage-edit #1514, file-flow #3482, export-pack #3481)
Stage: 2 plan (blocked)
Base: 2ab0eb96 (origin/dev)
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
- Belt watches lead/export-pack, which the suiteui export-pack lead (#3477) also uses for docs/leads/export-pack. This record lives at docs/leads/flare-export-pack/ so neither lead overwrites the other.
- PRs target dev (CLAUDE.md), as for file-flow.
- Rule 20: no Flare encoder and no local copy of MovieSettings or FrameClock, so FV-1 does not start until SM-a is on dev.

## Open
- shell-media (docs/blueprints/suite/features/shell-media.md) is `planned` with feature_issue "file when ready"; SM-a and SM-w are not on dev. All four slices wait on it. Noted on #3481.
- suiteui export-pack #3477 is labelled needs-human; XP-4 (FV-5) waits there.
