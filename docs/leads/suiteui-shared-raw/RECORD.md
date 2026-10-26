# shared-raw lead record

Issue: #3737 · Packet: docs/blueprints/suiteui/features/shared-raw.md
Run: act-1a175f402e7-kwji (relaunch 2026-10-26T02:00Z) · Started: 2026-10-26T02:00Z (earlier act-1a1702c56e8-b6cq, act-1a16cae7989-hj12, act-1a16cae79dd-mtf2)
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

## Open
- SR-6 waits on shared-codecs SC-photo (SC-4), which this run builds now; SR-8 on tone-controls TC-a and pen-paths PN-a (contract-first: their contract slices).
- Open findings for this feature: 0.
- 2026-10-24T07:05Z: run act-1a16cae7989-hj12 resumes on dev 830af22d. Server-added footers removed from #4848, #4859, #4865, #4872 bodies so Head: is the last line again (#4828, #4861, #4875, #4876 already clean). Contract-first waits (rule 12) applied to the slice table.
- 2026-10-26T02:20Z: relaunch check: 5 PRs open, clean; dev-red #5321 open (full CI 40251699354 macOS red, range main..cc5c6234a); while it names macOS no code batch forms, so code PRs wait; open findings 0
- 2026-10-26T02:31Z: heartbeat: no change; no PR of this feature merged; dev 8987427d8; dev-red #5321 open (code batches held); open findings 0
