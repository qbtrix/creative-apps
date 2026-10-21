# catalog-backup lead record

Issue: #3788 · Packet: docs/blueprints/library/features/catalog-backup.md
Run: act-1a15d1c39b2-vvii · Session: cse_01Frm5sedPTzoQ8Smui9DRCb · Started: 2026-10-21T06:20:32Z
Stage: 3 wave 1
Base: 0865916d47ed5b21be2f827768d2aa92b7d200bb
Next: finish BK-a from worktree wf_32b47868-6c0-4 (gate, commit, PR); then wave 2 stacks BK-u and BK-3 on it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| BK-a | rotation and restore commands as stubs, checks disabled | BK-1, BK-2 | MJ-BK | – | no | 0 | building | – | – |
| BK-u | Restore Catalog Backup sheet on stubs | BK-4, BK-4b | LJ-BK | BK-a; spine | yes | 0 | waits BK-a PR | – | – |
| BK-m | rotation limits, fallback, restore backs up current | BK-3, BK-5m | MJ-BK | BK-a; LF-m, FO-m, AK-library (not merged) | no | 0 | BK-3 next wave; BK-5m blocked | – | – |
| BK-z | live restore, RJ-L54, built | BK-5, BK-6 | LJ-BK, MJ-BK | BK-u, BK-m | yes | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| BK-1 | BK-a | 1 | BackupRotation stubs over FileStore; tests disabled; store part names it | Sources/SuiteModel/Store/BackupRotation.swift, Tests/SuiteModelTests/BackupRotationTests.swift, docs/c4/parts/creative-apps/suite-model/suite-store.json | compiles, disabled | – | building |
| BK-2 | BK-a | 1 | catalog.backups / restore-backup specs NotBuilt; tests disabled; journey skipped | LibraryBackup+Kernel.swift, LibraryBackupTests.swift, UITests/LibraryJourneyTests+Backup.swift | compiles, disabled | – | building (same PR) |
| BK-4 | BK-u | 2 | restore sheet and menu item | LibraryBackupSheet.swift, LibraryWindow+Backup.swift | ids, confirm text | – | planned |
| BK-4b | BK-u | 2 | render budget | RenderBudgetLibraryBackupTests.swift | openSheetInTwoBodies | – | planned |
| BK-3 | BK-m | 2 | rotation bodies | BackupRotation.swift, BackupRotationTests.swift, Tests/mutations/SuiteModel.BackupRotation.json | BackupRotationTests | – | planned |
| BK-5m | BK-m | – | Library on the rotation | LibraryBackup+Kernel.swift, LibraryPersistence.swift, ... | LibraryBackupTests | – | blocked: LF-m, FO-m, AK-library |
| BK-5 | BK-z | – | live sheet, journey, RJ-L54 | ... | LJ-BK | – | blocked |
| BK-6 | BK-z | – | feature-done | catalog-backup.wave.json | – | – | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target are dev, not main (packets live on dev; the lane merges into dev).
- BK-1 edits SuiteModel, outside line:library: the packet assigns it (rule 20, the rotation is a store service), so it is built here.

## Open
- BK-5m waits on file-flow:LF-m, folders:FO-m and suiteui adopt-kernel-autosave AK-library; none merged.
