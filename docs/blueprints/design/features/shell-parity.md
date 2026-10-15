# Feature packet: Design shell-parity

**Feature:** Design opens in `SuiteWindow` like Flare and Halo. Pages and
the layer tree move to the sidebar. Properties fills the inspector, which
loses its tabs. New, Open, Save, Undo, Redo and the zoom commands move to
the window toolbar. The tools become Flare's floating tool box over the
canvas, and the rulers and status line stay with the canvas. The window
keeps its title bar and follows the system appearance. The tools, their
shortcuts, the tool options and what each panel shows do not change.
**Line:** `line:design` · **Wave:** 2 (`../../suite/features/shell-parity-waves.md`) · **Lead branch:** `lead/design-shell-parity`
**Blueprint:** `docs/blueprints/design.md` section 6 (Captain decision
2026-10-15); `docs/blueprints/suiteui/features/editor-in-window.md` for the
slots used here.

**Covers:** the Design half of the 2026-10-15 decisions. It has no issue of
its own; every PR says "Part of the Design shell-parity feature".

**Depends on:** the editor-in-window feature issue (SuiteUI, wave 1). It
needs `SuiteWindow(sidebar:)`, `subtitle`, `inspectorWidth`,
`-SuiteWindowSize`, `EditorDetail`, `EditorDetailLayout`,
`SidebarActionRow`, `expectEditorWindow()` and `expectShellGeometry()`. No
creative-core issue. It shares no file with #812 (Photo) or #873 (targets).

**#933.** DS-4's geometric test needs `SuiteWindow` to fit its window,
which is #933 (the split view laid out wider than the window; its fix
changes the column minimums). editor-in-window's `feature-done` waits for
that fix (its EW-5b), so this feature, filed after editor-in-window closes,
never starts on a shell that still overflows. If #933 has reopened by the
time DS-4 runs, DS-4 waits on it and records that in RECORD.md.

**Owns only** `Sources/DesignApp/`, `Sources/DesignModel/`,
`Tests/DesignModelTests/`, `UITests/DesignJourneyTests*.swift` and the
`Design*` snapshot files in `Tests/AppSnapshotTests/`. It does not edit
`AppSnapshotTests.swift`: `DesignEditor(model:)` and
`DesignEditor(model:zoom:)` keep their signatures, so the shared `design()`
snapshot test builds unchanged and only its four PNGs change.

## Journey steps

`UITests/DesignJourneyTests.swift` keeps every journey it has, with three
changes in DS-3. The launch check moves from `expectEditorShell()` to
`expectEditorWindow()`. The core journey's two tab switches go, along with
their `tab(_:in:)` helper: `tab("Layers", in:)` at line 99 and
`tab("Properties", in:)` at line 111 click the `SegmentedTabs` that DS-3
removes. The checks after them find `design.current-page` and the layer
rows inside `suite.sidebar`, and the Properties rows inside
`suite.inspector`. The file header stops calling Design an EditorShell
window. Before DS-3, the lead greps the file for `tab(`, `radioButtons`,
`"Properties"` and `"Layers"` and rewrites every hit.

**"1024 × 768"** below means the runner's display. The window asks for it
with `-SuiteWindowSize 1024x768` and gets the visible frame, about
1024 × 737 (editor-in-window). The geometric checks assert the window
inside the visible frame and every frame inside the window.

New, in `UITests/DesignJourneyTests+Shell.swift`:

