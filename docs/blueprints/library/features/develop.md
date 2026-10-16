# Feature packet: develop

**Feature:** the inspector's Develop tab edits a photo without touching its
file: ten sliders (Exposure, Contrast, Highlights, Shadows, Whites, Blacks;
Temperature, Tint, Vibrance, Saturation), a tone curve and levels, over a
live histogram; the loupe follows a drag at preview size and settles to the
full render on release, and the grid redraws the changed photos. Copy and
paste settings and Sync from one photo to the rest of a selection are each
one undo step however many photos they touch. Show Original compares before
and after, and each slider, section and the whole panel resets.
**Line:** `line:library` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/develop`

**Covers:** #32 (closes with DV-10), #423 (closes with DV-13: render to
pixels in loupe and grid; its catalog-file half was persist's PE-2).

**Depends on:** the spine, persist, thumbnails and loupe-viewport feature
issues (all wave 1 or 2). Outside this repo's features:

- **Spine follow-up (to file, `line:library`, for the spine lead while
  #1044 is open):** "Pass the window's `menu` to `LibraryInspector`, and
  `DevelopInspector(model:menu:cropDraft:)`". The spine's stub is
  `DevelopInspector(cropDraft:)`, so the Develop tab has neither the catalog
  nor any action to call; the loupe got `LibraryLoupe(model:menu:)` for the
  same reason. Three spine files (`LibraryWindow.swift`,
  `LibraryInspector.swift`, the `DevelopInspector.swift` stub's signature),
  about 10 lines. Develop can't make the edit itself: `LibraryWindow.swift`
  is also filters-collections' (wave 5) and `LibraryInspector.swift`
  status-and-layout's (wave 3), and neither has a dependency path to
  develop. DV-9 waits on it.
- **creative-core (to file, `needs-core`):** "CoreRaster:
  `PixelBuffer.saturation(_ amount: Float)` and `vibrance(_ amount: Float)`".
  `amount` in -100...100. Saturation scales each pixel's distance from the
  grey of its own Rec. 709 luminance by `1 + amount/100`, in linear light,
  negative results clamped to 0. Vibrance does the same, weighted per pixel
  by `1 - s`, where `s` is that pixel's saturation (max minus min channel
  over max), so muted colors move more than strong ones. Both leave a
  neutral grey exactly as it was. Acceptance: at 0 each returns the input
  bit for bit; a grey pixel is unchanged by both at ±100; saturation -100
  gives a grey of the input's luminance within 1e-4; vibrance +50 moves a
  muted color's chroma more than a saturated one's; luminance is kept within
  1e-3; alpha never changes; a non-finite or out-of-range amount throws
  `RasterError.invalid`; 24 MP in under 1 s in release, like `contrast`.
  PhotoModel's local `hueSaturation` (its own `ponytail:` note says to move
  it to CoreRaster "once Library needs it too") can then use it. DV-12
  waits on this issue and on the `scripts/bump-core` PR that brings it to
  `dev`. Until then Vibrance and Saturation are disabled on the live
  services with help that names the issue (they work on the fakes).
- **creative-core, only if QB-LIB-6's Model half misses** (blueprint Q3):
  a fused pass, `PixelBuffer.developed(...)`, over every slider, the curve
  and levels in one pass over storage, equal to the chained calls within
  1e-6. Not filed unless DV-6's release budget fails.
- **SuiteUI (to file, `needs-ui`, `line:suiteui`):** S-L1 `HistogramView`
  (blueprint 6.4: three channel arrays of bin heights 0...1, two clipping
  flags with labels, 120 pt, in a well; value "Mean 0.42, highlights
  clipped") and S-L6 (an optional `onReset` on `InspectorSliderRow`, drawn
  while the value is off its default). Until S-L1 lands the tab shows the
  histogram as a text readout in a well (its value and clip labels); until
  S-L6 lands each row resets from its context menu. #782 (S-L8, the
  `render-preview` and `render-full` marks) for P3. #330 and #333 are
  closed.

No core issue for Whites, Blacks, Curve or Levels: CoreRaster's
`levels(inBlack:inWhite:gamma:outBlack:outWhite:encoding:)` and
`curves(points:encoding:)` already exist at the pinned commit (c608d4b).
Whites and Blacks are a `levels` call in sRGB values (pseudocode).

Blueprint sections: 2.2 (`library-develop`), 3 (tier 1 row 7, tier 2 row
2), 4.2 J5, 4.3 P3, 5.2 (`DevelopValues.swift`), 5.3 (`DevelopRendering`,
`LoupeImaging`), 5.6 (`copiedSettings`), 5.7 (the J5 row), 6.2 (Develop tab,
Photo menu), 6.3, 6.4 (S-L1, S-L6), 7.1 (QB-L2, QB-LIB-6), 7.4 (QB-LIB-V1 to
V3), 10.2 (Q3).

**What it fixes and what it adds.** Most-used first (blueprint 3: develop
is tier 1, copy and paste tier 2). The complaints below are the common ones
people raise about develop panels in public forums and reviews (*inferred*:
no study counts them); behaviour only, nothing copied from any app.

| Complaint | The fix here |
|---|---|
| The picture lags a slider on a large photo | a 512 px preview follows the drag, the full render lands on release (QB-LIB-6) |
| One drag fills the undo list | a drag, or a run of arrow keys on one row, is one named step |
| Pasting onto many photos needs as many undos | paste and sync are one step for every photo they touch |
| Paste or reset wipes the crop | paste never pastes a crop; Reset Develop resets adjustments only |
| You can't tell which photo Sync copies from | the button reads "Sync from IMG_0001" |
| The histogram updates only after you let go | it is drawn from each preview render, during the drag |
| Reset is all or nothing | per slider, per section, curve, levels, or everything |

From the future, cheap once settings are a value: the Paste button's help
lists what will paste ("Exposure +1.00, Contrast 13, Curve"); Show Original
compares before and after without recording a step; a multi-photo selection
shows "Mixed" per row and a drag sets every photo at once; the curve editor
draws the exact curve the render applies, sampled from the same CoreRaster
call.

No task edits `docs/c4/model.json`, `docs/design.md`,
`docs/review-rubric.md` or `waves.md`. The blueprint prose (J5's new steps,
6.2's Develop tab rows, 6.3's snapshots, 6.4's issue numbers, 7.1, 7.4's
order) changes only in DV-15, the `feature-done` task.

## Slices

A slice is the unit of done (`lead.md`, contract rule 6). DV-a to DV-c and
DV-e are Linux-only and prove themselves with a Model walk (MJ1 to MJ4, one
test method each); DV-d and DV-f are proved by J5 and P3 on a scoped macOS
run (`app=library`).

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DV-a | A catalog written before the new controls opens with them neutral, and every new field survives a save, changes the thumbnail token and moves the fake loupe's picture. | DV-1, DV-2 | MJ1 | nothing in this feature (spine, persist, thumbnails merged) |
| DV-b | Every slider, curve and levels edit, reset, copy, paste and sync acts on the right photos as one named undo step, and a drag drops the grid's stale thumbnails once, on release. | DV-3, DV-4 | MJ2 | DV-a (DV-3) |
| DV-c | The live renderer runs only the passes the settings need, in a fixed order, matches CoreRaster run by hand bit for bit, and draws the histogram of what it rendered. | DV-5, DV-6 | MJ3 | DV-a (DV-5, DV-6) |
| DV-d | In the app, the Develop tab's rows, curve, levels, histogram, Show Original, resets, Copy, Paste and Sync work on the fakes, with the loupe following each drag. | DV-7, DV-8, DV-9, DV-10 | J5 | DV-a (DV-8, DV-9); DV-b (DV-10); spine follow-up (DV-9) |
| DV-e | Vibrance and Saturation render through CoreRaster on the live services, and a grey stays grey. | DV-11, DV-12 | MJ4 | DV-c (DV-11, DV-12); creative-core issue and its bump (DV-12) |
| DV-f | On real files the developed picture survives a relaunch, the slider stays within its frame budget, and the blueprint says what shipped. | DV-13, DV-14, DV-15 | J5, P3 | DV-d (DV-13, DV-14); DV-c (DV-13, DV-14); DV-e (DV-15) |

## Journey steps

**J5 · `LibraryDevelopJourneyTests.testDevelopSlidersAndHistogram`**
(`UITests/LibraryJourneyTests+Develop.swift`, its own `XCTestCase` class,
like `+Shell.swift`; DV-7 writes it skipped, DV-10 enables the (F) steps,
DV-13 adds the (L) steps)

1. (F) Launch on `-LibraryFixture shoot`. (L) Live on `writeShoot` with
   `-LibraryImportOnLaunch`. Both with `-LibraryTestValues`. View > Sort By
   > Name; open `IMG_0001` in the loupe; click the inspector's **Develop**
   tab. Shot `develop`. Expect `library.develop.histogram` (value
   `mean 0.…`); TONE rows Exposure, Contrast, Highlights, Shadows, Whites,
   Blacks and COLOR rows Temperature, Tint, Vibrance, Saturation, all 0;
   the CURVE section (`library.develop.curve`, two points) and the LEVELS
   rows. (L, before DV-12) Vibrance and Saturation are disabled and their
   help names the creative-core issue. Note the loupe checksum. (DV-10)
2. (F, L) Drag Exposure right. Shot `develop-exposure`. Expect the row's
   value above 0, the loupe checksum changed and the histogram's mean up.
   Edit's Undo reads "Undo Exposure"; one Undo puts Exposure back to 0 (a
   drag is one step); Redo. (DV-10)
3. (F, L) Focus Contrast; press Right three times, then Shift-Right. Expect
   3, then 13. (DV-10)
4. (F, L) Undo reads "Undo Contrast"; undo once; Contrast reads 3. (DV-10)
5. (F, L) Click **Show Original** (`library.develop.original`; or press
   `\` while the tab shows). Shot `develop-original`. Expect the loupe
   checksum equal to step 1's and Undo still "Undo Contrast". Click it
   again: the developed checksum is back. (DV-10)
6. (F, L) In the curve, click at the middle and drag up 40 pt. Shot
   `develop-curve`. Expect three points, the checksum changed, Undo "Undo
   Curve". Set LEVELS' Midtones to 1.20: Undo "Undo Levels". (DV-10)
7. (F, L) Click the photo (focus leaves the curve); Photo > Copy Settings
   (Shift-Command-C); Escape to the grid; click `IMG_0002`, Shift-click
   `IMG_0004`; Photo > Paste Settings (Shift-Command-V). Shot
   `develop-pasted`. Expect Undo "Undo Paste Settings"; open `IMG_0003`:
   its Exposure equals `IMG_0001`'s; Escape; one Undo; open `IMG_0003`
   again: Exposure 0 (all three came back in one step). (DV-10)
8. (F, L) Escape; click `IMG_0001`, Shift-click `IMG_0006`. Expect
   **Sync from IMG_0001** (`library.develop.sync`); click it. Shot
   `develop-synced`. Expect the inspector's rows no longer "Mixed" and Undo
   "Undo Sync Settings". (DV-10)
9. (F, L) Open `IMG_0001`; right-click the Exposure row, choose **Reset
   Exposure**: Undo "Undo Reset Exposure". Click TONE's Reset: its six rows
   at 0, Undo "Undo Reset Tone". (A reset button inside the row waits on
   S-L6.) (DV-10)
10. (L) Set Exposure to +1 on `IMG_0001`; note the checksum; wait for
    `library.catalog` = `saved`; terminate and relaunch on the same
    `-LibraryCatalogDir`; open `IMG_0001`. Expect Exposure +1 and the same
    checksum. Escape: `IMG_0001`'s cell value is `ready` again within 2 s
    (the grid redrew it). (DV-13)
11. (F) Relaunch with `-LibraryFakeMode fail`; open a photo; Develop tab.
    Shot `develop-error`. Expect "Couldn't render this photo: the preview
    failed on purpose." (`library.develop.error`) under the histogram and
    the loupe's placeholder. (DV-10)

States: empty (no photo selected and not in the loupe: "Select a photo to
develop it." and every control disabled); loading (`preview` while a render
runs); error (render failed); mixed (several photos selected).

**P3 · `LibraryPerfDevelopJourneyTests.testDevelopSliderLatency`**
(`UITests/LibraryJourneyTests+PerfDevelop.swift`, DV-14; L on `writeShoot`,
`-LibraryPerfProbe`): open `IMG_0001` (6000 × 4000), Develop tab, velocity
drag on Exposure across its range three times. Attaches
`perf-testDevelopSliderLatency.json`; asserts only ≥ 60 samples per series
(the bar's marker, `render-preview`) and one `render-full` mark after each
release (report-only, rubric 6).

**Model walks** (Linux, in a test file the slice owns):

- **MJ1** `LibraryDevelopValuesTests.testOldCatalogAndNewFieldsWalk`
  (DV-1 writes it, its last two checks disabled until DV-2): persist's golden catalog text (`LibraryPersistGolden.catalogV1`)
  decodes through `LiveCatalogCoding` with every new field neutral and
  re-encodes byte-equal; set Whites 20, Saturation -10, a three-point curve
  and Midtones 1.2 on one photo; encode, decode: equal; its
  `ThumbnailToken` differs from the neutral photo's; `FakeLoupe`'s render of
  it differs from the neutral render.
- **MJ2** `LibraryDevelopTests.testDevelopEditsWalk` (DV-2 writes it
  skipped, DV-4 enables it): on `shoot` with fakes, open `IMG_0001`; 20
  Exposure samples under one key, then `endDevelopDrag()`: one step
  "Exposure", the photo's held thumbnail dropped; copy, select
  `IMG_0002`–`IMG_0004` in the grid, paste: one step, three photos, crop
  kept; undo: all three neutral; select `IMG_0001`–`IMG_0006`, sync: one
  step "Sync Settings"; reset TONE on `IMG_0001`: "Reset Tone", COLOR
  untouched.
- **MJ3** `LibraryDevelopRenderTests.testRenderWalk` (DV-5 writes it
  disabled, DV-6 enables it): a 64 × 48 gradient through `LiveDevelop` at
  neutral comes back equal with no passes; with every control set (but
  Vibrance and Saturation) it equals the CoreRaster calls run by hand in the
  pass order; its histogram equals `Histogram(of:bins:256,encoding:.sRGB)`
  of the result.
- **MJ4** `LibraryDevelopColorTests.testVibranceSaturationWalk` (DV-11
  writes it disabled, DV-12 enables it): a grey stays the same grey at
  Vibrance and Saturation ±100; Saturation -100 makes a red patch grey of
  its luminance; `LiveDevelop.waiting` is empty and
  `sliderHelp(.vibrance)` is nil on `.live`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Develop tab | nothing selected and not in the loupe: `EmptyStateView` "Develop", message "Select a photo to develop it." (`developHelp`), no controls | `developError` (the loupe's `loupeError`) in a line under the histogram (`library.develop.error`); the rows stay usable | the histogram readout keeps the last render's values while the next renders |
| Develop tab, several photos | – | – | – (each differing row reads "Mixed", the bar's `mixed:`) |
| Loupe | – | the last picture stays (loupe-viewport) | `preview` during a drag, `full` after release |
| Grid | – | – | a changed photo keeps its old thumbnail until release, then reloads |

Snapshots (`Tests/AppSnapshotTests/`, Light and Dark, from fixtures on the
fakes): `LibraryDevelopSnapshots.swift` draws `library-develop` (one photo,
Exposure +0.50, Contrast 13), `library-develop-mixed` (three photos, Exposure
differing), `library-develop-error`, `library-develop-empty` (DV-9) and
`library-develop-curve` (a three-point curve, Midtones 1.20) (DV-10).
`LibraryDevelopRenderSnapshots.swift` draws `library-develop-render`: the
loupe and the tab over a live render of the `shoot` gradient at Exposure +1
(DV-13). The QB-F5 Increase Contrast goldens for the clipping labels wait on
#331 and #332, as the blueprint says.

Audit: every new control carries a `library.develop.*` identifier through
`.libraryControl(id:enabled:help:)` and a name; J5's shots add nothing to
the `library` baseline.

## Contract slice

From the spine: `DevelopSlider`, `DevelopGroup`, `DevelopSettings`
(`setting(_:to:)`, `pastingAdjustments(from:)`), `HistogramBins`,
`RenderedPhoto`, `DevelopRendering`, `LoupeImaging`, `copiedSettings`,
`loupeError`, `histogramValue`, `recordEdit(_:coalesceKey:ids:_:)`,
`MetadataValue`, `LibraryMenu.Photo` (Copy Settings, Paste Settings, Reset
Develop). From thumbnails: `ThumbnailToken`, `invalidateThumbnail(_:)`.
From loupe-viewport: `loupeRequest(longSide:quality:)`, `LoupeRequest`,
`showLoupeRender(_:token:)`, `failLoupeRender(_:token:)`, the loupe area's
`render(_:)` and `RenderQueue` (LV-8).

**DV-1, `Sources/LibraryModel/Contracts/DevelopValues.swift`:**

```swift
public enum DevelopSlider: String, CaseIterable, Sendable, Codable {
    case exposure = "Exposure", contrast = "Contrast", highlights = "Highlights", shadows = "Shadows"
    case whites = "Whites", blacks = "Blacks"                       // new, TONE
    case temperature = "Temperature", tint = "Tint"
    case vibrance = "Vibrance", saturation = "Saturation"           // new, COLOR
    // group: the first six .tone, the last four .color; range: exposure -5...5, the rest -100...100
}

