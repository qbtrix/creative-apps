# Feature packet: raw

**Feature:** camera RAW files import, show and develop in Library through
the suite's shared RAW decode (`suiteui/shared-raw`, SuiteImaging's `Raw/`
module over Core Image). Library adds only what is Library's: the file kind,
which quality each caller asks for, and the float route from the decoder to
develop. The grid draws each file's embedded preview, so a RAW import is as
fast as a JPEG one; the loupe and export decode every pixel into a linear
float buffer, so Develop's shared tone sliders (Exposure, White Balance,
Highlights) work with the RAW file's headroom. A file the system can't read
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

**Depends on:** `import` and `thumbnails` (built). **Cross-line:**
suiteui `shared-raw` **SR-a** before RW-1 (its contract and
`FakeRawDecoder`) and **SR-m** before RW-4 (the system decoder);
suiteui `shared-codecs` **SC-library** before RW-4 (`ImageIODecoder.swift`
moves onto `SuiteImageIO`); suiteui `shared-thumbnails` **ST-m** and
`suite-imaging` **IM-library** before RW-3 (`LiveThumbnails.swift`,
`LiveLoupeImaging.swift`). **Same line:** export-pack **LX-a** before RW-2
(`LibraryContracts.swift`) and **LX-m** before RW-3 (`LiveExporter.swift`);
both come after `export`. metadata-more (not in the beta) now waits on this
packet instead of the other way round: its MD-a waits on RW-a
(`LibraryValues.swift`, `FakePlatform.swift`) and its MD-b on RW-m
(`ImageIODecoder.swift`), re-cut in this PR. No creative-core issue, no
`needs-ui` issue.

Blueprint sections: 1.3 (raw through the system decoder), 2.3
(`library-app-platform`), 5.1 (`PhotoDecoding`), 6.1 (thumbnails), 10.1
(D11, now taken for RAW files).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| RW-a | A RAW file name is a `.raw` photo kind, `PhotoDecoding` offers a float decode with a default, and the fake decoder answers RAW files from the shared fake. | RW-1, RW-2 | RJ0 | export-pack:LX-a (RW-2); suiteui shared-raw SR-a (cross-line) |
| RW-m | The grid asks for the embedded preview, the loupe for a draft then every pixel, export for every pixel, all as float, and the platform decoder scans, refuses and decodes RAW files through `SuiteRaw`. | RW-3, RW-4 | RJ0, RJ-mac | RW-a; export-pack:LX-m (RW-3); suiteui ST-m, IM-library (RW-3), SC-library and shared-raw SR-m (RW-4) (cross-line) |
| RW-z | On live services a folder with a RAW file imports, shows its preview, develops in the loupe and exports at full size, and the feature is built. | RW-5, RW-6 | RJ1 | RW-m |

RW-m is the UI slice (`"ui": true`): RW-4 changes
`Sources/LibraryApp/Platform/ImageIODecoder.swift`, and it waits on no slice
of this feature but the contract (rule 18). There is no new screen: the
grid, loupe, Develop tab and import notice draw RAW photos as they draw any
photo.

## Journey steps

**RJ0 · `LibraryRawTests`** (Linux; RW-1, cases turned on by RW-2 and RW-3):
1. `PhotoFileKind.kind(forFileName: "DSC_0001.NEF")` is `.raw`, and so for
   every `RawFormat` extension in any case; `IMG.jpg` stays `.jpeg`.
2. A test decoder that implements only `scan` and `decode` answers
   `decodeLinear` with nil.
3. On the fakes: a `.DNG` photo's thumbnail asks `.thumbnail`, the loupe's
   preview `.preview`, its full render and export `.full`; a JPEG photo never
   calls `decodeLinear`'s RAW route.
4. Exposure −1 on the fake DNG's loupe render keeps the two highlight
   patches more than 20 levels apart (the float route reached develop).

**RJ-mac · `LibraryRawDecodeTests`** (macOS, RW-4): shared-raw's
`tiny-bayer.dng` scans as `.raw` with its size 48 × 64 and capture facts;
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

`Sources/LibraryModel/Contracts/LibraryValues.swift` (RW-2): `PhotoFileKind`
gains `case raw`; `kind(forFileName:)` returns `.raw` when
`RawFormat(fileName:)` (SuiteImaging) is non-nil.

`Sources/LibraryModel/Contracts/LibraryContracts.swift` (RW-2):

```swift
extension PhotoDecoding {
    /// A RAW file's linear float pixels at `quality` (SuiteImaging's `RawQuality`), upright, values above 1 kept;
    /// nil for any other file, which keeps `decode`'s 8-bit route. Default: nil, so `FakeDecoder`
    /// and every test decoder compile unchanged. Throws `LibraryError.renderFailed(refusal.message)`.
    func decodeLinear(path: String, quality: RawQuality) async throws -> PixelBuffer?
}
```

`Sources/LibraryModel/Fakes/FakePlatform.swift` (RW-2): `FakeDecoder`
answers `decodeLinear` for RAW names through SuiteImaging's
`FakeRawDecoder`.

## Pseudocode

