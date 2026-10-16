# Feature packet: metadata-more

**Feature:** keywords and camera details. Select a photo and the Info tab
shows its camera, lens, aperture, shutter, ISO, focal length and date taken,
read from its Exif at import. Type keywords onto a selection (one undo step,
with suggestions from the catalog's keywords), remove them, and give photos a
title and a caption. Every one of those, plus rating and label, goes into an
XMP sidecar next to the file; the original file is never written. A search
field narrows the grid by keyword, title, caption or camera field.
**Line:** `line:library` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/metadata-more`

**Covers:** #744 (closes with MD-22, which carries `feature-done`).

**Depends on:** the import feature issue (scan and import path). It also
takes over files built in earlier waves, so `depends` names their features:
cull (`MetadataEditing.swift`, `MetadataInspector.swift`,
`LibraryWindow+Cull.swift`, `LibraryMetadataSnapshots.swift`, and
`cullTargets`), persist (`Live/LiveCatalogCoding.swift`, live), and
status-and-layout (`LibraryInspector.swift`). In its own wave it shares the
window shell (`LibraryWindow.swift`, `LibraryCommands.swift`) and the
shown-photos filter (`LibraryCatalog.shownItems`) with filters-collections,
so the slices that touch those files wait on that feature (slice waits, not
`depends`: same wave). No creative-core issue: Exif comes from ImageIO in
`Platform/`, and the XMP packet is plain text the Model writes. SuiteUI
(soft waits, to file as `needs-ui`, `line:suiteui`, plain SwiftUI
placeholders until they land):

- **S-L9 `InspectorTokenRow`**: an inspector row of removable tokens that
  wraps; a token can be partial ("Beach 3 of 5", drawn dimmer, a click makes
  it whole); an inline add field with a suggestions list; each token is a
  Button with an accessibility label and a remove action.
- **S-L10 `InspectorTextRow`**: a one-line or multi-line text value in the
  inspector that commits on Return or when focus leaves (Option-Return is a
  new line in the multi-line form), with a "Mixed" placeholder.

Blueprint sections: 0.2 (no file decode in the engine), 2.2 and 2.3
(`library-later`, `library-app-inspector`, `library-app-platform`), 3 tier 2
row 3 and tier 3 row 1, 4.1 (fixtures, values, identifiers), 5.3
(`PhotoDecoding`, `CatalogCoding`), 5.7 (`recordEdit`), 7.1 (QB-LIB-4's
`order` rule), 7.4 (QB-LIB-V7), 8.3 (wave 5).

**Shared docs.** No task edits `docs/c4/model.json`, `docs/design.md`,
`docs/review-rubric.md`, the blueprint or `c4-planned.json`: the supervisor
folds in the component descriptions and the `QB-LIB-M*` and `QB-LIB-V8`,
`V9` ids below. Every new source file sits where `c4-planned.json` already
has an owner (`Sources/LibraryModel/Contracts/`, `Fakes/`,
`Sources/LibraryApp/Platform/`, `LibraryKeywords.swift`), so the planned C4
ownership check passes without an edit. There is no new App view file:
`c4-planned.json` names every App file, so the views go in
`LibraryInspector.swift` and `MetadataInspector.swift` (see Open questions).

**What people complain about in this area, and what this fixes** (behaviour
only, clean-room; most-used first):

1. Tagging photos one at a time, and one undo per photo. Here a keyword
   typed on a selection lands on every photo as one step ("Undo Add
   Keywords").
2. Near-duplicate keywords ("beach", "Beach ", "beach  sunset"). Input is
   trimmed, inner spaces collapsed, and matched without regard to case; a
   keyword the catalog already has keeps the catalog's spelling.
3. Keywords that only one app can see. Each change writes an XMP sidecar
   (ISO 16684-1) that other tools read.
4. Apps that rewrite the original file (changed bytes, new dates, broken
   backups). Library never opens an original for writing; a test hashes it.
5. A sidecar another tool wrote, overwritten and lost. Library replaces only
   sidecars it wrote and says so for the rest.
6. Camera details shown as raw numbers ("0.004", "2.79999"). They read
   "1/250 s" and "f/2.8".
7. A mixed selection hiding which photos have a keyword. Partial keywords
   show "3 of 5"; one click adds it to all, × removes it from all.
8. Search that needs a separate dialog and can't find a lens or an ISO. One
   field, `lens:50`, `iso:>1600`, `keyword:beach`, or plain words.

**From the future** (cheap here, rare elsewhere):

- **Ranges, not "Mixed".** Several photos selected: "ISO 100–3200",
  "f/1.8–f/8", "2 cameras", "1 Jun – 3 Jun 2026".
- **Suggestions from the moment.** With nothing typed, the keyword field
  suggests the keywords on photos taken within an hour of the selection,
  then the ones that go with keywords the selection already has.
- **Click a detail to find its siblings.** A camera or lens value in the
  Info tab is a button that searches for it (`lens:"50mm F1.8"`).

## Slices

Every slice waits on the contract slice MD-a; MD-b, MD-c, MD-d and MD-e then
run side by side until their views, which share the inspector and window
files, line up one after another.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| MD-a | Every photo carries keywords, a title, a caption and camera details, the sidecar contract has a fake and a live default that says it isn't connected, the `cameras` fixture opens with camera details, and every later slot exists. | MD-1, MD-2, MD-3, MD-4 | MD-MJ1 | cull (MD-4: `MetadataEditing.swift`) |
| MD-b | Selecting a photo shows its camera, lens, aperture, shutter, ISO, focal length and date taken in the Info tab, read from its Exif at import; several photos show ranges and counts. | MD-5, MD-6, MD-7, MD-8 | MD-J1 | MD-a (MD-5); status-and-layout (MD-8) |
| MD-c | Adding or removing keywords on a selection, or setting its title or caption, is one named undo step with suggestions from the catalog's keywords, and the catalog keeps them across relaunch. | MD-9, MD-10, MD-11, MD-12, MD-13 | MD-J2 | MD-a (MD-9); cull (MD-10, MD-11, MD-13); persist (MD-12); MD-b (MD-13); filters-collections (MD-13); crop and export (MD-13: they edit `LibraryWindow.swift` in wave 4) |
| MD-d | Each keyword, title, caption, rating or label change on a photo with a file is written to an XMP sidecar beside it, the original never changes, and a sidecar another app wrote is left alone with a reason. | MD-14, MD-15, MD-16, MD-17, MD-18 | MD-J3 | MD-a (MD-14); MD-c (MD-18); cull (MD-18); filters-collections (MD-18) |
| MD-e | Typing in the window's search field shows only the photos whose keywords, title, caption or camera details match, `field:value` narrows to one field, and a camera value in the Info tab searches for itself. | MD-19, MD-20, MD-21, MD-22 | MD-J4 | MD-a (MD-19); filters-collections (MD-21, MD-22); MD-d (MD-22) |

## Journey steps

Each journey file declares its own `XCTestCase` class (packets.md). (F)
steps run on `-LibraryFixture cameras`; (L) steps write real files and launch
with `-LibraryImportFolder <dir> -LibraryImportOnLaunch` and a fresh
`-LibraryCatalogDir`. Every step takes a `shot`.

**MD-MJ1 · `LibraryCamerasFixtureTests.testContractWalk`** (Linux Model
walk, MD-3)
1. `LibraryLaunch(arguments: ["-LibraryFixture", "cameras"])`: 24 photos;
   23 have camera details, `IMG_0024` has none; `IMG_0001`'s camera is
   `Fixture Optics FX-1`, lens `24-70mm F2.8`, ISO 100.
2. Scan `/x` with that fixture's `FakeDecoder`, import through
   `LiveImporter(decoder:)`: every imported photo carries the same
   `CameraDetails` as its fixture photo.
3. On `.fake`, `services.sidecars` writes bytes for `/x/IMG_0001.jpg` and
   reads them back equal; on `-LibraryFakeMode fail` the write throws.
4. `.live(...)` without a sidecar writer lists
   `unavailable["sidecars"] == "Writing sidecars isn't connected yet (metadata-more)."`.

**MD-J1 · `LibraryCameraJourneyTests.testCameraDetailsInInfo`**
(`UITests/LibraryJourneyTests+Camera.swift`; MD-5 writes it skipped, MD-8
turns it on)
1. (F) Launch on `cameras`; View > Sort By > Name; click `IMG_0001`. Shot
   `camera-one`. The Info tab's Camera section reads, in order: Camera
   `Fixture Optics FX-1`, Lens `24-70mm F2.8`, Aperture `f/2.8`, Shutter
   `1/2000 s`, ISO `ISO 100`, Focal Length `24 mm`, Taken (the date).
   Identifiers `library.metadata.camera.<field>`.
2. (F) Shift-click `IMG_0006`. Shot `camera-range`. Camera reads
   `2 cameras`, ISO `ISO 100–3200`.
3. (F) Click `IMG_0024`. Shot `camera-none`. The section reads "No camera
   details" and has no rows.
4. (L) Write `a.jpg` (Make `Test Maker`, Model `TM-10`, LensModel
   `35mm F1.4`, ISO 800, ExposureTime 0.004, FNumber 2.0, FocalLength 35)
   and `b.png` (no Exif) with this file's own ImageIO helper; import on
   launch; click `a`. Shot `camera-live`. Expect `Test Maker TM-10`,
   `35mm F1.4`, `f/2`, `1/250 s`, `ISO 800`, `35 mm`; click `b`: "No camera
   details".
States: none selected (the collection header, no Camera section), no
details, one photo, several.

**MD-J2 · `LibraryKeywordsJourneyTests.testKeywordsOnASelection`**
(`UITests/LibraryJourneyTests+Keywords.swift`; MD-9 writes it skipped, MD-13
turns it on)
1. (F) Launch on `cameras`; Sort By Name; click `IMG_0010`, Shift-click
   `IMG_0012`. Click `library.metadata.keywords.field`, type
   `beach,  Sunset ,beach` and Return. Shot `keywords-added`. Tokens
   `Beach` and `Sunset` (the fixture's spelling wins over `beach`), each
   whole.
2. (F) Click the grid; open Edit. Shot `keywords-undo-name`. The Undo item
   reads "Undo Add Keywords". Choose it: no tokens. Redo: both back.
3. (F) Click `IMG_0012` alone; Command-click `IMG_0001`. Shot
   `keywords-partial`. `Beach` is whole (the fixture gives `IMG_0001`
   Beach) and `Sunset` is partial, its label `Sunset, 1 of 2`. Click
   `Sunset`: it becomes whole; Undo reads "Undo Add Keyword".
4. (F) Click `IMG_0007` alone (no keywords); click the field, type `su`.
   Shot `keywords-suggest`. The suggestions read `Sunset` (on 8 photos by
   now), then `Summer` (on 1). Press Escape.
5. (F) Click `IMG_0001`; click the remove button on `Beach`
   (`library.metadata.keyword.beach.remove`). Undo reads "Undo Remove
   Keyword".
6. (F) Type `Harbour at dawn` in Title (`library.metadata.title`), Return;
   Caption (`library.metadata.caption`) `Low tide`, Return. Undo reads
   "Undo Set Caption", then "Undo Set Title".
7. (L) After an import of three JPEGs: add keyword `Pier` to all three; wait
   for `library.catalog` `saved`; terminate and relaunch on the same
   catalog. Shot `keywords-relaunch`. All three show `Pier`.
States: nothing selected (no Keywords section), empty field, partial
tokens, suggestions open.

**MD-J3 · `LibrarySidecarJourneyTests.testKeywordsWriteASidecar`**
(`UITests/LibraryJourneyTests+Sidecars.swift`; MD-14 writes it skipped,
MD-18 turns it on)
1. (L) Write `IMG_1.jpg` and `IMG_2.jpg`, and `IMG_2.xmp` holding a packet
   with no Library marker (another app's). Hash both JPEGs and note their
   modification dates. Import on launch.
2. (L) Click `IMG_1`; add keyword `Pier`; rate 3. Shot `sidecar-saved`.
   `library.metadata.sidecar` reads `Saved to IMG_1.xmp`. The test reads
   `IMG_1.xmp` from disk: it holds `Pier` in `dc:subject` and
   `xmp:Rating` 3.
3. (L) Click `IMG_2`; add keyword `Pier`. Shot `sidecar-foreign`. The
   sidecar row reads `IMG_2.xmp was written by another app; Library left it
   unchanged.`; `IMG_2.xmp` is byte-equal to what step 1 wrote.
4. (L) Both JPEGs hash and date as in step 1.
5. (F) Relaunch on `cameras` with `-LibraryFakeMode fail`; add a keyword to
   `IMG_0001`. Shot `sidecar-failed`. The row reads `Not saved: The folder is
   read-only.`; the keyword is still on the photo.
States: sample (no file: "Samples have no file, so no sidecar."), saved,
foreign, failed.

**MD-J4 · `LibrarySearchJourneyTests.testSearchByKeywordAndCamera`**
(`UITests/LibraryJourneyTests+Search.swift`; MD-19 writes it skipped, MD-22
turns it on)
1. (F) Launch on `cameras`. Press Command-F. Shot `search-focus`. The
   search field (`library.search`) has focus.
2. (F) Type `lens:50`. Shot `search-lens`. The grid shows the 8 `50mm F1.8`
   photos; the status reads 8 photos.
3. (F) Replace with `iso:>1600 beach`. Shot `search-iso`. Only photos with
   ISO above 1600 and the keyword Beach.
4. (F) Press Escape. All 24 again.
5. (F) Click `IMG_0002`; in the Info tab click the Lens value. Shot
   `search-from-detail`. The field reads `lens:"50mm F1.8"` and the grid
   shows those 8.
6. (F) Open `IMG_0002` in the loupe; type in the field `lens:24`. Shot
   `search-hides-loupe`. `IMG_0002` (a 50 mm photo) is hidden, so the
   window is back in the grid with nothing selected.
States: no match (the empty collection state, "No photos match
"<text>"." with a Clear Search button), a match, cleared.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Info tab, Camera section | nothing selected: the collection header only; a photo with no details (or a sample): "No camera details" | – | – (details come with the import) |
| Info tab, Keywords, Title, Caption | nothing selected: hidden; no keywords: the add field alone, placeholder "Add Keywords" | – (an edit can't fail; refusals are no-ops with no undo step) | – |
| Info tab, Sidecar row | sample: "Samples have no file, so no sidecar."; never written: "No sidecar yet" | a write failed: "Not saved: <reason>"; a foreign sidecar: "<name>.xmp was written by another app; Library left it unchanged." | "Saving…" while a write is under way |
| Grid with a search | no match: "No photos match "<text>"." with Clear Search | – | – |

Snapshots (Light and Dark each): `LibraryCameraSnapshots.swift`
`library-camera`, `library-camera-mixed`, `library-camera-none`;
`LibraryKeywordSnapshots.swift` `library-keywords`, `library-keywords-mixed`
(partial tokens and "Mixed" title); `LibrarySidecarSnapshots.swift`
`library-sidecar-saved`, `library-sidecar-failed`, `library-sidecar-foreign`;
`LibraryMetadataSnapshots.swift` redrawn with the new rows.

## Contract slice

MD-a publishes everything the other slices compile against. A later slice's
acceptance tests are written before their code and disabled
(`@Test(.disabled("waits on MD-n"))`), so every type and method they call
must already exist: MD-a adds them, the behaviour ones as inert stubs (no
change, no undo step, empty results), and the slice that builds each fills
the body in the same file.

**`Contracts/PhotoDetails.swift`** (new; MD-1, bodies MD-6)

```swift
/// What the camera recorded (CIPA DC-008 Exif and TIFF tags). The init trims
/// spaces and NULs, turns empty text into nil, and drops any number that is
/// not finite or not above 0.
public struct CameraDetails: Hashable, Sendable {
    public var make: String?, model: String?, lens: String?
    public var iso: Int?
    public var exposureTime: Double?   // seconds
    public var fNumber: Double?
    public var focalLength: Double?    // mm
    public static let none: CameraDetails
    public init(make: String? = nil, model: String? = nil, lens: String? = nil, iso: Int? = nil,
                exposureTime: Double? = nil, fNumber: Double? = nil, focalLength: Double? = nil)
    public var isEmpty: Bool { get }
    /// From ImageIO's Exif and TIFF dictionaries, keyed by tag name ("Make",
    /// "Model", "LensModel", "ISOSpeedRatings", "ExposureTime", "FNumber",
    /// "FocalLength"). MD-1: returns `.none`; MD-6 reads the tags.
    public init(exif: [String: Any], tiff: [String: Any])
    /// "Fixture Optics FX-1" (the make left off when the model starts with it),
    /// "1/250 s" or "2.5 s", "f/2.8" or "f/8", "35 mm", "ISO 400". MD-1: nil; MD-6 fills them.
    public var cameraText: String? { get }
    public var shutterText: String? { get }
    public var apertureText: String? { get }
    public var focalText: String? { get }
    public var isoText: String? { get }
}

/// The Info tab's rows, most-used first (inferred: what the photo is, then
/// the exposure, then when).
public enum CameraField: String, CaseIterable, Sendable {
    case camera = "Camera", lens = "Lens", aperture = "Aperture", shutter = "Shutter",
         iso = "ISO", focalLength = "Focal Length", taken = "Taken"
}
public enum CameraRowValue: Hashable, Sendable { case text(String), dates(Date, Date) }
public struct CameraRow: Hashable, Sendable {
    public let field: CameraField
    public let value: CameraRowValue
    /// The search that finds this value (`lens:"50mm F1.8"`); nil for ranges and dates.
    public let search: String?
}
extension CameraRow {
    /// One row per field any photo has, in `CameraField` order: a shared
    /// value, a range ("ISO 100–3200"), or a count ("2 cameras"). MD-1: []; MD-6.
    public static func rows(for photos: [PhotoItem]) -> [CameraRow]
}
extension LibraryCatalog {
    /// The selected photos in the sort order (what the inspector shows). MD-1.
    public var selectedPhotos: [PhotoItem] { get }
    public var selectedCameraRows: [CameraRow] { get }   // CameraRow.rows(for: selectedPhotos)
}
extension MetadataInspectorID {
    public static func camera(_ field: CameraField) -> String   // "library.metadata.camera.lens"
}
```

**`PhotoItem.swift`** (MD-1) grows four fields, each with a default in the
init, and `withSize` / `withID` carry them:

```swift
public internal(set) var keywords: [String]   // normalized, sorted without regard to case, unique
public internal(set) var title: String        // "" when none
public internal(set) var caption: String
public let camera: CameraDetails              // .none for samples and files without Exif
```

**`Contracts/LibraryValues.swift`** (MD-1): `ImportCandidate` gains
`public var camera: CameraDetails` with `camera: CameraDetails = .none` last
in its init, so today's callers compile unchanged.

**The `cameras` fixture** (`LibraryFixtures.swift`, MD-3; `-LibraryFixture
cameras`, and `cameras-unimported` for an empty start whose fakes "find"
it): `shoot`'s 24 photos, with names, dates and sizes unchanged, plus, for
`IMG_n`:

| Field | Rule | `IMG_0001` |
|---|---|---|
| make, model | `Fixture Optics`; `FX-1` for odd n, `FX-2` for even | Fixture Optics FX-1 |
| lens, aperture | n mod 3 = 1: `24-70mm F2.8`, f/2.8; = 2: `50mm F1.8`, f/1.8; = 0: `100mm F2.8 Macro`, f/8 (8, 8 and 7 photos) | 24-70mm F2.8, f/2.8 |
| focal length | the 24-70 at 24, 35, 50, 70 mm in turn; the others at 50 and 100 | 24 mm |
| shutter | 1/2000, 1/500, 1/125, 1/30 s for (n − 1) mod 4 = 0…3 | 1/2000 s |
| ISO | 100 · 2^((n − 1) mod 7): 100 to 6400 | 100 |
| keywords | `Beach` on 1–4, 13 and 14; `Sunset` on 3–6; `Summer` on 20 | Beach |
| `IMG_0024` | no camera details at all (a file without Exif) | – |

No product or company name: the camera and lenses are invented. The fixture
is a new name, so `shoot` and every journey on it stay as they are.

**`Contracts/SidecarContracts.swift`** (new; MD-2)

```swift
/// Writes XMP sidecars beside photo files. Live: `XMPSidecarWriter`
/// (LibraryApp/Platform). Fake: `FakeSidecars` (in memory).
public protocol SidecarWriting: Sendable {
    /// The sidecar's bytes; nil when there is none.
    func read(sidecar path: String) async throws -> Data?
    /// Writes `data` to `path` atomically. Throws `writeFailed` when `path`
    /// is not a `.xmp` file, is an image file, or holds a sidecar Library
    /// didn't write. Never opens any other file for writing.
    func write(_ data: Data, sidecar path: String) async throws
}
/// `.live`'s default until the window passes `XMPSidecarWriter`: every call
/// throws `invalid(unavailable)`.
public struct UnconnectedSidecars: SidecarWriting {
    public static let unavailable = "Writing sidecars isn't connected yet (metadata-more)."
}
/// What a sidecar says about one photo: the fields it shares with other tools.
public struct SidecarFields: Hashable, Sendable {
    public var keywords: [String], title: String, caption: String
    public var rating: Int        // 0...5, or -1 for a reject (the XMP Basic rule)
    public var label: PhotoLabel?
    public init(photo: PhotoItem)
    public var isEmpty: Bool { get }   // nothing to say: no keywords, title, caption, rating or label
}
public struct SidecarWrite: Hashable, Sendable {
    public var photoID: String, path: String, fields: SidecarFields, data: Data
}
```

`LibraryServices` (MD-2) gains `public var sidecars: any SidecarWriting`:
the init takes `sidecars: any SidecarWriting = UnconnectedSidecars()` after
`writer:`, `.fake` uses `FakeSidecars(mode:)`, and
`.live(decoder:writer:store:sidecars: any SidecarWriting = UnconnectedSidecars())`
adds `unavailable["sidecars"]` while it is the unconnected one.
`LibraryLaunch.services(decoder:writer:store:sidecars:)` passes it through
with the same default. Every existing call site compiles unchanged.

**`Fakes/FakeSidecars.swift`** (new; MD-2): an actor keeping `files:
[String: Data]`, `foreign: Set<String>` (paths a test marks as another app's)
and `-LibraryFakeMode` (fail throws `writeFailed(path:, reason: "The folder
is read-only.")`).

**Slots** (MD-4, inert until their slice):

| File | Slot | Filled by |
|---|---|---|
| `LibraryKeywords.swift` (new) | `KeywordState {name, count, total; isPartial}`; `keywordStates: [KeywordState]`; `addKeywords(_ text: String)`; `addKeyword(toAll name: String)`; `removeKeyword(_ name: String)`; `keywordSuggestions(prefix: String, limit: Int = 8) -> [String]`; `keywordHelp: String?` ("Select a photo to add keywords." with no targets: real in MD-4); `MetadataInspectorID.keywordsField`, `.keyword(_:)`, `.removeKeyword(_:)`, `.title`, `.caption`, `.sidecar` | MD-10 |
| `MetadataEditing.swift` | `setTitle(_:)`, `setCaption(_:)`; `PhotoMetadata.photoTitle`, `.caption: MetadataValue<String>` | MD-11 |
| `Contracts/XMPSidecar.swift` (new) | `enum XMPSidecar { static func encode(_ fields: SidecarFields) -> Data; static func isWrittenByLibrary(_ data: Data) -> Bool; static func path(for photoPath: String, siblings: Set<String>) -> String }`; `extension LibraryCatalog { func sidecarWrites(after written: [String: SidecarFields]) -> [SidecarWrite]; func sidecarStatus(for id: String, written: [String: SidecarFields], failures: [String: String], writing: Set<String>) -> String? }` | MD-15 (encode, marker, path), MD-16 (plan, status) |
| `Contracts/PhotoSearch.swift` (new) | `struct PhotoSearch: Hashable, Sendable { init(_ text: String); var text: String; var isEmpty: Bool; func matches(_ photo: PhotoItem) -> Bool }` (empty text and `isEmpty` are real in MD-4; `matches` true until MD-20); `extension LibraryCatalog { func searchSuggestions(prefix: String, limit: Int = 8) -> [String] }`; `MetadataInspectorID.search = "library.search"` | MD-20 |

The search's stored state is not a slot: `LibraryCatalog.search` and
`setSearch(_:)` are added by MD-21 itself, because `LibraryCatalog.swift`
waits on filters-collections and the contract slice must not.

**Catalog methods each journey calls** (filled by their tasks):

| Journey | Methods | Undo step |
|---|---|---|
| MD-J1 | `selectedCameraRows` | – |
| MD-J2 | `addKeywords(_:)`, `addKeyword(toAll:)`, `removeKeyword(_:)`, `keywordSuggestions(prefix:)`, `setTitle(_:)`, `setCaption(_:)` | "Add Keyword" or "Add Keywords", "Remove Keyword", "Set Title", "Set Caption" |
| MD-J3 | `sidecarWrites(after:)`, `sidecarStatus(for:written:failures:writing:)` | – (never an undo step) |
| MD-J4 | `setSearch(_:)`, `searchSuggestions(prefix:)`, `CameraRow.search` | – (a search is a view, not an edit) |

The XMP namespace and marker are decided here: Library writes the
properties of the published XMP schemas (Dublin Core `dc:subject` as a
`rdf:Bag`, `dc:title` and `dc:description` as `rdf:Alt` with
`xml:lang="x-default"`, XMP Basic `xmp:Rating` and `xmp:Label`) plus one
property of its own, `lib:Writer="Library"`, in the namespace
`https://github.com/qbtrix/creative-apps/ns/library/1.0/` (a URI we control;
it need not resolve). `isWrittenByLibrary` looks for that namespace and
property. Sidecar names: `IMG_0001.xmp` beside `IMG_0001.jpg` (the name other
tools look for); when another catalog photo in the same folder has the same
stem (`IMG_0001.heic`), both use their full name (`IMG_0001.jpg.xmp`), so two
photos never share a sidecar.

## Pseudocode

```
CameraDetails(exif:, tiff:):                                       # MD-6
  make = text(tiff["Make"]); model = text(tiff["Model"]); lens = text(exif["LensModel"])
  iso = (exif["ISOSpeedRatings"] as? [Int])?.first ?? exif["ISOSpeedRatings"] as? Int
  exposureTime, fNumber, focalLength = positive finite Double of their tags
  text(v): String, trimmed of spaces and NULs, nil when empty
shutterText: t >= 1 → "\(t trimmed) s"; else n = round(1/t); |1/n - t|/t < 0.05 → "1/\(n) s" else one decimal "0.3 s"
apertureText: "f/" + one decimal, ".0" dropped                      # 2.0 → "f/2"
cameraText: model starts with make (any case) → model; else make + " " + model; one of them alone
rows(for photos):                                                  # MD-6
  for field in CameraField.allCases:
    values = photos' values that exist
    none → skip; all equal → .text(value), search for camera and lens
    text fields → .text("\(distinct count) cameras" / "lenses")
    numeric → .text(min–max in that field's format: "ISO 100–3200", "f/1.8–f/8", "24–70 mm", "1/2000–1/30 s")
    taken → .dates(min, max)

normalize(text) → [String]:                                        # MD-10
  split on ","; trim; collapse inner runs of spaces; drop empty
  dedupe without regard to case (first spelling wins)
  each: the catalog's existing spelling of it if one exists
addKeywords(text):
  ids = cullTargets; names = normalize(text); guard !ids.isEmpty, !names.isEmpty
  recordEdit(names.count == 1 ? "Add Keyword" : "Add Keywords", ids: ids) { photo.keywords = sortedUnion(photo.keywords, names) }
  (recordEdit records nothing when every photo already had them)
removeKeyword(name): recordEdit("Remove Keyword", ids: cullTargets) { remove name, any case }
keywordStates: for each keyword on any target: count of targets with it, total = targets
keywordSuggestions(prefix):
  pool = every keyword in the catalog with its photo count, minus the ones every target has
  prefix empty → rank: on photos taken within 1 h of any target, then co-occurring with the targets' keywords, then count
  else keep names where some word starts with prefix (any case); rank: whole name starts with it, then co-occurrence, then count, then name
  first `limit`

setTitle(text) / setCaption(text):                                  # MD-11
  t = trimmed; recordEdit("Set Title", ids: selection) { photo.title = t }   # no step when unchanged

LiveCatalogCoding (per photo record):                              # MD-12
  encode: write "keywords", "title", "caption", "camera" only when non-empty (camera: only its non-nil keys)
  decode: decodeIfPresent for each, defaults [], "", "", .none   # catalog-v1.json stays byte-equal

XMPSidecar.encode(fields):                                         # MD-15
  <?xpacket begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"?> <x:xmpmeta xmlns:x="adobe:ns:meta/"> <rdf:RDF …>
  <rdf:Description rdf:about="" xmlns:dc xmlns:xmp xmlns:lib lib:Writer="Library">
    xmp:Rating when rating != 0; xmp:Label when label; dc:subject Bag when keywords;
    dc:title / dc:description Alt x-default when non-empty
  </…> <?xpacket end="w"?>   every text XML-escaped (& < > " '), control characters but tab and newline dropped
path(for p, siblings): stem = p minus extension; another sibling in p's folder with the same stem → p + ".xmp" else stem + ".xmp"

sidecarWrites(after written):                                      # MD-16
  siblings = Set(items.compactMap(\.path))
  for photo with a path: f = SidecarFields(photo)
     if written[id] == f: skip; if written[id] == nil and f.isEmpty: skip     # never litter folders
     emit SidecarWrite(id, path(for: photo.path, siblings), f, encode(f))
sidecarStatus(id): no path → "Samples have no file, so no sidecar."
  writing ∋ id → "Saving…"; failures[id] → it ("Not saved: …" or the foreign sentence)
  written[id] == fields → "Saved to <file name>"; else "No sidecar yet"

XMPSidecarWriter.write(data, path):                                # MD-17, macOS
  guard path ends ".xmp", PhotoFileKind.kind(forFileName:) == nil else throw writeFailed
  if file exists: guard XMPSidecar.isWrittenByLibrary(contents) else throw writeFailed(path, "<name> was written by another app; Library left it unchanged.")
  data.write(to: path, options: .atomic)                            # temp file, then rename
  (no FileHandle, no write to any path but `path`)

sidecar area (LibraryWindow+Cull.swift, MD-18):
  launch: written = SidecarFields for every photo already in the catalog (they were written when they changed)
  saveRevision changed: plan = model.sidecarWrites(after: written minus writing)
    for each: writing.insert; Task.detached { try await services.sidecars.write(data, sidecar: path) }
      → main actor: success: written[id] = fields, failures[id] = nil; failure: failures[id] = message; writing.remove

PhotoSearch(text):                                                 # MD-20
  tokens = split on spaces outside double quotes
  token "field:value" with field in keyword|title|caption|camera|lens|iso|f|mm → that field
     iso, f, mm: value ">n", "<n", ">=n", "<=n" or "n"; a bad number makes the token plain text
  else plain text: matches name, any keyword, title, caption, cameraText, lens (contains, any case)
  matches(photo) = every token matches
setSearch(text):                                                   # MD-21
  search = PhotoSearch(text); rebuildOrder(); select(selection)
  (the hand-written `==` in LibraryCatalog.swift gains `lhs.search == rhs.search`)
  if mode == .loupe and focused photo not in order: mode = .grid; focusedItemID = nil   # #156's rule
shownItems: the collection's photos, then `search.isEmpty ? all : filter(search.matches)`
editCanReorder: … || !search.isEmpty     # a keyword edit can hide a photo under a search
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: metadata-more`,
`Slice: <slice>`, then `Mutate:` score lines for each plan it owns,
`Fast-Check: pass`, `Head:`. MD-22 carries `feature-done` and sets
`metadata-more.wave.json`'s `status` to `built`. Paths are from the repo
root; `LM/` is `Sources/LibraryModel/`, `LA/` is `Sources/LibraryApp/`,
`LT/` is `Tests/LibraryModelTests/`, `AT/` is `Tests/AppSnapshotTests/`,
`MU/` is `Tests/mutations/` (the `.wave.json` spells every path out).

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| MD-1 | #744 (part) | `CameraDetails` with its cleaning init, `CameraField`, `CameraRow` (rows and texts as stubs), `selectedPhotos`, `selectedCameraRows`; `PhotoItem` keywords, title, caption, camera; `ImportCandidate.camera` | `LM/Contracts/PhotoDetails.swift`, `LM/PhotoItem.swift`, `LM/Contracts/LibraryValues.swift`, `LT/LibraryPhotoDetailsTests.swift`, `MU/LibraryModel.PhotoDetails.json`, `MU/LibraryModel.PhotoItem.json` | – | ~260, 6 |
| MD-2 | – | The sidecar contract: `SidecarWriting`, `UnconnectedSidecars`, `SidecarFields`, `SidecarWrite`; `FakeSidecars`; `services.sidecars` on `.fake` and `.live`; the launch passes it | `LM/Contracts/SidecarContracts.swift`, `LM/Fakes/FakeSidecars.swift`, `LM/LibraryServices.swift`, `LM/LibraryLaunch.swift`, `LT/LibrarySidecarContractTests.swift`, `MU/LibraryModel.SidecarContracts.json`, `MU/LibraryModel.FakeSidecars.json`, `MU/LibraryModel.LibraryServices.json` | MD-1 | ~300, 8 |
| MD-3 | – | The `cameras` fixture; `FakeDecoder` and `LiveImporter` carry camera details from the scan to the photo; walk MD-MJ1 | `LM/LibraryFixtures.swift`, `LM/Fakes/FakePlatform.swift`, `LM/Live/LiveImporter.swift`, `LT/LibraryCamerasFixtureTests.swift`, `MU/LibraryModel.LibraryFixtures.json`, `MU/LibraryModel.LiveImporter.json` | MD-1, MD-2 | ~240, 6 |
| MD-4 | – | The slots: `LibraryKeywords.swift`, title and caption in `MetadataEditing.swift`, `XMPSidecar.swift`, `PhotoSearch.swift`, inert; `keywordHelp` and the identifiers real | `LM/LibraryKeywords.swift`, `LM/MetadataEditing.swift`, `LM/Contracts/XMPSidecar.swift`, `LM/Contracts/PhotoSearch.swift`, `LT/LibraryMetadataSlotsTests.swift` | MD-1, MD-2 | ~220, 5 |
| MD-5 | – | Check first for MD-b: camera rows, decode, snapshot and MD-J1, all disabled or skipped | `LT/LibraryCameraRowsTests.swift`, `AT/LibraryCameraDecodeTests.swift`, `AT/LibraryCameraSnapshots.swift`, `UITests/LibraryJourneyTests+Camera.swift` | MD-1, MD-3 | ~330, 4 |
| MD-6 | #744 (part) | Camera details read and shown: `CameraDetails(exif:tiff:)`, the display texts, `CameraRow.rows(for:)` with ranges and counts | `LM/Contracts/PhotoDetails.swift`, `LT/LibraryCameraRowsTests.swift`, `MU/LibraryModel.PhotoDetails.json` | MD-5 | ~280, 3 |
| MD-7 | #744 (part) | `ImageIODecoder.scan` hands each file's Exif and TIFF dictionaries to `CameraDetails(exif:tiff:)` | `LA/Platform/ImageIODecoder.swift`, `AT/LibraryCameraDecodeTests.swift` | MD-5, MD-6 | ~120, 2 |
| MD-8 | #744 (part) | The Info tab's Camera section: rows, "No camera details", identifiers; MD-J1 on | `LA/LibraryInspector.swift`, `AT/LibraryCameraSnapshots.swift`, `UITests/LibraryJourneyTests+Camera.swift` | MD-6, MD-7 | ~220, 3 |
| MD-9 | – | Check first for MD-c: keywords, title and caption, the catalog file, the keyword budgets, snapshots and MD-J2, all disabled or skipped | `LT/LibraryKeywordTests.swift`, `LT/LibraryCaptionTests.swift`, `LT/LibraryMetadataPersistTests.swift`, `LT/LibraryKeywordBudgetTests.swift`, `AT/LibraryKeywordSnapshots.swift`, `UITests/LibraryJourneyTests+Keywords.swift` | MD-4 | ~380, 6 |
| MD-10 | #744 (part) | Keywords: normalize, add to the targets as one step, add to all, remove, partial states, ranked suggestions | `LM/LibraryKeywords.swift`, `LT/LibraryKeywordTests.swift`, `LT/LibraryKeywordBudgetTests.swift`, `MU/LibraryModel.LibraryKeywords.json` | MD-9 | ~330, 4 |
| MD-11 | #744 (part) | Title and caption: `setTitle`, `setCaption` (trimmed, one step, none when unchanged), "Mixed" in `PhotoMetadata` | `LM/MetadataEditing.swift`, `LT/LibraryCaptionTests.swift`, `MU/LibraryModel.MetadataEditing.json` | MD-9 | ~180, 3 |
| MD-12 | #744 (part) | The catalog file keeps keywords, title, caption and camera details: optional keys, written only when set | `LM/Live/LiveCatalogCoding.swift`, `LT/LibraryMetadataPersistTests.swift`, `MU/LibraryModel.LiveCatalogCoding.json` | MD-9 | ~200, 3 |
| MD-13 | #744 (part) | Keywords, Title and Caption rows in the Info tab (S-L9, S-L10 placeholders); the window hands the inspector the edits; MD-J2 on | `LA/MetadataInspector.swift`, `LA/LibraryInspector.swift`, `LA/LibraryWindow.swift`, `AT/LibraryKeywordSnapshots.swift`, `AT/LibraryMetadataSnapshots.swift`, `UITests/LibraryJourneyTests+Keywords.swift` | MD-8, MD-10, MD-11, MD-12 | ~330, 6 |
| MD-14 | – | Check first for MD-d: XMP, the sidecar plan, the writer, snapshots and MD-J3, all disabled or skipped | `LT/LibraryXMPTests.swift`, `LT/LibrarySidecarPlanTests.swift`, `AT/LibrarySidecarWriterTests.swift`, `AT/LibrarySidecarSnapshots.swift`, `UITests/LibraryJourneyTests+Sidecars.swift` | MD-4 | ~380, 5 |
| MD-15 | #744 (part) | `XMPSidecar.encode`, `isWrittenByLibrary`, `path(for:siblings:)` | `LM/Contracts/XMPSidecar.swift`, `LT/LibraryXMPTests.swift`, `MU/LibraryModel.XMPSidecar.json` | MD-14 | ~300, 3 |
| MD-16 | #744 (part) | `sidecarWrites(after:)` and `sidecarStatus(...)` | `LM/Contracts/XMPSidecar.swift`, `LT/LibrarySidecarPlanTests.swift`, `MU/LibraryModel.XMPSidecar.json` | MD-15 | ~200, 3 |
| MD-17 | #744 (part) | `XMPSidecarWriter`: the guards, atomic write, never an original | `LA/Platform/XMPSidecarWriter.swift`, `AT/LibrarySidecarWriterTests.swift` | MD-14, MD-15 | ~200, 2 |
| MD-18 | #744 (part) | The sidecar area: seed at launch, write after each change off the main actor, the Sidecar row; the window passes `XMPSidecarWriter`; MD-J3 on | `LA/LibraryWindow+Cull.swift`, `LA/LibraryWindow.swift`, `LA/LibraryInspector.swift`, `LA/MetadataInspector.swift`, `AT/LibrarySidecarSnapshots.swift`, `UITests/LibraryJourneyTests+Sidecars.swift` | MD-13, MD-16, MD-17 | ~280, 6 |
| MD-19 | – | Check first for MD-e: search parsing, the grid under a search, its budget and MD-J4, all disabled or skipped | `LT/LibrarySearchTests.swift`, `LT/LibrarySearchOrderTests.swift`, `LT/LibrarySearchBudgetTests.swift`, `UITests/LibraryJourneyTests+Search.swift` | MD-3, MD-4 | ~330, 4 |
| MD-20 | #744 (part) | `PhotoSearch`: tokens, quoted phrases, fields, number comparisons; `searchSuggestions` | `LM/Contracts/PhotoSearch.swift`, `LT/LibrarySearchTests.swift`, `MU/LibraryModel.PhotoSearch.json` | MD-19 | ~320, 3 |
| MD-21 | #744 (part) | The grid follows the search: `search` (and in `==`), `setSearch`, `shownItems`, `editCanReorder`, the selection and the loupe kept true | `LM/LibraryCatalog.swift`, `LM/LibraryOrder.swift`, `LT/LibrarySearchOrderTests.swift`, `LT/LibrarySearchBudgetTests.swift`, `MU/LibraryModel.LibraryCatalog.json`, `MU/LibraryModel.LibraryOrder.json` | MD-19, MD-20 | ~240, 6 |
| MD-22 | #744 (closes) | The search field with suggestions, Edit > Find (Command-F), Escape clears, a camera value searches for itself; MD-J4 on; `status: built` | `LA/LibraryWindow.swift`, `LA/LibraryCommands.swift`, `LA/LibraryInspector.swift`, `UITests/LibraryJourneyTests+Search.swift` | MD-18, MD-21 | ~220, 5 |

Why each link: MD-2's `SidecarFields(photo:)` reads MD-1's new `PhotoItem`
fields; MD-3's walk uses the fake sidecars. MD-4's slots name MD-1's types
and MD-2's `SidecarFields`. Each check-first task (MD-5, MD-9, MD-14, MD-19)
compiles against the slots and owns the slice's tests (MD-5 and MD-19 also
wait on MD-3 because their tests assert facts of the `cameras` fixture, so
they are written against the fixture as it merged), and each build task
owns, and turns on, the test of its own behaviour, so build tasks never share
a test file. MD-7's decode test needs MD-6's tag reading; MD-8's (L) step
needs MD-7. MD-13, MD-18 and MD-22 share `LibraryInspector.swift` (and two of
`LibraryWindow.swift`, `MetadataInspector.swift`), so they line up after
MD-8. MD-16 builds its writes with MD-15's encoder in the same file; MD-17's
guard calls MD-15's `isWrittenByLibrary`. MD-21's `setSearch` builds MD-20's
`PhotoSearch`.

App-target tasks (MD-7, MD-8, MD-13, MD-17, MD-18, MD-22) carry no mutation
plan: rule 14's mutations target Model code, which builds on Linux. They put
every rule they can in the Model (tag reading, formats, the plan, the status
text, the marker), and their macOS test or journey is their check.

## Build waves

- Wave 1: MD-1. Independent in this wave: MD-1 alone.
- Wave 2: MD-2. Independent in this wave: MD-2 alone.
- Wave 3: MD-3, MD-4. Independent in this wave: both.
- Wave 4: MD-5, MD-9, MD-14, MD-19. Independent in this wave: all four.
- Wave 5: MD-6, MD-10, MD-11, MD-12, MD-15, MD-20. Independent in this wave: all six.
- Wave 6: MD-7, MD-16, MD-17, MD-21. Independent in this wave: all four.
- Wave 7: MD-8. Independent in this wave: MD-8 alone.
- Wave 8: MD-13. Independent in this wave: MD-13 alone.
- Wave 9: MD-18. Independent in this wave: MD-18 alone.
- Wave 10: MD-22 (final, `feature-done`). Independent in this wave: MD-22 alone.

Longest chain: MD-1 → MD-2 → MD-3 → MD-5 → MD-6 → MD-7 → MD-8 → MD-13 →
MD-18 → MD-22 (10).

Chain of 10: MD-1 → MD-2 → MD-3 are the contract the rest compile against;
MD-5 → MD-6 → MD-7 → MD-8 is check, rule, decode, view; MD-8 → MD-13 → MD-18
→ MD-22 share `LibraryInspector.swift`, and `c4-planned.json` names every App
file, so they can't split into new view files (Open questions: three new App
files would cut the chain to 7). The Model work of MD-c, MD-d and MD-e runs
beside MD-b in waves 4 to 6.

