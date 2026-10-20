# Feature packet: shared-raw

**Feature:** camera RAW files (CR2, CR3, NEF, NRW, ARW, SR2, RAF, ORF, RW2,
DNG, PEF, SRW, 3FR, IIQ, ERF, MOS, X3F) open once, the same way, in every app
that opens images. One shared decode lives in SuiteImaging's `Raw/` module
over Apple's Core Image RAW (`CIRAWFilter`), so we write no decoder and port
nothing. It hands back a Float32 `PixelBuffer` in SuiteImaging's wide
working space (extended-range linear sRGB, unclamped: suite-imaging's
`ImagingColor`, IM-15) with headroom: values above 1.0 and colours outside
sRGB survive, so the shared tone sliders (Exposure, White Balance,
Highlights) pull back detail a JPEG has already clipped. Thumbnails take the
camera's embedded preview; the full decode runs only for the loupe, Photo's
canvas and export. A file the system can't read or develop is refused with a
sentence that names the format or the camera. Photo opens a RAW file as a new
document; `afterglow` opens, develops (`tone.set`) and exports one. Which
files count as RAW is not a list of this packet's: shared-codecs' format
registry (`SuiteImageFormats`, slice SC-f) has one camera RAW row, so
Photo's open panel, Library's scan and the CLI already list RAW files; this
packet extends that row with the decode. Library's adoption is `library/raw`
(re-cut in this PR to a thin adopter).
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`) · **Lead branch:** `lead/shared-raw`
**Beta:** captain, 2026-10-21 ("RAW in beta, and it should be shared"). Labels `beta` and `p1` when filed.

**Covers:** feature map row `suiteui/shared-raw` (new; adopters photo, this
packet, and library, `library/raw`); real job RJ-X50 (new). Library's #427
and RJ-L22 close through `library/raw`.

**Depends on:** suite-imaging (same line): **IM-a** before SR-2 (the
SuiteImaging target, which PhotoModel, LibraryModel and AfterGlowCLICore
already link), **IM-m** before SR-3 (`ImagingProgram`, so the headroom test
runs the shared list). tone-controls **TC-a** and pen-paths **PN-a** before
SR-8 (`Tests/canonical-concepts.txt`, A/C first). shared-codecs **SC-f** and **SC-photo** before SR-6 (the format registry,
and SC-4's `SuiteImageIO.decode` into the working space; SC-15 and SC-4
also edit `PhotoImageFile.swift` and `ImageIOCodec.swift`).
**No creative-core issue and no `Package.swift` edit:** Core Image is a
system framework, linked by its `import`, and every target that needs RAW
already links SuiteImaging after IM-1, which also links SuiteModel into
SuiteImaging so `RawFormat` reads the registry (amended in this PR).

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **SR-photo:** the open panel and `PhotoHeadless`' lists come from the
  registry (shared-codecs SC-15), so this packet edits neither
  `PhotoWindow+File.swift` nor `PhotoHeadless.swift`. `ImageIOCodec.swift`
  is also photo/export-pack PX-m's; SR-6 adds `decodeLinear` after SC-4.
- **SR-z:** RJ-X50's `tone.set` in Photo is photo/tone-controls PT-4's; the
  job stays disabled until it merges.
- **library/raw** waits on this packet's SR-a (contract) and SR-m (the
  system decoder). It owns every Library file; this packet edits none.

**Why SuiteImaging, not SuiteShell's `SuiteImageIO`.** The CLI requirement
decides it. `AfterGlowCLICore` links SuiteKernel, SuiteModel, the app Models
and (after IM-1) SuiteImaging; SuiteShell depends on SuiteUI, so a RAW
decoder there could never serve `afterglow`. The macOS half sits in one file
behind `#if canImport(CoreImage)`, the way IM-5's `LiveToneSurface` sits
behind `#if canImport(Metal)`. It stays inside both XK3 ratchets: it imports
no ImageIO (shared-codecs' `ImageIOImportRatchetTests`; the camera's Make
and Model come from `CIRAWFilter.properties` with the string keys `{TIFF}`,
`Make`, `Model`) and no Metal (suite-imaging's `ImagingBoundaryTests`; a
default `CIContext()`).

