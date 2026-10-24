# layer-styles (Halo) lead record

Issue: #3936 · Packet: docs/blueprints/halo/features/layer-styles.md
Run: act-1a16c627cc6-nlss · Session: claude/layer-styles-lead-vx2vrg · Started: 2026-10-24 (resumed; earlier run act-1a1648ae75a-4dqz)
Wire: suiteui layer-styles:LS-a
Stage: wave 1 (HY-1 built on LS-a's stubs, stacked on #4911)
Base: a41e7f1 (origin/dev)
Next: HY-2 (Layer > Layer Style… and the panel sheet) in the HY-a slice; open the HY-a PR once #4911 lands on dev

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HY-a | `HaloLayer.style`, five style properties, `style.*` in the catalog on stubs, Layer > Layer Style… opens the panel | HY-1, HY-2 | MJ-HY | suiteui LS-a (#4911 open; stacked on it) | yes | 0 | building | – | – |
| HY-u | inspector style rows with stopwatches, snapshots, render budget, journey written | HY-3, HY-4 | HJ-Y1 | HY-a | yes | 0 | waiting | – | – |
| HY-m | style commands one undo step, five properties key and ease, frame renderer draws keyed styles | HY-5, HY-6 | MJ-HY | HY-a; LS-m | no | 0 | waiting | – | – |
| HY-z | viewer draws through the live route, journey on live, halo.md built | HY-7, HY-8 | HJ-Y1 | HY-u, HY-m; LS-gpu (HY-7); file-flow:HF-z (HY-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HY-1 | HY-a | 1 | `HaloLayer.style`; five properties; adapter stubs; specs and ids; tests disabled | Sources/HaloModel/HaloLayer.swift, Sources/HaloModel/Contracts/HaloValues.swift, Sources/HaloModel/HaloStyle+Kernel.swift, Sources/HaloModel/HaloCommandCatalog.swift, Tests/command-ids/halo.txt, Tests/HaloModelTests/HaloLayerStyleTests.swift | HaloLayerStyleTests (6 on, 4 disabled), command-id list | – | built on branch lead/halo-layer-styles-HY-a (64944d2) |
| HY-2 | HY-a | 2 | Layer menu items by id; panel sheet while `stylePanel` is set | Sources/HaloApp/HaloCommands.swift, Sources/HaloApp/HaloWindow+Styling.swift, Sources/HaloApp/HaloWindow.swift | HaloLayerStyleSnapshots.panel | – | waiting (HY-1) |
| HY-5 | HY-m | 2 | adapter bodies; tests on | Sources/HaloModel/HaloStyle+Kernel.swift, Tests/HaloModelTests/HaloLayerStyleTests.swift, Tests/mutations/HaloModel.HaloStyle+Kernel.json | HaloLayerStyleTests | – | waiting (HY-1, LS-m) |
| HY-3 | HY-u | 3 | inspector style rows with stopwatches | Sources/HaloApp/HaloLayerInspector.swift, Tests/AppSnapshotTests/HaloLayerStyleSnapshots.swift | HaloLayerStyleSnapshots | – | waiting (HY-2) |
| HY-6 | HY-m | 3 | frame renderer draws keyed styles; RJ-H43 job | Sources/HaloModel/Live/LiveFrameRendering.swift, Tests/HaloModelTests/HaloStyleRenderTests.swift, Tests/mutations/HaloModel.LiveFrameRendering.json, Tests/RealJobs/halo/keyed-glow/ | HaloStyleRenderTests | – | waiting (HY-5) |
| HY-4 | HY-u | 4 | render budget; journey written, skipped | Tests/AppSnapshotTests/RenderBudgetHaloLayerStyleTests.swift, UITests/HaloJourneyTests+LayerStyle.swift | RenderBudgetHaloLayerStyleTests | – | waiting (HY-3) |
| HY-7 | HY-z | 5 | viewer live frame via `StyleRoute`; journey on | Sources/HaloApp/HaloViewerCanvas.swift, UITests/HaloJourneyTests+LayerStyle.swift | HaloLayerStyleJourneyTests.testKeyedGlow | – | waiting (HY-4, HY-6, LS-gpu) |
| HY-8 | HY-z | 6 | halo.md row; `status: built`; `feature-done` | docs/blueprints/halo.md, docs/blueprints/halo/features/layer-styles.wave.json | scripts/waves render --dry-run | – | waiting (HY-7, HF-z) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-24: built on LS-a's stubs (#4911) per the supervisor, not waiting for its merge; HY-a's PR opens once #4911 is on dev.
- HY-1 touches three files outside its owns list, each a few lines: `HaloProject.swift` (stored `stylePanel`, part of `==`), `HaloLayerDefaults.swift` and `HaloFixtures.swift` (switch arms for the five new `HaloProperty` cases, which exhaustive switches require).
- The five style properties sit in `HaloProperty.styles`, not `allCases`, so the transform rows and key rules stay unchanged until HY-5's `rows(for:)`. The disabled HY-5 tests read the rows through `propertyRows`.
- Worked from `origin/dev` (a41e7f1), not `main`: the brief named `main` (verified HEAD 0dd23d65), but CLAUDE.md says branch from and target dev, and the lane retargets main PRs to dev.
- Status channel is `lead/halo-layer-styles` with `docs/leads/halo-layer-styles/`: `lead/layer-styles` already carries the Photo layer-styles lead's `docs/leads/layer-styles/RECORD.md` (#4511), so this record is added there under its own folder and never overwrites Photo's.
- No task starts: HY-1 needs SuiteImaging's `LayerStyle`, `LayerStyleTarget` and `StyleCommands` (LS-a), none on dev; rule 20 forbids a Halo copy, and LS-a is the suiteui line's work, so nothing is stubbed here.

## Open
- 2026-10-24: run resumed on the supervisor's direction (build on LS-a's fakes). HY-1 committed test-first on `lead/halo-layer-styles-HY-a`, stacked on LS-1 (#4911, open). The PR waits for #4911 to land so its diff stays HY-a's own.
- 2026-10-22T18:01Z re-check 3 on dev 5b2cafa: #3937 still `waiting-on-prereq`, no `LayerStyle`/`StyleCommands` on dev; PH-a #4426 open (fast-lane, mergeable clean, not merged); no HF-3/HF-4 merge. Third identical poll: `Question for the supervisor:` posted on #3936 (rule 23). Next: act on the answer, else re-read the three waits.
- 2026-10-22T17:40Z re-check 2 on dev 1632da1: #3937 still `waiting-on-prereq`, no `LayerStyle`/`StyleCommands` on dev; PH-a #4426 open (fast-lane, not merged); no HF-3/HF-4 merge. Nothing starts. A third identical poll posts `Question for the supervisor:` on #3936 (rule 23).
- 2026-10-22T17:00Z: #3937 (suiteui layer-styles) open, `waiting-on-prereq`; SuiteImaging on dev a41e7f1 has Adjust and Route only.
- Halo placed-images PH-a #4426 open (PH-u #4437, #4438 stacked); no placed-images slice merged for Halo.
- Halo file-flow HF-m (HF-3, HF-4) not merged; file-flow.wave.json still `planned`.