## Acceptance test per task

Each check-first task writes the slice's tests disabled
(`@Test(.disabled("waits on MD-n"))`, journeys `throw XCTSkip("waits on
MD-n")`); MD-n removes the trait. Mutations go in the named plan with the
`swift test --filter` regex that must catch them.

| id | test | fails when | mutations |
|---|---|---|---|
| MD-1 | `LibraryPhotoDetailsTests`: `CameraDetails(make: " Maker\0 ", model: "", iso: 0, exposureTime: .nan, fNumber: -2, focalLength: 35)` keeps make "Maker", focal 35 and nothing else; `.none.isEmpty`; a `PhotoItem` built with keywords, title, caption and camera keeps all four through `withID` and `withSize`; `ImportCandidate(path:captureDate:pixelSize:kind:)` still compiles with `camera == .none`; `selectedPhotos` follows the sort | a field leaks through the cleaning, a copy drops a field, or the old init breaks | `PhotoDetails`: drop the NUL trim; `> 0` to `>= 0` on numbers. `PhotoItem`: `withID` drops `keywords`. (`LibraryPhotoDetailsTests`) |
| MD-2 | `LibrarySidecarContractTests`: `.fake` writes and reads back bytes; `.fake(mode: .fail)` throws "The folder is read-only."; a `foreign` path refuses; `.live(...)` without sidecars has `unavailable["sidecars"]` with the sentence and `UnconnectedSidecars().write` throws it; with a test-local writer, no reason; `SidecarFields(photo:)` of a rejected 3-star photo has rating -1, of a picked one its stars; `isEmpty` only with nothing to say | the live default acts, the fake ignores its mode, or a reject is written as stars | `SidecarContracts`: reject keeps its stars; `UnconnectedSidecars.write` returns. `FakeSidecars`: fail mode writes. `LibraryServices`: `.live` skips the sidecars reason. (`LibrarySidecarContractTests`) |
| MD-3 | `LibraryCamerasFixtureTests` (MD-MJ1, steps 1–4): the fixture's 24 photos and their details as listed; `IMG_0024` has none; scan then `LiveImporter` keep each photo's details | a detail is lost between scan and photo, or the fixture drifts | `LiveImporter`: drop `camera: candidate.camera`. `LibraryFixtures`: `IMG_0024` gets details. (`LibraryCamerasFixtureTests`) |
| MD-4 | `LibraryMetadataSlotsTests`: `keywordHelp` is "Select a photo to add keywords." with nothing selected and nil with one; `PhotoSearch("  ").isEmpty`; every new identifier is unique and starts `library.` | a slot is missing, a help drifts, or two ids clash | – (slots only; no behaviour to mutate) |
| MD-5 | Its four files compile with every test disabled or skipped, each naming its task | a test is enabled before its code, or names no task | – |
| MD-6 | `LibraryCameraRowsTests`: `CameraDetails(exif:tiff:)` reads each tag, an `[Int]` or `Int` ISO, and ignores a non-number; texts: 0.004 → "1/250 s", 1/3 → "1/3 s", 0.3 → "0.3 s", 2.5 → "2.5 s", f 2.0 → "f/2", 2.8 → "f/2.8", model "FX-1" with make "Fixture Optics" → "Fixture Optics FX-1", model "Fixture Optics FX-1" → the model alone; rows of one photo in `CameraField` order with `search` for camera and lens; two cameras → "2 cameras"; ISO 100 and 3200 → "ISO 100–3200"; a field no photo has → no row; taken → `.dates(min, max)` | a format, the order, a range or a count is wrong | `PhotoDetails`: `< 0.05` to `<= 0.5`; drop the make-prefix check; `min` for `max` in ranges. (`LibraryCameraRowsTests`) |
| MD-7 | `LibraryCameraDecodeTests` (macOS): a JPEG written with ImageIO carrying Make, Model, LensModel, ISO 800, ExposureTime 0.004, FNumber 2, FocalLength 35 scans to those details; a PNG without Exif scans to `.none`; the capture date is unchanged | a tag is not read or the scan's date regresses | – (App target) |
| MD-8 | `LibraryCameraSnapshots` (`library-camera`, `-mixed`, `-none`, Light and Dark); MD-J1 steps 1–4 | a row, its order or its identifier is missing, or "No camera details" doesn't show | – (App target) |
| MD-9 | Its six files compile with every test disabled or skipped, each naming its task | as MD-5 | – |
| MD-10 | `LibraryKeywordTests`: `addKeywords("beach,  Sunset ,beach")` on three selected gives `["beach", "Sunset"]` on each in one step "Add Keywords"; with "Beach" already in the catalog it gives "Beach"; one name → "Add Keyword"; adding what all have records nothing; in the loupe it targets the loupe photo (`cullTargets`); `keywordStates` reads Sunset 1 of 2 partial; `addKeyword(toAll:)` makes it whole in one step; `removeKeyword("BEACH")` removes Beach from all in one step "Remove Keyword"; undo restores exactly; suggestions for "su" put "Sunset" before "Summer" when Sunset co-occurs with the targets' keywords, skip what every target has, and cap at `limit`; with "" they rank keywords of photos within an hour first | a keyword duplicates by case, a gesture is two steps, a no-op records a step, or suggestions rank wrong | `LibraryKeywords`: compare with case (drop `lowercased()`); record each photo as its own step; skip the co-occurrence rank. (`LibraryKeywordTests`) |
| MD-11 | `LibraryCaptionTests`: `setTitle("  Harbour ")` on two photos sets "Harbour" in one step "Set Title"; the same title again records nothing; different titles read `.mixed`; `setCaption` likewise "Set Caption"; undo restores | an edit isn't trimmed, isn't one step, or a no-op records a step | `MetadataEditing`: drop the trim; drop the unchanged guard. (`LibraryCaptionTests`) |
| MD-12 | `LibraryMetadataPersistTests`: a photo with keywords, title, caption and camera round-trips equal; the committed `Golden/catalog-v1.json` still encodes byte-equal (no new keys for photos without them) and decodes with empty fields; a camera with only `iso` writes only `iso` | a field is lost, or the golden changes | `LiveCatalogCoding`: always write `keywords`; decode `caption` from the `title` key. (`LibraryMetadataPersistTests`) |
| MD-13 | `LibraryKeywordSnapshots` (`library-keywords`, `-mixed`) and the redrawn `LibraryMetadataSnapshots`; MD-J2 steps 1–7 | a control has no identifier, a partial token isn't marked, or an edit misses the Model | – (App target) |
| MD-14 | Its five files compile with every test disabled or skipped, each naming its task | as MD-5 | – |
| MD-15 | `LibraryXMPTests`: `encode` of keywords `["A&B", "<x>"]`, title, caption, rating 3, label Red equals a committed expected string byte for byte, with `&amp;` and `&lt;`; rating 0 and empty fields write no element; a reject writes `xmp:Rating` -1; a control character is dropped; `isWrittenByLibrary` is true of its own output and false of the same packet without `lib:Writer`; `path(for: "/a/IMG_1.jpg", siblings: ["/a/IMG_1.jpg"])` is `/a/IMG_1.xmp`, with `/a/IMG_1.heic` too it is `/a/IMG_1.jpg.xmp`, and `/b/IMG_1.heic` elsewhere doesn't count | escaping, an element, the marker or a name is wrong | `XMPSidecar`: drop the `&` escape; write `xmp:Rating` 0; ignore siblings. (`LibraryXMPTests`) |
| MD-16 | `LibrarySidecarPlanTests`: on `cameras` with nothing written, only photos with something to say are planned; after `written` holds them, nothing; a keyword added to one gives exactly one write with its path and `encode` bytes; a sample is never planned; clearing a written photo's keywords plans an empty-fields write; the status texts for sample, writing, failure, saved and never-written | a photo is rewritten needlessly, a sample or an empty photo litters a folder, or a status drifts | `XMPSidecar`: drop `written[id] == f` skip; drop the `isEmpty` first-write skip; plan samples. (`LibrarySidecarPlanTests`) |
| MD-17 | `LibrarySidecarWriterTests` (macOS, temp folder): writes `IMG_1.xmp`; the JPEG beside it has the same SHA-256 and modification date after three writes; a path ending `.jpg` or with no `.xmp` throws and writes nothing; a foreign `IMG_2.xmp` throws with the sentence and stays byte-equal; a read-only folder throws; QB-LIB-V8: `CGImageMetadataCreateFromXMPData` on the written bytes finds the keywords, title, caption, rating and label | an original is touched, a foreign sidecar is replaced, or the system reader disagrees | – (App target) |
| MD-18 | `LibrarySidecarSnapshots` (`library-sidecar-saved`, `-failed`, `-foreign`); MD-J3 steps 1–5 | a write is missed after a change, an original changes, or the row lies | – (App target) |
| MD-19 | Its four files compile with every test disabled or skipped, each naming its task | as MD-5 | – |
| MD-20 | `LibrarySearchTests` on `cameras`: `lens:50` → the 8 `50mm F1.8`; `iso:>1600` → ISO 3200 and 6400 only; `iso:>=1600` includes 1600; `f:<4`; `mm:50`; `keyword:beach` (any case); `"24-70mm F2.8"` as a quoted phrase; `sunset fx-2` needs both; `iso:abc` is plain text and matches nothing; an unknown `foo:bar` is plain text; plain `img_0003` matches the name; `searchSuggestions("50")` lists `lens:"50mm F1.8"` | a field, a comparison or the AND is wrong | `PhotoSearch`: `>` as `>=`; OR the tokens; match keywords with case. (`LibrarySearchTests`) |
| MD-21 | `LibrarySearchOrderTests`: `setSearch("lens:50")` leaves 8 ids in `order`, drops hidden ids from the selection, and from the loupe on a hidden photo returns to the grid; `setSearch("")` restores all; under `keyword:beach`, removing Beach from a shown photo hides it; no search: editing a keyword doesn't rebuild `order` (counted); two catalogs that differ only in the search are not equal | a hidden photo stays selected or in the loupe, an edit under a search leaves a stale order, or `==` ignores the search | `LibraryCatalog`: `shownItems` ignores the search; drop `search` from `==`. `LibraryOrder`: drop `!search.isEmpty` from `editCanReorder`. (`LibrarySearchOrderTests`) |
| MD-22 | MD-J4 steps 1–6; J11 (`testEveryControlActsOrSaysWhy`) still passes with the search field listed | the field, Command-F, Escape or a detail click does nothing | – (App target) |