1. [DS-4, DS-J1] Launch with `-SuiteWindowSize 1024x768`. The window shows the title
   "Design", a sidebar with Pages and Layers, and a toolbar with the app switcher centered (Design's item in the capsule) where New and
   Open are enabled and Save, Undo, Redo and zoom are disabled with their
   reasons. The canvas shows its empty state with New File and no palette.
   The inspector reads "No Selection". Shot `shell-empty`.
2. [DS-4, DS-J2] ⌘N. The page fits in the canvas, the floating palette (Move, Frame,
   Rectangle, Ellipse, Text, Pen) sits at the canvas's leading edge, the
   title is "Untitled" and the status line shows zoom, page size and "Move".
   Shot `shell-open`.
3. [DS-4, DS-J3] Pick Rectangle and drag from 2% to 25% across the page, starting at its
   left edge, so the shape's left handles sit on the page's edge. Then
   View > Fit Page. Shot `shell-handles`, then `expectShellGeometry()` with
   the palette checked against the rulers and against the page grown by its
   handles.
4. [DS-4, DS-J4] Click the sidebar's Layers row of the rectangle: the inspector shows its
   Properties, and the toolbar's Undo reads "Undo Add Rectangle". Click it,
   and the rectangle is gone.
5. [DS-4, DS-J5] The same launch with `-AppleInterfaceStyle Dark`: shots `shell-open-dark`
   and `shell-handles-dark`, then `expectShellGeometry()` again.

## Screens and states

| Region | Before (EditorShell) | After (SuiteWindow) |
|---|---|---|
| Title | the top bar's "Design / <file>" menu | the window title: "Design" with no file, the file's name, or "Untitled". New, Open, Save and Save As stay in the File menu (`DesignCommands`). |
| Toolbar | the top bar's New, Open, Save, Undo, Redo, Zoom Out, Fit Page and Zoom In | the same eight as `ToolbarAction`s from `DesignToolbarItem`, each disabled with its reason. New, Open and Save are `documentActions` beside the title; Undo, Redo and the zoom commands are the trailing `actions`. Undo and Redo keep `design.bar.undo` and `design.bar.redo`. The app switcher sits centered between them. |
| Subtitle | – | the save state's place, as the blueprint's paragraph says. It reads nothing until files-history (#270) gives Design an unsaved state, so DS-3 passes `nil`. The "Saved <file>" note stays in the status line as today. |
| Sidebar | the panel's Layers tab | `DesignLayersPanel` as it is: Pages with the current page's checkmark and Add Page and Delete Page in a `SidebarActionRow` (`design.page.add`, `design.page.delete`), then the layer tree with eye and lock toggles, multi-select and disclosure. It keeps the identifier `design.layers` inside `suite.sidebar`. |
| Inspector | the panel's Properties tab under `SegmentedTabs` | `DesignInspector` alone, 304 pt (`editorPanelWidth` plus the inspector's padding), so its rows keep today's 280 pt; with nothing open it shows "No Selection" as today |
| Tools | the docked `.rail` | `ToolbarGroup(tools:selected:onSelect:)`, the floating style, in `EditorDetail`'s palette slot; it shows only while a file is open, as Flare's does |
| Canvas | `DesignCanvas` in the shell | `DesignCanvas` in `EditorDetail`'s canvas slot, unchanged; Fit Page uses `EditorDetailLayout.fitScale` |
| Status line | `ViewerStatusBar` under the shell | the same view in `EditorDetail`'s status slot |
| Appearance | dark in both | follows the system; the chrome is glass and the canvas stays flat |

The four states and the PNGs that show them: empty (no file:
`design-empty-light.png`, `design-empty-dark.png`, journey shot
`design-shell-empty`), open (a page and no selection: `design-open-light.png`,
`design-open-dark.png`, `design-shell-open`, `design-shell-open-dark`),
selected (one layer, with handles: `design-shell-handles`,
`design-shell-handles-dark`), and narrow (the window at its minimum of 944 pt,
where nothing is clipped: the dev run's `design-launch` at the runner's
size). DS-3 re-records `design-empty-*` and `design-open-*`.

## Contract slice

```swift
// Sources/DesignModel/DesignToolbarItems.swift (DS-1). Foundation only, Linux-tested.
public enum DesignToolbarItem: String, CaseIterable, Sendable {
    case newFile, open, save, undo, redo, zoomOut, fit, zoomIn
    public var identifier: String              // "design.bar.new" … ; undo and redo stay "design.bar.undo" / "design.bar.redo"
    public var systemImage: String             // today's top bar symbols
    public func title(in workspace: DesignWorkspace) -> String          // "Undo Add Rectangle" from undoActionName
    public func unavailableHelp(in workspace: DesignWorkspace) -> String?  // "Create or open a file first.", "Nothing to undo."
}
```

The app maps each item to a `ToolbarAction` and a `DesignIntent`. That is
one `switch` in `DesignEditor` and holds no logic.

## Pseudocode

```
DesignEditor.body:
  SuiteWindow(
      title: documentName ?? (model.isOpen ? "Untitled" : "Design"),
      subtitle: nil,                                   // #270 fills it later
      documentActions: [.newFile, .open, .save].map(action),
      actions: [.undo, .redo, .zoomOut, .fit, .zoomIn].map(action),
          // action(item) = ToolbarAction(item.title(in: model), systemImage: item.systemImage,
          //   unavailableHelp: item.unavailableHelp(in: model), identifier: item.identifier) { perform(item.intent) }
      inspectorWidth: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m
  ) {
      DesignLayersPanel(model, perform)
  } content: {
      EditorDetail {
          DesignCanvas(model, zoom, onViewport, onZoom, perform)
      } palette: {
          if model.isOpen { ToolbarGroup(tools: DesignTool.allCases, selected: model.tool) { perform(.tool($0)) } }
      } status: {
          ViewerStatusBar(…as today…)
      }
  } inspector: {
      model.isOpen ? DesignInspector(model, perform) : EmptyStateView("No Selection", …as today…)
  }

DesignWindow.fit():  scale = EditorDetailLayout(region: viewport, paletteSize: palette).fitScale(artboard: page)
DesignApp:           WindowGroup … no .windowStyle(.hiddenTitleBar); .defaultSize(width: 1000, height: 700);
                     .commands { SidebarCommands(); DesignCommands() }
```

## Tasks

Every task is one PR to `dev`, at most 400 changed lines and 15 files, with
the lines `Belt-Lead:`, `Feature: design-shell-parity`, `Fast-Check: pass`
and `Head:`, and the label `fast-lane`. DS-4 also carries `feature-done`.
Each UI PR lists the PNGs it changed.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DS-1 | – | `DesignToolbarItem`: the toolbar's eight commands, with titles, symbols, identifiers and the reason each can't run | `Sources/DesignModel/DesignToolbarItems.swift` (new), `Tests/DesignModelTests/DesignToolbarItemsTests.swift` (new) | – | ~180 lines, 2 files |
| DS-2 | – | The page actions under Pages become a `SidebarActionRow`. Nothing else in the Layers panel changes, so it works the same in today's tab and in the sidebar. The core journey asserts both page actions. | `Sources/DesignApp/DesignLayersPanel.swift`, `Tests/AppSnapshotTests/DesignLayersSnapshots.swift`, `UITests/DesignJourneyTests.swift` | – (editor-in-window merged) | ~70, 3 |
| DS-3 | – | The move: `DesignEditor` on `SuiteWindow` and `EditorDetail` with the floating palette, and the headers of the files it touches stop naming `EditorShell`. `DesignTopBar`, `DesignPanel` and `DesignPanelTab` go (`DesignPanelHint` stays in `DesignPanel.swift`). `DesignWindow` drops its tab state and its `.navigationTitle` and fits through `EditorDetailLayout`. The scene drops the hidden title bar and adds `SidebarCommands`. The journey changes listed under Journey steps. | `Sources/DesignApp/DesignEditor.swift`, `Sources/DesignApp/DesignPanel.swift`, `Sources/DesignApp/DesignIntent.swift`, `Sources/DesignApp/DesignWindow.swift`, `Sources/DesignApp/DesignApp.swift`, `UITests/DesignJourneyTests.swift`, `Tests/AppSnapshotTests/DesignAlignSnapshots.swift`, `Tests/AppSnapshotTests/DesignInspectorSnapshots.swift`, `Tests/AppSnapshotTests/DesignLayersSnapshots.swift` | DS-1, DS-2 | ~360, 9 |
| DS-4 | – | The shell journey (steps 1 to 5) with the geometric test | `UITests/DesignJourneyTests+Shell.swift` (new) | DS-3 | ~150, 1 |

## Build waves

- Wave 1: DS-1, DS-2. Independent in this wave: both.
- Wave 2: DS-3. Independent in this wave: DS-3 alone.
- Wave 3: DS-4. Independent in this wave: DS-4 alone.

Longest chain: DS-1 → DS-3 → DS-4 (3), and DS-2 → DS-3 → DS-4 (3). DS-3
can't be split further: the Layers tab leaves the panel in the same commit
that puts it in the sidebar, or the layers disappear from the window in
between.

**Why DS-3 carries the journey's launch check.** Once DS-3 merges, Design
shows no `suite.tools` at launch (the palette waits for a file). The old
`expectEditorShell()` would then fail the next dev run, so the one-line
switch to `expectEditorWindow()` lands in the same PR.

**DS-3's snapshot files.** The three snapshot files build `DesignPanel(model:
tab:)` today. They switch to `DesignInspector` or `DesignLayersPanel`
directly, at today's `editorPanelWidth`. Their PNGs lose the tab bar at the
top. `DesignFileSnapshots` renders the whole `DesignEditor`, so its PNGs
change without an edit, and so do `design-empty-*` and `design-open-*`
from `AppSnapshotTests.design()`. Name every changed PNG in the PR.
`snapshot()` only writes PNGs (there are no recorded goldens on `dev`), so
these are for review. The tests that can fail are the journeys.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| DS-1 | `DesignToolbarItemsTests` (Linux). On a new workspace New and Open have no help, and Save and the three zoom items read "Create or open a file first.". After `newFile()` and one drawn rectangle, Undo's title is "Undo Add Rectangle" and it has no help, and Redo reads "Nothing to redo.". Every disabled item has non-empty help. The eight identifiers are unique, and undo and redo are exactly `design.bar.undo` and `design.bar.redo`. | a command is enabled with nothing to act on, a disabled one is silent, or a journey identifier changes |
| DS-2 | The core journey (dev macOS run) finds `design.page.add` and `design.page.delete` as buttons titled Add Page and Delete Page next to the pages (its existing lookup at line 102 plus one new assertion). With one page, Delete Page is disabled and its help reads "A file keeps at least one page.". `DesignLayersSnapshots` PNGs are re-recorded for review and named in the PR. | the row loses an identifier, its title or its reason |
| DS-3 | Every existing Design journey green on the dev macOS run (`testLaunchShowsWindowShell` through `expectEditorWindow()`, `testNewFileAndEveryTool` over the floating palette, the align, menu and core journeys). The changed PNGs (the three snapshot files, `DesignFileSnapshots`, `design-empty-*`, `design-open-*`) re-recorded and named in the PR. `grep -n "EditorShell" Sources/DesignApp UITests/DesignJourneyTests.swift` finds nothing. `DesignToolsTests` still green. | a journey loses a control it clicks, a tool stops acting, or a panel's look changes |
| DS-4 | `DesignJourneyTests+Shell`, steps 1 to 5, green on the dev macOS run | any frame breaks a geometric rule, or the palette covers a ruler or a handle |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Geometric | On the 1024 × 768 display (window at its visible frame) with the inspector shown, every frame is inside the window: `suite.sidebar`, `suite.viewport`, `suite.status`, `suite.inspector`, the toolbar, the app switcher `suite.switcher` (centered, from editor-in-window EW-8) and each of the toolbar's eight items (hittable beside the switcher, none in the overflow). If they don't all fit, the switcher's spacing steps down first (SuiteUI); the app then drops Zoom Out and Zoom In from the toolbar (they stay in the View menu and on ⌘− and ⌘=), never Save, Undo or Redo. The four columns don't overlap by more than 1 pt. The viewport is at least `contentMinimum`, the inspector at least 304 pt and each tool at least `toolButton`. | DS-4 step 3 and step 5 |
| The floating palette never covers the rulers or the canvas's selection handles at 1024 × 768 | the palette frame clear of the top and leading ruler bands; with a shape on the page's left edge, selected, at Fit Page, the palette clear of the page grown by `anchorHit / 2` | DS-4 step 3 |
| Light and dark | `shell-*` journey shots in both appearances; `design-empty-*` and `design-open-*` PNGs in both | DS-3, DS-4 |
| Audit at or under baseline | `design` keeps only its `identifier` key, at or under 20. A new `offscreen`, `contrast`, `unnamed` or `overlap` count is a raise from 0 that the lane refuses. Fix its cause in this feature, and never raise the baseline. | the dev macOS run after DS-3 and after DS-4 |
| No dead controls | every toolbar item acts or says why; a palette tool that can't act (Pen) keeps its `unavailableHelp` | DS-1, `DesignToolsTests` |
| Contact sheet next to Flare and Halo | the `parity-design-*` shots beside `parity-flare-*`, `parity-photo-*` and `parity-halo-window` (editor-in-window EW-6), plus Design's own `shell-*` shots | done check |

## Done check

- **Journeys green.** The dev macOS run triggered by DS-4 (`feature-done`)
  is green: every Design journey, the new shell journey, and SuiteUI's
  parity journey.
- **Audit zero new.** `design` has no key but `identifier`, and that is at
  or under its baseline. No other app moves.
- **Contact sheet.** Comment `Belt-Contact-Sheet: <run link>` on the
  feature issue. Put Design's `shell-open` and `shell-open-dark` next to the
  same run's `parity-flare-window` and `parity-halo-window`, and the four
  `parity-*-palette` shots side by side, so the captain can see the shells
  and tool boxes match. Add the same run's `parity-design-switcher` beside
  `parity-flare-switcher`, in light and dark (the `shell-open-dark` shot
  shows the dark one).
