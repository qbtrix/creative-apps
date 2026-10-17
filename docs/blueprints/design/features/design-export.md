# Feature packet: design-export

**Feature:** File > Export… ⇧⌘E writes what a designer made as PNG (1x, 2x,
3x), SVG or PDF: the selected layers, the frame around the selection (every
top-level frame with nothing selected) or the whole page, one file each, into
a folder the person picks, never writing over a file that is already there
("Card.png", then "Card 2.png"). The sheet is SuiteUI's `ExportSheet`, the
run is SuiteKernel's `ExportRun`, and the Design half is only the plan (which
layers, which names, which sizes), the SVG text and the raster drawn from the
canvas's own artwork. (Blueprint F6, #418.) Most-used first: PNG of a frame
at 1x and 2x on nearly every hand-off, SVG of a frame often, a selection or
the page now and then, PDF and 3x rarely.
**Line:** `line:design` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/design-export`
**Beta:** in the captain's approved beta cut
(`paw-workspace/docs/design/drafts/2026-10-17-afterglow-beta-cut.md`, §2
Design: "design-export (PNG, SVG; #418): not filed"; §5 the Design tier-1
chain ends "… → save → export").

**Covers:** #418 (Design: export PNG, SVG, PDF; closes with DE-11). The
blueprint planned export as wave 3 behind `design-seams-2`; the beta cut
moves it in and parks design-seams-2 (→ `p3`), so this packet takes over
design-seams-2's export half (D2-2's live and fake export slots, D2-3a's
export actions, D2-4b's Export… item and sheet placeholder) and
design-seams-2 keeps the pen, components and variables halves.

**Depends on:** the design-contracts feature issue (`ExportPlanning`,
`DesignExportFormat`, `DesignExportItem`, `.nothingToExport`, the
`export:` slot in `DesignServices` and `NotBuilt`'s conformance, all on `dev`):
DE-1 starts then. Within the feature DE-u (the screen) and DE-s, DE-w (the
logic) wait only on DE-a, the contract, so the sheet is on screen on the
fakes while the SVG text and the rasterizer are built (`lead.md` rule 18);
DE-z integrates on live.

- **editor-kernel (SuiteUI line, cross-line, so in prose and not in
  `waits`):** DE-2 imports `SuiteKernel` for `ExportRun<Options>` and waits on
  its contract slice **EK-a** (the stubs; `Belt-Slice-Done: EK-a`). DE-6
  hosts SuiteUI's `ExportSheet` and waits on **EK-chrome** (EK-30). DE-10
  runs the journeys on the real run and waits on **EK-run** (EK-22). Nothing
  here waits on any other kernel slice.
- **The window's shared files** pass to DE-6 from their wave-1 owners, in
  the order `waves.md` gives: `DesignIntent.swift` and `DesignCommands.swift`
  from snapping SN-c (SN-8); `DesignWindow.swift` from canvas-basics CB-c
  (CB-9); `DesignWindowOptions.swift` (`DesignControlID`, the launch
  arguments) from design-window DW-c; `Tests/AppSnapshotTests/DesignFileMenuSnapshots.swift`
  from files-history FH-b (FH-3). DE-11's blueprint rows wait on FH-b
  (FH-7, the only other Design task that edits `docs/blueprints/design.md`).
- **design-seams-2 (OUT, `p3`)** owned the same four window files, the
  `export:` slot line in `DesignServices.swift`, `Live/LiveExport.swift` and
  `DesignExportSheet.swift`. Its `.wave.json` now waits on this feature
  (S2-a on DE-a for `DesignServices.swift`; S2-b on DE-u for the window
  files), so `scripts/waves check` holds. When its lead re-cuts it, D2-2
  drops `Live/LiveExport.swift` and the export slot, D2-3a drops the three
  export actions, and D2-4b drops Export… and `DesignExportSheet.swift`
  (this packet's files are named differently, so nothing collides until
  then).
- **SuiteModel (suite line):** DE-0 adds one new Linux-safe file,
  `Sources/SuiteModel/Values/UniqueFileNames.swift`, the unique-name rule
  Library's export (#1554, `LiveExporter.plan(… existingNames:)`, a stub
  today) needs too; `lead.md` rule 20 puts a concept two apps need in
  SuiteModel first. No suite packet owns that path. The lead files a
  `line:library` follow-up, "Library: `LiveExporter` names files with
  `UniqueFileNames`".
- **No creative-core issue.** DesignModel links `CoreColor` only; the raster
  is SwiftUI's `ImageRenderer` over the canvas's `DesignArtwork`, PNG through
  ImageIO, PDF through `CGContext(consumer:mediaBox:)`, all system frameworks.

**Canonical first (`lead.md` rule 20, `packets.md` check 14).** The export
run (idle, editing, running, finished, failed, progress never back, cancel)
is `SuiteKernel.ExportRun<DesignExportOptions>`; the sheet (format row,
progress bar, finished and failed lines) is `SuiteUI.ExportSheet`; the
unique-name rule is `SuiteModel.UniqueFileNames`. Design adds no run, no
sheet and no name rule. Its two files that touch the concept are adapters,
named for the `scripts/check-dup-logic` exemption and honestly so:
`Sources/DesignModel/DesignExport+Kernel.swift` conforms Design's export
slot to the kernel run (the `Options` payload, the plan that gives the run its
`total` and its `finished` names) and `Sources/DesignApp/DesignExport+Kernel.swift`
hosts the kernel sheet over that run. The SVG text (`Live/DesignSVG.swift`)
and the raster (`DesignRasterizer.swift`) are Design's drawing, which no
shared module has; their names hold no canonical stem. The blueprint's
`Live/LiveExport.swift` and `DesignExportSheet.swift` are not used (both
names would fail the ratchet, and both were design-seams-2's).

**Clean-room.** Behaviour only: the SVG rules come from the W3C SVG 2
recommendation (blueprint S6), never from another product's output.

Blueprint sections: 3 tier 2 (#418), 4 (the tier-2 journey `+Export`), 5.4
tier 2 (`ExportPlanning`), 5.6 (the slot), 6 (the Export sheet row, File >
Export… ⇧⌘E), 7.1 (QD-S12), 7.4 (QD-V8, QD-V9), 8.2 (F6).

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Design-scoped macOS run (a Model-only slice: its walk on the Linux gate).

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DE-a | The export options, scope and run type exist with every signature the sheet calls, the live and fake export slots plan a frame's files the way the fake did, and a name made unique against a folder is one SuiteModel rule. | DE-1, DE-0, DE-2 | MJ13 | design-contracts (the feature); editor-kernel EK-a (DE-2, cross-line) |
| DE-u | File > Export… ⇧⌘E opens SuiteUI's `ExportSheet` on the fakes with format, scale and scope rows and the files it will write, Export runs the fake steps to a finished list, Cancel and Escape close it, and a failed step names its file. | DE-6, DE-7 | J19 (on the fakes) | DE-a; design-window; files-history FH-b; snapping SN-c; canvas-basics CB-c; editor-kernel EK-chrome (cross-line) |
| DE-s | The plan picks the right layers for each scope, names them uniquely, sizes them for the scale, refuses with the right reason, and the SVG of a layer or a page equals the reference document. | DE-3, DE-5 | MJ13, MJ14 | DE-a |
| DE-w | A frame, a selection or the page renders to a PNG with the right pixel size at 1x, 2x and 3x, and to a one-page PDF, from the same artwork the canvas draws, off the window. | DE-8, DE-9 | `DesignRasterizerTests` (macOS) | DE-a |
| DE-z | Export writes real files into the chosen folder without overwriting, shows progress and the written names, reports a file that could not be written, and the journeys pass on the live services. | DE-10, DE-11 | J17, J18 | DE-u, DE-s, DE-w; files-history FH-b (DE-11); editor-kernel EK-run (DE-10, cross-line) |

DE-a is the contract (`lead.md` rule 12) and declares, as stubs returning
the fake's values, every Model signature the sheet calls (rule 18). DE-u is
the UI slice (`"ui": true`): within the feature it waits on DE-a only and
runs on the fakes; DE-6 puts Export… in the File menu, the visible control,
and J19 proves the slice on `-DesignServices fake` so it reads done before
any live file is written. DE-s is Model only. DE-w is `"ui": true` by path (it adds a file under
`Sources/DesignApp/`), though it draws nothing on screen; its render budget
row says the write never runs the window body. DE-z integrates: DE-10 swaps
the fake steps for real writes and turns J17 on; DE-11 turns J18 on and
carries `feature-done`.

## Journey steps

In `UITests/DesignJourneyTests+Export.swift`, class
`DesignExportJourneyTests`, launched with `-DesignFixture cards` and
`-SuiteWindowSize 1024x768`; J17 and J18 on the live services with
`-DesignExportTo <tmp folder>` (the folder the test creates; the argument
stands in for the folder panel, as `-DesignSaveTo` does for Save), J19 on
`-DesignServices fake`. Every step uses the mouse on visible controls; ⇧⌘E
is checked once as the keyboard twin of the menu item.

0. **J19** `testExportSheetOnFakes` (DE-6 writes it skipped, DE-7 turns it
   on; the fakes, no folder): click Desktop's row in Layers; click the menu
   bar's File, click Export… (DE-6): the sheet lists "Desktop.png 1440 ×
   1024, 1x"; click 2x: "2880 × 2048 px"; click Export (DE-7): the progress
   bar fills through the fake steps, the finished line reads "Exported 1
   file" and the status line repeats it; click Done; press ⇧⌘E, click
   Cancel: no sheet. The slice is done on this journey alone.
1. **J17** `testExportPNGSVGPDF` (DE-7 writes it skipped, DE-10 turns it
   on): click Desktop's row in Layers; click the menu bar's File, click
   Export… (DE-6): the sheet (`design.export.sheet`) lists "Desktop.png
   1440 × 1024, 1x" (DE-3). Click 2x (`design.export.scale`): the row reads
   "2880 × 2048 px". Click Export (`design.export.run`): the progress bar
   fills, the sheet's finished line reads "Exported 1 file to <folder>"
   (DE-7, DE-10) and the status line says the same; the folder holds
   `Desktop.png`, 2880 × 2048 pixels (the test reads it with ImageIO; DE-8).
   Press ⇧⌘E: the sheet opens again; click SVG (`design.export.format`);
   click Export: `Desktop.svg` exists and its first element is `<svg` with
   `viewBox="0 0 1440 1024"` (DE-5). Press ⇧⌘E; click PDF; click Export:
   `Desktop.pdf` exists and `CGPDFDocument` opens it with one page (DE-9).
2. **J18** `testExportNeverOverwritesAndCancels` (DE-7 writes it skipped,
   DE-11 turns it on): with Desktop selected, export PNG at 1x twice: the
   folder holds `Desktop.png` and `Desktop 2.png`, and the first file's
   bytes are unchanged (DE-0, DE-10). Click Escape on an open sheet, then
   open it and click Cancel (`design.export.cancel`): no third file. Click
   the canvas's empty corner (nothing selected) and open the sheet: scope
   reads Frame and the list holds every top-level frame (Desktop). Make the
   folder read-only (the test does, `chmod 0500`) and click Export: the
   sheet's failed line reads "Desktop 3.png couldn't be written. You don't
   have permission to save the file “Desktop 3.png” in the folder
   “<folder>”." (the system's words after Design's), the window keeps its
   document, Cancel closes the sheet (DE-11).
3. **MJ13** `DesignExportWalkTests.testPlanWalk` (DE-1 writes it, DE-3 turns
   it on; Linux): on `cards`, plan the selection A, B at PNG 2x into a folder
   holding "A.png" → items "A 2.png" 200 × 160 px and "B.png" 400 × 160 px;
   plan the frame around A → "Desktop.png" 2880 × 2048; nothing selected,
   scope selection → `.nothingSelected`; an empty page, scope frame →
   `.nothingToExport`; the page at SVG → one item "Page 1.svg" 1440 × 1024,
   pixel size equal to points.
4. **MJ14** `DesignSVGWalkTests.testDocumentWalk` (DE-1 writes it, DE-5
   turns it on; Linux): the SVG of Desktop on `cards` equals the reference
   literal (QD-V8); hiding B drops its element and nothing else changes; a
   text "A & B <C>" is escaped; the page's SVG on `twoPages`'s Mobile has
   `viewBox="0 0 390 844"` and one `<g>` for Phone with a `clipPath`.

J3 (`testDrawShapesAddTextAndSave`, existing) and J1 (`testEveryMenuOpens`,
existing) keep passing: J1's File menu gains Export…, disabled with
"Create or open a file first." before New File (DE-6).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| File > Export… (menu item) | no file open: disabled, help "Create or open a file first." | – | – |
| Export sheet, options | nothing on the page: Export disabled with "There's nothing on this page to export."; scope Selection with nothing selected: "Select a layer first." and scope falls back to Frame | – | – |
| Export sheet, files list | – | – | the list is the plan, rebuilt on every option change; a hidden selected layer is listed dimmed with "Hidden layers aren't exported" (it is skipped) |
| Export sheet, running | – | a step that fails ends the run: the failed line names the file and the reason; the files already written stay | progress bar "2 of 3", Cancel stops after the current file |
| Export sheet, finished | – | – | "Exported 3 files to <folder>"; Done (Return) closes; the status line repeats the sentence |
| Folder panel (system) | – | Cancel in the panel returns to the sheet in `.editing` | – |

Snapshots (`Tests/AppSnapshotTests/DesignExportSnapshots.swift`):
`design-export-menu` (File with Export… ⇧⌘E), `design-export-sheet` (editing,
PNG 1x Frame, one item), `design-export-sheet-selection` (two items, one
hidden and dimmed), `design-export-running` (2 of 3), `design-export-finished`,
`design-export-failed`. `DesignFileMenuSnapshots`' `design-file-menu-close`
PNG gains the Export… row (DE-6 re-records it).

## Contract slice

SuiteModel, `Sources/SuiteModel/Values/UniqueFileNames.swift` (DE-0; Linux):

```swift
/// One rule for a file name that is not already in a folder, shared by every app's export.
public enum UniqueFileNames {
    /// "Card.png"; when taken, "Card 2.png", "Card 3.png", … Comparison ignores case (APFS
    /// default); `/` and `:` in `base` become "-"; an empty base is "Untitled".
    public static func name(_ base: String, extension ext: String, among existing: Set<String>) -> String
}
```

Model, `Sources/DesignModel/DesignExport+Kernel.swift` (DE-2 declares, DE-3
fills the plan; Linux, imports `SuiteKernel`):

```swift
/// What one export writes: the selected layers, the frame around them, or the page.
public enum DesignExportScope: String, CaseIterable, Hashable, Sendable { case selection, frame, page }

