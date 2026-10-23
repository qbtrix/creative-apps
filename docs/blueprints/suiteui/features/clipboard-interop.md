# Feature packet: clipboard-interop

**Feature:** copy out of any app and paste into any app or the system. On
Copy, Design, Flare and Halo also write PNG (and SVG when the selection is
vector) beside their own layer type, so ⌘V in a chat, a document or a slide
pastes a picture; Library's Copy writes the photo as PNG and as a file URL.
Pasting a plain image (PNG, TIFF, JPEG, HEIC) or an SVG into Design, Flare or
Halo makes a placed image through the kernel's place commands
(`suiteui/placed-images`). Photo already writes PNG and TIFF and reads any
image (`PhotoPasteboard.swift`); its writer is the one lifted, so its
metadata stripping (RJ-X05) becomes everyone's. One live `PasteboardCoding`
replaces SuiteModel's fake (`pasteboardIsLive = false` today) and one
SuiteShell bridge replaces Design's, Flare's and Photo's own writers and the
two 4 Hz change-count polls. Editable vector paste between apps (E11, RJ-X14)
stays V1.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps on the kernel track) · **Lead branch:** `lead/clipboard-interop`
**Beta:** captain, 2026-10-21 (beta gaps C2). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C2, with the evidence in `2026-10-21-gaps-suite.md` row 8 and finding 5 and
`2026-10-21-gaps-design.md` rows 5 and 6; feature map row
`suiteui/clipboard-interop` (new); real jobs RJ-X72 and RJ-X73 (new); RJ-D10
now closes with it.

**Depends on:** editor-kernel, command-catalog, adopt-command-catalog (built).
**Waits:** placed-images PL-m (paste as a placed image); shared-codecs
SC-photo, which edits `PhotoPasteboard.swift` first; area-selection AR-z for
the baseline chain (CB-z).

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **CB-design:** design/placed-images PD-m builds Design's place path; the
  Design catalog chain's tail is design/pen-paths DP-m.
- **CB-flare:** flare/svg-place PF-m builds Flare's place path; the Flare
  catalog tail is flare/pen-paths FP-m.
- **CB-halo:** halo/placed-images PH-m; the Halo catalog tail is
  halo/file-flow HF-m.
- **CB-library:** #3160 restores Edit > Copy in Library's menu; this slice
  fills it. The Library catalog tail is library/file-flow LF-m.
- **CB-photo:** photo/file-flow PF-m for the catalog.

**Rule 20.** The pasteboard is a suite concept (`Pasteboard` in
`Tests/canonical-concepts.txt`). `DesignPasteboardBridge.swift`,
`FlarePasteboard.swift` and `PhotoPasteboard.swift` are three transports for
one job. Each app keeps only an adapter that makes and reads its own bytes
(`DesignPasteboardAdapter.swift`, `FlarePasteboardAdapter.swift`,
`PhotoPasteboardAdapter.swift`, `HaloPasteboardAdapter.swift`,
`LibraryPasteboardAdapter.swift`); the bridge carries them.

**Deleted app-local files:** `Sources/DesignApp/DesignPasteboardBridge.swift`,
`Sources/FlareApp/FlarePasteboard.swift` (with `FlarePasteboardWatch`) and
`Sources/PhotoApp/PhotoPasteboard.swift`, in CB-z with
`scripts/check-dup-logic --update-baseline`: `Tests/canonical-baseline.txt`
shrinks by 3 lines.

**AI-accessible first.** Copy and Paste are the existing `edit.copy` and
`edit.paste` commands; this packet adds `edit.copy-as` (`{format: png | svg |
own}`), `edit.paste-as-image` and Halo's `edit.copy-frame`, each with an Edit
menu item. The CLI reads and writes a pasteboard file in place of the system
one (`--pasteboard <dir>`), so the jobs run on Linux.

**C4:** CB-4 fills the shell part `shell-pasteboard.json`
(`PasteboardBridge.swift`) and CB-3 the model part `suite-pasteboard.json`
(`Sources/SuiteModel/Pasteboard/`), both already planned.

