# tone-controls lead record (Photo, #3468)

Issue: #3468 · Packet: docs/blueprints/photo/features/tone-controls.md
Run: act-1a17be7af84-ih2a · Started: 2026-10-27T05:45Z (takes over from act-1a178602311-syy6)
Stage: 3 build; PT-a, PT-u, PT-m done; PT-z left: PT-7 #5860 (head 29cec5b1, fast-lane, clean) waits for the lane, which holds code batches while dev-red #5818 (macOS, #4889's PhotoToolsKeyTests, not ours) is open
Base: dev (870080fb)
Next: when #5860 merges, merge dev into -pt8, gate, open PT-8 (feature-done); Belt-Slice-Done PT-z from a green photo-scoped or full ci.yml run on dev that contains PT-8, then Belt-Contact-Sheet

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PT-a | AdjustmentSettings.tone and the ToneTarget adapter as stubs; Adjust panel shows ToneRows | PT-1, PT-2 | MJ-PT | suiteui tone-controls TC-a (TC-1 #4555 merged; TC-2 building) | yes | 0 | done | 40250716357 | – |
| PT-u | snapshots, render budget, journey written | PT-5, PT-6 | PJ-T1 | PT-a; TC-3 (PT-5) | yes | 0 | done (PT-5 #5817, PT-6 #5008 merged) | – | – |
| PT-m | live route and export path; adapter bodies; catalog; RJ-P12–14 | PT-3, PT-4 | MJ-PT | PT-a; IM-photo (on dev), TC-5, TC-6 (stubs, rule 12); catalog chain (all built) | no | 0 | done (PT-3, PT-4 #5363, sharpen #5816 merged) | – | – |
| PT-z | journey on live, feature-done | PT-7, PT-8 | PJ-T1 | PT-u, PT-m; PG-z (PT-8) | yes | 0 | PT-7 #5860 in lane; PT-8 on -pt8 (opens after) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PT-1 | PT-a | 2 | tone in AdjustmentSettings; adapter stubs; PhotoToneTests disabled | Sources/PhotoModel/AdjustmentSettings.swift, PhotoTone+Kernel.swift, Tests/PhotoModelTests/PhotoToneTests.swift | PhotoToneTests | #4845 | merged |
| PT-2 | PT-a | 3 | Adjust panel ToneRows | Sources/PhotoApp/AdjustmentsInspector.swift | PhotoToneSnapshots.panel | #5007 | merged |
| PT-3 | PT-m | 4 | live route and export | PhotoAdjust+Imaging.swift, PhotoRender.swift | PhotoToneTests | #5105 | merged |
| PT-4 | PT-m | 4 | adapter bodies, catalog, jobs | PhotoTone+Kernel.swift, PhotoCommandCatalog.swift, RealJobs | PhotoToneCommandTests | #5112 → #5363 | merged (re-land, 20:14Z) |
| PT-5 | PT-u | 4 | snapshots, budget | Tests/AppSnapshotTests/PhotoToneSnapshots.swift, RenderBudgetPhotoToneTests.swift | snapshots | #5817 | merged |
| PT-6 | PT-u | 4 | journey skipped | UITests/PhotoJourneyTests+Tone.swift | compiles | #5008 | merged |
| PT-7 | PT-z | 5 | journey on live, RJ-P12–14 live | UITests/PhotoJourneyTests+Tone.swift, RealJobs | PhotoToneJobsTests | #5860 | in lane |
| PT-8 | PT-z | 6 | photo.md, built, feature-done | docs/blueprints/photo.md, tone-controls.wave.json | scripts/ci | – | waiting |

## Waves (combined plan, all three features)
- 13:30Z: bisect probe -6 (first 6 of batch 20261024110214) macOS gate 40092825860 failed on `RenderBudgetToneRowsTests.sliderDragInThreeBodies` (120 Temperature steps sent 100 `tone.set`). That test comes from #5006 (TC-3, suiteui tone-controls lead act-1a1693a3ff0-mwrd, line:suiteui): not this run's to fix. Probe -3 running (40097887707/40097890001). PT-5 stays blocked on #5006; #5008 and #5007 don't touch ToneRows.
- W1: PM-1 (SuiteUI LayerTreeList multi-select, no waits) and PP-a (PP-1 and PP-2 in one PR; waits met by PL-1 #3578 and PL-m on dev). The files do not overlap.
- W2: PM-2 once photo-gradient-fill PG-a is slice-done; PP-3 once placed-images PL-2 has merged; PT-1 once suiteui tone-controls TC-a is slice-done.
- W3: PM-3 (after PM-2), PP-4 (after PP-3), PT-2 (after PT-1), PM-4 (after PM-2).
- W4: PP-5 with PP-6 folded in, then PM-5 and PM-6, stacked in that order on the catalog. All three wait on PG-m. PT-3 and PT-4 wait on TC-5 and TC-6, IM-photo and the catalog chain. PM-7, PM-8, PT-5 and PT-6 also run here.
- W5: PP-7, PM-9, PT-7 (live journeys). W6: PP-8, PM-10, PT-8 (feature-done; each waits on PG-z).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- v3 loop: each packet has a `## Slices` table.
- Base `dev`, not `main`. The brief step one checked main at b3011ab, but the packets exist only on dev (6c2c7b0), and CLAUDE.md and the lead contract say to branch from and target dev.
- Line lead (rule 19) for #3455 place-image, #3468 tone-controls (Photo) and #3535 multi-layer-select. There is one combined wave plan, and all three records show the same waves.
- Photo tone-controls records on `lead/photo-tone-controls`, because `lead/tone-controls` belongs to the live SuiteUI tone-controls lead (#3476). PRs keep `Feature: tone-controls`.
- PP-1 starts on PL-1 (#3578, merged) rather than all of PL-a. PP-1 is Model-only and uses only the kernel `PlacedImageTarget` and Place types, which are on dev; PL-m (rule bodies) is done too. PL-2 is SuiteUI views, and only PP-3 needs it.
- PP-6 (under 50 lines) is folded into PP-5's PR, as the packet says.
- One PR per slice (rule 22), split per task when a slice is over the 400-line cap: PM-a (~600, so PM-1, PM-2 and PM-3 each get a PR).
- Run act-1a15eecbafe-u0f9 (2026-10-21T14:20Z) takes over this record. The brief asked for base main and status on lead/transform and lead/tone-controls. It uses base dev and these photo-prefixed status branches instead: the fast lane merges only into dev, and lead/transform and lead/tone-controls belong to the live Halo #3443 and SuiteUI #3476 leads. Force-pushing them would rewrite another lead's history.
- Red Linux runs on #3969, #4005 and #4003 came from dev at the time, not from the PRs: the PhotoPlace CommandPath failure (fixed by #4008), stale Design mutation anchors (DY-a), and LargeCatalogBudget timing (moved to perf-suites in #4050/#4069). A fixer merges origin/dev into each branch so the lane re-runs Linux on a fresh head.
- All four slices (PT-a, PT-u, PT-m, PT-z) remain for this run.
- Run act-1a16958d691-2ax3 (2026-10-23) takes over; same base-dev and status-branch choices as above (brief named main; the lane merges only into dev).
- Rule 12 on dev: TC-1 (#4555, ToneTarget, ToneSettings, ToneCommands) is the contract and has merged, so PT-1 builds on it now. PT-2 needs TC-2's ToneRows view, which is not on dev; PT-a ships as two PRs (PT-1 now, PT-2 when TC-2 lands), split per task.
- Tone gets no AdjustmentKind case: one would change the panel sections, the adjustment-layer kinds, the catalog oneOf and the stored `enabled` set. Instead `AdjustmentEdit.kind` is optional with `title`/`section` helpers, which touches PhotoWorkspace.swift and PhotoAdjustmentLayer.swift beyond PT-1's listed files (a few lines each).
- PT-2 runs a ToneIntent through a new `PhotoIntent.tone` case and `PhotoWindow+Tone.swift` (the per-area pattern), so the PR touches 6 files, not the packet's 1. It is still well inside the caps.
- No dead controls: until PT-4, `toneHelp` is non-nil with an image open, so the rows and tone.* commands stay off and say why.

- Run act-1a16cd04539-4jc0 (2026-10-24) takes over; same base-dev and status-branch choices. Brief step one checked main at 654fb3632.
- PT-3 and PT-4 start now (rule 12): TC-1, the tone contract, has merged; IM-photo (LiveToneSurface, the PhotoAdjust+Imaging adapter) is on dev; gradient-fill, transform, history-panel, eyedropper and place-image are all `built`. Tests that need the TC-5 / TC-6 bodies are written and disabled by name, with `Wire:` lines in the PR body.
- PT-3 and PT-4 branch from dev, not stacked on #5008: they are Model-only, share no files with PT-2/PT-6, and stacking would push their diffs over 400 lines while #5007/#5008 wait in the lane.
- PT-5 waits on TC-3 (#5006): snapshots and a render budget of the TC-2 placeholder rows would only be redone when TC-3 lands.
- Run act-1a16f6941b7-zb0r (2026-10-24T19:30Z) takes over; same base-dev and status-branch choices. The brief named lead/tone-controls; it belongs to the live SuiteUI lead (#3476, last commit 19:33Z), so it is not force-pushed and status stays on lead/photo-tone-controls.

- Run act-1a17be7af84-ih2a (2026-10-27T05:45Z) takes over with only PT-z left. Brief step one checked main at fef52e66. PRs stay based on dev: the fast lane merges only into dev and retargets PRs aimed at main.
- Status moves back to `lead/tone-controls`, as the brief asks: the branch is rebuilt as origin/main plus this record (force-with-lease). It held the finished SuiteUI tone lead's record (#3476, "Done: all slices"), which stays intact on `lead/suiteui-tone-controls` (same commit, 10818a7d). `lead/photo-tone-controls` gets the same record.

## Open
- [x] Wire: tone-controls:TC-2 (#4862 merged, dev 491ec5461): PT-2 #5007 builds on ToneRows(settings:help:hidden:onIntent:).
- 06:10Z: this session's GitHub write path appends an attribution footer to PR bodies (#5860); it cannot be stripped from here. The lane strips it from the squash commit.
- [ ] Wire: tone-controls:TC-5 (#4880 open) turns on PT-3's disabled cases; TC-6 (#4953 open) PT-4's; TC-3 (#5006 open) starts PT-5.
- [x] Supervisor (FYI, not a stall): Fast Lane has merged nothing since dev 654fb3632 (~22:55Z) because it is bisecting batch lane/batch-20261023215139: probe -9 macOS gate failed 01:29Z, probe -7 macOS gate passed (started 02:43Z); probe -8 Linux passed; at 05:02Z the lane started a new batch, lane/batch-20261024050226, with 12 older PRs (#4839-#4875). Its macOS gate went red; since 05:45Z it bisects (probe -6). #5007, #5008 and the TC waits are not in it and are queued for a later batch. #5007, #5008 and the TC waits (#5006, #4880, #4953) sit clean with fast-lane for the next batch. Resolved 2026-10-24T06:42Z: dev moved to e5dcf9394 (#4840 landed from batch-20261024050226, whose bisection continues at probes -1/-3); #5007, #5008 and the TC waits are still open and queued.
- PT-3 #5105 (head d86457b20, 5 files, +227/−19): 4 cases on, 2 disabled "waits on TC-5 #4880" with a Wire: line. Mutate 3/4 PhotoAdjust+Imaging: `.sharpenOnCanvas` escapes until TC-5, since only the disabled liveMatchesExportWithSharpenOn can catch it; 2/2 PhotoRender. Its check found an attribution footer after the Head: line, and the lead took it out of the body.
- #5027 (CI finding, testTier1Tone: dragging Black made no Levels step) is the Levels journey, outside tone-controls' files. It doesn't count toward this feature's findings.
- PT-4 #5112 (head 4fe163176, 11 files, +262/−10): Mutate 7/7 PhotoTone+Kernel. Wire: TC-6 turns on 2 command tests and RJ-P12..P14 (`.jobs.pending.json`), and drops the tone.* exampleRuns tolerations. Its check found the same attribution footer, and the lead took it out. The check also flagged 3 test files outside the task list: AllAppsCatalogTests.tolerated, the photo CLI golden and PhotoCommandCatalogTests. The lead accepted them, because each one is the catalog's own test that registering ToneCommands forces, and each follows an existing per-app entry. The build-wave builders' PR tooling appends the footer, so the lead removes it from every builder PR.
- 09:04Z: dev-red #5113 (macos job, range main..1bbaba6c1, 16 PRs) has no tone-controls or layer-styles PR in it, so it is not ours and nothing to do (CLAUDE.md, Parallel agents).

- 14:37Z: batch order puts #5006 then #5007 at positions 5 and 6; probe -4 macOS running. The failing test ships with #5006, so the culprit is most likely #5006 (not ours). A fixer runs only if `needs-fix` lands on #5007.

- 15:22Z: probe -4 green on both gates, so the batch break is #5006 or #5007; waiting on probe -5.

- 16:10Z: #5179 (CI finding, testTier1Tone: the Curves header click no longer folds Curves) went red at e79e9afcb, before any tone-controls PR merged. The range from the last pass touches only #5046, #5097 (zoom) and #5087 (paths). It is not filed against this feature, so no fix is started; PT-6 (#5008) touches the tone rows, so re-check #5179 once #5008 lands.

- 17:24Z: batch 172211 carries #4880 (TC-5). Once it is on dev, turn on the Wire tests that wait on TC-5.

- 18:19Z: dev-red #5183 opened 17:56Z for the full macOS job, range main..33cd6e97c (#3621 ... #4951). None of our PRs is in it; the lane keeps merging.

- 18:55Z: #4880 (TC-5) is on dev. The Pen PR #5134 conflicted with PT-2, PT-6 and PT-4 (PhotoIntent, PhotoWindow, catalog, command-ids, photo.list-commands golden). Resolved by keeping both; the golden is dev plus our tone.* entries, sorted by id.

- Run act-1a175ea563c-tbc1 (2026-10-26T02:00Z) takes over, with the same base-dev and status-branch choices. Brief step one checked main at d3323f6a7. Dev state: PT-1 #4845, PT-2 #5007, PT-3 #5105 and PT-6 #5008 are merged. PT-4 #5112 merged as eb2e2409 and was reverted by #5349 (19de4b93): the catalog laws said tone.auto's step read "Delete" and tone.set failed stepNamedTitle, once TC-6 #4953 made the runs real. TC-3 #5006, TC-5 and TC-6 are all on dev, so no Wire waits remain except TC-z #5239 (live rows, open).
- PT-a slice-done: scoped photo run 40250716357 at cc5c6234a (green) contains #5007.
- PT-m: PT-4 re-lands on `claude/tone-controls-lead-gms6yu` (a revert of the revert, then the law fixes, with the TC-6 tolerations dropped), and Packet-Review amendments 2, 3 and 8 go into it.
- 02:21Z: PT-4 re-land opened as #5363 (head 500006ca, `scripts/ci --changed` PASS, mutation plan 9/9). Amendment 3: the kernel's exposure folds into Photo's Exposure and `tone.set exposure` is refused. Laws: `tone.set: stepNamedTitle` is tolerated (the step names the slider, as transform.flip does). `tone.auto` is tolerated only on the flat-fill laws fixture, where it has nothing to suggest; it keeps every law on the real job input and is tested on the sample picture. Amendment 8 sets Amount first in sharpen-web. RJ-P12..14 now wait on PT-7.
- 02:38Z: #5363 conflicted with dev's layer-styles catalog entries. Merged origin/dev, keeping both tables' `style.*` entries beside the `tone.*` ones and regenerating `photo.list-commands.json` from the CLI. Head is now b9ddeb33; the PR body's Head: line was moved to it.
- PT-3 follow-up (Packet-Review amendment): the live canvas route and the dispatcher route never ran the tone section's Sharpen, which only export ran, so the canvas differed from export with Sharpen on. Branch `claude/tone-controls-lead-gms6yu-pt3` (head 42fbe440, on top of #5363's b9ddeb33, 5 files, +114/−22):
  - Live route: Sharpen runs over the cached composite plus a 3σ margin, and the result is cached per sharpen setting, so a temperature step still composites nothing.
  - Dispatcher route: unsharp runs before the imaging steps, and the region reads `readMargin`.
  - Tests: liveMatchesExportWithSharpenOn, liveMatchesExportWithSharpenUnderALayer, sharpenStepKeepsTheComposite and blurStillFallsBack, which puts an edge by the y 256 seam between rows of tiles.
  - Mutations: PhotoLiveTone 9/9 and PhotoRenderRoute 4/4. `scripts/ci --changed` PASS.
  - The PR opens once #5363 merges, so its diff holds only PT-3.
- PT-3 head moved to 9d80855d: the margin mutation now uses a horizontal edge, and the plans are still all caught.
- #5363 snapshot fix at be2ad8ae: `PhotoToneSnapshots.panel` expected the rows' "off" help with an image open, so it now expects none. The PR body's Head: line was moved to that commit.
- PT-u, PT-5 (render budget): branch `claude/tone-controls-lead-gms6yu-pt5` (head c1fb913b, on top of be2ad8ae, 6 files, +88/−11).
  - First commit is the failing test, `BodyCountSuites.RenderBudgetPhotoToneTests.temperatureDragInThreeBodies`. It steps the Temperature row 120 times and expects at most 3 editor bodies, Temperature at 100 and "Undo Temperature". The p95 is printed only.
  - Second commit: a tone row's drag samples (`tone.set` with a drag token) run on the window's live copy, the same way Free Transform's do (`runLive`). `perform` keeps the copy through tone samples, and the Adjust panel reads `live?.shown`, so each step reads the value it just set.
  - `scripts/ci --changed` PASS. The view code is macOS-only and was written blind. The PR opens once #5363 merges.
- PT-z, PT-7 (live): branch `claude/tone-controls-lead-gms6yu-pt7` (on top of PT-3's 9d80855d, 15 files, +96/−73).
  - First commit, 8beacef6: the failing test `PhotoToneJobsTests.runsLiveAndWritesWhatItExpects`. For each of the white-balance, backlit and sharpen-web jobs, there is one live `.jobs.json` with no pending entry. The job exits 0 and either passes or waits only on pixels. Every output and reference it names exists.
  - Second commit: the three jobs are no longer pending, with `platforms` set to linux and macos.
    - Deterministic inputs: tungsten-grey 480x320, backlit 480x320 and soft-edge 2400x1600.
    - References are the jobs' own exports. The card goes from (134,128,121) to (129,128,128), and the backlit shadow lifts from 69 to 78.
    - Sharpen-web's output is `.jpeg`, which is what JPEG export writes.
    - RJ-P12..14 in jobs.json now have `baseline: pass` and no waits_on.
    - The PJ-T1 journey's skip flag is removed.
- PT-7 gate: `scripts/ci --changed` PASS at 46e6878e. Branch -pt7 pushed. The PR waits for #5363 and PT-3.
- PT-z, PT-8 (feature-done): branch `claude/tone-controls-lead-gms6yu-pt8` (from dev, b8704e52, 2 files).
  - photo.md: a Tone row in the v2 line, listing White Balance, Tone with Auto, Presence and Sharpen as the code names them in `ToneSlider`.
  - photo.md: a PJ-T1 row in the Tier-2 journeys.
  - wave.json: `status: built` and feature_issue #3468.
  - It is docs-only and the lane would land it at once, so its PR opens only after PT-3, PT-5 and PT-7 have merged.

- 03:46Z: #5363 still open (mergeable clean; lane merged #5346, #5368 since). PT-3 9d80855d, PT-5 c1fb913b, PT-7 46e6878e, PT-8 b8704e52 (gate PASS) all wait on it; next check 04:05Z.
- 04:07Z: #5363 still open. Code PRs land on Linux proof plus the supervisor's local-ci/prescreen status (#5346 landed that way); be2ad8ae has none yet. Nothing for the lead to push; next check 04:27Z.
- 04:28Z: #5363 still waits on the pre-screen (no status, no comments); dev at 75292afd. Next check 04:48Z.
- 04:49Z: #5363 still waits on the pre-screen; the lane landed #5154 (dev 999895c8). Next check 05:09Z.
- 05:11Z: #5363 got local-ci/prescreen success at 05:05Z (compile + every Model suite). Awaiting the lane sweep; next check 05:21Z.
- 05:22Z: #5363 has its pre-screen but no lane decision yet; the lane landed #4948 (dev 7e13ba02). Next check 05:37Z.

- 05:39Z: #5363 still open (prescreen green, no lane comment, dev 7e13ba02). PT-3, PT-5, PT-7 branches ready; PRs open when it lands.

- 05:55Z: #5363 still open; dev moved to c480d848 (#5239), merges clean with #5363 and PT-5. Waiting on the lane.

- 06:19Z: #5363 still open, no lane comment; dev unchanged at c480d848 since 05:55Z; dev-red #5321 still open. Waiting on the lane.

- 06:50Z: #5244 (flip canvas) landed and conflicted #5363 in both catalog tables and the photo list-commands golden. Merged dev into #5363 (merge commit), kept both image.flip and tone.* tolerations, regenerated the golden from the CLI; scripts/ci --changed PASS; head 5260e203, Head line moved. Needs a fresh pre-screen. PT-3, PT-5, PT-7 re-merged on it; gates running.

- 07:07Z: gates PASS after re-merge and pushed: PT-5 b1e44767, PT-3 e7544ba8, PT-7 a825b8de. #5363 (5260e203) waits on a fresh prescreen.

- 07:27Z: the lane had flagged #5363 needs-rebase at 06:47Z (old head); fix at 5260e203 cleared it. Mergeable clean, waiting on the prescreen. dev 99ace703 merges clean with all heads.

- 07:49Z: #5363 still waits on the prescreen of 5260e203. dev 3e26fbe4 (#5264) merges clean with #5363, PT-5, PT-7.
