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
