# stroke-style lead record

Issue: #3450 · Packet: docs/blueprints/suiteui/features/stroke-style.md
Run: act-1a157ad4600-c6w5 · Session: 1dda8f22-4f7f-5e83-a997-571c40aa1288 · Started: 2026-10-20T05:01:16Z
Stage: 3 wave 1
Base: 424b4a60f1ea44dbabfd0ce8a0597674f31ecfc3
Next: #3826 SS-9 on dev (head 21226b0, gate PASS after dev's anchors were fixed). SS-8 waits on shape-tools:SH-z; SS-10 on SS-8, SS-9 and GF-z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SS-a | The kernel's stroke type, rules, target, intents, nine command specs and SVG writer are declared as stubs, the gallery's stroke-editor page is in the index, and the checks are written, disabled. | SS-1, SS-2 | SJ0 | gradient-fill:GF-a (SS-1) | true | 0 | done | 39469631014 | wanted |
| SS-u | On the gallery page the editor sets colour, width, join and cap, shows the dash presets and trim rows (disabled with their reason until SS-d), and hides trim where an app has none, every control identified, within the render budget. | SS-3, SS-4 | KS1 | SS-a (SS-3) | true | 0 | done | 39512606501 | wanted |
| SS-m | The rules clamp widths and scale the dash presets, the SVG writer writes colour, width, join and cap, and every stroke command but dash and trim records exactly one undo step (a scrub one). | SS-5, SS-6 | KJ-stroke | SS-a (SS-5, SS-6) | false | 0 | done | 39512606501 | – |
| SS-d | On the bumped core, dashes and trims paint the trimmed then dashed path, the two commands save fractions and scaled patterns in one step, and the fake app keeps them so RJ-X35 runs on the CLI. | SS-7, SS-8 | KJ-stroke | SS-m (SS-7); shape-tools:SH-z (SS-8) | false | 1 | waiting | – | – |
| SS-z | The gallery runs its intents through StrokeCommands on a live target, the journey dashes and trims on live, and the feature is built. | SS-9, SS-10 | KS1 | SS-u (SS-9); SS-d (SS-9, SS-10); gradient-fill:GF-z (SS-10) | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SS-1 | SS-a | 1 | see packet task table (waits: –) | Sources/SuiteKernel/Fill/VectorStroke.swift, Sources/SuiteKernel/Fill/StrokeRules.swift, Sources/SuiteKernel/Fill/StrokeCommands.swift, Sources/SuiteKernel/Fill/StrokeSVG.swift, Tests/SuiteKernelTests/StrokeRulesTests.swift, Tests/SuiteKernelTests/StrokeCommandsTests.swift, Tests/SuiteKernelTests/StrokeSVGTests.swift | packet acceptance row | #3583 | merged 11:20 (lane batch, Linux run 39412675839) |
| SS-2 | SS-a | – | see packet task table (waits: SS-1) | Sources/SuiteUI/StrokeEditor.swift, Sources/SuiteUI/Gallery/GalleryStrokeEditor.swift, Sources/SuiteUI/Gallery/GalleryInspector.swift, UITests/SuiteJourneyTests+Stroke.swift | packet acceptance row | #3601 | merged 17:44, d7f615d |
| SS-3 | SS-u | – | see packet task table (waits: SS-2) | Sources/SuiteUI/StrokeEditor.swift, Tests/SuiteUITests/StrokeEditorTests.swift | packet acceptance row | #3672 | merged (dev ba57546, 22:16Z) |
| SS-4 | SS-u | – | see packet task table (waits: SS-3) | Tests/AppSnapshotTests/SuiteStrokeEditorSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetStrokeEditorTests.swift, UITests/SuiteJourneyTests+Stroke.swift | packet acceptance row | #3763 | merged (dev f71e8ab, 23:02Z) |
| SS-5 | SS-m | – | see packet task table (waits: SS-1) | Sources/SuiteKernel/Fill/StrokeRules.swift, Sources/SuiteKernel/Fill/StrokeSVG.swift, Tests/SuiteKernelTests/StrokeRulesTests.swift, Tests/SuiteKernelTests/StrokeSVGTests.swift, Tests/mutations/SuiteKernel.StrokeRules.json, Tests/mutations/SuiteKernel.StrokeSVG.json | packet acceptance row | #3600 | merged 13:59 (squash 0f0e50c, batch 39433379397) |
| SS-6 | SS-m | – | see packet task table (waits: SS-5) | Sources/SuiteKernel/Fill/StrokeCommands.swift, Tests/SuiteKernelTests/StrokeCommandsTests.swift, Tests/mutations/SuiteKernel.StrokeCommands.json | packet acceptance row | #3627 | merged (dev ac3e825, 23:01Z) |
| SS-7 | SS-d | 2 | see packet task table (waits: SS-6) | Sources/SuiteKernel/Fill/StrokeRules.swift, Sources/SuiteKernel/Fill/StrokeCommands.swift, Sources/SuiteKernel/Fill/StrokeSVG.swift, Tests/SuiteKernelTests/StrokeDashTrimTests.swift, Tests/mutations/SuiteKernel.StrokeRules.json, Tests/mutations/SuiteKernel.StrokeCommands.json, Tests/mutations/SuiteKernel.StrokeSVG.json | packet acceptance row | #3823 | merged (779e08d) |
| SS-8 | SS-d | – | see packet task table (waits: SS-7) | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeStrokeTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/dash-trim/dash-trim.jobs.json, Tests/RealJobs/fake/dash-trim/input/one.fake | packet acceptance row | – | waiting |
| SS-9 | SS-z | 2 | see packet task table (waits: SS-4, SS-7) | Sources/SuiteUI/Gallery/GalleryStrokeEditor.swift, Tests/SuiteUITests/StrokeEditorLiveTests.swift, UITests/SuiteJourneyTests+Stroke.swift | packet acceptance row | #3826 | open on dev (head 21226b0) |
| SS-10 | SS-z | – | see packet task table (waits: SS-8, SS-9) | docs/c4/parts/creative-apps/suite-kernel/kernel-fill.json, docs/blueprints/suiteui/features/stroke-style.wave.json | packet acceptance row | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target is `dev` (CLAUDE.md, lead.md), not the brief's "base main": main b3011ab is an ancestor of dev, and the packets exist only on dev (#3426, #3432).
- v3 loop: the packet has a `## Slices` table; fix rounds capped at 2 per slice (contract rule 11).
- The contract slice waits on gradient-fill:GF-a (#3421 open, GF-2 not opened); a cross-feature wait is met only once its tasks merge (rule 12), so no task starts on an unmerged branch.
- GF-1 (#3421) merged on dev 9a14677. The packets give each gradient-fill:GF-a wait a per-task reason GF-1 alone meets (AH-1, PL-1: Tests/canonical-concepts.txt; SS-1: the Fill/ module and FillColor); GF-2 shares no file with them, so AH-1, SS-1 and PL-1 count GF-a's wait met. PL-2 still waits on GF-2 (SuiteGallery.swift). PL-1 runs after AH-1 (both edit canonical-concepts.txt). A slice is not one PR: AH-a is ~530 lines, over the 400 cap, so each task is its own PR and the first carries the disabled acceptance tests.

- 2026-10-20T09:12Z: the first SS-1 builder hung on one GitHub read of creative-core from 06:14 to 09:11 and never pushed; stopped it and respawned with a fixed branch name, a local core checkout and timeouts on long commands.

- 2026-10-20T09:34Z: SS-1 (#3583) declares dash(of:), trim(of:) and paintedPath against pinned core 0de5687d, which has no dash/dashPhase/trim on Stroke and no trimmed/dashed on Path: they return neutral values ([], 0 / nil / the input path) until SS-7 after the core bump (core #430). The no-stroke edit message is "Add a stroke first." (packet gives none). The StrokeSVG stub returns [] (the contract returns attributes). StrokeRules.notBuilt mirrors GradientRules.notBuilt.

- SS-5 (#3600): two gate runs failed only on Design timing budgets (DesignBudgetTests.hitTest/fileRoundTrip, DesignSelectBudgetTests.resizeStep) under parallel-builder load; suites passed alone and the gate on the pushed head passed. StrokeSVG keeps a private 4-decimal formatter (core SVGExporter helpers are internal, GradientSVG still a stub); colour bytes reuse SampleRules.hex. preset(of:) reads .solid until SS-7 fills dash(of:).

- SS-2 (#3601): journey file uses SS-3's planned `suite.stroke.*` identifiers (SS-3 must keep them); journey skipped "waits on SS-4", steps 4-5 off until SS-9. Gallery page applies edits to a local stroke; dash and trim only logged until SS-9. C4 suiteui-sources part description now names StrokeEditor.

- SS-6: dash and trim still throw StrokeRules.notBuilt, whose message names "stroke-style SS-6" (StrokeRules.swift, outside SS-6 files); SS-7 fixes the wording.

## Open
- SS-7 waits on creative-core path-geometry #430, the core stroke-style fields (not filed yet) and a core bump; SS-8 on shape-tools:SH-z; SS-10 on GF-z.
- SS-a slice-done posted 2026-10-20 18:17 (Linux check 39469631014 on d7f615d, green); Mac-Finish-Wanted posted.

## Run act-1a15b23f1eb-iz6h
Relaunched 2026-10-20T21:07Z. SS-4 started on lead/stroke-style-SS-4, stacked on #3672 (rule 22).
- 2026-10-21T00:04Z: SS-u and SS-m slice-done posted on #3450 (Linux check 39512606501 on 9f59e33a, green, carries #3763 f71e8ab and #3627 ac3e825). The core wait for SS-7 is met: dev's pin 2258b62 (bump #3549) has the stroke dash/trim fields and PathMeasure trimmed/dashed/paintedPath.
- 2026-10-21T00:20Z: SS-7 (#3823) also edits StrokeCommandsTests.swift (the waiting-core check became dashAndTrimNeedAStroke) and StrokeSVGTests.swift (SS-7's disabled plainStrokeHasNoDash enabled), 9 files. StrokeRules.notBuilt and stub() removed; waitingCore kept for the gallery until SS-9. paintedPath trims then dashes through core's trimmed/dashed (not Stroke.paintedPath) so the order is mutation-tested; isValidPattern mirrors core's internal Stroke.validate (<=64 finite entries >=0, positive sum). Pattern beats preset; dotted preset sets a round cap in the same step; solid resets phase; trim keeps mode and offset; SVG dasharray space-separated, dashoffset only when dashed.
- 2026-10-21T00:32Z: SS-9 (#3826, 3 files +171/-33 vs SS-7): GalleryStrokeBoard is the page's local StrokeTarget with a History<VectorStroke?> and StrokeCommands.specs; drag tokens fold into one step; dashHelp nil (waitingCore no longer shown); preview paints StrokeRules.paintedPath (move/line/close only). GalleryStrokeEditor.applied kept for RenderBudgetStrokeEditorTests. Log line: <command id> (<undo step>, <n> in History) <intent>. Preview a11y value adds dash and trim. No mutation plan (packet: UI). No snapshot PNG changes. Stale waitingCore wording in StrokeEditor.swift header and budget/snapshot comments left for a later fix.
- 2026-10-21T07:48Z: fix round 1 (SS-d): the lane's batch put #3823 on dev after #3521/#3815; Design's DesignStroke+Kernel.swift stub throws StrokeRules.notBuilt, which SS-7 removed. Restored notBuilt (generic feature text) with notBuiltStaysForAppsNotYetOnTheCommands; Design line's file untouched. #3826 merged the new SS-7 tip.
- 2026-10-21T09:26Z: #3823 (SS-7) merged as 779e08d. SS-9 merged dev (clean), retargeted #3826 to dev. Gate on dfafb97: all tests pass; mutate --validate fails on DesignModel.DesignCanvasEditing anchors (#3889), same on clean dev, tracked in #3856; noted on #3450, not fixed here.

## Run act-1a15e9d8ac8-27wz
Relaunched 2026-10-21T13:22:56Z. The lead branch was rebuilt on main 0dd23d6 (record files only). SS-9 #3826 (head 21226b0) is waiting on its macOS build, run 39601623669 (queued). SS-8 still waits on shape-tools:SH-z, and SS-10 on SS-8, SS-9 and GF-z. No open finding carries Feature: stroke-style. #3881 (stroke journey, no Feature: line) is tracked against SS-9.
