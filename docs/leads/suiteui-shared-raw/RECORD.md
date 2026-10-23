# shared-raw lead record

Issue: #3737 · Packet: docs/blueprints/suiteui/features/shared-raw.md
Run: act-1a1693a4009-hyio (line lead: area-selection, adjust-everywhere, shared-raw) · Session: claude/feature-lead-playbook-fkjibd · Started: 2026-10-23T14:40Z
Stage: 3 wave 1
Base: 35a0b5e7e9520a764f3eabf02968a453082a87cc
Next: check between waves: which of #4828, #4848, #4859, #4865, #4872 merged; restack and drop needs-split as each base merges; SR-6 once shared-codecs SC-15/SC-4 merge.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SR-a | test DNGs; Raw/ module as stubs over a fake decoder | SR-1, SR-2a, SR-2b | MJ-SR | IM-a (met) | false | 0 | building (SR-1 #4645 merged; #4828, #4848) | – | – |
| SR-m | formats, plan, refusals, system decoder with headroom | SR-3, SR-4 | MJ-SR, MJ-SR-mac | SR-a | false | 0 | building (#4859, #4865) | – | – |
| SR-photo | Photo opens RAW as a float layer | SR-5, SR-6 | MJ-SR-photo, PJ-SR | SR-a; shared-codecs SC-15, SC-4 | true | 0 | building (SR-5 #4872; SR-6 waits SC) | – | – |
| SR-z | live, RJ-X50, concept line, built | SR-7, SR-8 | PJ-SR, MJ-SR | SR-m, SR-photo; TC-a, PN-a | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SR-2a | SR-a | 1 | raw contract stubs over a fake decoder | Sources/SuiteImaging/Raw/*, tests, docs/c4/parts imaging-raw | Raw*Tests compile | #4828 | open, fast-lane (head 3b3b338) |
| SR-2b | SR-a | 1 | headroom checks, system decoder seam | Sources/SuiteImaging/Raw/* | tests | #4848 | open, stacked on #4828 (needs-split) |
| SR-3 | SR-m | 1 | formats from the registry, refusals, plan | Sources/SuiteImaging/Raw/{RawFormat,SuiteRaw}.swift | Mutate 4/4 + 2/2 | #4859 | open, stacked on #4848 (needs-split) |
| SR-4 | SR-m | 1 | system decoder over CIRAWFilter (macOS) | Sources/SuiteImaging/Raw/SystemRawDecoder.swift | Mutate pending/3 (macOS only) | #4865 | open, stacked on #4859 (needs-split) |
| SR-5 | SR-photo | 1 | Photo raw-open tests, journey, RJ-X50 job, disabled | Tests/PhotoModelTests, UITests, jobs | compiles | #4872 | open, stacked on #4848 (needs-split) |
| SR-6 | SR-photo | – | Photo opens RAW | Sources/PhotoModel | – | – | waiting (SC-15, SC-4) |
| SR-7, SR-8 | SR-z | – | live, RJ-X50, built | – | – | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Status branch is lead/suiteui-shared-raw (the name Belt reads); lead/shared-raw kept as a mirror.
- SR-2 (~530 lines) split into SR-2a and SR-2b; the stale SR-3..5 remote branches were overwritten (force-with-lease on their old shas).
- SR-4 asks the supervisor in its PR to add SystemRawDecoderTests.decodeTime to Tests/perf-suites.txt and run its macOS-only mutation plan.

## Open
- SR-6 waits on shared-codecs SC-15, SC-4; SR-8 on tone-controls TC-a.
- Open findings for this feature: 0.
