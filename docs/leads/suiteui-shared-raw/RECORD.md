# shared-raw lead record

Issue: #3737 · Packet: docs/blueprints/suiteui/features/shared-raw.md
Run: act-1a17835827e-1edk (relaunch 2026-10-26T12:40Z) · Started: 2026-10-26T02:00Z (earlier act-1a175f402e7-kwji, act-1a1702c56e8-b6cq, act-1a16cae7989-hj12, act-1a16cae79dd-mtf2)
Stage: 3 wave 2 (wave-2 PRs open, gated; stacks in the lane)
Base: origin/dev 8987427d8
Next: lane merges #4848 (code batches wait on dev-red #5321), then retarget #4859 and #4872 to dev; #4865 after #4859; #5262 rides on #4872. SR-z waits on SR-m, SR-photo, TC-a, PN-a.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SR-a | test DNGs; Raw/ module as stubs over a fake decoder | SR-1, SR-2a, SR-2b | MJ-SR | IM-a (met) | false | 0 | building (SR-1 #4645 merged; #4828, #4848) | – | – |
| SR-m | formats, plan, refusals, system decoder with headroom | SR-3, SR-4 | MJ-SR, MJ-SR-mac | SR-a | false | 0 | building (#4859, #4865) | – | – |
| SR-photo | Photo opens RAW as a float layer | SR-5, SR-6 | MJ-SR-photo, PJ-SR | SR-a; shared-codecs SC-f (done), SC-photo | true | 0 | building (SR-5 #4872; SR-6 waits SC) | – | – |
| SR-z | live, RJ-X50, concept line, built | SR-7, SR-8 | PJ-SR, MJ-SR | SR-m, SR-photo; TC-a, PN-a | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SR-2a | SR-a | 1 | raw contract stubs over a fake decoder | Sources/SuiteImaging/Raw/*, tests, docs/c4/parts imaging-raw | Raw*Tests compile | #4828 | merged (ea5171eb) |
| SR-2b | SR-a | 1 | headroom checks, system decoder seam | Sources/SuiteImaging/Raw/* | tests | #4848 | lane (a1c098e5, base dev) |
| SR-3 | SR-m | 1 | formats from the registry, refusals, plan | Sources/SuiteImaging/Raw/{RawFormat,SuiteRaw}.swift | Mutate 4/4 + 2/2 | #4859 | stacked on #4848 (f32f9a68) |
| SR-4 | SR-m | 1 | system decoder over CIRAWFilter (macOS) | Sources/SuiteImaging/Raw/SystemRawDecoder.swift | Mutate pending/3 (macOS only) | #4865 | stacked on #4859 (2eab661a) |
| SR-5 | SR-photo | 1 | Photo raw-open tests, journey, RJ-X50 job, disabled | Tests/PhotoModelTests, UITests, jobs | compiles | #4872 | stacked on #4848 (731e7f24) |
| SR-6 | SR-photo | – | Photo opens RAW | Sources/PhotoModel | – | – | waiting (SC-15, SC-4) |
| SR-7, SR-8 | SR-z | – | live, RJ-X50, built | – | – | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-25T01:45Z: SR-6 opened as #5262 (lead/shared-raw-SR-6 on SR-5, head b441375c, 137 lines/5 files, CI: PASS, mutate 2/2). Four RAW tests guarded .enabled(if:) until SR-3 is in the build; Wire shared-codecs:SC-photo, shared-raw:SR-m.
- 2026-10-25T01:15Z: wave 2: SR-6 building on SR-5 (Wire shared-codecs:SC-photo); 0 open findings.
- 2026-10-25T01:20Z: replay done: #4848 (158 lines, 2 files), #4859 (160/7), #4865 (317/5, carries the approved perf line), #4872 (251/4), each gated CI: PASS and labelled fast-lane; dev already held SR-2a's commits byte for byte.
- 2026-10-24T23:20Z: dev was rewritten to a new root (4f00afb8, #5150); old slice branches share no history with it, so fixers replay each PR's own commits onto the new dev, split to the 400-line/15-file cap, re-gate and force-with-lease push the lead/* branches (same PR numbers).
- Status branch is lead/suiteui-shared-raw (the name Belt reads); lead/shared-raw kept as a mirror.
- SR-2 (~530 lines) split into SR-2a and SR-2b; the stale SR-3..5 remote branches were overwritten (force-with-lease on their old shas).
- SR-4 asks the supervisor in its PR to add SystemRawDecoderTests.decodeTime to Tests/perf-suites.txt and run its macOS-only mutation plan.

- 2026-10-26T02:20Z Relaunch act-1a175f402e7-kwji. No raw PR merged since the last record. #4848 #4859 #4865 #4872 #5262 open with fast-lane, each merges dev 8987427d8 cleanly. dev-red #5321 open (full CI 40251699354 macOS red, range main..cc5c6234a); while it names macOS no code batch forms, so code PRs wait.
- 2026-10-26T12:55Z Relaunch act-1a17835827e-1edk. Packet-Review 1 (#3737, 3ff81cd3) answered, all seven applied: (1) `RawRefusal: LocalizedError`, `errorDescription = message` (SR-3, mutation `.refusalDescribed`); (2) SR-6 owns `PhotoHeadless.swift`: its open switch routes the registry's `.cameraRaw` names to `openImage` and `formats` lists them (SC-15 is not built, gap #5792); (3) `decodeLinear` default routes RAW through `SuiteRaw`, nil otherwise; `ImageIOCodec.decodeLinear` checks `RawFormat(fileName:)` first (SR-6); (4) new `RawQuality.fitted(longestSide:)`, scaled, never draft; Photo's capped open asks `.fitted` (SR-3, mutation `.fittedIsNotDraft`); (5) the plan is a full table in the packet, scale in Double; (6) `.previewCovers` and `.fullIsNotDraft` live in the `SuiteImaging.RawFormat` plan; (7) Photo open: `documentName` = stem, `fileKind = .readOnly`, Save goes to Save As, `documentURL` stays. Packet text rides SR-6 (#5262).

## Open
- SR-6 waits on shared-codecs SC-photo (SC-4), which this run builds now; SR-8 on tone-controls TC-a and pen-paths PN-a (contract-first: their contract slices).
- Open findings for this feature: 0.
- 2026-10-24T07:05Z: run act-1a16cae7989-hj12 resumes on dev 830af22d. Server-added footers removed from #4848, #4859, #4865, #4872 bodies so Head: is the last line again (#4828, #4861, #4875, #4876 already clean). Contract-first waits (rule 12) applied to the slice table.
- 2026-10-26T02:20Z: relaunch check: 5 PRs open, clean; dev-red #5321 open (full CI 40251699354 macOS red, range main..cc5c6234a); while it names macOS no code batch forms, so code PRs wait; open findings 0
- 2026-10-26T02:31Z: heartbeat: no change; no PR of this feature merged; dev 8987427d8; dev-red #5321 open (code batches held); open findings 0
- 2026-10-26T02:54Z: heartbeat: dev 6d5f8b92; dev-red #5321 open (code batches held); no PR of this feature merged; supervisor (02:46Z on #4865) will land SR-4 through the Linux check and the local Mac gate (its perf-suites.txt line approved); #4865 is still based on lead/shared-raw-SR-3; open findings 0
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
- 2026-10-26T10:34Z: heartbeat: dev-red #5321 open; dev 2ed77a2e; scoped suiteui 40302591880 green but holds no new slice of mine (no shared PR merged since the done ones); full CI 40305265877 pending; no Feature: shared PR updated since 10:05Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T10:57Z: heartbeat: dev-red #5321 open; dev f3af1c00 (#5725 quarantine for swift tests) after 2eab5aeb (#5163); full CI 40305265877 on 2ed77a2e cancelled; Linux check 40310541699 running; no Feature: shared PR updated since 10:30Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T11:26Z: heartbeat: dev-red #5321 open; dev 7aa95f57 (generated C4/waves) after b200af5b (#5726 lane auto-quarantine for a red dev with no culprit); Linux check on f3af1c00 green, Linux check 40313117666 and scoped photo running; no Feature: shared PR updated since 10:55Z; #5133 ST-z waits in lane; codec and raw stacks unchanged; findings 0
- 2026-10-26T11:52Z: heartbeat: dev c6700dba (#5727 quarantine expiry); dev-red #5321 open; Linux check 40316903931 running; no Feature: shared PR moved; #5133 ST-z still queued
- 2026-10-26T12:23Z: heartbeat: dev 746be6b1 (#5775 sharded macOS); full CI 40321924466 queued; Linux check 40316903931 on c6700dba green; dev-red #5321 open; no Feature: shared PR moved; #5133 ST-z queued
- 2026-10-26T12:55Z: heartbeat: SR-3 #4859 gains the fitted quality and the described refusal (local head 4fb41f90, CI: PASS; mutate running); SR-6 #5262 gains PhotoHeadless RAW (3e395410, 2ba1df55, gate next); dev 746be6b1; dev-red #5321 open; findings 0
- 2026-10-26T13:07Z: heartbeat: SR-6 golden list-apps.json now names Photo's RAW extensions (4c017e13), re-gate queued; SR-4 gate re-queued (stale module cache after a worktree move, not the code); dev 57dd31ff (#5146); dev-red #5321 open; findings 0
- 2026-10-26T13:29Z: heartbeat: SR-4 gate PASS on d986b47a, pushed, #4865 markers moved; SR-6 gate running; dev 01600e46; dev-red #5321 open; findings 0
- 2026-10-26T13:41Z: heartbeat: SR PRs unchanged (#4848 #4859 #4865 #4872 #5262); dev 01600e46; dev-red #5321 open holds code batches; findings 0
- 2026-10-26T14:03Z: heartbeat: SR PRs unchanged; dev 01600e46; dev-red #5321 open holds code batches; findings 0
- 2026-10-26T14:29Z: heartbeat: SR PRs unchanged; lane backlog 123 ready PRs; dev 68be32fc; dev-red #5321 open; findings 0
- 2026-10-26T14:52Z: heartbeat: SR PRs clean against dev f86f72f7; dev-red #5321 open; findings 0
- 2026-10-26T15:19Z: rule 23: three identical blocked polls (14:28Z, 14:51Z, 15:18Z); Question for the supervisor posted on #3737 (issuecomment-6419749547); all shared PRs clean, none merged; dev f86f72f7; dev-red #5321 open; findings 0
- 2026-10-26T15:42Z: heartbeat: all shared PRs clean against dev 310d7d14, none merged; no supervisor reply on #3737 yet; dev-red #5321 open; findings 0
- 2026-10-26T16:10Z: heartbeat: no change; all shared PRs clean on dev 310d7d14, none merged; no supervisor reply on #3737; dev-red #5321 open; findings 0
- 2026-10-26T16:32Z: heartbeat: all shared PRs clean on dev 527676af, none merged; no supervisor reply on #3737; dev-red #5321 open; findings 0
- 2026-10-26T16:56Z: heartbeat: all shared PRs clean on dev 527676af, none merged; no supervisor reply on #3737; dev-red #5321 open; findings 0
- 2026-10-26T17:19Z: heartbeat: all shared PRs clean on dev df48c0ba, none merged; no supervisor reply on #3737; dev-red #5321 open; findings 0
