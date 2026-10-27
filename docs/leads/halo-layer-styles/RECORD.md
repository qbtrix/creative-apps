# layer-styles (Halo) lead record

Issue: #3936 · Packet: docs/blueprints/halo/features/layer-styles.md
Run: act-1a17bed1e9b-xhpo · Started: 2026-10-27T05:55Z (relaunch; earlier runs act-1a178432d32-jxt0, act-1a175e3e638-skn9, act-1a171ab9e77-es26, act-1a16c627cc6-nlss, act-1a1648ae75a-4dqz)
Wire: suiteui layer-styles:LS-a
Wire: suiteui layer-styles:LS-8 (StyleProgram.render: turn on HaloStyleRenderTests.glowReachesItsKeyedSize and glowIsNotClipped; add the no-padding mutation, origin dropped in LiveFrameRendering's styled composite)
Wire: suiteui layer-styles:LS-6 (RJ-H43 job folder Tests/RealJobs/halo/keyed-glow/ once LS-6 and LS-8 land)
Stage: 2 building (06:00Z): #5158 (HY-m) and #5174 (LS-2) merged on dev; HY-2, HY-u and HY-7 rebuilt on dev ad29aeaf by cherry-picking their own commits (the old stacks carried LS-1, LS-2 and HY-1, all landed); gates running
Base: ad29aeaf (origin/dev; main fef52e66 verified at relaunch)
Next: #5157 (HY-a) ready on fcdeb1b2, in the lane; when it lands merge dev into #5161 (HY-u, 71fbffb1), gate, Head, ready; #5218 (HY-z, 11ebec94) stays draft for LS-9, HY-8 follows. HY-m slice-done waits for a green halo-scoped/full run (dev-red #5818: SuiteUI PendingAdjustTarget compile, not Halo)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HY-a | `HaloLayer.style`, five style properties, `style.*` in the catalog on stubs, Layer > Layer Style… opens the panel | HY-1, HY-2 | MJ-HY | suiteui LS-a (#4911), LS-2 | yes | 0 | draft PRs #5156, #5157 | – | – |
| HY-u | inspector style rows with stopwatches, snapshots, render budget, journey written | HY-3, HY-4 | HJ-Y1 | HY-a, HY-m | yes | 0 | draft PR #5161 | – | – |
| HY-m | style commands one undo step, five properties key and ease, frame renderer draws keyed styles | HY-5, HY-6 | MJ-HY | HY-1; LS-m | no | 0 | merged #5158 (e83dec8c) | – | – |
| HY-z | viewer draws through the live route, journey on live, halo.md built | HY-7, HY-8 | HJ-Y1 | HY-u, HY-m; LS-gpu (HY-7); file-flow:HF-z (HY-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HY-1 | HY-a | 1 | `HaloLayer.style`; five properties; adapter stubs; specs and ids; tests disabled | Sources/HaloModel/HaloLayer.swift, Sources/HaloModel/Contracts/HaloValues.swift, Sources/HaloModel/HaloStyle+Kernel.swift, Sources/HaloModel/HaloCommandCatalog.swift, Tests/command-ids/halo.txt, Tests/HaloModelTests/HaloLayerStyleTests.swift | HaloLayerStyleTests (6 on, 4 disabled), command-id list | #5156 | built, gate PASS on lead/halo-layer-styles-HY-a (e52c9ca, +223/-18, 12 files over LS-1); PR waits on #4911 |
| HY-2 | HY-a | 2 | Layer menu items by id; panel sheet while `stylePanel` is set | Sources/HaloApp/HaloCommands.swift, Sources/HaloApp/HaloWindow+Styling.swift, Sources/HaloApp/HaloWindow.swift | HaloLayerStyleSnapshots.panel, `Mutate: 5/5 HaloModel.HaloStyleMenu` | #5157 | built, gate PASS on lead/halo-layer-styles-HY-a (786456f, +302 over HY-1); PR waits on LS-2 on dev |
| HY-5 | HY-m | 2 | adapter bodies; tests on | Sources/HaloModel/HaloStyle+Kernel.swift, Tests/HaloModelTests/HaloLayerStyleTests.swift, Tests/mutations/HaloModel.HaloStyle+Kernel.json | HaloLayerStyleTests (10 on), `Mutate: 4/4 HaloModel.HaloStyle+Kernel` | #5158 | built, gate PASS on lead/halo-layer-styles-HY-m (3290e96, +80/-16, 4 files over HY-1); stacked on HY-a |
| HY-3 | HY-u | 3 | inspector style rows with stopwatches | Sources/HaloApp/HaloLayerInspector.swift, Tests/AppSnapshotTests/HaloLayerStyleSnapshots.swift | HaloLayerStyleSnapshots.styleRows | #5161 | built on lead/halo-layer-styles-HY-u (HY-m merged with HY-a); pushed (a5bf6960e); gate CI: PASS |
| HY-6 | HY-m | 3 | frame renderer draws keyed styles; RJ-H43 job | Sources/HaloModel/Live/LiveFrameRendering.swift, Tests/HaloModelTests/HaloStyleRenderTests.swift, Tests/mutations/HaloModel.LiveFrameRendering.json, Tests/RealJobs/halo/keyed-glow/ | HaloStyleRenderTests | #5158 | built ahead of LS-8 on lead/halo-layer-styles-HY-m (073ed78a9; HY-m is +229/-24, 9 files over HY-a); 4 tests on, 2 pixel tests disabled until LS-8; `Mutate: 10/10 HaloModel.LiveFrameRendering`; RJ-H43 job deferred |
| HY-4 | HY-u | 4 | render budget; journey written, skipped | Tests/AppSnapshotTests/RenderBudgetHaloLayerStyleTests.swift, UITests/HaloJourneyTests+LayerStyle.swift | RenderBudgetHaloLayerStyleTests | #5161 | pushed (60549a3ba), gate CI: PASS; macOS only, journey skipped until HY-7 |
| HY-7 | HY-z | 5 | viewer live frame via `StyleRoute`; journey on | Sources/HaloApp/HaloViewerCanvas.swift, UITests/HaloJourneyTests+LayerStyle.swift | HaloLayerStyleJourneyTests.testKeyedGlow | – | waiting (HY-4, HY-6, LS-gpu) |
| HY-8 | HY-z | 6 | halo.md row; `status: built`; `feature-done` | docs/blueprints/halo.md, docs/blueprints/halo/features/layer-styles.wave.json | scripts/waves render --dry-run | – | waiting (HY-7, HF-z) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-27T06:00Z (relaunch act-1a17bed1e9b-xhpo): brief rules 2-3 done (lead/file-flow, lead/layer-styles rebased onto main fef52e66, force-with-lease; docs only). This record stays here, mirrored to docs/leads/halo-layer-styles/ on lead/layer-styles; docs/leads/layer-styles/ there is SuiteUI #3937's. HY-a, HY-u and HY-z branches rebuilt on dev by cherry-picking their own commits and pushed with --force-with-lease (my own branches; merging 287 dev commits conflicted only on already-landed LS/HY-1 files). PRs stay on dev.
- 2026-10-26T02:00Z (relaunch act-1a175e3e638-skn9): Belt-Lead lines on #5157 #5158 #5161 #5218 moved to the new run id; attribution footers dropped from those bodies. Status channel and PR base unchanged (lead/halo-layer-styles, dev). Amendment 2 committed on HY-u: the journey expects 3 keyframes.
- 2026-10-25T21:30Z Packet-Review 1 (#3936, 21:15Z), each amendment:
  1. `Param.property` lists `HaloProperty.keyable` (`allCases + styles`), so `inspector.set-property` / `inspector.toggle-animation` take a style property; on HY-m (#5158), since HY-1 is merged. RJ-H43's job uses `timeline.scrub` + `inspector.*`, not `key.set`, when it is written (HY-z).
  2. Three keys (0, 30 and the stopwatch's last-frame key holding 0): HY-u's journey now expects "3 keyframes"; RJ-H43's expected track lists all three; packet line 60's wording rides HY-8's packet edit.
  3. Already so on HY-m: `setStatic` writes the style and clears the track. No change.
  4. Already so on HY-m: `HaloDrawItem.style` and `HaloDrawRules.style(of:in:at:placing:)`. No change.
  5. Already so on HY-m: `LiveFrameRendering.styled` merges source and stroke into one buffer, one `StyleProgram.render`, one composite. No change.
  6. HY-m: `styleSelection` is the style sampled at the playhead (`HaloLayer.sampledStyle`); `setStyle` keys a keyed number it changes at the playhead (`HaloKeyRules.keyed`, clamped). Tests in `HaloStyleKeysTests`.
  7. HY-m: `shadowDistance` range 0...1_000 (`HaloValues.swift`), test `shadowDistanceRunsToAThousand`.
  8. HY-m: `keySegments`, `compositionKeys` (the lane) and `HaloEasingRules.keys`/rank iterate `HaloProperty.keyable`.
  9. Not applied: `HaloKeyRules.rows` keeps the style rows (only while their effect is on). `HaloKeying`'s stopwatch and key-diamond lookups read `propertyRows` for any property, and HY-u's inspector already splits that list into TRANSFORM and LAYER STYLE; a separate `styleRows` would duplicate the row build and the lookups. The transform list is still `HaloProperty.allCases`.
  10. HY-m: `HaloStyleRenderTests` counts a pixel lit at alpha ≥ 1/255; frame 0 lights nothing outside the box; frames 15 and 30 reach > 0 and ≤ `StyleRules.reach` of the sampled style (still disabled until LS-8).
  11. Already so on HY-2 (#5157): Copy writes `LayerStylePasteboard`, Paste reads it and is disabled with help when it is empty. No change.
- 2026-10-25T06:08Z (relaunch act-1a171ab9e77-es26): Belt-Lead lines on #5157 #5158 #5161 #5218 moved to the new run id. Status channel stays lead/halo-layer-styles and PRs stay on dev, as decided earlier.
- 2026-10-24T21:55Z (supervisor): every PR of this beta feature carries `beta` (lane order p0, beta, rest), stacked drafts included. Added to #5157 #5158 #5161 #5218. #5156/#5174 waited because dev-red #5183 (Design drag timing) failed every macOS gate until #5222.
- 2026-10-24 (resume act-1a16e2f645b-47gj): the brief asks to rebase `lead/layer-styles` onto main and force-push. Not done: that branch is the SuiteUI layer-styles lead's live status channel (#3937, last push 13:56Z); this feature's channel stays `lead/halo-layer-styles`, as decided earlier. Work stays on `origin/dev` (the brief's main verified at 4f00afb; CLAUDE.md targets dev). PR bodies move to the new Belt-Lead id.
- 2026-10-24: HY-7 follows the supervisor's 13:10Z answer on #3936: a shared SuiteUI GPU layer view keeps one `RenderDispatcher`, uploads a layer's raster only when its content changes, runs only `StyleRoute.draw` per step and draws the resident result; Halo's viewer passes style and layer. Wire: suiteui layer-styles:LS-9 (StyleRoute body).
- 2026-10-24: HY-a is 525 changed lines over LS-2 (HY-1 223 in 12 files, HY-2 302 in 8), over the 400 cap, so it ships as two PRs, both `Slice: HY-a`: HY-1 once #4911 is on dev, HY-2 once LS-2 is. Posted on #3936.
- 2026-10-24: HY-u is stacked on HY-m merged with HY-a, not on HY-a alone: the inspector's style rows come from HY-5's `rows(for:)` (rows follow effects), and HY-a alone lists none. The view splits `propertyRows` into TRANSFORM and LAYER STYLE; `besideWidth` measures the style titles too. No mutation plan for HY-3: it is macOS view code only, and `scripts/mutate` runs on Linux Model targets.
- 2026-10-24: HY-5 built now on LS-a's types, not after LS-m: its tests call only Halo's adapter (`setStyle`, the keyed write, the rows), none of LS-5/LS-6's bodies. The keying hooks are two small edits in `Live/HaloKeyRules.swift` (outside the owns list): rows append `styleProperties`, and `setStatic` writes a style property into the style.
- 2026-10-24: built on LS-a's stubs (#4911) per the supervisor, not waiting for its merge; HY-a's PR opens once #4911 is on dev.
- HY-1 touches three files outside its owns list, each a few lines: `HaloProject.swift` (stored `stylePanel`, part of `==`), `HaloLayerDefaults.swift` and `HaloFixtures.swift` (switch arms for the five new `HaloProperty` cases, which exhaustive switches require).
- The five style properties sit in `HaloProperty.styles`, not `allCases`, so the transform rows and key rules stay unchanged until HY-5's `rows(for:)`. The disabled HY-5 tests read the rows through `propertyRows`.
- Worked from `origin/dev` (a41e7f1), not `main`: the brief named `main` (verified HEAD 0dd23d65), but CLAUDE.md says branch from and target dev, and the lane retargets main PRs to dev.
- Status channel is `lead/halo-layer-styles` with `docs/leads/halo-layer-styles/`: `lead/layer-styles` already carries the Photo layer-styles lead's `docs/leads/layer-styles/RECORD.md` (#4511), so this record is added there under its own folder and never overwrites Photo's.
- No task starts: HY-1 needs SuiteImaging's `LayerStyle`, `LayerStyleTarget` and `StyleCommands` (LS-a), none on dev; rule 20 forbids a Halo copy, and LS-a is the suiteui line's work, so nothing is stubbed here.
- 2026-10-24 (revised): the supervisor answered (#3936, 10:55Z) that building HY-7 ahead on the StyleRoute stub with a Wire line is right, superseding the earlier "not built ahead". Open point asked on #3936: the viewer draws items in a SwiftUI Canvas and no app holds a RenderDispatcher yet; feeding StyleRoute a layer RenderSurface per frame means a PixelBuffer upload per step (render-contract rule 3). HY-7 is built once the route shape is answered; until then the viewer draws styled layers unstyled and the journey stays skipped.

## Open
- 12:49Z HY-a #5157 open in the lane waiting on local-ci/prescreen; HY-u #5161 draft stacked on it; HY-m done (run 40490171439); HY-z #5218 draft until LS-9. No new line:halo findings.
- 12:17Z #5157 (HY-a) open, no needs-fix, no commit status on fcdeb1b20 yet (waits on local-ci/prescreen); #5161, #5218 draft. HY-m slice done.
- 11:51Z HY-m done: Belt-Slice-Done posted on #3936 (halo-scoped 40490171439 green at 4a7d926f3, contains e83dec8c9). #5157 (HY-a) still in the lane; #5161, #5218 draft.
- 11:27Z #5157 (HY-a) still in the lane, no needs-fix; #5161, #5218 draft. HY-m waits on halo-scoped 40490171439 (in progress) / full 40489065455 (queued) at 4a7d926f3.
- 11:06Z #5157 (HY-a) still in the lane, no needs-fix; #5161, #5218 draft. HY-m waits on runs 40489065455 / 40490171439 at 4a7d926f3 (in progress).
- 10:41Z #5157 (HY-a) still in the lane, no needs-fix; #5161, #5218 draft. HY-m e83dec8c9 waits on full run 40489065455 / halo-scoped 40490171439 at 4a7d926f3 (queued). No new halo findings.
- 10:18Z check: HY-a #5157 waits in the lane (clean). HY-m e83dec8c9: no green run yet (full runs 40484007992, 40487248024 pending; dev macOS red on Library #5128). No new findings.
- 09:56Z check: HY-a #5157 waits in the lane (clean); HY-m e83dec8c9 has no green run yet (dev-red #5818; halo-scoped 40478391622 red on Library's #5128 compile error, not Halo).
- 09:31Z check: #5157 (HY-a) open, clean, waiting in the lane at fcdeb1b2; #5161/#5218 draft; full CI 40470141862 red on macOS test shards (#5818, range of 85 PRs), so HY-m waits for a later green halo-scoped or full run
- 09:18Z check: #5157 (HY-a) still open, clean, waiting in the lane; #5161/#5218 draft; full CI 40470141862 (contains HY-m) pending; working file-flow #5123 after #4936 landed
- 2026-10-26T18:40Z: correction to 15:46Z. Code PRs land in batches of one (#5106, #5267, #5263). Fast-lane run 40375597431 calls #5158 and #5174 eligible, queued behind 9 open p0 PRs and about 46 older beta PRs, which is a day or more at the current rate. I asked the supervisor on #3936 (comment 6424372363) about putting p0 on #5174 and #5158.
- 2026-10-26T15:46Z: root cause of the wait: while dev-red #5321 (macOS) is open the lane forms no code batch (CLAUDE.md, fast lane), so #5158 and #5174 land when #5321 closes or via the supervisor's local Mac gate.
- 2026-10-26T13:57Z: four identical polls (#5158, #5174 eligible, unbatched); `Question for the supervisor:` on #3936 proposing the local Mac gate for #5174 then #5158.
- 2026-10-26T12:55Z: relaunched as act-1a178432d32-jxt0; Belt-Lead lines on #5157, #5158, #5161, #5218 moved to it and the attribution footers removed from their bodies.
- 2026-10-24T21:50Z: HY-7 draft #5218 (head 70a00b2f; SuiteImaging StyleLayerResident/StyleLayerGPU, SuiteUI StyleLayerView, Halo HaloStyledRuns + viewer; journey skip now `waits on LS-9`; Wire: suiteui layer-styles:LS-9). Not compiled on macOS yet. Limits listed in the PR (normal blend only, scale 1, CPU repaint on content change). #5156 still unbatched (in the newest-100 window): `Question for the supervisor:` posted on #3936.
- 2026-10-24T20:15Z: container restart lost the first HY-7 builder (nothing pushed); restarted. #5156 still clean and unmerged (only the fast-lane check on 0e12bffd): the lane is bisecting batch 20261024183708 (probe -6 macOS gate running, #5156 not in it) with dev-red #5183 open. If #5156 isn't batched once that batch resolves: `Question for the supervisor:` on #3936.
- 2026-10-24: draft PRs opened per the supervisor: #5156 (HY-1), #5157 (HY-2), #5158 (HY-m), #5161 (HY-u). They go ready once #4911 and LS-2 are on dev and dev is merged in.
- 2026-10-24T06:40Z: HY-1 gate PASS at e52c9ca after fixing the catalog counts, the conformance exemption (the eleven stubs' examples refuse until LS-6) and the halo list-commands golden (+11 ids only). HY-2 blocked on LS-2; HY-5 on LS-m.
- 2026-10-24: run resumed on the supervisor's direction (build on LS-a's fakes). HY-1 committed test-first on `lead/halo-layer-styles-HY-a`, stacked on LS-1 (#4911, open). The PR waits for #4911 to land so its diff stays HY-a's own.
- 2026-10-22T18:01Z re-check 3 on dev 5b2cafa: #3937 still `waiting-on-prereq`, no `LayerStyle`/`StyleCommands` on dev; PH-a #4426 open (fast-lane, mergeable clean, not merged); no HF-3/HF-4 merge. Third identical poll: `Question for the supervisor:` posted on #3936 (rule 23). Next: act on the answer, else re-read the three waits.
- 2026-10-22T17:40Z re-check 2 on dev 1632da1: #3937 still `waiting-on-prereq`, no `LayerStyle`/`StyleCommands` on dev; PH-a #4426 open (fast-lane, not merged); no HF-3/HF-4 merge. Nothing starts. A third identical poll posts `Question for the supervisor:` on #3936 (rule 23).
- 2026-10-22T17:00Z: #3937 (suiteui layer-styles) open, `waiting-on-prereq`; SuiteImaging on dev a41e7f1 has Adjust and Route only.
- Halo placed-images PH-a #4426 open (PH-u #4437, #4438 stacked); no placed-images slice merged for Halo.
- Halo file-flow HF-m (HF-3, HF-4) not merged; file-flow.wave.json still `planned`.

### Decision (HY-2, 2026-10-24)
- Layer menu style items are spec-built (`HaloStyleMenuState.spec(id)`, MenuCommand(spec, on:)). While a `style.*`
  body is LS-6's stub, the item's help is a dry run on a copy: "Not built yet (layer-styles LS-6)."; it heals when
  LS-6 lands. Paste says "Copy a layer style first." while LayerStylePasteboard (LS-2 placeholder) reads nil.
- The panel opens and closes through `showStylePanel` (spec availability respected); the sheet carries its own
  Done (spec `HaloStyleMenuState.done`, Return) until LS-3 gives LayerStylePanel one.
- Wire: suiteui layer-styles:LS-2 (LayerStylePanel, LayerStylePasteboard placeholders).
