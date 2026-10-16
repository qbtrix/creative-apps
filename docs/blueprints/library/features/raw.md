# Feature packet: raw

**Feature:** camera raw files (CR2, CR3, NEF, NRW, ARW, RAF, ORF, RW2, DNG,
PEF, SRW) import, show and develop through the system decoder (Core Image
RAW on macOS). The grid draws the camera's embedded preview first, so a raw
import is as fast as a JPEG one; a RAW and the JPEG the camera wrote beside
it are one photo; the Develop tab gains a RAW section with the controls the
decoder offers for that file (noise reduction, color noise reduction, lens
correction, highlight recovery), each one undo step, pasted with the other
settings, and applied the same in the grid, the loupe and export.
**Line:** `line:library` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/raw`

**Covers:** #427 (closes with RW-10, which carries `feature-done`). The
blueprint scoped #427 as "a tier-2 import, not a raw engine" (1.3); this
packet keeps that line: every pixel decision is the system decoder's, and
Library only chooses which of its outputs to ask for.

**Depends on:** the `import` and `thumbnails` features (blueprint 8.3).
Slice RW-c also waits on `develop` (its inspector, `developTargets` and
`endEdit` are the slot the RAW rows plug into), `persist` (RW-8's round-trip test), `export`
(RW-9 edits `LiveExporter.swift`); `loupe-viewport` comes through
`develop`. RW-10 needs `DevelopInspector(model:menu:cropDraft:)`, which
develop's DV-9 gets from its spine follow-up. Because develop, crop, export and
metadata-more take over the same contract and import files, slice RW-a also
waits on `develop:DV-a` (`DevelopValues.swift`), `crop:CR-a` and
`export:EX-a` (`LibraryContracts.swift`) and `metadata-more:MD-a` and `MD-e`
(`LibraryValues.swift`, `LiveImporter.swift`, `LibraryCatalog.swift`), and
RW-b on `metadata-more:MD-b` (`ImageIODecoder.swift`); open question R6.
SuiteUI: #779 (S-L2), plus one `needs-ui` issue the lead files at stage 1, "ThumbnailBadges: a short text tag per cell" (labels
`needs-ui`, `line:suiteui`; acceptance: `ThumbnailBadges(tag: "RAW")` draws a
caption-size tag in the cell's top-right corner, with the tag as part of the
cell's accessibility label). Until it lands, RW-7 appends " · RAW" to the
cell caption. **No creative-core issue:** decoding is Darwin-only and lives
in `LibraryApp/Platform` (blueprint 0.2, "File decode and encode"). Decision
D11 (a Float `PixelBuffer` decode, so raw headroom reaches develop) stays a
later contract change, not filed here.

Blueprint sections: 1.3 (non-goals), 1.4 (v1 line: raw is out of v1), 2.2
(`library-later`: `RawFileTypes.swift`), 2.3 (`library-app-platform`), 3
(tier 2, row 6), 5.1 (`PhotoDecoding`), 5.5 (`PhotoItem.develop`), 6.1
(thumbnails, develop rows), 6.4 (S-L2), 7.1, 7.4, 8.3 (wave 5), 10.1 (D6,
D11).

**Files this packet takes over, and why.** The C4 check
(`c4-planned.json`, `every_source_file_owned`) lets a new Model file live
only in `RawFileTypes.swift`, `Contracts/` or `Fakes/`, and a new app file
only in `Platform/`. So the RAW rules go in `RawFileTypes.swift`, the types in
`Contracts/RawValues.swift`, the fake in `Fakes/FakeRaw.swift`, the system
decoder in `Platform/RawDecoding.swift`, and these existing files gain a few
lines each: the spine's `Contracts/LibraryValues.swift`,
`Contracts/DevelopValues.swift`, `Contracts/LibraryContracts.swift`,
`Fakes/FakePlatform.swift`, `LibraryFixtures.swift`, `LibraryCatalog.swift`;
import's `Live/LiveImporter.swift` and `Platform/ImageIODecoder.swift`;
thumbnails' `Live/LiveThumbnails.swift` and `LibraryGrid.swift`;
loupe-viewport's `Live/LiveLoupeImaging.swift`; export's
`Live/LiveExporter.swift`; develop's `DevelopInspector.swift`,
`LibraryWindow+Develop.swift` and `LibraryMenus.swift` (its
`LibraryMenu.Develop`). Every one is reached through `depends` or a
slice wait, so `scripts/waves check` accepts it. `LibraryWindow.swift` (which
builds `ImageIODecoder()`) is filters-collections' in wave 5, so the raw
route lives inside `ImageIODecoder` instead of a new decoder type.

No task edits `docs/c4/model.json`, `docs/design.md`, the blueprint or
`waves.in.md`; the supervisor folds the RAW look rows (6.1) in later. RW-10
adds raw to the descriptions of the two Library C4 parts
(`docs/c4/parts/creative-apps/library-model/library-model-sources.json`,
`.../library-app/library-app-sources.json`), so it waits on
status-and-layout and on filters-collections' FC-e, which edit them too.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| RW-a | The raw types, the decoder's raw requirements with defaults, the fake raw files and the `raw-shoot` fixture exist, and a catalog file without raw settings encodes byte for byte as before. | RW-1, RW-2 | RJ0 | develop:DV-a, crop:CR-a, export:EX-a, metadata-more:MD-a (RW-1); metadata-more:MD-e (RW-2) |
| RW-b | Importing a folder of raw files is as fast as JPEGs because the grid draws each camera's embedded preview, a RAW and its JPEG come in as one photo, and the grid marks raw photos. | RW-3, RW-4, RW-5, RW-6, RW-7 | RJ1 | RW-a (RW-3); metadata-more:MD-b (RW-6) |
| RW-c | The Develop tab shows the RAW controls this file's decoder offers, each change is one undo step, and the grid, the loupe and export all decode with them. | RW-8, RW-9, RW-10 | RJ2 | RW-b (RW-8, RW-10); develop (RW-8, RW-10); persist (RW-8); export (RW-9); status-and-layout, filters-collections:FC-e (RW-10) |

## Top complaints and features from the future

Usage evidence for raw is thin (blueprint 3, tier 2 row 6: "pending
evidence"); every row is *inferred* from what public raw workflow guides
warn about. Clean-room: behaviour only, no other app's UI or code.

| # | Complaint (most common first) | What this packet does | Task |
|---|---|---|---|
| 1 | A raw import crawls: every thumbnail waits for a full raw decode | Grid thumbnails and the loupe's drag preview use the camera's embedded preview whenever it covers the size asked and the RAW settings are the camera's; a small embedded thumbnail falls back to a draft-mode decode at the cell's scale | RW-3, RW-6 |
| 2 | Shooting RAW + JPEG doubles every photo in the grid | A RAW and a same-name JPEG in the same folder import as one photo (the RAW); the JPEG stays on disk, untouched, and the RAW section names it | RW-3, RW-4 |
| 3 | A new camera's files don't open, with no reason given | The import failure reads "macOS can't read this raw file (NEF)."; a camera the system decoder doesn't develop yet still imports with its embedded preview, can be culled, and its RAW rows say "macOS can't develop raw files from <camera> yet." | RW-1, RW-6, RW-8 |
| 4 | High-ISO noise, fixed one photo at a time | Noise Reduction and Color Noise Reduction from the decoder; develop's Copy and Paste Settings carry them to a whole shoot | RW-1, RW-8 |
| 5 | Controls that silently do nothing on some files | Each row is enabled only when this file's decoder offers it, else disabled with the reason | RW-8, RW-10 |

From the future (a few, all decoder-backed): **Highlight Recovery** as a
toggle (`isHighlightRecoveryEnabled`, macOS 26), **Lens Correction** with
the file's own default shown, and the RAW section's header naming the camera
and the paired JPEG, so a person sees what the photo is made from.

## Journey steps

Journey ids: RJ0 is a Linux Model walk; RJ1 and RJ2 are XCUITests, each in
its own file and class (`project.yml` compiles `UITests/<target>*.swift`).

**RJ0 · `LibraryRawContractTests.testRawContractWalk`** (RW-1, Linux)
1. `RawFormat(fileName:)` reads each of the eleven extensions in any case
   and nothing else; `PhotoFileKind.kind(forFileName: "DSC_0001.NEF")` is
   `.raw`.
2. `DevelopSettings.neutral.setting(raw: RawSettings.cameraDefault.setting(.noiseReduction, to: 40))`
   round-trips through `JSONEncoder` with `.sortedKeys`; neutral settings
   encode with no `raw` key; a `develop` object without `raw` decodes with
   `raw == nil`.
3. A test-local `PhotoDecoding` that implements only `scan` and
   `decode(path:maxLongSide:)` answers `rawInfo` with nil and forwards the
   raw `decode` to the plain one.

**RJ1 · `LibraryRawJourneyTests.testImportRawFilesAndPairs`**
(`UITests/LibraryJourneyTests+Raw.swift`; written by RW-3 with
`XCTSkip("waits on RW-7")`, enabled by RW-7; all steps L)
1. Copy `Tests/AppSnapshotTests/Fixtures/library-tiny.dng` (found by
   `#filePath`) into a temp folder as `DSC_0001.DNG` and `DSC_0002.DNG`;
   write `DSC_0001.JPG` and `IMG_0003.jpg` with ImageIO; write
   `DSC_0004.NEF` holding the bytes `not a raw file`. Launch with
   `-LibraryImportFolder` on it and click **Import Folder…**. Shot
   `raw-imported`. Expect 3 cells, the notice "Imported 3 photos. 1 file
   couldn't be imported." whose **Show** lists `DSC_0004.NEF: macOS can't
   read this raw file (NEF).`, and `DSC_0001`'s cell label containing `RAW`.
2. Every cell's value starts with `ready` within 10 s.
3. Double-click `DSC_0001`. Shot `raw-loupe`. Expect `library.loupe.photo`'s
   value to start with `full` within 10 s (the system decoder's render).
4. Import the same folder again. Shot `raw-import-again`. Expect "No new
   photos in <folder>." and still 3 cells: the JPEG of the pair never
   becomes its own photo.
States: loading (cells before `ready`), error (unreadable raw), nothing new.

**RJ2 · `LibraryRawDevelopJourneyTests.testRawControlsFollowTheFile`**
(`UITests/LibraryJourneyTests+RawDevelop.swift`; written by RW-8 with
`XCTSkip("waits on RW-10")`, enabled by RW-10)
1. (F) Launch on `-LibraryFixture raw-shoot`; sort by Name; select
   `DSC_0001`; click the inspector's **Develop** tab. Shot `raw-develop`.
   Expect the RAW section `library.develop.raw` with the header "Test Camera
   Z · NEF · with DSC_0001.JPG" and the rows Noise Reduction, Color Noise
   Reduction (both 0–100), Lens Correction and Highlight Recovery, all
   enabled, at the file's defaults.
2. (F) Drag Noise Reduction right. Expect its value above the file's
   default and Edit's Undo item "Undo Noise Reduction"; undo once: the
   default is back (a drag is one step).
3. (F) Select `P0004` (ORF). Expect Lens Correction disabled with help
   "This camera's files don't offer Lens Correction."
4. (F) Select `DSC_0005` (unsupported camera). Shot `raw-develop-unsupported`.
   Expect every RAW row disabled with help "macOS can't develop raw files
   from Unreleased X1 yet."; press 3: its value contains `3 stars` (it can
   still be culled).
5. (F) Select `IMG_0006` (a JPEG). Expect no `library.develop.raw` section.
6. (F) Select `DSC_0001`; Photo > Copy Settings; select `DSC_0002`; Photo >
   Paste Settings. Expect `DSC_0002`'s Noise Reduction equal to
   `DSC_0001`'s.
7. (L) Relaunch live with `-LibraryTestValues` on the tiny DNG imported
   (`-LibraryImportOnLaunch`); open it in the loupe; note the checksum.
   Every RAW row is enabled or carries a reason (no dead control). Change
   the first enabled row; expect the loupe checksum to change within 10 s.
States: loading ("Reading the raw file…" while the info is fetched),
disabled with a reason, unsupported camera, not raw (no section).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Grid cell (raw) | – | an unsupported camera's cell is *not* an error: it draws the embedded preview | as today (`loading` until the preview arrives) |
| Import notice | – | a raw file the system can't read: "<name>: macOS can't read this raw file (NEF)." in the failure list | the import progress row, unchanged |
| Develop tab, RAW section | hidden when no target is raw | unsupported camera: every row disabled with the camera's reason; a row this file doesn't offer: disabled with "This camera's files don't offer <Control>." | "Reading the raw file…" in the section while `rawInfo` is pending for a target |
| Loupe (unsupported camera) | – | `.full` fails with "Couldn't render this photo: macOS can't develop raw files from <camera> yet."; the `.preview` picture (embedded preview) stays on screen | `preview` first, as today |

Snapshots (Light and Dark): `LibraryRawSnapshots.swift` `library-grid-raw`
(raw and JPEG cells side by side, the " · RAW" caption or the tag);
`LibraryRawDevelopSnapshots.swift` `library-develop-raw`,
`library-develop-raw-unsupported`, `library-develop-raw-loading`.

## Contract slice

`Sources/LibraryModel/Contracts/RawValues.swift` (RW-1, new):

```swift
/// A camera raw file extension Library imports; the raw value is the
/// extension in upper case as the inspector shows it.
public enum RawFormat: String, CaseIterable, Sendable, Codable {
    case cr2 = "CR2", cr3 = "CR3", nef = "NEF", nrw = "NRW", arw = "ARW", raf = "RAF"
    case orf = "ORF", rw2 = "RW2", dng = "DNG", pef = "PEF", srw = "SRW"
    /// Matched on the extension, ignoring case; nil for anything else.
    public init?(fileName: String)
    /// "macOS can't read this raw file (NEF)." — the import failure reason.
    public var unreadableReason: String { get }
}

