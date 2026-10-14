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
