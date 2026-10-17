# cull lead record

Issue: #1345 · Packet: docs/blueprints/library/features/cull.md
Run: act-1a145e74beb-obp4 · Session: cse_01BkDrX316MPq32KYU5agHQr · Started: 2026-10-16T18:10Z
Stage: 4 round 2
Base: 7ab292cdb1022222c00314a2b52c44c087811c46
Next: wait for the scoped library run that contains #1818 (b2f5986): J4 must pass; then the contact sheet

Loop: v2 (no `## Slices` table in the packet), with the findings queue and
the 2-round cap (started after #1302 merged at 2026-10-16T04:20Z).

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| CU-1 | 1 | `cull(_:advance:)` on `cullTargets`, one named undo step, refused change sets `cullError`, `cullHelp`, `cullChange(for:)`, `setAutoAdvance`, `dismissCullError` | Sources/LibraryModel/LibraryCulling.swift, Tests/LibraryModelTests/LibraryRatingTests.swift | LibraryRatingTests | #1541 | merged |
| CU-2 | 1 | `LiveCulling` full Auto Advance rule; `unavailable = nil` | Sources/LibraryModel/Live/LiveCulling.swift, Tests/LibraryModelTests/LibraryAutoAdvanceTests.swift | LibraryAutoAdvanceTests (live) | #1533 | merged |
| CU-6 | 1 | `MetadataInspector` stars, flag, label identifiers `library.metadata.*`; snapshots redrawn | Sources/LibraryApp/MetadataInspector.swift, Tests/AppSnapshotTests/LibraryMetadataSnapshots.swift | LibraryMetadataSnapshots | – | done before this lead (#262) |
| CU-3 | 2 | Auto Advance inside `cull`; undo never moves the loupe; cull budgets | Sources/LibraryModel/LibraryCulling.swift, Tests/LibraryModelTests/LibraryAutoAdvanceTests.swift, Tests/LibraryModelTests/LibraryCullBudgetTests.swift | LibraryAutoAdvanceTests, LibraryCullBudgetTests | #1588 | merged |
| CU-4 | 2 | inspector and menu edits go through `cull(_:advance: false)` | Sources/LibraryModel/MetadataEditing.swift, Tests/LibraryModelTests/LibraryMetadataTests.swift | LibraryMetadataTests | #1579 | merged |
| CU-5 | 3 | cull area: single keys, Metadata menu, Auto Advance checkmark, refused-change notice | Sources/LibraryApp/LibraryWindow+Cull.swift, Sources/LibraryApp/LibraryBrowser.swift (cull notice close button), Tests/AppSnapshotTests/LibraryRatingSnapshots.swift, Tests/AppSnapshotTests/LibraryAutoAdvanceSnapshots.swift | snapshots; J4 on macOS | #1598 | merged |
| CU-7 | 4 | J4 steps 1–8 (F and L); `feature-done`; cull.wave.json `status: built` | UITests/LibraryJourneyTests+Cull.swift, docs/blueprints/library/features/cull.wave.json | J4 | #1604 | merged (a5c680a) |
| CU-8 | – | P2 `testCullKeyLatency` (report-only) | UITests/LibraryJourneyTests+PerfCull.swift | P2 | | blocked: #782 open |

Wave independence: wave 1 CU-1 and CU-2 independent; wave 2 CU-3 and CU-4
independent of each other (CU-3 needs CU-1 and CU-2 merged, stacked on
LibraryCulling.swift and LibraryAutoAdvanceTests.swift; CU-4 needs CU-1's
`cull`); wave 3 CU-5 needs CU-3's Auto Advance in `cull`; wave 4 CU-7 drives
CU-5's keys and menu.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38965923292 (full, 1910bff) | macOS job red: SuiteUI TimelineStripLayoutTests (not cull); snapshots and journeys never ran; cullOneWithinBudget 12.97 ms > 10 hidden as known issue (#1587) | not measured | pending (scoped run) | #1587 | #1645 (r1-b1, merged) | no |
| 2r | 38986624933 (scoped library, 0e6f7c9) | J4 passes step 1, fails step 2 (no library.loupe.photo after the Metadata menu and Escape); other journeys green | – | – | – | #1818 (ci-3, merged) | no |
| 2r | 38984212662 (scoped library, b4b063d) | every Library journey green except J4: fails at step 1's position check (readout now ends with the cull summary, #1678) | – | – | – | #1803 (ci-2, merged) | no |
| 2r | 38981648832 (scoped library, b267d00) | snapshot test LibraryGridCellTests.anUnflaggedCellSaysItsStarsAndLabel red: seam between #1732 (label text) and #1687's test; journeys didn't run | not measured | – | – | #1774 (ci-1, merged) | no |
| 2 | 38977890145 (scoped library, a7c34b4) | snapshot test LibraryAutoAdvanceSnapshots.loupeMovesOnAfterARating red (test reads selection in the loupe after #1678), so journeys didn't run | not measured | clarity, journey, design, layout, controls, quality | #1718-#1722 (8 confirmed, 1 refuted; #1718 rerouted gap) | #1717 #1730 #1732 (all merged) | no |
| 1 | 38967059607 (scoped library, 5c1742f) | J4 red at step 1 (#1654: test reads a menu check mark XCUITest can't see; screen shows ✓ Auto Advance); testRateASelectedPhoto and testLoupeStepsAndReturnsToTheGrid green | identifier 2 / 12, unnamed 0 / 1 (under) | clarity, journey, design, layout, controls, quality | #1654, #1661, #1663-#1669 (12 confirmed, 8 refuted) | #1677 #1678 #1683 #1684 #1687 #1688 #1692 (all merged) | no |

## Decisions
- Base and PR target are `dev`, not `main` as the Belt brief says: CLAUDE.md
  forbids branching from or targeting `main`; the brief's main HEAD 2e0f7df
  was verified and is an ancestor of dev 132d910.
- v2 loop: the packet has no `## Slices` table and cull.wave.json no `slices`.
- CU-8 does not run: it waits on #782 (S-L8, open). The packet makes CU-8
  conditional ("CU-8 only when it runs"), so CU-7 carries `feature-done`.
- #779 has merged, so J4 step 6 reads cell values directly.
- CU-7 also sets cull.wave.json `"status": "built"` and `"feature_issue": 1345`
  (the feature-done PR marks the feature built in its own data, lead.md).
- CU-6 dropped: MetadataInspector's stars, flag and label already carry
  `library.metadata.*` ids (MetadataInspectorID, #262) and call the window's
  closures; CU-4 reroutes those closures' Model methods through `cull`.
- The PR footer "Generated by Claude Code" is re-added by the GitHub proxy on
  every body write and can't be removed from here; the lane strips it from
  the squash commit (CLAUDE.md).
- CU-2 also touched LibraryServicesTests.swift (its stub count followed
  `LiveCulling.unavailable = nil`); accepted as the task's test.
- CU-5 started beside wave 2 (base 7ab292c): it compiles against CU-1's
  `cull`, `cullHelp` and `setAutoAdvance` alone; only its Auto Advance
  snapshot needs CU-3, and snapshots run on macOS after both merge.
- CU-5 may edit LibraryBrowser.swift for the cull notice's close button (the
  packet's notice is dismissible; LibraryNoticeRow has none). Its owners
  (spine closed, import built, filters-collections not started) are idle.
- CU-7 built beside wave 3: a UI test reads ids and menu titles, so it doesn't
  need CU-5's code to compile. Its PR opens unlabelled; the lead adds
  fast-lane and feature-done after CU-3/4/5 merge, so it merges last.
- After round 2, a red run caused by the feature's own fixes (a test seam)
  is CI work, not a third critic round: fixed as ci-1, no new review.
- PRs open through the REST API (`gh api .../pulls`): GraphQL, which
  `gh pr create` uses, answers 403 here.

## Open
- Rerouted from round 1: #1662 (grid reject mark: thumbnails owns it per
  the packet, now `gap`), #1670 and #1671 (SuiteUI: `needs-ui`, line:suiteui).
  #1664 and #1669 narrowed to Library files. #1664's VoiceOver "Flagged"
  label is SuiteUI's (#1183). #1684 rewords the fake refusal; the packet's
  copies of the old string stay stale (docs, not code).
- Rerouted from round 2: #1718 (Favorites naming: collections' contract, `gap`).
- Full run 38965923292 reports success while its macOS job failed in
  unit tests (TimelineStripLayoutTests, SuiteUI), so no journey ran there;
  cull's done check waits on a run whose journeys ran. Same on 38967787160
  (8e0a526). Reported on #1480 (timeline lead, SuiteUI).
- CU-8 / P2 waits on #782.
