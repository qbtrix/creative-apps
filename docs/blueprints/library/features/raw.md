# Feature packet: raw

**Feature:** camera RAW files import, show and develop in Library through
the suite's shared RAW decode (`suiteui/shared-raw`, SuiteImaging's `Raw/`
module over Core Image). Library adds only what is Library's: which quality each caller asks for and
the float route from the decoder to develop. Which files are RAW is
shared-codecs' format registry: after its SC-16, Library's `PhotoFileKind`
is the registry's `SuiteImageFormat`, so the scan already takes RAW files. The grid draws each file's embedded preview, so a RAW import is as
fast as a JPEG one; the loupe and export decode every pixel into a Float32
buffer in SuiteImaging's working space (extended-range linear sRGB, unclamped), for every photo and not only RAW, so Develop's shared tone sliders
(Exposure, White Balance, Highlights) work with a RAW file's headroom and a
Display P3 phone photo keeps the colours sRGB can't hold. Export takes the
same buffer to the file's profile at its depth (16-bit TIFF included). A file the system can't read
is listed with the shared refusal sentence; a camera it can't develop yet
still imports and culls on its preview.
**Line:** `line:library` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/raw`
**Beta:** captain, 2026-10-21 ("RAW in beta, and it should be shared").
Labels `beta` and `p1`. Feature issue #1530.

**Covers:** #427 (closes with RW-6, which carries `feature-done`); feature
map row `library/raw` (new) and the library adopter of `suiteui/shared-raw`;
real job RJ-L22 (closes with this packet).

**Re-cut 2026-10-21: Library's thin adoption of the shared RAW.** The
earlier cut built a Library-only decoder (`Platform/RawDecoding.swift`,
`RawFileTypes.swift`, a tiny DNG under `Tests/AppSnapshotTests/`), RAW-only
develop rows, RAW+JPEG pairing and a grid tag. The decoder, the decode plan,
the refusal sentences and the test DNGs now live once in
`suiteui/shared-raw`, and none of those files will be written here. The
shared tone sliders are the only develop controls, so this packet adds no
develop settings and no catalog keys. Pairing (RJ-L21) and the grid's RAW
tag are post-beta (open questions R1, R2). `c4-planned.json` drops the
planned `RawFileTypes.swift` in the same PR.

**Depends on:** `import` and `thumbnails` (built). **Cross-line:** suiteui `shared-codecs` **SC-f** before RW-2 (the
registry's camera RAW kind; SC-16 also edits `LibraryValues.swift`, which
this packet no longer touches); suiteui `shared-raw` **SR-a** before RW-1 (its contract and
`FakeRawDecoder`) and **SR-m** before RW-4 (the system decoder);
suiteui `shared-codecs` **SC-library** before RW-4 (`ImageIODecoder.swift`
and `JPEGWriter.swift` move onto `SuiteImageIO`; its decode is already in the
working space); suiteui `shared-thumbnails` **ST-m** and
`suite-imaging` **IM-library** before RW-3 (`LiveThumbnails.swift`,
`LiveLoupeImaging.swift`). **Same line:** export-pack **LX-a** before RW-2
(`LibraryContracts.swift`) and **LX-m** before RW-3 (`LiveExporter.swift`);
both come after `export`. metadata-more (not in the beta) now waits on this
packet instead of the other way round: its MD-3 waits on RW-a
(`FakePlatform.swift`) and its MD-7 on RW-m (`ImageIODecoder.swift`),
re-cut in this PR. No creative-core issue, no
`needs-ui` issue.

Blueprint sections: 1.3 (raw through the system decoder), 2.3
(`library-app-platform`), 5.1 (`PhotoDecoding`), 6.1 (thumbnails), 10.1
(D11, now taken for RAW files).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| RW-a | `PhotoDecoding` offers a float decode with a default, the fake decoder answers RAW files from the shared fake, and a RAW file is the registry's camera RAW kind. | RW-1, RW-2 | RJ0 | export-pack:LX-a (RW-2); suiteui shared-codecs SC-f (RW-2) and shared-raw SR-a (cross-line) |
| RW-m | The grid asks for the embedded preview, the loupe for a draft then every pixel, export for every pixel, all as float, and the platform decoder scans, refuses and decodes RAW files through `SuiteRaw`. | RW-3, RW-4 | RJ0, RJ-mac | RW-a; export-pack:LX-m (RW-3, RW-4: `LiveExporter.swift`, `JPEGWriter.swift`); suiteui ST-m, IM-library (RW-3), SC-library and shared-raw SR-m (RW-4) (cross-line) |
| RW-z | On live services a folder with a RAW file imports, shows its preview, develops in the loupe and exports at full size, and the feature is built. | RW-5, RW-6 | RJ1 | RW-m |

RW-m is the UI slice (`"ui": true`): RW-4 changes
`Sources/LibraryApp/Platform/ImageIODecoder.swift`, and it waits on no slice
of this feature but the contract (rule 18). There is no new screen: the
grid, loupe, Develop tab and import notice draw RAW photos as they draw any
photo.

## Journey steps

**RJ0 · `LibraryRawTests`** (Linux; RW-1, cases turned on by RW-2 and RW-3):
1. `PhotoFileKind.kind(forFileName: "DSC_0001.NEF")` is the registry's
   `.cameraRaw`, and so for every extension in that row in any case;
   `IMG.jpg` stays `.jpeg` (a guard on shared-codecs' SC-16, not a rule of
   this packet's).
2. A test decoder that implements only `scan` and `decode` answers
   `decodeLinear` with nil.
3. On the fakes: a `.DNG` photo's thumbnail asks `.thumbnail`, the loupe's
   preview `.preview`, its full render and export `.full`; a JPEG photo never
   calls `decodeLinear`'s RAW route.
4. Exposure −1 on the fake DNG's loupe render keeps the two highlight
   patches more than 20 levels apart (the float route reached develop).
5. Exporting the fake `p3-red` photo as TIFF hands the writer a 16-bit,
   Display P3 request whose buffer still holds the P3 red outside sRGB (a
   recording writer); the same export as JPEG asks for sRGB.

**RJ-mac · `LibraryRawDecodeTests`** (macOS, RW-4): shared-raw's
`tiny-bayer.dng` scans as `.cameraRaw` with its size 48 × 64 and capture facts;
`not-raw.nef` fails the scan with "macOS can't read this raw file (NEF).";
the thumbnail is the preview's marker colour, the full decode the RAW data's.

**RJ1 · `LibraryRawJourneyTests.testImportDevelopExportRaw`**
(`UITests/LibraryJourneyTests+Raw.swift`; written by RW-1 with
`XCTSkip("waits on RW-5")`, turned on by RW-5; all steps live)
1. Copy shared-raw's `tiny-bayer.dng` (as `DSC_0001.DNG`) and `not-raw.nef`
   (as `DSC_0002.NEF`) and one JPEG into a temp folder. Launch with
   `-LibraryImportFolder` on it and click **Import Folder…**. Shot
   `library-raw-imported`. Expect 2 cells and the notice "Imported 2 photos.
   1 file couldn't be imported." whose **Show** lists `DSC_0002.NEF: macOS
   can't read this raw file (NEF).`
