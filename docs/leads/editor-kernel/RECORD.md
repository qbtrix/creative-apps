# editor-kernel lead record

Issue: #1933 · Packet: docs/blueprints/suiteui/features/editor-kernel.md
Run: act-1a1483c0771-g24c · Session: claude/task-52830u · Started: 2026-10-17T06:04Z
Stage: 3 wave 2
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745
Next: wave 2 (EK-2, EK-3, EK-29) is building (relaunched 10:46Z after the 06:52Z session-limit outage) stacked on branch lead-editor-kernel/EK-1 (PR #1992, head 45c1453, still awaiting the supervisor); when the supervisor merges #1992, retarget the wave-2 PRs to dev, add fast-lane, then run the check and start wave 3 from the new origin/dev

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| EK-a | `SuiteKernel` target builds on Linux and macOS; every public type and signature declared as a documented stub, fakes and fixtures | EK-1, EK-2, EK-3, EK-29 | KJ0 | – | no | 0 | building | – | – |
| EK-u | gallery `editor-kernel` page: 200-row layer tree with drag into a parent, selection handles, smart guide with distance label, within the render budget | EK-4, EK-5, EK-6 | testEditorKernelGallery | EK-a | yes | 0 | planned | – | – |
| EK-undo | `History<Payload>`: named steps, folded runs, run ends on undo/redo/endRun, ids never repeat, exact dirty, jump | EK-7, EK-8 | KJ1 | EK-a | no | 0 | planned | – | – |
| EK-sel | `Selection<ID>` replace/toggle/extend, primary, canAdd, prune, grid move; `Nudge`, `Marquee` | EK-9, EK-10 | KJ2 | EK-a | no | 0 | planned | – | – |
| EK-tree | `LayerTree<Payload>` nests, cascades, moves, arranges, groups, ungroups, duplicates; `followsID` without cycles keeping place | EK-11, EK-12, EK-13 | KJ3 | EK-a | no | 0 | planned | – | – |
| EK-keys | `KeyRules` toggle/move/remove/shift keys, key state; `EasePreset`, `EaseCurve` | EK-14, EK-15, EK-16 | KJ4 | EK-a | no | 0 | planned | – | – |
| EK-snap | `Snapping.candidates` and `offset` order; engines stay stubs for snapping SN-2/SN-3 | EK-17, EK-18 | KJ5 | EK-a; EK-tree (EK-18) | no | 0 | planned | – | – |
| EK-box | `BoxMath` resize with Shift/Option, never flips, scaled; `HandleHit` | EK-19, EK-20 | KJ6 | EK-a | no | 0 | planned | – | – |
| EK-run | `ExportRun<Options>` state machine, progress never back, cancel to idle | EK-21, EK-22 | KJ7 | EK-a | no | 0 | planned | – | – |
| EK-doc | `DocumentSession` dirty/status/autosave/recovery; `VersionedJSON.probe` | EK-23, EK-24 | KJ8 | EK-a | no | 0 | planned | – | – |
| EK-stroke | `StrokeSmoother`, `DabSpacer`, `BrushSettings`, `BrushPreset`, `LiveCopy` | EK-27, EK-28 | KJ10 | EK-a | no | 0 | planned | – | – |
| EK-chrome | `ExportSheet`, `StrokePacer`, `PointerPressure`, `BrushCursorMark`, `ToolKeys` on the gallery page, on the fakes | EK-30, EK-31 | testEditorKernelGallery | EK-a (EK-30 edits EK-4's page, so after EK-4) | yes | 0 | planned | – | – |
| EK-z | KJ9 full walk; blueprints and docs/engineering.md name the kernel tier; `status: built` | EK-25, EK-26 | KJ9 | every slice above; canvas-host:CH-d (EK-26) | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| EK-1 | EK-a | 1 | `SuiteKernel` + `SuiteKernelTests` targets (Package.swift, project.yml, scripts/test-scope), `Geometry.swift`, header doc, C4 container and geometry part, KJ0 disabled | Package.swift, project.yml, scripts/test-scope, Sources/SuiteKernel/SuiteKernel.swift, Sources/SuiteKernel/Geometry.swift, Tests/SuiteKernelTests/KernelShapeTests.swift, docs/c4/parts/creative-apps/suite-kernel/container.json, docs/c4/parts/creative-apps/suite-kernel/kernel-geometry.json | KernelShapeTests.geometryAliasesAndHandles | #1992 | open, awaiting the supervisor's merge |
| EK-2 | EK-a | 2 | stubs: History, HistoryReading, Selection, LayerTree, LayerNode, LayerRow, TreeRefusal; KernelFixtures (tree200, cards); C4 parts | Sources/SuiteKernel/History/History.swift, Sources/SuiteKernel/Selection/Selection.swift, Sources/SuiteKernel/Layers/LayerTree.swift, Sources/SuiteKernel/Fakes/KernelFixtures.swift, Tests/SuiteKernelTests/KernelShapeTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-history.json, kernel-selection.json, kernel-layers.json | KernelShapeTests.stubsReturnFakes | – | building |
| EK-3 | EK-a | 2 | stubs: Keys, KeyRules, BoxMath, HandleHit, ExportRun, DocumentSession, VersionedJSON; C4 parts; KJ0 on | Sources/SuiteKernel/Keys/Keys.swift, Keys/KeyRules.swift, Transform/BoxMath.swift, Transform/HandleHit.swift, Export/ExportRun.swift, Session/DocumentSession.swift, Session/VersionedJSON.swift, Tests/SuiteKernelTests/KernelShapeMoreTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-keys.json, kernel-transform.json, kernel-export-session.json | KernelShapeMoreTests.allModulesDeclared, KJ0 | – | building |
| EK-29 | EK-a | 2 | stubs: Stroke, BrushSettings, LiveCopy, Snapping, SnapLines, SnapGaps; strokeSamples fixture; C4 parts | Sources/SuiteKernel/Stroke/Stroke.swift, Stroke/BrushSettings.swift, Stroke/LiveCopy.swift, Snap/Snapping.swift, Snap/SnapLines.swift, Snap/SnapGaps.swift, Tests/SuiteKernelTests/KernelShapeStrokeTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-stroke.json, kernel-snap.json | KernelShapeStrokeTests.strokeAndSnapStubsDeclared | – | building |
| EK-4 | EK-u | 3 | gallery `editor-kernel` page with LayerTreeList over tree200; journey written, skipped | Sources/SuiteUI/SuiteGallery.swift, Sources/SuiteUI/Gallery/GalleryEditorKernel.swift, Sources/SuiteUI/LayerTreeList.swift, Tests/SuiteUITests/LayerTreeListTests.swift, UITests/SuiteJourneyTests+EditorKernel.swift | LayerTreeListTests.rowsAndDropTargets | – | planned |
| EK-7 | EK-undo | 3 | HistoryTests written, disabled | Tests/SuiteKernelTests/HistoryTests.swift | HistoryTests (disabled) | – | planned |
| EK-9 | EK-sel | 3 | SelectionTests, NudgeMarqueeTests written, disabled | Tests/SuiteKernelTests/SelectionTests.swift, NudgeMarqueeTests.swift | both (disabled) | – | planned |
| EK-11 | EK-tree | 3 | LayerTreeTests, LayerFollowTests written, disabled | Tests/SuiteKernelTests/LayerTreeTests.swift, LayerFollowTests.swift | both (disabled) | – | planned |
| EK-14 | EK-keys | 3 | KeyRulesTests, EaseCurveTests written, disabled | Tests/SuiteKernelTests/KeyRulesTests.swift, EaseCurveTests.swift | both (disabled) | – | planned |
| EK-17 | EK-snap | 3 | SnapCandidateTests written, disabled | Tests/SuiteKernelTests/SnapCandidateTests.swift | SnapCandidateTests (disabled) | – | planned |
| EK-19 | EK-box | 3 | BoxMathTests, HandleHitTests written, disabled | Tests/SuiteKernelTests/BoxMathTests.swift, HandleHitTests.swift | both (disabled) | – | planned |
| EK-21 | EK-run | 3 | ExportRunTests written, disabled | Tests/SuiteKernelTests/ExportRunTests.swift | ExportRunTests (disabled) | – | planned |
| EK-23 | EK-doc | 3 | DocumentSessionTests, VersionedJSONTests written, disabled | Tests/SuiteKernelTests/DocumentSessionTests.swift, VersionedJSONTests.swift | both (disabled) | – | planned |
| EK-27 | EK-stroke | 3 | StrokeTests written, disabled | Tests/SuiteKernelTests/StrokeTests.swift | StrokeTests (disabled) | – | planned |
| EK-5 | EK-u | 4 | SelectionHandles, SnapGuideMarks on the page; snapshots | Sources/SuiteUI/SelectionHandles.swift, SnapGuideMarks.swift, Gallery/GalleryEditorKernel.swift, Tests/AppSnapshotTests/SuiteEditorKernelSnapshots.swift | SuiteEditorKernelSnapshots | – | planned |
| EK-8 | EK-undo | 4 | History body + plan; turns on HistoryTests | Sources/SuiteKernel/History/History.swift, Tests/mutations/SuiteKernel.History.json, Tests/SuiteKernelTests/HistoryTests.swift | HistoryTests, KJ1; Mutate 4/4 | – | planned |
| EK-10 | EK-sel | 4 | Selection, Nudge, Marquee bodies + plans | Sources/SuiteKernel/Selection/Selection.swift, Nudge.swift, Marquee.swift, Tests/mutations/SuiteKernel.Selection.json, SuiteKernel.Nudge.json, Tests/SuiteKernelTests/SelectionTests.swift, NudgeMarqueeTests.swift | both, KJ2; Mutate 5/5 | – | planned |
| EK-12 | EK-tree | 4 | LayerTree body + plan | Sources/SuiteKernel/Layers/LayerTree.swift, Tests/mutations/SuiteKernel.LayerTree.json, Tests/SuiteKernelTests/LayerTreeTests.swift | LayerTreeTests, KJ3; Mutate 4/4 | – | planned |
| EK-13 | EK-tree | 4 | LayerFollow + plan | Sources/SuiteKernel/Layers/LayerFollow.swift, Tests/mutations/SuiteKernel.LayerFollow.json, Tests/SuiteKernelTests/LayerFollowTests.swift | LayerFollowTests; Mutate 3/3 | – | planned |
| EK-15 | EK-keys | 4 | Keys body (KeyRef, Track, Segment, EasePreset, EaseCurve) + plan | Sources/SuiteKernel/Keys/Keys.swift, Tests/mutations/SuiteKernel.Keys.json, Tests/SuiteKernelTests/EaseCurveTests.swift | EaseCurveTests, KernelShapeMoreTests.presetsSixCases; Mutate 3/3 | – | planned |
| EK-16 | EK-keys | 4 | KeyRules body + plan | Sources/SuiteKernel/Keys/KeyRules.swift, Tests/mutations/SuiteKernel.KeyRules.json, Tests/SuiteKernelTests/KeyRulesTests.swift | KeyRulesTests, KJ4; Mutate 4/4 | – | planned |
| EK-20 | EK-box | 4 | BoxMath, HandleHit bodies + plans | Sources/SuiteKernel/Transform/BoxMath.swift, HandleHit.swift, Tests/mutations/SuiteKernel.BoxMath.json, SuiteKernel.HandleHit.json, Tests/SuiteKernelTests/BoxMathTests.swift, HandleHitTests.swift | both, KJ6; Mutate 6/6 | – | planned |
| EK-22 | EK-run | 4 | ExportRun body + plan | Sources/SuiteKernel/Export/ExportRun.swift, Tests/mutations/SuiteKernel.ExportRun.json, Tests/SuiteKernelTests/ExportRunTests.swift | ExportRunTests, KJ7; Mutate 4/4 | – | planned |
| EK-24 | EK-doc | 4 | DocumentSession, RecoveryOffer, VersionedJSON bodies + plans | Sources/SuiteKernel/Session/DocumentSession.swift, VersionedJSON.swift, Tests/mutations/SuiteKernel.DocumentSession.json, SuiteKernel.VersionedJSON.json, Tests/SuiteKernelTests/DocumentSessionTests.swift, VersionedJSONTests.swift | both, KJ8; Mutate 4/4 | – | planned |
| EK-28 | EK-stroke | 4 | StrokeSmoother, DabSpacer, BrushSettings, BrushPreset, LiveCopy bodies + plans | Sources/SuiteKernel/Stroke/Stroke.swift, BrushSettings.swift, LiveCopy.swift, Tests/mutations/SuiteKernel.Stroke.json, SuiteKernel.BrushSettings.json, Tests/SuiteKernelTests/StrokeTests.swift | StrokeTests, KJ10; Mutate 7/7 | – | planned |
| EK-30 | EK-chrome | 4 | ExportSheet, StrokePacer, PointerPressure, BrushCursorMark; page's Export button and stroke pad; snapshots | Sources/SuiteUI/ExportSheet.swift, StrokePacer.swift, PointerPressure.swift, BrushCursorMark.swift, Gallery/GalleryEditorKernelChrome.swift, Tests/SuiteUITests/ExportSheetTests.swift, StrokePacerTests.swift, Tests/AppSnapshotTests/SuiteEditorKernelChromeSnapshots.swift | ExportSheetTests.rowsFollowTheRun, StrokePacerTests.spacingIsHalfAFrame | – | planned |
| EK-6 | EK-u | 5 | render budget test (120-sample tree drag ≤ 3 bodies); journey on | Tests/AppSnapshotTests/RenderBudgetEditorKernelTests.swift, UITests/SuiteJourneyTests+EditorKernel.swift | RenderBudgetEditorKernelTests.testTreeDragBodies | – | planned |
| EK-18 | EK-snap | 5 | Snapping body (candidates, offset, .fake, summary) + plan | Sources/SuiteKernel/Snap/Snapping.swift, Tests/mutations/SuiteKernel.Snapping.json, Tests/SuiteKernelTests/SnapCandidateTests.swift | SnapCandidateTests, KJ5; Mutate 4/4 | – | planned |
| EK-31 | EK-chrome | 5 | ToolKeys; page status line names the tool; stroke pad render budget | Sources/SuiteUI/ToolKeys.swift, Tests/SuiteUITests/ToolKeysTests.swift, Sources/SuiteUI/Gallery/GalleryEditorKernelChrome.swift, Tests/AppSnapshotTests/RenderBudgetEditorKernelStrokeTests.swift | ToolKeysTests.letterPicksTool, .modifiersFromFlags | – | planned |
| EK-25 | EK-z | 6 | KJ9 full walk | Tests/SuiteKernelTests/KernelWalkTests.swift | KernelWalkTests.walk | – | planned |
| EK-26 | EK-z | 7 | shared prose; `status: built`; `feature-done` | docs/blueprints/suite.md, docs/blueprints/suiteui.md, docs/engineering.md, docs/blueprints/suiteui/features/editor-kernel.wave.json | scripts/waves render --dry-run | – | planned (waits on canvas-host CH-d for suiteui.md) |

## Waves
- Wave 1: EK-1 alone. Protected paths, so the fast lane refuses it: the lead asks the supervisor on #1933 to run the macOS build-only job and merge.
- Wave 2: EK-2, EK-3, EK-29, independent of each other (disjoint new files). They need EK-1's target to build, so they start stacked on EK-1's branch as soon as its PR is open, and are retargeted to `dev` once EK-1 merges.
- Wave 3: EK-4, EK-7, EK-9, EK-11, EK-14, EK-17, EK-19, EK-21, EK-23, EK-27, all independent (each owns only its test file; EK-4 owns the page files). EK-4 waits on EK-2 (fixtures); EK-17 and EK-27 on EK-29; the rest on EK-2 or EK-3 for the stub types.
- Wave 4: EK-5, EK-8, EK-10, EK-12, EK-13, EK-15, EK-16, EK-20, EK-22, EK-24, EK-28, EK-30, all independent (each fills a different stub file). Each waits on its test task (rule 13) and EK-5/EK-30 on EK-4's page.
- Wave 5: EK-6 (waits on EK-5), EK-18 (waits on EK-17 and EK-12), EK-31 (waits on EK-30), independent of each other.
- Wave 6: EK-25 (waits on every code task).
- Wave 7: EK-26 (final prose, `feature-done`; waits on EK-6, EK-25, EK-31 and canvas-host:CH-d).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Wave 2 runs as Workflow run wf_2a77d1fc-422 (script: scratchpad wf/build-wave.js, a copy of docs/factory/workflows/build-wave.js with `baseBranch`, `noLabel`, `extra` args and REST `gh api` notes); a relaunched lead resumes it with resumeFromRunId or reads the three PRs by head branch `lead-editor-kernel/EK-2|EK-3|EK-29`.
- PRs base `dev`, as CLAUDE.md and lead.md say; the brief's "base main" is read as the integration branch Belt reads (`main` only takes `dev` SHAs that passed CI, and the lane retargets a `main` PR to `dev`). Belt's base SHA fdaabbfb is an ancestor of both.
- Line lead for #1933, #1529 and #1942. The captain commented on #1529 and #1942 (2026-10-17 03:08 UTC): "Out of the beta cut; resumes after beta. Finish the slice in flight, then stop." Neither has a slice in flight, so both are parked (their RECORD.md say so) and this run builds editor-kernel only.
- `gh`'s GraphQL commands (`gh pr create`, `gh issue view`, `gh pr list`, `gh label`) are blocked in this environment (403, "use the REST API"); builders open PRs, add labels and comment with `gh api` REST calls. Documented in every builder prompt.
- Wave 2 stacks on the unmerged EK-1 branch (base `lead/editor-kernel/EK-1`, no `fast-lane` label until retargeted) so the supervisor's merge latency on EK-1 costs one wave, not two. The lead retargets and labels them when EK-1 is on dev.
- Canonical first (rule 20): the kernel is the canonical home itself; its concepts were inventoried against every app Model in the editor-kernel design, and `Tests/canonical-concepts.txt` names them. No extraction task is needed before any kernel task.
- EK-30 waits on EK-4 (it adds to EK-4's page), so EK-chrome's first task runs in wave 4, not wave 2; the packet's waves already say so.

## Open
- Outage: the first wave-2 run (wf_2a77d1fc-422) lost all three builders at ~06:52Z to "session limit, resets 10:40 UTC"; nothing was pushed. Relaunched at 10:46Z. #1992 waited unmerged through the outage (no supervisor comment yet).
- Task branches are `lead-editor-kernel/<task>`: git cannot nest `lead/editor-kernel/<task>` under the record branch `lead/editor-kernel` (EK-1's builder hit "cannot lock ref").
- `gh pr create` appends a "Generated by Claude Code" footer to PR bodies in this environment; EK-1's builder removed it with the GitHub MCP update tool. Later builders open PRs through `gh api` REST and read the body back; the lead strips any footer that survives.
- dev was red at the base 4a86f5f (`scripts/check-app-marks` on #1977's files), fixed by #1985 at 0fb4cca; EK-1 rebased onto it. No `dev-red` issue was open because the scoped runs skip the Linux job.
- EK-1 must be merged by the supervisor (protected paths); the lead cannot dispatch CI.
- EK-26 waits on canvas-host CH-d (owner of `docs/blueprints/suiteui.md`); canvas-host's CH-1 PR (#1978) is open, CH-d is waves away. If CH-d is not on dev when EK-25 merges, the lead asks the supervisor on #1933 whether EK-26 may edit suiteui.md ahead of it.
- #1832: `AppSwitcherTests.theRoomModelMatchesTheMeasuredToolbars` fails on macOS since #1802, so no suiteui or full run reaches the journeys. The UI slices' journey screens may not appear until that is fixed; it never holds a `Belt-Slice-Done:` line.
- Open `CI finding:` issues on line:suiteui (#1813, #1796, #1795, #1784, #1783, #1782, #1781, #1778, #1777) are timeline and editor-window journeys, not this feature's files.
