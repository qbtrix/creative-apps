# Feature packet: loupe-viewport

**Feature:** the loupe shows the photo's real pixels at its real size on
`CanvasViewport`: zoom to fit, 100% and steps, pan when zoomed, Home and End,
the grid thumbnail shown at once as a preview while the screen-size render
runs, only the latest render shown, and the neighbours decoded ahead so
stepping is quick.
**Line:** `line:library` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/loupe-viewport`

**Covers:** #724 (its zoom, the photo on the artboard and real size; LV-8's
PR says `Part of #724`, or `Closes #724` if cull's CU-5 has already merged).

**Depends on:** the spine feature issue; #333 (J3 lives in
`UITests/LibraryJourneyTests+Loupe.swift`, which compiles only once #333
widens the Journey template). No creative-core issue. No SuiteUI change:
`CanvasViewport` already pans on scroll, arrows and Space-drag and takes a
zoom and `onZoom`. The perf task LV-11 also waits on #330 and S-L8 (#782).
J3's (L) step needs import's live decoder and importer: LV-10 waits for
import's IM-6 to merge (a task order inside the wave).

Blueprint sections: 2.2 (`library-loupe`), 2.5 (latest wins), 4.2 J3, 4.3
P4, 5.3 (`LoupeImaging`), 5.5 (`loupeArtboard` goes, and this feature removes
it: review note), 5.7 (the J3 row), 6.1 (Loupe surround), 6.2 (Loupe, View
menu), 6.3, 7.1 (QB-LIB-5, QB-L1, QB-LIB-8).

No task edits `docs/c4/model.json`, `docs/design.md` or
`docs/review-rubric.md`.