/// One point of the tone curve, both coordinates sRGB values in 0...1.
public struct DevelopCurvePoint: Hashable, Sendable, Codable {
    public var x: Double, y: Double
    public init(x: Double, y: Double)
}

public struct ToneCurve: Hashable, Sendable, Codable {
    public static let identity: ToneCurve          // (0, 0) and (1, 1)
    public static let maxPoints = 16
    public static let minGap = 0.01                 // in x
    public private(set) var points: [DevelopCurvePoint]
    /// Sorted by x; coordinates clamped to 0...1; the first point's x set to 0 and
    /// the last's to 1; a point closer than `minGap` in x to the one before it is
    /// dropped; at most `maxPoints`. Nil for fewer than 2 finite points.
    public init?(points: [DevelopCurvePoint])
    public var isIdentity: Bool { get }             // every point on y == x
    /// The curve at `count` evenly spaced values in 0...1: CoreRaster's
    /// `curves(points:encoding: .sRGB)` run on a `count`-pixel grey ramp of
    /// those values, the same call LiveDevelop makes. Empty for `count` < 2.
    public func samples(count: Int = 256) -> [DevelopCurvePoint]
}

public struct DevelopLevels: Hashable, Sendable, Codable {
    /// The raw value is the row's label.
    public enum Field: String, CaseIterable, Sendable {
        case inBlack = "Black Point", gamma = "Midtones", inWhite = "White Point"
        case outBlack = "Output Black", outWhite = "Output White"
    }
    public static let neutral = DevelopLevels()
    public static let gammaRange: ClosedRange<Double> = 0.1...9.99
    /// sRGB values in 0...1 (the rows show them as 0...255); gamma over 1 brightens.
    public private(set) var inBlack = 0.0, inWhite = 1.0, gamma = 1.0, outBlack = 0.0, outWhite = 1.0
    public init()
    public func value(_ field: Field) -> Double
    /// Clamped to the field's range; NaN or infinity gives the neutral value. The
    /// black and white points stay at least 1/255 apart: the one being moved stops there.
    public func setting(_ field: Field, to value: Double) -> DevelopLevels
}