```
LiveThumbnails (RW-3): decodeLinear(path, .thumbnail(bucket)) ?? decode(path, bucket)   # after the disk tier (ST-6)
LiveLoupeImaging (RW-3): .preview -> decodeLinear(path, .preview(side)); .full -> decodeLinear(path, .full)
                         either nil -> today's decode; the buffer goes to the develop route as is (no 8-bit step)
LiveExporter (RW-3): decodeLinear(path, .full) ?? decode(path, nil), then develop and the writer as today
ImageIODecoder (RW-4, macOS):
  scan: a RAW-named file -> SuiteImageIO.info (size, date, Exif) as for any photo; on failure the reason
        is SuiteRaw.info(.file(url))'s refusal message
  decodeLinear(path, quality): RawFormat(path) == nil ? nil
        : SuiteRaw.decode(.file(url), quality) mapping RawRefusal to LibraryError.renderFailed(message)
```

## Tasks

Every task is one PR to `dev` with the lead's lines (`Belt-Lead:`,
`Feature: raw`, `Slice:`, `Fast-Check:`, `Head:`). Model paths drop
`Sources/LibraryModel/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| RW-1 | #427 (part) | **Tests first.** `LibraryRawTests` (RJ0, Linux), disabled by name (`waits on RW-2`, `waits on RW-3`); `LibraryRawDecodeTests` (macOS) and RJ1 written and skipped | `Tests/LibraryModelTests/LibraryRawTests.swift`, `Tests/AppSnapshotTests/LibraryRawDecodeTests.swift`, `UITests/LibraryJourneyTests+Raw.swift` | – | ~260, 3 |
| RW-2 | #427 (part) | `PhotoFileKind.raw`; `decodeLinear` with its default; `FakeDecoder` over `FakeRawDecoder`; turns on RJ0 steps 1 and 2 | `Contracts/LibraryValues.swift`, `Contracts/LibraryContracts.swift`, `Fakes/FakePlatform.swift`, `Tests/LibraryModelTests/LibraryRawTests.swift`, `Tests/mutations/LibraryModel.LibraryValues.json`, `Tests/mutations/LibraryModel.LibraryContracts.json` | RW-1 | ~200, 6 |
| RW-3 | #427 (part) | Thumbnails, loupe and export ask for the right quality and keep the float buffer; turns on RJ0 steps 3 and 4 | `Live/LiveThumbnails.swift`, `Live/LiveLoupeImaging.swift`, `Live/LiveExporter.swift`, `Tests/LibraryModelTests/LibraryRawTests.swift`, `Tests/mutations/LibraryModel.LiveThumbnails.json`, `Tests/mutations/LibraryModel.LiveLoupeImaging.json`, `Tests/mutations/LibraryModel.LiveExporter.json` | RW-2 | ~220, 7 |
| RW-4 | #427 (part) | `ImageIODecoder` scans, refuses and decodes RAW files through `SuiteRaw`; turns on `LibraryRawDecodeTests` | `Sources/LibraryApp/Platform/ImageIODecoder.swift`, `Tests/AppSnapshotTests/LibraryRawDecodeTests.swift` | RW-2 | ~150, 2 |
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
| RW-2 | RJ0 steps 1 and 2; every catalog fixture encodes byte for byte as before | an extension is missed, or a decoder without RAW support stops compiling | `LibraryModel.LibraryValues`: `.raw` dropped from `kind(forFileName:)` → `.rawKind`. `LibraryModel.LibraryContracts`: the default returns a buffer for a JPEG → `.defaultIsNil` |
| RW-3 | RJ0 steps 3 and 4 (a recording decoder) | the grid decodes in full, export takes the preview, or the loupe converts to 8 bits | `LibraryModel.LiveThumbnails`: `.full` for a thumbnail → `.previewFirst`. `LibraryModel.LiveLoupeImaging`: the float buffer passed through `DisplayImage` → `.keepsHeadroom`. `LibraryModel.LiveExporter`: `.thumbnail` for export → `.exportFullSize` |
| RW-4 | `LibraryRawDecodeTests` on the macOS job | the preview isn't used, the size is sideways, or a bad file's reason is generic | – (macOS only) |
| RW-5 | RJ1 on a scoped run (`app=library`) | a step fails | – |
| RW-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-LIB-1 for RAW (preview first) | every grid bucket whose size the preview covers draws the preview, with no `develop` call | `LibraryRawTests`, `LibraryRawDecodeTests` |
| headroom | Exposure −1 in the loupe keeps the test DNG's highlight patches apart | `LibraryRawTests` step 4 |
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
Linux gate with every mutation caught; **RW-m** with RJ0 complete,
`Mutate:` full on RW-3 and `LibraryRawDecodeTests` green on the macOS job;
**RW-z** when a scoped run (`app=library`) runs RJ1 green. Then
`Belt-Contact-Sheet: <run url>` on #1530.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| R1 | RAW+JPEG pairs (RJ-L21) import as two photos | Post-beta: the earlier cut's `RawPairs.fold` returns as its own packet; the beta shows both files |
| R2 | The grid draws no RAW tag | Post-beta, with a `needs-ui` ThumbnailBadges tag; the Info panel's file name shows the extension |
| R3 | Library's catalog has no import command, so `afterglow` can't import a folder and RJ-L22 can't run on the CLI | File it with library/file-flow; until then RJ-L22's check is `LibraryRawDecodeTests` and RJ1 |
| R4 | A JPEG imported before RAW support, then its RAW file | They are two photos (no pairing in the beta) |
