# shell-parity lead record

Issue: #1325 · Packet: docs/blueprints/design/features/shell-parity.md
Run: act-1a14478b134-5to5 · Session: claude/design-shell-parity-2jr7z3 · Started: 2026-10-16T12:00Z
Stage: 3 wave 4
Base: 4c178c9a0a0405bd43275d3a66ba7dbfafba1a72
Next: wave 4 = #1404 build fix (DP-a round 1), DP-b round 1 fixers sp/r1-1443, sp/r1-1444; then the scoped run app=design containing them, DP-a review round 2 and the DP-b critic panel; DS-5 feature-done after

## Slices
| slice | behavior | tasks | journeys | waits on | rounds | state | run |
|---|---|---|---|---|---|---|---|
| DP-a | The toolbar's eight commands each act or say why, and Add Page and Delete Page sit in a row under the pages. | DS-1, DS-2 | J3 | editor-in-window APIs (on dev) | 1 | merged (fix round 1: #1403, #1408 merged; #1404 fixing build) | 38906785154 green, contains #1329 |
| DP-b | Design opens in the suite window with pages and layers in the sidebar, Properties in the inspector and the floating tool box over the canvas, in light and dark. | DS-3, DS-4 | J0, DS-J1..DS-J5 | DP-a (DS-3) | 1 | merged (fix round 1) | 38917492060 red: J3 #1443, shell journeys #1444 (switcher waits on #1337) |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DS-1 | DP-a | 1 | DesignToolbarItem: eight commands, titles, symbols, identifiers, reasons | Sources/DesignModel/DesignToolbarItems.swift, Tests/DesignModelTests/DesignToolbarItemsTests.swift, Tests/mutations/DesignModel.DesignToolbarItems.json | DesignToolbarItemsTests + Mutate 6/6 | #1335 | merged |
| DS-2 | DP-a | 1 | Page actions under Pages become a SidebarActionRow | Sources/DesignApp/DesignLayersPanel.swift, Tests/AppSnapshotTests/DesignLayersSnapshots.swift, UITests/DesignJourneyTests.swift | core journey asserts design.page.add/delete; DesignLayersSnapshots | #1329 | merged |
| DS-3 | DP-b | 2 | DesignEditor on SuiteWindow + EditorDetail, floating palette; DesignTopBar/DesignPanel tabs go | DesignEditor, DesignPanel, DesignIntent, DesignWindow, DesignApp, DesignJourneyTests, 3 snapshot files | every Design journey on the scoped run | #1391 | merged |
| DS-4 | DP-b | 1 | Shell journey steps 1-5 with geometry, merged skipped ("waits on DS-3") | UITests/DesignJourneyTests+Shell.swift | DesignJourneyTests+Shell on the scoped run, once DS-3 enables it | #1330 | merged |
| DS-5 | DP-b | 3 | feature-done: wave.json status built + feature issue | docs/blueprints/design/features/shell-parity.wave.json | scripts/ci renders waves | – | waits DS-3 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| DP-a | 38906785154 | b2e5453c | clarity, journey, design, layout, controls, oracle | #1385 (major), #1386, #1387 | 0 |
| DP-b | 38917492060 (CI lens: failed journeys) | fb72b7e5 | journey (CI) | #1443 (blocker), #1444 | 0 |

## Decisions
- Wave 1: DS-1 and DS-2 independent (disjoint files). Wave 2: DS-3 waits on DS-1 (uses DesignToolbarItem) and DS-2 (same UITests/DesignJourneyTests.swift and DesignLayersSnapshots.swift). DS-4 moved to wave 1 under contract rule 13 (acceptance journey before code): it merges with `throw XCTSkip("waits on DS-3")` and DS-3 removes the skips (DS-3 also owns UITests/DesignJourneyTests+Shell.swift for that). The feature-done label moves to a small DS-5 (wave.json status) after DS-3.
- DP-a's wait on editor-in-window (#1079): #1079 is open (needs-human), but every API this feature uses is on dev at the base (SuiteWindow sidebar:/subtitle/documentActions/inspectorWidth, SuiteWindowSizer, EditorDetail(+Layout), SidebarActionRow, AppSwitcher, expectEditorWindow, expectShellGeometry). The issue says "Depends on: none", so the wait is met for code; DS-4's geometry may still hit #933-type overflow, which DS-4 records.
- Wave 1 has 2 tasks: one worktree subagent each, started together (lead.md stage 3).
- PRs target dev (CLAUDE.md; main = dev at the base and the lane retargets main to dev).
- Builder branches are sp/<task> (git can't hold lead/shell-parity/<task> beside lead/shell-parity).
- Fixers are briefed directly (Agent per finding), not via fix-batch.js: its branch names lead/<feature>/<id> collide with lead/shell-parity and gh is unauthenticated here.
- DS-5 (feature-done) waits for DP-b's first review so the full run it triggers shows the reviewed shell.
- DS-4 carries feature-done and sets the wave.json status to built.

## Open
- dev-red #1393: full run 38915938965 red on Library tests only (LibraryImportBudgetTests timing, LibraryImportSnapshots.progressRowShowsAfterItsDelay from #1382); not Design's.
- Findings #1443, #1444 (DP-b, from scoped run 38917492060), fix round 1 in wave 4: #1443 -> PR #1446 (root cause: design.properties sat on the scroll view that SuiteWindow turns into suite.inspector). DP-b's shell journeys also wait on #1337 (EW-8, the app switcher in SuiteWindow).
- DS-3 note: the shell journey asserts suite.switcher, which SuiteWindow shows only after editor-in-window EW-8 (#1079 open); DP-b's journeys may stay red until EW-8 lands.
- Finding issues #1385, #1386, #1387 (DP-a), fix round 1 in wave 3.
- #1079 editor-in-window still open (needs-human); not blocking code.