public struct DevelopSettings {   // the spine's struct, grown
    public private(set) var whites = 0.0, blacks = 0.0, vibrance = 0.0, saturation = 0.0
    public private(set) var curve = ToneCurve.identity
    public private(set) var levels = DevelopLevels.neutral
    public func setting(curve: ToneCurve) -> DevelopSettings
    public func setting(levels: DevelopLevels) -> DevelopSettings
    // isAdjustmentNeutral also needs an identity curve and neutral levels;
    // pastingAdjustments(from:) already copies every field but the crop.
    /// FNV-1a over the settings' sorted-key JSON (below): every field, so any edit
    /// changes it. Deterministic across processes (never `hashValue`).
    public var fingerprint: UInt64 { get }
    // Codable by hand: the six original slider keys always, `crop` when set (as
    // the synthesized coding did, so persist's golden stays byte-equal), and
    // `whites`, `blacks`, `vibrance`, `saturation`, `curve`, `levels` only when
    // off their default; a missing key decodes as its default.
}
```

DV-2 points `ThumbnailToken.of(_:longSide:)` (thumbnails'
`LibraryThumbnails.swift`) at `settings.fingerprint`, one line, so a curve
or levels edit changes the token; and makes `FakeLoupe`
(`Fakes/FakeRendering.swift`) lift one byte level per curve point off the
diagonal and per levels field off neutral, so a fake curve or levels edit
moves the picture as slider steps already do.

**DV-2, `Sources/LibraryModel/LibraryDevelop.swift`** (DV-2 lands every
signature with a body that changes nothing; DV-3 and DV-4 fill them):

```swift
extension LibraryCatalog {
    /// The loupe photo in the loupe, else the selection.
    public var developTargets: Set<String> { get }
    /// "Select a photo to develop it." with no targets, else nil.
    public var developHelp: String? { get }
    /// Why `slider` can't change on these services: on the live services,
    /// `LiveDevelop.waiting[slider]`; nil on the fakes and once it renders.
    public func sliderHelp(_ slider: DevelopSlider) -> String?
    /// The targets' value, "Mixed" when they differ; nil with no targets.
    public func developValue(_ slider: DevelopSlider) -> MetadataValue<Double>?
    public var developCurve: MetadataValue<ToneCurve>? { get }
    public var developLevels: MetadataValue<DevelopLevels>? { get }

