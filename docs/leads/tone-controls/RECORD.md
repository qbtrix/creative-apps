# tone-controls lead record

Issue: #4520 · Packet: docs/blueprints/suiteui/features/tone-controls.md
Run: act-1a16469734c-d0s8 · Session: claude/feature-lead-playbook-d50vpe · Started: 2026-10-22 (earlier run act-1a15821c836-93pf on #3476)
Stage: 4 wave 1
Base: origin/dev 7e9f260a
Next: TC-1 (SuiteImaging Tone/ stubs) in wave 1; TC-2, TC-5, TC-7 in wave 2 once TC-1 is open

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TC-a | Tone module stubs, placeholder ToneRows on a gallery page, checks disabled | TC-1, TC-2 | SJ0 | suite-imaging:IM-a, gradient-fill:GF-a, autosave-history:AH-a, placed-images:PL-a (all met on dev) | no | 0 | waiting | – | – |
| TC-u | ToneRows view, snapshots, budget, journey | TC-3, TC-4 | tone journey | TC-a | yes | 0 | waiting | – | – |
| TC-m | ToneRules, ToneCommands, ToneSettings bodies | TC-5, TC-6, TC-7 | KJ-tone | TC-a | no | 0 | waiting | – | – |
| TC-z | Gallery live through ToneCommands; fake app takes tone (RJ-X41); built | TC-8, TC-9, TC-10 | tone journey, KJ-tone | TC-u, TC-m, GF-z, AH-z, TT-z, EY-z, SH-z, SS-d, PL-z | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TC-1 | TC-a | – | SuiteImaging Tone/ stubs (no Package.swift: IM-1 made the target) | Sources/SuiteImaging/Tone/{ToneSettings,ToneRules,ToneCommands}.swift, Tests/SuiteImagingTests/Tone{Settings,Rules,Commands}Tests.swift, Tests/canonical-concepts.txt, docs/c4/parts/creative-apps/suite-imaging/imaging-tone.json | suites compile disabled | – | building |
| TC-2 | TC-a | – | Placeholder ToneRows, gallery page, journey skipped | Sources/SuiteUI/ToneRows.swift, Sources/SuiteUI/Gallery/GalleryToneRows.swift, Sources/SuiteUI/SuiteGallery.swift, UITests/SuiteJourneyTests+Tone.swift | SJ0 | – | waiting |
| TC-3 | TC-u | – | The ToneRows view | Sources/SuiteUI/ToneRows.swift, Tests/SuiteUITests/ToneRowsTests.swift | ToneRowsTests | – | waiting |
| TC-4 | TC-u | – | Snapshots, budget, journey on | Tests/AppSnapshotTests/SuiteToneRowsSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetToneRowsTests.swift, UITests/SuiteJourneyTests+Tone.swift | journey | – | waiting |
| TC-5 | TC-m | – | ToneRules bodies | Sources/SuiteImaging/Tone/ToneRules.swift, Tests/SuiteImagingTests/ToneRulesTests.swift, Tests/mutations/SuiteImaging.ToneRules.json | ToneRulesTests | – | waiting |
| TC-6 | TC-m | – | ToneCommands bodies | Sources/SuiteImaging/Tone/ToneCommands.swift, Tests/SuiteImagingTests/ToneCommandsTests.swift, Tests/mutations/SuiteImaging.ToneCommands.json | ToneCommandsTests | – | waiting |
| TC-7 | TC-m | – | ToneSettings coding and clamping | Sources/SuiteImaging/Tone/ToneSettings.swift, Tests/SuiteImagingTests/ToneSettingsTests.swift, Tests/mutations/SuiteImaging.ToneSettings.json | ToneSettingsTests | – | waiting |
| TC-8 | TC-z | – | Gallery runs intents through ToneCommands | Sources/SuiteUI/Gallery/GalleryToneRows.swift, Tests/SuiteUITests/ToneRowsLiveTests.swift | ToneRowsLiveTests | – | waiting |
| TC-9 | TC-z | – | Fake app takes tone; RJ-X41 | Sources/SuiteImaging/Fakes/FakeToneDocument.swift, Sources/AfterGlowCLICore/Apps.swift, Tests/SuiteImagingTests/FakeToneTests.swift, Tests/mutations/SuiteImaging.FakeToneDocument.json, Tests/RealJobs/fake/tone-controls/ | FakeToneTests | – | waiting |
| TC-10 | TC-z | – | C4, status built, feature-done | docs/c4/parts/creative-apps/suite-imaging/imaging-tone.json, docs/blueprints/suiteui/features/tone-controls.wave.json | scripts/ci | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22 resume (#4520): the packet was re-cut (2026-10-20/21) so the Tone module lives in SuiteImaging and TC-1 edits no Package.swift; TC-1 is back on the fast lane.
- Branch from and target dev, not main: the fast lane only merges into dev and retargets main PRs; main fast-forwards from green dev. "Done" = feature-done merged and the green dev run that promotes main.
- lead/tone-controls rebased onto origin/main 0dd23d65 (71 lead commits replayed; old history was rewritten) per the brief.

## Open
- 2026-10-22: IM-a on dev (IM-1 #4028; IM-2 stubs present on dev, IM-4 #4393 built on them); GF-a, AH-a, PL-a done. TC-1 ready.
- 07:45Z: AH-1 merged (#3543); the rest unchanged.
- 07:09Z: #3144 open (core pin 9ed9ef0 for the CoreRaster tone programs); gradient-fill GF-a: GF-1 merged (#3421), GF-2 not on dev; autosave-history AH-a: AH-1 in #3543 (open), AH-2 not started; placed-images PL-a: PL-1 waits on AH-1. No TC task can start.
- 15:55Z: core bump #3549 (47dd9bb8, pin 2258b62) contains 9ed9ef0 and says it takes over #3144's pin move, so TC-a's #3144 dependency is met on dev. TC-1 still waits on gradient-fill GF-2 (not on dev).
