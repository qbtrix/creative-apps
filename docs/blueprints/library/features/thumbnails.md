# Feature packet: thumbnails

**Feature:** the grid shows each photo's real picture. Thumbnails are built
off the main thread at a size bucket that covers the cell at the display's
scale, only for the cells on screen, kept in a bounded cache, redrawn when a
photo's develop settings change, and shown as a placeholder while loading
and as a warning mark when the file can't be read.
**Line:** `line:library` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/thumbnails`

**Covers:** #33 (closes with TH-7).

**Depends on:** the spine feature issue; #779 (S-L2: `ThumbnailGrid`
reports visible cells and takes a per-cell value, help, identifier and the
dimmed and unreadable marks; a change to `Sources/SuiteUI/ThumbnailGrid.swift`,
which only SuiteUI may make); #333 (journey files: J2 lives in
`UITests/LibraryJourneyTests+Grid.swift`, which compiles only once #333
widens the Journey template). No creative-core issue: `resized(width:height:filter:)`
(#132) and `rgba8(colorSpace:)` (#143) are on creative-core `main`. The perf
task TH-9 also waits on #330 and S-L8 (#782) (`waves.md`, Perf tasks). J2's
(L) step needs import's live decoder and import's live importer, both wave 2:
TH-8 waits for import's IM-6 to merge (a task order inside the wave, not a
feature dependency).

Blueprint sections: 2.2 (`library-thumbnails`), 2.5, 4.2 J2, 4.3 P1, 5.2
(`ThumbnailBucket`), 5.3 (`ThumbnailProviding`), 5.7 (the J2 rows), 6.1
(Thumbnails, Cull marks, Unreadable photo), 6.3, 7.1 (QB-LIB-3, QB-LIB-8),
7.4 (QB-LIB-V5).

No task edits `docs/c4/model.json`, `docs/design.md` or
`docs/review-rubric.md` (the supervisor folds them in). The grid's reject
mark (dimmed cell, `xmark.circle` badge) is drawn here, since thumbnails owns
the cell builder; cull only changes Model state.

## Journey steps

**J2 · `testGridShowsThumbnailsAndSorts`** (`UITests/LibraryJourneyTests+Grid.swift`)
1. (F) Launch on `-LibraryFixture shoot`. (L, TH-8) Launch live on
   `LibraryFiles.writeShoot` with `-LibraryImportOnLaunch`. Shot `grid`.
   Expect every visible cell's value (`library.grid.cell.<id>`) to start with
   `ready` within 2 s; the first cell (capture order) is `IMG_0024`; a
   portrait cell's value reports a height above its width (for example
   `ready 341×512` at 2x, `ready 171×256` at 1x: the journey compares the
   two numbers, never fixed ones).
2. (F, L) View > Larger Thumbnails (Command-+; in the grid the Zoom In item
   carries that title) three times (160 → 280 pt). Shot `grid-larger`.
   Expect fewer columns and every visible cell `ready` with a larger long
   side than in step 1 (the next bucket: 512 → 1024 at 2x, 256 → 512 at
   1x).
3. (F, L) View > Sort By > Name. Shot `grid-by-name`. Expect the first
   cell's caption `IMG_0001`.
4. (F, L) Click a cell, Shift-click the fourth after it. Expect five cells
   with the selected trait.
States: loading (placeholder cells valued `loading`) → ready; unreadable
(`library-grid-unreadable` snapshot; J8 drives it live).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Grid cell | – | the file is missing or unreadable: the placeholder fill with `exclamationmark.triangle` in `stateWarning`, help `cellHelp(for:)` (the contract's `availability.help`: "The file is missing.", or "Library can't read this file: not an image file."), value `unreadable …` | the caption on the placeholder fill (`canvasSurround`), value `loading`, until its thumbnail arrives |
| Grid | the spine's empty states | – | cells off screen request nothing |
| Reject | – | – | – (a rejected photo's cell: its image at 40% and the `xmark.circle` badge labelled "Rejected", through #779's `dimmed`) |

Snapshots (`LibraryThumbnailSnapshots.swift`): `library-grid-thumbnails`
(real gradients from the fakes, portrait and landscape), `library-grid-loading`,
`library-grid-unreadable`, Light and Dark. `LibraryGridSnapshots.swift`
(existing) keeps `library-grid-*` and `library-grid-selected-*`, now with
real images.

## Contract slice

From the spine: `ThumbnailProviding`, `ThumbnailBucket`, `ThumbnailRequest`,
the stored `thumbnails`, `thumbnailLongSide`, `pendingThumbnails`, and the
readouts `cellValue(for:)` and `cellHelp(for:)` (computed from that state).
This feature adds, in `LibraryThumbnails.swift`:

```swift
extension LibraryCatalog {
    public static let heldThumbnailBytes = 128 * 1024 * 1024
    /// ThumbnailBucket for the cell; also sets `thumbnailLongSide`.
    public mutating func thumbnailLongSide(forCell cellWidth: Int, scale: Int) -> Int
    /// Requests for the visible ids that have no current image and no pending
    /// request; evicts held images outside visible ± two screens of `order`
    /// (never a visible one; an empty `visible`, as when the loupe opens, evicts nothing),
    /// farthest first, until `thumbnails` holds ≤ heldThumbnailBytes.
    public mutating func requestThumbnails(visible: [String]) -> [ThumbnailRequest]
    /// Dropped unless the request is still pending with the same token.
    public mutating func setThumbnail(_ image: DisplayImage, for request: ThumbnailRequest)
    /// Clears the pending request; marks the photo `.missing` or `.unreadable(reason)`.
    public mutating func failThumbnail(_ request: ThumbnailRequest, _ error: LibraryError)
    /// Drops the held image and any pending request of `id` (after its develop settings change).
    public mutating func invalidateThumbnail(_ id: String)
}
```

A request's `token` is `ThumbnailToken.of(photo.develop, longSide:)`, a
deterministic FNV-1a over the settings' fields and the long side (never
`hashValue`, which varies per process), so a result for settings that have
since changed is dropped. `LiveThumbnails(decoder:develop:)` replaces the
spine's stub, sets `unavailable` to nil and becomes an actor holding an LRU
of at most `ThumbnailBucket.cacheBytes` (256 MB) keyed by id, long side and
token. No contract signature changes.

## Pseudocode

```
requestThumbnails(visible):                                     # TH-1
  side = thumbnailLongSide
  out = []
  for id in visible where photo(id).availability == .available:
    token = ThumbnailToken.of(photo.develop, side)
    if thumbnails[id] covers side (its long side == min(side, photo long side)): continue   # a settings change
                                                    # removes the held image first (invalidateThumbnail)
    if pendingThumbnails[id]?.token == token: continue
    req = ThumbnailRequest(id, side, token); pendingThumbnails[id] = req; out.append(req)
  if visible.isEmpty: return out                               # the loupe is open: keep everything (its preview)
  keep = ids within visible's span in `order` ± 2 × visible.count
  evict held ids not in keep; then, while bytes(thumbnails) > heldThumbnailBytes,
    evict the held id farthest from the visible span that is not itself visible
  (the visible images alone always fit: 60 cells × 1 MB at the 512 bucket; at
   the 1024 bucket a 320 pt grid shows at most about 30 cells × 4 MB = 120 MB)
  return out