/// A RAW develop control the system decoder may offer for a file. The raw value is the row's label.
public enum RawControl: String, CaseIterable, Sendable, Codable {
    case noiseReduction = "Noise Reduction", colorNoiseReduction = "Color Noise Reduction"
    case lensCorrection = "Lens Correction", highlightRecovery = "Highlight Recovery"
    /// Lens Correction and Highlight Recovery are on/off (0 or 1); the rest 0...100.
    public var isToggle: Bool { get }
    public var range: ClosedRange<Double> { get }
}

/// A photo's RAW settings. Nil for a control: the file's own default.
public struct RawSettings: Hashable, Sendable, Codable {
    public static let cameraDefault: RawSettings
    public func value(_ control: RawControl) -> Double?
    /// Clamped to the range; a toggle rounds to 0 or 1; NaN or infinity clears it (nil).
    public func setting(_ control: RawControl, to value: Double?) -> RawSettings
}

/// What the system decoder says about one raw file.
public struct RawFileInfo: Hashable, Sendable {
    public var format: RawFormat
    public var camera: String               // "Test Camera Z"; "this camera" when the file names none
    public var developable: Bool            // false: the system decoder can't develop this camera yet
    public var previewSize: PixelSize?      // the embedded preview, upright; nil when there is none
    public var defaults: [RawControl: Double]  // the controls this file offers, with its defaults
    public var pairedJPEG: String?          // "DSC_0001.JPG" when it sits beside the raw file
    /// "macOS can't develop raw files from <camera> yet."
    public var undevelopableReason: String { get }
}