/// The run's payload (`ExportRun<DesignExportOptions>`): format, scale (1, 2, 3; PNG only) and scope.
public struct DesignExportOptions: Hashable, Sendable {
    public var format: DesignExportFormat = .png
    public var scale: Int = 1
    public var scope: DesignExportScope = .frame
    public init(format: DesignExportFormat = .png, scale: Int = 1, scope: DesignExportScope = .frame)
}

/// Design's export run is the kernel's; the sheet reads it, DesignExport+Kernel (App) drives it.
public typealias DesignExportRun = ExportRun<DesignExportOptions>

/// The live export slot: the plan and the SVG text. `.fake` uses the same type (planning is
/// pure; what differs on the fakes is that the App writes nothing).
public struct LiveExport: ExportPlanning {
    public init()
    public func exportHelp(_ ids: [String], on page: DesignPage) -> String?
    public func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
                     existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem]
    public func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String   // DesignSVG.document
}

extension DesignWorkspace {
    /// The ids `options.scope` names on the selected page: the selection; the top-level frame
    /// holding the primary selection, or every top-level frame with nothing selected; or
    /// `[page.id]` for the page. Hidden layers are dropped (the sheet dims them).
    public func exportTargetIDs(_ scope: DesignExportScope) -> [String]
    /// nil when Export can run; else the reason the sheet's Export button shows.
    public func exportHelp(_ options: DesignExportOptions) -> String?
    /// The files one run writes, names unique against `existing` (the folder's listing).
    public func exportPlan(_ options: DesignExportOptions, existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem]
    /// The SVG document of one planned item (a layer, or the page when `item.nodeID` is the page's id).
    public func exportSVG(_ item: DesignExportItem) throws(DesignRefusal) -> String
    /// The options the sheet opens with: the last run's, else PNG 1x Frame.
    public var exportDefaults: DesignExportOptions { get }
    public mutating func rememberExport(_ options: DesignExportOptions)   // not a history step
}
```

`DesignExportItem` (exists, `Contracts/StyleTypes.swift`): `nodeID`,
`fileName`, `width`, `height` in points, `pixelWidth`, `pixelHeight` at the
scale (equal to points for SVG and PDF). For the page item `nodeID` is the
page's id and `width`, `height` are `frameWidth`, `frameHeight`.

Model, `Sources/DesignModel/Live/DesignSVG.swift` (DE-2 stubs, DE-5 fills; Linux):

```swift
/// The SVG text of nodes inside a box. One element per visible layer in paint order; the box is
/// the viewBox and coordinates are relative to its origin.
enum DesignSVG {
    static func document(_ nodes: [DesignNode], box: DesignRect, clip: Bool) -> String
}
```

App, `Sources/DesignApp/DesignExport+Kernel.swift` (DE-6, DE-7, DE-10,
DE-11; macOS): `DesignExportArea`, a view modifier on the window root (the
shape of Photo's `PhotoExportArea` and Flare's `FlareFilePanels`), holding
`@State run: DesignExportRun = .idle` and presenting `SuiteUI.ExportSheet`
while `run != .idle`. `DesignIntent.export` (DE-6) asks it to `open()`:
`run.begin(model.exportDefaults)`. Its rows: the kernel sheet's format row
from `DesignExportFormat.allCases`, scale and scope as `ChoiceChips` (see the
`needs-ui` note under Quality tests), the plan as the item list, Export and
Cancel. `-DesignExportTo <folder>` and `-DesignServices fake` skip the folder
panel (DE-10, DE-6). Control ids, declared in `DesignControlID`
(`DesignWindowOptions.swift`, DE-6): `design.export.sheet`,
`design.export.format`, `design.export.scale`, `design.export.scope`,
`design.export.items`, `design.export.run`, `design.export.cancel`,
`design.export.result`.

App, `Sources/DesignApp/DesignRasterizer.swift` (DE-8, DE-9; macOS):

```swift
/// PNG and PDF of planned items, drawn from DesignArtwork (the canvas's painter) off the window.
enum DesignRasterizer {
    /// The nodes inside the item's box painted at `scale` into an sRGB PNG with alpha.
    static func png(_ item: DesignExportItem, on page: DesignPage, scale: Int) throws -> Data
    /// One page the size of the item's box in points.
    static func pdf(_ item: DesignExportItem, on page: DesignPage) throws -> Data
}
```

## Pseudocode

```
exportTargetIDs(scope):
  .selection → selectedNodeIDs minus hidden-in-tree
  .frame     → let top = topLevelAncestor(of: primary selection) where top.kind == .frame ?? [top]
               else page.nodes.filter(.frame && !hidden).ids          # nothing selected, or a top-level shape
  .page      → [page.id]
