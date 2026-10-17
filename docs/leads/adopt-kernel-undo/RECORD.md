# adopt-kernel-undo lead record

Issue: #1934 · Packet: docs/blueprints/suiteui/features/adopt-kernel-undo.md
Run: act-1a1483c075b-wqh5 · Session: session_01E7HwLAGZPekcD5oW8jbUBu · Started: 2026-10-17T06:04Z
Stage: 0 setup
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745
Next: wait for editor-kernel (#1933) slice EK-undo: its `Belt-Slice-Done: EK-undo` line on #1933, or `History<` and `HistoryReading` in Sources/SuiteModel on origin/dev; then stage 1 (read the packet) and wave 1 (AU-d1, AU-p1, AU-l1, AU-h1, AU-f1, each after its cross-line hand-off)

Line lead for #1936, #1935 and #1934 (contract rule 19); this record is the
adopt-kernel-undo half. The brief's integration branch is `main` at
fdaabbfb54c925161603d648b04a95ac18d07e93, verified as an ancestor of both
`origin/main` and `origin/dev`; PRs target `dev` per CLAUDE.md (the lane
retargets a fast-lane PR opened against `main` to `dev`).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AU-design | Design undo on `History<DesignSnapshot>` and `HistoryReading` behind its API; stack, run and limit code deleted | AU-d1, AU-d2 | MJ-AU-design (`DesignUndoTests`) | editor-kernel:EK-undo (AU-d1) | false | 0 | blocked | – | – |
| AU-photo | Photo undo on `History<PhotoEdit>` and `HistoryReading` behind its API; stack, id, base and jump code deleted | AU-p1, AU-p2 | MJ-AU-photo (`PhotoHistoryStepsTests`) | editor-kernel:EK-undo (AU-p1) | false | 0 | blocked | – | – |
| AU-library | Library undo on `History<[PhotoItem]>` and `HistoryReading` behind its API; `CatalogHistory.swift` deleted | AU-l1, AU-l2 | MJ-AU-library (`LibraryHistoryTests`) | editor-kernel:EK-undo (AU-l1) | false | 0 | blocked | – | – |
| AU-halo | Halo `ProjectHistory` (live and fake) wraps `History<HaloDocumentState>`; `HaloHistoryRules.swift` and the stack code deleted | AU-h1, AU-h2 | MJ-AU-halo (`ProjectHistoryContractTests`) | editor-kernel:EK-undo (AU-h1) | false | 0 | blocked | – | – |
| AU-flare | `FlareWorkspace` conforms to `HistoryReading` over `CommandEngine`; the Flare-only undo/redo name spelling goes | AU-f1, AU-f2 | MJ-AU-flare (`SceneUndoSelectionTests`) | editor-kernel:EK-undo (AU-f1) | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AU-d1 | AU-design | 1 | Design adapter: `DesignHistory` becomes `History<DesignSnapshot>` behind `undo()`, `redo()`, `endEditRun()`, `canUndo`, `undoActionName`, `undoSwapsDocument`; URL swap and id-counter max stay in the apply closure | Sources/DesignModel/DesignHistory.swift, Sources/DesignModel/DesignWorkspace.swift, Tests/DesignModelTests/DesignUndoTests.swift, Tests/DesignModelTests/DesignUndoSwapEdgeTests.swift, Tests/DesignModelTests/DesignGestureTests.swift, Tests/mutations/DesignModel.KernelUndoAdapter.json | DesignUndoTests, DesignUndoSwapEdgeTests, DesignGestureTests unchanged; `scripts/mutate --plan DesignModel.KernelUndoAdapter` (2+: dropped `endRun()` forward; refusal mapped to success) | – | waiting (EK-undo) |
| AU-d2 | AU-design | 2 | Design delete: stack, run and limit code in `DesignHistory.swift` (keeps the swap step and the `HistoryReading` conformance); plans repointed | Sources/DesignModel/DesignHistory.swift, Sources/DesignModel/DesignWorkspace.swift, Tests/mutations/DesignModel.DesignHistory.json | same tests; `scripts/mutate --validate` | – | waiting (AU-d1) |
| AU-p1 | AU-photo | 1 | Photo adapter: `PhotoHistory` becomes `History<PhotoEdit>`; `apply(edit)` is the closure; `currentStepID`, `isDirty`, `historySteps`, `historyIndex`, `jumpToHistoryStep` read the kernel; `endAdjust()` calls `endRun()` | Sources/PhotoModel/PhotoHistory.swift, Sources/PhotoModel/PhotoWorkspace.swift, Tests/PhotoModelTests/PhotoHistoryStepsTests.swift, Tests/PhotoModelTests/PhotoHistoryTests.swift, Tests/PhotoModelTests/PhotoStepIDTests.swift, Tests/PhotoModelTests/PhotoSliderGestureUndoTests.swift, Tests/mutations/PhotoModel.KernelUndoAdapter.json | those four test files unchanged; `scripts/mutate --plan PhotoModel.KernelUndoAdapter` | – | waiting (EK-undo) |
| AU-p2 | AU-photo | 2 | Photo delete: stack, id, base and jump code in `PhotoHistory.swift`; plans repointed | Sources/PhotoModel/PhotoHistory.swift, Sources/PhotoModel/PhotoWorkspace.swift, Tests/mutations/PhotoModel.PhotoHistory.json | same tests; `scripts/mutate --validate` | – | waiting (AU-p1) |
| AU-l1 | AU-library | 1 | Library adapter: `CatalogHistory` becomes `History<[PhotoItem]>` behind `undo()`, `redo()`, `endCoalescing()`, `undoTitle`; 100-step limit; dirty from the saved step id | Sources/LibraryModel/CatalogHistory.swift, Sources/LibraryModel/LibraryCulling.swift, Sources/LibraryModel/LibraryReadouts.swift, Tests/LibraryModelTests/LibraryHistoryTests.swift, Tests/mutations/LibraryModel.KernelUndoAdapter.json | LibraryHistoryTests unchanged; `scripts/mutate --plan LibraryModel.KernelUndoAdapter` | – | waiting (EK-undo) |
| AU-l2 | AU-library | 2 | Library delete: `CatalogHistory.swift` removed; `LibraryReadouts` plan repointed; C4 part updated | Sources/LibraryModel/CatalogHistory.swift, Sources/LibraryModel/LibraryCulling.swift, Sources/LibraryModel/LibraryReadouts.swift, Tests/mutations/LibraryModel.LibraryReadouts.json, Tests/mutations/LibraryModel.CatalogHistory.json | same tests; `scripts/mutate --validate` | – | waiting (AU-l1) |
| AU-h1 | AU-halo | 1 | Halo adapter: `ProjectHistory` (live and fake) wraps `History<HaloDocumentState>`; `HaloProject.edit` records through it; `file.unsaved` reads `isDirty` | Sources/HaloModel/Live/HaloHistoryRules.swift, Sources/HaloModel/Live/LiveProjectHistory.swift, Sources/HaloModel/Fakes/FakeProjectHistory.swift, Sources/HaloModel/HaloHistory.swift, Sources/HaloModel/HaloProject.swift, Tests/HaloModelTests/ProjectHistoryContractTests.swift, Tests/HaloModelTests/HaloUndoTests.swift, Tests/HaloModelTests/HaloHistoryCommandTests.swift, Tests/mutations/HaloModel.KernelUndoAdapter.json | ProjectHistoryContractTests, HaloUndoTests, HaloHistoryCommandTests unchanged; `scripts/mutate --plan HaloModel.KernelUndoAdapter` | – | waiting (EK-undo) |
| AU-h2 | AU-halo | 2 | Halo delete: `HaloHistoryRules.swift` and the stack code in `HaloHistory`; live and fake shrink to the conformance; C4 part drops the deleted file; plans repointed | Sources/HaloModel/Live/HaloHistoryRules.swift, Sources/HaloModel/Live/LiveProjectHistory.swift, Sources/HaloModel/Fakes/FakeProjectHistory.swift, Sources/HaloModel/HaloHistory.swift, Sources/HaloModel/HaloProject.swift, Tests/mutations/HaloModel.HaloHistory.json | same tests; `scripts/mutate --validate` | – | waiting (AU-h1) |
| AU-f1 | AU-flare | 1 | Flare adapter: `FlareWorkspace` conforms to `HistoryReading` over `CommandEngine` (`canUndo`, `undoName`, `isDirty`); `CommandEngine` stays | Sources/FlareModel/FlareWorkspace.swift, Tests/FlareModelTests/SceneUndoSelectionTests.swift, Tests/FlareModelTests/FlareLiveDragTests.swift, Tests/mutations/FlareModel.KernelUndoAdapter.json | SceneUndoSelectionTests, FlareLiveDragTests unchanged; `scripts/mutate --plan FlareModel.KernelUndoAdapter` | – | waiting (EK-undo) |
| AU-f2 | AU-flare | 2 | Flare delete: the Flare-only `undoActionName`/`redoActionName` spelling in favour of the protocol's; plans repointed; carries `feature-done` when last | Sources/FlareModel/FlareWorkspace.swift, Tests/mutations/FlareModel.FlareWorkspace.json | same tests; `scripts/mutate --validate` | – | waiting (AU-f1) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-17T06:04Z: no task can start. Every slice waits on editor-kernel:EK-undo (`History<Payload>`, `HistoryReading`). On origin/dev 4a86f5f no kernel type exists under Sources/, #1933 has no lead branch and no `Belt-Slice-Done:` comment. Recorded on #1934; stopped per lead.md stage 0 step 4.
- The brief names `main` as the integration branch; PRs will target `dev` (CLAUDE.md: never target `main`; the lane retargets). The brief's main SHA fdaabbf is an ancestor of both.
- Cross-line hand-offs checked on 2026-10-17: AU-design's `DesignHistory.swift` waits on design-seams-2 and files-history (both planned, not started) and `DesignWorkspace.swift` on design-window (planned); AU-photo's `PhotoWorkspace.swift` is free (photo-seams built); AU-library's `CatalogHistory.swift` waits on filters-collections (planned) and spine (building, #1044); AU-halo's files are free (history-files and foundation built); AU-flare's `FlareWorkspace.swift` waits on stage-edit and layers-files (both planned).
- Planned wave 1 once unblocked: AU-p1 and AU-h1 can start as soon as EK-undo merges; AU-d1, AU-l1 and AU-f1 after their line's packets. Wave 2: each app's delete task. This feature's AU-photo and AU-library gate adopt-kernel-layers:AL-photo and adopt-kernel-selection:AS-library, so they go first when the kernel lands.

## Open
- 2026-10-17T06:38Z heartbeat: editor-kernel's lead (run act-1a1483c0771-g24c, `lead/editor-kernel`) started wave 1 on 2026-10-17T06:36Z: PR #1992 (EK-1, slice EK-a). EK-undo waits on EK-a, so it is at least two editor-kernel waves away; still blocked, nothing to start.
- Blocked on #1933 editor-kernel: EK-undo (every slice).
