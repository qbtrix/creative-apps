# Feature packet: export

**Feature:** File > Export… (⇧⌘E) writes the selected photos, or the loupe's
photo, as finished files into a folder: sRGB JPEG at a long edge and a
quality by default, with each photo's develop settings and crop, never
enlarged and never overwriting a file. On top of that loop: PNG, TIFF and
HEIC through ImageIO, presets and a file-name template, a batch that shows
progress, keeps going past a bad file and can be cancelled, and an XMP
sidecar beside each file.
**Line:** `line:library` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/export`

**Covers:** #424 (closes with EX-13; EX-5, EX-6 and EX-12 say `Part of #424`).
Blueprint 1.4 puts other formats, presets and name templates *out* of v1;
this packet adds them under the captain's blueprint rule (fix the area's top
complaints, add a few features from the future), as slices EX-c, EX-d and
EX-f that run beside the v1 slices and never hold #424 up. As in
design-contracts, the lead files them at stage 1 as `gap` issues (labels
`gap`, `line:library`, `p2`): "Library: export PNG, TIFF and HEIC",
"Library: export presets and file-name templates", "Library: XMP sidecar
beside exported files". EX-8, EX-11 and EX-16 close them.

**Depends on:** the develop feature (`LiveDevelop` renders the settings) and
import (`ImageIODecoder.decode` at full size, the live importer for the (L)
steps). Inside wave 4 one task waits on crop: EX-14 waits on crop's CR-b, the slice that builds `LiveCrop.frame` and `LiveDevelop`'s crop (the cropped-photo half of QB-V4 and the plan's cropped size need them). It does not wait on CR-e, which hangs on a creative-core bump. Crop's packet no longer edits `LibraryContracts.swift`, `FakeRendering.swift` or `LibraryWindow.swift`, so EX-1 and EX-6 start without it. SuiteUI: S-L5 `ProgressRow` (#781, open) is a soft wait: until it merges the
sheet's progress row is a plain SwiftUI placeholder (import's precedent),
and a fix PR swaps it in. P8 waits on S-L8 named marks (#782, open); #330
and #333 have merged, so every journey has its own `+Export*.swift` file and
`UITests/LibraryJourneyTests.swift` is not touched.

**No creative-core issue.** creative-core at the pinned `c608d4b` has no
raster file encoder (CoreRaster has resampling and `rgba8(colorSpace:)`;
FlareCore's `PNGExportPlan` plans frames, it doesn't encode), and none is
needed: ImageIO encodes. `CGImageDestinationCopyTypeIdentifiers()` on macOS
26.6.2 lists `public.jpeg`, `public.png`, `public.tiff` and `public.heic`
(also AVIF, unasked) and **not** `org.webmproject.webp`, so WebP is out:
neither the engine nor the platform writes it (open question 1).

Blueprint sections: 1.4 (the v1 export row), 2.2 (`library-export`), 2.3
(`library-app-export`, `library-app-platform`), 4.1 (`-LibraryExportTo`,
`LibraryFiles.readOnlyFolder()`), 4.2 J7, 4.3 P8, 5.1 (`PhotoExporting`,
`JPEGWriting`), 5.2 (`ExportSummary`), 5.3 (`ExportOptions`, `ExportPlan`),
5.6 (`exportState`), 5.7 (the J7 row), 6.2 (the export sheet), 6.3, 7.1
(QB-L9, QB-LIB-7), 7.4 (QB-V4).

**Complaints this fixes, most-used first** (behaviour only, clean-room):

| Complaint in this area | What export does | Slice |
|---|---|---|
| An export wrote over an earlier file | Never overwrites: `IMG_0001 2.jpg`, and the writer refuses an existing name even if the plan raced | EX-a, EX-b |
| The file doesn't look like the edit (color shift, crop lost) | One pipeline: full-size decode, develop and crop, lanczos3, sRGB-tagged; QB-V4 holds it to the loupe | EX-a, EX-b, EX-e |
| A small photo came out blurry and huge | Never enlarges: the long edge is a ceiling | EX-a |
| Export froze the app with no idea how long | Off the main actor, "Exporting 3 of 24" with Cancel, within 100 ms | EX-b, EX-e |
| One bad file killed the whole batch | Every other file is still written; each failure is listed with its reason; Try Again re-runs only those | EX-e |
| The same settings retyped every time | Built-in and saved presets; the last settings come back, also after relaunch | EX-d |
| Names clash or mean nothing | A name template ({name}, {date}, {seq}, {rating}) with a live preview of the first name | EX-d |

**From the future:** the sheet shows the first file's name and pixel size
before you press Export; a format this Mac can't write is disabled with the
reason instead of failing after the fact; an XMP sidecar carries the rating,
label, pick and develop settings next to each file, so the work travels
with it.

No task edits `docs/c4/model.json` or `docs/design.md`. Every new source
file sits under `Sources/LibraryModel/Contracts/` or
`Sources/LibraryApp/Platform/`, which `c4-planned.json` already owns, so no
C4 part changes. Handovers from the spine (wave 1): EX-1 edits
`Contracts/LibraryContracts.swift` (`ExportOptions` only) and
`Fakes/FakeRendering.swift` (`FakeExporter` only); EX-6 edits one line of
`LibraryWindow.swift` (the sheet is presented as `LibraryExportSheet()`,
with no model to read). `LibraryServices.swift`, `LibraryLaunch.swift` and
`LibraryCatalog.swift` are not touched: no new service member, launch
argument or stored property.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Library-scoped macOS run (`ci.yml` with `app=library`); EX-a's walk runs
among the Model tests there. EX-a publishes every value, slot and catalog
method the other slices fill, so after EX-a and EX-b, slices EX-c to EX-f
build side by side.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| EX-a | On the fake services, exporting two selected photos plans files at the chosen long edge and quality that never overwrite (`IMG_0001 2.jpg` the second time), renders each with its develop settings, writes them in order, and the format, preset, name and sidecar options exist as slots the sheet can show. | EX-1, EX-2, EX-3 | MX1 | nothing |
| EX-b | File > Export… opens the sheet on the selection, and Export writes real sRGB JPEGs at 1024 px and quality 80 into the folder with Show in Finder, a second export adds `IMG_0001 2.jpg`, and the exported pixels match the loupe. | EX-4, EX-5, EX-6 | J7 | EX-a (EX-5, EX-6) |
| EX-c | The Format row writes PNG, TIFF or HEIC with the same pixels, hides quality for lossless formats, and disables a format this Mac can't write with the reason. | EX-7, EX-8 | J7F | EX-a (EX-7); EX-b (EX-8) |
| EX-d | A name template names the files with a live preview and never an illegal or duplicate name, presets set every option at once, and the last settings come back on the next export and after relaunch. | EX-9, EX-10, EX-11 | J7N | EX-a (EX-9, EX-10); EX-b (EX-11) |
| EX-e | Exporting many photos shows its progress with Cancel, keeps going past a file that fails, lists each failure with Try Again, stops cleanly on Cancel, and a cropped photo exports exactly as the loupe shows it. | EX-12, EX-13, EX-14 | J7B, P8 | EX-a (EX-12, EX-13, EX-14); EX-b (EX-13, EX-14); crop:CR-b (EX-14); #782 (P8 in EX-13) |
| EX-f | With Write Sidecar on, each exported file gets an XMP file beside it with its rating, label, pick and develop settings, named so neither file overwrites anything. | EX-15, EX-16, EX-17 | J7S | EX-a (EX-15, EX-16); EX-b (EX-16); EX-c, EX-d, EX-e (EX-17, the docs task) |

Screen early: EX-b, EX-c and EX-d own `Sources/LibraryApp/` files, so they
are UI slices (`"ui": true`). EX-b already waits only on EX-a, the first
slice; its sheet (EX-6) is reached from File > Export…. EX-a carries the real
`LiveExporter` and `ExportRunner` (EX-2, EX-3) beside the contract, so here
"contract" means the first slice, and nothing was split.

## Journey steps

Each journey has its own class and file (#333 merged). (F) runs on fakes,
(L) on real files written by the spine's `LibraryFiles` and imported with
`-LibraryImportFolder <dir> -LibraryImportOnLaunch`. Every (L) launch passes
`-LibraryExportTo` on a fresh temp folder and a fresh `-LibraryCatalogDir`.

**MX1 · `LibraryExportFlowTests.testExportWalk`** (Linux Model walk, EX-3;
slice EX-a). On `LibraryServices.fake(LibraryFixtures.photos(named: "shoot"))`:
sort by name, select `IMG_0001` and `IMG_0002`; `beginExport(folder: "/out")`
is true; `setExportOptions` long edge 1024, quality 80; `exportPlan` names
`IMG_0001.jpg` (1024 × 683) and `IMG_0002.jpg`; `ExportRunner.run` on the
fakes reports progress 1 then 2 and `finishExport` shows "Exported 2
photos."; `closeExport`; the same again plans `IMG_0001 2.jpg` and
`IMG_0002 2.jpg` against the fake writer's names.

**J7 · `LibraryExportJourneyTests.testExportJPEGsAtASize`**
(`UITests/LibraryJourneyTests+Export.swift`; slice EX-b; blueprint J7 steps
1–4 and 7)
1. (F) Launch on `shoot`; (L) live on `writeShoot`. Sort by Name; select
   `IMG_0001` and `IMG_0002`; File > Export…. Shot `export-sheet`. Expect
   the title "Export 2 Photos", long edge 2048, quality 85, the preview line
   "IMG_0001.jpg · 2048 × 1365", the sheet inside the display.
2. (L) Set the long edge to 1024 and quality to 80; click **Export**. Shot
   `exporting`. Expect `library.export.progress` "Exporting 1 of 2" with
   Cancel, or the summary if both were already written.
3. (L) Wait. Shot `exported`. Expect `library.export.summary` "Exported 2
   photos." and **Show in Finder**; `IMG_0001.jpg` and `IMG_0002.jpg` exist,
   start with `FF D8`, and their long edge is 1024.
4. (L) Export the same two again. Expect `IMG_0001 2.jpg` and
   `IMG_0002 2.jpg`; the first two files' bytes unchanged.
5. (F, L) Close the sheet; Escape to the grid; Deselect: File > Export… is
   disabled with "Select a photo to export it.".
States: none empty; loading (the progress row).

**J7F · `LibraryExportFormatsJourneyTests.testExportOtherFormats`**
(`+ExportFormats.swift`; slice EX-c; all L)
1. Live on `writeShoot`; select `IMG_0001`; Export…; choose **PNG**. Shot
   `export-png`. Expect the Quality row hidden and the preview
   "IMG_0001.png · 2048 × 1365". Export: `IMG_0001.png` starts with
   `89 50 4E 47`.
2. Choose **TIFF**; export: `IMG_0001.tif` starts with `49 49 2A 00` or
   `4D 4D 00 2A`.
3. Choose **HEIC**. If `library.export.format.HEIC` is enabled, export:
   `IMG_0001.heic` holds `ftyp` at byte 4. If it is disabled, its help is
   "This Mac can't write HEIC files." and the format stays JPEG.
States: error (a format this Mac can't write).

**J7N · `LibraryExportPresetsJourneyTests.testExportPresetsAndNames`**
(`+ExportPresets.swift`; slice EX-d; all L)
1. Live on `writeShoot`; sort by Name; select `IMG_0001` to `IMG_0003`;
   Export…; choose preset **For Sharing**. Expect long edge 2048, quality 85,
   JPEG.
2. Type `{date}-{seq}` in **Name**. Shot `export-names`. Expect the preview
   "2026-06-01-1.jpg · 2048 × 1365". Export: `2026-06-01-1.jpg`,
   `2026-06-01-2.jpg`, `2026-06-01-3.jpg`.
3. Set long edge 1200, quality 70; **Save as Preset…** "Web 1200". Close.
4. Relaunch on the same `-LibraryCatalogDir` (wait for `library.catalog` =
   `saved` first); select one photo; Export…. Expect long edge 1200, quality
   70, name `{date}-{seq}` (last settings), and "Web 1200" in the preset menu.
5. Type `{nope}`: the name field's help reads "Unknown token {nope}." and
   Export is disabled with that reason.
States: error (an unknown token).

**J7B · `LibraryExportBatchJourneyTests.testExportFailsAndCancels`**
(`+ExportBatch.swift`; slice EX-e; blueprint J7 steps 5–6)
1. (L) Live on `writeShoot` with `-LibraryExportTo` on
   `LibraryFiles.readOnlyFolder()`; select `IMG_0001`, `IMG_0002`; export.
   Shot `export-failed`. Expect "2 photos couldn't be exported." with each
   name and reason in `library.export.failures`, and **Try Again**.
2. (L) Relaunch writable; select all 24; Original Size; Export; click
   **Cancel** once `library.export.progress` reads "Exporting 2 of 24".
   Shot `export-cancelled`. Expect "Exported 1 of 24. Export was
   cancelled." (or 2 of 24 when the click lands after the second write) and
   fewer than 24 files.
3. (F) Relaunch on `shoot` with `-LibraryFakeMode slow`; select 3; Export.
   Expect the progress row within 2 s (the fake waits 2 s per file).
States: loading (progress row), error (per-file failures), cancelled.

**J7S · `LibraryExportSidecarsJourneyTests.testExportWithSidecars`**
(`+ExportSidecars.swift`; slice EX-f; all L)
1. Live on `writeShoot`; open `IMG_0001` in the loupe; press 3, then P.
   Export…; turn on **Write Sidecar**. Shot `export-sidecar`. Expect the
   preview "IMG_0001.jpg + .xmp · 2048 × 1365".
2. Export. Expect `IMG_0001.jpg` and `IMG_0001.xmp`; the `.xmp` holds
   `xmp:Rating="3"`.
3. Export again: `IMG_0001 2.jpg` and `IMG_0001 2.xmp`; nothing replaced.
States: none.

**P8 · `LibraryPerfExportJourneyTests.testExportThroughput`**
(`+PerfExport.swift`; slice EX-e) as blueprint 4.3: 10 written 6000 × 4000
JPEGs, export at long edge 2048, three runs; each run records its `progress`
mark (S-L8, #782) and its whole time in `perf-testExportThroughput.json`
(report-only).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| File menu | nothing selected and not in the loupe: Export… disabled with "Select a photo to export it." | – | while an export runs: disabled with "An export is already running." |
| Export sheet, options | – | Export disabled with the reason when the name template has an unknown token or the folder is unset; a format this Mac can't write is a disabled chip with its reason | – |
| Export sheet, running | – | – | progress row "Exporting 3 of 24" (`library.export.progress`, value the text) with Cancel, after 100 ms (placeholder until #781) |
| Export sheet, done | – | "2 photos couldn't be exported." with a list of `name: reason` (`library.export.failures`) and **Try Again**; cancelled: "Exported 1 of 24. Export was cancelled." | – |

Before a slice lands, its row in the sheet is a slot: the Format chips show
JPEG enabled and PNG, TIFF, HEIC disabled with "Other formats aren't built
yet (export formats)."; the preset menu and name field are disabled with
"Presets aren't built yet (export presets)." and "Name templates aren't
built yet (export naming)."; Write Sidecar is disabled with "Sidecars aren't
built yet (export sidecars).". So no control is ever dead (QB-F1).

Snapshots (`LibraryExportSnapshots.swift`, EX-6, Light and Dark, blueprint
6.3): `library-export`, `library-exporting`, `library-export-failed`,
`library-export-done`, `library-export-cancelled`. A slice that enables a
slot changes `library-export.png` without editing the snapshot file; its PR
lists that PNG.

## Contract slice

From the spine, unchanged: `PhotoExporting` (`plan`, `render`),
`JPEGWriting` (`existingNames`, `write(_:quality:folder:fileName:)`; the
writer picks the encoder from the name's extension, so its signature
stays), `ExportPlan`, `ExportSummary` and its `message`, `FileFailure`,
`ExportState`, `LibraryError.writeFailed`, `LibraryMenu.Export`,
`ExportAreaState`. EX-1 adds, all with slot behaviour where a later slice
fills it:

```swift
// Contracts/LibraryContracts.swift (ExportOptions only): three defaulted
// fields, so every existing ExportOptions(longEdge:quality:folder:) compiles.
public var format: ExportFormat = .jpeg
public var naming: ExportNaming = .original
public var sidecar: Bool = false
public init(longEdge: Int? = defaultLongEdge, quality: Int = 85, folder: String,
            format: ExportFormat = .jpeg, naming: ExportNaming = .original, sidecar: Bool = false)

// Contracts/ExportFormats.swift (filled by EX-7)
public enum ExportFormat: String, CaseIterable, Sendable, Codable {
    case jpeg = "JPEG", png = "PNG", tiff = "TIFF", heic = "HEIC"
    public var fileExtension: String                  // jpg, png, tif, heic (EX-1, final)
    public var usesQuality: Bool                      // slot: true; EX-7: jpeg and heic only
    /// The format a written name ends in (jpg, jpeg, png, tif, tiff, heic, any case).
    public static func forFileName(_ name: String) -> ExportFormat?   // slot: jpg/jpeg only
    /// Why `self` can't be chosen, nil when it can.
    public func help(writable: Set<ExportFormat>) -> String?          // slot: "Other formats aren't built yet (export formats)." but JPEG
}

// Contracts/ExportNaming.swift (stems filled by EX-9; the unique rule is final in EX-1)
public struct ExportNaming: Hashable, Sendable, Codable {
    public var template: String
    public static let original = ExportNaming(template: "{name}")
    public init(template: String)
    /// The file stem for `photo`, the `index`-th (0-based) of `count`.
    public func stem(for photo: PhotoItem, index: Int, count: Int) -> String   // slot: photo.name
    /// "Unknown token {x}." and the like; nil when the template can name files.
    public var help: String? { get }        // slot: nil for .original, else "Name templates aren't built yet (export naming)."
}
public enum ExportNames {
    /// `<stem>.<ext>`, then `<stem> 2.<ext>`, `<stem> 3.<ext>` … skipping `existing`
    /// and names earlier in the list; with `sidecar`, `<chosen stem>.xmp` must be free too.
    public static func unique(stems: [String], format: ExportFormat, sidecar: Bool,
                              existing: Set<String>) -> [String]
}

// Contracts/ExportPresets.swift (filled by EX-10)
public struct ExportPreset: Hashable, Sendable, Codable, Identifiable {
    public var id: String, name: String
    public var longEdge: Int?, quality: Int, format: ExportFormat, naming: ExportNaming, sidecar: Bool
    public var isBuiltIn: Bool
    public init(name: String, options: ExportOptions)
    /// `options` with every field of this preset but the folder.
    public func applied(to options: ExportOptions) -> ExportOptions
}
public struct ExportPresetFile: Hashable, Sendable, Codable {   // what the area stores
    public var presets: [ExportPreset]; public var last: ExportOptions?
}
public enum ExportPresets {
    public static let unavailable: String?         // slot: "Presets aren't built yet (export presets)."; EX-10: nil
    public static var builtIns: [ExportPreset] { get }               // slot: []
    public static func adding(_ preset: ExportPreset, to list: [ExportPreset]) -> [ExportPreset]   // slot: list
    public static func removing(_ id: String, from list: [ExportPreset]) -> [ExportPreset]         // slot: list
    public static func decode(_ data: Data?) -> ExportPresetFile     // slot: empty file
    public static func encode(_ file: ExportPresetFile) -> Data
}

// Contracts/ExportSidecar.swift (filled by EX-16)
public enum ExportSidecar {
    public static let unavailable: String?         // slot: "Sidecars aren't built yet (export sidecars)."; EX-16: nil
    /// `IMG_0001 2.jpg` → `IMG_0001 2.xmp` (EX-1, final).
    public static func fileName(for imageName: String) -> String
    /// The XMP packet for `photo` as exported; nil while unavailable.
    public static func xmp(for photo: PhotoItem) -> Data?            // slot: nil
}
```

`ExportOptions` needs `Codable` for `ExportPresetFile.last`: EX-1 adds the
conformance (every field is already `Codable`). The catalog methods
(blueprint 5.7, `LibraryExport.swift`), declared by EX-1 as stubs that
refuse with `LiveExporter.unavailable`, filled by EX-3, and the batch half
by EX-13:

```swift
extension LibraryCatalog {
    /// The loupe's photo in the loupe, else the selected photos in `order`.
    public var exportTargets: [PhotoItem] { get }
    /// "Select a photo to export it.", "An export is already running.", or the
    /// exporter's unavailable reason; nil when Export… can act.
    public var exportHelp: String? { get }
    /// Opens the sheet: `.editing(last ?? default)` with `folder`. False with no
    /// targets or while one runs.
    public mutating func beginExport(folder: String, last: ExportOptions? = nil) -> Bool
    public mutating func setExportOptions(_ options: ExportOptions)        // only while .editing
    /// The sheet's preview of the first target: "IMG_0001.jpg · 2048 × 1365",
    /// "IMG_0001.jpg + .xmp · …" with a sidecar, or the template's help.
    public var exportPreview: String? { get }
    /// The plan for `exportTargets` under the editing options, `.running(0, n)`;
    /// nil unless editing with a usable template.
    public mutating func exportPlan(existingNames: Set<String>) -> ExportPlan?
    public mutating func showExportProgress(done: Int, total: Int)
    public mutating func finishExport(_ summary: ExportSummary)
    /// True while running; the area then cancels its task (EX-13).
    public mutating func cancelExport() -> Bool
    /// From `.finished` with failures: the plan of only `failedIDs` under
    /// `options`, `.running(0, n)`; nil otherwise (EX-13; 5.7's `retryExport() -> Bool`
    /// takes the options because the finished state doesn't keep them).
    public mutating func retryExport(options: ExportOptions, existingNames: Set<String>) -> ExportPlan?
    public mutating func closeExport()                                     // refused while running
}

/// Renders and writes a plan off the main actor, in order, one photo at a time.
public enum ExportRunner {
    public static func run(_ plan: ExportPlan, photos: [String: PhotoItem],
                           exporter: any PhotoExporting, writer: any JPEGWriting,
                           writeSidecar: @escaping @Sendable (Data, _ folder: String, _ fileName: String) async throws -> Void,
                           progress: @escaping @Sendable (Int) -> Void) async -> ExportSummary
}
```

`LiveExporter(decoder:develop:)` replaces the spine's stub (EX-2) and sets
`unavailable` to nil. `JPEGWriter` replaces the spine's platform stub (EX-5)
and gains `static func writableFormats() -> Set<ExportFormat>` (`[.jpeg]`
until EX-8) and `func writeSidecar(_ data: Data, folder: String, fileName:
String) async throws` (never overwriting). Sidecar bytes go through that
platform method, passed to the runner as a closure, so `LibraryServices`
gains no member.

## Pseudocode

```
ExportNames.unique(stems, format, sidecar, existing):           # EX-1
  taken = existing; names = []
  for stem in stems:
    n = 1; s = stem
    while taken ∋ s.ext or (sidecar and taken ∋ s.xmp): n += 1; s = "\(stem) \(n)"
    taken ∪= {s.ext} ∪ (sidecar ? {s.xmp} : {}); names.append(s.ext)

LiveExporter.plan(photos, options, existing):                    # EX-2
  stems = photos.enumerated().map { options.naming.stem(for: $1, index: $0, count: photos.count) }
  names = ExportNames.unique(stems, options.format, options.sidecar, existing)
  for photo: full = croppedSize(photo)      # LiveCrop().frame(crop, photo.pixelSize) when a crop is set (EX-14 proves it), else pixelSize
             size = options.longEdge.map { full.fitting(longSide: $0) } ?? full     # never enlarged
LiveExporter.render(item, photo):
  image = photo.path == nil ? SampleImage.image(for: photo, longSide: nil)
                            : try await decoder.decode(path, maxLongSide: nil)      # full size, upright, sRGB
  buffer = PixelBuffer(rgba8: image) → try develop.render(buffer, settings: photo.develop)   # tone, then crop
  target = buffer.size.fitting(longSide: item.size.longSide)    # the real crop decides the shape
  if target != buffer.size: buffer = try buffer.resized(target, .lanczos3)
  return DisplayImage(buffer.rgba8(colorSpace: .sRGB))

ExportRunner.run(plan, photos, exporter, writer, writeSidecar, progress):   # EX-3, EX-13
  written = []; failures = []; failedIDs = []
  for (i, item) in plan.items:
    if Task.isCancelled: return summary(cancelled: true)                    # EX-13
    do { image = try await exporter.render(item, photo)
         if Task.isCancelled: return summary(cancelled: true)               # EX-13: never write after Cancel
         try await writer.write(image, quality, folder, item.fileName)
         if options.sidecar, let xmp = ExportSidecar.xmp(for: photo):
           try await writeSidecar(xmp, folder, ExportSidecar.fileName(for: item.fileName))
         written.append(item.fileName) }
    catch { failures.append(FileFailure(item.fileName, (error as? LibraryError)?.message ?? "\(error)"))
            failedIDs.append(item.photoID) }                                 # keep going
    progress(i + 1)

ExportNaming.stem(photo, index, count):                          # EX-9
  {name} photo.name · {date} captureDate as yyyy-MM-dd (Gregorian, UTC) ·
  {seq} index + 1 zero-padded to count's digit count · {rating} 0–5
  unknown {x} → help "Unknown token {x}."; "/" and ":" → "-"; leading "." dropped;
  empty → photo.name

ExportSidecar.xmp(photo):                                        # EX-16
  <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF …><rdf:Description
    xmp:Rating="3" xmp:Label="Red" xmp:CreateDate="2026-06-01T10:07:00Z"
    library:Flag="pick" library:Exposure="0.5" … library:CropAngle="2" library:Crop="x y w h"/>
  attributes in a fixed order, values XML-escaped (& < > " '), rating -1 for a reject (XMP's convention)

LibraryWindow+Export (EX-6, macOS):
  export.export = model.exportHelp == nil ? { model.beginExport(folder: launch.exportTo ?? last folder ?? Pictures) } : nil
  exportSheet: LibraryExportSheet(state: model.exportState, targets:, preview:, writable: isPreview ? all : JPEGWriter.writableFormats(), presets:, actions)
  Export: names = try await writer.existingNames(folder); plan = model.exportPlan(existingNames:)
          areas.export.task = Task.detached { ExportRunner.run(plan, …, progress: { main: model.showExportProgress }) → main: model.finishExport }
  Cancel while running: if model.cancelExport() { areas.export.task?.cancel() }
  Show in Finder: NSWorkspace.activateFileViewerSelecting(written URLs); Choose…: NSOpenPanel (folders, can create)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: export`, `Slice: <slice>`,
`Fast-Check: pass`, `Head:`, the snapshot PNGs it changes, and a `Mutate:`
score line when it owns a plan. EX-17 carries `feature-done`. Model paths
drop `Sources/LibraryModel/`; Model tests are `Tests/LibraryModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EX-1 | – | Contract: `ExportOptions` fields and `Codable`; the format, naming, preset and sidecar values with their slots; `ExportNames.unique`; `FakeExporter` on the shared rule; the catalog methods and `ExportRunner` as refusing stubs; EX-a's tests (EX-2's and EX-3's disabled) | `Contracts/LibraryContracts.swift`, `Contracts/ExportFormats.swift`, `Contracts/ExportNaming.swift`, `Contracts/ExportPresets.swift`, `Contracts/ExportSidecar.swift`, `Fakes/FakeRendering.swift`, `LibraryExport.swift`; tests `LibraryExportContractTests.swift`, `LibraryExportPlanTests.swift`, `LibraryExportFlowTests.swift`; `Tests/mutations/LibraryModel.ExportNaming.json` | crop CR-2 | ~390, 11 |
| EX-2 | #424 (part) | `LiveExporter`: plan (long edge never enlarged, original size, names), render (full decode, develop, lanczos3, samples); `unavailable = nil`; enables `LibraryExportPlanTests` | `Live/LiveExporter.swift`; tests `LibraryExportPlanTests.swift`; `Tests/mutations/LibraryModel.LiveExporter.json` | EX-1 | ~220, 3 |
| EX-3 | #424 (part) | The catalog's export states, `exportPreview` and `ExportRunner` (in order, per-file failures, sidecar slot); MX1; enables `LibraryExportFlowTests` | `LibraryExport.swift`; tests `LibraryExportFlowTests.swift`; `Tests/mutations/LibraryModel.LibraryExport.json` | EX-1 | ~300, 3 |
| EX-4 | – | EX-b's checks: J7 (`XCTSkip("waits on EX-6")`) and QB-V4 (a)–(c) on an uncropped photo (`.disabled("waits on EX-5")`) | `UITests/LibraryJourneyTests+Export.swift`, `Tests/AppSnapshotTests/LibraryExportFidelityTests.swift` | – | ~260, 2 |
| EX-5 | #424 (part) | `JPEGWriter`: sRGB JPEG by ImageIO at quality/100, `existingNames`, `.withoutOverwriting` writes, `writableFormats` (`[.jpeg]`), `writeSidecar`; enables the fidelity tests | `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Tests/AppSnapshotTests/LibraryExportFidelityTests.swift` | EX-2, EX-4 | ~170, 2 |
| EX-6 | #424 (part) | The export area and sheet: ⇧⌘E, size chips and Long Edge field, Quality, Folder with Choose…, the four slots, preview line, progress row placeholder, summary, Show in Finder, Cancel and Try Again wired to `cancelExport` and `retryExport`, Save as Preset… kept in memory; the sheet call site in `LibraryWindow.swift`; snapshots; enables J7 | `Sources/LibraryApp/LibraryWindow+Export.swift`, `Sources/LibraryApp/LibraryExportSheet.swift`, `Sources/LibraryApp/LibraryWindow.swift` (the `.sheet` line only), `Tests/AppSnapshotTests/LibraryExportSnapshots.swift`, `UITests/LibraryJourneyTests+Export.swift` | EX-3, EX-4, EX-5; crop CR-5 | ~380, 5 |
| EX-7 | gap "PNG, TIFF and HEIC" (part) | Format rules: quality only for JPEG and HEIC, `forFileName`, the can't-write reason; EX-c's checks (fidelity per format disabled, J7F skipped) | `Contracts/ExportFormats.swift`; tests `LibraryExportFormatTests.swift`; `Tests/AppSnapshotTests/LibraryExportFormatFidelityTests.swift`, `UITests/LibraryJourneyTests+ExportFormats.swift`; `Tests/mutations/LibraryModel.ExportFormats.json` | EX-1 | ~300, 5 |
| EX-8 | gap "PNG, TIFF and HEIC" (closes) | `JPEGWriter` encodes PNG, TIFF and HEIC by the name's extension; `writableFormats` from `CGImageDestinationCopyTypeIdentifiers`; enables the format fidelity tests and J7F | `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Tests/AppSnapshotTests/LibraryExportFormatFidelityTests.swift`, `UITests/LibraryJourneyTests+ExportFormats.swift` | EX-5, EX-6, EX-7 | ~160, 3 |
| EX-9 | gap "presets and templates" (part) | Name templates: tokens, padding, illegal characters, unknown-token help; EX-d's checks (preset tests disabled, J7N skipped) | `Contracts/ExportNaming.swift`; tests `LibraryExportNamingTests.swift`, `LibraryExportPresetTests.swift`; `UITests/LibraryJourneyTests+ExportPresets.swift`; `Tests/mutations/LibraryModel.ExportNaming.json` | EX-1 | ~330, 5 |
| EX-10 | gap "presets and templates" (part) | Presets: built-ins, add with a unique name, remove (never a built-in), apply keeps the folder, encode and decode (damaged data gives the built-ins and no last); enables the preset tests | `Contracts/ExportPresets.swift`; tests `LibraryExportPresetTests.swift`; `Tests/mutations/LibraryModel.ExportPresets.json` | EX-9 | ~220, 3 |
| EX-11 | gap "presets and templates" (closes) | `ExportPresetStore` (`export-presets.json` beside the catalog file, so each journey's fresh catalog folder starts clean); the area loads it when the sheet opens and saves the last options and presets; enables J7N | `Sources/LibraryApp/Platform/ExportPresetStore.swift`, `Sources/LibraryApp/LibraryWindow+Export.swift`, `UITests/LibraryJourneyTests+ExportPresets.swift` | EX-6, EX-9, EX-10 | ~200, 3 |
| EX-12 | #424 (part) | EX-e's checks: cancel and retry tests and P8 disabled or skipped; the export budgets (they measure EX-2's and EX-3's real code, never the stubs, so they wait for both and run at once) | tests `LibraryExportBatchTests.swift`, `LibraryExportBudgetTests.swift`; `UITests/LibraryJourneyTests+ExportBatch.swift`, `UITests/LibraryJourneyTests+PerfExport.swift` | EX-2, EX-3 | ~300, 4 |
| EX-13 | #424 (closes) | Cancel before each photo and between render and write; `cancelExport`; `retryExport` re-plans only the failed ids (EX-6 already wires the sheet's Cancel and Try Again to them); enables the batch tests, J7B and (once #782 has merged) P8 | `LibraryExport.swift`; tests `LibraryExportBatchTests.swift`; `UITests/LibraryJourneyTests+ExportBatch.swift`, `UITests/LibraryJourneyTests+PerfExport.swift`; `Tests/mutations/LibraryModel.LibraryExport.json` | EX-3, EX-6, EX-12; #782 for P8 | ~220, 5 |
| EX-14 | – | QB-V4 and the plan's size on a cropped, straightened photo | `Tests/AppSnapshotTests/LibraryExportFidelityTests.swift`; tests `LibraryExportPlanTests.swift`; `Tests/mutations/LibraryModel.LiveExporter.json` | EX-2, EX-5; crop (the feature) | ~150, 3 |
| EX-15 | – | EX-f's checks: the XMP tests disabled, J7S skipped | tests `LibraryExportSidecarTests.swift`; `UITests/LibraryJourneyTests+ExportSidecars.swift` | EX-1 | ~200, 2 |
| EX-16 | gap "XMP sidecar" (closes) | `ExportSidecar.xmp`: the packet, fixed attribute order, escaping, reject as -1; `unavailable = nil`; enables the XMP tests and J7S | `Contracts/ExportSidecar.swift`; tests `LibraryExportSidecarTests.swift`; `UITests/LibraryJourneyTests+ExportSidecars.swift`; `Tests/mutations/LibraryModel.ExportSidecar.json` | EX-6, EX-15 | ~180, 4 |
| EX-17 | – | Blueprint prose: J7 split into J7, J7F, J7N, J7B, J7S (4.2); the 1.4 export row; the 6.2 sheet rows; 6.3; 8.3's owned files. `feature-done` | `docs/blueprints/library.md` | EX-8, EX-11, EX-13, EX-14, EX-16 | ~120, 1 |

A task that measures over 400 lines splits by file before it opens (EX-1
and EX-6 are the likeliest; each split stays in its slice).

Shared files pass along a depends-on link: `LibraryExportPlanTests.swift`
EX-1 → EX-2 → EX-14; `LibraryExportFlowTests.swift` EX-1 → EX-3;
`LibraryExport.swift` and its plan EX-1 → EX-3 → EX-13; `JPEGWriter.swift`
EX-5 → EX-8; the fidelity tests EX-4 → EX-5 → EX-14; `ExportNaming.swift`
and its plan EX-1 → EX-9; `LibraryWindow+Export.swift` EX-6 → EX-11; each
`+Export*.swift` journey from its check task to the task that enables it.
EX-5 needs EX-2 because the fidelity tests it enables call
`LiveExporter.render`; EX-8, EX-11, EX-13 and EX-16 need EX-6 because their
journeys drive its sheet. EX-15 is checks only; its tests compile against
EX-1's stubs. EX-12 waits on EX-2 and EX-3 so its enabled budgets time
real code. EX-4 needs nothing: its tests use
`LiveExporter` and `JPEGWriter` as the spine left them.

Mutations target Model code (contract rule 14). EX-4, EX-5, EX-6, EX-8 and
EX-11 change only macOS code (`LibraryApp`) or journeys, so they own no
plan; their oracle is the fidelity tests (bytes and pixels), the snapshots
and the journeys. EX-12, EX-15 and EX-17 add no behaviour.

## Build waves

- Wave 1: EX-1, EX-4. Independent in this wave: both.
- Wave 2: EX-2, EX-3, EX-7, EX-9, EX-15. Independent in this wave: all five.
- Wave 3: EX-5, EX-10, EX-12. Independent in this wave: all three.
- Wave 4: EX-6, EX-14 (after crop's CR-b). Independent in this wave: both.
- Wave 5: EX-8, EX-11, EX-13, EX-16 (EX-13's P8 half also waits on #782). Independent in this wave: all four.
- Wave 6: EX-17 (blueprint prose, `feature-done`, final). Independent in this wave: EX-17 alone.

Longest chain: EX-1 → EX-2 → EX-5 → EX-6 → EX-13 → EX-17 (6).
Chain of 6: `LiveExporter` implements EX-1's naming rule; the fidelity tests
EX-5 enables call `LiveExporter.render`; the sheet's (L) steps need EX-5's
real writer; J7B drives EX-6's sheet; the prose task describes every slice,
so it lands last.

## Acceptance test per task

| id | test | fails when | mutations (plan) |
|---|---|---|---|
| EX-1 | `LibraryExportContractTests`: `ExportOptions(longEdge:quality:folder:)` keeps its clamps and defaults to JPEG, `.original`, no sidecar; options round-trip through `JSONEncoder`; `ExportNames.unique(["IMG_0001", "IMG_0001"], .jpeg, false, ["IMG_0001.jpg"])` is `["IMG_0001 2.jpg", "IMG_0001 3.jpg"]`; with `sidecar` and `IMG_0001.xmp` existing, the name is `IMG_0001 2.jpg`; `ExportSidecar.fileName(for: "IMG_0001 2.jpg") == "IMG_0001 2.xmp"`; `FakeExporter` plans the same names as the rule; on `.live` every stubbed catalog method refuses with `LiveExporter.unavailable`. `LibraryExportPlanTests` and `LibraryExportFlowTests` compile, disabled "waits on EX-2" / "waits on EX-3" | a name collides, numbering starts at 1, the sidecar's name is ignored, or an old call site changes meaning | suffix starts at 1 (`n = 1` start); names earlier in the list not reserved (`taken` not updated); sidecar name not checked (`ExportNaming`) |
| EX-2 | `LibraryExportPlanTests`: a 6000 × 4000 photo at long edge 1024 plans 1024 × 683, a 4000 × 6000 one 683 × 1024; at 8192 or Original it stays 6000 × 4000; `render` on a test decoder returns the planned size; a `DevelopRendering` spy receives the photo's settings; a sample photo renders from `SampleImage` with no decode; a decode error passes through as `missingFile` / `notAnImage`; `LiveExporter.unavailable == nil` | it enlarges, ignores the long edge, skips develop, or decodes a sample | long edge ignored; enlarges when the photo is smaller (`fitting` → fixed size); develop skipped (render returns the decoded buffer) (`LiveExporter`) |
| EX-3 | `LibraryExportFlowTests`: in the loupe the targets are the loupe photo, in the grid the selection in `order`; no targets: `beginExport` false and `exportHelp` "Select a photo to export it."; while running "An export is already running." and a second `beginExport` is false; `setExportOptions` outside `.editing` changes nothing; `exportPreview` for `IMG_0001` (6000 × 4000) at the defaults reads "IMG_0001.jpg · 2048 × 1365"; on fakes a plan of three with the middle one failing writes two and the summary lists the third's failure with its id; progress reports 1, 2, 3; export adds no undo step; `closeExport` is refused while running; MX1 | the wrong photos export, a failure stops the run, or a second export starts | loupe ignored in `exportTargets`; a failure stops the run (`continue` → `return`); `beginExport` allowed while running (`LibraryExport`) |
| EX-4 | J7 is `XCTSkip("waits on EX-6")`; `LibraryExportFidelityTests` compile and are disabled "waits on EX-5" | – (checks only) | – |
| EX-5 | `LibraryExportFidelityTests` (macOS, real `ImageIODecoder` and `JPEGWriter`): (a) `LiveExporter.render` of a 4000 × 3000 file with exposure +0.5 at 1024 equals decode → `LiveDevelop.render` → lanczos3 by hand, bit for bit; (b) within QB-V2's tolerance of the loupe's `.full` render at 1024, mean absolute difference ≤ 1/255; (c) written at quality 95 and decoded, PSNR ≥ 40 dB against (a); the file starts `FF D8`, is tagged sRGB; a second write to the same name throws `writeFailed` and the first file's bytes are unchanged | color or pixels drift, the file isn't sRGB, or a file is overwritten | – (macOS; the bytes and pixels are the oracle) |
| EX-6 | `LibraryExportSnapshots` (five states, Light and Dark); J7 steps 1–5 on the macOS run | a state is missing, a slot is enabled before its slice, or a control has no `library.export.*` identifier | – (macOS) |
| EX-7 | `LibraryExportFormatTests`: `usesQuality` is true for JPEG and HEIC only; `forFileName` maps `a.JPG`, `a.jpeg`, `a.tif`, `a.tiff`, `a.png`, `a.heic` and nothing else; `heic.help(writable: [.jpeg, .png, .tiff])` is "This Mac can't write HEIC files."; `png.help(writable: ExportFormat.allCases)` is nil; the plan names `IMG_0001.png` for PNG. Format fidelity and J7F compile, disabled/skipped "waits on EX-8" | a lossless format offers quality, a writable format is refused, or an unwritable one is offered | PNG uses quality; `.tif` not recognized; help nil for an unwritable format (`ExportFormats`) |
| EX-8 | `LibraryExportFormatFidelityTests` (macOS): PNG and TIFF decode back equal to the rendered `DisplayImage` bit for bit; HEIC, when `writableFormats()` lists it, decodes within PSNR 35 dB; magic bytes per format; `writableFormats()` equals the ImageIO list ∩ the four formats; J7F | a format writes the wrong container or loses pixels | – (macOS) |
| EX-9 | `LibraryExportNamingTests`: `{date}-{seq}` on the 3rd of 12 photos captured 2026-06-01 is `2026-06-01-03`; on the 3rd of 9 `2026-06-01-3`; `{rating}` of a 4-star photo is `4`; `a/b:c` gives `a-b-c`; `.hidden` gives `hidden`; `{nope}` gives the help "Unknown token {nope}." and `exportPlan` returns nil; an empty template falls back to the name. Preset tests and J7N compile, disabled/skipped "waits on EX-10" / "waits on EX-11" | a token renders wrong, a name escapes the folder, or an unknown token exports | `{seq}` 0-based; `/` kept; padding ignores the count (`ExportNaming`) |
| EX-10 | `LibraryExportPresetTests`: three built-ins ("For Sharing" 2048/85, "Full Size" Original/95, "Small" 1024/80, all JPEG); adding "Web 1200" twice gives "Web 1200" and "Web 1200 2"; removing a built-in leaves the list unchanged; `applied(to:)` keeps the folder; encode then decode round-trips presets and `last`; `decode(Data("not json".utf8))` gives no user presets and no `last`, never a throw; `unavailable == nil` | a built-in can be removed, two presets share a name, a preset moves the folder, or damaged data crashes | built-in removable; duplicate names kept; folder overwritten by `applied` (`ExportPresets`) |
| EX-11 | J7N on the macOS run, step 4 (relaunch) included | presets or the last settings don't survive a relaunch | – (macOS) |
| EX-12 | `LibraryExportBudgetTests` pass (rows below); `LibraryExportBatchTests`, J7B and P8 compile, disabled/skipped "waits on EX-13" | a budget is over its debug gate | – (checks only) |
| EX-13 | `LibraryExportBatchTests` on fakes: cancelled before the 2nd of 24 gives "Exported 1 of 24. Export was cancelled." and one write; cancelled during a render writes nothing for that photo; `retryExport` after two failures of five plans exactly those two under the given options and `.running(0, 2)`; `cancelExport` is false when not running; J7B; P8 attaches three runs with their marks once #782 has merged | Cancel writes on, a cancelled photo is still written, or Try Again re-exports everything | cancel check before each photo dropped; the check between render and write dropped; retry plans every id (`LibraryExport`) |
| EX-14 | `LibraryExportPlanTests`: a 6000 × 4000 photo with a 1:1 crop at 0° plans 1024 × 1024 at long edge 1024; `LibraryExportFidelityTests` (a) and (b) on a photo cropped 3:2 and straightened 2° | the plan or the pixels ignore the crop | plan ignores the crop (`photo.develop.crop` read as nil); cropped size takes the photo's aspect (`LiveExporter`) |
| EX-15 | `LibraryExportSidecarTests` and J7S compile, disabled/skipped "waits on EX-16" | – (checks only) | – |
| EX-16 | `LibraryExportSidecarTests`: a 3-star picked Red photo with exposure 0.5 gives exactly the expected packet (fixed attribute order); a name with `&` and `"` is escaped; a rejected photo has `xmp:Rating="-1"`; a photo with no crop has no `library:Crop`; the runner writes `IMG_0001.xmp` beside `IMG_0001.jpg` with `sidecar` on and nothing with it off; J7S | a value is lost or unescaped, or a sidecar is written when off | `&` not escaped; reject written as 0; crop dropped (`ExportSidecar`) |
| EX-17 | `git grep -n 'testExportFailsAndCancels' docs/blueprints/library.md` finds the J7B row; 1.4's export row names formats, presets and sidecars as built | the blueprint still names one J7 | – (prose) |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-L9 model half | `beginExport` on `large` (10,000) ≤ 10 ms (1 ms release) | `LibraryExportBudgetTests.beginExportWithinBudget` (EX-12) |
| QB-LIB-7 model half | `LiveExporter.plan` for 1,000 photos ≤ 50 ms (5 ms release), with a name template and sidecars on | `LibraryExportBudgetTests.planWithinBudget` (EX-12) |
| QB-L9, QB-LIB-7 probe | `progress` mark ≤ 100 ms after Export; 10 × 6000 × 4000 at 2048 ≤ 15 s; report-only | P8 (EX-13) |
| QB-V4 | exact, WYSIWYG within QB-V2's tolerance, PSNR ≥ 40 dB after JPEG | `LibraryExportFidelityTests` (EX-5, EX-14) |
| QB-F1 no dead controls | every slot disabled with its reason until its slice lands | `library-export` snapshot; J7 step 5 |
| QB-F2 progress and errors in place | the sheet's progress row, summary and failure list; never an alert | J7 step 2, J7B |
| QB-F4 keyboard | ⇧⌘E opens, Return exports, Escape cancels or closes | J7 step 1 (keys), J7B step 2 |
| QB-V5 | the five export snapshots, Light and Dark | `LibraryExportSnapshots` (EX-6) |

Export is not an undo step (it changes no catalog value), so QB-F3 has no
row here; EX-3's test checks no step is recorded.

## Done check

Per slice (contract rule 6): its tasks merged; its journeys green on a
Library-scoped run that contains its last PR (EX-a: MX1 among the Model
tests); every app built; no open `finding` issue for it; every mutation of
its plans caught (a full `Mutate:` line on each PR that changed planned
code). The lead comments `Belt-Slice-Done: <slice> <run url>` per slice.
Slice EX-e holds P8, which needs #782; if #782 is still open when EX-13
merges, P8 stays skipped "waits on #782" and EX-e is done with gaps
(`gaps: #782`). When all six are done (EX-17 is in EX-f): audit zero new on
the `library` row of `UITests/audit-baseline.json` (every sheet control has
a `library.export.*` identifier and a name), and `Belt-Contact-Sheet: <run
url>` on the feature issue with J7, J7F, J7N, J7B and J7S's shots and P8's
numbers.

## Open questions for the captain

1. **WebP.** ImageIO doesn't write it and creative-core has no encoder. A
   lossless-only WebP encoder in CoreRaster is the clean-room path (no new
   dependency) but is real engine work; recommended: leave WebP out and
   offer AVIF instead, which ImageIO writes today. Not filed.
2. **16-bit TIFF and PNG.** `DisplayImage` is 8-bit; 16-bit output needs a
   wider contract value and a CoreRaster `rgba16(colorSpace:)`. Recommended:
   later, filed as a `needs-core` issue only when someone asks.
3. **Which sidecar.** This packet reads "sidecar settings" as one XMP file
   per exported image (rating, label, pick, develop settings). The other
   reading, one settings file per export folder that the next export into it
   picks up, is cheap to add to EX-d's store instead. Recommended: XMP per
   image (it follows a published standard and other apps read the rating).
4. **`{date}` time zone.** Capture dates are stored as instants; this packet
   formats them in UTC so Linux and macOS agree. Local time would match what
   the photographer saw on the camera but needs the zone the import read.
5. **Scope.** Slices EX-c, EX-d and EX-f go past blueprint 1.4's v1 line.
   They run in parallel after EX-b and never block #424 (closed by EX-13);
   say if any should wait for after v1.
