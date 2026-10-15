# Library blueprint

Library is the suite's photo catalog and develop app. You point it at a
folder of photos, see them as a grid, step through them one at a time in a
loupe, cull them with the keyboard (stars, pick, reject), make the basic
tone and color corrections and a crop without touching the file, and export
finished JPEGs at a set size. The catalog remembers everything between
launches. This blueprint is the gate before feature code: everything a
feature lead needs to write a packet is decided here, and anything not yet
decided is listed as an open question for the captain (section 10).

Sources read on 2026-10-14: creative-apps `origin/dev` 956d946 (LibraryApp,
LibraryModel, their tests, `UITests/LibraryJourneyTests.swift`, SuiteUI,
`docs/`), the 17 open issues labelled `line:library`, the merged Library PRs
(#148 to #750), and creative-core `dev` 4cac701 (CoreRaster, CoreCatalog,
CoreAsset). The look is `docs/design.md`; the quality ids (`QB-…`) are
`docs/review-rubric.md` section 6; ids this blueprint adds are `QB-LIB-…`
and live only here until a feature lands them in the rubric.

Contents: 0 Status on dev · 1 Brief · 2 Pseudo-C4 · 3 Usage map ·
4 Journeys · 5 Contracts · 6 Look · 7 Quality bar · 8 Coverage and waves ·
9 Critic rounds · 10 Open questions for the captain

Each part ends in a checklist. A box is checked when the statement above it
can be verified from this file, the repo or CI, not when it sounds right.

---

## 0. Status on dev (2026-10-14)

Read on `origin/dev` 956d946 and creative-core `dev` 4cac701 (`Package.swift`
resolves `main` cfad97f; CoreRaster and CoreColor are the same in both).

### 0.1 What is built

Library is a working shell over generated sample photos. Nothing reads a
real file.