setThumbnail(image, req):  guard pendingThumbnails[req.id] == req,
                             req.token == ThumbnailToken.of(photo(req.id).develop, req.longSide) else return; thumbnails[req.id] = image; pending -= id
failThumbnail(req, err):   pending -= id; availability = err == .missingFile ? .missing : .unreadable(err.message)

LiveThumbnails.thumbnail(photo, longSide):                      # TH-3
  key = (photo.id, longSide, token); if cached: touch, return
  if photo.path == nil: image = SampleImage(photo, longSide) after the crop's shape
  else:
    bytes = try await decoder.decode(path, maxLongSide: min(2 × longSide, photo long side))
    buffer = PixelBuffer(rgba8:, width:, height:, colorSpace: .sRGB)
    buffer = try develop.render(buffer, settings: photo.develop)     # neutral stub until develop
    size = PixelSize(buffer).fitting(longSide)
    image = DisplayImage(buffer.resized(width, height, .lanczos3).rgba8(.sRGB))
  insert; while bytes > cacheBytes: remove least recently used
invalidate(id): remove every key of id

LibraryWindow+Thumbnails (TH-6, macOS):
  thumbnails.visibleChanged(ids) -> for req in model.requestThumbnails(visible: ids):
     Task.detached(priority: .userInitiated) { result = try await services.thumbnails.thumbnail(for: photo, longSide: req.longSide) }
       -> MainActor: model.setThumbnail(result, for: req) | model.failThumbnail(req, error)
  thumbnails.cellSizeChanged(width, scale) -> model.thumbnailLongSide(forCell: width, scale: scale); re-request visible
  scale from the window's displayScale (1 or 2)
