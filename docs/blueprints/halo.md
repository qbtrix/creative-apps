# Halo blueprint

Halo is the suite's motion graphics and compositing app. You make a
composition (a sized, timed canvas), stack layers in it (solids, shapes, text,
nulls), place each layer's span on a timeline, key its position, scale,
rotation and opacity, ease the keys, play it back, undo any step, save the
project, and render it to a movie or a PNG sequence. This blueprint is the
gate before feature code: it fixes the scope, the components, every tier-1
journey, the use-case contracts, the look, the quality bar and the build
order. Feature packets (`docs/blueprints/halo/features/`) come after the
captain approves it.

Sources read on 2026-10-14: creative-apps `origin/dev` 956d946 (HaloModel,
HaloApp, Halo tests and journeys, SuiteUI, docs), creative-core `main` 4cac701
(FlareCore, CoreRaster, `docs/design/suite.md` Halo section H1 to H10), and
the open and closed `line:halo` issues. The worked example for shape and
depth is `docs/blueprints/flare.md`. The look is `docs/design.md`; the
quality ids (`QB-…`) are `docs/review-rubric.md` section 6.

Contents: 0 Status on dev · 1 Brief · 2 Pseudo-C4 · 3 Usage map · 4 Journeys ·
5 Contracts · 6 Look · 7 Quality bar · 8 Coverage and waves · 9 Decisions
for the captain · 10 Critic rounds

Ids used below: **H-J<n>** is a journey (section 4), **HB-<n>** a Halo
budget (section 7), **HF-<n>** a fidelity test (section 7), **W<n>** a wave
(section 8).

---

## 0. Status on dev

Read on `origin/dev` 956d946 (2026-10-14).

### What exists

**HaloModel** (`Sources/HaloModel/`, 9 files, Linux-safe, depends on
FlareCore and CoreRaster in `Package.swift` but imports only CoreRaster):

