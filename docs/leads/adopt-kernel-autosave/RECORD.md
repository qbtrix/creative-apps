# adopt-kernel-autosave lead record

Issue: #3713 · Packet: docs/blueprints/suiteui/features/adopt-kernel-autosave.md
Run: act-1a163b2abfe-f182 (relaunch; first run act-1a15c07cabb-mtlw) · Started: 2026-10-22
Stage: parked by the supervisor (AK-10 landing via lane)
Base: 1a518080de143b64a57ee1838c3ef01b775e52e6
Next: AK side ended (parked by the supervisor): #4427 and #4428 on dev; relaunch takes AK-6, AK-8, AK-9, AK-11

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AK-a | One app-folder rule and a never-overwrite legacy plan; a ratchet stops new support-dir lookups | AK-1, AK-2 | – | autosave-history:AH-a (merged) | false | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39568091135 | – |
| AK-flare | Flare autosaves through the kernel schedule into its app folder | AK-3, AK-4 | – | AK-a (AK-3); autosave-history:AH-z (AK-4) | false | 0 | planned | – | – |
| AK-library | Library's catalog lives in the app folder, legacy moved once | AK-5, AK-6 | – | AK-a (AK-5); library spine hand-off (AK-6) | false | 0 | planned | – | – |
| AK-photo | Photo recovery lives in the app folder | AK-7, AK-8 | – | AK-a (AK-7); SC-f, PH-z (AK-8) | false | 0 | planned | – | – |
| AK-z | Design and Halo adopt; the ratchet baseline reaches zero; feature built | AK-9, AK-10, AK-11 | – | DA-z, HA-z (AK-9); AH-z (AK-10) | false | 0 | planned | – | – |

## Tasks

| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AK-1 | AK-a | 1 | contract stubs, disabled tests, support-dir ratchet | Sources/SuiteModel/Store/SuiteLocations.swift, Sources/SuiteModel/Store/LegacySupport.swift, Tests/SuiteModelTests/SuiteLocationsAppFolderTests.swift, Tests/SuiteModelTests/SupportFolderRatchetTests.swift, Tests/support-dir-baseline.txt | SupportFolderRatchetTests | #3835 | merged |
| AK-2 | AK-a | 1 | bodies, tests on, mutation plan | Sources/SuiteModel/Store/SuiteLocations.swift, Sources/SuiteModel/Store/LegacySupport.swift, Tests/SuiteModelTests/SuiteLocationsAppFolderTests.swift, Tests/mutations/SuiteModel.SuiteLocations.json, docs/c4/parts/creative-apps/suite-model/suite-store.json | SuiteLocationsAppFolderTests; .appFolderHasAppSegment .neverOverwrites .flagReachesApp | #3835 | merged (Mutate 3/3) |
| AK-3 | AK-flare | 2 | see packet | see packet | see packet | #3842 | merged |
| AK-4 | AK-flare | 4 | see packet | see packet | see packet | #4010 | open (68b3c4e6, dev merged; rounds used) |
| AK-5 | AK-library | 2 | see packet | see packet | see packet | #3848 | merged |
| AK-6 | AK-library | – | see packet | see packet | see packet | – | blocked (spine) |
| AK-7 | AK-photo | 2 | see packet | see packet | see packet | #3841 | merged |
| AK-8 | AK-photo | – | see packet | see packet | see packet | – | blocked (SC-f, PH-z) |
| AK-9 | AK-z | – | see packet | see packet | see packet | – | blocked (DA-z, HA-z) |
| AK-10 | AK-z | 5 | see packet | see packet | see packet | #4427, #4428 | open (split: tests 292 lines, source 185 lines) |
| AK-11 | AK-z | – | see packet | see packet | see packet | – | planned |

## Reviews

| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions

