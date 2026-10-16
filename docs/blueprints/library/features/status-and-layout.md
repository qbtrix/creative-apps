# Feature packet: status-and-layout

**Feature:** a status row under the grid and the loupe that always says
what the window holds and what is running (photo count, selection,
thumbnail size, zoom, the loupe's place, import, render and save state,
preview data); an inspector header with the photo's facts (#185); the
identifiers still missing from Library's controls (#291); and layout tests
at every window width, so the every-control and layout journeys cover
Library.
**Line:** `line:library` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/status-and-layout`

**Covers:** #185 (closes with SL-6), #291 (closes with SL-8 when the
`library` identifier and unnamed counts reach 0 on a scoped run; otherwise
SL-8 says `Part of #291` and names the issues holding the rest).

**Depends on:** the spine, thumbnails and loupe-viewport feature issues.
SuiteUI #1184 (S-L7: `ViewerStatusBar` with an optional zoom pill) for SL-4.
#779 (S-L2, per-cell identifiers) only sharpens J12's grid step: until it
merges J12 finds cells by label. #333 (journey files) is merged. No
creative-core issue: everything here is text and geometry over state the
catalog already holds.

Two outside fixes the lead files at stage 1, each one PR in a file this
feature can't own:

- **gap, spine:** `LibraryWindow.swift` draws `LibraryStatusBar` only while
  `services.isPreview`, so live catalogs get no status row. Drop the
  condition (the bar hides itself when it has nothing to say, SL-4). J12
  runs on a fixture (preview), so it passes either way; live users need the
  fix. Owner: the spine (status `building`), else filters-collections,
  which takes `LibraryWindow.swift` in wave 5.
- **gap, MetadataInspector header:** `MetadataInspector` draws its own
  `InspectorHeader(metadata.title)`. SL-6 moves the one header above the
  tabs, so this line goes. Owner: cull's CU-6 if it hasn't merged, else a
  one-line `gap` (metadata-more owns the file in wave 5). SL-6 waits on it,
  so the inspector never shows two titles.

Blueprint sections: 2.2 (`library-status`), 2.3 (`library-app-browse`,
`library-app-inspector`), 3 (tier 3 rows 3 and 4, pulled into v1, D9), 4.1
(identifiers and values, launch arguments), 4.2 J11 and J12, 6.2 (Content,
Inspector, Loupe rows), 6.3 (the status-and-layout snapshots), 6.4 (S-L7),
7.2 (audit exit), 7.3 (layout spec).

No task edits `docs/c4/model.json`, `docs/design.md`, `docs/blueprints/library.md`
or a `waves.md`. 6.1 moves no row for this feature and it adds no `QB-LIB`
id, so it has no docs task.

## Complaints fixed, features from the future

Clean-room, from the behaviour people describe in catalog apps generally;
nothing copied. Most-used first.

| What people run into | What this feature does |
|---|---|
| "Is it still importing? Did my changes save?" Progress lives in one spot that scrolls away or hides behind the loupe | Import progress and save problems are pills in the status row, under the grid and the loupe alike |
| "How many did I select?" | "5 selected" next to the photo count |
| "Am I looking at the sharp picture or a quick preview?" (culling is judging focus) | A "Preview" pill until the full render lands; "Render failed" in warning colors with the reason |
| "What zoom am I at?" | The zoom pill in the loupe (Fit, 100%, 250%), none in the grid |
| "Basic file facts need digging" | The inspector header: capture date, pixel size, file kind; for several photos, their count and capture span |
| Panels clip or the grid leaves a ragged gap at some window sizes | Layout tests at 880, 1024, 1280, 1440 and 1920 |
| Saving silently stops (a newer catalog, a full disk) | A "Not saved" or "Read only" warning pill with the reason as its help |

