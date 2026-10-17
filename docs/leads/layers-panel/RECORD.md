# layers-panel lead record

Issue: #1498 · Packet: docs/blueprints/design/features/layers-panel.md
Run: act-1a149c0c306-8ckd (before: act-1a1487bf8e3-hwdj) · Session: claude/design-shell-parity-lead-678eue · Started: 2026-10-17T06:08Z
Stage: 3 wave 1
Base: 042423165693f2f1d65d2ece90eb0d5bcb910554
Next: wave 1 resumed 12:10Z (L-3, L-7 building; the first run opened no PR for them); when they merge run the check. LP-a still waits on editor-kernel EK-tree (#1933: kernel at wave 2, EK-1 #1992 open) and design-window DW-a/DW-b (#1494)

Line lead (rule 19) over #1325 shell-parity (done), #1498 layers-panel and #1497 style-rows. One wave plan across the three.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LP-a | Rename, reorder and nest layers from the Layers panel, and Object > Arrange, each one step. | L-1, L-2, L-4, L-5 | J12 | editor-kernel EK-tree #1933 (L-1, L-2: the layer tree is a kernel concept, rule 20); design-window DW-a (L-4, L-5) and DW-b (L-4) | yes | 0 | blocked | – | – |
| LP-b | Locking a layer mid text edit keeps the typing, the Layers list scrolls 2,000 expanded rows, and a group row's own eye hides it once SuiteUI's LL-9 lands. | L-3, L-6, L-7 | P3, J12 | LP-a (L-6); design-window DW-a (L-7's P3); SuiteUI LL-9 (L-6) | no | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| L-3 | LP-b | 1 | A lock commits an open text edit first (#613); `renameNode` / `renamePage` trim the name, a same-name rename records nothing | Sources/DesignModel/DesignWorkspace.swift, Tests/DesignModelTests/DesignLockTextEditTests.swift, Tests/DesignModelTests/DesignRenameTests.swift, Tests/mutations/DesignModel.DesignWorkspace.json | DesignLockTextEditTests, DesignRenameTests + Mutate 2+/n | – | building (relaunch) |
| L-7 | LP-b | 1 | QD-S10 model budget (`layerRows`, 2,000 expanded rows on `crowd` ≤ 50 ms); P3 written skipped ("waits on design-window D0-5a") | Tests/DesignModelTests/DesignLayersBudgetTests.swift, UITests/DesignJourneyTests+PerfLayers.swift | DesignLayersBudgetTests.layerRows | – | building (relaunch) |
| L-1 | LP-a | – | `LiveOrdering` over the kernel tree: move with its refusals; arrange | Sources/DesignModel/Live/LiveOrdering.swift, Tests/DesignModelTests/DesignOrderingTests.swift, Tests/mutations/DesignModel.LiveOrdering.json | DesignOrderingTests | – | waits on EK-tree (#1933) |
| L-2 | LP-a | – | `layerDrop` and `DesignDropPosition` | Sources/DesignModel/DesignLayerToggles.swift, Tests/DesignModelTests/DesignLayerDropTests.swift | DesignLayerDropTests | – | waits on L-1 |
| L-4 | LP-a | – | Layers rows: rename, drag to reorder and nest, the empty page state, row ids, the drag check | Sources/DesignApp/DesignLayersPanel.swift, Tests/AppSnapshotTests/DesignLayersSnapshots.swift, Tests/AppSnapshotTests/DesignLayersDragTests.swift | DesignLayersSnapshots, DesignLayersDragTests | – | waits on L-1, L-2, DW-a, DW-b |
| L-5 | LP-a | – | J12; `feature-done` unless L-6 ships; closes gap #1986 | UITests/DesignJourneyTests+Layers.swift, docs/blueprints/design/features/layers-panel.wave.json | J12 | – | waits on L-4, DW-a |
| L-6 | LP-b | – | J12's group-row eye step without the skip | UITests/DesignJourneyTests+Layers.swift | J12 | – | waits on L-5, lists-and-layers LL-9 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-17 12:10Z relaunch (run act-1a149c0c306-8ckd, base 0424231 = dev = main): L-3 and L-7 had no PRs; rebuilt on branches wave/layers-panel-L-3, -L-7. EK-tree has not started (editor-kernel's EK-a is in its wave 2), DW-a not merged, so LP-a stays blocked.
- PRs target `dev` (the lane's base; it retargets `main`); builder branches are `wave/<feature>-<task>`.
- Rule 20 and the relaunch note on #1498: the layer tree and parenting are kernel concepts, so L-1 (`LiveOrdering` move and arrange) and L-2 (`layerDrop`) build on SuiteKernel's tree module (editor-kernel EK-tree, #1933) and wait for it. No Design copy. The SuiteKernel target doesn't exist on dev yet (EK-a is the kernel's first slice), so LP-a is blocked today.
- L-3 and L-7 start now: a lock that commits a text edit, name trimming and the row-build budget are Design's own, and `layerRows` and the `crowd` fixture exist. L-7's P3 journey is written skipped by name (`-DesignFixture` arrives with design-window D0-5a, rule 13).
- Filed the packet's stage-1 gap: #1986 ("Design: rename, reorder and nest layers from the panel, and Object > Arrange", p1, in-progress); L-5 closes it.
- Packet wave 1 was L-1, L-3, L-7; L-1 moved out under rule 20. Nothing else unchained.

## Open
- editor-kernel EK-tree (#1933) not started: L-1, L-2 and so LP-a wait. If the kernel's tree slice slips past this run, the supervisor decides whether L-1 may build an adapter on today's `DesignWorkspace.moveNode` instead.
- design-window DW-a / DW-b (#1494) not merged: L-4, L-5 and L-7's P3 wait.
- SuiteUI lists-and-layers LL-9 not merged: L-6 waits; J12's group-row eye step skips naming #589.