## Quality tests

| quality row | budget (CI gate, debug; release target in brackets) | test |
|---|---|---|
| QB-LIB-M1 keywords on a selection | `addKeywords` on 1,000 selected photos of `large` ≤ 20 ms (2 ms) | `LibraryKeywordBudgetTests.addToThousandWithinBudget` |
| QB-LIB-M2 suggestions per keystroke | `keywordSuggestions(prefix: "s")` over `large` with 3 keywords a photo from a pool of 500 ≤ 20 ms (2 ms) | `LibraryKeywordBudgetTests.suggestWithinBudget` |
| QB-LIB-M3 search per keystroke | `setSearch("iso:>800 beach")` on `large` ≤ 50 ms (5 ms): the spine's `order` rebuild row plus the match | `LibrarySearchBudgetTests.searchWithinBudget` |
| QB-LIB-M4 sidecar plan per change | `sidecarWrites(after:)` on `large` with one photo changed ≤ 10 ms (1 ms); it compares `SidecarFields` and encodes only the changed photos | `LibrarySidecarPlanTests.planWithinBudget` |
| QB-LIB-4 kept | with no search, a keyword edit doesn't rebuild `order` | `LibrarySearchOrderTests` (counted) |
| QB-LIB-V8 interop | the system XMP reader reads back every field Library wrote | `LibrarySidecarWriterTests` (macOS) |
| QB-LIB-V9 originals untouched | an original's bytes and modification date are unchanged after sidecar writes | `LibrarySidecarWriterTests`, MD-J3 step 4 |
| QB-F3 one gesture, one step | adding several keywords, adding to all, removing, a title, a caption: one named step each | `LibraryKeywordTests`, `LibraryCaptionTests`, MD-J2 steps 2, 3, 5, 6 |
| QB-F4 keyboard | Tab reaches the keyword field, Return adds, Command-F finds, Escape clears | MD-J2, MD-J4 |
| QB-F1 no dead controls | the keyword field, Title and Caption are hidden with nothing selected; the Sidecar row is text, not a control; the search field is in `library.controls` | J11, MD-J4 |
| QB-V5 | the eight snapshots above, Light and Dark | the three new snapshot files and the redrawn metadata one |
| Audit | MD-J1 to MD-J4's shots add no count over `UITests/audit-baseline.json` | each journey's shots |