From the future: the render-quality pill, the save-problem pill and the
capture span for a multi-photo selection. A command palette that searches
every menu command is in Open questions: it needs files this feature
can't own.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SL-a | On the fixtures the Model says what the status row and the inspector header show, and how many grid columns and what loupe fit every window width gets. | SL-1, SL-2 | MJ1 | spine |
| SL-b | The status row under the grid and the loupe shows the count, the selection, the thumbnail size or zoom, the loupe's place and every progress or problem pill, and J12 checks it at every width. | SL-3, SL-4 | J12 | SL-a (SL-4); thumbnails, loupe-viewport; #1184 (SL-4) |
| SL-c | The inspector's header names the selection with its facts, every Library control carries an identifier, and the wide widths are proven by snapshots. | SL-5, SL-6, SL-7, SL-8 | J12 | SL-a (SL-5, SL-7); SL-b (SL-6, SL-8); the MetadataInspector header gap (SL-6) |

SL-a is the contract: no other feature plugs into status or layout, so it
publishes values, not protocols or fakes. `LibraryStatusRow`,
`LibraryStatusPill`, `LibraryInspectorHeader` and `LibraryLayout` are what
SL-b and SL-c draw from, and SL-2 also writes SL-c's header tests, disabled.
SL-b's code is view only; its Model half and its mutations are SL-2's.

## Journey steps