| Area | What exists | Where | Proof |
|---|---|---|---|
| Window | `SuiteWindow` with the collections sidebar (All Photos, Favorites, Recently Added, with counts), content and inspector; `WindowGroup`, so each window has its own catalog | `Sources/LibraryApp/LibraryApp.swift` | `testLaunchShowsWindowShell` |
| Samples | 60 seeded sample photos (a flat sRGB color each, a date, rating, flag, label); File > Load Sample Photos and the empty state's button | `LibrarySample.swift`, `LibraryCommands.swift` | `testLoadSamplePhotos` |
| Grid | `ThumbnailGrid` of one-pixel images stretched to the cell, sort by capture date, name or rating, Larger and Smaller Thumbnails (80 to 320 pt in 40 pt steps), selection | `LibraryCatalog.swift`, `LibraryApp.swift` (`LibraryBrowser`) | `LibraryGridTests`, `LibraryGridEdgeTests`, `LibraryCellSizeFuzzTests`; `library-grid-*.png` |
| Empty states | No photos at all; an empty collection with a Show All Photos button | `LibraryEmptyCollection.swift` | `LibraryCollectionEmptinessTests`; `library-empty-*.png`, `library-empty-collection-*.png` |
| Loupe | View > Loupe, double-click, Left and Right through the sort, Escape or G back to the grid with the photo selected, a "12 of 60" readout in a `GlassPanel`; the photo is drawn over a fixed 4032 × 3024 `CanvasSurface` artboard (#726, #735) | `LoupeState.swift`, `LibraryLoupe.swift` | `LibraryLoupeTests`; `testLoupeStepsAndReturnsToTheGrid`; `library-loupe-*.png` |
| Metadata | Inspector for the selected photos: rating stars (clicking the current rating clears it), flag (None, Pick, Reject) and color label, "Mixed" where photos differ; edits apply to the whole selection (#750) | `MetadataEditing.swift`, `MetadataInspector.swift` | `LibraryMetadataTests`; `testRateASelectedPhoto`; `library-metadata-*.png` |
| Ids | Each photo has its own id; duplicates in one load get `#2`, `#3` (#230, #236) | `PhotoItem.swift`, `LibraryCatalog.swift` | `LibraryPhotoIDTests`, `LibraryPhotoIDFuzzTests` |

Journeys: `testLaunchShowsWindowShell`, `testLoadSamplePhotos`,
`testEveryMenuOpens`, `testLoupeStepsAndReturnsToTheGrid`,
`testRateASelectedPhoto`, and `testImportRateAndRelaunch`, which is an
`XCTSkip` placeholder waiting on #210, #211 and #212.

App audit baseline for `library` (`UITests/audit-baseline.json`): contrast 2,
identifier 16, offscreen 16, unnamed 1.

### 0.2 What the engine already has

| Need | creative-core API on `main` | State |
|---|---|---|
| Pixels | `PixelBuffer` (Float32 linear, premultiplied; at most `maxPixels` = 256 Mi pixels), `init(rgba8:width:height:colorSpace:)`, `rgba8(colorSpace:)` | landed (#125, #143) |
| Thumbnails | `resized(width:height:filter:)` with `.bilinear` and `.lanczos3` | landed (#132) |
| Develop | `exposure(stops:)` (any finite stops), `whiteBalance(temperature:tint:)`, `contrast(_:)`, `highlightsShadows(highlights:shadows:)` (these three in -100...100); identity returns the input bit for bit; contrast and highlights/shadows under 1 s on 24 MP | landed: creative-core#231 closed by #246, perf #261, #266 |
| Histogram | `Histogram(of:bins:encoding:)` with red, green, blue, luminance, `shadowClipped`, `highlightClipped` | landed (#142, #252) |
| Crop and straighten | `rotated(degrees:filter:)`, `PixelBuffer.straightenCrop(width:height:degrees:)`, `cropped(x:y:width:height:)` | landed: creative-core#230 closed by #251 |
| Catalog database | `CoreCatalog` is a skeleton: `CatalogError` only. It depends on GRDB, and `LibraryModel` does not depend on it (`Package.swift` gives Library only CoreRaster and CoreColor) | creative-core#157 open |
| File decode and encode | none, by design: ImageIO is Darwin-only, so decoding and JPEG writing live in `LibraryApp` | n/a |

So, unlike Flare, **the engine is not the risk.** Every tier-1 pixel
operation exists in CoreRaster today. The risks are speed (a 24 MP Float32
buffer is 384 MB, and one adjustment pass over it takes most of a second),
memory in a 10,000-photo catalog, and the UI, none of which is built.

### 0.3 What the open issues cover

17 open issues carry `line:library`. Section 8.1 maps each to a feature.

| Issue | Title (short) | Tier | Depends on (as written) | Notes |
|---|---|---|---|---|
| #33 | Grid thumbnails by resampling | p1 | #28 (merged) | Ready |
| #210 | Import a folder | p1 | #33 | Its `PhotoItem` stored id is done (#230); its path id is not |
| #211 | Rate, pick, reject with keys | p1 | #210 | `PhotoFlag` with reject landed in #750; keys, the Metadata menu, undo and the `for:` ids API are left |
| #212 | Keep the catalog across relaunch | p1 | #211 | JSON sidecar until creative-core#157 |
| #32 | Develop panel with histogram | p1 | #29 (closed), #33, #5 | Also copy and paste of settings |
| #423 | Render develop settings to pixels | p1 | #32, #212, creative-core#231 (closed) | |
| #424 | Export JPEG at a set size | p1 | #423 | |
| #425 | Crop and straighten in the loupe | p1 | #423, creative-core#230 (closed) | |
| #426 | Auto-advance after a rating or flag | p1 | #211, #29 | |
| #156 | Switching collection leaves the loupe on a hidden photo | p2 bug | | `in-progress`; PR #217 open since 2026-10-12 |
| #235 | `load` renames a photo whose own id a duplicate took | p2 bug | | Matters once import gives path ids |
| #724 | Loupe rating keys and zoom | p2 | #211 | Keys are tier 1 (culling in the loupe); zoom is tier 1 by inference (checking focus) |
| #31 | Collections and filters | p2 | #28, #4 | Filter by flag or rating is tier 2 |
| #744 | Keywords and camera details | p2 | #30 (closed) | |
| #427 | Camera raw files | p2 | #210, #33 | "Pending evidence" |
| #185 | Pro density inspector and status bar | p3 | #177 (merged) | The status bar is required by docs/design.md ("a bare canvas with no readout is not finished") |
| #291 | 16 controls have no identifier | p3 | | Lowers the audit baseline |

### 0.4 What is missing

- **Every tier-1 step but browsing.** No import, no real pixels, no culling
  keys, no undo of any kind, no persistence, no develop, no crop, no export.
- **Undo.** Library has no history at all: `setRating` and friends change
  the catalog with no way back, and there is no Edit > Undo item.
- **One catalog per app.** `WindowGroup` gives every window its own
  catalog; once the catalog is saved, two windows would overwrite each
  other's file (decision D2).
- **A structure for parallel work.** `LibraryApp.swift` holds the window,
  the browser, the grid cell builder and the image conversion;
  `LibraryCommands.swift` holds every menu. Every open issue lists one of
  the two as "edit", so today no two Library features can run side by
  side. The spine feature (section 8) fixes that once.
- **Speed at scale.** `sortedItems` sorts on every read and the loupe reads
  it three times per redraw; with 10,000 photos each arrow key would sort
  10,000 items several times. Nothing measures it yet.
- **SuiteUI parts.** No histogram view, no way for `ThumbnailGrid` to say
  which cells are on screen, no crop frame with handles, no progress row,
  and the harnesses Flare also waits on: `FrameProbe` (#330), goldens
  (#331, #332) and per-feature journey files (#333). Section 6 lists them.

Checklist:

- [x] Every Library source file on dev is named in 0.1 or 0.4.
- [x] Every open `line:library` issue is in 0.3 (17 of 17).
- [x] Every engine API in 0.2 was read in creative-core `dev` 4cac701.

---

## 1. Brief

### 1.1 The problem

People come home with a few hundred photos from a day. They need to see
them all quickly, throw out the bad ones, mark the keepers, fix exposure,
color and framing on the few that matter, and send those out as JPEGs, all
without the editor changing their original files and without paying a
subscription. The suite's Photo app edits one image deeply; Library handles
many images lightly. That split is the product: catalog plus a
non-destructive develop, with Photo for the rare deep edit (round trip to
Photo is later, section 1.4).

### 1.2 Who uses it

| Person | What they do in a session | What they need most |
|---|---|---|
| Hobbyist after a trip or an event (the main user) | Import one card's folder, cull 300 to 30, fix 10, export for sharing | Fast culling from the keyboard; good defaults; export that just works |
| Enthusiast who shoots weekly | The same, every week, into a catalog of 5,000 to 50,000 photos | The catalog stays fast and never forgets; consistent edits (copy and paste settings) |
| Someone tidying a phone's photo export | Import, browse by date, flag favorites, export a few | Import of HEIC and JPEG; sort by date; nothing destructive |

Evidence: these three people are inferred from the surveys
`docs/priorities.md` cites (photo editing habits of 18-25s, 2024; the photo
editing software survey), which show editing for sharing as the common
case. No public source measures per-feature use, so section 3 marks every
row without a direct source *inferred*.

### 1.3 Non-goals

- Pixel editing: brushes, layers, healing, text (Photo does these).
- Local adjustments: masks, gradients, brushes on the develop (tier 3).
- Camera raw processing beyond what the system decoder gives (#427 is a
  tier-2 import, not a raw engine).
- Cloud sync, sharing services, accounts, people or face recognition,
  maps, printing, slideshows, books, tethered capture.
- Managing files on disk: Library never moves, renames or deletes a user's
  file in v1. Import references files where they are.
- A plugin or scripting API; reading any closed catalog format.
- An iPad or iPhone build.

### 1.4 The v1 line

v1 is the tier-1 loop of `docs/priorities.md`, end to end, plus what that
loop needs to be trustworthy (undo, errors, speed). Everything else waits.

| In v1 | Out of v1 (later) |
|---|---|
| Import a folder (PNG, JPEG, HEIC; subfolders included), skipping files already in the catalog, with progress and a list of files that failed | Camera raw (#427), video, import from a camera or card reader with copy, duplicate detection by content |
| Grid of real thumbnails, built off the main thread, cached; sort by date, name, rating; Larger and Smaller Thumbnails | Stacks, a filmstrip under the loupe, a disk thumbnail cache (v1 rebuilds thumbnails in memory each launch) |
| Loupe with Left and Right, zoom to fit, 100% and back, pan when zoomed | Compare two photos side by side, survey mode |
| Cull from the keyboard in grid and loupe: 0 to 5 stars, P pick, X reject, U unflag; color labels from the inspector; Auto Advance | Keyboard color labels (6 to 9), keywords (#744), camera details (#744) |
| Undo and redo of every catalog change, named ("Undo Set Rating") | A history panel |
| Develop: exposure, temperature, tint, contrast, highlights, shadows, each with reset; a histogram with clipping warnings; copy and paste settings | Curves, HSL, vibrance and saturation, sharpening, noise reduction, lens corrections, presets, local masks, auto tone |
| Crop with aspect presets (Original, Free, 1:1, 4:5, 3:2, 16:9) and straighten ±45° | Flip, perspective (upright) correction, a crop guide other than thirds |
| Export selected photos as sRGB JPEG: long edge (or original), quality, folder; never overwrites; progress, cancel, per-file failures | Other formats, watermarks, metadata options, export presets, resize by short edge or megapixels |
| The catalog persists (JSON file) and restores at launch; a damaged file is set aside, never crashes | The SQLite catalog (creative-core#157), multiple catalogs, catalog backup |
| Status pills under the grid and loupe (#185's status bar); every control named and identified (#291) | Collections you make, smart collections and filters (#31) |
| One window, one catalog (decision D2) | Several windows on one catalog |

**The line in one sentence:** a person can import a folder, cull it from
the keyboard, fix and crop the keepers, export them, quit, and find it all
as they left it, and every step is fast enough that they never wait on the
app for something they did not ask to wait for.

Checklist:

- [x] Every tier-1 row of `docs/priorities.md`'s Library section is in the
      "In v1" column (import, grid, loupe, cull with auto-advance, basic
      develop, export JPEG at a size, persistence, crop and straighten).
- [x] Every non-goal names a behavior, not another company's product.
- [x] Every "out" row names where it goes (later tier or another app).

---

## 2. Pseudo-C4 (drawn before code)

The machine-readable twin of this section is
`docs/blueprints/library/c4-planned.json`, in the shape of
`docs/c4/model.json`, with `"status": "planned"` or `"existing"` and
`"authored": true` on every component. `docs/c4/model.json` itself is not
edited by this blueprint: each feature updates its own component
descriptions there when it lands (CLAUDE.md, C4 owner rule), using the
descriptions below. Because `model.json` covers a whole target folder with
one component per target, every new file below is already owned there; the
finer components here are for planning and for owned-file checks.

### 2.1 L1 and L2: the system and its containers

```
                    ┌────────────────────────── creative-apps ──────────────────────────┐
 person ──uses──▶   │  LibraryApp (macOS) ──reads, calls──▶ LibraryModel (Linux-safe)  │
 (photos on disk)   │      │  builds window from                 │ uses                 │
                    │      ▼                                     ▼                      │
                    │   SuiteUI (macOS)                 creative-core: CoreRaster,      │
                    │                                    CoreColor (existing)          │
                    └───────────────────────────────────────────────────────────────────┘
 LibraryApp ──reads and writes──▶ the person's image files (read only) and
             Application Support/Library/catalog.json; writes exported JPEGs
 CoreCatalog (creative-core#157, planned): not used in v1 (decision D1)
```

| Container | Status | Responsibility | Owned paths |
|---|---|---|---|
| `library-app` | existing | The SwiftUI app: window, menus, views, and the platform adapters that need Darwin (ImageIO decode and encode, folder scan, file store) | `Sources/LibraryApp/` |
| `library-model` | existing | State and logic behind the window, the use-case contracts, their live conformances over CoreRaster, and the fakes. Linux-safe | `Sources/LibraryModel/` |
| `suiteui` | existing (other line) | Shared components; Library asks for new ones by `needs-ui` issue | `Sources/SuiteUI/` |
| `coreraster`, `corecolor` | existing (creative-core) | Pixels, resampling, develop adjustments, histogram, rotate, crop; color | creative-core |
| `corecatalog` | planned (creative-core#157) | SQLite catalog. Not a v1 dependency: `Package.swift` gives LibraryModel no CoreCatalog and GRDB is not Linux-checked here | creative-core |

### 2.2 L3: LibraryModel components

`LibraryCatalog` stays the one value-type state behind the window. Each
component below owns its own files; only the spine (`library-catalog`)
declares stored properties, all of them, in one PR, so no later feature edits
`LibraryCatalog.swift` (Flare's LM-0a3 pattern).

| Component | Status | Responsibility | Owned paths | Uses |
|---|---|---|---|---|
| `library-catalog` | existing, grows | `LibraryCatalog`'s stored state (every property v1 needs, section 5.4), `PhotoItem`, sort and the cached display order, collections and their empty-state copy | `LibraryCatalog.swift`, `PhotoItem.swift`, `LibraryOrder.swift`, `LibraryEmptyCollection.swift` | `library-contracts`, `library-history` |
| `library-contracts` | planned | The use-case protocols and their value types (section 5), and `LibraryServices` (one existential per contract, `.fake` and `.live`) | `Contracts/`, `LibraryServices.swift` | CoreRaster (types only) |
| `library-fakes` | planned | One fake per contract, deterministic, with failure modes for error journeys | `Fakes/` | `library-contracts`, `library-fixtures` |
| `library-fixtures` | existing, grows | Seeded samples, the sample picture (`SampleImage`, used by fakes and live alike for photos with no file), the named fixtures journeys launch with, launch-argument parsing | `LibrarySample.swift`, `SampleImage.swift`, `LibraryFixtures.swift`, `LibraryLaunch.swift` | `library-catalog` |
| `library-history` | planned | Undo and redo: named steps, each holding the values it puts back; coalescing for slider drags | `CatalogHistory.swift` | none |
| `library-import` | planned | Folder import: file type rules, path ids, skip known paths, merge into the catalog, progress and failure state | `LibraryImport.swift`, `Live/LiveImporter.swift` | `PhotoDecoding` (platform) |
| `library-thumbnails` | planned | Size buckets from the cell size, requests for visible cells, an LRU of display bytes, rebuild after a develop change | `LibraryThumbnails.swift`, `Live/LiveThumbnails.swift` | CoreRaster `resized`, `PhotoDecoding`, `DevelopRendering` |
| `library-culling` | existing, grows | Rating, flag and label on a set of ids with undo, keyboard mapping, Auto Advance, mixed values for the inspector | `MetadataEditing.swift`, `LibraryCulling.swift`, `Live/LiveCulling.swift` | `library-history` |
| `library-persistence` | planned | Catalog file v1 (JSON) encode and decode, restore, setting aside a damaged file, the dirty flag and save requests | `LibraryPersistence.swift`, `Live/LiveCatalogCoding.swift` | `CatalogStoring` (platform) |
| `library-loupe` | existing, grows | The loupe's photo and place, zoom (fit, 100%, steps), pan, the latest-wins render of the loupe image and its histogram, prefetch of the neighbours | `LoupeState.swift`, `LoupeZoom.swift`, `LibraryLoupeImage.swift`, `RenderQueue.swift`, `Live/LiveLoupeImaging.swift` | `DevelopRendering`, `PhotoDecoding` |
| `library-develop` | planned | Develop settings per photo, slider edits with clamping and coalesced undo, reset, copy and paste, the renderer over CoreRaster | `LibraryDevelop.swift`, `Live/LiveDevelop.swift` | CoreRaster adjustments and `Histogram` |
| `library-crop` | planned | Crop rectangle and angle, aspect presets, the frame kept inside the straightened image, apply and cancel | `LibraryCrop.swift`, `Live/LiveCrop.swift` | CoreRaster `rotated`, `straightenCrop`, `cropped` |
| `library-export` | planned | Export plan (sizes, never enlarge, names that never overwrite, quality), progress, cancel, per-file failures | `LibraryExport.swift`, `Live/LiveExporter.swift` | `DevelopRendering`, CoreRaster `resized`, `JPEGWriting` (platform) |
| `library-status` | planned | Status pill text (counts, selection, zoom), inspector header facts, and the layout math the layout tests check (grid columns, loupe fit) | `LibraryStatusText.swift`, `LibraryLayout.swift` | `library-catalog` |
| `library-later` | planned (wave 5, not v1) | Collections and filters (#31), keywords (#744), raw file rules (#427) | `LibraryCollections.swift`, `LibraryFilter.swift`, `LibraryKeywords.swift`, `RawFileTypes.swift` | `library-catalog` |

All paths are under `Sources/LibraryModel/`.

**No shared wiring file.** `LibraryServices.live` (section 5.4) names a
`Live…` type for every member from the start. The spine creates each
`Live/Live….swift` as a stub that handles what needs no file (samples,
plain cull rules), throws for the rest, and carries
`static let unavailable: String? = "<what> isn't connected yet (<feature>)."`;
the feature that builds it replaces the file and sets `unavailable` to nil.
So no two features ever edit the same wiring line.

### 2.3 L3: LibraryApp components

| Component | Status | Responsibility | Owned paths | Uses |
|---|---|---|---|---|
| `library-app-shell` | existing, restructured | The `Window` scene, the root `LibraryWindow` holding the one `model` (with the window-level `onKeyPress` that hands keys to the cull area), the whole menu bar (every v1 item, section 6.2), `LibraryMenu` (one sub-struct of closures per feature), and `LibraryControls` (the `library.controls` JSON value J11 reads) | `LibraryApp.swift`, `LibraryWindow.swift`, `LibraryCommands.swift`, `LibraryMenus.swift`, `LibraryControls.swift` | every area file |
| `library-app-areas` | planned | One file per feature: it builds that feature's menu sub-struct (nil closures disable items) and runs its async work, handing results to catalog methods. `+Edit` (undo, redo, samples), `+Import`, `+Thumbnails`, `+Cull` (keys, Metadata menu), `+Persist` (load at launch, save after changes), `+Loupe` (View menu, renders, prefetch), `+Develop`, `+Crop`, `+Export`. The spine creates each as a stub returning an all-nil sub-struct | `LibraryWindow+Edit.swift`, `+Import`, `+Thumbnails`, `+Cull`, `+Persist`, `+Loupe`, `+Develop`, `+Crop`, `+Export` | `library-model` |
| `library-app-browse` | existing, grows | The content area: empty states, import progress row, the grid with real thumbnails, the loupe on `CanvasViewport`, the status pills | `LibraryBrowser.swift`, `LibraryGrid.swift`, `DisplayImage+Image.swift`, `LibraryLoupe.swift`, `LibraryStatusBar.swift` | SuiteUI |
| `library-app-inspector` | existing, grows | The inspector: Info and Develop tabs, metadata, develop sliders and histogram | `LibraryInspector.swift`, `MetadataInspector.swift`, `DevelopInspector.swift` | SuiteUI |
| `library-app-crop` | planned | The crop frame over the loupe photo, and the CROP section the Develop tab shows while cropping. The spine creates both files as stubs and already embeds them: the overlay in `LibraryLoupe`'s overlay slot, the section in `DevelopInspector` (shown while `cropDraft` is set) | `LibraryCropOverlay.swift`, `CropInspector.swift` | SuiteUI `CropShade`, `SelectionOutline` |
| `library-app-later` | planned (wave 5, not v1) | Filters and collections in the sidebar | `LibraryWindow+Filters.swift` | `library-model` |
| `library-app-export` | planned | The export sheet | `LibraryExportSheet.swift` | SuiteUI |
| `library-app-platform` | planned | Darwin adapters that conform to the platform contracts: `ImageIODecoder` (`PhotoDecoding`: folder scan, metadata, decode with orientation to sRGB RGBA8), `JPEGWriter` (`JPEGWriting`), `CatalogStore` (`CatalogStoring`: Application Support, atomic write, `.bad` rename). The spine creates the three files as stubs that throw "not built yet"; import, export and persist each own one | `Platform/` | ImageIO, Foundation |

All paths are under `Sources/LibraryApp/`. No SwiftUI in `Platform/`
(the logic track builds it, like Flare's `StagePath.swift`).

### 2.4 Relationships

| From | To | What |
|---|---|---|
| `library-app-shell` | `library-catalog` | holds the one `LibraryCatalog`, reads it, calls its methods |
| `library-app-areas` | `library-contracts` | awaits a service (import, thumbnails, loupe render, export, store) off the main actor, then hands the result to a catalog method |
| `library-app-platform` | `library-contracts` | conforms to `PhotoDecoding`, `JPEGWriting`, `CatalogStoring` |
| `library-app-browse`, `library-app-inspector`, `library-app-crop`, `library-app-export` | `suiteui` | build their views from SuiteUI |
| `library-catalog` | `library-history` | records every catalog change as a named step |
| `library-thumbnails`, `library-loupe`, `library-export` | `library-develop` | render with the photo's settings, so grid, loupe and export match (QB-V4) |
| `library-develop`, `library-crop`, `library-thumbnails`, `library-export` | `coreraster` | every pixel operation |
| `library-fakes` | `library-fixtures` | fake data comes from the fixtures |
| `library-persistence` | `library-catalog` | encodes and restores records; never pixels |

### 2.5 What runs where (threads)

- The main actor owns `LibraryCatalog` and the views. A catalog method
  never decodes, renders or touches the disk.
- Decoding, thumbnail building, loupe renders, export and catalog file
  writes run in `Task`s off the main actor, started by the area files, and
  return results through a catalog method (`finishImport`,
  `setThumbnail`, `showLoupeRender`, ...). Each result carries the request
  token it answers; a result for a stale token is dropped (`RenderQueue`
  rule: latest wins).
- Contracts are `Sendable` and stateless or actor-backed, so a live service
  can run on any thread. The LRU caches are actors inside the live
  conformances.

Checklist:

- [x] Every component has a status, a responsibility, owned paths and its
      relationships, here and in `c4-planned.json`.
- [x] Every existing file under `Sources/LibraryModel/` and
      `Sources/LibraryApp/` is in exactly one component
      (`python3 docs/blueprints/library/check_c4.py`).
- [x] No component writes another line's target.

---

## 3. Usage map

Ranked from `docs/priorities.md` (Library section), which is the source of
the tiers; this section adds the order inside each tier and the rows that
file did not list. The method is the same clean-room one: public sources
only, nothing opened or run. No public study counts per-feature use in
photo catalog apps, so most rows are *inferred* from what beginner courses
teach first and what keyboard cheat sheets repeat; those are the first to
move if usage data turns up.

Sources:

- S1. `docs/priorities.md`, Library section, and the surveys it cites:
  photo editing habits of 18-25s (2024),
  https://petapixel.com/2024/06/21/one-third-of-18-to-25-year-olds-edit-their-photos-for-social-media ;
  photo editing software survey, https://shotkit.com/photo-editing-software-survey/ .
- S2. CIPA DC-008, Exchangeable image file format (Exif), the published
  spec for capture date (`DateTimeOriginal`), orientation and camera
  fields: https://www.cipa.jp/e/std/std-sec.html .
- S3. IPTC Photo Metadata Standard (ratings, keywords and labels as people
  exchange them): https://iptc.org/standards/photo-metadata/ .
- S4. ISO 16684-1, Extensible Metadata Platform (where a rating and a
  label live in a file's metadata), https://www.iso.org/standard/75163.html .
- S5. Apple Human Interface Guidelines, macOS (keyboard, undo, menus):
  https://developer.apple.com/design/human-interface-guidelines/ .

Within a tier the order is the order a session meets the feature.

### Tier 1: nearly every session (`p1`)

| # | Feature | Evidence | Issues |
|---|---|---|---|
| 1 | Import a folder (PNG, JPEG, HEIC), capture date from Exif, skip known files | S1 (tier 1 in priorities); S2 for the date | #210 |
| 2 | Grid of real thumbnails, sorted by capture date | S1 | #33 |
| 3 | Loupe: one photo large, Left and Right, back to the grid | S1 | #29 (closed), #724 (zoom) |
| 4 | Cull from the keyboard: 0 to 5 stars, pick, reject, unflag | S1; S3 and S4 define the rating scale people exchange | #211, #724 (keys in the loupe) |
| 5 | Auto Advance after a rating or flag | S1 | #426 |
| 6 | Undo and redo of every change, named | S5 (every Mac editor); *inferred* as tier 1 | spine (no issue yet) |
| 7 | Develop: exposure, white balance (temperature, tint), contrast, highlights, shadows, with a histogram | S1 | #32, #423 |
| 8 | Crop and straighten | S1 (*inferred* there) | #425 |
| 9 | Export JPEG at a set long edge and quality | S1 | #424 |
| 10 | The catalog is there after relaunch | S1 (*inferred* there) | #212 |
| 11 | Loupe zoom to 100% to check focus, and pan | *inferred*: checking sharpness is part of culling | #724 |

### Tier 2: weekly (`p2`)

| # | Feature | Evidence | Issues |
|---|---|---|---|
| 1 | Filter the grid by flag or rating | S1 | #31 |
| 2 | Copy and paste develop settings across photos | S1 | #32 (rides along; cheap once settings exist) |
| 3 | Metadata panel: camera details, keywords | S1; S2 and S3 for the fields | #744 |
| 4 | Collections you make | S1 | #31 |
| 5 | Compare two photos side by side | S1 | not filed (later) |
| 6 | Camera raw files | S1 ("pending evidence") | #427 |
| 7 | Color labels from the keyboard | *inferred* | not filed (later) |

### Tier 3: specialist or occasional (`p3`)

| # | Feature | Evidence | Issues |
|---|---|---|---|
| 1 | Keywords at scale, smart collections | S1 | #31 (smart rules), later |
| 2 | Local masks, denoise | S1 | not filed (later) |
| 3 | Density polish of the inspector and status bar | design rule, not usage | #185 (the status bar is pulled into v1 as a design requirement, section 1.4) |
| 4 | Identifiers on every control | test plumbing | #291 (pulled into v1: the journeys need it) |

### Calls against the tiers

| Row | Call | Why |
|---|---|---|
| Undo (tier 1, no issue) | v1, built by the spine | No issue asks for it, but a cull without undo loses work on one wrong key, and the rubric (QB-F3) requires one named undo step per gesture |
| Copy and paste settings (tier 2) | v1, inside the develop feature | #32 already includes it, and it is a few lines once settings are a value type |
| Loupe zoom (tier 1, inferred) | v1 | Culling is judging focus; fit-to-window cannot show it |
| Filters (tier 2) | later | The cull works on the whole folder; filters are the first item after v1 |
| Status bar and identifiers (tier 3) | v1 | Required by docs/design.md and by the journeys, not by usage |

Checklist:

- [x] Every tier-1 item of `docs/priorities.md` (Library) appears in tier 1
      above, with the same issue numbers.
- [x] Every row has a source or says *inferred*.
- [x] No product or company name of another creative app appears.

---

## 4. Journeys

### 4.1 How the journeys run

- **Files.** Today `project.yml` compiles exactly `UITests/Journey.swift`,
  `UITests/Audit.swift`, the audit sources and
  `UITests/LibraryJourneyTests.swift`, so every feature would edit one
  file. SuiteUI's QH-4 (#333) widens the template to `UITests/Journey*.swift`
  and `UITests/<target>*.swift`. After it, each feature owns
  `UITests/LibraryJourneyTests+<Area>.swift` with its own `XCTestCase`
  class. Until #333 merges, at most one feature per wave adds journey steps,
  to `UITests/LibraryJourneyTests.swift` (section 8.3 names it), and the
  others ship Model tests and snapshots and add their file after #333.
- **Shared Library helpers** (`LibraryFiles`, below) live at the bottom of
  `UITests/LibraryJourneyTests.swift` until #333 merges, then move to
  `UITests/Journey+Library.swift` (the spine owns both). They write files
  through ImageIO in the test process: `LibraryFiles.writeShoot(in:)` (the
  24 photos of the `shoot` fixture below as real JPEGs with the same names,
  sizes and Exif dates), `LibraryFiles.write(_ count:kinds:in:subfolder:)`,
  `LibraryFiles.broken(in:)` (a `.jpg` holding the bytes `not an image`),
  `LibraryFiles.readOnlyFolder()` (can be listed, not written: for export
  failures) and `LibraryFiles.unreadableFolder()` (mode 000: can't be
  listed: for import failures). Every journey gets a fresh temporary
  catalog folder.
- **Two modes.** *Fake*: `-LibraryFixture <name>` puts that fixture's
  photos in the catalog and runs every service on its fake. *Live*: no
  fixture; the journey writes real files with `LibraryFiles` and launches
  with `-LibraryImportFolder <dir> -LibraryImportOnLaunch`, so the app
  imports them through the live services before the first step. Each
  journey below says which steps run in which mode: **(F)** passes on
  fakes, **(L)** needs the live conformance and runs only once that
  feature's last task has replaced its `Live/` stub. A feature's journey
  ships with its (F) steps; its last task adds the (L) steps. Every (L)
  setup imports real files, so in wave 2 the (L) steps of thumbnails, cull,
  persist and loupe-viewport also wait for import to merge (their packets
  say so; `check_waves.py` forbids same-wave dependencies, so it is a task
  order inside the wave, not a feature dependency).
- **Today's journeys.** The four existing journeys click "Load Sample
  Photos" in the content, which becomes the File menu's item once the empty
  state's button is Import Folder…. The spine switches
  `testLoadSamplePhotos`, `testEveryMenuOpens`,
  `testLoupeStepsAndReturnsToTheGrid` and `testRateASelectedPhoto` to
  `-LibraryFixture samples` (and File > Load Sample Photos for the first)
  in the same PR, in `UITests/LibraryJourneyTests.swift`, which it owns.
- **Sort for the named photos.** In `shoot`, capture order is not name
  order (below), so J3–J7 start with View > Sort By > Name to put
  `IMG_0001` first.
- **Saved before quit.** The window carries `library.catalog` with value
  `saved` or `dirty` (`saveRevision == savedRevision`); every journey that
  terminates and relaunches waits for `saved` first, and the persist area
  also flushes on `NSApplication.willTerminateNotification`.
- **Launch arguments** (parsed in `LibraryLaunch.swift`, Linux-tested):

| Argument | Effect |
|---|---|
| `-LibraryFixture <name>` | Fake services and that fixture's photos |
| `-LibraryCatalogDir <path>` | Where `catalog.json` lives (default: Application Support/Library) |
| `-LibraryImportFolder <path>` | File > Import Folder… imports this folder instead of showing the open panel |
| `-LibraryImportOnLaunch` | With `-LibraryImportFolder`: import it right after launch (live journeys' setup) |
| `-LibraryExportTo <path>` | The export sheet's folder; Export writes there without a panel |
| `-LibraryFakeMode ok\|fail\|slow` | Fakes only: every call succeeds, fails with its error, or waits 2 s first |
| `-LibraryPerfProbe` | Exposes `suite.perf` (SuiteUI QH-1, #330, with S-L8's named marks) |
| `-LibraryTestValues` | Computes the loupe checksum and other test-only values (`DisplayImage.checksum`); every journey that reads one passes it |
| `-LibraryReduceMotion` | The app treats Reduce Motion as on (an app-level override the animated views read beside the system setting), for QB-F5's probe check |
| `-LibraryWindowSize <w>x<h>` | The window's initial content size, for the layout journey |

- **Fixtures** (`LibraryFixtures`, built in code):

| Fixture | Contents | Used by |
|---|---|---|
| `empty` | no photos | fake runs of J0 |
| `samples` | today's 60 seeded samples (`LibrarySample`), with `pixelSize` 4032 × 3024 and no path | existing journeys, snapshots |
| `shoot` | 24 photos `IMG_0001` … `IMG_0024`; every third one (`IMG_0003`, `IMG_0006`, … `IMG_0024`, 8 photos) portrait 4000 × 6000, the other 16 landscape 6000 × 4000; `IMG_n` captured 2026-06-01 10:00 UTC plus `(7 · n) mod 24` minutes, so capture order (`IMG_0024` first) differs from name order; no ratings, flags or labels | J2–J7 (F); `LibraryFiles.writeShoot` writes the same 24 for (L) |
| `large` | 10,000 records over 365 days, names `IMG_00001` … | P1 (F), model budgets |

- **Identifiers and values.** Every Library control and mark gets
  `library.<area>.<name>` (`library.grid`, `library.grid.cell.<id>`,
  `library.loupe.photo`, `library.develop.exposure`, `library.crop.frame`,
  `library.export.longEdge`, ...). Accessibility values carry what a test
  reads, all built in the Model: a grid cell's value is its load state
  (`loading`, `ready`, `unreadable`), the shown image's pixel size, then
  `PhotoItem.cullSummary` ("ready 256×171 3 stars, Picked, Red"); the loupe
  photo's value is `preview` or `full`, the render's pixel size and
  checksum, the zoom percent, then `cullSummary`
  (`full 2048×1365 3f9a… 100% 3 stars`), so a journey can tell that the
  pixels, the shape, the zoom or the rating changed. The spine puts the
  loupe value on the photo in wave 1. Cell values need S-L2 (a per-cell
  value hook in `ThumbnailGrid`), a hard SuiteUI wait for the steps that
  read them; until it lands those steps open the photo in the loupe and
  read the loupe value instead.
- **Every control acts or says why.** `library.controls` is a JSON
  accessibility value on the window (spine: `LibraryControls.swift`, after
  Flare's `FlareControls.swift`) listing every `library.*` control with
  enabled and its reason; J11 reads it.
- **Waiting.** No journey asserts timing through an XCUI query. States are
  awaited with `waitForExistence` or a value predicate (10 s for import and
  export, 2 s otherwise); timing comes from the probe's JSON (section 7).
- Every step takes a `shot`, so each journey's PNGs reach the contact sheet.

### 4.2 Tier-1 journeys

The States line of each journey names every empty, loading and error state
it passes through; each has a snapshot in section 6.3.

**J0 · `testLaunchShowsEmptyCatalog`** (`+Shell.swift`, spine)
1. (F, L) Launch with an empty `-LibraryCatalogDir` and no fixture. Shot
   `empty`. Expect `expectWindowShell()`, the empty state "No Photos" with
   **Import Folder…** as its one prominent button, sidebar counts 0.
2. (F, L) Open File. Shot `file-menu-empty`. Import Folder… and the empty
   state's button are enabled exactly when `library.controls` lists
   `library.import` as enabled; when it is disabled, its reason is the
   button's help (in wave 1 "Import isn't connected yet (import)."). So the
   step passes before and after import lands without an edit. Export… is
   disabled.
3. (F, L) Open Edit. Expect Undo and Redo disabled.
States: empty (catalog); disabled with a reason.

**J1 · `testImportAFolder`** (`+Import.swift`, import; all steps L)
1. Write 24 JPEGs (4 of them in a subfolder `day2/`), 1 PNG, 1 HEIC,
   `LibraryFiles.broken` and a `notes.txt` into a temp folder; launch with
   `-LibraryImportFolder` on it (no `-LibraryImportOnLaunch`).
2. Click **Import Folder…**. Shot `importing`. Expect placeholder cells
   (value `loading`) as batches arrive (`PhotoImporting`'s `added`
   callback) before the import ends. The progress row itself is asserted
   in step 6, since 27 small files may finish before its 100 ms delay.
3. Wait for the progress row to go. Shot `imported`. Expect 26 cells; All
   Photos reads 26; capture-date order (the first cell is the earliest
   written); the notice reads `ImportNotice.message` = "Imported 26 photos.
   1 file couldn't be imported." with **Show** listing `broken.jpg: not an
   image file`; `notes.txt` is not mentioned (not an image type).
4. Delete `broken.jpg`; import the same folder again. Shot `import-again`.
   Expect "No new photos in <folder>." and still 26 cells.
5. Relaunch with `-LibraryImportFolder` on `LibraryFiles.unreadableFolder()`
   and import. Shot `import-denied`. Expect "Library can't read <folder>.
   Check that you have access to it." in the error state.
6. (F) Relaunch with `-LibraryFixture shoot -LibraryFakeMode slow` and an
   empty catalog; File > Import Folder…. Shot `import-progress`. Expect
   `library.import.progress` reading "Importing 1 of 24" within the 2 s
   the slow fake waits.
States: empty → loading (progress row, placeholder cells) → loaded;
error (broken file, unreadable folder); nothing new.

**J2 · `testGridShowsThumbnailsAndSorts`** (`+Grid.swift`, thumbnails)
1. (F) Launch on `shoot`. (L) Launch live on `writeShoot`. Shot `grid`.
   Expect every visible cell's value to start with `ready` within 2 s.
   The first cell (capture order) is `IMG_0024`; portrait cells' values
   report a height above their width (e.g. `ready 171×256`).
2. (F, L) View > Zoom In (Larger Thumbnails in the grid) three times
   (160 → 280 pt). Shot `grid-larger`. Expect fewer columns and every
   visible cell `ready` at the next bucket (512 → 1024 px at 2x).
3. (F, L) View > Sort By > Name. Shot `grid-by-name`. Expect the first
   cell's caption `IMG_0001`.
4. (F, L) Click a cell, Shift-click the fourth after it. Expect five cells
   with the selected trait. (The "5 selected" pill is asserted by J12.)
States: loading (placeholder cells) → ready.

**J3 · `testLoupeStepsZoomsAndReturns`** (`+Loupe.swift`, loupe-viewport;
the existing `testLoupeStepsAndReturnsToTheGrid` stays, on
`-LibraryFixture samples` from the spine)
1. (F) Launch on `shoot`. (L) Live on `writeShoot`. Sort by Name;
   double-click the first cell. Shot `loupe`. Expect `library.loupe.photo`
   with a value starting `full` within 2 s, and the readout
   "IMG_0001 · 1 of 24". (F) With `-LibraryFakeMode slow` the value reads
   `preview` first (the thumbnail scaled up); shot `loupe-preview`.
2. (F, L) Press Right twice. Shot `loupe-step`. Expect "3 of 24".
3. (F, L) View > Actual Size (Command-1). Shot `loupe-100`. Expect the
   photo's value to contain `100%`.
4. (F, L) Scroll the photo 200 pt left (`scroll(byDeltaX:deltaY:)`;
   XCUITest can't hold Space through a drag, and CanvasViewport pans on
   scroll and arrows too). Shot `loupe-pan`. Expect the photo frame's x
   moved left by 200 (±2). Space-drag is covered by a Model test of the pan
   math.
5. (F, L) View > Zoom to Fit (Command-0); press End, then Home. Expect
   "24 of 24", then "1 of 24" (loupe-viewport adds Home and End). Right
   twice; Escape. Shot `loupe-grid`. Expect the grid with `IMG_0003`
   selected.
States: loading (`preview` before `full`).

**J4 · `testCullWithKeysAndAutoAdvance`** (`+Cull.swift`, cull; all steps
F and L)
1. Launch on `shoot` (L: live on `writeShoot`); sort by Name; open
   `IMG_0001` in the loupe. Metadata > Auto Advance is checked by default.
2. Press 3. Shot `cull-rated`. Expect "2 of 24"; press Left: the photo's
   value ends `3 stars`; press Right.
3. Press P on `IMG_0002`, then X on `IMG_0003`. Shot `cull-flagged`.
   Expect "4 of 24"; Favorites count 1.
4. Open Edit: the Undo item reads "Undo Reject". Choose it. Shot
   `cull-undo`. Expect the loupe still on "4 of 24" (undo does not move,
   #426); Left: `IMG_0003`'s value no longer contains `Rejected`.
5. Uncheck Metadata > Auto Advance; press 5. Expect still the same photo,
   its value `5 stars`.
6. Escape; click `IMG_0005`, Command-click `IMG_0006`; press 2. Shot
   `cull-grid`. Expect both cells' values contain `2 stars` (before S-L2:
   open each in the loupe and read its value) and the selection did not
   move.
7. Press P (both picked), then U; Edit's Undo item reads "Undo Clear
   Flag".
States: none beyond the loaded grid; with nothing selected the keys do
nothing and the Metadata items are disabled.

**J5 · `testDevelopSlidersAndHistogram`** (`+Develop.swift`, develop)
1. (F) Launch on `shoot`. (L) Live on `writeShoot`. Both with
   `-LibraryTestValues`. Sort by Name; open `IMG_0001` in the loupe; click the inspector's **Develop** tab. Shot `develop`. Expect the
   histogram `library.develop.histogram`, TONE rows Exposure, Contrast,
   Highlights, Shadows and COLOR rows Temperature, Tint, all at 0.
2. (F, L) Drag Exposure right. Shot `develop-exposure`. Expect the row's
   value above 0, the loupe photo's checksum changed, and the histogram's
   value went up: the Model builds it as `mean 0.4213` (four decimals, the
   mean sRGB value over all three channels), so one byte level of change
   shows.
3. (F, L) Focus Contrast; press Right three times, then Shift-Right.
   Expect 3, then 13 (step 1, Shift ten).
4. (F, L) Edit's Undo item reads "Undo Contrast"; undo once; Contrast
   reads 3.
5. (F, L) Click the photo (focus leaves the slider); Photo > Copy Settings
   (Shift-Command-C); Right; Photo > Paste Settings (Shift-Command-V). Shot
   `develop-pasted`. Expect `IMG_0002`'s Exposure equals `IMG_0001`'s;
   Undo reads "Undo Paste Settings".
6. (F, L) Click the TONE section's Reset. Expect its four rows at 0 and Undo
   "Undo Reset Tone". (A per-row reset waits on S-L6.)
7. (L) Set Exposure to +1 on `IMG_0001`, note the loupe checksum; wait for
   `library.catalog` = `saved`; terminate and relaunch on the same
   `-LibraryCatalogDir`; open `IMG_0001`. Expect
   Exposure +1 and the same checksum (develop survives relaunch; persist
   landed in wave 2).
8. (F) Relaunch with `-LibraryFakeMode fail`; open a photo. Shot
   `develop-error`. Expect "Couldn't render this photo: the preview failed
   on purpose." under the histogram and the loupe's placeholder (there is
   no earlier picture to keep; keeping the last picture after a later
   failure is a Model test, `LibraryLoupeImageTests`).
States: loading (`preview` while a render runs); error (render failed).

**J6 · `testCropAndStraighten`** (`+Crop.swift`, crop)
1. (F) Launch on `shoot`. (L) Live on `writeShoot`. Both with
   `-LibraryTestValues`. Sort by Name; open `IMG_0001` (6000 × 4000) in the
   loupe; Photo > Crop (R).
   Shot `crop`. Expect `library.crop.frame`, the aspect chips and the
   Straighten row.
2. (F, L) Click **1:1**. Expect the frame's value "4000 × 4000".
3. (F, L) Focus Straighten, type 5, Return. Shot `crop-straighten`. Expect
   the frame's width under 4000 and the angle 5°. (L) The width equals
   `straightenCrop`'s *height* for 6000 × 4000 at 5° (3545, ±1 px), since a
   1:1 frame is limited by the short side.
4. (F, L) Click the photo (focus leaves the Straighten field), press
   Return. Shot `crop-applied`. Expect the loupe value's size square;
   Escape: the `IMG_0001` cell's value size is square; Undo reads "Undo
   Crop".
5. (F, L) Undo; R; drag the frame's corner; Escape. Expect no change and no
   new undo step.
6. (F, L) Layout: the six aspect chips have equal widths within 0.5 pt.
7. (L) Crop to 1:1, wait for `library.catalog` = `saved`, relaunch on the
   same catalog: the cell is still square (persist).
States: none beyond the loaded photo.

**J7 · `testExportJPEGsAtASize`** (`+Export.swift`, export; steps 2–7 L,
because only the live writer makes files)
1. (F) Launch on `shoot`. (L) Live on `writeShoot`. Both with
   `-LibraryExportTo` on a temp folder. Sort by Name; select `IMG_0001` and
   `IMG_0002`; File > Export… (Shift-Command-E). Shot
   `export-sheet`. Expect long edge 2048, quality 85, "Export 2 Photos";
   the sheet lies inside the display.
2. Set the long edge to 1024 and quality to 80; click **Export**. Shot
   `exporting`. Expect the progress row "Exporting 1 of 2" with Cancel.
3. Wait. Shot `exported`. Expect `ExportSummary.message` "Exported 2
   photos." and **Show in Finder**; `IMG_0001.jpg` and `IMG_0002.jpg` exist,
   start with `FF D8`, and have a long edge of 1024.
4. Export the same two again. Expect `IMG_0001 2.jpg` and `IMG_0002 2.jpg`;
   nothing overwritten.
5. Relaunch with `-LibraryExportTo` on `LibraryFiles.readOnlyFolder()` and
   export. Shot `export-failed`. Expect "2 photos couldn't be exported."
   with each name and reason, and **Try Again**.
6. Select all 24 at Original Size; Export; Cancel after the first file.
   Shot `export-cancelled`. Expect "Exported 1 of 24. Export was
   cancelled." and fewer than 24 files.
7. Escape to the grid with nothing selected: File > Export… is disabled.
States: loading (progress row), error (per-file failures), cancelled.

**J8 · `testCatalogSurvivesRelaunch`** (`+Persist.swift`, persist; all L;
it replaces the skipped `testImportRateAndRelaunch`, which import deletes
from `LibraryJourneyTests.swift`, the file it owns in wave 2)
1. Write 6 JPEGs, 2 of them in `day2/`; launch with
   `-LibraryImportFolder` and `-LibraryImportOnLaunch`. Rate the first 4
   stars, pick the second, label the third Red.
2. Wait for `library.catalog` = `saved`; terminate
   (`XCUIApplication.terminate()`) and relaunch with the same
   `-LibraryCatalogDir` and no import. Shot `relaunched`. Expect 6 cells,
   the first `4 stars`, the second `Picked`, the third `Red`, Favorites 1.
3. Delete `day2/` from disk; relaunch. Shot `missing-files`. Expect those
   two cells' values start `unreadable` with help "The file is missing.";
   they can still be rated (press 1 on one: its value contains `1 star`).
Develop and crop round trips are J5 step 7 and J6 step 7.
States: loading at launch (placeholders while thumbnails rebuild); error
(missing files).

**J9 · `testDamagedCatalogIsSetAside`** (`+Persist.swift`, persist; all L)
1. Write `not json` as `catalog.json` in the catalog folder; launch. Shot
   `catalog-damaged`. Expect the empty state and the notice
   `CatalogFileState.damaged.message` with **Show in Finder**;
   `catalog.json.bad` exists.
2. Write `{"version": 2}`; relaunch. Shot `catalog-newer`. Expect "This
   catalog was made by a newer Library. Update Library to open it."; the
   file is untouched; rating a photo after an import saves nothing over it
   (`canSave` is false).
States: error (damaged, newer version).

**J10 · `testEveryMenuOpens`** (existing; the spine updates it): every menu
opens, and each app menu's *app-owned* items (the ones section 6.2 lists,
not the items SwiftUI and the system add) are all present.

**J11 · `testEveryControlActsOrSaysWhy`** (`+Shell.swift`, spine): reads
`library.controls`, clicks each enabled control, Escape and Command-Z
after each; every enabled control changed the shot or a value, every
disabled one has a reason. A sweep, not feature coverage.

**J12 · `testLayoutAtWidths`** (`+Layout.swift`, status-and-layout): the
layout checks of section 7.3, plus the status pills: "24 photos", "5
selected" after J2 step 4's selection, and the loupe's zoom percent.

### 4.3 Perf journeys

| # | Test (file, feature) | Mode and data | Steps | Measures (section 7) | Samples |
|---|---|---|---|---|---|
| P1 | `testGridScrollLarge` (`+PerfGrid.swift`, thumbnails) | F, `large` | scroll the grid end to end at 2,000 pt/s, three times | QB-LIB-3, QB-LIB-8 | frame intervals, ≥ 60 |
| P2 | `testCullKeyLatency` (`+PerfCull.swift`, cull) | F and L, `shoot` | 60 rating keys in the grid, then 60 in the loupe with Auto Advance (Home after each 23, once loupe-viewport's Home has landed; Left × 23 before) | QB-LIB-4, QB-LIB-5 | ≥ 60 per series |
| P3 | `testDevelopSliderLatency` (`+PerfDevelop.swift`, develop) | L, `writeShoot` | velocity drag on Exposure across its range, three times | QB-L2, QB-LIB-6 | ≥ 60 per series |
| P4 | `testLoupeStepLatency` (`+PerfLoupe.swift`, loupe-viewport) | L, `writeShoot` | Right 23 times, Home, three passes (69 steps); then Actual Size and a scroll pan of 600 pt in 60 steps | QB-LIB-5, QB-L1 (pan), QB-LIB-8 | ≥ 60 per series |
| P5 | `testCropDragLatency` (`+PerfCrop.swift`, crop) | F, `shoot` | velocity drag of the crop corner, three times | QB-L1 | ≥ 60 |
| P6 | `testImportProgressAndThroughput` (`+PerfImport.swift`, import) | L, 200 written 4000 × 3000 JPEGs | import, five times into fresh catalogs | QB-L9, QB-LIB-1 | single marks: 5 runs, each with its `progress` and `thumb-ready` marks |
| P7 | `testLaunchLargeCatalog` (`+PerfLaunch.swift`, persist) | L, a 10,000-record `catalog.json` the test writes in the v1 format (files missing, so cells show placeholders) | launch, five times | QB-LIB-2, QB-L12 | single marks: 5 runs, each with `launch-grid` |
| P8 | `testExportThroughput` (`+PerfExport.swift`, export) | L, 10 written 6000 × 4000 JPEGs | export at long edge 2048, three times | QB-L9 (export), QB-LIB-7 | single marks: 3 runs |

Series rows assert at least 60 samples per series (else the test fails as
invalid); single-mark rows assert that each run recorded its marks. All
attach `perf-<test>.json`, ship report-only (rubric 6, How gates are set),
and need #330 with S-L8's named marks and #333 for velocity drags.

Checklist:

- [x] Every tier-1 row of section 3 has a journey: import J1, grid J2,
      loupe and zoom J3, cull and auto-advance J4, undo J4–J7, develop J5,
      crop J6, export J7, persistence J8 and J9.
- [x] Every journey names its XCUITest, its file and the feature that owns
      it.
- [x] Every empty, loading and error state a tier-1 journey passes through
      is named in its States line.

---

## 5. Contracts

One Swift protocol per use case, with exact signatures and a fake for
each, so the UI track builds on fakes while the logic track builds the
live conformances. The code below is the whole contract layer: it is also
in `docs/blueprints/library/contracts/`, and
`docs/blueprints/library/contracts/check.sh` copies it over today's
`Sources/LibraryModel` and runs `swift test` on Linux in Swift 6 mode
against creative-core `dev` 4cac701: the six smoke tests in
`ContractSmokeTests.swift` (every contract through `LibraryServices.fake`;
every fake called once; every notice's exact text; the fakes showing each
change a journey's (F) steps assert; every live stub's reason; samples on
the live stubs) plus all 63 existing LibraryModel tests against the new
`PhotoItem`, against creative-core 4cac701 (pinned in `check.sh`, `CORE_REV`
overrides). On 2026-10-14 it compiled with no warnings and 69 of 69 tests
passed (Swift 6.1.2, x86_64 Ubuntu 24.04). The spine lands these files verbatim as
`Sources/LibraryModel/Contracts/`, `Sources/LibraryModel/Fakes/`,
`Sources/LibraryModel/Live/` (stubs), `Sources/LibraryModel/SampleImage.swift` and
`Sources/LibraryModel/LibraryServices.swift`, and the `PhotoItem` changes in
5.5.

### 5.1 Use cases and who conforms

| Contract | Use case (journeys) | Kind | Live conformance (feature) | Fake |
|---|---|---|---|---|
| `PhotoDecoding` | read files: scan a folder, decode pixels (J1–J8) | platform | `ImageIODecoder`, `Sources/LibraryApp/Platform/` (import) | `FakeDecoder`: fixture photos in any folder, gradients |
| `JPEGWriting` | write a JPEG, never overwrite (J7) | platform | `JPEGWriter` (export) | `FakeJPEGWriter`: in memory |
| `CatalogStoring` | read, write and set aside the catalog file (J8, J9) | platform | `CatalogStore` (persist) | `FakeCatalogStore`: in memory |
| `PhotoImporting` | import a folder (J1) | use case | `LiveImporter(decoder:)` (import) | `FakeImporter`: the fixture minus known ids |
| `ThumbnailProviding` | grid thumbnails (J2) | use case | `LiveThumbnails(decoder:develop:)` (thumbnails) | `FakeThumbnails`: gradients in the crop's shape |
| `PhotoCulling` | rating, flag, label, Auto Advance (J4) | use case | `LiveCulling` (cull) | `FakeCulling`: applies; advances by the plain rule |
| `CatalogCoding` | catalog file v1 (J8, J9) | use case | `LiveCatalogCoding` (persist) | `FakeCatalogCoding`: id and rating as text |
| `LoupeImaging` | the loupe's picture and histogram (J3, J5) | use case | `LiveLoupeImaging(decoder:develop:)` (loupe-viewport, then develop) | `FakeLoupe`: gradients brightened per slider step, a counted histogram |
| `DevelopRendering` | settings to pixels (J5, J6, J7) | use case | `LiveDevelop` (develop; crop adds the crop) | `FakeDevelop`: unchanged buffer |
| `CropGeometry` | crop frame rules (J6) | use case | `LiveCrop` (crop) | `FakeCrop`: centered aspect, a simple angle shrink, edge drags |
| `PhotoExporting` | export plan and render (J7) | use case | `LiveExporter(decoder:develop:)` (export) | `FakeExporter`: same naming rule |

Every fake but `FakeCrop` (pure geometry) takes a `FakeMode` (`-LibraryFakeMode ok|fail|slow`): `fail`
throws the contract's error, `slow` waits 2 s first, so every loading and
error state can be shown and snapshotted before any live code exists.

**Why culling has a protocol.** Culling has no engine behind it; its live
conformance is plain Model code. It still gets a protocol so the UI track's
key handling and the logic track's rules (Auto Advance through a filter,
undo) can be built at the same time, and so `-LibraryFakeMode fail` can
show a refused change. This is the one place this blueprint departs from
Flare's decision 14 ("no protocol where there is one conformer"), at the
cost of about 40 lines.

### 5.2 Value types

```swift
// Contracts/LibraryValues.swift: the value types every Library contract
// shares. Linux-safe, Sendable, no pixels except DisplayImage's bytes.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A size in pixels. Both sides are at least 1 for a real photo.
public struct PixelSize: Hashable, Sendable, Codable {
    public var width: Int
    public var height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    public var longSide: Int { max(width, height) }
    /// This size scaled so its long side is at most `longSide`, never enlarged,
    /// each side at least 1. `longSide` under 1 is treated as 1.
    public func fitting(longSide limit: Int) -> PixelSize {
        let limit = max(limit, 1)
        guard longSide > limit, width > 0, height > 0 else { return self }
        let scale = Double(limit) / Double(longSide)
        return PixelSize(width: max(Int((Double(width) * scale).rounded()), 1),
                         height: max(Int((Double(height) * scale).rounded()), 1))
    }
}

/// The thumbnail sizes the grid asks for: the smallest bucket whose long
/// side covers the cell at the display's scale (a 320 pt cell at 2x needs
/// 640 px, so 1024).
public enum ThumbnailBucket {
    public static let sizes = [128, 256, 512, 1024]
    /// The live LRU's limit in bytes of display images (256 MB).
    public static let cacheBytes = 256 * 1024 * 1024
    /// The bucket for a cell `cellWidth` points wide at `scale` pixels a point.
    public static func longSide(forCell cellWidth: Int, scale: Int) -> Int {
        let needed = max(cellWidth, 1) * max(scale, 1)
        return sizes.first { $0 >= needed } ?? 1024
    }
}

/// A rectangle in whole pixels.
public struct PixelRect: Hashable, Sendable {
    public var x: Int, y: Int, width: Int, height: Int
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// Display bytes: sRGB, straight alpha, row-major, top row first, 4 bytes a
/// pixel (CoreRaster's `rgba8(colorSpace:)` layout).
public struct DisplayImage: Hashable, Sendable {
    public let size: PixelSize
    public let rgba8: [UInt8]
    /// Nil unless `rgba8.count == width * height * 4` and both sides are at least 1.
    public init?(size: PixelSize, rgba8: [UInt8]) {
        guard size.width >= 1, size.height >= 1,
              size.width.multipliedReportingOverflow(by: size.height).overflow == false,
              rgba8.count == size.width * size.height * 4 else { return nil }
        self.size = size
        self.rgba8 = rgba8
    }
    /// FNV-1a over the bytes as 16 hex digits: the loupe photo's checksum
    /// that journeys read. Computed on demand, only under `-LibraryTestValues`.
    public var checksum: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in rgba8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }
}

/// The image file types v1 imports (JPEG, PNG, HEIC); see `kind(forFileName:)`
/// for the extensions each accepts.
public enum PhotoFileKind: String, Sendable, Codable, CaseIterable {
    case jpeg, png, heic
    /// The kind for a file name, matched without regard to case; nil for anything else.
    public static func kind(forFileName name: String) -> PhotoFileKind? {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        switch name[name.index(after: dot)...].lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        default: return nil
        }
    }
}

/// One file a folder scan found, read for metadata only.
public struct ImportCandidate: Hashable, Sendable {
    /// The absolute file path: the photo's id once imported.
    public var path: String
    /// Exif DateTimeOriginal, else the file's creation date.
    public var captureDate: Date
    /// After the Exif orientation is applied.
    public var pixelSize: PixelSize
    public var kind: PhotoFileKind
    public init(path: String, captureDate: Date, pixelSize: PixelSize, kind: PhotoFileKind) {
        self.path = path; self.captureDate = captureDate; self.pixelSize = pixelSize; self.kind = kind
    }
}

/// A file that could not be imported or exported, and why, in words for people.
public struct FileFailure: Hashable, Sendable {
    public var path: String
    public var reason: String
    public init(path: String, reason: String) {
        self.path = path; self.reason = reason
    }
}

/// What a folder scan found.
public struct FolderScan: Hashable, Sendable {
    public var candidates: [ImportCandidate]
    /// Image-named files whose metadata could not be read.
    public var failures: [FileFailure]
    public init(candidates: [ImportCandidate], failures: [FileFailure]) {
        self.candidates = candidates; self.failures = failures
    }
}

public struct ImportProgress: Hashable, Sendable {
    public var done: Int
    public var total: Int
    public init(done: Int, total: Int) {
        self.done = done; self.total = total
    }
    /// "Importing 3 of 27".
    public var text: String { "Importing \(min(done + 1, max(total, 1))) of \(max(total, 1))" }
}

public struct ImportResult: Hashable, Sendable {
    /// New photos, in capture-date order.
    public var added: [PhotoItem]
    /// Paths already in the catalog, skipped.
    public var alreadyKnown: Int
    public var failures: [FileFailure]
    public init(added: [PhotoItem], alreadyKnown: Int, failures: [FileFailure]) {
        self.added = added; self.alreadyKnown = alreadyKnown; self.failures = failures
    }
}

/// Every error a Library contract throws. `message` is the text the window shows.
public enum LibraryError: Error, Hashable, Sendable {
    case unreadableFolder(String)
    case noPhotos(String)
    case notAnImage(String)
    case missingFile(String)
    case damagedCatalog(String)
    case newerCatalog(version: Int)
    case invalid(String)
    case renderFailed(String)
    case writeFailed(path: String, reason: String)
    case cancelled

    public var message: String {
        switch self {
        case .unreadableFolder(let folder): "Library can't read \(folder). Check that you have access to it."
        case .noPhotos(let folder): "No photos found in \(folder)."
        case .notAnImage: "not an image file"
        case .missingFile(let path): "The file is missing: \(path)"
        case .damagedCatalog: "Library couldn't read its catalog and started a new one. The old file is catalog.json.bad."
        case .newerCatalog: "This catalog was made by a newer Library. Update Library to open it."
        case .invalid(let detail): detail
        case .renderFailed(let reason): "Couldn't render this photo: \(reason)."
        case .writeFailed(_, let reason): reason
        case .cancelled: "Cancelled."
        }
    }
}

/// How the fakes behave; `-LibraryFakeMode`.
public enum FakeMode: String, Sendable, CaseIterable {
    case ok, fail, slow
}
```

```swift
// Contracts/DevelopValues.swift: a photo's develop settings, its crop, and
// the histogram the develop panel draws. Settings are edit instructions,
// never pixels; neutral settings render the photo unchanged.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One develop slider. The raw value is the row's label.
public enum DevelopSlider: String, CaseIterable, Sendable, Codable {
    // The panel's order: TONE, then COLOR.
    case exposure = "Exposure", contrast = "Contrast", highlights = "Highlights", shadows = "Shadows"
    case temperature = "Temperature", tint = "Tint"

    /// The inspector section the row sits in; a section's Reset resets its group.
    public var group: DevelopGroup {
        switch self {
        case .exposure, .contrast, .highlights, .shadows: .tone
        case .temperature, .tint: .color
        }
    }

    /// Exposure in stops, -5...5; the rest -100...100 (CoreRaster's slider range).
    public var range: ClosedRange<Double> { self == .exposure ? -5...5 : -100...100 }
    /// One arrow-key step; Shift is ten, Option a tenth (docs/design.md, Scrub fields).
    public var step: Double { self == .exposure ? 0.01 : 1 }
}

/// A develop section. The raw value is its header.
public enum DevelopGroup: String, CaseIterable, Sendable {
    case tone = "Tone", color = "Color"
    public var sliders: [DevelopSlider] { DevelopSlider.allCases.filter { $0.group == self } }
}

public struct DevelopSettings: Hashable, Sendable, Codable {
    public private(set) var exposure: Double = 0
    public private(set) var temperature: Double = 0
    public private(set) var tint: Double = 0
    public private(set) var contrast: Double = 0
    public private(set) var highlights: Double = 0
    public private(set) var shadows: Double = 0
    /// Nil: the whole photo, upright.
    public private(set) var crop: CropSettings?

    public static let neutral = DevelopSettings()
    public init() {}

    public var isNeutral: Bool { self == .neutral }
    /// True when no slider is off zero (the crop may still be set).
    public var isAdjustmentNeutral: Bool { DevelopSlider.allCases.allSatisfy { value($0) == 0 } }

    public func value(_ slider: DevelopSlider) -> Double {
        switch slider {
        case .exposure: exposure
        case .temperature: temperature
        case .tint: tint
        case .contrast: contrast
        case .highlights: highlights
        case .shadows: shadows
        }
    }

    /// A copy with `slider` at `value`, clamped to its range; NaN and infinity give 0.
    public func setting(_ slider: DevelopSlider, to value: Double) -> DevelopSettings {
        let clamped = value.isFinite ? min(max(value, slider.range.lowerBound), slider.range.upperBound) : 0
        var copy = self
        switch slider {
        case .exposure: copy.exposure = clamped
        case .temperature: copy.temperature = clamped
        case .tint: copy.tint = clamped
        case .contrast: copy.contrast = clamped
        case .highlights: copy.highlights = clamped
        case .shadows: copy.shadows = clamped
        }
        return copy
    }

    public func setting(crop: CropSettings?) -> DevelopSettings {
        var copy = self
        copy.crop = crop
        return copy
    }

    /// All six sliders of `other` with this crop: Paste Settings never pastes a crop.
    public func pastingAdjustments(from other: DevelopSettings) -> DevelopSettings {
        var copy = other
        copy.crop = crop
        return copy
    }
}

/// A rectangle in 0...1 of an image's width and height.
public struct UnitRect: Hashable, Sendable, Codable {
    public var x: Double, y: Double, width: Double, height: Double
    public static let full = UnitRect(x: 0, y: 0, width: 1, height: 1)
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// The crop's aspect. The raw value is the chip's title.
public enum CropAspect: String, CaseIterable, Sendable, Codable {
    case original = "Original", free = "Free", square = "1:1"
    case fourFive = "4:5", threeTwo = "3:2", sixteenNine = "16:9"

    /// Width over height for a photo of `size` (a 3:2 on a portrait photo is 2:3); nil for Free.
    public func ratio(for size: PixelSize) -> Double? {
        let portrait = size.height > size.width
        let base: Double? = switch self {
        case .free: nil
        case .original: size.height > 0 ? Double(size.width) / Double(size.height) : nil
        case .square: 1
        case .fourFive: 4.0 / 5.0
        case .threeTwo: 3.0 / 2.0
        case .sixteenNine: 16.0 / 9.0
        }
        guard let base, self != .original, self != .square else { return base }
        return portrait == (base > 1) ? 1 / base : base
    }
}

public struct CropSettings: Hashable, Sendable, Codable {
    public static let angleRange: ClosedRange<Double> = -45...45
    /// Degrees clockwise, in `angleRange`.
    public var angle: Double
    /// In 0...1 of the straightened photo's largest upright crop
    /// (CoreRaster `PixelBuffer.straightenCrop`), so no transparent corner shows.
    public var rect: UnitRect
    public var aspect: CropAspect
    public init(angle: Double, rect: UnitRect, aspect: CropAspect) {
        self.angle = angle; self.rect = rect; self.aspect = aspect
    }
}

/// A crop frame handle.
public enum CropHandle: Sendable, Hashable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, inside
}

/// The develop panel's histogram: 256 bins per channel over sRGB-encoded
/// values (what a display shows), plus clipping counts.
public struct HistogramBins: Hashable, Sendable {
    public static let binCount = 256
    public let red: [Int], green: [Int], blue: [Int]
    public let shadowClipped: Int, highlightClipped: Int
    public static let empty = HistogramBins(
        red: Array(repeating: 0, count: binCount), green: Array(repeating: 0, count: binCount),
        blue: Array(repeating: 0, count: binCount), shadowClipped: 0, highlightClipped: 0)
    public init(red: [Int], green: [Int], blue: [Int], shadowClipped: Int, highlightClipped: Int) {
        self.red = red; self.green = green; self.blue = blue
        self.shadowClipped = shadowClipped; self.highlightClipped = highlightClipped
    }
    /// Each channel scaled to 0...1 by the tallest bin of all three; all 0 (never NaN) when empty.
    public var heights: (red: [Double], green: [Double], blue: [Double]) {
        let tallest = Double(max(red.max() ?? 0, green.max() ?? 0, blue.max() ?? 0))
        let scale: ([Int]) -> [Double] = { bins in bins.map { tallest > 0 ? Double($0) / tallest : 0 } }
        return (scale(red), scale(green), scale(blue))
    }
}

/// A preview is drawn from the thumbnail-size decode while a drag is under
/// way; full is the screen-size render it settles to.
public enum RenderQuality: String, Sendable, Hashable { case preview, full }

/// The loupe's picture and its histogram.
public struct RenderedPhoto: Hashable, Sendable {
    public var image: DisplayImage
    public var histogram: HistogramBins
    public var quality: RenderQuality
    public init(image: DisplayImage, histogram: HistogramBins, quality: RenderQuality) {
        self.image = image; self.histogram = histogram; self.quality = quality
    }
}
```

The notice and file-state values, with the exact text journeys read (the
spine declares them; `LibraryCatalog`'s stored state holds them):

```swift
// Contracts/StateValues.swift: the values behind the import and export
// notices and the catalog file's state, with the exact text the window
// shows, so journeys and Linux tests assert the same strings. The spine
// declares these with the catalog's stored state; features only fill them.
/// What the last import did; the content's notice shows `message`.
public struct ImportNotice: Hashable, Sendable {
    public var folder: String
    public var added: Int
    public var alreadyKnown: Int
    public var failures: [FileFailure]
    /// Set when the whole import failed (unreadable folder, no photos).
    public var error: LibraryError?
    public init(folder: String, added: Int = 0, alreadyKnown: Int = 0, failures: [FileFailure] = [],
                error: LibraryError? = nil) {
        self.folder = folder; self.added = added; self.alreadyKnown = alreadyKnown
        self.failures = failures; self.error = error
    }

    public var message: String {
        if let error { return error.message }
        let failed = failures.isEmpty ? "" : failures.count == 1
            ? " 1 file couldn't be imported." : " \(failures.count) files couldn't be imported."
        if added == 0 { return failures.isEmpty ? "No new photos in \(folder)." : String(failed.dropFirst()) }
        return (added == 1 ? "Imported 1 photo." : "Imported \(added) photos.") + failed
    }
    /// The notice's state: error when nothing came in and something failed.
    public var isError: Bool { error != nil || (added == 0 && !failures.isEmpty) }
}

/// How an export ended; the sheet shows `message`, `failures` and, when
/// any failed, Try Again (`LibraryCatalog.retryExport()` re-plans `failedIDs`).
public struct ExportSummary: Hashable, Sendable {
    public var total: Int
    public var written: [String]
    public var failures: [FileFailure]
    public var failedIDs: [String]
    public var cancelled: Bool
    public init(total: Int, written: [String], failures: [FileFailure] = [], failedIDs: [String] = [],
                cancelled: Bool = false) {
        self.total = total; self.written = written; self.failures = failures
        self.failedIDs = failedIDs; self.cancelled = cancelled
    }

    public var message: String {
        if cancelled { return "Exported \(written.count) of \(total). Export was cancelled." }
        if !failures.isEmpty {
            return failures.count == 1 ? "1 photo couldn't be exported." : "\(failures.count) photos couldn't be exported."
        }
        return written.count == 1 ? "Exported 1 photo." : "Exported \(written.count) photos."
    }
}

/// The catalog file at launch and after; the content's notice shows `message`.
public enum CatalogFileState: Hashable, Sendable {
    case loading, ready
    /// The file was set aside as `catalog.json.bad`; the catalog starts empty.
    case damaged
    /// A newer Library wrote it; it is left untouched and nothing is saved over it.
    case newer(version: Int)

    public var message: String? {
        switch self {
        case .loading, .ready: nil
        case .damaged: LibraryError.damagedCatalog("").message
        case .newer(let version): LibraryError.newerCatalog(version: version).message
        }
    }
    /// False while loading and for `.newer`: saving would overwrite a file
    /// this Library can't read.
    public var canSave: Bool {
        switch self {
        case .ready, .damaged: true
        case .loading, .newer: false
        }
    }
}
```

Sample photos have no file. Fakes and live conformances alike draw them
with `SampleImage` (`Sources/LibraryModel/SampleImage.swift`, spine), so
today's sample journeys keep working when services go live:

```swift
// SampleImage.swift: the picture of a photo with no file (a generated
// sample): a left-to-right gradient from its color to half its color, at
// its pixel size fitted to a long side. Fakes and the live conformances
// both draw samples with it, so sample photos look the same on fake and
// live services. Deterministic. Linux-safe.
public enum SampleImage {
    /// `photo`'s gradient, its `pixelSize` fitted to `longSide` (nil: full size).
    public static func image(for photo: PhotoItem, longSide: Int?) -> DisplayImage? {
        let size = longSide.map { photo.pixelSize.fitting(longSide: $0) } ?? photo.pixelSize
        let color = photo.pixel
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.width * size.height * 4)
        for _ in 0..<size.height {
            for x in 0..<size.width {
                let t = size.width > 1 ? Double(x) / Double(size.width - 1) : 0
                for channel in 0..<3 { bytes.append(UInt8((Double(color[channel]) * (1 - t / 2)).rounded())) }
                bytes.append(255)
            }
        }
        return DisplayImage(size: size, rgba8: bytes)
    }
}
```

### 5.3 The protocols

```swift
// Contracts/LibraryContracts.swift: one protocol per use case, so the UI
// track builds on the fakes while the logic track builds the live
// conformances. Three are platform contracts (decode, JPEG write, catalog
// file), conformed to in LibraryApp/Platform; the rest are conformed to in
// LibraryModel/Live over CoreRaster. Every async call runs off the main
// actor and returns a value the window hands to a LibraryCatalog method.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

// MARK: Platform (conformed to in LibraryApp/Platform, ImageIO and the file system)

/// Reads image files. Live: `ImageIODecoder`. Fake: `FakeDecoder`.
public protocol PhotoDecoding: Sendable {
    /// Image files under `folder`, subfolders included, hidden files and
    /// packages skipped, with their metadata; no pixels are decoded.
    /// Throws `LibraryError.unreadableFolder` when the folder can't be listed.
    func scan(folder: String) async throws -> FolderScan
    /// The file's pixels with its Exif orientation applied, converted to
    /// sRGB, long side at most `maxLongSide` (nil: full size), never enlarged.
    /// Throws `missingFile` or `notAnImage`.
    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage
}

/// Writes JPEG files. Live: `JPEGWriter`. Fake: `FakeJPEGWriter` (in memory).
public protocol JPEGWriting: Sendable {
    /// File names already in `folder`; throws `writeFailed` when it can't be listed.
    func existingNames(in folder: String) async throws -> Set<String>
    /// Writes `image` as an sRGB JPEG at `quality` (0...100) to `folder`/`fileName`.
    /// Never overwrites: throws `writeFailed` when the file exists or can't be written.
    func write(_ image: DisplayImage, quality: Int, folder: String, fileName: String) async throws
}

/// Where the catalog file lives. Live: `CatalogStore` (Application Support,
/// or `-LibraryCatalogDir`). Fake: `FakeCatalogStore` (in memory).
public protocol CatalogStoring: Sendable {
    /// The file's bytes; nil when there is no catalog yet.
    func read() async throws -> Data?
    /// Replaces the file atomically (write to a temporary file, then rename).
    func write(_ data: Data) async throws
    /// Renames the file to `catalog.json.bad` (replacing an older `.bad`), so
    /// the next write starts fresh; returns the new name.
    func setAside() async throws -> String
}

// MARK: Use cases (conformed to in LibraryModel/Live)

/// J1. Import a folder. Live: `LiveImporter(decoder:)`.
public protocol PhotoImporting: Sendable {
    /// Scans `folder`, skips paths in `known`, and returns the new photos in
    /// capture-date order with ids equal to their paths. Calls `progress`
    /// after each file, at most 30 times a second, and `added` with each
    /// batch of new photos (at most 50, at least every 250 ms) as they are
    /// read, so the grid fills while the import runs; the result repeats
    /// them all. Throws `unreadableFolder`, or `noPhotos` when the folder
    /// holds no image file at all; a file that fails is a `FileFailure`,
    /// never a throw.
    func importFolder(_ folder: String, known: Set<String>,
                      progress: @escaping @Sendable (ImportProgress) -> Void,
                      added: @escaping @Sendable ([PhotoItem]) -> Void) async throws -> ImportResult
}

/// J2. Grid thumbnails. Live: `LiveThumbnails(decoder:develop:)`, an actor
/// with an LRU of at most `ThumbnailBucket.cacheBytes` of images. A photo
/// with no `path` (a sample) is drawn from `SampleImage`, never decoded.
public protocol ThumbnailProviding: Sendable {
    /// The photo at `longSide` (a `ThumbnailBucket`) with its develop
    /// settings and crop applied. Throws `missingFile` or `notAnImage`.
    func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage
    /// Drops cached images of `id` (after its settings change).
    func invalidate(_ id: String) async
}

/// J4. Rating, flag and label. Live: `LiveCulling`. Pure and synchronous: it
/// runs on the main actor inside a catalog method.
public protocol PhotoCulling: Sendable {
    /// `items` with `change` applied to every photo whose id is in `ids`;
    /// the rest unchanged and in the same order. Throws
    /// `LibraryError.invalid` for a rating outside 0...5, changing nothing.
    func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem]
    /// Auto Advance: the photo to focus after a change to `id`. `before` is
    /// the shown order before the change and `after` the order after it (a
    /// filter may hide the photo). The next photo after `id`; if `id` is no
    /// longer shown, the photo that took its place; `id` itself when it was
    /// last; nil when nothing is shown.
    func advance(from id: String, before: [String], after: [String]) -> String?
}

/// J8, J9. The catalog file. Live: `LiveCatalogCoding` (JSON, `"version": 1`).
public protocol CatalogCoding: Sendable {
    func encode(_ photos: [PhotoItem]) throws -> Data
    /// Throws `damagedCatalog` for bytes that aren't a v1 catalog and
    /// `newerCatalog` for a version above 1. A missing `develop` object
    /// decodes as neutral settings.
    func decode(_ data: Data) throws -> [PhotoItem]
}

/// J3, J5. The loupe's picture. Live: `LiveLoupeImaging(decoder:develop:)`,
/// an actor caching the decoded screen-size buffers of the focused photo and
/// its two neighbours. A photo with no `path` is drawn from `SampleImage`.
public protocol LoupeImaging: Sendable {
    /// `photo` with `settings` (tone and crop), long side at most `longSide`,
    /// and its histogram. `.preview` renders from the 512 px thumbnail decode
    /// (used during a drag); `.full` from the screen-size decode.
    func render(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                quality: RenderQuality) async throws -> RenderedPhoto
    /// Decodes `photos` ahead (the neighbours of the focused photo).
    func prefetch(_ photos: [PhotoItem], longSide: Int) async
}

/// J5, J7. Develop settings to pixels. Live: `LiveDevelop` over CoreRaster:
/// white balance, exposure, contrast, highlights and shadows in that order,
/// then the crop. Neutral settings return the buffer unchanged.
public protocol DevelopRendering: Sendable {
    func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer
    func histogram(of buffer: PixelBuffer) throws -> HistogramBins
}

/// J6. Crop geometry. Live: `LiveCrop` over CoreRaster's `straightenCrop`.
public protocol CropGeometry: Sendable {
    /// A crop at `aspect` and `angle`, centered and as large as fits.
    func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings
    /// `crop` after dragging `handle` by `dx`, `dy` photo pixels, kept on its
    /// aspect and inside the straightened photo; at least 16 px a side.
    func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                 photo: PixelSize) throws -> CropSettings
    /// `crop` at a new angle, shrunk if needed to stay inside.
    func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings
    /// The crop's frame in the straightened photo's pixels (what export writes).
    func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect
}

/// J7. Export. Live: `LiveExporter(decoder:develop:)`. A photo with no
/// `path` exports its `SampleImage` at its `pixelSize`.
public protocol PhotoExporting: Sendable {
    /// Sizes and file names for `photos`: long edge from `options`, never
    /// enlarged; `<name>.jpg`, then `<name> 2.jpg`, ... skipping
    /// `existingNames` and names earlier in the plan.
    func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan
    /// One planned photo at full size with its settings, resized with
    /// lanczos3 to `item.size`. Throws `missingFile`, `notAnImage` or `renderFailed`.
    func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage
}

// MARK: Values the contracts above take

/// One culling change.
public enum CullChange: Hashable, Sendable {
    case rating(Int)
    case flag(PhotoFlag)
    case label(PhotoLabel?)

    /// The undo step's name: "Set Rating", "Pick", "Reject", "Clear Flag", "Set Label".
    public var undoName: String {
        switch self {
        case .rating: "Set Rating"
        case .flag(.pick): "Pick"
        case .flag(.reject): "Reject"
        case .flag(.none): "Clear Flag"
        case .label: "Set Label"
        }
    }
}

public struct ExportOptions: Hashable, Sendable {
    public static let defaultLongEdge = 2048
    public static let longEdgeRange = 16...16384
    /// Nil: original size.
    public var longEdge: Int?
    public var quality: Int
    public var folder: String
    /// `longEdge` and `quality` clamped to their ranges.
    public init(longEdge: Int? = defaultLongEdge, quality: Int = 85, folder: String) {
        self.longEdge = longEdge.map { min(max($0, Self.longEdgeRange.lowerBound), Self.longEdgeRange.upperBound) }
        self.quality = min(max(quality, 0), 100)
        self.folder = folder
    }
}

public struct ExportPlan: Hashable, Sendable {
    public struct Item: Hashable, Sendable {
        public var photoID: String
        public var fileName: String
        public var size: PixelSize
        public init(photoID: String, fileName: String, size: PixelSize) {
            self.photoID = photoID; self.fileName = fileName; self.size = size
        }
    }
    public var items: [Item]
    public var options: ExportOptions
    public init(items: [Item], options: ExportOptions) {
        self.items = items; self.options = options
    }
}
```

### 5.4 Wiring: `LibraryServices`

```swift
// LibraryServices.swift: one existential per contract. `.fake` runs every
// member on its fake (the UI track, snapshots, `-LibraryFixture`); `.live`
// takes the platform adapters from LibraryApp and builds the `Live…`
// conformances. Until a feature lands, its `Live…` type is the spine's stub,
// whose `unavailable` reason disables the controls that need it.
public struct LibraryServices: Sendable {
    public var decoder: any PhotoDecoding
    public var importer: any PhotoImporting
    public var thumbnails: any ThumbnailProviding
    public var culling: any PhotoCulling
    public var coding: any CatalogCoding
    public var store: any CatalogStoring
    public var loupe: any LoupeImaging
    public var develop: any DevelopRendering
    public var crop: any CropGeometry
    public var exporter: any PhotoExporting
    public var writer: any JPEGWriting
    /// Why a member can't act yet, by member name; empty once all are live.
    public var unavailable: [String: String]
    /// True for `.fake` (fixture data on screen); drives the "Preview data" pill.
    public var isPreview: Bool

    public init(decoder: any PhotoDecoding, importer: any PhotoImporting, thumbnails: any ThumbnailProviding,
                culling: any PhotoCulling, coding: any CatalogCoding, store: any CatalogStoring,
                loupe: any LoupeImaging, develop: any DevelopRendering, crop: any CropGeometry,
                exporter: any PhotoExporting, writer: any JPEGWriting,
                unavailable: [String: String] = [:], isPreview: Bool) {
        self.decoder = decoder; self.importer = importer; self.thumbnails = thumbnails
        self.culling = culling; self.coding = coding; self.store = store; self.loupe = loupe
        self.develop = develop; self.crop = crop; self.exporter = exporter; self.writer = writer
        self.unavailable = unavailable; self.isPreview = isPreview
    }

    /// Every member a fake over `photos` (a fixture's photos).
    public static func fake(_ photos: [PhotoItem] = [], mode: FakeMode = .ok) -> LibraryServices {
        let decoder = FakeDecoder(photos: photos, mode: mode)
        return LibraryServices(
            decoder: decoder, importer: FakeImporter(photos: photos, mode: mode),
            thumbnails: FakeThumbnails(mode: mode), culling: FakeCulling(mode: mode),
            coding: FakeCatalogCoding(mode: mode), store: FakeCatalogStore(mode: mode),
            loupe: FakeLoupe(mode: mode), develop: FakeDevelop(mode: mode), crop: FakeCrop(),
            exporter: FakeExporter(mode: mode), writer: FakeJPEGWriter(mode: mode), isPreview: true)
    }

    /// The live services over LibraryApp's platform adapters. Every member is
    /// its `Live…` type from the start; a feature replaces its own `Live/`
    /// file and sets that type's `unavailable` to nil, so nobody edits this.
    public static func live(decoder: any PhotoDecoding, writer: any JPEGWriting,
                            store: any CatalogStoring) -> LibraryServices {
        let develop = LiveDevelop()
        let reasons: [(String, String?)] = [
            ("importer", LiveImporter.unavailable), ("thumbnails", LiveThumbnails.unavailable),
            ("culling", LiveCulling.unavailable), ("coding", LiveCatalogCoding.unavailable),
            ("loupe", LiveLoupeImaging.unavailable), ("develop", LiveDevelop.unavailable),
            ("crop", LiveCrop.unavailable), ("exporter", LiveExporter.unavailable),
        ]
        var unavailable: [String: String] = [:]
        for (member, reason) in reasons { if let reason { unavailable[member] = reason } }
        return LibraryServices(
            decoder: decoder, importer: LiveImporter(decoder: decoder),
            thumbnails: LiveThumbnails(decoder: decoder, develop: develop), culling: LiveCulling(),
            coding: LiveCatalogCoding(), store: store, loupe: LiveLoupeImaging(decoder: decoder, develop: develop),
            develop: develop, crop: LiveCrop(), exporter: LiveExporter(decoder: decoder, develop: develop),
            writer: writer, unavailable: unavailable, isPreview: false)
    }
}
```

Each `Live/Live….swift` starts as a spine stub (all eight are in
`docs/blueprints/library/contracts/Live/`). A stub does what needs no file
and no feature: sample photos draw through `SampleImage`, culling applies
the plain rules (so the #750 inspector keeps working), `LiveDevelop`
returns neutral renders and an empty histogram (so the live loupe works in
wave 2). Anything that needs a file or the feature throws the reason. The
thumbnails stub:

```swift
// Live/LiveThumbnails.swift: spine stub. The thumbnails feature replaces this file
// with the live conformance and sets `unavailable` to nil. Until then it
// does what needs no file (samples through `SampleImage`, pure rules) and
// throws its reason for anything that needs the feature, so the controls
// that need it are disabled with that reason.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveThumbnails: ThumbnailProviding {
    public static let unavailable: String? = "Thumbnails aren't connected yet (thumbnails)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    let decoder: any PhotoDecoding
    let develop: any DevelopRendering
    public init(decoder: any PhotoDecoding, develop: any DevelopRendering) {
        self.decoder = decoder; self.develop = develop
    }

    public func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage {
        guard photo.path == nil, let image = SampleImage.image(for: photo, longSide: longSide) else { throw Self.notBuilt }
        return image
    }

    public func invalidate(_ id: String) async {}
}
```

<details><summary>The fakes (Fakes/FakeSupport.swift, FakePlatform.swift, FakeUseCases.swift)</summary>

The fakes are stand-ins, not the engine: `FakeLoupe` lifts by one byte
level per slider step (0.01 EV, or 1) and takes the crop's shape, so every
slider and crop visibly changes the picture and the histogram; `FakeCrop` shrinks by a simple angle rule; `FakeCulling`
advances by the plain rule. Journey steps that need the real math are
marked live-only in section 4.

```swift
// Fakes/FakeSupport.swift: what every fake shares: the `-LibraryFakeMode`
// behavior (fail throws, slow waits 2 s first) and the photo's sample
// gradient, so fake thumbnails and loupe pictures differ per photo and are
// the same on every run.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum FakeBehavior {
    /// Waits in `.slow`, throws `error` in `.fail`.
    static func perform(_ mode: FakeMode, failing error: LibraryError) async throws {
        if mode == .slow { try await Task.sleep(nanoseconds: 2_000_000_000) }
        if mode == .fail { throw error }
    }

    /// The photo's sample gradient (`SampleImage`), so fakes and samples agree.
    static func gradient(for photo: PhotoItem, longSide: Int?) -> DisplayImage? {
        SampleImage.image(for: photo, longSide: longSide)
    }

    /// `photo` at its crop's shape, so a cropped photo looks cropped on fakes too.
    static func cropShaped(_ photo: PhotoItem, _ crop: CropSettings?) -> PhotoItem {
        guard let rect = crop?.rect else { return photo }
        return photo.withSize(PixelSize(width: max(Int(Double(photo.pixelSize.width) * rect.width), 1),
                                        height: max(Int(Double(photo.pixelSize.height) * rect.height), 1)))
    }
}
```

```swift
// Fakes/FakePlatform.swift: fakes of the three platform contracts. The
// decoder "finds" the fixture's photos in any folder; the writer and the
// store keep bytes in memory, so tests read back what was written.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakeDecoder: PhotoDecoding {
    let photos: [PhotoItem]
    let mode: FakeMode
    public init(photos: [PhotoItem], mode: FakeMode = .ok) {
        self.photos = photos; self.mode = mode
    }

    public func scan(folder: String) async throws -> FolderScan {
        try await FakeBehavior.perform(mode, failing: .unreadableFolder(folder))
        let candidates = photos.map {
            ImportCandidate(path: folder + "/" + $0.name + ".jpg", captureDate: $0.captureDate,
                            pixelSize: $0.pixelSize, kind: .jpeg)
        }
        return FolderScan(candidates: candidates, failures: [])
    }

    public func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .notAnImage(path))
        guard let photo = photos.first(where: { $0.path == path || $0.id == path }),
              let image = FakeBehavior.gradient(for: photo, longSide: maxLongSide)
        else { throw LibraryError.missingFile(path) }
        return image
    }
}

public actor FakeJPEGWriter: JPEGWriting {
    let mode: FakeMode
    /// Written files by "folder/name", for tests.
    public private(set) var files: [String: DisplayImage] = [:]
    public init(mode: FakeMode = .ok) { self.mode = mode }

    public func existingNames(in folder: String) async throws -> Set<String> {
        Set(files.keys.filter { $0.hasPrefix(folder + "/") }.map { String($0.dropFirst(folder.count + 1)) })
    }

    public func write(_ image: DisplayImage, quality: Int, folder: String, fileName: String) async throws {
        let key = folder + "/" + fileName
        try await FakeBehavior.perform(mode, failing: .writeFailed(path: key, reason: "The folder is read-only."))
        guard files[key] == nil else { throw LibraryError.writeFailed(path: key, reason: "The file already exists.") }
        files[key] = image
    }
}

public actor FakeCatalogStore: CatalogStoring {
    let mode: FakeMode
    public private(set) var data: Data?
    public private(set) var setAsideCount = 0
    public init(data: Data? = nil, mode: FakeMode = .ok) {
        self.data = data; self.mode = mode
    }
    public func read() async throws -> Data? { data }
    public func write(_ data: Data) async throws {
        try await FakeBehavior.perform(mode, failing: .writeFailed(path: "catalog.json", reason: "The disk is full."))
        self.data = data
    }
    public func setAside() async throws -> String {
        data = nil
        setAsideCount += 1
        return "catalog.json.bad"
    }
}
```

```swift
// Fakes/FakeUseCases.swift: fakes of the use-case contracts. Each does the
// simplest honest thing (import returns the fixture, thumbnails and the
// loupe are gradients, develop changes nothing, crop centers the aspect,
// export plans by the same naming rule in a few lines) and obeys
// `-LibraryFakeMode`, so the UI track can show every state.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreRaster

public struct FakeImporter: PhotoImporting {
    let photos: [PhotoItem]
    let mode: FakeMode
    public init(photos: [PhotoItem], mode: FakeMode = .ok) {
        self.photos = photos; self.mode = mode
    }
    public func importFolder(_ folder: String, known: Set<String>,
                             progress: @escaping @Sendable (ImportProgress) -> Void,
                             added: @escaping @Sendable ([PhotoItem]) -> Void) async throws -> ImportResult {
        try await FakeBehavior.perform(mode, failing: .unreadableFolder(folder))
        let fresh = photos.filter { !known.contains($0.id) }
        for index in fresh.indices {
            progress(ImportProgress(done: index, total: fresh.count))
            added([fresh[index]])
        }
        return ImportResult(added: fresh, alreadyKnown: photos.count - fresh.count, failures: [])
    }
}

public struct FakeThumbnails: ThumbnailProviding {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .notAnImage(photo.id))
        guard let image = FakeBehavior.gradient(for: FakeBehavior.cropShaped(photo, photo.develop.crop),
                                                longSide: longSide) else {
            throw LibraryError.notAnImage(photo.id)
        }
        return image
    }
    public func invalidate(_ id: String) async {}
}

/// Applies changes like the live one; Auto Advance is the plain rule (the
/// next id in `before`, staying on the last) without the filter case.
public struct FakeCulling: PhotoCulling {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem] {
        if mode == .fail { throw LibraryError.invalid("Rating is unavailable in this preview.") }
        if case .rating(let stars) = change, !(0...5).contains(stars) {
            throw LibraryError.invalid("A rating is 0 to 5 stars.")
        }
        return items.map { item in
            guard ids.contains(item.id) else { return item }
            var copy = item
            switch change {
            case .rating(let stars): copy.rating = stars
            case .flag(let flag): copy.flag = flag
            case .label(let label): copy.label = label
            }
            return copy
        }
    }
    public func advance(from id: String, before: [String], after: [String]) -> String? {
        guard let index = before.firstIndex(of: id) else { return after.first }
        return index + 1 < before.count ? before[index + 1] : id
    }
}

/// Stores ids and ratings only, as text: enough to drive the restore journey on fakes.
public struct FakeCatalogCoding: CatalogCoding {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func encode(_ photos: [PhotoItem]) throws -> Data {
        Data(photos.map { "\($0.id)\t\($0.rating)" }.joined(separator: "\n").utf8)
    }
    public func decode(_ data: Data) throws -> [PhotoItem] {
        if mode == .fail { throw LibraryError.damagedCatalog("fake") }
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        return try lines.map { line in
            let fields = line.split(separator: "\t")
            guard fields.count == 2, let rating = Int(fields[1]) else { throw LibraryError.damagedCatalog("fake") }
            return PhotoItem(id: String(fields[0]), name: String(fields[0]), captureDate: Date(timeIntervalSince1970: 0),
                             color: .init(0.5, 0.5, 0.5), rating: rating)
        }
    }
}

public struct FakeLoupe: LoupeImaging {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func render(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                       quality: RenderQuality) async throws -> RenderedPhoto {
        try await FakeBehavior.perform(mode, failing: .renderFailed("the preview failed on purpose"))
        guard let base = FakeBehavior.gradient(for: FakeBehavior.cropShaped(photo, settings.crop),
                                               longSide: quality == .preview ? 512 : longSide) else {
            throw LibraryError.renderFailed("empty photo")
        }
        // Not the develop math: a visible stand-in so the UI track sees every
        // slider move. Each step of any slider (0.01 EV, or 1) lifts by one
        // byte level, clamped to the byte range.
        let steps = DevelopSlider.allCases.map { settings.value($0) / $0.step }.reduce(0, +)
        let lift = Int(min(max(steps, -255), 255).rounded())
        var bytes = base.rgba8
        var red = [Int](repeating: 0, count: HistogramBins.binCount), green = red, blue = red
        for i in stride(from: 0, to: bytes.count, by: 4) {
            for c in 0..<3 { bytes[i + c] = UInt8(min(max(Int(bytes[i + c]) + lift, 0), 255)) }
            red[Int(bytes[i])] += 1; green[Int(bytes[i + 1])] += 1; blue[Int(bytes[i + 2])] += 1
        }
        guard let image = DisplayImage(size: base.size, rgba8: bytes) else { throw LibraryError.renderFailed("size") }
        let histogram = HistogramBins(red: red, green: green, blue: blue, shadowClipped: 0, highlightClipped: 0)
        return RenderedPhoto(image: image, histogram: histogram, quality: quality)
    }
    public func prefetch(_ photos: [PhotoItem], longSide: Int) async {}
}

/// Returns the buffer unchanged and an empty histogram.
public struct FakeDevelop: DevelopRendering {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        if mode == .fail { throw LibraryError.renderFailed("the preview failed on purpose") }
        return buffer
    }
    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins { .empty }
}

/// Takes no `FakeMode` (pure geometry, nothing to fail). Centers the aspect
/// on the photo; an angle shrinks the rect by
/// cos + sin of it (a stand-in for `straightenCrop`); handle drags move the
/// matching edges by the drag, clamped to the photo, ignoring the aspect.
public struct FakeCrop: CropGeometry {
    public init() {}
    public func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings {
        var rect = UnitRect.full
        if let ratio = aspect.ratio(for: photo), photo.height > 0 {
            let photoRatio = Double(photo.width) / Double(photo.height)
            if ratio < photoRatio { rect.width = ratio / photoRatio } else { rect.height = photoRatio / ratio }
            rect.x = (1 - rect.width) / 2
            rect.y = (1 - rect.height) / 2
        }
        return CropSettings(angle: min(max(angle, -45), 45), rect: rect, aspect: aspect)
    }
    public func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                        photo: PixelSize) throws -> CropSettings {
        guard photo.width > 0, photo.height > 0 else { return crop }
        let ux = dx / Double(photo.width), uy = dy / Double(photo.height)
        var r = crop.rect
        switch handle {
        case .inside: r.x += ux; r.y += uy
        case .left, .topLeft, .bottomLeft: r.x += ux; r.width -= ux
        case .right, .topRight, .bottomRight: r.width += ux
        case .top, .bottom: break
        }
        switch handle {
        case .top, .topLeft, .topRight: r.y += uy; r.height -= uy
        case .bottom, .bottomLeft, .bottomRight: r.height += uy
        default: break
        }
        r.width = min(max(r.width, 0.01), 1); r.height = min(max(r.height, 0.01), 1)
        r.x = min(max(r.x, 0), 1 - r.width); r.y = min(max(r.y, 0), 1 - r.height)
        return CropSettings(angle: crop.angle, rect: r, aspect: crop.aspect)
    }
    public func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings {
        let a = min(max(angle, -45), 45), radians = abs(a) * Double.pi / 180
        let shrink = 1 / (cos(radians) + sin(radians))
        var r = crop.rect
        let w = r.width * shrink, h = r.height * shrink
        r.x += (r.width - w) / 2; r.y += (r.height - h) / 2; r.width = w; r.height = h
        return CropSettings(angle: a, rect: r, aspect: crop.aspect)
    }
    public func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect {
        PixelRect(x: Int(crop.rect.x * Double(photo.width)), y: Int(crop.rect.y * Double(photo.height)),
                  width: max(Int(crop.rect.width * Double(photo.width)), 1),
                  height: max(Int(crop.rect.height * Double(photo.height)), 1))
    }
}

public struct FakeExporter: PhotoExporting {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        var taken = existingNames
        let items = photos.map { photo -> ExportPlan.Item in
            var name = photo.name + ".jpg", n = 2
            while taken.contains(name) { name = photo.name + " \(n).jpg"; n += 1 }
            taken.insert(name)
            let size = options.longEdge.map { photo.pixelSize.fitting(longSide: $0) } ?? photo.pixelSize
            return ExportPlan.Item(photoID: photo.id, fileName: name, size: size)
        }
        return ExportPlan(items: items, options: options)
    }
    public func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .renderFailed("the preview failed on purpose"))
        guard let image = FakeBehavior.gradient(for: photo, longSide: item.size.longSide) else {
            throw LibraryError.renderFailed("empty photo")
        }
        return image
    }
}
```

</details>

### 5.5 `PhotoItem` grows four fields (spine)

The checked version is `docs/blueprints/library/contracts/PhotoItem.swift`.
Added, each with a default in the existing initializer so every current
caller and test still compiles:

```swift
public let path: String?                              // nil for a sample; equal to `id` when imported
public let pixelSize: PixelSize                       // after Exif orientation; samples 4032 × 3024
public internal(set) var develop: DevelopSettings     // neutral until developed
public internal(set) var availability: PhotoAvailability  // .available, .missing, .unreadable(reason)
```

`LibraryCatalog.loupeArtboard` goes away (loupe-viewport removes it): the loupe reads the photo's own
`pixelSize` (#724's "real photo size").

### 5.6 `LibraryCatalog`: every stored property, declared once (spine)

The spine adds all of these in one PR, so no feature edits
`LibraryCatalog.swift` afterwards. Stored state becomes
`public internal(set)` (Flare's LM-0a3 rule): extension files in the Model
can write it, `LibraryApp` (another module) still cannot, so the app-state
rule and the compiler still hold. This is a deliberate exception to
CLAUDE.md's `public private(set)`, recorded as decision D6.

| Stored property | Read by | Written by (file, feature) |
|---|---|---|
| `services: LibraryServices` | every extension | `init(services:)` (spine) |
| `history: CatalogHistory` | Edit menu | `CatalogHistory.swift` (spine) |
| `order: [String]` (the shown ids in sort order, cached) | grid, loupe, status | `LibraryOrder.swift` (spine): rebuilt on load, sort, collection, and any change that can reorder or hide |
| `importState: ImportState` (`.idle`, `.running(ImportProgress)`), `importNotice: ImportNotice?` (5.2) | progress row, notice | `LibraryImport.swift` (import) |
| `thumbnails: [String: DisplayImage]` (at most 128 MB, evicted by `requestThumbnails`), `thumbnailLongSide: Int`, `pendingThumbnails: [String: ThumbnailRequest]` | grid cells | `LibraryThumbnails.swift` (thumbnails) |
| `autoAdvance: Bool` | Metadata menu | `LibraryCulling.swift` (cull) |
| `loupeZoom: LoupeZoom` (`.fit`, `.actual`, `.scale(Double)`), `loupeRender: RenderedPhoto?`, `loupeRenderToken: Int`, `loupeError: String?` | loupe, status pills, histogram | `LoupeZoom.swift`, `LibraryLoupeImage.swift` (loupe-viewport) |
| `copiedSettings: DevelopSettings?` | Photo menu | `LibraryDevelop.swift` (develop) |
| `cropDraft: CropSettings?` (non-nil while cropping) | crop overlay, Photo menu | `LibraryCrop.swift` (crop) |
| `exportState: ExportState` (`.idle`, `.editing(ExportOptions)`, `.running(done: Int, total: Int)`, `.finished(ExportSummary)`) | export sheet | `LibraryExport.swift` (export) |
| `catalogState: CatalogFileState` (5.2), `saveRevision: Int`, `savedRevision: Int`, `saveError: String?` | launch, notice | `LibraryPersistence.swift` (persist) |

`ImportState`, `LoupeZoom` and `ExportState` are declared by the spine in
`LibraryCatalog.swift` next to the properties, with only the cases listed,
so features add behavior, never cases. `ImportNotice`, `ExportSummary` and
`CatalogFileState`, with every field and their `message` text, are
contracts (5.2), Linux-tested by the smoke tests.

**Equatable.** `LibraryCatalog` is `Equatable` today and tests compare
whole catalogs (`LibraryCellSizeFuzzTests.swift:59`,
`LibraryCollectionEmptinessTests.swift:104`). `LibraryServices` holds
existentials, so the spine writes `==` by hand over every stored property
except `services`, as `FlareWorkspace` does (`FlareWorkspace.swift`), and
its test proves two catalogs that differ only in services are equal.

### 5.7 The catalog methods each journey calls

Views call only these (and the existing ones). Each mutating method runs
on the main actor, never awaits, and is Linux-tested. An `async` service
call happens in the area file (`LibraryWindow+<Area>.swift`), which then
calls the matching `finish…`/`show…` method with the request's token.

| Journey step | Method (file, feature) | Undo step |
|---|---|---|
| J1 Import Folder… | `beginImport(_ folder: String) -> Set<String>?` (known ids; nil while one runs) · `showImportProgress(_:)` · `appendImported(_ photos: [PhotoItem])` (each batch from `added`; ids already present are ignored) · `finishImport(_ result: ImportResult)` · `failImport(_ error: LibraryError)` · `dismissImportNotice()` (`LibraryImport.swift`, import) | none: import is not undoable in v1 (decision D4) |
| J2 thumbnails | `thumbnailLongSide(forCell:scale:) -> Int` (`ThumbnailBucket`: 128, 256, 512, 1024) · `requestThumbnails(visible: [String]) -> [ThumbnailRequest]` (id, long side, and the photo's `develop` revision as a token; it also evicts held images outside the visible ids plus two screens of margin, keeping `thumbnails` under 128 MB) · `setThumbnail(_ image: DisplayImage, for request: ThumbnailRequest)` (dropped when the token is stale: the photo's settings changed after the request) · `failThumbnail(_ request: ThumbnailRequest, _ error: LibraryError)` (`LibraryThumbnails.swift`, thumbnails) | none |
| J2 sort, sizes, selection | existing `setSort`, `stepCellSize`, `select` (spine moves them onto `order`) | none |
| J3 loupe step and zoom | existing `open`, `showLoupe`, `stepLoupe`, `showGrid`, plus `zoomLoupe(_ zoom: LoupeZoom)`, `stepZoom(by:)`, `loupeRequest() -> LoupeRequest?` (photo, settings, long side, token) · `showLoupeRender(_:token:)` · `failLoupeRender(_:token:)` · `neighboursToPrefetch() -> [PhotoItem]` · `showFirstInLoupe()`, `showLastInLoupe()` (Home, End) · `panLoupe(dx:dy:)` (the Space-drag math, Model-tested) (`LoupeZoom.swift`, `LibraryLoupeImage.swift`, loupe-viewport) | none |
| J4 keys | `cull(_ change: CullChange)` (applies to the loupe photo, else the selection; Auto Advance when it applies) · `cullKey(_ key: Character) -> CullChange?` (`0`–`5`, `p`, `x`, `u`) · `setAutoAdvance(_:)` (`LibraryCulling.swift`, cull). The existing `setRating`, `setFlag`, `setLabel`, `clickStar` call `cull` | "Set Rating", "Pick", "Reject", "Clear Flag", "Set Label" |
| J4–J7 undo | `undo()`, `redo()`, `undoTitle: String?`, `redoTitle: String?` (`CatalogHistory.swift`, spine) | n/a |
| J5 develop | `setDevelop(_ slider: DevelopSlider, to value: Double, coalesceKey: String?)` · `endDevelopDrag()` · `resetDevelop(_ group: DevelopGroup?)` (nil: all; a per-row reset waits on S-L6 and adds `resetDevelop(_ slider:)`) · `copySettings()` · `pasteSettings()` (to the selection or the loupe photo) · `developError: String?` from `loupeError` (`LibraryDevelop.swift`, develop) | "<Slider>" coalesced per drag, "Reset Tone", "Reset Color", "Reset Develop", "Paste Settings" |
| J6 crop | `beginCrop()` · `setCropAspect(_:)` · `dragCrop(_ handle: CropHandle, dx: Double, dy: Double)` · `setCropAngle(_:)` · `applyCrop()` · `cancelCrop()` · `resetCrop()` (`LibraryCrop.swift`, crop) | "Crop" on apply, "Reset Crop"; drags and cancel record nothing |
| J7 export | `beginExport() -> Bool` (false with nothing to export) · `setExportOptions(_:)` · `exportPlan(existingNames:) -> ExportPlan` · `showExportProgress(done:total:)` · `finishExport(_ summary: ExportSummary)` · `cancelExport()` · `retryExport() -> Bool` (re-plans `failedIDs`) · `closeExport()` (`LibraryExport.swift`, export) | none |
| J8, J9 persist | `restore(_ photos: [PhotoItem])` · `failRestore(_ error: LibraryError)` · `saveRequest() -> (revision: Int, photos: [PhotoItem])?` (nil when saved) · `didSave(revision:)` · `failSave(_:)` (`LibraryPersistence.swift`, persist) | none |
| J0, every area | `help(for member: String) -> String?` (the `unavailable` reason, for disabled controls) · `controlsJSON: String` (J11's `library.controls`) (spine) | n/a |
| J2–J8 values | `PhotoItem.cullSummary`, `cellValue(for id:) -> String` (load state, shown pixel size, cull summary), `loupeValue: String?` (quality, rendered pixel size, checksum under `-LibraryTestValues`, zoom percent, cull summary), `histogramValue: String` (`mean 0.4213`) (spine declares them; thumbnails, loupe-viewport and develop fill their parts) | n/a |
| J5–J9 relaunch | `catalogValue: String` (`saved` or `dirty`, the `library.catalog` value) (`LibraryPersistence.swift`, persist; the spine declares it as always `saved`) | n/a |
| J1, J8 setup | `importOnLaunch: Bool` from `-LibraryImportOnLaunch` with `importFolder: String?` from `-LibraryImportFolder` (`LibraryLaunch.swift`, spine) | n/a |

Checklist:

- [x] One protocol per use case, with exact signatures, in a file that
      compiles on Linux (`check.sh`, run on 2026-10-14).
- [x] Every protocol has a fake, and the smoke tests call every one.
- [x] Every journey step in section 4 maps to a method in 5.7 or a menu
      item in 6.2, and every method names the file and feature that owns it.

---

## 6. Look

Library uses the suite look as it is: `docs/design.md` (Component order,
Visual language, Pro density, Studio rows and chips, Window structure).
The house reference for every inspector control is Flare's easing editor
(`docs/blueprints/flare-easing-editor.md`): filled 28 pt bar rows
(`StudioScrubRow` / `InspectorSliderRow`), 24 pt `ChoiceChips`, uppercase
group headers, accent only for selected or active, flat, never glass. This
section lists only what Library adds, then each screen and its parts.

### 6.1 What Library adds to docs/design.md

These are Library rules; the feature that first builds each one moves its
row into `docs/design.md` (under a new "Catalog apps (Library)" section)
in the same PR.

| Rule | Value | Why |
|---|---|---|
| Window | `SuiteWindow` (sidebar, content, inspector), following the system appearance; one `Window` scene, not `WindowGroup` (decision D2) | Library is a browser of many documents, not a canvas editor, so it keeps the system window; one catalog means one window |
| Loupe surround | `SuiteColor.canvasSurround` (a neutral grey that follows the appearance: dark in Dark, light grey in Light), never the window background; the loupe already uses it | A photo is judged against neutral grey, not white or black |
| Thumbnails | Aspect-fit inside the cell (`ThumbnailGrid`), never cropped to fill; the cell is `cellSize` wide and 3/4 of it tall; the cell background is `SuiteColor.canvasSurround`; the image's bucket covers the cell at the display scale (`ThumbnailBucket`, up to 1024 px for a 320 pt cell at 2x) | Culling judges the whole frame, sharp |
| Cull marks | Rating: stars badge. Pick: `flag.fill` badge. Reject: the cell's image at 40% and an `xmark.circle` badge, label "Rejected" | State colors are never the only cue (design.md, State colors) |
| Unreadable photo | Placeholder cell with `exclamationmark.triangle` in `stateWarning` and the reason as help | An error appears where it happened |
| Develop rows | `InspectorSliderRow` (the bar slider `StudioScrubRow` wraps), Exposure with `decimals: 2` and unit "EV", the others `decimals: 0`; each section's Reset icon (`InspectorSection(onReset:)`) resets its group (TONE or COLOR) and shows only while one of its sliders is off 0; a per-row reset needs S-L6 | Same look as Flare's easing rows; whole numbers read faster |
| Histogram | 120 pt tall well, `SuiteRadius.medium`, three channel areas at 40% (red, green, blue through the system colors) with their sum in `.primary` at 20%, clipping triangles top-left (shadows) and top-right (highlights) in `stateWarning` when any pixel clips, each labelled ("Shadows clipped", "Highlights clipped") | The only colored chrome is data |
| Crop mode | `CropShade` outside the frame, `SelectionOutline` on it, a thirds grid at 0.5 pt `.primary` 40% while dragging, eight handles at 10 pt with 28 pt hit targets (the curve-handle sizes) | Same handle anatomy as the curve editor |
| Progress | Import and export show a progress row in the content (import) or the sheet (export) within 100 ms (QB-L9), with a Cancel for export; never a modal spinner | design.md, Motion: never block input |
| Notices | Import results and catalog problems show as an inline notice at the top of the content: symbol and state color, one sentence, at most one action (Show, Show in Finder, Try Again); dismissible | Errors appear near the problem and never as an alert at launch |

### 6.2 Screens and their components

Components are SuiteUI unless named `Library*`. **needs-ui** marks a part
SuiteUI does not have; section 6.4 lists them as issues to file.

| Screen | Region | Contents | Components |
|---|---|---|---|
| Main window, grid | Sidebar | Library section: All Photos, Favorites, Recently Added with counts | `SuiteWindow`, `SidebarItem` / `SidebarRow` |
| | Content | Notice (import result, catalog problem); import progress row; the grid; status pills under it | **needs-ui** `InlineNotice`; **needs-ui** `ProgressRow`; `ThumbnailGrid` (**needs-ui**: visible ids, per-cell loading state and identifier, reject and unreadable badges); `ViewerStatusBar(zoom:size:trailing:)` with its trailing pills ("3 selected"); **needs-ui** S-L7 to make the zoom and size pills optional, so the grid shows "24 photos" and the thumbnail size instead of a zoom percent |
| | Inspector | Tabs Info and Develop; Info: `InspectorHeader` (name or "3 Photos", facts: date, size, file kind), Metadata section (existing) | `SegmentedTabs`, `InspectorHeader`, `InspectorSection`, `InspectorRow`, `InspectorPickerRow`; with nothing selected, the collection's `InspectorHeader` and "N photos" (replacing today's `SurfaceCard`, which design.md keeps out of inspectors) |
| Main window, empty | Content | "No Photos", Import Folder… as the one prominent button; Load Sample Photos stays in File | `EmptyStateView` |
| Loupe | Content | The photo on `CanvasViewport` (no checkerboard) at fit, 100% or a step; Space-drag, scroll or arrows pan when zoomed (a plain drag reaches the host as `onDrag`: unused in the loupe, the crop frame in crop mode); readout "IMG_0003 · 3 of 24" | `CanvasViewport`, `GlassPanel`; `ViewerStatusBar(zoom:size:trailing:)` (zoom percent from `ViewerZoom`, pixel size, "3 of 24" as a trailing pill) |
| Develop tab | Inspector | Histogram; TONE section: Exposure, Contrast, Highlights, Shadows; COLOR section: Temperature, Tint; Reset All; with several photos selected, "Mixed" where they differ (the bar's `mixed:`) | **needs-ui** `HistogramView`; `InspectorSection` (Reset icon), `InspectorSliderRow`, `InspectorAction` |
| Crop mode | Content and inspector (`CropInspector`, shown in the Develop tab while cropping) | The frame over the photo; CROP section: aspect `ChoiceChips` (Original, Free, 1:1 / 4:5, 3:2, 16:9: three columns, two rows), Straighten row (−45 to 45, `decimals: 1`, unit °), Apply (primary) and Cancel; Reset Crop | `CropShade`, `SelectionOutline`, **needs-ui** `CropHandles` (eight handles and the thirds grid, keyboard nudge), `ChoiceChips`, `InspectorSliderRow`, `InspectorAction` |
| Export sheet | Sheet | "Export 3 Photos"; Size `ChoiceChips` (1024, 2048, 4096 / Original) plus a Long Edge `ScrubField` in px; Quality bar 0–100; Folder row with Choose…; Export (primary), Cancel; while running: progress row and Cancel; done: success row with Show in Finder; failures: list of name and reason, Try Again | `Form` in a `.sheet`, `ChoiceChips`, `ScrubField`, `InspectorSliderRow`, **needs-ui** `ProgressRow`, `InspectorAction` |
| Menu bar | | below | `LibraryCommands` |

**Menu bar** (spine writes every item; areas fill the actions; an item that
can't act yet is disabled by a nil action):

- **Library**: About, Hide, Quit (no Settings window in v1).
- **File**: Import Folder… ⇧⌘I, Load Sample Photos, Export… ⇧⌘E, Close ⌘W.
- **Edit**: Undo <step> ⌘Z, Redo <step> ⇧⌘Z, Select All ⌘A, Deselect ⇧⌘A.
- **View**: Grid, Loupe, Zoom In ⌘+ (in the grid: Larger
  Thumbnails), Zoom Out ⌘− (Smaller Thumbnails), Zoom to Fit ⌘0, Actual Size
  ⌘1, Sort By ▸ (Capture Date, Name, Rating), Show Inspector ⌥⌘I. A menu item
  whose title changes with the mode is allowed by the HIG; the shortcut
  stays on one item.
- **Photo**: Copy Settings ⇧⌘C, Paste Settings ⇧⌘V, Reset Develop, Crop
  (a toggle: "Done Cropping" while cropping), Reset Crop.
- **Metadata**: Set Rating ▸ (No Stars, 1 Star … 5 Stars), Set Flag ▸
  (Pick, Reject, Clear Flag), Set Label ▸ (None, Red … Purple), Auto
  Advance (a checkmark).
- **Window**, **Help**: system.

**Single keys.** 0–5, P, X, U, R, G, Return, Home and End act only while the grid or
loupe has focus, through the window's `onKeyPress`, never while a field is
being typed in. Their menu items carry no key equivalent (an unmodified
equivalent could fire while a text field has focus); each item's title is
followed by its key in its help tag ("Pick (P)"). Q5 asks the captain to
confirm. Only the items listed above are the app's; J10 counts those, not
the items SwiftUI and the system add (Services, Hide Others, dictation and
the like).

### 6.3 Snapshots each feature adds

Every new visible state gets a snapshot in its own file in
`Tests/AppSnapshotTests/`, named `library-<state>-<appearance>.png`: Light
and Dark today, and all four appearances the rubric's QB-V5 names for a
`SuiteWindow` app (Light, Dark, and each with Increase Contrast) once QH-2b
(#332) lands; once QH-2 (#331) lands each is also a golden with the
rubric's tolerance.

| Feature | Snapshot states |
|---|---|
| spine | `library-preview-data` (the "Preview data" pill while services are fakes, drawn by the spine as a `ViewerStatusBar` trailing warning pill until status-and-layout's bar takes it over), `library-empty-import` (with Import Folder…; `library-empty` stays the existing shot in `AppSnapshotTests.swift`, which no Library feature edits), `library-inspector-none`, `library-notice-damaged`, `library-notice-newer` |
| import | `library-importing` (progress row), `library-imported`, `library-import-failures`, `library-import-nothing-new`, `library-import-denied` |
| thumbnails | `library-grid-thumbnails`, `library-grid-loading`, `library-grid-unreadable` |
| cull | `library-rated` (stars, pick, reject dimmed) |
| loupe-viewport | `library-loupe-fit`, `library-loupe-preview`, `library-loupe-100`, `library-loupe-100-panned` |
| persist | `library-restored` |
| develop | `library-develop`, `library-develop-render`, `library-develop-mixed`, `library-develop-error` |
| crop | `library-crop`, `library-crop-straightened` |
| export | `library-export`, `library-exporting`, `library-export-failed`, `library-export-done`, `library-export-cancelled` |
| status-and-layout | `library-grid-status`, `library-inspector` (#185) |

### 6.4 SuiteUI parts Library needs (to file as `needs-ui`, `line:suiteui`)

Not filed by this blueprint (the captain approves first); each gets its
issue when the blueprint merges.

| Id | Part | What Library needs | Needed by |
|---|---|---|---|
| S-L1 | `HistogramView` | Draws three channel arrays of bin heights (0...1) and two clipping flags with labels, 120 pt tall, in a well; accessibility value a short summary ("Mean 0.42, highlights clipped") | develop |
| S-L2 | `ThumbnailGrid` additions | `onVisibleChange([ID])` as cells appear and disappear; a per-cell accessibility value and help from the app; a per-cell identifier from an id prefix; a `dimmed` badge state for rejects; aspect-fit inside the cell | thumbnails, cull; a hard wait for journey steps that read cell values (they read the loupe value until it lands) |
| S-L3 | `CropHandles` | Eight handles and an inside drag over a rect at a zoom, reporting `(handle, dx, dy)` in document pixels; thirds grid while dragging; arrow keys nudge the focused handle (Shift 10) | crop |
| S-L4 | `InlineNotice` | Symbol, state color, one sentence, one optional action, a close button; content layer, flat | import, persist, export |
| S-L5 | `ProgressRow` | "Importing 3 of 27" text, a determinate bar, an optional Cancel; shows only after 100 ms | import, export |
| S-L6 | Row reset on `InspectorSliderRow` | An optional `onReset` drawing a small reset button inside the row while the value is off its default | develop (per-row reset; until then the section reset) |
| S-L7 | Optional zoom and size pills | `ViewerStatusBar` already takes trailing pills; it needs its zoom and size pills to be optional, so the grid row reads "24 photos · 3 selected · 160 pt" | status-and-layout |
| S-L8 | Named probe marks | `FrameProbe.mark(_ name: String)` for app marks (`thumb-ready`, `render-preview`, `render-full`, `launch-grid`), in the same JSON as #330's fixed marks; a comment on #330 or its own issue | every perf journey |
| existing | #330 FrameProbe, #331 and #332 goldens, #333 journey files and velocity drags | as in Flare | perf journeys, goldens, journey files |

Until a part lands, the feature uses a plain SwiftUI placeholder (CLAUDE.md)
and keeps going; the journey asserts behavior, not the part's look.

Checklist:

- [x] Every screen lists the SuiteUI component of each region, or names
      the needs-ui part and its id.
- [x] Every new rule says why, and which feature moves it into
      `docs/design.md`.
- [x] Every visible state in section 4 has a snapshot in 6.3.

---

## 7. Quality bar

Every item here is a number with a test that measures it, on CI or
locally. Three harnesses do the measuring, all named in rubric section 6:

- **Probe** (macOS, perf journeys): SuiteUI's `FrameProbe` (#330) under
  `-LibraryPerfProbe`, read by `perf()` (#333), attached as
  `perf-<test>.json`. Frames late = display refreshes between the input
  event and the first frame that shows it. Marks Library adds: `progress`
  (import or export progress row first drawn), `thumb-ready` (a cell's
  image first drawn), `render-preview` and `render-full` (a loupe picture of
  a given token first drawn), `launch-grid` (first grid frame after launch).
- **Model budget** (Linux and macOS, `swift test`): one file per feature,
  `Tests/LibraryModelTests/Library<Area>BudgetTests.swift`, over the
  spine's helper `Budget.swift` (same folder, the rubric's name): wall time over 20 runs
  on the `large` fixture or a named buffer, median and p95, printed as one
  `LIBRARY-BUDGET` line per row and written to
  `.build/snapshots/library-budget-<area>.txt`, so the contact sheet shows
  them.
  CI runs debug; the debug gate is the release target × 10 (rubric) for
  rows without pixel loops. Rows that run CoreRaster pixel loops (preview,
  full render, histogram, thumbnail, export) are **report-only in debug**,
  as Photo's `PhotoBrushLatencyTests` does for the same reason (debug pixel
  loops run about 20× slower, and creative-core #266 measured contrast at
  about 9 s in debug on 24 MP), and gate in release:
  `swift test -c release --filter Budget` locally, which each pixel feature's
  packet runs and records in its PR (decision D8).
- **Fidelity** (Linux for pixels the Model makes; macOS for ImageIO):
  exact or toleranced comparisons against a reference, listed in 7.4.

Per rubric section 6, every probe row ships **report-only** (asserts only
that it collected at least 60 samples) and gets its CI gate after ten green
CI runs (measured p95 × 1.5, never tighter than the target), written in
`UITests/Journey+Budgets.swift`. Model budgets gate from their first PR.

### 7.1 Input-to-screen budgets, per interactive tool

| id | Interaction | Target (device, release) | Measured by | Model half (release; debug gate) |
|---|---|---|---|---|
| QB-LIB-3 | Scroll the grid of a 10,000-photo catalog end to end | p95 frame interval ≤ 1.5 refreshes; every visible cell `thumb-ready` within 500 ms of stopping | P1 probe | rebuilding `order` for 10,000 ≤ 5 ms (50 ms); `requestThumbnails` for 60 visible ≤ 0.5 ms (5 ms) |
| QB-LIB-4 | Rating, flag or label key in the grid; click to select | p95 ≤ 2 frames late to the badge or selection drawn | P2 probe | `cull` on one photo of 10,000 ≤ 1 ms (10 ms); it rebuilds `order` only when the sort or collection depends on the change |
| QB-LIB-5 | Left or Right in the loupe (and Auto Advance) | the next photo's preview (its thumbnail, scaled) on screen p95 ≤ 2 frames late; `render-full` p95 ≤ 150 ms after the key when the neighbour was prefetched | P4, P2 probe | `stepLoupe` ≤ 0.1 ms (1 ms) with `order` cached |
| QB-L1 | Pan the zoomed loupe; drag a crop handle | p95 ≤ 2 frames late | P4 (pan series), P5 probe | `dragCrop` ≤ 0.2 ms (2 ms) |
| QB-L2 | Drag a develop slider: the bar's marker | p95 ≤ 2 frames late | P3 probe | `setDevelop` ≤ 0.1 ms (1 ms) |
| QB-LIB-6 | Drag a develop slider: the loupe picture follows | p95 ≤ 100 ms from a slider event to a `render-preview` at least that new; `render-full` ≤ 400 ms after mouse-up for a 6000 × 4000 photo | P3 probe | release only (debug reports): preview render (512 px long side, all six sliders) ≤ 8 ms; full render (2048 px) ≤ 120 ms; histogram of 2048 px ≤ 10 ms |
| QB-L9 | Import or export starts | `progress` mark ≤ 100 ms after the command | P6, P8 probe | `beginImport`, `beginExport` ≤ 1 ms (10 ms) |
| QB-LIB-1 | Import 200 JPEGs of 4000 × 3000 | the first batch of cells appears and the first 20 are `thumb-ready` ≤ 2 s after the command (batches come through `added` while the import runs); all records in ≤ 10 s; the main thread never stalls more than 2 refreshes | P6 probe | `finishImport` of 200 into 10,000 ≤ 5 ms (50 ms); planning 10,000 candidates against 10,000 known ≤ 20 ms (200 ms) |
| QB-LIB-2 | Launch on a 10,000-photo catalog | `launch-grid` ≤ 1 s after launch; no main-thread stall over 2 refreshes while the catalog decodes | P7 probe | `LiveCatalogCoding.decode` of 10,000 ≤ 100 ms (1 s); `encode` ≤ 50 ms (500 ms) |
| QB-LIB-7 | Export 10 photos of 6000 × 4000 at long edge 2048 | ≤ 15 s; progress advances after each file | P8 probe (report-only) | `plan` for 1,000 photos ≤ 5 ms (50 ms) |
| QB-LIB-8 | Memory | Peak resident memory ≤ 1.5 GB while scrolling the 10,000 catalog and stepping the loupe through 24 photos | P1 and P4 with `XCTMemoryMetric` | the live thumbnail LRU never holds more than `ThumbnailBucket.cacheBytes` (256 MB) and the catalog's `thumbnails` never more than 128 MB after scrolling all 10,000 (`LibraryThumbnailTests` sums both); the loupe actor holds at most 3 decoded screen-size buffers (`LibraryLoupeImageTests` counts) |

Why the loupe has two numbers: a 6000 × 4000 photo is 384 MB as Float32,
and one CoreRaster adjustment pass over a screen-size copy takes tens of
milliseconds, so no full-size render can follow a drag at 60 Hz. The design
answer (section 2.5, `RenderQueue`) is the Photo rule: render a 512 px
preview while the pointer moves, keep only the latest request, and settle to
the screen-size render on mouse-up. QB-L2 holds the slider itself to the
usual 2 frames; QB-LIB-6 holds the picture to "never more than 100 ms
behind". If the model half misses its budget, the fix is a fused develop
pass in CoreRaster (open question Q3), not a looser budget.

### 7.2 App-audit checks

All six checks in `docs/blueprints/app-audit.md` apply to every Library
screen: `disabled-dim`, `overlap`, `contrast`, `identifier`, `offscreen`,
`unnamed`. The baseline today is contrast 2, identifier 16, offscreen 16,
unnamed 1.

- No Library PR raises a count (the lane refuses it).
- Each feature's journeys must leave its own new screens at zero for every
  check: its packet lists the screens and the contact sheet's audit table
  proves it per run.
- **v1 exit**: every `library` count is 0. Identifier goes to 0 through
  #291 and S-L2's per-cell identifiers; offscreen through the layout
  feature (7.3), unnamed and contrast through the status-and-layout
  feature's fixes.
- No new check is proposed: the audit grows from faults (app-audit.md,
  Growing the audit). If a Library fault slips past all six, its fix PR
  proposes the check.

### 7.3 Layout spec

Checked at the window widths 880 (`SuiteSize.windowMinimum.width`), 1024,
1280, 1440 and 1920, with the inspector at its minimum (200), ideal (240)
and maximum (360) width, in three places:

1. **Model math** (Linux), `Tests/LibraryModelTests/LibraryLayoutTests.swift`
   over `LibraryLayout` (status-and-layout feature): for each width, the
   content width is the window minus the sidebar and inspector; the grid's
   column count is `max(1, ⌊(W − 2·12 + 12) / (cell + 2·xs + 12)⌋)` (the
   `ThumbnailGrid` padding and spacing, `SuiteSpacing.m` = 12) and equals
   SuiteUI's `GridSelection.columns` for the same width (that comparison is
   macOS-only, in `LibraryLayoutSnapshots.swift`), so arrow keys and the
   drawn grid agree; the default cell (160 pt) gives at least 2 columns
   at the content minimum (440 pt); the loupe's fit scale leaves
   `SuiteSize.canvasInset` on the tighter axis.
2. **Journey** J12 `testLayoutAtWidths` (macOS, on the 1024 × 768 runner, so
   widths 880 and 1024 only), launched with `-LibraryWindowSize`: reads XCUI
   frames and asserts, within 0.5 pt: every grid cell in a column shares its
   left edge; gaps between columns are equal; the status pills share one
   baseline row and none is clipped; every inspector row's label left edge
   is equal and every value's right edge is equal; in the loupe at fit the
   photo's left and right margins differ by at most 1 pt, and so do top and
   bottom. The crop chips (J6 step 6) and the export sheet (J7 step 1) are
   checked in their own journeys, since they land in wave 4. The audit's `overlap` and `offscreen` run on every shot.
3. **Snapshots** at 1280, 1440 and 1920
   (`Tests/AppSnapshotTests/LibraryLayoutSnapshots.swift`,
   `library-layout-<width>-<light|dark>.png`), for the widths the runner
   display can't show; goldens once #331 lands.

### 7.4 Fidelity tests (output equals a reference)

| id | Check | Reference and tolerance | Test (target) |
|---|---|---|---|
| QB-LIB-V1 | Neutral settings change nothing | the input buffer, bit for bit; `render` returns without touching a pixel (counted) | `LibraryDevelopRenderTests` (Linux) |
| QB-LIB-V2 | Develop order and math | the same buffer run through CoreRaster's calls by hand in the order white balance, exposure, contrast, highlights and shadows: bit for bit. Exposure +1 doubles a linear 0.18 grey within 1e-4; temperature +50 makes red above blue on grey and keeps its Rec. 709 luminance within 1e-3 | `LibraryDevelopRenderTests` (Linux) |
| QB-LIB-V3 | Histogram is the picture's | CoreRaster `Histogram(of:bins:256,encoding:.sRGB)` of the rendered buffer, exactly; each channel sums to the pixel count | `LibraryDevelopTests` (Linux) |
| QB-LIB-V4 | Crop size and edges | 600 × 400 at rect width 0.5 renders 300 px wide; 1:1 on 6000 × 4000 is 4000 × 4000; a 10° straighten's crop has alpha 1 in every pixel (no transparent corner) | `LibraryCropTests` (Linux) |
| QB-V4 | What you see is what you export | (a) exact: `LiveExporter.render` equals the same pipeline run by hand (decode at full size, `LiveDevelop.render`, lanczos3 to 1024), bit for bit; (b) WYSIWYG: that export before JPEG vs the loupe's `.full` render at long side 1024 (which develops a screen-size decode, so order differs at edges) within the rubric's QB-V2 tolerance (2/255 per channel, at most 0.5% of pixels over it) plus a mean absolute difference ≤ 1/255; (c) after JPEG at quality 95 and decoding, PSNR ≥ 40 dB against (a) | `LibraryExportFidelityTests` (macOS, `Tests/AppSnapshotTests/`, real `JPEGWriter` and `ImageIODecoder`) |
| QB-LIB-V5 | Thumbnail matches the full picture | the 256 px thumbnail vs the hand-run pipeline (fake decoder at full size, `LiveDevelop.render`, lanczos3 to 256): mean absolute difference ≤ 1/255, max ≤ 8/255; needs no other wave-2 feature | `LibraryThumbnailTests` (Linux, fake decoder giving a fixed gradient) |
| QB-LIB-V6 | Decode orientation and color | a generated JPEG with Exif orientation 6 decodes as portrait, its red marker pixel lands top-left; a Display P3 PNG decodes to sRGB within 2/255 of the expected value | `LibraryDecodeTests` (macOS, `Tests/AppSnapshotTests/`) |
| QB-LIB-V7 | Catalog file round trip | encode → decode → encode is byte-equal; a fixed three-photo catalog encodes byte-equal to the committed `Tests/LibraryModelTests/Golden/catalog-v1.json` (with `develop` and `crop`), and that file without `develop` objects decodes to neutral settings | `LibraryPersistTests` (Linux) |
| QB-V5 | Every new visible state has a golden | the PNGs of 6.3, rubric tolerance (channel 2/255, ≤ 0.5% pixels) | `GoldenImage` once #331 and #332 land; PNGs for eyes until then |

Feel (rubric QB-F1–F6) applies as written: J11 is the no-dead-controls
sweep (QB-F1); J1, J5 and J7 show progress and errors in place (QB-F2);
J4–J6 read the Edit menu after each gesture (QB-F3); J4 and J5 drive
everything from the keyboard once (QB-F4). QB-F5: Library's tinted states
(reject dimming, clipping warnings, notices, progress) get Increase
Contrast goldens with QB-V5's four appearances, and its only animations
(progress, the loupe's preview-to-full swap) record a duration of 0 under
Reduce Motion through the probe, in a journey step launched with
`-LibraryReduceMotion`; each owning feature's packet lists them.

Checklist:

- [x] Every interactive tool (grid scroll and select, cull keys, loupe
      step, pan, crop drag, develop slider, import, export, launch) has a
      budget with a target and the test that measures it.
- [x] Every budget is measurable on CI (probe or model budget) or locally
      (`scripts/ui-test`); none is "feels fast".
- [x] The layout spec names the widths, the tolerance and the test for each.
- [x] Every fidelity test names its reference and tolerance.

---

## 8. Coverage and waves

The data behind this section is `docs/blueprints/library/features/*.wave.json`;
`scripts/waves check library` fails when two features in
one wave own the same file (or one owns a folder or prefix holding the
other's), when a feature depends on one in its own or a later wave, or
when a Sources file is
owned but missing from `c4-planned.json` (or the reverse). It prints
`waves: OK`. The tables below are generated by
`python3 docs/blueprints/library/gen_section8.py`.

### 8.1 Coverage matrix: every open `line:library` issue

| Issue | Title (short) | Tier | Feature | How |
|---|---|---|---|---|
| #31 | Collections and filters | p2 | not v1: filters-collections | not v1 (wave 5) |
| #32 | Develop panel with histogram | p1 | develop | sliders, histogram, copy and paste |
| #33 | Grid thumbnails by resampling | p1 | thumbnails | whole issue |
| #156 | Loupe on a hidden photo after a collection switch | p2 bug | spine | fixed in `LibraryCatalog.swift` by the spine, or by open PR #217 if it merges first |
| #185 | Pro density inspector and status bar | p3 | status-and-layout | status pills and inspector header; pulled into v1 (design.md requires the readout) |
| #210 | Import a folder | p1 | import | whole issue; its `LibraryCommands.swift` edit becomes the spine's File menu item plus `LibraryWindow+Import.swift` |
| #211 | Rate, pick, reject with keys | p1 | cull | keys, Metadata menu, `cull(_:)` on ids, undo (`PhotoFlag` already landed in #750) |
| #212 | Keep the catalog across relaunch | p1 | persist | whole issue; the file also carries `develop` and `crop` from the start |
| #235 | load renames a photo whose id a duplicate took | p2 bug | spine | fixed in `uniquingIDs` by the spine (two passes, as the issue proposes) |
| #291 | 16 controls without identifiers | p3 | status-and-layout | what is left after each feature names its own controls; pulled into v1 (journeys need it) |
| #423 | Render develop settings to pixels | p1 | develop | render in loupe and grid; its catalog-file part is done by persist |
| #424 | Export JPEG at a set size | p1 | export | whole issue |
| #425 | Crop and straighten | p1 | crop | whole issue |
| #426 | Auto-advance | p1 | cull | whole issue |
| #427 | Camera raw files | p2 | not v1: raw | not v1 (wave 5, pending evidence) |
| #724 | Loupe rating keys and zoom | p2 | cull, loupe-viewport | keys → cull; zoom, photo on the artboard, real size → loupe-viewport |
| #744 | Keywords and camera details | p2 | not v1: metadata-more | not v1 (wave 5) |

17 of 17 open issues are mapped. Nothing is dropped: the three "not v1"
issues have a wave-5 feature so their packets can follow v1 directly.

**Issue dependency lines to edit (captain).** The issues were filed as a
chain (#210 after #33, #211 after #210, #212 after #211, #423 after #212).
With the contracts and fakes in the spine, those features no longer wait on
each other: #33, #210, #211, #212 and #724's zoom all run in wave 2. Each
issue's `Depends on` line should read "the spine" (as `docs/priorities.md`
asks: fix the line, don't serialize the work). Their "Files likely
involved" lists are superseded by the owned files below; each packet says so.

### 8.2 Features

| Feature | Wave | What it delivers | Issues | Journeys | Quality ids (section 7) | Depends on (features) |
|---|---|---|---|---|---|---|
| `spine` | 1 | Contracts, fakes, live stubs, catalog state, undo, launch arguments, and the app split into per-feature files | #156, #235 | J0, J10, J11 | QB-F1 (J11), QB-F3 (undo), QB-V5 | – |
| `import` | 2 | Import a folder: scan, metadata, path ids, skip known, progress, failures | #210 | J1, P6 | QB-L9, QB-LIB-1, QB-LIB-V6, QB-F2 | `spine` |
| `thumbnails` | 2 | Real grid thumbnails: buckets, visible requests, LRU, placeholders | #33 | J2, P1 | QB-LIB-3, QB-LIB-8, QB-LIB-V5 | `spine` |
| `cull` | 2 | Cull from the keyboard with undo and Auto Advance, in grid and loupe | #211, #426, #724 | J4, P2 | QB-LIB-4, QB-LIB-5, QB-F3, QB-F4 | `spine` |
| `persist` | 2 | The catalog file: JSON v1 with develop and crop, restore at launch, set aside a damaged file | #212 | J8, J9, P7 | QB-LIB-2, QB-L12, QB-LIB-V7 | `spine` |
| `loupe-viewport` | 2 | Loupe on CanvasViewport: zoom, pan, real photo size, latest-wins render, prefetch | #724 | J3, P4 | QB-LIB-5, QB-L1 (pan), QB-LIB-8 | `spine` |
| `develop` | 3 | Develop sliders, histogram, render to pixels in loupe and grid, copy and paste settings | #32, #423 | J5, P3 | QB-L2, QB-LIB-6, QB-LIB-V1, QB-LIB-V2, QB-LIB-V3, QB-F3 | `spine`, `loupe-viewport`, `thumbnails` |
| `status-and-layout` | 3 | Status pills, inspector header (#185), the remaining identifiers (#291), layout tests | #185, #291 | J12 | layout spec 7.3, audit exit 7.2, QB-V5 | `spine`, `thumbnails`, `loupe-viewport` |
| `crop` | 4 | Crop and straighten in the loupe, applied in render, thumbnail and export | #425 | J6, P5 | QB-L1, QB-LIB-V4, QB-F3, QB-F4 | `develop` |
| `export` | 4 | Export JPEG at a set long edge and quality, never overwriting | #424 | J7, P8 | QB-L9, QB-LIB-7, QB-V4, QB-F2 | `develop`, `import` |
| `filters-collections` | 5 | Filter by flag and rating, collections you make, smart rules (not v1) | #31 | – | later | `cull` |
| `metadata-more` | 5 | Keywords and camera details (not v1) | #744 | – | later | `import` |
| `raw` | 5 | Camera raw files through the system decoder (not v1) | #427 | – | later | `import`, `thumbnails` |

### 8.3 Waves, owned files and what each waits on

A feature may touch only its owned files (paths from the repo root; a path
ending in `/` or `+` covers everything under or starting with it). In one
wave no two features share a file. A later wave may take a file an earlier
wave owned; the note says so.

#### Wave 1: the spine (waits on nothing)

**`spine`** (#156, #235). Contracts, fakes, live stubs, catalog state, undo, launch arguments, and the app split into per-feature files.

- Engine (creative-core): none.
- SuiteUI: none for its own work; the cell values it declares are shown once S-L2 lands (a hard wait for journey steps that read them); #333 for its own journey file (until then it edits LibraryJourneyTests.swift).
- Note: Creates every stub file later features replace; lands as several stacked PRs. Coordinates with open PR #217 (#156). In wave 1 it also adds PhotoItem.cullSummary as the accessibility value of the loupe photo (LibraryLoupe.swift) and the grid cells, and embeds the LibraryCropOverlay and CropInspector stubs, so later features never edit another's view. Existing tests it owns are kept passing (the hand-written == keeps whole-catalog comparisons working). It also presents LibraryExportSheet from LibraryWindow while exportState is not idle, shows the Preview data pill while services are fakes, and switches today's four journeys to -LibraryFixture samples.
- Owned files: `Sources/LibraryModel/LibraryCatalog.swift`, `Sources/LibraryModel/PhotoItem.swift`, `Sources/LibraryModel/LibraryOrder.swift`, `Sources/LibraryModel/CatalogHistory.swift`, `Sources/LibraryModel/LibraryServices.swift`, `Sources/LibraryModel/Contracts/`, `Sources/LibraryModel/Fakes/`, `Sources/LibraryModel/Live/`, `Sources/LibraryModel/LibraryFixtures.swift`, `Sources/LibraryModel/LibraryLaunch.swift`, `Sources/LibraryModel/LibrarySample.swift`, `Sources/LibraryApp/LibraryApp.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `Sources/LibraryApp/LibraryCommands.swift`, `Sources/LibraryApp/LibraryMenus.swift`, `Sources/LibraryApp/LibraryWindow+`, `Sources/LibraryApp/LibraryBrowser.swift`, `Sources/LibraryApp/LibraryGrid.swift`, `Sources/LibraryApp/DisplayImage+Image.swift`, `Sources/LibraryApp/LibraryInspector.swift`, `Sources/LibraryApp/DevelopInspector.swift`, `Sources/LibraryApp/LibraryCropOverlay.swift`, `Sources/LibraryApp/LibraryExportSheet.swift`, `Sources/LibraryApp/LibraryStatusBar.swift`, `Sources/LibraryApp/Platform/`, `Tests/LibraryModelTests/LibraryHistoryTests.swift`, `Tests/LibraryModelTests/LibraryServicesTests.swift`, `Tests/LibraryModelTests/LibraryLaunchTests.swift`, `Tests/LibraryModelTests/LibraryOrderTests.swift`, `Tests/LibraryModelTests/LibraryCatalogTests.swift`, `Tests/LibraryModelTests/LibraryPhotoIDTests.swift`, `Tests/AppSnapshotTests/LibraryShellSnapshots.swift`, `UITests/Journey+Library.swift`, `UITests/LibraryJourneyTests.swift`, `UITests/LibraryJourneyTests+Shell.swift`, `Tests/LibraryModelTests/Budget.swift`, `Sources/LibraryApp/LibraryLoupe.swift`, `Sources/LibraryApp/LibraryControls.swift`, `Sources/LibraryModel/SampleImage.swift`, `Sources/LibraryApp/CropInspector.swift`, `Sources/LibraryModel/LibraryEmptyCollection.swift`, `Tests/LibraryModelTests/LibraryCellSizeFuzzTests.swift`, `Tests/LibraryModelTests/LibraryCollectionEmptinessTests.swift`, `Tests/LibraryModelTests/LibraryEmptyCollectionTests.swift`, `Tests/LibraryModelTests/LibraryGridEdgeTests.swift`, `Tests/LibraryModelTests/LibraryGridTests.swift`, `Tests/LibraryModelTests/LibraryPhotoIDFuzzTests.swift`, `Tests/AppSnapshotTests/LibraryEmptyCollectionSnapshots.swift`.

#### Wave 2: the loop on real files (after the spine)

**`import`** (#210). Import a folder: scan, metadata, path ids, skip known, progress, failures.

- Engine (creative-core): none (decode is ImageIO in LibraryApp).
- SuiteUI: S-L4 InlineNotice, S-L5 ProgressRow (placeholders until then); #330, #333.
- Note: Owns LibraryJourneyTests.swift in its wave, for its journey steps if #333 has not merged. Deletes the skipped testImportRateAndRelaunch (J8 replaces it).
- Owned files: `Sources/LibraryModel/LibraryImport.swift`, `Sources/LibraryModel/Live/LiveImporter.swift`, `Sources/LibraryApp/Platform/ImageIODecoder.swift`, `Sources/LibraryApp/LibraryWindow+Import.swift`, `Sources/LibraryApp/LibraryBrowser.swift`, `Tests/LibraryModelTests/LibraryImportTests.swift`, `Tests/AppSnapshotTests/LibraryImportSnapshots.swift`, `Tests/AppSnapshotTests/LibraryDecodeTests.swift`, `UITests/LibraryJourneyTests+Import.swift`, `UITests/LibraryJourneyTests+PerfImport.swift`, `UITests/LibraryJourneyTests.swift`, `Tests/LibraryModelTests/LibraryImportBudgetTests.swift`.

**`thumbnails`** (#33). Real grid thumbnails: buckets, visible requests, LRU, placeholders.

- Engine (creative-core): none (resized and rgba8 landed: creative-core #132, #143).
- SuiteUI: S-L2 ThumbnailGrid additions; #330, #333.
- Note: Live thumbnails read files through services.decoder, which is FakeDecoder in tests and the live ImageIODecoder once import lands. Its (L) steps wait for import to merge. Cell values need S-L2.
- Owned files: `Sources/LibraryModel/LibraryThumbnails.swift`, `Sources/LibraryModel/Live/LiveThumbnails.swift`, `Sources/LibraryApp/LibraryGrid.swift`, `Sources/LibraryApp/DisplayImage+Image.swift`, `Sources/LibraryApp/LibraryWindow+Thumbnails.swift`, `Tests/LibraryModelTests/LibraryThumbnailTests.swift`, `Tests/AppSnapshotTests/LibraryThumbnailSnapshots.swift`, `Tests/AppSnapshotTests/LibraryGridSnapshots.swift`, `UITests/LibraryJourneyTests+Grid.swift`, `UITests/LibraryJourneyTests+PerfGrid.swift`, `Tests/LibraryModelTests/LibraryGridBudgetTests.swift`.

**`cull`** (#211, #426, #724). Cull from the keyboard with undo and Auto Advance, in grid and loupe.

- Engine (creative-core): none.
- SuiteUI: S-L2 (reject badge); #330, #333.
- Note: #724's keys only; its zoom and photo size go to loupe-viewport. The grid's reject mark (dimmed cell, xmark badge) is drawn by thumbnails, which owns the cell builder; cull changes only Model state. Owns MetadataInspector.swift in wave 2: it routes the stars, flag and label through cull(_:) and gives every control an identifier (most of #291's list); metadata-more takes the file in wave 5. Its (L) steps wait for import to merge. Its PR that lands the loupe keys says 'Part of #724'; whichever of cull and loupe-viewport merges its #724 part last says 'Closes #724'.
- Owned files: `Sources/LibraryModel/LibraryCulling.swift`, `Sources/LibraryModel/Live/LiveCulling.swift`, `Sources/LibraryModel/MetadataEditing.swift`, `Sources/LibraryApp/LibraryWindow+Cull.swift`, `Tests/LibraryModelTests/LibraryRatingTests.swift`, `Tests/LibraryModelTests/LibraryAutoAdvanceTests.swift`, `Tests/LibraryModelTests/LibraryMetadataTests.swift`, `Tests/AppSnapshotTests/LibraryRatingSnapshots.swift`, `Tests/AppSnapshotTests/LibraryAutoAdvanceSnapshots.swift`, `UITests/LibraryJourneyTests+Cull.swift`, `UITests/LibraryJourneyTests+PerfCull.swift`, `Tests/LibraryModelTests/LibraryCullBudgetTests.swift`, `Sources/LibraryApp/MetadataInspector.swift`, `Tests/AppSnapshotTests/LibraryMetadataSnapshots.swift`.

**`persist`** (#212). The catalog file: JSON v1 with develop and crop, restore at launch, set aside a damaged file.

- Engine (creative-core): none for v1 (JSON); creative-core#157 only if decision D1 picks the SQLite catalog.
- SuiteUI: S-L4 InlineNotice; #330, #333.
- Note: Writes the develop and crop objects from the start (their types come from the spine), so #423's and #425's catalog parts are done here. Its (L) steps wait for import to merge. Flushes on quit and exposes library.catalog = saved or dirty.
- Owned files: `Sources/LibraryModel/LibraryPersistence.swift`, `Sources/LibraryModel/Live/LiveCatalogCoding.swift`, `Sources/LibraryApp/Platform/CatalogStore.swift`, `Sources/LibraryApp/LibraryWindow+Persist.swift`, `Tests/LibraryModelTests/LibraryPersistTests.swift`, `Tests/LibraryModelTests/Golden/catalog-v1.json`, `Tests/AppSnapshotTests/LibraryRestoreSnapshots.swift`, `UITests/LibraryJourneyTests+Persist.swift`, `UITests/LibraryJourneyTests+PerfLaunch.swift`, `Tests/LibraryModelTests/LibraryCatalogBudgetTests.swift`.

**`loupe-viewport`** (#724). Loupe on CanvasViewport: zoom, pan, real photo size, latest-wins render, prefetch.

- Engine (creative-core): none.
- SuiteUI: #330, #333.
- Note: #724's zoom, photo on the artboard and real size. Adds Home and End (first and last photo) and scroll pan. Its (L) steps wait for import to merge. Its #724 PR says 'Part of #724' unless it merges after cull's, then 'Closes #724'.
- Owned files: `Sources/LibraryModel/LoupeState.swift`, `Sources/LibraryModel/LoupeZoom.swift`, `Sources/LibraryModel/LibraryLoupeImage.swift`, `Sources/LibraryModel/RenderQueue.swift`, `Sources/LibraryModel/Live/LiveLoupeImaging.swift`, `Sources/LibraryApp/LibraryLoupe.swift`, `Sources/LibraryApp/LibraryWindow+Loupe.swift`, `Tests/LibraryModelTests/LibraryLoupeTests.swift`, `Tests/LibraryModelTests/LibraryLoupeZoomTests.swift`, `Tests/LibraryModelTests/LibraryRenderQueueTests.swift`, `Tests/LibraryModelTests/LibraryLoupeImageTests.swift`, `Tests/AppSnapshotTests/LibraryLoupeSnapshots.swift`, `UITests/LibraryJourneyTests+Loupe.swift`, `UITests/LibraryJourneyTests+PerfLoupe.swift`, `Tests/LibraryModelTests/LibraryLoupeBudgetTests.swift`.

#### Wave 3: develop and the readouts (after wave 2)

**`develop`** (#32, #423). Develop sliders, histogram, render to pixels in loupe and grid, copy and paste settings.

- Engine (creative-core): none (creative-core#231 closed by #246); a new core issue only if QB-LIB-6's model half misses: PixelBuffer.developed(temperature:tint:exposure:contrast:highlights:shadows:), one pass over storage, equal to the chained calls within 1e-6.
- SuiteUI: S-L1 HistogramView; #330, #333.
- Note: Owns LibraryJourneyTests.swift in its wave, for its journey steps if #333 has not merged.
- Owned files: `Sources/LibraryModel/LibraryDevelop.swift`, `Sources/LibraryModel/Live/LiveDevelop.swift`, `Sources/LibraryApp/DevelopInspector.swift`, `Sources/LibraryApp/LibraryWindow+Develop.swift`, `Tests/LibraryModelTests/LibraryDevelopTests.swift`, `Tests/LibraryModelTests/LibraryDevelopRenderTests.swift`, `Tests/AppSnapshotTests/LibraryDevelopSnapshots.swift`, `Tests/AppSnapshotTests/LibraryDevelopRenderSnapshots.swift`, `UITests/LibraryJourneyTests+Develop.swift`, `UITests/LibraryJourneyTests+PerfDevelop.swift`, `UITests/LibraryJourneyTests.swift`, `Tests/LibraryModelTests/LibraryDevelopBudgetTests.swift`.

**`status-and-layout`** (#185, #291). Status pills, inspector header (#185), the remaining identifiers (#291), layout tests.

- Engine (creative-core): none.
- SuiteUI: S-L7 optional zoom and size pills; #330, #333.
- Note: Identifiers in other features' views are each feature's own job; this one clears what is left of #291's list.
- Owned files: `Sources/LibraryModel/LibraryStatusText.swift`, `Sources/LibraryModel/LibraryLayout.swift`, `Sources/LibraryApp/LibraryStatusBar.swift`, `Sources/LibraryApp/LibraryInspector.swift`, `Tests/LibraryModelTests/LibraryStatusTextTests.swift`, `Tests/LibraryModelTests/LibraryLayoutTests.swift`, `Tests/AppSnapshotTests/LibraryLayoutSnapshots.swift`, `Tests/AppSnapshotTests/LibraryInspectorSnapshots.swift`, `UITests/LibraryJourneyTests+Layout.swift`.

#### Wave 4: crop and export (after develop)

**`crop`** (#425). Crop and straighten in the loupe, applied in render, thumbnail and export.

- Engine (creative-core): none (creative-core#230 closed by #251).
- SuiteUI: S-L3 CropHandles; #330, #333.
- Note: Edits LiveDevelop.swift (crop after tone), which develop owned in wave 3.
- Owned files: `Sources/LibraryModel/LibraryCrop.swift`, `Sources/LibraryModel/Live/LiveCrop.swift`, `Sources/LibraryModel/Live/LiveDevelop.swift`, `Sources/LibraryApp/LibraryCropOverlay.swift`, `Sources/LibraryApp/LibraryWindow+Crop.swift`, `Tests/LibraryModelTests/LibraryCropTests.swift`, `Tests/AppSnapshotTests/LibraryCropSnapshots.swift`, `UITests/LibraryJourneyTests+Crop.swift`, `UITests/LibraryJourneyTests+PerfCrop.swift`, `Tests/LibraryModelTests/LibraryCropBudgetTests.swift`, `Sources/LibraryApp/CropInspector.swift`.

**`export`** (#424). Export JPEG at a set long edge and quality, never overwriting.

- Engine (creative-core): none.
- SuiteUI: S-L5 ProgressRow; #330, #333.
- Note: Its last task (the QB-V4 test with a cropped photo) waits for crop to merge. Owns LibraryJourneyTests.swift in its wave, for its journey steps if #333 has not merged.
- Owned files: `Sources/LibraryModel/LibraryExport.swift`, `Sources/LibraryModel/Live/LiveExporter.swift`, `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Sources/LibraryApp/LibraryExportSheet.swift`, `Sources/LibraryApp/LibraryWindow+Export.swift`, `Tests/LibraryModelTests/LibraryExportPlanTests.swift`, `Tests/AppSnapshotTests/LibraryExportSnapshots.swift`, `Tests/AppSnapshotTests/LibraryExportFidelityTests.swift`, `UITests/LibraryJourneyTests+Export.swift`, `UITests/LibraryJourneyTests.swift`, `Tests/LibraryModelTests/LibraryExportBudgetTests.swift`, `UITests/LibraryJourneyTests+PerfExport.swift`.

#### Wave 5: after v1 (tier 2, not v1)

**`filters-collections`** (#31). Filter by flag and rating, collections you make, smart rules (not v1).

- Engine (creative-core): none.
- SuiteUI: none.
- Note: Not v1. Needs one menu item added to LibraryCommands.swift; it takes that file for this wave.
- Owned files: `Sources/LibraryModel/LibraryCollections.swift`, `Sources/LibraryModel/LibraryFilter.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `Sources/LibraryApp/LibraryWindow+Filters.swift`, `Tests/LibraryModelTests/LibraryCollectionsTests.swift`, `Tests/AppSnapshotTests/LibraryCollectionsSnapshots.swift`, `UITests/LibraryJourneyTests+Filters.swift`, `Sources/LibraryApp/LibraryCommands.swift`.

**`metadata-more`** (#744). Keywords and camera details (not v1).

- Engine (creative-core): none.
- SuiteUI: none.
- Note: Not v1. Camera details come from the Exif the import scan already reads.
- Owned files: `Sources/LibraryModel/LibraryKeywords.swift`, `Tests/LibraryModelTests/LibraryKeywordTests.swift`, `Sources/LibraryApp/MetadataInspector.swift`, `Tests/AppSnapshotTests/LibraryMetadataSnapshots.swift`.

**`raw`** (#427). Camera raw files through the system decoder (not v1).

- Engine (creative-core): none.
- SuiteUI: S-L2 (RAW badge).
- Note: Not v1, pending evidence (docs/priorities.md).
- Owned files: `Sources/LibraryModel/RawFileTypes.swift`, `Sources/LibraryApp/Platform/RawDecoding.swift`, `Tests/LibraryModelTests/LibraryRawImportTests.swift`, `Tests/AppSnapshotTests/LibraryRawSnapshots.swift`, `UITests/LibraryJourneyTests+Raw.swift`.

#### Order at a glance

```
wave 1   spine ─────────────────────────────────────────────────────────┐
wave 2   import · thumbnails · cull · persist · loupe-viewport          │ (#333 for journey files,
wave 3   develop (needs loupe-viewport, thumbnails) · status-and-layout │  #330 for perf rows)
wave 4   crop (needs develop) · export (needs develop, import)          │
         ── v1: J0–J12 green live, P1–P8 reporting, audit 0 ──          │
wave 5   filters-collections · metadata-more · raw                      ┘
```

- **Journey files before #333.** Until SuiteUI's QH-4 (#333) merges, the
  Journey template compiles only `UITests/LibraryJourneyTests.swift`. Then
  in each wave exactly one feature may add journey steps, to that file: the
  spine in wave 1, import in wave 2, develop in wave 3, export in wave 4.
  The others ship Model tests and snapshots and add their `+<Area>` file as
  soon as #333 lands. `scripts/waves check library` treats the `+<Area>` files as owned
  already.
- **No engine waits for v1.** Every CoreRaster call v1 needs is on
  creative-core `main` (section 0.2). The one possible core issue is the
  fused develop pass, filed only if QB-LIB-6's model budget fails (develop's
  row above has its one-line spec).
- **SuiteUI waits are soft.** Each `needs-ui` part has a placeholder path
  (CLAUDE.md); a feature never blocks on one. The harness issues (#330,
  #331, #332, #333) block only the perf rows, goldens and journey files.
- **Live order.** Fakes first (UI track), then each feature's last task
  replaces its `Live/` stub, which turns its journeys from
  `-LibraryFixture` to live files. v1 is done when J0–J12 run live, P1–P8
  report numbers, every Library audit count is 0, and the captain has
  looked at the contact sheet.

Checklist:

- [x] Every open `line:library` issue maps to a feature or says "not v1"
      (`scripts/waves check library`).
- [x] Every feature has owned files, and no two features in a wave share
      one (`scripts/waves check library`).
- [x] Every feature names the creative-core work it waits on: an existing
      issue (closed ones named), "none", or a one-line spec for a new one.

---

## 9. Critic rounds

Two rounds, each one subagent told to refute the blueprint against the
code, the engine, the rubric and the open issues (a journey with no
component, a contract a journey can't be built from, a budget that can't be
measured, overlapping owned files, a missing issue, a product name, factual
errors, contradictions, rule breaks). Each verified its findings with
evidence before reporting. Neither found a product name of another
creative app, a protected path, or a banned no-crash word in the contract
code. The fixes are in the commits after each round on this branch.

### Round 1: 1 blocking, 20 major, 15 minor (all fixed)

| Kind | Findings | Fix |
|---|---|---|
| Journeys vs fakes (**blocking**) | Journeys asserted states the fakes couldn't produce (Auto Advance, checksum and histogram changes, crop shrink, square cells), and "live on a fixture" had no meaning: a fixture has no files | Two modes per step, (F) fake and (L) live, with `LibraryFiles.writeShoot` and `-LibraryImportOnLaunch` for live setup (4.1); fakes made honest stand-ins that show each change (5.4); steps needing real math marked (L); decision D12 |
| Journeys in the wrong wave | J0 expected import enabled in wave 1; J2 and J3 asserted status pills built in wave 3; J12 checked wave-4 crop chips and export sheet; J8 used develop and crop | J0 reads the expected state from `library.controls`; pill asserts moved to J12; chips and sheet to J6 and J7; J8 split, round trips moved to J5 step 7 and J6 step 7 |
| Views a feature must edit but didn't own | Cull needed values on the loupe; crop's overlay and section had no host | The spine embeds `cullSummary`, the crop overlay and `CropInspector` stubs in wave 1 (8.3) |
| Live stubs | `LiveDevelop` stub threw on the histogram, breaking the live loupe in wave 2; path-less samples had no live picture | Stub returns an empty histogram; `SampleImage` draws samples for fakes and live alike |
| Missing parts | `library.controls` had no owner; per-row reset, plain-drag pan, free status pills and named probe marks don't exist in SuiteUI | `LibraryControls.swift` (spine); S-L6, S-L7, S-L8; scroll pan; section-level reset |
| Contract gaps | `ImportNotice`, `ExportSummary` had no fields or text; no retry; J1 used a readable folder for "can't read"; `LibraryCatalog`'s `Equatable` breaks with `services` | `StateValues.swift` with exact `message` text and tests; `retryExport()`; `unreadableFolder()`; hand-written `==` |
| Budgets and fidelity | QB-V4's 1/255 couldn't hold across two pipelines; perf rows with fewer than 60 samples; export perf had no harness; pixel budgets would fail in debug | QB-V4 split into exact, WYSIWYG (rubric tolerance) and JPEG; per-series and single-mark sample rules; P8; pixel rows report-only in debug, gated in release (D8) |
| Rubric | Two appearances instead of four; no QB-F5 | Four appearances once #332 lands; QB-F5 with `-LibraryReduceMotion` |
| Ownership and facts | Unowned existing files; a snapshot name clash; a "fixed" surround that isn't; 512 px too small for a 320 pt cell at 2x; exposure range wording; helpers that wouldn't compile before #333; menu single keys | Every file owned (`check_waves.py` now cross-checks C4); `library-empty-import`; D7 reworded; `ThumbnailBucket` with 1024; helpers in `LibraryJourneyTests.swift` until #333; single keys settled in 6.2 |

### Round 2: 0 blocking, 19 major, 15 minor (all fixed)

Round 1 had a blocking item, so a second round ran on the revised text.
It confirmed the three checkers pass, `gen_section8.py` reproduces section
8 exactly, and jscpd stays under its threshold with the contract files
added to `Sources/`.

| Kind | Findings | Fix |
|---|---|---|
| Not drivable by XCUITest | Space can't be held through a drag | J3 and P4 pan by scroll; Space-drag math is a Model test (`panLoupe`) |
| Same-wave live setup | (L) steps of four wave-2 features import files, which import builds in the same wave | Stated as a task order inside wave 2 in 4.1 and each feature's note |
| Stubs vs shipped behavior | Throwing stubs would break the #750 inspector and the sample grid and loupe | Stubs apply the plain cull rules and draw samples; only file work throws (smoke test `liveStubsKeepSamplesWorking`) |
| Existing journeys | Four journeys click the content's "Load Sample Photos", which moves to File | The spine switches them to `-LibraryFixture samples` |
| Not observable | Re-import still failed the broken file; no streaming of records; shape not in any value; fake lift too small; checksum flag missing; no "saved" state before quit; no Home key; a passing `preview` state | J1 deletes the broken file first; `added` batch callback and `appendImported`; pixel sizes in cell and loupe values; one byte level per slider step; `-LibraryTestValues`; `library.catalog` and a flush on quit; Home and End; `preview` asserted under `-LibraryFakeMode slow` |
| Ownership | `MetadataInspector.swift` unowned in v1 (most of #291); J0 edited by import | Cull owns it in wave 2; J0 needs no edit |
| Memory and staleness | The catalog's thumbnail dictionary was unbounded; thumbnail results carried no token | 128 MB cap with eviction in `requestThumbnails`; `ThumbnailRequest` token |
| Fidelity and numbers | QB-LIB-V5 compared against a same-wave feature; J6 compared the wrong side of `straightenCrop` | Hand-run pipeline reference; the crop's height (3545 px at 5°) |
| Minor | Bucket and sort steps that couldn't show a change; U on unflagged photos; J5 fail-mode wording; launch lines; `FakeCrop` mode; smoke tests not calling every fake; `ViewerStatusBar` facts; stale comments; slider-group names; `importOnLaunch` type; unpinned core revision; who closes #724; missing preview snapshot, Reduce Motion switch, preview-data pill, export sheet host | Fixed in place: three Zoom Ins, a `shoot` capture order unlike name order, P before U, launch lines, every fake called (`everyFakeAnswers`), `init(zoom:size:trailing:)` and S-L7 narrowed, comments, `isAdjustmentNeutral`, `Bool`, `check.sh` pinned to 4cac701, "Part of" / "Closes" rule, `library-loupe-preview`, `-LibraryReduceMotion`, the spine owns the pill and the sheet's presentation |

No third round: round 2 found nothing blocking (the stop rule set for this
blueprint). After both rounds: `check_c4.py` and `check_waves.py` clean,
`contracts/check.sh` 69 of 69 tests passing with no warnings.

---

## 10. Decisions and open questions for the captain

### 10.1 Calls this blueprint makes (recommended; the captain may overturn any)

| # | Decision | Recommended | Alternative |
|---|---|---|---|
| D1 | Where the catalog lives in v1 | A JSON file, `catalog.json`, `"version": 1`, behind `CatalogCoding` and `CatalogStoring`, so moving to the SQLite catalog later swaps one live conformance | Wait for CoreCatalog (creative-core#157): it needs a `Package.swift` change (protected) to give LibraryModel CoreCatalog and GRDB, and GRDB on Linux CI is unproven here |
| D2 | Windows | One `Window` scene: one catalog, one window, so two windows can never overwrite each other's file | `WindowGroup` with a shared catalog object, which breaks "one value-type model per window" and needs a reference type |
| D3 | A protocol for culling | Yes, so key handling and rules are built in parallel (section 5.1) | No protocol, like Flare decision 14 |
| D4 | Import and the files | Import is not an undo step; Library never moves, renames or deletes a user's file; no Remove from Catalog in v1 | An undoable import and a Remove from Catalog command (see Q1) |
| D5 | Issue dependency lines | Rewrite #210, #211, #212, #423's `Depends on` to the spine (section 8.1) | Keep the chain, which serializes wave 2 into four waves |
| D6 | Catalog state access | `public internal(set)`, as Flare's LM-0a3, so per-feature extension files can write it; the app still can't | `public private(set)` with every mutation in `LibraryCatalog.swift`, which makes it a file every feature edits |
| D7 | Loupe background | `canvasSurround` (neutral grey per appearance), as the loupe uses today | The window background (white in Light), which changes how a photo reads |
| D8 | Budgets for pixel loops | Report-only in debug CI, gated in release (`swift test -c release --filter Budget`, run by each pixel feature and recorded in its PR); rows without pixel loops gate in debug at × 10, as the rubric says | Gate pixel rows in debug at × 10 or × 20, which would fail on debug CI for no real regression |
| D9 | #185 and #291 | In v1 (status pills and identifiers), though tier 3 | Leave them p3 after v1 |
| D10 | Thumbnail cache | Memory only (an LRU capped at 256 MB), rebuilt each launch | A disk cache next to the catalog; faster relaunch of a big catalog, more to get wrong |
| D11 | Pixel depth into develop | 8-bit sRGB display bytes from ImageIO, made into a `PixelBuffer`; HEIC's 10-bit and wide-gamut data is reduced before develop, and strong pushes may band | Decode to a Float `PixelBuffer` in the platform adapter (a `PhotoDecoding` that returns `PixelBuffer`), better for raw (#427) later; more memory and a contract change |
| D12 | Fakes in journeys | Every journey's (F) steps pass on the fakes, which are honest stand-ins (section 5.4); steps needing the real math are (L) and run once the live conformance lands | Live services only, which would leave the UI track nothing to test against until each feature's logic lands |

### 10.2 Open questions

| # | Question | Why it matters | Recommendation |
|---|---|---|---|
| Q1 | Should v1 let a person remove photos from the catalog (for example all rejects)? | Culling ends in "get rid of the rejects"; without it rejects stay in the grid forever. No issue asks for it | Yes, as Metadata > "Remove Rejected from Catalog" (never deleting files), one undo step. The spine adds the menu item (it owns `LibraryCommands.swift`); cull adds the method |
| Q2 | Is 4:5 meant to flip with the photo's orientation (5:4 on a landscape)? | `CropAspect.ratio(for:)` flips 3:2, 4:5 and 16:9 to the photo's orientation | Keep the flip; the chips' titles stay as written |
| Q3 | If QB-LIB-6's model half misses on CI, may develop file the fused-pass core issue? | Four separate CoreRaster passes over a 512 px preview may not fit 8 ms in release | Yes, with the spec in section 8.3 |
| Q4 | May the blueprint's merge be followed by filing S-L1 to S-L5 as `needs-ui` issues on `line:suiteui`? | The UI track's placeholders are fine, but SuiteUI should start early | Yes, filed by the first feature lead that needs each |
| Q5 | Single-key menu equivalents (0–5, P, X, U, R, G) | An unmodified key equivalent can fire while a text field is focused; the window's `onKeyPress` cannot | Settled in 6.2 as recommended: keys through `onKeyPress` only, no unmodified menu equivalents, the key named in each item's help. The captain may still ask for visible equivalents |
| Q6 | Exposure range | CoreRaster's `exposure(stops:)` takes any finite value; the slider needs a range | ±5 EV, step 0.01, two decimals |
| Q7 | Fakes' Auto Advance and crop rules | The fakes use simple stand-in rules (section 5.4); a UI built on them could look right and still differ from live | Accept: every rule the fakes simplify has an (L) journey step |