**Rule 20.** One RAW decode (`SuiteRaw`), one set of refusal sentences
(`RawRefusal`), and no RAW extension list of its own: `RawFormat` reads the
registry's camera RAW row. One home for
exposure and white balance: the shared tone sliders. The decoder is told
neither: it decodes at the camera's as-shot white balance with its tone
curve off (`boostAmount = 0`) and its baseline exposure moved out
(`baselineExposure = 0`, then `SuiteRaw` applies the file's baseline as one
core `exposure(stops:)` step on the float buffer). So a RAW file has no
second Exposure or Temperature control, and a slider step on it stays one
GPU display write on the resident float base (`docs/render-contract.md`;
CoreRender's tile textures are `rgba16Float`, so the headroom survives on
the GPU). SR-8 adds the `Raw decode: Raw` line to
`Tests/canonical-concepts.txt`, so an app-local `*Raw*` decoder fails
`scripts/check-dup-logic`.

**Headroom and gamut, the contract decision (beta).** Photo's
`DecodedImage` and Library's `DisplayImage` are 8-bit sRGB, so a RAW file's
highlights and a Display P3 phone photo's colours are clipped before any
slider moves. This packet routes every opened file around them, not only
RAW: Photo's codec gains `decodeLinear`, whose working-space `PixelBuffer`
becomes the layer as is (SR-6: RAW through `SuiteRaw`, every other format
through shared-codecs' `SuiteImageIO.decode`, which reads the file's ICC
profile and depth), and library/raw gives `PhotoDecoding` the same for the
loupe and export (its RW-2 to RW-4). Develop runs in the working space; the
display step and the output transform come last (`ImagingColor`). That
resolves Library's old decision D11. The 8-bit types stay for thumbnails and
paste only.

**Deleted app-local code: none.** Nothing decodes RAW today. The re-cut
deletes library/raw's own planned decoder (`Platform/RawDecoding.swift`,
`RawFileTypes.swift`, the tiny DNG under `Tests/AppSnapshotTests/`) before
it is written.

**C4:** a new component part `suite-imaging/imaging-raw.json`
(`Sources/SuiteImaging/Raw/`), added by SR-2; SR-8 names the adopters.

**Clean-room.** Decoding is Apple's documented `CIRAWFilter`. The test DNGs
are written by our own test code from Adobe's published DNG specification
(1.7). No other app's code, files or UI are read.