LibraryGrid (TH-5): ThumbnailItem(image: model.thumbnails[id].map(Image.init(display:))   # the spine's helper (SA-1), caption, badges(dimmed: flag == .reject),
                     accessibilityValue: model.cellValue(for: id), help: model.cellHelp(for: id))
                     with cellIdentifierPrefix "library.grid.cell.", onVisibleChange -> menu.thumbnails.visibleChanged
                     (LibraryGrid(model:menu:) from the spine; LibraryBrowser.swift, import's in wave 2, is not edited)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: thumbnails`, `Fast-Check:
pass`, `Head:`. The last task to merge carries `feature-done` (TH-8, or TH-9
when it runs).

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| TH-1 | #33 (part) | Buckets, visible requests, tokens, eviction under 128 MB | `Sources/LibraryModel/LibraryThumbnails.swift`, `Tests/LibraryModelTests/LibraryThumbnailTests.swift` | spine |
| TH-2 | #33 (part) | Results: stale drops, failures to availability, invalidate | `Sources/LibraryModel/LibraryThumbnails.swift`, `Tests/LibraryModelTests/LibraryThumbnailResultTests.swift` | TH-1 |
| TH-3 | #33 (part) | `LiveThumbnails` actor: decode, develop, lanczos3, LRU ≤ 256 MB; QB-LIB-V5 | `Sources/LibraryModel/Live/LiveThumbnails.swift`, `Tests/LibraryModelTests/LibraryLiveThumbnailsTests.swift` | spine |
| TH-4 | #33 (part) | The grid model budgets | `Tests/LibraryModelTests/LibraryGridBudgetTests.swift` | TH-1 |
| TH-5 | #33 (part) | Cells show images (through the spine's `Image(display:)`), values, help, identifiers, reject and unreadable marks; snapshots | `Sources/LibraryApp/LibraryGrid.swift`, `Tests/AppSnapshotTests/LibraryThumbnailSnapshots.swift`, `Tests/AppSnapshotTests/LibraryGridSnapshots.swift` | TH-2, #779 |
| TH-6 | #33 (part) | The thumbnails area: visible ids to requests to tasks, cell size and scale | `Sources/LibraryApp/LibraryWindow+Thumbnails.swift` | TH-2, TH-3 |
| TH-7 | #33 (closes) | J2 (F) steps | `UITests/LibraryJourneyTests+Grid.swift` | TH-5, TH-6, #333 |
| TH-8 | – | J2 (L) step 1 on written files | `UITests/LibraryJourneyTests+Grid.swift` | TH-7, import IM-6 |
| TH-9 | – | P1 `testGridScrollLarge` with `XCTMemoryMetric` (perf, report-only) | `UITests/LibraryJourneyTests+PerfGrid.swift` | TH-7, #330, #782 |

`LibraryThumbnailResultTests.swift` and `LibraryLiveThumbnailsTests.swift`
are new test files (not in `waves.json`); no other feature names them. TH-1,
TH-3 and TH-4's model work can start before #779 merges; TH-5 cannot.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| TH-1 | `LibraryThumbnailTests`: `thumbnailLongSide(forCell: 160, scale: 2)` is 512 and `(280, 2)` is 1024; 30 visible ids give 30 requests, and asking again gives none; a photo `.missing` gets no request; after `requestThumbnails` over every screen of `large` in turn (60 ids at a time at the 512 bucket, about 1 MB each; then 30 at a time at the 1024 bucket, 4 MB each), the held bytes never exceed 128 MB and the visible ones are all held (QB-LIB-8 model half); `requestThumbnails(visible: [])` evicts nothing | a request repeats, a missing file is requested, a visible image is evicted, or memory grows past the cap |
| TH-2 | `LibraryThumbnailResultTests`: a result whose photo's develop changed after the request is dropped; a result for a request no longer pending is dropped; `failThumbnail(.missingFile)` makes `cellValue` start `unreadable` and `cellHelp` "The file is missing."; `invalidateThumbnail` drops the held image and any pending request, so the next `requestThumbnails` asks again; a result whose token no longer matches the photo's settings is dropped even while its request is still pending | a stale picture is shown, a failure leaves the cell loading, or an invalidated photo isn't redrawn |
| TH-3 | `LibraryLiveThumbnailsTests` over a test decoder giving a fixed 1200 × 800 gradient: the 256 px thumbnail vs the hand-run pipeline (decode full size, `LiveDevelop().render`, `resized(.lanczos3)` to 256 × 171) has mean absolute difference ≤ 1/255 and max ≤ 8/255 (QB-LIB-V5); a portrait photo gives 171 × 256; a sample (no path) equals `SampleImage` at 256; after 300 distinct 1024 px thumbnails the actor's byte count is ≤ `cacheBytes`; `invalidate` makes the next call decode again (decoder call count); `LiveThumbnails.unavailable == nil` | the picture drifts from the pipeline, the cache grows unbounded, or invalidation is ignored |
| TH-4 | `LibraryGridBudgetTests` (rows below) | a model half misses its debug gate |
| TH-5 | `LibraryThumbnailSnapshots` (three states, Light and Dark) and `LibraryGridSnapshots` redrawn with images; a portrait image is aspect-fit inside its landscape cell | a state is missing, a picture is cropped to fill, or a reject isn't dimmed |
| TH-6 | J2 step 1–2 on the macOS run (cells reach `ready` within 2 s, and the bucket changes after Zoom In) | requests block the main thread or the bucket never changes |
| TH-7 | J2 steps 1 (F) to 4 | any expectation fails |
| TH-8 | J2 step 1 (L) | real files don't reach `ready` within 2 s |
| TH-9 | P1 attaches `perf-testGridScrollLarge.json` with ≥ 60 frame intervals per pass and a peak memory value | fewer than 60 samples (the test fails as invalid) |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-LIB-3 model half | `requestThumbnails` for 60 visible on `large` ≤ 5 ms (0.5 ms release) | `LibraryGridBudgetTests.requestThumbnailsWithinBudget` |
| QB-LIB-3 probe | p95 frame interval ≤ 1.5 refreshes; every visible cell `thumb-ready` ≤ 500 ms after the scroll stops; report-only | P1 (TH-9) |
| QB-LIB-8 memory | catalog `thumbnails` ≤ 128 MB after scrolling all 10,000; the live LRU ≤ 256 MB; peak resident ≤ 1.5 GB in P1 | `LibraryThumbnailTests.heldBytesStayUnderCap`, `LibraryLiveThumbnailsTests.cacheStaysUnderCap`, P1's `XCTMemoryMetric` |
| QB-LIB-V5 | 256 px thumbnail vs the hand-run pipeline: mean ≤ 1/255, max ≤ 8/255 | `LibraryLiveThumbnailsTests.matchesFullPipeline` |
| QB-V5 | three new states, Light and Dark (four appearances once #332 lands) | `LibraryThumbnailSnapshots` |
| release run | `swift test -c release --filter Budget` once, recorded in TH-4's PR body (decision D8: pixel rows report in debug) | – |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR is green, J2 included.
- **Audit zero new:** no `library` count over `UITests/audit-baseline.json`;
  with #779's per-cell identifiers the `identifier` count for the grid shots
  drops, never rises; `grid`, `grid-larger`, `grid-by-name` add nothing.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  with J2's shots and, if TH-9 ran, P1's numbers.
