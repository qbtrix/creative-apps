# shape-tools lead record

Issue: #3449 · Packet: docs/blueprints/suiteui/features/shape-tools.md
Run: act-1a1646f0a9f-d1ei (resumed; first run act-1a1579fdd22-6z1j) · Session: claude/suiteui-feature-lead-v7e2hk · Started: 2026-10-20T04:46Z · Resumed: 2026-10-22T16:30Z
Stage: 3 awaiting supervisor (SH-z blocked on eyedropper:EY-z)
Base: dev 567d03bb (main 0dd23d65 verified)
Next: re-read the FakeCanvasDocument.swift chain each poll (stroke-style:SS-d via #4607, then transform-tools:TT-z #4429, then eyedropper:EY-z); once all three merge, build SH-8 on FakeRect.stroke (with the star-drag budget row), then SH-9 with feature-done, as one slice PR to dev

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SH-a | The kernel's shape spec is complete and its rules, target, intents and two command specs are declared as stubs, the gall... | SH-1, SH-2 | SJ0 | editor-kernel | true | 0 | done | – | – |
| SH-u | On the gallery page the kind chips switch the rows, each row edits its option and shows why a value is out of range, eve... | SH-3, SH-4 | PJ1 | SH-a | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39424989659 | wanted |
| SH-m | The rules build every kind's path in a box and the drag's box with Shift and Option, refuse out-of-range counts in words... | SH-5, SH-6 | KJ-shapes | SH-a | false | 0 | done | – | – |
| SH-z | The gallery draws through shape.draw on a live target, the fake app keeps shape specs so RJ-X34 runs on the CLI, and the... | SH-7, SH-8, SH-9 | PJ1, KJ-shapes | SH-u, SH-m, eyedropper:EY-z, stroke-style:SS-d | true | 0 | building: SH-7 #3567 merged; SH-8, SH-9 wait on stroke-style:SS-d and eyedropper:EY-z | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SH-1 | SH-a | 1 | The contract: `ShapeKind` and `ShapeSpec` (complete), `ShapeRules`, `ShapeTarget`, `ShapeIntent`, the two s... | `Sources/SuiteKernel/Shapes/ShapeSpec.swift`, `Sources/SuiteKernel/Shapes/ShapeRules.swift`, `Sources/SuiteKernel/Shapes/ShapeCommands.swift`, `Tests/SuiteKernelTests/ShapeRulesTests.swift`, `Tests/SuiteKernelTests/ShapeCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-shapes.json` | see packet Acceptance | #3483 | open |
| SH-2 | SH-a | 2 | The placeholder `ShapeToolOptions`; the gallery's `shape-tools` page in `GalleryEditorKernel.pages`, its ca... | `Sources/SuiteUI/ShapeToolOptions.swift`, `Sources/SuiteUI/Gallery/GalleryShapeTools.swift`, `Sources/SuiteUI/Gallery/GalleryEditorKernel.swift`, `UITests/SuiteJourneyTests+Shapes.swift` | see packet Acceptance | #3483 | open |
| SH-3 | SH-u | 3 | The options: kind chips and each kind's rows, the help under an out-of-range value, identifiers `suite.shap... | `Sources/SuiteUI/ShapeToolOptions.swift`, `Tests/SuiteUITests/ShapeToolOptionsTests.swift` | see packet Acceptance | #3509 | merged |
| SH-4 | SH-u | 4 | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteShapeToolsSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetShapeToolsTests.swift`, `UITests/SuiteJourneyTests+Shapes.swift` | see packet Acceptance | #3509 | merged |
| SH-5 | SH-m | 2 | `ShapeRules` bodies (paths through `PathBuilders`, line and arrow, the drag rule, the help sentences); turn... | `Sources/SuiteKernel/Shapes/ShapeRules.swift`, `Tests/SuiteKernelTests/ShapeRulesTests.swift`, `Tests/mutations/SuiteKernel.ShapeRules.json` | see packet Acceptance | #3523 | merged |
| SH-6 | SH-m | 3 | `ShapeCommands` bodies and `ShapeIntent`; turns on `ShapeCommandsTests` on a test target | `Sources/SuiteKernel/Shapes/ShapeCommands.swift`, `Tests/SuiteKernelTests/ShapeCommandsTests.swift`, `Tests/mutations/SuiteKernel.ShapeCommands.json` | see packet Acceptance | #3523 | merged |
| SH-7 | SH-z | 5 | The gallery page draws through `shape.draw` on a local target with a `History` and paints each shape's `Sha... | `Sources/SuiteUI/Gallery/GalleryShapeTools.swift`, `Tests/SuiteUITests/ShapeToolsLiveTests.swift` | see packet Acceptance | #3567 | merged |
| SH-8 | SH-z | 4 | The fake app draws shapes: `FakeRect.shape` (omitted when nil), `FakeCanvasDocument` conforms and lists the... | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeShapeTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/draw-star/draw-star.jobs.json`, `Tests/RealJobs/fake/draw-star/input/empty.fake` | see packet Acceptance | – | planned |
| SH-9 | SH-z | 6 | The C4 part names the commands and the options view; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-shapes.json`, `docs/blueprints/suiteui/features/shape-tools.wave.json` | see packet Acceptance | – | planned |

(wave = the packet's build wave; the combined slice-PR plan is under Decisions.)

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22T19:37Z: poll on dev 567d03bb: SS-8 #4607 and TT-z #4429 still open; no EY-7/8/9 PR. No supervisor reply; SH-8, SH-9 stay unstarted.
- 2026-10-22T19:07Z: poll on dev cf65010a: TT-7 #3577 merged (a1bf680b, doesn't touch the fake); SS-8 #4607 and TT-z #4429 still open; no EY-7/8/9 PR. No supervisor reply; SH-8, SH-9 stay unstarted.
- 2026-10-22T18:36Z: #4608 (merged as e16b9852, supervisor's answer on #3450) puts stroke-style SS-d ahead in the FakeCanvasDocument.swift chain: AH-z → SS-d → TT-z → EY-z → SH-z. SH-8 now also waits on stroke-style:SS-d and builds FakeRect.shape on SS-8's FakeRect.stroke. SS-8 is #4607 (not merged); TT-z #4429 still open; no EY-7/8/9 PR. No supervisor reply to issuecomment-6347075135; SH-8, SH-9 stay unstarted.
- 2026-10-22T18:05Z: poll on dev 5b2cafad: TT-z #4429 still open, no EY-7/8/9 PR. No supervisor reply yet; SH-8, SH-9 stay unstarted.
- 2026-10-22T17:35Z: poll on dev 1d3f98f9: TT-z #4429 still open; no EY-7/8/9 PR. No supervisor reply on #3449. Asked the supervisor to hold or release the run (on #1942, issuecomment-6347075135, covering both features); default: leave SH-8, SH-9 unstarted for the next lead.
- 2026-10-22T17:10Z: Belt nudge: status lives on lead/suiteui-shape-tools, not lead/shape-tools where this run first wrote; record moved here (branch cut from main 0dd23d65 with only docs/leads/suiteui-shape-tools). Re-polled on dev a41e7f1f: TT-z #4429 still open, no EY-7/8/9 on dev (last suiteui eyedropper merge #3597). SH-8 stays unstarted; nothing else in the brief can start.
- 2026-10-22T16:45Z: blocked note on #3449 (issuecomment-6345842420).
- 2026-10-22T16:30Z Resumed by run act-1a1646f0a9f-d1ei for SH-z only. Waits re-read: SH-7 #3567 merged (4eeb532b); autosave-history:AH-z merged (#4388, AH-9/AH-10); transform-tools:TT-z in flight (#4429 open, owns FakeCanvasDocument.swift); eyedropper:EY-z not started (EY-7, EY-8, EY-9 unmerged). SH-8 needs no EY-z code but shares FakeCanvasDocument.swift and its plan with TT-8 and EY-8, which are live in that order, so it is not unchained. No task can start; noted on #3449.
- 2026-10-22T16:30Z Brief rule 2: lead/shape-tools rebuilt on origin/main 0dd23d65 with only docs/leads/shape-tools (the old branch carried dev history, 1793 commits main lacks); slice PRs still target dev (CLAUDE.md; the lane retargets main).
- 2026-10-20T16:25:30Z SH-8 waits on eyedropper EY-8, not EY-7: FakeCanvasDocument.swift is owned in order autosave-history AH-9 (another lead, #3629 AH-8 still open) -> TT-8 -> EY-8 -> SH-8. SH-9 waits on SH-8.
- 2026-10-20T13:00Z Comments posted via gh api get a server-appended attribution footer; stripped all lead comments on #3446/#3448/#3449 via the GitHub MCP comment edit. Post lead comments, then edit via MCP.
- 2026-10-20T11:12Z #3509 needs-rebase fixed: dev merged at fe695591 (C4 description keeps ShapeToolOptions and HistoryPanel clauses), 395 lines; #3567 restacked at 568ddaff; both CI: PASS.
- 2026-10-20T10:44Z #3509 got needs-rebase again (suiteui-sources.json description); fixer merges dev keeping all clauses, then restacks #3567.
- 2026-10-20T09:42Z #3509 needs-rebase cleared: dev merged, C4 description kept both clauses; head f1913a62; #3567 restacked to fd41010c; both CI: PASS.
- 2026-10-20T09:33Z #3509 needs-rebase (conflict in docs/c4/parts/creative-apps/suiteui/suiteui-sources.json); fixer merging dev, keeping both sides, then restacking #3567.
- 2026-10-20T09:19Z SH-u fix pushed: #3509 head e62e666f (comment marker restored, 5 Mac-only files scanned clean); #3567 restacked to d302cba5; both gates CI: PASS, Head lines moved.
- 2026-10-20T09:10Z #3509 (SH-u) macOS build red (run 39392324099): UITests/SuiteJourneyTests+Shapes.swift:7 lost its comment marker; fixer sent to fix SH-u, scan the stack's Mac-only files and restack #3567.
- 2026-10-20T08:38Z SH-m merged-done: green dev Linux run https://github.com/qbtrix/creative-apps/actions/runs/39393071639 (83750492) holds #3523; Belt-Slice-Done posted (logic slice, no Mac finish).
- 2026-10-20T08:16Z SH-7 opened as #3567 (196 lines, base lead/shape-tools-SH-u). #3509 now has dev merged in, head 8e0def08. The star-drag row in RenderBudgetShapeToolsTests, which waits on SH-7, was outside SH-7's files; it folds into SH-8 (under 50 lines, brief rule 8).
- 2026-10-20T08:07Z #3523 (SH-m) merged as 83750492. SH-7 starts now, stacked on #3509 (SH-u) after dev is merged into SH-u (rule 22: stack, don't wait). SH-8 still waits on eyedropper:EY-z.
- 2026-10-20T07:37Z SH-a is merged-done: the green dev Linux run 39386117416 (854a3b52) holds ddf5b86e. Belt-Slice-Done and Mac-Finish-Wanted are posted on #3449. Its critic review waits for a scoped suiteui run.
- 2026-10-20T07:24Z Restack done with merge commits and the gate passed on both. #3509 (30749a4d, 395 lines) and #3523 (bdcc4165, 284 lines) now have base dev. Every conflict was SH-a's stub against the slice's real code, and the slice's side was kept.
- 2026-10-20T07:11Z #3483 (SH-a) merged as ddf5b86e. A fixer is merging dev into #3509 and #3523 and retargeting both to dev. SH-a is merged-done once a green dev Linux job holds ddf5b86e.
- 2026-10-20T06:06Z SH-m (#3523, 284 lines, mutate 4/4 + 2/2) gated green except Design/Library wall-clock budgets under load 10-24 from parallel builders; each suite passed on a clean --no-parallel rerun; named in the PR body. Retargeted to lead/shape-tools-SH-a.
- 2026-10-20T05:48Z SH-u (#3509) was opened against dev while stacked on unmerged #3483; retargeted to lead/shape-tools-SH-a so the lane sees only its 395 lines. It moves to dev once #3483 merges.
- PR bodies written through gh pick up an attribution footer from the proxy (the lane flagged #3483). Bodies are now set through the GitHub MCP tool, which adds none; #3483, #3485 and #3486 were cleaned and builders told.
- Base is origin/dev, not main: the packets exist only on dev and CLAUDE.md sends every PR to dev (the lane retargets main). Brief step one verified main HEAD b3011ab.
- Line lead (rule 19) over #3449 shape-tools, #3448 eyedropper, #3446 transform-tools; one combined plan.
- Combined plan by slice PRs: wave 1 SH-a, TT-a; wave 2 (stacked on each contract PR, rule 22) SH-m, TT-m, SH-u, TT-u; wave 3 SH-7, TT-7 (z slices, part one) and EY-a once GF-a merges; then EY-u/EY-m; fake tasks TT-8, EY-8, SH-8 in that order as their waits clear; the x-9 status tasks last with feature-done.
- A slice PR over 400 changed lines or 15 files splits into its tasks, the second stacked on the first; the Slice: line stays the slice id.
- SH-2 needs SH-1: shipped together as the SH-a slice PR (rule 22), first commit the disabled suites and skipped journey (rule 13).
- SH-6 waits on SH-5 in the packet only for ordering; one SH-m PR carries both (rule 22).
- SH-z: SH-7 and SH-9 can ship once SH-u and SH-m merge; SH-8 waits on eyedropper:EY-z, so SH-z ships as SH-7 now and SH-8 + SH-9 last.
- SH-z, EY-z and TT-z all own Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift and Tests/mutations/SuiteKernel.FakeCanvasDocument.json: their fake tasks run one after another (TT-8, then EY-8, then SH-8), never in one wave.

## Open
- SH-8 waits on eyedropper:EY-z (#3448, labelled waiting-on-prereq), which waits on transform-tools:TT-z (#3446; TT-z PR #4429 open). AH-z, TT-8's wait, is met.