| File | What it does today | Tests |
|---|---|---|
| `HaloProject.swift` | The window's state: `compositions`, `selectedCompositionID`, `selectedLayerID`, `refusedRename`. New, duplicate, rename (refused for empty, taken or look-alike names), delete (never the last), select; Layer > New (Solid, Shape, Text, Null) on top, spanning the composition; opacity and blend mode of the selected layer. Stored state is `public private(set)`; no undo | `HaloProjectTests`, `HaloCompositionTests`, `HaloCompositionEdgeTests`, `HaloLayersTests`, `HaloUniqueName*`, `HaloRename*` |
| `HaloLayer.swift` | `HaloLayer` (id, name, kind, in and out frame, sRGB color, clamped opacity, CoreRaster `BlendMode`, optional solid rectangle), `HaloLayerKind`, `HaloLayerColor`, `HaloLayerRect`. No keys, no transform, no parent, not `Codable` | `HaloLayerOpacityClampTests` |
| `HaloTimeline.swift` | Each composition's playhead (`scrub(to:)`, clamped), SMPTE-style timecode, the strip's rows, I and O set in and out points at the playhead (refused across the other point) | `HaloTimelineTests`, `HaloTimelineCostTests` |
| `FrameRenderer.swift` | `renderFrame(at:scale:)`: composites visible solids, axis-aligned, with blend mode and opacity, through CoreRaster at quarter size; counts other kinds as skipped (nulls too: bug #457). Not shown anywhere yet (#451) | `HaloRenderTests`, `HaloRenderEdgeTests` |
| `CompositionSettings.swift`, `CompositionDraft.swift` | New Composition sheet: name, size 1–8192, 24/25/30/60 fps, duration up to 24 h, validated from the typed text | `HaloCompositionDraft*` |
| `HaloStatusText.swift` | Size, rate, duration and status-bar timecode text | `HaloStatusTextTests` |
| `NameKey.swift`, `RefusedRename.swift`, `CompositionDeleteCommand.swift` | Name comparison by case folding; the refused rename kept for the alert; Command-Delete inside the rename field edits text | `HaloNameCaseFoldingTests`, `HaloRenameRefusal*`, `HaloCompositionDeleteCommandTests` |

131 `@Test`s in `Tests/HaloModelTests/` (20 files).

**HaloApp** (`Sources/HaloApp/`, 8 files, macOS): `SuiteWindow` with a
Compositions sidebar (add, select, double-click rename), `HaloViewer` (an
empty `CanvasSurface` artboard, `ViewerStatusBar` with zoom, size, timecode
and layer count, then `HaloTimelineView`), `HaloCompositionInspector`
(`InspectorHeader`, read-only Composition rows, `HaloLayerList`), the New
Composition sheet, the rename refusal alert, the Composition menu (New ⌥⌘N,
Duplicate ⌘D, Delete ⌘⌫) and Layer > New. No viewer drawing, no playback, no
transform inspector, no Edit or File items of its own, no launch arguments.

**Snapshots** (`Tests/AppSnapshotTests/`): `HaloCompositionSnapshots`,
`HaloCompositionInspectorSnapshots`, `HaloLayersSnapshots`,
`HaloTimelineSnapshots`.

**Journeys** (`UITests/HaloJourneyTests.swift`): `testLaunchShowsWindowShell`,
`testNewComposition`, `testScrubTheTimeline`, `testEveryMenuOpens`, and
`testKeyLayerAndSave` as an `XCTSkip` placeholder ("arrives with #207, #208
and #209").

**App audit** (`UITests/audit-baseline.json`): `halo` contrast 2,
identifier 10, offscreen 8, unnamed 5.

**Shipped issues:** #34 layers, #35 composition settings, duplicate, rename
and delete, #36 timeline (in #727), #40 composite solids (in #452), #184 pro
density inspector (in #746), and the bug fixes #126, #127 (folded into #208),
#128, #129, #138, #144, #150, #151, #152, #456.

### What the open `line:halo` issues cover

| # | Title | Labels | Depends on (as written) |
|---|---|---|---|
| #37 | Preview and playback | p1 | #36 (closed), #6 (closed) |
| #38 | Layer inspector with keys, parent and blend mode | p1 | #37, #5 (closed) |
| #207 | Drag a layer in the viewer to key its position | p1, needs-human | #37 |
| #208 | Undo and Redo for project edits | p1 | #207 |
| #209 | Save and open a project file | p1 | #208 |
| #428 | Ease keys in and out | p1 | #38, #208 |
| #429 | Render to a movie or PNG sequence | p2 | #40 (closed) |
| #430 | Text layers with editable text, size and color | p2 | #38, #40, #209 |
| #451 | Render Frame (⌘R) shows the rendered solids | p2 | #37 |
| #39 | Effects stack panel | p2 | #38, #5 |
| #457 | Render note counts null layers as skipped | bug | – |
| #286 | New Composition fields have no accessibility label | p2, needs-ui | – |
| #290 | 10 controls have no accessibility identifier | p2, needs-ui | – |
| #149 | Inner no-break, thin or zero-width spaces bypass the taken-name check | p3, bug | – |
| #139 | A refused rename opens a modal alert, not an inline message | p3, bug, needs-human | SuiteUI #577 |

The p1 chain as filed is strictly serial (#37 → #207 → #208 → #209, and #38
→ #428). #207's last comment records why nothing started: no playhead and
no drawing on dev at the time. The playhead has since shipped (#36), so #37
is the head of the chain and nothing else on the line can start until it
merges. Section 5's contracts break that chain: with fakes, the inspector,
the drag, undo and files can be built beside the viewer (section 8).

### What is missing

- **The core loop after "create".** Nothing draws in the viewer, nothing
  plays, nothing is keyed, nothing undoes, nothing saves (#37, #38, #207,
  #208, #209, #428).
- **Layer housekeeping.** No delete, rename, reorder or duplicate for a
  layer (no issue filed).
- **The seams for parallel work.** No contracts or fakes, no fixtures, no
  launch arguments for journeys, and `HaloApp.swift` and
  `HaloProject.swift` are the only places a feature can wire into, so every
  feature would edit them.
- **Harness.** One journey file for the whole app (SuiteUI QH-4, #333, open)
  and no frame probe (QH-1, #330, open), so UI latency can't be measured yet.
- **Engine.** No Halo engine in creative-core. FlareCore already has what
  Halo's keys need (`Keyframe`, `Easing`, `Timeline.value(of:at:)`,
  `Timeline.playbackFrame`, `Matrix`, `Path.flattened`), and CoreRaster has
  composite at an offset, the W3C blend modes, polygon, ellipse and
  rectangle masks, rotate, resize, blur and levels. Missing for v1: drawing a
  pixel buffer through an affine matrix (needed for rotated or scaled text),
  and an ellipse path builder for rotated shape layers (section 8).

---

## 1. Brief

### The problem

Short animated graphics (titles, lower thirds, logo stings, animated
social posts, explainer shots) are made by layering simple elements on a
timed canvas and moving them over time. People who make them today need a
Mac tool that opens fast, keys a move in a few gestures, plays back at the
frame rate without stutter, and renders exactly what they saw. Halo is that
tool, free and open, sharing its timeline, keys and easing with Flare and
its pixel engine with Photo.

### Who uses it

1. **The everyday motion designer** (the 2019 motion design survey's
   majority: freelancers and in-house designers making short social and
   brand pieces). Every session: create or open a composition, add layers,
   key transforms, ease, preview, save. Weekly: render to a file, titles.
2. **The designer who animates now and then** (from Design or Photo).
   Needs the loop to be discoverable without training: obvious keying, a
   visible playhead, named undo.
3. **The Flare animator** who wants to composite a Flare scene with titles
   and solids (later: Flare scenes as layers, suite plan H10).

### Non-goals

Video editing (cutting clips on a multi-track sequence), audio editing,
node-based compositing, 3D scenes and cameras, particle systems,
expressions or any scripting language, plugins, collaboration or cloud
sync, an iPad build, and reading or writing any closed project format.
Vector drawing beyond simple shape layers belongs to Flare and Design;
pixel painting to Photo.

### The v1 line

| Area | In v1 | Out of v1 (later, in order) |
|---|---|---|
| Project | Compositions: new (with validation), duplicate, rename, delete, select (shipped). One project per window | Several projects in tabs; composition folders |
| Layers | Solid, shape (ellipse), text, null. New, delete, rename, reorder, duplicate; in and out points; select in the list, timeline or viewer | Image and footage layers (needs creative-core affine sampling); precomps (H4); Flare scenes as layers (H10); hide, lock and solo |
| Transform | Position, scale, rotation, opacity, anchor point; parenting to another layer (keeps its place on screen) | Skew; 3D |
| Keys | Stopwatch and key-here diamond per property; drag in the viewer keys position at the playhead; keys as diamonds on the layer's lane | Retiming keys by drag on the timeline; per-property sub-lanes; a value graph editor |
| Easing | Linear, Ease In, Ease Out, Ease In and Out, Hold, from the Animation menu, a key's context menu and the inspector's chips; the custom curve editor (SuiteUI `CurveEditor`, as Flare) | Speed graph; roving keys |
| Viewer | Draws the composition at the playhead, fitted, with the layer under the pointer selectable and draggable; selection box | Zoom and pan beyond fit; guides; safe-area overlays |
| Playback | Play and pause (Space), loop, step a frame, go to start and end; holds the composition rate | Cached full-resolution preview; audio |
| Undo | Every edit one named step, 100 steps; scrubs and drags coalesce | History panel |
| Files | Save, Save As, Open, Open Recent; `.halo` JSON; damaged, newer and oversized files refused with a message | Autosave and crash recovery (first Later item); collect files |
| Blend | The 16 W3C blend modes per layer (shipped in the Model) | Track mattes (H8); masks |
| Render | Render Frame (⌘R) into the viewer; Render… to a PNG sequence or an H.264 movie, full or half size, with progress and Cancel | Other codecs; render queue; alpha movie |
| Text | One-line text layers: string, size, the layer's color | Fonts, paragraph text, per-character animation |
| Effects | – | Effects stack (#39): blur, fill, levels; motion blur (H9) |

Calls against the suite plan (`creative-core docs/design/suite.md`, Halo MVP):

| Suite MVP item | Call | Why |
|---|---|---|
| Image and precomp layers | Later | No tier-1 journey needs them, and both need engine work (affine sampling, H4 time mapping) that isn't filed |
| Keyframes with a graph editor | Presets and the curve editor in v1; the graph editor later | Priorities rank presets tier 1 and the graph tier 2; the curve editor already exists in SuiteUI |
| Masks and track mattes | Later | Tier 3 in `docs/priorities.md` |
| 3 effects (blur, fill, levels) | Later (#39 stays p2, not v1) | Tier 2; the render path must first match the viewer (HF-1) before effects change pixels |
| Motion blur | Later | Tier 3 by inference; needs H9 |
| RAM preview | v1 plays the viewer's vector drawing live; a cached pixel preview is later | The viewer draws vectors with SwiftUI at screen size, so live playback needs no cache for v1 layer kinds (HB-4) |
| Export to H.264 | v1 (#429) | Tier 2 but the only way a piece leaves the app |
| Flare scene as a layer | Later (H10) | Needs the composition renderer to sample arbitrary vector content |
| AI "animate in" presets | Later | Suite Phase 3 |

---

## 2. Pseudo-C4 (drawn before code)

Three layers, unchanged from `docs/engineering.md`. SuiteUI sits beside the
app and knows no Model. Machine-readable twin:
`docs/blueprints/halo/c4-planned.json` (same shape as `docs/c4/model.json`,
one level finer, each element with `"status"` and `"authored": true`).
`docs/c4/model.json` itself is not edited by this blueprint; W0's last task
updates the `halo-model` and `halo-app` descriptions there (section 8).

### L1 and L2: containers

```
 Motion designer
       │ makes, plays, renders compositions
       ▼
┌──────────────────── creative-apps ────────────────────┐        ┌──── creative-core ────┐
│                                                       │        │                       │
│  HaloApp (macOS) ──reads, calls──▶ HaloModel (Linux) ─┼──────▶ │ FlareCore  keys,      │
│    │  scene, window, menus,           project, keys,  │        │   easing, sampling,   │
│    │  viewer, timeline, inspector,    history, files, │        │   Matrix, Path        │
│    │  sheets, platform writers        contracts,      ├──────▶ │ CoreRaster pixels,    │
│    │                                  fakes, live     │        │   composite, masks    │
│    └──builds from──▶ SuiteUI (macOS)                  │        └───────────────────────┘
│                                                       │
│  Halo tests: HaloModelTests (Linux), Halo snapshots   │   Apple frameworks used only in
│  and goldens, Halo journeys (XCUITest)                │   HaloApp: SwiftUI, AVFoundation,
└───────────────────────────────────────────────────────┘   ImageIO, CoreText, UniformTypeIdentifiers
```

| Container | Status | Responsibility | Owned paths |
|---|---|---|---|
| HaloModel | existing | All state and logic; contracts, fakes, live conformances; Linux-tested | `Sources/HaloModel/` |
| HaloApp | existing | SwiftUI window and views, menus, macOS-only writers and rasterizer | `Sources/HaloApp/` |
| Halo tests | existing | Model tests, snapshots and goldens, journeys | `Tests/HaloModelTests/`, `Tests/AppSnapshotTests/Halo*`, `UITests/HaloJourneyTests*` |
| SuiteUI | existing (another line) | Components Halo uses; gaps go to `needs-ui` issues | `Sources/SuiteUI/` |
| FlareCore, CoreRaster | existing (creative-core) | Engines; gaps go to `needs-core` issues | – |

### L3: components

Each row is a component with the files it owns. A file belongs to exactly
one component. "existing" means at least one of its paths is on dev today;
the planned files inside it are named in section 8 with the feature that
creates them.

#### HaloModel (existing)

Linux-safe state and logic behind Halo's window: the project document, selection, playhead and playback, keys and easing, undo history, file state and render state, plus one contract per use case with its fake and live conformance. Calls FlareCore for keys, easing, sampling and matrices and CoreRaster for pixels.

| Component | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| `halo-project` Project and compositions | existing | HaloProject: the window's one value-type state. Holds the document (compositions, selection, id counter) as a HaloDocumentState, the services, and every stored property v1 needs (history, playback, viewer drag, selected keys, file, rendered frame, render job, last refusal), each written only by its own extension file. Composition new, duplicate, rename (look-alike names refused), delete, select; the New Composition draft and settings; status text; `edit(_:coalesceKey:_:)`, the one place an edit records undo. | `Sources/HaloModel/HaloProject.swift`<br>`Sources/HaloModel/CompositionSettings.swift`<br>`Sources/HaloModel/CompositionDraft.swift`<br>`Sources/HaloModel/NameKey.swift`<br>`Sources/HaloModel/RefusedRename.swift`<br>`Sources/HaloModel/CompositionDeleteCommand.swift`<br>`Sources/HaloModel/HaloStatusText.swift` | reads its services → `halo-services`; stores HaloDocumentState and HaloHistory → `halo-contracts` |
| `halo-layers` Layers | existing | HaloLayer (kind, span, color, opacity, CoreRaster blend mode, solid rectangle, and from W0 keyframe tracks keyed by HaloProperty, parent id and text content; Codable) and each kind's own box and default property values. | `Sources/HaloModel/HaloLayer.swift`<br>`Sources/HaloModel/HaloLayerDefaults.swift` | stores FlareCore Keyframe tracks → `flarecore`; stores CoreRaster BlendMode → `coreraster` |
| `halo-timeline` Timeline and playback | existing | Each composition's playhead and timecode, the strip's rows with key frames, in and out points at the playhead (I and O), and from W1 play, pause, loop, step and the tick that advances the playhead through PlaybackClock. | `Sources/HaloModel/HaloTimeline.swift`<br>`Sources/HaloModel/HaloPlayback.swift` | advances through PlaybackClock → `halo-contracts` |
| `halo-commands` Commands and availability | planned | HaloCommand: every menu, toolbar and key command of v1, with its title, and HaloProject.unavailableHelp(for:): nil when it can act now, else the reason the control shows. Read from each service's unavailableHelp and the state, so a command turns on when its feature's live type lands. | `Sources/HaloModel/HaloCommand.swift` | reads each service's unavailableHelp → `halo-services` |
| `halo-contracts` Use-case contracts | planned | One protocol per use case (FrameDrawing, LayerPlacing, PropertyKeying, ViewerDragging, KeyEasing, ProjectHistory, ProjectFiles, PlaybackClock, FrameRendering, TextRasterizing, RenderSink, CompositionRendering) and the values they speak (HaloProperty, HaloDrawList, HaloDocumentState, HaloHistory, HaloKeyRef, HaloEasingPreset, the render plan and the error enums). FlareCore's Keyframe, Easing, Matrix and Point under Halo names. | `Sources/HaloModel/Contracts/` | names FlareCore Keyframe, Easing, Matrix and Point → `flarecore`; names PixelBuffer and BlendMode → `coreraster` |
| `halo-services` Services and live conformances | planned | HaloServices: one existential per contract with its .fake and .live values. Live/ holds one file per contract: a W0 stub that says why its controls are disabled, replaced whole by its feature with the real conformance over FlareCore and CoreRaster. | `Sources/HaloModel/HaloServices.swift`<br>`Sources/HaloModel/Live/` | conforms to → `halo-contracts`; samples tracks, eases, multiplies matrices → `flarecore`; composites, masks and converts pixels → `coreraster` |
| `halo-fakes` Fakes and fixtures | planned | One fake per contract, small and predictable, for views, snapshots and journeys before the live types land; HaloFixtures builds the named fixture projects (empty, three-layers, keyed, parented, two-comps, reference, crowd) in code. | `Sources/HaloModel/Fakes/`<br>`Sources/HaloModel/HaloFixtures.swift` | conforms to → `halo-contracts` |
| `halo-viewer-model` Viewer state | planned | The viewer's draw list at the playhead (FrameDrawing plus the live drag offset), the viewer hit and drag: begin on the topmost layer under the pointer, move as a preview that never records undo, commit on mouse-up as one 'Move' step through ViewerDragging. | `Sources/HaloModel/HaloViewerState.swift`<br>`Sources/HaloModel/HaloViewerDrag.swift` | calls FrameDrawing and ViewerDragging → `halo-contracts`; records the Move step through edit → `halo-project` |
| `halo-keying` Keys and easing | planned | The inspector's property rows for the selected layer at the playhead; set value, stopwatch, key-here diamond and parent, each one named step (scrubs coalesce); selected keys on the timeline and setting their easing as one 'Keyframe Easing' step. | `Sources/HaloModel/HaloKeying.swift`<br>`Sources/HaloModel/HaloKeySelection.swift` | calls PropertyKeying, LayerPlacing and KeyEasing → `halo-contracts`; records steps through edit → `halo-project` |
| `halo-layer-edits` Layer housekeeping | planned | Delete, rename, reorder and duplicate a layer of the selected composition, each one named step; a parent that is deleted leaves its children in place. | `Sources/HaloModel/HaloLayerEdits.swift` | records steps through edit → `halo-project` |
| `halo-history` Undo and redo | planned | undo() and redo() of whole-document steps through ProjectHistory, their menu titles, and the rule that selection, scrubbing and playback are not steps. | `Sources/HaloModel/HaloHistory.swift` | calls ProjectHistory → `halo-contracts` |
| `halo-files` Project files | planned | fileData() and open(_:) through ProjectFiles, the file name, unsaved flag, the last save or open error, and the Open Recent list. Opening clears history. | `Sources/HaloModel/HaloFiles.swift` | calls ProjectFiles → `halo-contracts` |
| `halo-frames` Rendered frames | existing | FrameRenderer composites a frame with CoreRaster (today: axis-aligned solids; from W1 every v1 layer kind at its world transform, through FrameRendering) and the rendered frame Render Frame shows in the viewer, with when it goes stale. | `Sources/HaloModel/FrameRenderer.swift`<br>`Sources/HaloModel/HaloRenderFrame.swift` | composites, masks, blends → `coreraster`; flattens and transforms outlines → `flarecore` |
| `halo-render-out` Render to files | planned | The Render… job: settings, the plan, progress ('Frame 48 of 240'), cancel and the outcome, driving CompositionRendering into a RenderSink the app supplies. | `Sources/HaloModel/HaloRenderJob.swift` | calls CompositionRendering → `halo-contracts` |
| `halo-text` Text layers | planned | Set a text layer's string and size, each one named step; an empty string is refused. | `Sources/HaloModel/HaloTextEdits.swift` | records steps through edit → `halo-project` |

#### HaloApp (existing)

The Halo app: the SwiftUI scene, the window and its views built from SuiteUI, the menus, and the macOS-only platform pieces (file type, PNG and movie writers, text rasterizer, frame image). Reads HaloModel and calls its methods; never writes its state (scripts/ci app-state rule).

| Component | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| `halo-scene` App scene and launch | existing | The App scene (WindowGroup, commands) and the launch arguments that pick services and data for journeys: -HaloFixture, -HaloSample, -HaloOpenFile, -HaloSaveTo, -HaloRenderTo, -HaloWindowSize, -HaloPerfProbe. | `Sources/HaloApp/HaloApp.swift`<br>`Sources/HaloApp/HaloLaunch.swift` | shows → `halo-window`; installs → `halo-menus` |
| `halo-window` Window and command router | planned | HaloWindow: the one @State model, every presentation flag v1 needs, and perform(_ command: HaloCommand), which routes each command to its area file (HaloWindow+Viewer, +Playback, +Keys, +Layers, +Edit, +File, +Easing, +Render, +Text). W0 writes the router and stub area files; each feature owns one area file. | `Sources/HaloApp/HaloWindow.swift`<br>`Sources/HaloApp/HaloWindow+Viewer.swift`<br>`Sources/HaloApp/HaloWindow+Playback.swift`<br>`Sources/HaloApp/HaloWindow+Keys.swift`<br>`Sources/HaloApp/HaloWindow+Layers.swift`<br>`Sources/HaloApp/HaloWindow+Edit.swift`<br>`Sources/HaloApp/HaloWindow+File.swift`<br>`Sources/HaloApp/HaloWindow+Easing.swift`<br>`Sources/HaloApp/HaloWindow+Render.swift`<br>`Sources/HaloApp/HaloWindow+Text.swift` | reads state, calls methods → `halo-project`; asks each command's availability → `halo-commands`; SuiteWindow shell → `suiteui` |
| `halo-menus` Menus | existing | Composition, Layer, File, Edit and Animation menus. Every item sends a HaloCommand through the focused window and is disabled, with the Model's reason as help, when it can't act. | `Sources/HaloApp/HaloCommands.swift`<br>`Sources/HaloApp/HaloCompositionCommands.swift`<br>`Sources/HaloApp/HaloFileMenu.swift`<br>`Sources/HaloApp/HaloEditMenu.swift`<br>`Sources/HaloApp/HaloAnimationMenu.swift` | sends commands to → `halo-window` |
| `halo-viewer` Viewer | existing | The viewer: the artboard (CanvasSurface) with the draw list painted in a SwiftUI Canvas, the selection outline, the drag gesture, the rendered-frame image, the status bar and the transport; the display-link playback driver. | `Sources/HaloApp/HaloViewer.swift`<br>`Sources/HaloApp/HaloViewerCanvas.swift`<br>`Sources/HaloApp/HaloViewerGestures.swift`<br>`Sources/HaloApp/HaloTransport.swift`<br>`Sources/HaloApp/HaloPlaybackDriver.swift` | reads the draw list, calls the drag → `halo-viewer-model`; CanvasSurface, SelectionOutline, ViewerStatusBar, TransportCapsule → `suiteui` |
| `halo-timeline-view` Timeline view | existing | The strip under the viewer: one lane per layer with its span and key diamonds, the playhead, scrub, I and O, key selection and the key context menu. | `Sources/HaloApp/HaloTimelineView.swift` | reads rows, calls scrub and points → `halo-timeline`; TimelineStrip → `suiteui` |
| `halo-inspector` Inspector | existing | The inspector: the composition header and rows, the layer list (select, rename, reorder, delete), the selected layer's TRANSFORM rows with keyframe buttons, parent and blend pickers, the EASING group (chips and curve) and the TEXT section. | `Sources/HaloApp/HaloCompositionInspector.swift`<br>`Sources/HaloApp/HaloLayerList.swift`<br>`Sources/HaloApp/HaloLayerInspector.swift`<br>`Sources/HaloApp/HaloEasingInspector.swift`<br>`Sources/HaloApp/HaloTextInspector.swift` | reads rows, calls keying → `halo-keying`; InspectorHeader, InspectorSection, StudioScrubRow, KeyframeButton, InspectorPickerRow, ChoiceChips, CurveEditor, InspectorColorRow → `suiteui` |
| `halo-sheets` Sheets and alerts | existing | New Composition sheet, the rename refusal alert (until SuiteUI #577), and the Render… sheet with progress and Cancel. | `Sources/HaloApp/NewCompositionSheet.swift`<br>`Sources/HaloApp/RenameRefusalAlert.swift`<br>`Sources/HaloApp/HaloRenderSheet.swift` | reads the job, starts and cancels it → `halo-render-out` |
| `halo-platform` Platform pieces | planned | macOS-only conformances and conversions with no SwiftUI: the .halo UTType, the rendered frame as a CGImage (from CoreRaster rgba8), the PNG sequence writer (ImageIO) and movie writer (AVFoundation) as RenderSinks, and the CoreText TextRasterizing. | `Sources/HaloApp/HaloDocumentType.swift`<br>`Sources/HaloApp/HaloFrameImage.swift`<br>`Sources/HaloApp/HaloPNGWriter.swift`<br>`Sources/HaloApp/HaloMovieWriter.swift`<br>`Sources/HaloApp/HaloTextRasterizer.swift` | conforms to RenderSink and TextRasterizing → `halo-contracts`; reads rgba8 display bytes → `coreraster` |

#### Halo tests (existing)

HaloModelTests (Linux and macOS), Halo's snapshot, golden and latency files in AppSnapshotTests (macOS), and Halo's UI journeys.

| Component | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| `halo-model-tests` HaloModelTests | existing | Model behavior, contract conformance suites run against both the fake and the live type, fixtures, budgets (HaloBudgetTests) and Linux fidelity checks (render reference pixels, file round trip). | `Tests/HaloModelTests/` | tests → `halo-model` |
| `halo-snapshots` Halo snapshots and goldens | existing | Halo*Snapshots.swift PNGs in Light and Dark, goldens once QH-2 (#331) lands, HaloViewerFidelityTests (viewer equals render) and HaloViewerLatencyTests. | `Tests/AppSnapshotTests/Halo` | renders views of → `halo-app` |
| `halo-journeys` Halo journeys | existing | UITests/HaloJourneyTests.swift and, once QH-4 (#333) lands, one HaloJourneyTests+<Area>.swift per feature: the tier-1 journeys H-J0 to H-J12 with a whole-window shot per step and the app audit on every shot. | `UITests/HaloJourneyTests` | drives the release bundle of → `halo-app` |

### Rules the components keep

**One state value.** `HaloProject` stays the single `Sendable`, `Equatable`
value behind the window. W0 (task F0-5 in section 8) moves the document part
into a stored `document: HaloDocumentState` (compositions, selection, the id
counter) with computed accessors for today's public names, so nothing that
reads `compositions` or `selectedCompositionID` changes. W0 adds, in one PR
to `HaloProject.swift`, every stored property this blueprint needs, so no
later feature edits that file:

| Stored property | Read by | Written only by (file) |
|---|---|---|
| `document: HaloDocumentState` | everything | `HaloProject.swift`, through `edit` and `restore` |
| `services: HaloServices` | every extension | `init(services:)` |
| `history: HaloHistory` | Edit menu | `HaloHistory.swift`, and `edit` in `HaloProject.swift` |
| `playback: HaloPlaybackState` (playing, loops, start frame, start time) | transport, driver | `HaloPlayback.swift` |
| `viewerDrag: HaloViewerDragState?` (layer, start point, delta) | viewer | `HaloViewerDrag.swift` |
| `selectedKeys: Set<HaloKeyRef>` | timeline, inspector, Animation menu | `HaloKeySelection.swift` |
| `file: HaloFileState` (name, unsaved, error, recent) | title, File menu, alerts | `HaloFiles.swift` |
| `renderedFrame: HaloRenderedFrame?`, `renderedFrameStale: Bool` | viewer | `HaloRenderFrame.swift` |
| `renderJob: HaloRenderJobState?` (settings, plan, progress, outcome) | Render sheet | `HaloRenderJob.swift` |
| `refusal: String?` (the last refused edit's message) | the control that refused | `HaloProject.swift` (`edit` sets it from a thrown `HaloEditError`) |

The same PR changes stored state from `public private(set)` to
`public internal(set)`, as Flare's LM-0a3 did: extensions in other files of
HaloModel can write their own property, and HaloApp, another module, still
cannot (the compiler and the app-state lint both hold).

**One undo step, exactly.** Every document edit goes through
`mutating func edit(_ name: String, coalesceKey: String? = nil, _ body: (inout HaloDocumentState) throws -> Void)`
in `HaloProject.swift`: it copies the document, runs the body on the copy,
and only if the body did not throw and the copy differs from the original,
stores the copy and calls `services.history.record(name, before:, coalesceKey:, in: &history)`.
A throw sets `refusal` to the error's message and changes nothing. So:

- *Scrubs* (an inspector bar drag, arrow-key nudges on one row) pass
  `coalesceKey: "<layer id>.<property>"`: one undo entry however many calls.
- *Viewer drags* never call `edit` while the pointer moves. They change only
  `viewerDrag`; mouse-up calls `edit("Move")` once.
- *Selection, scrubbing the playhead and playback* never call `edit`; they
  are not steps (`docs/design.md`, Canvas apps).
- Existing mutators move under `edit` in W0 with these names: "New
  Composition", "Duplicate Composition", "Rename Composition", "Delete
  Composition", "New Layer", "Set In Point", "Set Out Point", "Change Opacity",
  "Change Blend Mode". Later features add "Move", "Change <Property title>",
  "Animate <title>", "Stop Animating <title>", "Add Key", "Remove Key", "Set
  Parent", "Keyframe Easing", "Delete Layer", "Rename Layer", "Move Layer",
  "Duplicate Layer", "Edit Text", "Change Text Size".

The history keeps whole `HaloDocumentState` values (#208's call, marked
`ponytail:` in the code: commands replace it once creative-core has a Halo
engine). A 300-layer, 5,000-key project is about 0.5 MB in memory, so 100
steps cost at most about 50 MB; HB-9 checks the copy time.

**Where a property's value lives.** A layer's `tracks[property.rawValue]`
holds FlareCore `Keyframe`s, sorted, one per frame. The rule, shared by fake
and live and stated in `PropertyKeying`'s doc comments, is Flare's (section 2
of `docs/blueprints/flare.md`), so the two apps' keyframe buttons behave the
same:

- No track or one key: **not animated**. The value is that key's (or the
  layer default: anchor and position at the box center, scale 1, rotation 0,
  opacity the layer's `opacity`). Setting it rewrites that one key.
- Two or more keys: **animated**. Setting it at any frame writes a key at
  the playhead. The stopwatch is filled; "keyed here" when a key sits at the
  playhead.
- The stopwatch on a not-animated property keys the playhead and the last
  frame with the current value, so two diamonds appear; off keeps the value
  at the playhead as the one static value.
- Sampling is FlareCore's `Timeline.value(of:at:)`, so easing (#428) is
  FlareCore's `Easing` and nothing in Halo interpolates on its own.

**Coordinates.** Composition pixels, top-left origin, y down, as
`HaloLayerRect` and CoreRaster already use. Rotation in degrees, positive
clockwise on screen (FlareCore's `Matrix.rotation` in a y-down space, the
same reading Flare's stage uses). A layer's world matrix is
`parent world × translate(x, y) × rotate(r) × scale(sx, sy) × translate(−anchorX, −anchorY)`
(suite plan H2). Opacity does not pass to children; a hidden parent (out of
its span) does not hide children. A parent cycle can't be made
(`setParent` throws) and a file holding one is refused (`ProjectFiles`).

**Rendering and feel.** The viewer and the renderer read the same
`HaloDrawList`, built once per frame by `FrameDrawing`:

1. The viewer paints the list in one SwiftUI `Canvas` inside
   `CanvasSurface` at screen resolution: rectangles, ellipses and text as
   vectors, each with its matrix, opacity and blend mode
   (`GraphicsContext.blendMode` maps from CoreRaster's `BlendMode` in one
   switch in `HaloViewerCanvas.swift`). No pixels are composited per frame
   while scrubbing or playing; HB-2 and HB-4 hold because of this.
2. `FrameRendering` turns the same list into CoreRaster pixels: each item's
   outline (a FlareCore `Path` of its box or ellipse, transformed by its
   matrix and flattened) becomes a `Mask.polygon`, filled with its color,
   composited with its blend mode and opacity. That is the reference every
   rendered file is made from, and HF-1 holds the viewer to it.
3. A viewer drag changes only `viewerDrag`; the viewer redraws
   `drawList.offsetting(layer, by: delta)`. Mouse-up commits once.
4. Playback is driven by a display link in `HaloPlaybackDriver.swift` that
   calls `model.tick(now:)`; the frame math is `PlaybackClock` (FlareCore's
   `Timeline.playbackFrame` in the live type), tested on Linux.

**Commands and availability.** `HaloCommand` (Model) lists every command in
v1. `HaloProject.unavailableHelp(for:)` returns nil when the command can act
now, or the reason (from the state, then from the command's service:
`services.clock.unavailableHelp` for Play). Menus, toolbar items and the
journey sweep read it, so a command turns on the day its live type replaces
the W0 stub, and `HaloCommandTests` proves on Linux that every command on
`.live` today is disabled with a reason. On the app side `HaloWindow.perform`
routes each command to its area file.

**Engine-direct (no protocol, one conformer):** composition management and
the New Composition draft (shipped, in `HaloProject`), timecode and status
text, in and out points, layer housekeeping, and fixtures. Fixtures are
their fake data.

**Why not new targets:** `Package.swift` is protected and every target
exists; HaloModel is Linux-safe and tested, which is where contracts and
fakes belong (the same call as Flare).

**Launch arguments** (`HaloLaunch.swift`, W0): `-HaloFixture <name>` (fake
services plus a fixture project), `-HaloSample <name>` (the same project on
live services, for integrated journeys), `-HaloOpenFile <path>`,
`-HaloSaveTo <file path>` (Save writes there without a panel), `-HaloRenderTo <folder>`, `-HaloWindowSize <w>x<h>`
(layout checks), `-HaloPerfProbe` (exposes the frame probe once #330 lands).

**Fixtures** (`HaloFixtures`, HaloModel, built in code, W0):

| Fixture | Contents | Used by |
|---|---|---|
| `empty` | One composition "Comp 1", 1920 × 1080, 30 fps, 10 s, no layers | H-J1, H-J8 |
| `three-layers` | "Intro", 1920 × 1080, 24 fps, 72 frames: "Title" text (frames 24–72), "Badge" shape, "Background" solid, "Rig" null (0–72) | H-J2, H-J3, H-J4, H-J11 |
| `keyed` | "Bounce", 1920 × 1080, 24 fps, 48 frames: "Ball" solid 200 × 200 with x keyed 160 at 0 and 960 at 24, opacity 0 at 0 and 1 at 12; "Floor" solid, not animated | H-J5, H-J6, H-J7, H-J9 |
| `parented` | `keyed` plus a "Rig" null that Ball follows, Rig x keyed | H-J6 (parent step), parenting tests |
| `two-comps` | "Intro" and "Outro" with layers and keys | H-J10 |
| `reference` | 1920 × 1080, 30 fps, 300 frames, 50 layers (solids, shapes, text), every property keyed at 10 frames: 4,000 keys | budgets HB-1 to HB-10 |
| `crowd` | 300 layers, 5,000 keys, 1920 × 1080, 30 fps, 300 frames | HB-6, HB-9, layout checks |

---

## 3. Usage map

Starts from `docs/priorities.md` (Halo section) and keeps its rule: the
features people use in nearly every session first. No public study measures
per-feature use in motion graphics tools, so, as there, tiers come from what
beginner courses teach first, what shortcut lists repeat, and what the
public specs we build on define. Rows marked *inferred* have no direct
source and move first if usage data turns up.

Sources (public, no product opened or run):

- [S1] 2019 motion design survey, 1,065 respondents (already used by
  `docs/priorities.md`): https://schoolofmotion.com/blog/2019-motion-design-survey
  — most respondents make short commercial and social pieces; keyframed 2D
  animation of text and shapes is the bulk of the work.
- [S2] W3C CSS Easing Functions Level 1: https://www.w3.org/TR/css-easing-1/
  — the linear, ease-in, ease-out, ease-in-out and step (hold) presets and
  the cubic-bezier form; FlareCore's `Easing` follows it.
- [S3] W3C Compositing and Blending Level 1: https://www.w3.org/TR/compositing-1/
  — the 16 blend modes and source-over; CoreRaster follows it.
- [S4] Lottie Animation Community format specification:
  https://lottie.github.io/lottie-spec/ — layer model (in and out points, parenting, transform with anchor
  point, solids, shapes, text, nulls, precomps), a public description of
  what motion graphics layers carry.
- [S5] SMPTE ST 12-1 timecode (hours:minutes:seconds:frames), as public
  summaries describe it: https://en.wikipedia.org/wiki/SMPTE_timecode
  — the readout format Halo already shows.

| Tier | Feature | Evidence | Issue | v1 |
|---|---|---|---|---|
| 1 | Create or pick a composition (size, rate, duration) | priorities.md; [S4] | shipped (#35) | yes |
| 1 | Timeline: layers, in and out points, scrub the playhead | priorities.md; [S4]; [S5] | shipped (#36) | yes |
| 1 | See layers drawn at the playhead | priorities.md ("preview at the playhead") | #37 | yes |
| 1 | Play, pause, loop at the composition rate | priorities.md | #37 | yes |
| 1 | Keyframe position, scale, rotation, opacity (stopwatch, key at playhead) | priorities.md; [S1]; [S4] | #38 | yes |
| 1 | Drag a layer in the viewer to key its position | priorities.md, *inferred* | #207 | yes |
| 1 | Easing presets | priorities.md; [S2] | #428 | yes |
| 1 | Undo and redo | priorities.md, *inferred* | #208 | yes |
| 1 | Save and open | priorities.md, *inferred* | #209 | yes |
| 1 | Layers: new, delete, rename, reorder, duplicate | *inferred* (the same tier Design gives its layers panel in priorities.md) | to file (L-1) | yes |
| 2 | Render to a movie or PNG sequence | priorities.md (export is p2 for Halo and Flare) | #429 | yes |
| 2 | Render Frame into the viewer | follows #429; checks what render will write | #451 | yes |
| 2 | Text layers | priorities.md; [S4] | #430 | yes |
| 2 | Parenting | priorities.md; [S4] | #38 (parent picker) | yes |
| 2 | Blend modes | priorities.md; [S3] | shipped in the Model; picker in #38 | yes |
| 2 | Anchor point | [S4], *inferred* | #38 | yes |
| 2 | Custom easing curve | priorities.md (Flare: curve editor tier 2); SuiteUI `CurveEditor` exists | #428 | yes (cheap) |
| 2 | Effects stack (blur, fill, levels) | priorities.md | #39 | no |
| 2 | Precompose | priorities.md; [S4] | – | no |
| 2 | Image and footage layers | [S4], *inferred* | – | no |
| 2 | Retime keys by dragging on the timeline; per-property lanes | *inferred* | – | no |
| 2 | Open Recent | *inferred* (Flare ships it in v1) | #209 (in scope) | yes |
| 3 | Expressions | priorities.md | – | no |
| 3 | Masks and track mattes | priorities.md; [S3] | – | no |
| 3 | Keying, tracking, 3D layers | priorities.md | – | no |
| 3 | Motion blur | *inferred*; suite plan H9 | – | no |
| 3 | Autosave and crash recovery | *inferred* (Flare ships it in v1; first Halo Later item) | – | no |
| – | Bugs and accessibility on shipped screens | review and audit | #457, #286, #290, #149, #139 | #457, #286, #290 yes; #149 yes (p3, small); #139 no (waits on SuiteUI #577) |

"To file (L-1)" is a new `line:halo` issue this blueprint asks for; it is
filed when the captain approves (section 9, Q4).

---

## 4. Journeys

Every tier-1 feature has a journey: an XCUITest that launches the release
bundle, works the window like a person, and shoots the whole window after
every step (`docs/engineering.md`, Human-like UI tests). The app audit runs
on every shot.

**Files.** Today all Halo journeys live in `UITests/HaloJourneyTests.swift`,
because `project.yml` compiles exactly one file per app. Once SuiteUI QH-4
(#333) lands, each feature owns `UITests/HaloJourneyTests+<Area>.swift`
with its own `XCTestCase` class, so two features never edit one journey
file. Until then a feature's journey task waits on #333 (section 8).

**Modes.** A journey first runs on `-HaloFixture <name>` (fake services) and
is flipped to `-HaloSample <name>` (live services, same project) by the task
that lands the live type. H-J12 runs live from its first PR.

**Finding things.** By the title a person reads where there is one, else
by identifier (`halo.<area>.<name>`). The viewer can't be read through
pixels in XCUITest, so `halo.viewer.artboard` carries the Model's
`viewerSummary` as its accessibility value ("Frame 30: Background, Badge,
Title"), built and tested in HaloModel. Drags use normalized points inside
`halo.viewer.artboard`, which map one to one onto composition pixels.

**Waiting.** No journey asserts timing through an XCUI query. State changes
are awaited with `waitForExistence` or a value predicate (2 s). Timing
claims come from the frame probe's JSON once #330 lands (section 7).

### Tier-1 journeys

| # | Test (file, feature) | Launch | Steps (each one shot, named `halo-<step>`) | Asserts |
|---|---|---|---|---|
| H-J0 | `testLaunchShowsWindowShell` (`HaloJourneyTests.swift`, shipped; extended by W0) | none | launch | `expectWindowShell()`; the viewer's empty state "No Composition" with New Composition…; the inspector's "No Selection"; no audit count over baseline |
| H-J1 | `testNewComposition` (`HaloJourneyTests.swift`, shipped; extended by W0) | none | New Composition…; type `abc` in Width; type `1080` in Width, `1920` in Height; pick 24 fps; Create | the problem "Width must be a whole number of pixels." and Create disabled; then Create enabled; inspector header reads "1080 × 1920" and "24 fps · 10 s"; sidebar row "Comp 1" |
| H-J2 | `testLayersDrawAtThePlayhead` (`+Viewer`, viewer-playback) | `three-layers` | scrub to frame 12; scrub to frame 30; Layer > New > Solid | `halo.viewer.artboard` value "Frame 12: Background, Badge" (Title starts at 24; Rig is a null, never drawn); at 30 "Frame 30: Background, Badge, Title"; after New > Solid "…, Solid 1" on top and the layer list's first row "Solid 1" |
| H-J3 | `testScrubAndSetInOutPoints` (`HaloJourneyTests.swift`, shipped as `testScrubTheTimeline`; extended by viewer-playback) | `three-layers` | select Badge in the timeline; scrub to 20; press I; scrub to 50; press O; scrub to 60 | timecode reads 00:00:00:20 then 00:00:02:02; Badge's span is 20–50 (row value "20 → 51"); at 60 the artboard value has no Badge |
| H-J4 | `testPlayPauseLoopAndStep` (`+Playback`, viewer-playback) | `three-layers` | Space; wait 1 s; Space; → twice; Animation > Go to End; Loop off; Animation > Go to Start; Space; wait 4 s | play button value "Playing" then "Paused"; frame after pause f ≠ 0; after → → f + 2; at end the timecode reads 00:00:02:23; with Loop off playback stops on the last frame and the button reads "Paused" |
| H-J5 | `testDragLayerToKeyPosition` (`+Drag`, layer-keys) | `keyed` | scrub to 12; drag Ball 100 px right in the artboard; open Edit; scrub to 0; drag Floor 50 px down | Ball's Position X row reads its frame-12 value + 100 and its key button "Keyed at this frame"; the Edit menu reads "Undo Move"; Floor's Position Y row moved by 50 and its key button reads "Not animated" (not animated layers move without keys); dragging empty surround selects nothing |
| H-J6 | `testInspectorKeysTransform` (`+Inspector`, layer-keys) | `keyed` | select Ball; click Rotation's stopwatch; scrub to 20; drag the Rotation bar right; focus it, → twice, Shift-→; click Opacity's diamond at 20 | Rotation key button "Animated", then "Keyed at this frame" at 20; value steps +1, +1, +10 (`QB-F4`); Ball's lane gains diamonds at 20 and 47 (the lane shows every property's keys: 0, 12, 20, 24, 47); Opacity "Keyed at this frame"; Edit menu "Undo Add Key" |
| H-J7 | `testEaseKeys` (`+Easing`, easing) | `keyed` | select Ball; in EASING click the row "Position X 0 → 24"; click Ease In and Out; drag curve handle 1; open Edit | the Animation > Keyframe Easing items are disabled with help "Select a key on the timeline first." before the row is picked; after the chip the row reads "Ease In and Out" and Ball's Position X at frame 12 reads 560.0 px (the eased midpoint equals the linear one for this symmetric curve, so the test also reads frame 6: below the linear 360.0 px); after the drag no chip is on and the row reads "Custom"; the Edit menu reads "Undo Keyframe Easing" |
| H-J8 | `testUndoRedoEveryEdit` (`+History`, history-files) | `empty` | Layer > New > Solid; rename the composition "Intro"; Composition > Delete is disabled (one left); Composition > New, Create; Composition > Delete; ⌘Z; ⌘Z; ⇧⌘Z | after each edit the Edit menu names it ("Undo New Layer", "Undo Rename Composition", "Undo New Composition", "Undo Delete Composition"); the first ⌘Z brings the deleted composition back with its layers at its place in the sidebar; the second removes it; ⇧⌘Z restores it; scrubbing in between adds no step |
| H-J9 | `testLayerHousekeeping` (`+Layers`, layer-panel) | `three-layers` | select Badge; Layer > Duplicate; rename "Badge copy" to "Badge 2" in the list; drag it to the bottom; Layer > Delete; ⌘Z | "Badge copy" appears above Badge; renamed; last in the list and drawn first (artboard value lists it first); gone, then back on ⌘Z; each step named in the Edit menu |
| H-J10 | `testSaveAndReopen` (`+Files`, history-files) | `two-comps` with `-HaloSaveTo <tmp>/Spot.halo` (skips the save panel) | ⌘S; quit; relaunch with `-HaloOpenFile <saved path>`; File > Open Recent | the window title reads "Spot" with no unsaved dot; after reopen both compositions, their layers and Ball's keys are back and the history is empty (Undo disabled with "Nothing to undo."); Open Recent lists "Spot" |
| H-J11 | `testOpenBadFiles` (`+FileErrors`, history-files) | none, then `-HaloOpenFile` per file | write four files in the test's temp folder (`not json`; `{"format":"halo","version":2}`; `{"format":"halo","version":1,"compositions":[{"id":"a"}]}`; 65 MB of spaces) and open each | each alert's text is `HaloFileError.message` for its case (not a Halo project; newer format 2; damaged with the reason; too large); after each, the empty state stays |
| H-J12 | `testKeyLayerAndSave` (`HaloJourneyTests.swift`, core-loop; replaces the `XCTSkip`) | live, `-HaloSaveTo` | New Composition…, Create; Layer > New > Solid; scrub to 0; Position X stopwatch; scrub to 24; drag the solid 300 px right; Ease Out on its first key; Space, wait 1 s, Space; ⌘Z; ⇧⌘Z; ⌘S; relaunch on the file | each step on live services; Edit menu names along the way; the reopened file has Position X keys at 0, 24 and 299 (the stopwatch also keys the last frame) with Ease Out on the first |
| H-J13 | `testEveryMenuOpens` (shipped) and `testEveryControlActsOrSaysWhy` (`+EveryControl`, W0) | `keyed` | open each menu; then read the `halo.controls` JSON (every `halo.*` control with enabled and help), click each enabled one, Escape, ⌘Z | every menu shot; each menu's item count equals section 6's menu list; every enabled control changed the shot or a value; every disabled one has help text (`QB-F1`). A sweep: the coverage matrix never cites it |

### States each journey passes through

| Journey | Empty | Error | Loading |
|---|---|---|---|
| H-J0, H-J1 | "No Composition" empty state with New Composition…; "No Selection" in the inspector | each `CompositionSettings.problems` line under the form, Create disabled | none |
| H-J2 | a composition with no layers: the artboard shows the background and the value "Frame 0: no layers"; a frame where nothing is in its span reads the same | none (draw never fails) | none |
| H-J3 | no layer selected: I and O are refused and the timeline's help says "Select a layer, then press I or O." | I after the out point (or O before the in point) is refused: the row keeps its span and `refusal` reads "The in point must come before the out point." | none |
| H-J4 | no composition: Play disabled with "Create a composition first." | none | none |
| H-J5 | a drag that starts on no layer moves nothing and adds no step | a drag on a layer outside its span can't hit it | the live preview while dragging (`viewerDrag`) is the in-between state; the probe's "preview before mouse-up" mark proves it once #330 lands |
| H-J6 | no layer selected: the TRANSFORM group is replaced by "Select a layer to see its properties." | a typed `abc` in a row keeps the old value and shows "Rotation needs a number." under the row | none |
| H-J7 | no keys on the layer: "Key a property to shape its easing."; keys but none picked: "Pick a key above." | setting easing with nothing selected is refused (the menu item is disabled with that reason) | none |
| H-J8 | nothing to undo: Undo disabled, help "Nothing to undo." | none | none |
| H-J9 | deleting the last layer leaves the timeline's empty text "No layers yet. Add one from Layer > New." | renaming to an empty name keeps the old one | none |
| H-J10, H-J11 | a new project is "Untitled Project" until saved | save to a read-only folder: the title shows "Not saved" and an alert with the reason; open errors per `HaloFileError` | opening a large file shows progress in the viewer after 100 ms (`QB-L9`); the window stays responsive (decode runs off the main actor) |

### Tier-2 journeys (v1, after the core loop)

| # | Test (file, feature) | Launch | Steps | Asserts |
|---|---|---|---|---|
| H-J20 | `testRenderFrame` (`+RenderFrame`, render-out) | `keyed` | scrub to 12; ⌘R; scrub to 13 | the viewer shows the rendered image (`halo.viewer.rendered` exists) with the note gone (#457); after scrubbing it reads "Rendered frame is out of date." until ⌘R again |
| H-J21 | `testRenderPNGSequence` (`+Render`, render-out) | `keyed` (48 frames) with `-HaloRenderTo` | File > Render…; PNG sequence, half size; Render; then start a movie render and Cancel | progress "Frame n of 48" then success with Reveal in Finder; 48 files `Bounce_0001.png` … `Bounce_0048.png` of 960 × 540; after Cancel no partial movie is left |
| H-J22 | `testTextLayer` (`+Text`, text-layers) | `empty` | Layer > New > Text; type "Hello" in TEXT; size 96; empty the field and press Return | artboard value lists "Text 1: Hello"; Edit menu "Undo Edit Text"; the empty string is refused and "Hello" comes back |
| H-J23 | `testParentAndBlend` (`+Parent`, layer-keys) | `parented` | select Ball; Parent → Rig; drag Rig 100 px right; Blend → Multiply; Parent → None | Ball moves with Rig (its own Position X row unchanged); the Blend row reads Multiply; clearing the parent keeps Ball where it is on screen; Ball's parent menu leaves out Ball itself and any layer following Ball |

### Perf journeys (after QH-1 #330 and QH-4 #333)

| # | Test | Launch | Steps | Budget (section 7) |
|---|---|---|---|---|
| H-P1 | `testViewerDragLatency` (`+Perf`, core-loop) | `reference` | four velocity-controlled drags of a layer across 600 pt at 300 pt/s | HB-U1, at least 60 samples per drag |
| H-P2 | `testInspectorScrubLatency` (`+Perf`, core-loop) | `reference` | drag the Rotation bar | HB-U2 |
| H-P3 | `testPlayheadScrubLatency` (`+Perf`, core-loop) | `reference` | drag the playhead end to end | HB-U3 |
| H-P4 | `testPlaybackHoldsRate` (`+Perf`, core-loop) | `reference` | play 5 s at 30 fps | HB-U4 |
