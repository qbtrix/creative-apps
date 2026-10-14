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

---

## 3. Usage map

SuiteUI has no users of its own (`docs/priorities.md`, SuiteUI). A component
takes the **highest tier of any app step that shows it**: tier 1 if any
app's tier-1 loop puts it on screen, tier 2 if only weekly features do, tier
3 otherwise. A dependency is never below what needs it, so the harness that
proves tier-1 components is tier 1.

**How the app tiers were made.** `docs/priorities.md` ranked each app from
public sources only: usage surveys, help-centre task articles, course
syllabi, "learn these first" shortcut sheets and community threads, and no
other app was opened. The surveys it lists: the 2019 motion design survey
(schoolofmotion.com/blog/2019-motion-design-survey), photo editing habits of
18–25s (petapixel.com, 2024-06-21), the photo editing software survey
(shotkit.com/photo-editing-software-survey), the state of design systems
2022–23 (sympli.io), and the UX tools survey 2022 (designcompass.org).
Rows it marks *inferred* stay inferred here.

**What this blueprint adds** for the component-level rules (not for ranking
apps): the macOS Human Interface Guidelines (developer.apple.com/design/
human-interface-guidelines: sidebars, inspectors, toolbars, sliders, focus
and keyboard navigation), WCAG 2.2 success criteria 1.4.3 contrast, 1.4.11
non-text contrast and 2.5.8 target size (w3.org/TR/WCAG22), and the WAI-ARIA
Authoring Practices slider, grid and tree view patterns
(w3.org/WAI/ARIA/apg/patterns/), which give the keyboard model every
adjustable and selectable component follows (arrows step, Page or Shift
steps coarse, Home and End jump, Return edits, Escape cancels).

App letters: **F** Flare, **D** Design, **P** Photo, **L** Library, **H**
Halo. "now" is the grep table in 0.5; "planned" comes from each app's
blueprint or issues.

### 3.1 Tier 1: on every app's everyday loop

