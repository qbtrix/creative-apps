# shared-thumbnails lead record

Issue: #3719 · Packet: docs/blueprints/suiteui/features/shared-thumbnails.md
Run: act-1a175f402e7-kwji (relaunch 2026-10-26T02:00Z; earlier act-1a170e37e52-d0q6) · Started: 2026-10-23T15:30Z
Stage: 3 polling (ST-a, ST-u, ST-m done; ST-z part 1 #5102 merged, part 2 #5133 open)
Base: origin/dev 8987427d8
Next: #5133 (90eb5fab2) is clean and merges dev cleanly; it waits for the lane, which forms no code batch while dev-red #5321 open (full CI 40251699354 macOS red, range main..cc5c6234a) is open. Then a green scoped suiteui or full run containing #5133 gets Belt-Slice-Done ST-z and Mac-Finish-Wanted ST-z; the supervisor posts the contact sheet (#3719). Heartbeat every 20 min.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| ST-a | SuiteShell and LibraryModel link CoreAsset; `ThumbnailPublishing.preview(for:)`; `FakeThumbnails`; `ThumbnailWriter` and `LiveThumbnailStoreAdapter` stubs; tests written, disabled | ST-1, ST-2 | MJ-ST | shared-codecs:SC-a (ST-2) | false | 0 | done | 40070077878 | – |
| ST-u | home Recent cards show `preview(for:)` on the fake, app mark when nil, within the render budget | ST-3, ST-4 | HJ-ST | ST-a | true | 0 | done | – | – |
| ST-m | writer stores and reads previews in `AfterGlow/Thumbnails/` within budget; Library reads disk before decoding | ST-5, ST-6 | MJ-ST | ST-a; adopt-kernel-autosave:AK-a (ST-5); library spine (ST-6) | false | 0 | done | – | – |
| ST-z | slot live, Photo publishes on save, Library over the shared store, feature built | ST-7, ST-8 | HJ-ST, MJ-ST | ST-u, ST-m; adopt-kernel-autosave:AK-photo (ST-7) | true | 0 | building (#5102 merged 2026-10-24T18:19Z; #5133 open, dev merged in at 502e566f9, waiting on the lane) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| ST-1 | ST-a | 1 | tests first, disabled; RJ-X47 job folder | Tests/AppSnapshotTests/ThumbnailWriterTests.swift, Tests/LibraryModelTests/LibraryThumbnailDiskTests.swift, Tests/RealJobs/library/relaunch-grid/relaunch-grid.jobs.json | (disabled) | – | building |
| ST-2 | ST-a | 1 | CoreAsset links; preview(for:); FakeThumbnails; writer and adapter stubs | Package.swift, project.yml, Sources/SuiteModel/Contracts/ThumbnailPublishing.swift, Sources/SuiteModel/Fakes/FakeThumbnails.swift, Sources/SuiteShell/ThumbnailWriter.swift, Sources/LibraryModel/Live/LiveThumbnailStoreAdapter.swift | FakeThumbnails test | – | building |
| ST-3 | ST-u | 2 | home previews on the fake | Sources/AfterGlowApp/HomeGrid.swift, Tests/AppSnapshotTests/HomeGridPreviewTests.swift | HomeGridPreviewTests | – | planned |
| ST-4 | ST-u | 3 | snapshots, render budget, journey skipped | Tests/AppSnapshotTests/HomePreviewSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHomePreviewTests.swift, UITests/AfterGlowJourneyTests+Previews.swift | RenderBudgetHomePreviewTests | – | planned |
| ST-5 | ST-m | 2 | ThumbnailWriter body | Sources/SuiteShell/ThumbnailWriter.swift, Tests/AppSnapshotTests/ThumbnailWriterTests.swift, Tests/mutations/SuiteShell.ThumbnailWriter.json | ThumbnailWriterTests | – | planned |
| ST-6 | ST-m | 2 | Library disk tier | see packet | LibraryThumbnailDiskTests | – | planned |
| ST-7 | ST-z | 4 | live wiring | see packet | PhotoPublishesPreviewTests | – | planned |
| ST-8 | ST-z | 5 | journey live, built, feature-done | see packet | journey | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-23T15:30Z Relaunch act-1a16953ae34-05a4. The supervisor unparked this feature under contract-first waits (#3719 15:12Z; lead.md rule 12, #4814). SC-a's SC-1 is on dev (#4020) but SC-2 is not, so ST-2 builds ahead of it with a Wire line. AK-a is done (run 39568091135), so ST-5's wait is met with real code.
- ST-1 and ST-2 ship as one slice PR (test-first commit, then ST-2): ST-1's tests name types only ST-2 declares.
- ST-2 edits protected Package.swift and project.yml. The supervisor said on #3719 (2026-10-21) that they will land it, so the ST-a PR carries no fast-lane label.
- PRs target `dev` (CLAUDE.md; the lane retargets PRs to main), not main.
- 2026-10-24T07:30Z Relaunch act-1a16cc96904-199n. ST-z starts now: its wait on adopt-kernel-autosave:AK-photo is met under contract-first waits (AK-a merged; rule 12). ST-7 keeps its PhotoWindow+File.swift edit to a few lines so AK-8 merges over it easily. ST-z is stacked on ST-u and ST-m and opened as a draft until they merge (its diff vs dev is over the size cap until then).
- Scoped library run 40070367564 red on RenderBudgetLibraryFoldersTests.expandFolderInTwoBodies (Library folders, not this feature's files); holds no slice.
- 2026-10-24T07:55Z Belt watches lead/suiteui-shared-thumbnails and docs/leads/suiteui-shared-thumbnails/RECORD.md. Every RECORD push now goes to both branches (same commit), with the record mirrored at both paths.
- Earlier runs (act-1a15b69feea-et92) were all blocked on SC-a; their heartbeat log is in RECORD.prev.

- 2026-10-24T08:15Z ST-z came back at 548 lines/13 files, over the 400 cap even after its parents merge. Split into two stacked PRs, both `Slice: ST-z`: #5102 (ST-7 Photo publish on save + live slot, 7 files/340) and #5133 (Library grid on disk, journey on live previews, wave.json built, feature-done; 6 files/208). The hard cap wins over "one PR per slice"; the slice is done once a run contains ST-z2.
- 10:16Z Supervisor answered the 07:54Z question: Belt's stall check reads `lead/suiteui-shared-thumbnails`. Keep pushing every RECORD update to both branches. The ST-z drafts stacked on #4950/#4951 are approved. The lane says the body footer (re-added by the session proxy) blocks nothing, because it is stripped at squash.

- 2026-10-25T02:35Z Relaunch act-1a170e37e52-d0q6. The brief targets main; lead/shared-thumbnails was recreated on origin/main afef017c2 with this record (its old history was 2.4k dev commits; the timeline keeps the events). Supervisor merged #5219 (Photo publishes through the bridge's thumbnails) and #5209 (end-to-end Recent-card test), and is holding #3719 for them; #5133 still carries feature-done and the slice.

- 2026-10-26T02:20Z Relaunch act-1a175f402e7-kwji. Nothing of this feature merged since the last record. #5133 open (fast-lane, feature-done, beta; clean; trial merge of dev 8987427d8 clean). dev-red #5321 open (full CI 40251699354 macOS red, range main..cc5c6234a); while it names macOS no code batch forms, so code PRs wait. Supervisor holds #3719 for #5219.

## Wire
- [x] Wire: shared-codecs:SC-a (ST-2 built ahead; when SC-2 merges, merge dev into the ST-a branch, keeping both Package.swift/project.yml link changes)
- [~] Wire (in ST-z2): Library live services build LiveThumbnails with the disk store (folder + budget); then un-pend RealJobs relaunch-grid. Do in ST-z or a follow-up before close.

## Open
- –
- 2026-10-23T15:20:44Z: ST-a builder started (ST-1 test commit, ST-2) on lead/shared-thumbnails-ST-a; pinned core 7966e5a has CoreAsset/ThumbnailStore, so ST-2 links without a bump
- 2026-10-23T17:32Z: wave 2: ST-a is #4840 (touches Package.swift, so it needs a supervisor merge; no-fast-lane added). ST-u and ST-m builders started, stacked on ST-a, opened as drafts. Decision: ST-6 is built now (two-line call in spine's LiveThumbnails.swift, which spine hasn't edited in 12h; the lane integrates conflicts).
- 2026-10-23T19:15:35Z: SC-2 merged on dev; merged dev into ST-a (#4840) at 07c11358c, SuiteShell keeps CoreAsset + CoreRaster; scripts/ci --changed PASS (6039). Head line moved; asked supervisor to re-gate. Restacking ST-u/ST-m.
- 2026-10-23T19:36:47Z: ST-u (#4950) restacked on ST-a 07c11358c -> 5b8f875, CI --changed PASS, Head moved. ST-m gate running. #4840 still needs-fix pending supervisor re-gate.
- 2026-10-23T19:40:02Z: ST-m (#4951) restacked on ST-a 07c11358c -> 06dfc0e, CI --changed PASS, Head moved. Both drafts wait on #4840.
- 2026-10-23T19:58:03Z: check: #4840 awaits supervisor Mac re-gate at 07c11358c; #4950/#4951 drafts restacked, waiting.
- 2026-10-23T20:20:41Z: heartbeat: #4840 ST-a still needs-fix/no-fast-lane at 07c11358c, mergeable clean, waiting on supervisor Mac re-gate; #4950/#4951 stay drafts
- 2026-10-23T20:42:21Z: heartbeat: #4840 ST-a unchanged at 07c11358c (needs-fix, awaiting supervisor Mac re-gate); #4950/#4951 drafts
- 2026-10-23T21:04:27Z: heartbeat: #4840 ST-a unchanged at 07c11358c (needs-fix, awaiting supervisor Mac re-gate); #4950/#4951 drafts; dev idle 70 min
- 2026-10-23T21:26:10Z: heartbeat: #4840 ST-a no status on 07c11358c yet (awaiting supervisor Mac re-gate); #4950/#4951 drafts; dev idle since 19:45Z
- 2026-10-23T21:50:21Z: dev batch at 21:40Z merged 12 PRs (#4841-#4862) and skipped #4837 (EP-m). The cause is the lane's open_list --limit 100: 144 PRs are open and #4837 was past the cutoff. Raised with the supervisor on #4837. #4840 (ST-a) is still waiting on the Mac re-gate. #4950/#4951 are drafts, #4943 waits on EP-m.
- 2026-10-23T22:13:33Z: No dev merges since 21:40Z. #4840 (ST-a) still waits on the supervisor's Mac re-gate. #4837 (EP-m) is 97th of the newest open PRs, just inside the lane's 100-PR window. Supervisor not yet answered. #4943/#4950/#4951 unchanged.
- 2026-10-23T22:34:52Z: Still no dev merges since 21:40Z. #4840 has no status on its head and is still waiting on the supervisor's Mac re-gate. #4837 is now 99th newest, so it is still inside the lane's window. No supervisor reply. Stacked slices unchanged.
- 2026-10-23T22:57:28Z: Dev only gained the generated-docs commit; no lane batch since 21:40Z. #4840 still has no status and is waiting on the supervisor. #4837 is 99th newest, still inside the lane's window. No supervisor reply. Stacked slices unchanged.
- 2026-10-23T23:18:57Z: #4837 (EP-m) is in lane/batch-20261023215139, a batch of 12 with #4818-#4870. Its Linux check passed and the macOS gate run 40029779505 is still in progress after 1.5h. I updated the supervisor note on #4837. #4840 (ST-a) still has no status and is waiting on the supervisor's Mac re-gate. A full CI run on dev 654fb36 is in progress.
- 2026-10-23T23:41:37Z: heartbeat: batch-20261023215139 macOS gate 40029779505 still in progress (~1h50m); #4837 EP-m waits in it; #4840 ST-a still needs-fix/no-fast-lane awaiting supervisor Mac re-gate; #4943/#4950/#4951 wait on parents
- 2026-10-24T00:04:03Z: check: batch-20261023215139 macOS gate 40029779505 FAILED 23:44Z on Design stroke tests (RenderBudgetDesignStrokeTests.widthScrubInThreeBodies, DesignStrokeSnapshots.editor: selectedStroke nil); not EP-m's Photo-only diff; lane bisect pending, #4837 not labelled needs-fix. #4840 ST-a unchanged (needs-fix/no-fast-lane, no status, supervisor re-gate).
- 2026-10-24T00:26:26Z: check: lane bisecting batch-20261023215139 (probe -6 = first 6 PRs, before #4837); #4837 open, no needs-fix; #4840 ST-a unchanged awaiting supervisor re-gate
- 2026-10-24T00:48:33Z: check: bisect still on probe batch-20261023215139-6 (macOS gate on first 6 PRs); #4837 open, no needs-fix; #4840 ST-a unchanged awaiting supervisor re-gate
- 2026-10-24T01:10:44Z: 01:10Z check: dev still 654fb3632; lane bisect probe batch-20261023215139-6 unchanged; #4837 EP-m open (fast-lane, no needs-fix); #4840 ST-a waits on supervisor Mac re-gate
- 2026-10-24T01:31:46Z: 01:31Z check: lane bisect moved to probe batch-20261023215139-9 (first 9 PRs, includes #4837 EP-m), so the culprit is past PR 6; #4837 no needs-fix; #4840 ST-a still waits on supervisor Mac re-gate; dev 654fb3632
- 2026-10-24T01:53:22Z: 01:53Z check: probe batch-20261023215139-9 (incl. #4837 EP-m) Linux check green (run 40050009822), macOS gate 40050012604 running since 01:29Z; #4840 ST-a still waits on supervisor Mac re-gate; dev 654fb3632
- 2026-10-24T02:14:52Z: 02:14Z check: probe -9 macOS gate 40050012604 still running (45 min); #4837 EP-m unmerged; #4840 ST-a still waits on supervisor Mac re-gate; dev 654fb3632
- 2026-10-24T02:37:23Z: 02:37Z check: probe -9 macOS gate 40050012604 failed on RenderBudgetDesignStrokeTests.widthScrubInThreeBodies and DesignStrokeSnapshots.editor, tests that #4864 (design DK-3) adds itself; culprit is #4864, not #4837 EP-m (Photo-only), which should land when the bisect finishes; #4840 ST-a still waits on supervisor Mac re-gate
- 2026-10-24T02:58:27Z: 02:58Z check: lane opened probe batch-20261023215139-7 (49949b4, first 7 PRs ending at #4837 EP-m); its runs decide EP-m; #4840 ST-a still waits on supervisor Mac re-gate; dev 654fb3632
- 2026-10-24T03:20:16Z: batch-20261023215139 probe -7 (49949b4, ends at #4837): Linux 40055390941 green, macOS gate 40055393733 running; -9 red on Design stroke tests points at #4864. #4837 open fast-lane; #4840 ST-a still needs-fix/no-fast-lane awaiting supervisor Mac re-gate; dev 654fb3632
- 2026-10-24T03:42:09Z: probe -7 macOS gate 40055393733 still in_progress (started 02:44Z, likely waiting on a macOS runner); #4837 open fast-lane, no needs-fix; #4840 ST-a unchanged (needs-fix/no-fast-lane, supervisor Mac re-gate)
- 2026-10-24T04:04:24Z: probe -7 (49949b4, ends at #4837) macOS gate 40055393733 green at 03:46Z with Linux 40055390941 green: #4837 EP-m cleared, culprit is #4839 or #4864 (likely #4864); waiting for lane to merge prefix. #4840 ST-a unchanged (supervisor Mac re-gate)
- 2026-10-24T04:26:11Z: bisect continues: probe -8 (5c349da, adds #4839) Linux 40060703756 green, macOS gate 40060705865 running; #4837 cleared by -7, not merged yet (dev 654fb3632). #4840 ST-a unchanged
- 2026-10-24T04:53:03Z: probe -8 (adds #4839) macOS gate 40060705865 still in_progress since 04:01Z; dev 654fb3632, #4837 not merged yet; #4840 ST-a unchanged
- 2026-10-24T05:15:38Z: bisect -8 macOS gate 40060705865 passed (05:05Z): #4837 EP-m and #4839 clear, culprit #4864; waiting for lane to merge prefix. #4840 ST-a: supervisor cleared window-lifetime flake (dev flaky 1/3), merging via gate at 2dbfc165
- 2026-10-24T05:38:06Z: lane run 40064397299 named #4864 culprit but dropped stale batch: nothing merged (dev still 654fb3632) though its comment said prefix merged. New batch-20261024050226 starts at #4839 and skips #4818..#4837 (open_list --limit 100). Asked supervisor on #4837 (comment 6380464537) to hand-merge cleared prefix and fix lane. #4840 ST-a waits on supervisor gate merge
- 2026-10-24T06:00:12Z: no change: dev still 654fb3632; #4837 EP-m open awaiting supervisor reply on 6380464537 (prefix skipped by lane); #4840 ST-a awaiting supervisor gate merge
- 2026-10-24T06:22:16Z: no change: dev 654fb3632; #4837 EP-m open, not in batch-20261024050226 (probe -6 running), no supervisor reply; #4840 ST-a open, supervisor merge pending
- 2026-10-24T07:05:06Z: ST-a #4840 merged (4446461); full CI 40070365168 + scoped suite/library running on it. Restacked ST-u #4950 (223c79c, 8 files/385 lines) and ST-m #4951 (d6f2c3e, 11 files/224 lines; add/add conflicts taken from ST-m, dev side == ST-a 07c1135 stubs) on dev; scripts/ci --changed PASS both; undrafted, fast-lane, Head moved. ST-z blocked: ST-7 needs adopt-kernel-autosave AK-photo (AK-8, PhotoWindow+File.swift), not on dev, no open PR.

- 16:19Z ST-u and ST-m done: dev Linux check 40109079881 at 33cd6e97c green. Posted Belt-Slice-Done ST-u, Mac-Finish-Wanted ST-u and Belt-Slice-Done ST-m on #3719. The session proxy appends a "Generated by Claude Code" footer to issue comments and re-adds it on every edit; it cannot be removed from this session.
- 2026-10-26T02:20Z: relaunch check: #5133 clean at 90eb5fab2; dev-red #5321 open (full CI 40251699354 macOS red, range main..cc5c6234a); while it names macOS no code batch forms, so code PRs wait; open findings 0
- 2026-10-26T02:31Z: heartbeat: no change; no PR of this feature merged; dev 8987427d8; dev-red #5321 open (code batches held); open findings 0
- 2026-10-26T02:54Z: heartbeat: dev 6d5f8b92; dev-red #5321 open (code batches held); no PR of this feature merged; open findings 0
- 2026-10-26T03:16Z: heartbeat: dev d0859e01 (#5346); full CI 40262284734 in progress on it, a green run would close dev-red #5321 and reopen code batches; no PR of this feature changed or merged; open findings 0
- 2026-10-26T03:38Z: heartbeat: full CI 40262284734 on dev d0859e01: Linux job failed (scripts/ci), macOS still running, so dev-red #5321 stays open and code batches stay held; no PR of this feature changed or merged; open findings 0
- 2026-10-26T03:59Z: heartbeat: full CI 40262284734 Linux red in HomeModelTests and OnboardingModelTests (suite line, not ours; the Linux check 40263148639 on the same sha d0859e01 passed); dev now 75292afd (#5378 widens the scrub timing test behind dev-red); full CI 40266495039 pending on it; dev-red #5321 open, code batches held; no PR of this feature changed or merged; open findings 0
- 2026-10-26T04:22Z: heartbeat: dev-red #5321 open (now names linux); full CI 40266495039 on 75292afd running both jobs since 04:15Z; no PR of this feature changed since 04:00Z; 0 findings
- 2026-10-26T04:45Z: heartbeat: full CI 40266495039 on 75292afd: Linux green, macOS red on HomeModelTests/OnboardingModelTests 60 s time limits (suite line, not this feature); dev-red #5321 stays open, code batches held; no PR of this feature changed; 0 findings
- 2026-10-26T05:07Z: heartbeat: dev-red #5321 open; full CI 40266495039 on 75292afd re-running (attempt 2 since 04:45Z); scoped suiteui 40267267454 on 75292afd green but holds no new slice PR (#5133 unmerged); dev now 999895c8 (#5154, library); no PR of this feature changed; 0 findings
- 2026-10-26T05:29Z: heartbeat: dev-red #5321 open (linux named); full run 40266495039 attempt 2 still running on 75292afd; dev now 7e13ba02 (#4948); no lane movement on #5133, codec or raw PRs; 0 findings
- 2026-10-26T05:52Z: heartbeat: dev-red #5321 open (linux named); full run 40266495039 attempt 2 still in progress on 75292afd; dev 7e13ba02 green on Linux check and scoped library; no lane movement on #5133, codec or raw PRs; 0 findings
- 2026-10-26T06:22Z: heartbeat: dev-red #5321 open; full run 40266495039 attempt 2 failed on 75292afd; dev now c480d848 (#5239 tone-controls TC-z, so TC-a is on dev); scoped suiteui 40276982587 green on c480d848 but holds no slice PR of ours; full run 40277933712 in progress; no lane movement on #5133, codec or raw PRs; 0 findings; SR-z still waits on SR-m, SR-photo and PN-a
- 2026-10-26T06:45Z: heartbeat: dev-red #5321 open; full run 40277933712 on c480d848 red on macOS only (Linux green); no lane movement on #5133, codec or raw PRs; 0 findings; SR-z waits on SR-m, SR-photo and PN-a
- 2026-10-26T07:09Z: heartbeat: dev-red #5321 open (macOS red on c480d848); dev now 798f1f0a (#5244, other lead), its scoped photo run in progress; no lane movement on #5133, codec or raw PRs; 0 findings; SR-z waits on SR-m, SR-photo and PN-a
- 2026-10-26T07:30Z: heartbeat: dev-red #5321 open; dev now 99ace703 (#5043 XP-3, other lead), scoped suiteui run 40284902781 in progress (none of my slices in it); no lane movement on #5133, codec or raw PRs; 0 findings; SR-z waits on SR-m, SR-photo and PN-a
- 2026-10-26T07:53Z: heartbeat: dev-red #5321 open; dev now 3e26fbe4 (#5264, other line), scoped photo/library runs in progress; no lane movement on #5133, codec or raw PRs; 0 findings; SR-z waits on SR-m, SR-photo and PN-a
- 2026-10-26T08:17Z: heartbeat: dev-red #5321 open; full CI 40290214719 queued on 3e26fbe4 (#5264); no Feature: shared PR merged or updated since 07:50Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T08:39Z: heartbeat: dev-red #5321 open; dev 1960c2d9 (#4956, photo); full CI 40290214719 in progress on 3e26fbe4; no Feature: shared PR merged or updated since 08:15Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T09:02Z: heartbeat: dev-red #5321 open; full CI 40290214719 on 3e26fbe4 finished red (holds no slice: none of mine in it); no Feature: shared PR merged or updated since 08:38Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T09:23Z: heartbeat: dev-red #5321 open; dev be5f2c00 (lane fix: red_scope scratch clone; the empty scope had held the whole queue); Linux check 40297365321 running; no Feature: shared PR merged or updated since 09:00Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T09:46Z: heartbeat: dev-red #5321 open; dev 1b843d15 (#5383, test-scope timing lint); Linux check 40299951550 running; Linux check on be5f2c00 green; no Feature: shared PR merged or updated since 09:20Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T10:11Z: heartbeat: dev-red #5321 open; dev 2ed77a2e (#5065 export-pack XP-4, not mine); scoped suiteui 40302591880 and photo 40302585871 runs, Linux check 40303915704 in progress, full CI 40305265877 queued, none contain a slice of mine; no Feature: shared PR merged or updated since 09:40Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
