# share-sheet lead record

Issue: #3789 · Packet: docs/blueprints/library/features/share-sheet.md
Run: act-1a1693fbf6d-ap2g · Session: claude/large-catalog-share-sheet-2tdm4i (earlier act-1a1648ae708-bncr, act-1a15df37b73-k199, act-1a15b98bc49-4lk9) · Started: 2026-10-20T23:00Z (resumed 2026-10-22T16:55Z)
Stage: closed (#3789 closed by the supervisor sentinel 20:29Z; every slice done; SH-z Belt-Slice-Done on library run 40009734956 at 20:25Z, #3789 comment 6374028785; the earlier red 39997279554 on RenderBudgetLibraryFoldersTests was a slow-runner flake, passing on 40009734956)
Base: 8021b0f56a45a59540cd4ea0ff99651c5fb8dc2a (origin/dev)
Next: none; fix any share-sheet finding that is filed later

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SH-a | sharing preset, share folder, ShareButton: the contract | SH-1, SH-2 | MJ-SH | - | yes | 0 | done #3809 (482f03c6) | 39571804700 | wanted |
| SH-u | Share in the toolbar and File menu, journey | SH-4, SH-4b | LJ-SH | SH-a | yes | 1 | done #3814 | 39601343733 | wanted; finisher PR #4432 open |
| SH-m | prepare writes the files, launch cleanup, command, RJ-L55 | SH-3, SH-3c | MJ-SH | SH-a, file-flow:LF-m, catalog-backup:BK-m | no | 0 | done #4592 (567d03bb) | 39957675362 | - |
| SH-z | live wiring, journey on, built | SH-5, SH-6 | LJ-SH, MJ-SH | SH-u, SH-m | yes | 0 | done (#4612, 55017fac; run 40009734956) | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SH-1 | SH-a | 1 | SharePrep stubs, file.share-prepare stub | Sources/LibraryModel/LibraryShare+Kernel.swift, Tests/LibraryModelTests/LibrarySharePrepTests.swift | LibrarySharePrepTests | #3809 | merged |
| SH-2 | SH-a | 1 | ShareButton over ShareLink | Sources/SuiteUI/ShareButton.swift, Tests/SuiteUITests/ShareButtonTests.swift | ShareButtonTests | #3809 | merged |
| SH-4 | SH-u | 2 | File > Share, grid and loupe Share buttons on the stubs | Sources/LibraryApp/LibraryShareItems.swift, Sources/LibraryApp/LibraryMenus+Share.swift, UITests/LibraryJourneyTests+Share.swift | ids, reason | #3814 | merged |
| SH-4b | SH-u | 2 | render budget | Tests/AppSnapshotTests/RenderBudgetLibraryShareTests.swift | prepareThreeInTwoBodies | #3814 | merged |
| SH-3 | SH-m | 3 | SharePrep bodies, file.share-prepare in the catalog and ledger | Sources/LibraryModel/LibraryShare+Kernel.swift, Sources/LibraryModel/LibraryCommandCatalog.swift, Tests/command-ids/library.txt, Tests/LibraryModelTests/LibrarySharePrepTests.swift, Tests/mutations/LibraryModel.LibraryShare+Kernel.json | LibrarySharePrepTests | #4592 | merged |
| SH-3c | SH-m | 3 | RJ-L55 job folder | Tests/RealJobs/library/share-three/ | scripts/jobs check | #4592 | merged |
| SH-5 | SH-z | 4 | buttons and menu on live, journey on | Sources/LibraryApp/LibraryShareItems.swift, UITests/LibraryJourneyTests+Share.swift | LJ-SH | #4612 | merged |
| SH-6 | SH-z | 4 | status built, feature-done | docs/blueprints/library/features/share-sheet.wave.json | waves render | #4612 | merged |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target are dev, not main (CLAUDE.md; the lane retargets main PRs to dev). This run's brief says main.
- The record is back on lead/share-sheet at docs/leads/share-sheet/, the path this run's brief names; lead/library-share-sheet holds a pointer.
- SH-a carries SH-2 (a SuiteUI file) because the packet's slice table puts it there.
- SH-m starts now (2026-10-22): the supervisor's 13:44Z answer said to start once LF-3 #4024 and BK-u #3967 land; both merged (593cfe6, 15806ab). LF-4 (macOS window import) and BK-5m (Library on the rotation) are not merged, but SH-3 needs none of their code: it only shares LibraryCommandCatalog.swift and the ledger with BK-5m, which the lane's merge drivers integrate. The catalog-backup lead is told on #3788 (packet hand-off note).
- SH-3 and SH-3c ship as one slice PR (rule 22): #4592, 262+/52-, 15 files.
- #4592: file.share-prepare only plans the copies (kernel commands are synchronous); async prepareShare writes them. The writer contract gains removeAll(in:) for the launch cleanup; LibraryShare+Kernel.swift joins the LibraryNeverDeletesTests allow-list because cleanup only empties <support>/Share/, Library's own copies. RJ-L55 lists no platforms until #3741.
- SH-5 and SH-6 ship as one slice PR (rule 22: SH-6 is under 50 lines).
- Belt's nudges name lead/library-share-sheet, so the record is mirrored there at docs/leads/library-share-sheet/ as well.

## Open
- 2026-10-23T15:44Z: #4612 open, labels fast-lane and feature-done, head de155da4; waits on its batch's macOS gate.
- Belt reads lead/library-share-sheet; this record is mirrored there at docs/leads/library-share-sheet/ from 2026-10-23T15:44Z on.
- 2026-10-23: #4612 had grown to 427 lines / 25 files because it was stacked on #4592; the lane dropped fast-lane and the sentinel asked for needs-split. After merging origin/dev (conflicts in LibraryApp.swift, kept both sides, and the CLI golden list, took dev's) the diff is 113 lines / 11 files, so no split: the label goes and fast-lane comes back once the gate passes.
- Mac finish PR #4432 (SH-u, label mac-finish) edits Sources/LibraryApp/LibraryShareItems.swift, which SH-5 also owns; SH-5 starts after it merges or merges dev over it.
- dev-red #3856 was open on 2026-10-21 (others' merges); not ours.