**Clean-room.** Behaviour from the apps' own tests (Photo's pasteboard
journeys) and Apple's documented pasteboard types.

Blueprint sections: suite.md 5.2 (UC-7 typed pasteboard); each app's Edit menu.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CB-a | SuiteClipItem gains the app's own layer bytes, the live coder and the shell bridge are declared as stubs, and their tests are written and disabled. | CB-1, CB-2 | MJ-CB | editor-kernel, command-catalog (built, `depends`) |
| CB-m | The coder orders representations richest first (own type, SVG, PNG, TIFF, text), picks the best item a target app can take and says why Paste is off, and the CLI's pasteboard folder round-trips every item. | CB-3, CB-4 | MJ-CB | CB-a |
| CB-s | One SuiteShell bridge writes and reads the coder's items on the system pasteboard with no source metadata and no polling timer. | CB-4b, CB-4c | MJ-CB | CB-a |
| CB-u | SuiteUI has one Copy As submenu (PNG, SVG, the app's own type) and Paste as Image built from the catalog's specs, each item off with the coder's reason as its help, reachable from the gallery's menus page on the fakes. | CB-u1, CB-u2 | SJ-CB | CB-a |
| CB-design | Design's Copy writes its layers, a PNG of the selection at 2x and an SVG beside them, and Paste of a plain image or SVG places it as a picture at the view's centre. | CB-5, CB-6 | DJ-CB | CB-a (CB-5); CB-m, CB-s, CB-u and placed-images:PL-m (CB-6); design/placed-images PD-m and design/pen-paths DP-m (cross-line); shared files, after adopt-kernel-unsaved-prompt:UP-design (CB-6), area-selection:AR-design (CB-6) |
| CB-flare | Flare's Copy writes its layers, a PNG of the selection at the playhead and an SVG frame beside them, Paste of an image or SVG places it, and its 4 Hz pasteboard poll is gone. | CB-7, CB-8 | FJ-CB | CB-a (CB-7); CB-m, CB-s, CB-u and placed-images:PL-m (CB-8); flare/svg-place PF-m and flare/pen-paths FP-m (cross-line); shared files, after frame-rates:FR-flare (CB-8) |
| CB-halo | Halo's Edit > Copy Frame writes the viewer's frame as PNG, and Paste of an image or SVG adds a placed image layer at the playhead. | CB-9, CB-10 | HJ-CB | CB-a (CB-9); CB-m, CB-s, CB-u and placed-images:PL-m (CB-10); halo/placed-images PH-m and halo/file-flow HF-m (cross-line); shared files, after frame-rates:FR-halo (CB-10) |
| CB-library | Library's Copy writes the selected photo as a full-size PNG with its develop settings applied and as a file URL, with no location data. | CB-11, CB-12 | LJ-CB | CB-a (CB-11); CB-m, CB-s (CB-12); #3160 and library/file-flow LF-m (cross-line); shared files, after shared-thumbnails:ST-m (CB-12) |
| CB-photo | Photo's Copy and Paste run through the shared bridge with the same bytes it writes today, and Paste of an SVG places it rasterized at the canvas centre. | CB-13, CB-14 | PJ-CB | CB-m, CB-s, CB-u; shared-codecs:SC-photo (`PhotoPasteboard.swift`); photo/file-flow PF-m (cross-line); shared files, after area-selection:AR-photo-m (CB-14) |
| CB-z | Design's, Flare's and Photo's own pasteboard files are deleted with the baseline shrunk by three lines, RJ-X72 and RJ-X73 pass, and the feature is built. | CB-15, CB-16 | MJ-CB, DJ-CB, FJ-CB, PJ-CB | every adopt slice; area-selection:AR-z (CB-15, `canonical-baseline.txt`) |

**Slice size.** Each slice is one PR of 150 to 400 lines with its test commit first (lead.md rule 22). CB-z is smaller than that; the lead folds it into whichever adopt slice merges last, as rule 22 says for a same-feature change under 50 lines.

## Journey steps

Linux walks, then the apps' journeys on the scoped run after each slice's last PR:
- `MJ-CB`: `SuitePasteboardCodingTests` and `PasteboardFolderTests` on Linux; `PasteboardBridgeTests` on the macOS job.
- `SJ-CB` (`SuiteClipboardJourneyTests.testCopyAsMenuInGallery`, CB-u2): open the gallery's Menus page, open Edit > Copy As; three items; put text on the fake pasteboard; Paste as Image is off and says why.
- `DJ-CB` (`DesignEditJourneyTests.testCopyOutPasteImageIn`, CB-6): copy a red rectangle, read the general pasteboard's types (own, SVG, PNG); write a PNG to it, Edit > Paste; a picture layer appears centred.
- `FJ-CB` (`FlareEditJourneys.testCopyOutPasteImageIn`, CB-8): the same at frame 12, then paste an SVG logo; its layers appear.
- `HJ-CB` (`HaloEditJourneyTests.testCopyFramePasteImage`, CB-10): Edit > Copy Frame; the pasteboard holds a 1920×1080 PNG; paste a PNG; a layer starts at the playhead.
- `LJ-CB` (`LibraryJourneyTests.testCopyPhotoOut`, CB-12): select a photo, Edit > Copy; the pasteboard holds a PNG and a file URL.
- `PJ-CB` (`PhotoEditJourneyTests.testPasteFromAnotherApp`, existing): green unchanged after CB-13.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X72 | adds, closes with `suiteui/clipboard-interop` | Cm | `Tests/RealJobs/suite/copy-design-paste-photo/copy-design-paste-photo.jobs.json`: in Design, make a 200×100 red rectangle and `edit.copy`; in Photo, `edit.paste` into a new 800×600 image; export PNG | none (built by commands) |
| RJ-X73 | adds, closes with `suiteui/clipboard-interop` | C | `Tests/RealJobs/suite/paste-screenshot/paste-screenshot.jobs.json`: with `screenshot.png` on the CLI's pasteboard folder, `edit.paste` in Design, Flare and Halo; save each | `input/screenshot.png` |
| RJ-D10 | closes with `suiteui/clipboard-interop` (was A1) | C | `edit.copy-as {format: svg}` on a rounded rectangle; the folder's SVG parses and has one `rect` with `rx` | – |

RJ-X72. Trap: Photo's Paste is greyed because Design wrote only its own type.
Assertion: Photo gains one layer of 400×200 px (2x) whose centre pixel is
pure red. Mutations: `SuiteModel.SuitePasteboardCoding` `.photoTakesPixels`,
`DesignModel.DesignPasteboardAdapter` `.pngAtTwoX`. `Cm`: it crosses
NSPasteboard. Written by CB-5, disabled (`waits_on: CB-6`).

RJ-X73. Trap: the paste is refused, or lands at the top-left corner, or at
time 0 in Halo. Assertion: each file has one new placed-image layer at the
pasted pixel size, centred in the canvas (Halo: in point at the playhead).
Mutations: `.pasteCentres`, `.pasteAtPlayhead`. Written by CB-9, disabled
(`waits_on: CB-10`); it also needs CB-6 and CB-8, which its `needs` names
through this row.

## Screens and states

- `suite-gallery-copy-as-{light,dark}.png` (CB-u1): the submenu open, Paste as Image off with its help.
- `design-edit-menu-copy-as-{light,dark}.png` (CB-6): Edit > Copy As with PNG, SVG and Design Layers.
- `halo-edit-menu-{light,dark}.png` (CB-10): Copy Frame and Paste enabled.
- No other new screens: the canvases gain a placed image, already shot by the placed-images packets.

## Contract slice

```swift
// Sources/SuiteModel/Values/Clip.swift (CB-1): one new case.
public enum SuiteClipItem { /* existing cases */ case appLayers(SuiteTypeID, Data) }
// Sources/SuiteModel/Pasteboard/SuitePasteboardCoding.swift (CB-1 stub, CB-3 body). Linux-safe.
public struct SuitePasteboardCoding: PasteboardCoding {
    public init()
    /// Richest first: own layers, then SVG (vector items), then PNG, then TIFF (images), then text.
    public func representations(of item: SuiteClipItem) -> [TypedData]
    public func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem?
    public func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError?
}
// Sources/SuiteModel/Pasteboard/PasteboardFolder.swift (CB-1 stub, CB-3 body): the CLI's pasteboard, one file per type.
public struct PasteboardFolder: Sendable { public init(_ url: URL); public func write(_ items: [TypedData]) throws; public func read() throws -> [TypedData] }
// Sources/SuiteShell/PasteboardBridge.swift (CB-1 stub, CB-4 body). macOS.
@MainActor public struct PasteboardBridge {
    public init(_ pasteboard: NSPasteboard = .general)
    public func write(_ items: [TypedData])            // one clearContents, one write
    public func offered() -> [TypedData]               // what is there now, read lazily per type
    public var changeCount: Int { get }                // read on menu open and window key, never on a timer
}
// Sources/SuiteKernel/Commands/CopyAsCommands.swift (CB-1).
public enum CopyAsCommands { public static let specs: [CommandSpec] }   // edit.copy-as {format}, edit.paste-as-image, edit.copy-frame
```

## Pseudocode

- **Copy:** the app's adapter returns a `SuiteClipItem.appLayers` plus a
  vector or image item for the same selection; the coder lists their
  `TypedData` richest first; the bridge writes them in one item.
- **Paste:** the bridge reads the offered types; the coder's `bestItem` for
  this app picks own layers first, then SVG (Design, Flare, Halo place it as
  vectors where the place path supports it, else as a picture), then any
  image; the adapter runs the kernel's `place.image` with the decoded bytes at
  the view's centre (Halo: at the playhead). Refusal names what is there
  ("The pasteboard holds text; Paste takes layers or images").
- **PNG scale:** Design 2x of the selection's bounds; Flare 1x of the scene at
  the playhead, cropped to the selection; Halo the full frame.
- **No polling:** the Edit menu's Paste reason re-reads the change count on
  `menuNeedsUpdate` and on window key; idle CPU stays at zero.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CB-1 | – | **Contract as stubs.** `SuiteClipItem.appLayers(SuiteTypeID, Data)`; `SuitePasteboardCoding` (representations, best item, refusal) returning the fake's answers; `PasteboardBridge` (write items, read offered, change count) behind `#if canImport(AppKit)` and a file-backed `PasteboardFolder` for the CLI; `CopyAsCommands` specs (`edit.copy-as`, `edit.paste-as-image`, `edit.copy-frame`) | `Sources/SuiteModel/Values/Clip.swift`, `Sources/SuiteModel/Pasteboard/SuitePasteboardCoding.swift`, `Sources/SuiteModel/Pasteboard/PasteboardFolder.swift`, `Sources/SuiteShell/PasteboardBridge.swift`, `Sources/SuiteKernel/Commands/CopyAsCommands.swift` | – | ~230, 5 |
| CB-2 | – | `SuitePasteboardCodingTests` and `PasteboardFolderTests` written, disabled by name (`waits on CB-3`) | `Tests/SuiteModelTests/SuitePasteboardCodingTests.swift`, `Tests/SuiteModelTests/PasteboardFolderTests.swift` | CB-1 | ~170, 2 |
| CB-3 | – | Coder bodies: the order, the best item per app, the refusal sentence; turns on `SuitePasteboardCodingTests` | `Sources/SuiteModel/Pasteboard/SuitePasteboardCoding.swift`, `Tests/SuiteModelTests/SuitePasteboardCodingTests.swift`, `Tests/mutations/SuiteModel.SuitePasteboardCoding.json`, `docs/c4/parts/creative-apps/suite-model/suite-pasteboard.json` | CB-1, CB-2 | ~190, 4 |
| CB-4 | – | `PasteboardFolder` body (one file per type, the CLI's `--pasteboard <dir>`); the live slot (`pasteboardIsLive = true`); turns on `PasteboardFolderTests` | `Sources/SuiteModel/Pasteboard/PasteboardFolder.swift`, `Sources/SuiteShell/Live/PasteboardSlot.swift`, `Tests/SuiteModelTests/PasteboardFolderTests.swift`, `Tests/mutations/SuiteModel.PasteboardFolder.json` | CB-1, CB-2 | ~120, 4 |
| CB-4b | – | `PasteboardBridgeTests` (macOS, a private named pasteboard), disabled (`waits on CB-4c`) | `Tests/SuiteUITests/PasteboardBridgeTests.swift` | CB-1, CB-2 | ~110, 1 |
| CB-4c | – | `PasteboardBridge` body, lifted from `PhotoPasteboard`'s writer: PNG plus TIFF re-encoded with no source metadata, SVG as `public.svg-image`, own types as data, a file URL; the change count read when the Edit menu opens or the window becomes key (no timer); turns on `PasteboardBridgeTests` | `Sources/SuiteShell/PasteboardBridge.swift`, `Tests/SuiteUITests/PasteboardBridgeTests.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-pasteboard.json` | CB-4b, CB-1, CB-2 | ~170, 3 |
| CB-u1 | – | **Reachable first:** the gallery's Menus page gains Edit > Copy As and Paste as Image over `FakePasteboard`; `CopyAsMenu` builds the items from `CopyAsCommands` through `MenuCommand+Catalog`; `CopyAsMenuTests` first | `Sources/SuiteUI/CopyAsMenu.swift`, `Sources/SuiteUI/Gallery/GalleryMenus.swift`, `Tests/SuiteUITests/CopyAsMenuTests.swift` | CB-1, CB-2 | ~200, 3 |
| CB-u2 | – | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+Clipboard.swift`, `Tests/AppSnapshotTests/RenderBudgetCopyAsMenuTests.swift` | CB-u1 | ~100, 2 |
| CB-5 | – | **Design, test first.** `DesignPasteboardAdapterTests`, disabled; the journey, skipped; RJ-X72's job folder, disabled | `Tests/DesignModelTests/DesignPasteboardAdapterTests.swift`, `UITests/DesignJourneyTests+Edit.swift`, `Tests/RealJobs/suite/copy-design-paste-photo/copy-design-paste-photo.jobs.json` | CB-1, CB-2 | ~170, 3 |
| CB-6 | – | `DesignPasteboardAdapter.swift` (own bytes, `DesignRasterizer` PNG, `DesignSVG` SVG; paste image to `place.image`); the canvas and Layers hooks call the bridge; `edit.copy-as` and `edit.paste-as-image` in the catalog with Edit menu items; turns on both | `Sources/DesignModel/DesignPasteboardAdapter.swift`, `Sources/DesignApp/DesignEditMenu.swift`, `Sources/DesignApp/DesignWindow.swift`, `Tests/DesignModelTests/DesignPasteboardAdapterTests.swift`, `UITests/DesignJourneyTests+Edit.swift`, `Tests/mutations/DesignModel.DesignPasteboardAdapter.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/AfterGlowCLITests/Golden/apps/design.list-commands.json` | CB-5, CB-3, CB-4, CB-4b, CB-4c, CB-u1, CB-u2 | ~230, 9 |
| CB-7 | – | **Flare, test first.** `FlarePasteboardAdapterTests`, disabled; the journey, skipped | `Tests/FlareModelTests/FlarePasteboardAdapterTests.swift`, `UITests/FlareJourneyTests+Edit.swift` | CB-1, CB-2 | ~150, 2 |
| CB-8 | – | `FlarePasteboardAdapter.swift` (own bytes, `StageRasterizer` PNG at the playhead, the SVG frame writer; paste to `place.image` or svg-place's `place.svg`); Edit menu and the stage context menu call the bridge; `FlarePasteboardWatch`'s timer no longer runs; catalog specs; turns on both | `Sources/FlareModel/FlarePasteboardAdapter.swift`, `Sources/FlareApp/FlareWindow+Edit.swift`, `Sources/FlareApp/FlareStageContextMenu.swift`, `Tests/FlareModelTests/FlarePasteboardAdapterTests.swift`, `UITests/FlareJourneyTests+Edit.swift`, `Tests/mutations/FlareModel.FlarePasteboardAdapter.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | CB-7, CB-3, CB-4, CB-4b, CB-4c, CB-u1, CB-u2 | ~230, 9 |
| CB-9 | – | **Halo, test first.** `HaloPasteboardAdapterTests`, disabled; RJ-X73's job folder, disabled; the journey, skipped | `Tests/HaloModelTests/HaloPasteboardAdapterTests.swift`, `UITests/HaloJourneyTests+Edit.swift`, `Tests/RealJobs/suite/paste-screenshot/paste-screenshot.jobs.json`, `Tests/RealJobs/suite/paste-screenshot/input/screenshot.png` | CB-1, CB-2 | ~170, 4 |
| CB-10 | – | `HaloPasteboardAdapter.swift` (the frame through `HaloFramePNG`; paste to halo/placed-images' layer at the playhead); `edit.copy-frame` and `edit.paste` in Halo's catalog and `HaloEditMenu`; turns on both | `Sources/HaloModel/HaloPasteboardAdapter.swift`, `Sources/HaloApp/HaloEditMenu.swift`, `Sources/HaloApp/HaloWindow+Edit.swift`, `Tests/HaloModelTests/HaloPasteboardAdapterTests.swift`, `UITests/HaloJourneyTests+Edit.swift`, `Tests/mutations/HaloModel.HaloPasteboardAdapter.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/AfterGlowCLITests/Golden/apps/halo.list-commands.json` | CB-9, CB-3, CB-4, CB-4b, CB-4c, CB-u1, CB-u2 | ~220, 9 |
| CB-11 | – | **Library, test first.** `LibraryPasteboardAdapterTests`, disabled; the journey, skipped | `Tests/LibraryModelTests/LibraryPasteboardAdapterTests.swift`, `UITests/LibraryJourneyTests+Copy.swift` | CB-1, CB-2 | ~140, 2 |
| CB-12 | – | `LibraryPasteboardAdapter.swift` (the rendered photo through export's pipeline, metadata stripped as in a clean export; the file URL); `edit.copy` in Library's catalog and menu; turns on both | `Sources/LibraryModel/LibraryPasteboardAdapter.swift`, `Sources/LibraryApp/LibraryCommands.swift`, `Tests/LibraryModelTests/LibraryPasteboardAdapterTests.swift`, `UITests/LibraryJourneyTests+Copy.swift`, `Tests/mutations/LibraryModel.LibraryPasteboardAdapter.json`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/AfterGlowCLITests/Golden/apps/library.list-commands.json` | CB-11, CB-3, CB-4, CB-4b, CB-4c | ~220, 8 |
| CB-13 | – | **Photo, oracle first.** `PhotoPasteboardAdapterTests` from today's `PhotoPasteboard` behaviour (PNG and TIFF out, any image in, RJ-X05's no-metadata), then `PhotoPasteboardAdapter.swift` routes Copy and Paste through the bridge; SVG paste rasterizes at the canvas size | `Sources/PhotoModel/PhotoPasteboardAdapter.swift`, `Sources/PhotoApp/PhotoWindow+Edit.swift`, `Tests/PhotoModelTests/PhotoPasteboardAdapterTests.swift`, `Tests/mutations/PhotoModel.PhotoPasteboardAdapter.json` | CB-3, CB-4, CB-4b, CB-4c | ~240, 4 |
| CB-14 | – | `edit.paste-as-image` in Photo's catalog and Edit menu (paste a vector as pixels by name) | `Sources/PhotoApp/PhotoCommands+Edit.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/AfterGlowCLITests/Golden/apps/photo.list-commands.json` | CB-13, CB-u1, CB-u2 | ~80, 4 |
| CB-15 | – | **Delete the transports.** Removes `DesignPasteboardBridge.swift`, `FlarePasteboard.swift` (and its watch) and `PhotoPasteboard.swift`; `scripts/check-dup-logic --update-baseline` drops their 3 lines | `Sources/DesignApp/DesignPasteboardBridge.swift`, `Sources/FlareApp/FlarePasteboard.swift`, `Sources/PhotoApp/PhotoPasteboard.swift`, `Tests/canonical-baseline.txt` | CB-5, CB-6, CB-7, CB-8, CB-13, CB-14 | ~200, 4 |
| CB-16 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/clipboard-interop.wave.json` | CB-15, CB-9, CB-10, CB-11, CB-12 | ~10, 1 |

## Build waves

- Wave 1: CB-1. Independent in this wave: CB-1 alone.
- Wave 2: CB-2. Independent in this wave: CB-2 alone.
- Wave 3: CB-3, CB-4, CB-4b, CB-u1, CB-5, CB-7, CB-9, CB-11. Independent in this wave: all.
- Wave 4: CB-4c, CB-u2. Independent in this wave: both.
- Wave 5: CB-6, CB-8, CB-10, CB-12, CB-13. Independent in this wave: all.
- Wave 6: CB-14. Independent in this wave: CB-14 alone.
- Wave 7: CB-15. Independent in this wave: CB-15 alone.
- Wave 8: CB-16. Independent in this wave: CB-16 alone.

Longest chain: CB-1 → CB-2 → CB-4b → CB-4c → CB-13 → CB-14 → CB-15 → CB-16 (8). Chain of 8: each link is a slice waiting on the slice whose types or files it needs (the stubs before the bodies, the bodies before an app's adapter, the adapter before its screen, the delete and the status last); only the named tasks wait, so the other slices run beside it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| CB-1 | SuiteModel builds on Linux; `CommandShapeTests` passes with the new specs | a spec has no schema or the coder doesn't conform | – (stubs) |
| CB-2 | compile, disabled | a signature the adapters call is missing | – (tests only) |
| CB-3 | `SuitePasteboardCodingTests`: a Design copy offered to Photo picks PNG; to Design picks its own layers; SVG offered to Flare picks `.vector`; text alone refuses Paste with a sentence; `PasteboardFolderTests` round-trips each item | an app is offered its second-best item or Paste is on for text | `SuiteModel.SuitePasteboardCoding`: own type ranked below PNG → `.ownTypeFirst`; SVG accepted by Photo → `.photoTakesPixels`; refusal nil for text → `.textRefused` |
| CB-4 | `PasteboardFolderTests`: each item kind round-trips; an unknown file is ignored; the slot reports live | a type is lost on the round trip | `SuiteModel.PasteboardFolder`: write appends instead of replacing → `.writeReplaces`; a type read from the extension only → `.typeFromManifest` |
| CB-4b | compiles, disabled | – | – (tests only) |
| CB-4c | `PasteboardBridgeTests`: a written PNG reads back as the same bytes and carries no GPS or MakerNote; two writes in a row bump the change count; nothing polls (no `Timer` in SuiteShell) | metadata leaks or a timer polls | – (macOS; covered by RJ-X05 and the bridge tests) |
| CB-u1 | `CopyAsMenuTests`: three Copy As items in order, each with its command id; with text on the fake pasteboard Paste as Image is off and its help is the coder's sentence | an item is bare or on when it can't act | – (SuiteUI view) |
| CB-u2 | `SuiteClipboardJourneyTests.testCopyAsMenuInGallery`; `RenderBudgetCopyAsMenuTests.openMenuInOneBody` | – | – |
| CB-5 | compiles, disabled; `scripts/jobs check` | – | – (tests only) |
| CB-6 | `DesignPasteboardAdapterTests`: copy of a red rectangle offers own, SVG and a 2x PNG of its bounds; paste of a 300×200 PNG adds one placed-image layer at 300×200 pt centred in the view; `DesignEditJourneyTests.testCopyOutPasteImageIn` | the PNG is the whole page or paste refuses a PNG | `DesignModel.DesignPasteboardAdapter`: PNG drawn at 1x → `.pngAtTwoX`; pasted image not centred → `.pasteCentres` |
| CB-7 | compiles, disabled | – | – (tests only) |
| CB-8 | `FlarePasteboardAdapterTests`: copy at frame 12 offers own, SVG and PNG of frame 12; paste SVG adds svg-place's layers; `FlareEditJourneys.testCopyOutPasteImageIn` | the PNG is frame 0 or the poll still runs | `FlareModel.FlarePasteboardAdapter`: the PNG drawn at frame 0 → `.pngAtPlayhead`; SVG pasted as a bitmap → `.svgPlacesVectors` |
| CB-9 | compiles, disabled; `scripts/jobs check` | – | – (tests only) |
| CB-10 | `HaloPasteboardAdapterTests`: Copy Frame at frame 30 writes the composition's size; paste adds one layer whose in point is the playhead; `HaloEditJourneyTests.testCopyFramePasteImage` | the frame is the wrong size or the layer starts at 0 | `HaloModel.HaloPasteboardAdapter`: the in point set to 0 → `.pasteAtPlayhead`; the frame drawn at half size → `.frameFullSize` |
| CB-11 | compiles, disabled | – | – (tests only) |
| CB-12 | `LibraryPasteboardAdapterTests`: a photo with exposure +1 copies as the developed pixels, no GPS; `LibraryJourneyTests.testCopyPhotoOut` | the copy is the undeveloped original or carries GPS | `LibraryModel.LibraryPasteboardAdapter`: develop skipped → `.copiesDeveloped`; GPS kept → `.stripsLocation` |
| CB-13 | `PhotoPasteboardAdapterTests`; `PhotoEditJourneyTests.testPasteFromAnotherApp` unchanged; RJ-P35 and RJ-X05 green | Photo's copy changes bytes or gains metadata | `PhotoModel.PhotoPasteboardAdapter`: TIFF dropped → `.writesPngAndTiff`; SVG pasted at its own size → `.svgFitsCanvas` |
| CB-14 | `CommandPathTests`; the CLI golden lists it | the item is bare | – (catalog) |
| CB-15 | every app builds; `scripts/check-dup-logic` (baseline shrank by 3); the five journeys | a deleted transport is still called | – (deletion) |
| CB-16 | `scripts/waves check`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Design copy of 50 layers | ≤ 2 window bodies; PNG encode off the main actor; p95 ≤ 120 ms | `RenderBudgetDesignTests.copyFiftyLayers` |
| render: Flare paste of an SVG logo | ≤ 3 window bodies | `RenderBudgetFlareTests.pasteSvg` |
| render: Halo paste into a 10-layer comp | ≤ 3 window bodies | `RenderBudgetHaloTests.pasteImage` |
| render: Library copy of a 24 MP photo | ≤ 2 window bodies; the render runs detached | `RenderBudgetLibraryTests.copyPhoto` |
| idle | no pasteboard timer in any app; idle CPU under 10% after a copy | `PasteboardBridgeTests.noTimer`; the stress gate |
| privacy | no GPS, serial or MakerNote on any copy | RJ-X05 (existing) and `PasteboardBridgeTests` |
| one gesture, one step | a paste is one undo step | each adapter's tests |
| no dead controls | every new Edit item has a command | `CommandPathTests` |
| render: opening Copy As in the gallery | ≤ 1 window body | `RenderBudgetCopyAsMenuTests.openMenuInOneBody` |
| render: copy and paste once the transports go (CB-z) | the adopt rows above, unchanged | `RenderBudgetDesignTests.copyFiftyLayers`, `RenderBudgetFlareTests.pasteSvg` |

## Done check

Per slice (rules 6, 15, 17, 21): CB-a and CB-m green on Linux (CB-4 on the
macOS job) with clean `Mutate:` scores; each adopt slice through the feel
gate (`mouse`, `taste`, `job`: copy from one app and paste into Messages and
into another suite app) with its `Mac-Finish:` line; CB-z with the baseline
shrunk, RJ-X73 green on Linux and RJ-X72 on the macOS run. Then
`Belt-Contact-Sheet:`.
