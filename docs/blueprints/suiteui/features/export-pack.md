# Feature packet: export-pack

**Feature:** one export options model for the suite and the two rows every
still export needs. SuiteKernel's `Export/` module gains `ExportOptions`
(format, size, quality, metadata policy, alpha, frame rate, loop), the
rules that turn a size into exact pixels and a policy into the tags to drop,
and `ExportFormats`, the suite's format list with what each one can carry.
SuiteUI's `SuiteExportSheet` gains a Size row (Scale, Pixels, Long edge, with
the result in pixels) and a Metadata row (All, All but location, None).
SuiteModel gets a `MetadataCarrying` contract, and SuiteShell writes it on
ImageIO beside shell-media's still encoder. Encoding stays shell-media's:
this packet adds no writer.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/export-pack`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 5). Labels `beta` and `p0` when filed.

**Covers:** feature map S11 (the shared half: at a size, the format list,
the metadata option; presets, name templates, per-layer and a render queue
stay S11's later rows); real job RJ-X42 (new). Five adopts, each its own
packet on its line: `design/export-pack` (JPG and PNG at an exact pixel
size), `photo/export-pack` (export at a size, HEIC and TIFF), `flare/export-pack`
(MP4 and GIF), `halo/export-pack` (ProRes 4444 with alpha) and
`library/export-pack` (export without location), each waiting on XP-a.

**Depends on:** shell-media (suite, planned): XP-2 waits on its **SM-a**
(the `Media` folder and `SuiteServices.media`, so the new `metadata` member
lands after it in `SuiteServices.swift`); XP-7 on **SM-w** (the still
encoder it sits beside). editor-kernel (built): `ExportRun`,
`SuiteExportSheet` (EK-30, the options slot and `idPrefix`, #3242).
tone-controls (this wave): XP-3 waits on its TC-a for `SuiteGallery.swift`,
XP-9 on its TC-z for `FakeCanvasDocument.swift`. Nothing in creative-core.

**Rule 20.** One options model: `ExportOptions`. Each app's export keeps
its own scope (which layers, which frames) and maps its options onto it with
an `<X>Export+Kernel.swift` adapter; no app declares its own size, format
flags or metadata policy again. `ExportOptions(json:)` is the one params
schema every `HeadlessDocument.export(_:options:)` reads, so the CLI, MCP and
the sheet ask for the same thing (`afterglow design export --format jpeg
--options '{"size":{"pixels":[1080,1350]}}'`). The writers are shell-media's
(`MediaEncoding`); the metadata copy is one live file beside them.

**C4:** `suite-kernel/kernel-export-session.json` gains
`Export/ExportOptions.swift` (XP-1); `suite-model/suite-contracts` and
`suite-fakes` cover the new contract and fake by folder; `shell-media` covers
`Media/StillMetadata.swift` by folder.

**Clean-room.** Size modes and metadata choices from the HIG's export
guidance and the apps' own blueprints; tag names from the Exif, IPTC and
XMP specs. No task reads another product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets); suite.md
1.5 (commands), 5 (media).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| XP-a | The kernel's export options, rules and format list exist as stubs, the metadata contract and its fake exist, the sheet shows Size and Metadata rows on a gallery page, and the checks are written, disabled. | XP-1, XP-2, XP-3 | SJ0 | shell-media:SM-a (XP-2, cross-line); tone-controls:TC-a, editor-kernel (XP-3); autosave-history:AH-a (XP-1, A/C first); placed-images:PL-a (XP-3, A/C first) |
| XP-u | On the gallery page the Size row switches between Scale, Pixels and Long edge with a ratio lock and shows the pixels it will write, the Metadata row picks a policy, and every control is identified, within the render budget. | XP-4, XP-5 | XJ1 (`SuiteExportJourneyTests.testExportSheetSizesAndMetadata`) | XP-a |
| XP-m | A size gives exact pixels (even when a codec needs it, never zero, never past the limit), a policy gives the tags to drop, a bad option says why, and the live copy drops those tags from a real JPEG and HEIC. | XP-6, XP-7 | KJ-export, `StillMetadataTests` (macOS) | XP-a; shell-media:SM-w (XP-7, cross-line) |
| XP-z | The gallery sheet plans through the rules on a live target, the fake app exports at a size so RJ-X42 runs on the CLI, and the feature is built. | XP-8, XP-9, XP-10 | XJ1, KJ-export | XP-u, XP-m; tone-controls:TC-z (XP-9); autosave-history:AH-a (XP-10, A/C first); autosave-history:AH-z (XP-9, A/C first); transform-tools:TT-z (XP-9, A/C first); eyedropper:EY-z (XP-9, A/C first); shape-tools:SH-z (XP-9, A/C first); stroke-style:SS-d (XP-9, A/C first); placed-images:PL-z (XP-9, A/C first) |

XP-u waits only on XP-a (rule 18); XP-m never waits on XP-u. KJ-export is
the rules' Linux walk in `SuiteKernelTests`; `StillMetadataTests` runs on
the macOS job (ImageIO).

## Journey steps

1. Open the gallery index, click `export-pack` (XP-3, SJ0): the sheet on a
   1000 × 1250 artwork with Format, Size, Quality and Metadata rows.
2. Pick Size > Pixels (XP-4, `testExportSheetSizesAndMetadata`): width and
   height fields, the ratio locked; type 1080 in width, height reads 1350.
3. Unlock the ratio and type 1351: the readout says "1080 × 1351 px, stretched".
4. Pick Long edge, type 2048: the readout reads "1638 × 2048 px".
5. Pick Metadata > All but location; switch Format to PNG: Quality hides,
   Metadata stays; switch to SVG: Size shows Scale only and Metadata hides.
6. Every control works by keyboard and reads its label and value in
   VoiceOver (XP-5).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X42 | adds, closes with S11 | C | `Tests/RealJobs/fake/export-pack/export-pack.jobs.json`: export JPEG with `{"size":{"pixels":[1080,1350]}}`, then `{"size":{"pixels":[1080,1351]}}` without `stretch`, then `{"size":{"longEdge":2048}}` | `input/one.fake` (a 500 × 625 artboard) |

Trap: "1080 × 1350" comes out 2160 × 2700 (a 2x scale applied on top), or
1080 × 1349 (rounding), or squashed when the ratio doesn't match. Assertion:
the first file is exactly 1080 × 1350; the second run is refused with
"1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to
stretch."; the third is 1638 × 2048. Mutations sit in
`SuiteKernel.ExportOptions.json` (round for floor on the short side; the
ratio check skipped).

## Screens and states

`suiteui-export-pack` (Pixels, light and dark), `-long-edge`, `-stretched`
(the readout's warning), `-vector` (SVG: Scale only, no Metadata).

## Contract slice

```swift
// Sources/SuiteKernel/Export/ExportOptions.swift (XP-1 values and stubs, XP-6 bodies)
public enum ExportSize: Hashable, Codable, Sendable {
    case scale(Double)                          // 1x, 2x, 0.5x of the scope's own size
    case pixels(width: Int, height: Int, stretch: Bool = false)
    case longEdge(Int)
}
public enum ExportMetadata: String, Hashable, Codable, CaseIterable, Sendable {
    case all, noLocation, none                  // titles "All", "All but location", "None"
    public var title: String { get }
}
public struct ExportFormatSpec: Hashable, Sendable {
    public enum Kind: String, Sendable { case still, vector, movie, animated }
    public let id: String, name: String, fileExtension: String, kind: Kind
    public let hasQuality: Bool, keepsAlpha: Bool, carriesMetadata: Bool, needsEvenSize: Bool
}
public enum ExportFormats {
    /// png, jpeg, heic, tiff, svg, pdf, mp4 (H.264), mp4-hevc, mov-prores (ProRes 4444, alpha), gif, apng.
    public static let all: [ExportFormatSpec]
    public static func spec(_ id: String) -> ExportFormatSpec?
}
public struct ExportOptions: Hashable, Codable, Sendable {
    public var format: String, size: ExportSize, quality: Double      // quality 0...1
    public var metadata: ExportMetadata, alpha: Bool, fps: Int?, loop: Bool
    /// The one params schema: every key optional, each missing one from `defaults`; an unknown key throws.
    public init(json: JSONValue, defaults: ExportOptions) throws
    public static let schema: ParamSchema
}
public enum ExportRules {
    public static let maxSide = 16_384
    /// Exact output pixels for a scope `source` pixels big at 1x.
    public static func pixels(of source: (width: Int, height: Int), _ size: ExportSize,
                              evenSize: Bool) throws -> (width: Int, height: Int)
    /// ImageIO property paths to drop ("{GPS}", "{Exif}.BodySerialNumber", "{MakerApple}", ...) and the XMP
    /// properties a sidecar leaves out ("exif:GPSLatitude", "xmp:CreateDate" under `.none`).
    public static func dropped(_ m: ExportMetadata) -> (properties: Set<String>, xmp: Set<String>)
    /// Why these options can't run, or nil.
    public static func refusal(_ o: ExportOptions, source: (width: Int, height: Int), formats: [ExportFormatSpec]) -> String?
}
// Sources/SuiteModel/Contracts/MetadataCarrying.swift (XP-2)
public protocol MetadataCarrying: Sendable {
    /// `still` (encoded bytes) rewritten with `source`'s metadata minus `dropping`; orientation and the colour
    /// profile always kept. An unreadable source copies nothing.
    func carrying(_ still: Data, from source: Data, dropping: Set<String>) throws(SuiteError) -> Data
    /// The property paths present in an image: what tests and jobs assert on.
    func properties(of image: Data) throws(SuiteError) -> Set<String>
}
// Sources/SuiteModel/Fakes/FakeMetadata.swift (XP-2): records calls; returns `still` unchanged.
// SuiteServices gains `metadata: any MetadataCarrying` (default FakeMetadata()).
// Sources/SuiteUI/ExportSheet.swift (XP-3 rows as placeholders, XP-4 views)
public struct ExportPick { ...; public var size: ExportSize? = nil; public var metadata: ExportMetadata? = nil }
// nil size: the Scale row as today; nil metadata: no Metadata row. Existing callers compile unchanged.
public struct ExportSheetRows { public enum Row { ...; case pixels(ExportSize, source: Int, Int); case metadata(ExportMetadata) } }
```

## Pseudocode

- **pixels.** `scale(s)`: `round(w·s)`, `round(h·s)`. `longEdge(n)`: the long
  side n, the short `round(short·n/long)`. `pixels(w, h)`: exact; without
  `stretch`, refused unless `|w·sh − h·sw| ≤ max(sw, sh)/2` (one side is the
  other's proportional length rounded; `ExportRules.keepsShape`): for a
  500 × 625 source 1080 × 1350 passes and 1080 × 1351 is refused (#5326). Then even sizes round down to even for codecs that need them,
  each side clamped to 1...`maxSide` (past it: refused, not clamped). Never
  enlarge only where an app says so (Library), as its own refusal.
- **dropped.** `.all`: nothing. `.noLocation`: `{GPS}`, the IPTC location
  fields, `{Exif}.BodySerialNumber`, `{Exif}.LensSerialNumber`, every
  maker-note dictionary; XMP `exif:GPS*`. `.none`: every dictionary but
  `{TIFF}.Orientation` and the profile; XMP everything but the app's own
  namespace.
- **refusal.** Unknown format, quality outside 0...1 on a format that has
  one, alpha on a format that can't keep it ("H.264 can't keep
  transparency. Choose ProRes 4444."), and `pixels`'s own errors.
- **Size row.** `ChoiceChips` Scale | Pixels | Long edge; Pixels shows two
  `NumericInput`s and a lock; the readout under it is `pixels(...)`'s answer
  or its refusal, live as the person types. The Metadata row is an
  `InspectorPickerRow` with the three titles.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| XP-1 | – | `ExportOptions.swift` as stubs: `ExportSize`, `ExportMetadata`, `ExportFormatSpec`, `ExportFormats`, `ExportOptions` with its schema, `ExportRules`; the C4 part names it; the suite written, disabled | `Sources/SuiteKernel/Export/ExportOptions.swift`, `Tests/SuiteKernelTests/ExportOptionsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json` | – | ~300, 3 |
| XP-2 | – | `MetadataCarrying`, `FakeMetadata` and the `SuiteServices.metadata` member | `Sources/SuiteModel/Contracts/MetadataCarrying.swift`, `Sources/SuiteModel/Fakes/FakeMetadata.swift`, `Sources/SuiteModel/SuiteServices.swift`, `Tests/SuiteModelTests/FakeMetadataTests.swift` | shell-media:SM-a | ~120, 4 |
| XP-3 | – | `ExportPick.size` and `.metadata` (defaulted), the two rows as placeholders, the gallery's `export-pack` page, the journey written and skipped (`XCTSkip("waits on XP-5")`) | `Sources/SuiteUI/ExportSheet.swift`, `Sources/SuiteUI/Gallery/GalleryExportPack.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `UITests/SuiteJourneyTests+Export.swift` | XP-1, tone-controls:TC-a | ~220, 4 |
| XP-4 | – | The rows: Size modes with the ratio lock and the live readout, the Metadata picker, identifiers `<prefix>.size.*` and `<prefix>.metadata` | `Sources/SuiteUI/ExportSheet.swift`, `Tests/SuiteUITests/ExportPackRowsTests.swift` | XP-3 | ~300, 2 |
| XP-5 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteExportPackSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetExportPackTests.swift`, `UITests/SuiteJourneyTests+Export.swift` | XP-4 | ~200, 3 |
| XP-6 | – | `ExportRules` bodies, `ExportOptions(json:)` and the format list; turns on `ExportOptionsTests` | `Sources/SuiteKernel/Export/ExportOptions.swift`, `Tests/SuiteKernelTests/ExportOptionsTests.swift`, `Tests/mutations/SuiteKernel.ExportOptions.json` | XP-1 | ~320, 3 |
| XP-7 | – | `StillMetadata`: the live `MetadataCarrying` on ImageIO (`CGImageDestinationCopyImageSource` with the source's properties minus the dropped paths), wired into the media slot | `Sources/SuiteShell/Media/StillMetadata.swift`, `Tests/AppSnapshotTests/StillMetadataTests.swift`, `Tests/RealJobs/fixtures/gps-phone.jpg` | XP-2, shell-media:SM-w | ~220, 3 |
| XP-8 | – | The gallery sheet plans each pick through `ExportRules` on a local target and runs a fake export; the live test | `Sources/SuiteUI/Gallery/GalleryExportPack.swift`, `Tests/SuiteUITests/ExportPackLiveTests.swift` | XP-5, XP-6 | ~120, 2 |
| XP-9 | – | The fake app exports with `ExportOptions(json:)` (PNG and JPEG at a size); RJ-X42's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeCanvasExportTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/export-pack/` | XP-6, tone-controls:TC-z | ~180, 4 |
| XP-10 | – | The C4 part names the rows and the rules; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json`, `docs/blueprints/suiteui/features/export-pack.wave.json` | XP-8, XP-9, XP-7 | ~20, 2 |

XP-1 declares every rule, so XP-6 fills one file. No `suiteui.md` edit: the
C4 part and the adopts' blueprint lines carry it.

## Build waves

- Wave 1: XP-1, XP-2. Independent in this wave: both.
- Wave 2: XP-3, XP-6, XP-7. Independent in this wave: all three.
- Wave 3: XP-4, XP-9. Independent in this wave: both.
- Wave 4: XP-5. Independent in this wave: XP-5 alone.
- Wave 5: XP-8. Independent in this wave: XP-8 alone.
- Wave 6: XP-10 (`feature-done`, final). Independent in this wave: XP-10 alone.

Longest chain: XP-1 → XP-3 → XP-4 → XP-5 → XP-8 → XP-10 (6). Chain of 6: the page needs the module, the rows fill the placeholders, the budget and journey time them, the live page plans under the journey, and XP-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| XP-1 | `ExportOptionsTests` compiles, disabled by name; `KernelShapeTests` passes over `Export/` | the module imports past Foundation and the engines | – (stubs) |
| XP-2 | `FakeMetadataTests`: the fake records `carrying` and returns its input; `SuiteServices()` has it | the member is missing | – (contract) |
| XP-3 | SJ0: the index lists `export-pack`; existing `ExportPick` callers compile unchanged | a caller breaks or the page is missing | – (UI) |
| XP-4 | `ExportPackRowsTests`: typing 1080 with the lock on sets 1350; unlocking and typing 1351 shows the stretched readout; Long edge 2048 reads 1638 × 2048; SVG hides Metadata and offers Scale only | a readout or a hidden row is wrong | – (UI) |
| XP-5 | `SuiteExportPackSnapshots`; `RenderBudgetExportPackTests.typingWidthInTwoBodies`; `testExportSheetSizesAndMetadata` steps 1 to 6 | budget over, or a step fails | – (UI) |
| XP-6 | `ExportOptionsTests`: 500 × 625 at `pixels(1080, 1350)` is exact; `pixels(1080, 1351)` is refused with its sentence; `longEdge(2048)` gives 1638 × 2048; `scale(2)` gives 1000 × 1250; H.264 at 1081 wide gives 1080; 20000 wide is refused; `.noLocation` drops `{GPS}` and keeps `{Exif}.DateTimeOriginal`; JSON with an unknown key throws | a pixel count, a refusal or a dropped tag is wrong | `SuiteKernel.ExportOptions`: round for floor on the short side → `.longEdgeShortSide`; ratio check skipped → `.pixelsKeepShape`; GPS not dropped under `.noLocation` → `.noLocationDropsGPS`; even rounding up → `.evenRoundsDown` |
| XP-7 | `StillMetadataTests` (macOS): a GPS-tagged phone JPEG re-encoded and carried with `.noLocation` has no `{GPS}`, no serials, no maker note, and keeps orientation, `DateTimeOriginal` and `Copyright`; with `.none` only orientation and the profile; HEIC the same | a dropped tag survives, or orientation is lost | – (macOS live code; the rule's mutations are XP-6's) |
| XP-8 | `ExportPackLiveTests`: an Export on the page writes the planned size; `testExportSheetSizesAndMetadata` on live | the page stays on placeholders | – (UI) |
| XP-9 | `FakeCanvasExportTests`: the fake's JPEG at `pixels(1080, 1350)` decodes 1080 × 1350; old jobs' exports are unchanged; RJ-X42 passes on Linux | a size or an old export changes | `SuiteKernel.FakeCanvasDocument`: options ignored (1x written) → `.exportsAtSize`; refusal swallowed → `.refusesBadShape` |
| XP-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: typing a 4-digit width | ≤ 2 window bodies per keystroke | `RenderBudgetExportPackTests.typingWidthInTwoBodies` |
| render: switching Size mode | ≤ 2 window bodies | `RenderBudgetExportPackTests.modeSwitchInTwoBodies` |
| Exact size | every adopter's export at `pixels(w, h)` decodes at w × h | each adopt's job |
| No dead controls | every row registers in `suite.controls`; a hidden row is absent, not disabled | `testExportSheetSizesAndMetadata` |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): XP-m merged-done on the Linux job with
`Mutate:` clean and `StillMetadataTests` green on macOS; XP-u's feel gate and
`Mac-Finish:`; XP-z's journey on live and RJ-X42 green in the Linux job. Then
`Belt-Contact-Sheet:` with `suiteui-export-pack-*`.

## Adopted by

`design/export-pack` (JPEG, PNG at exact pixels; RJ-D41), `photo/export-pack`
(at a size, HEIC and TIFF; RJ-P01), `flare/export-pack` (MP4 and GIF;
RJ-F07, F08), `halo/export-pack` (ProRes 4444 with alpha; RJ-H41),
`library/export-pack` (the metadata row, without location; RJ-L16, RJ-X03).
Each waits on XP-a and runs its UI on these stubs.

## Not in this packet

WebP (ImageIO can't write it on the pinned macOS), presets and name
templates across apps (S11's later rows; Library has its own), per-layer
export, a render queue, watermarks (RJ-L17), audio in movies (S23).
