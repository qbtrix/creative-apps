# Feature packet: shared-codecs

**Feature:** one list of the image formats the suite reads and writes, and
one way to read and write them. The list comes first (slice SC-f): SuiteModel's
`SuiteImageFormats` names every format ImageIO reads that we expose (TIFF,
WebP, GIF, BMP, OpenEXR, TGA, HEIC, HEIF, JPEG, PNG, and camera RAW through
`suiteui/shared-raw`) and the four we write (TIFF, PNG, JPEG, HEIC; TIFF at
8 or 16 bits). Every app's open and save panels, Library's import scan and
export formats, the plists' document types and the `afterglow` CLI's
`openExtensions`/`exportFormats` derive from it, and the per-app lists are
deleted in the same slice. Then, PNG
and JPEG go through creative-core's CoreRaster codecs (Linux-safe, the same
bytes everywhere); the formats and facts only macOS knows (HEIC, TIFF, Exif
orientation, colour profile, metadata) go through one ImageIO adapter,
`SuiteImageIO` in SuiteShell. Photo, Library, Halo, Design and Flare call it
instead of their own ImageIO code, and the two hand-rolled PNG writers
(Halo's `HaloFramePNG` and Photo's fallback in `CoreRasterImageCodec`) are
deleted. A ratchet keeps `import ImageIO` in that one file.
**Line:** `line:suiteui` · **Wave:** XK3 (`waves.md`, the canonical burn-down) · **Lead branch:** `lead/shared-codecs`
**Beta:** captain, 2026-10-20 (canonical burn-down, audit rank 6). Labels `beta` and `p1` when filed.

**Covers:** the canonical duplicates audit
(`paw-workspace/docs/design/drafts/2026-10-20-canonical-duplicates-audit.md`),
top-15 #6; the captain's "are we not even supporting TIFF?" (2026-10-21:
Photo opens PNG, JPEG and HEIC and exports PNG and JPEG, while Library
writes four formats through its own list); feature map row
`suiteui/shared-codecs`; real job RJ-X46 (new).

