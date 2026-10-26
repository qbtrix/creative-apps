# tone-controls lead record

Issue: #3476 · Packet: docs/blueprints/suiteui/features/tone-controls.md
Run: act-1a175ea55b7-729d (line lead, line:suiteui; relaunch 2026-10-26) · earlier: act-1a1702c569a-0puo · Session: claude/suiteui-feature-lead-run-azjeoo · Started: 2026-10-24T23:00Z (earlier: act-1a1693a3ff0-mwrd · Session: cloud line lead (line:suiteui) · Started: 2026-10-23T14:52Z (earlier runs act-1a16469734c-d0s8, act-1a15821c836-93pf))
Stage: All slices done: TC-a, TC-m, TC-u, TC-z (Belt-Slice-Done TC-z run 40276982587, Linux check 40276985896 green). TC-z critic review clean (snapshots: shared InspectorSliderRow track offset is suite-wide, not filed). #5375 (Fixes #5324) restacked on dev at 26ead271, gate PASS. Note: the session proxy appends a tool footer to every PR body and comment write; it can't be stripped from here.
Base: origin/dev 8eff8ab85
Next: Belt-Contact-Sheet once journeys run 40279283359 (suiteui at c480d848) finishes, with its journey lines and audit counts


## Run act-1a175ea55b7-729d decisions
- Brief rule 1: main checked out at d3323f6a7; main was rewritten, so each lead branch is rebuilt as origin/main plus this record (no merge base with the old branch), pushed --force-with-lease.
- PR base stays `dev` (CLAUDE.md; BASE_BRANCH=dev in scripts/fast-lane.sh; the lane retargets main PRs).
- Stacked PRs whose parent squash-merged carry the parent's commits (size FAIL, dirty): merge origin/dev into each branch, gate, move Head.
- TC-u #5006 merged 13:51Z (e8a888296); scoped suiteui run 40247461868 at 30096d710 green and contains it.
- 2026-10-26T03:07:58Z: #5324 (Sharpen offscreen on the 768-pt runner): the gallery page's rows scroll and the journey reveals each row (#5375).
- 2026-10-26T03:30:04Z heartbeat: #5239 (TC-z) and #5375 open and clean; waiting on lane
- 2026-10-26T04:01:17Z heartbeat: #5239 #5375 open and clean; ratchet checked
- 2026-10-26T04:22:59Z heartbeat: all PRs open and clean, no labels; batches held while dev-red #5321 is open (not ours)
- 2026-10-26T04:53:11Z heartbeat: all PRs open and clean, no labels
- 2026-10-26T05:15:11Z heartbeat: all open PRs clean, no needs-fix/needs-rebase; #5297/#5299 over the size cap until #5295 lands; dev-red #5321 open (not ours)
- 2026-10-26T05:37:33Z heartbeat: no change: all open PRs clean, no labels to fix; dev-red #5321 open (not ours)
- 2026-10-26T06:00:09Z heartbeat: #5239 TC-z merged; scoped suiteui run 40276982587 on c480d848 running
- 2026-10-26T06:28:20Z heartbeat: TC-z Belt-Slice-Done posted; critic review clean; #5375 conflict resolved and pushed
- 2026-10-26T06:53:25Z heartbeat: journeys run 40279283359 still running; Contact Sheet waits on it; #5375 clean in lane
- 2026-10-26T07:15:52Z heartbeat: journeys run 40279283359 still running; Contact Sheet waits on it
- 2026-10-26T07:34:19Z heartbeat: all slices done; waiting on journeys 40279283359 for Contact Sheet
- 2026-10-26T07:56:21Z heartbeat: journeys 40279283359 cancelled (superseded); Contact Sheet waits on suiteui journeys 40288150154 at 99ace7038 (contains TC-z)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TC-a | Tone module stubs, placeholder ToneRows on a gallery page, checks disabled | TC-1, TC-2 | SJ0 | suite-imaging:IM-a, gradient-fill:GF-a, autosave-history:AH-a, placed-images:PL-a (all met on dev) | no | 0 | done: run 40029042081 green; Belt-Slice-Done posted 23:24Z | – | – |
| TC-u | ToneRows view, snapshots, budget, journey | TC-3, TC-4 | tone journey | TC-a | yes | 0 | done (run 40247461868) | 40247461868 | wanted |
| TC-m | ToneRules, ToneCommands, ToneSettings bodies | TC-5, TC-6, TC-7 | KJ-tone | TC-a | no | 0 | done: run 40195226753 | 40195226753 | – |
| TC-z | Gallery live through ToneCommands; fake app takes tone (RJ-X41); built | TC-8, TC-9, TC-10 | tone journey, KJ-tone | TC-u, TC-m, GF-z, AH-z, TT-z, EY-z, SH-z, SS-d, PL-z | no | 0 | building (#5239) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TC-1 | TC-a | – | SuiteImaging Tone/ stubs (no Package.swift: IM-1 made the target) | Sources/SuiteImaging/Tone/{ToneSettings,ToneRules,ToneCommands}.swift, Tests/SuiteImagingTests/Tone{Settings,Rules,Commands}Tests.swift, Tests/canonical-concepts.txt, docs/c4/parts/creative-apps/suite-imaging/imaging-tone.json | suites compile disabled | #4555 f5993669 | merged |
| TC-2 | TC-a | – | Placeholder ToneRows, gallery page, journey skipped | Sources/SuiteUI/ToneRows.swift, Sources/SuiteUI/Gallery/GalleryToneRows.swift, Sources/SuiteUI/SuiteGallery.swift, UITests/SuiteJourneyTests+Tone.swift | SJ0 | #4862 610cb64f | merged |
| TC-3 | TC-u | – | The ToneRows view | Sources/SuiteUI/ToneRows.swift, Tests/SuiteUITests/ToneRowsTests.swift | ToneRowsTests | #5006 9e077af0 | open |
| TC-4 | TC-u | – | Snapshots, budget, journey on | Tests/AppSnapshotTests/SuiteToneRowsSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetToneRowsTests.swift, UITests/SuiteJourneyTests+Tone.swift | journey | #5006 9e077af0 | open |
| TC-5 | TC-m | – | ToneRules bodies | Sources/SuiteImaging/Tone/ToneRules.swift, Tests/SuiteImagingTests/ToneRulesTests.swift, Tests/mutations/SuiteImaging.ToneRules.json | ToneRulesTests | #4880 5f34a503 | merged 18:20Z |
| TC-6 | TC-m | – | ToneCommands bodies | Sources/SuiteImaging/Tone/ToneCommands.swift, Tests/SuiteImagingTests/ToneCommandsTests.swift, Tests/mutations/SuiteImaging.ToneCommands.json | ToneCommandsTests | #4953 9e709bc9 | open |
| TC-7 | TC-m | – | ToneSettings coding and clamping | Sources/SuiteImaging/Tone/ToneSettings.swift, Tests/SuiteImagingTests/ToneSettingsTests.swift, Tests/mutations/SuiteImaging.ToneSettings.json | ToneSettingsTests | #4870 10ccbb47 | merged |
| TC-8 | TC-z | – | Gallery runs intents through ToneCommands | Sources/SuiteUI/Gallery/GalleryToneRows.swift, Tests/SuiteUITests/ToneRowsLiveTests.swift | ToneRowsLiveTests | #5239 | open |
| TC-9 | TC-z | – | Fake app takes tone; RJ-X41 | Sources/SuiteImaging/Fakes/FakeToneDocument.swift, Sources/AfterGlowCLICore/Apps.swift, Tests/SuiteImagingTests/FakeToneTests.swift, Tests/mutations/SuiteImaging.FakeToneDocument.json, Tests/RealJobs/fake/tone-controls/ | FakeToneTests | #5239 | open |
| TC-10 | TC-z | – | C4, status built, feature-done | docs/c4/parts/creative-apps/suite-imaging/imaging-tone.json, docs/blueprints/suiteui/features/tone-controls.wave.json | scripts/ci | #5239 | open |

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
- 2026-10-24T06:57Z: run act-1a16cae7922-5nat resumes on #3476 (dev e5dcf939). TC-u #5006, TC-5 #4880, TC-6 #4953 (stacked on #4880), TC-7 #4870 wait in the lane; no needs-fix or needs-rebase. No open finding names tone-controls (#3323 is inspector-controls' SJ16). Full CI 40070365168 on 4446461e in progress.

- 2026-10-24T08:33Z check-in: no merges; no needs-fix/rebase; no new findings; waits unchanged
- 2026-10-24T17:19Z: #4870 (TC-7) merged 17:03:43Z. #4880, #4953, #5006 still open in the lane, no needs-fix/needs-rebase. 0 new findings.
- 2026-10-24T18:26Z: #4880 (TC-5) merged 18:20:36Z. #4953 (TC-6) and #5006 (TC-u) still open in the lane, clean. No new finding names tone-controls.

## Run act-1a1702c569a-0puo decisions
- Integration branch: the brief says main, but the fast lane only merges into dev (main fast-forwards from green dev), so slice PRs base on and target dev, as earlier runs did.
- lead/<feature> was rebuilt on main ef37711d (its old history shares no base with the rewritten main): records copied onto main and force-pushed with lease.
- Contract-first waits (rule 12): every cross-feature wait is met, since each named feature's first slice has merged (checked by its owned files on dev).
- TC-z's waits on GF-z, AH-z, TT-z, EY-z, SH-z, SS-d and PL-z are met contract-first (GF-a, AH-a, TT-a, EY-a, SH-a, SS-a, PL-a merged); Wire lines added for each one TC-z builds ahead of.
- TC-z #5239 is stacked on TC-u #5006 with dev merged in, so its diff against the TC-u branch shows dev's drift until #5006 merges and GitHub retargets #5239 to dev; no restack needed.
- Status is mirrored to lead/suiteui-tone-controls (docs/leads/suiteui-tone-controls/), the branch Belt reads.
- 2026-10-25T13:07Z: #4953 (TC-6, last PR of slice TC-m) merged as 930337d5. TC-m is done once a green full or scoped-suiteui ci.yml run on dev contains it (only Linux check 40195226753 so far). #5006 (TC-u) and #5239 (TC-z) still open and clean.
- 2026-10-25T13:28Z: TC-m merged-done (rule 6): TC-5 #4880, TC-6 #4953, TC-7 #4870 merged; Linux check run 40195226753 at 930337d5 has a green Linux job. Posted Belt-Slice-Done: TC-m on #3476. ui false, so no Mac-Finish-Wanted. Left: TC-u #5006, TC-z #5239.