| Component | Apps now | Apps planned | The tier-1 step that shows it (`docs/priorities.md`) |
|---|---|---|---|
| Tokens, glass | all | all | every screen |
| `SuiteWindow` | F L H | L H | Library browse (#33); Halo compositions (#36) |
| `EditorShell`, top bar, `EditorBarItem(.primary)`, save status | D P | F D P | Open, save, undo for F (5), D (8), P (1, 4) |
| Timeline slot in `EditorShell` | – | F (H if it moves to the shell) | Flare keyframes and scrub (1, 3) |
| `ToolbarGroup` rail and floating palette | F D P | F D P H | Draw and select (F 4, D 2–3, P 2) |
| `CanvasViewport`, rulers, zoom, pan | D P | F D P | Zoom and pan (F 5, D 1, P 4) |
| `CanvasSurface` | F L H | L H | Library loupe (#29); Halo viewer (H 4) |
| `SelectionOutline`, `CropShade` | D P | D P | Select (D 2); crop (P 2) |
| `SelectionHandles`, `PathMarks`, guide marks | – (Design draws its own) | F D H | Select, move, resize (F 4, D 2, H 5) |
| `InspectorHeader`, `InspectorSection`, `InspectorRow` | D P L H | all | Properties inspector (D 5); tone (P 3); develop (L 4) |
| Bar slider (`InspectorSliderRow`, `StudioScrubRow`) | F P | all | Exposure and levels (P 3); develop (L 4); transform rows (F 1, H 3) |
| `ScrubField` exact numbers with `onEnd` | D | D F | Position and size (D 5) |
| `InspectorPickerRow`, toggle rows | P L | all | Develop and tone options (P 3, L 4) |
| `InspectorColorRow` | D P | D F | Fill and stroke (D 5, F 4) |
| `KeyframeButton` | – | F H | Keyframe a property (F 1, H 3) |
| `PresetGrid`, `ChoiceChips`, `ChipRow` | F | F H | Easing presets (F 2, H 7) |
| `ToneCurveEditor` | P | P | Curves (P 3) |
| `SidebarRow`, `SidebarSection`, `LayerList` (dimmed, rename, reorder) | F D H | F D P H | Layers panel (F 4, D 6, P 5); compositions (H 1) |
| `ThumbnailGrid` | L | L | Browse the grid, cull with keys (L 2, 3) |
| `TimelineStrip` (selectable, draggable keys) | H | F H | Keys on a timeline, retime and delete (F 1, H 2–3) |
| `TransportCapsule` | – | F H | Play and loop with Space (F 3, H 4) |
| `ViewerStatusBar` pills | D P H | all canvas apps | Zoom readout under every canvas (design doc, Viewer chrome) |
| `EmptyStateView` | all | all | Open or create a document (every app's step 1) |
| `SegmentedTabs` | D P | D P F | The right panel's tabs (P 5 layers, D 6) |
| Golden compare and snapshot host (#331, #332) | – | all | p1 by dependency: every tier-1 component's look is proven by it |
| Journey files and helpers (#333), gallery, control inventory | – | all | p1 by dependency: every journey in section 4 runs on it |

### 3.2 Tier 2: weekly

| Component | Apps planned | Step |
|---|---|---|
| `CurveEditor` (custom easing curve) | F H | Curve editor (F tier 2) |
| `CanvasPointMark`, `CanvasGrid` | P | Clone and heal (P tier 2, #422); straighten grid (P, done for v1 on a placeholder) |
| `MotionPathMarks`, `GhostLayer` | F | Onion skin and motion paths (F tier 2) |
| Row context menus (#73) | H F D | Duplicate and delete compositions (H #35) |
| Keyboard rename (#108), contrast fixes (#283, #284, #285, #622) | all | Accessibility basics (tier 2 in every app) |
| `InspectorStepperRow` | – | No caller planned; kept, not extended |

### 3.3 Tier 3: specialist

| Component | Apps planned | Step |
|---|---|---|
| `NodeGraph` (#344) | F | Interactive state machines (F tier 3, but in Flare's v1 scope) |
| `FrameProbe` (#330) | all | Perf budgets (tier 3 in every app). It ships in wave 1 anyway: section 7's budgets cannot be measured without it, and it is small |
| App-owned expansion (#111), the rename-guard tests (#249, #308, #311, #312) | D | Polish and test plumbing |
| Command palette (#7) | all | No tier-1 or tier-2 step needs it: not v1 |

---

## 4. Journeys

### 4.1 Where SuiteUI's journeys run

SuiteUI has no app, and `Package.swift` (protected) has no gallery target.
So the harness feature adds a **gallery behind a launch flag** that needs
no app change and no manifest change:

- `SuiteWindow` checks its process arguments once. With `-SuiteGallery
  <page>` it shows `SuiteGallery(page:)` in place of the app's sidebar,
  content and inspector. Without the flag nothing changes. Every
  `SuiteWindow` app can host it; the journeys launch **Library**, whose
  window stays a `SuiteWindow` in every app plan (Flare and Halo may move to
  `EditorShell`). Pages that need the editor look draw an `EditorShell`
  inside the gallery, so both shells are covered.
- Each page holds real SuiteUI components over the page's own `@State`
  (allowed: SuiteUI is not under the app-state rule) and a **log**: a `Text`
  with identifier `suite.gallery.log` whose accessibility *label* is the
  last thing a host would have received, for example `value 45 · ends 1`.
  The label, not the value, because XCUITest reads many SwiftUI values as
  empty (#262).
- Two more flags serve the gallery only: `-SuiteGalleryFakes` runs a page
  on the section 5 Fakes instead of the live rules (for UI work before a
  conformance lands), and `-SuiteGalleryWidth <points>` pins an inspector
  page's panel width (SJ24).
- Every control on a page carries a `suite.gallery.<page>.<name>`
  identifier. `ControlInventory` (probes) publishes every control's
  identifier, enabled state and reason as `suite.controls` under
  `-SuitePerfProbe`, the same flag that publishes `suite.perf`.
- `project.yml` gains one bundle, `SuiteJourneyTests`, from the same
  `Journey` template; after #333 the template compiles
  `UITests/<target>*.swift`, so each feature owns its own
  `UITests/SuiteJourneyTests+<Area>.swift` (section 8 lists them).
  `Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery",
  page])` launches it. The new `name:` parameter (suite-harness edits
  `UITests/Journey.swift` for it) names the shots `suiteui-<page>-<step>`
  and tallies the audit under a new `suiteui` key in
  `UITests/audit-baseline.json`, at **0 for every check**, so gallery
  shots never move Library's counts and the gallery starts clean (adding an
  app key at 0 does not loosen the audit; question Q3 asks the captain to
  confirm).

Question Q2 offers the alternative: a dedicated gallery executable target.

**Waiting.** No journey asserts timing through an XCUI query. State is
awaited with `waitForExistence` or a label predicate (2 s); timing comes
from `suite.perf` (section 7). Every step takes a `shot`, so every step is
audited.

**States.** Each journey names the empty, error and loading states it
passes through. For a component, *empty* is "no items or no document",
*error* is "input refused or invalid, nothing changed", *loading* is
"content not ready yet" (a thumbnail without pixels, a probe with no
samples). "none" means the component has no such state, said on purpose.

### 4.2 Tier-1 journeys

Page names are the gallery's (section 6.2). "Log reads" means the label of
`suite.gallery.log`. ⇧ Shift, ⌥ Option, ⌘ Command.

| # | Test (file) | Page | Steps (each one shot) | Asserts | Empty · error · loading |
|---|---|---|---|---|---|
| SJ0 | `testGalleryOpensEveryPage` (`SuiteJourneyTests.swift`) | `index`, then each | launch with `-SuiteGallery index -SuitePerfProbe`; open each page from the index list; launch with `-SuiteGallery nosuch` | each page's root `suite.gallery.<page>` exists; `suite.controls` parses and lists every `suite.gallery.*` control on the page, each enabled or with a non-empty reason; the second launch shows an `EmptyStateView` reading "No gallery page named nosuch." | empty: unknown page message · error: none · loading: none |
| SJ1 | `testShellsFitAtEveryWidth` (`+Chrome`) | `window`, then `editor` | for each page, drag the window's bottom-right corner to widths 880 (`SuiteSize.windowMinimum.width` on dev), 1024, 1280 and 1440 pt; shot at each | every `suite.*` region frame (sidebar, inspector, canvas, tools, timeline) lies inside the window with 1 pt slack; no two regions overlap by more than 1 pt; content is at least `SuiteSize.contentMinimum.width` wide; the right panel is exactly `editorPanelWidth`; the app audit's `offscreen` and `overlap` counts on these shots are 0 | none · none · none |
| SJ2 | `testEditorShellTimelineSlot` (`+Chrome`) | `editor`, `editor-plain` | drag the slot's divider up 120 pt; drag it to the top of the window; double-click the divider (collapse); double-click again (restore); open `editor-plain` | slot height grows by 120 (±1); stops at its maximum (canvas keeps `contentMinimum.height`); collapse leaves only the slot's toolbar row and the canvas grows by the difference; restore returns the last height; `editor-plain` (no timeline) has no divider element and its canvas fills the shell exactly as today | empty: shell without timeline · error: none · loading: none |
| SJ3 | `testTopBarCommandsAndSaveStatus` (`+Chrome`) | `editor` | click New (outlined); hover Export (primary); click Undo (icon-only); hover the disabled Redo; set the page's save state to unsaved, then failed, then saved | log reads `command new`; exactly one element is primary and it is the right-most; Undo's label is "Undo" with no visible title; Redo's tooltip is its `unavailableHelp`; save status reads "Saved", then the unsaved dot with label "Unsaved changes", then "Not saved" with the warning triangle | empty: none · error: "Not saved" · loading: none |
| SJ4 | `testToolRailSelectsAndExplains` (`+Chrome`) | `editor` | click the second tool; click the canvas, press the first tool's key; hover the disabled tool; click it | log reads `tool b`, then `tool a`; the selected tool's value is "selected"; the disabled tool's tooltip is its reason and clicking it leaves the log unchanged | empty: none · error: none · loading: none |
| SJ5 | `testTransportPlaysStepsAndLoops` (`+Chrome`) | `editor` | click Play; click Pause; click step forward twice; click Go to End; click step forward; toggle Loop; click step forward | Play's label becomes "Pause" while playing; log reads `frame f+2` after the steps; at the end, step forward stays on the last frame with loop off and wraps to 0 with loop on; timecode text reads `00:01 / 00:02` style (current / total) | empty: duration 0 disables every button with "Nothing to play." · error: none · loading: none |
| SJ6 | `testStatusPills` (`+Chrome`) | `editor` | read the pills; click the toggle pill; click it again; switch the page's warning on | zoom pill text equals `ViewerZoom.percentText` of the page zoom; size pill "1920 × 1080"; toggle pill value On, then Off, log `toggle onion`; the warning pill shows its triangle and label | empty: no trailing pills · error: warning pill · loading: none |
| SJ7 | `testEmptyStateOffersAction` (`+Chrome`) | `empty` | read it; click its button; open the variant without an action | title, message and one primary button; log `action new`; the variant has no button | empty: itself · error: none · loading: none |
| SJ8 | `testSegmentedTabsSwitch` (`+Chrome`) | `editor` | click the second tab; press ← with the tabs focused | log `tab layers`, then `tab adjust`; the selected tab's value is "selected" | none · none · none |
| SJ9 | `testCanvasZoomPanAndDrag` (`+Canvas`) | `canvas` | ⌘+ twice; ⌘0; drag 100 pt right from the artboard's corner; Space-drag 100 pt; press → with the canvas focused; open `canvas-pt` | zoom pill 200 %, then the fit value; log `drag (0,0)→(100,0) ends 1` in document pixels at 100 %; the Space-drag moves the scroll position and adds no drag to the log; → scrolls a tenth of the viewport; `canvas-pt`'s ruler corner reads "pt" (#264) | empty: a 0 × 0 document fits at the smallest zoom and draws no artboard · error: none · loading: none |
| SJ10 | `testSelectionHandlesAtEveryZoom` (`+Canvas`) | `marks` | at zoom 25 %, 100 % and 400 %: drag the bottom-right handle 50 pt out; ⇧-drag it; drag the rotate zone a quarter turn | log names `handle bottomRight` and the new rect each time; each handle's hit frame is at least 12 × 12 pt at every zoom; ⇧ keeps the aspect ratio (±1 px); the rotate drag logs `rotate 90` (±1) | empty: no selection draws no handles · error: none · loading: none |
| SJ11 | `testBarSliderScrubTypeAndStep` (`+Inspector`) | `inspector` | drag the Rotation bar 40 pt right; ⇧-drag 4 pt; ⌥-drag 10 pt; click the value, type 72, Return; click, type `abc`, Return; click, type 9, Escape; focus it, press → twice, ⇧→, End, Home; hover the disabled row | values +40, +40, +1 steps as `ScrubValue` says; 72; still 72 after `abc`; still 72 after Escape; then 73, 74, 84, the maximum, the minimum; log `ends n` grows by exactly one per drag, typed commit and key press; the disabled row's tooltip is its reason and dragging it changes nothing | empty: "Mixed" shows no marker · error: `abc` keeps the old value · loading: none |
| SJ12 | `testExactFieldAndColorRowEnd` (`+Inspector`) | `inspector` | drag the X field 30 pt; press ↑; click the FILL hex, type `FF3B30`, Return; type `zz`, Return; pick a color in the system panel | X +30 then +1, log `ends` +1 each (#718); fill reads `#FF3B30`, log `color #FF3B30 ends` +1; `zz` keeps `#FF3B30`; the panel pick logs one end when the panel closes | empty: none · error: `zz` refused · loading: none |
| SJ13 | `testSectionsPickersTogglesAndReset` (`+Inspector`) | `inspector` | click the TRANSFORM header; click it again; change a value; click Reset; choose "Round" in the Cap picker; click the checkbox row; hover the disabled action | the section collapses and expands; Reset appears only while the section differs and its hit frame is at least 20 × 20 pt and overlaps no other control (#622, #285); log `reset transform`; picker value "Round"; checkbox value toggles; the action's tooltip is its reason | empty: an empty section shows its header only · error: none · loading: none |
| SJ14 | `testKeyframeButtonStates` (`+Inspector`) | `inspector` | click Rotation's stopwatch; set the page to animated; set it to keyed-here; click the diamond | log `key add`, then `key remove`; values "Not animated", "Animated", "Keyed at this frame"; the row's frame width is the same in all three states | none · none · none |
| SJ15 | `testPresetsAndChips` (`+Inspector`) | `inspector` | click "Ease Out"; press → and Space; click the Onion chip twice | one preset on at a time, log `preset ease-out`, then the neighbour; chip value On, then Off | empty: no preset matches (selected nil) shows none on · error: none · loading: none |
| SJ16 | `testToneCurveAddMoveRemove` (`+Inspector`) | `curves` | click inside the well; drag the new point 20 pt up; press ↑; press Tab; drag a middle point out of the well; press Delete on the focused point | log points count +1, then moved, nudged by 0.01, focus moved, count −1, count −1; log `ends` +1 per gesture, nudge and delete | empty: two end points only cannot be deleted · error: none · loading: histogram missing draws no bars |
| SJ17 | `testLayerListToggleRenameReorder` (`+Lists`) | `layers` | click Ball's eye; click Shadow's lock; double-click Ball's title, type `Hero`, Return; focus Shadow, press Return, type `Taken`, Return; press Escape; drag Shadow above Hero; click a child row's eye (#589) | log `toggle eye ball`; Shadow's row is dimmed (title in secondary text, its value includes "locked"); log `rename ball Hero`; `Taken` is refused with the page's message inline under the row and the draft stays; Escape restores "Shadow"; log `move shadow 0`; the child's eye is its own element and logs `toggle eye child` | empty: "No layers yet." text · error: refused rename · loading: none |
| SJ18 | `testThumbnailGridSelectsByClickAndKeys` (`+Lists`) | `grid` | click item 3; ⇧-click item 6; ⌘-click item 4; press → | log selection `3,5,6`, then `3,4,5,6`… exactly as `GridSelection` gives; → moves the anchor one item | empty: no items shows the page's empty state · error: none · loading: an item without an image shows its caption on the placeholder fill |
| SJ19 | `testTimelineScrubSelectAndDragKeys` (`+Timeline`) | `timeline`, `timeline-long` | drag the ruler to frame 30; click Ball's key at 12; press →; drag the selected key 5 frames right; press ⌫ on it; toggle the page's recording; open `timeline-long` (10,000 frames) and scroll to the end | log `scrub 30`; `select ball 12`, then `select ball 24` (#63); `move ball 24→29 ends 1`; `delete ball 29`; the playhead pill reads 30; the recording ring element exists while on; `timeline-long` draws ruler labels at the end (#219) | empty: no tracks shows "No layers yet." · error: a drag past the end clamps to the last frame · loading: none |
| SJ24 | `testInspectorRowsAlignAtEveryWidth` (`+Inspector`) | `inspector` | launch with `-SuiteGalleryWidth` 200, 240, 280 and 360 in turn; shot each | every row's leading and trailing edges equal (±0.5 pt); every value's trailing edge equal; every label and value frame inside its row (QB-S19) | empty: none · error: none · loading: none |
| SJ25 | `testEveryControlMeetsHitSize` (`SuiteJourneyTests.swift`) | each page | read `suite.controls` on each page; measure each listed control's frame | every control is at least 20 × 20 pt, and the ones the token table lists at their hit size (QB-S20) | empty: a page with no controls passes with a count of 0 · error: none · loading: none |

### 4.3 Tier-2 and tier-3 journeys

| # | Test (file) | Page | Steps | Asserts |
|---|---|---|---|---|
| SJ20 | `testEasingCurveHandles` (`+Inspector`) | `curves` | drag handle 1; Tab; press ↑; ⇧↑ | one `ends` per gesture; values change by 0.01 and 0.1; the preview dot is absent under the page's Reduce Motion switch (probe mark, #343) |
| SJ21 | `testPointAndGridMarks` (`+Canvas`) | `marks` | show the point mark at zoom 1 and 4 over light and dark pixels; show the grid | the mark's on-screen size is the same at both zooms; it takes no click (the drag under it logs); the grid draws `cells` lines (#706, #737, #530) |
| SJ22 | `testRowContextMenus` (`+Lists`) | `layers` | right-click Ball; choose Duplicate; right-click again; hover the disabled Delete | log `menu duplicate ball`; Delete is disabled and its reason is the item's help (#73) |
| SJ23 | `testNodeGraphDrawsAndSelects` (`+Graph`) | `graph` | click node B; click the arrow A→B; open `graph-loop` | log `select node b`, `select edge a-b`; each arrow's ends lie on its nodes' edges (±1 pt); the self-loop draws outside its node; the warning badge has its triangle and label (#344) |

### 4.4 Perf journeys (report-only first, section 7)

| # | Test (file) | Page | Steps | Measures |
|---|---|---|---|---|
| SP1 | `testBarSliderScrubLatency` (`+Inspector`) | `inspector` | velocity-controlled drag across a bar slider, 300 pt/s | frames late, at least 60 samples |
| SP2 | `testCanvasDragLatency` (`+Canvas`) | `canvas` | drag on the canvas, then Space-pan, 300 pt/s | frames late per series |
| SP3 | `testTimelineScrubLatency` (`+Timeline`) | `timeline-long` | drag the playhead across the ruler | frames late |
| SP4 | `testListAndGridScroll` (`+Lists`) | `layers-300`, `grid-2000` | scroll each end to end | frame interval p95 |
| SP5 | `testHandleDragLatency` (`+Canvas`) | `marks` | drag a handle at 300 pt/s | frames late |

Each perf test lives in the journey file of the feature that owns its page.
The harness feature supplies only the helpers they call
(`UITests/Journey+Input.swift`: velocity drag, `perf()`, the 60-sample
validity check), so no two features share a perf file.

---

## 5. Contracts

### 5.1 Where they live and how Linux compiles them

One Swift protocol per use case, over Foundation-only value types, with a
Fake for each, so a component's view and its rules can be built in
parallel: a UI builder draws against the Fake, a logic builder writes the
live conformance and its tests, and the gallery page switches between them
(`-SuiteGalleryFakes`).

- **Files.** `Sources/SuiteUI/Contracts/<Protocol>.swift`, one per use case,
  holding the protocol, its value types and its Fake; the shared types in
  `Contracts/ContractTypes.swift`. Live conformances sit next to the rule
  file they wrap (`ScrubValue.swift` gains `SuiteValueScrubbing`), so the
  contract folder never imports SwiftUI. The suite-harness feature lands all
  of `Contracts/` in its first task, exactly as below; later features add
  conformances, never signatures (a signature change is a blueprint change).
- **Linux.** Nothing under `Sources/SuiteUI/` builds on Linux today, and
  `Package.swift` is protected, so the contracts cannot live in a Linux
  target without the captain (question Q1). Until then: they import
  Foundation through the `FoundationEssentials` pattern, use no SwiftUI,
  AppKit or CoreGraphics type (no `CGFloat`, `CGPoint`, `Color`,
  `KeyEquivalent`), and reuse exactly one existing type, `ScrubKey`, whose
  declaration has no imports. They were compiled and run on Linux for this
  blueprint (Swift 6.3.3, language mode 6, warnings as errors):

  ```
  swiftc -swift-version 6 -warnings-as-errors Shim.swift Contracts.swift main.swift -o check && ./check
  contracts: every fake ran
  ```

  The three files are in `docs/blueprints/suiteui/contracts/`:
  `Contracts.swift` (the code below, verbatim), `Shim.swift` (`ScrubKey`,
  copied from `ScrubValue.swift`) and `main.swift` (calls every Fake once
  with a concrete input and checks the literal result). Anyone can rerun the
  command after an edit. Once Q1 lands, the same files move into the Linux
  target and `scripts/ci` runs them on every PR.
- **Rules.** Value types, `Sendable`, explicit public inits; no `try!`,
  `as!`, force unwraps, unchecked indexing or division by a value that can
  be zero (each Fake guards its divisions, as the live rules do). Every
  method that a gesture drives says how it ends: components emit `onEnd`
  through `EditRun`, one end per drag, typed commit, key press or nudge.

### 5.2 The use cases

| UC | Protocol | Journeys | Live conformance wraps (on dev unless planned) | What its Fake gets wrong on purpose | Feature |
|---|---|---|---|---|---|
| – | `EditRun` (a struct, shared) | SJ11–SJ17, SJ19, SJ20 | new; used by `ScrubField`, `ColorWell`, `CurveEditor`, `ToneCurveEditor`, `TimelineStrip`, `SidebarRow` | none: it is the rule | suite-harness |
| UC1 | `ValueScrubbing` (+ `TrackStepping`) | SJ11, SJ12, SP1 | `ScrubValue.dragged/pressed/fraction`, `NumericInput.committed/text/spoken`, `ScrubTrack` (+ #591's `stepped`) | no snapping, plain text | inspector-controls |
| UC2 | `HexColorEditing` | SJ12 | `HexColor` in `ColorWell.swift` (its parsing moves to a Foundation-only extension) | no `#RGB` shorthand | inspector-controls |
| UC3 | `KeyframeFacing` | SJ14 | `KeyState` (its `symbol`, `voiceOverValue`, `diamond`; `color` stays in the view) | none needed: it is a table | inspector-controls |
| UC4 | `PresetNavigating` | SJ15 | `PresetGrid.neighbor` (takes `GridArrow` instead of `KeyEquivalent`) | wraps at the edges | inspector-controls |
| UC5 | `ShellLayingOut` | SJ1, SJ2 | planned `ShellLayout.swift`; the column sums now in `SuiteSize.windowMinimum` | no slot clamping | editor-chrome |
| UC6 | `ToolPicking` | SJ4 | `ToolbarAction.help`, `isEnabled`, `shortcut`, `PaletteTool` | does not flag duplicate shortcuts | editor-chrome |
| UC7 | `CanvasNavigating` | SJ9, SP2 | `ZoomMath`, `ViewerZoom.fitScale`, `CanvasViewport`'s pan step | doubles and halves instead of the zoom stops | canvas-marks |
| UC8 | `HandleGeometryProviding` | SJ10, SP5 | planned `HandleGeometry.swift` (from Design's selection marks, #273) | corners only | canvas-marks |
| UC9 | `GridSelecting` | SJ18, SP4 | `GridSelection.click/move/columns` | single selection only | lists-and-layers |
| UC10 | `ListEditing` | SJ17, SJ22 | planned `ListEditing.swift`; today the rename draft rules sit inside `SidebarRow` | never refuses | lists-and-layers |
| UC11 | `TimelineMapping` | SJ19, SP3 | `FrameMapping` | a label every 10 frames, no ticks | timeline |
| UC12 | `KeyEditing` | SJ19 | planned `TimelineKeys.swift` (#63) | clamps each key, not the group | timeline |
| UC13 | `TransportStepping` | SJ5 | planned, in `TransportCapsule.swift`'s Foundation-only half | never wraps, frames not timecode | editor-chrome |
| UC14 | `StatusPillComposing` | SJ6 | `ViewerStatusBar`'s zoom and size facts, `ViewerZoom.percentText` | raw zoom text | editor-chrome |
| UC15 | `CurvePointEditing` | SJ16, SJ20 | `ToneCurveEditor.added/moved/removed/nudged`, `CurveEditor.nudged` | unsorted, never refuses | inspector-controls |
| UC16 | `GraphGeometry` | SJ23 | planned `NodeGraphGeometry.swift` (#344) | center to center | node-graph |
| UC17 | `FrameProbeRecording` | SP1–SP5, section 7 | planned `FrameProbe.swift` (#330) | every sample 0 frames late | suite-harness |
| UC18 | `ControlInventorying` | SJ0, every app's every-control sweep | planned `ControlInventory.swift` | no duplicate check | suite-harness |
| UC19 | `GoldenComparing` | every golden (QB-V2–V5) | planned `Tests/AppSnapshotTests/GoldenImage.swift` (#331) | exact match only, no diff image | suite-harness |

**Views with no contract, on purpose.** `EmptyStateView`, `SurfaceCard`,
`SegmentedTabs`, `InspectorHeader`, `InspectorAction`, `GlassPanel` and the
marks' drawing hold no rule a Model or a second view could share; their
journeys (SJ3's save status, SJ7, SJ8) and goldens prove them directly, and
their inputs are already plain values (`ToolbarAction`, `InspectorFact`).
Inventing a protocol for them would be a wrapper with one caller and no
decision in it (`docs/engineering.md`, Reading cost).

### 5.3 The code (`docs/blueprints/suiteui/contracts/Contracts.swift`)

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: 5.1 Shared value types (Contracts/ContractTypes.swift)

/// A point in points (view space) or document pixels; the call says which.
public struct PlanePoint: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// A width and height. Not called "Size": `SuiteSize` is the size token enum.
public struct PlaneExtent: Hashable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

public struct PlaneRect: Hashable, Sendable {
    public var origin: PlanePoint
    public var extent: PlaneExtent
    public init(x: Double, y: Double, width: Double, height: Double) {
        origin = PlanePoint(x: x, y: y); extent = PlaneExtent(width: width, height: height)
    }
    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + extent.width }
    public var maxY: Double { origin.y + extent.height }
    public var mid: PlanePoint { PlanePoint(x: origin.x + extent.width / 2, y: origin.y + extent.height / 2) }
    public func contains(_ p: PlanePoint) -> Bool { p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY }
}

public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let shift = KeyModifiers(rawValue: 1)    // coarse ×10, constrain, extend
    public static let option = KeyModifiers(rawValue: 2)   // fine ×0.1
    public static let command = KeyModifiers(rawValue: 4)  // toggle in a selection
}

public enum GridArrow: Sendable, CaseIterable { case left, right, up, down }

/// One gesture, one end. Every component that reports `onEnd` keeps one of
/// these: a drag, a typed commit, a key press or a nudge opens a run with its
/// first change and closes it once, so the host makes it one undo step.
public struct EditRun: Equatable, Sendable {
    public private(set) var isOpen = false
    public private(set) var ends = 0
    public init() {}
    /// Returns true when this change opened the run.
    public mutating func change() -> Bool {
        defer { isOpen = true }
        return !isOpen
    }
    /// Returns true exactly once per opened run; an end with no change is ignored.
    public mutating func end() -> Bool {
        guard isOpen else { return false }
        isOpen = false; ends += 1
        return true
    }
}

// MARK: 5.2 Use-case protocols, one per use case, each with its Fake

// UC1 · SJ11, SJ12, SP1 · Contracts/ValueScrubbing.swift
public struct ScrubSpec: Hashable, Sendable {
    public var range: ClosedRange<Double>
    public var step: Double
    public var decimals: Int
    public var unit: String
    public init(range: ClosedRange<Double>, step: Double, decimals: Int = 2, unit: String = "") {
        self.range = range; self.step = step; self.decimals = decimals; self.unit = unit
    }
}

/// A non-linear track (Photo's log gamma): the bar moves in positions, the
/// field shows values; `stepped` is #591's track-owned discrete step.
public protocol TrackStepping: Sendable {
    func position(of value: Double) -> Double
    func value(at position: Double) -> Double
    func stepped(_ position: Double, by direction: Double) -> Double
}

public protocol ValueScrubbing: Sendable {
    /// Press-and-drag scrubs relative to `start`: one step per point, ⇧ ×10, ⌥ ×0.1; clamped and snapped.
    func dragged(from start: Double, by points: Double, modifiers: KeyModifiers, spec: ScrubSpec) -> Double
    /// Arrows step (⇧ coarse, ⌥ fine), Home and End jump to the ends; on a track the track steps.
    func pressed(_ key: ScrubKey, from value: Double, modifiers: KeyModifiers, spec: ScrubSpec,
                 track: (any TrackStepping)?) -> Double
    /// The typed text when the field closes. Text that isn't a number keeps `old`.
    func committed(_ text: String, opening: String, old: Double, spec: ScrubSpec) -> Double
    /// How far the bar's fill reaches, 0...1.
    func fraction(_ value: Double, spec: ScrubSpec) -> Double
    /// What the row shows ("45°") and what VoiceOver reads ("45 degrees").
    func text(_ value: Double, spec: ScrubSpec) -> String
    func spoken(_ value: Double, spec: ScrubSpec) -> String
}

/// Linear and unsnapped, two decimals: enough to build and snapshot a row before the live rules are wired.
public struct FakeValueScrubbing: ValueScrubbing {
    public init() {}
    private func clamp(_ v: Double, _ r: ClosedRange<Double>) -> Double { v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : r.lowerBound }
    private func mult(_ m: KeyModifiers) -> Double { m.contains(.option) ? 0.1 : m.contains(.shift) ? 10 : 1 }
    public func dragged(from start: Double, by points: Double, modifiers: KeyModifiers, spec: ScrubSpec) -> Double {
        clamp(start + points * spec.step * mult(modifiers), spec.range)
    }
    public func pressed(_ key: ScrubKey, from value: Double, modifiers: KeyModifiers, spec: ScrubSpec,
                        track: (any TrackStepping)?) -> Double {
        switch key {
        case .home: return spec.range.lowerBound
        case .end: return spec.range.upperBound
        case .increment, .decrement:
            let direction: Double = key == .increment ? 1 : -1
            if let track { return clamp(track.value(at: track.stepped(track.position(of: value), by: direction)), spec.range) }
            return clamp(value + direction * spec.step * mult(modifiers), spec.range)
        }
    }
    public func committed(_ text: String, opening: String, old: Double, spec: ScrubSpec) -> Double {
        Double(String(text.filter { $0 != " " })).map { clamp($0, spec.range) } ?? old
    }
    public func fraction(_ value: Double, spec: ScrubSpec) -> Double {
        let span = spec.range.upperBound - spec.range.lowerBound
        return span > 0 ? clamp((value - spec.range.lowerBound) / span, 0...1) : 0
    }
    public func text(_ value: Double, spec: ScrubSpec) -> String { "\(value)\(spec.unit)" }
    public func spoken(_ value: Double, spec: ScrubSpec) -> String { spec.unit.isEmpty ? "\(value)" : "\(value) \(spec.unit)" }
}

// UC2 · SJ12 · Contracts/HexColorEditing.swift
public struct RGB8: Hashable, Sendable {
    public var red: UInt8, green: UInt8, blue: UInt8
    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) { self.red = red; self.green = green; self.blue = blue }
}

public protocol HexColorEditing: Sendable {
    /// "#RRGGBB", "RRGGBB" or "#RGB" in either case; nil otherwise.
    func parse(_ text: String) -> RGB8?
    /// The color after the hex field closes: the parsed color, or `old` for text that isn't one.
    func committed(_ text: String, old: RGB8) -> RGB8
    /// Always "#RRGGBB", upper case.
    func format(_ color: RGB8) -> String
}

/// Accepts six hex digits only (no "#RGB" shorthand).
public struct FakeHexColorEditing: HexColorEditing {
    public init() {}
    public func parse(_ text: String) -> RGB8? {
        let digits = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard digits.count == 6, let v = UInt32(digits, radix: 16) else { return nil }
        return RGB8(UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF))
    }
    public func committed(_ text: String, old: RGB8) -> RGB8 { parse(text) ?? old }
    public func format(_ c: RGB8) -> String {
        let hex = [c.red, c.green, c.blue].map { b -> String in
            let s = String(b, radix: 16, uppercase: true); return s.count == 1 ? "0" + s : s
        }
        return "#" + hex.joined()
    }
}

// UC3 · SJ14 · Contracts/KeyframeFacing.swift
public enum KeyPresence: Sendable, CaseIterable { case idle, animated, keyedHere }
public enum KeyAction: Sendable { case add, remove }

public struct KeyframeFace: Hashable, Sendable {
    public var symbol: String
    public var diamondSymbol: String?       // nil: the slot is reserved but empty
    public var diamondAction: KeyAction?
    public var spoken: String
    public init(symbol: String, diamondSymbol: String?, diamondAction: KeyAction?, spoken: String) {
        self.symbol = symbol; self.diamondSymbol = diamondSymbol; self.diamondAction = diamondAction; self.spoken = spoken
    }
}

public protocol KeyframeFacing: Sendable {
    func face(for presence: KeyPresence) -> KeyframeFace
}

public struct FakeKeyframeFacing: KeyframeFacing {
    public init() {}
    public func face(for presence: KeyPresence) -> KeyframeFace {
        switch presence {
        case .idle: KeyframeFace(symbol: "stopwatch", diamondSymbol: nil, diamondAction: nil, spoken: "Not animated")
        case .animated: KeyframeFace(symbol: "stopwatch.fill", diamondSymbol: "diamond", diamondAction: .add, spoken: "Animated")
        case .keyedHere: KeyframeFace(symbol: "stopwatch.fill", diamondSymbol: "diamond.fill", diamondAction: .remove, spoken: "Keyed at this frame")
        }
    }
}

// UC4 · SJ15 · Contracts/PresetNavigating.swift
public protocol PresetNavigating: Sendable {
    /// The preset an arrow key moves focus to in a grid of `count` presets in `columns` columns; nil at an edge.
    func neighbor(of index: Int, _ arrow: GridArrow, count: Int, columns: Int) -> Int?
}

/// Wraps instead of stopping at the edges (the live rule stops), so a UI built on it must not rely on wrapping.
public struct FakePresetNavigating: PresetNavigating {
    public init() {}
    public func neighbor(of index: Int, _ arrow: GridArrow, count: Int, columns: Int) -> Int? {
        guard count > 0, columns > 0, (0..<count).contains(index) else { return nil }
        let delta = switch arrow { case .left: -1; case .right: 1; case .up: -columns; case .down: columns }
        return ((index + delta) % count + count) % count
    }
}

// UC5 · SJ1, SJ2 · Contracts/ShellLayingOut.swift
public struct ShellMetrics: Hashable, Sendable {
    public var leadingWidth: Double          // the rail (EditorShell) or the sidebar's ideal (SuiteWindow)
    public var trailingWidth: Double         // the right panel or the inspector's ideal
    public var contentMinimum: PlaneExtent
    public var slotMinimum: Double           // the timeline slot when open
    public var slotToolbar: Double           // what stays when collapsed
    public init(leadingWidth: Double, trailingWidth: Double, contentMinimum: PlaneExtent,
                slotMinimum: Double, slotToolbar: Double) {
        self.leadingWidth = leadingWidth; self.trailingWidth = trailingWidth; self.contentMinimum = contentMinimum
        self.slotMinimum = slotMinimum; self.slotToolbar = slotToolbar
    }
}

public struct ShellColumns: Hashable, Sendable {
    public var leading: Double, content: Double, trailing: Double
    /// False when the window is narrower than the three columns' minimum (the window minimum prevents it).
    public var fits: Bool
    public init(leading: Double, content: Double, trailing: Double, fits: Bool) {
        self.leading = leading; self.content = content; self.trailing = trailing; self.fits = fits
    }
}

public struct TimelineSlot: Hashable, Sendable {
    public var height: Double
    public var collapsed: Bool
    public var lastOpenHeight: Double
    public init(height: Double, collapsed: Bool = false, lastOpenHeight: Double? = nil) {
        self.height = height; self.collapsed = collapsed; self.lastOpenHeight = lastOpenHeight ?? height
    }
}

public protocol ShellLayingOut: Sendable {
    /// Leading and trailing columns keep their widths; the content takes the rest, never below its minimum.
    func columns(windowWidth: Double, metrics: ShellMetrics) -> ShellColumns
    /// A divider drag of `dy` points (up is negative), clamped so the canvas keeps its minimum height.
    func slot(_ slot: TimelineSlot, dragged dy: Double, available height: Double, metrics: ShellMetrics) -> TimelineSlot
    /// Collapse to the toolbar row, or restore the last open height.
    func toggled(_ slot: TimelineSlot, metrics: ShellMetrics) -> TimelineSlot
}

/// No clamping on the slot: fine for building the divider's look, wrong for SJ2's limits.
public struct FakeShellLayingOut: ShellLayingOut {
    public init() {}
    public func columns(windowWidth: Double, metrics: ShellMetrics) -> ShellColumns {
        let content = windowWidth - metrics.leadingWidth - metrics.trailingWidth
        return ShellColumns(leading: metrics.leadingWidth, content: max(content, metrics.contentMinimum.width),
                            trailing: metrics.trailingWidth, fits: content >= metrics.contentMinimum.width)
    }
    public func slot(_ slot: TimelineSlot, dragged dy: Double, available height: Double, metrics: ShellMetrics) -> TimelineSlot {
        let h = slot.height - dy
        return TimelineSlot(height: h, collapsed: false, lastOpenHeight: h)
    }
    public func toggled(_ slot: TimelineSlot, metrics: ShellMetrics) -> TimelineSlot {
        slot.collapsed ? TimelineSlot(height: slot.lastOpenHeight, collapsed: false, lastOpenHeight: slot.lastOpenHeight)
                       : TimelineSlot(height: metrics.slotToolbar, collapsed: true, lastOpenHeight: slot.height)
    }
}

// UC6 · SJ4 · Contracts/ToolPicking.swift
public struct ToolFace: Hashable, Sendable {
    public var id: String
    public var title: String
    public var shortcut: Character?
    public var unavailableHelp: String?
    public init(id: String, title: String, shortcut: Character? = nil, unavailableHelp: String? = nil) {
        self.id = id; self.title = title; self.shortcut = shortcut; self.unavailableHelp = unavailableHelp
    }
}

public protocol ToolPicking: Sendable {
    /// The enabled tool whose one-key shortcut is `key` (case-insensitive), if any.
    func tool(forKey key: Character, in tools: [ToolFace]) -> String?
    /// The tooltip: "Brush (B)" while enabled, the reason while not.
    func help(for tool: ToolFace) -> String
    /// Ids that break the palette's rules: disabled with an empty reason, or a shortcut used twice.
    func violations(in tools: [ToolFace]) -> [String]
}

public struct FakeToolPicking: ToolPicking {
    public init() {}
    public func tool(forKey key: Character, in tools: [ToolFace]) -> String? {
        tools.first { $0.unavailableHelp == nil && $0.shortcut.map { $0.lowercased() == key.lowercased() } == true }?.id
    }
    public func help(for tool: ToolFace) -> String {
        if let reason = tool.unavailableHelp { return reason }
        return tool.shortcut.map { "\(tool.title) (\($0.uppercased()))" } ?? tool.title
    }
    public func violations(in tools: [ToolFace]) -> [String] {
        tools.filter { $0.unavailableHelp?.isEmpty == true }.map(\.id)
    }
}

// UC7 · SJ9, SP2 · Contracts/CanvasNavigating.swift
public protocol CanvasNavigating: Sendable {
    /// 0.1...32 (10 % to 3200 %); a zoom that isn't a number is 1.
    func clamped(_ zoom: Double) -> Double
    func zoomedIn(from zoom: Double) -> Double
    func zoomedOut(from zoom: Double) -> Double
    /// The zoom that fits `document` inside `viewport` less `margin` on every side; never a division by zero.
    func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double
    /// A view point (in the canvas's content, scrolled) to document pixels.
    func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint
    /// How far an arrow key pans: a tenth of the viewport, ⇧ a whole one.
    func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint
}

/// Doubles and halves instead of the live zoom stops.
public struct FakeCanvasNavigating: CanvasNavigating {
    public init() {}
    public func clamped(_ zoom: Double) -> Double { zoom.isFinite ? min(max(zoom, 0.1), 32) : 1 }
    public func zoomedIn(from zoom: Double) -> Double { clamped(zoom * 2) }
    public func zoomedOut(from zoom: Double) -> Double { clamped(zoom / 2) }
    public func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double {
        let w = viewport.width - 2 * margin, h = viewport.height - 2 * margin
        guard w > 0, h > 0, document.width > 0, document.height > 0 else { return 0.1 }
        return clamped(min(w / document.width, h / document.height))
    }
    public func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint {
        let z = clamped(zoom)
        return PlanePoint(x: (view.x - artboardOrigin.x) / z, y: (view.y - artboardOrigin.y) / z)
    }
    public func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint {
        let f = modifiers.contains(.shift) ? 1.0 : 0.1
        switch arrow {
        case .left: return PlanePoint(x: -viewport.width * f, y: 0)
        case .right: return PlanePoint(x: viewport.width * f, y: 0)
        case .up: return PlanePoint(x: 0, y: -viewport.height * f)
        case .down: return PlanePoint(x: 0, y: viewport.height * f)
        }
    }
}

// UC8 · SJ10, SP5 · Contracts/HandleGeometryProviding.swift
public enum HandleKind: String, Sendable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, rotate
}

public protocol HandleGeometryProviding: Sendable {
    /// Each handle's hit rect in view points around `rect` (view points at the current zoom). The hit size
    /// is `SuiteSize.selectionHandle`'s hit (12 pt) at every zoom; the rotate zone sits outside the top-right corner.
    func handles(around rect: PlaneRect, hitSize: Double) -> [HandleKind: PlaneRect]
    /// The handle under `point`, corners before edges before rotate; nil when none.
    func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double) -> HandleKind?
    /// `rect` after dragging `handle` by `delta`, the opposite side fixed; `keepAspect` (⇧) scales evenly.
    func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect
    /// Degrees turned about `center` from `start` to `end`, clockwise positive (y-down), ⇧ snaps to 15°.
    func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double
}

/// Corner handles only; edges and rotate are never hit. Enough to draw handles, not for SJ10.
public struct FakeHandleGeometry: HandleGeometryProviding {
    public init() {}
    private func square(_ p: PlanePoint, _ s: Double) -> PlaneRect { PlaneRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s) }
    public func handles(around rect: PlaneRect, hitSize: Double) -> [HandleKind: PlaneRect] {
        [.topLeft: square(rect.origin, hitSize),
         .topRight: square(PlanePoint(x: rect.maxX, y: rect.minY), hitSize),
         .bottomRight: square(PlanePoint(x: rect.maxX, y: rect.maxY), hitSize),
         .bottomLeft: square(PlanePoint(x: rect.minX, y: rect.maxY), hitSize)]
    }
    public func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double) -> HandleKind? {
        handles(around: rect, hitSize: hitSize).first { $0.value.contains(point) }?.key
    }
    public func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect {
        guard handle == .bottomRight else { return rect }
        return PlaneRect(x: rect.minX, y: rect.minY, width: max(rect.extent.width + delta.x, 0), height: max(rect.extent.height + delta.y, 0))
    }
    public func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double { 0 }
}

// UC9 · SJ18, SP4 · Contracts/GridSelecting.swift
public enum ClickKind: Sendable { case plain, extend, toggle }   // click, ⇧-click, ⌘-click

public struct GridPick<ID: Hashable & Sendable>: Equatable, Sendable {
    public var selection: Set<ID>
    public var anchor: ID?
    public init(selection: Set<ID> = [], anchor: ID? = nil) { self.selection = selection; self.anchor = anchor }
}

public protocol GridSelecting: Sendable {
    func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID>
    func move<ID: Hashable & Sendable>(_ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int) -> GridPick<ID>
    /// Adaptive columns for `width`; at least 1.
    func columns(width: Double, minimum: Double, spacing: Double) -> Int
}

/// Single selection only: every click selects just that item; arrows move one item and never extend.
public struct FakeGridSelecting: GridSelecting {
    public init() {}
    public func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID> {
        order.contains(id) ? GridPick(selection: [id], anchor: id) : current
    }
    public func move<ID: Hashable & Sendable>(_ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int) -> GridPick<ID> {
        guard let anchor = current.anchor, let i = order.firstIndex(of: anchor) else { return current }
        let step = switch arrow { case .left: -1; case .right: 1; case .up: -max(columns, 1); case .down: max(columns, 1) }
        let j = i + step
        guard order.indices.contains(j) else { return current }
        return GridPick(selection: [order[j]], anchor: order[j])
    }
    public func columns(width: Double, minimum: Double, spacing: Double) -> Int {
        guard minimum > 0, width.isFinite else { return 1 }
        return max(1, Int((width + spacing) / (minimum + spacing)))
    }
}

// UC10 · SJ17, SJ22 · Contracts/ListEditing.swift
public enum RenameOutcome: Equatable, Sendable {
    case renamed(String)
    case refused(message: String, draft: String)   // the row keeps the draft and shows the message
    case unchanged                                 // empty, whitespace only, or the same title
    case cancelled                                 // Escape
}

public protocol ListEditing: Sendable {
    /// `validate` is the app's check: nil accepts, a message refuses (#577).
    func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome
    func cancelRename(_ draft: String, original: String) -> RenameOutcome
    /// The order after moving `id` to `index` (an index in the order without it, clamped).
    func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID]
    /// Where a drop at `y` (points from the list's top) lands among `count` rows of `rowHeight`.
    func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int
}

/// Never refuses and never trims: it ignores `validate`, so refusal UI can't be built on it.
public struct FakeListEditing: ListEditing {
    public init() {}
    public func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome {
        draft == original ? .unchanged : .renamed(draft)
    }
    public func cancelRename(_ draft: String, original: String) -> RenameOutcome { .cancelled }
    public func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID] {
        var rest = order.filter { $0 != id }
        guard rest.count < order.count else { return order }
        rest.insert(id, at: min(max(index, 0), rest.count))
        return rest
    }
    public func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int {
        guard rowHeight > 0, y.isFinite else { return 0 }
        return min(max(Int((y / rowHeight).rounded()), 0), count)
    }
}

// UC11 · SJ19, SP3 · Contracts/TimelineMapping.swift
public struct TimelineScale: Hashable, Sendable {
    public var duration: Int          // frames; below 0 counts as 0
    public var frameWidth: Double     // points per frame; 0, negative or NaN maps every x to frame 0
    public init(duration: Int, frameWidth: Double) { self.duration = duration; self.frameWidth = frameWidth }
}

public struct RulerMarkSet: Equatable, Sendable {
    public var ticks: [Int]
    public var labels: [Int]
    public init(ticks: [Int], labels: [Int]) { self.ticks = ticks; self.labels = labels }
}

public protocol TimelineMapping: Sendable {
    func x(forFrame frame: Int, scale: TimelineScale) -> Double
    /// Always inside 0...duration.
    func frame(atX x: Double, scale: TimelineScale) -> Int
    /// The key nearest `x` within `tolerance` points, if any.
    func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double, scale: TimelineScale) -> Int?
    /// Ticks and labels inside the visible stretch only, so a long timeline costs no more than a short one.
    func rulerMarks(visible: ClosedRange<Double>, minimumSpacing: Double, scale: TimelineScale) -> RulerMarkSet
}

/// A label every 10 frames and no ticks.
public struct FakeTimelineMapping: TimelineMapping {
    public init() {}
    public func x(forFrame frame: Int, scale: TimelineScale) -> Double { Double(frame) * max(scale.frameWidth, 0) }
    public func frame(atX x: Double, scale: TimelineScale) -> Int {
        guard scale.frameWidth > 0, x.isFinite else { return 0 }
        return min(max(Int((x / scale.frameWidth).rounded()), 0), max(scale.duration, 0))
    }
    public func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double, scale: TimelineScale) -> Int? {
        keyframes.first { abs(self.x(forFrame: $0, scale: scale) - x) <= tolerance }
    }
    public func rulerMarks(visible: ClosedRange<Double>, minimumSpacing: Double, scale: TimelineScale) -> RulerMarkSet {
        let lo = frame(atX: visible.lowerBound, scale: scale), hi = frame(atX: visible.upperBound, scale: scale)
        return RulerMarkSet(ticks: [], labels: Array(stride(from: (lo / 10) * 10, through: hi, by: 10)))
    }
}

// UC12 · SJ19 · Contracts/KeyEditing.swift
public struct KeyRef: Hashable, Sendable {
    public var track: String
    public var frame: Int
    public init(track: String, frame: Int) { self.track = track; self.frame = frame }
}

public protocol KeyEditing: Sendable {
    /// The key the selection moves to with ← or → (`direction` −1 or +1): along the same track, nil at its ends (#63).
    func nextKey(after key: KeyRef, direction: Int, tracks: [String: [Int]]) -> KeyRef?
    /// Whole frames a drag of `points` moves keys by.
    func frameDelta(points: Double, scale: TimelineScale) -> Int
    /// Old key to new frame for moving `keys` by `delta`, clamped as a group so none leaves 0...duration.
    func moved(_ keys: Set<KeyRef>, by delta: Int, duration: Int) -> [KeyRef: Int]
}

/// Moves each key on its own, clamping each (the live rule clamps the group).
public struct FakeKeyEditing: KeyEditing {
    public init() {}
    public func nextKey(after key: KeyRef, direction: Int, tracks: [String: [Int]]) -> KeyRef? {
        let frames = (tracks[key.track] ?? []).sorted()
        guard let i = frames.firstIndex(of: key.frame), frames.indices.contains(i + direction) else { return nil }
        return KeyRef(track: key.track, frame: frames[i + direction])
    }
    public func frameDelta(points: Double, scale: TimelineScale) -> Int {
        scale.frameWidth > 0 && points.isFinite ? Int((points / scale.frameWidth).rounded()) : 0
    }
    public func moved(_ keys: Set<KeyRef>, by delta: Int, duration: Int) -> [KeyRef: Int] {
        Dictionary(uniqueKeysWithValues: keys.map { ($0, min(max($0.frame + delta, 0), max(duration, 0))) })
    }
}

// UC13 · SJ5 · Contracts/TransportStepping.swift
public struct TransportState: Hashable, Sendable {
    public var frame: Int
    public var duration: Int          // frames; 0 means nothing to play
    public var fps: Int
    public var isPlaying: Bool
    public var loops: Bool
    public init(frame: Int, duration: Int, fps: Int, isPlaying: Bool = false, loops: Bool = false) {
        self.frame = frame; self.duration = duration; self.fps = fps; self.isPlaying = isPlaying; self.loops = loops
    }
}

public struct TransportFace: Hashable, Sendable {
    public var playTitle: String              // "Play" or "Pause"
    public var unavailableHelp: String?       // every button's reason when nothing can play
    public var timecode: String               // "00:01 / 00:02"
    public init(playTitle: String, unavailableHelp: String?, timecode: String) {
        self.playTitle = playTitle; self.unavailableHelp = unavailableHelp; self.timecode = timecode
    }
}

public protocol TransportStepping: Sendable {
    /// Step `by` frames: stop at the ends, or wrap while `loops`.
    func stepped(_ state: TransportState, by frames: Int) -> TransportState
    func toStart(_ state: TransportState) -> TransportState
    func toEnd(_ state: TransportState) -> TransportState
    func face(_ state: TransportState) -> TransportFace
}

/// Never wraps and prints frames ("12 / 48") instead of a timecode.
public struct FakeTransportStepping: TransportStepping {
    public init() {}
    private func last(_ s: TransportState) -> Int { max(s.duration - 1, 0) }
    public func stepped(_ s: TransportState, by frames: Int) -> TransportState {
        var n = s; n.frame = min(max(s.frame + frames, 0), last(s)); return n
    }
    public func toStart(_ s: TransportState) -> TransportState { var n = s; n.frame = 0; return n }
    public func toEnd(_ s: TransportState) -> TransportState { var n = s; n.frame = last(s); return n }
    public func face(_ s: TransportState) -> TransportFace {
        TransportFace(playTitle: s.isPlaying ? "Pause" : "Play",
                      unavailableHelp: s.duration > 0 ? nil : "Nothing to play.",
                      timecode: "\(s.frame) / \(s.duration)")
    }
}

// UC14 · SJ6 · Contracts/StatusPillComposing.swift
public enum PillStyle: Hashable, Sendable { case plain, toggle(isOn: Bool), warning }

public struct StatusPill: Hashable, Sendable {
    public var text: String
    public var style: PillStyle
    public init(text: String, style: PillStyle = .plain) { self.text = text; self.style = style }
}

public protocol StatusPillComposing: Sendable {
    /// Zoom first ("200%", "–" for a zoom that isn't a number), then "1920 × 1080", then `trailing` in order.
    func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill]
}

/// Prints the raw zoom ("2.0×").
public struct FakeStatusPillComposing: StatusPillComposing {
    public init() {}
    public func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill] {
        [StatusPill(text: "\(zoom)×"), StatusPill(text: "\(Int(documentSize.width)) × \(Int(documentSize.height))")] + trailing
    }
}

// UC15 · SJ16, SJ20 · Contracts/CurvePointEditing.swift
public protocol CurvePointEditing: Sendable {
    /// Unit points (0...1 both ways), sorted by x, at least two. A click adds a point between its neighbours.
    func added(_ point: PlanePoint, to points: [PlanePoint]) -> (points: [PlanePoint], index: Int)?
    /// Moved, kept between its neighbours with a minimum gap; the ends keep their x.
    func moved(_ index: Int, to point: PlanePoint, in points: [PlanePoint]) -> [PlanePoint]
    /// Nil when the point is an end or the curve would drop under two points.
    func removed(_ index: Int, from points: [PlanePoint]) -> [PlanePoint]?
    /// Arrow nudges of 0.01, ⇧ 0.1.
    func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [PlanePoint]) -> [PlanePoint]
}

/// Appends without sorting and never refuses a removal.
public struct FakeCurvePointEditing: CurvePointEditing {
    public init() {}
    public func added(_ point: PlanePoint, to points: [PlanePoint]) -> (points: [PlanePoint], index: Int)? {
        (points + [point], points.count)
    }
    public func moved(_ index: Int, to point: PlanePoint, in points: [PlanePoint]) -> [PlanePoint] {
        guard points.indices.contains(index) else { return points }
        var p = points; p[index] = point; return p
    }
    public func removed(_ index: Int, from points: [PlanePoint]) -> [PlanePoint]? {
        guard points.indices.contains(index) else { return nil }
        var p = points; p.remove(at: index); return p
    }
    public func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [PlanePoint]) -> [PlanePoint] {
        guard points.indices.contains(index) else { return points }
        let s = coarse ? 0.1 : 0.01
        return moved(index, to: PlanePoint(x: points[index].x + Double(dx) * s, y: points[index].y + Double(dy) * s), in: points)
    }
}

// UC16 · SJ23 · Contracts/GraphGeometry.swift
public struct ArrowPath: Hashable, Sendable {
    public var start: PlanePoint
    public var end: PlanePoint
    public var controls: [PlanePoint]   // empty for a straight arrow
    public init(start: PlanePoint, end: PlanePoint, controls: [PlanePoint] = []) {
        self.start = start; self.end = end; self.controls = controls
    }
}

public protocol GraphGeometry: Sendable {
    /// From the edge of `from` to the edge of `to`, along the line between their centers.
    func arrow(from: PlaneRect, to: PlaneRect) -> ArrowPath
    /// A loop leaving and entering the top edge of `node`, drawn outside it.
    func selfLoop(around node: PlaneRect) -> ArrowPath
}

/// Center to center: arrows overlap their nodes.
public struct FakeGraphGeometry: GraphGeometry {
    public init() {}
    public func arrow(from: PlaneRect, to: PlaneRect) -> ArrowPath { ArrowPath(start: from.mid, end: to.mid) }
    public func selfLoop(around node: PlaneRect) -> ArrowPath { ArrowPath(start: node.mid, end: node.mid) }
}

// MARK: 5.3 Harness contracts

// UC17 · SP1–SP5, every QB-L row · Contracts/FrameProbeRecording.swift
public struct ProbeSample: Hashable, Sendable, Codable {
    public var series: String          // "bar-slider", "canvas-drag", ...
    public var eventTime: Double       // the input event's timestamp, seconds
    public var shownAt: Double         // the target timestamp of the first refresh that drew it
    public init(series: String, eventTime: Double, shownAt: Double) {
        self.series = series; self.eventTime = eventTime; self.shownAt = shownAt
    }
}

public struct ProbeSummary: Hashable, Sendable, Codable {
    public var count: Int
    public var p50FramesLate: Int
    public var p95FramesLate: Int
    public var valid: Bool             // at least 60 samples (section 7)
    public init(count: Int, p50FramesLate: Int, p95FramesLate: Int, valid: Bool) {
        self.count = count; self.p50FramesLate = p50FramesLate; self.p95FramesLate = p95FramesLate; self.valid = valid
    }
}

public protocol FrameProbeRecording: Sendable {
    mutating func record(_ sample: ProbeSample)
    /// An in-app moment: "preview-before-mouse-up", "progress-shown", "animation-ended" and the like.
    mutating func mark(_ name: String, at time: Double)
    /// Frames late = refreshes between the event and the refresh that showed it, at `refreshInterval` seconds.
    func summary(of series: String, refreshInterval: Double) -> ProbeSummary
    /// The `suite.perf` JSON.
    func encoded() throws -> Data
}

/// Keeps samples and marks; reports every sample as 0 frames late.
public struct FakeFrameProbe: FrameProbeRecording {
    public private(set) var samples: [ProbeSample] = []
    public private(set) var marks: [String: Double] = [:]
    public init() {}
    public mutating func record(_ sample: ProbeSample) { samples.append(sample) }
    public mutating func mark(_ name: String, at time: Double) { marks[name] = time }
    public func summary(of series: String, refreshInterval: Double) -> ProbeSummary {
        let n = samples.filter { $0.series == series }.count
        return ProbeSummary(count: n, p50FramesLate: 0, p95FramesLate: 0, valid: n >= 60)
    }
    public func encoded() throws -> Data { try JSONEncoder().encode(samples) }
}

// UC18 · SJ0, every app's every-control sweep · Contracts/ControlInventorying.swift
public struct ControlEntry: Hashable, Sendable, Codable {
    public var id: String
    public var enabled: Bool
    public var reason: String?
    public init(id: String, enabled: Bool, reason: String? = nil) { self.id = id; self.enabled = enabled; self.reason = reason }
}

public protocol ControlInventorying: Sendable {
    mutating func register(_ entry: ControlEntry)
    mutating func unregister(_ id: String)
    /// Ids that break "no dead controls": disabled with no reason, or an id registered twice.
    func violations() -> [String]
    /// The `suite.controls` JSON, sorted by id.
    func encoded() throws -> Data
}

/// Keeps the last entry per id; never reports a duplicate.
public struct FakeControlInventory: ControlInventorying {
    public private(set) var entries: [String: ControlEntry] = [:]
    public init() {}
    public mutating func register(_ entry: ControlEntry) { entries[entry.id] = entry }
    public mutating func unregister(_ id: String) { entries[id] = nil }
    public func violations() -> [String] {
        entries.values.filter { !$0.enabled && ($0.reason ?? "").isEmpty }.map(\.id).sorted()
    }
    public func encoded() throws -> Data { try JSONEncoder().encode(entries.values.sorted { $0.id < $1.id }) }
}

// UC19 · QB-V2–V5 · Contracts/GoldenComparing.swift (conformance in Tests/AppSnapshotTests/GoldenImage.swift)
public struct RGBAImage: Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var bytes: [UInt8]   // width × height × 4, row-major, 8-bit sRGB
    public init(width: Int, height: Int, bytes: [UInt8]) { self.width = width; self.height = height; self.bytes = bytes }
}

public struct GoldenTolerance: Hashable, Sendable {
    public var channel: UInt8        // largest per-channel difference that still counts as equal
    public var maxShare: Double      // largest share of differing pixels that still passes
    public init(channel: UInt8 = 2, maxShare: Double = 0.005) { self.channel = channel; self.maxShare = maxShare }
    public static let standard = GoldenTolerance()
}

public struct GoldenResult: Hashable, Sendable {
    public var passes: Bool
    public var differing: Int
    public var share: Double
    public var diff: RGBAImage?      // differing pixels in magenta over a grey copy; nil when they match exactly
    public init(passes: Bool, differing: Int, share: Double, diff: RGBAImage?) {
        self.passes = passes; self.differing = differing; self.share = share; self.diff = diff
    }
}

public protocol GoldenComparing: Sendable {
    /// Different dimensions, or a malformed buffer, always fail with share 1.
    func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult
}

/// Byte-for-byte equality, no diff image.
public struct FakeGoldenComparing: GoldenComparing {
    public init() {}
    public func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult {
        actual == baseline ? GoldenResult(passes: true, differing: 0, share: 0, diff: nil)
                           : GoldenResult(passes: false, differing: max(actual.width * actual.height, 1), share: 1, diff: nil)
    }
}
```

---

## 6. Look

### 6.1 The house reference

Flare's easing editor (`Sources/FlareApp/FlareEasingInspector.swift`) is
the look every SuiteUI component is held to: Studio caps headers
(`SuiteFont.sectionCaps`, uppercased, tracked), 28 pt filled number rows
(`StudioScrubRow`, the one bar slider), 24 pt filled preset chips in three
columns (`ChoiceChips`), the 180 pt `CurveEditor` well, values in semibold
tabular figures, color only for state (accent selected, amber keyed), and
one `onEnd` per drag, nudge or typed value. `docs/design.md` already writes
that look down (Visual language, Studio rows and chips); where its Visual
language tables and its Studio section differ (34 pt bars and 6 pt gaps
against 28 pt rows and 4 pt gaps), the Studio section wins, as it says, and
the code on dev follows it (`InspectorRows.swift`: 28 pt rows, 4 pt apart).

### 6.2 What SuiteUI adds to `docs/design.md`

These are the additions to `docs/design.md` (Component order table plus a
paragraph under Anatomy of the controls). The feature in the last column
builds to the row; until the shared doc carries it, the row here is the
rule. `docs/design.md` is one file several features would edit, so a single
feature, suite-record in wave 4 (section 8), lands every row at once, and
no other SuiteUI feature edits it. This blueprint does not edit it.

| Addition | Rule | Built by |
|---|---|---|
| Timeline slot | A 1 pt `hairline` divider with an 8 pt grab zone above the slot; the slot's own top row is the chip toolbar (`ChipRow`, 28 pt plus 4 pt above and below = the 36 pt collapsed height); minimum open height 120 pt; the canvas never drops under `SuiteSize.contentMinimum.height`; double-click the divider or press ⌥⌘T to collapse and restore; the pointer is the row-resize cursor over the grab zone | editor-chrome |
| Save status | Already in Anatomy (Top bar); add the accessibility labels "Saved", "Unsaved changes", "Not saved" | editor-chrome |
| Transport capsule | Already in Anatomy; add: disabled as a group, with one reason ("Nothing to play.") when the duration is 0; loop is a toggle button whose value is On or Off | editor-chrome |
| Tabs capsule | Already in Anatomy (Tabs and the tool rail) | editor-chrome |
| Layer list | `LayerList` rows are `SidebarRow`s in a flat panel list (no split view): eye and lock toggles in their fixed column, a dimmed row (title and symbol in `textSecondary`) for hidden or locked, rename by double-clicking the title or pressing Return on the focused row, a refused rename keeps the field open with the message under it in `stateError` with the exclamation symbol, drag to reorder with a 2 pt `accent` insertion line, context menu actions from `ToolbarAction`s | lists-and-layers |
| Selection handles | Already in Anatomy (Stage marks); add: the hit square is `selectionHandleHit` in view points at every zoom; the rotate zone is a 16 pt quarter-ring outside each corner with the rotate pointer | canvas-marks |
| Path, motion path, ghosts | Already in Anatomy (Stage marks) | canvas-marks |
| Point mark | A 12 pt ring with a 6 pt cross, 1.5 pt ink (white) over a 3 pt paper (black) halo, fixed on screen at any zoom, hidden from accessibility, never hit | canvas-marks |
| Grid mark | Hairlines in white at 50 % over a black 1 px shadow, `cells` × `cells`, clipped to its rect | canvas-marks |
| Timeline keys and playhead | Already in Anatomy (Timeline); add: the selected key moves with ← and →, ⌫ deletes it, a drag shows the key's new frame in a time pill while dragging | timeline |
| Node graph | Nodes are `card`-filled rounded rects at `SuiteRadius.control`, 120 × 56 pt, title in `inspectorTitle`, detail in `pill` type; arrows 1.5 pt `textSecondary` with a 6 pt head, condition chips (`ChipRow` look, not interactive) at the arrow's middle; the initial node has a 2 pt leading bar; the active node (preview) takes the `stateSelected` tint and outline; a warning badge is the triangle in `stateWarning` with its text as the accessibility label | node-graph |
| Gallery pages | Plain `List` index; each page a `Form`-free stack of the real components on the right background (`panel` for inspector pages, `canvasSurround` for canvas pages, the dark `EditorShell` for editor pages) and the log row at the bottom in `SuiteFont.timecode` | suite-harness |

**New tokens**, all landed once by suite-harness in `Tokens.swift` so no
later wave edits that file: `timelineSlotMinimum` 120, `timelineSlotToolbar`
36, `timelineGrab` 8, `rotateZone` 16, `pointMarkRing` 12, `pointMarkCross`
6, `pointMarkInk` 1.5, `pointMarkPaper` 3, `nodeSize` 120 × 56, `nodeGap`
32, `arrowHead` 6, `arrowStroke` 1.5, `insertionLine` 2. TokensTests'
geometry test lists each one.

### 6.3 Screens (gallery pages) and the components each uses or needs

SuiteUI's screens are its gallery pages (section 4.1). "Needs" names a
component that does not exist yet and the issue that builds it.

| Page | Shell | Uses (on dev) | Needs | Journeys |
|---|---|---|---|---|
| `index` | `SuiteWindow` content | `List`, `EmptyStateView` | `SuiteGallery` (new) | SJ0 |
| `window` | `SuiteWindow` | `SidebarSection`, `SidebarRow`, `InspectorHeader`, `InspectorSection`, `EmptyStateView` | – | SJ1 |
| `editor`, `editor-plain` | `EditorShell` | `EditorTopBar`, `EditorBarItem`, `EditorBarMenu`, `ToolbarGroup(.rail)`, `CanvasViewport`, `SegmentedTabs`, `ViewerStatusBar` | `EditorShell(timeline:)` #342, `EditorBarItem(.primary)` and save status #339, `TransportCapsule` #340, capsule tabs and rail colors #341 | SJ1–SJ6, SJ8 |
| `empty` | `SuiteWindow` content | `EmptyStateView` | its primary button style #339 | SJ7 |
| `canvas`, `canvas-pt` | `EditorShell` | `CanvasViewport`, `Ruler`, `ViewerStatusBar` | the ruler corner unit #264 | SJ9, SP2 |
| `marks` | `EditorShell` | `CanvasViewport`, `SelectionOutline`, `CropShade` | `SelectionHandles`, `PathMarks`, `MotionPathMarks`, `GhostLayer` #273, `CanvasPointMark` #706 #737, `CanvasGrid` #530 | SJ10, SJ21, SP5 |
| `inspector` | panel (`panel` fill) | `InspectorHeader`, `InspectorSection`, `InspectorSliderRow`, `ScrubField`, `InspectorPickerRow`, `InspectorColorRow`, `InspectorAction`, `KeyframeButton`, `PresetGrid`, `ChoiceChips`, `ChipRow`, toggle rows | `onEnd` on the exact field and the color rows #718, the Reset hit area #622 #285, readable values #262 | SJ11–SJ15, SP1 |
| `curves` | panel | `CurveEditor`, `ToneCurveEditor`, `StudioScrubRow` | goldens and the probe mark #343 | SJ16, SJ20 |
| `layers`, `layers-300` | panel | `SidebarRow`, `SidebarItem`, `SidebarToggle` | `LayerList` and dimmed rows #146, keyboard rename #108, refusable rename #577, context menus #73, child toggles #589 | SJ17, SJ22, SP4 |
| `grid`, `grid-2000` | `SuiteWindow` content | `ThumbnailGrid`, `EmptyStateView` | – | SJ18, SP4 |
| `timeline`, `timeline-long` | `EditorShell` slot | `TimelineStrip`, `ChipRow`, `TransportCapsule` | the restyle #62, key selection and drag #63 | SJ19, SP3 |
| `graph`, `graph-loop` | `EditorShell` canvas | `ChipRow` look, `EmptyStateView` | `NodeGraph` #344 | SJ23 |

Every page renders in Dark (editor pages always), and the window pages also
in Light; every component additionally has goldens in all four appearances
(section 7.4).

---

## 7. Quality bar

Every row says what is measured, where, and what fails it. "CI" is the
macOS job on `dev`; "Linux" is `scripts/ci` (for SuiteUI rules only once
Q1 lands; until then the same test runs in `SuiteUITests` on macOS). New
perf rows ship report-only and get their gate after ten green runs, as
`docs/review-rubric.md` (How gates are set) says; a gate never loosens
without the captain.

### 7.1 Input-to-screen budgets, per interactive component

Measured by `FrameProbe` (UC17) in frames late: refreshes between the input
event's timestamp and the first refresh that shows its result. Each series
needs at least 60 samples or the test fails as invalid.

| id | Component and input | Device target | CI gate | Measured by |
|---|---|---|---|---|
| QB-S1 | Bar slider and exact field: drag (= QB-L2) | p95 ≤ 2 frames late | report-only, then set from CI (placeholder 3) | SP1 |
| QB-S2 | Bar slider: arrow key to the new value drawn | p95 ≤ 1 frame late | report-only (placeholder 2) | SJ11's key presses with `-SuitePerfProbe`, series `slider-key` |
| QB-S3 | Canvas drag and Space-pan (= QB-L1) | p95 ≤ 2 | placeholder 3 | SP2 |
| QB-S4 | Selection handle drag (= QB-L1) | p95 ≤ 2 | placeholder 3 | SP5 |
| QB-S5 | Timeline ruler scrub and key drag (= QB-L3) | p95 ≤ 2 | placeholder 3 | SP3 (scrub); SJ19's key drag, series `key-drag` |
| QB-S6 | Curve handle and tone point drag (= QB-L2) | p95 ≤ 2 | placeholder 3 | SJ16 and SJ20 with the probe, series `curve-drag` |
| QB-S7 | Layer list (300 rows) and thumbnail grid (2,000 items) scroll (= QB-L10) | frame interval p95 ≤ 1.5 refreshes | set from CI | SP4 |
| QB-S8 | Chip, preset, tab, tool and transport press: press to the selected state drawn | p95 ≤ 1 frame late | placeholder 2 | SJ4, SJ5, SJ8, SJ15 with the probe, series `press` |
| QB-S9 | State fades (hover, on, disabled) | 0.14 s ± 1 refresh; 0 under Reduce Motion | exact | the probe's animation mark in SJ15 with and without the Reduce Motion switch (QB-F5) |
| QB-S10 | Timeline slot divider drag | p95 ≤ 2 | placeholder 3 | SJ2 with the probe, series `slot-drag` |

**Rule budgets** (wall time, median and p95 of 100 runs, `Tests/SuiteUITests/SuiteBudgetTests.swift`;
the debug gate is ten times the device target, as for Model budgets):

| id | Call | Target | Debug gate |
|---|---|---|---|
| QB-S11 | `TimelineMapping.rulerMarks` over a 4,096 pt stretch of a 100,000-frame timeline | ≤ 0.2 ms | ≤ 2 ms |
| QB-S12 | `GridSelecting.click` with ⇧ over 10,000 ids | ≤ 1 ms | ≤ 10 ms |
| QB-S13 | `HandleGeometryProviding.hit` | ≤ 0.02 ms | ≤ 0.2 ms |
| QB-S14 | `ListEditing.reordered` over 10,000 ids | ≤ 1 ms | ≤ 10 ms |
| QB-S15 | `GoldenComparing.compare` of two 2,880 × 1,800 images | ≤ 150 ms | ≤ 1.5 s |
| QB-S16 | `FrameProbeRecording.summary` over 10,000 samples | ≤ 2 ms | ≤ 20 ms |

### 7.2 App-audit checks that apply

All six checks of `docs/blueprints/app-audit.md` run on every gallery shot
under the `suiteui` key, baseline 0 for each:

| Check | Why it applies to SuiteUI | Where a SuiteUI fault showed before |
|---|---|---|
| `disabled-dim` | Every SuiteUI control dims at 40 % when disabled | #233 (`EditorBarLabelStyle` overrode dimming) |
| `overlap` | Section headers, Reset icons, toggles in rows | #215, #285 |
| `contrast` | Every token pair, headers, pills | #62, #146, #283, #284 |
| `identifier` | Every gallery control carries `suite.gallery.*`; shells carry `suite.*` | #262 |
| `offscreen` | Shells at the window minimum | #215, #263 |
| `unnamed` | Icon-only buttons (undo, transport, toggles, Reset) | #63 |

And because SuiteUI draws every app's chrome, every SuiteUI feature's last
round reads the five apps' audit counts on the CI run that contains it: a
count that rises in any app is that feature's finding, not the app's.

### 7.3 Layout spec

| id | Check | Widths | Measured by |
|---|---|---|---|
| QB-S17 | Shell regions inside the window, no overlap over 1 pt, content ≥ `contentMinimum.width`, the right panel exactly `editorPanelWidth` | 880, 1024, 1280, 1440 pt | SJ1 (frames from the accessibility tree) |
| QB-S18 | `ShellLayingOut.columns`: leading + content + trailing = the window width, content never under its minimum, `fits` false only under the minimum | every 40 pt from 600 to 2,560 | `ShellLayoutTests` (rule test) |
| QB-S19 | Inspector rows align: every row's leading and trailing edges equal (±0.5 pt), every value's trailing edge equal, every label inside its row, no text clipped (its frame inside the row) | inspector widths 200, 240, 280, 360 (`inspectorWidth` min, ideal, the editor panel, max) | SJ24 `testInspectorRowsAlignAtEveryWidth` (`+Inspector`): the `inspector` page with `-SuiteGalleryWidth <w>` |
| QB-S20 | Hit sizes: every control in `suite.controls` is at least 20 × 20 pt (WCAG 2.5.8), and the ones the token table lists at their hit size (28 for chips, keyframe button, preset hit; 12 for handles at any zoom) | every page | SJ25 `testEveryControlMeetsHitSize` (`SuiteJourneyTests.swift`) |
| QB-S21 | Timeline labels end inside the strip and never overlap | lane widths 320, 640, 1,280 pt and 48 to 100,000 frames | `FrameMapping` label tests (exist) plus SJ19's long page shot |
| QB-S22 | Corners nest: an inner shape's radius is one step under its container's | every component | `TokensTests.geometry` plus goldens |
| QB-S23 | Fits the window minimum: rail + content minimum + panel ≤ `windowMinimum.width` | – | `TokensTests` (exists) |

### 7.4 Fidelity: output equals a reference

| id | Check | Reference | Measured by |
|---|---|---|---|
| QB-S24 | Every component state has a golden (QB-V5): rest, hover, focus, pressed or dragging, editing, disabled, and every state color it can show, in Light, Dark and both with Increase Contrast; one contact sheet per component family per appearance | committed PNGs in `Tests/AppSnapshotTests/Golden/` | `GoldenComparing` through `SnapshotHost` at scale 2: channel tolerance 2/255, at most 0.5 % differing pixels |
| QB-S25 | Hairlines: a 1 pt divider, ruler edge, selection outline and timeline slot divider is exactly 2 device pixels at 2× (QB-V3) | the golden's pixel column | `SnapshotHostTests` hairline test |
| QB-S26 | Curves stay curves: `CurveEditor.curvePath` and `ToneCurveEditor`'s path hold cubic elements, never a polyline of over 8 segments; arrows in `NodeGraph` are one cubic for a loop | element kinds | `CurveEditorTests`, `NodeGraphTests` |
| QB-S27 | Number rules equal a reference table: 60 rows of (start, points, modifiers, step, range) → value and (value, key, modifiers) → value | a table in `Tests/SuiteUITests/ScrubReferenceTests.swift` written from `docs/design.md`'s rules, not from the code | the live `ValueScrubbing` |
| QB-S28 | Selection rules equal a reference: 40 click and arrow sequences → selection and anchor | a table in `GridSelectionReferenceTests` | the live `GridSelecting` |
| QB-S29 | Frame mapping equals a reference: frame ↔ x round trips for 0...duration at 5 frame widths; ruler marks for 6 fixed stretches | a table | the live `TimelineMapping` |
| QB-S30 | Probe math equals a reference: 100 synthetic samples at 60 Hz and 120 Hz → known p50, p95 and dropped count | a table | `FrameProbeTests` |
| QB-S31 | Golden compare equals a reference: identical images pass with share 0; one pixel off by 3 in a 10 × 10 image fails at share 0.01; a size mismatch fails with share 1 | three fixed images built in code | `GoldenImageTests` |
| QB-S32 | Contrast (QB-V6) for every new token pair: the slot divider, node text on `card`, the point mark's ink on paper, the error message under a refused rename | `docs/design.md` ratio rules | `TokensTests.contrast` |
| QB-S33 | Arrow ends lie on node edges (±0.5 pt) for 8 fixed node pairs and a self-loop stays outside its node | a table | `NodeGraphTests` against the live `GraphGeometry` |

### 7.5 Feel (QB-F rows, SuiteUI's share)

| Row | SuiteUI's part | Measured by |
|---|---|---|
| QB-F1 no dead controls | `ControlInventorying.violations()` is empty on every gallery page; every app's sweep reads the same JSON | SJ0, the apps' every-control journeys |
| QB-F3 one gesture, one undo step | every component ends each gesture with exactly one `onEnd` (`EditRun`) | SJ11–SJ17, SJ19, SJ20 assert the log's `ends`; `EditRunTests` |
| QB-F4 keyboard parity | every value the pointer changes changes from the keyboard too | SJ11, SJ12, SJ14–SJ17, SJ19 each do it once |
| QB-F5 Reduce Motion, Increase Contrast | fades instant, the preview dot stops; outlines appear | QB-S9, goldens in the IC appearances |
| QB-F6 geometry holds | sizes and radii match the tokens | `TokensTests.geometry`, goldens |

---

## 8. Coverage and waves

### 8.1 Coverage matrix: every open `line:suiteui` issue

41 open issues on 2026-10-14. "Feature" is the packet that closes it (8.3);
"not v1" says why.

| Issue | Tier | What | Feature | Note |
|---|---|---|---|---|
| #331 | p1 | Golden compare | suite-harness | root of the golden chain |
| #332 | p1 | Snapshot host, scale 2, four appearances | suite-harness | after #331 in the same feature |
| #333 | p1 | Journey files and helpers | suite-harness | its smoke file becomes `UITests/SuiteJourneyTests+Smoke.swift`, not a Flare file, so the SuiteUI line stays in its own files (the packet restates the acceptance) |
| #330 | p3 | `FrameProbe` | suite-harness | p3 by its own tier, but every budget in section 7 needs it |
| #283 | p2 | Secondary text on light cards | suite-harness | a `Tokens.swift` change; that file is harness-owned |
| #339 | p2 | Outlined bar items, `.primary`, save status, empty-state primary | editor-chrome | p1 by dependency for Flare F1a/F1b |
| #340 | p1 | `TransportCapsule` (pills already merged in #522) | editor-chrome | |
| #341 | p3 | Capsule tabs, rail colors | editor-chrome | |
| #342 | p1 | `EditorShell(timeline:)` | editor-chrome | |
| #718 | – | Public `onEnd` on `ScrubField`, the color rows | inspector-controls | the fuller of the two |
| #745 | – | Same ask as #718 | inspector-controls | duplicate: closed by the #718 PR (`Closes #718, closes #745`) |
| #591 | – | Track-owned discrete step | inspector-controls | Photo's Gamma |
| #88 | p3 | Log slider mapping | inspector-controls | largely met by `ScrubTrack` (#505); closes with #591's PR after its test shows the field reads the value |
| #622 | – | Reset hit area ≥ 20 pt | inspector-controls | same header as #285; one PR |
| #285 | p2 | Header button under Reset | inspector-controls | |
| #262 | p3 | Empty accessibility values | inspector-controls | |
| #343 | p1 | `CurveEditor` goldens and probe mark | inspector-controls | the editor exists (#257); this is its proof |
| #146 | p1 | `LayerList`, dimmed rows | lists-and-layers | |
| #108 | p2 | Keyboard rename | lists-and-layers | the double-click half was fixed by #167; the packet keeps only the keyboard and accessibility routes |
| #73 | p2 | Row context menus | lists-and-layers | |
| #577 | p3 | Refusable rename keeps the draft | lists-and-layers | |
| #589 | – | Child row's toggles reachable | lists-and-layers | |
| #111 | p3 | App-owned expansion | lists-and-layers | |
| #284 | p2 | Sidebar header contrast | lists-and-layers | title fixed by #599; the packet adds the audit proof and closes it; Design's own `Section("Pages")` goes to `line:design` |
| #249 | p3 | Nesting snapshot draws real rows | lists-and-layers | |
| #308 | p3 | Rename guard: behavioural journey | lists-and-layers | one SJ17 step covers #308, #311, #312 |
| #311 | p3 | Rename guard: optional-chained helper | lists-and-layers | closed by #308's journey |
| #312 | p3 | Rename guard: outside label style | lists-and-layers | closed by #308's journey |
| #273 | p1 | Selection handles and the vector marks | canvas-marks | adds `PathMarks`, `MotionPathMarks`, `GhostLayer` (0.4) |
| #706 | – | Point mark | canvas-marks | one mark for both |
| #737 | – | Source crosshair | canvas-marks | duplicate of #706's mark: closed by the same PR |
| #530 | – | Grid mark | canvas-marks | |
| #264 | p3 | Ruler corner unit | canvas-marks | |
| #62 | p1 | Timeline restyle | timeline | absorbs #61 (closed) and #219 |
| #63 | p1 | Key drag, keyboard keys (`needs-human`) | timeline | `needs-human` came from a run blocked on #62; the packet asks the captain to lift it |
| #219 | p3 | Blank long timelines | timeline | closed by #62's PR |
| #344 | p3 | `NodeGraph` | node-graph | Flare's Interactions editor, last in Flare's order |
| #345 | p3 | C4 description names the new components | suite-record | the one SuiteUI edit of `docs/c4/model.json` |
| #7 | p3 | Command palette | not v1 | no tier-1 or tier-2 step shows it (section 3.3) |
| #274 | p3 | Shared open and save panel plumbing | not v1 | each app keeps its own until a second app needs the same shape; refactor issues are p3 |
| #272 | p3 | Design lint misses computed font sizes | not v1 for SuiteUI | the lint lives in `scripts/` (protected); it is the captain's or a scripts issue's, not this line's |

Every row of 0.4 (no issue yet) lands with the feature named there.

### 8.2 Waves

A wave starts when everything it waits on has merged. No two features in a
wave own the same file (8.3 lists them; a file may pass from one feature to
another between waves). SuiteUI knows no engine, so **no SuiteUI feature
waits on creative-core**: every "core" cell is "none".

| Wave | Feature | Covers | Waits on | creative-core | App features it unblocks |
|---|---|---|---|---|---|
| 1 | suite-harness | #331, #332, #333, #330, #283; gallery, control inventory, contracts, token sheet, `Journey(name:)`, the `suiteui` audit key | nothing | none | every app's goldens; every app's second journey file (Flare's `FlareJourneyTests+<Area>.swift` plan needs #333); Flare's perf journeys (QH-5, QH-6) |
| 2 | editor-chrome | #339, #340, #341, #342 | wave 1 (#332 for goldens; the gallery) | none | Flare F1a #346 and F1b #347 (the window on `EditorShell`), Flare's transport and playback UI; Design and Photo's primary Export and save status |
| 2 | inspector-controls | #718, #745, #591, #88, #622, #285, #262, #343 | wave 1 | none | Design's undo runs (#536), Photo's Gamma (#584), Flare's inspector (F6a #348 and after), Flare and Halo easing |
| 2 | lists-and-layers | #146, #108, #73, #577, #589, #111, #284, #249, #308, #311, #312 | wave 1 | none | Flare's layers and scenes panel (F11a), Halo's rename refusal (#139) and composition menu (#35), Design's Layers (#50, #549) |
| 2 | canvas-marks | #273, #706, #737, #530, #264 | wave 1 | none | Flare's stage (F3a #12 and its select and direct-select tasks), Design's handles, Photo's Clone and Heal (#647, #422) and Straighten (#419) |
| 3 | timeline | #62, #219, #63 | wave 2's editor-chrome (#62 depends on #342) | none | Flare's timeline (F7a, F8 #377), Halo's timeline (#36) |
| 3 | node-graph | #344 | wave 1 | none | Flare's Interactions editor (F13a and after) |
| 4 | suite-record | #345; section 6.2's rows into `docs/design.md` | waves 1–3 | none | nothing waits on it; it brings the shared docs up to date |

Why this order:

- **The harness goes alone, first.** Every later feature proves its work
  with goldens (#331, #332), runs journeys from its own file (#333), shows
  its components on a gallery page and registers its controls. The gallery's
  pages are created as empty stubs here (one file per later feature, like
  Flare's F1 area stubs), and every token the later waves need is added here,
  so no later feature edits `Tokens.swift`, `SuiteGallery.swift` or
  `project.yml`.
- **Wave 2 is wide.** Four features with disjoint files run side by side;
  each is the SuiteUI half of a p1 app feature that is otherwise ready.
  Editor chrome is first among equals: Flare's whole UI track starts with
  F1a and F1b on `EditorShell`.
- **Timeline waits on the slot.** #62's own `Depends on:` line names #342.
  If the captain drops that line (Q4: the strip's restyle doesn't need the
  slot, only its gallery page does), timeline moves to wave 2 with no file
  conflict.
- **Node graph waits only on the harness** but is tier 3 and last in
  Flare's order, so it shares wave 3 rather than crowding wave 2.
- **suite-record is last** because it describes what the others built.

### 8.3 Owned files per feature

Test files are listed by name; `Golden/<area>/` is each feature's own
baseline folder. A file under "harness, then" passes to the named feature
at the next wave.

**suite-harness (wave 1)**
- `Sources/SuiteUI/Contracts/` (every file of section 5), `Sources/SuiteUI/SuiteGallery.swift`, `Sources/SuiteUI/Gallery/GalleryIndex.swift`, and the stubs `Gallery/GalleryChrome.swift`, `GalleryInspector.swift`, `GalleryLists.swift`, `GalleryCanvas.swift`, `GalleryTimeline.swift`, `GalleryGraph.swift` (harness, then their features)
- `Sources/SuiteUI/FrameProbe.swift`, `Sources/SuiteUI/ControlInventory.swift`, `Sources/SuiteUI/Tokens.swift`
- `Sources/SuiteUI/SuiteWindow.swift` (the `-SuiteGallery` hook; harness, then lists-and-layers)
- `Sources/SuiteUI/ToolbarGroup.swift`, `EditorTopBar.swift`, `InspectorAction.swift`, `EmptyStateView.swift` (only to register `ToolbarAction`-built controls with the inventory; harness, then editor-chrome or inspector-controls)
- `project.yml`, `UITests/Journey.swift`, `UITests/Journey+Input.swift`, `UITests/SuiteJourneyTests.swift`, `UITests/SuiteJourneyTests+Smoke.swift`, `UITests/audit-baseline.json` (the `suiteui` key at 0 only)
- `Tests/AppSnapshotTests/GoldenImage.swift`, `GoldenImageTests.swift`, `SnapshotHost.swift`, `SnapshotHostTests.swift`, `Golden/README.md`
- `Tests/SuiteUITests/TokensTests.swift`, `FrameProbeTests.swift`, `ControlInventoryTests.swift`, `EditRunTests.swift`, `ContractFakesTests.swift`

**editor-chrome (wave 2)**
- `Sources/SuiteUI/EditorShell.swift`, `EditorTopBar.swift`, `SegmentedTabs.swift`, `ToolbarGroup.swift`, `ShellLayout.swift`, `TransportCapsule.swift`, `ViewerStatusBar.swift`, `EmptyStateView.swift`, `SurfaceCard.swift`, `GlassPanel.swift`, `Gallery/GalleryChrome.swift`
- `UITests/SuiteJourneyTests+Chrome.swift`
- `Tests/SuiteUITests/EditorShellTests.swift`, `ShellLayoutTests.swift`, `TransportTests.swift`, `ToolPickingTests.swift`, `StatusPillTests.swift`
- `Tests/AppSnapshotTests/SuiteEditorShellSnapshots.swift`, `SuiteEditorBarDimmingTests.swift`, `SuiteStatusSnapshots.swift`, `SuiteWindowLaunchSnapshots.swift`, `SuiteWindowMinimumSnapshots.swift`, `SuiteTopBarSnapshots.swift`, `SuiteTabsSnapshots.swift`, `SuiteTransportSnapshots.swift`, `Golden/chrome/`

**inspector-controls (wave 2)**
- `Sources/SuiteUI/InspectorRows.swift`, `InspectorHeader.swift`, `InspectorAction.swift`, `ColorWell.swift`, `KeyframeButton.swift`, `ScrubField.swift`, `ScrubValue.swift`, `NumericInput.swift`, `StudioScrubRow.swift`, `PresetGrid.swift`, `ChipRow.swift`, `ChoiceChips.swift`, `CurveEditor.swift`, `ToneCurveEditor.swift`, `Gallery/GalleryInspector.swift`
- `UITests/SuiteJourneyTests+Inspector.swift`
- `Tests/SuiteUITests/ScrubValueTests.swift`, `ScrubReferenceTests.swift`, `NumericInputTests.swift`, `SliderBarTests.swift`, `KeyframeButtonTests.swift`, `PresetGridTests.swift`, `CurveEditorTests.swift`, `ToneCurveEditorTests.swift`, `HexColorTests.swift`
- `Tests/AppSnapshotTests/SuiteInspectorSnapshots.swift`, `SuiteProInspectorSnapshots.swift`, `SuiteSliderSnapshots.swift`, `SuiteHeaderSnapshots.swift`, `SuiteKeyframeSnapshots.swift`, `SuitePresetsSnapshots.swift`, `SuiteCurveEditorSnapshots.swift`, `SuiteToneCurveSnapshots.swift`, `Golden/inspector/`

**lists-and-layers (wave 2)**
- `Sources/SuiteUI/SidebarRow.swift`, `SidebarSection.swift`, `SuiteWindow.swift`, `LayerList.swift`, `ListEditing.swift`, `ThumbnailGrid.swift`, `GridSelection.swift`, `Gallery/GalleryLists.swift`
- `UITests/SuiteJourneyTests+Lists.swift`
- `Tests/SuiteUITests/SidebarTests.swift`, `SidebarEdgeTests.swift`, `SidebarNestingTests.swift`, `SidebarRenameGestureTests.swift`, `LayerListTests.swift`, `ListEditingTests.swift`, `GridSelectionTests.swift`, `GridSelectionEdgeTests.swift`, `GridSelectionExtendTests.swift`, `GridSelectionOverflowTests.swift`, `GridSelectionToggleTests.swift`, `GridSelectionToggleFuzzTests.swift`, `GridSelectionReferenceTests.swift`
- `Tests/AppSnapshotTests/SuiteSidebarSnapshots.swift`, `SuiteSidebarNestingSnapshots.swift`, `SuiteSidebarToggleColumnSnapshots.swift`, `SuiteGridSnapshots.swift`, `SuiteGridSmallSnapshots.swift`, `SuiteLayerListSnapshots.swift`, `Golden/lists/`

**canvas-marks (wave 2)**
- `Sources/SuiteUI/CanvasMarks.swift`, `CanvasMarks+Vector.swift`, `CanvasMarks+Points.swift`, `HandleGeometry.swift`, `CanvasViewport.swift`, `CanvasSurface.swift`, `Ruler.swift`, `ZoomMath.swift`, `Gallery/GalleryCanvas.swift`
- `UITests/SuiteJourneyTests+Canvas.swift`
- `Tests/SuiteUITests/CanvasPanTests.swift`, `ZoomMathTests.swift`, `RulerMarksTests.swift`, `RulerLabelPlacementTests.swift`, `RulerLabelSweepTests.swift`, `RulerLabelWidthTests.swift`, `CanvasMarksTests.swift`, `HandleGeometryTests.swift`
- `Tests/AppSnapshotTests/SuiteMarksSnapshots.swift`, `Golden/canvas/`

**timeline (wave 3)**
- `Sources/SuiteUI/TimelineStrip.swift`, `FrameMapping.swift`, `TimelineKeys.swift`, `Gallery/GalleryTimeline.swift`
- `UITests/SuiteJourneyTests+Timeline.swift`
- `Tests/SuiteUITests/FrameMappingTests.swift`, `FrameMappingEdgeTests.swift`, `FrameMappingOverflowTests.swift`, `FrameMappingSweepTests.swift`, `TimelineKeysTests.swift`, `TimelineKeyDragTests.swift`
- `Tests/AppSnapshotTests/SuiteTimelineSnapshots.swift`, `Golden/timeline/`

**node-graph (wave 3)**
- `Sources/SuiteUI/NodeGraph.swift`, `NodeGraphGeometry.swift`, `Gallery/GalleryGraph.swift`
- `UITests/SuiteJourneyTests+Graph.swift`
- `Tests/SuiteUITests/NodeGraphTests.swift`, `Tests/AppSnapshotTests/SuiteGraphSnapshots.swift`, `Golden/graph/`

**suite-record (wave 4)**
- `docs/c4/model.json` (the `suiteui` container and `suiteui-sources` descriptions only), `docs/design.md` (section 6.2's rows only)

Checks on this list: within wave 2 the four features' lists share no path
(`ToolbarGroup.swift`, `EditorTopBar.swift`, `InspectorAction.swift`,
`EmptyStateView.swift` and `SuiteWindow.swift` were the harness's in wave
1 and belong to exactly one wave-2 feature each); within wave 3 timeline
and node-graph share none. `Sources/SuiteUI/SnapshotRendering`-style shared
test helpers do not exist today; a feature that needs a shared test helper
adds it in its own file, never in another feature's.

### 8.4 What every packet will carry

Per `docs/factory/lead.md`: the feature issue (`feature-lead`,
`line:suiteui`, one `Depends on:` line), its tasks with ids, one behaviour
each, files, the test, the gallery page and journey step it adds, the
goldens it adds, and a size under 400 lines and 15 files. Packets are
written after the captain approves this blueprint, not before.

---

## 9. Open questions for the captain

| # | Question | Recommendation | What changes if not |
|---|---|---|---|
| Q1 | Add a Linux target for SuiteUI's pure rules and contracts (a `Package.swift` change, protected)? | Yes: a `SuiteUILogic` target with `Contracts/` and the rule files (`ScrubValue`, `NumericInput`, `FrameMapping`, `GridSelection`, `ZoomMath`, `RulerTicks`, and the planned `ShellLayout`, `HandleGeometry`, `ListEditing`, `TimelineKeys`, `NodeGraphGeometry`, `FrameProbe` math), which SuiteUI re-exports. Then `scripts/ci` tests them on every PR, and app Models may reuse them | Contracts stay in `Sources/SuiteUI/Contracts/`, compiled only by the macOS job; this blueprint's Linux run in `docs/blueprints/suiteui/contracts/` is the only Linux proof, rerun by hand |
| Q2 | Gallery behind `-SuiteGallery` in `SuiteWindow`, or a separate gallery app target? | The flag: no protected file changes, and it runs inside a real app bundle | A `SuiteGalleryApp` target needs `Package.swift` and `scripts/bundle-apps` (both protected) |
| Q3 | A `suiteui` key in `UITests/audit-baseline.json`, every check at 0? | Yes | Gallery shots would count under `library` and raise its baseline |
| Q4 | Drop #342 from #62's `Depends on:` line so the timeline restyle runs in wave 2? | Yes, if Flare's timeline UI is wanted sooner; the gallery page can host the strip in a panel until the slot lands | Timeline stays in wave 3 as planned |
| Q5 | Lift `needs-human` on #63? | Yes: the label came from a run blocked on #62, not from a design question | #63 stays out of the timeline packet |
| Q6 | Close #745 as a duplicate of #718 and #737 of #706 now? | Yes | The packets close them with the same PRs anyway |
| Q7 | Who owns `docs/design.md` edits for SuiteUI: one wave-4 feature (this plan) or each feature as it lands? | One feature: four wave-2 features would otherwise edit one file | Waves 2 and 3 serialize on `docs/design.md` |
| Q8 | `design.md`'s Visual language tables (34 pt bars, 6 pt gaps, 16/8 section spacing) disagree with its Studio rows section and the code (28, 4, 12/4). Should suite-record rewrite the tables to the Studio values? | Yes, so the doc has one number per thing | Readers keep needing the "this section wins" sentence |