**Why the registry lives in SuiteModel.** It must reach the CLI and the
Models, which SuiteShell (macOS, over SuiteUI) can't. SuiteModel's
`SuiteTypeRegistry.standard` is already the suite's one registry of
document types (the plists mirror it, Open In routes by it), so its public
image rows are built from `SuiteImageFormats`, not listed again. The write
capabilities (quality, alpha, metadata) stay in SuiteKernel's
`ExportFormats.all` (export-pack); `ImageFormatParityTests` keeps the
writable ids and its `.still` rows equal. SuiteImaging reads the registry
too (shared-raw's RAW row), so suite-imaging's IM-1 links SuiteModel into it
(amended in this PR).

**The creative-core bump: none needed.** The audit was read at pin
`0de5687d`, where `PNG.read` and `PNG.write` threw "waits on IC-4/IC-5".
Dev has since moved to `2258b62` (#3549), which carries core's `PNGRead.swift`
and `PNGWrite.swift` (8-bit and 16-bit, the five filters, interlace on read).
SC-1 proves it with a live test before anything is deleted: core's PNG
round-trips the buffers both local writers handle and reads their output
pixel for pixel. If that test fails at the pin, SC-a stops and files a
`scripts/bump-core` PR instead. #3144 (open) also touches
`Package.swift`/`Package.resolved`: its rebase must keep `2258b62` or newer.

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **SC-photo (colour):** SC-4 waits on suite-imaging's IM-m (IM-15,
  `ImagingColor`) for the working space.
- **SC-f:** `PhotoHeadless.swift` was also command-catalog's and
  adopt-command-catalog's (built, now in `depends`);
  `PhotoWindow+Export.swift` is photo/export-pack PX-a's;
  `LibraryValues.swift` is library metadata-more MD-a's; `JPEGWriter.swift`
  and `ExportPresets.swift` are library/export's (EX-b to EX-d) and
  export-pack's (LX-m); `PhotoHeadless.swift` is photo/export-pack PX-m's.
  SC-15 and SC-16 change only the format lists in them; they go first where
  the other owner hasn't started, else after it with the owner told.
- **SC-photo:** `ImageIOCodec.swift` is photo/export-pack PX-m's.
- **SC-library:** `ImageIODecoder.swift` is library/spine's (building),
  metadata-more MD-b's and raw RW-4's; `JPEGWriter.swift` is library/export
  EX-b/EX-c's and export-pack LX-m's. SC-8 starts after spine's feature-done
  and rebases onto whichever of the others lands first.
- **SC-raster:** `DesignRasterizer.swift` and `StageRasterizer.swift` are
  also the vector-raster concept (audit #5, no packet yet); this packet only
  swaps their PNG encode.

**Rule 20.** One format list (`SuiteImageFormats`), one PNG (core), one
JPEG (core), one ImageIO adapter (`SuiteImageIO`). Apps keep their codec protocols (`PhotoImageCodec`,
Library's `PhotoDecoding`/`JPEGWriting`) as thin conformances over it.

**Deleted app-local code:** the per-app format lists, in SC-f:
Photo's `ImageFormat` enum body (`PhotoImageFile.swift`; the name stays as a
typealias of `SuiteImageFormat`), its panel lists in `PhotoWindow+File.swift`
(open `[.png, .jpeg, .heic]`, save `[.png, .jpeg]`) and
`PhotoWindow+Export.swift` (`[exportFormat == .png ? .png : .jpeg]`),
`PhotoHeadless`' literal `openExtensions`/`exportFormats`; Library's
`Contracts/ExportFormats.swift` (deleted; `ExportFormat` becomes a typealias)
and `PhotoFileKind.kind(forFileName:)`'s switch (`LibraryValues.swift`), and
`JPEGWriter`'s UTI switch. These are baseline deletions:
`FormatListRatchetTests` (SC-13) starts with every file above in
`Tests/format-lists-baseline.txt`, each adopting task removes its lines, and
SC-16 deletes the file and makes the ratchet strict. Then
`Sources/HaloModel/HaloFramePNG.swift` and its
plan `Tests/mutations/HaloModel.HaloFramePNG.json` (SC-11), and the
`writePNG`/`readPNG` fallback inside `Sources/PhotoModel/CoreRasterImageCodec.swift`
(SC-4). SC-11 runs `scripts/check-dup-logic --update-baseline` in the same PR
so `Tests/canonical-baseline.txt` drops `HaloFramePNG.swift` (#3642's "Image
codec" line). The other codec files stay as thin conformances, so their
baseline lines stay.

**C4:** a new component part `suite-shell/shell-imageio.json`
(`Sources/SuiteShell/SuiteImageIO.swift`), added by SC-2; SC-14 adds the
registry to `suite-model/suite-identity.json`'s description (the part that
holds `Values/`).

**Clean-room.** ImageIO's documented behaviour and the apps' own tests.

Blueprint sections: suite.md 2.3 (SuiteShell); photo.md (open, export);
library.md (import, export); halo.md (render-out).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SC-f | One registry in SuiteModel lists every image format the suite reads and the four it writes, the plists and the type registry are built from it, and Photo's and Library's panels, import kinds, export formats and the CLI's lists derive from it with the per-app lists deleted and their ratchet strict. | SC-13, SC-14, SC-15, SC-16 | MJ-SC-f, PJ-SC | – (first; AC-export-sheet and AK-8 wait on it) |
| SC-a | Core's PNG is proven to round-trip what both local writers write, the ImageIO import ratchet is live with today's files baselined, and `SuiteImageIO` is declared as stubs in SuiteShell, which links CoreRaster. | SC-1, SC-2 | MJ-SC | suite-imaging:IM-a (SC-2: `Package.swift`, `project.yml`, A/C first) |
| SC-photo | Photo decodes and encodes PNG and JPEG through core and everything else through `SuiteImageIO`, its own ImageIO code and PNG fallback are gone, and the pasteboard uses the same adapter. | SC-3, SC-4 | MJ-SC-photo, PJ-SC | SC-a; photo/export-pack PX-m (SC-4, cross-line hand-off); suite-imaging:IM-m (SC-4, `ImagingColor`) |
| SC-halo | Halo's rendered frames and PNG sequences are core's PNG bytes, so the headless render, the sequence sink and the viewer agree. | SC-5, SC-6 | MJ-SC-halo, HJ-SC | SC-a |
| SC-library | Library scans, decodes, orients and writes through `SuiteImageIO` and core's JPEG, with the same pixel size, capture date and metadata as before. | SC-7, SC-8 | MJ-SC-library, LJ-SC | SC-a; SC-f (SC-8, `JPEGWriter.swift`); library spine, metadata-more, raw, export, export-pack (SC-8, cross-line hand-offs) |
| SC-raster | Design's and Flare's rasterizers hand their pixels to `SuiteImageIO` for PNG instead of their own `CGImageDestination` code. | SC-9, SC-10 | MJ-SC-raster | SC-a |
| SC-z | `HaloFramePNG.swift` is deleted with the baseline shrunk, only `SuiteImageIO.swift` imports ImageIO, and the feature is built. | SC-11, SC-12 | MJ-SC, HJ-SC | SC-photo, SC-halo, SC-library, SC-raster; adopt-kernel-autosave:AK-z (SC-11, `canonical-baseline.txt`, A/C first) |

SC-f runs first: it needs no adapter and waits on nothing. SC-library's
JPEGWriter edit, adopt-kernel-autosave's AK-8 (`PhotoWindow+File.swift`)
and adopt-suiteui-chrome's AC-export-sheet (`PhotoWindow+Export.swift`; not
in the beta, so it must not hold the registry back) wait on it. Drop
targets need no edit: SuiteShell's `suiteFileDrop` routes by
`SuiteTypeRegistry`, which SC-14 builds from the registry, and Photo's
canvas drop hands any file to the same open path SC-15 derives. No new screen (`"ui_slice": "none"`):
the panels list more types, and the export sheets more formats, through
controls that exist. `SuiteImageIO` builds only on macOS;
its plan runs on the supervisor's Mac before `Belt-Slice-Done:` (suiteui
waves, Q10).