/// How a caller wants a raw file decoded.
public struct RawDecodeOptions: Hashable, Sendable {
    public var settings: RawSettings
    /// True for the grid and the loupe's drag preview: the embedded preview may stand in.
    public var allowPreview: Bool
}

extension PhotoItem {
    /// The raw format of the photo's file; nil for samples and other kinds.
    public var rawFormat: RawFormat? { get }
}
```

Edits in other contract files (RW-1):

- `LibraryValues.swift`: `PhotoFileKind` gains `case raw`;
  `kind(forFileName:)` returns `.raw` when `RawFormat(fileName:)` is non-nil.
  From this merge the live scan lists raw files (ImageIO reads their size
  and date); until RW-6 they decode through ImageIO's own full decode.
- `DevelopValues.swift`: `DevelopSettings` gains
  `public private(set) var raw: RawSettings?` and
  `func setting(raw: RawSettings) -> DevelopSettings`, which stores nil for
  `.cameraDefault`. Develop's hand-written coder (DV-1) gains
  `encodeIfPresent(raw)` and `decodeIfPresent`, so a photo without RAW
  settings encodes byte for byte as before (persist's golden) and its
  `fingerprint`, the thumbnail token, moves when a RAW value does. `pastingAdjustments(from:)` already copies every
  field but the crop, so Paste Settings carries RAW settings (a JPEG target
  ignores them at decode).
- `LibraryContracts.swift`: `PhotoDecoding` gains two requirements, each with
  a default in a protocol extension, so `FakeDecoder` and every test decoder
  compile unchanged:

```swift
/// `decode(path:maxLongSide:)` for a raw file with RAW settings and the preview rule.
/// Default: the plain decode (a decoder that knows no raw files ignores `raw`).
func decode(path: String, maxLongSide: Int?, raw: RawDecodeOptions) async throws -> DisplayImage
/// What the system decoder offers for a raw file; nil for any other file. Default: nil.
func rawInfo(path: String) async throws -> RawFileInfo?
```

`Sources/LibraryModel/Fakes/FakeRaw.swift` (RW-2, new): `FakeRawFiles.info(for path:)`,
a fixed table: `.NEF` from "Test Camera Z" offers all four controls
(defaults 25, 25, 1, 1) and a preview of 1616 × 1080; `.ORF` offers only the
two noise rows; `.ARW` from "Unreleased X1" is `developable == false`;
`.DNG` offers the noise rows and Highlight Recovery. `FakeDecoder` answers
`rawInfo` from it (`FakePlatform.swift`). `LibraryFixtures` gains `raw-shoot`:
`DSC_0001.NEF` (paired), `DSC_0002.NEF`, `DSC_0003.CR3`, `P0004.ORF`,
`DSC_0005.ARW`, `IMG_0006.jpg`, paths under `/fixture/raw/`, ids equal to
paths. `LibraryCatalog.swift` gains one stored property,
`public internal(set) var rawInfo: [String: RawFileInfo] = [:]` (memory
only, never saved, rebuilt on demand), in the hand-written `==`.

Model rules and catalog methods, `Sources/LibraryModel/RawFileTypes.swift`
(RW-3, RW-8):

```swift
public enum RawPairs {
    /// Folds each JPEG whose folder and stem (ignoring case) match exactly one raw
    /// candidate into it. Returns the kept candidates and, per kept raw path, its JPEG's path.
    public static func fold(_ candidates: [ImportCandidate]) -> (kept: [ImportCandidate], partners: [String: String])
    /// "DSC_0001.jpg", ".JPG", ".jpeg", ".JPEG" beside `rawPath`: what the platform looks for.
    public static func jpegSiblings(of rawPath: String) -> [String]
}

