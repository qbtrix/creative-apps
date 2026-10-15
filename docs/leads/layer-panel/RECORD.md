# layer-panel lead record

Issue: #1038 · Packet: docs/blueprints/halo/features/layer-panel.md
Run: act-1a13e9a2019-lau7 · Session: session_01NGHcmJbQja1RSYvcMZR3TD · Started: 2026-10-15T08:07Z
Stage: 3 wave 3
Base: a5182b48a42c17aaf8862bf3bd053250c64d7014
Next: wait for LP-4's PR (branch layer-panel/lp-4) to merge and for the dev CI run containing #1045/#1047/LP-4; then round 1 of the Anatomy loop

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| LP-1 | 1 | delete, rename, move (+ forward/backward, `moveTarget`), duplicate: each one named `edit` step; delete un-parents through `keying.setParent(nil, …)` with the `.notBuilt` fallback | `Sources/HaloModel/HaloLayerEdits.swift`, `Tests/HaloModelTests/HaloLayerEditsTests.swift` | `HaloLayerEditsTests` | #1041 | merged (a2313a5) |
| LP-2 | 2 | Layer commands' availability and routes; Rename Layer prompt from `request`; edit budgets | `Sources/HaloModel/Availability/HaloAvailability+Layers.swift`, `Sources/HaloApp/HaloWindow+Layers.swift`, `Tests/HaloModelTests/HaloLayerAvailabilityTests.swift`, `Tests/HaloModelTests/HaloLayerEditsBudgetTests.swift` | `HaloLayerAvailabilityTests`, `HaloLayerEditsBudgetTests` | #1045 | merged |
| LP-3 | 2 | `HaloLayerList` as a `List` of `SidebarRow`s: select, rename, `.onMove`, `.onDeleteCommand`, refusal caption, empty text; snapshots | `Sources/HaloApp/HaloLayerList.swift`, `Tests/AppSnapshotTests/HaloLayersSnapshots.swift` | snapshots `halo-layer-list{,-refused,-empty}-{light,dark}.png` | #1047 | merged |
| LP-4 | 3 | H-J9 `testLayerHousekeeping`, eight steps; `feature-done` | `UITests/HaloJourneyTests+Layers.swift` | H-J9 on the dev CI run | #1052 | opened (fast-lane only, no feature-done) |

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
- LP-1 (#1041): Position X 560.0 at 12 not asserted: Ball's parent is set directly, so un-parenting keeps its world place (x = 560 + Rig's offset); the test asserts the world anchor point within 1e-6, which is the contract.
- LP-3 keeps W0's row look (HaloLayerListTests pixel checks) with a chrome-less plain `List`, since `.onMove` needs a List.
- Wave 2 has 2 independent tasks: two worktree subagents started together, not the build-wave workflow.
- LP-2 (#1045): `.selectLayer(nil)` stays off with "A layer stays selected until you pick another." (no Model method clears the selection); Rename is the alert's default button (Return renames).
- The GitHub MCP appends an attribution footer to PR bodies; the lead strips it with update_pull_request after each PR opens.
- `feature-done` moves from LP-4 to the feature's final PR (an Anatomy fix or the packet status line, which closes #770): LP-2/LP-3's SwiftUI first compiles on the dev macOS run, and any fix must land before the feature-done CI run.
- LP-3 (#1047): a refused layer rename also shows in W0's viewer caption (`halo.refusal`), since HaloViewer shows any non-inspector refusal; candidate for the critic round.

## Open
- dev is red before this feature (#763, run 38704216123 on 92db316): Halo `testLayoutAtWidths` (timeline track under the sidebar at 880 pt; fixed by SuiteUI #1040, waiting on a human Mac-Check) and SuiteUI `testGalleryOpensEveryPage` (Hide Sidebar identifier). Neither is in this feature's files; the done check's green dev run needs #1040 merged.
