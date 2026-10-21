# Feature packet: folders

**Feature:** after three imports, everything no longer sits in one pile. The
sidebar gains a **FOLDERS** section: the folders photos were imported from, as
a tree rooted at each import's top folder, each row with its photo count and
a disclosure for subfolders. Clicking a folder shows its photos; "Include
Subfolders" (on by default, in the section's menu) decides whether children's
photos show too. A folder whose files are all missing shows the missing badge.
The tree is derived from the catalog's paths (no new catalog field), so every
existing catalog shows its folders at once. Every action is a catalog command
(`view.show-folder {path, subfolders}`, `folders.list`).
**Line:** `line:library` · **Wave:** 7 (`waves.md`) · **Lead branch:** `lead/folders`
**Beta:** captain, 2026-10-21 (beta gaps, Library must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` Library must-have "folders in the
sidebar"; Library audit row 6; feature map A6 (folders; the date browse is
later); RJ-L53 (new).

**Depends on:** spine (building), import (built). filters-collections (wave 5,
planned) owns the sidebar's collections section and `LibraryFilter`; FO-u waits
on its FC-a and FO-m on its FC-d.

**Rule 20.** The sidebar rows are SuiteUI's (`SidebarSection`, `SidebarRow`,
the disclosure `SuiteSidebarList` already draws); the folder tree is a pure
function over paths in `LibraryFolders.swift`; the filter is one more case of
the existing `LibraryFilter`, not a second filter.

**C4:** the new files join `c4-planned.json`'s "Later model" and "Browse
views" components (this PR).

**Clean-room.** Behaviour from the audit and Library's blueprint.

Blueprint sections: library.md 3 (sidebar), 5 (filters).

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (clipboard-interop CB-library, orientation-crop OC-library-m) also edit `LibraryCommandCatalog.swift` and `Tests/command-ids/library.txt`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FO-a | Library declares the folder tree and the folder filter case as stubs, with the Model checks written and disabled. | FO-1, FO-2 | MJ-FO | – |
| FO-u | The sidebar shows a FOLDERS section with a disclosure tree and counts on the stubs, clicking a row selects it, every row identified and within the render budget. | FO-3, FO-3b | LJ-FO | FO-a; filters-collections:FC-a (`LibraryBrowser.swift`) |
| FO-m | The tree comes from the catalog's paths with correct counts, the folder filter shows a folder's photos with or without its subfolders, and both commands run headless. | FO-4, FO-5 | MJ-FO | FO-a; filters-collections:FC-d (`LibraryFilter.swift`); file-flow:LF-m and catalog-files:LC-m (the catalog and ledger) |
| FO-z | The FOLDERS section runs live end to end, RJ-L53 passes, and the feature is built. | FO-6, FO-7 | LJ-FO, MJ-FO | FO-u, FO-m |

**Screen early.** FO-u builds the real section on FO-a's stubs, beside FO-m.

## Journey steps

`MJ-FO` on Linux (`LibraryFoldersTests`), then:
1. Import three fixture folders (one with subfolders); FOLDERS shows three roots with counts; expand one; click a subfolder: the grid shows its photos; turn Include Subfolders off on the root: only its own photos (FO-3, FO-6; `LJ-FO`, `LibraryFoldersJourneyTests.testBrowseFolders`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L53 | adds, closes with `library/folders` | C | `Tests/RealJobs/library/browse-folders/`: import `trips/` (with `2025/` and `2026/` inside) and `family/`, `folders.list`, `view.show-folder` `trips/2025`, then `trips` without subfolders | generated folders |

Trap: a folder named like a prefix of another (`trip` and `trips`) shows the
other's photos, or the counts include subfolders twice. Assertion: each
`view.show-folder` lists exactly the expected file names, and `folders.list`'s
counts match the files on disk. Mutation: `LibraryModel.LibraryFolders`
(`.siblingNotChild`). FO-2 writes it; FO-6 enables it.

## Screens and states

`library-sidebar-folders` (three roots, one expanded), `library-folder-selected`.

## Contract slice

```swift
// Sources/LibraryModel/LibraryFolders.swift (FO-1 stub, FO-4 body). Linux-safe.
public struct FolderNode: Hashable, Sendable, Identifiable {
    public var id: String { path }
    public var path: String; public var name: String
    public var ownCount: Int; public var totalCount: Int; public var allMissing: Bool
    public var children: [FolderNode]
}
public enum LibraryFolders { public static func tree(_ photos: [PhotoItem]) -> [FolderNode] }
// Sources/LibraryModel/LibraryFilter.swift (FO-5): one new case
//   case folder(path: String, subfolders: Bool)
```

| id | title | params | unavailable when |
|---|---|---|---|
| `folders.list` | – (query) | – → the tree | an empty catalog |
| `view.show-folder` | – (view state, not an undo step) | `{path, subfolders?}` | an unknown path |

## Pseudocode

- **Tree.** Parent folder of every photo; insert into a trie keyed by path
  components; roots are the import roots (the catalog's import records), else
  the shallowest folders; collapse a chain of folders that hold no photos and
  one child each into one row named `a/b/c`.
- **Filter.** `subfolders` true: `path == folder || path.hasPrefix(folder + "/")`;
  false: the photo's parent equals the folder.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FO-1 | – | **Checks first.** `LibraryFoldersTests` written, disabled (`waits on FO-4`); `FolderNode` and `LibraryFolders.tree(paths:)` stubs; the `view.show-folder` and `folders.list` specs in `LibraryFolders+Kernel.swift` with real ids and schemas, runs throwing `NotBuilt` | `Sources/LibraryModel/LibraryFolders.swift`, `Sources/LibraryModel/LibraryFolders+Kernel.swift`, `Tests/LibraryModelTests/LibraryFoldersTests.swift` | – | ~170, 3 |
| FO-2 | – | `LibraryFoldersJourneyTests` written, skipped until FO-6; RJ-L53's job folder, disabled | `UITests/LibraryJourneyTests+Folders.swift`, `Tests/RealJobs/library/browse-folders/browse-folders.jobs.json` | FO-1 | ~90, 2 |
| FO-3 | – | **Reachable first.** The FOLDERS section under the collections in `LibraryBrowser`'s sidebar (SuiteUI rows with disclosure), its menu with Include Subfolders; a click runs `view.show-folder` (unavailable on the stubs with "Folders arrive with FO-4.") | `Sources/LibraryApp/LibraryBrowser.swift`, `Sources/LibraryApp/LibraryFoldersSection.swift` | FO-1 | ~170, 2 |
| FO-3b | – | Render budget test: expand and collapse a folder at 10,000 photos | `Tests/AppSnapshotTests/RenderBudgetLibraryFoldersTests.swift` | FO-3 | ~70, 1 |
| FO-4 | – | `LibraryFolders.tree` body: group paths by parent folder, collapse single-child chains under each import root, count photos (own and with descendants), mark all-missing folders; turns on `LibraryFoldersTests` | `Sources/LibraryModel/LibraryFolders.swift`, `Tests/LibraryModelTests/LibraryFoldersTests.swift`, `Tests/mutations/LibraryModel.LibraryFolders.json` | FO-1 | ~160, 3 |
| FO-5 | – | The filter case `.folder(path, subfolders)` in `LibraryFilter`; `view.show-folder` and `folders.list` bodies; the catalog appends the specs; ids in the ledger | `Sources/LibraryModel/LibraryFilter.swift`, `Sources/LibraryModel/LibraryFolders+Kernel.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/mutations/LibraryModel.LibraryFolders+Kernel.json` | FO-4 | ~150, 5 |
| FO-6 | – | The section on live: the tree from the catalog, the click filters the grid, the journey on, RJ-L53 enabled | `Sources/LibraryApp/LibraryFoldersSection.swift`, `UITests/LibraryJourneyTests+Folders.swift`, `Tests/RealJobs/library/browse-folders/browse-folders.jobs.json` | FO-3, FO-5, FO-2 | ~120, 3 |
| FO-7 | – | `status: built`; `feature-done` | `docs/blueprints/library/features/folders.wave.json` | FO-6 | ~10, 1 |

## Build waves

- Wave 1: FO-1. Independent in this wave: FO-1 alone.
- Wave 2: FO-2, FO-3, FO-4. Independent in this wave: all.
- Wave 3: FO-3b, FO-5. Independent in this wave: both.
- Wave 4: FO-6. Independent in this wave: FO-6 alone.
- Wave 5: FO-7. Independent in this wave: FO-7 alone.

Longest chain: FO-1 → FO-4 → FO-5 → FO-6 → FO-7 (5). Chain of 5: the stubs, the tree, the filter and commands, the live section, the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FO-1 | compiles, disabled by name | a signature the sidebar calls is missing | – (stubs) |
| FO-2 | `scripts/jobs check` | the job names a missing command | – (tests) |
| FO-3 | rows carry `library.folder.<path-hash>` ids; the menu item toggles | a row has no id or command | – (view; render budget row) |
| FO-3b | `RenderBudgetLibraryFoldersTests.expandFolderInTwoBodies` | expanding re-renders the grid | – (budget) |
| FO-4 | `LibraryFoldersTests`: 3 imports give 3 roots; `/a/b/c` with photos only in `c` shows `a/b/c` as one row; counts with and without descendants; `/a/bc` is not a child of `/a/b` | a count is off or a sibling counts as a child | `LibraryModel.LibraryFolders`: prefix test without a slash → `.siblingNotChild`; descendant count used for own count → `.ownCountExact` |
| FO-5 | `LibraryFoldersTests.filter`: a folder with subfolders off shows only its own photos; with it on, its descendants' too; `folders.list` matches the tree | the filter leaks other folders' photos | `LibraryModel.LibraryFolders+Kernel`: subfolder flag ignored → `.subfoldersToggle` |
| FO-6 | `LJ-FO`; RJ-L53 on Linux | the grid doesn't follow the click | – (window wiring) |
| FO-7 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: expand a folder at 10,000 photos | ≤ 2 window bodies | `RenderBudgetLibraryFoldersTests.expandFolderInTwoBodies` |
| tree speed | `tree` of 10,000 paths under 20 ms | `LibraryFoldersTests.tenThousandPaths` |
| no dead controls | each row and the menu run commands | `CommandPathTests` |
| keyboard parity | arrow keys move in the tree, → expands | `LibraryFoldersJourneyTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): FO-a and FO-m green on Linux with
`Mutate:` clean; FO-u and FO-z through the feel gate (`mouse`) with their
`Mac-Finish:` lines; RJ-L53 green on Linux. Then `Belt-Contact-Sheet:`.
