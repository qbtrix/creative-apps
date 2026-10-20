# Feature packet: shared-codecs

**Feature:** one way to read and write image files across the suite. PNG
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
top-15 #6; feature map row `suiteui/shared-codecs`; real job RJ-X46 (new).

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
- **SC-photo:** `ImageIOCodec.swift` is photo/export-pack PX-m's.
- **SC-library:** `ImageIODecoder.swift` is library/spine's (building),
  metadata-more MD-b's and raw RW-b's; `JPEGWriter.swift` is library/export
  EX-b/EX-c's and export-pack LX-m's. SC-8 starts after spine's feature-done
  and rebases onto whichever of the others lands first.
- **SC-raster:** `DesignRasterizer.swift` and `StageRasterizer.swift` are
  also the vector-raster concept (audit #5, no packet yet); this packet only
  swaps their PNG encode.

**Rule 20.** One PNG (core), one JPEG (core), one ImageIO adapter
(`SuiteImageIO`). Apps keep their codec protocols (`PhotoImageCodec`,
Library's `PhotoDecoding`/`JPEGWriting`) as thin conformances over it.

**Deleted app-local code:** `Sources/HaloModel/HaloFramePNG.swift` and its
plan `Tests/mutations/HaloModel.HaloFramePNG.json` (SC-11), and the
`writePNG`/`readPNG` fallback inside `Sources/PhotoModel/CoreRasterImageCodec.swift`
(SC-4). SC-11 runs `scripts/check-dup-logic --update-baseline` in the same PR
so `Tests/canonical-baseline.txt` drops `HaloFramePNG.swift` (#3642's "Image
codec" line). The other codec files stay as thin conformances, so their
baseline lines stay.

**C4:** a new component part `suite-shell/shell-imageio.json`
(`Sources/SuiteShell/SuiteImageIO.swift`), added by SC-2.

**Clean-room.** ImageIO's documented behaviour and the apps' own tests.

Blueprint sections: suite.md 2.3 (SuiteShell); photo.md (open, export);
library.md (import, export); halo.md (render-out).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SC-a | Core's PNG is proven to round-trip what both local writers write, the ImageIO import ratchet is live with today's files baselined, and `SuiteImageIO` is declared as stubs in SuiteShell, which links CoreRaster. | SC-1, SC-2 | MJ-SC | suite-imaging:IM-a (SC-2: `Package.swift`, `project.yml`, A/C first) |
| SC-photo | Photo decodes and encodes PNG and JPEG through core and everything else through `SuiteImageIO`, its own ImageIO code and PNG fallback are gone, and the pasteboard uses the same adapter. | SC-3, SC-4 | MJ-SC-photo, PJ-SC | SC-a; photo/export-pack PX-m (SC-4, cross-line hand-off) |
| SC-halo | Halo's rendered frames and PNG sequences are core's PNG bytes, so the headless render, the sequence sink and the viewer agree. | SC-5, SC-6 | MJ-SC-halo, HJ-SC | SC-a |
| SC-library | Library scans, decodes, orients and writes through `SuiteImageIO` and core's JPEG, with the same pixel size, capture date and metadata as before. | SC-7, SC-8 | MJ-SC-library, LJ-SC | SC-a; library spine, metadata-more, raw, export, export-pack (SC-8, cross-line hand-offs) |
| SC-raster | Design's and Flare's rasterizers hand their pixels to `SuiteImageIO` for PNG instead of their own `CGImageDestination` code. | SC-9, SC-10 | MJ-SC-raster | SC-a |
| SC-z | `HaloFramePNG.swift` is deleted with the baseline shrunk, only `SuiteImageIO.swift` imports ImageIO, and the feature is built. | SC-11, SC-12 | MJ-SC, HJ-SC | SC-photo, SC-halo, SC-library, SC-raster; adopt-kernel-autosave:AK-z (SC-11, `canonical-baseline.txt`, A/C first) |

No new screen (`"ui_slice": "none"`). `SuiteImageIO` builds only on macOS;
its plan runs on the supervisor's Mac before `Belt-Slice-Done:` (suiteui
waves, Q10).

**Shared-file chains:** `Package.swift` and `project.yml`: suite-imaging IM-a
→ SC-a → shared-thumbnails ST-a → suite-imaging IM-z.
`Tests/canonical-baseline.txt`: adopt-kernel-autosave AK-z → SC-11 →
adopt-kernel-unsaved-prompt UP-z → adopt-kernel-eyedropper-photo EP-z →
suite-imaging IM-8d.

## Journey steps

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
// Sources/SuiteShell/SuiteImageIO.swift (SC-2 stubs throwing `.notBuilt`, SC-4 bodies). macOS only.
public enum SuiteImageIO {
    public struct Info: Sendable { public var width, height: Int; public var orientation: Int
        public var captureDate: Date?; public var exif, tiff: [String: any Sendable] }
    public enum Format: Sendable { case png, jpeg(quality: Double), heic(quality: Double), tiff }
    /// The file's facts without decoding pixels (size already oriented).
    public static func info(_ url: URL) throws -> Info
    /// Pixels, oriented and in sRGB, as CoreRaster's premultiplied linear buffer. PNG and JPEG are
    /// read by CoreRaster; everything else by ImageIO. `longestSide` shrinks while decoding.
    public static func decode(_ data: Data, longestSide: Int?) throws -> PixelBuffer
    /// PNG and JPEG by CoreRaster, HEIC and TIFF by ImageIO.
    public static func encode(_ buffer: PixelBuffer, as format: Format) throws -> Data
    /// For the CoreGraphics rasterizers: the image as PNG through CoreRaster.
    public static func png(_ image: CGImage) throws -> Data
}
```

`ImageIOImportRatchetTests` (SC-1): `import ImageIO` only in
`Sources/SuiteShell/SuiteImageIO.swift`, with today's seven files in
`Tests/imageio-baseline.txt` (shrink-only) until SC-12 deletes it.

## Pseudocode

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
| SC-1 | – | **Tests first.** `CorePNGParityTests` (live, Linux): core's PNG round-trips 8-bit RGB and RGBA buffers and reads `HaloFramePNG`'s and `CoreRasterImageCodec.writePNG`'s output pixel for pixel; `ImageIOImportRatchetTests` live with the seven files in `Tests/imageio-baseline.txt`; `SuiteImageIOTests` (macOS) written, disabled | `Tests/PhotoModelTests/CorePNGParityTests.swift`, `Tests/SuiteModelTests/ImageIOImportRatchetTests.swift`, `Tests/imageio-baseline.txt`, `Tests/AppSnapshotTests/SuiteImageIOTests.swift`, `Tests/PhotoModelTests/Fixtures/png-parity/` | – | ~260, 5 |
| SC-2 | – | `SuiteImageIO` as stubs; SuiteShell links CoreRaster in `Package.swift` and `project.yml`; the C4 part. A supervisor merge (`Package.swift`) | `Sources/SuiteShell/SuiteImageIO.swift`, `Package.swift`, `project.yml`, `docs/c4/parts/creative-apps/suite-shell/shell-imageio.json` | SC-1 | ~200, 4 |
| SC-3 | – | **Photo, test first.** `PhotoCodecRouteTests` (Linux), disabled (`waits on SC-4`); RJ-X46's job folder | `Tests/PhotoModelTests/PhotoCodecRouteTests.swift`, `Tests/RealJobs/photo/rotated-photo/rotated-photo.jobs.json`, `Tests/RealJobs/photo/rotated-photo/input/rotated-6.jpg`, `Tests/RealJobs/photo/rotated-photo/input/rotated-6.heic` | SC-2 | ~200, 4 |
| SC-4 | – | **`SuiteImageIO` bodies and Photo on them.** The adapter's decode, encode, info and png; `ImageIOCodec` becomes a conformance over it; `CoreRasterImageCodec` loses its PNG fallback; `PhotoPasteboard` encodes TIFF through it; turns on `PhotoCodecRouteTests` and `SuiteImageIOTests` | `Sources/SuiteShell/SuiteImageIO.swift`, `Sources/PhotoApp/ImageIOCodec.swift`, `Sources/PhotoModel/CoreRasterImageCodec.swift`, `Sources/PhotoApp/PhotoPasteboard.swift`, `Tests/PhotoModelTests/PhotoCodecRouteTests.swift`, `Tests/AppSnapshotTests/SuiteImageIOTests.swift`, `Tests/mutations/PhotoModel.CoreRasterImageCodec.json` | SC-3 | ~350, 7 |
| SC-5 | – | **Halo, test first.** `HaloFramePNGCoreTests` (Linux), disabled (`waits on SC-6`): `HaloHeadless`' PNG is `PNG.write`'s bytes and decodes to the rendered frame | `Tests/HaloModelTests/HaloFramePNGCoreTests.swift` | SC-2 | ~150, 1 |
| SC-6 | – | **Halo on core PNG.** `HaloHeadless` and `HaloPNGWriter` write `PNG.write`'s bytes (no `HaloFramePNG`, no ImageIO in the sink); turns on the test | `Sources/HaloModel/HaloHeadless.swift`, `Sources/HaloApp/HaloPNGWriter.swift`, `Tests/HaloModelTests/HaloFramePNGCoreTests.swift`, `Tests/mutations/HaloModel.HaloHeadless.json` | SC-5 | ~180, 4 |
| SC-7 | – | **Library, test first.** `LibraryImageIOTests` (macOS), disabled (`waits on SC-8`): the import fixtures scan to the same pixel size, capture date and Exif as today; RJ-X46's fixtures decode upright | `Tests/AppSnapshotTests/LibraryImageIOTests.swift`, `Tests/AppSnapshotTests/Fixtures/library-imageio-expected.json` | SC-2 | ~200, 2 |
| SC-8 | – | **Library on the adapter.** `ImageIODecoder` scans with `SuiteImageIO.info` and decodes with `decode(longestSide:)`; `JPEGWriter` writes with `encode` (sidecars unchanged); their ImageIO code goes; turns on the test | `Sources/LibraryApp/Platform/ImageIODecoder.swift`, `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Tests/AppSnapshotTests/LibraryImageIOTests.swift` | SC-7, SC-4 | ~320, 3 |
| SC-9 | – | **Design and Flare, test first.** `RasterizerPNGTests` (macOS), disabled (`waits on SC-10`) | `Tests/AppSnapshotTests/RasterizerPNGTests.swift` | SC-2 | ~150, 1 |
| SC-10 | – | `DesignRasterizer` and `StageRasterizer` encode through `SuiteImageIO.png`; their ImageIO imports go; turns on the test | `Sources/DesignApp/DesignRasterizer.swift`, `Sources/FlareApp/StageRasterizer.swift`, `Tests/AppSnapshotTests/RasterizerPNGTests.swift` | SC-9, SC-4 | ~120, 3 |
| SC-11 | – | **Halo delete.** Removes `HaloFramePNG.swift`, its plan and `CorePNGParityTests`' reference to it; `scripts/check-dup-logic --update-baseline` drops its line | `Sources/HaloModel/HaloFramePNG.swift`, `Tests/mutations/HaloModel.HaloFramePNG.json`, `Tests/PhotoModelTests/CorePNGParityTests.swift`, `Tests/canonical-baseline.txt` | SC-6 | ~120, 4 |
| SC-12 | – | The ratchet strict (`Tests/imageio-baseline.txt` deleted); the C4 part names the adopters; `status: built`; `feature-done` | `Tests/imageio-baseline.txt`, `Tests/SuiteModelTests/ImageIOImportRatchetTests.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-imageio.json`, `docs/blueprints/suiteui/features/shared-codecs.wave.json` | SC-4, SC-8, SC-10 | ~40, 4 |

## Build waves

- Wave 1: SC-1. Independent in this wave: SC-1 alone.
- Wave 2: SC-2. Independent in this wave: SC-2 alone.
- Wave 3: SC-3, SC-5, SC-7, SC-9. Independent in this wave: all.
- Wave 4: SC-4, SC-6. Independent in this wave: both.
- Wave 5: SC-8, SC-10, SC-11. Independent in this wave: all.
- Wave 6: SC-12. Independent in this wave: SC-12 alone.

Longest chain: SC-1 → SC-2 → SC-3 → SC-4 → SC-8 → SC-12 (6). Chain of 6: the parity proof before the adapter's stubs, the stubs before Photo's test, Photo's task fills the adapter's bodies, Library calls those bodies, and the strict ratchet waits for every app.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SC-1 | `CorePNGParityTests` green at the pin; the ratchet fails a fixture `import ImageIO` in `Sources/HaloModel/` | core's PNG can't replace the local writers (then the slice stops for a core bump), or an eighth ImageIO file passes | – (tests; the parity test is the oracle for the deletes) |
| SC-2 | builds on macOS; `swift build` on Linux unchanged; `SuiteImageIOTests` disabled by name | SuiteShell can't see `PixelBuffer` | – (stubs) |
| SC-3 | compiles, disabled; `scripts/jobs check` | – | – (tests) |
| SC-4 | `SuiteImageIOTests` (Exif 6 upright, a P3 PNG converted to sRGB, HEIC round trip); `PhotoCodecRouteTests` (PNG never falls back); RJ-X46 on the macOS job | a sideways or colour-shifted decode, or the fallback still runs | `PhotoModel.CoreRasterImageCodec`: JPEG routed to the PNG reader → `.formatSniff`; core error swallowed into an empty buffer → `.errorsSurface` |
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
| one PNG writer | no PNG chunk literals (`"IHDR"`, `"IDAT"`) under `Sources/` | `ImageIOImportRatchetTests.noHandRolledPNG` (SC-12) |

## Done check

Per slice: SC-a with `CorePNGParityTests` green at the pin; each app slice's
Model walk and existing journeys green, the feel gate's `Mac-Finish:` line;
SC-z with the strict ratchet and RJ-X46 green on the macOS job. Then
`Belt-Contact-Sheet:` with one opened file per app.