exportHelp(options): try exportPlan(options, existing: []) → nil; catch → refusal.help
exportPlan(options, existing):
  ids = exportTargetIDs(options.scope)
  if options.scope == .page: item(page.name, frameWidth, frameHeight)
  else: items = services.export.plan(ids, page, format, scale, existing)     # LiveExport.plan
LiveExport.plan(ids, page, format, scale, existing):
  nodes = ids.isEmpty ? top-level frames : fakeFind(ids, page); drop hidden
  guard !nodes.isEmpty else throw ids.isEmpty ? .nothingToExport : .nothingSelected
  k = format == .png ? clamp(scale, 1...3) : 1;  taken = existing (lowercased)
  for node: name = UniqueFileNames.name(node.name, ext: format.rawValue, among: taken); taken += name
    item(node, name, w, h, Int(w.rounded()) * k, Int(h.rounded()) * k)   # whole points before scaling
DesignSVG.document(nodes, box, clip):
  <svg xmlns viewBox="0 0 w h" width="w" height="h">; if clip: <defs><clipPath id="clip"><rect …/></clipPath></defs>
  for node in nodes (paint order, hidden subtrees skipped), translated by -box.origin:
    .rectangle → <rect x y width height rx=cornerRadius? fill stroke stroke-width opacity?>
    .ellipse   → <ellipse cx cy rx ry …>;  .text → <text x y font-size font-family font-weight text-anchor>escaped</text>
    .frame     → <g clip-path="url(#clip-<id>)"> with its own <clipPath>, then children;  .group → <g opacity?> children
  attributes only when they differ from the SVG default (opacity 1, no stroke, rx 0)
