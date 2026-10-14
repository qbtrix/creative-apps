# Design blueprint

Design is the suite's vector app for UI and graphic design: pages of frames,
shapes and text you draw, arrange, style, reuse and export. This blueprint is
the gate before the next round of feature code. It records what exists on
`dev`, the v1 line, the planned components, every tier-1 journey, the
use-case contracts with their fakes, the look, the quality bar, and the
features grouped into waves with owned files. Feature packets
(`docs/blueprints/design/features/`) come after the captain approves it.

Read on `origin/dev` 956d946 (2026-10-14), the open and closed `line:design`
issues, and the docs this repo already has: `CLAUDE.md`, `docs/design.md`,
`docs/priorities.md`, `docs/engineering.md`, `docs/review-rubric.md`,
`docs/factory/lead.md`, `docs/blueprints/app-audit.md`, and
`docs/blueprints/flare.md` with its packets as the worked example. The quality
ids (QB-…) are section 6 of `docs/review-rubric.md`; this doc adds Design's
own rows as QD-….

Contents: 0 Status on dev · 1 Brief · 2 Pseudo-C4 · 3 Usage map · 4 Journeys ·
5 Contracts · 6 Look · 7 Quality bar · 8 Coverage and waves · 9 Open
questions · 10 Critic rounds

---

## 0. Status on dev

### What exists

Design is further along than Flare was at its blueprint: the core loop
(create, see, edit with each enabled tool, undo, save, reopen) works end to
end and a journey proves it.