2. Every cell's value starts with `ready` within 10 s.
3. Double-click `DSC_0001`. Expect `library.loupe.photo`'s value to start
   with `full` within 10 s. Shot `library-raw-loupe`.
4. In Develop, drag Exposure to −1. Expect the loupe checksum to change
   (under `-LibraryTestValues`).
5. Export the photo as JPEG at original size. Expect the file 48 × 64.
States: loading (cells before `ready`), error (unreadable RAW in the notice).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L22 | closes with `library/raw` (was `needs_note: "raw RW-b"`) | Cm | `LibraryRawDecodeTests.embeddedPreviewFirst` (RW-4) and RJ1 step 2; a CLI check waits on Library's catalog gaining an import command (R3) | shared-raw's `tiny-bayer.dng` |

Trap: RAW files are skipped on import, or every thumbnail waits for a full
decode. Assertion: the thumbnail is the preview's marker colour and arrives
without a `develop` call (the recording decoder in `LibraryRawTests` counts
them). RJ-L21 (RAW+JPEG pairs) stays without a packet (R1).

## Screens and states

| Screen | Error | Loading |
|---|---|---|
| Grid cell (RAW) | a camera the system can't develop still shows its preview | as today |
| Import notice | "<name>: macOS can't read this raw file (NEF)." in the failure list | unchanged |
| Loupe | a camera it can't develop: "Couldn't render this photo: macOS can't develop raw files from <camera> yet.", the preview stays | `preview` first, as today |

Snapshots: none new beyond the journey's whole-window shots; the grid,
loupe and Develop views are unchanged.

## Contract slice

`PhotoFileKind` is shared-codecs' `SuiteImageFormat` (SC-16); its
`.cameraRaw` row is the RAW kind, so `LibraryValues.swift` gets no edit here.

`Sources/LibraryModel/Contracts/LibraryContracts.swift` (RW-2):

