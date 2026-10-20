# gradient-fill lead record

Issue: #3418 · Packet: docs/blueprints/suiteui/features/gradient-fill.md
Run: act-1a1574f672e-wf5q · Session: claude/gradient-fill-lead-1i5sqe · Started: 2026-10-20T03:19Z
Stage: 3 wave 1
Base: 233aff5cae4aac6b2b273fc39c1ed3b06e967b3f
Next: GF-1 (contract stubs) builder running; then stack GF-5 + GF-7 (GF-m) and GF-6 on it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| GF-a | kernel Fill/ module as stubs; gallery page; checks written, disabled | GF-1, GF-2 | SJ0 | command-catalog:CC-u (GF-2) | true | 0 | building | – | – |
| GF-u | the GradientEditor view, snapshots, budget, journey | GF-3, GF-4 | GJ1 | GF-a | true | 0 | planned | – | – |
| GF-m | rules, commands (one undo step per edit), SVG writer | GF-5, GF-6, GF-7 | KJ-fill | GF-a; command-catalog:CC-run (met) | false | 0 | planned | – | – |
| GF-z | gallery live on GradientCommands, fake app takes fills (RJ-X30), built | GF-8, GF-9, GF-10 | GJ1, KJ-fill | GF-u, GF-m; command-catalog:CC-a (met) | true | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| GF-1 | GF-a | 1 | Fill/ module stubs, concept line, C4 part, three suites disabled | Sources/SuiteKernel/Fill/{Fill,GradientRules,GradientCommands,GradientSVG}.swift, Tests/SuiteKernelTests/Gradient{Rules,Commands,SVG}Tests.swift, Tests/canonical-concepts.txt, docs/c4/parts/creative-apps/suite-kernel/kernel-fill.json | suites compile disabled; KernelShapeTests | – | building |
| GF-2 | GF-a | – | placeholder editor + shading stub, gallery page, journey skipped | Sources/SuiteUI/GradientEditor.swift, GradientShading.swift, Gallery/GalleryGradientEditor.swift, SuiteGallery.swift, UITests/SuiteJourneyTests+Gradient.swift | SJ0 | – | blocked on CC-u |
| GF-3 | GF-u | – | the view | Sources/SuiteUI/GradientEditor.swift, GradientShading.swift, Tests/SuiteUITests/GradientEditorTests.swift | GradientEditorTests | – | waits GF-2 |
| GF-4 | GF-u | – | snapshots, budget, journey on | Tests/AppSnapshotTests/SuiteGradientEditorSnapshots.swift, RenderBudgetGradientEditorTests.swift, UITests/SuiteJourneyTests+Gradient.swift | RenderBudgetGradientEditorTests | – | waits GF-3 |
| GF-5 | GF-m | 2 | GradientRules bodies | Sources/SuiteKernel/Fill/GradientRules.swift, Tests/SuiteKernelTests/GradientRulesTests.swift, Tests/mutations/SuiteKernel.GradientRules.json | GradientRulesTests | – | planned |
| GF-6 | GF-m | 3 | GradientCommands bodies, intent.command | Sources/SuiteKernel/Fill/GradientCommands.swift, Tests/SuiteKernelTests/GradientCommandsTests.swift, Tests/mutations/SuiteKernel.GradientCommands.json | GradientCommandsTests | – | planned |
| GF-7 | GF-m | 2 | GradientSVG body | Sources/SuiteKernel/Fill/GradientSVG.swift, Tests/SuiteKernelTests/GradientSVGTests.swift, Tests/mutations/SuiteKernel.GradientSVG.json | GradientSVGTests | – | planned |
| GF-8 | GF-z | – | gallery live through GradientCommands | Sources/SuiteUI/Gallery/GalleryGradientEditor.swift, Tests/SuiteUITests/GradientEditorLiveTests.swift | GradientEditorLiveTests | – | waits GF-4, GF-6 |
| GF-9 | GF-z | 4 | fake app takes fills; RJ-X30 | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeCanvasFillTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/gradient-fill/* | FakeCanvasFillTests, RJ-X30 | – | waits GF-6 |
| GF-10 | GF-z | last | C4 part, status built, feature-done | kernel-fill.json, gradient-fill.wave.json | waves render --dry-run | – | waits GF-8, GF-9, GF-7 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is `lead/suiteui-gradient-fill` (record `docs/leads/suiteui-gradient-fill/`): `lead/gradient-fill` already belongs to the Flare adopt lead (#3419), whose packet has the same feature name.
- PRs target `dev` (CLAUDE.md, contract rule 4); the brief's main b3011ab9 is verified as an ancestor of dev 233aff5c. The lane retargets main to dev anyway.
- GF-a ships as two PRs: GF-1 now, GF-2 once command-catalog:CC-u has merged (it owns SuiteGallery.swift first). GF-m and GF-u-free work stack on GF-1 (rule 22).
- GF-m is three PRs (GF-5 ~300, GF-6 ~330, GF-7 ~140 lines) because one slice PR would be ~770 lines, over the 400 cap. GF-5 and GF-7 each fold their slice's tests; GF-6 waits on GF-5 (its specs call the rules).
- `gh` has no token in this session; PRs, issues and comments go through the GitHub MCP tools.

## Open
- GF-2 (and through it GF-u, GF-8, GF-10) waits on command-catalog:CC-u, blocked on font-picker:FP-a (planned, no PR).