The probe rows (keystroke-to-screen in the field and the grid) are not added:
both are model-bound here, and P2's harness covers the grid's redraw. If
QB-LIB-M2 or M3 misses, the fix is an index of keywords and camera values
kept beside `items`, not a looser budget.

## Done check

Per slice (`lead.md`, contract rule 6):

- **MD-a:** its four tasks merged, MD-MJ1 green among LibraryModelTests on
  the scoped run (`ci.yml` with `app=library`), every mutation in its plans
  caught.
- **MD-b, MD-c, MD-d, MD-e:** their tasks merged, MD-J1, MD-J2, MD-J3 and
  MD-J4 green in a scoped run containing the slice's last PR (MD-J3's steps
  are mostly live: they need import's live importer and persist's live
  catalog, both built in wave 2), every app built, no open `finding` issue for
  the slice, every `Mutate:` line full.
- Each done slice gets `Belt-Slice-Done: <slice> <run url>` on the feature
  issue; after MD-e, `Belt-Contact-Sheet: <run url>`.
- **Audit zero new** on the four journeys' screens.

## Open questions

1. **Photos imported before this feature have no camera details.** The
   import skips known paths, so a re-import doesn't fill them. Recommended
   next step (not in this packet): when an import meets a known path whose
   photo has `camera.isEmpty`, it updates that photo's details (no undo step,
   like the import itself).
2. **Reading existing sidecars on import.** Keywords another tool put in
   `IMG_0001.xmp` are not read in. Recommended as the follow-up: import
   reads a sidecar's `dc:subject`, `dc:title` and `dc:description` into the
   new photo.
3. **The chain of 10.** Three new App files in `c4-planned.json`'s
   `library-app-inspector` (`CameraSection.swift`, `KeywordSection.swift`,
   `SidecarRow.swift`) would let MD-8, MD-13 and MD-18 run side by side and
   cut it to 7. That is a blueprint edit, so it is the captain's call.
4. **Search and filters-collections' filter.** This packet ANDs the search
   with whatever `shownItems` already shows; filters-collections lands first
   (MD-21 waits on it). If that feature makes the filter a value of its own,
   the search becomes one of its rules in a follow-up.
5. **Shared XMP code.** If Photo also writes XMP, `XMPSidecar` could move to
   creative-core (a `needs-core` issue then: `XMPPacket.encode` and
   `isWrittenBy`, with these tests). Not needed for this feature.
