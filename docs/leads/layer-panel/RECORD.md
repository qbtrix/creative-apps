# layer-panel lead record

Issue: #1038 · Packet: docs/blueprints/halo/features/layer-panel.md
Run: act-1a13e9a2019-lau7 · Session: session_01NGHcmJbQja1RSYvcMZR3TD · Started: 2026-10-15T08:07Z
Stage: 3 wave 1
Base: 1dcd1a64507a652233eaa21836855530007eb1bb
Next: wait for LP-1's PR to merge, then start wave 2 (LP-2, LP-3) on the new origin/dev

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| LP-1 | 1 | delete, rename, move (+ forward/backward, `moveTarget`), duplicate: each one named `edit` step; delete un-parents through `keying.setParent(nil, …)` with the `.notBuilt` fallback | `Sources/HaloModel/HaloLayerEdits.swift`, `Tests/HaloModelTests/HaloLayerEditsTests.swift` | `HaloLayerEditsTests` | – | building |
| LP-2 | 2 | Layer commands' availability and routes; Rename Layer prompt from `request`; edit budgets | `Sources/HaloModel/Availability/HaloAvailability+Layers.swift`, `Sources/HaloApp/HaloWindow+Layers.swift`, `Tests/HaloModelTests/HaloLayerAvailabilityTests.swift`, `Tests/HaloModelTests/HaloLayerEditsBudgetTests.swift` | `HaloLayerAvailabilityTests`, `HaloLayerEditsBudgetTests` | – | waits on LP-1 |
| LP-3 | 2 | `HaloLayerList` as a `List` of `SidebarRow`s: select, rename, `.onMove`, `.onDeleteCommand`, refusal caption, empty text; snapshots | `Sources/HaloApp/HaloLayerList.swift`, `Tests/AppSnapshotTests/HaloLayersSnapshots.swift` | snapshots `halo-layer-list{,-refused,-empty}-{light,dark}.png` | – | waits on LP-1 |
| LP-4 | 3 | H-J9 `testLayerHousekeeping`, eight steps; `feature-done` | `UITests/HaloJourneyTests+Layers.swift` | H-J9 on the dev CI run | – | waits on LP-2, LP-3 |

Journeys: H-J9 (8 steps, packet "Journey steps"). Quality bars: QB-F1 no dead controls, QB-F3 one named step, QB-F4 keyboard parity, HB-9 edit budget (≤ 20 ms debug CI), audit zero new.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Identifiers keep W0's shipped `halo.layer.*` prefix (`halo.layer.row.<id>`, `halo.layer.empty`, `halo.layer.new`; W0's journey reads `halo.layer.row.comp-1-layer-2`), so the packet's `halo.layers.list/row/refusal/empty` become `halo.layer.list/row/refusal/empty`.
- Builder branches are `layer-panel/<task id>`: `lead/layer-panel/<id>` can't coexist with the `lead/layer-panel` ref.
- Waves as the packet has them: LP-2 and LP-3 each call LP-1's methods (need its merged code); LP-4's journey needs LP-2's routes and LP-3's list. #777 and #333 are both closed.
- Wave 1 has one task, so one worktree subagent rather than the build-wave workflow.
- The container had no Swift; ran the repo's `scripts/cloud-setup.sh` to install the pinned 6.3.3 toolchain for the gate.

## Open
- none
