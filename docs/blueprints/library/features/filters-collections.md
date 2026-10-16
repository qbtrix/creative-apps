# Feature packet: filters-collections

**Feature:** a filter bar over the grid narrows any collection by flag, by
rating (at least or exactly N) and by hiding rejects, and always says how
many photos it shows; collections you make take the selection through the
menu or a drag onto the sidebar; a smart collection is a saved filter that
fills itself as you cull. The filter, your collections and their rules are
there after a relaunch. Every collection change is one named undo step, and
a collection never deletes or moves a photo.
**Line:** `line:library` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/filters-collections`

**Covers:** #31 (closes with FC-16; FC-7, FC-9 and FC-12 say `Part of #31`).

**Depends on:** the feature issues of cull (`cullTargets`, Auto Advance
through a filter), persist (the catalog folder, `catalogState.canSave`,
the `library.catalog` marker J16 waits on), thumbnails (owns
`LibraryGrid.swift` in wave 2) and import (owns `LibraryBrowser.swift` in
wave 2), plus status-and-layout and export: wave 5 starts after v1
(blueprint 8.3), and their slices edit `LibraryWindow.swift`, the blueprint
and the C4 parts this feature edits too (export depends on develop, so
develop is covered). No creative-core issue: filtering, counting and the collections
file are plain Model code over `PhotoItem`. SuiteUI issues to file (6.4
style), `needs-ui`, `line:suiteui`:

- **S-L9, drag the grid selection onto a sidebar row.** `ThumbnailGrid`:
  a cell drag carries the selected ids (or the dragged cell's id when it
  isn't selected) as `String`s. `SuiteWindow` sections init and
  `SuiteSidebarList`: `onDrop: (@MainActor (SidebarItem.ID, [String]) -> Bool)?`
  and `canDrop: (SidebarItem.ID) -> Bool`, with the row highlighted while a
  drop it accepts hovers. Acceptance: a SuiteUI test drags two ids onto a row
  and receives them; a row that can't take a drop never highlights. Only
  FC-10 waits on it.
- **S-L10, rename only some rows.** `SidebarItem.isRenamable` (default
  true). Until it lands, a double-click on All Photos opens the field and the
  Model ignores the new name (the row reverts). Nothing waits on it.

Blueprint sections: 2.2 (`library-later`), 2.3 (`library-app-later`), 3
(tier 2 rows 1 and 4, tier 3 row 1), 4.1 (fixtures, launch arguments,
values), 5.3 (`PhotoCulling.advance`, the filter case), 5.6 (stored state),
6.2 (menu bar), 7.1 (QB-LIB-3, QB-LIB-4), 8.3 (wave 5).

**Spine files this feature takes in wave 5.** The spine declared every v1
stored property; a filter and your collections are new state, so FC-2 adds
them to `LibraryCatalog.swift` (and hooks `shownItems`, `recount`, `==`),
makes `editCanReorder` in `LibraryOrder.swift` true under a filter, and FC-3
lets `CatalogHistory.swift` carry a collection change. These are the only
edits to spine files besides the shell's (`LibraryWindow.swift`,
`LibraryCommands.swift`), which the blueprint already gives this feature.
`LibraryMenus.swift` is not touched: the feature publishes its own focused
value, `\.libraryFilters`.

**Every new source file has a C4 owner.** `c4-planned.json` plans exactly
`LibraryFilter.swift`, `LibraryCollections.swift`, `LibraryWindow+Filters.swift`
and the `Platform/` folder for this feature, so the filter bar view, every
menu closure and the save hooks live in `LibraryWindow+Filters.swift`, the
collections file's I/O in `Platform/CollectionsStore.swift`. That one area
file is why the macOS wiring is a single contract task (FC-4) and the
behavior slices change only Model code and tests.

**What it fixes (most used first).** Clean-room: behavior described from
what people ask of any photo catalog, no other app opened or copied.

1. *A filter hides photos and nothing says so.* The bar always shows its
   rules and "3 of 24"; a filter that hides everything gives "No Matching
   Photos" with **Clear Filter**, never an empty grid.
2. *Rejects clutter the grid after culling.* **Hide Rejected** is one click
   in the bar and one menu item, and it stays on across collections.
3. *Rating inside a filter loses your place.* When a change hides the photo,
   the loupe moves to the photo that took its place (cull's Auto Advance
   rule), and Undo brings the photo back.
4. *The filter is gone after a relaunch.* The filter, your collections and
   the selected collection are saved beside the catalog.
5. *Deleting a collection feels like deleting photos.* It never does; its
   help says so and it is one undo step.
6. *Smart rules are hidden in a dialog.* A smart collection's rules are the
   filter bar itself while it is selected.

**From the future.** Save the current filter as a smart collection in one
command, named after its rules; smart counts follow every rating as you cull;
the bar's summary ("At least 3 stars, Rejects hidden; 3 of 24") is also
what VoiceOver reads.

## Slices

A slice is the unit of done (`lead.md` contract rule 6). FC-a is Linux plus
the macOS wiring every other slice lights up; FC-b to FC-e change Model code
and tests only, except FC-10's drag and FC-15's file I/O.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FC-a | With no filter and no collection of yours Library behaves exactly as today, while the filter and collection state, the undo of a collection change, every catalog method, the filter bar, the sidebar's Collections section and every new menu item exist, each control disabled with "… isn't built yet (filters-collections)." | FC-1, FC-2, FC-3, FC-4, FC-5 | MJ1 | features cull, persist, thumbnails, import, status-and-layout, export |
| FC-b | The filter bar narrows any collection by flag, by rating at least or exactly N, and by hiding rejects, shows "N of M", and says so with Clear Filter when nothing matches. | FC-6, FC-7 | J13 | FC-a (FC-6, FC-7) |
| FC-c | New Collection takes the selection, Photo > Add to Collection, Remove from Collection, rename and delete each record one undo step, and dragging the selection onto a sidebar row adds it. | FC-8, FC-9, FC-10 | J14 | FC-a (FC-8, FC-9, FC-10); S-L9 (FC-10) |
| FC-d | New Smart Collection from Filter saves the filter as a collection whose count follows every rating, and while it is selected the filter bar edits its rules as one undo step each. | FC-11, FC-12 | J15 | FC-a (FC-11, FC-12); FC-b (FC-12) |
| FC-e | Your collections, their rules, the filter and the selected collection survive a relaunch, and a damaged collections file is set aside with a notice, never overwritten. | FC-13, FC-14, FC-15, FC-16 | J16 | FC-a (FC-13, FC-15); FC-c (FC-14, FC-16); FC-b, FC-d (FC-16) |

