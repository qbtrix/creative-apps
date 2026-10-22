# adopt-kernel-autosave lead record

Issue: #3713 · Packet: docs/blueprints/suiteui/features/adopt-kernel-autosave.md
Run: act-1a163b2abfe-f182 (relaunch; first run act-1a15c07cabb-mtlw) · Started: 2026-10-22
Stage: 3 wave 5
Base: 1a518080de143b64a57ee1838c3ef01b775e52e6
Next: fixer merges dev into #4010 (dirty); finding #4015 fixed first (rule 6); AK-10 stacked on #4010 (AH-z merged). AK-6, AK-8, AK-9, AK-11 blocked.

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
| AK-1 | AK-a | 1 | contract stubs, disabled tests, support-dir ratchet | Sources/SuiteModel/Store/SuiteLocations.swift, Sources/SuiteModel/Store/LegacySupport.swift, Tests/SuiteModelTests/SuiteLocationsAppFolderTests.swift, Tests/SuiteModelTests/SupportFolderRatchetTests.swift, Tests/support-dir-baseline.txt | SupportFolderRatchetTests | #3835 | open |
| AK-2 | AK-a | 1 | bodies, tests on, mutation plan | Sources/SuiteModel/Store/SuiteLocations.swift, Sources/SuiteModel/Store/LegacySupport.swift, Tests/SuiteModelTests/SuiteLocationsAppFolderTests.swift, Tests/mutations/SuiteModel.SuiteLocations.json, docs/c4/parts/creative-apps/suite-model/suite-store.json | SuiteLocationsAppFolderTests; .appFolderHasAppSegment .neverOverwrites .flagReachesApp | #3835 | open (Mutate 3/3) |
| AK-3 | AK-flare | 2 | see packet | see packet | see packet | #3842 | open (base feat/ak-a-app-folder) |
| AK-4 | AK-flare | 4 | see packet | see packet | see packet | #4010 | open (rounds used; dirty) |
| AK-5 | AK-library | 2 | see packet | see packet | see packet | #3848 | open (base feat/ak-a-app-folder) |
| AK-6 | AK-library | – | see packet | see packet | see packet | – | blocked (spine) |
| AK-7 | AK-photo | 2 | see packet | see packet | see packet | #3841 | open (base feat/ak-a-app-folder) |
| AK-8 | AK-photo | – | see packet | see packet | see packet | – | blocked (SC-f, PH-z) |
| AK-9 | AK-z | – | see packet | see packet | see packet | – | blocked (DA-z, HA-z) |
| AK-10 | AK-z | 5 | see packet | see packet | see packet | – | building (stacked on #4010) |
| AK-11 | AK-z | – | see packet | see packet | see packet | – | planned |

## Reviews

| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions

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
