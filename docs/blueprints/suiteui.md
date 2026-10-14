# SuiteUI blueprint

SuiteUI is the suite's shared component library: the tokens, the two window
shells, the inspector rows, the canvas, the marks drawn over it, the lists,
the timeline and the test harness every app's journeys run on. It is a
platform, not an app. Nobody launches SuiteUI; people meet it inside Flare,
Design, Photo, Library and Halo. So in this blueprint a **journey** is a
component behaviour an app relies on, the **usage map** is which app uses
which component and how often its users touch it, and every **wave** must
land before the app features that need it.

This is the gate before any feature code. Feature packets
(`docs/blueprints/suiteui/features/<feature>.md`) are written only after the
captain approves it. The worked example of shape and depth is
`docs/blueprints/flare.md` and `docs/blueprints/flare/features/`.

Sources read on 2026-10-14: creative-apps `origin/dev` 956d946
(`Sources/SuiteUI/`, `Tests/SuiteUITests/`, `Tests/AppSnapshotTests/`,
`Tests/AppAuditTests/`, `UITests/`, `project.yml`, `Package.swift`), the 41
open issues labelled `line:suiteui`, the SuiteUI PRs merged up to #757, and
the docs named in CLAUDE.md. The look is `docs/design.md`; the quality ids
(`QB-…`) are section 6 of `docs/review-rubric.md`; the audit checks are
`docs/blueprints/app-audit.md`.

Contents: 0 Status on dev · 1 Brief · 2 Pseudo-C4 · 3 Usage map ·
4 Journeys · 5 Contracts · 6 Look · 7 Quality bar · 8 Coverage and waves ·
9 Open questions for the captain · 10 Critic rounds

Every item below is written to be checked: a table row names the file, the
test or the issue that proves it.

---

## 0. Status on dev (956d946, 2026-10-14)

### 0.1 What exists

36 Swift files, 4,512 lines, all under `Sources/SuiteUI/`, one C4 component
(`suiteui-sources`, path `Sources/SuiteUI/`). Grouped by job:

