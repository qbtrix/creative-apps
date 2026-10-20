# Feature packet: cull-finish

**Feature:** the last two steps of a cull. **Delete Rejected Photos…** (Photo
menu, ⌘⌫) moves the selected collection's rejected photos to the macOS Trash
after one confirmation, takes them out of the catalog, and remembers their
paths so importing the folder again doesn't bring them back. It is one undo
step: Undo puts the files back from the Trash where they were and the photos
back where they sat. **Colour label keys:** 6 Red, 7 Yellow, 8 Green, 9 Blue
set the label of the loupe photo or the selection, the way 0–5 rate and P, X,
U flag. Every action is a command; nothing in Library ever deletes a file.
**Line:** `line:library` · **Wave:** 6 (`waves.md`) · **Lead branch:** `lead/cull-finish`
**Beta:** captain, 2026-10-18 (Delete Rejects lifts blueprint 1.3's "never
deletes" for v1, with the Trash and undo as its guard), filed 2026-10-20.
Labels `beta` and `p1` when filed.

**Covers:** feature map A5 (Delete Rejects and label keys; its "full screen"
part is not here, see the end); real job RJ-L06 (closes here).

**Not here, because #1563 has it.** Filtering by flag, by rating (at least or
exactly N), by colour label and Hide Rejected are filters-collections' FC-b
(FC-6, FC-7) on `LibraryFilter` (FC-1, merged #1976); #1563 is in the beta and
its lead is building FC-a now. This packet adds no filter. Its journey uses
the Rejected chip only once FC-b has merged (step 2), and the Model check
needs no filter at all. metadata-more (#1555) owns keywords and camera
details; nothing here touches them.

**Depends on:** filters-collections **FC-a** (FC-3 widens the history step in
`LibraryUndoAdapter.swift`; FC-2 and FC-5 own `LibraryCatalog.swift`,
`LibraryWindow.swift` and `LibraryCommands.swift`) and metadata-more
**MD-a** (`LibraryServices.swift`), **MD-c** (`LiveCatalogCoding.swift`),
**MD-d** (`LibraryWindow+Cull.swift`'s neighbours) and **MD-e**
(`LibraryCatalog.swift`, `LibraryCommands.swift`, `LibraryWindow.swift`), by
slice below; cull, import and persist (built). No creative-core or SuiteUI
issue: `FileManager.trashItem(at:resultingItemURL:)` is Foundation on macOS,
and the confirmation is SwiftUI's `confirmationDialog`.

**Hand-offs:** `LibraryCommandCatalog.swift`, `LibraryMenus.swift` and
`Tests/command-ids/library.txt` are adopt-command-catalog's (#2999): DR-3 and
DR-7 start after AC-library's `Belt-Slice-Done:`.

**Rule 20.** Undo is the kernel's `History` through `LibraryUndoAdapter`, one
step like every cull edit; no second undo stack holds the Trash moves. The
Trash is a service (`PhotoTrashing`) like every Library side effect: `FakeTrash`
on Linux and in tests, `LiveTrash` on `FileManager.trashItem` on macOS, in
LibraryModel so the CLI uses it headless (RJ-L06 runs `Cm`). **Never
permanent:** no Library file calls `removeItem`, `unlink` or empties the
Trash on a photo; `LibraryNeverDeletesTests` scans `Sources/LibraryModel` and
`Sources/LibraryApp` for them and fails. Its one allowed line is
`Platform/CatalogStore.swift`'s replace of an older `.bad` copy of the catalog
file (persist's set-aside, never a photo), listed by file and text in the test.

Blueprint sections: library.md 1.3 (never deletes, amended), 3 (cull), 6.2
(menus).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DR-a | The Trash service with its fake and a live stub, the label keys' cases, and the catalog's Delete Rejects title, help, targets and run exist as stubs, and the checks and RJ-L06's job are written, disabled. | DR-1, DR-2 | MJ-DR | filters-collections:FC-a; metadata-more:MD-a |
| DR-u | Photo > Delete Rejected Photos… ⌘⌫ asks once with the count and runs on the stubs, and Set Label's items name keys 6–9, with snapshots, the render budget and the journey written. | DR-3, DR-4 | J-DR1 | DR-a; filters-collections:FC-a; metadata-more:MD-d, MD-e (DR-3) |
| DR-m | Keys 6–9 set Red, Yellow, Green and Blue as one step each; Delete Rejects moves every reject of the collection to the Trash, removes them and remembers their paths in one step whose undo puts files and photos back; the catalog file keeps those paths and import skips them; it runs from the catalog. | DR-5, DR-6, DR-7, DR-8 | MJ-DR | DR-a; metadata-more:MD-c, MD-e (DR-6, DR-7) |
| DR-z | The window runs on live services, the journey passes on live, and the blueprint says Library moves rejects to the Trash. | DR-9, DR-10 | J-DR1 | DR-u, DR-m |

DR-u waits only on DR-a and other features' slices (rule 18); DR-m never
waits on DR-u. MJ-DR is the Model walk in `LibraryDeleteRejectsTests` and
`LibraryLabelKeysTests` (Linux, on `FakeTrash`).

## Journey steps

1. Launch with the `shoot` fixture on live services in a scratch folder
   (`LibraryCullFinishJourneyTests.testDeleteRejects`): 24 photos, 3 rejected.
2. Select `IMG_0005` and press 7, then select three photos and press 9: the
   labels read Yellow, then Blue on all three; Undo once clears the three Blue.
   (With FC-b merged, click the Rejected chip to review the three rejects
   first; the journey skips this click until then.)
3. Photo > Delete Rejected Photos… (DR-3): the dialog reads "Move 3 rejected
   photos to the Trash?" with "You can put them back with Undo or from the
   Trash." and buttons Move to Trash (destructive) and Cancel. Cancel: nothing
   changes.
4. Again, Move to Trash: the grid shows 21 photos; the status line reads
   "Moved 3 photos to the Trash."; the files are gone from the folder.
5. Edit > Undo Delete Rejects: 24 photos, the three files back in the folder.
6. Redo, then File > Import Folder… on the same folder: "No new photos." (the
   three remembered paths are skipped).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L06 | closes with A5 | Cm | `Tests/RealJobs/library/delete-rejects/delete-rejects.jobs.json`: `photo.delete-rejects`, then the catalog file | `input/shoot.library` (four photos, `fog` and `pier` rejected) and `input/images/` (their four PNGs, copied to a scratch folder by the runner) |

Trap: the photos leave the catalog but stay on disk, or a later import brings
them back. Assertion: the output catalog lists `beach` and `dock` only, its
`excludedPaths` is `["images/fog.png", "images/pier.png"]`, and neither file
remains in the scratch `images/` folder. Mutations (the Model half, checked on
Linux by `LibraryDeleteRejectsTests` on `FakeTrash`):
`LibraryModel.LibraryDeleteRejects.json`, `!= .reject` for `== .reject` (the
keepers go) → `.onlyRejectsGo`; photos removed before the Trash answers (a
failed move loses the photo) → `.failedMoveKeepsPhoto`; and
`LibraryModel.LiveCatalogCoding.json`, `excludedPaths` not written →
`.excludedPathsSurviveSave`.

## Screens and states

`library-delete-rejects-confirm` (the dialog), `library-delete-rejects-done`
(21 photos, the status line), `library-delete-rejects-none` (the menu item
disabled with "No rejected photos in Keepers."), `library-label-keys` (the Set
Label menu naming 6–9), light and dark.

## Contract slice

```swift
// Sources/LibraryModel/Contracts/TrashContracts.swift (DR-1)
public protocol PhotoTrashing: Sendable {
    /// Moves the file at `path` to the Trash; returns where it went. Throws when it can't (missing, no rights).
    func moveToTrash(_ path: String) throws -> String
    /// Moves `trashed` back to `path`; throws when the Trash no longer has it or `path` is taken.
    func putBack(_ trashed: String, to path: String) throws
}
// Sources/LibraryModel/LibraryServices.swift (DR-1): one more member; `.fake` FakeTrash, `.live` LiveTrash.
public var trash: any PhotoTrashing
// Sources/LibraryModel/Live/LiveTrash.swift (DR-1 stub, every call throwing its `unavailable`; DR-8 body)
public struct LiveTrash: PhotoTrashing { public static var unavailable: String? }   // Linux: "Moving to the Trash needs macOS."
// Sources/LibraryModel/LibraryKeys.swift (DR-1): 6 red, 7 yellow, 8 green, 9 blue; purple has no key.
public enum LibraryKey { ...; case label(PhotoLabel) }
// Sources/LibraryModel/LibraryDeleteRejects.swift (DR-1 stubs, DR-6 bodies)
/// One photo a Delete Rejects step took out: where it sat and where its file went (nil: no file, a sample).
public struct TrashedPhoto: Hashable, Sendable { public var photo: PhotoItem; public var index: Int; public var trashedPath: String? }
extension LibraryCatalog {
    public var deleteRejectsTargets: [PhotoItem] { get }   // the selected collection's rejects, whatever the filter shows
    public var deleteRejectsTitle: String { get }          // "Delete 3 Rejected Photos…"
    public var deleteRejectsHelp: String? { get }          // "No rejected photos in Keepers."; the services' reason
    public var deleteRejectsMessage: String { get }        // the dialog's text, naming any the filter hides
    /// Trash every target, take the moved ones out as one "Delete Rejects" step; the status line says how many
    /// and names any it couldn't move, which stay in the catalog.
    public mutating func deleteRejects()
    public internal(set) var excludedPaths: Set<String>     // DR-6, stored in LibraryCatalog.swift
}
```

`photo.delete-rejects` (edit, "Delete Rejects", no params → `{moved, failed}`,
unavailable with `deleteRejectsHelp`) goes in `LibraryCommandCatalog` and
`Tests/command-ids/library.txt` (DR-7).

## Pseudocode

```
deleteRejects():                                                       # DR-6
  guard deleteRejectsHelp == nil
  moved = [], failed = []
  for p in deleteRejectsTargets (catalog order):
    guard let path = p.path else { moved += (p, index, nil); continue }   # a sample: catalog only
    do { moved += (p, index(p), try services.trash.moveToTrash(path)) } catch { failed += (p.name, reason) }
  guard !moved.isEmpty else { status = failed's first reason; return }
  items −= moved; excludedPaths ∪= moved paths
  record one step "Delete Rejects" with trashed = moved           # FC-3's step, one more defaulted field
  status = "Moved n photos to the Trash." + " Couldn't move IMG_4: <reason>." per failure
undo of a trashed step:                                                # DR-6, in LibraryUndoAdapter
  for t in trashed (ascending index):
    if let tp = t.trashedPath { do { try services.trash.putBack(tp, to: t.photo.path) } catch { note; continue } }
    items.insert(t.photo, at: min(t.index, items.count)); excludedPaths.remove(t.photo.path)
  the opposite step holds the photos that came back; redo trashes those again (new trashedPath)
import(folder): known = item paths ∪ excludedPaths                     # DR-6, LibraryImport
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DR-1 | – | `PhotoTrashing`, the services member, `FakeTrash` (a dictionary of moved paths, failures by path), the `LiveTrash` stub, `LibraryKey.label` and its characters, the catalog extension as stubs, `TrashedPhoto` | `Sources/LibraryModel/Contracts/TrashContracts.swift`, `Sources/LibraryModel/LibraryServices.swift`, `Sources/LibraryModel/Fakes/FakeTrash.swift`, `Sources/LibraryModel/Live/LiveTrash.swift`, `Sources/LibraryModel/LibraryKeys.swift`, `Sources/LibraryModel/LibraryDeleteRejects.swift` | filters-collections:FC-a, metadata-more:MD-a | ~220, 6 |
| DR-2 | – | Checks first, disabled by name: `LibraryDeleteRejectsTests`, `LibraryLabelKeysTests`, `LibraryNeverDeletesTests` (enabled: it passes today with its one allowed line, `CatalogStore`'s set-aside); RJ-L06's job folder with `waits_on: DR-8` | `Tests/LibraryModelTests/LibraryDeleteRejectsTests.swift`, `Tests/LibraryModelTests/LibraryLabelKeysTests.swift`, `Tests/LibraryModelTests/LibraryNeverDeletesTests.swift`, `Tests/RealJobs/library/delete-rejects/` | DR-1 | ~320, 9 |
| DR-3 | – | Reachable: Photo > Delete Rejected Photos… ⌘⌫ (its title and help from the Model), the `confirmationDialog` in `LibraryWindow+Trash`, mounted by the window; Set Label's items name 6–9 | `Sources/LibraryApp/LibraryWindow+Trash.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `Sources/LibraryApp/LibraryCommands.swift`, `Sources/LibraryApp/LibraryMenus.swift` | DR-1, metadata-more:MD-e | ~180, 4 |
| DR-4 | – | Snapshots, the render budget test, the journey written and skipped (`XCTSkip("waits on DR-9")`) | `Tests/AppSnapshotTests/LibraryCullFinishSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetLibraryDeleteRejectsTests.swift`, `UITests/LibraryJourneyTests+CullFinish.swift` | DR-3 | ~220, 3 |
| DR-5 | – | Label keys: `cullChange(for: .label)` is `.label`, one "Set Label" step on the targets, never moving the loupe (Auto Advance leaves labels alone); turns on `LibraryLabelKeysTests` | `Sources/LibraryModel/LibraryCulling.swift`, `Tests/LibraryModelTests/LibraryLabelKeysTests.swift`, `Tests/mutations/LibraryModel.LibraryCulling.json` | DR-2 | ~120, 3 |
| DR-6 | – | `deleteRejects` and its title, help and message; the trashed step and its undo and redo; `excludedPaths` stored and fed to import; turns on `LibraryDeleteRejectsTests` | `Sources/LibraryModel/LibraryDeleteRejects.swift`, `Sources/LibraryModel/LibraryUndoAdapter.swift`, `Sources/LibraryModel/LibraryCatalog.swift`, `Sources/LibraryModel/LibraryImport.swift`, `Tests/LibraryModelTests/LibraryDeleteRejectsTests.swift`, `Tests/mutations/LibraryModel.LibraryDeleteRejects.json` | DR-2, metadata-more:MD-e | ~360, 6 |
| DR-7 | – | The catalog file keeps `excludedPaths` (omitted when empty, so every golden stays byte-equal); `photo.delete-rejects` in the catalog and the id list | `Sources/LibraryModel/Live/LiveCatalogCoding.swift`, `Tests/mutations/LibraryModel.LiveCatalogCoding.json`, `Tests/LibraryModelTests/LibraryExcludedPathsCodingTests.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt` | DR-6, metadata-more:MD-c | ~200, 5 |
| DR-8 | – | `LiveTrash` on `FileManager.trashItem` and a move back (macOS; on Linux `unavailable`); turns on RJ-L06 | `Sources/LibraryModel/Live/LiveTrash.swift`, `Tests/LibraryModelTests/LiveTrashTests.swift`, `Tests/RealJobs/library/delete-rejects/` | DR-2, DR-7 | ~140, 3 |
| DR-9 | – | Live: the journey turned on, on live services in a scratch folder | `UITests/LibraryJourneyTests+CullFinish.swift` | DR-4, DR-5, DR-8 | ~60, 1 |
| DR-10 | – | library.md 1.3 says rejects go to the Trash, with undo, and 3 lists keys 6–9; the C4 part names the Trash service; `status: built`; `feature-done` | `docs/blueprints/library.md`, `docs/c4/parts/creative-apps/library-model/library-model-sources.json`, `docs/blueprints/library/features/cull-finish.wave.json` | DR-9 | ~40, 3 |

The packet PR lists the five new Library files in `library/c4-planned.json`
(its `every_source_file_owned` rule).

## Build waves

- Wave 1: DR-1. Independent in this wave: DR-1 alone.
- Wave 2: DR-2, DR-3. Independent in this wave: both.
- Wave 3: DR-4, DR-5, DR-6. Independent in this wave: all three.
- Wave 4: DR-7. Independent in this wave: DR-7 alone.
- Wave 5: DR-8. Independent in this wave: DR-8 alone.
- Wave 6: DR-9. Independent in this wave: DR-9 alone.
- Wave 7: DR-10 (shared prose, `feature-done`, final). Independent in this wave: DR-10 alone.

Longest chain: DR-1 → DR-2 → DR-6 → DR-7 → DR-8 → DR-9 → DR-10 (7). Chain of
7: the checks need the stubs, the step needs its checks, the file codes what
the step stores, the live Trash's job reads that file, the journey needs the
live Trash, DR-10 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DR-1 | builds; `LibraryKey(character: "6")` is `.label(.red)` and "5" still rates; every existing Library test passes | a key maps wrong, or a rating key changes | – (stubs) |
| DR-2 | the suites compile, disabled by name; `LibraryNeverDeletesTests` passes on today's sources, `CatalogStore`'s set-aside its only allowed hit | a source deletes outside that line | – (checks) |
| DR-3 | `LibraryCullFinishSnapshots.confirm` (DR-4's, first in the slice PR) | the item or the dialog is missing | – (UI) |
| DR-4 | `LibraryCullFinishSnapshots`; `RenderBudgetLibraryDeleteRejectsTests.deleteOf300InThreeBodies` | budget over | – (UI) |
| DR-5 | `LibraryLabelKeysTests`: 6, 7, 8, 9 set Red, Yellow, Green, Blue on the loupe photo, else the selection, one step each; a label key never moves the loupe with Auto Advance on; 0–5, P, X, U unchanged | a key sets the wrong label, two steps, or advances | `LibraryModel.LibraryCulling`: `.label` mapped to nil → `.sixIsRed`; label treated as a flag for Auto Advance → `.labelNeverAdvances` |
| DR-6 | `LibraryDeleteRejectsTests` on `FakeTrash`: the three rejects of `shoot` leave, the 21 others stay in order; one step "Delete Rejects"; undo puts the photos back at their indices and calls `putBack` for each, redo trashes them again; a failed move keeps that photo and names it; a failed put-back leaves it out and says so; a sample photo (no path) leaves the catalog without a Trash call; a collection holding no rejects disables it with its help; a re-import of the folder adds none of the trashed paths, and after undo they are known again | a keeper goes, a failure loses a photo, undo misses a file, or import brings a reject back | `LibraryModel.LibraryDeleteRejects`: `!= .reject` → `.onlyRejectsGo`; removed before the move answers → `.failedMoveKeepsPhoto`; excluded paths not fed to import → `.reimportSkipsTrashed`; undo restores photos without `putBack` → `.undoPutsFilesBack` |
| DR-7 | `LibraryExcludedPathsCodingTests`: a catalog with excluded paths round-trips; with none, every existing golden is byte-equal; `photo.delete-rejects` is listed with its availability | a path is lost on save, or old files change | `LibraryModel.LiveCatalogCoding`: `excludedPaths` not written → `.excludedPathsSurviveSave`; written when empty → `.goldensUnchanged` |
| DR-8 | `LiveTrashTests` (macOS; skipped on Linux with the reason): a scratch file moves to the Trash and back to its path; a missing file throws; a taken path refuses the put-back; RJ-L06 passes on macOS | a file is deleted rather than moved, or put back over another | – (macOS service; the Model's mutations are DR-6's) |
| DR-9 | `LibraryCullFinishJourneyTests.testDeleteRejects` steps 1 to 6 | a step fails | – |
| DR-10 | `scripts/waves render --dry-run`; `scripts/ci` (C4 assembles) | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Delete Rejects of 300 rejects in a 10,000-photo catalog | ≤ 3 window bodies; the moves off the main actor's frame budget (one status update at the end) | `RenderBudgetLibraryDeleteRejectsTests.deleteOf300InThreeBodies` |
| Model cost | `deleteRejects` of 300 on `large` with `FakeTrash` ≤ 50 ms debug | `LibraryDeleteRejectsTests.largeBudget` |
| Never permanent | no `removeItem`, `unlink` or Trash-emptying call in Library | `LibraryNeverDeletesTests` |
| One gesture, one step | a label key, a Delete Rejects | `LibraryLabelKeysTests`, `LibraryDeleteRejectsTests` |
| No dead controls | Delete Rejected Photos… in `library.controls`, disabled with its reason | `testDeleteRejects` |
| Keyboard parity | ⌘⌫ opens the dialog; Return is Cancel, not Move to Trash | `testDeleteRejects` step 3 |
| Audit | zero new over Library's baseline | `audit-library-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DR-m merged-done on the Linux job with
`Mutate:` clean (the Model half of RJ-L06 is `LibraryDeleteRejectsTests`);
DR-u's feel gate and `Mac-Finish:`; DR-z's journey on live and RJ-L06 green in
the scoped run (`Cm`). Then `Belt-Contact-Sheet:` with
`library-delete-rejects-*` and `library-label-keys`.

## Not in this packet

A5's "full screen" (the window's own Enter Full Screen ⌃⌘F already works; a
chrome-free loupe is its own small packet), pressing a label key again to clear
the label (Set Label > None clears; the toggle needs the window's key route,
which metadata-more owns), a Purple key, forgetting a remembered path (a later
"Show Excluded" list), deleting from disk for good (never), filters (#1563).
