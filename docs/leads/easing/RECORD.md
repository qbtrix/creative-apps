# easing lead record

Issue: #1333 · Packet: docs/blueprints/halo/features/easing.md
Run: act-1a1448a5fbe-p22s · Session: session_01Fpq7bUwf2TjhThXdtGKn4r · Started: 2026-10-16T11:48Z
Stage: 4 round 1
Base: e464ecab9b0e11b9cfc27851181beafdb8fee424
Next: wait for scoped halo run 38917497685 (head fb72b7e, contains #1389); then Anatomy round 1 on it (full runs 38914550143 cancelled, 38915938965 red on Library only, dev-red #1393)

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

## Decisions
- Packet has no `## Slices` table: v2 loop. Started after #1302 merged (2026-10-16T04:20Z), so findings queue (rule 10) and round cap of 2 (rule 11) apply.
- PRs target `dev`, not `main`: CLAUDE.md and lead.md say never target main, and the lane retargets fast-lane PRs on main to dev anyway. Brief's main HEAD 9e3c5f8 verified; dev = main + #1327.
- Builder branches are `lead/easing-<id>`: `lead/easing/<id>` can't coexist with the `lead/easing` ref.
- Container had no Swift; installed the pinned toolchain with `scripts/cloud-setup.sh` before wave 1.
- The PR API appends a Claude Code footer to bodies; the lane strips it from the squash commit (#1339 to #1343 merged clean), so builders don't fight it.
- #1352 (EZ-5) also edits Tests/HaloModelTests/HaloTimelineHelpTests.swift: it asserted the W0 easing stub help, which EZ-5 replaces.
- Rules 13 and 14 (check first, mutations) don't apply: v2 packet.

## Open
- Ask the supervisor to add HaloModelTests.HaloEasingBudgetTests to Tests/perf-suites.txt (#1363 body).
- Full run 38915938965 red only on LibraryImportBudgetTests (Linux) and LibraryImportSnapshots.progressRowShowsAfterItsDelay (macOS): not easing, tracked by dev-red #1393. Its macOS job stopped before journeys.
- #771 (key shapes, selected-keys set) not blocking: plain diamonds.