```swift
extension PhotoDecoding {
    /// The file's pixels at `quality` (SuiteImaging's `RawQuality`; non-RAW files read it as a size) in the
    /// working space (extended-range linear sRGB, Float32, unclamped), upright, nothing clipped. Nil when the
    /// decoder has no float route (the default, so `FakeDecoder` and every test decoder compile unchanged);
    /// callers then take `decode`'s 8-bit route. Throws `LibraryError.renderFailed(refusal.message)`.
    func decodeLinear(path: String, quality: RawQuality) async throws -> PixelBuffer?
}
extension JPEGWriting {
    /// Writes a working-space buffer as `format` at `bitDepth` in `profile` (shared-codecs' `SuiteImageIO.encode`).
    /// Default: converts to `DisplayImage` and calls `write(_:quality:folder:fileName:)`, so fakes compile unchanged.
    func write(linear: PixelBuffer, format: SuiteImageFormat, bitDepth: Int, profile: ColorProfile,
               quality: Int, folder: String, fileName: String) async throws
}
```

`Sources/LibraryModel/Fakes/FakePlatform.swift` (RW-2): `FakeDecoder`
answers `decodeLinear` for RAW names through SuiteImaging's
`FakeRawDecoder`, and for `p3-*` fixture names with a working-space buffer
holding a Display P3 red outside sRGB.

## Pseudocode

```
LiveThumbnails (RW-3): decodeLinear(path, .thumbnail(bucket)) ?? decode(path, bucket)   # after the disk tier (ST-6)
LiveLoupeImaging (RW-3): .preview -> decodeLinear(path, .preview(side)); .full -> decodeLinear(path, .full)
                         either nil -> today's decode; the buffer goes to the develop route as is (no 8-bit step)
LiveExporter (RW-3): decodeLinear(path, .full) ?? decode(path, nil), develop on the float buffer, then
                     writer.write(linear:format:bitDepth:profile:...) (16 bits for TIFF; the profile per
                     shared-codecs' Q1: sRGB for JPEG and PNG, the source's for TIFF and HEIC)
ImageIODecoder (RW-4, macOS):
  scan: a RAW-named file -> SuiteImageIO.info (size, date, Exif) as for any photo; on failure the reason
        is SuiteRaw.info(.file(url))'s refusal message
  decodeLinear(path, quality): RawFormat(path) != nil ? SuiteRaw.decode(.file(url), quality)
        : SuiteImageIO.decode(data, longestSide)            # every other format, from its own profile
        mapping RawRefusal to LibraryError.renderFailed(message)
JPEGWriter (RW-4, macOS): write(linear:...) -> SuiteImageIO.encode(buffer, as: format(bitDepth), profile:)
```

## Tasks

