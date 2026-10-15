# Feature packet: Photo shell-parity

**Feature:** Photo opens in `SuiteWindow` like Flare and Halo. The layer
list moves to the sidebar. The image header, tool options, adjustment
sections and the selected layer's blend mode and opacity fill the
inspector, which loses its tabs. Open, Save, Export, Undo, Redo and the zoom
commands move to the window toolbar, and the save state becomes the
window's subtitle. The tools become Flare's floating tool box over the
canvas, and the rulers, checkerboard and status line stay with the canvas.
The window keeps its title bar and follows the system appearance. The
tools, their shortcuts, the tool options and what each panel shows do not
change.
**Line:** `line:photo` · **Wave:** 2 (`../../suite/features/shell-parity-waves.md`) · **Lead branch:** `lead/photo-shell-parity`
**Blueprint:** `docs/blueprints/photo.md` section 6 (Captain decision
2026-10-15); `docs/blueprints/suiteui/features/editor-in-window.md` for the
slots used here.

**Covers:** the Photo half of the 2026-10-15 decisions. It has no issue of
its own; every PR says "Part of the Photo shell-parity feature".

**Depends on:** #812 (photo-seams) and the editor-in-window feature issue.
photo-seams owns nearly every file of `Sources/PhotoApp/` until its last
task (S-13). S-8a to S-12 rewrite `PhotoWindow`, `PhotoEditor`,
`PhotoPanel`, the commands, the top bar and the status line, so nothing
here can start before it closes. The file names below are the ones
photo-seams leaves (its task table). At stage 1 the lead checks them
against `dev` and records any rename in RECORD.md before planning. #873
(targets) shares no file with this feature.

**#933.** PS-5's geometric test needs `SuiteWindow` to fit its window,
which is #933 (the split view laid out wider than the window; its fix
changes the column minimums). editor-in-window's `feature-done` waits for
that fix (its EW-5b), so this feature, filed after editor-in-window closes,
never starts on a shell that still overflows. If #933 has reopened by the
time PS-5 runs, PS-5 waits on it and records that in RECORD.md.

**Owns only** `Sources/PhotoApp/`, `Sources/PhotoModel/`,
`Tests/PhotoModelTests/`, `UITests/PhotoJourneyTests*.swift` and the
`Photo*` snapshot files in `Tests/AppSnapshotTests/`. It does not edit
`AppSnapshotTests.swift`: `PhotoEditor(model:)` and
`PhotoEditor(model:tiles:zoom:)` keep their signatures, so the shared
`photo()` snapshot test builds unchanged and only its four PNGs change.

## Journey steps

`UITests/PhotoJourneyTests.swift` keeps every journey it has.
`testLaunchShowsWindowShell` calls `expectEditorWindow()`. A step that
clicks the palette before an image is open first opens or creates one,
because the palette shows only over an open image, as Flare's does. The
toolbar buttons keep their `photo.bar.*` identifiers and titles, so
`click("Zoom In", in: .window)`, `"Export"`, `"Undo …"` and the
`photo.bar.undo` checks pass unchanged. Three changes are known, and the
lead greps for more before PS-3 (`radioButtons`, `"Adjust"`, `"Layers"`,
and any slider found by a label the inspector now holds twice):

- `testTier1Layers` waits for and clicks `photo.app.radioButtons["Layers"]`
  (lines 336 to 338 on 54e16aa), the tab PS-3 removes. It finds
  `photo.layers` inside `suite.sidebar` instead.
- The inspector now holds two sliders labelled Opacity: the tool's
  (`photo.tool.opacity`) and the layer's (`photo.layer.opacity`).
  `drag("Opacity", …)` takes the first match, so every opacity drag names
  its identifier.
- The file header stops calling Photo an EditorShell window.

**"1024 × 768"** below means the runner's display. The window asks for it
with `-SuiteWindowSize 1024x768` and gets the visible frame, about
1024 × 737 (editor-in-window). The geometric checks assert the window
inside the visible frame and every frame inside the window.

New, in `UITests/PhotoJourneyTests+Shell.swift`:

