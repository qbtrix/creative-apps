# cli-bundle lead record

Issue: #3773 · Packet: docs/blueprints/suite/features/cli-bundle.md
Run: act-1a175f7cc55-xlmt (relaunch; earlier act-1a17129eefa-0kqr, act-1a16daeb4e8-vghz, act-1a16a37a3ed-0kyn, act-1a166b69fd0-x9m8) · Started: 2026-10-23T03:08Z
Stage: 3 polling (CB-z: #4999 queued in the lane; #5000 waits on #4999)
Base: d3323f6a7dc523e1986e1693b640cf377e362f08 (main, verified at relaunch; PRs target dev 8987427d8)
Next: the lane (now listing every PR after main promoted to 4f00afb with #5150) batches #4999; once it merges, rebuild #5000 on dev (3 docs files + feature_issue #3773), drop no-fast-lane, move Head.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CB-a | BundleLayout.cliPath, AssistantConnect stubs, help catalog stubs, checks disabled | CB-1, CB-2 | MJ-CB | report-problem:RP-m (met) | no | 0 | done | 39983291011 | - |
| CB-u | Connect an AI Assistant sheet on the stubs; render budget | CB-5, CB-5b | XJ-CB | CB-a; RP-u (met) | yes | 0 | done | 39983291011 | - |
| CB-m | bodies + bundled signed afterglow (CB-3 supervisor merge) | CB-4, CB-3 | MJ-CB, XJ-CB | CB-a | no | 0 | done | 39983291011 | - |
| CB-z | Install Command-Line Tool; RJ-X62 on; built | CB-6, CB-7, CB-8 | XJ-CB, MJ-CB | CB-u, CB-m | yes | 0 | building (on CB-u + CB-m) | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CB-1 | CB-a | 1 | cliPath, AssistantConnect stubs, disabled tests, C4 part | packet CB-1 (4 files) | compiles, disabled by name | - | open #4715 |
| CB-2 | CB-a | 1 | help.connect-assistant + help.install-cli stubs, ids, MCPConfig provider | packet CB-2 (4 files) | specs list | - | open #4715 |
| CB-5 | CB-u | 2 | Help item + AssistantConnectSheet; journey skipped | packet CB-5 (3 files) | XJ-CB | - | open |
| CB-5b | CB-u | 2 | RenderBudgetConnectTests | 1 file | openSheetInTwoBodies | - | open |
| CB-4 | CB-m | 2 | AssistantConnect + help bodies; tests on | packet CB-4 (5 files) | Mutate SuiteModel.AssistantConnect | - | open |
| CB-3 | CB-m | 2 | bundle-apps copies and signs afterglow (supervisor merge) | scripts/bundle-apps, C4, job | macOS bundle | - | open |
| CB-6 | CB-z | 3 | Install Command-Line Tool | InstallCommandLineTool.swift, journey | XJ-CB | - | waiting |
| CB-7 | CB-z | 4 | RJ-X62 on; suite.md 1.4 | 2 files | RJ-X62 | - | waiting |
| CB-8 | CB-z | 4 | status built; feature-done | wave.json | waves render | - | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (e055e6713e4e852d6c19d98f7c2fd82c6758e67a), not main: the packet exists only on dev, and CLAUDE.md, lead.md and the fast lane all target dev. main HEAD 0dd23d65 verified at start.
- Status mirrored to lead/suite-cli-bundle (docs/leads/suite-cli-bundle/) as well as lead/cli-bundle, as earlier suite leads did.
- PR bodies carry no attribution footer; any footer the tooling adds is removed with update_pull_request after the PR opens.
- One combined wave plan across #3776, #3774 and #3773 (same session); builders are worktree subagents, at most 4 at once.
- CB-3 edits scripts/bundle-apps (protected): opened without fast-lane as a supervisor-merge PR.

## Open

- C4-only PR: suite-packaging description gains the CLI path and AssistantConnect: opened #4755.
- `--bundle` flag in Arguments.swift: wire in CB-m (MCPConfig.bundle(flag:) already takes it).
- CB-3 goes as its own PR on `lead/cli-bundle-CB-m-bundle` with `no-fast-lane` (protected scripts/bundle-apps; supervisor merges).
- 04:45Z #4715 (CB-a) merged. CB-m #4740, CB-m-bundle #4741 (no-fast-lane, supervisor), CB-u #4743 (test-first split, Mutate 3/3) merged origin/dev; gate rerun before retarget to dev. C4-only suite-packaging description PR is now due.
- 2026-10-23T05:22Z CB-u #4743 and CB-m-bundle #4741 merged origin/dev, gate rerun (CB-u: only dev-red #3856 fails; CB-m-bundle: CI: PASS), pushed, retargeted to dev.
- 2026-10-23T05:24Z #4741 got needs-split (1428/51 counted against the merged CB-a base); replied that on dev it is 3 files ~63 lines. CB-z builder started.

## 2026-10-23T06:20:27Z
- Merged: #4740 CB-m, #4743 CB-u, #4755 C4 packaging.
- CB-z split to stay ≤15 files: code on lead/cli-bundle-CB-z (13 files, 0e6a426b1), docs (suite.md, cli-bundle.wave.json built, jobs.json) on lead/cli-bundle-CB-z-docs (f6a22109b), which carries feature-done.
- Both PRs open after #4741 (supervisor, scripts/bundle-apps) merges; CB-z's diff against dev otherwise holds that protected path.
- Gap #4762: the bundle runner RJ-X62 waits on.
- 2026-10-23T19:28Z Relaunch act-1a16a37a3ed-0kyn: rebased on main 35a0b5e7e. Full CI https://github.com/qbtrix/creative-apps/actions/runs/39983291011 (green, main) holds CB-a (#4755), CB-u (#4743) and CB-m (#4740); done markers posted. #4741 (CB-m bundle script) is still open with the supervisor; CB-z waits on it.

## 2026-10-24T11:35Z relaunch act-1a16daeb4e8-vghz
- lead/cli-bundle rebased on main 9f476af (88 record commits, docs/leads only).
- Lane starvation cause (--limit 100) fixed by #5150 on dev 4f00afb; lane runs scripts from main, so it applies after full CI run 40087964618 promotes.
- #4999 open, clean, Head 941da48 matches; #5000 held (no-fast-lane) until #4999 merges.
- 12:12Z full CI 40087964618 green; main promoted 9f476af -> 4f00afb (holds #5150).
- 14:13Z lane run 40100183592 rates #4999 eligible (Fast-Check marker, 298 lines/13 files, CLEAN); it waits because batch lane/batch-20261024110214 (12 PRs, from 11:02Z) is still bisecting (probe 3). One batch at a time, so #4999 joins the next one.
- 15:05Z batch 20261024110214 resolved; new batch lane/batch-20261024144917 (14:49Z) holds 12 older/priority PRs (#3621 … #4951), not #4999. #4999 stays eligible for a later batch.

## 2026-10-25T03:48:09Z relaunch act-1a17129eefa-0kqr
- lead/cli-bundle rebuilt on main afef017 (record files only).
- #4999 open, merges clean with dev, Head 941da48 current; not in batch-20261025023716 (bisecting). #5000 held (no-fast-lane, needs-split) until #4999 merges.
- 2026-10-25T04:07:19Z: #4999 still waits; batch-20261025023716 bisecting.
- 2026-10-25T04:17:23Z: Belt nudge: mirror lead/suite-cli-bundle resynced. #4999 waits for the next batch (batch-20261025023716 at probe -1).
- 2026-10-25T04:35:51Z: #4999 waits for the next batch; batch-20261025023716 still bisecting
- 2026-10-25T04:53:45Z: #4999 waits for the next batch; batch-20261025023716 still at probe -1
- 2026-10-25T05:11:37Z: #4999 waits for the next batch; batch-20261025023716 at probe -2
- 2026-10-25T05:30:03Z: batch-20261025023716 resolved; #4999 ready for next batch; body carries run act-1a17129eefa-0kqr
- 2026-10-25T05:48:01Z: lane batch-20261025054232 running without #4999; waits for the next batch
- 2026-10-25T06:06:02Z: batch-20261025054232 (not ours) bisecting; #4999 waits for the next batch
- 2026-10-25T06:23:57Z: batch-20261025054232 (not ours) still bisecting; #4999 waits for the next batch
- 2026-10-25T06:41:52Z: batch-20261025054232 probe -6 macOS still running; #4999 waits for the next batch
- 2026-10-25T06:59:49Z: batch-20261025054232 probe -6 macOS still running; #4999 waits for the next batch
- 2026-10-25T07:17:50Z: batch-20261025054232 (not ours) at probe -3; #4999 waits for the next batch
- 2026-10-25T07:35:44Z: batch-20261025054232 probe -3 macOS running; #4999 waits for the next batch
- 2026-10-25T07:53:37Z: batch-20261025054232 probe -3 macOS still running; #4999 waits for the next batch
- 2026-10-25T08:11:29Z: batch-20261025054232 probe -3 macOS still running; #4999 waits for the next batch
- 2026-10-25T08:29:24Z: batch-20261025054232 probe -4 running; #4999 waits for the next batch
- 2026-10-25T08:47:24Z: no batch in flight; #4999 clean and ready for the next batch
- 2026-10-25T09:06:07Z: batch-20261025090316 (p0 PRs) running without #4999; waits for the next batch. Same body-footer note as editor-menus
- 2026-10-25T09:24:02Z: batch-20261025090316 (p0, not ours) bisecting; #4999 waits
- 2026-10-25T09:41:54Z: batch-20261025090316 (p0, not ours) probe -6 macOS running; #4999 waits
- 2026-10-25T09:59:52Z: batch-20261025090316 (p0, not ours) still bisecting; #4999 waits
- 2026-10-25T10:17:58Z: batch-20261025090316 (p0, not ours) still bisecting; #4999 waits
- 2026-10-25T10:35:57Z: batch-20261025090316 (p0, not ours) bisecting; #4999 waits
- 2026-10-25T10:54:04Z: batch-20261025090316 (p0, not ours) bisect narrowing; #4999 waits
- 2026-10-25T11:12:03Z: no batch in flight; #4999 clean, ready for the next batch
- 2026-10-25T11:30:14Z: batch-20261025111803 (#4886 only) running; #4999 waits for the next batch
- 2026-10-25T11:48:11Z: batch-20261025111803 resolved without #4999; still open, clean, fast-lane; waiting for next batch
- 2026-10-25T12:07:06Z: #4999 lane decision pending: waiting for supervisor's local-ci/prescreen status on head 941da487; supervisor: please pre-screen #4999
- 2026-10-25T12:25:07Z: #4999 still waiting for local-ci/prescreen on 941da487 (supervisor)
- 2026-10-25T12:43:10Z: #4999 still waiting for local-ci/prescreen on 941da487 (supervisor)
- 2026-10-25T13:01:08Z: #4999 still waiting for local-ci/prescreen on 941da487 (supervisor)
- 2026-10-25T13:19:02Z: #4999 local-ci/prescreen now success on 941da487; eligible, waiting for the lane
- 2026-10-25T13:37:13Z: #4999 prescreen green, eligible; waiting for the lane
- 2026-10-25T13:55:08Z: #4999 eligible, queued behind p0 PRs; no batch in flight
- 2026-10-25T14:13:03Z: #4999 eligible, queued behind p0
- 2026-10-25T14:30:56Z: #4999 eligible, queued; no batch in flight
- 2026-10-25T14:48:50Z: #4999 eligible, queued behind p0
- 2026-10-25T15:06:43Z: #4999 eligible, queued; no batch in flight
- 2026-10-25T15:24:39Z: #4999 eligible, queued behind p0
- 2026-10-25T15:42:41Z: QUEUE: 50+ open p0 fast-lane PRs sort ahead of beta #4999; ~1 code PR per 20 min. Supervisor: raise #4999 to p0 if CB-z should land sooner
- 2026-10-25T16:00:37Z: #4999 still beta, queued behind p0

## 2026-10-26T02:12:53Z relaunch act-1a175f7cc55-xlmt
- main d3323f6 verified. #4999 open, clean, Head 941da48 current; #5000 held (no-fast-lane, needs-split) until #4999 merges. Belt-Lead line moved to this run.

## 2026-10-26T12:38:54Z relaunch act-1a178358362-etn1
- main d3323f6 verified. #4999 open, clean, beta, Head 941da48; Belt-Lead moved to this run. #5000 held until #4999 merges. Next: follow-up CB-z PR for the drift gaps (ShellHelpProvider.installCLI, CLI --bundle on help commands).
- 2026-10-26T12:38:54Z: relaunch act-1a178358362-etn1; scoping CB-z follow-up
- 2026-10-26T12:39:40Z: builder started: CB-z follow-up (in-app help.install-cli shares the CLI install plan), stacked on #4999; #4999 still beta, queued
- 2026-10-26T13:10:03Z: #5793 opened: in-app help.install-cli shares the CLI install plan (drift #5642), stacked on #4999; next: CLI --bundle builder (drift #5643)
- 2026-10-26T13:10:53Z: #4999 and #5793 open, fast-lane, beta, no lane comments since; --bundle builder running
- 2026-10-26T13:30:40Z: #5794 CLI --bundle (drift #5643), stacked on #5793; gate PASS at 11fc8017; Arguments plan 6/8 (2 pre-existing CLI.swift entries escape on stacked base, checking on dev)
- 2026-10-26T13:37:08Z: Arguments-plan escapes reproduce on dev (3/5), not #5794's: filed gap #5797 (p2, line:suite)
- 2026-10-26T13:39:58Z: 13:39: #4999 open fast-lane beta, mergeable, waiting; #5793 lost fast-lane (stacked size 519/21 counts #4999) and conflicted with dev in ShellHelpProvider betaNotes: merged dev, gate running; re-label after #4999 lands; #5794 fast-lane, unmergeable until #5793 resolves; #5000 unchanged
- 2026-10-26T14:01:51Z: #5793 merged dev (conflict resolved), gate PASS, Head 9c361148; #5794 merged #5793, gate PASS, Head moved
- 2026-10-26T14:03:09Z: 14:02: #4999 open fast-lane beta mergeable, queued behind ~30 open p0 fast-lane PRs (lane merging ~1 per 20-40 min); #5793/#5794 mergeable, lane drops fast-lane on stacked size until #4999 lands; #5000 waits on #4999
- 2026-10-26T14:27:02Z: 14:26: #4999 still queued (fast-lane beta, mergeable); lane kept re-labelling then dropping #5793/#5794 on stacked size, so parked both with no-fast-lane until #4999 merges; #5000 waits
- 2026-10-26T14:49:11Z: 14:49: no change; #4999 queued (fast-lane beta, mergeable), #5793/#5794 parked no-fast-lane, #5000 waits
- 2026-10-26T15:19:59Z: 15:20: Belt nudge: record now also at docs/leads/suite-cli-bundle/ on the mirror. #4999 ready (Fast-Check+Head match 941da487, local-ci/prescreen success), queued behind p0; #5793/#5794 parked no-fast-lane; #5000 waits
- 2026-10-26T15:37:49Z: 15:37 heartbeat: #4999 still queued (fast-lane, clean, prescreen green) behind p0 PRs; #5793/#5794 parked no-fast-lane, clean; #5000 awaiting docs-only rework after #4999.
- 2026-10-26T15:58:57Z: 15:58 heartbeat: #4999 still queued (fast-lane, clean) behind p0 PRs; #5793/#5794 parked no-fast-lane, clean; #5000 awaits docs-only rework after #4999.
- 2026-10-26T16:21:40Z: 16:21 heartbeat: #4999 still queued (fast-lane, clean) behind p0 PRs; #5793/#5794 parked no-fast-lane, clean; #5000 awaits docs-only rework after #4999.