Every task is one PR to `dev` with the lead's lines (`Belt-Lead:`,
`Feature: raw`, `Slice:`, `Fast-Check:`, `Head:`). Model paths drop
`Sources/LibraryModel/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| RW-1 | #427 (part) | **Tests first.** `LibraryRawTests` (RJ0, Linux), disabled by name (`waits on RW-2`, `waits on RW-3`); `LibraryRawDecodeTests` (macOS) and RJ1 written and skipped | `Tests/LibraryModelTests/LibraryRawTests.swift`, `Tests/AppSnapshotTests/LibraryRawDecodeTests.swift`, `UITests/LibraryJourneyTests+Raw.swift` | – | ~260, 3 |
| RW-2 | #427 (part) | `decodeLinear` and `write(linear:)` with their defaults; `FakeDecoder` over `FakeRawDecoder` and the P3 fake; turns on RJ0 steps 1 and 2 | `Contracts/LibraryContracts.swift`, `Fakes/FakePlatform.swift`, `Tests/LibraryModelTests/LibraryRawTests.swift`, `Tests/mutations/LibraryModel.LibraryContracts.json`, `Tests/mutations/LibraryModel.FakePlatform.json` | RW-1, shared-codecs SC-16 | ~220, 5 |
| RW-3 | #427 (part) | Thumbnails, loupe and export ask for the right quality and keep the working-space buffer from decode through develop to the writer; turns on RJ0 steps 3 to 5 | `Live/LiveThumbnails.swift`, `Live/LiveLoupeImaging.swift`, `Live/LiveExporter.swift`, `Tests/LibraryModelTests/LibraryRawTests.swift`, `Tests/mutations/LibraryModel.LiveThumbnails.json`, `Tests/mutations/LibraryModel.LiveLoupeImaging.json`, `Tests/mutations/LibraryModel.LiveExporter.json` | RW-2 | ~260, 7 |
| RW-4 | #427 (part) | `ImageIODecoder` scans, refuses and decodes RAW files through `SuiteRaw` and every other file through `SuiteImageIO.decode`, both into the working space; `JPEGWriter` writes the float buffer through `SuiteImageIO.encode`; turns on `LibraryRawDecodeTests` | `Sources/LibraryApp/Platform/ImageIODecoder.swift`, `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Tests/AppSnapshotTests/LibraryRawDecodeTests.swift` | RW-2 | ~220, 3 |
| RW-5 | – | RJ1 turned on live | `UITests/LibraryJourneyTests+Raw.swift` | RW-3, RW-4 | ~40, 1 |
| RW-6 | #427 (closes) | `status: built`; `feature-done` | `docs/blueprints/library/features/raw.wave.json` | RW-5 | ~10, 1 |

RW-4 changes macOS-only code, so it carries no mutation plan (rule 14
targets Model code); `LibraryRawDecodeTests` is its oracle.

## Build waves

- Wave 1: RW-1. Independent in this wave: RW-1 alone.
- Wave 2: RW-2. Independent in this wave: RW-2 alone.
- Wave 3: RW-3, RW-4. Independent in this wave: both.
- Wave 4: RW-5. Independent in this wave: RW-5 alone.
- Wave 5: RW-6. Independent in this wave: RW-6 alone.

Longest chain: RW-1 → RW-2 → RW-3 → RW-5 → RW-6 (5). Chain of 5: the tests
before the contract, the contract before the callers that use it, both
callers and the decoder before the live journey, and the status last.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| RW-1 | compiles, disabled or skipped by name | – | – (tests) |
| RW-2 | RJ0 steps 1 and 2; every catalog fixture encodes byte for byte as before | an extension is missed, or a decoder without RAW support stops compiling | `LibraryModel.LibraryContracts`: the default returns a buffer for a JPEG → `.defaultIsNil`. `LibraryModel.FakePlatform`: a RAW name answered with nil → `.fakeDecodesRaw` |
| RW-3 | RJ0 steps 3 to 5 (a recording decoder and writer) | the grid decodes in full, export takes the preview, or the loupe or export converts to 8 bits or sRGB on the way | `LibraryModel.LiveThumbnails`: `.full` for a thumbnail → `.previewFirst`. `LibraryModel.LiveLoupeImaging`: the float buffer passed through `DisplayImage` → `.keepsHeadroom`. `LibraryModel.LiveExporter`: `.thumbnail` for export → `.exportFullSize` |
| RW-4 | `LibraryRawDecodeTests` on the macOS job, plus `.p3PhotoKeepsItsGamut` (shared-raw's `p3-red-16.png` imported, exported as TIFF: 16 bits, P3 profile, red within 1/1000) | the preview isn't used, the size is sideways, a bad file's reason is generic, or a P3 photo comes out clipped to sRGB or 8 bits | – (macOS only) |
| RW-5 | RJ1 on a scoped run (`app=library`) | a step fails | – |
| RW-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-LIB-1 for RAW (preview first) | every grid bucket whose size the preview covers draws the preview, with no `develop` call | `LibraryRawTests`, `LibraryRawDecodeTests` |
| headroom | Exposure −1 in the loupe keeps the test DNG's highlight patches apart | `LibraryRawTests` step 4 |
| wide gamut, high bit depth (beta) | a P3 photo's out-of-sRGB red survives decode, develop and a 16-bit TIFF export | `LibraryRawTests` step 5, `LibraryRawDecodeTests.p3PhotoKeepsItsGamut` |
| QB-V4 for RAW | export decodes `.full` with the same develop settings as the loupe's full render | `LibraryRawTests` step 3 |
| render: a develop step on a RAW photo | as any photo (suite-imaging's `LibraryDevelopLatencyTests`) | unchanged |
| QB-F1 no dead controls | no new control | – |

QB-LIB-V5 (the thumbnail matches the full picture) doesn't hold for a RAW
photo at default settings: its thumbnail is the camera's preview and its
loupe render the system decoder's, which can differ in colour. Accepted:
it keeps the import fast, and the loupe's value already says `preview` or
`full`.

## Done check

Per slice (lead.md rule 6): **RW-a** when RJ0 steps 1 and 2 pass on the
Linux gate with every mutation caught; **RW-m** with RJ0 complete (step 5: the P3 red reaches the writer as a
16-bit P3 request), `Mutate:` full on RW-3 and `LibraryRawDecodeTests`
green on the macOS job, `p3PhotoKeepsItsGamut` included;
**RW-z** when a scoped run (`app=library`) runs RJ1 green. Then
`Belt-Contact-Sheet: <run url>` on #1530.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| R1 | RAW+JPEG pairs (RJ-L21) import as two photos | Post-beta: the earlier cut's `RawPairs.fold` returns as its own packet; the beta shows both files |
| R2 | The grid draws no RAW tag | Post-beta, with a `needs-ui` ThumbnailBadges tag; the Info panel's file name shows the extension |
| R3 | Library's catalog has no import command, so `afterglow` can't import a folder and RJ-L22 can't run on the CLI | File it with library/file-flow; until then RJ-L22's check is `LibraryRawDecodeTests` and RJ1 |
| R4 | A JPEG imported before RAW support, then its RAW file | They are two photos (no pairing in the beta) |
