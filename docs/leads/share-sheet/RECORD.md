# share-sheet lead record

Issue: #3789 · Packet: docs/blueprints/library/features/share-sheet.md
Run: act-1a15b98bc49-4lk9 · Session: claude/task-k1zaw1 · Started: 2026-10-20T23:00Z
Stage: 3 wave 2 (SH-a #3809 and SH-u #3814 shipped; #3814 stacked on share-sheet/sh-a, retarget to dev once #3809 merges)
Base: 2cc149f57 (origin/dev)
Next: #3809 rebased onto dev at b63c2756 (2026-10-21T00:33:59Z), waiting on its lane batch; then retarget #3814 to dev and move its Head:; SH-m waits on file-flow LF-m and catalog-backup BK-m; then SH-z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SH-a | sharing preset, share folder, ShareButton: the contract | SH-1, SH-2 | - | - | yes | 0 | shipped #3809 | - | - |
| SH-u | Share in the toolbar and File menu, journey | SH-4, SH-4b | LibraryJourneyTests+Share | SH-a | yes | 0 | planned | - | - |
| SH-m | prepare writes the files, launch cleanup, command | SH-3, SH-3c | - | SH-a, file-flow:LF-m, catalog-backup:BK-m | no | 0 | blocked | - | - |
| SH-z | finish | SH-5, SH-6 | - | SH-u, SH-m | yes | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SH-1 | SH-a | 1 | SharePrep options/folder/cleanup stubs, file.share-prepare stub | Sources/LibraryModel/LibraryShare+Kernel.swift | LibrarySharePrepTests | #3809 | shipped |
| SH-2 | SH-a | 1 | ShareButton stub over the system share picker | Sources/SuiteUI/ShareButton.swift | ShareButtonTests | #3809 | shipped |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is dev, not main: PRs target dev (CLAUDE.md).
- SH-a carries SH-2 (a SuiteUI file) because the packet's slice table puts it there.

## Open
- SH-m blocked: file-flow LF-m and catalog-backup BK-m not on dev 2cc149f5.
- ShareButton is two presses: Share prepares, then "Share N Photos" is the ShareLink (a ShareLink can't open itself after an await). SharePhase holds the logic so SuiteUITests check it.