**Shared-file chains:** `PhotoWindow+File.swift`: SC-15 → adopt-kernel-autosave
AK-8 → shared-thumbnails ST-7 → adopt-kernel-unsaved-prompt UP-photo.
`Package.swift` and `project.yml`: suite-imaging IM-a
→ SC-a → shared-thumbnails ST-a → suite-imaging IM-z.
`Tests/canonical-baseline.txt`: adopt-kernel-autosave AK-z → SC-11 →
adopt-kernel-unsaved-prompt UP-z → adopt-kernel-eyedropper-photo EP-z →
suite-imaging IM-8d.

## Journey steps

- `MJ-SC-f` (SC-13, Linux): `SuiteImageFormatsTests` and
  `FormatListRatchetTests` in `SuiteModelTests`; `ImageFormatParityTests`
  in `AfterGlowCLITests`; `afterglow apps --json` lists Photo's
  `openExtensions` with `tif`, `webp` and `exr`, and `exportFormats` with
  `tiff` once SC-4's encoder writes it.
- `MJ-SC` (SC-1, Linux): `CorePNGParityTests` in `PhotoModelTests`;
  `ImageIOImportRatchetTests` in `SuiteModelTests`.
- `MJ-SC-photo` (SC-3): `PhotoCodecRouteTests` (Linux). `PJ-SC`
  (`PhotoDocumentsJourneyTests.testSaveLayeredDocumentAndReopen`, existing):
  green unchanged.
- `MJ-SC-halo` (SC-5): `HaloFramePNGCoreTests` (Linux). `HJ-SC`
  (`HaloRenderFrameJourneyTests.testRenderFrame`, existing): the rendered PNG
  decodes and matches the viewer within 1 level.
- `MJ-SC-library` and `LJ-SC` (SC-7): `LibraryImageIOTests` (macOS
  AppSnapshotTests) and the existing Library import journeys, unchanged.
- `MJ-SC-raster` (SC-9): `RasterizerPNGTests` (macOS): Design's and Flare's
  PNG decode with core's `PNG.read` to the same pixels.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X46 | adds, closes with `suiteui/shared-codecs` | Cm | `Tests/RealJobs/photo/rotated-photo/rotated-photo.jobs.json`: `file.open` an Exif-orientation-6 JPEG and a HEIC from the same camera in Photo, `file.export` each as PNG | `input/rotated-6.jpg`, `input/rotated-6.heic` (each 4032 × 3024 stored, 3024 × 4032 shown) |

Trap: one decode path ignores the orientation (a sideways photo) or drops
the colour profile, so the same file opens differently per app. Assertion:
both exports are 3024 × 4032, the sky band at the top is within 2 levels of
the reference crop, and the JPEG's and HEIC's exports match within 3
levels. Cm because the decode crosses ImageIO. Written by SC-3
(`waits_on: SC-3`); `LibraryImageIOTests` checks Library against the same
fixtures.

## Screens and states

None new. Every app's file-open snapshots must not change: the Mac finisher
diffs them against the previous dev run.

## Contract slice