    /// Every target to `value` (clamped). Edits sharing an open `coalesceKey`
    /// (one drag, "develop-exposure") are one step named after the slider.
    public mutating func setDevelop(_ slider: DevelopSlider, to value: Double, coalesceKey: String?)
    public mutating func setCurve(_ points: [DevelopCurvePoint], coalesceKey: String?)   // step "Curve"; nil curve: ignored
    public mutating func setLevels(_ field: DevelopLevels.Field, to value: Double, coalesceKey: String?)  // "Levels"
    /// Ends the gesture: the next edit is a new step. Drops the held thumbnails
    /// of the photos the gesture changed and returns their ids.
    @discardableResult public mutating func endDevelopDrag() -> Set<String>
    /// nil: every adjustment ("Reset Develop"), never the crop; .tone or .color: "Reset Tone", "Reset Color".
    @discardableResult public mutating func resetDevelop(_ group: DevelopGroup?) -> Set<String>
    @discardableResult public mutating func resetDevelop(_ slider: DevelopSlider) -> Set<String>  // "Reset Exposure"
    @discardableResult public mutating func resetCurve() -> Set<String>     // "Reset Curve"
    @discardableResult public mutating func resetLevels() -> Set<String>    // "Reset Levels"

    /// The loupe photo's settings, else the single selected photo's; nothing with 0 or several.
    public mutating func copySettings()
    public var canPasteSettings: Bool { get }   // copied settings and at least one target
    /// "Exposure +1.00, Contrast 13, Curve": the copied settings off neutral, in panel order.
    public var copiedSummary: String? { get }
    /// The copied adjustments onto every target, keeping each one's crop: one step "Paste Settings".
    @discardableResult public mutating func pasteSettings() -> Set<String>
    /// In the grid with 2 or more selected: the first selected photo in the shown order.
    public var syncSource: PhotoItem? { get }
    public var syncTitle: String? { get }       // "Sync from IMG_0001"
    /// The source's adjustments onto the rest of the selection, crops kept: one step "Sync Settings".
    @discardableResult public mutating func syncSettings() -> Set<String>

    public var developError: String? { get }    // loupeError
    public var histogramClips: [String] { get } // "Shadows clipped", "Highlights clipped" while any pixel clips
    /// The loupe histogram's three channels summed per bin, scaled 0...1, for the curve's backdrop.
    public var curveHistogram: [Double] { get }
}
```

**DV-6, `Sources/LibraryModel/Live/LiveDevelop.swift`** (replaces the
spine's stub; `unavailable` becomes nil; the `DevelopRendering` signature
is unchanged):

```swift
public struct LiveDevelop: DevelopRendering {
    public static let unavailable: String? = nil
    /// Sliders the live renderer can't draw yet, with the reason the row shows.
    /// DV-6: Vibrance and Saturation, "… waits on creative-core#<n>."; DV-12 empties it.
    public static let waiting: [DevelopSlider: String]
    /// The CoreRaster calls `settings` needs, in render order; empty when neutral.
    public enum Pass: Hashable, Sendable {
        case whiteBalance(temperature: Float, tint: Float), exposure(Float), contrast(Float)
        case highlightsShadows(highlights: Float, shadows: Float)
        case whitesBlacks(inBlack: Float, inWhite: Float, outBlack: Float, outWhite: Float)
        case color(vibrance: Float, saturation: Float)                  // DV-12
        case curve([DevelopCurvePoint]), levels(DevelopLevels)
    }
    public static func passes(for settings: DevelopSettings) -> [Pass]
    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer
    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins
}
```

**DV-8, `Sources/LibraryApp/LibraryMenus.swift`** (the spine's file):
`LibraryMenu.Photo` gains `var develop = Develop()`, so the develop area
fills it inside `developMenu` and the window's merge with the crop half
keeps it without an edit:

```swift
struct Develop {
    var set: (@MainActor (DevelopSlider, Double) -> Void)?
    var setCurve: (@MainActor ([DevelopCurvePoint]) -> Void)?
    var setLevels: (@MainActor (DevelopLevels.Field, Double) -> Void)?
    var endEdit: Action?                          // a row's or the curve's onEnd
    var reset: (@MainActor (DevelopGroup?) -> Void)?
    var resetSlider: (@MainActor (DevelopSlider) -> Void)?
    var resetCurve: Action?
    var resetLevels: Action?
    var sync: Action?
    var syncTitle: String?
    var toggleOriginal: Action?
    var showsOriginal = false
}
```

No new menu item and no new single key: Copy Settings, Paste Settings and
Reset Develop are the spine's Photo items; Sync, Show Original and the
resets live in the tab (filters-collections owns `LibraryCommands.swift` in
wave 5 with no path to develop, and `LibraryKeys.swift` is the spine's).
Show Original's `\` is a `.keyboardShortcut` on its button, so it works
while the Develop tab shows.

## Pseudocode

```
DevelopSettings.encode(to:):                                        # DV-1
  encode exposure, contrast, highlights, shadows, temperature, tint     # always, as today
  encodeIfPresent crop
  for each of whites, blacks, vibrance, saturation: if != 0 encode
  if !curve.isIdentity encode curve; if levels != .neutral encode levels
init(from:): each new key decodeIfPresent ?? default; the six old keys decode as today
fingerprint: FNV-1a 64 over JSONEncoder([.sortedKeys]).encode(self) bytes
ThumbnailToken.of(settings, longSide): FNV-1a(settings.fingerprint, longSide)   # was field by field

setDevelop(slider, value, key):                                     # DV-3
  ids = developTargets; guard !ids.isEmpty, sliderHelp(slider) == nil else return
  recordEdit(slider.rawValue, coalesceKey: key, ids: ids) { $0.develop = $0.develop.setting(slider, to: value) }
  # no thumbnail work per sample: the grid keeps its picture until release
setCurve(points, key): guard let curve = ToneCurve(points: points) else return
  recordEdit("Curve", coalesceKey: key, ids: developTargets) { $0.develop = $0.develop.setting(curve: curve) }
setLevels(field, value, key): recordEdit("Levels", ...) { $0.develop = $0.develop.setting(levels: $0.develop.levels.setting(field, to: value)) }
endDevelopDrag():
  ids = history.open ? Set(history.top?.after.map(\.id) ?? []) : []
  endCoalescing(); ids.forEach(invalidateThumbnail); return ids
resetDevelop(group): sliders = group?.sliders ?? DevelopSlider.allCases
  name = group.map { "Reset " + $0.rawValue } ?? "Reset Develop"
  recordEdit(name, ids: developTargets) { photo in
    for s in sliders { photo.develop = photo.develop.setting(s, to: 0) }
    if group == nil { photo.develop = photo.develop.setting(curve: .identity).setting(levels: .neutral) } }
  endCoalescing(); invalidate the changed ids; return them

copySettings():                                                     # DV-4
  source = loupeItem ?? (selection.count == 1 ? the selected photo : nil); guard source
  copiedSettings = source.develop                       # not undoable, no saveRevision bump
