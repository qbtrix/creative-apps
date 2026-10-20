# Feature packet: catalog-backup

**Feature:** one bad write can't lose a week of culling. Today the catalog
writes atomically and sets a damaged file aside as `.bad`, then starts empty.
This packet keeps **rolling backups**: after a successful save, at most once
an hour, and at quit, the catalog file is copied to `Backups/` beside it;
the last 10 copies are kept, plus the newest of each of the last 7 days.
When the catalog can't be read, Library offers the newest good backup instead
of an empty catalog. **File > Restore Catalog Backup…** lists the backups with
their date and photo count, and restoring one first backs up the current
catalog, so a restore is never a loss. The rotation is a SuiteModel service
over `FileStore`, so other support files can use it later. Every action is a
catalog command (`catalog.backups`, `catalog.restore-backup`).
**Line:** `line:library` · **Wave:** 7 (`waves.md`) · **Lead branch:** `lead/catalog-backup`
**Beta:** captain, 2026-10-21 (beta gaps, Library must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` Library must-have "catalog
backup"; Library audit row 9; RJ-L54 (new).

**Depends on:** persist (built), spine (building). **Hand-off** (cross-line):
suiteui adopt-kernel-autosave **AK-library** moves `CatalogStore.swift` under
the suite support root; BK-u and BK-m start after it, so the backups live
beside the moved catalog.

**Rule 20.** The rotation is `SuiteModel/Store/BackupRotation.swift`, a store
service (SuiteModel holds the store), not Library code; Library keeps one
adapter, `LibraryBackup+Kernel.swift`.

**C4:** edits the `suite-model/suite-store.json` part (BK-1 names the
rotation); Library's new files join `c4-planned.json`'s "Catalog file"
component (this PR).

**Clean-room.** Nothing external is read.

Blueprint sections: library.md 6 (catalog), suite.md 2.6 (store).

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (clipboard-interop CB-library, orientation-crop OC-library-m) also edit `LibraryCommandCatalog.swift` and `Tests/command-ids/library.txt`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| BK-a | SuiteModel declares the backup rotation and Library the restore commands as stubs, with the checks written and disabled. | BK-1, BK-2 | MJ-BK | – |
| BK-u | File > Restore Catalog Backup lists backups with date and count and restores one after a confirm, on the stubs, within the render budget. | BK-4, BK-4b | LJ-BK | BK-a; spine |
| BK-m | Saves keep hourly and quit backups with the rotation's limits, an unreadable catalog falls back to the newest good backup, and a restore backs up the current catalog first, one command each. | BK-3, BK-5m | MJ-BK | BK-a; file-flow:LF-m and folders:FO-m (the catalog and ledger); suiteui adopt-kernel-autosave AK-library (cross-line) |
| BK-z | Restore runs live end to end, RJ-L54 passes, and the feature is built. | BK-5, BK-6 | LJ-BK, MJ-BK | BK-u, BK-m |

**Screen early.** BK-u builds the real sheet on BK-a's stubs, beside BK-m.

## Journey steps

`MJ-BK` on Linux (`BackupRotationTests`, `LibraryBackupTests`), then:
1. Open a catalog with fixture backups, rate a photo, File > Restore Catalog Backup…, pick yesterday's, confirm; the rating is yesterday's; reopen the sheet: today's catalog is now a backup (BK-4, BK-5; `LJ-BK`, `LibraryBackupJourneyTests.testRestoreBackup`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L54 | adds, closes with `library/catalog-backup` | C | `Tests/RealJobs/library/restore-backup/`: rate 30 photos over three saves an hour apart (the job's clock), truncate the catalog file, relaunch, then `catalog.restore-backup` the oldest | a 30-photo catalog |

Trap: a damaged catalog opens empty and the backups are pruned before anyone
notices, or a restore overwrites the only good copy. Assertion: the relaunch
opens the newest good backup with all 30 ratings and names it; after the
restore, `catalog.backups` lists the pre-restore catalog. Mutation:
`LibraryModel.LibraryBackup+Kernel` (`.fallbackToNewestGood`). BK-5 writes it.

## Screens and states

`library-restore-backup-sheet`, `library-restore-confirm`.

## Contract slice

```swift
// Sources/SuiteModel/Store/BackupRotation.swift (BK-1 stubs, BK-3 bodies). Linux-safe.
public struct BackupEntry: Hashable, Sendable { public var name: String; public var date: Date; public var bytes: Int }
public struct BackupRotation: Sendable {
    public init(store: FileStore, file: String, keepLast: Int = 10, keepDays: Int = 7)
    public func shouldBackUp(now: Date) -> Bool                 // an hour since the newest backup
    public func backUp(now: Date, force: Bool) throws(SuiteError) -> BackupEntry?
    public func list() -> [BackupEntry]                         // newest first
    public func prune(now: Date) throws(SuiteError)
    public func restore(_ name: String, now: Date) throws(SuiteError)   // backs up the current file first
}
```

| id | title | params | unavailable when |
|---|---|---|---|
| `catalog.backups` | – (query) | – → `[{name, date, photos}]` | – |
| `catalog.restore-backup` | – (not an undo step: it replaces the catalog; confirm in the window) | `{name}` | an unknown name; an import running |

## Pseudocode

- **When.** After `CatalogStore`'s atomic write succeeds: `shouldBackUp` then
  `backUp`; at quit `backUp(force: true)`; `prune` after each backup.
- **Fallback.** On a decode failure, walk `list()` newest first, decode each,
  open the first that decodes and show "Opened the backup from <date>; the
  damaged catalog is kept as …".

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| BK-1 | – | **Checks first.** `BackupRotationTests` written, disabled (`waits on BK-3`); `BackupRotation` (`shouldBackUp`, `backUp`, `prune`, `list`) as stubs over `FileStore`; the store part names it | `Sources/SuiteModel/Store/BackupRotation.swift`, `Tests/SuiteModelTests/BackupRotationTests.swift`, `docs/c4/parts/creative-apps/suite-model/suite-store.json` | – | ~150, 3 |
| BK-2 | – | `LibraryBackup+Kernel.swift`: `catalog.backups` and `catalog.restore-backup` specs, runs throwing `NotBuilt`; `LibraryBackupTests` written, disabled; `LibraryBackupJourneyTests` written, skipped until BK-5 | `Sources/LibraryModel/LibraryBackup+Kernel.swift`, `Tests/LibraryModelTests/LibraryBackupTests.swift`, `UITests/LibraryJourneyTests+Backup.swift` | BK-1 | ~140, 3 |
| BK-4 | – | **Reachable first.** File > Restore Catalog Backup… opens a sheet (SuiteUI list rows: date, photo count), Restore with a confirm naming what happens to the current catalog; each runs its command (unavailable on the stubs with "Backups arrive with BK-3.") | `Sources/LibraryApp/LibraryBackupSheet.swift`, `Sources/LibraryApp/LibraryWindow+Backup.swift` | BK-2 | ~170, 2 |
| BK-4b | – | Render budget test: open the sheet with 17 backups | `Tests/AppSnapshotTests/RenderBudgetLibraryBackupTests.swift` | BK-4 | ~60, 1 |
| BK-3 | – | `BackupRotation` bodies: at most one backup an hour unless forced (quit); keep the last 10 plus the newest per day for 7 days; never delete the newest good copy; `list` with date and size; turns on `BackupRotationTests` | `Sources/SuiteModel/Store/BackupRotation.swift`, `Tests/SuiteModelTests/BackupRotationTests.swift`, `Tests/mutations/SuiteModel.BackupRotation.json` | BK-1 | ~170, 3 |
| BK-5m | – | Library on the rotation: back up after a successful save and at quit; on an unreadable catalog, offer the newest backup that decodes; the command bodies (restore backs up the current file, then replaces it, then reloads); the catalog appends the specs; ids in the ledger; turns on `LibraryBackupTests` | `Sources/LibraryModel/LibraryBackup+Kernel.swift`, `Sources/LibraryModel/LibraryPersistence.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/LibraryModelTests/LibraryBackupTests.swift`, `Tests/mutations/LibraryModel.LibraryBackup+Kernel.json` | BK-3, BK-2 | ~220, 6 |
| BK-5 | – | The sheet on live; the journey on; RJ-L54's job folder, enabled | `Sources/LibraryApp/LibraryWindow+Backup.swift`, `UITests/LibraryJourneyTests+Backup.swift`, `Tests/RealJobs/library/restore-backup/restore-backup.jobs.json` | BK-4, BK-5m | ~110, 3 |
| BK-6 | – | `status: built`; `feature-done` | `docs/blueprints/library/features/catalog-backup.wave.json` | BK-5 | ~10, 1 |

## Build waves

- Wave 1: BK-1. Independent in this wave: BK-1 alone.
- Wave 2: BK-2, BK-3. Independent in this wave: both.
- Wave 3: BK-4, BK-5m. Independent in this wave: both.
- Wave 4: BK-4b, BK-5. Independent in this wave: both.
- Wave 5: BK-6. Independent in this wave: BK-6 alone.

Longest chain: BK-1 → BK-2 → BK-4 → BK-5 → BK-6 (5). Chain of 5: the rotation, Library's adapter, the live sheet, the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| BK-1 | compiles, disabled by name | a signature Library calls is missing | – (stubs) |
| BK-2 | compiles, disabled by name | a spec the menu calls is missing | – (stubs) |
| BK-4 | the item, the rows and Restore carry ids; the confirm text names the current catalog's backup | a control has no id or command | – (view; render budget row) |
| BK-4b | `RenderBudgetLibraryBackupTests.openSheetInTwoBodies` | opening re-renders the grid | – (budget) |
| BK-3 | `BackupRotationTests`: 30 saves over 3 hours make 3 backups; 20 days of backups prune to 10 plus 7 daily; a forced backup within the hour is kept | backups pile up, or pruning drops the newest | `SuiteModel.BackupRotation`: hour check skipped → `.atMostHourly`; daily keep uses oldest of the day → `.keepsNewestPerDay` |
| BK-5m | `LibraryBackupTests`: a corrupted catalog with two backups opens the newer good one and says so; restore of an older one leaves a backup of the current one; ratings match the restored backup | a restore loses the current catalog, or a damaged catalog opens empty | `LibraryModel.LibraryBackup+Kernel`: current not backed up before restore → `.restoreKeepsCurrent`; first backup used instead of newest → `.fallbackToNewestGood` |
| BK-5 | `LJ-BK`; RJ-L54 on Linux | the grid doesn't reload after a restore | – (window wiring) |
| BK-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: open the restore sheet | ≤ 2 window bodies | `RenderBudgetLibraryBackupTests.openSheetInTwoBodies` |
| save cost | a backup copy off the main thread; a save stays under its budget | `LibraryBackupTests.backupOffMain` |
| disk | at most 17 backups kept | `BackupRotationTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): BK-a and BK-m green on Linux with
`Mutate:` clean; BK-u and BK-z through the feel gate (`mouse`) with their
`Mac-Finish:` lines; RJ-L54 green on Linux. Then `Belt-Contact-Sheet:`.