```swift
// Sources/SuiteModel/Values/SuiteImageFormats.swift (SC-14). Linux-safe, Foundation free.
public struct SuiteImageFormat: RawRepresentable, Hashable, Codable, Sendable {
    public enum Family: String, Sendable { case raster, highDynamicRange, cameraRaw }
    public let rawValue: String                  // "tiff": the id the CLI, catalogs and ExportFormats use
    public init?(rawValue: String)                // nil for an id the registry doesn't list
    public var name: String { get }               // "TIFF image"
    public var typeID: SuiteTypeID { get }        // public.tiff
    public var extensions: [String] { get }       // ["tif", "tiff"]; the first is the one we write
    public var family: Family { get }
    public var writeBitDepths: [Int] { get }      // [] read-only; TIFF [8, 16], PNG [8], JPEG and HEIC [8]
    public var title: String { get }              // "TIFF": the panels' and sheets' label
    public var fileExtension: String { get }      // extensions[0]
    public init?(fileName: String)                // by extension, any case
        public static let png, jpeg, heic, heif, tiff, webp, gif, bmp, exr, tga: SuiteImageFormat
    /// One row for every camera RAW extension (cr2, cr3, nef, nrw, arw, sr2, raf, orf, rw2, dng, pef, srw,
    /// 3fr, iiq, erf, mos, x3f), type public.camera-raw-image, family .cameraRaw, read-only. ImageIO reads them
    /// today; suiteui/shared-raw adds the float decode and the refusals on top of this row.
    public static let cameraRaw: SuiteImageFormat
}
public enum SuiteImageFormats {
    /// Read order for panels: png, jpeg, heic, heif, tiff, webp, gif, bmp, exr, tga, cameraRaw.
    public static let all: [SuiteImageFormat]
    public static var readable: [SuiteImageFormat] { get }    // all
    public static var writable: [SuiteImageFormat] { get }    // png, jpeg, heic, tiff
    /// Every extension `all` reads, lower case: an app's `openExtensions` and Library's scan.
    public static var readExtensions: [String] { get }
}
// SuiteTypeRegistry.standard's public image rows are `SuiteImageFormats.all` mapped to
// SuiteDocumentType(id: typeID, name:, extensions:, owner: nil, readers: [.photo, .library]).
```

```swift
// Sources/SuiteShell/SuiteImageIO.swift (SC-2 stubs throwing `.notBuilt`, SC-4 bodies). macOS only.
public enum SuiteImageIO {
    public struct Info: Sendable { public var width, height: Int; public var orientation: Int
        public var captureDate: Date?; public var exif, tiff: [String: any Sendable] }
    public enum Format: Sendable { case png, jpeg(quality: Double), heic(quality: Double), tiff(bitDepth: Int) }
    /// The registry's formats this Mac's ImageIO reads and writes (`CGImageSourceCopyTypeIdentifiers`,
    /// `CGImageDestinationCopyTypeIdentifiers`); a panel or sheet offers the intersection.
    public static var readable: Set<SuiteImageFormat> { get }
    public static var writable: Set<SuiteImageFormat> { get }
    /// The file's facts without decoding pixels (size already oriented).
    public static func info(_ url: URL) throws -> Info
        /// Pixels, oriented, in SuiteImaging's working space (extended-range linear sRGB, Float32, unclamped) from the
    /// file's own ICC profile through `ImagingColor.toWorking`, as CoreRaster's premultiplied buffer. 16-bit and
    /// float sources keep their depth; PNG and JPEG are read by CoreRaster, everything else by ImageIO.
    /// `longestSide` shrinks while decoding.
    public static func decode(_ data: Data, longestSide: Int?) throws -> PixelBuffer
        /// PNG and JPEG by CoreRaster, HEIC and TIFF by ImageIO. The buffer is in the working space;
    /// `ImagingColor.toOutput` takes it to `profile` (default sRGB) at the format's depth, and the profile's ICC
    /// bytes are embedded.
    public static func encode(_ buffer: PixelBuffer, as format: Format, profile: ColorProfile = .sRGB) throws -> Data
    /// For the CoreGraphics rasterizers: the image as PNG through CoreRaster.
    public static func png(_ image: CGImage) throws -> Data
}
```

`ImageIOImportRatchetTests` (SC-1): `import ImageIO` only in
`Sources/SuiteShell/SuiteImageIO.swift`, with today's seven files in
`Tests/imageio-baseline.txt` (shrink-only) until SC-12 deletes it.

## Pseudocode

- **Registry** (SC-14). One table of rows; `SuiteTypeRegistry.standard`
  maps them to its public rows, and Photo's and Library's plists list the
  same types as Alternate readers (`PlistShapeAppsTests` reads them from the
  registry instead of its own literal). OpenEXR's and TGA's type ids are
  ImageIO's (`com.ilm.openexr-image`, `com.truevision.tga-image`).
- **Photo** (SC-15). Open panel: `.ora` plus each readable format's
  `UTType(filenameExtension:)`; save and export panels: the writable formats
  `SuiteImageIO.writable` holds (PNG and JPEG until SC-4's encoder adds HEIC
  and TIFF, so nothing dead is offered); `PhotoHeadless.openExtensions` is
  `["ora"] + SuiteImageFormats.readExtensions`, `exportFormats` the writable
  ids its codec encodes. `ImageFormat` is a typealias, so call sites keep
  `.png` and `.jpeg`.
- **Library** (SC-16). `PhotoFileKind` and `ExportFormat` are typealiases of
  `SuiteImageFormat`; the catalog's coding keeps its two spellings (a kind as
  the id, `"jpeg"`; an export preset's format as the title, `"JPEG"`), so
  every catalog fixture re-encodes byte for byte. The scan accepts every
  readable format; the export sheet offers the writable ones this Mac
  writes.