| Group | Files on dev | Tests on dev |
|---|---|---|
| Tokens and glass | `Tokens.swift` (spacing, insets, radii, sizes, type, motion, the graphite ladder and state colors as literal hex per appearance), `Glass.swift` (`suiteGlass(in:)`, the snapshot stand-in), `GlassPanel.swift` | `TokensTests` (contrast table, geometry) |
| Window shells | `SuiteWindow.swift` (split view, sidebar, inspector, launch and minimum size from the column tokens), `EditorShell.swift` (top bar, rail, canvas, panel, status; dark; no timeline slot yet), `EditorTopBar.swift` (`EditorTopBar`, `EditorBarItem`, `EditorBarMenu`, `EditorBarDivider`; flat accessory items, no `.primary`, no save status) | `EditorShellTests`, snapshots `SuiteEditorShellSnapshots`, `SuiteWindowLaunchSnapshots`, `SuiteWindowMinimumSnapshots`, `SuiteEditorBarDimmingTests` |
| Tools | `ToolbarGroup.swift` (`ToolbarAction` with `unavailableHelp` and `shortcut`, `PaletteTool`, `.floating` and `.rail` styles) | journeys' `clickEachTool()` |
| Canvas | `CanvasSurface.swift`, `CanvasViewport.swift` (checkerboard, rulers, zoom 10–3200 %, Space-drag and arrow pan, drags in document pixels), `Ruler.swift`, `ZoomMath.swift`, `CanvasMarks.swift` (`SelectionOutline`, `CropShade` only) | `CanvasPanTests`, `ZoomMathTests`, `RulerMarksTests`, `RulerLabel*Tests` |
| Inspector | `InspectorHeader.swift` (title and info card), `InspectorRows.swift` (`InspectorSection`, `InspectorRow`, `InspectorSliderRow`, `InspectorStepperRow`, `InspectorPickerRow`), `ScrubField.swift` and `ScrubValue.swift` (the bar slider and exact field, number rules, `ScrubTrack`), `NumericInput.swift`, `ColorWell.swift` (`HexColor`, `InspectorColorRow`, `InspectorColorWellRow`), `InspectorAction.swift`, `KeyframeButton.swift`, `PresetGrid.swift`, `ChipRow.swift`, `ChoiceChips.swift`, `StudioScrubRow.swift`, `SegmentedTabs.swift` (a plain segmented `Picker`) | `ScrubValueTests`, `NumericInputTests`, `SliderBarTests`, `KeyframeButtonTests`, `PresetGridTests`; snapshots `SuiteInspectorSnapshots`, `SuiteProInspectorSnapshots`, `SuiteSliderSnapshots`, `SuiteHeaderSnapshots`, `SuiteKeyframeSnapshots`, `SuitePresetsSnapshots` |
| Curves | `CurveEditor.swift` (two-handle easing well, preview dot, nudges, Tab), `ToneCurveEditor.swift` (N points, histogram) | `CurveEditorTests`, `ToneCurveEditorTests`; `SuiteCurveEditorSnapshots`, `SuiteToneCurveSnapshots` |
| Lists | `SidebarRow.swift` (`SidebarItem`, `SidebarToggle`, rename draft), `SidebarSection.swift` (`SidebarNode`, two-level cap), `ThumbnailGrid.swift`, `GridSelection.swift` | `Sidebar*Tests` (incl. the #54 rename guard), `GridSelection*Tests`; `SuiteSidebar*Snapshots`, `SuiteGrid*Snapshots` |
| Timeline | `TimelineStrip.swift` (names column, ruler, lanes with diamonds and spans; no key drag), `FrameMapping.swift` | `FrameMapping*Tests`; `SuiteTimelineSnapshots` |
| Content | `SurfaceCard.swift`, `EmptyStateView.swift`, `ViewerStatusBar.swift` (already pills, #522) | `SuiteStatusSnapshots` |

What SuiteUI does **not** have, though `docs/design.md` names some of them:
`TransportCapsule`, `LayerList`, `NodeGraph`, `SelectionHandles`,
`PathMarks`, `MotionPathMarks`, `GhostLayer`, a point mark and a grid mark,
the `EditorShell(timeline:)` slot, `EditorBarItem(.primary)` and the save
status, `FrameProbe`, the golden compare (`GoldenImage`, `SnapshotHost`), a
per-control inventory for the every-control sweep, and any journey of its
own. `UITests/` has five app journey files and the shared `Journey.swift`
and `Audit.swift`; `project.yml` compiles exactly `UITests/<target>.swift`
per bundle, so no second journey file per app is picked up yet (#333).

**The Linux gap.** `Package.swift` declares SuiteUI and its tests only under
`#if os(macOS)`. The Linux gate (`scripts/ci`) never compiles a line of
SuiteUI, including its pure rule files (`ScrubValue`, `NumericInput`,
`FrameMapping`, `GridSelection`, `ZoomMath`, `RulerTicks`), which already
avoid SwiftUI on purpose. Every SuiteUI PR so far has merged on the macOS job
on `dev` alone. Section 5 and question Q1 deal with this.

### 0.2 Merged work, by the blueprint tasks it closed

Flare's blueprint (section 7.2, the `track:ui` SuiteUI chain) defined S0–S16
and QH-1–QH-6. On dev now:

| Task | Issue | Merged in | State |
|---|---|---|---|
| S0 tokens: ladder, text and state colors, sizes, type, motion | #329 | #499, #500 | closed |
| S1 bar slider and its number rules | #334 | #505, #506, #507 | closed |
| S2 keyframe button | #335 | #520 | closed |
| S3 filled rows, caps headers, the one color row | #336 | #517, #518 | closed |
| S4 inspector title and info card | #337 | #519 | closed |
| S5 presets, chips, action button | #338 | #521 | closed |
| S7 status pills (first half) | #340 | #522 | open: `TransportCapsule` left |
| Canvas surface, zoom, checkerboard, pan | #6 | #555, #711 | closed |
| Photo's tone curve editor | #412 | #528 | closed |
| Window overflow at the minimum width | #215 | #578, #715 | closed |
| Sidebar header contrast | #284 | #599 | open; the title color is fixed, Design's own `Section("Pages")` is a Design-line change |
| Rename hit area (#54) | #54 | #97, #167, #307, #310 | closed |

### 0.3 What the open `line:suiteui` issues cover (41)

| Area | Issues | Ready now? |
|---|---|---|
| Test harness | #331 goldens, #332 snapshot host, #333 journey files and helpers, #330 frame probe | #331, #333, #330 have no open dependency; #332 waits on #331 |
| Editor chrome | #339 top bar primary and save status, #340 transport capsule, #341 tabs capsule and rail colors, #342 timeline slot | all wait on #332 |
| Inspector controls | #745 and #718 (one ask filed twice: public `onEnd` on `ScrubField` and the color rows), #591 discrete step on `ScrubTrack`, #88 log slider (largely met by `ScrubTrack`), #622 Reset hit area, #285 Reset sits over the header button, #283 secondary text on light cards, #262 empty accessibility values, #343 curve editor goldens and probe mark | all but #343 are ready |
| Lists | #146 `LayerList` and dimmed rows, #108 keyboard rename, #73 row context menus, #577 refusable rename, #589 child rows read as one checkbox, #111 app-owned expansion, #249 nesting snapshot, #308 #311 #312 rename-guard gaps, #284 header contrast | #146 waits on #332; the rest are ready |
| Timeline | #62 restyle (absorbs #61 and #219), #63 key drag and keyboard keys (`needs-human`), #219 blank long timelines | #62 waits on #342; #63 on #62 |
| Canvas marks | #273 selection handles and the vector marks, #706 and #737 (one point mark asked twice), #530 grid mark, #264 ruler corner unit | #273 waits on #332; the rest are ready |
| Graph | #344 `NodeGraph` | waits on #332 |
| Docs | #345 C4 description names the new components | waits on all of the above |
| Not for v1 | #7 command palette, #274 shared open and save plumbing, #272 design lint misses computed font sizes (`scripts/`, protected) | see section 8 |

### 0.4 What is missing (no issue yet)

Each row is filed as a `needs-ui` / `line:suiteui` issue with the packet
that owns it, after the captain approves this blueprint.

| Missing | Why it is needed | Feature (section 8) |
|---|---|---|
| A component gallery that journeys can launch (`-SuiteGallery <page>`) | SuiteUI has no window of its own, so its behaviours have no journey; today they are proven only through whatever an app happens to show | suite-harness |
| A control inventory (`suite.controls` JSON: every control's identifier, enabled state and reason) | Flare's J29 and every app's "every control acts or says why" sweep read it; nothing writes it | suite-harness |
| Linux-checkable contracts for the component rules (section 5) | UI and logic can only be built in parallel against a fixed seam | suite-harness (files), every feature (conformances) |
| Path, motion path and onion marks for Flare (`PathMarks`, `MotionPathMarks`, `GhostLayer`) | Named in #273's title area but not in its acceptance; Flare's J4 and J13 need them | canvas-marks |
| Timeline playhead pill drag and the recording ring | Flare J9, J6 | timeline (inside #62's restyle; confirm in the packet) |

### 0.5 Who uses what today

Files under each app's `Sources/<X>App/` that name the component (grep on
dev). `–` means none yet.

| Component | Flare | Design | Photo | Library | Halo |
|---|---|---|---|---|---|
| `SuiteWindow` | 1 | – | – | 1 | 1 |
| `EditorShell`, `EditorTopBar`, `EditorBarItem` | – | 2 | 2 | – | – |
| `ToolbarGroup` / `ToolbarAction` | 1 / 2 | 1 / 4 | 1 / 2 | – / 1 | – / 1 |
| `CanvasViewport` | – | 2 | 2 | – | – |
| `CanvasSurface` | 1 | – | – | 1 | 1 |
| `SelectionOutline`, `CropShade` | – | 1, – | 1, 2 | – | – |
| `InspectorHeader`, `InspectorSection`, `InspectorRow` | – | 1, 2, 1 | 1, 2, 1 | 1, 1, 1 | 1, 1, 1 |
| `InspectorSliderRow` | – | – | 2 | – | – |
| `InspectorPickerRow` | – | – | 1 | 1 | – |
| `InspectorColorWellRow` | – | 1 | 1 | – | – |
| `InspectorAction` | – | 1 | 1 | – | – |
| `ScrubField`, `NumericInput` | – | 1, 1 | –, 2 | – | – |
| `StudioScrubRow`, `CurveEditor`, `ChoiceChips` | 1, 1, 1 | – | – | – | – |
| `ToneCurveEditor` | – | – | 1 | – | – |
| `SegmentedTabs` | – | 1 | 1 | – | – |
| `SidebarRow`, `SidebarSection`, `SidebarItem` | –, 2, 1 | 1, –, 1 | – | –, –, 1 | 1, 1, 2 |
| `ThumbnailGrid` | – | – | – | 1 | – |
| `TimelineStrip` | – | – | – | – | 1 |
| `ViewerStatusBar` | – | 1 | 1 | – | 1 |
| `EmptyStateView` | 1 | 2 | 2 | 1 | 1 |
| `SurfaceCard`, `GlassPanel` | 1, – | – | – | 1, 1 | – |
| `KeyframeButton`, `PresetGrid`, `ChipRow`, `InspectorColorRow`, `InspectorStepperRow` | – | – | – | – | – |

The last row is built and waiting: Flare's inspector (F6a #348 and after)
is its first user. Flare is still on `SuiteWindow`; its F1a (#346) and F1b
(#347) move it to `EditorShell`, which is why the editor-chrome feature
comes first in section 8.

---

## 1. Brief

### The problem

Five apps share one window, one inspector, one canvas and one timeline. When
a component is missing, each app writes a placeholder in its own target
(Photo's `CloneSourceMark` and `StraightenMarks`, Flare's layer rows on
`SidebarSection`, Design's drag-plus-submit workaround for `onEnd` in #749),
and the placeholders drift apart. When a component is wrong, every app is
wrong at once, and the fault surfaces only in the next macOS run on `dev`,
by which time several PRs sit in the culprit range. Two things fix that:
every component behaviour an app relies on is written down with the test
that proves it, and every component lands before the app feature that
needs it.

### Who uses it

- **App lines** (Flare, Design, Photo, Library, Halo crews and feature
  leads), who build views only from SuiteUI and file `needs-ui` when
  something is missing. They need stable signatures, a fake they can build
  against, and a component that already behaves.
- **The people using the apps**, indirectly: SuiteUI decides whether a slider
  steps from the keyboard, a disabled button says why, a row is readable
  under Increase Contrast, a drag feels immediate.
- **Reviewers and the captain**, who judge the suite from the contact sheet
  and the goldens. SuiteUI owns the harness that makes those.

### Non-goals

- No app logic, no Model, no engine call. SuiteUI knows no Model and no
  creative-core type (`docs/engineering.md`, Layers).
- No look-alike of a system control. Apple's own components come first
  (`docs/design.md`, Component order); SuiteUI only restyles where the design
  doc sanctions it (the bar slider, the keyframe button, chips).
- No document rendering: the stage, the raster tiles and the thumbnails'
  pixels are the apps' (SuiteUI draws marks over them, never them).
- No in-app appearance switch, no custom fonts, no iPad layouts.
- No plugin or theming API for third parties.

### The v1 line

**In v1:** everything an app's tier-1 loop (`docs/priorities.md`) shows on
screen: both shells with the timeline slot, the top bar with its primary and
save status, the tool rail, the canvas with zoom, pan, rulers, selection
handles and the vector marks, every inspector row with keyboard parity and
one `onEnd` per gesture, presets and chips, the keyframe button, both curve
editors, the sidebar rows and `LayerList` with keyboard rename and dimmed
rows, the thumbnail grid, the timeline with selectable and draggable keys,
the transport capsule, status pills, empty states, and the harness that
proves all of it: goldens in four appearances, the gallery, the journey
helpers, the control inventory and the frame probe.

**Also in v1, after the loop:** the point and grid marks (Photo's Clone,
Heal and Straighten, tier 2), row context menus (Halo, tier 2), and
`NodeGraph` (Flare's Interactions editor, tier 3 but in Flare's v1 scope,
so it is the last wave).

**Out of v1:** the command palette (#7), shared open and save panel plumbing
(#274; each app keeps its own until a second refactor shows the shared
shape), lint changes in `scripts/` (#272, a protected path), a tree deeper
than two levels, a node graph you can drag nodes in (Flare's blueprint keeps
positions computed), and any component that no app's v1 shows.

---

## 2. Pseudo-C4 (drawn before code)

The machine-readable copy is `docs/blueprints/suiteui/c4-planned.json`, in
the shape of `docs/c4/model.json` (systems, containers, components with
`name`, `description`, `paths`, and `relationships`), with `"status":
"planned"` or `"existing"` and `"authored": true` on every container and
component. It is a plan: the C4 gate keeps reading `docs/c4/model.json`,
where SuiteUI stays one component (`suiteui-sources`, path
`Sources/SuiteUI/`) so every new file below is owned without editing the
shared model. The description there is brought up to date once, by #345 in
the last wave (section 8). Check: every one of the 36 files on dev sits in
exactly one L3 component's `paths` below (the script that wrote the JSON
asserts it), and every relationship names ids that exist.

### 2.1 L2: containers

```
             Flare · Design · Photo · Library · Halo  (<X>App, macOS)
                              │ build every view from
                              ▼
 ┌──────────────────────── SuiteUI (Sources/SuiteUI, macOS) ───────────────────────┐
 │ tokens+glass ◀── every component                                                │
 │ window shell ──▶ rows and lists, gallery      editor shell ──▶ tools, canvas,   │
 │ canvas ──▶ canvas marks, probes                 viewer chrome, timeline slot     │
 │ inspector ──▶ number entry, chips             curves · grid · content · graph   │
 │ contracts (Foundation only) ◀── conformed to by every rule file                 │
 └──────────────────────────────────────────────────────────────────────────────────┘
        ▲ tested by                 ▲ rendered by               ▲ launched by
  SuiteUITests (macOS)     Suite snapshots + goldens     Journey harness: Journey*.swift,
                           (AppSnapshotTests/Suite*)     project.yml, SuiteJourneyTests
                                                         ──▶ App audit (not SuiteUI's)
  SuiteUI logic (Linux): proposed only, Q1
```

| Container | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| SuiteUI | existing | The component library and tokens. Knows no Model or engine | `Sources/SuiteUI/` | used by the five apps; tested by the three below |
| SuiteUITests | existing | Unit tests of rules and components | `Tests/SuiteUITests/` | tests SuiteUI |
| Suite snapshots and goldens | existing (PNGs), planned (goldens) | Every component state as a PNG; planned: compared against committed baselines in four appearances | `Tests/AppSnapshotTests/Suite*.swift`, `GoldenImage*.swift`, `SnapshotHost*.swift`, `Golden/` | renders SuiteUI |
| Journey harness | existing (`Journey.swift`), planned (the rest) | The shared XCUITest steps, the template that picks up every journey file, and SuiteUI's own journeys | `UITests/Journey.swift`, `UITests/Journey+Input.swift`, `UITests/SuiteJourneyTests*.swift`, `project.yml` | launches a SuiteWindow app under `-SuiteGallery`; reads the probes; runs the app audit |
| SuiteUI logic (Linux) | planned, proposal | Compile `Contracts/` and the pure rule files on Linux so `scripts/ci` tests them | none until Q1 is decided (`Package.swift` is protected) | would hold `suiteui-contracts` |
| App audit | existing, not SuiteUI's | The audit checks every shot runs | `Tests/AppAuditTests/`, `UITests/Audit.swift` | run by the journey harness |

### 2.2 L3: components inside SuiteUI

| Component | Status | Responsibility | Owned paths (`Sources/SuiteUI/`) | Relationships |
|---|---|---|---|---|
| Tokens and glass | existing | Every raw value and the one glass modifier | `Tokens.swift`, `Glass.swift`, `GlassPanel.swift` | used by every component |
| Window shell | existing | `SuiteWindow`; planned: the `-SuiteGallery` hook, app-owned expansion, row context menus | `SuiteWindow.swift` | draws Rows and lists; shows the gallery |
| Editor shell | existing + planned | `EditorShell`, the top bar family, `SegmentedTabs`; planned: timeline slot, `.primary`, save status, capsule tabs, `ShellLayout` | `EditorShell.swift`, `EditorTopBar.swift`, `SegmentedTabs.swift`, `ShellLayout.swift` (planned) | hosts Tools, Canvas, Viewer chrome, Timeline; conforms to `ShellLayingOut` |
| Tool palette | existing | `ToolbarAction`, `PaletteTool`, `ToolbarGroup` (floating, rail) | `ToolbarGroup.swift` | hosted by both shells; conforms to `ToolPicking` |
| Canvas | existing | `CanvasSurface`, `CanvasViewport`, `Ruler`, `ZoomMath` | `CanvasSurface.swift`, `CanvasViewport.swift`, `Ruler.swift`, `ZoomMath.swift` | draws Canvas marks; reports to Probes; conforms to `CanvasNavigating` |
| Canvas marks | existing + planned | `SelectionOutline`, `CropShade`; planned: `SelectionHandles`, `PathMarks`, `MotionPathMarks`, `GhostLayer`, guide marks, `CanvasPointMark`, `CanvasGrid`, `HandleGeometry` | `CanvasMarks.swift`, `CanvasMarks+Vector.swift`, `CanvasMarks+Points.swift`, `HandleGeometry.swift` (last three planned) | drawn by Canvas; conforms to `HandleGeometryProviding` |
| Inspector rows | existing | Header, section, rows, the color row, action, keyframe button | `InspectorHeader.swift`, `InspectorRows.swift`, `ColorWell.swift`, `InspectorAction.swift`, `KeyframeButton.swift` | uses Number entry and Presets; conforms to `HexColorEditing`, `KeyframeFacing` |
| Number entry | existing | `ScrubField` and the bar slider, `ScrubValue`, `NumericInput`, `StudioScrubRow` | `ScrubField.swift`, `ScrubValue.swift`, `NumericInput.swift`, `StudioScrubRow.swift` | reports to Probes; conforms to `ValueScrubbing` |
| Presets and chips | existing | `PresetGrid`, `ChipRow`, `ChoiceChips` | `PresetGrid.swift`, `ChipRow.swift`, `ChoiceChips.swift` | used by Inspector and the timeline toolbar; conforms to `PresetNavigating` |
| Curve editors | existing | `CurveEditor`, `ToneCurveEditor` | `CurveEditor.swift`, `ToneCurveEditor.swift` | conforms to `CurvePointEditing` |
| Rows and lists | existing + planned | Sidebar rows and sections; planned: `LayerList`, `ListEditing` | `SidebarRow.swift`, `SidebarSection.swift`, `LayerList.swift`, `ListEditing.swift` (last two planned) | drawn by Window shell and app panels; conforms to `ListEditing` |
| Thumbnail grid | existing | `ThumbnailGrid`, `GridSelection` | `ThumbnailGrid.swift`, `GridSelection.swift` | conforms to `GridSelecting` |
| Timeline | existing + planned | `TimelineStrip`, `FrameMapping`; planned: restyle, `TimelineKeys` | `TimelineStrip.swift`, `FrameMapping.swift`, `TimelineKeys.swift` (planned) | hosted by Editor shell's slot; conforms to `TimelineMapping`, `KeyEditing` |
| Viewer chrome | existing + planned | `ViewerStatusBar`; planned: `TransportCapsule` | `ViewerStatusBar.swift`, `TransportCapsule.swift` (planned) | hosted by both shells; conforms to `StatusPillComposing`, `TransportStepping` |
| Content surfaces | existing | `SurfaceCard`, `EmptyStateView` | `SurfaceCard.swift`, `EmptyStateView.swift` | view only (section 5.4) |
| Node graph | planned | `NodeGraph`, `NodeGraphGeometry` | `NodeGraph.swift`, `NodeGraphGeometry.swift` | conforms to `GraphGeometry` |
| Probes | planned | `FrameProbe`, `ControlInventory` | `FrameProbe.swift`, `ControlInventory.swift` | fed by Canvas, Number entry, Timeline, Tools; read by the journey harness; conform to `FrameProbeRecording`, `ControlInventorying` |
| Component gallery | planned | `SuiteGallery` and one page per family | `SuiteGallery.swift`, `Gallery/` | shown by Window shell; launched by SuiteUI's journeys |
| Component contracts | planned | Section 5's protocols, value types, live conformances and Fakes, Foundation only | `Contracts/` | conformed to by the rule files; the Fakes back the gallery's UI-first pages |

Golden comparison (`GoldenComparing`) belongs to the snapshot container, not
to SuiteUI: its conformance lives in `Tests/AppSnapshotTests/GoldenImage.swift`
and its contract in `Contracts/` so it can be unit-tested with the rest.
