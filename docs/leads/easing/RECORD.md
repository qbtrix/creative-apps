# easing lead record

Issue: #1333 · Packet: docs/blueprints/halo/features/easing.md
Run: act-1a1448a5fbe-p22s · Session: session_01Fpq7bUwf2TjhThXdtGKn4r · Started: 2026-10-16T11:48Z
Stage: 4 round 2
Base: e464ecab9b0e11b9cfc27851181beafdb8fee424
Next: fix round 2 (the last; fix-batch on #1416 #1417 #1422 #1423 #1424 #1450 #1453 #1454 #1455) merges; then the final review on a scoped halo run that reaches the journeys; open findings then become gap; contact sheet

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| EZ-1 | 1 | `LiveKeyEasing` over FlareCore `Easing` through shared `HaloEasingRules` (finite check, handle x clamped 0...1); `FakeKeyEasing` thin wrapper; contract suite over `[fake, live]` | Sources/HaloModel/Live/HaloEasingRules.swift, Sources/HaloModel/Live/LiveKeyEasing.swift, Sources/HaloModel/Fakes/FakeKeyEasing.swift, Tests/HaloModelTests/KeyEasingContractTests.swift | KeyEasingContractTests | #1339 | merged |
| EZ-2 | 1 | `HaloKeySegment`, `HaloEasingHandle`, `keySegments`, `pickedSegment`, `pickedPreset`, `selectKey`, `selectLaneKeys`, `clearKeySelection`; none records a step | Sources/HaloModel/HaloKeySelection.swift, Tests/HaloModelTests/HaloKeySelectionTests.swift | HaloKeySelectionTests | #1341 | merged |
| EZ-7 | 1 | `HaloTimelineView` slot: diamond click sends `.selectLaneKeys`, context menu of the five presets for the picked keys, disabled with help | Sources/HaloApp/HaloTimelineView.swift | macOS build; H-J7 step 7 (EZ-8) | #1343 | merged |
| EZ-3 | 2 | `setEasing` one "Keyframe Easing" step; `setCustomEasing`, `moveEasingHandle`, `easingHandles`, `easingCurve`; HF-4; Model journey | Sources/HaloModel/HaloKeySelection.swift, Tests/HaloModelTests/HaloEasingTests.swift | HaloEasingTests | #1351 | merged |
| EZ-5 | 2 | `HaloAvailability+Easing.swift` turns the five Keyframe Easing commands on when a key is picked | Sources/HaloModel/Availability/HaloAvailability+Easing.swift, Tests/HaloModelTests/HaloEasingAvailabilityTests.swift | HaloEasingAvailabilityTests | #1352 | merged |
| EZ-4 | 3 | HB-7 budget | Tests/HaloModelTests/HaloEasingBudgetTests.swift | HaloEasingBudgetTests.easingStep | #1363 | merged |
| EZ-6 | 3 | `HaloEasingInspector` EASING group + `HaloWindow+Easing` routes | Sources/HaloApp/HaloEasingInspector.swift, Sources/HaloApp/HaloWindow+Easing.swift, Tests/AppSnapshotTests/HaloEasingSnapshots.swift | HaloEasingSnapshots (6 PNGs) | #1364 | merged |
| EZ-8 | 4 | H-J7 `testEaseKeys` steps 1 to 8 on `-HaloSample keyed`; `feature-done` | UITests/HaloJourneyTests+Easing.swift | H-J7 on dev CI | #1389 | merged |

Wave 1: EZ-1, EZ-2, EZ-7 independent (disjoint files; EZ-2 reads tracks and W0's `selectedKeys` directly; EZ-7 only sends FD-11 commands).
Wave 2: EZ-3 waits on EZ-1 (`.live` runs need `LiveKeyEasing`) and EZ-2 (`pickedKeys`, `pickedSegment`, same file). EZ-5 waits on EZ-1 (`unavailableHelp == nil`) and EZ-2 (`pickedKeys`). EZ-3 and EZ-5 independent of each other.
Wave 3: EZ-4 waits on EZ-3 (budget of `setEasing`). EZ-6 waits on EZ-3 (calls its methods) and EZ-5 (chips read real availability). Independent of each other.
Wave 4: EZ-8 waits on EZ-6 and EZ-7 (drives what they put on screen); #333 closed.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38917497685 (scoped halo, fb72b7e) | red: H-J7 step 3 (#1411); testLayerHousekeeping contrast 3 > 2 (#1412); testDragLayerToKeyPosition and testEveryControlActsOrSaysWhy are full-run quarantined (#1283, #1035), not easing | contrast 3 vs 2 | clarity, journey, design, layout, controls, audit | #1411 to #1424 (14: 1 blocker, 7 major, 6 minor; 1 refuted) | #1429 (r-b1: #1411-#1415, #1418-#1421) | no |
| 2 | 38930143233 (scoped halo, 4fb505e) | red: HaloEasingSnapshots.segmentTitlesFitOneLine 126 > 124 pt (#1450); ui-test skipped, so no journey screens | n/a (journeys skipped) | same 6 | #1450, #1453-#1455 (4 new: 1 blocker, 1 major, 2 minor; 1 refuted) + #1416 #1417 #1422 #1423 #1424 | fix round 2 | no |

## Decisions
- Packet has no `## Slices` table: v2 loop. Started after #1302 merged (2026-10-16T04:20Z), so findings queue (rule 10) and round cap of 2 (rule 11) apply.
- PRs target `dev`, not `main`: CLAUDE.md and lead.md say never target main, and the lane retargets fast-lane PRs on main to dev anyway. Brief's main HEAD 9e3c5f8 verified; dev = main + #1327.
- Builder branches are `lead/easing-<id>`: `lead/easing/<id>` can't coexist with the `lead/easing` ref.
- Container had no Swift; installed the pinned toolchain with `scripts/cloud-setup.sh` before wave 1.
- The PR API appends a Claude Code footer to bodies; the lane strips it from the squash commit (#1339 to #1343 merged clean), so builders don't fight it.
- #1352 (EZ-5) also edits Tests/HaloModelTests/HaloTimelineHelpTests.swift: it asserted the W0 easing stub help, which EZ-5 replaces.
- The issue and PR APIs append a Claude Code footer to every body and re-add it on edit; it can't be removed from here.
- Round 2 reviews the snapshots only: run 38930143233 skipped the journeys after #1450, and the last fix round should still catch what #1429 changed visibly.
- Rules 13 and 14 (check first, mutations) don't apply: v2 packet.

## Open
- Ask the supervisor to add HaloModelTests.HaloEasingBudgetTests to Tests/perf-suites.txt (#1363 body).
- Full run 38915938965 red only on LibraryImportBudgetTests (Linux) and LibraryImportSnapshots.progressRowShowsAfterItsDelay (macOS): not easing, tracked by dev-red #1393. Its macOS job stopped before journeys.
- Round 1 fix batch r-b1 takes #1411-#1415, #1418-#1421; the minors #1416, #1417, #1422, #1423, #1424 wait for the next fix wave (round 2).
- #1426 (needs-ui, line:suiteui): ChoiceChips column count and wrapping, and a non-lazy preset grid; Halo uses three PresetGrids meanwhile (#1429).
- #1429 makes EASING start collapsed on a layer with no segments (#1412) and updates the packet's Screens and states and EZ-6 rows to match.
- #771 (key shapes, selected-keys set) not blocking: plain diamonds.