1. Launch with `-SuiteWindowSize 1024x768`. The window shows the title
   "Photo", an empty sidebar list titled Layers, and a toolbar with the app switcher centered (Photo's item in the capsule) where Open is
   enabled and Save, Export, Undo, Redo and zoom are disabled with their
   reasons. The canvas shows its empty state with Open… and no palette. The
   inspector shows the no-image state. Shot `shell-empty`.
2. Open the journey's 800 × 600 test photo with `-PhotoOpenFile`. The title
   is the file's name and the subtitle is empty or "Saved". The sidebar
   shows its one layer, the floating palette sits at the canvas's leading
   edge, and the inspector shows the header ("<file>, 800 × 600 px, sRGB · 1
   layer"), Tool Options, the Layer section and the adjustments. Shot
   `shell-open`.
3. Pick Marquee and drag from the image's left edge to 30% across, then
   View > Fit on Screen. Shot `shell-selection`, then `expectShellGeometry()`
   with the palette checked against the rulers and against the image grown
   by `anchorHit / 2`.
4. Brush a stroke. The subtitle reads "Edited" and the toolbar's Undo reads
   "Undo Paint". Click it, and the subtitle no longer reads "Edited".
5. The sidebar's New Layer adds "Layer 1". Its eye hides it, and the
   inspector's Layer section shows its blend mode and opacity.
6. The same launch with `-AppleInterfaceStyle Dark`: shots `shell-open-dark`
   and `shell-selection-dark`, then `expectShellGeometry()` again.

## Screens and states

| Region | Before (EditorShell) | After (SuiteWindow) |
|---|---|---|
| Title | the top bar's "Photo / <file>" document menu | the window title: "Photo" with no image, the file's name, or "Untitled". New Image, Open…, Save, Save As… and Export… stay in the File menu. |
| Toolbar | the top bar's Open, Save, Export, Image ▸, Undo, Redo, Zoom Out, Fit and Zoom In | Open, Save, Export, Undo, Redo, Zoom Out, Fit on Screen and Zoom In as `ToolbarAction`s from `PhotoToolbarItem`, keeping `photo.bar.open` … `photo.bar.zoom-in`. The Image menu stays in the menu bar only (it already lives there), so the toolbar fits 1024 pt. |
| Subtitle | – | the save state: "Edited" while `isDirty`, "Saved" for a clean file that has a name, none otherwise. PV-1 later adds "Edited, autosaved" and "Not saved". |
| Sidebar | the panel's Layers tab | `PhotoLayerList`: the layer rows (eye, name, blend and opacity badge), selection and drag to reorder as today, then New Layer, Delete Layer and Rename Layer… in a `SidebarActionRow` (`photo.layer.new`, `.delete`, `.rename`). It keeps the identifier `photo.layers` inside `suite.sidebar`. History joins as a second section when PV-4 builds it (the `PhotoHistoryTab` stub stays hidden). |
| Inspector | `SegmentedTabs` (Adjust, Layers) above the tab's content | no tabs: the image header, then Tool Options, then `PhotoLayerSettings` (the selected layer's blend mode and opacity, from the old Layers tab), then the adjustment sections, at 304 pt (`editorPanelWidth` plus the inspector's padding) so its rows keep today's 280 pt |
| Tools | the docked `.rail` | `ToolbarGroup(tools:selected:onSelect:)` over `PhotoRailTool` (renamed `PhotoPaletteTool` in PS-4), the floating style, in `EditorDetail`'s palette slot; only while an image is open |
| Canvas | `PhotoCanvas` with `.scrollIndicators(.never)` | the same, in `EditorDetail`'s canvas slot; Fit on Screen uses `EditorDetailLayout.fitScale` |
| Status line | `PhotoStatusLine` | the same view in `EditorDetail`'s status slot |
| Appearance | dark in both | follows the system; the chrome is glass and the canvas stays flat |

The five states: empty, open (one layer), a selection (marching ants at the
image's edge), several layers (one hidden), and narrow (the window at its
minimum of 944 pt, where nothing is clipped).

## Contract slice

```swift
// Sources/PhotoModel/PhotoToolbarItems.swift (PS-1). Foundation only, Linux-tested.
public enum PhotoToolbarItem: String, CaseIterable, Sendable {
    case open, save, export, undo, redo, zoomOut, fit, zoomIn
    public var identifier: String              // today's: "photo.bar.open" … "photo.bar.zoom-in"
    public var systemImage: String             // today's top bar symbols
    public func title(in workspace: PhotoWorkspace) -> String           // undo and redo name the edit
    public func unavailableHelp(in workspace: PhotoWorkspace) -> String? // "Open or create an image first.", "Nothing to undo."
    /// The window subtitle: "Edited", "Saved" or nil.
    public static func saveState(of workspace: PhotoWorkspace) -> String?
}
```

## Pseudocode

```
PhotoEditor.body:
  SuiteWindow(
      title: model.documentName ?? (model.canvas == nil ? "Photo" : "Untitled"),
      subtitle: PhotoToolbarItem.saveState(of: model),
      documentActions: [.open, .save, .export].map(action),            // beside the title
      actions: [.undo, .redo, .zoomOut, .fit, .zoomIn].map(action),    // trailing; the switcher sits between
          // action(item) = ToolbarAction(item.title(in: model), …, identifier: item.identifier) { perform(item.intent) }
      inspectorWidth: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m
  ) {
      PhotoLayerList(model, perform)                       // History is added here by PV-4
  } content: {
      EditorDetail {
          PhotoCanvas(…as today…).scrollIndicators(.never)
      } palette: {
          if model.canvas != nil { ToolbarGroup(tools: PhotoTool.allCases.map(PhotoRailTool…), …) }
      } status: {
          PhotoStatusLine(…as today…)
      }
  } inspector: {
      PhotoPanel(model, perform)       // header, PhotoAdjustTab's content, PhotoLayerSettings; the no-image state as today
  }

PhotoWindow (and its area file holding fit): no `tab` state; fit = EditorDetailLayout(region:paletteSize:).fitScale(artboard: image)
PhotoApp: WindowGroup … no .windowStyle(.hiddenTitleBar); .defaultSize(width: 1000, height: 700);
          .commands { SidebarCommands(); PhotoCommands() }
```

## Tasks

Every task is one PR to `dev`, at most 400 changed lines and 15 files, with
the lines `Belt-Lead:`, `Feature: photo-shell-parity`, `Fast-Check: pass`
and `Head:`, and the label `fast-lane`. PS-5 also carries `feature-done`.
Each UI PR lists the PNGs it changed.

| id | behavior | owned files | depends on | size |
|---|---|---|---|---|
| PS-1 | `PhotoToolbarItem`: the toolbar's eight commands and the save state | `Sources/PhotoModel/PhotoToolbarItems.swift` (new), `Tests/PhotoModelTests/PhotoToolbarItemsTests.swift` (new) | – (#812 closed) | ~200 lines, 2 files |
| PS-2 | The Layers tab splits into `PhotoLayerList` (the rows, plus a `SidebarActionRow` in place of the `EditorBarItem` row) and `PhotoLayerSettings` (blend mode and opacity). The tab composes the two, so only the action row looks different. | `Sources/PhotoApp/PhotoLayersTab.swift`, `Sources/PhotoApp/PhotoLayerList.swift` (new), `Sources/PhotoApp/PhotoLayerSettings.swift` (new), `Tests/AppSnapshotTests/PhotoLayerRowSnapshots.swift`, `UITests/PhotoJourneyTests.swift` (one assertion) | – (#812 closed) | ~230, 5 |
| PS-3 | The move: `PhotoEditor` on `SuiteWindow` and `EditorDetail` with the floating palette, file headers that no longer name `EditorShell`, `PhotoLayerList` in the sidebar, `PhotoPanel` without tabs (`PhotoPanelTab` goes), the subtitle, the toolbar from PS-1 (`PhotoTopBar` no longer used). `PhotoWindow` drops its tab state and fits through `EditorDetailLayout`. The scene drops the hidden title bar and adds `SidebarCommands`. The journey changes listed under Journey steps. | `Sources/PhotoApp/PhotoEditor.swift`, `Sources/PhotoApp/PhotoPanel.swift`, `Sources/PhotoApp/PhotoLayersTab.swift` (deleted: its two halves are used directly), `Sources/PhotoApp/PhotoWindow.swift`, the one `Sources/PhotoApp/PhotoWindow+*.swift` file that holds `fit()`, `Sources/PhotoApp/PhotoApp.swift`, `UITests/PhotoJourneyTests.swift`, `Tests/AppSnapshotTests/PhotoEditorSnapshots.swift`, `Tests/AppSnapshotTests/PhotoProInspectorSnapshots.swift` | PS-1, PS-2 | ~380, 9 |
| PS-4 | Subtract. Delete `PhotoTopBar.swift`, first moving `PhotoImageMenu` into the Image menu's commands file if it still lives there. Rename `PhotoRailTool` to `PhotoPaletteTool` with its test. Retire photo-seams' `-PhotoWindowWidth` (its 880 pt floor sits under the new 944 pt minimum) in favor of `-SuiteWindowSize`, with its parse and its test cases. | `Sources/PhotoApp/PhotoTopBar.swift` (deleted), `Sources/PhotoApp/PhotoCommands+Image.swift`, `Sources/PhotoApp/PhotoRailTool.swift` → `PhotoPaletteTool.swift`, `Sources/PhotoApp/PhotoEditor.swift`, the `PhotoRailTool` test file photo-seams S-10a added, `Sources/PhotoModel/PhotoFixtures.swift` and `Tests/PhotoModelTests/PhotoLaunchOptionsTests.swift` (the width flag only), and the `PhotoApp.swift` / `PhotoWindow.swift` lines that read it | PS-3 | ~260 (mostly deletions), 9 |
| PS-5 | The shell journey (steps 1 to 6) with the geometric test | `UITests/PhotoJourneyTests+Shell.swift` (new) | PS-3 | ~170, 1 |

**Build waves.** PS-1 and PS-2 are independent and run as one wave. PS-3
comes next. PS-4 and PS-5 share no file and run together as the last wave.
The longest chain is 3 tasks. PS-3 can't be split further, for the same
reason as Design's DS-3: the layer list has to leave the panel in the same
commit that puts it in the sidebar.

**Why PS-3 carries the journeys' changes.** Once PS-3 merges, Photo shows no
palette until an image is open. The launch check and any step that clicks a
tool first have to change in the same PR, or the next dev run goes red.

**Snapshot names.** `photo-empty-{light,dark}` and `photo-open-{light,dark}`
from `AppSnapshotTests.photo()` change, and so do `PhotoEditorSnapshots`
(which drops its `tab:` parameter). Name every changed PNG in the PR.
`PhotoProInspectorSnapshots` builds `PhotoPanel(model:)` at
`editorPanelWidth`, so its PNGs lose the tab bar; name those too.
`snapshot()` only writes PNGs (there are no recorded goldens on `dev`), so
the PNGs are for review. The tests that can fail are the journeys and the
unit tests.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| PS-1 | `PhotoToolbarItemsTests` (Linux). With no image only Open has no help; the rest read "Open or create an image first.". After `newCanvas`, Save and Export are enabled, Undo reads "Nothing to undo." and `saveState` is nil. After one brush stroke Undo's title is "Undo Paint" and `saveState` is "Edited", and after `undo()` it is not "Edited". After `didSave(as:)` it is "Saved". The eight identifiers are unique and equal today's `photo.bar.*`. | a command is enabled with nothing to act on, a disabled one is silent, the subtitle lies about unsaved work, or a journey identifier changes |
| PS-2 | `testTier1Layers` (dev macOS run) clicks New Layer, Rename Layer… and Delete Layer by title, as it does today, and PS-2 adds one assertion that each carries its identifier. `PhotoLayerRowSnapshots` PNGs re-recorded for review and named in the PR. New, Delete and Rename keep `photo.layer.new`, `.delete` and `.rename`. With one layer, Delete reads "The last layer can't be deleted.". `testTier1Layers` is green on the dev run. | the split changes a row, or an action loses its identifier or reason |
| PS-3 | Every existing Photo journey green on the dev macOS run (`testLaunchShowsWindowShell` through `expectEditorWindow()`, `testNewImageAndEveryTool` over the floating palette, the tier-1 crop, layers, tone and undo-zoom-pan journeys, export, save and straighten). `PhotoToolsTests` green. The changed PNGs re-recorded and named in the PR. `grep -n "EditorShell" Sources/PhotoApp UITests/PhotoJourneyTests.swift` finds nothing. | a journey loses a control it clicks, a tool stops acting, or the inspector loses a section |
| PS-4 | `scripts/ci` `CI: PASS` on Linux. The dev macOS run builds with no `PhotoTopBar` or `PhotoRailTool` left in the tree (`grep -r` finds none). The Image menu still has every item. The renamed tool's test is green. `PhotoLaunchOptionsTests` no longer parses `-PhotoWindowWidth`, and `grep -rn PhotoWindowWidth Sources Tests UITests` finds nothing. | a dangling reference, an Image menu item lost, or two window-size flags left |
| PS-5 | `PhotoJourneyTests+Shell`, steps 1 to 6, green on the dev macOS run | any frame breaks a geometric rule, the palette covers a ruler or the selection's edge, or the subtitle misreads the save state |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Geometric | On the 1024 × 768 display (window at its visible frame) with the inspector shown, every frame is inside the window: `suite.sidebar`, `suite.viewport`, `suite.status`, `suite.inspector`, the toolbar, the app switcher `suite.switcher` (centered, from editor-in-window EW-8) and each of the toolbar's eight items (hittable beside the switcher, none in the overflow). If they don't all fit, the switcher's spacing steps down first (SuiteUI); the app then drops Zoom Out and Zoom In from the toolbar (they stay in the View menu and on ⌘− and ⌘=), never Save, Undo or Redo. The four columns don't overlap by more than 1 pt. The viewport is at least `contentMinimum`, the inspector at least 304 pt and each tool at least `toolButton`. | PS-5 steps 3 and 6 |
| The floating palette never covers the rulers or the canvas's selection handles at 1024 × 768 | the palette frame clear of the top and leading ruler bands; with a selection from the image's left edge, at Fit on Screen, the palette clear of the image grown by `anchorHit / 2` (the crop's and Free Transform's handles live on that edge) | PS-5 step 3 |
| Light and dark | `shell-*` journey shots in both appearances; `photo-empty-*` and `photo-open-*` PNGs in both | PS-3, PS-5 |
| Audit at or under baseline | `photo` keeps only its `identifier` key, at or under 23. A new `offscreen`, `contrast`, `unnamed` or `overlap` count is a raise from 0 that the lane refuses. Fix its cause in this feature, and never raise the baseline. | the dev macOS run after PS-3 and after PS-5 |
| No dead controls | every toolbar item acts or says why; a palette tool that can't act (the Eyedropper on `.live`) keeps its help | PS-1, `PhotoToolsTests`, the palette tool's test |
| Contact sheet next to Flare and Halo | the `parity-photo-*` shots beside `parity-flare-*`, `parity-design-*` and `parity-halo-window` (editor-in-window EW-6), plus Photo's own `shell-*` shots | done check |

## Done check

- **Journeys green.** The dev macOS run triggered by PS-5 (`feature-done`)
  is green: every Photo journey, the new shell journey, and SuiteUI's
  parity journey.
- **Audit zero new.** `photo` has no key but `identifier`, and that is at or
  under its baseline. No other app moves.
- **Contact sheet.** Comment `Belt-Contact-Sheet: <run link>` on the
  feature issue. Put Photo's `shell-open` and `shell-open-dark` next to the
  same run's `parity-flare-window`, `parity-halo-window` and
  `parity-design-window`, and the `parity-*-palette` shots side by side, so
  the captain can see the shells and tool boxes match. Add the same run's
  `parity-photo-switcher` beside `parity-flare-switcher`, in light and
  dark (the `shell-open-dark` shot shows the dark one).
