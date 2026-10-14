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
(#148 to #750), and creative-core `main` 4cac701 (CoreRaster, CoreCatalog,
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

Read on `origin/dev` 956d946 and creative-core `main` 4cac701 (the revision
`Package.swift` resolves; it tracks `main`).

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
| Develop | `exposure(stops:)`, `whiteBalance(temperature:tint:)`, `contrast(_:)`, `highlightsShadows(highlights:shadows:)`, sliders in -100...100, identity returns the input bit for bit; contrast and highlights/shadows under 1 s on 24 MP | landed: creative-core#231 closed by #246, perf #261, #266 |
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
- [x] Every engine API in 0.2 was read in creative-core `main` 4cac701.

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
| `library-fixtures` | existing, grows | Seeded samples and the named fixtures journeys launch with; launch-argument parsing | `LibrarySample.swift`, `LibraryFixtures.swift`, `LibraryLaunch.swift` | `library-catalog` |
| `library-history` | planned | Undo and redo: named steps, each holding the values it puts back; coalescing for slider drags | `CatalogHistory.swift` | none |
| `library-import` | planned | Folder import: file type rules, path ids, skip known paths, merge into the catalog, progress and failure state | `LibraryImport.swift`, `Live/LiveImporter.swift` | `PhotoDecoding` (platform) |
| `library-thumbnails` | planned | Size buckets from the cell size, requests for visible cells, an LRU of display bytes, rebuild after a develop change | `LibraryThumbnails.swift`, `Live/LiveThumbnails.swift` | CoreRaster `resized`, `PhotoDecoding`, `DevelopRendering` |
| `library-culling` | existing, grows | Rating, flag and label on a set of ids with undo, keyboard mapping, Auto Advance, mixed values for the inspector | `MetadataEditing.swift`, `LibraryCulling.swift`, `Live/LiveCulling.swift` | `library-history` |
| `library-persistence` | planned | Catalog file v1 (JSON) encode and decode, restore, setting aside a damaged file, the dirty flag and save requests | `LibraryPersistence.swift`, `Live/LiveCatalogCoding.swift` | `CatalogStoring` (platform) |
| `library-loupe` | existing, grows | The loupe's photo and place, zoom (fit, 100%, steps), pan, the latest-wins render of the loupe image and its histogram, prefetch of the neighbours | `LoupeState.swift`, `LoupeZoom.swift`, `LibraryLoupeImage.swift`, `RenderQueue.swift`, `Live/LiveLoupeImaging.swift` | `DevelopRendering`, `PhotoDecoding` |
| `library-develop` | planned | Develop settings per photo, slider edits with clamping and coalesced undo, reset, copy and paste, the renderer over CoreRaster | `LibraryDevelop.swift`, `Live/LiveDevelop.swift` | CoreRaster adjustments and `Histogram` |
| `library-crop` | planned | Crop rectangle and angle, aspect presets, the frame kept inside the straightened image, apply and cancel | `LibraryCrop.swift`, `Live/LiveCrop.swift` | CoreRaster `rotated`, `straightenCrop`, `cropped` |
| `library-export` | planned | Export plan (sizes, never enlarge, names that never overwrite, quality), progress, cancel, per-file failures | `LibraryExport.swift`, `Live/LiveExporter.swift` | `DevelopRendering`, CoreRaster `resized`, `JPEGWriting` (platform) |

All paths are under `Sources/LibraryModel/`.

### 2.3 L3: LibraryApp components

| Component | Status | Responsibility | Owned paths | Uses |
|---|---|---|---|---|
| `library-app-shell` | existing, restructured | The `Window` scene, the root `LibraryWindow` holding the one `model`, the whole menu bar, the per-area menu structs, launch arguments | `LibraryApp.swift`, `LibraryWindow.swift`, `LibraryCommands.swift`, `LibraryMenus.swift` | every area file |
| `library-app-areas` | planned | One file per area that builds that area's menu closures and runs its async work: `+File` (import, export, samples), `+Edit` (undo, redo), `+View` (grid, loupe, zoom, sort, sizes), `+Photo` (develop, crop), `+Metadata` (rating, flag, label, Auto Advance), `+Keys` (grid and loupe keys), `+Persist` (load at launch, save after changes) | `LibraryWindow+File.swift`, `+Edit`, `+View`, `+Photo`, `+Metadata`, `+Keys`, `+Persist` | `library-model` |
| `library-app-browse` | existing, grows | The content area: empty states, import progress row, the grid with real thumbnails, the loupe on `CanvasViewport`, the status pills | `LibraryBrowser.swift`, `LibraryGrid.swift`, `DisplayImage+Image.swift`, `LibraryLoupe.swift`, `LibraryStatusBar.swift` | SuiteUI |
| `library-app-inspector` | existing, grows | The inspector: Info and Develop tabs, metadata, develop sliders and histogram | `LibraryInspector.swift`, `MetadataInspector.swift`, `DevelopInspector.swift` | SuiteUI |
| `library-app-crop` | planned | The crop frame over the loupe photo | `LibraryCropOverlay.swift` | SuiteUI `CropShade`, `SelectionOutline` |
| `library-app-export` | planned | The export sheet | `LibraryExportSheet.swift` | SuiteUI |
| `library-app-platform` | planned | Darwin adapters that conform to the platform contracts: `ImageIODecoder` (`PhotoDecoding`: folder scan, metadata, decode with orientation to sRGB RGBA8), `JPEGWriter` (`JPEGWriting`), `CatalogStore` (`CatalogStoring`: Application Support, atomic write, `.bad` rename) | `Platform/` | ImageIO, Foundation |

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
      `Sources/LibraryApp/` is in exactly one component (checked by the
      script in section 9).
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

- **Files.** Today `project.yml` compiles exactly `UITests/Journey.swift`
  and `UITests/LibraryJourneyTests.swift`, so every feature would edit one
  file. SuiteUI's QH-4 (#333) widens the template to `UITests/Journey*.swift`
  and `UITests/<target>*.swift`. After it, each feature owns
  `UITests/LibraryJourneyTests+<Area>.swift` with its own `XCTestCase`
  class, and `UITests/LibraryJourneyTests.swift` keeps only the existing
  tests. Until #333 merges, at most one feature per wave may add journey
  steps (section 8.3 names it), and the rest ship model tests and snapshots
  and add their journey after #333.
- **Shared Library helpers** live in `UITests/Journey+Library.swift`
  (owned by the spine): `LibraryFiles.write(_ count:in:)` writes generated
  JPEG, PNG and HEIC files with Exif `DateTimeOriginal` and a
  per-file color through ImageIO in the test process, plus
  `LibraryFiles.broken(in:)` (a `.jpg` holding the bytes `not an image`) and
  `LibraryFiles.readOnlyFolder()`. Every journey gets a fresh temporary
  catalog folder.
- **Launch arguments** (parsed in `LibraryLaunch.swift`, Linux-tested):

| Argument | Effect |
|---|---|
| `-LibraryFixture <name>` | Fake services and that fixture's catalog (UI track). Without it the services are live |
| `-LibraryCatalogDir <path>` | Where `catalog.json` lives (default: Application Support/Library) |
| `-LibraryImportFolder <path>` | File > Import Folder… imports this folder instead of showing the open panel |
| `-LibraryExportTo <path>` | The export sheet's folder; Export writes there without a panel |
| `-LibraryFakeMode ok\|fail\|slow` | Fakes only: every call succeeds, fails with its error, or waits 2 s first |
| `-LibraryPerfProbe` | Exposes `suite.perf` (SuiteUI QH-1, #330) |
| `-LibraryWindowSize <w>x<h>` | The window's initial content size, for the layout journey |

- **Fixtures** (`LibraryFixtures`, built in code):

| Fixture | Contents | Used by |
|---|---|---|
| `empty` | no photos | J0 |
| `samples` | today's 60 seeded samples (`LibrarySample`), now with pixel sizes | existing journeys, snapshots |
| `shoot` | 24 photos: 16 landscape 6000 × 4000, 8 portrait 4000 × 6000, dates one minute apart, no ratings | J2–J7 on fakes |
| `large` | 10,000 records over 365 days, fake decoder | P1, P7, model budgets |

- **Identifiers.** Every Library control and mark gets `library.<area>.<name>`
  (`library.grid`, `library.grid.cell.<id>`, `library.loupe.photo`,
  `library.develop.exposure`, `library.crop.frame`,
  `library.export.longEdge`, ...). Accessibility values carry state a test
  reads: a grid cell's value is `loading`, `ready` or `unreadable`; the
  loupe photo's value is `preview` or `full` plus the render's checksum
  (`full 3f9a…`), so a journey can tell that the pixels changed.
- **Waiting.** No journey asserts timing through an XCUI query. States are
  awaited with `waitForExistence` or a value predicate (10 s for import and
  export, 2 s otherwise); timing comes from the probe's JSON (section 7).
- Every step takes a `shot`, so each journey's PNGs reach the contact sheet.

### 4.2 Tier-1 journeys

Each journey first runs on fakes (`-LibraryFixture`) and its feature's
last task flips it to live services with real files. The states column
names every empty, loading and error state the journey passes through;
each also has a snapshot (section 6.3).

**J0 · `testLaunchShowsEmptyCatalog`** (`LibraryJourneyTests+Shell.swift`, spine)
1. Launch with an empty `-LibraryCatalogDir`. Shot `empty`.
   Expect `expectWindowShell()`; the empty state "No Photos" with
   **Import Folder…** as its one prominent button; the sidebar counts read 0.
2. Open File. Shot `file-menu-empty`. Expect Import Folder… enabled;
   Export… disabled.
3. Open Edit. Expect Undo and Redo disabled.
States: empty (catalog).

**J1 · `testImportAFolder`** (`+Import.swift`, import)
1. Write 24 JPEGs (4 of them in a subfolder `day2/`), 1 PNG, 1 HEIC, one
   broken `.jpg` and a `notes.txt` into a temp folder; launch with
   `-LibraryImportFolder` on it.
2. Click **Import Folder…** in the empty state. Shot `importing`. Expect the
   progress row `library.import.progress` ("Importing 3 of 27") while it
   runs; the grid shows placeholder cells with value `loading` as records
   arrive.
3. Wait for the progress row to go. Shot `imported`. Expect 26 cells; All
   Photos reads 26; the grid is in capture-date order (first cell's date
   label is the earliest written); the failure banner reads "1 file couldn't
   be imported." with **Show** listing `broken.jpg: not an image file`;
   `notes.txt` is not mentioned (not an image type, skipped silently, as
   import of a folder means images only).
4. Import the same folder again. Shot `import-again`. Expect the message
   "No new photos in <folder>." and still 26 cells.
5. Relaunch with `-LibraryImportFolder` on a read-only folder holding no
   readable files; import. Shot `import-denied`. Expect the banner
   "Library can't read <folder>. Check that you have access to it."
States: empty → loading (progress row, placeholder cells) → loaded;
error (broken file, unreadable folder); nothing new.

**J2 · `testGridShowsThumbnailsAndSorts`** (`+Grid.swift`, thumbnails)
1. Launch on `shoot`. Shot `grid`. Expect every visible cell's value to
   become `ready` within 2 s; portrait cells are taller than wide inside
   the cell (the image keeps its aspect).
2. View > Larger Thumbnails twice. Shot `grid-larger`. Expect fewer
   columns; cells re-render at the next size bucket (value `ready` again).
3. View > Sort By > Name. Shot `grid-by-name`. Expect the first cell's
   caption is the alphabetically first name.
4. Select a cell, Shift-click another four along. Expect the status pill
   reads "5 selected".
States: loading (placeholder cells) → ready.

**J3 · `testLoupeStepsZoomsAndReturns`** (`+Loupe.swift`, loupe-viewport;
grows the existing `testLoupeStepsAndReturnsToTheGrid`, which stays as is)
1. Launch on `shoot`; double-click the first cell. Shot `loupe`. Expect
   `library.loupe.photo` with value starting `preview`, then `full` within
   2 s; the readout "1 of 24"; the zoom pill reads "Fit".
2. Press Right twice. Shot `loupe-step`. Expect "3 of 24".
3. View > Actual Size (Command-1). Shot `loupe-100`. Expect the zoom pill
   "100%".
4. Drag the photo 200 pt left. Shot `loupe-pan`. Expect the photo frame's
   x moved left by 200 (±2).
5. View > Zoom to Fit (Command-0), then Escape. Shot `loupe-grid`. Expect
   the grid with the third photo selected.
States: loading (`preview` before `full`).

**J4 · `testCullWithKeysAndAutoAdvance`** (`+Cull.swift`, cull)
1. Launch on `shoot`; open the first photo in the loupe. Metadata > Auto
   Advance is checked by default.
2. Press 3. Shot `cull-rated`. Expect "2 of 24"; going back with Left shows
   3 stars on photo 1 (its value reads "3 stars").
3. Press P on photo 2, then X on photo 3. Shot `cull-flagged`. Expect "4 of
   24"; Favorites count 1; photo 3's value includes "Rejected".
4. Edit > Undo. Shot `cull-undo`. Expect the Edit menu read "Undo Reject"
   before, photo 3 no longer rejected, and the loupe still on "4 of 24"
   (undo does not move, #426).
5. Uncheck Metadata > Auto Advance; press 5. Expect still "4 of 24", 5
   stars.
6. Escape; select photos 5 and 6 in the grid; press 2. Shot `cull-grid`.
   Expect both read 2 stars and the selection did not move.
7. Press U on them; Edit menu reads "Undo Clear Flag".
States: none beyond the loaded grid; the refusal of a key with nothing
selected is "nothing happens and the Metadata items are disabled".

**J5 · `testDevelopSlidersAndHistogram`** (`+Develop.swift`, develop)
1. Launch on `shoot` (live after integration); open photo 1 in the loupe;
   click the inspector's **Develop** tab. Shot `develop`. Expect the
   histogram `library.develop.histogram` and six rows: Exposure,
   Temperature, Tint, Contrast, Highlights, Shadows, all at 0.
2. Drag Exposure right. Shot `develop-exposure`. Expect the row's value
   above 0; the loupe photo's checksum changed; the histogram's value
   (its mean as text) went up.
3. Focus Contrast, press Right three times then Shift-Right. Expect 3, then
   13 (step 1, Shift ×10).
4. Edit menu reads "Undo Contrast"; undo once; Contrast reads 3 (the
   Shift step was one step).
5. Photo > Copy Settings (Shift-Command-C); Right; Photo > Paste Settings
   (Shift-Command-V). Shot `develop-pasted`. Expect photo 2's Exposure
   equals photo 1's; Edit menu "Undo Paste Settings".
6. Click Exposure's reset. Expect 0 and the checksum back to the
   undeveloped photo's.
States: loading (the loupe shows `preview` while a render is under way);
error: a render that throws keeps the last picture and shows "Couldn't
render this photo: <reason>." under the histogram (fake mode `fail`).

**J6 · `testCropAndStraighten`** (`+Crop.swift`, crop)
1. Launch on `shoot`; open photo 1 (6000 × 4000) in the loupe; Photo > Crop
   (R). Shot `crop`. Expect `library.crop.frame` with a thirds grid, aspect
   chips and the Straighten row.
2. Click the **1:1** chip. Expect the frame's value "4000 × 4000".
3. Set Straighten to 5 (focus it, type 5, Return). Shot `crop-straighten`.
   Expect the frame shrank (value width under 4000) and the angle reads 5°.
4. Press Return. Shot `crop-applied`. Expect the loupe photo's value
   reports a square size; the grid cell (Escape) is square; the Edit menu
   reads "Undo Crop".
5. Undo; R; drag the frame's corner; Escape. Expect no change and no new
   undo step.
States: none beyond the loaded photo.

**J7 · `testExportJPEGsAtASize`** (`+Export.swift`, export)
1. Launch on `shoot` (live after integration) with `-LibraryExportTo` on a
   temp folder; select photos 1 and 2; File > Export… (Shift-Command-E).
   Shot `export-sheet`. Expect long edge 2048, quality 85, "2 photos".
2. Set long edge 1024, quality 80; click **Export**. Shot `exporting`.
   Expect the progress row "Exporting 1 of 2" with Cancel.
3. Wait for done. Shot `exported`. Expect "Exported 2 photos." with
   **Show in Finder**; two files `IMG_0001.jpg` and `IMG_0002.jpg` exist,
   start with the JPEG marker `FF D8`, and have a long edge of 1024.
4. Export the same two again. Expect `IMG_0001 2.jpg` and `IMG_0002 2.jpg`;
   nothing overwritten.
5. Point `-LibraryExportTo` at a read-only folder (relaunch) and export.
   Shot `export-failed`. Expect "2 photos couldn't be exported." with each
   name and reason, and **Try Again**.
6. Select all 24 at Original Size; Export; Cancel after the first file.
   Expect "Exported 1 of 24. Export was cancelled." and fewer than 24 files.
7. With nothing selected and the grid showing, File > Export… is disabled.
States: loading (progress row), error (per-file failures), cancelled.

**J8 · `testCatalogSurvivesRelaunch`** (`+Persist.swift`, persist; replaces
the skipped `testImportRateAndRelaunch`)
1. Import a written folder of 6 JPEGs (live); rate photo 1 four stars,
   pick photo 2, set photo 3's Exposure to +1, crop photo 4 to 1:1.
2. Terminate the app (`XCUIApplication.terminate()`) and relaunch with the
   same `-LibraryCatalogDir`. Shot `relaunched`.
3. Expect 6 cells, photo 1 "4 stars", Favorites 1, photo 3's loupe
   checksum equals the one before quitting, photo 4's cell square.
4. Delete `day2/` from disk for a catalog that holds it, relaunch. Expect
   those cells' value `unreadable` and help "The file is missing:
   <path>"; they can still be rated.
States: loading at launch (grid placeholders while thumbnails rebuild);
error: missing file.

**J9 · `testDamagedCatalogIsSetAside`** (`+Persist.swift`, persist)
1. Write `not json` as `catalog.json` in the catalog folder; launch.
   Shot `catalog-damaged`. Expect the empty state plus the message
   "Library couldn't read its catalog and started a new one. The old file
   is catalog.json.bad." with **Show in Finder**; the file was renamed.
2. Write `{"version": 2}`; relaunch. Expect "This catalog was made by a
   newer Library. Update Library to open it." and the file left untouched
   (not renamed: a newer app can still read it), and nothing saved over it.
States: error (damaged, newer version).

**J10 · `testEveryMenuOpens`** (existing, spine updates it): every menu
opens and the item count of each equals section 6.2's menu list.

**J11 · `testEveryControlActsOrSaysWhy`** (`+Shell.swift`, spine): reads
the `suite.controls` value (SuiteUI, with #330), clicks each enabled
`library.*` control, Escape and Command-Z after each; every enabled control
changed the shot or a value, every disabled one has a reason. A sweep, not
feature coverage.

**J12 · `testLayoutAtWidths`** (`+Layout.swift`, status-and-layout
feature): see section 7.3.

### 4.3 Perf journeys

| # | Test (file, feature) | Fixture | Steps | Measures (section 7) |
|---|---|---|---|---|
| P1 | `testGridScrollLarge` (`+Perf.swift`, thumbnails) | `large` | scroll the grid end to end at a set velocity | QB-LIB-3 |
| P2 | `testCullKeyLatency` (`+Perf.swift`, cull) | `shoot` | 60 rating keys in the grid, then 60 in the loupe with Auto Advance | QB-LIB-4, QB-LIB-5 |
| P3 | `testDevelopSliderLatency` (`+Perf.swift`, develop) | `shoot` live | velocity drag on Exposure across its range | QB-L2, QB-LIB-6 |
| P4 | `testLoupeStepLatency` (`+Perf.swift`, loupe-viewport) | `shoot` live | Right 23 times | QB-LIB-5 |
| P5 | `testCropDragLatency` (`+Perf.swift`, crop) | `shoot` | velocity drag of the crop corner | QB-L1 |
| P6 | `testImportProgressAndThroughput` (`+Perf.swift`, import) | 200 written 4000 × 3000 JPEGs | import | QB-L9, QB-LIB-1 |
| P7 | `testLaunchLargeCatalog` (`+Perf.swift`, persist) | `large` saved, relaunched | launch | QB-LIB-2, QB-L12 |

Every perf journey asserts at least 60 samples (else it fails as invalid)
and attaches `perf-<test>.json`. They ship report-only (rubric 6, How
gates are set), and need #330 (FrameProbe) and #333 (velocity drags).

Checklist:

- [x] Every tier-1 row of section 3 has a journey: import J1, grid J2,
      loupe and zoom J3, cull and auto-advance J4, undo J4–J7, develop J5,
      crop J6, export J7, persistence J8 and J9.
- [x] Every journey names its XCUITest, its file and the feature that owns
      it.
- [x] Every empty, loading and error state a tier-1 journey passes through
      is named in its States line.