- **High bit depth and wide gamut (beta).** `decode` reads the file's ICC
  profile (core `ColorProfile(iccData:)`; none means sRGB) and its samples
  at their own depth: a source with more than 8 bits per component (EXR,
  16-bit TIFF and PNG) draws into a Float32 context, and every source goes
  through `ImagingColor.toWorking`, so a Display P3 phone photo keeps its
  out-of-sRGB colours and nothing is cut at 1.0. `encode` runs
  `ImagingColor.toOutput` to the chosen profile and writes 16 bits for
  `.tiff(bitDepth: 16)`, embedding the profile. Photo and Library take the
  float buffer for every file, not only RAW (shared-raw SR-6, library/raw
  RW-3 and RW-4); their 8-bit `DecodedImage`/`DisplayImage` stay only for
  thumbnails and paste.
- **decode.** Sniff the signature: PNG → `PNG.read`, JPEG → core `JPEG.read`
  then the Exif orientation applied with CoreRaster's `rotated`/`flipped`;
  anything else → `CGImageSource` with `kCGImageSourceCreateThumbnailWithTransform`
  into 8-bit sRGB, unpremultiplied with Accelerate as Photo's codec does
  today, then into a `PixelBuffer`.
- **encode.** PNG → `PNG.write`; JPEG → core `JPEG.write(quality:)`;
  HEIC/TIFF → `CGImageDestination`.
- **Photo.** `ImageIOCodec` becomes a 10-line conformance; `CoreRasterImageCodec`
  calls `PNG.read`/`PNG.write` with no `catch .unsupported` fallback.
- **Halo.** `HaloHeadless` and `HaloPNGWriter` call `PNG.write` on the
  rendered frame; the sink keeps its folder and naming rules.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SC-13 | – | **Format tests first.** `SuiteImageFormatsTests` (the rows, ids, extensions in any case, writable set, TIFF's bit depths, the type registry's public rows equal the image rows), `FormatListRatchetTests` live (no image-format literal list under `Sources/` outside `SuiteImageFormats.swift`, today's files in `Tests/format-lists-baseline.txt`), `ImageFormatParityTests` (writable ids equal `ExportFormats.all`'s `.still` ids), all but the ratchet disabled (`waits on SC-14`) | `Tests/SuiteModelTests/SuiteImageFormatsTests.swift`, `Tests/SuiteModelTests/FormatListRatchetTests.swift`, `Tests/format-lists-baseline.txt`, `Tests/AfterGlowCLITests/ImageFormatParityTests.swift` | – | ~260, 4 |
