# tone-controls lead record

Issue: #3476 · Packet: docs/blueprints/suiteui/features/tone-controls.md
Run: act-1a1693a3ff0-mwrd · Session: cloud line lead (line:suiteui) · Started: 2026-10-23T14:52Z (earlier runs act-1a16469734c-d0s8, act-1a15821c836-93pf)
Stage: 4 wave 2
Base: origin/dev 8021b0f5
Next: TC-a done (run 40029042081 green, Belt-Slice-Done posted 23:24Z). TC-u PR #5006 open (dev merged in, gated CI: PASS at 9e077af0). On the lane: TC-5 #4880, TC-7 #4870, TC-6 #4953 (TC-m). TC-z waits on TC-u, TC-m and other features' z slices.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TC-a | Tone module stubs, placeholder ToneRows on a gallery page, checks disabled | TC-1, TC-2 | SJ0 | suite-imaging:IM-a, gradient-fill:GF-a, autosave-history:AH-a, placed-images:PL-a (all met on dev) | no | 0 | done: run 40029042081 green; Belt-Slice-Done posted 23:24Z | – | – |
| TC-u | ToneRows view, snapshots, budget, journey | TC-3, TC-4 | tone journey | TC-a | yes | 0 | building (#5006) | – | – |
| TC-m | ToneRules, ToneCommands, ToneSettings bodies | TC-5, TC-6, TC-7 | KJ-tone | TC-a | no | 0 | waiting | – | – |
| TC-z | Gallery live through ToneCommands; fake app takes tone (RJ-X41); built | TC-8, TC-9, TC-10 | tone journey, KJ-tone | TC-u, TC-m, GF-z, AH-z, TT-z, EY-z, SH-z, SS-d, PL-z | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TC-1 | TC-a | – | SuiteImaging Tone/ stubs (no Package.swift: IM-1 made the target) | Sources/SuiteImaging/Tone/{ToneSettings,ToneRules,ToneCommands}.swift, Tests/SuiteImagingTests/Tone{Settings,Rules,Commands}Tests.swift, Tests/canonical-concepts.txt, docs/c4/parts/creative-apps/suite-imaging/imaging-tone.json | suites compile disabled | #4555 f5993669 | merged |
| TC-2 | TC-a | – | Placeholder ToneRows, gallery page, journey skipped | Sources/SuiteUI/ToneRows.swift, Sources/SuiteUI/Gallery/GalleryToneRows.swift, Sources/SuiteUI/SuiteGallery.swift, UITests/SuiteJourneyTests+Tone.swift | SJ0 | #4862 610cb64f | merged |
| TC-3 | TC-u | – | The ToneRows view | Sources/SuiteUI/ToneRows.swift, Tests/SuiteUITests/ToneRowsTests.swift | ToneRowsTests | #5006 9e077af0 | open |
| TC-4 | TC-u | – | Snapshots, budget, journey on | Tests/AppSnapshotTests/SuiteToneRowsSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetToneRowsTests.swift, UITests/SuiteJourneyTests+Tone.swift | journey | #5006 9e077af0 | open |
| TC-5 | TC-m | – | ToneRules bodies | Sources/SuiteImaging/Tone/ToneRules.swift, Tests/SuiteImagingTests/ToneRulesTests.swift, Tests/mutations/SuiteImaging.ToneRules.json | ToneRulesTests | #4880 5f34a503 | open |
| TC-6 | TC-m | – | ToneCommands bodies | Sources/SuiteImaging/Tone/ToneCommands.swift, Tests/SuiteImagingTests/ToneCommandsTests.swift, Tests/mutations/SuiteImaging.ToneCommands.json | ToneCommandsTests | #4953 9e709bc9 | open |
| TC-7 | TC-m | – | ToneSettings coding and clamping | Sources/SuiteImaging/Tone/ToneSettings.swift, Tests/SuiteImagingTests/ToneSettingsTests.swift, Tests/mutations/SuiteImaging.ToneSettings.json | ToneSettingsTests | #4870 10ccbb47 | open |
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
- 2026-10-23T16:45Z: TC-5 auto rounds each value to the hundredth before clamping (sRGB white of 1.0 came back as ~4e-14 Whites). TC-u (TC-3+TC-4) is one PR stacked on TC-2; TC-6 stacks on TC-5. Status now also pushed to lead/suiteui-tone-controls (the branch Belt reads).
- 2026-10-23T18:32Z: TC-6 (#4953, 303 lines with TC-5's commits, mutate 5/5): Radius/Threshold refusal reads "Sharpen is off at Amount 0." (the packet's help text); `tone.reset` with no group is the undo step "Reset Tone" (same name as a Tone-group reset, per contract); a target with no toneSettings and no toneHelp is refused with "There is no picture to adjust." (packet silent). TC-6 needs nothing from TC-7.
- 2026-10-23T18:33Z: TC-u: a row's accessibility label is its title and its value the number (journey step 6 checks label and value separately); onIntent is @MainActor; the disabling reason shows once above the sections, the Vibrance and Sharpen reasons under their section; a section's Reset shows only off neutral; Exposure 2 decimals, Radius 1, others 0; Auto is wand.and.stars, id suite.tone.auto. Snapshots suiteui-tone-rows{,-edited,-vibrance-waiting,-sharpen-off}-{light,dark}. The PR waits for #4862 to merge to stay under the 400-line cap.

## Open
- 2026-10-22: IM-a on dev (IM-1 #4028; IM-2 stubs present on dev, IM-4 #4393 built on them); GF-a, AH-a, PL-a done. TC-1 ready.
- 07:45Z: AH-1 merged (#3543); the rest unchanged.
- 07:09Z: #3144 open (core pin 9ed9ef0 for the CoreRaster tone programs); gradient-fill GF-a: GF-1 merged (#3421), GF-2 not on dev; autosave-history AH-a: AH-1 in #3543 (open), AH-2 not started; placed-images PL-a: PL-1 waits on AH-1. No TC task can start.
- 15:55Z: core bump #3549 (47dd9bb8, pin 2258b62) contains 9ed9ef0 and says it takes over #3144's pin move, so TC-a's #3144 dependency is met on dev. TC-1 still waits on gradient-fill GF-2 (not on dev).
- 2026-10-23T14:52:29Z: run act-1a1693a3ff0-mwrd resumes on #3476 (the record said #4520). TC-1 merged as #4555. TC-m is 5 to 7 (~820 lines): it ships as three PRs under the 400 cap, all `Slice: TC-m`. Base and target are dev (CLAUDE.md, the lane), not main.
- 2026-10-23T16:45Z: PRs #4862 (TC-2), #4870 (TC-7), #4880 (TC-5) open with fast-lane and current Fast-Check/Head; waiting on the lane. TC-6 and TC-u builders launched.
- 2026-10-23T18:32Z: no PR merged yet; all seven of this run's PRs wait on the lane (#4873 on the supervisor). Builders share scratchpad gate.lock; a stale holder blocked gates ~30 min and was cleared.
- 2026-10-23T22:05Z: #4862 merged; merged dev into TC-u (add/add on ToneRows.swift and the tone journey, took TC-u's superset), gated CI: PASS, opened #5006.
- 2026-10-23T23:24Z: TC-a done: scoped suiteui run 40029042081 green at 491ec546; Belt-Slice-Done on #3476 (ui false, no panel).
