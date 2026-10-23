# Feature packet: catalog-files

**Feature:** the three file chores a week-one photographer hits. **Copy on
import:** the import sheet gains "Copy photos to" a chosen folder, optionally
into dated subfolders (`2026/2026-10-21/`), so a card can be ejected and
nothing goes missing; names never collide (`IMG_0001 2.jpg`), nothing is
overwritten, and each copy's size is checked before the catalog points at it.
**Remove from Catalog** (Photo menu and the grid's context menu): the selected
photos leave the catalog, their files stay on disk, one undo step brings them
back. **Relink:** a photo whose file is gone shows the missing badge; Locate…
picks its new file, and every other missing photo under the same old folder is
relinked to the same new folder when a file of the same name and size is
there. Every action is a catalog command (`file.import` with `copyTo` and
`byDate`, `photo.remove-from-catalog`, `photo.relink`).
**Line:** `line:library` · **Wave:** 7 (`waves.md`) · **Lead branch:** `lead/catalog-files`
**Beta:** captain, 2026-10-21 (beta gaps, Library must-haves; the blueprint's
1.3 "no file management" and 1.4 "no card copy" lines are re-cut for these three
by that call). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` Library must-haves "copy on
import, remove from catalog, relink missing"; Library audit rows 5, 7 and 8;
feature map A7 (its copy half; rename on import, templates and the watched
folder stay later); RJ-L50, RJ-L51, RJ-L52 (new). RJ-L01 stays open: it also
asks for rename by date and a second backup copy.

**Depends on:** spine (building; owns the window files), import and persist
(built). **Hand-offs** (cross-line): suite **command-state** CS-library-1 adds
the `file.import` id this packet extends; the import sheet's
`LibraryWindow+Import.swift` is library/file-flow's (LF-a).

**Rule 20.** File copy naming reuses SuiteModel's `UniqueFileNames` (the
onboarding sample rule); undo is the kernel's `History` through
`LibraryUndoAdapter`; no new file-name or undo code in Library.

**C4:** the new files go in `c4-planned.json`'s "Folder import" and "Catalog
file" components (this PR).

**Clean-room.** Behaviour from the apps' blueprints and the audit's jobs.

Blueprint sections: library.md 1.3 and 1.4 (re-cut), 4 (import), 6 (catalog).

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (clipboard-interop CB-library, orientation-crop OC-library-m) also edit `LibraryCommandCatalog.swift` and `Tests/command-ids/library.txt`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LC-a | Library declares the copy plan, remove and relink rules and their command specs as stubs, with the Model checks written and disabled. | LC-1, LC-2 | MJ-LC | cull-finish:DR-m (`LibraryImport.swift`) |
| LC-u | The import sheet offers Copy to a folder with dated subfolders, the grid offers Remove from Catalog, and a missing photo offers Locate…, on the stubs, every control identified and within the render budget. | LC-3, LC-4 | LJ-LC1, LJ-LC2 | LC-a; spine (window files) |
| LC-m | Copy on import copies, verifies and points the catalog at the copies without overwriting, remove keeps files and undoes in one step, and relink maps a moved folder's missing photos to their new files. | LC-5, LC-6 | MJ-LC | LC-a; metadata-more:MD-a (`LiveImporter.swift`); file-flow:LF-m (the catalog and ledger) |
| LC-z | The three chores run live end to end, RJ-L50 to RJ-L52 pass, and the feature is built. | LC-7, LC-8 | LJ-LC1, LJ-LC2, MJ-LC | LC-u, LC-m |

**Screen early.** LC-u builds the sheet option, the menu items and the badge's
Locate… on LC-a's stubs, beside LC-m.

## Journey steps

`MJ-LC` on Linux (`ImportCopyTests`, `CatalogRemoveTests`, `RelinkTests`), then:
1. Import a fixture "card" folder with Copy to a temp Pictures folder and dated folders on; the grid shows the photos; their paths are under the dated folders; delete the card folder: nothing goes missing (LC-3, LC-7; `LJ-LC1`, `LibraryFilesJourneyTests.testCopyOnImport`).
2. Select three, Remove from Catalog, confirm; they leave the grid; the files are still there; Undo brings them back. Move the folder on disk; the badges show; Locate… one photo: all relink (LC-3, LC-7; `LJ-LC2`, `LibraryFilesJourneyTests.testRemoveAndRelink`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L50 | adds, closes with `library/catalog-files` | C | `Tests/RealJobs/library/copy-on-import/`: `file.import` a two-folder card with `copyTo` and `byDate`, then delete the card | a generated card with a duplicate name |
| RJ-L51 | adds, closes with `library/catalog-files` | C | `Tests/RealJobs/library/remove-keep-files/`: rate 3 photos, `photo.remove-from-catalog` them, undo | a 10-photo folder |
| RJ-L52 | adds, closes with `library/catalog-files` | C | `Tests/RealJobs/library/relink-folder/`: import, move the folder, `photo.relink` one photo | a 40-photo folder |

Traps and assertions. RJ-L50: the duplicate name overwrites, or the catalog
still points at the card; after the card is deleted every photo opens, both
`IMG_0001` files exist with different bytes. RJ-L51: remove deletes the file or
undo loses the ratings; files exist, the ratings are back after undo. RJ-L52:
relink fixes only the one located photo; all 40 open after one relink.
Mutations: `LibraryModel.ImportCopyPlan` (`.neverOverwrites`),
`LibraryModel.CatalogFileRules` (`.relinkSameFolderOnly`). LC-2 writes them;
LC-7 enables them.

## Screens and states

`library-import-copy-options`, `library-remove-confirm`, `library-missing-locate`.

## Contract slice

```swift
// Sources/LibraryModel/ImportCopyPlan.swift (LC-1 stub, LC-5 body). Linux-safe.
public struct ImportCopyOptions: Hashable, Codable, Sendable { public var copyTo: String?; public var byDate: Bool }
public struct ImportCopyStep: Hashable, Sendable { public var source: String; public var destination: String }
public enum ImportCopyPlan {
    public static func plan(_ sources: [(path: String, captured: Date?, modified: Date)], options: ImportCopyOptions,
                            exists: (String) -> Bool) -> [ImportCopyStep]
}
// Sources/LibraryModel/CatalogFileRules.swift (LC-1 stubs, LC-6 bodies)
public enum CatalogFileRules {
    public static func removing(_ ids: Set<String>, from photos: [PhotoItem]) -> [PhotoItem]
    /// The new path for each missing photo under `oldFolder`, when `newFolder` holds a file of the same name and size.
    public static func relinks(missing: [PhotoItem], located: (id: String, file: String),
                               size: (String) -> Int?) -> [String: String]
}
```

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `file.import` (extended) | Import | `{folder, copyTo?, byDate?}` | an import is running |
| `photo.remove-from-catalog` | Remove from Catalog | `{ids?}` (the selection when nil) | nothing selected |
| `photo.relink` | Relink | `{id, file}` | the photo isn't missing; the file doesn't exist |

## Pseudocode

- **Copy.** Plan first (pure), then copy each step to a temporary name in the
  destination folder, compare sizes, rename into place; a failure leaves the
  source referenced and is listed in the import notice.
- **Remove.** One `History` step holding the removed `PhotoItem`s and their
  positions; undo reinserts them; thumbnails stay cached until the next prune.
- **Relink.** Old folder = the located photo's old parent; new folder = the
  picked file's parent; each missing photo whose path starts with the old
  folder plus "/" maps to the same relative path under the new folder when that
  file exists with the same size; one step for all.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LC-1 | – | **Checks first.** `ImportCopyTests`, `CatalogRemoveTests` and `RelinkTests` written, disabled by name; `ImportCopyPlan`, `CatalogFileRules` (remove, relink) and `LibraryCatalogFiles+Kernel.swift` specs as stubs; `ImportOptions` gains `copyTo` and `byDate` | `Sources/LibraryModel/ImportCopyPlan.swift`, `Sources/LibraryModel/CatalogFileRules.swift`, `Sources/LibraryModel/LibraryCatalogFiles+Kernel.swift`, `Sources/LibraryModel/LibraryImport.swift`, `Tests/LibraryModelTests/ImportCopyTests.swift`, `Tests/LibraryModelTests/CatalogRemoveTests.swift`, `Tests/LibraryModelTests/RelinkTests.swift` | – | ~240, 7 |
| LC-2 | – | `LibraryFilesJourneyTests` written, skipped until LC-7; RJ-L50 to RJ-L52 job folders, disabled | `UITests/LibraryJourneyTests+Files.swift`, `Tests/RealJobs/library/copy-on-import/copy-on-import.jobs.json`, `Tests/RealJobs/library/remove-keep-files/remove-keep-files.jobs.json`, `Tests/RealJobs/library/relink-folder/relink-folder.jobs.json` | LC-1 | ~120, 4 |
| LC-3 | – | **Reachable first.** The import sheet's "Add in place / Copy to" choice, the folder picker and "Into dated folders"; Photo > Remove from Catalog (⌫ with a confirm naming the count) and the grid's context menu; Locate… on the missing badge and in the inspector, each running its command (unavailable on the stubs with "File management arrives with LC-5.") | `Sources/LibraryApp/LibraryImportOptions.swift`, `Sources/LibraryApp/LibraryWindow+Files.swift`, `Sources/LibraryApp/LibraryMissingBadge.swift` | LC-1 | ~230, 3 |
| LC-4 | – | Render budget test for the grid's missing badges at 10,000 photos | `Tests/AppSnapshotTests/RenderBudgetLibraryFilesTests.swift` | LC-3 | ~80, 1 |
| LC-5 | – | `ImportCopyPlan` body and the live copier: destinations under `copyTo` (dated `yyyy/yyyy-MM-dd` from the capture date, else the file date), unique names, copy then size check, the catalog stores the copy's path; a failed copy leaves the original referenced and names the file; turns on `ImportCopyTests` | `Sources/LibraryModel/ImportCopyPlan.swift`, `Sources/LibraryModel/Live/LiveImporter.swift`, `Tests/LibraryModelTests/ImportCopyTests.swift`, `Tests/mutations/LibraryModel.ImportCopyPlan.json` | LC-1 | ~220, 4 |
| LC-6 | – | `CatalogFileRules` bodies and the commands: `photo.remove-from-catalog` (one undo step, files untouched), `photo.relink` (`{id, file}` then every missing photo under the same old folder whose name and size match under the new one); the catalog appends the specs; ids in the ledger; turns on `CatalogRemoveTests` and `RelinkTests` | `Sources/LibraryModel/CatalogFileRules.swift`, `Sources/LibraryModel/LibraryCatalogFiles+Kernel.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/LibraryModelTests/CatalogRemoveTests.swift`, `Tests/LibraryModelTests/RelinkTests.swift`, `Tests/mutations/LibraryModel.CatalogFileRules.json` | LC-1 | ~240, 7 |
| LC-7 | – | The sheet's copy choice, the remove confirm and Locate… on live; the journeys on; the jobs enabled | `Sources/LibraryApp/LibraryWindow+Files.swift`, `UITests/LibraryJourneyTests+Files.swift`, `Tests/RealJobs/library/copy-on-import/copy-on-import.jobs.json` | LC-3, LC-5, LC-6, LC-2 | ~150, 3 |
| LC-8 | – | `status: built`; `feature-done` | `docs/blueprints/library/features/catalog-files.wave.json` | LC-7 | ~10, 1 |

## Build waves

- Wave 1: LC-1. Independent in this wave: LC-1 alone.
- Wave 2: LC-2, LC-3, LC-5, LC-6. Independent in this wave: all.
- Wave 3: LC-4, LC-7. Independent in this wave: both.
- Wave 4: LC-8. Independent in this wave: LC-8 alone.

Longest chain: LC-1 → LC-3 → LC-7 → LC-8 (4). Chain of 4: the stubs before the bodies, the bodies before the live window, then the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LC-1 | the suites compile, disabled by name; existing import tests unchanged | a signature the sheet or the commands call is missing | – (stubs) |
| LC-2 | `scripts/jobs check` | a job names a command the catalog lacks | – (tests) |
| LC-3 | the controls exist with their ids; the confirm names the count | a control has no id or command | – (view; render budget row) |
| LC-4 | `RenderBudgetLibraryFilesTests.missingBadgeScroll` | badges re-render the grid per frame | – (budget) |
| LC-5 | `ImportCopyTests`: two `IMG_0001.jpg` from two folders land as `IMG_0001.jpg` and `IMG_0001 2.jpg`; an existing file is never overwritten; dated folders follow the capture date; a short copy is refused and the original kept | a copy overwrites, collides or is trusted unchecked | `LibraryModel.ImportCopyPlan`: unique-name check skipped → `.neverOverwrites`; size check skipped → `.shortCopyRefused`; file date used before capture date → `.datedByCapture` |
| LC-6 | `CatalogRemoveTests`: 3 removed, files still on disk, undo restores ratings and develop; `RelinkTests`: locating one of 40 moved photos relinks all 40; a same-name file of another size is not linked | a remove deletes a file, or relink links the wrong file | `LibraryModel.CatalogFileRules`: size match skipped → `.relinkChecksSize`; folder prefix compared without a trailing slash (`/a/b` matches `/a/bc`) → `.relinkSameFolderOnly` |
| LC-7 | `LJ-LC1`, `LJ-LC2`; RJ-L50 to RJ-L52 on Linux (`C`) | the window's import still references in place when Copy is picked | – (window wiring) |
| LC-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: scroll 10,000 photos with 500 missing badges | ≤ 3 window bodies per 120-sample scroll | `RenderBudgetLibraryFilesTests.missingBadgeScroll` |
| import copy speed | 2,000 JPEGs (5 MB) copied at disk speed, progress live | `ImportCopyTests` (plan) and the journey's progress step |
| one gesture, one step | remove and relink one undo step each | `CatalogRemoveTests`, `RelinkTests` |
| writes only where chosen | copies only under `copyTo`; nothing deleted, ever | RJ-L50, RJ-L51 |

## Done check

Per slice (rules 6, 15, 17, 21, 22): LC-a and LC-m green on Linux with
`Mutate:` clean; LC-u and LC-z through the feel gate (`mouse`: import with
copy, remove, relink by mouse) with their `Mac-Finish:` lines; RJ-L50 to
RJ-L52 green on Linux. Then `Belt-Contact-Sheet:`.