**Pan.** Blueprint 5.7 lists `panLoupe(dx:dy:)` as Model-tested Space-drag
math. `CanvasViewport` already owns the scroll position and pans on scroll,
arrows and Space-drag (`CanvasLayout.panned`, covered by SuiteUI's SJ9), and
the spine declares no stored pan state for a catalog method to change. So
this feature builds no `panLoupe`; J3 step 4 drives the pan by scroll and
P4 measures it.

## Journey steps

**J3 · `testLoupeStepsZoomsAndReturns`** (`UITests/LibraryJourneyTests+Loupe.swift`;
the existing `testLoupeStepsAndReturnsToTheGrid` stays)
1. (F) Launch on `-LibraryFixture shoot`. (L, LV-10) Live on `writeShoot`
   with `-LibraryImportOnLaunch`. Sort by Name; double-click the first cell.
   Shot `loupe`. Expect `library.loupe.photo` with a value starting `full`
   within 2 s and the readout "IMG_0001 · 1 of 24". (F) Relaunched with
   `-LibraryFakeMode slow`, wait for the first cell's thumbnail (its value
   `ready`, or 2 s before #779), then open it: the value reads `preview`
   at once (the grid thumbnail, scaled) and `full` after the slow render;
   shot `loupe-preview`.
2. (F, L) Press Right twice. Shot `loupe-step`. Expect "3 of 24".
3. (F, L) View > Actual Size (Command-1). Shot `loupe-100`. Expect the
   value to contain `100%`.
4. (F, L) Scroll the photo 200 pt left. Shot `loupe-pan`. Expect the photo
   frame's x moved left by 200 (±2).
5. (F, L) View > Zoom to Fit (Command-0); press End, then Home. Expect "24
   of 24", then "1 of 24". Right twice; Escape. Shot `loupe-grid`. Expect
   the grid with `IMG_0003` selected.
States: loading (`preview` before `full`); error (a failed render keeps the
last picture: a Model test, `LibraryLoupeImageTests`; the visible error
line is develop's J5 step 8).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Loupe | no photo shown: the grid (the loupe can't open on nothing) | a render failed: the last picture stays, `loupeError` holds "Couldn't render this photo: …" (shown under the histogram by develop in wave 3; in wave 2 as the loupe photo's help); with no earlier picture, the placeholder (the photo's size in `canvasSurround` with its name) | `preview` (the grid thumbnail scaled up) until the `full` render of the current token arrives; with no thumbnail yet, the placeholder |
| View menu | in the grid: Zoom In and Zoom Out read Larger and Smaller Thumbnails; Zoom to Fit and Actual Size are disabled with "Open a photo in the loupe to zoom." | – | – |

Snapshots (`LibraryLoupeSnapshots.swift`, existing): `library-loupe-fit`,
`library-loupe-preview`, `library-loupe-100`, `library-loupe-100-panned`,
Light and Dark (the existing `library-loupe-*` shots are redrawn on the
real photo size).

## Contract slice

From the spine: `LoupeImaging`, `RenderedPhoto`, `RenderQuality`, the stored
`loupeZoom`, `loupeRender`, `loupeRenderToken`, `loupeError`, `thumbnails`,
the readout `loupeValue`, and `LibraryMenu.view`. This feature adds:

```swift
// LoupeZoom.swift
extension LoupeZoom {
    public static let steps: [Double] = [0.125, 0.25, 0.5, 1, 2, 4, 8]
    /// The scale this zoom draws at, for a fit scale the view measured.
    public func scale(fit: Double) -> Double
}
extension LibraryCatalog {
    public mutating func zoomLoupe(_ zoom: LoupeZoom)
    /// The next step above (positive) or below the current scale; fit counts as its scale.
    public mutating func stepZoom(by steps: Int, fitScale: Double)
    /// "Larger Thumbnails" in the grid, "Zoom In" in the loupe (and Smaller, Zoom Out).
    public var zoomInTitle: String { get }; public var zoomOutTitle: String { get }
}
// LibraryLoupeImage.swift
public struct LoupeRequest: Sendable, Hashable { photo: PhotoItem; settings: DevelopSettings; longSide: Int; quality: RenderQuality; token: Int }
extension LibraryCatalog {
    /// After the loupe's photo changes: the grid thumbnail as a `.preview` render
    /// (or nil), no error, a new token; the zoom stays (stepping at 100% compares focus).
    public mutating func loupeFocusChanged()
    /// The render the loupe needs now at `longSide`, under a new token; nil outside the loupe.
    public mutating func loupeRequest(longSide: Int, quality: RenderQuality) -> LoupeRequest?
    /// Shown only for the current token (latest wins); a `.preview` never replaces a `.full` of the same token.
    public mutating func showLoupeRender(_ render: RenderedPhoto, token: Int)
    /// Keeps the last picture; sets `loupeError` for the current token only.
    public mutating func failLoupeRender(_ error: LibraryError, token: Int)
    /// The photos before and after the loupe's in `order`.
    public func neighboursToPrefetch() -> [PhotoItem]
}
// LoupeState.swift
extension LibraryCatalog {
    public mutating func showFirstInLoupe(); public mutating func showLastInLoupe()
    /// "IMG_0003 · 3 of 24".
    public var loupeReadout: String? { get }
}
// RenderQueue.swift: latest wins, at most one render running and one waiting.
public actor RenderQueue {
    public init()
    /// Runs `work` after the one running now; a submission still waiting is dropped for this one.
    public func submit(token: Int, _ work: @escaping @Sendable () async -> Void)
}
```

`LiveLoupeImaging(decoder:develop:)` replaces the spine's stub, sets
`unavailable` to nil and becomes an actor caching at most three decoded
screen-size buffers (the focused photo and its two neighbours) and their 512
px preview decodes. `LibraryCatalog.loupeArtboard` and its uses go (LV-7).
No contract signature changes.

## Pseudocode

```
loupeFocusChanged():                                            # LV-2
  loupeRenderToken += 1; loupeError = nil                       # loupeZoom stays
  loupeRender = loupeItem.flatMap { thumbnails[$0.id] }.map { RenderedPhoto($0, histogram: .empty, .preview) }
loupeRequest(longSide, quality):
  guard let photo = loupeItem else nil; loupeRenderToken += 1
  return LoupeRequest(photo, photo.develop, longSide, quality, loupeRenderToken)
showLoupeRender(r, token): guard token == loupeRenderToken else return
  if loupeRender?.quality == .full && r.quality == .preview && same token: return
  loupeRender = r; loupeError = nil
failLoupeRender(e, token): guard token == loupeRenderToken else return; loupeError = e.message

stepZoom(by n, fitScale):                                       # LV-1
  s = loupeZoom.scale(fit: fitScale)
  target = n > 0 ? steps.first { $0 > s * 1.0001 } : steps.last { $0 < s / 1.0001 }
  loupeZoom = target.map { $0 == 1 ? .actual : .scale($0) } ?? loupeZoom

RenderQueue.submit(token, work):                                # LV-3
  if running: waiting = (token, work)   # replaces an older waiting one
  else: running = true; await work(); while let w = waiting.take(): await w.work(); running = false

LiveLoupeImaging.render(photo, settings, longSide, quality):    # LV-5
  if photo.path == nil: base = SampleImage(photo, quality == .preview ? 512 : longSide)
  else base = cache[photo.id, quality] ?? decoder.decode(path, maxLongSide: quality == .preview ? 512 : longSide)
  keep cache to the last 3 photo ids touched (render or prefetch)
  buffer = try develop.render(PixelBuffer(base), settings)      # neutral stub until develop
  return RenderedPhoto(image: buffer.rgba8, histogram: try develop.histogram(of: buffer), quality)

LibraryWindow+Loupe (LV-8, macOS):
  loupeAreaFocusChanged() (the spine's onChange(of: focusedItemID) hook), in the loupe:
    model.loupeFocusChanged(); render(.full); prefetch
  LoupeAreaState (the spine's empty class in this file) gains: let queue = RenderQueue(); var fitScale = 1.0
  render(q): guard let req = model.loupeRequest(longSide: screenLongSide(px), quality: q)
    queue.submit(token: req.token) { result = try await services.loupe.render(req.photo, settings, req.longSide, q)
      -> MainActor model.showLoupeRender(result, token) | model.failLoupeRender(error, token) }
  prefetch: Task { await services.loupe.prefetch(model.neighboursToPrefetch(), longSide) }
  view: grid, loupe, setSort, sort, zoomIn/Out (loupe: stepZoom(±1, fitScale); grid: stepCellSize(±1)),
        zoomToFit, actualSize (nil in the grid), first, last (nil outside the loupe), the titles,
        zoomTo(s) -> model.zoomLoupe(|s - fitScale| < 0.0001 ? .fit : .scale(s)), fitMeasured(f) -> areas.loupe.fitScale = f
LibraryLoupe(model:menu:) (LV-7; the spine passes both, so LibraryBrowser.swift, import's in wave 2, is not edited):
  CanvasViewport(documentSize: photo.pixelSize, zoom: model.loupeZoom.scale(fit: measuredFit), checkerboard: false,
    onSize: { measure fit; menu.view.fitMeasured?(fit) }, onZoom: { menu.view.zoomTo?($0) },
    onKey: { key in Left/Right -> step(∓1/±1) .handled; Escape, G -> menu.view.grid .handled; else .ignored })
    { Image(display: loupeRender.image) or placeholder }
  (CanvasViewport takes focus once onZoom is set and pans on arrow keys unless onKey handles them first,
   CanvasViewport.swift: so onKey keeps Left and Right stepping photos; its own Command-0 arrives through
   onZoom at the fit scale, which zoomTo maps back to .fit)
  readout GlassPanel model.loupeReadout; value model.loupeValue; help photo.availability.help ?? model.loupeError
  the preview-to-full swap has no animation (and none under Reduce Motion)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: loupe-viewport`,
`Fast-Check: pass`, `Head:`. The last task to merge carries `feature-done`
(LV-10, or LV-11 when it runs).

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| LV-1 | #724 (part) | Zoom: fit, actual, steps, titles | `Sources/LibraryModel/LoupeZoom.swift`, `Tests/LibraryModelTests/LibraryLoupeZoomTests.swift` | spine |
| LV-2 | – | The loupe's picture state: focus change, requests, latest wins, failures, neighbours | `Sources/LibraryModel/LibraryLoupeImage.swift`, `Tests/LibraryModelTests/LibraryLoupeImageTests.swift` | spine |
| LV-3 | – | `RenderQueue`: one running, the latest waiting | `Sources/LibraryModel/RenderQueue.swift`, `Tests/LibraryModelTests/LibraryRenderQueueTests.swift` | spine |
| LV-4 | – | Home and End; the readout with the photo's name | `Sources/LibraryModel/LoupeState.swift`, `Tests/LibraryModelTests/LibraryLoupeTests.swift` | spine |
| LV-5 | – | `LiveLoupeImaging`: decode, develop, histogram, three-photo cache, prefetch; `unavailable = nil` | `Sources/LibraryModel/Live/LiveLoupeImaging.swift`, `Tests/LibraryModelTests/LibraryLiveLoupeTests.swift` | spine |
| LV-6 | – | The loupe model budgets | `Tests/LibraryModelTests/LibraryLoupeBudgetTests.swift` | LV-2, LV-4 |
| LV-7 | #724 (part) | The loupe on `CanvasViewport` at the photo's real size; picture, placeholder, error help; remove `loupeArtboard`; snapshots | `Sources/LibraryApp/LibraryLoupe.swift`, `Sources/LibraryModel/LoupeState.swift`, `Tests/LibraryModelTests/LibraryLoupeTests.swift`, `Tests/AppSnapshotTests/LibraryLoupeSnapshots.swift` | LV-1, LV-2, LV-4 |
| LV-8 | #724 (part or closes) | The loupe area: the View menu, renders through the queue, prefetch, Home and End | `Sources/LibraryApp/LibraryWindow+Loupe.swift` | LV-3, LV-5, LV-7 |
| LV-9 | – | J3 (F) steps | `UITests/LibraryJourneyTests+Loupe.swift` | LV-8, #333; thumbnails TH-6 for step 1's slow `preview` sub-step (the preview is the held grid thumbnail) |
| LV-10 | – | J3 (L) step 1 on written files | `UITests/LibraryJourneyTests+Loupe.swift` | LV-9, import IM-6 |
| LV-11 | – | P4 `testLoupeStepLatency` with `XCTMemoryMetric` (perf, report-only) | `UITests/LibraryJourneyTests+PerfLoupe.swift` | LV-9, #330, #782 |

`LibraryLiveLoupeTests.swift` is a new test file (not in `waves.json`); no
other feature names it. LV-4 and LV-7 share `LoupeState.swift` and
`LibraryLoupeTests.swift`, stacked. LV-1 to LV-5 start side by side.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| LV-1 | `LibraryLoupeZoomTests`: from fit at 0.3, `stepZoom(by: 1)` gives `.scale(0.5)`, then `.actual`, then `.scale(2)`; at 8 another step stays 8; from `.actual`, `stepZoom(by: -1)` gives 0.5; `.fit.scale(fit: 0.3)` is 0.3; the titles read "Larger Thumbnails" in the grid and "Zoom In" in the loupe | a step skips or overshoots, or a title doesn't follow the mode |
| LV-2 | `LibraryLoupeImageTests`: `loupeFocusChanged` shows the held thumbnail as `.preview` and bumps the token; a render for an older token is dropped; a `.preview` after a `.full` of the same token is dropped; `failLoupeRender` keeps the last picture and sets "Couldn't render this photo: …"; a failure for an old token changes nothing; neighbours of the first photo are only the second | a stale render shows, a failure blanks the picture, or prefetch reaches past the ends |
| LV-3 | `LibraryRenderQueueTests`: submitting tokens 1, 2, 3 while 1 runs runs 1 then 3 and never 2; one at a time (a counter never exceeds 1) | an outdated render runs or two run at once |
| LV-4 | `LibraryLoupeTests` (existing, extended): End shows "24 of 24", Home "1 of 24"; both do nothing in the grid; the readout is "IMG_0003 · 3 of 24"; every existing loupe test passes | Home or End move in the grid, or the readout lacks the name |
| LV-5 | `LibraryLiveLoupeTests` over a counting test decoder: rendering 5 photos in turn leaves at most 3 decoded buffers (QB-LIB-8 model half); `prefetch` of the two neighbours then a render of one decodes nothing more; a sample (no path) equals `SampleImage`; neutral settings return the decode unchanged; `.preview` decodes at 512; `LiveLoupeImaging.unavailable == nil` | the cache grows past 3, prefetch is wasted, or a sample is decoded |
| LV-6 | `LibraryLoupeBudgetTests` (rows below) | a model half misses its debug gate |
| LV-7 | `LibraryLoupeSnapshots` (four states, Light and Dark); a portrait photo draws taller than wide; no source names `loupeArtboard`; on the macOS run `testLoupeStepsAndReturnsToTheGrid` still steps with Right and returns with Escape | the photo is drawn on a fixed 4032 × 3024 board, a state is missing, or the canvas swallows the arrow keys |
| LV-8 | J3 steps 2–5 on the macOS run | a menu item stays enabled with nothing to do, Home or End go nowhere, or renders pile up |
| LV-9 | J3 (F) steps 1–5 | any expectation fails |
| LV-10 | J3 step 1 (L) | a written file doesn't reach `full` within 2 s |
| LV-11 | P4 attaches ≥ 60 samples per series (steps, pan) and a peak memory value | fewer samples (invalid) |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-LIB-5 model half | `stepLoupe` on `large` with `order` cached ≤ 1 ms (0.1 ms release); `loupeFocusChanged` ≤ 1 ms | `LibraryLoupeBudgetTests.stepWithinBudget`, `.focusChangeWithinBudget` |
| QB-LIB-5 probe | the next photo's preview ≤ 2 frames late; `render-full` p95 ≤ 150 ms after the key when prefetched; report-only | P4 (LV-11) |
| QB-L1 (pan) | p95 ≤ 2 frames late while scroll-panning at 100%; report-only | P4 pan series |
| QB-LIB-8 | the loupe actor holds ≤ 3 decoded screen-size buffers; peak resident ≤ 1.5 GB stepping 24 photos | `LibraryLiveLoupeTests.holdsAtMostThreeBuffers`, P4's `XCTMemoryMetric` |
| QB-F5 | the preview-to-full swap records duration 0 under `-LibraryReduceMotion` | a P4 step relaunched with `-LibraryReduceMotion` (once #330 lands) |
| QB-V5 | four loupe states, Light and Dark | `LibraryLoupeSnapshots` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR is green: J3 and `testLoupeStepsAndReturnsToTheGrid`.
- **Audit zero new:** no `library` count over `UITests/audit-baseline.json`;
  `loupe`, `loupe-100`, `loupe-pan` add nothing (the photo at 100% overflows
  the viewport on purpose: it is clipped content, not an offscreen control).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue.