**MJ1 · `LibraryStatusTextTests.testStatusWalk`** (Linux, SL-2): on
`LibraryFixtures` `shoot`, sorted by Name: the row reads size "24 photos",
pills "160 pt" and "Preview data"; select `IMG_0001` … `IMG_0005`: "5
selected" before "160 pt"; `open("IMG_0001")`: size "6000 × 4000 px", zoom
nil, pills "Fit", "1 of 24", "Loading"; `loupeZoom = .actual` (set under `@testable`; `zoomLoupe` is loupe-viewport's): zoom 1, no
"Fit"; switch to Favorites (empty collection in a full catalog): size "0
photos"; the header with nothing selected reads the collection's name and
"Photos 0".

**J12 · `LibraryLayoutJourneyTests.testLayoutAtWidths`**
(`UITests/LibraryJourneyTests+Layout.swift`; all steps F, on
`-LibraryFixture shoot`; the pattern of Halo's `testLayoutAtWidths`). For
each size 880 × 560 (`SuiteSize.windowMinimum`), 1024 × 768, 1280 × 800,
1440 × 900 and 1920 × 1080, launched with `-SuiteWindowSize <w>x<h>`
(SuiteWindow sizes itself; see Review notes):

1. [SL-3, SL-4] Shot `layout-<w>`. Expect the window's width within 2 pt
   when it fits the display. The status row `library.status` holds the
   text "24 photos" and `library.status.cellSize` "160 pt"; every pill
   (`library.status.*` and the size text) shares one top edge within 0.5 pt
   and lies inside the window and the row.
2. [SL-3] Grid cells (`library.grid.cell.*` once #779 has merged, else
   buttons whose label contains `IMG_`) on the screen: cells in one row
   share a top edge, cells in one column a left edge, and the gaps between
   adjacent columns are equal, all within 0.5 pt. At 880 there are at least
   2 columns.
3. [SL-3, SL-4] View > Sort By > Name; click the first cell, Shift-click
   the fifth. Expect `library.status.selection` "5 selected".
4. [SL-3] Where the inspector is on the screen (≤ 1024): the Rating, Flag
   and Label row labels share a left edge and their controls'
   (`library.metadata.*`) right edges are equal, within 0.5 pt.
5. [SL-3, SL-4] Double-click `IMG_0001`. Shot `layout-<w>-loupe`. Expect
   `library.status.zoom` "Fit", `library.status.position` "1 of 24", and
   `library.loupe.photo`'s left and right margins inside the content
   column differ by at most 1 pt, and so do top and bottom. Command-1:
   the zoom pill reads "Zoom 100%" and `library.status.zoom` is gone.
   Escape.
6. [SL-6] Back in the grid with `IMG_0001` … `IMG_0005` selected: where the
   inspector is on the screen, `library.inspector.header` reads "5 Photos"
   and contains "Captured"; click `IMG_0001` alone: it reads "IMG_0001" and
   contains "6000 × 4000" and "JPEG".
7. [SL-3] Every `library.*` control in `library.controls` lies inside the
   window (Halo's check). After the loop: the grid has fewer columns at 880
   than at 1024 (the content column follows the window).

The audit (`overlap`, `offscreen`, `identifier`, `unnamed`, `contrast`,
`disabled-dim`) runs on every shot. States: loading (the "Loading" pill
before the loupe's first render); none of J12's steps reach an error.

## Screens and states

| Screen | Normal | Empty | Error | Loading |
|---|---|---|---|---|
| Grid status row | size pill "24 photos"; "5 selected" while photos are selected; "160 pt" | an empty catalog: no row, except the "Preview data" pill on preview data (the spine's look); an empty collection: "0 photos" | "Not saved" (save error) or "Read only" (newer catalog), warning style, the reason as help | "Importing 3 of 27" |
| Loupe status row | zoom pill (100%, 250%) or a "Fit" pill; size "6000 × 4000 px"; "3 of 24" | – | "Render failed", the render's error as help | "Loading" before the first render, "Preview" until the full one |
| Inspector header (above the Info and Develop tabs) | one photo: name, Captured, Size, Kind; several: "5 Photos", Captured span | nothing selected: the collection's name, "Photos 24" | – | – |

Snapshots, Light and Dark: `LibraryStatusSnapshots.swift`
`library-grid-status` (5 selected), `library-loupe-status` (100%),
`library-status-progress` (import running, a preview render, a save
error; each state set under `@testable`, as `LibraryShellSnapshots` does, so none waits on another feature's methods); `LibraryInspectorSnapshots.swift` `library-inspector` (one photo,
#185's name) and `library-inspector-several`; `LibraryLayoutSnapshots.swift`
`library-layout-1280`, `-1440`, `-1920`. The spine's `library-preview-data`
and `library-inspector-none` redraw (the PR lists them).

## Contract slice

New in `Sources/LibraryModel/LibraryStatusText.swift` (SL-2), Linux-safe:

```swift
public struct LibraryStatusPill: Hashable, Sendable, Identifiable {
    public enum Style: Hashable, Sendable { case plain, warning }
    public let id: String       // selection, cellSize, zoom, position, import, render, save, preview
    public let text: String
    public let help: String     // the tooltip and accessibility hint
    public let style: Style
}

/// What ViewerStatusBar draws: `zoom` nil hides its zoom pill (#1184).
public struct LibraryStatusRow: Hashable, Sendable {
    public let zoom: Double?
    public let size: String
    public let pills: [LibraryStatusPill]
}

public struct LibraryInspectorHeader: Hashable, Sendable {
    public struct Fact: Hashable, Sendable { public let label: String; public let value: String }
    public let title: String
    public let facts: [Fact]
}

extension LibraryCatalog {
    /// "This window shows built-in sample data, not photos on disk." (moved from LibraryStatusBar).
    public static let previewDataHelp: String
    /// The row under the content; nil when there is nothing to say (an empty live catalog).
    public var statusRow: LibraryStatusRow? { get }
    /// The inspector's header. `utcOffset` is the local offset in seconds
    /// (the view passes TimeZone.current's); tests pass 0.
    public func inspectorHeader(utcOffset: Int) -> LibraryInspectorHeader
}
```

SL-2 fills `statusRow` completely and `inspectorHeader` for nothing
selected (collection name, "Photos N") and for a selection (its title
only, `PhotoMetadata.title`); SL-5 adds the facts. The count text reuses
the spine's `LibraryCatalog.photoCountText`.

New in `Sources/LibraryModel/LibraryLayout.swift` (SL-1). LibraryModel
can't import SuiteUI, so the tokens are parameters whose defaults
`LibraryLayoutSnapshots` checks against `SuiteSize` and `SuiteSpacing`:

```swift
public struct LibraryLayout: Hashable, Sendable {
    public var sidebar = 200.0, inspector = 240.0     // SuiteSize.sidebarWidth.ideal, inspectorWidth.ideal
    public var gridPadding = 12.0, gridSpacing = 12.0 // SuiteSpacing.m
    public var cellInset = 4.0                        // SuiteSpacing.xs
    public var canvasInset = 64.0                     // SuiteSize.canvasInset
    public init()
    public func contentWidth(window: Double) -> Double            // max(0, window − sidebar − inspector)
    public func gridColumns(contentWidth: Double, cell: Double) -> Int
    /// The scale that fits `photo` in `viewport` leaving canvasInset on the tighter axis; 1 when either is empty.
    public func loupeFit(viewport: (width: Double, height: Double), photo: PixelSize) -> Double
}
```

## Pseudocode

```
gridColumns(W, cell):                                   # SL-1 (equals GridSelection.columns)
  pitch = cell + 2·cellInset + gridSpacing
  guard pitch > 0, W finite else 1
  return clamp(⌊(W − 2·gridPadding + gridSpacing) / pitch⌋, 1, 10_000)

loupeFit(viewport, photo):                              # SL-1
  guard photo.width > 0, photo.height > 0 else 1
  return max(0, min((vw − 2·canvasInset) / pw, (vh − 2·canvasInset) / ph))

statusRow:                                              # SL-2
  tail = progressPills
  if isEmpty: return services.isPreview ? Row(nil, photoCountText(0), tail) : nil
  if mode == .loupe, let id = focusedItemID, let photo = item(id):
     zoom = .actual → 1 · .scale(s) → s if finite and > 0, else nil · .fit → nil
     i = order.firstIndex(of: id)                       # order, never sortedItems: no sort per frame
     pills = (zoom == nil ? [zoom "Fit"] : []) + (i.map { [position "\($0 + 1) of \(order.count)"] } ?? [])
     return Row(zoom, "\(photo.pixelSize.width) × \(photo.pixelSize.height) px", pills + tail)
  pills = (selection.isEmpty ? [] : [selection "\(selection.count) selected"]) + [cellSize "\(cellSize) pt"]
  return Row(nil, photoCountText(order.count), pills + tail)

progressPills:                                          # SL-2
  case .running(let p) = importState  → import p.text ("Importing 3 of 27")
  in the loupe on an available photo: loupeError → render "Render failed" (warning, help the error)
     else loupeRender nil → render "Loading"; quality .preview → render "Preview"
  saveError → save "Not saved" (warning, help the error); else catalogState .newer → save "Read only" (warning, its message)
  services.isPreview → preview "Preview data" (warning, previewDataHelp)

inspectorHeader(utcOffset):                             # SL-2 contract, SL-5 facts
  photos = items whose id is in selection, in order
  none:    Header(selectedCollection.name, [Photos "\(count)"])
  one:     Header(name, [Captured dateText(captureDate), Size "W × H", Kind kind(path)])
  several: Header("\(n) Photos", [Captured span])       # "2026-06-01", or "2026-06-01 – 2026-06-03"
dateText(date, offset):                                 # SL-5; no formatted(), no Calendar
  s = Int(floor(date.timeIntervalSince1970)) + offset
  days = floorDiv(s, 86_400); (y, m, d) = civil(from: days)   # days-from-civil, inverse, proleptic Gregorian
  mins = (s − days·86_400) / 60  → "YYYY-MM-DD HH:MM"
kind(path): nil → "Sample"; jpg, jpeg → "JPEG"; png → "PNG"; heic, heif → "HEIC";
  other extension → uppercased; none → "File"

LibraryStatusBar (SL-4):
  if let row = model.statusRow:
    ViewerStatusBar(zoom: row.zoom, size: row.size) {
      ForEach(row.pills) { Text($0.text).statusPill($0.style == .warning ? .warning : .plain)
        .help($0.help).accessibilityHint($0.help).accessibilityIdentifier("library.status.\($0.id)") } }
    .accessibilityIdentifier("library.status")       # container: .accessibilityElement(children: .contain)

LibraryInspector (SL-6):
  header = model.inspectorHeader(utcOffset: TimeZone.current.secondsFromGMT())
  InspectorHeader(header.title, facts: header.facts.map { InspectorFact($0.label, $0.value) })
    .accessibilityIdentifier("library.inspector.header")
  then the tabs as today; Info shows MetadataInspector (its own header gone, the gap) or nothing
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: status-and-layout`,
`Slice: <slice>`, `Fast-Check: pass`, `Head:`, and for a task that changes
planned Model code its `Mutate:` score line. SL-8 carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SL-1 | – | `LibraryLayout`: content width, grid columns, loupe fit | `Sources/LibraryModel/LibraryLayout.swift`, `Tests/LibraryModelTests/LibraryLayoutTests.swift`, `Tests/mutations/LibraryModel.LibraryLayout.json` | – | ~180, 3 |
| SL-2 | #185 (part) | The status contract and `statusRow` (count, selection, size, zoom, place, import, render, save, preview); the header for nothing selected; MJ1; SL-5's header tests written, disabled; the model C4 part | `Sources/LibraryModel/LibraryStatusText.swift`, `Tests/LibraryModelTests/LibraryStatusTextTests.swift`, `Tests/mutations/LibraryModel.LibraryStatusText.json`, `docs/c4/parts/creative-apps/library-model/library-model-sources.json` | – | ~360, 4 |
| SL-3 | – | J12 written whole from this packet, steps 1–5 and 7, `throw XCTSkip("waits on SL-4")` | `UITests/LibraryJourneyTests+Layout.swift` | – | ~220, 1 |
| SL-4 | #185 (part) | `LibraryStatusBar` draws `statusRow` with pill identifiers and help; snapshots; J12 enabled; the app C4 part | `Sources/LibraryApp/LibraryStatusBar.swift`, `Tests/AppSnapshotTests/LibraryStatusSnapshots.swift`, `UITests/LibraryJourneyTests+Layout.swift`, `docs/c4/parts/creative-apps/library-app/library-app-sources.json` | SL-2, SL-3, #1184 | ~200, 4 |
| SL-5 | #185 (part) | Header facts: one photo (Captured, Size, Kind), several (count, capture span); Linux-safe date text; enables SL-2's header tests | `Sources/LibraryModel/LibraryStatusText.swift`, `Tests/LibraryModelTests/LibraryStatusTextTests.swift`, `Tests/mutations/LibraryModel.LibraryStatusText.json` | SL-2 | ~170, 3 |
| SL-6 | #185 (closes) | `LibraryInspector`: the header above the tabs (`library.inspector.header`); snapshots; J12 step 6; the app C4 part names the header | `Sources/LibraryApp/LibraryInspector.swift`, `Tests/AppSnapshotTests/LibraryInspectorSnapshots.swift`, `UITests/LibraryJourneyTests+Layout.swift`, `docs/c4/parts/creative-apps/library-app/library-app-sources.json` | SL-4, SL-5, the MetadataInspector header gap | ~180, 4 |
| SL-7 | – | Layout snapshots at 1280, 1440 and 1920; `LibraryLayout` equals `GridSelection.columns` and its defaults equal the tokens | `Tests/AppSnapshotTests/LibraryLayoutSnapshots.swift` | SL-1 | ~150, 1 |
| SL-8 | #291 (closes or part) | The identifier and unnamed sweep: each remaining `library` finding named with its owner; this feature's fixed in its files; `feature-done` | `Sources/LibraryApp/LibraryStatusBar.swift`, `Sources/LibraryApp/LibraryInspector.swift` | SL-4, SL-6 | ~60, 2 |

SL-2 and SL-5 share `LibraryStatusText.swift`, its tests and its plan,
stacked. SL-3, SL-4 and SL-6 share J12's file, stacked; SL-4 and SL-6 also
share the app C4 part. SL-8 edits SL-4's and SL-6's views. A task that
measures over 400 lines splits by file before it opens (SL-2's first move:
its disabled header tests go to SL-5).

**If #1184 hasn't merged** when SL-4 starts, SL-4 passes
`zoom: row.zoom ?? 1` (today's bare 100% in the grid, already in the audit
baseline) and the lead files a one-line `gap` to pass `row.zoom` once it
lands, so SuiteUI never blocks SL-6 and SL-8. SL-7 needs only
SL-1's functions (the PNGs redraw when the views change), so it builds in
wave 2.

**SL-8, the #291 sweep.** At stage 1 the lead reads the newest scoped
library run's `audit-library-*.json` (`ui-screens` artifact) and files a
`needs-ui`, `line:suiteui` issue for each finding a SuiteUI view or the
system draws, with a `suite.` identifier to add. #291 already names three:
the inspector toggle (`Hide Inspector`), the toolbar overflow (`more
toolbar items`) and the 11 × 434 pt unnamed button. Grid cells are #779's
and thumbnails'. After SL-6 merges, SL-8 rereads the audit from a scoped
run that contains it, fixes every finding in `LibraryStatusBar.swift` or
`LibraryInspector.swift`, and files a `gap` for any finding in another
feature's file. It says `Closes #291` only when the run shows `library`
`identifier` 0 and `unnamed` 0; otherwise `Part of #291` with the issues
that hold the rest. CI's Audit lower job lowers the baseline; nobody edits it.

## Build waves

- Wave 1: SL-1, SL-2, SL-3. Independent in this wave: all three.
- Wave 2: SL-4, SL-5, SL-7. Independent in this wave: all three.
- Wave 3: SL-6. Independent in this wave: SL-6 alone.
- Wave 4: SL-8 (final, `feature-done`). Independent in this wave: SL-8 alone.

Longest chain: SL-2 → SL-4 → SL-6 → SL-8 (4), and SL-3 → SL-4 → SL-6 → SL-8 (4).
Chain of 4: SL-4 draws SL-2's `statusRow` and enables SL-3's J12; SL-6
adds its step to that J12 file and its phrase to SL-4's C4 part; SL-8
fixes identifiers in both views.

## Acceptance test per task

| id | test | fails when | mutations (plan: `swift test --filter`) |
|---|---|---|---|
| SL-1 | `LibraryLayoutTests`: `contentWidth(window:)` for 880, 1024, 1280, 1440, 1920 with the inspector at 200, 240 and 360; `gridColumns` is 2 at 440 and cell 160, 3 at 584, exactly 2 at the exact-fit width 372, 1 at 0, NaN and infinity, and never above 10,000; at 880 with the default cell at least 2 columns; `loupeFit` of 6000 × 4000 in 840 × 700 is (840 − 128) / 6000, of 4000 × 6000 is (700 − 128) / 6000, and 1 for a zero-size photo | a column count or a fit differs, or a degenerate width crashes | `LibraryModel.LibraryLayout`: drop `max(…, 1)` → 0 columns; drop `+ gridSpacing` in the numerator → 1 at 372; `2 * canvasInset` → `canvasInset`; `min(` → `max(` in `loupeFit` (`LibraryLayoutTests`) |
| SL-2 | `LibraryStatusTextTests`: MJ1; `statusRow` is nil on an empty live catalog and holds only "Preview data" (size "0 photos") on an empty fake one; the selection pill is absent with nothing selected; Favorites with one picked photo of 24 reads "1 photo"; zoom `.scale(2.5)` → 2.5, `.scale(.nan)` → nil and a "Fit" pill; the position follows `order` after `setSort(.name)`; import `.running(3 of 27)` → "Importing 4 of 27"; a `.preview` render → "Preview", a `.full` one → no render pill, `loupeError` → "Render failed" warning with that help; `saveError` → "Not saved" warning, `.newer` → "Read only"; `statusRowWithinBudget`: on `large` (10,000) in the grid and in the loupe ≤ 1 ms debug (0.1 ms release) through `Budget.measure`. SL-5's tests are here, `@Test(.disabled("waits on SL-5"))` | a pill shows when it shouldn't, counts the wrong set, or the row sorts per read | `LibraryModel.LibraryStatusText`: drop `selection.isEmpty ? [] :` → "0 selected"; `order.count` → `items.count` → "24 photos" in Favorites; `index + 1` → `index` → "0 of 24"; `.preview` check → `loupeRender != nil` → a pill on full renders; drop the `isPreview` guard (`LibraryStatusTextTests`) |
| SL-3 | J12 compiles and skips with "waits on SL-4" | the file doesn't build or runs early | none (a journey) |
| SL-4 | `LibraryStatusSnapshots` (three states, Light and Dark; `library.status.*` identifiers on every pill); J12 steps 1–5 and 7 on the next library-scoped run | a pill is missing, has no identifier, or the row shows under an empty live catalog | none: view only, its Model half is SL-2's |
| SL-5 | `LibraryStatusTextTests` header tests enabled: one photo of `shoot` reads "IMG_0001" with Captured "2026-06-01 10:07", Size "6000 × 4000", Kind "JPEG"; with `utcOffset` 19,800 Captured "2026-06-01 15:37"; 1970-01-01 00:00, 1969-12-31 23:59 (a negative timestamp) and 2024-02-29 23:59 format exactly; a sample reads Kind "Sample"; `.png` "PNG", `.heif` "HEIC", `.tiff` "TIFF", no extension "File"; five selected read "5 Photos" with one day "2026-06-01", photos across days "2026-06-01 – 2026-06-03" whatever the selection order | a date, an offset, a kind or a span is off | `LibraryModel.LibraryStatusText`: `+ utcOffset` dropped; month `mp + 3` → `mp + 2` in the civil conversion; `floorDiv` → `/` (a pre-1970 day off by one); span `min`/`max` swapped (`LibraryStatusTextTests`) |
| SL-6 | `LibraryInspectorSnapshots` `library-inspector` and `library-inspector-several`; the header carries `library.inspector.header`; J12 step 6 | the header is missing, doubled or unidentified | none: view only, its Model half is SL-5's |
| SL-7 | `LibraryLayoutSnapshots`: for every width of 7.3, inspector 200/240/360 and cell 80…320 in 40 pt steps, `LibraryLayout().gridColumns` equals `GridSelection.columns(width: content − 2·SuiteSpacing.m, minimum: cell + 2·SuiteSpacing.xs, spacing: SuiteSpacing.m)`; `LibraryLayout()`'s defaults equal `SuiteSize.sidebarWidth.ideal`, `inspectorWidth.ideal`, `SuiteSpacing.m`, `SuiteSpacing.xs`, `SuiteSize.canvasInset`; the three PNGs | the Model and SuiteUI disagree, or a token moved | none: test only |
| SL-8 | the scoped run after SL-8: no `library` finding in this feature's views; J12 and J11 green | a status or inspector control has no identifier | none: identifiers only |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Layout spec 7.3 (model) | exact | `LibraryLayoutTests` (SL-1), `LibraryLayoutSnapshots` (SL-7) |
| Layout spec 7.3 (journey) | 0.5 pt; loupe margins 1 pt | J12 (SL-3, SL-4, SL-6) |
| Audit exit 7.2 | `library` identifier and unnamed to 0, or each left one owned by a filed issue; J12's shots add nothing | SL-8 on a scoped run |
| QB-V5 | every new state, Light and Dark | `LibraryStatusSnapshots`, `LibraryInspectorSnapshots`, `LibraryLayoutSnapshots` |
| Status row cost | `statusRow` on 10,000 ≤ 0.1 ms release (1 ms debug gate) | `LibraryStatusTextTests.statusRowWithinBudget` (SL-2) |
| QB-F1 no dead controls | pills and the header are text, not controls; J11 unchanged | J11 (spine) |

## Done check

Per slice (`lead.md`, contract rule 6):

- **SL-a:** SL-1 and SL-2 merged; MJ1 and `LibraryLayoutTests` pass among
  the Model tests of a library-scoped run that contains SL-2; every
  mutation in both plans caught.
- **SL-b:** SL-3 and SL-4 merged; J12 green on a library-scoped run that
  contains SL-4; every app built.
- **SL-c:** SL-5 to SL-8 merged; J12 (with step 6) green on a scoped run
  that contains SL-8; SL-5's mutations caught; no `library` audit count
  over the baseline and none left without an owning issue.

Then `Belt-Contact-Sheet: <run link>` on the feature issue.

## Review notes folded in

- **Window size.** Blueprint 4.1 lists `-LibraryWindowSize`; `LibraryLaunch`
  parses it but nothing applies it, while `SuiteWindow` already honours
  `-SuiteWindowSize` (Design's shell journeys use it). Blueprint 7.3.2 runs
  J12 at 880 and 1024 only; it launches all five widths here, as Halo's
  does, checking only what lies on the runner's display. J12 launches with
  `-SuiteWindowSize`, so this feature needs neither `LibraryApp.swift` nor
  `LibraryWindow.swift`.
- **The grid's zoom pill.** #185 asked for a zoom of 160 pt = 100%;
  blueprint 6.2 and S-L7 (#1184) replace it with no zoom pill in the grid
  and a "160 pt" pill. The blueprint wins.
- **One header.** #185 and 6.2 put the facts in `InspectorHeader`.
  `MetadataInspector` (not ownable here) draws its own header, so the one
  header moves above the tabs, where it also names the photo while the
  Develop tab is open, and the MetadataInspector header gap drops the other.
- **No export pill.** Export's progress shows in its sheet, which covers
  the row; a pill would only repeat it.
- **Save pill only on problems.** The catalog saves after every change, so
  a "Saving" pill would flicker; only a refused or failed save shows.
- **Reachability.** `LibraryWindow.swift`, `LibraryCommands.swift` and
  `MetadataInspector.swift` are owned by features with no order against
  this one (filters-collections, metadata-more), and a new `Sources/` file
  needs a `c4-planned.json` entry first; so every change here sits in the
  four Sources files the blueprint gives `library-status`, `library-app-browse`
  and `library-app-inspector`.

## Open questions

1. **Command palette.** Asked for: one field that finds every menu command
   by name and runs it. SuiteUI has none yet: #7 (`CommandPalette`,
   `PaletteFilter`, Command-K) is open, p3, out of SuiteUI's v1. Library's
   half needs a ⌘K item in `LibraryCommands.swift`, the presentation in
   `LibraryWindow.swift`, and a Model list of every command
   (`LibraryCommandList.swift`, so a Linux test proves the list equals 6.2's
   menu) plus `LibraryWindow+Palette.swift`, which maps each command to its
   `LibraryMenu` action with an exhaustive switch. None of those files can
   be owned in wave 3. Meanwhile macOS's Help menu search already finds
   every menu item by name, disabled ones included. Recommendation: re-rank
   #7 to p2, add the two files to `c4-planned.json`, and fold the Library
   half into filters-collections (wave 5), which already takes
   `LibraryCommands.swift` and `LibraryWindow.swift`.
2. **Import pill and progress row.** Import shows both the content's
   progress row and the status pill. Keep both (the row has room for a
   Cancel later), or let the pill replace the row once S-L5 lands?
3. **`LibraryLayout` has no runtime caller.** It is the spec the tests
   check SuiteUI against (blueprint 7.3). The lazier path is
   `GridSelection.columns` plus the snapshots alone; this packet keeps it
   because the blueprint names it and it keeps the column rule testable on
   Linux.
