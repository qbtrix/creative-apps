# adopt-kernel-selection lead record

Issue: #1935 · Packet: docs/blueprints/suiteui/features/adopt-kernel-selection.md
Run: act-1a1483c075b-wqh5 · Session: session_01E7HwLAGZPekcD5oW8jbUBu · Started: 2026-10-17T06:04Z
Stage: 0 setup
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745
Next: wait for editor-kernel (#1933) slice EK-sel: its `Belt-Slice-Done: EK-sel` line on #1933, or `Selection<` with `Pick`, `Nudge` and `Marquee` in Sources/SuiteModel on origin/dev; then stage 1 (read the packet) and wave 1 (AS-f1, AS-d1, AS-h1; AS-l1 also waits on adopt-kernel-undo:AU-library)

Line lead for #1936, #1935 and #1934 (contract rule 19); this record is the
adopt-kernel-selection half. The brief's integration branch is `main` at
fdaabbfb54c925161603d648b04a95ac18d07e93, verified as an ancestor of both
`origin/main` and `origin/dev`; PRs target `dev` per CLAUDE.md (the lane
retargets a fast-lane PR opened against `main` to `dev`).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AS-flare | Flare selection on `Selection<StageAddress>`, `Pick`, `Nudge`, `Marquee` behind its API; set logic deleted | AS-f1, AS-f2 | MJ-AS-flare (`WorkspaceWiringTests`) | editor-kernel:EK-sel (AS-f1) | false | 0 | blocked | – | – |
| AS-design | Design selection on `Selection<String>` with `canAdd`, `Nudge.delta`/`runKey`, `Marquee.rect`/`union` behind its API; set logic and `DesignDirection` deleted | AS-d1, AS-d2 | MJ-AS-design (`DesignMultiSelectTests`) | editor-kernel:EK-sel (AS-d1) | false | 0 | blocked | – | – |
| AS-halo | Halo `selectedKeys` on `Selection<HaloKeyRef>` as a set with `prune(alive:)` behind its API; set and prune code deleted | AS-h1, AS-h2 | MJ-AS-halo (`HaloKeySelectionTests`) | editor-kernel:EK-sel (AS-h1) | false | 0 | blocked | – | – |
| AS-library | Library `LibraryCatalog.selection` on `Selection<String>` with `anchor`, `pick(_:_:order:)`, `move(_:order:columns:)` behind its API; set code deleted | AS-l1, AS-l2 | MJ-AS-library (`LibraryGridTests`) | editor-kernel:EK-sel, adopt-kernel-undo:AU-library (AS-l1) | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AS-f1 | AS-flare | 1 | Flare adapter: `FlareWorkspace.selection` is `Selection<StageAddress>`; `select(_:extending:)`, `setSelection`, `selectAll`, `deselect`, `selectedLayerIDs`, `selectionBounds` keep signatures; `endSelect` uses `Marquee.union` | Sources/FlareModel/FlareSelection.swift, Tests/FlareModelTests/WorkspaceWiringTests.swift, Tests/FlareModelTests/SymbolEditSelectionTests.swift, Tests/FlareModelTests/J5MarqueeAdversarialTests.swift, Tests/mutations/FlareModel.KernelSelectionAdapter.json | WorkspaceWiringTests, SymbolEditSelectionTests, J5MarqueeAdversarialTests unchanged; `scripts/mutate --plan FlareModel.KernelSelectionAdapter` (2+) | – | waiting (EK-sel) |
| AS-f2 | AS-flare | 2 | Flare delete: the set logic in `FlareSelection.swift` (keeps `StageAddress` hit routing); plans repointed | Sources/FlareModel/FlareSelection.swift, Tests/mutations/FlareModel.FlareSelection.json | same tests; `scripts/mutate --validate` | – | waiting (AS-f1) |
| AS-d1 | AS-design | 1 | Design adapter: `selectedNodeIDs` is `Selection<String>` with `canAdd` = not hidden or locked; `toggleSelection`, `selectItem`, `deselect`, `selectAll`, `selectedNodeID`, `hasMultipleSelection` keep signatures; a change calls `history.endRun()`; `nudge` uses `Nudge.delta`/`runKey`; `beginGesture` wires `MarqueeSelecting` through `Marquee.rect`/`union` | Sources/DesignModel/DesignSelection.swift, Sources/DesignModel/DesignCanvasEditing.swift, Sources/DesignModel/DesignActions.swift, Tests/DesignModelTests/DesignMultiSelectTests.swift, Tests/DesignModelTests/DesignSelectionRunTests.swift, Tests/DesignModelTests/DesignMarqueeTests.swift, Tests/DesignModelTests/DesignActionsTests.swift, Tests/mutations/DesignModel.KernelSelectionAdapter.json | those four test files unchanged; `scripts/mutate --plan DesignModel.KernelSelectionAdapter` | – | waiting (EK-sel) |
| AS-d2 | AS-design | 2 | Design delete: `DesignSelection.swift` set logic and `DesignDirection`; plans repointed | Sources/DesignModel/DesignSelection.swift, Sources/DesignModel/DesignCanvasEditing.swift, Sources/DesignModel/DesignActions.swift, Tests/mutations/DesignModel.DesignSelection.json, Tests/mutations/DesignModel.DesignActions.json | same tests; `scripts/mutate --validate` | – | waiting (AS-d1) |
| AS-h1 | AS-halo | 1 | Halo adapter: `selectedKeys` is `Selection<HaloKeyRef>` (`.toggle` for `selectKey(extending:)`, `.extend` for `selectLaneKeys`), pruned with `prune(alive:)`; `pickedKeyframes`, `pickedSegment`, `clearKeySelection` keep signatures | Sources/HaloModel/HaloKeySelection.swift, Tests/HaloModelTests/HaloKeySelectionTests.swift, Tests/mutations/HaloModel.KernelSelectionAdapter.json | HaloKeySelectionTests unchanged; `scripts/mutate --plan HaloModel.KernelSelectionAdapter` | – | waiting (EK-sel) |
| AS-h2 | AS-halo | 2 | Halo delete: the set and prune code in `HaloKeySelection.swift` (segment and handle code stays for adopt-kernel-easing); plans repointed | Sources/HaloModel/HaloKeySelection.swift, Tests/mutations/HaloModel.HaloKeySelection.json | same tests; `scripts/mutate --validate` | – | waiting (AS-h1) |
| AS-l1 | AS-library | 1 | Library adapter: `LibraryCatalog.selection` is `Selection<String>` with `anchor`; the grid reports `(id, Pick)` and the catalog calls `pick(_:_:order:)`; `move(_:order:columns:)` replaces `GridSelection.move`; `select(_:)`, `cullTargets` keep signatures | Sources/LibraryModel/LibraryCatalog.swift, Sources/LibraryModel/LibraryCulling.swift, Tests/LibraryModelTests/LibraryGridTests.swift, Tests/LibraryModelTests/LibraryGridEdgeTests.swift, Tests/mutations/LibraryModel.KernelSelectionAdapter.json | LibraryGridTests, LibraryGridEdgeTests unchanged; `scripts/mutate --plan LibraryModel.KernelSelectionAdapter` | – | waiting (EK-sel, AU-library) |
| AS-l2 | AS-library | 2 | Library delete: the selection set code in `LibraryCatalog.swift`; plans repointed; carries `feature-done` when last | Sources/LibraryModel/LibraryCatalog.swift, Sources/LibraryModel/LibraryCulling.swift, Tests/mutations/LibraryModel.LibraryCatalog.json | same tests; `scripts/mutate --validate` | – | waiting (AS-l1) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-17T06:04Z: no task can start. Every slice waits on editor-kernel:EK-sel (`Selection<ID>`, `Pick`, `Nudge`, `Marquee`). On origin/dev 4a86f5f no kernel type exists under Sources/, #1933 has no lead branch and no `Belt-Slice-Done:` comment. Recorded on #1935; stopped per lead.md stage 0 step 4.
- The brief names `main` as the integration branch; PRs will target `dev` (CLAUDE.md: never target `main`; the lane retargets). The brief's main SHA fdaabbf is an ancestor of both.
- Cross-line hand-offs checked on 2026-10-17: AS-flare's `FlareSelection.swift` waits on stage-edit (planned, not started); AS-design's `DesignCanvasEditing.swift` waits on the design-seams → canvas-basics → select-several → snapping → design-seams-2 chain (all planned); AS-halo's `HaloKeySelection.swift` is free (easing built; this slice goes before adopt-kernel-easing's Halo slice); AS-library's `LibraryCatalog.swift` waits on spine (building, #1044) and export (planned), and `LibraryCulling.swift` on AU-library first.
- Planned wave 1 once unblocked: AS-h1 can start as soon as EK-sel merges (no cross-line wait); AS-f1, AS-d1 and AS-l1 after their line's packets. Wave 2: each app's delete task.

## Open
- Blocked on #1933 editor-kernel: EK-sel (every slice).
- AS-library also waits on adopt-kernel-undo:AU-library (this lead's own feature, same block).