## Journey steps

Ids continue the blueprint's J0 to J12. Each journey is its own
`XCTestCase` class in its own file (#333 merged: the template compiles
`UITests/LibraryJourneyTests+*.swift`). Every step takes a shot.
**(F)** passes on fakes, **(L)** live on `LibraryFiles.writeShoot` with
`-LibraryImportOnLaunch`. Identifiers: the bar `library.filter` (its value
`filterValue`), chips `library.filter.flag.pick`, `.none`, `.reject`, the
rating menu `library.filter.rating`, `library.filter.hideRejected`,
`library.filter.label`, `library.filter.clear`; the hidden element
`library.collections` whose label is `collectionsFileValue`.

**MJ1 · `LibraryCollectionsSeamTests.testSeamsWalk`** (FC-2, Linux): on
`shoot` with `.all` and no collections of yours, `order`, every count and
`==` equal a catalog built without this feature; with `filter.hidesRejected`
set, rejecting `IMG_0004` through `setFlag` drops it from `order` (a rebuild
under a filter); a `UserCollection` "user-1" of three ids (set through
`@testable`) adds a sidebar row with count 3 and `selectCollection("user-1")`
shows three; removing it falls back to All Photos.

**J13 · `LibraryFiltersJourneyTests.testFilterByFlagAndRating`**
(`UITests/LibraryJourneyTests+Filters.swift`, FC-6 writes it, FC-7 enables
it; all steps F and L)
1. Launch on `shoot`; View > Sort By > Name; double-click `IMG_0001`; press
   5, 3, P, X, 3, P (Auto Advance: `IMG_0001` 5 stars, `IMG_0002` 3 stars,
   `IMG_0003` Picked, `IMG_0004` Rejected, `IMG_0005` 3 stars, `IMG_0006`
   Picked); Escape. Expect `library.filter` = "All photos; 24 of 24".
2. Click Hide Rejected. Shot `filter-no-rejects`. Expect "Rejects hidden; 23
   of 24", no `IMG_0004` cell, All Photos still counts 24.
3. Rating > At Least 3 Stars. Shot `filter-rating`. Expect "At least 3 stars,
   Rejects hidden; 3 of 24" and the cells `IMG_0001`, `IMG_0002`, `IMG_0005`.
4. Rating > Exactly 3 Stars. Expect `IMG_0002`, `IMG_0005`.
5. Rating > Any Rating; click Picked. Expect "Picked, Rejects hidden; 2 of
   24": `IMG_0003`, `IMG_0006`.
