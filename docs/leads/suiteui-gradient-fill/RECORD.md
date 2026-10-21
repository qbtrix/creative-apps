# gradient-fill lead record

Issue: #3418 · Packet: docs/blueprints/suiteui/features/gradient-fill.md
Run: act-1a15f92d30e-mfnc · Session: claude/feature-lead-suiteui-srh349 · Started: 2026-10-20T03:19Z (relaunched 2026-10-21)
Stage: 3 wave 5
Base: aaa43f918e028249e0525eb468f37795638932d7
Next: #3742 (GF-6+GF-7, head 573bf571, Fast-Check pass) waits on the lane's macOS build; GF-8 and GF-9 build stacked on feat/suiteui-gradient-gf-6

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| GF-a | kernel Fill/ module as stubs; gallery page; checks written, disabled | GF-1, GF-2 | SJ0 | command-catalog:CC-u (GF-2) | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39554157396 | wanted |
| GF-u | the GradientEditor view, snapshots, budget, journey | GF-3, GF-4 | GJ1 | GF-a | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39646407505 | wanted |
| GF-m | rules, commands (one undo step per edit), SVG writer | GF-5, GF-6, GF-7 | KJ-fill | GF-a; command-catalog:CC-run (met) | false | 0 | building | – | – |
| GF-z | gallery live on GradientCommands, fake app takes fills (RJ-X30), built | GF-8, GF-9, GF-10 | GJ1, KJ-fill | GF-u, GF-m; command-catalog:CC-a (met) | true | 0 | building (stacked on GF-m) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| GF-1 | GF-a | 1 | Fill/ module stubs, concept line, C4 part, three suites disabled | Sources/SuiteKernel/Fill/{Fill,GradientRules,GradientCommands,GradientSVG}.swift, Tests/SuiteKernelTests/Gradient{Rules,Commands,SVG}Tests.swift, Tests/canonical-concepts.txt, docs/c4/parts/creative-apps/suite-kernel/kernel-fill.json | suites compile disabled; KernelShapeTests | #3421 | merged |
| GF-2 | GF-a | 2 | placeholder editor + shading stub, gallery page, journey skipped | Sources/SuiteUI/GradientEditor.swift, GradientShading.swift, Gallery/GalleryGradientEditor.swift, SuiteGallery.swift, UITests/SuiteJourneyTests+Gradient.swift | SJ0 | #3695 | merged |
| GF-3 | GF-u | 3 | the view | Sources/SuiteUI/GradientEditor.swift, GradientShading.swift, Tests/SuiteUITests/GradientEditorTests.swift | GradientEditorTests | #3760 | merged |
| GF-4 | GF-u | 4 | snapshots, budget, journey on | Tests/AppSnapshotTests/SuiteGradientEditorSnapshots.swift, RenderBudgetGradientEditorTests.swift, UITests/SuiteJourneyTests+Gradient.swift | RenderBudgetGradientEditorTests | #3982 | merged f9239af |
| GF-5 | GF-m | 2 | GradientRules bodies | Sources/SuiteKernel/Fill/GradientRules.swift, Tests/SuiteKernelTests/GradientRulesTests.swift, Tests/mutations/SuiteKernel.GradientRules.json | GradientRulesTests | #3705 | merged |
| GF-6 | GF-m | 3 | GradientCommands bodies, intent.command | Sources/SuiteKernel/Fill/GradientCommands.swift, Tests/SuiteKernelTests/GradientCommandsTests.swift, Tests/mutations/SuiteKernel.GradientCommands.json | GradientCommandsTests | #3742 | open, head 573bf571, Fast-Check pass |
| GF-7 | GF-m | 3 | GradientSVG body | Sources/SuiteKernel/Fill/GradientSVG.swift, Tests/SuiteKernelTests/GradientSVGTests.swift, Tests/mutations/SuiteKernel.GradientSVG.json | GradientSVGTests | #3742 | open (folded into GF-6's PR) |
| GF-8 | GF-z | 5 | gallery live through GradientCommands | Sources/SuiteUI/Gallery/GalleryGradientEditor.swift, Tests/SuiteUITests/GradientEditorLiveTests.swift | GradientEditorLiveTests | – | building, stacked on GF-6 |
| GF-9 | GF-z | 5 | fake app takes fills; RJ-X30 | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeCanvasFillTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/gradient-fill/* | FakeCanvasFillTests, RJ-X30 | – | building, stacked on GF-6 |
| GF-10 | GF-z | last | C4 part, status built, feature-done | kernel-fill.json, gradient-fill.wave.json | waves render --dry-run | – | waits GF-8, GF-9 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is `lead/suiteui-gradient-fill` (record `docs/leads/suiteui-gradient-fill/`): `lead/gradient-fill` already belongs to the Flare adopt lead (#3419), whose packet has the same feature name.
- PRs target `dev` (CLAUDE.md, contract rule 4); the brief's main b3011ab9 is verified as an ancestor of dev 233aff5c. The lane retargets main to dev anyway.
- GF-a ships as two PRs: GF-1 now, GF-2 once command-catalog:CC-u has merged (it owns SuiteGallery.swift first). GF-m and GF-u-free work stack on GF-1 (rule 22).
- GF-m is three PRs (GF-5 ~300, GF-6 ~330, GF-7 ~140 lines) because one slice PR would be ~770 lines, over the 400 cap. GF-5 and GF-7 each fold their slice's tests; GF-6 waits on GF-5 (its specs call the rules).
- `gh` has no token in this session; PRs, issues and comments go through the GitHub MCP tools.

- Relaunch (run act-1a15f92d30e-mfnc): GF-z is built stacked on #3742's branch (rule 22); its PR opens once #3742 merges, so its diff against dev stays under the cap.
- #3742 had no Fast-Check marker and a cancelled macOS build; merged dev in (no conflicts), scripts/ci --changed PASS, pushed head 573bf571 and moved the marker.

## Open
- #4047 (needs-ui, line:suiteui): four GradientEditor changes asked by Flare's findings #4039, #4041, #4042, #4043. Taken after GF-z, in GF-u's files.