run (DesignExportArea, DE-10):
  Export: folder = launch -DesignExportTo ?? NSOpenPanel(canChooseDirectories, canCreateDirectories, prompt "Export")
          (Cancel in the panel: stay .editing)
  existing = folder listing (file names);  items = model.exportPlan(options, existing)
  guard run.start(total: items.count)
  for (i, item): data = format == .svg ? exportSVG : .png ? png(scale) : pdf
                 write(folder/item.fileName, .withoutOverwriting)      # the rule, enforced twice
                 run.progressed(done: i + 1);  if cancelled: break
  run.end(.success(names))  |  on a thrown error: run.end(.failure("\(name) couldn't be written. \(reason)"))
  model.rememberExport(options);  note = "Exported \(n) file\(s) to \(folder.lastPathComponent)"
  on the fakes (-DesignServices fake): no folder, no write; progressed through the plan, then .success(names)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: design-export`, `Slice:
<slice>`, `Fast-Check: pass`, `Head:`, the snapshot PNGs it changes, and for
a Model task its `Mutate: n/n <plan>` line. DE-11 also carries
`feature-done` and `Closes #418`. Paths drop `Sources/DesignModel/` and
`Sources/DesignApp/`; Model tests are `Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DE-1 | – | **Checks first.** The Model tests from this packet, disabled by name: `DesignExportPlanTests` (shape half `.disabled("waits on DE-2")`, rules half "waits on DE-3"), `DesignSVGTests` (QD-V8 literal; "waits on DE-5"), `DesignExportBudgetTests` (QD-S12 SVG half; "waits on DE-5"), MJ13 `DesignExportWalkTests` ("waits on DE-3"), MJ14 `DesignSVGWalkTests` ("waits on DE-5"), `UniqueFileNamesTests` ("waits on DE-0") | `DesignExportPlanTests.swift`, `DesignSVGTests.swift`, `DesignExportBudgetTests.swift`, `DesignExportWalkTests.swift`, `DesignSVGWalkTests.swift`, `Tests/SuiteModelTests/UniqueFileNamesTests.swift` | – | ~300, 6 |
| DE-0 | – | **One name rule.** `UniqueFileNames.name` in SuiteModel (rule 20: Library's export needs it too), its plan; the `suite-identity` C4 part (it covers `Values/`) names the rule; turns on its test | `Sources/SuiteModel/Values/UniqueFileNames.swift`, `Tests/mutations/SuiteModel.UniqueFileNames.json`, `Tests/SuiteModelTests/UniqueFileNamesTests.swift`, `docs/c4/parts/creative-apps/suite-model/suite-identity.json` | DE-1 | ~120, 4 |
| DE-2 | #418 (contract) | **Contract and stubs.** `DesignExportScope`, `DesignExportOptions`, `DesignExportRun`, `LiveExport` whose `plan` is the blueprint `FakeExport`'s (top-level frames or the named layers, "<name>.<ext>", no uniqueness) and whose `svg` calls the `DesignSVG.document` stub (the fake's one-element document); the workspace readouts with `exportTargetIDs` real and `exportDefaults` stored; both `DesignServices` slots `LiveExport()`; the three tests that asserted NotBuilt updated; the `DesignServices.json` entry whose find was the NotBuilt slot repointed; new plans; the C4 Model part's sentence; turns on the shape half of `DesignExportPlanTests` | `DesignExport+Kernel.swift`, `Live/DesignSVG.swift`, `DesignServices.swift`, `DesignLiveStubTests.swift`, `DesignNotBuiltTests.swift`, `DesignArrangeFakesTests.swift`, `DesignExportPlanTests.swift`, `Tests/mutations/DesignModel.DesignServices.json`, `Tests/mutations/DesignModel.DesignExport+Kernel.json`, `docs/c4/parts/creative-apps/design-model/design-model-sources.json` | DE-1; editor-kernel EK-a (`import SuiteKernel`) | ~340, 10 |
| DE-3 | #418 (plan) | **The plan.** `LiveExport.plan` and `exportPlan` as the pseudocode: scopes, hidden layers dropped, names through `UniqueFileNames` against `existing`, pixel sizes from whole points times the scale (PNG only), the refusals; turns on the rules half and MJ13 | `DesignExport+Kernel.swift`, `Tests/mutations/DesignModel.DesignExport+Kernel.json`, `DesignExportPlanTests.swift`, `DesignExportWalkTests.swift` | DE-2, DE-0 | ~220, 4 |
| DE-5 | #418 (SVG) | **The SVG text.** `DesignSVG.document` as the pseudocode (QD-V8), its plan; turns on `DesignSVGTests`, `DesignExportBudgetTests.svgExport` and MJ14 | `Live/DesignSVG.swift`, `Tests/mutations/DesignModel.DesignSVG.json`, `DesignSVGTests.swift`, `DesignExportBudgetTests.swift`, `DesignSVGWalkTests.swift` | DE-2 | ~280, 5 |
| DE-6 | #418 (screen) | **Reachable, on the fakes.** `DesignIntent.export`; File > Export… ⇧⌘E after Save As… in `DesignFileMenu`, disabled with the Model's help; `DesignWindow.perform(.export)` opens `DesignExportArea`, which hosts `ExportSheet` in `.editing` over `model.exportPlan` with format, scale and scope rows and the item list; the ids in `DesignControlID` and the `-DesignExportTo <folder>` and `-DesignExportFail <name>` arguments parsed in `DesignWindowOptions`; the App C4 part's sentence (the export area and the rasterizer DE-8 adds beside it); J19 written, `XCTSkip("waits on DE-7")`; `DesignExportSnapshots` (`design-export-menu`, `design-export-sheet`, `-selection`; the run states `.disabled("waits on DE-7")`); `design-file-menu-close` re-recorded; `RenderBudgetDesignExportTests` written, `sheet` `.disabled("waits on DE-7")`, `liveRun` `.disabled("waits on DE-10")` | `DesignIntent.swift`, `DesignCommands.swift`, `DesignWindow.swift`, `DesignWindowOptions.swift`, `DesignExport+Kernel.swift` (App), `UITests/DesignJourneyTests+Export.swift`, `Tests/AppSnapshotTests/DesignExportSnapshots.swift`, `Tests/AppSnapshotTests/DesignFileMenuSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignExportTests.swift`, `docs/c4/parts/creative-apps/design-app/design-app-sources.json` | DE-2; design-window DW-c; files-history FH-b; snapping SN-c; canvas-basics CB-c; editor-kernel EK-chrome | ~330, 10 |
| DE-7 | #418 (screen) | **The run on the fakes.** Export runs the plan through `DesignExportRun` with no folder and no write (progress per item, then `.finished` with the names); Cancel and Escape `dismiss()`; Return on `.finished` closes; DE-6's `-DesignExportFail <name>` fails that item's step and shows the failed line; J19 turned on; J17 and J18 written, `XCTSkip("waits on DE-10")` / `("waits on DE-11")`; the three state snapshots and the `sheet` render budget test turned on | `DesignExport+Kernel.swift` (App), `UITests/DesignJourneyTests+Export.swift`, `Tests/AppSnapshotTests/DesignExportSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignExportTests.swift` | DE-6 | ~290, 4 |
| DE-8 | #418 (PNG) | **PNG.** `DesignRasterizer.png`: `ImageRenderer` over `DesignArtwork(painted:)` of the nodes inside the item's box, `scale` 1, 2, 3, `cgImage` written through `CGImageDestination` as PNG with alpha (sRGB); `DesignRasterizerTests` (pixel size at each scale for Desktop and for the page; a transparent corner outside a shape on the page; QD-V9 against the canvas golden, report-only until #331 and #332); `RenderBudgetDesignRasterTests` (QD-S12: 2x PNG of 1440 × 1024 ≤ 1 s, zero window bodies) | `DesignRasterizer.swift`, `Tests/AppSnapshotTests/DesignRasterizerTests.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignRasterTests.swift` | DE-2 | ~240, 3 |
| DE-9 | #418 (PDF) | **PDF.** `DesignRasterizer.pdf`: one page the item's size in points through `CGContext(consumer:mediaBox:)` and `ImageRenderer.render`; the test opens it with `CGPDFDocument` (one page, the media box) | `DesignRasterizer.swift`, `Tests/AppSnapshotTests/DesignRasterizerTests.swift` | DE-8 | ~120, 2 |
| DE-10 | #418 (live) | **Real files.** The folder from `-DesignExportTo` or `NSOpenPanel`; `existing` from the folder's listing; each item rendered (SVG from `exportSVG`, PNG and PDF from `DesignRasterizer`) and written with `.withoutOverwriting`; progress per file; the status note; `rememberExport`; J17 and the `liveRun` render budget test turned on | `DesignExport+Kernel.swift` (App), `UITests/DesignJourneyTests+Export.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignExportTests.swift` | DE-7, DE-3, DE-5, DE-9; editor-kernel EK-run | ~220, 3 |
| DE-11 | #418 (closes) | **Failures, Cancel mid-run, docs.** A thrown write ends the run `.failed` with the file's name and the system's reason, files already written stay; Cancel while running stops after the current file and reports what was written; J18 turned on; blueprint rows (F6's owned files and journeys, QD-S12's test names, the journey list's `+Export` names); `feature-done`, `Closes #418` | `DesignExport+Kernel.swift` (App), `UITests/DesignJourneyTests+Export.swift`, `docs/blueprints/design.md` | DE-10; files-history FH-b | ~170, 3 |