| Area | On dev | Where |
|---|---|---|
| Window | `EditorShell` window (top bar, tool rail, canvas with rulers, Properties and Layers tabs, status line), dark, hidden title bar, one window per file | `DesignApp.swift`, `DesignEditor.swift`, `DesignWindow.swift` |
| Files | New File (a 1440 × 1024 page with a "Desktop" frame), Open, Save, Save As; JSON with sorted keys, `version: 1`; all-or-nothing open with a reason per refusal (`DesignFileError`); Open never replaces a window's file (it opens another window); `-DesignOpenFile` and `-DesignSaveTo` for journeys | `DesignFile.swift`, `DesignWindow.swift` |
| Pages | Add, rename (Model only), delete (refuses the last), select | `DesignWorkspace.swift`, `DesignLayersPanel.swift`, Page menu |
| Tree | Frames and groups hold children; absolute page points; depth-first paint order; ids unique across the file, never reused, minted from a held-id index (#433) | `DesignNode.swift`, `DesignHeldIDs.swift` |
| Tools | Move (V), Frame (F), Rectangle (R), Ellipse (O), Text (T) work; Pen (P) is disabled with "Drawing paths isn't built yet."; a drawing tool returns to Move after one shape | `DesignWorkspace.swift` (`DesignTool`), `DesignDrawing.swift`, `DesignCanvasEditing.swift` |
| Canvas | Click select, Shift-click add or remove (#725), move with subtree, 8 resize handles (Shift keeps aspect, Option from center; corners only, outside, on a small box), arrow nudge (Shift 10), Delete; locked and hidden subtrees never hit; zoom in, zoom out, fit page (window state), Space-drag pan (CanvasViewport) | `DesignCanvasEditing.swift`, `DesignCanvas.swift`, `DesignCanvasMarks.swift` |
| Text | Text click places "Text" and opens an inline editor; commit is one step; empty or cancelled placement leaves nothing | `DesignText.swift`, `DesignTextEditor.swift` |
| Inspector | Header (name, kind, size), Align row (one layer to its frame or page, #716), Layer (Hidden, Locked), Frame (X, Y, W, H scrub fields, one step per run), Fill (color well and hex; text color for text); "Multiple layers selected" with several; locked layers disabled with a reason | `DesignInspector.swift`, `DesignAlignBar.swift`, `DesignInspectorContent.swift`, `DesignLocking.swift` |
| Layers | Pages list with Add Page and Delete Page, then the tree front to back, disclosure follows the Model's expanded set, eye and lock toggles (one step each), current page checkmark | `DesignLayersPanel.swift`, `DesignLayerToggles.swift` |
| Undo | Model-owned history, 100 steps, one named step per edit, coalescing runs (frame edits, nudges), New File undoable with its file URL (#436), refused or no-op edits record nothing | `DesignHistory.swift` |
| Menus | File (New File, Open…, Save, Save As…), Edit (Undo/Redo named, Delete Layer), Page (Add, Delete), Object (Align submenu), View (Zoom In, Zoom Out, Fit Page) | `DesignCommands.swift`, `DesignObjectMenu.swift` |
| Tests | 65 Model test files on Linux (fuzz, edge and undo suites), 13 snapshot files (`design-*`), 5 journeys: `testLaunchShowsWindowShell`, `testNewFileAndEveryTool`, `testEveryMenuOpens`, `testAlignALayer`, `testDrawShapesAddTextAndSave` | `Tests/DesignModelTests/`, `Tests/AppSnapshotTests/Design*`, `UITests/DesignJourneyTests.swift` |
| Audit | Baseline `design: { identifier: 20 }`; no other check counts | `UITests/audit-baseline.json` |

In flight: #753 (corner radius for rectangles and frames, closes #532's first
bullet) and #719 (end the inspector edit run; its fix shipped as #749, so #719
looks superseded). Neither is merged; section 8 assumes #753 merges first and
builds on its `cornerRadius` field.

### What the open issues cover

21 open issues carry `line:design` (listed with their feature in section 8.1):
the rest of tier 1 (#714 align several and distribute, #414 duplicate, #415
clipboard, #416 group, #532 and #752 inspector style rows, #267 text style,
#268 text size jump, #275 undo inside text fields and the close prompt, #270
save state), tier 2 (#418 export, #19 components, #20 variables), tier 3
(#21 wide gamut), five small bugs (#542, #607, #613, #276, #266) and two
quality items shared with SuiteUI (#288 identifiers, #589 group rows).

### What is missing (no open issue yet)

| Gap | Tier | Why it is a gap |
|---|---|---|
| Marquee select | 1 | #413 ("Shift-click and a marquee") closed after Shift-click alone; the canvas has no marquee |
| Move, resize, nudge and delete several layers | 1 | `DesignSelection.swift`: "editing several layers at once is a later issue"; with two selected there are no handles and the inspector shows nothing editable |
| Zoom to selection | 1 | priorities tier 1 item 1; View has no such command |
| Rename a layer or page from the panel | 1 | `renameNode` and `renamePage` exist in the Model, no view calls them |
| Reorder and nest by dragging in Layers; Arrange (forward, backward, front, back) | 1 | `moveNode` only appends to a parent; no view calls it |
| Unsaved-changes state and close prompt | 1 | #270 and #275 mention it; no Model flag exists |
| Opening a bad file has no journey | 1 | `DesignFileError` reasons are Model-tested only |
| A public `DesignPage` init | 1 (by dependency) | fixtures and fakes outside the module can't build a page (found compiling section 5) |

---

## 1. Brief

### The problem

People who design screens, icons, social posts and slides need a fast,
native, free vector tool that saves plain files. Today Design can draw boxes,
ellipses and text on pages and save them, but a working session also needs
selecting many things at once, duplicating, grouping, copy and paste, style
(radius, stroke, opacity, type), and tidy layers. Without those, nobody can
finish a real screen in it.

### Who uses it

- **Interface designers** laying out app and web screens in frames, nesting
  and aligning parts, reusing a button as a component (tier 2).
- **Graphic designers** making posts, banners and simple illustrations:
  shapes, type, color, export to PNG and SVG (export is tier 2).
- **Developers and students** opening a file to read sizes and colors, or
  sketching a layout; they need it to be fast and obvious.

### Non-goals

Raster painting and photo retouching (Photo), animation and timelines
(Flare), compositing (Halo), real-time multi-user editing or cloud sync,
interactive prototype players, a plugin or scripting API, an iPad build,
code generation, and reading or writing any closed file format.

### The v1 line

| In v1 (tier 1, the everyday loop) | Out of v1 |
|---|---|
| Zoom, pan, fit page, zoom to selection | Rulers in other units (#264 is SuiteUI's) |
| Click, Shift-click and marquee select; move, resize, nudge and delete one or several layers | Rotation, skew, flip |
| Draw frames, rectangles, ellipses; place and edit text | Polygon, star, line and arrow tools |
| Inspector: X, Y, W, H, corner radius, fill, fill opacity, stroke color and width, text family, size, weight and alignment | Gradients, images as fills, shadows and blurs, blend modes, per-corner radius, dashed strokes |
| Layers: select, rename, reorder and nest by drag, hide, lock; Arrange menu | Auto Layout values and the layout math (#752's last bullet: section 9, Q2) |
| Duplicate and Option-drag, group and ungroup, cut, copy and paste (also between windows) | Boolean operations, masks, constraints |
| Align (one layer to its frame, several to each other) and distribute | Smart guides and snapping (first item after v1) |
| Undo and redo named for each step; save, Save As, reopen; unsaved-changes dot and close prompt; open errors named | Version history, autosave and crash recovery (section 9, Q4) |

**Tier 2, after the loop (still v1.x, waves 2 and 3):** export to PNG, SVG and
PDF (#418), the Pen tool, components and instances (#19), variables with light
and dark modes (#20).

**Tier 3, not v1:** wide-gamut variables (#21), Auto Layout, prototyping
links, comments, a shared library across files.

### Calls made against the priorities list

| Item | Call | Why |
|---|---|---|
| Marquee | v1 | Selecting several layers is how align, group and duplicate are reached; #413 promised it |
| Pen tool | Tier 2, wave 3 | Basic shapes and frames cover UI layout; a path also needs exact curve bounds from creative-core (section 8.4). The tool stays on the rail, disabled with its reason |
| Auto Layout section of #752 | Not v1 | Storing direction, gap and padding without the layout math gives controls that change nothing on the canvas, which breaks "no dead controls". Ship it with the math (Q2) |
| Close prompt for unsaved changes | v1 | Losing work is worse than any missing feature; #275 already names it |
| Pages | Already built | Tier 2 in priorities, but it shipped with the tree |

---

## 2. Pseudo-C4 (drawn before code)

The same three layers as `docs/engineering.md`: creative-core, then
DesignModel (Linux, where the tests live), then DesignApp on SuiteUI. Design
has no engine of its own in creative-core; its tree, edits and file format
live in DesignModel, which depends only on CoreColor. The machine-readable
form is `docs/blueprints/design/c4-planned.json`, in the shape of
`docs/c4/model.json` plus `"status"` and `"authored": true` on each element.
It is a plan, not the gate's model: the features that add files update
`docs/c4/model.json`'s descriptions (section 8.3 names which).

```
creative-core                     creative-apps
CoreColor ─────────────────────▶  DesignModel ─────────────────▶ DesignApp ◀── SuiteUI
(existing)                        contracts → services/actions   EditorShell window,
path geometry (planned, ───────▶  → live | fakes; workspace,     canvas, panel, menus,
 needs a core issue; Pen only)     tree, history, file codec      pasteboard, export
                                                                 ▲
                                               UITests/DesignJourneyTests*.swift
```

### L2 containers

| Container | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| DesignModel | existing | State, logic and use cases; Linux-safe | `Sources/DesignModel/` | uses CoreColor; read and called by DesignApp |
| DesignApp | existing | The SwiftUI window, reads the Model, sends intents | `Sources/DesignApp/` | builds on SuiteUI; calls DesignModel |
| SuiteUI | existing (another line) | Shell, rows, canvas viewport, probes | `Sources/SuiteUI/` | used by DesignApp; Design asks for parts with `needs-ui` |
| Design journeys | existing | XCUITest journeys and the app audit | `UITests/DesignJourneyTests*.swift` | launch `.build/apps/DesignApp.app` |
| CoreColor | existing (creative-core) | Color spaces | creative-core | used by DesignModel |
| Shared path geometry | planned (creative-core) | Path type, exact curve bounds, hit test, SVG path data | creative-core, needs a new issue | used by `LivePen` (wave 3) only |

### L3 components of DesignModel

| Component | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| Workspace | existing | Pages, selection, tool, text edit, file URL, held ids; from D0-1 also `services`, `marquee` and the saved marker | `DesignWorkspace.swift`, `DesignSelection.swift`, `DesignHeldIDs.swift` | applies every edit through History |
| Node tree | existing | Node and geometry types; D0-1 adds style fields, D2-1 the path and component fields | `DesignNode.swift` | encoded by File codec |
| History | existing | Named undo steps, coalescing, document swaps; F5 adds the saved marker | `DesignHistory.swift` | called by Workspace and Services |
| Canvas gestures | existing | Tool routing for pointer drags; D0-3 adds marquee, several-layer and Option-drag routes | `DesignCanvasEditing.swift`, `DesignDrawing.swift`, `DesignText.swift` | calls Services |
| Inspector logic | existing | Header lines, locks, row toggles, align one layer | `DesignInspectorContent.swift`, `DesignLocking.swift`, `DesignLayerToggles.swift`, `DesignAlign.swift` | read by the panel |
| File codec | existing | JSON open and save, refusal reasons | `DesignFile.swift` | F5 moves the codec into `Live/LiveFiling.swift` |
| Use-case contracts | planned | One protocol per use case, `DesignEdit`, `DesignRefusal`, `DesignIDMint`, value types (section 5) | `Contracts/` | conformed to by Live and Fakes |
| Services and actions | planned | `DesignServices` (`.live`, `.fake`), `NotBuilt`, and `DesignActions`: one workspace method and one help per command, applying a `DesignEdit` as one step | `DesignServices.swift`, `DesignActions.swift` | called by the window's `perform` and the canvas gestures |
| Fixture fakes and fixtures | planned | A fake per use case; named fixture documents | `Fakes/`, `DesignFixtures.swift` | used by snapshots and `-DesignServices fake` journeys |
| Live conformances | planned | The real use cases, one file each | `Live/` | swapped into `.live` by their feature |

### L3 components of DesignApp

| Component | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| Window shell | existing | Scene, `DesignWindow` (`perform`, launch arguments, close prompt from F5), `DesignEditor`, `DesignIntent` | `DesignApp.swift`, `DesignWindow.swift`, `DesignEditor.swift`, `DesignIntent.swift` | calls Services and actions |
| Canvas | existing | `DesignCanvas` on `CanvasViewport`, artwork, selection marks and marquee (split into `DesignSelectionMarks.swift` by D0-4), inline text editor | `DesignCanvas.swift`, `DesignCanvasMarks.swift`, `DesignSelectionMarks.swift`, `DesignTextEditor.swift` | copy and paste hooks call the Pasteboard bridge |
| Panel | existing | Tabs, inspector, Align row, style sections (F3), Layers list, Assets section (wave 3) | `DesignPanel.swift`, `DesignInspector.swift`, `DesignAlignBar.swift`, `DesignLayersPanel.swift`, `DesignInspectorStyle.swift`, `DesignAssetsPanel.swift` | values in, intents out |
| Menus | existing | File, Edit (`DesignEditMenu.swift` from D0-5), Page, Object, View | `DesignCommands.swift`, `DesignObjectMenu.swift`, `DesignEditMenu.swift` | publish `DesignMenu` helps |
| Pasteboard bridge | planned | System pasteboard read and write under the clipboard's type | `DesignPasteboardBridge.swift` | calls `LayerClipboard` through actions |
| Export sheet and rasterizer | planned (wave 3) | Export sheet, PNG and PDF from the artwork view, file writing | `DesignExportSheet.swift`, `DesignRasterizer.swift` | renders the Canvas artwork |
| Pen marks | planned (wave 3) | Anchors and handles of the pen draft | `DesignPenMarks.swift` | needs SuiteUI #706 |
| Variables sheet | planned (wave 3) | Variables grid and the mode switch | `DesignVariablesSheet.swift` | calls `VariableEditing` |

Every existing file under `Sources/DesignModel/`, `Sources/DesignApp/` and
`UITests/Design*.swift` sits in exactly one component of the JSON (checked by
a script while writing this; section 10 records it).

---

## 3. Usage map

Ranked the way `docs/priorities.md` ranks every app: what nearly every
session uses first, then weekly work, then specialist work. Clean-room: only
public sources, no other app opened. No public study measures per-feature
use in vector UI tools, so the tiers come from what beginner courses teach
first, what "learn these shortcuts first" sheets repeat, and the surveys
below; rows marked *inferred* have no direct source and are the first to move
if data turns up.

Sources (the first two are the ones `docs/priorities.md` used for Design):

- [S1] State of design systems 2022-23: https://sympli.io/blog/state-of-design-systems-2022-2023 (components, shared styles and variables as weekly team work).
- [S2] UX tools survey 2022: https://designcompass.org/en/2022/12/07/ux-tools-2022-survey/ (UI design as the main daily activity of the respondents).
- [S3] Design tools survey 2024, method and results (2,220 designers, Nov 2024 to Jan 2025): https://www.uxtools.co/survey/introduction/methodology (UI design and basic prototyping as the most common jobs; tool-level, not feature-level).
- [S4] Apple Human Interface Guidelines, keyboard shortcuts and the standard Edit menu: https://developer.apple.com/design/human-interface-guidelines/keyboards (Cut, Copy, Paste, Duplicate, Undo, Redo, Select All as expected on every Mac editor).
- [S5] Beginner shortcut cheat sheets for vector UI tools, read as a set (the same five actions top every list: frame tool, duplicate, group and ungroup, align, Option-drag to copy). Not linked here because their titles name products; the pattern is common to all of them.
- [S6] W3C SVG 2: https://www.w3.org/TR/SVG2/ (what an exported file must carry: viewBox, rect, ellipse, path, text, clipPath, opacity).

### Tier 1: nearly every session (`p1`)

| # | Feature | Source | State on dev | Issue |
|---|---|---|---|---|
| 1 | Zoom in and out, fit page, pan | S5, priorities | built | – |
| 2 | Zoom to selection | priorities, *inferred* | missing | new gap (F1) |
| 3 | Click and Shift-click select | S5 | built (#725) | – |
| 4 | Marquee select | S5 | missing | new gap (F1); #413 closed without it |
| 5 | Move, resize and nudge one layer | S5 | built | #542, #607 bugs |
| 6 | Move, resize, nudge and delete several layers | S5, *inferred* | missing | new gap (F1) |
| 7 | Draw frames, rectangles, ellipses | S5, S2 | built | #266 frame names |
| 8 | Place and edit text | S2 | built | #268 size jump, #613 |
| 9 | Text family, size, weight, alignment | priorities (#267) | missing | #267 |
| 10 | Inspector X, Y, W, H and fill | priorities (#18) | built | #276 |
| 11 | Corner radius | priorities | in flight | #532 / PR #753 |
| 12 | Fill opacity, stroke color and width | priorities | missing | #752 |
| 13 | Layers: select, hide, lock | priorities (#45) | built | #589 group rows |
| 14 | Layers: rename, reorder and nest by drag; Arrange | priorities (#45), S5 | Model only | new gap (F4) |
| 15 | Duplicate and Option-drag | S5, S4 | missing | #414 |
| 16 | Group and ungroup | S5 | missing | #416 |
| 17 | Cut, copy and paste, also between files | S4 | missing | #415 |
| 18 | Align one layer | S5 | built (#716) | – |
| 19 | Align several, distribute | S5 | missing | #714 |
| 20 | Undo and redo named for each step | S4 | built | #275 (system undo in text fields) |
| 21 | Save, Save As, reopen | priorities, *inferred* | built | – |
| 22 | Unsaved state and close prompt | S4, *inferred* | missing | #270, #275 |
| 23 | Open errors named | *inferred* | built, no journey | new journey (F5) |

### Tier 2: weekly (`p2`)

| Feature | Source | State | Issue |
|---|---|---|---|
| Export PNG (1x, 2x, 3x), SVG, PDF | priorities, S6 | missing | #418 |
| Components and instances | S1 | missing | #19 |
| Variables with light and dark modes | S1 | missing | #20 |
| Pen tool: corners, smooth points, close | S5, *inferred* | disabled with a reason | new gap (wave 3) |
| Pages | priorities | built | – |

### Tier 3: specialist (`p3`)

| Feature | Source | State | Issue |
|---|---|---|---|
| Wide-gamut color variables | priorities | missing | #21 |
| Auto Layout (direction, gap, padding) with the layout math | S1, *inferred* | missing | #752 (last bullet; not v1) |
| Smart guides and snapping | *inferred* | missing | none (first item after v1) |
| Boolean operations, masks | *inferred* | missing | none |
| Prototype links and a player | S3 | missing | none |

---

## 4. Journeys

**Files.** `project.yml`'s Journey template compiles `UITests/Journey.swift`
plus `UITests/<target>.swift` only, so today every feature would append to
one file. SuiteUI #333 (QH-4) changes the template to `UITests/Journey*.swift`
plus `UITests/<target>*.swift` and adds `Journey+Input.swift` (keys with
modifiers, velocity drags, `perf()`). Each Design feature then owns its own
`UITests/DesignJourneyTests+<Area>.swift` with its own `XCTestCase` class.
If #333 is still open when wave 0 starts, D0-6 makes the same one-line
template change itself (project.yml is not protected) and the helpers stay
with #333 (section 9, Q1).

**Modes.** A journey launches with `-DesignFixture <name>` (D0-6: the window
opens that fixture as an unsaved file). It runs on `-DesignServices fake`
while its feature builds the UI, and on the live services once the feature's
live type lands; the feature's last PR removes the flag. Every step takes a
`shot`. Controls carry identifiers `design.<area>.<name>`; titles that change
(Undo names) are found by identifier (`design.bar.undo`).

**Waiting.** No journey asserts timing through an XCUI query: state is
awaited with `waitForExistence` or a value predicate (5 s, as today), and
timing comes from the probe's JSON (section 7).

**Fixtures** (`DesignFixtures`, DesignModel, D0-6; built in code, never read
from disk):

| Fixture | Contents | Used by |
|---|---|---|
| `empty` | New File: one page, the "Desktop" frame | J1–J4 |
| `cards` | Desktop frame 1440 × 1024; inside it rectangles "A" (100, 100, 100 × 80), "B" (300, 140, 200 × 80), "C" (700, 100, 100 × 120); text "Title" (100, 40, 200 × 32); group "Pair" holding two ellipses; rectangle "Locked" (locked); rectangle "Hidden" (hidden) | J5–J15 |
| `two-pages` | `cards` plus a second page "Mobile" 390 × 844 with a frame "Phone" | J12, J16 |
| `crowd` | 2,000 layers: 40 frames of 49 rectangles and one text each | P1–P4, model budgets |
| bad files | written by the test into its temp folder: `not json`, `{"version":99,"pages":[]}`, `{"version":1,"pages":[]}`, a file repeating an id | J16 |

### Tier-1 journeys

| # | Test (file, feature) | Fixture | Steps (each one shot) | Asserts | Empty, error and loading states passed |
|---|---|---|---|---|---|
| J0 | `testLaunchShowsWindowShell` (`DesignJourneyTests.swift`, exists) | none | launch | `expectEditorShell()`; canvas empty state with New File; panel "No Selection" | empty: no file open |
| J1 | `testEveryMenuOpens` (exists; D0-5 extends) | empty | open File, Edit, Page, Object, View; Page > Add Page | each menu's items equal section 6's menu list, enabled or disabled with a tooltip; "Undo Add Page" | empty selection: Edit and Object items disabled with reasons |
| J2 | `testNewFileAndEveryTool` (exists) | empty | ⌘N; `clickEachTool()` | each enabled tool picked; Pen listed disabled with its reason | – |
| J3 | `testDrawShapesAddTextAndSave` (exists; the core loop) | empty | Frame, Rectangle, Ellipse drags; move; resize; Shift-click; Layers eye; Text "Hello"; undo; redo; ⌘S to `-DesignSaveTo`; relaunch with `-DesignOpenFile` | each step's undo name; the reopened file shows its layers | empty canvas, text edit open |
| J4 | `testZoomPanFitAndZoomToSelection` (`+Select`, F1) | cards | ⌘+ twice; Space-drag 200 pt; ⌘0; select "C"; View > Zoom to Selection (⌥⌘2); Escape; check Zoom to Selection is off | zoom pill 200% after two steps from 100%; ruler origin label changed after the pan; "Fit" zoom after ⌘0; after Zoom to Selection "C" is centered (its frame's center within 2 pt of the canvas center, read from `design.canvas.selection` frame) | nothing selected: Zoom to Selection disabled with "Select a layer first." |
| J5 | `testMarqueeMoveResizeSeveral` (`+Select`, F1) | cards | drag a marquee from empty canvas around "A" and "B"; drag "A" 40 pt right; drag the box's bottom-right handle out 20 pt; ⇧→; ⌫; ⌘Z | header reads "2 Layers" after the marquee and "Locked" is not included; "Undo Move" then "Undo Resize", "Undo Nudge", "Undo Delete" each one step; after ⌘Z both layers are back | marquee over only locked and hidden layers selects nothing (Escape state) |
| J6 | `testAlignAndDistributeSeveral` (`+Select`, F1; replaces `testAlignALayer` steps for several) | cards | select A, B, C; Align Top from the inspector; Object > Distribute Horizontally; select A and B; Distribute | Edit menu "Undo Align Top", then "Undo Distribute Horizontally"; with two selected Distribute is disabled with "Select 3 or more layers." | refusal: disabled with reason |
| J7 | `testDuplicateAndOptionDrag` (`+Arrange`, F2) | cards | select "A"; ⌘D; Option-drag "A" 100 pt down; select "Locked" from Layers; ⌘D | Layers shows "A" three times; "Undo Duplicate" after each; the copy of "Locked" is unlocked; nothing selected: Duplicate disabled with "Select a layer first." | empty selection |
| J8 | `testCutCopyPasteAcrossWindows` (`+Arrange`, F2) | cards | select "Pair"; ⌘C; ⌘V; ⌘X on "B"; ⌘N (a second window); ⌘V; rename "A" in Layers, select its text, ⌘C, ⌘V | pasted "Pair" offset 10, 10 with two children; "Undo Paste", "Undo Cut"; the second window holds "B"; the rename field pasted text and the layer count is unchanged | Paste disabled with "The pasteboard holds no Design layers." after copying plain text |
| J9 | `testGroupAndUngroup` (`+Arrange`, F2) | cards | select A and B; ⌘G; ⇧⌘G; select A and "Title" across parents | group row with two children and "Undo Group"; after ⇧⌘G the row is gone and "Undo Ungroup"; across parents Group is disabled with "Select layers that share a parent." | refusal |
| J10 | `testInspectorStyleRows` (`+Style`, F3) | cards | select "A"; Corner radius 12 by typing; drag Opacity to 50%; add a stroke, width 4 with → four times; select "Hidden" from Layers | each value reads back; one undo step per row ("Undo Change Corner Radius", "Undo Change Opacity", "Undo Change Stroke"); keyboard parity on the width row; a hidden layer's rows are disabled with "Show Hidden to change it." | disabled with reason |
| J11 | `testTextFontAndSize` (`+Style`, F3) | cards | select "Title"; size 32; weight Bold; alignment Center; zoom to 50%; double-click "Title", type, Return | rows read back; the committed text's frame equals the editor's frame within 1 pt (no jump, #268); "Undo Edit Text" | text edit open |
| J12 | `testLayersRenameReorderNest` (`+Layers`, F4) | two-pages | double-click "A" row, type "Avatar", Return; drag "C" above "B"; drag "Title" into "Pair"; Object > Arrange > Send to Back on "B"; hide "Pair" from its own row's eye; rename page "Mobile" to "Phone screens" | row reads "Avatar" ("Undo Rename Layer"); order C above B; "Title" nested under Pair; B last; Pair's eye toggled (#589); page renamed; each one step | empty-name rename refused, the row keeps its old name |
| J13 | `testUndoInTextFieldsAndDirtyState` (`+Files`, F5) | cards | type in the X field and press ⌘Z inside the field; Escape; draw a rectangle; check the dot; ⌘S | ⌘Z in the field undid the typing, not a document step (#275); the top bar shows the unsaved dot after the draw and "Saved" after ⌘S (#270) | save in progress shows "Saving…" when slower than 100 ms (QB-L9) |
| J14 | `testCloseWithUnsavedChanges` (`+Files`, F5) | cards | draw; ⌘W; Cancel; ⌘W; Don't Save | the alert names the file; Cancel keeps the window; Don't Save closes it | – |
| J15 | `testEveryControlActsOrSaysWhy` (`+EveryControl`, D0-6) | cards | read `suite.controls`, click each enabled `design.*` control, Escape, ⌘Z | every enabled control changed the shot or a value; every disabled one has a reason. A sweep, never cited by the matrix | – |
| J16 | `testOpenBadFiles` (`+Files`, F5) | bad files | launch with `-DesignOpenFile` on each | the alert reads "It is not a Design file.", "It was made by a newer version of Design (file version 99).", "It has no pages.", "It uses the id node-2 more than once."; the window stays empty | error |
| P1 | `testCanvasDragLatency` (`+PerfCanvas`, F1) | crowd | four velocity drags of 600 pt at 300 pt/s: move a layer, draw a rectangle, resize, marquee; one Space-pan; ⌘+ and ⌘− ten times each | at least 60 samples per drag series; QB-L1 and QD-S1 to QD-S5 (section 7) | – |
| P2 | `testScrubLatency` (`+PerfScrub`, F3) | crowd | velocity drag on the Opacity bar and the X scrub field; type 30 characters into the inline text editor | at least 60 samples per series; QB-L2 and QD-S6 | – |
| P3 | `testLayerListScroll` (`+PerfLayers`, F4) | crowd | scroll Layers end to end, all frames expanded | QD-S10 | – |
| P4 | `testOpenLargeFile` (`+PerfFiles`, F5) | crowd saved then reopened | ⌘O | progress within QB-L9; no stall over QB-L12 | loading |

Tier-2 journeys, written with their packets: `testExportPNGSVGPDF`
(`+Export`; from #418 (c), plus Cancel and a read-only folder),
`testPenCornersAndCurves` (`+Pen`), `testComponentsCreateAndInsert`
(`+Components`) and `testVariablesLightAndDark` (`+Variables`).

---

## 5. Contracts

The use cases as Swift, so the UI track and the logic track build in
parallel. Everything here compiles on Linux: it was built against
DesignModel on `origin/dev` 956d946 with Swift 6.3.3 (the CI image), with the
section 5.1 schema patched in, and a scratch test ran the fakes (marquee,
align, distribute, duplicate, group, clipboard, pen close). None of it is
committed by this PR; tasks D0-1 to D0-3 and D2-1 land it (section 8).

### The rules

- **A use case never touches the workspace.** It reads one `DesignPage` and
  returns a `DesignEdit` (the page's new tree, the new selection, the undo
  name and an optional coalescing key) or throws `DesignRefusal`.
  `DesignWorkspace.apply` records it as exactly one named step; a refusal
  records nothing. That keeps today's invariant ("every document edit
  records exactly one named undo step") without each use case knowing about
  history.
- **Help law.** For every write `w` with a help read `wHelp`, `wHelp(...) ==
  nil` exactly when `w(...)` succeeds and changes something. The disabled
  tooltip is `DesignRefusal.help`. `DesignContractLawTests` (D0-2) runs the
  law over every conformance in `.fake` and `.live` on the `cards` fixture.
- **Ids.** A use case that adds nodes takes a `DesignIDMint` built from the
  workspace's held-id index, so ids never repeat (#296, #303, #433 stay
  fixed).
- **`.live` and `.fake`.** `.live` holds `NotBuilt` for each use case until
  its feature lands, so its controls are disabled with "<Feature> isn't
  built yet." and never act; `.fake` is for snapshots and fake-mode
  journeys. Existing single-layer behaviour (move, resize, nudge, delete,
  align one layer, the file codec) keeps running on today's code until its
  live type replaces it, so nothing that works today regresses.
- **No engine type in a contract.** Design has no creative-core document; the
  contracts use DesignModel's own value types only.

### 5.1 Schema (D0-1, D2-1)

D0-1 adds to `DesignNode` (all with defaults, so every file written today
still opens; `init(from:)` uses `decodeIfPresent` for each, and a test opens
a file saved before the fields existed):

```swift
public var cornerRadius: Double = 0          // #753 adds this first; D0-1 keeps its name
public var opacity: Double = 1               // 0...1
public var stroke: DesignStroke? = nil
public var textStyle: DesignTextStyle = .default
```

and gives `DesignPage` a public memberwise `init(id:name:frameWidth:frameHeight:nodes:)`
(fixtures and the contract law tests outside the module need one; none
exists today). `DesignWorkspace` gains `public internal(set) var services:
DesignServices = .live` and `public internal(set) var marquee: DesignRect?`.

D2-1 adds `case path` to `DesignNodeKind` (with its symbol `scribble`, its
fill label in `DesignInspectorContent.swift`, which is the one other switch
over the kind), `public var path: DesignPath? = nil` and `public var
componentID: String? = nil` on `DesignNode`, and `components` and
`variables` to the file. The file version becomes 2; version 1 files still
open, and a version-1 build refuses a version-2 file with its existing
"made by a newer version" message.

### 5.2 Shared types (`Contracts/EditContracts.swift`, D0-2)

```swift
// Contracts/EditContracts.swift: what every Design use case returns and the
// ids it mints. A use case never touches the workspace: it reads one page and
// returns a DesignEdit, which DesignWorkspace.apply records as exactly one named
// undo step (or merges into the run with the same coalescing key). A refused
// call throws DesignRefusal and the workspace records nothing. For every write
// `w` with a help read `wHelp`, `wHelp(...) == nil` exactly when `w(...)`
// succeeds and changes something (DesignContractLawTests checks every fake and
// live conformance against that law). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One edit to the selected page: its whole new node tree and selection, named for Undo.
public struct DesignEdit: Sendable, Equatable {
    /// The undo step's name, without "Undo": "Duplicate", "Group", "Align Left".
    public var name: String
    /// The selected page's top-level nodes after the edit, back to front.
    public var nodes: [DesignNode]
    /// The selected layers after the edit, primary last.
    public var selection: [String]
    /// A run of edits with the same key is one undo step (a scrub, a drag); nil never merges.
    public var coalescingKey: String?

    public init(name: String, nodes: [DesignNode], selection: [String], coalescingKey: String? = nil) {
        (self.name, self.nodes, self.selection, self.coalescingKey) = (name, nodes, selection, coalescingKey)
    }
}

/// Why a use case refused. `help` is the sentence a disabled control shows as its tooltip.
public enum DesignRefusal: Error, Equatable, Sendable {
    case nothingSelected
    case locked(String)
    case hidden(String)
    case notSameParent
    case tooFew(needed: Int)
    case notAGroup(String)
    case notAContainer(String)
    case intoItself(String)
    case unknownID(String)
    case unreadable
    case unchanged
    /// The use case has no live conformance yet (DesignServices.live before its feature lands).
    case notBuilt(String)

    public var help: String {
        switch self {
        case .nothingSelected: "Select a layer first."
        case .locked(let name): "Unlock \(name) to change it."
        case .hidden(let name): "Show \(name) to change it."
        case .notSameParent: "Select layers that share a parent."
        case .tooFew(let needed): "Select \(needed) or more layers."
        case .notAGroup(let name): "\(name) isn't a group."
        case .notAContainer(let name): "\(name) can't hold other layers."
        case .intoItself(let name): "\(name) can't go inside itself."
        case .unknownID(let id): "\(id) isn't on this page."
        case .unreadable: "The pasteboard holds no Design layers."
        case .unchanged: "Nothing would change."
        case .notBuilt(let feature): "\(feature) isn't built yet."
        }
    }
}

/// Mints node ids no page or node of the file holds. The workspace makes one from its held-id
/// index and counter before a use case runs, and takes `counter` back after a successful edit.
public struct DesignIDMint: Sendable, Equatable {
    /// Every id the file held when the mint was made.
    public let taken: Set<String>
    /// The highest "node-N" handed out so far.
    public private(set) var counter: Int
    /// The ids this mint handed out, in order.
    public private(set) var minted: [String] = []

    public init(taken: Set<String>, after counter: Int) {
        (self.taken, self.counter) = (taken, Swift.max(counter, 0))
    }

    /// The next "node-N" that is neither taken nor minted. Never repeats an id.
    public mutating func nextNodeID() -> String {
        repeat { counter += 1 } while taken.contains("node-\(counter)")
        let id = "node-\(counter)"
        minted.append(id)
        return id
    }
}
```

### 5.3 Value types (`Contracts/StyleTypes.swift`, D0-2)

```swift
// Contracts/StyleTypes.swift: the style values DesignNode gains in task D0-1
// (corner radius, opacity, stroke, text style) and the tier-2 values (paths,
// components, variables) that D2-1 adds to the file. Value types, Codable, so
// they go into a file as they are. Linux-safe.

/// A stroke drawn centered on the shape's outline.
public struct DesignStroke: Sendable, Hashable, Codable {
    public var color: DesignColor
    /// Points; 0 draws nothing. The inspector clamps it to 0...1000.
    public var width: Double

    public init(color: DesignColor, width: Double) {
        (self.color, self.width) = (color, width)
    }

    public static let `default` = DesignStroke(color: .black, width: 1)
}

public enum DesignTextAlignment: String, CaseIterable, Sendable, Codable { case leading, center, trailing }

/// How a text layer's text is set. The app measures and draws it; the Model only stores it.
public struct DesignTextStyle: Sendable, Hashable, Codable {
    /// A family name the system font list offers; "System" is the system font.
    public var family: String
    /// Points, 1...1000.
    public var size: Double
    /// 100...900 in steps of 100, as CSS and OpenType name weights.
    public var weight: Int
    public var alignment: DesignTextAlignment

    public init(family: String, size: Double, weight: Int, alignment: DesignTextAlignment) {
        (self.family, self.size, self.weight, self.alignment) = (family, size, weight, alignment)
    }

    public static let `default` = DesignTextStyle(family: "System", size: 16, weight: 400, alignment: .leading)
}

/// The style properties the inspector edits, for help lookups.
public enum DesignStyleProperty: String, CaseIterable, Sendable { case cornerRadius, opacity, stroke, textStyle }

/// One pen anchor: where it sits and its two curve handles, absolute page points. No handle is a corner.
public struct DesignAnchor: Sendable, Hashable, Codable {
    public var point: DesignPoint
    public var handleIn: DesignPoint?
    public var handleOut: DesignPoint?

    public init(point: DesignPoint, handleIn: DesignPoint? = nil, handleOut: DesignPoint? = nil) {
        (self.point, self.handleIn, self.handleOut) = (point, handleIn, handleOut)
    }
}

/// A pen path: anchors joined by cubic segments (a straight one when both handles are absent).
public struct DesignPath: Sendable, Hashable, Codable {
    public var anchors: [DesignAnchor]
    public var isClosed: Bool

    public init(anchors: [DesignAnchor], isClosed: Bool) {
        (self.anchors, self.isClosed) = (anchors, isClosed)
    }
}

/// A component: a named master tree that instances draw. Its nodes are relative to its own top-left.
public struct DesignComponent: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public var name: String
    public var width: Double
    public var height: Double
    public var nodes: [DesignNode]

    public init(id: String, name: String, width: Double, height: Double, nodes: [DesignNode]) {
        (self.id, self.name, self.width, self.height, self.nodes) = (id, name, width, height, nodes)
    }
}

public enum DesignMode: String, CaseIterable, Sendable, Codable { case light, dark }

public enum DesignVariableValue: Sendable, Hashable, Codable {
    case color(DesignColor)
    case number(Double)
}

/// A named value with one value per mode.
public struct DesignVariable: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public var name: String
    public var light: DesignVariableValue
    public var dark: DesignVariableValue

    public init(id: String, name: String, light: DesignVariableValue, dark: DesignVariableValue) {
        (self.id, self.name, self.light, self.dark) = (id, name, light, dark)
    }

    public func value(in mode: DesignMode) -> DesignVariableValue { mode == .light ? light : dark }
}

public enum DesignExportFormat: String, CaseIterable, Sendable { case png, svg, pdf }

/// One file an export writes.
public struct DesignExportItem: Sendable, Equatable {
    public var nodeID: String
    /// "Card.png", "Card 2.png": unique in the folder.
    public var fileName: String
    /// The item's size in points, and in pixels at the export scale (equal for SVG and PDF).
    public var width: Double
    public var height: Double
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(nodeID: String, fileName: String, width: Double, height: Double, pixelWidth: Int, pixelHeight: Int) {
        (self.nodeID, self.fileName, self.width, self.height) = (nodeID, fileName, width, height)
        (self.pixelWidth, self.pixelHeight) = (pixelWidth, pixelHeight)
    }
}

public enum DesignDistributeAxis: String, CaseIterable, Sendable {
    case horizontal, vertical

    public var title: String { self == .horizontal ? "Distribute Horizontally" : "Distribute Vertically" }
}

public enum DesignArrangeStep: String, CaseIterable, Sendable {
    case bringToFront, bringForward, sendBackward, sendToBack

    public var title: String {
        switch self {
        case .bringToFront: "Bring to Front"
        case .bringForward: "Bring Forward"
        case .sendBackward: "Send Backward"
        case .sendToBack: "Send to Back"
        }
    }
}
```

### 5.4 The use-case protocols (`Contracts/UseCases.swift`, D0-2)

Already-built use cases keep their workspace methods and get no new
protocol: new file, pages (add, rename, delete), add a node, draw, text
edit, the row toggles, the frame and fill rows, undo and redo.

```swift
// Contracts/UseCases.swift: one protocol per Design use case. Reads take the
// page; writes take the page (and a mint when they add nodes) and return a
// DesignEdit or throw DesignRefusal. Each write's comment names its undo case:
// **single "Name"** (one step), or **coalescing "key"** (a run with that key is
// one step). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: Tier 1

/// Marquee: which layers a dragged rectangle on empty canvas selects.
public protocol MarqueeSelecting: Sendable {
    /// The visible, unlocked layers `rect` touches, in paint order. Candidates are the children of
    /// `parentID` (the frame the marquee started in), or the page's top-level layers when nil. A
    /// hidden or locked layer, or one inside a hidden or locked layer, is never picked.
    func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String]
}

/// Move, resize, nudge and delete for one or more selected layers.
public protocol SelectionTransforming: Sendable {
    func transformHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Coalescing "move": every selected layer with its subtree, by `delta` from the gesture start.
    func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "resize": the selection's box by `handle`; each layer scales inside the box.
    func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "nudge": 1 pt, or 10 pt with `large`.
    func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Single "Delete" (one layer: "Delete <Kind>").
    func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// Align to the selection's bounds (or the enclosing frame or page for one layer), and distribute.
public protocol LayerAligning: Sendable {
    func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String?
    /// Single, named `edge.title`. Locked layers count toward the bounds but don't move.
    func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String?
    /// Single, named `axis.title`. Needs three or more layers; the outer two stay.
    func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// Duplicate (Command-D) and the copy an Option-drag moves.
public protocol LayerDuplicating: Sendable {
    func duplicateHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Duplicate". Each copy sits right above its original in the same parent, moved by
    /// `offset` (10, 10 for Command-D; zero for Option-drag), unlocked; the copies are the selection.
    func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                   mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
    /// `node` and its subtree with fresh ids from `mint`; everything else equal. The clipboard reuses it.
    func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode
}

/// Group (Command-G) and Ungroup (Shift-Command-G).
public protocol LayerGrouping: Sendable {
    func groupHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Group". The group's frame is the union; it takes the topmost layer's place; nothing moves.
    func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
    func ungroupHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Ungroup". Each selected group's children take its place, in order; the children are the selection.
    func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// Cut, Copy and Paste of layers through the system pasteboard (the app moves the bytes).
public protocol LayerClipboard: Sendable {
    /// The pasteboard type the app reads and writes.
    var pasteboardType: String { get }
    func copyHelp(_ ids: [String], on page: DesignPage) -> String?
    /// The selected layers, children included, as bytes for the pasteboard.
    func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data
    /// Whether `data` holds layers `paste` can add. Paste is disabled otherwise.
    func canPaste(_ data: Data) -> Bool
    /// Single "Paste". Fresh ids; into `parentID` (a selected frame) or the top level; offset by
    /// (10, 10) when a copy would land exactly on a layer with the same name and frame.
    func paste(_ data: Data, into parentID: String?, on page: DesignPage,
               mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
}

/// Stacking order and nesting from the Layers panel and Object > Arrange.
public protocol LayerOrdering: Sendable {
    func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String?
    /// Single "Move Layer". `index` counts the new parent's children back to front, after removal.
    func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String?
    /// Single, named `step.title`. Within each layer's own parent.
    func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// The inspector's style rows: corner radius, opacity, stroke and text style.
public protocol StyleEditing: Sendable {
    func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String?
    /// Coalescing "radius". Clamped to 0...half the shorter side; rectangles and frames only.
    func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "opacity". Clamped to 0...1.
    func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "stroke". nil removes the stroke; width clamped to 0...1000.
    func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "text-style". Text layers only; size clamped to 1...1000, weight to 100...900.
    func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// What View > Zoom to Selection shows.
public protocol ViewFraming: Sendable {
    /// The union of the visible selected layers' frames; nil with none (the command is then off).
    func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect?
}

/// The file codec behind Open, Save and Save As.
public protocol DocumentFiling: Sendable {
    /// Same document, same bytes (sorted keys). Refuses what `decode` would refuse.
    func encode(_ document: DesignDocument) throws(DesignFileError) -> Data
    /// All or nothing: a refused file throws and the caller keeps what it had.
    func decode(_ data: Data) throws(DesignFileError) -> DesignDocument
}

/// What a file holds. `components` and `variables` stay empty until wave 2 (D2-1).
public struct DesignDocument: Sendable, Equatable {
    public var pages: [DesignPage]
    public var components: [DesignComponent]
    public var variables: [DesignVariable]

    public init(pages: [DesignPage], components: [DesignComponent] = [], variables: [DesignVariable] = []) {
        (self.pages, self.components, self.variables) = (pages, components, variables)
    }
}

// MARK: Tier 2

/// File > Export: what to write and the SVG text (PNG and PDF are rendered by DesignApp).
public protocol ExportPlanning: Sendable {
    func exportHelp(_ ids: [String], on page: DesignPage) -> String?
    /// The selected layers, or every top-level frame when `ids` is empty; names made unique against `existing`.
    func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
              existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem]
    /// The layer as an SVG document: viewBox in its points, hidden layers left out, frames clip.
    func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String
}

/// The Pen tool: click for corners, drag for smooth points, click the first anchor to close.
public protocol PathDrawing: Sendable {
    /// The draft after a press at `point`; closes it when `point` is within `tolerance` of the first anchor.
    func press(at point: DesignPoint, draft: DesignPath?, tolerance: Double) -> DesignPath
    /// The draft's last anchor made smooth, its out handle at `point` and its in handle mirrored.
    func dragHandle(to point: DesignPoint, draft: DesignPath) -> DesignPath
    /// The tight bounds of the path's curves (not of its handles).
    func bounds(of path: DesignPath) -> DesignRect?
    /// Single "Add Path". Refused with fewer than two anchors.
    func commit(_ draft: DesignPath, into parentID: String?, on page: DesignPage,
                mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
}

/// Components and instances.
public protocol ComponentLibrary: Sendable {
    func createHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Create Component": the selected frame becomes the component and its first instance.
    func create(from id: String, on page: DesignPage, library: [DesignComponent],
                mint: inout DesignIDMint) throws(DesignRefusal) -> (edit: DesignEdit, library: [DesignComponent])
    /// Single "Insert <name>": an instance centered on `center`, selected.
    func insert(_ componentID: String, centeredOn center: DesignPoint, on page: DesignPage,
                library: [DesignComponent], mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
    /// What an instance draws: the component's nodes moved to the instance's frame; nil when it is missing.
    func resolve(_ instance: DesignNode, library: [DesignComponent]) -> [DesignNode]?
}

/// Variables with a light and a dark value.
public protocol VariableEditing: Sendable {
    /// Single "Add Variable". Refused when the name is empty or taken.
    func add(named name: String, value: DesignVariableValue, to variables: [DesignVariable],
             id: String) throws(DesignRefusal) -> [DesignVariable]
    /// Single "Rename Variable".
    func rename(_ id: String, to name: String, in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable]
    /// Single "Delete Variable". Layers bound to it keep their own fill.
    func remove(_ id: String, from variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable]
    /// Coalescing "variable-<id>-<mode>".
    func set(_ id: String, _ mode: DesignMode, to value: DesignVariableValue,
             in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable]
    func resolve(_ id: String, in mode: DesignMode, variables: [DesignVariable]) -> DesignVariableValue?
}
```

### 5.5 Workspace actions (`DesignActions.swift`, D0-3)

What the views call. Signatures only; D0-3 writes the bodies, each running
its use case on the selected page and calling `apply`.

```swift
// DesignActions.swift: the workspace methods the window, the menus and the canvas call for every
// command that runs a use case, and the help each control shows. `help(c) == nil` exactly when
// `run(c)` changes the document. Each successful run applies one DesignEdit as one named undo step
// (merged into the run with the same coalescing key); a refusal records nothing. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A command on the selection that a menu item, a top bar item or a key runs.
public enum DesignCommand: Hashable, Sendable {
    case duplicate, group, ungroup, delete
    case nudge(DesignDirection, large: Bool)
    case align(DesignAlignEdge)
    case distribute(DesignDistributeAxis)
    case arrange(DesignArrangeStep)
}

/// One inspector style change on the selection.
public enum DesignStyleChange: Hashable, Sendable {
    case cornerRadius(Double), opacity(Double), stroke(DesignStroke?), textStyle(DesignTextStyle)

    public var property: DesignStyleProperty {
        switch self {
        case .cornerRadius: .cornerRadius
        case .opacity: .opacity
        case .stroke: .stroke
        case .textStyle: .textStyle
        }
    }
}

extension DesignWorkspace {
    /// Why `command` can't run now; nil when it would change the document.
    public func help(_ command: DesignCommand) -> String?
    public mutating func run(_ command: DesignCommand) throws(DesignRefusal)

    public func copyHelp() -> String?
    /// The selected layers as pasteboard bytes; the document doesn't change.
    public func copySelection() throws(DesignRefusal) -> Data
    /// Copy, then delete as one step named "Cut".
    public mutating func cutSelection() throws(DesignRefusal) -> Data
    public func canPaste(_ data: Data) -> Bool
    /// Into the selected frame, else the top level of the selected page.
    public mutating func paste(_ data: Data) throws(DesignRefusal)
    /// The pasteboard type the bridge reads and writes.
    public var pasteboardType: String

    public func moveLayerHelp(_ id: String, into parentID: String?, at index: Int) -> String?
    public mutating func moveLayer(_ id: String, into parentID: String?, at index: Int) throws(DesignRefusal)

    public func styleHelp(_ property: DesignStyleProperty) -> String?
    public mutating func setStyle(_ change: DesignStyleChange) throws(DesignRefusal)

    /// What View > Zoom to Selection shows; nil turns the command off.
    public var zoomToSelectionRect: DesignRect?
    /// Edit > Select All: every visible, unlocked layer at the selection's level (the top of the page when nothing is selected).
    public mutating func selectAll()

    /// Swaps the services (the window does it once, from `-DesignServices fake`).
    public mutating func useServices(_ services: DesignServices)

    /// A mint over the file's ids, for a use case that adds nodes.
    func mint() -> DesignIDMint
    /// Records `edit` on the selected page as one step and takes the mint's counter.
    mutating func apply(_ edit: DesignEdit, mint: DesignIDMint? = nil)
}
```

### 5.6 Services and NotBuilt (`DesignServices.swift`, D0-2)

As compiled. In D0-2, `.fake` holds `NotBuilt` for `export`, `pen`,
`components` and `variables` (their fakes need the D2-1 schema); D2-1 swaps
in the four tier-2 fakes. `.live.filing` stays `NotBuilt` only on paper:
D0-2 sets it to `LiveFiling`, today's codec moved behind the protocol by F5
(until F5, `filing` is not called; `DesignFile.swift` keeps serving Open and
Save).

```swift
// DesignServices.swift: the use cases a workspace runs on. `.live` is what the
// shipping app uses: each use case's live type once its feature lands, and
// NotBuilt before that, so the control is disabled with "<Feature> isn't built
// yet." and never acts. `.fake` is the fixture set the snapshots and the
// journeys launched with `-DesignServices fake` use. Two service sets are equal
// when their names are, so DesignWorkspace stays Equatable. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct DesignServices: Sendable, Equatable {
    public let name: String
    public var marquee: any MarqueeSelecting
    public var transforming: any SelectionTransforming
    public var aligning: any LayerAligning
    public var duplicating: any LayerDuplicating
    public var grouping: any LayerGrouping
    public var clipboard: any LayerClipboard
    public var ordering: any LayerOrdering
    public var styling: any StyleEditing
    public var framing: any ViewFraming
    public var filing: any DocumentFiling
    public var export: any ExportPlanning
    public var pen: any PathDrawing
    public var components: any ComponentLibrary
    public var variables: any VariableEditing

    public static func == (a: DesignServices, b: DesignServices) -> Bool { a.name == b.name }

    public static let fake = DesignServices(
        name: "fake", marquee: FakeMarquee(), transforming: FakeTransforming(), aligning: FakeAligning(),
        duplicating: FakeDuplicating(), grouping: FakeGrouping(), clipboard: FakeClipboard(), ordering: FakeOrdering(),
        styling: FakeStyling(), framing: FakeFraming(), filing: FakeFiling(), export: FakeExport(), pen: FakePen(),
        components: FakeComponents(), variables: FakeVariables())

    /// Each feature swaps its NotBuilt for its live type in the PR that makes it work.
    public static let live = DesignServices(
        name: "live", marquee: NotBuilt("Marquee selection"), transforming: NotBuilt("Editing several layers"),
        aligning: NotBuilt("Align and distribute"), duplicating: NotBuilt("Duplicate"), grouping: NotBuilt("Group"),
        clipboard: NotBuilt("Copy and paste"), ordering: NotBuilt("Reordering layers"), styling: NotBuilt("Style editing"),
        framing: NotBuilt("Zoom to Selection"), filing: NotBuilt("Saving"), export: NotBuilt("Export"),
        pen: NotBuilt("The Pen tool"), components: NotBuilt("Components"), variables: NotBuilt("Variables"))
}

/// Every use case, refusing with `.notBuilt(feature)`; every help says so.
public struct NotBuilt: Sendable {
    public let feature: String
    public init(_ feature: String) { self.feature = feature }
    var refusal: DesignRefusal { .notBuilt(feature) }
    var help: String { refusal.help }
}

extension NotBuilt: MarqueeSelecting {
    public func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String] { [] }
}

extension NotBuilt: SelectionTransforming {
    public func transformHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                       on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerAligning {
    public func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String? { help }
    public func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String? { help }
    public func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerDuplicating {
    public func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                          mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode { node }
}

extension NotBuilt: LayerGrouping {
    public func groupHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func ungroupHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerClipboard {
    public var pasteboardType: String { "org.creativesuite.design.layers" }
    public func copyHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data { throw refusal }
    public func canPaste(_ data: Data) -> Bool { false }
    public func paste(_ data: Data, into parentID: String?, on page: DesignPage,
                      mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerOrdering {
    public func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? { help }
    public func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? { help }
    public func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: StyleEditing {
    public func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String? { help }
    public func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: ViewFraming {
    public func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect? { nil }
}

extension NotBuilt: DocumentFiling {
    public func encode(_ document: DesignDocument) throws(DesignFileError) -> Data { throw .noFile }
    public func decode(_ data: Data) throws(DesignFileError) -> DesignDocument { throw .unreadable }
}

extension NotBuilt: ExportPlanning {
    public func exportHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
                     existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] { throw refusal }
    public func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String { throw refusal }
}

extension NotBuilt: PathDrawing {
    public func press(at point: DesignPoint, draft: DesignPath?, tolerance: Double) -> DesignPath {
        draft ?? DesignPath(anchors: [], isClosed: false)
    }
    public func dragHandle(to point: DesignPoint, draft: DesignPath) -> DesignPath { draft }
    public func bounds(of path: DesignPath) -> DesignRect? { nil }
    public func commit(_ draft: DesignPath, into parentID: String?, on page: DesignPage,
                       mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: ComponentLibrary {
    public func createHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func create(from id: String, on page: DesignPage, library: [DesignComponent],
                       mint: inout DesignIDMint) throws(DesignRefusal) -> (edit: DesignEdit, library: [DesignComponent]) { throw refusal }
    public func insert(_ componentID: String, centeredOn center: DesignPoint, on page: DesignPage,
                       library: [DesignComponent], mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func resolve(_ instance: DesignNode, library: [DesignComponent]) -> [DesignNode]? { nil }
}

extension NotBuilt: VariableEditing {
    public func add(named name: String, value: DesignVariableValue, to variables: [DesignVariable],
                    id: String) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func rename(_ id: String, to name: String, in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func remove(_ id: String, from variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func set(_ id: String, _ mode: DesignMode, to value: DesignVariableValue,
                    in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func resolve(_ id: String, in mode: DesignMode, variables: [DesignVariable]) -> DesignVariableValue? { nil }
}
```

### 5.7 Fakes (`Fakes/DesignFakes.swift`, D0-2; tier 2 in D2-1)

```swift
// Fakes/DesignFakes.swift: one fixture fake per use case, so views, snapshots
// and journeys (`-DesignServices fake`) build before the live conformance. A
// fake keeps its protocol's undo case and the help law, but acts on the page's
// top-level layers only and ignores locks and hidden layers: it is a stand-in,
// never shipped as `.live`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The top-level layers of `page` named in `ids`, in paint order.
private func topLevel(_ ids: [String], _ page: DesignPage) -> [DesignNode] {
    page.nodes.filter { ids.contains($0.id) }
}

private func union(_ frames: [DesignRect]) -> DesignRect? {
    guard let first = frames.first else { return nil }
    return frames.dropFirst().reduce(first) { box, f in
        let (x, y) = (Swift.min(box.x, f.x), Swift.min(box.y, f.y))
        return DesignRect(x: x, y: y, width: Swift.max(box.maxX, f.maxX) - x, height: Swift.max(box.maxY, f.maxY) - y)
    }
}

/// Changes the named top-level layers; throws `.nothingSelected` when none is top-level, `.unchanged` when nothing moved.
private func change(_ ids: [String], _ page: DesignPage, _ name: String, key: String? = nil,
                    _ body: (inout DesignNode) -> Void) throws(DesignRefusal) -> DesignEdit {
    guard !topLevel(ids, page).isEmpty else { throw .nothingSelected }
    var nodes = page.nodes
    for index in nodes.indices where ids.contains(nodes[index].id) { body(&nodes[index]) }
    guard nodes != page.nodes else { throw .unchanged }
    return DesignEdit(name: name, nodes: nodes, selection: ids, coalescingKey: key)
}

/// The help law for a fake write: nil exactly when `body` succeeds.
private func help(_ body: () throws(DesignRefusal) -> DesignEdit) -> String? {
    do { _ = try body(); return nil } catch { return error.help }
}

public struct FakeMarquee: MarqueeSelecting {
    public init() {}
    public func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String] {
        page.nodes.filter { n in
            n.frame.x <= rect.maxX && rect.x <= n.frame.maxX && n.frame.y <= rect.maxY && rect.y <= n.frame.maxY
        }.map(\.id)
    }
}

public struct FakeTransforming: SelectionTransforming {
    public init() {}
    public func transformHelp(_ ids: [String], on page: DesignPage) -> String? {
        topLevel(ids, page).isEmpty ? DesignRefusal.nothingSelected.help : nil
    }
    public func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change(ids, page, "Move", key: "move") { $0.translate(by: delta) }
    }
    public func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                       on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change(ids, page, "Resize", key: "resize") {
            $0.frame = $0.frame.resized(handle, by: delta, keepAspect: modifiers.contains(.shift), fromCenter: modifiers.contains(.option))
        }
    }
    public func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let step = large ? 10.0 : 1.0
        let delta = switch direction {
        case .up: DesignPoint(x: 0, y: -step)
        case .down: DesignPoint(x: 0, y: step)
        case .left: DesignPoint(x: -step, y: 0)
        case .right: DesignPoint(x: step, y: 0)
        }
        return try change(ids, page, "Nudge", key: "nudge") { $0.translate(by: delta) }
    }
    public func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        guard !topLevel(ids, page).isEmpty else { throw .nothingSelected }
        return DesignEdit(name: "Delete", nodes: page.nodes.filter { !ids.contains($0.id) }, selection: [])
    }
}

public struct FakeAligning: LayerAligning {
    public init() {}
    public func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String? {
        help { () throws(DesignRefusal) in try align(edge, ids, on: page) }
    }
    public func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let page1 = DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)
        let selected = topLevel(ids, page)
        guard let box = selected.count == 1 ? page1 : union(selected.map(\.frame)) else { throw .nothingSelected }
        return try change(ids, page, edge.title) { node in
            let f = node.frame
            let x: Double = switch edge {
            case .left: box.x
            case .center: box.x + (box.width - f.width) / 2
            case .right: box.maxX - f.width
            case .top, .middle, .bottom: f.x
            }
            let y: Double = switch edge {
            case .top: box.y
            case .middle: box.y + (box.height - f.height) / 2
            case .bottom: box.maxY - f.height
            case .left, .center, .right: f.y
            }
            node.translate(by: DesignPoint(x: x - f.x, y: y - f.y))
        }
    }
    public func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String? {
        help { () throws(DesignRefusal) in try distribute(axis, ids, on: page) }
    }
    public func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let horizontal = axis == .horizontal
        let selected = topLevel(ids, page).sorted { horizontal ? $0.frame.x < $1.frame.x : $0.frame.y < $1.frame.y }
        guard selected.count >= 3, let first = selected.first, let last = selected.last else { throw .tooFew(needed: 3) }
        let start = horizontal ? first.frame.maxX : first.frame.maxY
        let end = horizontal ? last.frame.x : last.frame.y
        let inner = selected.dropFirst().dropLast()
        let gap = (end - start - inner.reduce(0) { $0 + (horizontal ? $1.frame.width : $1.frame.height) }) / Double(inner.count + 1)
        var targets: [String: Double] = [:]
        var cursor = start + gap
        for node in inner {
            targets[node.id] = cursor
            cursor += (horizontal ? node.frame.width : node.frame.height) + gap
        }
        return try change(ids, page, axis.title) { node in
            guard let to = targets[node.id] else { return }
            node.translate(by: horizontal ? DesignPoint(x: to - node.frame.x, y: 0) : DesignPoint(x: 0, y: to - node.frame.y))
        }
    }
}

public struct FakeDuplicating: LayerDuplicating {
    public init() {}
    public func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? {
        topLevel(ids, page).isEmpty ? DesignRefusal.nothingSelected.help : nil
    }
    public func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                          mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        guard !topLevel(ids, page).isEmpty else { throw .nothingSelected }
        var (nodes, copies) = ([DesignNode](), [String]())
        for node in page.nodes {
            nodes.append(node)
            guard ids.contains(node.id) else { continue }
            var copy = copySubtree(node, mint: &mint)
            copy.translate(by: offset)
            copy.isLocked = false
            nodes.append(copy)
            copies.append(copy.id)
        }
        return DesignEdit(name: "Duplicate", nodes: nodes, selection: copies)
    }
    public func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode {
        var children: [DesignNode] = []
        for child in node.children { children.append(copySubtree(child, mint: &mint)) }
        var copy = DesignNode(id: mint.nextNodeID(), name: node.name, kind: node.kind, frame: node.frame,
                              children: children, isHidden: node.isHidden, isLocked: node.isLocked,
                              fill: node.fill, text: node.text)
        copy.cornerRadius = node.cornerRadius
        copy.opacity = node.opacity
        copy.stroke = node.stroke
        copy.textStyle = node.textStyle
        return copy
    }
}

public struct FakeGrouping: LayerGrouping {
    public init() {}
    public func groupHelp(_ ids: [String], on page: DesignPage) -> String? {
        topLevel(ids, page).isEmpty ? DesignRefusal.nothingSelected.help : nil
    }
    public func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        let members = topLevel(ids, page)
        guard let box = union(members.map(\.frame)),
              let top = page.nodes.lastIndex(where: { ids.contains($0.id) }) else { throw .nothingSelected }
        let group = DesignNode(id: mint.nextNodeID(), name: "Group", kind: .group, frame: box, children: members)
        var nodes = page.nodes
        nodes.insert(group, at: top + 1)
        nodes.removeAll { ids.contains($0.id) }
        return DesignEdit(name: "Group", nodes: nodes, selection: [group.id])
    }
    public func ungroupHelp(_ ids: [String], on page: DesignPage) -> String? {
        topLevel(ids, page).contains { $0.kind == .group } ? nil : DesignRefusal.notAGroup(ids.last ?? "The selection").help
    }
    public func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        guard topLevel(ids, page).contains(where: { $0.kind == .group }) else { throw .notAGroup(ids.last ?? "The selection") }
        var (nodes, selection) = ([DesignNode](), [String]())
        for node in page.nodes {
            guard ids.contains(node.id), node.kind == .group else { nodes.append(node); continue }
            nodes += node.children
            selection += node.children.map(\.id)
        }
        return DesignEdit(name: "Ungroup", nodes: nodes, selection: selection)
    }
}

public struct FakeClipboard: LayerClipboard {
    public init() {}
    public var pasteboardType: String { "org.creativesuite.design.layers" }
    public func copyHelp(_ ids: [String], on page: DesignPage) -> String? {
        topLevel(ids, page).isEmpty ? DesignRefusal.nothingSelected.help : nil
    }
    public func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data {
        let nodes = topLevel(ids, page)
        guard !nodes.isEmpty else { throw .nothingSelected }
        do { return try JSONEncoder().encode(nodes) } catch { throw .unreadable }
    }
    public func canPaste(_ data: Data) -> Bool { (try? JSONDecoder().decode([DesignNode].self, from: data)) != nil }
    public func paste(_ data: Data, into parentID: String?, on page: DesignPage,
                      mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        guard let nodes = try? JSONDecoder().decode([DesignNode].self, from: data), !nodes.isEmpty else { throw .unreadable }
        var pasted: [DesignNode] = []
        for node in nodes {
            var copy = FakeDuplicating().copySubtree(node, mint: &mint)
            copy.translate(by: DesignPoint(x: 10, y: 10))
            pasted.append(copy)
        }
        return DesignEdit(name: "Paste", nodes: page.nodes + pasted, selection: pasted.map(\.id))
    }
}

public struct FakeOrdering: LayerOrdering {
    public init() {}
    public func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? {
        help { () throws(DesignRefusal) in try move(id, into: parentID, at: index, on: page) }
    }
    public func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        guard parentID == nil else { throw .notAContainer(parentID ?? "") }
        guard let from = page.nodes.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        var nodes = page.nodes
        let node = nodes.remove(at: from)
        nodes.insert(node, at: Swift.min(Swift.max(index, 0), nodes.count))
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: "Move Layer", nodes: nodes, selection: [id])
    }
    public func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? {
        help { () throws(DesignRefusal) in try arrange(step, ids, on: page) }
    }
    public func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        guard let id = ids.last, let from = page.nodes.firstIndex(where: { $0.id == id }) else { throw .nothingSelected }
        let to = switch step {
        case .bringToFront: page.nodes.count - 1
        case .bringForward: from + 1
        case .sendBackward: from - 1
        case .sendToBack: 0
        }
        var edit = try move(id, into: nil, at: to, on: page)
        edit.name = step.title
        return edit
    }
}

public struct FakeStyling: StyleEditing {
    public init() {}
    public func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String? {
        topLevel(ids, page).isEmpty ? DesignRefusal.nothingSelected.help : nil
    }
    public func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change(ids, page, "Change Corner Radius", key: "radius") {
            $0.cornerRadius = Swift.min(Swift.max(radius, 0), Swift.min($0.frame.width, $0.frame.height) / 2)
        }
    }
    public func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change(ids, page, "Change Opacity", key: "opacity") { $0.opacity = Swift.min(Swift.max(opacity, 0), 1) }
    }
    public func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change(ids, page, "Change Stroke", key: "stroke") { $0.stroke = stroke }
    }
    public func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change(ids, page, "Change Text Style", key: "text-style") { $0.textStyle = style }
    }
}

public struct FakeFraming: ViewFraming {
    public init() {}
    public func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect? { union(topLevel(ids, page).map(\.frame)) }
}

/// Keeps documents in memory as JSON; refuses bytes that don't decode.
public struct FakeFiling: DocumentFiling {
    public init() {}
    public func encode(_ document: DesignDocument) throws(DesignFileError) -> Data {
        do { return try JSONEncoder().encode(document.pages) } catch { throw .unreadable }
    }
    public func decode(_ data: Data) throws(DesignFileError) -> DesignDocument {
        guard let pages = try? JSONDecoder().decode([DesignPage].self, from: data) else { throw .unreadable }
        guard !pages.isEmpty else { throw .noPages }
        return DesignDocument(pages: pages)
    }
}
```

```swift
// Fakes/DesignTierTwoFakes.swift (D2-1): the tier-2 fakes. Same rules as DesignFakes.swift.
// Uses `union` and `topLevel`, which D0-2 puts in Fakes/FakeSupport.swift (internal, not private)
// rather than at the top of DesignFakes.swift as compiled here.

public struct FakeExport: ExportPlanning {
    public init() {}
    public func exportHelp(_ ids: [String], on page: DesignPage) -> String? {
        page.nodes.isEmpty ? "There's nothing on this page to export." : nil
    }
    public func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
                     existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] {
        let items = ids.isEmpty ? page.nodes.filter { $0.kind == .frame } : topLevel(ids, page)
        guard !items.isEmpty else { throw .nothingSelected }
        let k = format == .png ? Swift.max(scale, 1) : 1
        return items.map {
            DesignExportItem(nodeID: $0.id, fileName: "\($0.name).\(format.rawValue)", width: $0.frame.width, height: $0.frame.height,
                             pixelWidth: Int($0.frame.width.rounded()) * k, pixelHeight: Int($0.frame.height.rounded()) * k)
        }
    }
    public func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String {
        guard let node = topLevel([id], page).first else { throw .unknownID(id) }
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(node.frame.width) \(node.frame.height)\"/>"
    }
}

public struct FakePen: PathDrawing {
    public init() {}
    public func press(at point: DesignPoint, draft: DesignPath?, tolerance: Double) -> DesignPath {
        var path = draft ?? DesignPath(anchors: [], isClosed: false)
        if let first = path.anchors.first, path.anchors.count > 1,
           Swift.abs(first.point.x - point.x) <= tolerance, Swift.abs(first.point.y - point.y) <= tolerance {
            path.isClosed = true
        } else {
            path.anchors.append(DesignAnchor(point: point))
        }
        return path
    }
    public func dragHandle(to point: DesignPoint, draft: DesignPath) -> DesignPath {
        var path = draft
        guard let last = path.anchors.last else { return path }
        let mirrored = DesignPoint(x: 2 * last.point.x - point.x, y: 2 * last.point.y - point.y)
        path.anchors[path.anchors.count - 1] = DesignAnchor(point: last.point, handleIn: mirrored, handleOut: point)
        return path
    }
    /// The anchors' box (handles ignored); the live type bounds the curves exactly.
    public func bounds(of path: DesignPath) -> DesignRect? {
        guard let first = path.anchors.first?.point else { return nil }
        let rest = path.anchors.dropFirst().map { DesignRect(x: $0.point.x, y: $0.point.y, width: 0, height: 0) }
        return union([DesignRect(x: first.x, y: first.y, width: 0, height: 0)] + rest)
    }
    public func commit(_ draft: DesignPath, into parentID: String?, on page: DesignPage,
                       mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        guard draft.anchors.count >= 2, let box = bounds(of: draft) else { throw .tooFew(needed: 2) }
        var node = DesignNode(id: mint.nextNodeID(), name: "Path", kind: .path,
                              frame: DesignRect(x: box.x, y: box.y, width: Swift.max(box.width, 1), height: Swift.max(box.height, 1)))
        node.path = draft
        return DesignEdit(name: "Add Path", nodes: page.nodes + [node], selection: [node.id])
    }
}

public struct FakeComponents: ComponentLibrary {
    public init() {}
    public func createHelp(_ ids: [String], on page: DesignPage) -> String? {
        topLevel(ids, page).first?.kind == .frame ? nil : "Select a frame to make it a component."
    }
    public func create(from id: String, on page: DesignPage, library: [DesignComponent],
                       mint: inout DesignIDMint) throws(DesignRefusal) -> (edit: DesignEdit, library: [DesignComponent]) {
        guard let frame = topLevel([id], page).first, frame.kind == .frame else { throw .nothingSelected }
        let component = DesignComponent(id: "component-\(library.count + 1)", name: frame.name,
                                        width: frame.frame.width, height: frame.frame.height, nodes: frame.children)
        var nodes = page.nodes
        for index in nodes.indices where nodes[index].id == id {
            nodes[index].kind = .instance
            nodes[index].componentID = component.id
            nodes[index].children = []
        }
        return (DesignEdit(name: "Create Component", nodes: nodes, selection: [id]), library + [component])
    }
    public func insert(_ componentID: String, centeredOn center: DesignPoint, on page: DesignPage,
                       library: [DesignComponent], mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        guard let component = library.first(where: { $0.id == componentID }) else { throw .unknownID(componentID) }
        var node = DesignNode(id: mint.nextNodeID(), name: component.name, kind: .instance,
                              frame: DesignRect(x: center.x - component.width / 2, y: center.y - component.height / 2,
                                                width: component.width, height: component.height))
        node.componentID = componentID
        return DesignEdit(name: "Insert \(component.name)", nodes: page.nodes + [node], selection: [node.id])
    }
    public func resolve(_ instance: DesignNode, library: [DesignComponent]) -> [DesignNode]? {
        library.first { $0.id == instance.componentID }?.nodes
    }
}

public struct FakeVariables: VariableEditing {
    public init() {}
    public func add(named name: String, value: DesignVariableValue, to variables: [DesignVariable],
                    id: String) throws(DesignRefusal) -> [DesignVariable] {
        guard !name.isEmpty, !variables.contains(where: { $0.name == name }) else { throw .unchanged }
        return variables + [DesignVariable(id: id, name: name, light: value, dark: value)]
    }
    public func rename(_ id: String, to name: String, in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] {
        guard let index = variables.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        var result = variables
        result[index].name = name
        return result
    }
    public func remove(_ id: String, from variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] {
        guard variables.contains(where: { $0.id == id }) else { throw .unknownID(id) }
        return variables.filter { $0.id != id }
    }
    public func set(_ id: String, _ mode: DesignMode, to value: DesignVariableValue,
                    in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] {
        guard let index = variables.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        var result = variables
        if mode == .light { result[index].light = value } else { result[index].dark = value }
        return result
    }
    public func resolve(_ id: String, in mode: DesignMode, variables: [DesignVariable]) -> DesignVariableValue? {
        variables.first { $0.id == id }?.value(in: mode)
    }
}
```

### 5.8 Which journey each contract serves

| Contract | Journeys | Feature |
|---|---|---|
| `MarqueeSelecting` | J5, P1 | F1 |
| `SelectionTransforming` | J5, P1 | F1 |
| `LayerAligning` | J6 | F1 |
| `ViewFraming` | J4 | F1 |
| `LayerDuplicating` | J7 | F2 |
| `LayerGrouping` | J9 | F2 |
| `LayerClipboard` | J8 | F2 |
| `StyleEditing` | J10, J11, P2 | F3 |
| `LayerOrdering` | J12, P3 | F4 |
| `DocumentFiling` | J3, J13, J14, J16, P4 | F5 |
| `ExportPlanning` | `testExportPNGSVGPDF` | F6 |
| `PathDrawing` | `testPenCornersAndCurves` | F7 |
| `ComponentLibrary` | `testComponentsCreateAndInsert` | F8 |
| `VariableEditing` | `testVariablesLightAndDark` | F9 |

---

## 6. Look

Design keeps everything `docs/design.md` already says for an editor shell
(dark `EditorShell`, hidden title bar, flat bars, glass only where SuiteUI
puts it). The house reference for inspector rows is Flare's easing editor
(`docs/blueprints/flare-easing-editor.md`): Studio rows, `StudioScrubRow` for
numbers with a range, `ChoiceChips` for a few named choices, SuiteUI
components only, every drag or typed value ending in one `onEnd` so it is one
undo step.

### What Design adds to docs/design.md

These rules land in `docs/design.md` (a Design section) with the first wave-1
PR that needs them; this blueprint does not edit that shared file.

1. **Exact coordinates stay `ScrubField`; ranged values are Studio rows.** X,
   Y, W, H keep their scrub fields (pixels to one decimal). Corner radius,
   opacity (shown as a whole percent) and stroke width use `StudioScrubRow`.
   Text weight and alignment are `ChoiceChips`; family is a menu `Picker`;
   colors are `InspectorColorWellRow` (swatch plus hex).
2. **Several layers selected.** The header reads "<n> Layers"; a row whose
   value differs reads "Mixed" in secondary text (no marker); typing or
   scrubbing sets every selected layer; one undo step.
3. **Frame names sit above their frame**, outside it, in caption type, one
   size at any zoom, clipped by nothing (#266).
4. **Selection marks.** One layer: outline and handles (today's). Several:
   each layer's outline, the dashed `SelectionOutline` around them all, and
   the 8 handles on that box. Marquee: a 1 pt accent outline over a 10%
   accent fill, in the overlay, never clipped by the page.
5. **Rename in place.** A layer or page row renames on double-click or
   Return, through `SidebarRow`'s rename (SuiteUI #577, #108); an empty name
   is refused and the old one stays.
6. **Status line** gains the selection count ("2 Layers") next to zoom and
   page size; the top bar's save status shows the unsaved dot (#270, needs
   SuiteUI #339).

### Screens and their components

Components are SuiteUI unless named `Design*`. "Needs" names a SuiteUI issue
the screen waits on; until it lands the screen uses the plain placeholder
CLAUDE.md asks for.

| Screen | Region or state | Uses | Needs |
|---|---|---|---|
| Main window | Top bar: "Design" menu, document menu, New, Open, Save, Undo, Redo, zoom out, fit, zoom in; Export… (wave 3, the one filled primary); save status | `EditorTopBar`, `EditorBarMenu`, `EditorBarItem`, `EditorBarDivider` | #339 (outlined items, primary, save status) |
| Main window | Tool rail: Move V, Frame F, Rectangle R, Ellipse O, Text T, Pen P (disabled with its reason until wave 3) | `ToolbarGroup(style: .rail)` | – |
| Main window | Canvas: page, artwork, frame names, selection marks, marquee, inline text editor, pen draft (wave 3); empty state with New File | `CanvasViewport`, `SelectionOutline`, `CanvasMarks`, `EmptyStateView`, `DesignArtwork`, `DesignSelectionMarks`, `DesignTextOverlay`, `DesignPenMarks` | #273 (handles into SuiteUI; not blocking), #706 (anchor mark, wave 3), #264 (ruler unit reads px) |
| Main window | Status line: zoom, page size, selection count, last message, tool | `ViewerStatusBar` | #340 (pills; name and API kept) |
| Properties tab | One layer: header, Align row, Layer (Hidden, Locked), Frame (X, Y, W, H), Corner radius, Fill (color, opacity), Stroke (color, width, add and remove), Text (family, size, weight, alignment) | `InspectorHeader`, `InspectorSection`, `InspectorAction`, `ScrubField`, `StudioScrubRow`, `InspectorColorWellRow`, `ChoiceChips`, `Picker`, `Toggle(.checkbox)` | #745 / #718 (public `onEnd` on `ScrubField` and the color row; Design has a local end today) |
| Properties tab | Several layers: "<n> Layers", Align row with Distribute, rows reading "Mixed" | as above, plus `InspectorAction` for Distribute | – |
| Properties tab | Page only: page name, size (read only) | `InspectorHeader`, `InspectorRow` | – |
| Properties tab | Nothing open: "No Selection" with how to start | `EmptyStateView` | – |
| Layers tab | Pages (rename, add, delete, current checkmark), layer tree (rename, drag to reorder and nest, eye, lock, dimmed when hidden), context menu (Rename, Duplicate, Group, Delete, Arrange) | `List` in the sidebar style, `SidebarRow`, `DisclosureGroup`, `EditorBarItem` | #589 (group row toggles), #577 and #108 (rename), #73 (context menus), #111 |
| Layers tab | Assets section (wave 3): components with Insert | `SidebarSection`, `SidebarRow`, `InspectorAction`, `EmptyStateView` ("No components yet. Select a frame and choose Create Component.") | – |
| Alerts | Open failure (reason from `DesignFileError`), close with unsaved changes (Save, Don't Save, Cancel) | system alert | – |
| Export sheet (wave 3) | Format (PNG, SVG, PDF) as `ChoiceChips`, scale 1x/2x/3x, the item list, progress with Cancel, an error row naming the failed file | `ChoiceChips`, `InspectorSection`, `ProgressView`, `InspectorAction` | – |
| Variables sheet (wave 3) | `Grid` of Name, Light, Dark; add, rename, delete; Light/Dark preview switch in the top bar | `Grid`, `InspectorColorWellRow`, `ScrubField`, `Picker(.segmented)` | – |

### Menu bar

Every top bar command is here; an item that can't run is disabled with its
help, never hidden.

- **File**: New File ⌘N, Open… ⌘O, Save ⌘S, Save As… ⇧⌘S, Export… ⇧⌘E (wave 3), Close ⌘W (with the unsaved prompt).
- **Edit**: Undo <step> ⌘Z, Redo <step> ⇧⌘Z, Cut ⌘X, Copy ⌘C, Paste ⌘V, Duplicate ⌘D, Delete ⌫, Select All ⌘A. In a focused text field Undo, Redo, Cut, Copy, Paste and Select All act on the text (#275, #415).
- **Page**: Add Page, Rename Page…, Delete Page.
- **Object**: Group ⌘G, Ungroup ⇧⌘G; Arrange ▸ Bring to Front ⇧⌘], Bring Forward ⌘], Send Backward ⌘[, Send to Back ⇧⌘[; Align ▸ the six edges, Distribute Horizontally, Distribute Vertically; Create Component ⌥⌘K (wave 3).
- **View**: Zoom In ⌘=, Zoom Out ⌘−, Fit Page ⌘0, Zoom to Selection ⌥⌘2; Light / Dark preview (wave 3); Variables… (wave 3).

---

## 7. Quality bar

Every row says what measures it and where it runs: **Linux** (`scripts/ci`,
so every PR), **macOS CI** (the `macOS` job on `dev`), or **local** (a Mac
with Xcode: `scripts/ui-test`, then `.build/ui-screens/perf-*.json` and
`contact-sheet.html`). Gates follow `docs/review-rubric.md` "How gates are
set": a screen-side row ships report-only, and after ten green CI runs its
gate is the CI p95 × 1.5, never tighter than the device target.

### 7.1 Speed budgets, input to screen, per interactive tool

Each tool has two halves. The **model half** is the Model work one input
causes, timed on Linux now (`Tests/DesignModelTests/DesignBudgetTests.swift`,
median and p95 of 200 runs on the `crowd` fixture; debug CI gates are 10 ×
the device target, as the rubric does). D0-6 adds the timing helper
(`Tests/DesignModelTests/DesignBudget.swift`) and QD-S8, QD-S9 and QD-S11;
each feature puts its rows in its own `Design<Area>BudgetTests.swift`, so
the test names below are `<file>.<test>`. The **screen half** is frames late
from the event to the first frame that shows it, read from SuiteUI's
`FrameProbe` (#330) by the perf journeys P1 to P4 through `perf()` (#333).
Until #330 lands the screen half cannot be measured anywhere, so those rows
are recorded as blocked in each lead's RECORD.md and the model half gates
alone (section 9, Q3).

| id | Tool or input | Model half: device / Linux debug gate | Screen half (device target) | Test |
|---|---|---|---|---|
| QD-S1 | Move tool: one drag step on a frame with 50 children (rewind, translate, preview) | ≤ 1 ms / ≤ 10 ms | p95 ≤ 2 frames late (QB-L1) | `DesignSelectBudgetTests.moveStep`; P1 move |
| QD-S2 | Frame, Rectangle, Ellipse: one draw step | ≤ 1 ms / ≤ 10 ms | p95 ≤ 2 frames late | `DesignSelectBudgetTests.drawStep`; P1 draw |
| QD-S3 | Resize handle: one step, one layer and 20 layers | ≤ 1 ms / ≤ 10 ms | p95 ≤ 2 frames late | `DesignSelectBudgetTests.resizeStep`; P1 resize |
| QD-S4 | Marquee: one step (query 2,000 layers, set selection) | ≤ 1 ms / ≤ 10 ms | p95 ≤ 2 frames late | `DesignSelectBudgetTests.marqueeStep`; P1 marquee |
| QD-S5 | Space-pan and zoom keys | none (view state) | pan p95 ≤ 2 frames late; a zoom key repaints within 2 frames | P1 pan, zoom |
| QD-S6 | Text tool: one keystroke in the inline editor | `setTextDraft` ≤ 0.1 ms / ≤ 1 ms | p95 ≤ 2 frames late | `DesignStyleBudgetTests.textDraftStep`; P2 typing |
| QD-S7 | Inspector scrub (opacity, radius, stroke width, X) | `setStyle` / `setNodeFrame` step ≤ 0.5 ms / ≤ 5 ms, coalesced to one step | p95 ≤ 2 frames late (QB-L2) | `DesignStyleBudgetTests.scrubStep`; P2 |
| QD-S8 | Hit test per pointer move | ≤ 0.5 ms / ≤ 5 ms on 2,000 layers | – | `DesignBudgetTests.hitTest` |
| QD-S9 | Any command that changes the document (`apply` plus one history record) | ≤ 1 ms / ≤ 10 ms | – | `DesignBudgetTests.applyStep` |
| QD-S10 | Layers list with every row expanded (2,000 rows) | row build ≤ 5 ms / ≤ 50 ms | scroll p95 frame interval ≤ 1.5 refreshes (QB-L10) | `DesignLayersBudgetTests.layerRows`; P3 |
| QD-S11 | Open and save the `crowd` file | decode and encode ≤ 50 ms / ≤ 500 ms | progress within 100 ms (QB-L9); no main-thread stall over 2 refreshes (QB-L12) | `DesignBudgetTests.fileRoundTrip`; P4 |
| QD-S12 | Export (wave 3): SVG of the Desktop frame of `crowd`; PNG at 2x | SVG ≤ 100 ms / ≤ 1 s | PNG progress within 100 ms; 2x PNG of 1440 × 1024 written ≤ 1 s | `DesignExportBudgetTests.svgExport`; `testExportPNGSVGPDF` |

### 7.2 App-audit checks that apply

All six checks in `Tests/AppAuditTests/Checks/` run on every Design journey
shot (macOS CI; locally through `scripts/ui-test`); the baseline only goes
down.

| Check | Design today | Target | How Design gets there |
|---|---|---|---|
| `identifier` | 20 | 0 | Each feature gives `design.<area>.<name>` identifiers to the controls of the views it owns; the SuiteUI part (top bar, rail, tabs, inspector rows) comes from SuiteUI issues (#288 lists both) |
| `disabled-dim` | 0 | 0 | Disabled-with-reason controls use SuiteUI's dimming, never a custom opacity |
| `overlap` | 0 | 0 | The layout journey (7.3) shoots each width |
| `contrast` | 0 | 0 | Secondary text only through `SuiteColor.textSecondary` |
| `offscreen` | 0 | 0 | The layout journey at 880 × 560 and 1024 × 768 |
| `unnamed` | 0 | 0 | Every icon-only control keeps a title (the rail, Align row, row toggles) |

### 7.3 Layout spec

Checked at five window sizes: 880 × 560 (`SuiteSize.windowMinimum`),
1024 × 768 (the CI runner's display), 1280 × 800, 1440 × 900 and
1920 × 1080. `testLayoutAtWidths` (`+Layout`, D0-6) launches with
`-DesignWindowSize <w>x<h>` (D0-6 adds the argument) on `cards` with "A"
selected, shoots each size, and asserts from element frames, to 0.5 pt:

1. Rail, canvas and panel sit side by side with no gap or overlap; the panel
   is 280 pt; the canvas is at least 440 pt wide (`contentMinimum`).
2. Top bar items don't overlap and none is cut off; at 880 the items keep
   their titles or collapse to icons with their titles as tooltips, never
   truncated text.
3. In the Properties tab, the value column's leading edge is the same x in
   every section (Frame, Corner radius, Fill, Stroke, Text) and the locked
   hint sits in that column (#276).
4. In Layers, every row's eye and lock toggles share one x for the eyes and
   one for the locks, whatever the row's depth.
5. The status pills are on one line, untruncated, from 1024 up; at 880 the
   message pill is the one that shortens.
6. The audit's `overlap` and `offscreen` counts for these shots are 0.

### 7.4 Fidelity: output equals a reference

| id | Check | Reference | Runs |
|---|---|---|---|
| QD-V1 | Save is stable: open then save gives the same bytes, for every fixture and for a version-1 file written before D0-1 | the fixture's committed JSON in `Tests/DesignModelTests/Fixtures/` | Linux |
| QD-V2 | The canvas draws what the file holds: the `cards` canvas matches its golden within QB-V2 (channel 2/255, ≤ 0.5% pixels), Dark and Dark + Increase Contrast | `Tests/AppSnapshotTests/Golden/design-canvas-cards-*.png` (#331, #332) | macOS CI |
| QD-V3 | Curves stay curves: an ellipse, a rounded rectangle and (wave 3) a pen curve reach the drawing layer as curve elements, never line segments | element kinds of the built `Path` | macOS CI (`DesignArtworkPathTests`) |
| QD-V4 | Grouping and ungrouping move nothing: every leaf frame is equal before and after, and the canvas golden is unchanged | the pre-group frames; the golden | Linux; macOS CI |
| QD-V5 | Duplicate and paste copy faithfully: the copy equals the original except ids, the offset and the lock | the original subtree | Linux |
| QD-V6 | Align and distribute land exactly: three rectangles at x 10, 50, 200 aligned left all have x 10; widths 20, 40, 20 spanning 0...300 distribute to equal gaps (≤ 1e-9) | #714's numbers | Linux |
| QD-V7 | Text doesn't jump: the committed text's frame equals the editor's at 25%, 50%, 100% and 200% zoom (#268) | the editor frame | macOS CI (`DesignTextScaleTests`) |
| QD-V8 | SVG export (wave 3) equals a reference document for the `cards` Desktop frame: viewBox, one element per visible layer, clipPath for the frame, escaped text, opacity and stroke attributes | `Tests/DesignModelTests/Fixtures/cards-desktop.svg` | Linux |
| QD-V9 | PNG export (wave 3) of a frame equals the canvas golden of that frame (QB-V4) | the QD-V2 golden | macOS CI |

### 7.5 Feel

The rubric's QB-F1 to QB-F6 apply to every feature. Design's tests for
them: `DesignToolsTests` (an enabled tool's drag changes the document; a
disabled one has help), `DesignContractLawTests` (help nil exactly when the
write changes something, for every conformance), each journey reading the
Edit menu's undo name after every gesture (QB-F3), the keyboard step on one
Studio row and one scrub field in J10 (QB-F4), and goldens for the marquee
and the several-layer selection box under Increase Contrast (QB-F5, once
#332 lands).

---

## 8. Coverage and waves

### 8.1 Every open line:design issue

| Issue | Title (short) | Tier | Feature |
|---|---|---|---|
| #752 | Fill opacity, stroke, Auto Layout | p1 | F3 `style-rows` (opacity, stroke); Auto Layout bullet: not v1 (Q2) |
| #714 | Align several, distribute | p1 | F1 `select-several` |
| #613 | Lock mid text edit drops the typing | p3 | F4 `layers-panel` (lock commits the edit first, in `DesignWorkspace.swift`) |
| #607 | Arrows nudge a layer in a hidden group | p3 | F1 `select-several` (`DesignCanvasEditing.swift`) |
| #589 | Group row's toggles unreachable | quality | F4 `layers-panel`, after the SuiteUI side of #589 |
| #542 | Edit mid drag leaves a stray undo step | p3 | F1 `select-several` (`DesignCanvasEditing.swift`) |
| #532 | Corner radius, stroke, Auto Layout | p1 | Radius: PR #753 (before wave 0); rest is #752 → F3 |
| #418 | Export PNG, SVG, PDF | p2 | F6 `export` (wave 3) |
| #416 | Group and ungroup | p1 | F2 `copy-group` |
| #415 | Cut, copy, paste | p1 | F2 `copy-group` |
| #414 | Duplicate, Option-drag | p1 | F2 `copy-group` |
| #288 | Controls without identifiers | p2 | Spread: D0-4 and D0-5 (window, top bar, menus), then each wave-1 feature for the views it owns; the SuiteUI part goes to SuiteUI. Closes when the `identifier` count is 0 |
| #276 | Locked hint in the gutter | p3 | F3 `style-rows` |
| #275 | System undo lost in text fields; close prompt | p1 | F5 `files-history` |
| #270 | Save stays bright after saving | p3 | F5 `files-history` |
| #268 | Text jumps size on commit | p1 | F3 `style-rows` |
| #267 | Stroke, opacity, text size | p1 | F3 `style-rows` (Align is done, #716) |
| #266 | Frame names inside the frame | p2 | F3 `style-rows` (the artwork painter) |
| #21 | Wide-gamut variables | p3 | Not v1 |
| #20 | Variables, light and dark | p2 | F9 `variables` (wave 3) |
| #19 | Components panel | p2 | F8 `components` (wave 3) |

Gaps with no issue (each lead files a `gap` issue when it starts): marquee,
several-layer transform and zoom to selection (F1); rename, reorder, nest and
Arrange (F4); the open-error journey (F5); the Pen tool (F7); the public
`DesignPage` init (D0-1). Open PR #719 duplicates the fix that shipped as
#749 and can close (Q6).

### 8.2 Waves

A wave starts when everything it waits on has merged. No two features in a
wave own the same file; across waves a file changes hands only after the
earlier wave merged. "Tests" means new files in `Tests/DesignModelTests/`
unless a path says otherwise; journeys are `UITests/DesignJourneyTests+<Area>.swift`;
snapshots are in `Tests/AppSnapshotTests/`. Paths below drop the
`Sources/DesignModel/` and `Sources/DesignApp/` prefixes where the file name
says which target (`Live/`, `Contracts/`, `Fakes/` are DesignModel).

#### Wave 0: `design-seams` (one feature, tasks in order)

Waits on: PR #753 merged (it adds `cornerRadius`); SuiteUI #333 for the
journey template, or D0-6 makes the one-line template change (Q1). Engine:
none.

| Task | Behavior | Owned files |
|---|---|---|
| D0-1 | Style schema with old files still opening; public `DesignPage` init; `services` and `marquee` on the workspace | `DesignNode.swift`, `DesignWorkspace.swift`, `DesignFile.swift`; tests `DesignStyleSchemaTests.swift`, `Fixtures/v1-before-style.json` |
| D0-2 | Contracts, `DesignServices`, `NotBuilt`, tier-1 fakes, the contract law | `Contracts/EditContracts.swift`, `Contracts/StyleTypes.swift`, `Contracts/UseCases.swift`, `DesignServices.swift`, `Fakes/FakeSupport.swift`, `Fakes/DesignFakes.swift`; tests `DesignContractLawTests.swift`, `DesignIDMintTests.swift` |
| D0-2b | One stub per tier-1 live type, forwarding to `NotBuilt` (`LiveFiling` to today's codec), and `.live` naming them, so no later feature edits `DesignServices.swift` | `Live/LiveMarquee.swift`, `Live/LiveTransforming.swift`, `Live/LiveAligning.swift`, `Live/LiveFraming.swift`, `Live/LiveDuplicating.swift`, `Live/LiveGrouping.swift`, `Live/LiveClipboard.swift`, `Live/LiveOrdering.swift`, `Live/LiveStyling.swift`, `Live/LiveFiling.swift`, `DesignServices.swift` |
| D0-3 | `DesignActions` (section 5.5) and the gesture routes: marquee on an empty-canvas drag, several-layer move and resize, Option-drag copies | `DesignActions.swift`, `DesignCanvasEditing.swift`; tests `DesignActionsTests.swift`, `DesignGestureRouteTests.swift` |
| D0-4 | Every new intent, `perform` for each, launch arguments `-DesignServices`, `-DesignFixture`, `-DesignWindowSize`; marquee mark; selection marks split out; pasteboard bridge with the canvas and Layers copy and paste hooks; rename presentation state | `DesignIntent.swift`, `DesignWindow.swift`, `DesignCanvas.swift`, `DesignCanvasMarks.swift`, `DesignSelectionMarks.swift`, `DesignPasteboardBridge.swift`, `DesignLayersPanel.swift` |
| D0-5 | Menus: Edit (Cut, Copy, Paste, Duplicate, Select All), Page (Rename Page…), Object (Group, Ungroup, Arrange, Distribute), View (Zoom to Selection); every item disabled with its help | `DesignCommands.swift`, `DesignEditMenu.swift`, `DesignObjectMenu.swift`; snapshots `DesignEditMenuSnapshots.swift`, `DesignPageMenuSnapshots.swift`; `UITests/DesignJourneyTests.swift` (J1's item list) |
| D0-6 | Fixtures, the budget helper and the shared budget rows, the every-control sweep and the layout journey | `DesignFixtures.swift`; tests `DesignFixturesTests.swift`, `DesignBudget.swift`, `DesignBudgetTests.swift`; `UITests/DesignJourneyTests+EveryControl.swift`, `UITests/DesignJourneyTests+Layout.swift`; `project.yml` only if #333 is open |

D0-2 and D0-4 also update `docs/c4/model.json`'s `design-model-sources` and
`design-app-sources` descriptions (contracts, services, fakes, live types;
selection marks and the pasteboard bridge).

#### Wave 1: the rest of tier 1 (five features side by side)

Waits on: wave 0 merged. Engine: none for any of the five (Design's tree,
edits and file live in DesignModel; CoreColor is not needed until #21).

| Feature | Covers | Owned files | Waits on (besides wave 0) |
|---|---|---|---|
| F1 `select-several` | marquee, several-layer move, resize, nudge, delete; align several and distribute (#714); zoom to selection; #542, #607; J4, J5, J6, P1 | `Live/LiveMarquee.swift`, `Live/LiveTransforming.swift`, `Live/LiveAligning.swift`, `Live/LiveFraming.swift`, `DesignAlign.swift`, `DesignSelection.swift`, `DesignCanvasEditing.swift`, `DesignCanvas.swift`, `DesignSelectionMarks.swift`, `DesignAlignBar.swift`; tests `DesignMarqueeTests.swift`, `DesignSeveralTransformTests.swift`, `DesignDistributeTests.swift`, `DesignFramingTests.swift`, `DesignSelectBudgetTests.swift`; snapshots `DesignMarqueeSnapshots.swift`, `DesignAlignSnapshots.swift`, `DesignMultiSelectSnapshots.swift`; journeys `+Select`, `+PerfCanvas` | SuiteUI #330 for P1's screen half (report-only until then) |
| F2 `copy-group` | duplicate and Option-drag (#414), group and ungroup (#416), cut, copy, paste (#415); J7, J8, J9 | `Live/LiveDuplicating.swift`, `Live/LiveGrouping.swift`, `Live/LiveClipboard.swift`; tests `DesignDuplicateTests.swift`, `DesignGroupTests.swift`, `DesignPasteboardTests.swift`; snapshots `DesignDuplicateSnapshots.swift`, `DesignGroupSnapshots.swift`, `DesignPasteboardSnapshots.swift`; journey `+Arrange` | nothing |
| F3 `style-rows` | opacity and stroke (#752), text family, size, weight, alignment (#267), no jump on commit (#268), hint column (#276), frame names (#266), drawing radius, stroke and opacity; J10, J11, P2 | `Live/LiveStyling.swift`, `DesignInspector.swift`, `DesignInspectorStyle.swift`, `DesignInspectorContent.swift`, `DesignCanvasMarks.swift`, `DesignTextEditor.swift`, `DesignText.swift`; tests `DesignStyleTests.swift`, `DesignTextScaleTests.swift`, `DesignStyleBudgetTests.swift`; snapshots `DesignInspectorSnapshots.swift`, `DesignTextSnapshots.swift`, `DesignStyleSnapshots.swift`, `DesignArtworkPathTests.swift`; journeys `+Style`, `+PerfScrub` | SuiteUI #745 or #718 (public `onEnd`; Design's local end works meanwhile) |
| F4 `layers-panel` | rename layers and pages, drag to reorder and nest, Arrange, group-row toggles (#589), lock commits a text edit (#613); J12, P3 | `Live/LiveOrdering.swift`, `DesignLayersPanel.swift`, `DesignLayerToggles.swift`, `DesignWorkspace.swift`; tests `DesignOrderingTests.swift`, `DesignRenameTests.swift`, `DesignLockTextEditTests.swift`, `DesignLayersBudgetTests.swift`; snapshots `DesignLayersSnapshots.swift`; journeys `+Layers`, `+PerfLayers` | SuiteUI #589, #577, #108, #73 (until they land: mouse rename, no context menu, the group-row eye step skipped with its issue named) |
| F5 `files-history` | system undo in text fields and the close prompt (#275), save status and the unsaved dot (#270), the codec behind `DocumentFiling`, the open-error journey; J13, J14, J16, P4 | `Live/LiveFiling.swift`, `DesignFile.swift`, `DesignHistory.swift`, `DesignCommands.swift`, `DesignWindow.swift`, `DesignEditor.swift`; tests `DesignDirtyTests.swift`, `DesignFilingTests.swift`; snapshots `DesignFileSnapshots.swift`, `DesignFileMenuSnapshots.swift`; journeys `+Files`, `+PerfFiles` | SuiteUI #339 (save status in the top bar; a plain status text meanwhile) |

#### Wave 2: `design-seams-2` (one feature, tasks in order)

Waits on: wave 1 merged (it edits files wave 1 owns). Engine: none.

| Task | Behavior | Owned files |
|---|---|---|
| D2-1 | Tier-2 schema: `path` kind and field, `componentID`, file `components` and `variables`, file version 2 with version 1 still opening; snapshots of history carry components and variables | `DesignNode.swift`, `DesignInspectorContent.swift`, `DesignFile.swift`, `DesignHistory.swift`, `DesignWorkspace.swift`; tests `DesignTierTwoSchemaTests.swift`, `Fixtures/v1-file.json` |
| D2-2 | Tier-2 fakes and live stubs; `.fake` and `.live` name them | `Fakes/DesignTierTwoFakes.swift`, `Live/LiveExport.swift`, `Live/LivePen.swift`, `Live/LiveComponents.swift`, `Live/LiveVariables.swift`, `DesignServices.swift`; tests `DesignContractLawTierTwoTests.swift` |
| D2-3 | Actions and routes: export plan, pen press and drag, create and insert component, variable edits, light and dark mode | `DesignActions.swift`, `DesignCanvasEditing.swift`; tests `DesignActionsTierTwoTests.swift` |
| D2-4 | Intents, menus and the top bar: Export…, Create Component, Variables…, Light / Dark; the canvas draws paths and resolved instances | `DesignIntent.swift`, `DesignWindow.swift`, `DesignCommands.swift`, `DesignObjectMenu.swift`, `DesignEditor.swift`, `DesignCanvasMarks.swift`; `docs/c4/model.json` (names the wave-3 files, so no wave-3 feature edits it) |

#### Wave 3: tier 2 (four features side by side)

Waits on: wave 2 merged.

| Feature | Covers | Owned files | Engine work it waits on |
|---|---|---|---|
| F6 `export` | #418: PNG 1x/2x/3x, SVG, PDF; progress, Cancel, per-file errors | `Live/LiveExport.swift`, `Live/DesignSVG.swift`, `DesignExportSheet.swift`, `DesignRasterizer.swift`; tests `DesignExportTests.swift`, `DesignSVGTests.swift`, `DesignExportBudgetTests.swift`, `Fixtures/cards-desktop.svg`; snapshots `DesignExportSnapshots.swift`; journey `+Export` | none (the SVG writer is DesignModel's, per #418; PNG and PDF render the artwork view) |
| F7 `pen` | Pen tool: corners, smooth points, close; enable the tool | `Live/LivePen.swift`, `DesignPenMarks.swift`, `DesignWorkspace.swift` (the tool's help); tests `DesignPenTests.swift`; snapshots `DesignPenSnapshots.swift`; journey `+Pen` | **Needs a new core issue:** "Shared path geometry: a Linux-safe path (move, line, cubic, close) with exact cubic bounds, a hit test within a tolerance and SVG path data, for Flare and Design." Also SuiteUI #706 (anchor mark) |
| F8 `components` | #19: create from a frame, Assets section, insert, instances draw the component | `Live/LiveComponents.swift`, `DesignPanel.swift`, `DesignAssetsPanel.swift`; tests `DesignComponentsTests.swift`; snapshots `DesignComponentsSnapshots.swift`; journey `+Components` | none |
| F9 `variables` | #20: Variables sheet, light and dark values, fills bound to a variable, preview mode | `Live/LiveVariables.swift`, `DesignVariablesSheet.swift`, `DesignInspector.swift`; tests `DesignVariablesTests.swift`; snapshots `DesignVariablesSnapshots.swift`; journey `+Variables` | none (CoreColor wide gamut is #21, not v1) |

### 8.3 Why this order

- **Wave 0 takes every shared file once.** `DesignIntent.swift`,
  `DesignCommands.swift`, `DesignWindow.swift`, `DesignServices.swift` and
  `DesignNode.swift` are where parallel features would collide. Wave 0 puts
  every tier-1 case, menu item, service slot and stored field in place,
  backed by `NotBuilt`, so no control is dead (each says "<Feature> isn't
  built yet.") and wave 1 only fills its own `Live/` files and its own
  views. This is Flare's LM-0a3 move ("every stored property in one PR") for
  Design.
- **Wave 1 is the everyday loop**, in five features with disjoint files;
  each can ship in any order. F1 and F2 together finish the "several
  layers" story that priorities item 7 says comes first.
- **Wave 2 repeats the seam for tier 2**, once wave 1 has let go of the
  shared files, so wave 3's four features run side by side.
- **Only F7 waits on creative-core**, and only for path geometry. If that
  issue is slow, F7 waits alone; nothing else depends on it.

### 8.4 Engine work

| Feature | creative-core work |
|---|---|
| D0, F1–F5, D2, F6, F8, F9 | none |
| F7 `pen` | needs a new core issue: shared path geometry (spec in 8.2) |
| #21 (not v1) | none new: CoreColor's existing conversion, per #21's body |

---

## 9. Open questions for the captain

1. **Q1 Journey files.** Wave 0 needs SuiteUI #333's template change so each
   feature owns its own journey file. If #333 is not merged when wave 0
   starts, may D0-6 make the one-line `project.yml` change itself (leaving
   the input and perf helpers to #333)?
2. **Q2 Auto Layout.** #752's last bullet stores direction, gap, padding and
   alignment with no layout math, which leaves controls that change nothing
   on the canvas. Proposal: drop that bullet from v1 and file one tier-3
   issue for Auto Layout with its math. Agree?
3. **Q3 Screen-side budgets.** No input-to-screen number can be measured
   until SuiteUI #330 (`FrameProbe`, now `p3`) lands. Proposal: raise #330
   to `p1` by dependency (Design and Flare both need it) and let wave 1 gate
   on the model half meanwhile. Agree?
4. **Q4 Autosave and recovery.** Flare's v1 has a recovery file. This
   blueprint leaves Design's out of v1 (the close prompt covers the common
   loss). In or out?
5. **Q5 Pen tool tier.** The Pen sits in wave 3 and waits on a new core
   issue for shared path geometry. Should Design instead take a dependency on
   FlareCore's existing path type (a `Package.swift` change, which is a
   protected path), or wait for the shared module?
6. **Q6 Housekeeping.** Close PR #719 (its fix shipped as #749)? File the
   gap issues listed in 8.1 when wave 0 starts, or now?
7. **Q7 Status of the existing selection handles.** SuiteUI #273 moves
   Design's handles into SuiteUI for Flare and Halo. F1 edits
   `DesignSelectionMarks.swift`; should F1 wait for #273 to avoid doing the
   several-layer box twice?