pasteSettings(): guard let copied = copiedSettings, !developTargets.isEmpty
  recordEdit("Paste Settings", ids: developTargets) { $0.develop = $0.develop.pastingAdjustments(from: copied) }
  endCoalescing(); invalidate and return the changed ids      # ONE recordEdit over the set: one step
syncSource: guard mode == .grid, selection.count >= 2; return order.first(where: selection.contains) as a PhotoItem
syncSettings(): guard let source = syncSource
  recordEdit("Sync Settings", ids: selection.subtracting([source.id])) { $0.develop = $0.develop.pastingAdjustments(from: source.develop) }
developValue(slider): MetadataValue.of(targets.map { $0.develop.value(slider) })   # the spine's helper

LiveDevelop.passes(settings):                                       # DV-6
  p = []
  if temperature != 0 || tint != 0: p += .whiteBalance
  if exposure != 0: p += .exposure;  if contrast != 0: p += .contrast
  if highlights != 0 || shadows != 0: p += .highlightsShadows
  if whites != 0 || blacks != 0:                        # sRGB values; at most a quarter of the range
     inWhite = whites > 0 ? 1 - 0.25*whites/100 : 1;  outWhite = whites < 0 ? 1 + 0.25*whites/100 : 1
     inBlack = blacks < 0 ? 0.25*(-blacks)/100 : 0;   outBlack = blacks > 0 ? 0.25*blacks/100 : 0
     p += .whitesBlacks(inBlack, inWhite, outBlack, outWhite)   # inBlack ≤ 0.25 < 0.75 ≤ inWhite: never throws
  (DV-12) if vibrance != 0 || saturation != 0: p += .color
  if !curve.isIdentity: p += .curve;  if levels != .neutral: p += .levels
  return p
render(buffer, settings):
  for s in DevelopSlider.allCases where settings.value(s) != 0: if let why = Self.waiting[s] { throw .renderFailed(why) }
  var b = buffer
  for pass in passes(settings): b = try b.<the CoreRaster call>      # whitesBlacks, curve, levels with encoding: .sRGB, gamma 1 for whitesBlacks
  return b                                                            # neutral: the input itself, untouched
histogram(of b): h = try Histogram(of: b, bins: 256, encoding: .sRGB)
  return HistogramBins(red: h.red, green: h.green, blue: h.blue, shadowClipped: h.shadowClipped, highlightClipped: h.highlightClipped)

LibraryWindow+Develop (DV-8, macOS):
  @Observable final class DevelopAreaState { var originalPhotoID: String? }   # presentation state, like the inspector's tab
  showsOriginal = areas.develop.originalPhotoID != nil && areas.develop.originalPhotoID == model.focusedItemID
     # stepping to another photo ends it with no edit outside develop's files
  developMenu: Photo(copySettings: copy ? {...} : nil, pasteSettings: model.canPasteSettings ? {...} : nil,
                     resetDevelop: targets ? { finish(model.resetDevelop(nil)) } : nil,
                     develop: Develop(set: { s, v in model.setDevelop(s, to: v, coalesceKey: "develop-\(s)"); preview() },
                                      setCurve: { model.setCurve($0, coalesceKey: "develop-curve"); preview() },
                                      setLevels: { f, v in model.setLevels(f, to: v, coalesceKey: "develop-levels"); preview() },
                                      endEdit: { finish(model.endDevelopDrag()) },
                                      reset/resetSlider/resetCurve/resetLevels/sync: { finish(model.…) },
                                      syncTitle: model.syncTitle, toggleOriginal: inLoupe ? { toggle() } : nil,
                                      showsOriginal: showsOriginal))
  every action above is nil when developHelp != nil
  preview(): areas.develop.originalPhotoID = nil; if model.mode == .loupe { render(.preview) }   # LV-8's render, through its queue
  finish(ids): if model.mode == .loupe { render(.full) }
     Task { for id in ids { await services.thumbnails.invalidate(id) }; refreshThumbnails() }
  toggle(): areas.develop.originalPhotoID = showsOriginal ? nil : model.focusedItemID
     if now on: guard let req = model.loupeRequest(longSide: screen px, quality: .full)
            areas.loupe.queue.submit(token: req.token) { render req.photo with
              DevelopSettings.neutral.setting(crop: req.settings.crop) -> showLoupeRender / failLoupeRender }
     else: render(.full)
