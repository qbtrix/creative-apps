# layer-panel lead record

Issue: #1038 · Packet: docs/blueprints/halo/features/layer-panel.md
Run: act-1a13e9a2019-lau7 · Session: session_01NGHcmJbQja1RSYvcMZR3TD · Started: 2026-10-15T08:07Z
Stage: 4 round 2
Base: e8de2ff5d8ed3515af321c805cc2bebab17050a4
Next: wait for the r2-menu-wait PR (feature-done) to merge and its dispatched dev run; read H-J9 steps 3-8 and run the same five-lens panel on its screens (round 3)

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| LP-1 | 1 | delete, rename, move (+ forward/backward, `moveTarget`), duplicate: each one named `edit` step; delete un-parents through `keying.setParent(nil, …)` with the `.notBuilt` fallback | `Sources/HaloModel/HaloLayerEdits.swift`, `Tests/HaloModelTests/HaloLayerEditsTests.swift` | `HaloLayerEditsTests` | #1041 | merged (a2313a5) |
| LP-2 | 2 | Layer commands' availability and routes; Rename Layer prompt from `request`; edit budgets | `Sources/HaloModel/Availability/HaloAvailability+Layers.swift`, `Sources/HaloApp/HaloWindow+Layers.swift`, `Tests/HaloModelTests/HaloLayerAvailabilityTests.swift`, `Tests/HaloModelTests/HaloLayerEditsBudgetTests.swift` | `HaloLayerAvailabilityTests`, `HaloLayerEditsBudgetTests` | #1045 | merged |
| LP-3 | 2 | `HaloLayerList` as a `List` of `SidebarRow`s: select, rename, `.onMove`, `.onDeleteCommand`, refusal caption, empty text; snapshots | `Sources/HaloApp/HaloLayerList.swift`, `Tests/AppSnapshotTests/HaloLayersSnapshots.swift` | snapshots `halo-layer-list{,-refused,-empty}-{light,dark}.png` | #1047 | merged |
| LP-4 | 3 | H-J9 `testLayerHousekeeping`, eight steps; `feature-done` | `UITests/HaloJourneyTests+Layers.swift` | H-J9 on the dev CI run | #1052 | merged (e8de2ff) |

Journeys: H-J9 (8 steps, packet "Journey steps"). Quality bars: QB-F1 no dead controls, QB-F3 one named step, QB-F4 keyboard parity, HB-9 edit budget (≤ 20 ms debug CI), audit zero new.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38708263577 (f5bd765) | red: macOS scripts/ci, HaloLayerListTests (4 expectations: List insets rows, icon at 21 pt, tint off both edges); journeys skipped | not run | – (blocker found before the panel) | list inset (LP-3) | #1058 | no |
| 1b | 38711122431 (2fc9b59) | red: H-J9 step 3, double-click opens no rename field (row is a Button); W0 Halo journeys pass but testLayoutAtWidths (#1040); SuiteUI gallery (#763) | halo identifier 1 (10), contrast 0 (2), offscreen 0 (8), unnamed 0 (5): under | clarity, journey, design, layout, controls | row rename (LP-3); panel 11 confirmed (4 major): selected icon 2.5:1 in Dark, journey shots under a fading Edit menu, row help, null help, row font, empty inset (ours, batch 3); (#38) caption, inspector scroll (not ours); back to List (rejected) | #1070 (merged 3894890), batch 3 #1078 (merged 09:49) | no |
| 2 | 38721434364 (c7e5c17) | red: macOS scripts/ci green (HaloLayerListTests pass with the round 1 look); H-J9 stops at step 2: #1078's expectClosed asserts app.menus gone after a menu choice and it never is. Other Halo reds not ours: Files testSaveAndReopen, History testUndoRedoEveryEdit (inspector 192 pt), testEveryControlActsOrSaysWhy (transport.end), testLayoutAtWidths (#1040); SuiteUI gallery (#763) | not read (no new feature screens) | panel deferred to the run with H-J9 screens | menu wait (#1078) | #1104 (feature-done, merged 11:08) | no |

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
- Round 1 fix: drop the List (macOS insets rows even with zero row insets) and reorder with `.draggable`/`.dropDestination` on W0's stack, which passed HaloLayerListTests; dropping on row i moves to index i.
- Rejected round 1 panel finding "go back to a system List(selection:)": the macOS run proved List insets rows (38708263577); W0's stack is what passes HaloLayerListTests.
- Skipped minor: re-hosting the halo-layer-list snapshots inside an InspectorSection (W0's snapshot shape; HaloLayerListTests draws the list alone too).
- The lane runs main's scripts/fast-lane.sh (ee57a15), which dispatches CI only after a feature-done merge (the UI and 10-merge rules are dev-only, and main is held while dev is red). So each round's PR carries feature-done to get its CI run; #1092 (packet status line, merged 10:39) is the first.

## Open
- Panel finding, not this feature's files: the selected layer's inspector shows "Properties arrive with the layer inspector (#38)." (HaloLayerInspector.swift, W0's placeholder that layer-keys #38 replaces whole). File as gap at finish if still on dev.
- Panel finding, not this feature's files: the inspector column (HaloCompositionInspector.swift) may not scroll, so many layers would fall off the window. File as gap at finish.
- dev is red before this feature (#763, run 38704216123 on 92db316): Halo `testLayoutAtWidths` (timeline track under the sidebar at 880 pt; fixed by SuiteUI #1040, waiting on a human Mac-Check) and SuiteUI `testGalleryOpensEveryPage` (Hide Sidebar identifier). Neither is in this feature's files; the done check's green dev run needs #1040 merged.