public enum RawDecodePlan: Hashable, Sendable {
    case preview                          // the embedded preview, scaled
    case raw(scale: Double, draft: Bool)  // a system decode at `scale` of full size
    case undevelopable                    // throw renderFailed(info.undevelopableReason)
    public static func plan(maxLongSide: Int?, options: RawDecodeOptions,
                            info: RawFileInfo, fullSize: PixelSize) -> RawDecodePlan
}

public struct RawRowState: Hashable, Sendable {
    public var value: MetadataValue<Double>?  // the offering targets' values (the file's default where unset); nil: none offers it
    public var help: String?                  // nil: enabled; else why not
}

extension LibraryCatalog {
    /// `developTargets`' photos that are raw files.
    public var rawTargets: [PhotoItem] { get }
    /// Raw targets whose `rawInfo` is not known yet: (id, path) for the area to fetch.
    public func rawInfoRequests() -> [(id: String, path: String)]
    public mutating func setRawInfo(_ info: RawFileInfo, for id: String)
    /// A failed fetch stores an undevelopable info, so the rows say why and are not re-asked.
    public mutating func failRawInfo(_ error: LibraryError, for id: String)
    /// Nil when no target is raw (the section hides); "Reading the raw file…" while pending;
    /// else "Test Camera Z · NEF · with DSC_0001.JPG".
    public var rawHeader: String? { get }
    public func rawRow(_ control: RawControl) -> RawRowState
    /// One step named `control.rawValue` on the raw targets that offer `control`;
    /// a drag shares `coalesceKey`. Like `setDevelop`, no thumbnail work per sample:
    /// the row's release calls develop's `endDevelopDrag()`, which drops the stale thumbnails.
    public mutating func setRaw(_ control: RawControl, to value: Double, coalesceKey: String?)
}
```

**The develop slot.** Develop publishes `DevelopInspector(model:menu:cropDraft:)`,
`LibraryMenu.Develop` (with `endEdit` for a row's release) and
`developTargets`. RW-10 adds a RAW section below develop's COLOR section in
`DevelopInspector.swift`, one closure `setRaw: (@MainActor (RawControl, Double) -> Void)?`
to `LibraryMenu.Develop` in `LibraryMenus.swift`, and fills it in
`LibraryWindow+Develop.swift`; each RAW row's release calls develop's
existing `endEdit`. The loupe follows on its own: its request carries the
photo's settings, now with `raw`.

## Pseudocode

```
RawPairs.fold(candidates):                                        # RW-3
  raws = candidates where kind == .raw, keyed by (folder, stem.lowercased())
  for jpeg in candidates where kind == .jpeg:
    group = raws[(folder(jpeg), stem(jpeg).lowercased())]
    if group.count == 1: drop jpeg; partners[group[0].path] = jpeg.path
  kept keeps input order minus the dropped JPEGs

RawDecodePlan.plan(maxLongSide, options, info, fullSize):        # RW-3
  want = min(maxLongSide ?? fullSize.longSide, fullSize.longSide)
  previewCovers = info.previewSize.map { $0.longSide >= want } ?? false
  if !info.developable:
    return options.allowPreview && info.previewSize != nil ? .preview : .undevelopable
  if options.allowPreview && options.settings == .cameraDefault && previewCovers: return .preview
  return .raw(scale: Double(want) / Double(fullSize.longSide), draft: options.allowPreview)

