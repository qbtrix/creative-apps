# layer-styles (Halo) lead record

Issue: #3936 · Packet: docs/blueprints/halo/features/layer-styles.md
Run: act-1a16e2f645b-47gj · Session: claude/layer-styles-lead-rsr0u8 · Started: 2026-10-24 (resumed 14:0xZ; earlier runs act-1a16c627cc6-nlss, act-1a1648ae75a-4dqz)
Wire: suiteui layer-styles:LS-a
Wire: suiteui layer-styles:LS-8 (StyleProgram.render: turn on HaloStyleRenderTests.glowReachesItsKeyedSize and glowIsNotClipped; add the no-padding mutation, origin dropped in LiveFrameRendering's styled composite)
Wire: suiteui layer-styles:LS-6 (RJ-H43 job folder Tests/RealJobs/halo/keyed-glow/ once LS-6 and LS-8 land)
Stage: 3 wave 5 (resume): #4911 LS-1 merged on dev 78983bc; #5156 HY-1 ready, clean, waits the lane; #5157/#5158/#5161 drafts; LS-2 is #5174 (open); HY-7 being built per the supervisor's 13:10Z answer (shared SuiteUI GPU layer view)
Base: 6be19b3 (origin/dev)
Next: HY-7 builder on lead/halo-layer-styles-HY-z (SuiteUI StyleLayerView + Halo viewer + no-upload budget test); when #5156 merges, merge dev into #5158, gate, Head, ready; when #5174 LS-2 lands, the same for #5157 then #5161

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HY-a | `HaloLayer.style`, five style properties, `style.*` in the catalog on stubs, Layer > Layer Style… opens the panel | HY-1, HY-2 | MJ-HY | suiteui LS-a (#4911), LS-2 | yes | 0 | draft PRs #5156, #5157 | – | – |
| HY-u | inspector style rows with stopwatches, snapshots, render budget, journey written | HY-3, HY-4 | HJ-Y1 | HY-a, HY-m | yes | 0 | draft PR #5161 | – | – |
| HY-m | style commands one undo step, five properties key and ease, frame renderer draws keyed styles | HY-5, HY-6 | MJ-HY | HY-1; LS-m | no | 0 | draft PR #5158 | – | – |
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