DE-3 and DE-5 are independent: DE-2 gives `svg` its own file
(`Live/DesignSVG.swift`), so the plan task and the SVG task never share one.
DE-6 depends on DE-2 because it calls `exportPlan`, `exportHelp`,
`exportDefaults` and `DesignExportRun`; it does not depend on DE-3 or DE-5
(the stubs return the fake's plan). DE-8 depends on DE-2 for
`DesignExportOptions` only. DE-10 is the integrate step: it calls DE-3's
plan, DE-5's SVG and DE-9's rasterizer and edits DE-7's file. No task edits
`docs/c4/model.json`, `waves.md` or `UITests/DesignJourneyTests.swift`; the
owned list lives in `design-export.wave.json`.

**Lazier alternative, named (ponytail lite):** the blueprint's top bar also
gets an Export… item ("the one filled primary", EC-4). It is not in the beta
promise, and a ninth `DesignToolbarItem` would reopen
`DesignToolbarItems.swift` (shell-parity's), `DesignEditor.swift`,
`DesignToolbarItemsTests` (`ids.count == 8`) and its plan. Skipped; the lead
files it as a `line:design` follow-up, "Design: Export… in the top bar", with
`Depends on:` editor-chrome #339 for the primary style.

## Build waves

- Wave 1: DE-1. Independent in this wave: DE-1 alone.
- Wave 2: DE-0, DE-2 (editor-kernel EK-a merged). Independent in this wave: both.
- Wave 3: DE-3, DE-5, DE-8, DE-6 (design-window, files-history FH-b,
  snapping SN-c, canvas-basics CB-c and editor-kernel EK-chrome merged).
  Independent in this wave: all four.
- Wave 4: DE-7, DE-9. Independent in this wave: both.
- Wave 5: DE-10 (editor-kernel EK-run merged). Independent in this wave: DE-10 alone.
- Wave 6: DE-11 (`feature-done`, final). Independent in this wave: DE-11 alone.

Longest chain: DE-1 → DE-2 → DE-6 → DE-7 → DE-10 → DE-11 (6). Chain of 6:
DE-2 declares the types DE-1's tests and DE-6's sheet compile against; DE-7
adds the run states to DE-6's file; DE-10 swaps the fake steps for real
writes in that file; DE-11 adds the failure paths to it and carries the
docs. The screen (DE-6, DE-7) is done by wave 4, beside the plan, the SVG
and the raster.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DE-1 | every new suite compiles and is skipped by name on the Linux job; `swift test --filter DesignExport` lists them as skipped, none passing | a test passes before its code exists (a false oracle) | – (tests) |
| DE-0 | `UniqueFileNamesTests`: "Card" + png among {} → "Card.png"; among {"Card.png"} → "Card 2.png"; among {"Card.png", "Card 2.png"} → "Card 3.png"; among {"card.png"} → "Card 2.png"; "A/B:C" → "A-B-C.png"; "" → "Untitled.png" | a taken name comes back, or the first suffix is 1 | the suffix is dropped when taken (`among` ignored) → `.takenGetsSuffix`; the counter starts at 1 → `.firstSuffixIsTwo`; comparison is case-sensitive → `.ignoresCase` |
| DE-2 | `DesignExportPlanTests` shape half: the signatures exist (a `Stub: ExportPlanning` typed like `DesignDocumentTests`'), `.fake.export` and `.live.export` are `LiveExport`, `exportTargetIDs` gives the selection, the top-level frame of A, every top-level frame with nothing selected, `[page.id]` for the page, and drops a hidden id; `exportDefaults` is PNG 1x Frame and `rememberExport` changes it without a history step; `DesignLiveStubTests`, `DesignNotBuiltTests`, `DesignArrangeFakesTests` updated and green; `scripts/mutate --validate` | a slot is still NotBuilt, a target id is wrong, `rememberExport` records a step | `exportTargetIDs(.frame)` returns the selected shape instead of its frame → `.frameScopeClimbs`; a hidden selected id kept → `.hiddenDropped`; `rememberExport` records "Export" as a step → `.defaultsNotAStep`; the `DesignServices.json` entry repointed to `export: LiveExport()` → `DesignLiveStubTests` |
| DE-3 | `DesignExportPlanTests` rules half and MJ13 as Journey step 3: names unique against `existing` and against each other (two layers named "Card" → "Card.png", "Card 2.png"), pixel sizes `Int(w.rounded()) * k` with k 1…3 for PNG and 1 for SVG and PDF, scale 0 and 9 clamp, `.nothingSelected` vs `.nothingToExport`, the page item's size is the page's, a locked layer exports | a name repeats, a size is off by the scale, a refusal is swapped | `existing` ignored → `.namesUniqueAgainstFolder`; the second "Card" not renamed → `.namesUniqueWithinPlan`; SVG sized by `scale` → `.svgIgnoresScale`; `scale` not clamped → `.scaleClamps`; `.nothingToExport` thrown with ids given → `.refusalNamesTheCause`; a locked layer refused → `.lockedExports`; the page item sized by `contentBounds` → `.pageIsThePage` |
| DE-5 | `DesignSVGTests` (QD-V8: the Desktop reference literal; one element per visible layer; `clipPath` on frames; escaped text; `opacity`, `stroke`, `stroke-width`, `rx` only when not the default; coordinates relative to the box); `DesignExportBudgetTests.svgExport` (QD-S12: the `crowd` page ≤ 100 ms device / ≤ 1 s Linux debug); MJ14 | a byte of the reference differs, a hidden layer is written, text is unescaped | a hidden layer emitted → `.hiddenLeftOut`; `&` written raw → `.textEscaped`; the frame's `clip-path` dropped → `.framesClip`; `opacity="1"` always written → `.defaultsOmitted`; `stroke-width` dropped → `.strokeWritten`; the box origin not subtracted → `.coordinatesRelative`; `rx` dropped → `.cornerRadiusWritten` |
| DE-6 | `DesignExportSnapshots` `design-export-menu`, `design-export-sheet`, `design-export-sheet-selection`; `DesignFileMenuSnapshots` re-recorded; J1 still green; J19 skips with its message; `suite.controls` lists every `design.export.*` id while the sheet is open (J15's sweep) | Export… is missing, enabled with no file, or the sheet shows a row the plan has no item for | – (UI) |
| DE-7 | J19 passes on the fakes (Journey step 0); `design-export-running`, `-finished`, `-failed`; `RenderBudgetDesignExportTests.sheet` (open the sheet, click format, scale and scope three times each: ≤ 2 `DesignEditor` body runs; the sheet is window state); J17 and J18 skip with their messages | Cancel leaves `.running`, Return on `.finished` does nothing, the finished line names the wrong count, or the body count rises with the sheet | – (UI) |
| DE-8 | `DesignRasterizerTests.pixelSize` (Desktop at 1x 1440 × 1024, 2x 2880 × 2048, 3x 4320 × 3072; the `twoPages` Mobile page 390 × 844), `.alphaOutsideShapes` (the page item's corner with nothing drawn is transparent), `.matchesCanvasGolden` (QD-V9, report-only until #331, #332); `RenderBudgetDesignRasterTests.write` (2x of Desktop ≤ 1 s wall; `DesignWindow.bodyRuns` unchanged) | a size is off by the scale, the window body runs during a write | – (UI; macOS) |
| DE-9 | `DesignRasterizerTests.pdfOnePage`: `CGPDFDocument` opens the data, one page, media box 1440 × 1024 pt | the PDF has no page or the box is scaled | – (UI; macOS) |
| DE-10 | J17 passes: the three files exist with the right pixel size, `viewBox` and page count; `rememberExport` makes the second sheet open on SVG after an SVG run; `RenderBudgetDesignExportTests.liveRun` (a three-file PNG export of `cards`' Desktop, A and B into a temp folder: ≤ 4 `DesignEditor` body runs, one per progress step plus the finish) | a file is missing, overwritten or sized wrong, or the body count rises with the file count | – (UI) |
| DE-11 | J18 passes: "Desktop 2.png" beside an unchanged "Desktop.png", no file after Cancel or Escape, the read-only folder's failed line names "Desktop 3.png" and the window keeps its document; `git grep -n 'testExportPNGSVGPDF' docs/blueprints/design.md` shows `+Export` with both journeys | a file is replaced, a failure is reported as finished, the blueprint still lists wave-3 names | – (UI) |

Rule 13 holds: DE-1 owns every Model test before DE-0 and DE-2; DE-6, the
first code task of DE-u, owns its snapshots, render budget test and
journeys; DE-8, the first of DE-w, owns its tests. Rule 14: each Model task
that adds behaviour lists two or more mutations in the plan of the file it
changes (`Tests/mutations/SuiteModel.UniqueFileNames.json`,
`DesignModel.DesignExport+Kernel.json`, `DesignModel.DesignSVG.json`), run
with `scripts/mutate --plan` before its PR.

## Quality tests

| quality row | budget | test |
|---|---|---|
| QD-S12 export | SVG of the `crowd` page ≤ 100 ms device / ≤ 1 s Linux debug; 2x PNG of 1440 × 1024 written ≤ 1 s wall; progress visible within 100 ms of Export | `DesignExportBudgetTests.svgExport` (DE-5); `RenderBudgetDesignRasterTests.write` (DE-8); J17 |
| QD-V8 SVG is the reference | the Desktop document equals the literal byte for byte | `DesignSVGTests` (DE-5) |
| QD-V9 PNG is the canvas | the frame's PNG equals the canvas golden of that frame | `DesignRasterizerTests.matchesCanvasGolden` (DE-8; report-only until #331 and #332) |
| never overwrite | a planned name is never in the folder's listing, and the write refuses an existing file anyway (`.withoutOverwriting`) | `DesignExportPlanTests` (DE-3), J18 (DE-11) |
| render: the sheet (DE-u) | open the sheet, change format, scale and scope three times each: ≤ 2 `DesignEditor` body runs (`lead.md` rule 15a; `swiftui-rules.md` rules 1 and 6); sheet open p95 ≤ 16 ms, reported, checked by the Mac finisher | `RenderBudgetDesignExportTests.sheet` (DE-7) |
| render: the write (DE-w) | a 2x PNG of a 1440 × 1024 frame renders off the window: 0 `DesignEditor` body runs during the write; ≤ 1 s wall, reported | `RenderBudgetDesignRasterTests.write` (DE-8) |
| render: the live run (DE-z) | a three-file PNG export on `cards`: ≤ 4 `DesignEditor` body runs (one per progress step plus the finish; the run is sheet state, the canvas never redraws); first progress within 100 ms (QD-S12), reported | `RenderBudgetDesignExportTests.liveRun` (DE-10) |
| QB-F3 one gesture, one step | an export records no history step; Undo's title is unchanged after a run | `DesignExportPlanTests.defaultsNotAStep` (DE-2), J17 |
| keyboard parity | ⇧⌘E opens the sheet, Return runs Export (or closes on finished), Escape cancels | J17, J18 |
| no dead controls | Export is disabled with a reason whenever the plan refuses; every `design.export.*` id acts or says why | J15 (design-window D0-7b) over the open sheet, `DesignExportSnapshots` |
| audit | zero new `design` counts; the sheet's controls carry their ids | the macOS run's audit |

**`needs-ui` to file (SuiteUI line, not waited on):** (1) "SuiteUI
`ExportSheet`: a scope row and a scale choice row" — EK-30's rows are
format, size and quality; Design needs Selection / Frame / Page and 1x / 2x /
3x. If EK-30 lands with an extra-rows slot DE-6 passes two `ChoiceChips`
rows into it; otherwise DE-6 draws them above the kernel sheet's format row
(`swiftui-rules.md` rule 11) and the issue asks for first-class rows.
(2) "SuiteUI: one image file writer (PNG and JPEG through ImageIO, PDF
through `CGPDFContext`) for Photo, Library, Design and Flare" — Photo's
`ImageIOCodec.encode` and Library's `JPEGWriter` each hold a copy today;
`DesignRasterizer` keeps its four `CGImageDestination` lines until it lands.

## Done check

Per slice (`lead.md` rule 6): its journeys green on a Design-scoped run that
contains its last merged PR (MJ13 and MJ14 on the Linux gate too), no open
`finding` for the slice, every mutation in its plans caught; for DE-u and
DE-w also the feel gate (rule 15: the render budget rows, the `mouse` and
`taste` lenses over the sheet) and their `Mac-Finish:` lines (rule 17); then
`Belt-Slice-Done: <slice> <run url>` on the feature issue. The feature is
done when DE-a, DE-u, DE-s, DE-w and DE-z are:

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J17, J18 and J19 new; J1, J3 and J15 still pass with Export… in the
  File menu.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey and walk, the audit counts,
  the QD-S12 times, and the follow-up issue numbers (the top-bar item, the
  two `needs-ui`, the Library `UniqueFileNames` adoption).