LiveImporter.importFolder:                                        # RW-4
  scan = try await decoder.scan(folder)
  (kept, partners) = RawPairs.fold(scan.candidates)
  fresh = kept where !known.contains(path) && !(partners[path].map(known.contains) ?? false)
  alreadyKnown = kept.count - fresh.count          # a pair counts once
  (rest unchanged)

ImageIODecoder (RW-6, macOS):
  scan: a raw-named file ImageIO can't read fails with RawFormat.unreadableReason
  rawInfo(path): RawFormat(path) == nil ? nil : SystemRawDecoder.info(url)
  decode(path, maxLongSide): raw ? decode(path, maxLongSide, raw: .init(.cameraDefault, allowPreview: true)) : today's
  decode(path, maxLongSide, raw):
    guard RawFormat(path) != nil else today's decode
    info = SystemRawDecoder.info(url); full = today's metadata size
    switch RawDecodePlan.plan(...):
      .preview -> SystemRawDecoder.preview(url, maxLongSide)
      .raw(scale, draft) -> SystemRawDecoder.decode(url, settings, scale, draft)
      .undevelopable -> throw LibraryError.renderFailed(info.undevelopableReason)

SystemRawDecoder (Platform/RawDecoding.swift, RW-6): CIRAWFilter(imageURL:)
  info: nil filter -> developable false, camera from the ImageIO TIFF Model;
        defaults only for supported controls: isLuminanceNoiseReductionSupported ->
        luminanceNoiseReductionAmount × 100; isColorNoiseReductionSupported -> colorNoiseReductionAmount × 100;
        isLensCorrectionSupported -> isLensCorrectionEnabled; isHighlightRecoverySupported -> isHighlightRecoveryEnabled;
        previewSize from previewImage's extent after orientation; pairedJPEG = first of RawPairs.jpegSiblings that exists
  preview: previewImage, oriented, scaled to maxLongSide (never enlarged)
  decode: scaleFactor = scale; isDraftModeEnabled = draft; each non-nil setting (÷ 100 for the sliders);
          outputImage rendered by one shared CIContext into sRGB RGBA8, unpremultiplied like straightRGBA8

LiveThumbnails / LiveLoupeImaging / LiveExporter (RW-9): their decode call becomes
  decoder.decode(path:, maxLongSide:, raw: RawDecodeOptions(settings: photo.develop.raw ?? .cameraDefault,
                                                            allowPreview: thumbnails ? true : loupe ? quality == .preview : false))

setRaw(control, value, key):                                      # RW-8
  ids = rawTargets where rawInfo[id]?.developable == true && rawInfo[id]?.defaults[control] != nil
  recordEdit(control.rawValue, coalesceKey: key, ids) { p in
    p.develop = p.develop.setting(raw: (p.develop.raw ?? .cameraDefault).setting(control, to: value)) }
  # release: menu.develop.endEdit -> endDevelopDrag() drops those thumbnails once