| SC-14 | – | **The registry.** `SuiteImageFormats`; `SuiteTypeRegistry.standard`'s public rows from it; Photo's and Library's plists list every readable type; `PlistShapeAppsTests` reads the registry; the C4 description; turns on SC-13's suites | `Sources/SuiteModel/Values/SuiteImageFormats.swift`, `Sources/SuiteModel/Values/SuiteTypes.swift`, `Bundle/Info/Photo.plist`, `Bundle/Info/Library.plist`, `Tests/SuiteModelTests/PlistShapeAppsTests.swift`, `Tests/SuiteModelTests/SuiteImageFormatsTests.swift`, `Tests/AfterGlowCLITests/ImageFormatParityTests.swift`, `Tests/mutations/SuiteModel.SuiteImageFormats.json`, `docs/c4/parts/creative-apps/suite-model/suite-identity.json` | SC-13 | ~320, 9 |
| SC-15 | – | **Photo derives.** Open, save and export panels and `PhotoHeadless`' lists from the registry; `ImageFormat`'s enum body goes (a typealias); its baseline lines go | `Sources/PhotoModel/PhotoImageFile.swift`, `Sources/PhotoModel/PhotoHeadless.swift`, `Sources/PhotoApp/PhotoWindow+File.swift`, `Sources/PhotoApp/PhotoWindow+Export.swift`, `Tests/PhotoModelTests/PhotoFormatsTests.swift`, `Tests/format-lists-baseline.txt`, `Tests/mutations/PhotoModel.PhotoHeadless.json` | SC-14 | ~260, 7 |
| SC-16 | – | **Library derives, and the ratchet goes strict.** `PhotoFileKind` and `ExportFormat` as typealiases with the catalog's spellings kept; `Contracts/ExportFormats.swift` deleted; `JPEGWriter`'s UTIs from the registry; `Tests/format-lists-baseline.txt` deleted | `Sources/LibraryModel/Contracts/LibraryValues.swift`, `Sources/LibraryModel/Contracts/ExportFormats.swift`, `Sources/LibraryModel/Contracts/ExportPresets.swift`, `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Tests/LibraryModelTests/LibraryFormatsTests.swift`, `Tests/format-lists-baseline.txt`, `Tests/SuiteModelTests/FormatListRatchetTests.swift`, `Tests/mutations/LibraryModel.LibraryValues.json` | SC-15 | ~280, 8 |
| SC-1 | – | **Tests first.** `CorePNGParityTests` (live, Linux): core's PNG round-trips 8-bit RGB and RGBA buffers and reads `HaloFramePNG`'s and `CoreRasterImageCodec.writePNG`'s output pixel for pixel; `ImageIOImportRatchetTests` live with the seven files in `Tests/imageio-baseline.txt`; `SuiteImageIOTests` (macOS) written, disabled | `Tests/PhotoModelTests/CorePNGParityTests.swift`, `Tests/SuiteModelTests/ImageIOImportRatchetTests.swift`, `Tests/imageio-baseline.txt`, `Tests/AppSnapshotTests/SuiteImageIOTests.swift`, `Tests/PhotoModelTests/Fixtures/png-parity/` | – | ~260, 5 |
| SC-2 | – | `SuiteImageIO` as stubs; SuiteShell links CoreRaster in `Package.swift` and `project.yml`; the C4 part. A supervisor merge (`Package.swift`) | `Sources/SuiteShell/SuiteImageIO.swift`, `Package.swift`, `project.yml`, `docs/c4/parts/creative-apps/suite-shell/shell-imageio.json` | SC-1 | ~200, 4 |
| SC-3 | – | **Photo, test first.** `PhotoCodecRouteTests` (Linux), disabled (`waits on SC-4`); RJ-X46's job folder | `Tests/PhotoModelTests/PhotoCodecRouteTests.swift`, `Tests/RealJobs/photo/rotated-photo/rotated-photo.jobs.json`, `Tests/RealJobs/photo/rotated-photo/input/rotated-6.jpg`, `Tests/RealJobs/photo/rotated-photo/input/rotated-6.heic` | SC-2 | ~200, 4 |
| SC-4 | – | **`SuiteImageIO` bodies and Photo on them.** The adapter's decode, encode, info and png; `ImageIOCodec` becomes a conformance over it; `CoreRasterImageCodec` loses its PNG fallback; `PhotoPasteboard` encodes TIFF through it; `readable`/`writable` from ImageIO's type lists, 16-bit TIFF and the float decode for high-bit sources; turns on `PhotoCodecRouteTests` and `SuiteImageIOTests`, and writes and runs `SuiteImageIOFormatsTests` | `Sources/SuiteShell/SuiteImageIO.swift`, `Sources/PhotoApp/ImageIOCodec.swift`, `Sources/PhotoModel/CoreRasterImageCodec.swift`, `Sources/PhotoApp/PhotoPasteboard.swift`, `Tests/PhotoModelTests/PhotoCodecRouteTests.swift`, `Tests/AppSnapshotTests/SuiteImageIOTests.swift`, `Tests/AppSnapshotTests/SuiteImageIOFormatsTests.swift`, `Tests/mutations/PhotoModel.CoreRasterImageCodec.json` | SC-3, SC-14 | ~380, 8 |
| SC-5 | – | **Halo, test first.** `HaloFramePNGCoreTests` (Linux), disabled (`waits on SC-6`): `HaloHeadless`' PNG is `PNG.write`'s bytes and decodes to the rendered frame | `Tests/HaloModelTests/HaloFramePNGCoreTests.swift` | SC-2 | ~150, 1 |
| SC-6 | – | **Halo on core PNG.** `HaloHeadless` and `HaloPNGWriter` write `PNG.write`'s bytes (no `HaloFramePNG`, no ImageIO in the sink); turns on the test | `Sources/HaloModel/HaloHeadless.swift`, `Sources/HaloApp/HaloPNGWriter.swift`, `Tests/HaloModelTests/HaloFramePNGCoreTests.swift`, `Tests/mutations/HaloModel.HaloHeadless.json` | SC-5 | ~180, 4 |
| SC-7 | – | **Library, test first.** `LibraryImageIOTests` (macOS), disabled (`waits on SC-8`): the import fixtures scan to the same pixel size, capture date and Exif as today; RJ-X46's fixtures decode upright | `Tests/AppSnapshotTests/LibraryImageIOTests.swift`, `Tests/AppSnapshotTests/Fixtures/library-imageio-expected.json` | SC-2 | ~200, 2 |
| SC-8 | – | **Library on the adapter.** `ImageIODecoder` scans with `SuiteImageIO.info` and decodes with `decode(longestSide:)`; `JPEGWriter` writes with `encode` (sidecars unchanged); their ImageIO code goes; turns on the test | `Sources/LibraryApp/Platform/ImageIODecoder.swift`, `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Tests/AppSnapshotTests/LibraryImageIOTests.swift` | SC-7, SC-4, SC-16 | ~320, 3 |
| SC-9 | – | **Design and Flare, test first.** `RasterizerPNGTests` (macOS), disabled (`waits on SC-10`) | `Tests/AppSnapshotTests/RasterizerPNGTests.swift` | SC-2 | ~150, 1 |
| SC-10 | – | `DesignRasterizer` and `StageRasterizer` encode through `SuiteImageIO.png`; their ImageIO imports go; turns on the test | `Sources/DesignApp/DesignRasterizer.swift`, `Sources/FlareApp/StageRasterizer.swift`, `Tests/AppSnapshotTests/RasterizerPNGTests.swift` | SC-9, SC-4 | ~120, 3 |
| SC-11 | – | **Halo delete.** Removes `HaloFramePNG.swift`, its plan and `CorePNGParityTests`' reference to it; `scripts/check-dup-logic --update-baseline` drops its line | `Sources/HaloModel/HaloFramePNG.swift`, `Tests/mutations/HaloModel.HaloFramePNG.json`, `Tests/PhotoModelTests/CorePNGParityTests.swift`, `Tests/canonical-baseline.txt` | SC-6 | ~120, 4 |
| SC-12 | – | The ratchet strict (`Tests/imageio-baseline.txt` deleted); the C4 part names the adopters; `status: built`; `feature-done` | `Tests/imageio-baseline.txt`, `Tests/SuiteModelTests/ImageIOImportRatchetTests.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-imageio.json`, `docs/blueprints/suiteui/features/shared-codecs.wave.json` | SC-4, SC-8, SC-10 | ~40, 4 |

