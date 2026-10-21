# share-sheet lead record

Issue: #3789 · Packet: docs/blueprints/library/features/share-sheet.md
Run: act-1a15df37b73-k199 · Session: claude/library-line-lead-lqhhp8 (earlier act-1a15b98bc49-4lk9 on claude/task-k1zaw1) · Started: 2026-10-20T23:00Z
Stage: 3 wave 2 done (SH-a, SH-u done); SH-m waits on LF-3 #4024 and BK-u #3967
Base: e2b8aa76 (origin/dev)
Next: #3814 fixer: build File > Share from a LibraryCommandCatalog spec (CommandPathTests), gate, move Head:; SH-m waits on file-flow LF-m and catalog-backup BK-m (only LF-a #3624, BK-a #3960 on dev); then SH-z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SH-a | sharing preset, share folder, ShareButton: the contract | SH-1, SH-2 | - | - | yes | 0 | done #3809 (482f03c6) | 39571804700 | - |
| SH-u | Share in the toolbar and File menu, journey | SH-4, SH-4b | LibraryJourneyTests+Share | SH-a | yes | 1 | merged #3814 | - | - |
| SH-m | prepare writes the files, launch cleanup, command | SH-3, SH-3c | - | SH-a, file-flow:LF-m, catalog-backup:BK-m | no | 0 | blocked | - | - |
| SH-z | finish | SH-5, SH-6 | - | SH-u, SH-m | yes | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SH-1 | SH-a | 1 | SharePrep options/folder/cleanup stubs, file.share-prepare stub | Sources/LibraryModel/LibraryShare+Kernel.swift | LibrarySharePrepTests | #3809 | merged |
| SH-2 | SH-a | 1 | ShareButton stub over the system share picker | Sources/SuiteUI/ShareButton.swift | ShareButtonTests | #3809 | merged |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The record moved to lead/library-share-sheet at docs/leads/library-share-sheet/, where Belt reads it. lead/share-sheet is the old copy.
- Base is dev, not main: PRs target dev (CLAUDE.md).
- SH-a carries SH-2 (a SuiteUI file) because the packet's slice table puts it there.

- Run act-1a15df37b73-k199 takes over: #3814's Belt-Lead line moves to this run.
- SH-a done on the dev Linux check 39571804700 (d93267da contains 482f03c6); its stubs show no new screen, so no critic run for it.

## Open
- SH-m blocked: file-flow LF-m and catalog-backup BK-m not on dev e2b8aa76 (LF-a, BK-a merged; BK-u #3967, BK-3 #3965 open).
- SH-u #3814 merged at 12:15Z. Waiting on a green dev Linux check that contains it: 39598650564 on 76d0c892 is running.
- SH-m: LF-m is in flight (LF-3 #4024, needs-rebase cleared). For BK-m, BK-3 #3965 merged as 73c3deb1 and BK-u #3967 is still open. LF-m and BK-m are not met on dev c2aa3391.
- dev-red #3856 is open (others' merges); not ours to fix.
- ShareButton is two presses: Share prepares, then "Share N Photos" is the ShareLink (a ShareLink can't open itself after an await). SharePhase holds the logic so SuiteUITests check it.

- 13:05Z: Posted Belt-Slice-Done: SH-u on 39601343733 (737541328, contains 76d0c892; only red LibraryFoldersTests, #3961), plus Mac-Finish-Wanted for SH-u and the missed one for SH-a. SH-m still waits on #4024 and #3967, both open with fast-lane (poll 1 at this state).
