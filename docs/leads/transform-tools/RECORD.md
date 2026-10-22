# transform-tools lead record

Issue: #3446 · Packet: docs/blueprints/suiteui/features/transform-tools.md
Run: act-1a163b2abfe-f182 (relaunch; first run act-1a1579fdd22-6z1j) · Started: 2026-10-22
Stage: 3 wave 5 (TT-z) shipped; polling lane
Base: 1a518080de143b64a57ee1838c3ef01b775e52e6
Next: fix round 1 PRs land; lane batches #4429; then TT-z done from the dev run holding it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TT-u | 39810321089 | 401242a5 | clarity, mouse, taste, design, job | #4625-#4629 | 0 |
| TT-a | The kernel's transform rules, target, intents and six command specs are declared as stubs, the handles take a turn, the ... | TT-1, TT-2 | SJ0 | editor-kernel | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39411363661 | wanted |
| TT-u | On the gallery page the knob turns the box and its handles together, a side drag grows the turned box in its own frame, ... | TT-3, TT-4 | TJ1 | TT-a | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39445745786 | wanted |
| TT-m | The rules turn, mirror and scale a box about its centre or an anchor and map points both ways, and every transform comma... | TT-5, TT-6 | KJ-transform | TT-a | false | 0 | done | – | – |
| TT-z | The gallery runs its intents through TransformCommands on a live target, the fake app turns and flips so RJ-X32 runs on ... | TT-7, TT-8, TT-9 | TJ1, KJ-transform | TT-u, TT-m, autosave-history:AH-z (merged #4388) | true | 0 | in lane | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TT-1 | TT-a | 1 | The contract as stubs: `FlipDirection`, `BoxAnchor`, `TransformBox`, `TransformRules`, `TransformTarget`, `... | `Sources/SuiteKernel/Transform/TransformRules.swift`, `Sources/SuiteKernel/Transform/TransformCommands.swift`, `Tests/SuiteKernelTests/TransformRulesTests.swift`, `Tests/SuiteKernelTests/TransformCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json` | see packet Acceptance | #3485 | merged |
| TT-2 | TT-a | 2 | The placeholder `TransformRows`; `SelectionHandlesEditor`'s `degrees:` initializer (ignored for now); the g... | `Sources/SuiteUI/TransformRows.swift`, `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Sources/SuiteUI/Gallery/GalleryTransform.swift`, `Sources/SuiteUI/Gallery/GalleryCanvas.swift`, `UITests/SuiteJourneyTests+Transform.swift` | see packet Acceptance | #3486 | merged |
| TT-3 | TT-u | 3 | The rows (X, Y, W, H, Rotation, Flip H and V, identifiers `suite.transform.*`) and the turned box: drawn tu... | `Sources/SuiteUI/TransformRows.swift`, `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Tests/SuiteUITests/TransformRowsTests.swift`, `Tests/SuiteUITests/SelectionHandleTurnTests.swift` | see packet Acceptance | #3512 | merged |
| TT-4 | TT-u | 4 | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteTransformSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetTransformTests.swift`, `UITests/SuiteJourneyTests+Transform.swift` | see packet Acceptance | #3513 | open (9b339941, macOS fix) |
| TT-5 | TT-m | 2 | `TransformRules` bodies; turns on `TransformRulesTests` | `Sources/SuiteKernel/Transform/TransformRules.swift`, `Tests/SuiteKernelTests/TransformRulesTests.swift`, `Tests/mutations/SuiteKernel.TransformRules.json` | see packet Acceptance | #3524 | merged |
| TT-6 | TT-m | 3 | `TransformCommands` bodies and `TransformIntent.command`; turns on `TransformCommandsTests` on a test target | `Sources/SuiteKernel/Transform/TransformCommands.swift`, `Tests/SuiteKernelTests/TransformCommandsTests.swift`, `Tests/mutations/SuiteKernel.TransformCommands.json` | see packet Acceptance | #3524 | merged |
| TT-7 | TT-z | 5 | The gallery page runs each intent through `TransformCommands` on a local target with a `History`, so one un... | `Sources/SuiteUI/Gallery/GalleryTransform.swift`, `Tests/SuiteUITests/TransformLiveTests.swift` | see packet Acceptance | #3577 | open (00e33bb1) |
| TT-8 | TT-z | 4 | The fake app turns and flips: `FakeRect.degrees`, `flipX`, `flipY` (omitted at their defaults, so old jobs'... | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeTransformTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/turn-flip/turn-flip.jobs.json`, `Tests/RealJobs/fake/turn-flip/input/one.fake` | see packet Acceptance | #4429 | open (93c81453) |
| TT-9 | TT-z | 6 | The C4 part names the commands and the rows; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json`, `docs/blueprints/suiteui/features/transform-tools.wave.json` | see packet Acceptance | #4429 | open (feature-done) |

(wave = the packet's build wave; the combined slice-PR plan is under Decisions.)

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22T20:40Z #4429 got needs-rebase (SS-8 #4607 added stroke commands in the same places): merged dev, every hunk a union (38 ids), describeAll budget 20 to 26 KiB (23,612 bytes); scripts/ci --changed CI: PASS; pushed cba819fc, Head moved. Fix round 1 started: 4 fixers, disjoint files (#4625 gallery; #4626+#4629 rows and snapshots; #4627 journey and budgets; #4628 pointers).
- 2026-10-22T20:19Z critic panel on scoped suiteui 39810321089 (401242a5): filed #4625 (TT-z) and #4626-#4629 (TT-u), 5 open (cap). Not filed: InspectorAction pressed state equals hover (shared SuiteUI, outside this feature). Refuted: knob sends a total turn (TT-7 sends the difference); mirror in turned resize. Fix round 1 next.
- 2026-10-22T20:16Z #4429 (TT-z) macOS build green; now dirty against dev (no needs-rebase; the lane integrates it). Scoped suiteui 39810321089 green at 401242a5 (holds TT-a, TT-u, TT-m, not TT-7): critic panel on TT-u's screens started, lenses clarity, mouse, taste, design, job.
- 2026-10-22T19:51Z heartbeat: #4429 (TT-z) base dev head 1f2ab442, clean, lane macOS build in progress; scoped suiteui 39810321089 in progress.
- 19:22Z #3577 (TT-7) merged (a1bf680bff). Merged dev into lead/transform-tools-TT-z (1f2ab442): transform-tools.wave.json conflicted because the merge-json driver pointed at a deleted worktree (now repointed); kept "status": "built" and took dev's waits_on and stroke-style:SS-d. scripts/ci --changed: CI: PASS. #4429 retargeted to dev, Head moved, no footer.
- 18:58Z heartbeat: #3577 build green, still waiting for its lane batch; #4429 stacked; scoped suiteui 39810321089 queued; #4428 (AK) macOS build queued
- 18:40Z heartbeat: #3577 macOS build 39815190852 green, waiting for its lane batch; #4429 stacked; scoped suiteui 39810321089 still queued
- 18:10Z heartbeat: no change; #3577 rebuild 39815190852 pending, scoped suiteui 39810321089 queued
- 17:47Z heartbeat: #3577 macOS rebuild 39815190852 still pending; #4429 stacked; scoped suiteui 39810321089 queued
- 2026-10-22T17:25Z heartbeat: no change. #3577's macOS rebuild 39815190852 is still pending, #4429 is still stacked, and scoped suiteui 39810321089 is still queued. The macOS runners are saturated.
- 2026-10-22T17:04Z heartbeat: #3577 is still waiting on macOS. Build 39813540395 was cancelled, and the lane's rebuild 39815190852 is in the queue. #4429 is still stacked on it. Scoped suiteui 39810321089 (dev 401242a5) is still queued. No needs-fix or needs-rebase.
- 2026-10-22T16:42Z heartbeat: #3577 is waiting on its macOS build 39813540395, which is queued (the runners are saturated; the lane re-dispatched it after an earlier build was cancelled). #4429 is still stacked on it. On dev 401242a5, scoped suiteui 39810321089 is still queued and full CI 39810338100 was cancelled. No needs-fix or needs-rebase.
- 2026-10-22T16:20Z heartbeat: #3577 (TT-7) is clean on dev at eca74db6 and waits for a lane batch. #4429 is still stacked on it. Dev 401242a5 holds #3513 (d96c2645); its runs are pending: scoped suiteui 39810321089 (the TT-4 screens for the critic panel) and full CI 39810338100.
- 2026-10-22T15:50Z heartbeat: #3513 (TT-4) merged into dev at 15:42Z as d96c2645. The lane left #3577 on the TT-4 base, so I merged dev into lead/transform-tools-TT-7 (eca74db6, scripts/ci --changed: CI: PASS), retargeted #3577 to dev, moved its Head line and removed the footer the API added to its body. #4429 is stacked on #3577; no dev CI run holds d96c2645 yet.
- 2026-10-22T15:20Z heartbeat: #3513 macOS build 39786650299 green on 9b339941 (the @Test arguments fix compiles); waits on a lane sweep. #3577, #4429 stacked behind it.
- 2026-10-22T14:58Z heartbeat: #3513 macOS build 39786650299 queued (9b339941); #3577 and #4429 stacked behind it; no needs-fix or needs-rebase.
- 2026-10-22T14:35Z Wave 5 shipped: #3513 merged dev and inlined the Rects in the @Test arguments (9b339941, CI: PASS); #3577 merged it (00e33bb1, CI: PASS); TT-8+TT-9 opened as #4429 (191+/22-, 15 files, Mutate 12/12, feature-done) stacked on #3577. Attribution footers the PR tool added to #4427-#4430 removed. No needs-fix or needs-rebase.
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
- Lane: #3513, #3577, #4429 (stacked). After merge: Belt-Slice-Done TT-z, Mac-Finish-Wanted TT-z, Belt-Contact-Sheet on #3446.
