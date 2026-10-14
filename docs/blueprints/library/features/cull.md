# Feature packet: cull

**Feature:** rate, pick, reject and label photos from the keyboard in the
grid and the loupe, each change one named undo step, with Auto Advance
moving the loupe to the next photo after a rating or flag. The Metadata menu
and the inspector's stars, flag and label go through the same path.
**Line:** `line:library` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/cull`

**Covers:** #211 (closes with CU-4), #426 (closes with CU-3), #724 (its
keys only; CU-5's PR says `Part of #724`, or `Closes #724` if
loupe-viewport's #724 part has already merged). `PhotoFlag` with reject
landed in #750; the keys, the Metadata menu, undo and the ids API are left.

**Depends on:** the spine feature issue; #333 (J4 lives in
`UITests/LibraryJourneyTests+Cull.swift`, which compiles only once #333
widens the Journey template). No creative-core issue. No SuiteUI change: the
grid's reject mark is thumbnails' (through #779), and until #779 lands J4
reads a cell's cull state by opening the photo in the loupe. The perf task
CU-8 also waits on #330 and S-L8 (#782). J4's (L) run needs import's live
importer: CU-7 waits for import's IM-6 to merge (a task order inside the
wave).

Blueprint sections: 2.2 (`library-culling`), 4.2 J4, 4.3 P2, 5.1 (why
culling has a protocol), 5.3 (`PhotoCulling`, `CullChange`), 5.7 (the J4
row), 6.1 (Cull marks), 6.2 (Metadata menu, single keys), 6.3, 7.1
(QB-LIB-4, QB-LIB-5).

No task edits `docs/c4/model.json`, `docs/design.md` or
`docs/review-rubric.md`. Cull owns `MetadataInspector.swift` in wave 2
(metadata-more takes it in wave 5).

## Journey steps

**J4 · `testCullWithKeysAndAutoAdvance`** (`UITests/LibraryJourneyTests+Cull.swift`;
all steps F and L)
1. Launch on `-LibraryFixture shoot` (L: live on `writeShoot` with
   `-LibraryImportOnLaunch`); View > Sort By > Name; open `IMG_0001` in the
   loupe. Metadata > Auto Advance is checked.
2. Press 3. Shot `cull-rated`. Expect "2 of 24"; press Left: the photo's
   value ends `3 stars`; press Right.
3. Press P on `IMG_0002`, then X on `IMG_0003`. Shot `cull-flagged`. Expect
   "4 of 24"; Favorites count 1.
4. Open Edit: the Undo item reads "Undo Reject". Choose it. Shot
   `cull-undo`. Expect the loupe still on "4 of 24" (undo does not move,
   #426); press Left: `IMG_0003`'s value no longer contains `Rejected`.
5. Uncheck Metadata > Auto Advance; press 5. Expect the same photo, its
   value ending `5 stars`.
6. Escape; click `IMG_0005`, Command-click `IMG_0006`; press 2. Shot
   `cull-grid`. Expect both contain `2 stars` (cell values once #779 has
   merged; before it, open each in the loupe and read its value) and the
   selection did not move.
7. Press P (both picked), then U; Edit's Undo item reads "Undo Clear Flag".
8. (F) Relaunch with `-LibraryFakeMode fail`; open a photo; press 3. Shot
   `cull-refused`. Expect the notice "Rating is unavailable in this
   preview." and the photo's value unchanged.
States: with nothing selected the keys do nothing and the Metadata items
are disabled; refused change (fake fail mode).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Grid, loupe | nothing selected and not in the loupe: keys are ignored, Metadata items disabled with help "Select a photo to rate it." | a refused change (`services.culling` throws): `cullError` holds its message, shown in the content's notice slot (the spine's `notice`), dismissible; nothing changes and no undo step | – |
| Inspector (Metadata section) | the spine's header when nothing is selected | – | – |
| Metadata menu | – | – | – (Auto Advance is a checkmark item) |