rawRow(control):
  no raw target -> help "Select a raw photo."
  any target info pending -> help "Reading the raw file…"
  every target undevelopable -> help first.undevelopableReason
  no target offers control -> help "This camera's files don't offer <Control>."
  value: MetadataValue.of(offering targets' raw value ?? their file default)   # the spine's helper: .value or .mixed

LibraryWindow+Develop (RW-10, macOS): on the develop targets changing,
  for (id, path) in model.rawInfoRequests(): Task.detached { try await services.decoder.rawInfo(path) }
    -> MainActor: setRawInfo or failRawInfo
DevelopInspector (RW-10): if let header = model.rawHeader: InspectorSection("RAW") { InspectorRow(header);
  noise rows InspectorSliderRow 0–100 decimals 0; toggles a system Toggle in an InspectorRow;
  each row .disabled(rawRow.help != nil).help(rawRow.help); identifiers library.develop.raw.<control> }
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: raw`, `Slice: <slice>`,
`Fast-Check: pass`, `Head:`, and for a task with mutations the `Mutate:`
score line. RW-10 carries `feature-done` and sets `status` to `built` in
`raw.wave.json`. Model paths drop `Sources/LibraryModel/`; Model tests are
`Tests/LibraryModelTests/`; plans are `Tests/mutations/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| RW-1 | #427 (part) | Raw types; `PhotoFileKind.raw`; `DevelopSettings.raw`; the two `PhotoDecoding` requirements with defaults; walk RJ0; RW-2's tests, disabled | `Contracts/RawValues.swift`, `Contracts/LibraryValues.swift`, `Contracts/DevelopValues.swift`, `Contracts/LibraryContracts.swift`; tests `LibraryRawContractTests.swift`, `LibraryRawFakesTests.swift`; plans `LibraryModel.RawValues.json`, `LibraryModel.LibraryValues.json`, `LibraryModel.DevelopValues.json`, `LibraryModel.LibraryContracts.json` | – | ~380, 10 |
| RW-2 | – | `FakeRawFiles`, `FakeDecoder.rawInfo`, the `raw-shoot` fixture, `rawInfo` stored on the catalog | `Fakes/FakeRaw.swift`, `Fakes/FakePlatform.swift`, `LibraryFixtures.swift`, `LibraryCatalog.swift`; tests `LibraryRawFakesTests.swift`; plans `LibraryModel.FakeRaw.json`, `LibraryModel.FakePlatform.json`, `LibraryModel.LibraryCatalog.json` | RW-1 | ~260, 8 |
| RW-3 | #427 (part) | `RawPairs` and `RawDecodePlan`; the fold budget; RJ1 and the slice's macOS tests written and disabled | `RawFileTypes.swift`; tests `LibraryRawImportTests.swift`, `LibraryRawDecodePlanTests.swift`, `LibraryRawBudgetTests.swift`, `Tests/AppSnapshotTests/LibraryRawDecodeTests.swift`, `Tests/AppSnapshotTests/LibraryRawSnapshots.swift`, `UITests/LibraryJourneyTests+Raw.swift`; plan `LibraryModel.RawFileTypes.json` | RW-1, RW-2 | ~380, 8 |
| RW-4 | #427 (part) | `LiveImporter` folds pairs and skips a pair either of whose files is known | `Live/LiveImporter.swift`; tests `LibraryRawImportTests.swift`; plan `LibraryModel.LiveImporter.json` | RW-3 | ~120, 3 |
| RW-5 | – | The tiny DNG: its writer, the committed file, and the spike that the system decoder opens it | `Tests/AppSnapshotTests/LibraryTinyDNG.swift`, `Tests/AppSnapshotTests/Fixtures/library-tiny.dng`, `Tests/AppSnapshotTests/LibraryRawDecodeTests.swift` | RW-3 | ~200, 3 |
| RW-6 | #427 (part) | `SystemRawDecoder` over Core Image RAW; `ImageIODecoder` routes raw files through `RawDecodePlan` | `Sources/LibraryApp/Platform/RawDecoding.swift`, `Sources/LibraryApp/Platform/ImageIODecoder.swift`, `Tests/AppSnapshotTests/LibraryRawDecodeTests.swift` | RW-3, RW-5 | ~300, 3 |
| RW-7 | – | The grid's RAW mark (caption, then the tag once the needs-ui issue lands); `library-grid-raw`; RJ1 enabled | `Sources/LibraryApp/LibraryGrid.swift`, `Tests/AppSnapshotTests/LibraryRawSnapshots.swift`, `UITests/LibraryJourneyTests+Raw.swift` | RW-3, RW-4, RW-6 | ~160, 3 |
| RW-8 | #427 (part) | RAW info state, rows, header and `setRaw` with undo; the setRaw budget; RJ2 and the slice's other tests written and disabled | `RawFileTypes.swift`; tests `LibraryRawDevelopTests.swift`, `LibraryRawRenderTests.swift`, `LibraryRawBudgetTests.swift`, `Tests/AppSnapshotTests/LibraryRawDevelopSnapshots.swift`, `UITests/LibraryJourneyTests+RawDevelop.swift`; plan `LibraryModel.RawFileTypes.json` | RW-2, RW-3 | ~390, 7 |
| RW-9 | #427 (part) | Thumbnails, loupe and export decode with the photo's RAW settings and the preview rule | `Live/LiveThumbnails.swift`, `Live/LiveLoupeImaging.swift`, `Live/LiveExporter.swift`; tests `LibraryRawRenderTests.swift`; plans `LibraryModel.LiveThumbnails.json`, `LibraryModel.LiveLoupeImaging.json`, `LibraryModel.LiveExporter.json` | RW-8 | ~180, 7 |
| RW-10 | #427 (closes) | The RAW section in the Develop tab and its info fetch; snapshots; RJ2 enabled; the C4 parts name raw; `status: built` | `Sources/LibraryApp/DevelopInspector.swift`, `Sources/LibraryApp/LibraryWindow+Develop.swift`, `Sources/LibraryApp/LibraryMenus.swift`, `Tests/AppSnapshotTests/LibraryRawDevelopSnapshots.swift`, `UITests/LibraryJourneyTests+RawDevelop.swift`, `docs/c4/parts/creative-apps/library-model/library-model-sources.json`, `docs/c4/parts/creative-apps/library-app/library-app-sources.json` | RW-6, RW-8, RW-9 | ~350, 7 |

RW-10 also sets `status` to `built` in `raw.wave.json` (packets.md rule
(a)). RW-3 waits on RW-2 for the slice order (contract first, rule 12), not for
code. RW-3 and RW-8 share `RawFileTypes.swift`, its plan and
`LibraryRawBudgetTests.swift`, stacked. RW-1 owns RW-2's test file (disabled,
"waits on RW-2"), RW-3 owns RW-4's to RW-7's tests and RJ1, RW-8 owns RW-9's
and RW-10's tests and RJ2 (build the check first, rule 13); each later task
co-owns the file it enables. RW-5, RW-6 and RW-7 change macOS-only code or
tests, so they carry no mutation plan (rule 14 targets Model code); their slice's Model
tasks carry it. A test written ahead of its code is skipped, not left
uncompiled: its body may name only what has merged (RW-1's contract surface,
`RawDecodePlan`, a test-local decoder), never `SystemRawDecoder` or
`LibraryTinyDNG`; the task that enables it adds those calls. A task that
measures over 400 lines splits by file before it opens.

**The tiny DNG.** `LibraryTinyDNG.swift` writes a 32 × 24 RGGB Bayer DNG
(16-bit, uncompressed, Orientation 6, `UniqueCameraModel` "AfterGlow Test",
a 16 × 12 8-bit RGB preview in a second IFD whose color differs from the raw
data) from the published DNG specification, and
`LibraryRawDecodeTests.tinyDNGMatchesItsWriter` checks the committed
`library-tiny.dng` byte for byte against it. Both macOS targets read the file
by `#filePath` (no `Package.swift` resources; the `Golden/` pattern). If the
system decoder rejects the hand-made Bayer file, RW-5 falls back to a
LinearRaw DNG and says so in its PR (open question R5). RW-5 is the spike:
it lands before the decoder, so a fixture the system can't read stops the
slice early instead of inside RW-6.

## Build waves