- 2026-10-22T19:51Z #4428 (AK-10 source) merged by the lane as b653cb7bfd. AK side ended; relaunch takes AK-6, AK-8, AK-9, AK-11.
- 18:40Z #4427 (AK-10 tests) merged (31da7d22f6). Merged dev into feat/ak-10-flare-delete (f9be9a48): one conflict in FlareWindow.swift, resolved by keeping #4428's rename FlareRecovery.swift -> FlareAutosaveAdapter.swift (same body as AK-4's squash). scripts/ci --changed: CI: PASS. #4428 retargeted to dev, Head moved, no footer. AK side ends here, as the supervisor said; AK-6, AK-8, AK-9 and AK-11 wait for the relaunch.
- 18:10Z heartbeat: no change; #4427 build green, waiting for its lane batch
- 17:47Z heartbeat: #4427 macOS build 39813862769 green, waiting for its lane batch; #4428 stacked
- 2026-10-22T17:25Z heartbeat (parked): no change. #4427's macOS build 39813862769 is still queued, and #4428 is still stacked.
- 2026-10-22T17:04Z heartbeat (parked): #4427's macOS build 39813862769 is still queued. #4428 is still stacked on it. Scoped flare 39810327753 is still pending.
- 2026-10-22T16:42Z heartbeat (parked): #4427 is waiting on its macOS build 39813862769, which is queued. #4428 is still stacked on it. The lane is still rebuilding #4430. On dev 401242a5, scoped flare 39810327753 is still pending.
- 2026-10-22T16:20Z Supervisor answer on #3713 (issuecomment-6345079787): park it. Don't reorder the hand-off, don't start AK-6 or AK-8, and end the run once AK-4 and AK-10 are in the lane. The supervisor labels the issue waiting-on-prereq and will relaunch for AK-6, AK-8, AK-9 and AK-11 once spine is feature-done and SC-f lands. AK-4 #4010 merged as a3c4bff9 (held by dev 401242a5; scoped flare run 39810327753 and full CI 39810338100 pending). AK-10: I merged dev into feat/ak-10a-flare-autosave-tests (a1ede4d9, scripts/ci --changed: CI: PASS) and retargeted #4427 to dev with its Head line moved. #4428 stays stacked on #4427 and gets the same retarget once #4427 merges. Then the AK side of this run ends.
- 2026-10-22T15:50Z blocked poll 3 (rule 23): spine.wave.json is still building, and shared-codecs.wave.json (SC-f) is still planned, the same as polls 1 and 2. Posted a Question for the supervisor on #3713 (issuecomment-6345010241): keep waiting, or reorder the AK-8/SC-f hand-off and build AK-6 against spine's dev state. AK-6, AK-8, AK-9 and AK-11 stay unstarted until it is answered. #4010 is clean at 68b3c4e6 (macOS build green) and waits on a lane sweep; #4427 and #4428 are stacked on it; #4430's macOS rebuild 39803550165 is still queued.
- 2026-10-22T15:20Z heartbeat: #4010 macOS green, waits on a lane sweep; #4430 first macOS build (39792175488) was cancelled after sitting queued, lane re-dispatched 39803550165 (queued). Waits unchanged (blocked poll 2): spine building (AK-6), shared-codecs SC-f planned (AK-8); AK-9, AK-11 follow.
- 2026-10-22T14:58Z heartbeat: #4010 macOS build 39790006247 green, waits on a lane sweep; #4430 macOS build 39792175488 queued; #4427/#4428 stacked on #4010. Waits re-read (blocked poll 1 of this run): library/spine building (AK-6); shared-codecs SC-f planned and owns PhotoWindow+File.swift (AK-8); AK-9 on AK-6/AK-8 (DA-z, HA-z built); AK-11 on AK-9, AK-10.
- 2026-10-22T14:35Z: wave 5 shipped. #4010 merged dev (68b3c4e6, 400 lines, CI: PASS; command-path flare.txt conflict kept both removals). AK-10 came to 477 lines with deletions, so it split: #4427 deletes the two test files (stacked on #4010), #4428 deletes FlareAutosave.swift and renames FlareRecovery.swift to FlareAutosaveAdapter.swift, which holds the live .autosaveRecovery wiring (stacked on #4427). Finding #4015 fixed as #4430 (quit write via AutosaveSchedule.beginQuit, failed restore keeps the copy and shows the error; Mutate 8/8). Attribution footers the PR tool added to #4427-#4430 removed. #4018 (gap) stays for later.
- 2026-10-22: relaunch as run act-1a163b2abfe-f182. Main HEAD verified 0dd23d65; main is 487 commits behind dev, so base stays origin/dev (1a518080) and the lead branch is rebuilt on dev with this folder.
- 2026-10-22: AH-z merged (#4388): AK-10 unblocked. SC-f still open (SC-15, SC-16), library spine still building: AK-8 and AK-6 stay blocked, so AK-9 and AK-11 do too.
- 2026-10-22: #4010 went dirty after its Linux run 39608399428 failed only on photo CommandPathTests from dev (not ours). Fixer merges dev in and moves Head:.
- 2026-10-22: finding #4015 (SuiteUI .autosaveRecovery: no write on quit, restore swallows a decode error) is the feature's only open finding; fixed this wave as its own PR (Slice: AK-z, Fixes #4015), since AK-flare's rounds are spent and the modifier is shared by every editor in AK-z.

- 2026-10-21T01:21:08Z: integration base is dev (7277a83a), not main: crew PRs target dev per CLAUDE.md.
- 2026-10-21T01:21:08Z: AK-1 and AK-2 ship as one slice PR (test-first commit, then bodies); AH-a is merged (all owned files on dev).
- 2026-10-21T01:21:08Z: AH-z is not merged (FakeHistoryTests, history-jump jobs missing on dev), so AK-4 and AK-10 wait.

- 2026-10-21T02:19Z: AK-3, AK-5, AK-7 open as test-first PRs stacked on #3835 now: their code halves (AK-4, AK-6, AK-8) wait on other features, so the slice PRs can't be whole yet.
- 2026-10-21T02:19Z: Belt reads lead/suiteui-<feature> with docs/leads/suiteui-<feature>/; the RECORD is pushed under both names.

- 2026-10-21T02:43Z: AK-7 (#3841) tests use a private launch helper on SuiteLocations.appFolder + LegacySupport.plan, since LiveRecovery's argument-taking call doesn't exist yet; AK-8 adds that call and points the helper at it.

- 2026-10-21T02:56Z: dev #3837 forbids changing an existing C4 part's description. #3835 had edited suite-store.json's, so d48dc817 restores dev's text (the new file is already covered by the part's paths). The first gate run failed only on 60 s timeouts at load ~18; the rerun printed CI: PASS. Head moved on #3835. AK-7 (#3841) is taking the merge next, and AK-3/AK-5 merge it before they open their PRs.

- 2026-10-21T03:02Z: AK-3 is #3842: seven Flare tests, disabled "waits on AK-4", plus stubs. It adds FlareWorkspace.legacyRecovery ("Flare/Recovery.flare") so the old-file test reads the path from the Model. Base retargeted to feat/ak-a-app-folder (+345 against dev with #3835 in it). For AK-4: .restoreIsOneStep wants one undo step back to the document before the restore, while today's restoreRecovery(Document) clears history. AK-4 has to change that.

- 2026-10-21T03:02Z: AK-5 is #3848: six Library tests, disabled "waits on AK-6". Its catalogFolder stub keeps today's place. #3841, #3842 and #3848 all have feat/ak-a-app-folder as their base, so none can land before #3835. Each moves back to dev when #3835 squash-merges and its branch is deleted.

- 2026-10-21T03:41Z: the container restarted. #3841 took #3835's fix (head 0e4d7dcd, CI: PASS) and its Head: line moved. #3835's macOS build on d48dc817 is green (run 39536987251), so it is waiting on the lane's next sweep. #3842, #3848 and #3841 wait on it.

- 04:08Z heartbeat: #3835 AK-a macOS build 39536987251 green; waits on the lane's batch. Children #3841 #3842 #3848 stay stacked on feat/ak-a-app-folder.

- 04:36Z heartbeat: #3835 AK-a built on macOS and is clean; the lane is batching (lane/batch-20261021043428 in flight). Children stay stacked.

- 05:04Z heartbeat: #3835 still green and clean. Lane batch 20261021043428 (PRs #3466..#3703, oldest first) went red and is bisecting; ours queue behind that backlog. Nothing to fix.

- 05:30Z heartbeat: the lane integrated dev into #3835 (head 6b13c089) and dispatched macOS build 39549571625. Gating that head locally to move Head:.

- 05:40Z: `scripts/ci --changed` passed on the lane-merged head 6b13c089 (ci-ak-a-3.log); moved #3835's Head: line to it.

- 06:03Z heartbeat: #3835 macOS build 39549571625 green on 6b13c089, clean, Head: matches. Lane batch 20261021053311 (up to #3813) is bisecting; ours are next in line.

- 06:30Z heartbeat: #3835 green and clean on 6b13c089. The lane landed batch 20261021053311 at 06:12Z; ours are next in line.

- 2026-10-21T06:58Z heartbeat: #3835 AK-a in lane batch 20261021065242 (Linux check 39558186618 running); children #3841 #3842 #3848 wait on it.

- 2026-10-21T07:24Z heartbeat: batch 20261021065242 red; bisect shows prefix 2 green and prefix 3 red (culprit #3823, not ours); #3835 rolls into the next batch.

- 2026-10-21T07:53Z heartbeat: #3835 AK-a MERGED to dev. Children #3841 #3842 #3848: merged dev in (new heads 4a8bfbd5 d3f55929 90df1e9b), retargeted to dev, gating.

- 2026-10-21T08:06Z heartbeat: #3841 #3842 #3848 gated CI: PASS on the dev-merged heads, base dev, Head: lines moved; diffs 148/176/102 lines.

- 2026-10-21T08:33Z heartbeat: AK-a squash 7d5845e7 is in dev CI 39568091135 (733e8ef2, queued); Belt-Slice-Done for AK-a after it is green. Children's macOS builds: #3848 success, #3841 running, #3842 queued.

- 2026-10-21T09:01Z heartbeat: dev CI 39568091135 still queued; newer dev CI 39573184415 (296186f4) pending, either green run posts AK-a done. #3841 macOS build green, #3842 build queued, #3848 waits batch.

- 2026-10-21T09:29Z heartbeat: dev red #3856 (Design mutation anchors DY-a in DesignCanvasEditing, not this line); AK-a Belt-Slice-Done waits a green dev run. #3841 and #3842 macOS builds green; #3841/#3842/#3848 wait lane batch.

- 2026-10-21T10:02Z heartbeat: #3848 AK-library merged. #3841/#3842 macOS green, wait lane batch. Dev still red #3856 (Design anchors), so AK-a Belt-Slice-Done waits.

- 2026-10-21T10:36Z heartbeat: Belt-Slice-Done AK-a posted on #3713 (run 39568091135, Linux green; macOS red on UnsavedGuardTests is not AK-a's). AK-4 builder started (AH-8 #3629 merged, which is the task's dependency). AK-6 waits on spine feature-done; AK-8 on PH-z.

- 2026-10-21T10:54Z AK-4 (AK-flare) opened as #4010, head a2bacabf, fast-lane; job-lens critic on the diff running.

- 2026-10-21T11:00Z critic (job) on #4010: blocking, the quit write is gone (FJ-AK needs it); minor: legacy move runs while recovery is off, a wrong .move result, Undo of restore loses fileName. Fix round 1 sent to the builder. The SuiteUI modifier's quit and restore-error gaps are filed as finding #4015.

- 2026-10-21T11:03Z heartbeat: #4010 (AK-flare) in fix round 1; AK-6/8/9/10 still blocked on spine, PH-z, DA-z/HA-z and AH-10

- 2026-10-21T11:10Z #4010 fix round 1 pushed: head e284d05a, 397 lines in 6 files, mutate 10/10. Quit write via RecoveryFolder.write; legacy move skipped while recovery is off. Undo-restore fileName gap filed as #4018. Sentinel needs-split was for a 457-line mid-round head; I removed it with a comment. Round-2 critic running.

- 2026-10-21T11:19Z AK-flare #4010 round-2 critic: one blocker (an ignore-state launch with its own store moves and loses the real legacy Recovery.flare); fix round 2 (last) sent to the builder. Minor tick/quit race noted, not fixed.

- 2026-10-21T11:24Z AK-flare #4010 fix round 2 pushed: head ba534cf4, ignore-state launches never move the legacy copy; mutate 11/11; 400 lines, 6 files; Head: moved. Fix rounds for AK-flare used up; the minor tick/quit race is recorded in the PR body.

- 2026-10-21T11:30Z Heartbeat: #4010 at ba534cf4 waits on the lane's per-PR macOS build (dispatched 11:30Z); fix rounds used up. #4015 the only open AK finding. AK-6/8/9/10 still blocked.

- 2026-10-21T11:57Z Heartbeat: #4010 ba534cf4 macOS build (run 39592399191) still queued; no needs-fix.

- 2026-10-21T12:25Z Heartbeat: #4010 ba534cf4 macOS build (run 39592399191) green; waits on the lane's merge sweep.

- 2026-10-21T12:52Z heartbeat: #4010 AK-flare macOS build green, waits on lane merge sweep; #4015 only open finding; AK-6/8/9/10 blocked

## Open

- AK-6 on the library spine; AK-8 on SC-f; AK-9 on AK-6, AK-8, DA-z, HA-z; AK-11 on AK-9, AK-10.
- 2026-10-26T03:03:42Z AK-z: #5040 gated (CI: PASS) on head 78f6ac0b; body Head and Belt-Lead moved. Waiting on the lane batch.
- 2026-10-26T03:30:20Z Blocked on lane: dev-red #5321 (macos) is open, so no code batch forms. Bisect/triage name #5112 (reverted in #5349) and #5044, not ours. All 8 run PRs (#5040 #5088 #5089 #5091 #5231 #5244 #5263 #5266) are gated, fast-lane, no needs-fix/needs-rebase. Waiting; will not fix dev-red in our PRs.
- 2026-10-26T03:48:06Z Heartbeat: dev-red #5321 still open; dev unmoved; our 8 PRs clean (no needs-fix/needs-rebase). Waiting on the lane.
- 2026-10-26T04:08:24Z AK-9 #5040 merged to dev (0ce906f7). AK-z not done: Photo leg and AK-11 wait on AK-8 (SC-15/16). Check-in: dev-red #5321 still open; our 7 open PRs clean (no needs-fix/needs-rebase).
- 2026-10-26T04:27:32Z Check-in: dev-red #5321 still open (latest run red on linux, range to d0859e01, not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T04:46:45Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T05:07:56Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T05:27:48Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T05:48:49Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T06:19:47Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T06:53:46Z Check-in: #5244 (OC-photo-m) merged 06:37 as 798f1f0a. Restacked #5263 (OC-photo-u) on dev: the dev merge put image.flip back in PhotoCatalog noMenu, fixed in 79ed59ec, gate PASS, Head moved. dev-red #5321 still open (not ours). 6 open PRs, none needs-fix or needs-rebase.
- 2026-10-26T07:18:31Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, #5263 head 79ed59ec unchanged; OC-photo-m waits on a green dev run.
- 2026-10-26T07:38:15Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T07:59:44Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T08:24:05Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T08:43:49Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T09:04:17Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T09:23:42Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T09:43:41Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T10:04:38Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T10:23:46Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T10:44:24Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T11:05:20Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T11:26:08Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T11:45:59Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged.
- 2026-10-26T12:07:48Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged.
- 2026-10-26T12:36:23Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged.
- 2026-10-26T13:01:19Z Check-in: dev-red #5321 still labelled (not ours); 6 open PRs clean, none merged.
- 2026-10-26T13:38:58Z Check-in: dev-red #5321 still open (not ours); this feature's open PRs clean, none merged.
- 2026-10-26T14:00:10Z Check-in: dev-red #5321 still open (not ours); 5 open PRs clean, none merged; OC-library-u (01600e46c) has only a Linux check so far, no scoped-suiteui or full run yet.
- 2026-10-26T14:40:25Z Resume, run act-1a178a4b1c2-ibn1. AK-8 still blocked on shared-codecs SC-f (not on dev); AK-11 waits AK-8. dev-red #5321 open (not ours).
- 2026-10-26T15:00:31Z poll: dev-red #5321 open (macos); ci.yml at f86f72f79 running; no needs-fix/needs-rebase on our PRs; AK-photo/AK-z wait on SC-f
- 2026-10-26T15:26:56Z poll 15:26: dev-red #5321 open; full CI 40342241864 + scoped library at f86f72f79 still running; none of ours merged or labelled needs-fix; SC-f still open (SC-15/16 unmerged, packet review #5798 open)
- 2026-10-26T15:50:40Z AK-photo/AK-z blocked: SC-f PRs #5262 #5265 still open
- 2026-10-26T16:15:10Z AK-photo/AK-z blocked: SC-f PRs #5262 #5265 still open
- 2026-10-26T16:37:01Z AK-photo/AK-z blocked: SC-f PRs #5262 #5265 still open
- 2026-10-26T16:59:04Z AK-photo/AK-z blocked: SC-f PRs #5262 #5265 still open
- 2026-10-26T17:21:40Z AK-photo/AK-z blocked: SC-f PRs #5262 #5265 still open
- 2026-10-26T17:43:14Z AK-photo/AK-z blocked: SC-f PRs #5262 #5265 still open
- 2026-10-26T18:05:43Z 18:05 poll: none merged, no needs-fix, dev-red #5321 open; SC-f open
- 2026-10-26T18:27:38Z 18:27 poll: no needs-fix, dev-red #5321 open; SC-f open
- 2026-10-26T18:48:58Z 18:48 poll: no needs-fix, dev-red #5321 open; SC-f open
- 2026-10-26T19:11:43Z 19:11 poll: dev-red #5321 closed, no needs-fix; SC-f open
- 2026-10-26T19:33:54Z AK-photo/AK-z blocked on SC-f (#5262 #5265 open); no dev-red
- 2026-10-26T19:55:32Z AK-photo/AK-z blocked on SC-f (#5262 #5265 open); no dev-red
- 2026-10-26T20:18:16Z AK-photo/AK-z blocked on SC-f (#5262 #5265 open); no dev-red
- 2026-10-26T20:40:33Z AK-photo/AK-z blocked on SC-f (#5262 #5265 open); no dev-red
- 2026-10-26T21:03:02Z AK-photo/AK-z blocked on SC-f #5262/#5265 (open)
- 2026-10-26T21:25:44Z AK-photo/AK-z blocked on SC-f #5262/#5265 (open)
- 2026-10-26T21:47:46Z AK-photo/AK-z blocked on SC-f #5262 #5265, both still open.
- 2026-10-26T22:10:45Z AK-photo/AK-z blocked on SC-f #5262 #5265, both still open.
- 2026-10-26T22:32:45Z AK-photo/AK-z blocked on SC-f #5262 #5265, both still open.
- 2026-10-26T22:49:37Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-26T23:09:20Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-26T23:29:10Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-26T23:50:43Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T00:10:46Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T00:30:19Z AK-photo/AK-z blocked on SC-f 5262/5265 (open)
- 2026-10-27T00:49:57Z AK-photo/AK-z blocked on SC-f 5262/5265 (open)
- 2026-10-27T01:10:55Z AK-photo/AK-z blocked on SC-f 5262/5265 (open)
- 2026-10-27T01:29:43Z AK-photo/AK-z blocked on SC-f 5262/5265 (open)
- 2026-10-27T01:49:27Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T02:09:15Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T02:29:34Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T02:49:36Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T03:09:15Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T03:29:06Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T03:49:36Z SC-f #5262 #5265 still open; AK-photo/AK-z blocked
- 2026-10-27T04:09:12Z SC-f #5262 #5265 still open; AK-photo/AK-z blocked
- 2026-10-27T04:30:20Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T04:49:44Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T05:12:20Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T05:32:02Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T05:52:02Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T06:22:00Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T06:43:22Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T07:03:48Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T07:23:21Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T07:43:14Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T08:04:16Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T08:24:16Z AK-photo/AK-z blocked on SC-f #5262 #5265 (open)
- 2026-10-27T08:44:44Z AK-photo/AK-z wait on SC-f #5262 #5265 (open)
- 2026-10-27T09:05:46Z AK-photo/AK-z wait on SC-f #5262 #5265 (open)
- 2026-10-27T09:25:20Z AK-photo/AK-z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T09:45:53Z AK-photo/AK-z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T10:06:42Z AK-photo/AK-z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T10:27:02Z SC-f #5262 #5265 still open
- 2026-10-27T10:47:52Z SC-f #5262 #5265 still open
- 2026-10-27T11:13:05Z AK-photo/AK-z wait on SC-f #5262 #5265, both open
- 2026-10-27T11:32:55Z AK-photo/AK-z wait on SC-f #5262 #5265, both open
- 2026-10-27T12:00:38Z AK-photo/AK-z wait on SC-f #5262 #5265, both open
- 2026-10-27T12:30:14Z AK-photo waits on SC-f #5262 #5265, both open
- 2026-10-27T12:57:31Z AK-photo waits on SC-f #5262 #5265, both open
- 2026-10-27T13:33:26Z AK-photo waits on SC-f #5262 #5265, both open
- 2026-10-27T14:34:24Z AK-photo waits on SC-f #5262/#5265 (open)
- 2026-10-27T14:55:12Z AK-photo waits on SC-f #5262/#5265 (open)
- 2026-10-27T15:35:01Z AK-photo waits on SC-f #5262/#5265 (open)
- 2026-10-27T15:56:12Z AK-photo waits on SC-f #5262/#5265 (open)
- 2026-10-27T16:17:50Z blocked on SC-f #5262/#5265
- 2026-10-27T16:38:54Z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T16:59:27Z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T17:19:04Z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T17:39:46Z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T17:59:21Z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T18:19:13Z blocked on SC-f #5262/#5265 (open)
- 2026-10-27T18:39:08Z AK-photo/AK-z wait on SC-f #5262/#5265 (open)
- 2026-10-27T18:58:57Z AK-photo/AK-z wait on SC-f #5262/#5265 (open)
- 2026-10-27T19:19:22Z AK-photo/AK-z wait on SC-f #5262/#5265 (open)
- 2026-10-27T19:39:35Z AK-photo/AK-z wait on SC-f #5262/#5265 (open)
- 2026-10-27T19:59:43Z AK-photo blocked on SC-f #5262/#5265, both open
- 2026-10-27T20:18:59Z AK-photo blocked on SC-f #5262/#5265, both open
- 2026-10-27T20:39:14Z AK-photo blocked on SC-f #5262/#5265, both open
- 2026-10-27T20:59:05Z AK-photo blocked on SC-f #5262/#5265, both open
- 2026-10-27T21:19:20Z AK-photo blocked on SC-f #5262/#5265, both open