Snapshots: `LibraryRatingSnapshots.swift` `library-rated` (inspector and
loupe value for a 3-star picked red photo, and a rejected one; the grid's
dimmed cell is thumbnails'), `LibraryAutoAdvanceSnapshots.swift`
`library-auto-advance` (the loupe on the next photo after a rating),
`LibraryMetadataSnapshots.swift` (existing, redrawn with identifiers),
Light and Dark.

## Contract slice

From the spine: `PhotoCulling`, `CullChange` (`undoName`), `LibraryKey`,
`recordEdit(_:coalesceKey:ids:_:)`, `autoAdvance`, `cullError`,
`cullSummary`, and `LibraryMenu.cull`. This feature adds, in
`LibraryCulling.swift`:

```swift
extension LibraryCatalog {
    /// The loupe photo in the loupe, else the selection; empty: nothing to cull.
    public var cullTargets: Set<String> { get }
    /// Applies `change` through `services.culling` as one undo step named
    /// `change.undoName`; in the loupe with Auto Advance on, moves to
    /// `services.culling.advance(from:before:after:)` for a rating or flag.
    /// A throw sets `cullError` and changes nothing.
    public mutating func cull(_ change: CullChange)
    /// The change a single key makes: 0–5, P, X, U; nil for other keys.
    public static func cullChange(for key: LibraryKey) -> CullChange?
    public mutating func setAutoAdvance(_ on: Bool)
    public mutating func dismissCullError()
    /// "Select a photo to rate it." with no targets, else nil.
    public var cullHelp: String? { get }
}
```

`MetadataEditing.swift`'s `setRating`, `setFlag`, `setLabel` and
`clickStar` call `cull(_:)`, so the inspector and the menu record the same
undo steps as the keys. `LiveCulling` replaces the spine's stub (which
already applies the plain rules) with the full Auto Advance rule and sets
`unavailable` to nil. Blueprint 5.7 names the key method
`cullKey(_ key: Character)`; the spine's `LibraryKey` already parses the
character, so this feature maps `LibraryKey` to `CullChange` instead. Label
keys (6–9) stay out of v1.

## Pseudocode

```
cull(change):                                                     # CU-1
  ids = cullTargets; guard !ids.isEmpty else return
  beforeOrder = order
  do { next = try services.culling.apply(change, to: ids, in: items) }
  catch { cullError = (error as? LibraryError)?.message ?? "\(error)"; return }
  recordEdit(change.undoName, ids: ids) { photo in photo = next[photo.id] }   # one step; saveRevision += 1
  cullError = nil
  if mode == .loupe, autoAdvance, change is .rating or .flag, let id = focusedItemID:
     focusedItemID = services.culling.advance(from: id, before: beforeOrder, after: order)
     if focusedItemID == nil: mode = .grid
  (in the grid the selection never moves)

LiveCulling.advance(from id, before, after):                      # CU-2
  guard !after.isEmpty else nil
  i = before.firstIndex(of: id) else after.first
  if after.contains(id): return i + 1 < before.count ? first of before[i+1...] that is in after ?? id : id
  else: return first of before[i+1...] in after ?? last of before[..<i] in after      # the photo that took its place

LibraryWindow+Cull (CU-5, macOS):
  cull.key = { key in if let c = LibraryCatalog.cullChange(for: key), model.cullHelp == nil { model.cull(c) } }
  cull.setRating/setFlag/setLabel = targets ? { model.cull(...) } : nil
  cull.toggleAutoAdvance = { model.setAutoAdvance(!model.autoAdvance) }; autoAdvance = model.autoAdvance
  cull.dismissCullError = { model.dismissCullError() }
MetadataInspector (CU-6): stars, flag and label call cull through the existing closures; identifiers
  library.metadata.rating.<n>, library.metadata.flag, library.metadata.label
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: cull`, `Fast-Check: pass`,
`Head:`. The last task to merge carries `feature-done` (CU-7, or CU-8 when
it runs).

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| CU-1 | #211 (part) | `cull(_:)` on targets with one undo step, refused changes, help, key mapping | `Sources/LibraryModel/LibraryCulling.swift`, `Tests/LibraryModelTests/LibraryRatingTests.swift` | spine |
| CU-2 | #426 (part) | `LiveCulling` with the full Auto Advance rule; `unavailable = nil` | `Sources/LibraryModel/Live/LiveCulling.swift`, `Tests/LibraryModelTests/LibraryAutoAdvanceTests.swift` | spine |
| CU-3 | #426 (closes) | Auto Advance in `cull` and `setAutoAdvance`; undo never moves the loupe; the cull budgets | `Sources/LibraryModel/LibraryCulling.swift`, `Tests/LibraryModelTests/LibraryAutoAdvanceTests.swift`, `Tests/LibraryModelTests/LibraryCullBudgetTests.swift` | CU-1, CU-2 |
| CU-4 | #211 (closes) | The inspector's and the menu's edits go through `cull` (undo steps named) | `Sources/LibraryModel/MetadataEditing.swift`, `Tests/LibraryModelTests/LibraryMetadataTests.swift` | CU-1 |
| CU-5 | #724 (part) | The cull area: single keys, the Metadata menu, Auto Advance, the refused-change notice | `Sources/LibraryApp/LibraryWindow+Cull.swift`, `Tests/AppSnapshotTests/LibraryRatingSnapshots.swift`, `Tests/AppSnapshotTests/LibraryAutoAdvanceSnapshots.swift` | CU-3, CU-4 |
| CU-6 | – | `MetadataInspector` identifiers and routing; its snapshots | `Sources/LibraryApp/MetadataInspector.swift`, `Tests/AppSnapshotTests/LibraryMetadataSnapshots.swift` | CU-4 |
| CU-7 | – | J4 steps 1–8 (F), then (L) once import's IM-6 has merged | `UITests/LibraryJourneyTests+Cull.swift` | CU-5, CU-6, #333, import IM-6 for (L) |
| CU-8 | – | P2 `testCullKeyLatency` (perf, report-only) | `UITests/LibraryJourneyTests+PerfCull.swift` | CU-7, #330, #782 |