- Wave 1: RW-1. Independent in this wave: RW-1 alone.
- Wave 2: RW-2. Independent in this wave: RW-2 alone.
- Wave 3: RW-3. Independent in this wave: RW-3 alone.
- Wave 4: RW-4, RW-5, RW-8. Independent in this wave: all three.
- Wave 5: RW-6, RW-9. Independent in this wave: both.
- Wave 6: RW-7, RW-10 (RW-10 final, `feature-done`). Independent in this wave: both.

Longest chain: RW-1 → RW-2 → RW-3 → RW-8 → RW-9 → RW-10 (6).
Chain of 6: RW-2's fakes conform to RW-1's types; RW-3 starts after the
contract slice (rule 12); RW-8 adds to RW-3's `RawFileTypes.swift`, the only
Model file the C4 check allows a raw rule in; RW-9's tests are RW-8's
(rule 13); RW-10 draws RW-8's rows and RJ2's (L) step needs RW-9's pixels.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| RW-1 | `LibraryRawContractTests` (RJ0): all eleven extensions in upper, lower and mixed case parse, `DSC_0001.jpg`, `NEF` with no dot and `.nef` alone don't; `unreadableReason` reads "macOS can't read this raw file (NEF)."; `RawSettings` clamps 140 to 100 and -5 to 0, rounds a toggle's 0.6 to 1, NaN clears; `setting(raw: .cameraDefault)` stores nil; neutral `DevelopSettings` encodes byte-equal to a literal without `raw`; a `raw` object round-trips; the default `rawInfo` is nil and the default raw `decode` returns what the plain one returns | an extension is missed or misread, a clamp slips, or neutral settings gain a key | `RawFormat(fileName:)` matches case-sensitively; the slider clamp drops its upper bound; `setting(raw:)` stores `.cameraDefault` instead of nil; `kind(forFileName:)` loses `.raw`; the default `decode` passes `nil` for `maxLongSide` |
| RW-2 | `LibraryRawFakesTests` (from RW-1, enabled): the fake's table per format (NEF all four, ORF the noise rows only, ARW undevelopable, DNG three); `raw-shoot` has six photos with ids equal to paths and `rawFormat` set on five; two catalogs differing only in `rawInfo` are unequal | a fake row or fixture photo differs from the packet, or `==` ignores `rawInfo` | ORF offers Lens Correction; the ARW row is developable; `==` skips `rawInfo` |
| RW-3 | `LibraryRawImportTests` (fold): `DSC_0001.NEF` + `DSC_0001.JPG` keep the NEF with its partner; `dsc_0001.jpg` pairs too; a JPEG in another folder, a HEIC, or a stem shared by two raws stays apart; input order kept. `LibraryRawDecodePlanTests`: preview 1616 covers a 1024 request with `allowPreview` and camera defaults → `.preview`; 2048 → `.raw(scale:, draft: true)`; any setting set → `.raw`; `allowPreview` false → `.raw(draft: false)`; undevelopable with a preview and `allowPreview` → `.preview`, without → `.undevelopable`; `scale` never above 1. `LibraryRawBudgetTests.foldWithinBudget`: 10,000 candidates (half raw, a quarter paired) ≤ 5 ms release, 50 ms debug | a JPEG is lost or wrongly paired, a full decode runs where the preview covers, or export gets a draft | the stem compare is case-sensitive; a HEIC is folded as a partner; `>=` becomes `>` in `previewCovers`; `draft` is always true; an undevelopable file without `allowPreview` returns `.preview` |
| RW-4 | `LibraryRawImportTests` (enabled `liveImporter*` cases, a test-local decoder scanning NEF + JPG + a lone JPEG): 2 photos, the pair's id is the NEF path, `alreadyKnown` 0; again with both known: 0 new, `alreadyKnown` 2; with only the JPEG known (imported before raw support): the NEF is skipped, no duplicate | a pair imports twice, or a known JPEG lets its RAW in as a second photo | the known check ignores the partner; `alreadyKnown` counts the scan's candidates instead of the kept ones |
| RW-5 | `LibraryRawDecodeTests.tinyDNGMatchesItsWriter` (the committed file equals the writer's bytes) and `.tinyDNGOpensInTheSystemDecoder` (`CIRAWFilter(imageURL:)` is non-nil and its `outputImage` renders), both enabled | the fixture drifts from its writer, or the system decoder can't open it | – (test fixture only) |
| RW-6 | `LibraryRawDecodeTests` (macOS, the rest enabled): the tiny DNG scans as `.raw`, 24 × 32 after Orientation 6; `rawInfo` names "AfterGlow Test" and `previewSize` 12 × 16; `decode(maxLongSide: 16, allowPreview: true)` returns the preview's marker color, `allowPreview: false` the raw data's (each within 8/255); every offered control's default is in its range; a `.NEF` holding `not a raw file` fails the scan with `unreadableReason` | the preview isn't used, a decode ignores orientation, or a bad raw file's reason is generic | – (macOS only) |
| RW-7 | `LibraryRawSnapshots` `library-grid-raw`; RJ1 on the macOS run | a raw cell carries no RAW mark, or RJ1 fails | – (macOS only) |
| RW-8 | `LibraryRawDevelopTests` on `raw-shoot`: `rawInfoRequests` lists only raw targets without info; `rawHeader` "Test Camera Z · NEF · with DSC_0001.JPG", "Reading the raw file…" while pending, nil for `IMG_0006`; `rawRow(.lensCorrection)` on P0004 reads "This camera's files don't offer Lens Correction."; on DSC_0005 every row reads the camera's reason; two NEFs with different noise values read `.mixed`; `setRaw(.noiseReduction, 40, key)` twice with one key is one "Noise Reduction" step, undo restores both photos; it never changes a JPEG or an undevelopable target; through `LiveCatalogCoding` encode → decode the setting survives. `LibraryRawBudgetTests.setRawWithinBudget`: on `large` with 2 raw targets ≤ 1 ms release, 10 ms debug | a row is enabled that the file doesn't offer, a drag is several steps, or a setting reaches the wrong photo | `setRaw` applies to targets that don't offer the control; `rawRow` returns the first target's value instead of `.mixed` when they differ; the coalesce key is dropped; `failRawInfo` stores nothing (re-asks forever) |
| RW-9 | `LibraryRawRenderTests` (from RW-8, enabled; a recording decoder): a thumbnail asks with `allowPreview: true` and the photo's RAW settings; a loupe `.preview` render asks `allowPreview: true`, `.full` false; export false; a JPEG photo's calls carry `.cameraDefault` | the grid misses the preview, or the loupe or export accepts it | `LiveThumbnails` passes `allowPreview: false`; `LiveLoupeImaging` allows the preview for `.full`; `LiveExporter` allows the preview |
| RW-10 | `LibraryRawDevelopSnapshots` (three states); RJ2 (F and L) on the macOS run | a row is missing, enabled without support, or RJ2 fails | – (macOS only) |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-LIB-1 for raw (model half) | `RawPairs.fold` of 10,000 candidates ≤ 5 ms release (50 ms debug) | `LibraryRawBudgetTests.foldWithinBudget` |
| QB-LIB-1 for raw (preview first) | every grid bucket (128 to 1024, decoded at 2×) uses the embedded preview when it covers the size and the settings are the camera's | `LibraryRawDecodePlanTests`, `LibraryRawRenderTests`, `LibraryRawDecodeTests` |
| QB-L2 for RAW rows | `setRaw` ≤ 1 ms release (10 ms debug) | `LibraryRawBudgetTests.setRawWithinBudget` |
| QB-V4 for raw | export decodes with `allowPreview: false` and the same RAW settings the loupe's `.full` uses | `LibraryRawRenderTests` |
| QB-LIB-V8 (new) | the tiny DNG decodes upright; the preview and the raw render are told apart by color | `LibraryRawDecodeTests` |
| QB-F1 no dead controls | every RAW row is enabled or carries a reason | `LibraryRawDevelopTests`, RJ2 steps 3, 4, 7 |
| QB-F3 one gesture one step | a RAW drag is one named step | `LibraryRawDevelopTests`, RJ2 step 2 |
| QB-V5 | `library-grid-raw`, `library-develop-raw`, `library-develop-raw-unsupported`, `library-develop-raw-loading`, Light and Dark | the two snapshot files |

QB-LIB-V5 (the thumbnail matches the full picture) does not hold for a raw
photo at camera defaults: its thumbnail is the camera's preview, its loupe
render the system decoder's (open question R4). Real camera files (CR2 to
RW2) never run on CI: their extensions are Linux-tested, their pixels are
the system decoder's, and only the tiny DNG decodes in tests.

