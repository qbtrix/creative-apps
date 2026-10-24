# export-pack (Flare) lead record

Issue: #3481 · Packet: docs/blueprints/flare/features/export-pack.md
Run: act-1a16c619006-nour (took over 2026-10-24 from act-1a1695ebf10-z0v8; earlier act-1a160bffba1-bvv3) · Session: claude/feature-lead-export-pack-rpvio0 · Started: 2026-10-21T02:26Z
Stage: 3 build (fix round 1 in lane)
Base: 721168a (origin/dev)
Next: #5025 (fix round 1, r-b1) merged dev and now draws live MP4/GIF frames (StageRasterizer.frame, FV-7's drawing; the live refusal is dropped), head 9c2bc627, gate PASS. #5005 closed as its duplicate. FV-z's live journey needs both #4854 and #5025 on dev. Once both merge and a green run contains FV-u and FV-z, post Belt-Slice-Done FV-u and FV-z + Mac-Finish-Wanted on #3481, then the FJ-X1 critic panel and the contact sheet. 10 findings open: no new feature work.

Loop: v3 (the packet has a `## Slices` table).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FV-a | MP4 and GIF with frame rate and loop on stubs; sheet chips and Size row | FV-1, FV-2 | MJ-FV | XP-a, shell-media SM-a | yes | 1 | merged-done; review 1 filed #5012-#5021 (10); fix round 1 PR #5025 (clean, in lane; on #5012 #5013 #5014 #5015 #5017 #5018 #5020); #5016/#5019 wait on needs-ui #4819, #5021 on #5023, #5012's unit on #5022 | https://github.com/qbtrix/creative-apps/actions/runs/40029025919 | |
| FV-u | snapshots, render budget, journey written | FV-5, FV-6 | FJ-X1 | FV-a; XP-4 | yes | 0 | PR #4852 (base dev, clean, awaiting lane batch; Head c1835cd6) | | |
| FV-m | frame plan, alpha, even size; live adapter streams to the writers | FV-3, FV-4 | MJ-FV | FV-a; XP-6 (merged), SM-w | no | 0 | done (Belt-Slice-Done posted) | https://github.com/qbtrix/creative-apps/actions/runs/39957675362 | n/a |
| FV-z | real files on live, journey passes, blueprint | FV-7, FV-8 | FJ-X1 | FV-u, FV-m; gradient-fill:FG-z; svg-place:PF-z | no | 0 | PR #4854 (base lead/export-pack-fvu, stacked on #4852; feature-done) | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FV-1 | FV-a | 1 | .mp4 and .gif with fps and loop, refused until FV-3 | Sources/FlareModel/FlareExport.swift, Tests/FlareModelTests/FlareVideoExportTests.swift | export tests pass; MP4 refused | #4414 | merged c07dcd11 |
| FV-3 | FV-m | 2 | frame plan for MP4 and GIF | FlareExport+Kernel.swift, RealJobs | FlareVideoExportTests | #4435 | merged 465c2794 |
| FV-4 | FV-m | 2 | live adapter streams frames into the media writers | LiveExportAdapter.swift, FakeExport.swift | FlareVideoWriteTests | #4436 | merged dbc4b87e |
| FV-2 | FV-a | 2 | sheet: MP4/GIF, Frame rate, Loop forever, shared Size row; window writes through writeVideo | FlareExportSheetAdapter.swift, FlareWindow+Export.swift, FlareIntent*.swift | FlareExportPackSnapshots.gif, FlareVideoExportTests | #4843 | open, fast-lane, gate PASS a46aee36 |
| FV-5 | FV-u | 2 | a video run counts its planned frames; running snapshot; progress render budget | FlareExport+Kernel.swift | FlareVideoExportTests.aVideoRunCountsItsFrames, FlareExportPackSnapshots.running, RenderBudgetFlareExportPackTests | #4852 | open, fast-lane, gate PASS 232b7c0d, mutate 11/11 |
| FV-6 | FV-u | 2 | FJ-X1 journey written, skipped behind live=false until FV-7 | UITests/FlareJourneyTests+ExportPack.swift | FlareExportPackJourneyTests | #4852 | open |
| FV-7 | FV-z | 4 | journey on live (live flag removed) | UITests/FlareJourneyTests+ExportPack.swift | FlareExportPackJourneyTests | #4854 | open, fast-lane, feature-done |
| FV-8 | FV-z | 5 | flare.md: MP4 and GIF; wave status built | docs/blueprints/flare.md, export-pack.wave.json | waves render | #4854 | open |

## Decisions
- 2026-10-23T17:03Z (act-1a1695ebf10-z0v8): Belt watches lead/flare-export-pack; this run had pushed status to lead/export-pack. From now the record and timeline live on lead/flare-export-pack (timeline rows from both branches merged, in order).
- 2026-10-23T15:46Z: Wire: suiteui/export-pack:XP-a (pixel and long-edge Size modes, XP-3/XP-4). FV-2 uses the shared scale row; the Model already takes .pixels and .longEdge.
- 2026-10-23T15:59Z: FV-u's run total is the plan's frame count for MP4/GIF (first-use clarity: the bar sat at 0 of 1). FV-u's PR is based on lead/export-pack-fv2 because a dev-based diff would be 418 lines, over the cap; it retargets to dev when #4843 merges.
- 2026-10-23T16:03Z: FV-8 went ahead: FG-z (the flare.md owner) is on dev (#4257); svg-place's PF-z is not built yet, and its PF-8 edits other flare.md rows.
- 2026-10-23T15:46Z: FV-5's snapshot file lands in the FV-a PR as FV-2's acceptance test; FV-u adds the running state and the render budget.
- 2026-10-21T07Z (act-1a15d4ed024-1wsg): resumed. SM-a still not on dev and not filed as a PR; the 02:32Z question on #3481 stands, so no second question until three identical polls.
- Belt watches lead/export-pack, which the suiteui export-pack lead (#3477) also uses for docs/leads/export-pack. This record lives at docs/leads/flare-export-pack/ so neither lead overwrites the other.
- PRs target dev (CLAUDE.md), as for file-flow.
- Rule 20: no Flare encoder and no local copy of MovieSettings or FrameClock, so FV-1 does not start until SM-a is on dev.
- 2026-10-24: this session's GitHub writes get the attribution footer appended on the way out, so PATCHing it out of PR bodies doesn't hold; the lane strips it from the squash commit and waits on nothing for it. Left as is.

- 2026-10-24: the FV-u budget test hang is #4852's own defect (stack: FlareFileDialogs.chooseFolder from startExport), not a flake: fixed on its branch rather than waiting for the bisect's needs-fix.

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
- 2026-10-22T07:05Z: XP-3 still not on dev.
- 2026-10-22T07:31Z: XP-3 still not on dev.
- 2026-10-22T07:59Z: XP-3 still not on dev.
- 2026-10-22T08:26Z: XP-3 still not on dev.
- 2026-10-23T15:46Z: FV-m done (full green run 39957675362 contains #4435 and #4436); FV-a PR #4843 opened.