## Build waves

- Wave 1: SC-13, SC-1. Independent in this wave: both.
- Wave 2: SC-14, SC-2. Independent in this wave: both.
- Wave 3: SC-15, SC-3, SC-5, SC-7, SC-9. Independent in this wave: all.
- Wave 4: SC-16, SC-4, SC-6. Independent in this wave: all.
- Wave 5: SC-8, SC-10, SC-11. Independent in this wave: all.
- Wave 6: SC-12. Independent in this wave: SC-12 alone.

Longest chain: SC-13 → SC-14 → SC-15 → SC-16 → SC-8 → SC-12 (6), tied with SC-1 → SC-2 → SC-3 → SC-4 → SC-8 → SC-12. Chain of 6: the format tests before the registry, the registry before Photo and then Library derive from it (they share the baseline file), Library's writer list before the writer moves onto the adapter, and the strict ImageIO ratchet waits for every app. The adapter chain is the parity proof, the stubs, Photo's test, the bodies, Library's caller, the ratchet.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SC-13 | the ratchet green with the baseline and failing a fixture `[.png, .jpeg]` in `Sources/DesignApp/X.swift`; the rest compile, disabled by name | a new per-app format list passes | – (tests) |
| SC-14 | `SuiteImageFormatsTests`: TIFF reads `a.TIF` and `a.tiff`, writes 8 and 16 bits; WebP, GIF, BMP, EXR, TGA and HEIF are readable, not writable; `SuiteTypeRegistry.standard.type(forExtension: "webp")` is Photo's and Library's; `PlistShapeAppsTests` green on the new rows; `ImageFormatParityTests` | a format is missing, a read-only format is offered for writing, or the plists drift from the registry | `SuiteModel.SuiteImageFormats`: `tif` dropped from TIFF → `.tiffBothExtensions`; EXR marked writable → `.writableIsFour`; extension compared case-sensitively → `.anyCase` |
| SC-15 | `PhotoFormatsTests` (Linux): `PhotoHeadless.openExtensions` holds `ora` and every readable extension; `exportFormats` only what its codec writes; `ImageFormat(fileName: "a.TIFF")` is `.tiff`; Photo's journeys unchanged; the ratchet with four fewer baseline lines | a panel or the CLI keeps its own list, or offers a format nothing writes | `PhotoModel.PhotoHeadless`: export list from `writable` without the codec filter → `.noDeadFormats` |
| SC-16 | `LibraryFormatsTests`: every catalog fixture re-encodes byte for byte; a folder with `.tif`, `.webp` and `.exr` scans all three; the export formats equal the registry's writable ones this Mac writes; the ratchet strict | a catalog's spelling changes, a readable file is skipped, or a list survives | `LibraryModel.LibraryValues`: kind from a local switch → `.kindFromRegistry`; preset coded as the id → `.presetSpelling` |
| SC-1 | `CorePNGParityTests` green at the pin; the ratchet fails a fixture `import ImageIO` in `Sources/HaloModel/` | core's PNG can't replace the local writers (then the slice stops for a core bump), or an eighth ImageIO file passes | – (tests; the parity test is the oracle for the deletes) |
| SC-2 | builds on macOS; `swift build` on Linux unchanged; `SuiteImageIOTests` disabled by name | SuiteShell can't see `PixelBuffer` | – (stubs) |
| SC-3 | compiles, disabled; `scripts/jobs check` | – | – (tests) |
| SC-4 | `SuiteImageIOTests` (Exif 6 upright, a P3 PNG converted to sRGB, HEIC round trip); `SuiteImageIOFormatsTests` (each readable format's fixture decodes, each writable one round-trips, a 16-bit TIFF keeps a 1/1000 step that 8 bits loses, an EXR value above 1 survives decode, a Display P3 PNG's out-of-sRGB red decodes outside sRGB and a 16-bit TIFF written with the P3 profile reads back within 1/1000); `PhotoCodecRouteTests` (PNG never falls back); RJ-X46 on the macOS job | a sideways or colour-shifted decode, or the fallback still runs | `PhotoModel.CoreRasterImageCodec`: JPEG routed to the PNG reader → `.formatSniff`; core error swallowed into an empty buffer → `.errorsSurface` |
| SC-5 | compiles, disabled | – | – (test) |
| SC-6 | `HaloFramePNGCoreTests`; `HJ-SC` | a frame's bytes differ from core's, or the viewer and the file differ | `HaloModel.HaloHeadless`: alpha written premultiplied → `.straightAlpha`; frame name ignores the plan → `.namedByPlan` |
| SC-7 | compiles, disabled | – | – (test) |
| SC-8 | `LibraryImageIOTests`; Library's import and export journeys unchanged | a scanned size, date or Exif field changes | – (macOS App code; `LibraryImageIOTests` is the oracle) |
| SC-9 | compiles, disabled | – | – (test) |
| SC-10 | `RasterizerPNGTests`; Design's and Flare's export journeys unchanged | an exported PNG's pixels change | – (App code) |
| SC-11 | Halo's Model tests; `scripts/check-dup-logic`; `scripts/mutate --validate` | a deleted symbol is referenced, or the baseline names a gone file | – (deletion) |
| SC-12 | `ImageIOImportRatchetTests` strict; `scripts/waves render --dry-run` | an ImageIO import outside the adapter, or status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| same file, same picture | an Exif-6 JPEG and HEIC open upright and within 3 levels in Photo and Library | RJ-X46, `LibraryImageIOTests` |
| no slower | a 24 MP JPEG decodes at `longestSide: 512` within 10% of today's time | `SuiteImageIOTests.thumbnailDecodeTime` (report-only) |
| render: Photo open of a 24 MP file | ≤ 3 window bodies from Open to first paint (Photo's existing open budget) | `RenderBudgetPhotoOpenTests` (existing) |
| one ImageIO user | `import ImageIO` only in `SuiteImageIO.swift` | `ImageIOImportRatchetTests` |
| one format list | no image-format literal list under `Sources/` outside the registry | `FormatListRatchetTests` (strict from SC-16) |
| no dead formats | a panel, sheet or the CLI offers only formats this Mac reads or writes | `PhotoFormatsTests`, `LibraryFormatsTests`, `SuiteImageIOFormatsTests` |
| one PNG writer | no PNG chunk literals (`"IHDR"`, `"IDAT"`) under `Sources/` | `ImageIOImportRatchetTests.noHandRolledPNG` (SC-12) |

## Done check

Per slice: SC-f with `FormatListRatchetTests` strict and `Mutate:` clean on
Linux, Photo's and Library's journeys unchanged (the feel gate opens a TIFF
in each); SC-photo only with `SuiteImageIOFormatsTests` green on the macOS
job, including the wide-gamut round trip (a Display P3 16-bit PNG decodes,
develops and writes a 16-bit TIFF with the P3 profile embedded, its
out-of-sRGB red within 1/1000); SC-a with `CorePNGParityTests` green at the pin; each app slice's
Model walk and existing journeys green, the feel gate's `Mac-Finish:` line;
SC-z with the strict ratchet and RJ-X46 green on the macOS job. Then
`Belt-Contact-Sheet:` with one opened file per app.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| Q1 | Which profile does an export default to: sRGB (safest for the web) or Display P3 (keeps a wide photo wide)? | sRGB for JPEG and PNG, the source's profile (P3 when the photo came in P3) for TIFF and HEIC; the export sheet shows it, the CLI takes `profile` |
| Q2 | WebP, GIF and BMP writing (ImageIO writes some of them on current macOS) | Not exposed in the beta: the writable list stays the four the captain named; adding one is a registry row and an `ExportFormats` row |