6. (L: the fakes' Auto Advance has no filter case, blueprint 5.4 and Q7)
   Double-click `IMG_0003`; press U. Expect the loupe on `IMG_0006` ("1 of
   1"). Press U. Shot `filter-empty`. Expect the grid with "No Matching
   Photos" and **Clear Filter**. Edit > Undo twice ("Undo Clear Flag"):
   two cells again.
7. Click Favorites. Expect the filter still on: "Picked, Rejects hidden; 2
   of 2".
8. View > Filter > Clear Filter; All Photos. Expect "All photos; 24 of 24".
   View > Filter > Hide Rejected. Expect "Rejects hidden; 23 of 24".
States: filtered; filtered to nothing (No Matching Photos, Clear Filter);
unfiltered. With no photos the bar's controls are disabled with "Import or
load photos to filter them."

**J14 · `LibraryCollectionsJourneyTests.testMakeACollection`**
(`UITests/LibraryJourneyTests+Collections.swift`, FC-8 writes it, FC-9
enables steps 1 to 6, FC-10 step 7; F and L)
1. Launch on `shoot`; sort by Name; Edit > Deselect; File > New Collection
   (⌘N). Shot `collection-empty`. Expect a row "Untitled Collection" in the
   sidebar's Collections section, selected, count 0, the empty state "No
   Photos in Untitled Collection" with Show All Photos; Undo reads "Undo New
   Collection". Undo: the row is gone and All Photos is selected.
2. Click `IMG_0001`, Shift-click `IMG_0003`; File > New Collection. Expect
   "Untitled Collection", count 3, selected, three cells.
3. Double-click the row, type "Keepers", Return. Expect "Keepers"; Undo
   reads "Undo Rename Collection".
4. All Photos; click `IMG_0010`; Photo > Add to Collection > Keepers. Expect
   Keepers 4, Undo "Undo Add to Collection", and Photo > Add to Collection >
   Keepers now disabled with "Every selected photo is already in Keepers."
5. Keepers; click `IMG_0002`; Photo > Remove from Collection (⌘⌫). Shot
   `collection-removed`. Expect three cells, Keepers 3, All Photos 24, Undo
   "Undo Remove from Collection".
6. File > Delete Collection. Expect no Keepers row, All Photos selected with
   24; Undo ("Undo Delete Collection"): Keepers is back with 3.
7. (waits on FC-10, so the last step; `XCTSkip("waits on FC-10")` until
   then) All Photos; select `IMG_0020` and `IMG_0021`; drag them onto
   Keepers. Shot `collection-dropped`. Expect Keepers 5 and one step "Undo
   Add to Collection".
States: empty collection; Add disabled with a reason.

**J15 · `LibrarySmartJourneyTests.testSmartCollectionFromFilter`**
(`UITests/LibraryJourneyTests+Smart.swift`, FC-11 writes it, FC-12 enables
it; F and L)
1. Launch on `shoot`; sort by Name; loupe on `IMG_0001`; press 5, 4, 2;
   Escape.
2. Rating > At Least 4 Stars; File > New Smart Collection from Filter
   (⌥⌘N). Shot `smart-new`. Expect a row "At least 4 stars" in Collections,
   count 2, selected; the bar's caption "Rules of At least 4 stars" and value
   "At least 4 stars; 2 of 24"; Undo "Undo New Smart Collection".
3. All Photos (its own filter is still At least 4 stars); View > Filter >
   Clear Filter; click `IMG_0003`; press 5. Expect the smart row's count 3.
4. Click the smart row; Rating > Exactly 5 Stars. Expect `IMG_0001` and
   `IMG_0003`, the row's count 2, its name unchanged, Undo "Undo Edit Rules".
5. Undo. Expect three cells again.
6. Rating > Exactly 1 Star. Shot `smart-empty`. Expect "No Photos in At
   least 4 stars" with "Photos that match this collection's rules appear
   here. Change the rules in the filter bar." and Show All Photos.
States: smart collection with nothing matching.

**J16 · `LibraryCollectionsFileJourneyTests.testCollectionsSurviveRelaunch`**
(`UITests/LibraryJourneyTests+CollectionsFile.swift`, FC-13 writes it, FC-14
enables it)
1. (F) Launch on `shoot` with a fresh `-LibraryCatalogDir`; sort by Name;
   select `IMG_0001`–`IMG_0003`; New Collection; rename "Keepers"; click
   Hide Rejected.
2. (F) Wait for `library.collections` = `saved`; terminate; relaunch with
   the same arguments. Shot `collections-relaunched`. Expect Keepers
   selected, count 3, the bar "Rejects hidden; 3 of 3".
3. (F) Write `not json` over `collections.json`; relaunch. Shot
   `collections-damaged`. Expect no Collections rows, All Photos selected,
   the notice "Library couldn't read your collections. The file was set aside
   as collections.json.bad.", and `collections.json.bad` holds `not json`.
4. (L) Live with a fresh catalog folder: Keepers of `IMG_0001`–`IMG_0003`;
   wait for `library.catalog` and `library.collections` both `saved`;
   relaunch without import. Expect Keepers 3 (persist restored the photos,
   this file the membership).
States: error (damaged collections file).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Filter bar (top of the content, above the notice slot) | no photos: every control disabled, "Import or load photos to filter them." | – | – |
| Grid under a filter | "No Matching Photos", "No photos in <collection> match <summary>.", **Clear Filter** | – | – |
| Sidebar, Collections section | the section header with its New Collection (+) button and no rows | – | – |
| A collection you made | "No Photos in <name>", "Select photos in All Photos, then choose Photo > Add to Collection or drag them here.", Show All Photos | – | – |
| A smart collection | "No Photos in <name>", "Photos that match this collection's rules appear here. Change the rules in the filter bar.", Show All Photos | – | – |
| Content notice slot | – | the collections file was damaged or newer: set aside, notice (warning) | – (the file is read before the first frame that shows the sidebar) |

Snapshots, Light and Dark: `LibraryFilterSnapshots.swift` `library-filter-off`,
`library-filter-on`, `library-filter-empty` (FC-6);
`LibraryCollectionsSnapshots.swift` `library-collections-sidebar`,
`library-collection-empty` (FC-8); `LibrarySmartSnapshots.swift`
`library-smart-selected`, `library-smart-empty` (FC-11);
`LibraryCollectionsNoticeSnapshots.swift` `library-collections-damaged`
(FC-13). FC-5 redraws every Library window snapshot (the bar and the
sidebar's two sections); its PR lists them.

## Contract slice

All Model code is Linux-safe; stored state is `public internal(set)` (D6).
FC-1, in `LibraryFilter.swift`:

```swift
public enum RatingRule: Hashable, Sendable {
    case any, atLeast(Int), exactly(Int)          // atLeast 1...5; exactly 0...5 (0: unrated)
    public func admits(_ stars: Int) -> Bool
    public var title: String                      // "Any Rating", "At Least 3 Stars", "Exactly 1 Star", "Unrated"
}
public struct LibraryFilter: Hashable, Sendable {
    public var flags: Set<PhotoFlag> = []         // empty: any flag
    public var rating = RatingRule.any
    public var labels: Set<PhotoLabel> = []       // empty: any label or none
    public var hidesRejected = false
    public static let all = LibraryFilter()
    public var isActive: Bool { self != .all }
    public func matches(_ photo: PhotoItem) -> Bool
    /// "All photos" when off; else flags ("Picked or Unflagged"), rating
    /// ("At least 3 stars", "Exactly 1 star", "Unrated"), labels ("Red or
    /// Blue"), "Rejects hidden", joined by ", ".
    public var summary: String { get }
}
```

FC-2: the stored state (`LibraryCatalog.swift`) and every catalog method of
the feature with a stub body, so the checks of FC-b to FC-e compile before
their code. `LibraryCollections.swift`:

```swift
public struct UserCollection: Identifiable, Hashable, Sendable {
    public enum Contents: Hashable, Sendable { case photos(Set<String>), rules(LibraryFilter) }
    public let id: String                         // "user-<n>" or "smart-<n>", never reused while it exists
    public internal(set) var name: String
    public internal(set) var contents: Contents
    public var isSmart: Bool { get }
    public static func isUserID(_ id: String) -> Bool   // either prefix
    /// Set to nil by the task that builds each part (FC-9, FC-12, FC-14).
    public static let unavailable: String? = "Collections aren't built yet (filters-collections)."
    public static let smartUnavailable: String? = "Smart collections aren't built yet (filters-collections)."
    public static let fileUnavailable: String? = "Saving collections isn't built yet (filters-collections)."
}
// LibraryCatalog, stored (FC-2):
//   filter = LibraryFilter.all               the bar's filter outside smart collections
//   userCollections: [UserCollection] = []   sidebar order
//   collectionsRevision = 0, collectionsSavedRevision = 0
//   collectionsNotice: String?               the damaged-file notice
extension LibraryCatalog {
    public var selectedUserCollection: UserCollection? { get }
    @discardableResult public mutating func newCollection() -> String   // with cullTargets; "New Collection"
    public mutating func renameCollection(_ id: String, to name: String) // "Rename Collection"; built-ins ignored
    public mutating func add(_ ids: Set<String>, to id: String)         // "Add to Collection" (menu and drop)
    public mutating func addToCollection(_ id: String)                  // add(cullTargets, to: id)
    public mutating func removeFromCollection()                         // "Remove from Collection"
    public mutating func deleteCollection(_ id: String)                 // "Delete Collection"
    public func addToCollectionHelp(_ id: String) -> String?
    public var removeFromCollectionHelp: String? { get }
    public var deleteCollectionHelp: String? { get }
    // the collections file (FC-14)
    public func collectionsSaveRequest() -> (revision: Int, data: Data)?
    public mutating func didSaveCollections(revision: Int)
    public mutating func restoreCollections(_ data: Data?) throws       // LibraryError.damagedCatalog / .newerCatalog
    public mutating func failRestoreCollections(setAsideAs name: String)
    public var collectionsFileValue: String { get }                     // "saved" or "dirty"
    /// Rebuilds `order`, keeps the selection to what is shown, and leaves a
    /// loupe whose photo is hidden for the grid (#156). FC-2, real code.
    mutating func refreshShown()
}
```

FC-2, in `LibraryFilter.swift` (stubs filled by FC-7, smart by FC-12):

```swift
extension LibraryFilter {
    /// Set to nil by FC-7.
    public static let unavailable: String? = "Filters aren't built yet (filters-collections)."
}
extension LibraryCatalog {
    public var activeFilter: LibraryFilter { get }       // the selected smart collection's rules, else `filter`
    public mutating func setFilter(_ filter: LibraryFilter)   // smart selected: one "Edit Rules" step
    public mutating func toggleFilterFlag(_ flag: PhotoFlag)
    public mutating func setRatingRule(_ rule: RatingRule)
    public mutating func toggleFilterLabel(_ label: PhotoLabel)
    public mutating func toggleHideRejected()
    public mutating func clearFilter()
    public var filterHelp: String? { get }               // LibraryFilter.unavailable, else "Import or load photos to filter them."
    public var clearFilterHelp: String? { get }          // "No filter is on."
    public var filterValue: String { get }               // "<summary>; <shown> of <in the collection>"
    public var filterCaption: String? { get }            // "Rules of <name>" while a smart collection is selected
    public var isHiddenByFilter: Bool { get }            // a non-smart collection has photos, the filter shows none
    @discardableResult public mutating func newSmartCollection() -> String?   // "New Smart Collection"
    public var newSmartCollectionHelp: String? { get }
}
```

`shownItems` becomes the collection's photos (a `photos` set for yours,
every photo for a smart one) passed through `activeFilter`; `recount` builds
`collections` as the three built-ins plus one `LibraryCollection` per
`UserCollection` (count before the bar's filter) and falls back to All
Photos when the selected one is gone; `editCanReorder` is also true when
`activeFilter.isActive` or the selected collection is yours. Filter changes
are view state like the sort: no undo step, but `collectionsRevision += 1`.

FC-3, in `CatalogHistory.swift`: `Step` gains `collectionsBefore` and
`collectionsAfter: [UserCollection]?` (defaulted nil, so every caller
compiles), and

```swift
extension LibraryCatalog {
    /// Applies `edit` to `userCollections` as the step `name`; a no-op
    /// records nothing; collectionsRevision += 1.
    mutating func recordCollectionsEdit(_ name: String, _ edit: (inout [UserCollection]) -> Void)
}
```

Undo and redo put `collectionsBefore` / `collectionsAfter` back before the
photos and never move the loupe.

FC-4, in `LibraryWindow+Filters.swift`: `struct LibraryFiltersMenu` (every
filter, collection and smart action as an optional closure, plus titles and
the per-collection Add items), `@Entry var libraryFilters:
LibraryFiltersMenu?` on `FocusedValues`, the filter bar view
`LibraryFilterBar` (`ChipRow` for Picked, Unflagged, Rejected; a `Menu` for
the rating; a `Toggle` for Hide Rejected; a `Menu` for labels; the value
text and Clear), the area hooks `filtersAreaLaunch()`,
`filtersAreaChanged()`, `filtersAreaFlush()`, and `FiltersAreaState`
(the debounce). Every closure is built from the Model: `enabled(help == nil)`,
so the controls light up when a slice sets its `unavailable` to nil, with no
further app edit. `Platform/CollectionsStore.swift` is a stub that throws
"The collections file isn't built yet (filters-collections)." FC-5 mounts
it all: `LibraryWindow.swift` switches to the `sections:` init (Library:
All Photos, Favorites, Recently Added; Collections: yours, with New Collection
as the section's `addAction` and `onRename`), puts the bar above
`LibraryBrowser`, publishes `\.libraryFilters`, the `library.collections`
element and the hooks; `LibraryCommands.swift` adds the items below;
`LibraryBrowser.swift` shows "No Matching Photos" when `isHiddenByFilter`
(before the empty-collection branch) and `collectionsNotice` in the notice
slot.

**Menu items** (FC-5; each disabled with its Model help):

- **File:** New Collection ⌘N, New Smart Collection from Filter ⌥⌘N, Delete
  Collection (help "Deleting a collection never removes its photos.").
- **Photo:** Add to Collection ▸ (one item per collection you made, not
  smart), Remove from Collection ⌘⌫.
- **View:** Filter ▸ Picked, Unflagged, Rejected (checkmarks); Rating ▸;
  Label ▸; Hide Rejected; Clear Filter.

**The collections file.** Persist's `catalog.json` is photos only
(`CatalogCoding.encode(_ photos:)`, a byte-equal golden), so this feature
keeps its state beside it as `collections.json` in the same folder
(`-LibraryCatalogDir` or Application Support/Library), never changing
persist's contract or bytes. One object, sorted keys, pretty, no escaped
slashes, a trailing newline, ids and set members sorted, so equal state
encodes to equal bytes:

```json
{
  "collections" : [
    { "id" : "smart-1", "name" : "At least 4 stars", "rules" : { "flags" : [ ], "hidesRejected" : false, "labels" : [ ], "rating" : "atLeast", "stars" : 4 } },
    { "id" : "user-1", "name" : "Keepers", "photos" : [ "/fixture/shoot/IMG_0001.jpg" ] }
  ],
  "filter" : { "flags" : [ "Pick" ], "hidesRejected" : true, "labels" : [ ], "rating" : "any", "stars" : 0 },
  "selected" : "user-1",
  "version" : 1
}
```

(`collections` keeps sidebar order, not id order.) Records are private
`Codable` structs over the raw values; the feature never adds `Codable` to
`PhotoFlag` or `PhotoLabel` (persist may). A file that isn't a readable
version 1, damaged or newer, is set aside as `collections.json.bad` and the
catalog starts with none: nothing is ever written over it. On fakes without
`-LibraryCatalogDir` nothing is read or written (a fixture run never touches
the user's folder). Nothing is written while `catalogState.canSave` is
false.

## Pseudocode

```
LibraryFilter.matches(p):                                            # FC-1
  (flags.isEmpty || flags.contains(p.flag)) && rating.admits(p.rating)
  && (labels.isEmpty || p.label.map(labels.contains) == true)
  && !(hidesRejected && p.flag == .reject)
RatingRule.admits(s): any → true; atLeast(n) → s >= n; exactly(n) → s == n

shownItems:                                                          # FC-2
  base = all → items; favorites → picks; recent → newest 20;
         user-n → items whose id is in its photos; smart-n → items
  f = activeFilter; return f.isActive ? base.filter(f.matches) : base
recount: collections = built-ins + userCollections.map { id, name, count(base) }
         if selectedCollectionID not in collections: selectedCollectionID = "all"
refreshShown: rebuildOrder(); select(selection)
              if mode == .loupe, focused not in order: mode = .grid; focusedItemID = nil
selectCollection keeps its guard and calls refreshShown (one copy of the #156 rule)

setFilter(f):                                                        # FC-7 (FC-12 the smart branch)
  guard filterHelp == nil
  if let s = selectedUserCollection, s.isSmart: recordCollectionsEdit("Edit Rules") { s.contents = .rules(f) }
  else: filter = f; collectionsRevision += 1
  refreshShown()
toggleFilterFlag(.reject) turning Rejected on clears hidesRejected;
toggleHideRejected turning it on removes .reject from flags (never a filter that can't match by construction)
setRatingRule(.atLeast(0)) is .any
filterValue: activeFilter.summary + "; " + order.count + " of " + base.count
cull under a filter: cull's own rule; order is rebuilt (editCanReorder), so
  services.culling.advance(from:before:after:) finds the photo that took its place

newCollection():                                                     # FC-9
  id = "user-" + (max n of user ids + 1); name = "Untitled Collection" (then " 2", " 3" while taken)
  recordCollectionsEdit("New Collection") { append(id, name, .photos(cullTargets)) }
  selectCollection(id)
add(ids, to: id): guard id is a "user-" id, ids ⊄ its photos
  recordCollectionsEdit("Add to Collection") { photos ∪= ids }
removeFromCollection(): guard selected is "user-", targets ∩ photos non-empty
  recordCollectionsEdit("Remove from Collection") { photos −= cullTargets }; refreshShown()
deleteCollection(id): recordCollectionsEdit("Delete Collection") { remove id }   # items untouched
renameCollection(id, name): trimmed, non-empty, a user or smart id; "Rename Collection"

newSmartCollection():                                                # FC-12
  guard newSmartCollectionHelp == nil (filter.isActive, no smart selected)
  id = "smart-" + next n; recordCollectionsEdit("New Smart Collection") { append(id, filter.summary, .rules(filter)) }
  selectCollection(id)                    # `filter` itself is left as it was

collectionsSaveRequest():                                            # FC-14
  guard UserCollection.fileUnavailable == nil, catalogState.canSave,
        collectionsRevision != collectionsSavedRevision else nil
  return (collectionsRevision, encode(userCollections, filter, selectedCollectionID))
restoreCollections(data): nil → nothing; decode or throw; userCollections = …; filter = …;
  collectionsSavedRevision = collectionsRevision; recount(); selectCollection(selected ?? "all")

LibraryWindow+Filters (FC-4 wiring, FC-15 store):
  filtersAreaLaunch (from the window's .task, after persistAreaLaunch):
    guard let dir = launch.catalogDir ?? (services.isPreview ? nil : appSupport/Library)
    data = try? store.read() → do { try model.restoreCollections(data) }
      catch { name = try store.setAside(); model.failRestoreCollections(setAsideAs: name) }
  filtersAreaChanged (onChange of collectionsRevision): debounce 500 ms, then
    guard let (rev, data) = model.collectionsSaveRequest(); Task.detached { try await store.write(data) }
    → model.didSaveCollections(revision: rev)  (a failure stays dirty)
  filtersAreaFlush (willTerminate): the same, written with store.writeNow (synchronous)
CollectionsStore(dir): read (missing → nil), write (atomic), writeNow, setAside (→ .bad, replacing an older one)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: filters-collections`,
`Slice: <slice>`, `Fast-Check: pass`, `Head:`, and for a task with a plan
`Mutate: <score> <plan>`. Whichever of FC-16 and FC-10 merges last carries
`feature-done`. Model paths drop `Sources/LibraryModel/`, tests
`Tests/LibraryModelTests/`, plans `Tests/mutations/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FC-1 | #31 (part) | `LibraryFilter`, `RatingRule`: `matches`, `admits`, `summary`, titles | `LibraryFilter.swift`; tests `LibraryFilterTests.swift`; plan `LibraryModel.LibraryFilter.json` | – | ~240, 3 |
| FC-2 | #31 (part) | `UserCollection`; the stored state, `==`, `shownItems`, `recount`, `editCanReorder`, `refreshShown`; every catalog method stubbed; empty-collection messages; walk MJ1 | `LibraryCatalog.swift`, `LibraryOrder.swift`, `LibraryCollections.swift`, `LibraryFilter.swift`, `LibraryEmptyCollection.swift`; tests `LibraryCollectionsSeamTests.swift`; plans `LibraryModel.LibraryCatalog.json`, `LibraryModel.LibraryOrder.json` | FC-1 | ~360, 8 |
| FC-3 | #31 (part) | Collection steps in the history: snapshots, `recordCollectionsEdit`, undo and redo | `CatalogHistory.swift`; tests `LibraryCollectionsHistoryTests.swift`; plan `LibraryModel.CatalogHistory.json` | FC-2 | ~180, 3 |
| FC-4 | – | The area: `LibraryFiltersMenu`, the focused value, `LibraryFilterBar`, every closure from the Model's help, the save hooks, the store stub | `Sources/LibraryApp/LibraryWindow+Filters.swift`, `Sources/LibraryApp/Platform/CollectionsStore.swift` | FC-2 | ~330, 2 |
| FC-5 | – | The shell: sidebar sections, the bar mounted, the menu items, the No Matching Photos branch, the notice, `library.collections` | `Sources/LibraryApp/LibraryWindow.swift`, `Sources/LibraryApp/LibraryCommands.swift`, `Sources/LibraryApp/LibraryBrowser.swift` | FC-4 | ~220, 3 |
| FC-6 | – | The filter bar's checks, disabled until FC-7: Model tests, budget, snapshots, J13 | tests `LibraryFilterBarTests.swift`, `LibraryFilterBudgetTests.swift`; `Tests/AppSnapshotTests/LibraryFilterSnapshots.swift`; `UITests/LibraryJourneyTests+Filters.swift` | FC-4 | ~330, 4 |
| FC-7 | #31 (part) | The filter methods (not smart); `LibraryFilter.unavailable = nil`; enables FC-6's checks | `LibraryFilter.swift`; plan `LibraryModel.LibraryFilter.json`; FC-6's four files | FC-5, FC-6 | ~200, 6 |
| FC-8 | – | Collections' checks, disabled until FC-9 (step 7: FC-10): Model tests, budget, snapshots, J14 | tests `LibraryCollectionsTests.swift`, `LibraryCollectionsBudgetTests.swift`; `Tests/AppSnapshotTests/LibraryCollectionsSnapshots.swift`; `UITests/LibraryJourneyTests+Collections.swift` | FC-4 | ~360, 4 |
| FC-9 | #31 (part) | New, add, remove, rename, delete, their help; `unavailable = nil`; enables FC-8's checks but J14 step 7 | `LibraryCollections.swift`; plan `LibraryModel.LibraryCollections.json`; FC-8's four files | FC-3, FC-5, FC-8 | ~260, 6 |
| FC-10 | – | Drag the selection onto a sidebar row (`add(_:to:)`); enables J14 step 7 | `Sources/LibraryApp/LibraryGrid.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `UITests/LibraryJourneyTests+Collections.swift` | FC-9, S-L9 | ~80, 3 |
| FC-11 | – | Smart collections' checks, disabled until FC-12: Model tests, snapshots, J15 | tests `LibrarySmartCollectionTests.swift`; `Tests/AppSnapshotTests/LibrarySmartSnapshots.swift`; `UITests/LibraryJourneyTests+Smart.swift` | FC-4 | ~260, 3 |
| FC-12 | #31 (part) | `newSmartCollection`, the "Edit Rules" branch of `setFilter`, `filterCaption`; `smartUnavailable = nil`; enables FC-11's checks | `LibraryFilter.swift`; plan `LibraryModel.LibraryFilter.json`; FC-11's three files | FC-3, FC-7, FC-11 | ~160, 5 |
| FC-13 | – | The collections file's checks, disabled until FC-14 and FC-15: the golden, codec and restore tests, the store test, the notice snapshot, J16 | tests `LibraryCollectionsFileTests.swift`; `Tests/AppSnapshotTests/LibraryCollectionsStoreTests.swift`, `Tests/AppSnapshotTests/LibraryCollectionsNoticeSnapshots.swift`; `UITests/LibraryJourneyTests+CollectionsFile.swift` | FC-4 | ~340, 4 |
| FC-14 | #31 (part) | The codec, `restoreCollections`, save requests, `collectionsFileValue`; `fileUnavailable = nil`; enables FC-13's Model checks, the notice snapshot and J16 | `LibraryCollections.swift`; plan `LibraryModel.LibraryCollections.json`; tests `LibraryCollectionsFileTests.swift`; `Tests/AppSnapshotTests/LibraryCollectionsNoticeSnapshots.swift`, `UITests/LibraryJourneyTests+CollectionsFile.swift` | FC-9, FC-13, FC-15 | ~280, 5 |
| FC-15 | – | `CollectionsStore`: folder, atomic write, `writeNow`, set aside; enables its test | `Sources/LibraryApp/Platform/CollectionsStore.swift`, `Tests/AppSnapshotTests/LibraryCollectionsStoreTests.swift` | FC-13 | ~140, 2 |
| FC-16 | #31 (closes) | Shared prose: blueprint 6.3, 6.4 (S-L9, S-L10), 8.3 owned files; design.md "Filter bar" rule; the two C4 part descriptions; `status: built` | `docs/blueprints/library.md`, `docs/design.md`, `docs/c4/parts/creative-apps/library-model/library-model-sources.json`, `docs/c4/parts/creative-apps/library-app/library-app-sources.json`, `docs/blueprints/library/features/filters-collections.wave.json` | FC-7, FC-9, FC-12, FC-14, FC-15 | ~80, 5 |

Why the links: FC-2 stubs methods in FC-1's file; FC-3 snapshots FC-2's
`userCollections`; FC-4 calls FC-2's signatures; FC-5 mounts FC-4's views.
Each checks task (FC-6, FC-8, FC-11, FC-13) compiles against FC-2's stubs
and FC-4's views and nothing else, so all four build in one wave. A code
task enables its checks (shares their files) and its journey needs the
shell (FC-5); FC-9 calls FC-3's `recordCollectionsEdit`; FC-12 edits FC-7's
file and its test drives FC-7's `setFilter`; FC-14 edits FC-9's file and
J16 needs FC-15's store. FC-10 is the only task that waits on SuiteUI.

## Build waves

- Wave 1: FC-1. Independent in this wave: FC-1 alone.
- Wave 2: FC-2. Independent in this wave: FC-2 alone.
- Wave 3: FC-3, FC-4. Independent in this wave: both.
- Wave 4: FC-5, FC-6, FC-8, FC-11, FC-13. Independent in this wave: all five.
- Wave 5: FC-7, FC-9, FC-15. Independent in this wave: all three.
- Wave 6: FC-12, FC-14, FC-10 (FC-10 once S-L9 has merged). Independent in this wave: all three.
- Wave 7: FC-16 (final, shared prose). Independent in this wave: FC-16 alone.

Longest chain: FC-1 → FC-2 → FC-4 → FC-6 → FC-7 → FC-12 → FC-16 (7).
Chain of 7: FC-2 stubs into FC-1's file; FC-4 wires FC-2's signatures; FC-6's
snapshots draw FC-4's bar; FC-7 enables FC-6's checks; FC-12 edits FC-7's
`LibraryFilter.swift` (C4 plans only two Model files for this feature, so the
filter and smart code can't split into a third); FC-16's prose describes
the built feature. The same holds for FC-1 → FC-2 → FC-4 → FC-13 → FC-15 →
FC-14 → FC-16.

## Acceptance test per task

Rule 13: each slice's checks (FC-6, FC-8, FC-11, FC-13) merge before its
code, disabled with `@Test(.disabled("waits on FC-n"))` (a journey:
`throw XCTSkip("waits on FC-n")`); the code task flips them. FC-a's tasks
carry their own tests: there is no earlier contract to compile them against.
Rule 14: the bugs below go in the plan of the file the task changes, each
with the `swift test --filter` regex of its test.

| id | test | fails when | mutations |
|---|---|---|---|
| FC-1 | `LibraryFilterTests`: `.all` matches every `shoot` photo and its summary is "All photos"; `atLeast(3)` admits 3, 4, 5 and not 2; `exactly(0)` admits only unrated; `[.pick]` keeps picks; `[.pick, .none]` reads "Picked or Unflagged"; `hidesRejected` drops rejects whatever `flags` says; labels `[.red, .blue]` keep only those and read "Red or Blue"; a three-part summary reads "Picked, At least 3 stars, Rejects hidden"; every `RatingRule.title` | a rule admits the wrong photo or a summary's words drift | `>=` → `>` in `atLeast`; `hidesRejected` term dropped; empty `labels` treated as "no label" |
| FC-2 | `LibraryCollectionsSeamTests` (MJ1): with `.all` and none of yours, `order`, counts and `==` equal today's on `shoot` and `samples`; two catalogs differing only in `filter` or `userCollections` are not equal; a filter applies in All Photos, Favorites and Recently Added; under a filter (name sort) a reject leaves `order`; a `user-1` row appears with its count, shows its photos, and falls back to All Photos when removed; a filter that hides the loupe photo returns to the grid; every stub's help is its `unavailable` text | the bar's filter skips a collection, `order` goes stale under a filter, or counts include filtered-out photos | `editCanReorder` without the filter term; `recount` omits your collections; `==` without `filter` |
| FC-3 | `LibraryCollectionsHistoryTests`: a collections edit is one named step and a no-op records none; undo puts the list back and redo the new one; undo of a New Collection that was selected falls back to All Photos; a photo step and a collections step undo in order; undo never moves the loupe; `saveRevision` is untouched by a collections-only step | a collection change can't be undone, or undo restores the wrong list | undo skips `collectionsBefore`; redo applies `before`; no-op guard dropped |
| FC-4 | builds on the lane's macOS build-only run; every closure is built as `enabled(help == nil)`, so while FC-2's stubs answer their `unavailable` text every one is nil (J11 in FC-5 checks it on screen) | a control is enabled with nothing behind it | – (macOS, no Model code) |
| FC-5 | J0, J10, J11 pass: every new menu item and bar control is listed in `library.controls`, disabled, with "… isn't built yet (filters-collections)."; the sidebar shows the Library and Collections sections; existing Library snapshots redrawn and listed | a new control is dead or unnamed, or an existing journey breaks | – (macOS, no Model code) |
| FC-6 | checks only: the tests of FC-7, disabled; `LibraryFilterBudgetTests` disabled | – | – (no source) |
| FC-7 | `LibraryFilterBarTests` (enabled): each toggle changes `order` as J13 steps 2–8 say on `shoot`; "N of M" in `filterValue`; turning Rejected on clears Hide Rejected and the reverse; `atLeast(0)` stores `.any`; a filter change keeps the selection ∩ order and leaves a loupe with a hidden photo; under Picked, unflagging the loupe photo in the loupe with Auto Advance moves to the photo that took its place, and the last one returns to the grid with `isHiddenByFilter` (on services whose culling is `LiveCulling`; the fake has no filter case); a filter change records no undo step and bumps `collectionsRevision`; with no photos every control's help is "Import or load photos to filter them."; J13 and `LibraryFilterSnapshots` pass | a filter shows a photo it excludes, the count lies, or the loupe stays on a hidden photo | Rejected chip leaves `hidesRejected` on; `refreshShown` without the loupe check; `filterValue` counts after the filter on both sides |
| FC-8 | checks only: the tests of FC-9, disabled; J14 step 7 skipped until FC-10 | – | – (no source) |
| FC-9 | `LibraryCollectionsTests` (enabled): New Collection with three selected holds them, is named "Untitled Collection" then "Untitled Collection 2", is selected and is one step; with none selected it is empty; ids are never reused while one exists; Add to a smart collection or a built-in is refused with its help; Add when every target is in it: "Every selected photo is already in Keepers."; Remove outside a collection you made: "Open a collection you made to remove photos from it."; Delete never changes `items`; rename trims and refuses empty and built-in ids; each is one named step that undo reverts exactly; `LibraryCollectionsBudgetTests`: `cull` of one photo of `large` with 10 collections of 1,000 ids and 10 smart ones ≤ 10 ms debug; J14 steps 1–6 and `LibraryCollectionsSnapshots` pass | a collection takes the wrong photos, a delete loses photos, or a change is two steps | `add` into a smart id; `deleteCollection` also filters `items`; `newCollection` ignores `cullTargets`; next id from `count + 1` |
| FC-10 | J14 step 7 on the macOS run: a drag of two cells onto Keepers adds both in one step; a drop on All Photos is refused (no highlight) | the drop adds nothing or adds to a built-in | – (macOS; the rule is FC-9's `add`) |
| FC-11 | checks only: the tests of FC-12, disabled | – | – (no source) |
| FC-12 | `LibrarySmartCollectionTests` (enabled): New Smart Collection from "At least 4 stars" is named that, counts the matches and is one step; it is refused with no filter on ("Set a filter first: a smart collection keeps the filter's rules.") and while a smart one is selected; rating a photo changes its count; while it is selected `activeFilter` is its rules, `setFilter` changes its rules as one "Edit Rules" step and leaves `filter` untouched; `filterCaption` is "Rules of <name>"; J15 and `LibrarySmartSnapshots` pass | a smart collection freezes its photos, or editing it changes the view filter | `setFilter` writes `filter` while smart is selected; smart edit records no step; `newSmartCollection` allowed with `.all` |
| FC-13 | checks only: the tests of FC-14 and FC-15, disabled | – | – (no source) |
| FC-14 | `LibraryCollectionsFileTests` (enabled): a manual and a smart collection, a filter and the selection encode byte-equal to the golden in the test (pasted from the Linux output) and decode back equal; two encodes of equal state are byte-equal whatever the set order; `not json` and `{}` throw `damagedCatalog`, `{"version": 2}` `newerCatalog(version: 2)`; `collectionsSaveRequest` is nil when saved, when `catalogState` is `.newer`, and after `didSaveCollections` of the newest revision, and stays dirty after an older one; `restoreCollections` of an unknown selected id selects All Photos; `failRestoreCollections` sets the notice; encode and decode of 20 collections over 10,000 ids ≤ 200 ms debug; J16 (F) and the notice snapshot pass | a relaunch loses or alters a collection, or a newer or damaged file could be written over | photo ids unsorted; `canSave` guard dropped; `selected` not encoded; `version > 1` accepted |
| FC-15 | `LibraryCollectionsStoreTests` (macOS, enabled): missing file reads nil; write then read gives the bytes; `setAside` renames to `.bad`, replacing an older one; `writeNow` writes synchronously; J16 step 3 | a write isn't atomic or a damaged file is lost | – (macOS) |
| FC-16 | `scripts/ci` (C4 assembles, waves render, `.wave.json` `status: built`) | a shared doc is out of step with the code | – (docs) |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-LIB-3 model half under a filter | `rebuildOrder` on `large` with a three-part filter ≤ 5 ms release, 50 ms debug | `LibraryFilterBudgetTests.rebuildWithFilterWithinBudget` |
| QB-LIB-4 model half with collections | `cull` of one photo of `large` with 10 + 10 collections, no filter, name sort ≤ 1 ms release, 10 ms debug (recount stays cheap); under a filter the rebuild budget above applies | `LibraryCollectionsBudgetTests.cullWithCollectionsWithinBudget`, `.cullUnderFilterWithinBudget` |
| Relaunch | encode and decode 20 collections over 10,000 ids ≤ 20 ms release, 200 ms debug | `LibraryCollectionsFileTests.codecWithinBudget` |
| QB-F3 one gesture, one step | each collection command and each smart rule edit is one named step; a filter change is none | `LibraryCollectionsHistoryTests`, `LibraryCollectionsTests`, `LibrarySmartCollectionTests`, J14 |
| QB-F4 keyboard parity | every bar control has a View > Filter item; every collection command is in File or Photo | J13 step 8, J14, J15 through menus |
| QB-F1 no dead controls | every new control acts or says why, from FC-5 on | J11 |
| Audit | the bar, the two sidebar sections and the four empty states add nothing to any `library` count | the contact sheet's audit table for J13 to J16 |
| QB-V5 | the eight snapshot states, Light and Dark | the four snapshot files |

## Done check

Per slice (`lead.md` contract rule 6): its tasks merged, its journey green
in the newest scoped run (`ci.yml` with `app=library`) that contains its last
PR, every app built, no open `finding` for it, and every mutation in its
plans caught. FC-a's MJ1 runs with the Library Model tests; FC-a also needs
J0, J10 and J11 green with the new controls disabled. FC-c is done with J14
steps 1–6 if S-L9 hasn't merged (step 7 stays skipped and FC-10 follows as
a gap). Then `Belt-Contact-Sheet: <run url>` on the feature issue, with the
audit counts of J13 to J16.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| FQ1 | Collections in a `collections.json` beside the catalog, or inside `catalog.json`? | Beside it: persist's contract and golden stay as they are, and the file works on fakes. The alternative (membership as an optional per-photo field, the list and filter as new top-level keys, still version 1) touches `CatalogCoding`, every fake and `LiveCatalogCoding`, and is one file to back up |
| FQ2 | One filter for every collection, or one per collection? | One, as here: complaint 1 is "where did my photos go", and a filter that silently differs per collection makes it worse. The bar names it everywhere |
| FQ3 | Allow two more planned files (`LibraryWindow+Collections.swift`, `LibraryCollectionsFile.swift`) in `c4-planned.json`? | Yes if the lead wants the chain shorter: FC-12 and FC-14 would stop sharing files with FC-7 and FC-9, cutting the longest chain from 7 to 5. The packet doesn't assume it |
| FQ4 | Should Remove from Collection take the Delete key alone in a collection you made? | Not in this feature: `LibraryKey` is the spine's, and an unmodified Delete next to D4 ("never removes a photo") invites mistakes; ⌘⌫ only |
