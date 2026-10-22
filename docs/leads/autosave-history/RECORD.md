# autosave-history lead record

Issue: #3444 · Packet: docs/blueprints/suiteui/features/autosave-history.md
Run: act-1a1630f0f74-0l2p (prior: act-1a157ad4600-c6w5) · Started: 2026-10-20T05:01:16Z · Resumed: 2026-10-22T10:03:39Z
Stage: 3 wave 3
Base: 02d2e5be85489fdeb62bd479a819456cf13c568e
Next: AH-z slice PR (AH-9 fake HistoryJumping + RJ-X31, AH-10 status built, feature-done); then Belt-Slice-Done AH-z on a green Linux run that contains it, then Belt-Contact-Sheet.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AH-a | The kernel's schedule and history commands and the recovery folder are declared as stubs, the gallery's history-panel page is in the index, and the checks are written, disabled. | AH-1, AH-2 | SJ0 | gradient-fill:GF-a (AH-1) | true | 0 | done | 39756689216 | wanted |
| AH-u | On the gallery page the panel lists the states, marks the current one, dims the undone ones and jumps on a click or arrows and Return, every row identified, within the render budget. | AH-3, AH-4 | HJ1 | AH-a (AH-3) | true | 0 | done | 39448853502 | wanted |
| AH-m | The schedule writes once per edit a delay after it and deletes a write a save overtook, a jump lands on its index without recording a step, and the folder keeps the newest recovery files and drops damaged ones. | AH-5, AH-6, AH-7 | KJ-history | AH-a (AH-5, AH-6, AH-7) | false | 0 | done | 39424989659 | – |
| AH-z | The modifier autosaves and offers recovery on the live schedule and folder, the gallery jumps on a live history, the fake app jumps so RJ-X31 runs on the CLI, and the feature is built. | AH-8, AH-9, AH-10 | HJ1, KJ-history | AH-u (AH-8); AH-m (AH-8, AH-9); gradient-fill:GF-z (AH-9) | true | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AH-1 | AH-a | 1 | see packet task table (waits: –) | Sources/SuiteKernel/Session/AutosaveSchedule.swift, Sources/SuiteKernel/History/HistoryCommands.swift, Sources/SuiteModel/Store/RecoveryFolder.swift, Tests/SuiteKernelTests/AutosaveScheduleTests.swift, Tests/SuiteKernelTests/HistoryCommandsTests.swift, Tests/SuiteModelTests/RecoveryFolderTests.swift, Tests/canonical-concepts.txt, Tests/canonical-baseline.txt, docs/c4/parts/creative-apps/suite-kernel/kernel-history.json, docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json, docs/c4/parts/creative-apps/suite-model/suite-store.json | packet acceptance row | #3543 | merged (dev 854a3b5, 07:11Z) |
| AH-2 | AH-a | 2 | see packet task table (waits: AH-1) | Sources/SuiteUI/HistoryPanel.swift, Sources/SuiteUI/AutosaveRecovery.swift, Sources/SuiteUI/Gallery/GalleryHistoryPanel.swift, Sources/SuiteUI/Gallery/GalleryLists.swift, UITests/SuiteJourneyTests+History.swift | packet acceptance row | #3568 | merged 10:41 (lane batch, Linux run 39408184084) |
| AH-3 | AH-u | – | see packet task table (waits: AH-2) | Sources/SuiteUI/HistoryPanel.swift, Tests/SuiteUITests/HistoryPanelTests.swift | packet acceptance row | #3596 | merged 13:02 (lane batch 39425106447) |
| AH-4 | AH-u | – | see packet task table (waits: AH-3) | Tests/AppSnapshotTests/SuiteHistoryPanelSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHistoryPanelTests.swift, UITests/SuiteJourneyTests+History.swift | packet acceptance row | #3607 | merged 15:12, 27b6733 |
| AH-5 | AH-m | 2 | see packet task table (waits: AH-1) | Sources/SuiteKernel/Session/AutosaveSchedule.swift, Tests/SuiteKernelTests/AutosaveScheduleTests.swift, Tests/mutations/SuiteKernel.AutosaveSchedule.json | packet acceptance row | #3576 | merged 10:23 (lane batch, Linux run 39405967473) |
| AH-6 | AH-m | 2 | see packet task table (waits: AH-1) | Sources/SuiteKernel/History/HistoryCommands.swift, Tests/SuiteKernelTests/HistoryCommandsTests.swift, Tests/mutations/SuiteKernel.HistoryCommands.json | packet acceptance row | #3573 | merged 12:42 (squash 3e010e3; lane batch Linux run 39422459237) |
| AH-7 | AH-m | 2 | see packet task table (waits: AH-1) | Sources/SuiteModel/Store/RecoveryFolder.swift, Tests/SuiteModelTests/RecoveryFolderTests.swift, Tests/mutations/SuiteModel.RecoveryFolder.json | packet acceptance row | #3572 | merged 10:23 (lane batch, Linux run 39405967473) |
| AH-8 | AH-z | – | see packet task table (waits: AH-4, AH-5, AH-6, AH-7) | Sources/SuiteUI/AutosaveRecovery.swift, Sources/SuiteUI/Gallery/GalleryHistoryPanel.swift, Tests/SuiteUITests/AutosaveDriverTests.swift | packet acceptance row | #3629 | merged 2026-10-20 21:15, 0506808 |
| AH-9 | AH-z | – | see packet task table (waits: AH-6) | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeHistoryTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/history-jump/history-jump.jobs.json, Tests/RealJobs/fake/history-jump/input/one.fake | packet acceptance row | – | building (wave 3, with AH-10 folded in) |
| AH-10 | AH-z | – | see packet task table (waits: AH-8, AH-9) | docs/c4/parts/creative-apps/suite-kernel/kernel-history.json, docs/blueprints/suiteui/features/autosave-history.wave.json | packet acceptance row | – | building (in the AH-9 PR) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target is `dev` (CLAUDE.md, lead.md), not the brief's "base main": main b3011ab is an ancestor of dev, and the packets exist only on dev (#3426, #3432).
- v3 loop: the packet has a `## Slices` table; fix rounds capped at 2 per slice (contract rule 11).
- The contract slice waits on gradient-fill:GF-a (#3421 open, GF-2 not opened); a cross-feature wait is met only once its tasks merge (rule 12), so no task starts on an unmerged branch.
- GF-1 (#3421) merged on dev 9a14677. The packets give each gradient-fill:GF-a wait a per-task reason GF-1 alone meets (AH-1, PL-1: Tests/canonical-concepts.txt; SS-1: the Fill/ module and FillColor); GF-2 shares no file with them, so AH-1, SS-1 and PL-1 count GF-a's wait met. PL-2 still waits on GF-2 (SuiteGallery.swift). PL-1 runs after AH-1 (both edit canonical-concepts.txt). A slice is not one PR: AH-a is ~530 lines, over the 400 cap, so each task is its own PR and the first carries the disabled acceptance tests.
- AH-1 notes (#3543): branch lead/autosave-history-AH-1 (the lead/autosave-history ref blocks a lead/autosave-history/ path); RecoveryFolder.notBuilt is SuiteError.notAvailable (SuiteError has no notBuilt); history.read titled "Read History" (typed specs need a title); public inits on HistoryListing and RecoveryItem; Allow-Dup line for the Autosave concept grandfathering FlareAutosave and PhotoAutosave.

- AH-2 (#3568): the REST PR create appended an attribution footer; the GitHub MCP update_pull_request removed it (a REST PATCH re-adds it). Builders now strip it through MCP.
- AH-3 builds on #3568: rows get ids `suite.history.row.<n>` and selection, undone rows' labels end in "not applied", and a row click calls the stored `onJump` (the journey in UITests/SuiteJourneyTests+History.swift expects these).

- Gate under load: with 5 builders compiling on 4 cores (load 14-43), other lines' wall-clock budget tests (Design, Library, Halo) fail the gate. These suites pass when run alone. AH-7 (#3572) shipped without the Fast-Check marker so the lane's Linux run is its proof. AH-5 regates when load < 6. Later waves run at most 3 builders at once.

- AH-6 (#3573) adds public `History.jumpEndingRun(to:_:)`, which ends the open run and then jumps. An app's `jumpHistory` calls it (AH-8, AH-9). A jump to the current index still ends the run.

- AH-3 (#3596) draws rows in a lazy scroll view with a focusable container instead of a system List, so a click jumps at once while arrows only move the cursor until Return; key/selection logic is the value type HistoryPanelCursor; public init(listing:onJump:) from #3568 unchanged.

- 2026-10-20T13:08:33Z AH-m merged-done: dev run 39424989659 (Linux green at 897ccbb) contains 3e010e3; Belt-Slice-Done posted on #3444.

- 2026-10-20T13:25:10Z AH-4 #3607: arrowWalkInThreeBodies makes the harness window key in-test to deliver arrows (unverified on Mac); p95 8 ms is printed, not asserted (perf-suites.txt is supervisor-only); packet row hoverInThreeBodies not written by AH-4 -> check at AH-u critic review.

- AH-8 (#3629): journey step 5 (Undo after a jump) is not in testHistoryPanelJumps (UITests file outside its list), and there is no suiteui-recovery-alert snapshot (system alert); both go to the AH-z critic review or AH-10. New SwiftUI API unverified until the macOS build. Body footer removed via MCP.

- AH-u slice-done posted 2026-10-20 (run 39448853502), Mac-Finish-Wanted posted. Critic panel queued for the first scoped suiteui or full run with HJ1 screens.

- 2026-10-22T10:03:39Z resume: base and PR target stay `dev` (the brief says main; main 0dd23d6 is an ancestor of dev, dev is 449 ahead, CLAUDE.md targets dev). lead/autosave-history rebuilt as origin/dev + this record (force-with-lease), since a plain rebase would replay dev's history onto main.
- GF-z merged (#4179, 6dd3a88), so AH-9's wait is met. AH-10 (~20 lines) folds into the AH-9 PR (rule 22); that PR carries `feature-done`.
- AH-a merged-done: Linux check 39756689216 (1896483) green and contains #3568 (575cc80); Belt-Slice-Done and Mac-Finish-Wanted posted.

## Open
- AH-u Mac finish gap #4174 (hover budget tests pass without hover).
- No open findings for suiteui autosave-history (#3947 is Design's DA-a).