LibraryWindow+Thumbnails (DV-8 adds, thumbnails' file):
  ThumbnailsAreaState keeps the last ids visibleChanged received (var visible: [String] = [])
  refreshThumbnails(): run visibleChanged's request loop again on `visible`   # cells a paste or a drag
     # invalidated show `loading` until then; TH-6 alone re-requests only on a scroll or a size change

DevelopInspector(model:menu:cropDraft:) (DV-9, DV-10; values in, closures out):
  cropDraft set: CropInspector(cropDraft:) as today
  developHelp != nil: EmptyStateView("Develop", systemImage: "slider.horizontal.3", message: developHelp)
  histogram well (until S-L1): model.histogramValue and histogramClips as text, value histogramValue, id library.develop.histogram
  developError line (library.develop.error)
  InspectorSection("Tone", onReset: tone off 0 ? { menu.reset?(.tone) } : nil), same for "Color"
    InspectorSliderRow(s.rawValue, value: developValue(s).shared ?? 0, in: s.range, step: s.step,
      unit: s == .exposure ? "EV" : "", decimals: s == .exposure ? 2 : 0, mixed: developValue(s) == .mixed,
      onChange: { menu.set?(s, $0) }, onEnd: { menu.endEdit?() })
      .contextMenu { Button("Reset \(s.rawValue)") { menu.resetSlider?(s) } }
      .libraryControl(id: "library.develop.\(s.rawValue.lowercased())", enabled: menu.set != nil && sliderHelp(s) == nil, help: sliderHelp(s))
  Show Original button (library.develop.original, `\`), Sync button titled syncTitle (library.develop.sync), Paste help copiedSummary
  (DV-10) InspectorSection("Curve", onReset:) ToneCurveEditor(points:, samples: curve.samples(), histogram: curveHistogram,
            id: "library.develop.curve", onChange: { menu.setCurve?($0.map { DevelopCurvePoint(x: $0.x, y: $0.y) }) }, onEnd: { menu.endEdit?() })
          InspectorSection("Levels", onReset:) a row per Field, 0...255 whole numbers (gamma 0.10...9.99, two places)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: develop`,
`Slice: <slice>`, `Fast-Check: pass`, `Head:`, and for a task that changes
planned Model code a `Mutate:` line (`lead.md`, contract rule 14). DV-15
carries `feature-done`. Mutation plans are `Tests/mutations/<Target>.<File>.json`.
A task that measures over 400 lines splits by file before it opens.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DV-1 | #32 (part) | The new sliders, `ToneCurve`, `DevelopLevels`, back-compatible coding, `fingerprint`; MJ1's coding half | `Sources/LibraryModel/Contracts/DevelopValues.swift`, `Tests/LibraryModelTests/LibraryDevelopValuesTests.swift`, `Tests/mutations/LibraryModel.DevelopValues.json` | spine, persist PE-2 | ~320, 3 |
| DV-2 | – | The slots: every `LibraryDevelop.swift` signature with a body that changes nothing; the thumbnail token over `fingerprint`; the fake loupe lifts for curve and levels (MJ1's last two checks); all of `LibraryDevelopTests` and MJ2, disabled | `Sources/LibraryModel/LibraryDevelop.swift`, `Sources/LibraryModel/LibraryThumbnails.swift` (the token line), `Sources/LibraryModel/Fakes/FakeRendering.swift`, `Tests/LibraryModelTests/LibraryDevelopTests.swift`, `Tests/LibraryModelTests/LibraryDevelopValuesTests.swift`, `Tests/mutations/LibraryModel.LibraryThumbnails.json`, `Tests/mutations/LibraryModel.FakeRendering.json` | DV-1, thumbnails TH-1 | ~380, 7 |
| DV-3 | #32 (part) | Slider, curve and levels edits with coalescing, `endDevelopDrag`, the resets, the helps, mixed values | `Sources/LibraryModel/LibraryDevelop.swift`, `Tests/LibraryModelTests/LibraryDevelopTests.swift`, `Tests/mutations/LibraryModel.LibraryDevelop.json` | DV-2 | ~220, 3 |
| DV-4 | #32 (part) | Copy, paste and sync as one step, `copiedSummary`, the histogram helpers; MJ2 enabled | `Sources/LibraryModel/LibraryDevelop.swift`, `Tests/LibraryModelTests/LibraryDevelopTests.swift`, `Tests/mutations/LibraryModel.LibraryDevelop.json` | DV-3 | ~180, 3 |
| DV-5 | – | The render and budget checks, disabled until DV-6: QB-LIB-V1 to V3, the pass list, MJ3, QB-L2 and QB-LIB-6's Model half | `Tests/LibraryModelTests/LibraryDevelopRenderTests.swift`, `Tests/LibraryModelTests/LibraryDevelopBudgetTests.swift` | DV-1 | ~300, 2 |
| DV-6 | #423 (part) | `LiveDevelop`: the pass list, the CoreRaster calls, neutral untouched, the histogram, `waiting`; `unavailable = nil`; enables DV-5's tests | `Sources/LibraryModel/Live/LiveDevelop.swift`, `Tests/LibraryModelTests/LibraryDevelopRenderTests.swift`, `Tests/LibraryModelTests/LibraryDevelopBudgetTests.swift`, `Tests/mutations/LibraryModel.LiveDevelop.json` | DV-5 | ~200, 4 |
| DV-7 | – | J5 written from this packet, `throw XCTSkip("waits on DV-10")` (and "waits on DV-13" on step 10) | `UITests/LibraryJourneyTests+Develop.swift` | – | ~260, 1 |
| DV-8 | – | `LibraryMenu.Develop`; the develop area: menu closures, preview and full loupe renders through LV-8's queue, Show Original, thumbnails redrawn on release (`refreshThumbnails` in the thumbnails area) | `Sources/LibraryApp/LibraryMenus.swift`, `Sources/LibraryApp/LibraryWindow+Develop.swift`, `Sources/LibraryApp/LibraryWindow+Thumbnails.swift` (`visible` and `refreshThumbnails` only) | DV-2, loupe-viewport LV-8, thumbnails TH-6 | ~240, 3 |
| DV-9 | #32 (part) | The Develop tab: histogram readout, TONE and COLOR rows with Mixed, section and row resets, Show Original, Sync, Paste help, error, empty; four snapshots | `Sources/LibraryApp/DevelopInspector.swift`, `Tests/AppSnapshotTests/LibraryDevelopSnapshots.swift` | DV-8, spine follow-up (inspector pass-through) | ~320, 2 |
| DV-10 | #32 (closes) | CURVE (`ToneCurveEditor`) and LEVELS sections; `library-develop-curve`; J5's (F) steps enabled | `Sources/LibraryApp/DevelopInspector.swift`, `Tests/AppSnapshotTests/LibraryDevelopSnapshots.swift`, `UITests/LibraryJourneyTests+Develop.swift` | DV-4, DV-7, DV-9 | ~240, 3 |
| DV-11 | – | Vibrance and Saturation checks and MJ4, disabled until DV-12 | `Tests/LibraryModelTests/LibraryDevelopColorTests.swift` | DV-6 | ~140, 1 |
| DV-12 | – | The `.color` pass over CoreRaster's `vibrance` and `saturation`; `waiting` emptied; MJ4 enabled; DV-6's "Vibrance throws" check becomes "every control set" | `Sources/LibraryModel/Live/LiveDevelop.swift`, `Tests/LibraryModelTests/LibraryDevelopColorTests.swift`, `Tests/LibraryModelTests/LibraryDevelopRenderTests.swift`, `Tests/mutations/LibraryModel.LiveDevelop.json` | DV-11, the creative-core issue and its bump on `dev` | ~120, 4 |
| DV-13 | #423 (closes) | J5's (L) steps (relaunch, grid redraw); `library-develop-render` over a live render | `UITests/LibraryJourneyTests+Develop.swift`, `Tests/AppSnapshotTests/LibraryDevelopRenderSnapshots.swift` | DV-6, DV-10, import IM-6 | ~160, 2 |
| DV-14 | – | P3 `testDevelopSliderLatency` (perf, report-only) | `UITests/LibraryJourneyTests+PerfDevelop.swift` | DV-6, DV-9, #782, import IM-6 | ~130, 1 |
| DV-15 | – | Blueprint prose: 5's note that `Sources/LibraryModel/Contracts/DevelopValues.swift` supersedes `docs/blueprints/library/contracts/`' copy, 5.7's J5 row, J5's steps, 6.2's Develop rows, 6.3, 6.4's S-L1 and S-L6 numbers, 7.1's pass list, 7.4's order, 8.2's depends cell (`persist`); `status: built` (`feature-done`) | `docs/blueprints/library.md` | DV-12, DV-13, DV-14 | ~120, 1 |

Links, under rule (b): DV-2 needs DV-1's types and shares `LibraryDevelopValuesTests.swift`; DV-2 to DV-4 share `LibraryDevelop.swift` and
`LibraryDevelopTests.swift` (the C4 plan names one `LibraryDevelop.swift`
for `library-develop`, so the file can't split into `+Area` files without a
blueprint change; see Open questions). DV-5 needs DV-1 because its tests
set the new fields; DV-6 enables DV-5's tests; DV-11 reads DV-6's
`LiveDevelop.waiting`; DV-12 and DV-6 share `LiveDevelop.swift`. DV-8
fills DV-2's signatures, not their behaviour, so it builds beside DV-3 and
DV-4 on the stub bodies. DV-9 is the view over DV-8's closures and needs
the spine follow-up to receive them; it doesn't need DV-3 or DV-4 (its
snapshots build photos with settings already set). DV-10 enables J5, whose
steps need DV-4's paste and sync and DV-9's panel; it shares two files with
DV-9 and the journey file with DV-7. DV-13 extends the journey file and
needs the live renderer. The perf journey drags DV-9's Exposure row, through
DV-8's area, on DV-6's renderer.

## Build waves

- Wave 1: DV-1, DV-7. Independent in this wave: both.
- Wave 2: DV-2, DV-5. Independent in this wave: both.
- Wave 3: DV-3, DV-6, DV-8. Independent in this wave: all three.
- Wave 4: DV-4, DV-9, DV-11. Independent in this wave: all three.
- Wave 5: DV-10, DV-12 (once the core bump is on `dev`), DV-14. Independent in this wave: all three.
- Wave 6: DV-13. Independent in this wave: DV-13 alone.
- Wave 7: DV-15 (final, `feature-done`). Independent in this wave: DV-15 alone.

Longest chain: DV-1 → DV-2 → DV-3 → DV-4 → DV-10 → DV-13 → DV-15 (7), and
DV-1 → DV-2 → DV-8 → DV-9 → DV-10 → DV-13 → DV-15 (7).
Chain of 7: DV-2 to DV-4 stack on the one `LibraryDevelop.swift` the C4
plan allows; DV-10 enables J5, which needs DV-4's paste and DV-9's panel;
DV-13 adds the live steps to DV-10's journey file; DV-15 is the
`feature-done` docs task and goes last by rule (a). The other branch is the
UI track: DV-8's closures, DV-9's view over them, DV-10 in the same view.

## Acceptance test per task

Build the check first: DV-1, DV-2, DV-5, DV-7 and DV-11 merge each slice's
checks before or with its first code task. A Model test that lands ahead of
its code is `@Test(.disabled("waits on DV-n"))`; a journey step
`throw XCTSkip("waits on DV-n")`; the named task enables it. DV-5, DV-7
and DV-11 add only checks, so they carry no mutations; DV-2's signatures
change nothing, and its two mutations cover the token and the fake.

| id | test | fails when | mutations (`swift test --filter` regex) |
|---|---|---|---|
| DV-1 | `LibraryDevelopValuesTests`: `setting(.whites, to: 900)` is 100 and `.nan` is 0; groups are TONE ×6, COLOR ×4 in panel order; `ToneCurve(points:)` sorts, clamps, pins the ends, drops a point 0.005 from its neighbour, keeps 16 of 20 and is nil for one point; `samples(count: 5)` of the identity is the diagonal and of a lifted middle point is above it at 0.5; `DevelopLevels.setting(.inBlack, to: 0.999)` stops at 1 − 1/255 below `inWhite`; `.neutral.setting(.exposure, to: 1)` encodes (sorted keys) exactly `{"contrast":0,"exposure":1,"highlights":0,"shadows":0,"temperature":0,"tint":0}`; that text decodes with every new field at its default; a settings value with every field set round-trips; `fingerprint` differs for a curve-only change and is equal across two encodes; MJ1 up to its encode and decode (its token and fake checks disabled "waits on DV-2") | an old catalog fails or gains keys, or a clamp, curve or levels rule differs | `decodeIfPresent(…whites) ?? 0` → `decode(…whites)` (`LibraryDevelopValuesTests`); drop the `whites != 0` guard on encode (`LibraryDevelopValuesTests`); curve min gap `<` → `<=` (`LibraryDevelopValuesTests`); `fingerprint` hashes only the six old sliders (`LibraryDevelopValuesTests`) |
| DV-2 | `LibraryDevelopTests` compiles against every signature in the Contract slice and each case is disabled "waits on DV-3" or "waits on DV-4"; `LibraryDevelopValuesTests` (MJ1 enabled whole): `ThumbnailToken.of` differs for a levels-only change; `FakeLoupe` renders a curve-only change and a levels-only change with other checksums; the rest of the LibraryModel suite stays green | a signature is missing or differs, or a new field misses the token or the fake picture | token back to field-by-field without `levels` (`LibraryDevelopValuesTests`); `FakeLoupe` ignores the curve (`LibraryDevelopValuesTests`) |
| DV-3 | `LibraryDevelopTests` (enabled): in the loupe `setDevelop` changes only the loupe photo, in the grid every selected one; 20 samples under one key then `endDevelopDrag()` are one step "Exposure" whose undo restores the start; two drags are two steps; `endDevelopDrag` returns the changed ids and their `thumbnails` entries are gone, while during the drag they are kept; `resetDevelop(.tone)` zeroes the six tone sliders, leaves Temperature and the crop, and names "Reset Tone"; `resetDevelop(nil)` resets curve and levels too, keeps the crop, "Reset Develop"; `resetDevelop(.contrast)` "Reset Contrast"; `setCurve` with one point records nothing; `setLevels(.inBlack, …)` past `inWhite` stops 1/255 below it; with no targets nothing changes and `developHelp` is "Select a photo to develop it."; `sliderHelp(.vibrance)` is nil on `.fake` and `LiveDevelop.waiting[.vibrance]` on `.live`; three photos with Exposure 0, 0, 1 read `.mixed` | a drag is several steps, a reset touches the wrong fields or the crop, thumbnails drop per sample, or a refusal leaves a step | `coalesceKey: key` → `coalesceKey: nil` (`LibraryDevelopTests`); `group?.sliders ?? allCases` → `allCases` (`LibraryDevelopTests`); levels gap `<` → `<=` (`LibraryDevelopTests`); `invalidateThumbnail` moved into `setDevelop` (`LibraryDevelopTests`) |
| DV-4 | `LibraryDevelopTests`: copy in the loupe then paste on three grid-selected photos: `history.undo.count` grows by exactly 1, named "Paste Settings", every target's adjustments equal the source's, each keeps its own crop, one Undo restores all three; paste with nothing copied is disabled (`canPasteSettings` false); copy with two selected and no loupe copies nothing; `copiedSummary` of Exposure +1, Contrast 13 and a curve is "Exposure +1.00, Contrast 13, Curve"; `syncSource` of `IMG_0004` and `IMG_0002` selected under the name sort is `IMG_0002`, nil in the loupe or with one selected; sync is one step "Sync Settings" that leaves the source unchanged; `histogramClips` lists "Highlights clipped" for bins with highlight clipping; `curveHistogram` sums the channels and its tallest bin is 1; MJ2 enabled | paste or sync records several steps, copies a crop, picks the wrong source, or a mixed check reads only one photo | `recordEdit` once per id in `pasteSettings` (`LibraryDevelopTests`); `pastingAdjustments(from:)` → assign `copied` (crop pasted) (`LibraryDevelopTests`); `order.first(where:)` → `order.last(where:)` in `syncSource` (`LibraryDevelopTests`); `MetadataValue.of(values)` → `.value(values[0])` (`LibraryDevelopTests`) |
| DV-5 | the checks below, disabled "waits on DV-6"; the LibraryModel suite stays green | a check is missing | – (no behaviour) |
| DV-6 | `LibraryDevelopRenderTests` (enabled): `passes(for: .neutral)` is empty and `render` returns the input equal (QB-LIB-V1); each slider alone gives exactly its pass; every control set gives the order white balance, exposure, contrast, highlights and shadows, whites and blacks, curve, levels; that render equals the CoreRaster calls run by hand in the same order, bit for bit (QB-LIB-V2); Exposure +1 doubles a linear 0.18 grey within 1e-4; Temperature +50 makes red above blue on grey and keeps its Rec. 709 luminance within 1e-3; Whites +50 brightens a 0.9 sRGB grey and Blacks −50 darkens a 0.1 one; Vibrance ≠ 0 throws `.renderFailed` with `waiting`'s text; `histogram(of:)` equals `Histogram(of:bins:256,encoding:.sRGB)` of the rendered buffer and each channel sums to the pixel count (QB-LIB-V3); `LiveDevelop.unavailable == nil`; MJ3. `LibraryDevelopBudgetTests` rows below | the order or math drifts from CoreRaster, neutral touches pixels, or the histogram is of the wrong buffer | drop the neutral `if … != 0` guards (`LibraryDevelopRenderTests`); contrast pass before exposure (`LibraryDevelopRenderTests`); `histogram(of:)` over the input (`LibraryDevelopRenderTests`); `whites > 0 ? 1 - …` → `1 + …` (`LibraryDevelopRenderTests`) |
| DV-7 | J5 compiles and every step skips with its reason | the file doesn't build in the journey bundle | – |
| DV-8 | J5 steps 2 to 7 once DV-10 enables them (the closures are only reachable through the panel); the macOS build of `LibraryApp` | a closure is nil while its action can run, or a drag doesn't re-render | – (app code) |
| DV-9 | `LibraryDevelopSnapshots`: `library-develop`, `-mixed`, `-error`, `-empty`, Light and Dark, each control with its `library.develop.*` identifier | a row, the readout or a state is missing | – (app code) |
| DV-10 | `library-develop-curve`; J5 (F) steps 1–9 and 11 green on the scoped run | any (F) expectation fails | – (app code) |
| DV-11 | `LibraryDevelopColorTests`, disabled "waits on DV-12" | – | – (no behaviour) |
| DV-12 | `LibraryDevelopColorTests` (enabled): grey unchanged at Vibrance and Saturation ±100; Saturation −100 turns a red patch into a grey of its luminance within 1e-4; Vibrance +50 lifts a muted color's chroma more than a strong one's; the `.color` pass sits after whites and blacks and before the curve; `waiting` is empty; MJ4 | a grey shifts, the pass is dropped or misplaced, or a row stays disabled | drop the `.color` pass (`LibraryDevelopColorTests`); pass `saturation` as vibrance and back (`LibraryDevelopColorTests`); leave `.vibrance` in `waiting` (`LibraryDevelopColorTests`) |
| DV-13 | J5 (L) steps 1–10 green on the scoped run; `library-develop-render` | develop doesn't survive a relaunch, or the grid keeps the old picture | – (journey) |
| DV-14 | P3 attaches ≥ 60 samples per series and a `render-full` per release | fewer samples (invalid) | – (journey) |
| DV-15 | `scripts/ci` (the docs lints and the waves check) passes | the prose drifts from the shipped behaviour | – (docs) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-L2 Model half | `setDevelop` on one photo of `large` (10,000) ≤ 1 ms debug gate (0.1 ms release) | `LibraryDevelopBudgetTests.setDevelopWithinBudget` (DV-5, enabled by DV-6) |
| Paste across many (new) | `pasteSettings` onto 1,000 selected photos of `large` ≤ 50 ms debug gate (5 ms release), one step | `LibraryDevelopBudgetTests.pasteManyWithinBudget` |
| QB-LIB-6 Model half | release only, report-only in debug (decision D8): preview render (512 px long side, every control but Vibrance and Saturation set) ≤ 8 ms; full render (2048 px) ≤ 120 ms; histogram of 2048 px ≤ 10 ms. DV-6's PR records `swift test -c release --filter LibraryDevelopBudget` | `LibraryDevelopBudgetTests.previewRender`, `.fullRender`, `.histogram`; a miss files the fused-pass core issue (Q3), not a looser budget |
| QB-LIB-6 grid half | thumbnails drop once per gesture, on release, never per sample | `LibraryDevelopTests` (DV-3); J5 step 10 (a changed cell `ready` again within 2 s) |
| QB-L2, QB-LIB-6 probe | the bar's marker p95 ≤ 2 frames late; a `render-preview` at least as new as the slider event p95 ≤ 100 ms; `render-full` ≤ 400 ms after release (6000 × 4000); report-only | P3 (DV-14) |
| QB-LIB-V1, V2, V3 | exact | `LibraryDevelopRenderTests` (DV-6) |
| QB-F3 | each drag, key run, reset, paste and sync is one named step; Show Original and copy record none | `LibraryDevelopTests`; J5 steps 2, 4, 5, 7, 8, 9 |
| QB-F4 | J5 steps 3, 4 and 7 drive a row and Copy and Paste from the keyboard; Show Original has `\` | J5 |
| QB-F1 | every Develop control acts or says why (`developHelp`, `sliderHelp`) | J11 reads `library.controls` |
| QB-V5 | `library-develop`, `-mixed`, `-error`, `-empty`, `-curve`, `-render`, Light and Dark | the two snapshot files |

## Done check

Per slice (`lead.md`, contract rule 6), each with no open `finding` for it
and every mutation in its plans caught:

- **DV-a, DV-b, DV-c, DV-e:** their tasks merged and MJ1, MJ2, MJ3, MJ4
  green among the LibraryModel tests of a scoped run (`app=library`) that
  contains the slice's last PR.
- **DV-d:** J5's (F) steps green on a scoped run containing DV-10, every app
  built, `library` audit counts not above `UITests/audit-baseline.json`.
- **DV-f:** J5 (F and L) and P3 (≥ 60 samples) on a scoped run containing
  DV-13 and DV-14; DV-15 merged with `feature-done`; then
  `Belt-Contact-Sheet: <run url>` on the feature issue.

If the creative-core issue hasn't reached `dev` when DV-f's other tasks are
done, see Open questions (Q1).

## Open questions

1. **Vibrance and Saturation wait on creative-core.** Recommended: if the
   core issue and its bump are not on `dev` when DV-13 and DV-14 have
   merged, DV-15 drops its DV-12 link and ships `feature-done` with the two
   rows disabled (their help names the core issue); DV-e's tasks become one
   `gap` issue. The alternative holds the feature open on core.
2. **The spine follow-up.** The Develop tab can't reach the catalog or any
   action through the spine's `DevelopInspector(cropDraft:)`. Recommended:
   the spine lead adds the pass-through under #1044 (three spine files,
   about 10 lines) before wave 3 starts; crop's `CropInspector` will need
   the same `model` and `menu`, which `DevelopInspector` can hand on.
3. **Before and after lives in the app.** `LibraryCatalog` declares every
   stored property once (spine), so Show Original's flag is presentation
   state in `DevelopAreaState`, not Linux-tested; J5 step 5 is its proof.
   The alternative is a spine slot (`showsOriginal: Bool`) and a one-line
   change in loupe-viewport's `loupeRequest`.
4. **QB-LIB-6 with more passes.** The blueprint's 8 ms preview budget was set
   for six sliders; this packet holds it for every control. Whites, Blacks,
   the curve and levels add up to three passes when set; if the release
   budget misses, the fused pass (blueprint Q3) must cover them too.
5. **One Model file for develop.** `c4-planned.json` lists only
   `LibraryDevelop.swift` and `Live/LiveDevelop.swift` for
   `library-develop`, which forces DV-2 to DV-4 into one stack. A planned
   `LibraryDevelop+Clipboard.swift` would let DV-4 build beside DV-3.
6. **Levels shown as 0–255.** The Model stores sRGB values in 0...1, as
   CoreRaster takes them; the rows show whole levels 0–255, which is how
   most people meet levels. Gamma shows two places.
