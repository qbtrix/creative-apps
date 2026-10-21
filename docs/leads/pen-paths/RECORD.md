# pen-paths lead record

Issue: #3518 · Packet: docs/blueprints/suiteui/features/pen-paths.md
Run: act-1a15f92d30e-mfnc · Session: claude/feature-lead-suiteui-srh349 · Started: 2026-10-20T07:09Z (relaunched 2026-10-21)
Stage: 3 wave 5
Base: aaa43f918e028249e0525eb468f37795638932d7
Next: #3770 (PN-3a) compile fix pushed (head be778261), awaiting the lane macOS build; once merged open PN-3 then PN-4. PN-7 is #4153 (head 76b697d2, Fast-Check pass) on the lane. PN-8 waits PN-u + PN-m; PN-9 waits export-pack:XP-z (#3477).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PN-a | Paths/ module stubs, placeholder overlay and pen on a gallery page, checks disabled | PN-1, PN-2 | SJ0 | core bump >= e09c6c30 (PN-1) | no | 0 | merged-done (Belt-Slice-Done posted) | https://github.com/qbtrix/creative-apps/actions/runs/39500009414 | n/a |
| PN-u | Path edit overlay view, snapshots, budget, journey | PN-3, PN-4 | pen journey | PN-a | yes | 0 | building (PN-3a #3770 open; PN-3, PN-4 stacked) | – | – |
| PN-m | PenRules, AnchorEdit, AnchorIndex, PathCommands bodies | PN-5, PN-6, PN-7 | KJ-paths | PN-1 (PN-5, PN-6); command-catalog:CC-run (PN-7, met) | no | 0 | building (PN-5, PN-6 merged; PN-7 #4153 open) | – | – |
| PN-z | Gallery live through PathCommands; fake app takes paths (RJ-X37); built | PN-8, PN-9, PN-10 | pen journey, KJ-paths | PN-u, PN-m, export-pack:XP-z (PN-9) | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PN-1 | PN-a | – | Kernel Paths/ stubs, C4 part, fixture, six suites disabled | Sources/SuiteKernel/Paths/*.swift, Tests/SuiteKernelTests/{PenRules,AnchorEdit,AnchorIndex,PathCommands,AnchorBudget,FakeCanvasPath}Tests.swift, Tests/SuiteKernelTests/AnchorStressFixture.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-paths.json | suites compile disabled; KernelShapeTests | #3643 | merged 014da2f1 |
| PN-2 | PN-a | 1 | Placeholder overlay and pen, gallery page, journey skipped | Sources/SuiteUI/PathEditOverlay.swift, Sources/SuiteUI/CanvasMarks+Path.swift, Sources/SuiteUI/Gallery/GalleryPenPaths.swift, Sources/SuiteUI/SuiteGallery.swift, Tests/canonical-concepts.txt, UITests/SuiteJourneyTests+PenPaths.swift | SJ0 | #3553 | merged 4256c5b8 (2026-10-20 ~21:1xZ) |
| PN-3 | PN-u | 4 | Overlay view | Sources/SuiteUI/PathEditOverlay.swift, Sources/SuiteUI/CanvasMarks+Path.swift, Tests/SuiteUITests/PathEditOverlayTests.swift | PathEditOverlayTests | #3770 (PN-3a), PN-3 next | PN-3a open, head 92162512 (dev merged in), Fast-Check pass; PN-3 on lead/pen-paths-PN-3 with PN-3a merged in (C4 description conflict resolved), PR opens once #3770 merges |
| PN-4 | PN-u | – | Snapshots, budgets, journey on | Tests/AppSnapshotTests/SuitePenPathsSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPenPathsTests.swift, UITests/SuiteJourneyTests+PenPaths.swift | journey | – | on lead/pen-paths-PN-4 with PN-3 merged in (clean); PR opens after PN-3 merges |
| PN-5 | PN-m | – | PenRules and AnchorEdit bodies | Sources/SuiteKernel/Paths/PenRules.swift, Sources/SuiteKernel/Paths/AnchorEdit.swift, tests, mutation plans | PenRulesTests, AnchorEditTests | #3738 | merged |
| PN-6 | PN-m | – | AnchorIndex body; Selection keeps a Set | Sources/SuiteKernel/Paths/AnchorIndex.swift, Sources/SuiteKernel/Selection/Selection.swift, tests, mutation plans | AnchorIndexTests, AnchorBudgetTests | #3739 | merged 5684f9dd |
| PN-7 | PN-m | 5 | PathCommands bodies | Sources/SuiteKernel/Paths/PathCommands.swift, Tests/SuiteKernelTests/PathCommandsTests.swift, Tests/mutations/SuiteKernel.PathCommands.json | PathCommandsTests | #4153 | open, head 76b697d2, Fast-Check pass, Mutate 6/6 |
| PN-8 | PN-z | – | Gallery runs intents through PathCommands | Sources/SuiteUI/Gallery/GalleryPenPaths.swift, Tests/SuiteUITests/PathEditOverlayLiveTests.swift | live test | – | waiting |
| PN-9 | PN-z | – | Fake app takes paths; RJ-X37 | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeCanvasPathTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/pen-path/ | FakeCanvasPathTests | – | waiting |
| PN-10 | PN-z | – | C4, status built, feature-done | docs/c4/parts/creative-apps/suite-kernel/kernel-paths.json, docs/blueprints/suiteui/features/pen-paths.wave.json | scripts/ci | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The core pin moves only through a supervisor bump PR (Package.swift and Package.resolved are protected), so the lead asks for it on #3518 rather than opening one.
- PN-2 is unchained from PN-1 and export-pack:XP-a on the supervisor's answer (rule 18): it builds on SuiteUI-local stand-ins that PN-3 swaps for PN-1's types; SuiteGallery.swift ordering with XP-3 is left to the merge drivers.
- Relaunch (run act-1a15f92d30e-mfnc): #3770 had cancelled macOS builds and a Linux run red on dev's stale DesignCanvasEditing anchors; merged dev in, scripts/ci --changed PASS, pushed 92162512, moved Head and Belt-Lead.

## Open
- 08:37Z: the lane's macOS build has been queued for 30 min behind run 39362977551 (#3409, running since 03:11Z); third identical poll, so asked the supervisor on #3477 (6286926687).
- 08:02Z: PN-2 PR #3553 opened (fast-lane). Its snapshot lands in PN-4 (rubric gap noted, rule 18 stand-ins).
- 07:12Z supervisor answer on #3518 (6285500994): a core bump to core dev (contains e09c6c30) is being built as #758's PR; #3144 rebases onto it. Build what doesn't need it; don't poll the pin.
- 07:09Z: pin is 0de5687d; #3144 would move it to 9ed9ef0, which also lacks e09c6c30 (checked with git merge-base on creative-core). No bump to e09c6c30 or later is open. No PN task can start.
- 15:55Z: core bump #3549 (47dd9bb8) moved the pin to 2258b62; git merge-base on creative-core confirms e09c6c30 is an ancestor. PN-1 builder started (worktree, branch lead/pen-paths-PN-1).
- 16:21Z: PN-1 builder reported CI: PASS (SuiteKernelTests 472 pass, 13 files, +397). Opened #3643 (fast-lane, Refs #3518, Slice PN-a) and stripped the server-added footer. FlareCore aliases: VectorPath=Path, VectorAnchor=PathAnchor, VectorContour=PathContour, AnchorKind; the C4 part kernel-paths.json owns Sources/SuiteKernel/Paths/.
- 2026-10-20T16:22:40Z: PN-5 (PenRules, AnchorEdit) and PN-6 (AnchorIndex, Selection set) builders started, stacked on lead/pen-paths-PN-1; their PRs open once each passes scripts/ci --changed.
- 2026-10-20T16:45:20Z: PN-5 built on lead/pen-paths-PN-5 (head 0594773b, 6 files, +238/-37 vs PN-1, CI: PASS, Mutate: 4/4 SuiteKernel.PenRules, 5/5 SuiteKernel.AnchorEdit). Three PN-1 expectations changed because FlareCore paths infer anchor kinds from handles (cornerThenSmoothIsOneCubic, the symmetric fixture, insertKeepsOutline). Critic panel running. Its PR opens once #3643 merges: against dev now it would carry PN-1 too and break the 400-line cap.
- 2026-10-20T16:57:12Z: PN-5 critic panel: 1 blocking (PenRules.closes closes on a press near the last anchor; Flare ignores it, LiveShapes.swift:91-94), 3 nits (non-finite input in moved/movingHandle and handleOut; port the scale-guard cases; a curved insertKeepsOutline fixture). All 3 changed PN-1 expectations judged to keep the packet intent. Fix round 1 sent on lead/pen-paths-PN-5, before its PR opens.
- 2026-10-20T17:16:05Z: PN-5 fix round 1 pushed (head ec3f3a29, 369 changed lines vs PN-1, CI: PASS, Mutate: 7/7 SuiteKernel.PenRules, 7/7 SuiteKernel.AnchorEdit). Closes ignores a press on the last anchor; non-finite moves, handles and drags are no-ops; the scale-guard cases and a curved insert test are ported. PR opens once #3643 merges.
- 2026-10-20T17:30:27Z: PN-6 built on lead/pen-paths-PN-6 (head ff5a6fbd, stacked on PN-1; 6 files, 248 lines; CI: PASS; Mutate 4/4 SuiteKernel.AnchorIndex, 5/5 SuiteKernel.Selection). Release budgets well under (marquee 0.15/4 ms, move+reindex 0.97/4 ms, hover 0.0006/0.1 ms); debug slack 5x under #if DEBUG. AnchorBudgetTests not in Tests/perf-suites.txt: asked the supervisor. Critic panel sent. PR held until #3643 merges (size cap when stacked).
- 2026-10-20T17:55:07Z: PN-6 critics: 2 blocking (B1 a missed hover scans the whole path, about 10 ms in debug against a 0.1 ms budget; B2 marqueeScales flakes under load, 2/17 runs), 2 nits (N1 extend order with repeated ids, left as is; N2 nearest tie order). Mutate 4/4 and 5/5 confirmed; Design, Halo and Library Model tests 2185 pass. Fix round 1 sent (B1, B2, N2).
- 2026-10-20T18:09:09Z: PN-2 #3553 conflicted with dev d7f615dc (SS-2 #3601, suiteui-sources C4 description). Merged dev in keeping both clauses; scripts/ci --changed CI: PASS after a clean build; pushed head cf39f47b and moved the Head: line.
- 2026-10-20T18:50:04Z: PN-6 fix round 1 pushed, head 7076fe13 (389 lines vs PN-1). B1 segment grid + brute-force equivalence test, miss hovers 9.6ms -> 0.16ms debug; B2 interleaved 15 pairs, min ratio 3x; N2 deterministic ties; N1 left. CI: PASS, Mutate 8/8 AnchorIndex, 5/5 Selection, budget suite 5/5 green. Rebuild after move 14.5ms debug (budget 20ms). Re-check critic sent.
- 2026-10-20T19:17:16Z: PN-6 re-check: B1 and N2 verified correct. New BLOCKING: AnchorBudgetTests debug rebuild budget (20ms) and marqueeScales fail under parallel load (2/6 loaded runs, 1/2 full swift test). Nits: segment filed in up to 1024 cells (cap lower), Set(wide)+sort per hover, public slot, N1 carried. Fix round 2 (last) sent: wall-clock budgets release-only, debug scaling checks made load-proof, cap 64 cells, slot internal. Nits 3 and 5 stay.
- 2026-10-20T19:35:42Z: PN-6 fix round 2 pushed, head cbc0c7af (361 lines vs PN-1). Wall-clock budgets release-only, scaling checks 16x work fail above 64x (loaded 10/10, worst 26x), cap 64 cells with over-cap test, slot and wide internal. CI: PASS, Mutate 9/9 AnchorIndex, 5/5 Selection. Verify critic sent.
- 2026-10-20T19:53:22Z: PN-6 verify critic (round 2): clean, no blocking. Nits (ratio not load-proof at 4x oversubscription; absolute budgets unchecked until perf-suites) plus open round-1 nits filed as gap #3709. PN-6 ready; PR opens after #3643 merges.
- 2026-10-20T20:10:58Z: PN-1 merged to dev as 014da2f1 (#3643). Opening PN-5 and PN-6 PRs: merging dev in, rerunning scripts/ci --changed.
- 2026-10-20T20:28:39Z: PN-5 PR #3738 opened (dev merged in, head 95aa38b2, CI: PASS, fast-lane, footer stripped). PN-6 gate still running.
- 2026-10-20T20:30:48Z: PN-6 PR #3739 opened (dev merged in, head b352e463, CI: PASS, fast-lane, footer stripped).
- 2026-10-20T21:20:20Z: #3553 (PN-2) merged to dev as 4256c5b8. PN-3 builder dispatched on lead/pen-paths-PN-3 (swap stand-ins for PN-1 types, the overlay view, PathEditOverlayTests). #3738/#3739 macOS builds still queued.
- 2026-10-20T21:45:04Z: Belt-Slice-Done: PN-a posted on #3518 (dev Linux run 39500009414 on aaf3ad97, green). #3739 (PN-6) merged as 5684f9dd. #3738 (PN-5) build still queued. PN-3 being split into PN-3a + PN-3.
- 2026-10-20T21:51:54Z: PN-3 split. #3770 (PN-3a, PathGesture + tests) opened, fast-lane, head 475fb9e7. PN-3 overlay stacked on lead/pen-paths-PN-3 at 9cf53b14; its PR opens after #3770 merges, so its diff against dev stays under the cap.
- 2026-10-20T21:52:20Z: PN-4 builder dispatched on lead/pen-paths-PN-4, stacked on lead/pen-paths-PN-3 (snapshots, RenderBudgetPenPathsTests, journey on with per-anchor ids).
- 2026-10-20T22:00Z: PN-4 built on lead/pen-paths-PN-4 at caa97e12 (4 files, +366/-25 over PN-3; scripts/ci --changed PASS; unbuilt on macOS). 12 snapshot PNGs suiteui-pen-paths{,-drawing,-smooth,-close-hover,-selected,-stress}-{light,dark}. Per-anchor ids suite.path.anchor-<c>-<i> (first 200 anchors). Journey runs steps 1-7 where possible and ends in XCTSkip behind penRulesWait (flip after PN-5) and pageWait (flip after PN-8). Asked the supervisor to add RenderBudgetPenPathsTests to Tests/perf-suites.txt.