**Non-goals (beta).** No RAW-only sliders: noise reduction, lens correction
and highlight recovery run at the decoder's defaults (highlight recovery on
where `isHighlightRecoverySupported`). No XMP sidecars: develop settings stay
in Library's catalog and Photo's `.ora`, the slots that exist. No RAW+JPEG
pairing and no grid RAW tag (library/raw's open questions). Photo doesn't
re-develop a RAW after opening it; it opens at the as-shot white balance and
the tone sliders work from there. No RAW writing.

Blueprint sections: suite.md 2 (shared tiers); photo.md (Open, Export);
library.md 1.3 (raw through the system decoder), 10.1 (D11).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SR-a | The tiny test DNGs are written in-repo and checked byte for byte, and SuiteImaging's `Raw/` module declares the formats, the refusals, the decode plan and `SuiteRaw` as stubs over a fake decoder, with their tests written, disabled. | SR-1, SR-2 | MJ-SR | suite-imaging:IM-a (SR-2) |
| SR-m | RAW extensions parse, the plan picks the embedded preview only where it covers the size, refusals read as sentences, and the system decoder returns an upright linear float buffer whose highlights survive Exposure −1 through the shared list. | SR-3, SR-4 | MJ-SR, MJ-SR-mac | SR-a; suite-imaging:IM-m (SR-3) |
| SR-photo | Photo opens a RAW file as a new document whose layer keeps the decoder's float pixels, the CLI opens it headless, and a refused file leaves the document as it was with the sentence. | SR-5, SR-6 | MJ-SR-photo, PJ-SR | SR-a; shared-codecs:SC-f and SC-photo (SR-6: `PhotoImageFile.swift`, `ImageIOCodec.swift`, A/C first) |
| SR-z | On live services Photo opens, develops and exports the test DNG at full size, RJ-X50 passes on the macOS job, the concept line guards against a second decoder, and the feature is built. | SR-7, SR-8 | PJ-SR, MJ-SR | SR-m, SR-photo; tone-controls:TC-a, pen-paths:PN-a (SR-8, `canonical-concepts.txt`, A/C first) |

There is no new screen: the open panel lists RAW through the registry
(shared-codecs SC-15) and a refusal shows in Photo's existing open-failure
alert. SR-photo is the UI slice (`"ui": true`, SR-6 edits `ImageIOCodec.swift`)
and waits on no slice of this feature but SR-a (rule 18); its Model tests run
on `FakeRawDecoder`. SR-m never waits on SR-photo. `SystemRawDecoder.swift` and
its tests build only on macOS: SR-4's mutation plan runs on the supervisor's
Mac before `Belt-Slice-Done:` (suiteui waves, Q10).

## Journey steps

- `MJ-SR` (Linux): `TinyDNGTests`, `RawFormatTests`, `RawDecodePlanTests`,
  `RawHeadroomTests` in `SuiteImagingTests`.
- `MJ-SR-mac` (SR-4, the macOS job): `SystemRawDecoderTests` in
  `SuiteImagingTests` behind `#if canImport(CoreImage)`.
- `MJ-SR-photo` (Linux): `PhotoRawOpenTests` in `PhotoModelTests`.
- `PJ-SR` · `PhotoRawJourneyTests.testOpenRawDevelopExport`
  (`UITests/PhotoJourneyTests+Raw.swift`; written by SR-5 with
  `XCTSkip("waits on SR-7")`, enabled by SR-7):
  1. Copy `tiny-bayer.dng` and `not-raw.nef` (by `#filePath`) into a temp
     folder. Launch Photo with `-PhotoOpenFile <folder>/not-raw.nef`. Expect
     the alert "macOS can't read this raw file (NEF)." and an empty window.
     Shot `photo-open-raw-refused`.
  2. Open `tiny-bayer.dng`. Expect the title "tiny-bayer", the canvas 48 ×
     64 (Orientation 6 applied), one layer "Background". Shot
     `photo-open-raw`.
  3. Drag Exposure to −1 in the tone rows.
  4. File > Export as PNG (`-PhotoExportTo <folder>`). Expect the file 48 ×
     64, not the preview's 24 × 32, and its two highlight patches more than
     20 levels apart.
  States: refused (alert, window unchanged), opened.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X50 | adds, closes with `suiteui/shared-raw` | Cm | `Tests/RealJobs/photo/raw-develop/raw-develop.jobs.json`: `afterglow` opens `tiny-bayer.dng` in Photo, `tone.set` Exposure −1, exports PNG | `input/tiny-bayer.dng` (SR-1's writer), `expected/tiny-bayer-ev-1.png` (SR-8) |

Trap: the CLI's export is the embedded preview (24 × 32), or the decode went
through 8 bits so the two highlight patches come back the same flat value
after Exposure −1. Assertion: the export is 48 × 64, matches the reference
within 3 levels, and the two patches differ by more than 20 levels. Cm
because the decode crosses Core Image; on Linux the CLI refuses the file with
`RawRefusal.unavailable`'s sentence, which `PhotoRawOpenTests` checks. Written
by SR-5 (`waits_on: SR-7`, which adds the reference PNG once SR-4's decoder
has produced it on the Mac). RJ-L22 (Library's embedded preview) closes with
`library/raw`.

## Screens and states

| Screen | Error | Loading |
|---|---|---|
| Photo, open | the refusal sentence in the existing open-failure alert; the window keeps what it had | the existing open progress, unchanged |
| Photo canvas | – | – |

Snapshots (Light and Dark): `PhotoRawSnapshots.swift` `photo-open-raw` and
`photo-open-raw-refused` (SR-7, live).

## Contract slice

```swift
// Sources/SuiteImaging/Raw/RawFormat.swift (SR-2 stubs, SR-3 bodies). Linux-safe.
/// A camera RAW file's extension, upper case as the refusals name it ("NEF"). Which extensions are RAW is
/// the registry's: `SuiteImageFormat.cameraRaw.extensions` (shared-codecs SC-14).
public struct RawFormat: Hashable, Sendable, Codable {
    public let fileExtension: String
    /// Non-nil when the registry's format for `fileName` is in the `.cameraRaw` family, any case.
    public init?(fileName: String)
}
/// Why a RAW file can't be read or developed; `message` is the sentence the apps show.
public enum RawRefusal: Error, Equatable, Sendable {
    case unreadable(RawFormat)                // "macOS can't read this raw file (NEF)."
    case undevelopable(camera: String)        // "macOS can't develop raw files from <camera> yet."
    case unavailable                          // "This build can't read raw files. Open it on a Mac."
    case tooLarge(pixels: Int)                // "This raw file is larger than 256 megapixels."
    public var message: String { get }
}
/// A pixel size, upright (orientation applied).
public struct RawSize: Hashable, Sendable { public var width, height: Int; public var longSide: Int { get } }
/// What the decoder says about one file.
public struct RawFileInfo: Hashable, Sendable {
    public var format: RawFormat
    public var camera: String                 // "AfterGlow Test"; "this camera" when the file names none
    public var developable: Bool
    public var size: RawSize                  // full decoded size
    public var previewSize: RawSize?          // the embedded preview; nil when there is none
    public var baselineStops: Double          // the file's baseline exposure, applied by `decode`
}
/// How much picture a caller needs.
public enum RawQuality: Hashable, Sendable {
    case thumbnail(longestSide: Int)          // the embedded preview may stand in
    case preview(longestSide: Int)            // a draft decode at that size
    case full                                 // every pixel, never draft: the loupe at 100 %, Photo, export
}
public enum RawDecodePlan: Hashable, Sendable {
    case embeddedPreview(longestSide: Int)
    case develop(scale: Double, draft: Bool)
    case refuse(RawRefusal)
    public static func plan(_ quality: RawQuality, info: RawFileInfo) -> RawDecodePlan
}
// Sources/SuiteImaging/Raw/SuiteRaw.swift (SR-2 stubs throwing .unavailable, SR-3 bodies). Linux-safe.
public enum RawSource: Sendable { case file(URL), bytes(Data, fileName: String) }
public enum SuiteRaw {
    /// The decoder the apps use: `SystemRawDecoder` on macOS, nil on Linux (every call refuses `.unavailable`).
    public static var decoder: (any RawDecoding)? { get }
    public static func info(_ source: RawSource, decoder: (any RawDecoding)? = SuiteRaw.decoder) throws(RawRefusal) -> RawFileInfo
    /// The working space (extended-range linear sRGB), Float32, premultiplied, upright; values above 1 and
    /// outside sRGB kept. The file's baseline exposure is applied
    /// here as one core `exposure(stops:)` step; an embedded preview comes back as decoded (no baseline).
    public static func decode(_ source: RawSource, quality: RawQuality,
                              decoder: (any RawDecoding)? = SuiteRaw.decoder) throws(RawRefusal) -> PixelBuffer
}
// Sources/SuiteImaging/Raw/RawDecoding.swift (SR-2). Linux-safe. The seam the fake and the system decoder share.
public protocol RawDecoding: Sendable {
    func info(_ source: RawSource) throws(RawRefusal) -> RawFileInfo
    func embeddedPreview(_ source: RawSource, longestSide: Int) throws(RawRefusal) -> PixelBuffer
    /// Linear, tone curve off, baseline exposure 0, as-shot white balance, highlight recovery where supported.
    func develop(_ source: RawSource, scale: Double, draft: Bool) throws(RawRefusal) -> PixelBuffer
}
// Sources/SuiteImaging/Raw/FakeRawDecoder.swift (SR-2). Linux-safe: a fixed table by extension
// (.DNG 64 × 48 with a 32 × 24 preview, baseline 1; .ARW "Unreleased X1", undevelopable, preview only;
// .NEF holding non-RAW bytes unreadable), pixels from `RawHeadroomFixture` (two patches at 0.7 and 0.9 linear).
public struct FakeRawDecoder: RawDecoding { public init() }
// Sources/SuiteImaging/Raw/SystemRawDecoder.swift (SR-2 stub, SR-4 body). macOS, #if canImport(CoreImage).
public struct SystemRawDecoder: RawDecoding { public init() }
```

Photo's seam (SR-6), in `Sources/PhotoModel/PhotoImageFile.swift`:

```swift
extension PhotoImageCodec {
    /// A RAW file's linear float pixels, or nil for any other file (it takes `decode`'s 8-bit route).
    /// Default: `SuiteRaw.decode(.bytes(data, fileName:), quality: longestSide.map { .preview(longestSide: $0) } ?? .full)`
    /// when `RawFormat(fileName:)` is non-nil.
    public func decodeLinear(_ data: Data, fileName: String, longestSide: Int?) throws -> PixelBuffer?
}
```

## Pseudocode

- **plan** (SR-3). `want = min(longestSide, info.size.longSide)`. Not
  developable: `.embeddedPreview` for `.thumbnail` when there is a preview,
  else `.refuse(.undevelopable(camera))`. `.thumbnail` with
  `previewSize.longSide >= want`: `.embeddedPreview(want)`. `.preview`:
  `.develop(scale: want / size.longSide, draft: true)`. `.full`:
  `.develop(scale: 1, draft: false)`. Scale never above 1.
- **decode** (SR-3). `info` → `plan` → the decoder's call. After `develop`,
  `PixelBuffer.exposure(stops: info.baselineStops)` when it isn't 0, nothing
  else: no clamp, no 8-bit step. Any decoder error becomes a `RawRefusal`;
  a size over `PixelBuffer.maxPixels` is `.tooLarge` before allocating.
- **SystemRawDecoder** (SR-4). `CIRAWFilter(imageURL:)` or
  `CIRAWFilter(imageData:identifierHint:)` (the hint from the extension); nil
  → `.unreadable(format)`. Camera from `properties["{TIFF}"]["Model"]`
  (Make when Model is missing). `developable` is false when the model isn't
  in `CIRAWFilter.supportedCameraModels` and the format isn't DNG, or when
  `outputImage` is nil. Develop: `boostAmount = 0`, `baselineExposure = 0`,
  `exposure = 0`, `isHighlightRecoveryEnabled = isHighlightRecoverySupported`,
  `scaleFactor = scale`, `isDraftModeEnabled = draft`, orientation applied;
  render with one shared `CIContext()` into `.RGBAf` in
  `CGColorSpace(name: CGColorSpace.extendedLinearSRGB)`, the working space,
  so nothing clips and no gamut is lost (a colour outside sRGB comes out as
  a negative or above-1 component);
  alpha 1, so premultiplied equals straight. Preview: `previewImage`,
  oriented, scaled to `longestSide`, never enlarged, rendered the same way.
- **Photo open** (SR-6). `openImage(data, name)`: `decodeLinear` first; a
  buffer becomes the "Background" layer directly (the 8-bit `DecodedImage`
  route is skipped), the document is named by the file's stem and is
  untitled, so Save writes `.ora` and never touches the RAW file;
  `maxOpenPixels` still sets `longestSide`. A `RawRefusal` throws its
  `message` through the existing open-failure path and leaves the workspace
  unchanged. `PhotoHeadless.openExtensions` already lists the RAW
  extensions (the registry, SC-15), so the CLI needs no change here.
- **Fixtures** (SR-1). `TinyDNG.write(_ spec)` builds a DNG 1.4 file from the
  published spec: IFD0 holds the 32 × 24 8-bit RGB preview
  (`NewSubFileType` 1) and a SubIFD the 64 × 48 16-bit uncompressed RGGB CFA
  (`CFARepeatPatternDim` 2 2, `BlackLevel` 0, `WhiteLevel` 65535,
  `ColorMatrix1` for sRGB D65, `AsShotNeutral` 1 1 1, `BaselineExposure`
  1.0, `Orientation` 6, `UniqueCameraModel` "AfterGlow Test"). The scene:
  a grey ramp, two highlight patches at 0.70 and 0.90 of white (1.4 and 1.8
  linear after the baseline, so both read 255 in an 8-bit render, and 0.70
  and 0.90 after Exposure −1), and a preview filled with a marker colour the
  RAW data doesn't contain, so a test can tell which one it got.
  `tiny-linear.dng` is the same scene as a `LinearRaw` DNG (SR-4's fallback
  if Core Image refuses the hand-made CFA, open question R1). `not-raw.nef`
  is the 14 bytes `not a raw file`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SR-1 | – | **Tests first, and the fixtures.** `TinyDNG.swift` and `TinyPNG.swift` (test support, Linux) and the four committed files (`p3-red-16.png`: 8 × 8, 16-bit, core's Display P3 profile in an iCCP chunk, the left half pure P3 red, outside sRGB); `TinyDNGTests` live (each file equals its writer byte for byte; the writer's IFDs parse back to the spec's sizes and tags); `RawFormatTests`, `RawDecodePlanTests` and `RawHeadroomTests` written, disabled by name (`waits on SR-3`) | `Tests/SuiteImagingTests/TinyDNG.swift`, `Tests/SuiteImagingTests/TinyPNG.swift`, `Tests/SuiteImagingTests/TinyDNGTests.swift`, `Tests/SuiteImagingTests/Fixtures/raw/`, `Tests/SuiteImagingTests/RawFormatTests.swift`, `Tests/SuiteImagingTests/RawDecodePlanTests.swift`, `Tests/SuiteImagingTests/RawHeadroomTests.swift` | – | ~400, 9 |
| SR-2 | – | The `Raw/` module as stubs: `RawFormat`, `RawRefusal`, `RawSize`, `RawFileInfo`, `RawQuality`, `RawDecodePlan`, `RawSource`, `SuiteRaw` (every call throws `.unavailable`), `RawDecoding`, `FakeRawDecoder` (its table filled: the Photo and Library slices run on it), `SystemRawDecoder` behind `#if canImport(CoreImage)`; the C4 part | `Sources/SuiteImaging/Raw/RawFormat.swift`, `Sources/SuiteImaging/Raw/SuiteRaw.swift`, `Sources/SuiteImaging/Raw/RawDecoding.swift`, `Sources/SuiteImaging/Raw/FakeRawDecoder.swift`, `Sources/SuiteImaging/Raw/SystemRawDecoder.swift`, `docs/c4/parts/creative-apps/suite-imaging/imaging-raw.json` | SR-1 | ~300, 6 |
| SR-3 | – | Bodies on Linux: `RawFormat(fileName:)` over the registry's camera RAW row, the refusal sentences, `RawDecodePlan.plan`, `SuiteRaw.info` and `decode` with the baseline step; turns on the three suites | `Sources/SuiteImaging/Raw/RawFormat.swift`, `Sources/SuiteImaging/Raw/SuiteRaw.swift`, `Tests/SuiteImagingTests/RawFormatTests.swift`, `Tests/SuiteImagingTests/RawDecodePlanTests.swift`, `Tests/SuiteImagingTests/RawHeadroomTests.swift`, `Tests/mutations/SuiteImaging.RawFormat.json`, `Tests/mutations/SuiteImaging.SuiteRaw.json` | SR-2, suite-imaging IM-4 | ~320, 7 |
| SR-4 | – | **The system decoder, spike first.** `SystemRawDecoderTests` opens `tiny-bayer.dng` before anything else (if Core Image refuses it, switch the fixture to `tiny-linear.dng` and say so in the PR, R1); then `SystemRawDecoder`'s body as in Pseudocode; `SuiteRaw.decoder` returns it on macOS | `Sources/SuiteImaging/Raw/SystemRawDecoder.swift`, `Tests/SuiteImagingTests/SystemRawDecoderTests.swift`, `Tests/mutations/SuiteImaging.SystemRawDecoder.json` | SR-2 | ~350, 3 |
| SR-5 | – | **Photo, test first.** `PhotoRawOpenTests` (Linux, `FakeRawDecoder` through a test codec), disabled (`waits on SR-6`); the journey written and skipped; RJ-X50's job folder, disabled (`waits_on: SR-7`) | `Tests/PhotoModelTests/PhotoRawOpenTests.swift`, `UITests/PhotoJourneyTests+Raw.swift`, `Tests/RealJobs/photo/raw-develop/raw-develop.jobs.json`, `Tests/RealJobs/photo/raw-develop/input/tiny-bayer.dng` | SR-2 | ~260, 4 |
| SR-6 | – | **Photo's float route, every format.** `PhotoImageCodec.decodeLinear` with its default (RAW through `SuiteRaw`); `ImageIOCodec` implements it for every file through `SuiteImageIO.decode`; `openImage` puts the working-space buffer in the layer and names an untitled document; refusals through the open-failure path; turns on `PhotoRawOpenTests` | `Sources/PhotoModel/PhotoImageFile.swift`, `Sources/PhotoApp/ImageIOCodec.swift`, `Tests/PhotoModelTests/PhotoRawOpenTests.swift`, `Tests/mutations/PhotoModel.PhotoImageFile.json` | SR-5, shared-codecs SC-15 and SC-4 | ~240, 4 |
| SR-7 | – | **Live, and the wide-gamut round trip.** `WideGamutRoundTripTests` (macOS): `p3-red-16.png` and `tiny-bayer.dng` each go decode → develop (Exposure −1 on the DNG) → `SuiteImageIO.encode(.tiff(bitDepth: 16), profile: .displayP3)` → decode again; the journey turned on; `photo-open-raw` and `photo-open-raw-refused`; RJ-X50's reference PNG from the Mac decode, so the job (`waits_on: SR-7`) runs from this merge | `Tests/SuiteImagingTests/WideGamutRoundTripTests.swift`, `UITests/PhotoJourneyTests+Raw.swift`, `Tests/AppSnapshotTests/PhotoRawSnapshots.swift`, `Tests/RealJobs/photo/raw-develop/raw-develop.jobs.json`, `Tests/RealJobs/photo/raw-develop/expected/tiny-bayer-ev-1.png` | SR-4, SR-6 | ~280, 5 |
| SR-8 | – | The `Raw decode: Raw` concept line; the C4 part names Photo, Library and the CLI as adopters; `status: built`; `feature-done` | `Tests/canonical-concepts.txt`, `docs/c4/parts/creative-apps/suite-imaging/imaging-raw.json`, `docs/blueprints/suiteui/features/shared-raw.wave.json` | SR-7 | ~30, 3 |

SR-1's size is mostly the writer (about 200 lines) and its test; the three
fixtures are a few kilobytes of binary. SR-8's concept line lands last, after
library/raw's files exist under their own names (none of them may be named
`*Raw*` decoders; library/raw keeps its RAW logic in existing files), and the
supervisor runs `scripts/check-dup-logic` on it.

## Build waves

- Wave 1: SR-1. Independent in this wave: SR-1 alone.
- Wave 2: SR-2. Independent in this wave: SR-2 alone.
- Wave 3: SR-3, SR-4, SR-5. Independent in this wave: all three.
- Wave 4: SR-6. Independent in this wave: SR-6 alone.
- Wave 5: SR-7. Independent in this wave: SR-7 alone.
- Wave 6: SR-8. Independent in this wave: SR-8 alone.

Longest chain: SR-1 → SR-2 → SR-5 → SR-6 → SR-7 → SR-8 (6). Chain of 6: the
fixtures before the module that reads them, the contract before Photo's
test, the test before Photo's route, the route and the real decoder before
the live journey and the job's reference, and the concept line last so it
runs over every adopter's final files.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SR-1 | `TinyDNGTests`: each committed file equals `TinyDNG.write`'s bytes; IFD0 is the 32 × 24 preview, the SubIFD the 64 × 48 CFA, Orientation 6, `BaselineExposure` 1.0; the other suites compile, disabled by name | a fixture drifts from its writer, or a tag the decoder needs is missing | – (tests and fixtures) |
| SR-2 | the module builds on Linux without `SystemRawDecoder`; `ImagingBoundaryTests` and `ImageIOImportRatchetTests` green (no Metal, no ImageIO); the fake's table matches the contract comment | a stub signature the adopters call is missing, or the module imports ImageIO or Metal | – (stubs) |
| SR-3 | `RawFormatTests`: every extension of the registry's camera RAW row parses in any case; `DSC_0001.jpg`, `a.tif`, `NEF` with no dot and `.nef` alone don't; each refusal's sentence. `RawDecodePlanTests`: a 32-px preview covers `.thumbnail(32)` but not `.thumbnail(64)`; `.preview(32)` drafts at 0.5; `.full` is scale 1, not draft; undevelopable with a preview gives the preview for thumbnails and `.refuse` otherwise. `RawHeadroomTests`: the fake's decode carries 1.4 and 1.8 linear; `ImagingProgram.adjustments` with Exposure −1 gives them 0.7 and 0.9 (sRGB more than 20 levels apart), while the same buffer clamped to 8 bits first gives two equal values | a format is missed, the preview stands in where it's too small or for export, a refusal is generic, or anything on the path clamps | `SuiteImaging.RawFormat`: compare case-sensitively → `.anyCase`; family check dropped (a TIFF passes) → `.cameraRawOnly`. `SuiteImaging.SuiteRaw`: `>=` to `>` in the preview cover → `.previewCovers`; `draft` true for `.full` → `.fullIsNotDraft`; baseline step skipped → `.baselineApplied`; result clamped to 1 → `.keepsHeadroom` |
| SR-4 | `SystemRawDecoderTests` (macOS): `tiny-bayer.dng` opens and is 48 × 64 upright; `info` names "AfterGlow Test", `previewSize` 24 × 32, baseline 1.0; `.thumbnail(32)` returns the marker colour, `.full` the RAW data's (each within 8/255); `.full` leaves both highlight patches above 1.0 after the baseline; `not-raw.nef` refuses `.unreadable` with "macOS can't read this raw file (NEF)."; `.preview(32)` drafts | the decoder clips, ignores orientation, hands export the preview, or a bad file's refusal is generic | `SuiteImaging.SystemRawDecoder` (on the supervisor's Mac): `boostAmount` left at default → `.linearOutput`; render format `.RGBA8` → `.floatOutput`; orientation not applied → `.upright` |
| SR-5 | compiles, disabled; `scripts/jobs check` | – | – (tests) |
| SR-6 | `PhotoRawOpenTests`: opening `x.DNG` on the fake gives one "Background" layer of 64 × 48 whose highlight patch reads 1.4 (not 1.0); the document is "x", untitled, and Save As offers `x.ora`; opening `y.NEF` (unreadable) throws "macOS can't read this raw file (NEF)." and leaves the open document as it was; on Linux with no decoder the sentence is `.unavailable`'s; `PhotoHeadless.openExtensions` contains `dng` and `cr3` (from the registry); a PNG still opens through `decode` | the RAW route goes through 8 bits, overwrites the RAW on save, or a refusal changes the workspace | `PhotoModel.PhotoImageFile`: the RAW buffer converted to `DecodedImage` first → `.keepsFloat`; refusal after clearing the layers → `.refusalLeavesWorkspace` |
| SR-7 | `WideGamutRoundTripTests`: the PNG's red reads back within 1/1000 of P3 red and, in linear sRGB, with a negative green (still outside sRGB); the TIFF is 16 bits per sample with the P3 profile embedded; the DNG's two highlight patches read back 0.70 and 0.90 (not both 1.0) and a 1/1000 grey step on the ramp survives; `PJ-SR` steps 1 to 4 on live; RJ-X50 on the macOS job; `PhotoRawSnapshots`; `scripts/jobs check` | a colour outside sRGB or a highlight is cut anywhere between decode and the file, the TIFF is 8-bit, the export is the preview's size, or the journey fails | – (macOS) |
| SR-8 | `scripts/check-dup-logic` green with the concept line; `scripts/waves render --dry-run` | an app-local RAW decoder exists, or status isn't built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| headroom | Exposure −1 on the RAW path separates the two highlight patches by more than 20 levels; the 8-bit path doesn't | `RawHeadroomTests`, RJ-X50 |
| wide gamut, high bit depth (beta) | a RAW highlight and a P3 colour outside sRGB survive decode → develop → 16-bit TIFF | `WideGamutRoundTripTests`, suite-imaging's `WideGamutTests` |
| thumbnail fast path | a grid-sized request on a file whose preview covers it never runs `develop` | `RawDecodePlanTests`; library/raw's `LibraryRawTests` |
| decode time (report-only, perf list) | `tiny-bayer.dng` `.thumbnail(32)` under 5 ms and `.full` under 50 ms on the Mac; a 24 MP camera file is the open question R3 | `SystemRawDecoderTests.decodeTime` |
| render: a tone step on a RAW base | p95 ≤ 30 ms at 8K, one display write, like any picture (the base is `rgba16Float`) | suite-imaging's `PhotoAdjustSliderLatencyTests`, unchanged |
| no dead controls; clear refusals | every refusal is one of the four sentences | `RawFormatTests`, `PhotoRawOpenTests` |
| one decoder | no `*Raw*` decoder outside `Sources/SuiteImaging/Raw/` | `scripts/check-dup-logic` (SR-8) |
| one format list | no RAW extension list outside the registry | shared-codecs' `FormatListRatchetTests` |

## Done check

Per slice: SR-a with `TinyDNGTests` green on Linux; SR-m with `Mutate:`
clean on SR-3's plans on Linux and SR-4's on the supervisor's Mac, and
`SystemRawDecoderTests` green on the macOS job; SR-photo with `Mutate:`
clean on Linux; SR-z with `WideGamutRoundTripTests` green on the macOS job and through the feel gate (open a RAW from the panel, drag
Exposure) with its `Mac-Finish:` line, `PJ-SR` green on live and RJ-X50 green on the macOS job. Then
`Belt-Contact-Sheet:` with `photo-open-raw*`, and library/raw's lead is told
SR-m has landed.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| R1 | Will Core Image develop a hand-written CFA DNG? | SR-4 is the spike and runs first; `tiny-linear.dng` is the fallback (the plan and the headroom tests don't care which) |
| R2 | Does `CIRAWFilter`'s output keep values above 1.0 with `boostAmount` 0? | Not needed: `baselineExposure` is set to 0 and `SuiteRaw` applies the file's baseline itself on the float buffer, so the decoder never has to output above 1 |
| R3 | Real camera files (CR3, NEF, ARW, RAF and so on) never run in CI; their pixels are Core Image's. Should a small, licence-clear set run on the captain's Mac in the perf-nightly? Candidates, none fetched: raw.pixls.us (per-file CC0 or CC BY-SA, by camera), Adobe's DNG sample files, the camera makers' own sample pages, and the photographer's own shots | Captain's call. Until then the tiny DNGs are the only fixtures, and R3 stays open in the feature issue |
| R4 | A camera newer than the Mac's RAW support imports in Library with its preview but won't develop. `CIRAWFilter` has `downloadResources(timeout:)` for decoder updates | Post-beta: the refusal sentence is enough for the beta; try the download on a refusal later |
| R5 | Photo opens a RAW at the as-shot white balance and can't re-develop it | Post-beta: an "Open RAW" sheet would need a second decode route; the tone sliders cover the beta |
| R6 | Photo's `.ora` stores 8- or 16-bit layers, so headroom above 1.0 is clipped at save | Accept for the beta: develop and export run before the save; a float layer format is a photo/file-flow question |
