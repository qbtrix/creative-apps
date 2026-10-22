# transform-tools lead record

Issue: #3446 · Packet: docs/blueprints/suiteui/features/transform-tools.md
Run: act-1a163b2abfe-f182 (relaunch; first run act-1a1579fdd22-6z1j) · Started: 2026-10-22
Stage: 3 wave 5 (TT-z)
Base: 1a518080de143b64a57ee1838c3ef01b775e52e6
Next: fixer on #3513 (macOS compile error in SuiteTransformSnapshots), restack #3577 on it; builder TT-8+TT-9 stacked on #3577 with feature-done

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TT-a | The kernel's transform rules, target, intents and six command specs are declared as stubs, the handles take a turn, the ... | TT-1, TT-2 | SJ0 | editor-kernel | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39411363661 | wanted |
| TT-u | On the gallery page the knob turns the box and its handles together, a side drag grows the turned box in its own frame, ... | TT-3, TT-4 | TJ1 | TT-a | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39445745786 | wanted |
| TT-m | The rules turn, mirror and scale a box about its centre or an anchor and map points both ways, and every transform comma... | TT-5, TT-6 | KJ-transform | TT-a | false | 0 | done | – | – |
| TT-z | The gallery runs its intents through TransformCommands on a live target, the fake app turns and flips so RJ-X32 runs on ... | TT-7, TT-8, TT-9 | TJ1, KJ-transform | TT-u, TT-m, autosave-history:AH-z (merged #4388) | true | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TT-1 | TT-a | 1 | The contract as stubs: `FlipDirection`, `BoxAnchor`, `TransformBox`, `TransformRules`, `TransformTarget`, `... | `Sources/SuiteKernel/Transform/TransformRules.swift`, `Sources/SuiteKernel/Transform/TransformCommands.swift`, `Tests/SuiteKernelTests/TransformRulesTests.swift`, `Tests/SuiteKernelTests/TransformCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json` | see packet Acceptance | #3485 | merged |
| TT-2 | TT-a | 2 | The placeholder `TransformRows`; `SelectionHandlesEditor`'s `degrees:` initializer (ignored for now); the g... | `Sources/SuiteUI/TransformRows.swift`, `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Sources/SuiteUI/Gallery/GalleryTransform.swift`, `Sources/SuiteUI/Gallery/GalleryCanvas.swift`, `UITests/SuiteJourneyTests+Transform.swift` | see packet Acceptance | #3486 | merged |
| TT-3 | TT-u | 3 | The rows (X, Y, W, H, Rotation, Flip H and V, identifiers `suite.transform.*`) and the turned box: drawn tu... | `Sources/SuiteUI/TransformRows.swift`, `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Tests/SuiteUITests/TransformRowsTests.swift`, `Tests/SuiteUITests/SelectionHandleTurnTests.swift` | see packet Acceptance | #3512 | merged |
| TT-4 | TT-u | 4 | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteTransformSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetTransformTests.swift`, `UITests/SuiteJourneyTests+Transform.swift` | see packet Acceptance | #3513 | open |
| TT-5 | TT-m | 2 | `TransformRules` bodies; turns on `TransformRulesTests` | `Sources/SuiteKernel/Transform/TransformRules.swift`, `Tests/SuiteKernelTests/TransformRulesTests.swift`, `Tests/mutations/SuiteKernel.TransformRules.json` | see packet Acceptance | #3524 | merged |
| TT-6 | TT-m | 3 | `TransformCommands` bodies and `TransformIntent.command`; turns on `TransformCommandsTests` on a test target | `Sources/SuiteKernel/Transform/TransformCommands.swift`, `Tests/SuiteKernelTests/TransformCommandsTests.swift`, `Tests/mutations/SuiteKernel.TransformCommands.json` | see packet Acceptance | #3524 | merged |
| TT-7 | TT-z | 5 | The gallery page runs each intent through `TransformCommands` on a local target with a `History`, so one un... | `Sources/SuiteUI/Gallery/GalleryTransform.swift`, `Tests/SuiteUITests/TransformLiveTests.swift` | see packet Acceptance | #3577 | open |
| TT-8 | TT-z | 4 | The fake app turns and flips: `FakeRect.degrees`, `flipX`, `flipY` (omitted at their defaults, so old jobs'... | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeTransformTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/turn-flip/turn-flip.jobs.json`, `Tests/RealJobs/fake/turn-flip/input/one.fake` | see packet Acceptance | – | planned |
| TT-9 | TT-z | 6 | The C4 part names the commands and the rows; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json`, `docs/blueprints/suiteui/features/transform-tools.wave.json` | see packet Acceptance | – | planned |

(wave = the packet's build wave; the combined slice-PR plan is under Decisions.)

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22 Relaunch as run act-1a163b2abfe-f182 for TT-z only. Brief step one verified main HEAD 0dd23d65. Brief rule 2 asks to rebase lead/transform-tools onto main, but main is 487 commits behind dev and the packets live on dev; the lead branch is rebuilt from origin/dev (1a518080) plus docs/leads/transform-tools and force-pushed with lease. Base stays origin/dev.
- 2026-10-22 AH-z merged (#4388, autosave-history built): TT-8 is unblocked. TT-8 + TT-9 ship as one TT-z slice PR (TT-9 is under 50 lines, rule 11) stacked on #3577, labelled feature-done.
- 2026-10-22 #3513's macOS build (run 39445647593) fails: the `@Test(arguments:)` list in SuiteTransformSnapshots.swift reads a main-actor `static let box`, so the expansion needs await. Fixer: inline the Rects.
- 2026-10-20T13:23Z TT-u macOS build failed on two test-only compile errors; fixer dispatched, then restack TT-4 and TT-z.
- 2026-10-20T11:08Z Restack done: #3512 on dev at a69a49ac (367 lines; kept TT-3's CanvasMarks+Vector and TransformRows over the TT-2 placeholders), #3513 at 6bc71e0a, #3577 at 2c41699c; all CI: PASS.
- 2026-10-20T11:07Z TT-a done: Linux run 39411363661 holds b930e657; Belt-Slice-Done and Mac-Finish-Wanted posted on #3446.
- 2026-10-20T10:43Z #3486 (TT-a part 2) merged as b930e657; fixer restacks #3512 onto dev and #3513, #3577 on it; TT-a done waits on a green Linux run on dev.
- 2026-10-20T08:55Z TT-m merged-done: green dev Linux run https://github.com/qbtrix/creative-apps/actions/runs/39395513875 (be364d1e) holds #3524; Belt-Slice-Done posted (logic slice, no Mac finish).
- 2026-10-20T08:44Z TT-7 opened as #3577 (186 lines, 2 files) stacked on TT-u-4; stack carried dev (heads #3486 fed4d4b5, #3512 c538227e, #3513 7d1586df). Builder flags for critics: turned resize in CanvasMarks+Vector.swift ignores mirror flags, so journey step 3 after a flip may land off.
- 2026-10-20T08:31Z #3524 (TT-m) merged as be364d1e. TT-7 starts, stacked on #3513 after dev is carried up the TT-u stack (#3486 → #3512 → #3513). TT-8 still waits on autosave-history:AH-z.
- 2026-10-20T07:02Z Restack done with merge commits only and the gate passed on every head. #3486 (b21081df, 198 lines) and #3524 (0ba51fba, 271 lines) are now based on dev. #3512 (fcb46615) and #3513 (a791067e) stay stacked. TT-m's conflicts in the Transform kernel files kept TT-m's bodies over dev's TT-1 stubs.
- 2026-10-20T06:46Z #3485 (TT-a part 1) merged as 5a17e0e5. A fixer is merging dev into #3486 and #3524 and retargeting both to dev, then carrying the merge up to #3512 and #3513 and moving every Head line.
- 2026-10-20T06:07Z TT-m (#3524, 271 lines, mutate 4/4 + 3/3) gated green except Design/Library/Halo wall-clock budgets under load ~20; those suites passed serially; named in the PR body.
- 2026-10-20T05:55Z TT-u came to ~600 lines; split into #3512 (TT-3, 367 lines, on TT-a-2) and #3513 (TT-4, 236 lines, on TT-u). Turned-handle tests wait on TT-5 rules; journey steps 2-4 expected red until TT-5/TT-7 (report-only).
- PR bodies written through gh pick up an attribution footer from the proxy (the lane flagged #3483). Bodies are now set through the GitHub MCP tool, which adds none; #3483, #3485 and #3486 were cleaned and builders told.
- TT-a was ~600 lines: split into #3485 (TT-1, base dev, 400 lines) and #3486 (TT-2, stacked on lead/transform-tools-TT-a). #3486 gets retargeted to dev with dev merged in once #3485 squashes; TT-1 branch must stay at or under 400 lines.
- Base is origin/dev, not main: the packets exist only on dev and CLAUDE.md sends every PR to dev (the lane retargets main). Brief step one verified main HEAD b3011ab.
- Line lead (rule 19) over #3449 shape-tools, #3448 eyedropper, #3446 transform-tools; one combined plan.
- Combined plan by slice PRs: wave 1 SH-a, TT-a; wave 2 (stacked on each contract PR, rule 22) SH-m, TT-m, SH-u, TT-u; wave 3 SH-7, TT-7 (z slices, part one) and EY-a once GF-a merges; then EY-u/EY-m; fake tasks TT-8, EY-8, SH-8 in that order as their waits clear; the x-9 status tasks last with feature-done.
- A slice PR over 400 changed lines or 15 files splits into its tasks, the second stacked on the first; the Slice: line stays the slice id.
- TT-2 needs TT-1: shipped together as the TT-a slice PR (rule 22), first commit the disabled suites and skipped journey (rule 13).
- TT-6 waits on TT-5 in the packet; one TT-m PR carries both (rule 22).
- TT-z: TT-7 ships once TT-u and TT-m merge; TT-8 waits on autosave-history:AH-z, so TT-8 + TT-9 ship last.
- kernel-transform.json is an existing editor-kernel C4 part: TT-1 adds its new paths there, not a new part.

## Open
- #3513 compile fix, then #3577 restack; TT-8+TT-9 PR.
