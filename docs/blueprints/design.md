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
| bad files | written by the test into its temp folder: `not json`, `{"version":2,"pages":[]}`, `{"version":1,"pages":[]}`, a file repeating an id | J16 |

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
| J9 | `testGroupAndUngroup` (`+Arrange`, F2) | cards | select A and B; ⌘G; ⌥⌘G is not used; ⇧⌘G; select A and "Title" across parents | group row with two children and "Undo Group"; after ⇧⌘G the row is gone and "Undo Ungroup"; across parents Group is disabled with "Select layers that share a parent." | refusal |
| J10 | `testInspectorStyleRows` (`+Style`, F3) | cards | select "A"; Corner radius 12 by typing; drag Opacity to 50%; add a stroke, width 4 with → four times; select "Hidden" from Layers | each value reads back; one undo step per row ("Undo Change Corner Radius", "Undo Change Opacity", "Undo Change Stroke"); keyboard parity on the width row; a hidden layer's rows are disabled with "Show Hidden to change it." | disabled with reason |
| J11 | `testTextFontAndSize` (`+Style`, F3) | cards | select "Title"; size 32; weight Bold; alignment Center; zoom to 50%; double-click "Title", type, Return | rows read back; the committed text's frame equals the editor's frame within 1 pt (no jump, #268); "Undo Edit Text" | text edit open |
| J12 | `testLayersRenameReorderNest` (`+Layers`, F4) | two-pages | double-click "A" row, type "Avatar", Return; drag "C" above "B"; drag "Title" into "Pair"; Object > Arrange > Send to Back on "B"; hide "Pair" from its own row's eye; rename page "Mobile" to "Phone screens" | row reads "Avatar" ("Undo Rename Layer"); order C above B; "Title" nested under Pair; B last; Pair's eye toggled (#589); page renamed; each one step | empty-name rename refused, the row keeps its old name |
| J13 | `testUndoInTextFieldsAndDirtyState` (`+Files`, F5) | cards | type in the X field and press ⌘Z inside the field; Escape; draw a rectangle; check the dot; ⌘S | ⌘Z in the field undid the typing, not a document step (#275); the top bar shows the unsaved dot after the draw and "Saved" after ⌘S (#270) | save in progress shows "Saving…" when slower than 100 ms (QB-L9) |
| J14 | `testCloseWithUnsavedChanges` (`+Files`, F5) | cards | draw; ⌘W; Cancel; ⌘W; Don't Save | the alert names the file; Cancel keeps the window; Don't Save closes it | – |
| J15 | `testEveryControlActsOrSaysWhy` (`+EveryControl`, D0-6) | cards | read `suite.controls`, click each enabled `design.*` control, Escape, ⌘Z | every enabled control changed the shot or a value; every disabled one has a reason. A sweep, never cited by the matrix | – |
| J16 | `testOpenBadFiles` (`+Files`, F5) | bad files | launch with `-DesignOpenFile` on each | the alert reads "It is not a Design file.", "It was made by a newer version of Design (file version 2).", "It has no pages.", "It uses the id node-2 more than once."; the window stays empty | error |
| P1 | `testCanvasDragLatency` (`+Perf`, F1) | crowd | four velocity drags of 600 pt at 300 pt/s: move a layer, draw a rectangle, resize, marquee; one Space-pan | at least 60 samples each; QB-L1 (section 7) | – |
| P2 | `testScrubLatency` (`+Perf`, F3) | crowd | velocity drag on the Opacity bar and the X scrub field | at least 60 samples; QB-L2 | – |
| P3 | `testLayerListScroll` (`+Perf`, F4) | crowd | scroll Layers end to end, all frames expanded | QD-L5 | – |
| P4 | `testOpenLargeFile` (`+Perf`, F5) | crowd saved then reopened | ⌘O | progress within QB-L9; no stall over QB-L12 | loading |

Tier-2 journeys, written with their packets: `testExportPNGSVGPDF`
(`+Export`; from #418 (c), plus Cancel and a read-only folder),
`testPenCornersAndCurves` (`+Pen`), `testComponentsCreateAndInsert`
(`+Components`) and `testVariablesLightAndDark` (`+Variables`).