CU-1 and CU-3 share `LibraryCulling.swift`, stacked; CU-2 and CU-3 share
`LibraryAutoAdvanceTests.swift`, stacked. CU-1, CU-2 and CU-4's model work
start side by side once the spine has merged. P2's Home after every 23 keys
uses loupe-viewport's Home; until that merges, P2 presses Left 23 times.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| CU-1 | `LibraryRatingTests`: in the loupe `cull(.rating(3))` changes only the loupe photo, in the grid every selected photo; one call is one undo step named "Set Rating", and P, X, U, a label give "Pick", "Reject", "Clear Flag", "Set Label"; undo restores every photo exactly; with no targets nothing changes and `cullHelp` is "Select a photo to rate it."; on `.fake(mode: .fail)` the catalog is unchanged, no step is recorded and `cullError` is "Rating is unavailable in this preview."; `cullChange(for:)` maps `.rating(3)`, `.pick`, `.reject`, `.unflag` to their changes and `.grid`, `.crop`, `.first` to nil | a change hits the wrong photos, a gesture is two steps, a refused change leaves a trace, or a key maps wrong |
| CU-2 | `LibraryAutoAdvanceTests` (live): the next photo after `id`; the last stays on itself; when a rating hides the photo (a filtered order without it), the photo that took its place; an empty order gives nil; live equals `FakeCulling` wherever the fake's plain rule applies (no filter) | the rule moves to the wrong photo or disagrees with the fake |
| CU-3 | `LibraryAutoAdvanceTests`: with Auto Advance on, a rating in the loupe on `IMG_0001` (name order) focuses `IMG_0002`; a label does not advance; off, nothing moves; in the grid the selection never moves; undo after an advance restores the rating and leaves the loupe on `IMG_0002` (#426) | Auto Advance fires on a label or in the grid, or undo moves the loupe |
| CU-4 | `LibraryMetadataTests` (existing, extended): `clickStar(4)` then undo restores, Undo reads "Undo Set Rating"; `setFlag(.reject)` reads "Undo Reject"; every existing metadata test passes | an inspector edit bypasses undo |
| CU-5 | `LibraryRatingSnapshots` and `LibraryAutoAdvanceSnapshots`; J4 steps 2–7 on the macOS run | a key reaches nothing, Auto Advance's checkmark doesn't follow the model, or the notice is missing |
| CU-6 | `LibraryMetadataSnapshots` redrawn; the inspector's stars, flag and label carry `library.metadata.*` identifiers (the audit's `identifier` count for the inspector drops) | a control has no identifier |
| CU-7 | J4 passes on fakes and live | any expectation fails |
| CU-8 | P2 attaches ≥ 60 samples per series (grid, loupe) | fewer samples (invalid) |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-LIB-4 model half | `cull` on one photo of `large` (10,000) ≤ 10 ms (1 ms release); it rebuilds `order` only when the sort is by rating or the collection is Favorites | `LibraryCullBudgetTests.cullOneWithinBudget`, `.orderRebuiltOnlyWhenNeeded` (counts rebuilds) |
| QB-LIB-5 model half | `cull` with Auto Advance in the loupe on `large` ≤ 10 ms (1 ms release); `stepLoupe` itself is loupe-viewport's row | `LibraryCullBudgetTests.advanceWithinBudget` |
| QB-LIB-4, QB-LIB-5 probe | p95 ≤ 2 frames late to the badge or the next photo's preview; report-only | P2 (CU-8) |
| QB-F3 | each key, menu item and inspector click is one named step | `LibraryRatingTests`, `LibraryMetadataTests`, J4 steps 4 and 7 |
| QB-F4 | J4 runs from the keyboard alone after the launch | J4 |
| QB-V5 | `library-rated`, `library-auto-advance`, Light and Dark | the two snapshot files |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR is green, J4 included, and `testRateASelectedPhoto` still passes.
- **Audit zero new:** no `library` count over `UITests/audit-baseline.json`;
  the inspector's identifiers lower the `identifier` count (most of #291's
  list); J4's shots add nothing.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue.