## Done check

Per slice (lead.md rule 6): **RW-a** when RW-1 and RW-2 have merged and RJ0
passes on the Linux gate with every mutation caught; **RW-b** when a scoped
run (`ci.yml` with `app=library`) containing RW-7 runs RJ1 green, every app
built, `Mutate:` full on RW-3 and RW-4, no open `finding`; **RW-c** the same
with RJ2 and RW-10. The audit adds nothing over `UITests/audit-baseline.json`
(the RAW rows carry `library.develop.raw.*` identifiers and names). Then
`Belt-Contact-Sheet: <run url>` on the feature issue.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| R1 | RW-2 adds a stored property (`rawInfo`) to `LibraryCatalog.swift`, which decision D6 reserves for the spine. The info is per file and arrives async, and no existing property can hold it | Accept the exception; metadata-more's MD-e also adds state there, so RW-2 waits on MD-e (R6) |
| R2 | RW-10 relies on develop's spine follow-up (`DevelopInspector(model:menu:cropDraft:)`) and adds one closure to develop's `LibraryMenu.Develop`. If that follow-up is dropped, the RAW section has no catalog to read | Keep the follow-up on develop's DV-9; RW-10 waits on all of develop |
| R3 | A JPEG imported before raw support, then its RAW: skip the RAW (no duplicate) or swap the photo to the RAW? | Skip in this packet (RW-4); swapping is a later, undoable command |
| R4 | At camera defaults the grid shows the camera's preview and the loupe's full render the system decoder's, which can differ in color | Accept: it is what keeps a raw import fast; the loupe value already says `preview` or `full` |
| R5 | The tiny DNG is hand-written from the public DNG spec by our own test code; whether Core Image RAW develops a hand-made Bayer file is untested | The spike is RW-5; fall back to LinearRaw (then the noise rows may not be offered, which RJ2 step 7 tolerates) |
| R6 | Raw and metadata-more (both wave 5) take over the same spine and import files (`LibraryValues.swift`, `LiveImporter.swift`, `ImageIODecoder.swift`, `LibraryCatalog.swift`), so one must wait on the other | Raw waits (this packet): metadata-more's keywords and camera details rank above raw in tier 2 (blueprint 3, rows 3 and 6), so most-used first. The cost: RW-a, two small Linux tasks, can't start until MD-e, late in metadata-more (which itself waits on filters-collections), and RW-10 waits on all of status-and-layout for two C4 sentences. To start raw early, flip it: metadata-more's MD-a, MD-b and MD-e wait on `raw:RW-a` / `raw:RW-b` and these waits go |
| R7 | Raw is still "not v1, pending evidence" (`docs/priorities.md`). Build it after v1, or now? | After v1, as the blueprint orders; the packet is ready either way |
