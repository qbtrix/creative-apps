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
| `halo-viewer` Viewer | existing | The viewer: the artboard (CanvasSurface) with the draw list painted in a SwiftUI Canvas, the selection outline, the drag gesture, the rendered-frame image (HaloRenderedFrameView), the status bar and the transport; the display-link playback driver. | `Sources/HaloApp/HaloViewer.swift`<br>`Sources/HaloApp/HaloViewerCanvas.swift`<br>`Sources/HaloApp/HaloViewerGestures.swift`<br>`Sources/HaloApp/HaloRenderedFrameView.swift`<br>`Sources/HaloApp/HaloTransport.swift`<br>`Sources/HaloApp/HaloPlaybackDriver.swift` | reads the draw list, calls the drag → `halo-viewer-model`; CanvasSurface, SelectionOutline, ViewerStatusBar, TransportCapsule → `suiteui` |
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

---

## 5. Contracts

One Swift protocol per use case, with a fake for each, so a feature's views
can be built and journeyed on the fake while its logic is built on the
live type, and the two meet by swapping one file. They are written to
compile on Linux in HaloModel: Foundation through the FoundationEssentials
pattern, FlareCore and CoreRaster only, value types, `Sendable`, Swift 6.

**Proof.** The code below is copied from
`docs/blueprints/halo/contracts/`, and `docs/blueprints/halo/contracts/check.sh`
builds it with today's HaloModel and creative-core `main` in a throwaway
package and runs `Tests/HaloContractTests.swift` (7 tests on the fakes). Run
on 2026-10-14 with Swift 6.3.3 on Ubuntu 24.04 against creative-core
4cac701: `CONTRACTS: PASS`, no warnings. W0 copies these files into
`Sources/HaloModel/` (the fakes split one file per contract, the live stubs
one file per contract under `Live/`).

**Rules every conformance keeps.**

- Reads take values; writes take the composition `inout` and throw
  `HaloEditError`, changing nothing when they throw (fakes do it by writing
  to a copy).
- No contract records undo. `HaloProject.edit(_:coalesceKey:_:)` does
  (section 2), so fakes and live types are tested without a project.
- Every service has `unavailableHelp`: nil once it works. The W0 live
  stubs return the reason, so every control that needs one is disabled
  with that text until its feature lands.
- One conformance suite per contract (`Tests/HaloModelTests/<Contract>ContractTests.swift`,
  W0) runs the same expectations against the fake and, once it exists, the
  live type: `@Test(arguments: [HaloServices.fake, .live])` style. A live
  type is done when it passes its suite.

### Use cases at a glance

| Use case | Protocol | Fake | Live file (feature) | Journeys |
|---|---|---|---|---|
| See the layers at the playhead | `FrameDrawing` | `FakeFrameDrawing` (no parenting) | `Live/LiveFrameDrawing.swift` (viewer-playback) | H-J2, H-J3 |
| Where a layer is, through parents | `LayerPlacing` | `FakeLayerPlacing` (no parenting) | `Live/LiveLayerPlacing.swift` (layer-keys) | H-J5, H-J6, H-J23 |
| Key a property in the inspector | `PropertyKeying` | `FakePropertyKeying` | `Live/LivePropertyKeying.swift` (layer-keys) | H-J6, H-J12 |
| Drag a layer to key its position | `ViewerDragging` | `FakeViewerDragging` | `Live/LiveViewerDragging.swift` (layer-keys) | H-J5, H-J12 |
| Ease keys | `KeyEasing` | `FakeKeyEasing` | `Live/LiveKeyEasing.swift` (easing) | H-J7, H-J12 |
| Undo and redo | `ProjectHistory` | `FakeProjectHistory` | `Live/LiveProjectHistory.swift` (history-files) | H-J8, all Edit-menu asserts |
| Save and open | `ProjectFiles` | `FakeProjectFiles` (no validation) | `Live/LiveProjectFiles.swift` (history-files) | H-J10, H-J11 |
| Play | `PlaybackClock` | `FakePlaybackClock` | `Live/LivePlaybackClock.swift` (viewer-playback) | H-J4 |
| Render a frame to pixels | `FrameRendering` (+ `TextRasterizing`) | `FakeFrameRendering`, `FakeTextRasterizer` | `Live/LiveFrameRendering.swift` (viewer-playback); `HaloTextRasterizer.swift` in HaloApp (text-layers) | H-J20, H-J22 |
| Render a composition to files | `CompositionRendering` (+ `RenderSink`) | `FakeCompositionRendering` | `Live/LiveCompositionRendering.swift` (render-out); sinks `HaloPNGWriter.swift`, `HaloMovieWriter.swift` in HaloApp | H-J21 |

Composition management, timecode, in and out points, layer housekeeping and
text edits are engine-direct workspace methods (section 2), tested on
`HaloProject` itself.

### The workspace methods views call

Each lives in the extension file its feature owns (section 8). Every write
goes through `edit`; every read is a computed property.

| File (feature) | Methods |
|---|---|
| `HaloViewerState.swift` (W0) | `var viewerDrawList: HaloDrawList?` (drawing at the playhead plus the drag offset), `var viewerSummary: String` |
| `HaloCommand.swift` (W0) | `enum HaloCommand`, `func unavailableHelp(for: HaloCommand) -> String?`, `func title(for: HaloCommand) -> String` (Undo and Redo carry the step name) |
| `HaloPlayback.swift` (viewer-playback) | `play(at now: Double)`, `pause()`, `togglePlay(at:)`, `setLoops(_:)`, `tick(now:)`, `stepFrame(by:)`, `goToStart()`, `goToEnd()` |
| `HaloViewerDrag.swift` (layer-keys) | `beginViewerDrag(at: HaloPoint)`, `moveViewerDrag(to: HaloPoint)`, `endViewerDrag()`, `cancelViewerDrag()` |
| `HaloKeying.swift` (layer-keys) | `var propertyRows: [HaloPropertyRow]`, `setProperty(_:to:)` (coalesced per row), `endPropertyScrub()`, `toggleAnimation(_:)`, `toggleKey(_:)`, `setParent(_:)`, `var parentChoices: [(id: String, name: String)]` |
| `HaloLayerEdits.swift` (layer-panel) | `deleteSelectedLayer()`, `renameLayer(_:to:)`, `moveLayer(_:to:)`, `duplicateSelectedLayer()` |
| `HaloHistory.swift` (history-files) | `undo()`, `redo()`, `var undoTitle: String?`, `var redoTitle: String?` |
| `HaloFiles.swift` (history-files) | `fileData() throws -> Data`, `open(_ data: Data, name: String) throws`, `didSave(as name: String)`, `var title: String`, `var recent: [String]` |
| `HaloKeySelection.swift` (easing) | `var keySegments: [HaloKeySegment]`, `selectKey(_:extending:)`, `clearKeySelection()`, `setEasing(_ preset: HaloEasingPreset)`, `setCustomEasing(_:coalesceKey:)` |
| `HaloRenderFrame.swift` (render-out) | `renderCurrentFrame()`, `var renderedFrameNote: String?` |
| `HaloRenderJob.swift` (render-out) | `startRender(_ settings:)`, `renderProgress(frame:)`, `cancelRender()`, `finishRender(_ outcome:)` |
| `HaloTextEdits.swift` (text-layers) | `setText(_:)`, `setFontSize(_:)` |

The state types the stored properties use (`HaloPlaybackState`,
`HaloViewerDragState`, `HaloFileState`, `HaloRenderJobState`) are declared
with `HaloProject` in W0, all `Sendable` and `Equatable` with public
memberwise inits; `HaloKeySegment` (a key and the next one on a track, with
its preset or "Custom") is declared by the easing feature in
`HaloKeySelection.swift`.

### W0 change to `HaloLayer`

The contracts read three new stored fields on `HaloLayer`, all added in W0
with `Codable` on the layer and composition types (the file
`docs/blueprints/halo/contracts/W0/HaloLayer.swift` is `HaloLayer.swift` as
W0 leaves it):

```swift
    /// W0: keyframe tracks by `HaloProperty.rawValue`, each sorted by frame
    /// with one key per frame. A property with no track uses its default.
    public var tracks: [String: [HaloKeyframe]] = [:]
    /// W0: the layer this one follows; nil for none. Never a cycle.
    public var parentID: String?
    /// W0: a text layer's words and size; nil for other kinds (tier 2, #430).
    public var text: HaloTextContent?
```

`withID` (used by Duplicate Composition) copies all three, and
`duplicateComposition` remaps `parentID` to the copy's ids.

### 5.1 Values (`Contracts/HaloValues.swift`)

```swift
// Contracts/HaloValues.swift: the value types every Halo contract speaks.
// Linux-safe. FlareCore's keyframe, easing, matrix and point are used as they
// are (never mirrored), under Halo names so HaloApp never has to import
// FlareCore, whose Path and Color clash with SwiftUI's.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import FlareCore

public typealias HaloKeyframe = FlareCore.Keyframe
public typealias HaloEasing = FlareCore.Easing
public typealias HaloMatrix = FlareCore.Matrix
public typealias HaloPoint = FlareCore.Point

/// An animatable layer property. The raw value is the track key in
/// `HaloLayer.tracks`, the same names FlareCore's `Layer.sample` uses.
public enum HaloProperty: String, CaseIterable, Codable, Sendable {
    case x, y, scaleX, scaleY, rotation, opacity, anchorX, anchorY

    /// The inspector row's label.
    public var title: String {
        switch self {
        case .x: "Position X"
        case .y: "Position Y"
        case .scaleX: "Scale X"
        case .scaleY: "Scale Y"
        case .rotation: "Rotation"
        case .opacity: "Opacity"
        case .anchorX: "Anchor X"
        case .anchorY: "Anchor Y"
        }
    }

    /// The values a row accepts; a write outside is clamped, never refused.
    public var range: ClosedRange<Double> {
        switch self {
        case .x, .y, .anchorX, .anchorY: -100_000...100_000
        case .scaleX, .scaleY: -100...100
        case .rotation: -36_000...36_000
        case .opacity: 0...1
        }
    }

    /// One arrow-key step; Shift is ten, Option a tenth (ScrubField's rule).
    public var step: Double {
        switch self {
        case .x, .y, .anchorX, .anchorY, .rotation: 1
        case .scaleX, .scaleY, .opacity: 0.01
        }
    }

    /// What the row shows per stored unit: scale and opacity are stored as
    /// factors (1 = 100%) and shown in percent.
    public var displayFactor: Double {
        switch self {
        case .scaleX, .scaleY, .opacity: 100
        case .x, .y, .anchorX, .anchorY, .rotation: 1
        }
    }

    /// The unit `InspectorSliderRow` shows after the value.
    public var unit: String {
        switch self {
        case .x, .y, .anchorX, .anchorY: " px"
        case .scaleX, .scaleY, .opacity: "%"
        case .rotation: "°"
        }
    }

    /// Places shown: one for pixels, whole for percent and degrees
    /// (docs/design.md, Editor shell).
    public var decimals: Int {
        switch self {
        case .x, .y, .anchorX, .anchorY: 1
        case .scaleX, .scaleY, .opacity, .rotation: 0
        }
    }

    /// The value as the row shows it and VoiceOver reads it: "960.0 px",
    /// "100%", "45°"; "–" for a value that isn't finite.
    public func text(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        let shown = value * displayFactor
        if decimals == 0 { return "\(Int(shown.rounded()))\(unit)" }
        return "\((shown * 10).rounded() / 10)\(unit)"
    }
}

/// Whether a property is animated, and whether a key sits at the playhead.
/// HaloApp maps it one to one onto SuiteUI's `KeyState`.
public enum HaloKeyState: Sendable, Hashable {
    /// No track, or a track with one key: the value is that key's.
    case notAnimated
    /// Two or more keys, none at the playhead.
    case animated
    /// Two or more keys and one at the playhead.
    case keyedHere
}

/// One inspector row: a property of the selected layer at the playhead.
public struct HaloPropertyRow: Identifiable, Sendable, Hashable {
    public var id: HaloProperty { property }
    public var property: HaloProperty
    public var value: Double
    public var text: String
    public var keyState: HaloKeyState
    public init(property: HaloProperty, value: Double, text: String, keyState: HaloKeyState) {
        self.property = property; self.value = value; self.text = text; self.keyState = keyState
    }
}

/// One key: which layer, which property, which frame.
public struct HaloKeyRef: Hashable, Sendable, Codable {
    public var layerID: String
    public var property: HaloProperty
    public var frame: Int
    public init(layerID: String, property: HaloProperty, frame: Int) {
        self.layerID = layerID; self.property = property; self.frame = frame
    }
}

/// The easing presets the menu, the chips and the timeline diamonds name.
/// Each is FlareCore's own `Easing` value; a curve matching none is custom.
public enum HaloEasingPreset: String, CaseIterable, Sendable {
    case linear, easeIn, easeOut, easeInOut, hold

    public var title: String {
        switch self {
        case .linear: "Linear"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In and Out"
        case .hold: "Hold"
        }
    }

    public var easing: HaloEasing {
        switch self {
        case .linear: .linear
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInOut
        case .hold: .hold
        }
    }

    /// The preset `easing` equals; nil for a custom curve.
    public init?(_ easing: HaloEasing) {
        guard let match = Self.allCases.first(where: { $0.easing == easing }) else { return nil }
        self = match
    }
}

/// A text layer's words and size (tier 2, #430). Color is the layer's.
public struct HaloTextContent: Codable, Sendable, Hashable {
    public var string: String
    /// In composition pixels.
    public var fontSize: Double
    public init(string: String = "Text", fontSize: Double = 72) {
        self.string = string; self.fontSize = fontSize
    }
}

/// One layer as the viewer and the renderer draw it at a frame.
public struct HaloDrawItem: Sendable, Hashable {
    public var layerID: String
    public var kind: HaloLayerKind
    /// The layer's own box in layer space: a solid's rectangle (the whole
    /// composition when it has none), a shape's ellipse box, a text's line box.
    public var bounds: HaloLayerRect
    /// Layer space to composition space, parents included.
    public var matrix: HaloMatrix
    /// 0...1, the layer's own sampled opacity (parents don't pass it on).
    public var opacity: Double
    public var color: HaloLayerColor
    public var blendMode: BlendMode
    /// The words of a text layer; nil otherwise.
    public var text: HaloTextContent?
    public init(
        layerID: String, kind: HaloLayerKind, bounds: HaloLayerRect, matrix: HaloMatrix, opacity: Double,
        color: HaloLayerColor, blendMode: BlendMode, text: HaloTextContent? = nil
    ) {
        self.layerID = layerID; self.kind = kind; self.bounds = bounds; self.matrix = matrix
        self.opacity = opacity; self.color = color; self.blendMode = blendMode; self.text = text
    }
}

/// What one frame of a composition draws, bottom layer first. Nulls and
/// layers outside their in and out points are absent.
public struct HaloDrawList: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var frame: Int
    public var items: [HaloDrawItem]
    public init(width: Int, height: Int, frame: Int, items: [HaloDrawItem]) {
        self.width = width; self.height = height; self.frame = frame; self.items = items
    }

    /// The list with one layer moved by `delta` composition pixels: the live
    /// preview of a viewer drag before mouse-up. Other layers are untouched.
    public func offsetting(_ layerID: String, by delta: HaloPoint) -> HaloDrawList {
        var copy = self
        for i in copy.items.indices where copy.items[i].layerID == layerID {
            copy.items[i].matrix = HaloMatrix.translation(x: delta.x, y: delta.y) * copy.items[i].matrix
        }
        return copy
    }
}

/// The document part of a project: what undo restores and a file holds.
/// Selection rides along so undo puts it back; the playhead lives in each
/// composition and is restored with it.
public struct HaloDocumentState: Codable, Sendable, Hashable {
    public var compositions: [HaloComposition]
    public var selectedCompositionID: String?
    public var selectedLayerID: String?
    /// The number in the next composition id; only goes up.
    public var nextCompositionNumber: Int
    public init(
        compositions: [HaloComposition] = [], selectedCompositionID: String? = nil, selectedLayerID: String? = nil,
        nextCompositionNumber: Int = 1
    ) {
        self.compositions = compositions; self.selectedCompositionID = selectedCompositionID
        self.selectedLayerID = selectedLayerID; self.nextCompositionNumber = nextCompositionNumber
    }
}

/// One undo step: its name ("New Layer") and the document before it.
public struct HaloHistoryEntry: Sendable, Hashable {
    public var name: String
    public var before: HaloDocumentState
    /// Steps with the same non-nil key in a row share one entry (a scrub).
    public var coalesceKey: String?
    public init(name: String, before: HaloDocumentState, coalesceKey: String? = nil) {
        self.name = name; self.before = before; self.coalesceKey = coalesceKey
    }
}

/// Undo and redo stacks, newest last. Only a `ProjectHistory` changes them.
public struct HaloHistory: Sendable, Hashable {
    public var undo: [HaloHistoryEntry]
    public var redo: [HaloHistoryEntry]
    public init(undo: [HaloHistoryEntry] = [], redo: [HaloHistoryEntry] = []) {
        self.undo = undo; self.redo = redo
    }
    /// "Undo New Layer"; nil when there is nothing to undo.
    public var undoTitle: String? { undo.last.map { "Undo \($0.name)" } }
    /// "Redo New Layer"; nil when there is nothing to redo.
    public var redoTitle: String? { redo.last.map { "Redo \($0.name)" } }
}

/// Where playback is after a tick.
public struct HaloPlaybackTick: Sendable, Hashable {
    public var frame: Int
    /// True once play-once has shown the last frame; the window stops then.
    public var ended: Bool
    public init(frame: Int, ended: Bool) { self.frame = frame; self.ended = ended }
}

/// What Render… writes (tier 2, #429).
public struct HaloRenderSettings: Sendable, Hashable {
    public enum Format: String, CaseIterable, Sendable { case pngSequence, movie }
    public var format: Format
    /// Half size halves width and height, rounded down to even.
    public var halfSize: Bool
    public init(format: Format, halfSize: Bool = false) { self.format = format; self.halfSize = halfSize }
}

/// The frames one render writes and what each is called.
public struct HaloRenderPlan: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var framesPerSecond: Int
    /// Composition frames in order, 0 through the last.
    public var frames: [Int]
    /// "Intro_0001.png" for each frame of a PNG sequence; one "Intro.mp4" for a movie.
    public var fileNames: [String]
    public init(width: Int, height: Int, framesPerSecond: Int, frames: [Int], fileNames: [String]) {
        self.width = width; self.height = height; self.framesPerSecond = framesPerSecond
        self.frames = frames; self.fileNames = fileNames
    }
}

/// How a render ended.
public enum HaloRenderOutcome: Sendable, Hashable {
    case finished(frames: Int)
    /// Stopped by Cancel after writing `frames` frames.
    case cancelled(frames: Int)
    case failed(frame: Int, message: String)
}

/// Why an edit was refused. `message` is the text the window shows.
public enum HaloEditError: Error, Sendable, Hashable {
    case noComposition
    case unknownLayer(String)
    case notANumber(HaloProperty)
    case parentCycle(String)
    case noKeySelected
    case notBuilt(String)

    public var message: String {
        switch self {
        case .noComposition: "Create a composition first."
        case .unknownLayer: "That layer no longer exists."
        case .notANumber(let p): "\(p.title) needs a number."
        case .parentCycle(let name): "\(name) can't follow a layer that follows it."
        case .noKeySelected: "Select a key on the timeline first."
        case .notBuilt(let what): "\(what) isn't built yet."
        }
    }
}

/// Why a project file didn't open. The open project stays as it was.
public enum HaloFileError: Error, Sendable, Hashable {
    case notAHaloFile
    case newerVersion(Int)
    case damaged(String)
    case tooLarge

    public var message: String {
        switch self {
        case .notAHaloFile: "This file isn't a Halo project."
        case .newerVersion(let v): "This project was saved by a newer Halo (format \(v)). Update Halo to open it."
        case .damaged(let detail): "This project is damaged: \(detail)."
        case .tooLarge: "This project is larger than Halo can open (64 MB)."
        }
    }
}
```

### 5.2 The protocols (`Contracts/HaloContracts.swift`)

```swift
// Contracts/HaloContracts.swift: one protocol per Halo use case, so the
// views (on the fakes) and the logic (the live types) are built in parallel.
// Reads take values; writes take the composition `inout` and throw
// `HaloEditError`, leaving it unchanged when they throw. None of them records
// undo: HaloProject wraps each write in `edit(_:coalesceKey:_:)`, which hands
// the state before it to `ProjectHistory`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// What every service shares: whether its controls can act yet.
public protocol HaloService: Sendable {
    /// Nil once the use case works; otherwise the tooltip of every control
    /// that needs it, which stays disabled (CLAUDE.md, no dead controls).
    var unavailableHelp: String? { get }
}

extension HaloService {
    public var unavailableHelp: String? { nil }
}

/// #37: the viewer's picture of a composition at a frame.
public protocol FrameDrawing: HaloService {
    /// Every layer visible at `frame`, bottom first, at its sampled transform
    /// through its parents. Nulls never appear; a layer in a parent cycle
    /// draws as if it had no parent.
    func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList
}

/// #38: where a layer is at a frame, through its parents.
public protocol LayerPlacing: HaloService {
    /// The property's value at `frame`: its track sampled with FlareCore's
    /// `Timeline.value(of:at:)`, or the layer's default with no track. Nil for
    /// an unknown layer.
    func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double?
    /// Layer space to composition space, parents applied outermost last. Nil
    /// for an unknown layer.
    func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix?
    /// The layers `layerID` may follow: every other layer except those that
    /// already follow it, in timeline order.
    func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String]
}

/// #38: the inspector's TRANSFORM rows, the stopwatch and the key diamond.
public protocol PropertyKeying: HaloService {
    /// One row per property in `HaloProperty.allCases` order; empty for an
    /// unknown layer.
    func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow]
    /// Not animated: sets the one value (key at frame 0, or the static value).
    /// Animated: writes a key at `frame`. NaN or infinity throws
    /// `.notANumber`; other values clamp to `property.range`.
    func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition) throws
    /// The stopwatch. Off to on: keys at `frame` and at the last frame with
    /// the current value (so the row turns animated). On to off: drops the
    /// track and keeps the value at `frame`.
    func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws
    /// The diamond: adds a key at `frame` with the sampled value, or removes
    /// the one there. A track left with one key is not animated.
    func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws
    /// Parent picker. Nil clears it. A cycle throws `.parentCycle`. The child
    /// keeps its place on screen at `frame` (its position is rewritten in the
    /// parent's space).
    func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws
}

/// #207: drag a layer in the viewer to key its position.
public protocol ViewerDragging: HaloService {
    /// The topmost layer under `point` (composition pixels) that draws at
    /// `frame`. Nulls are never hit; nil over empty space.
    func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String?
    /// Mouse-up: moves the layer by `delta` in composition pixels, writing
    /// its x and y through `PropertyKeying`'s rule (keys when animated). A
    /// zero delta changes nothing and does not throw.
    func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition) throws
}

/// #428: ease keys.
public protocol KeyEasing: HaloService {
    /// Every key of the layer, by property then frame: the timeline's diamonds.
    func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef]
    /// The easing from `key` to the next key; nil when the key doesn't exist.
    func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing?
    /// Sets `easing` on every key in `keys`. Empty throws `.noKeySelected`;
    /// a key that doesn't exist throws `.unknownLayer` and changes nothing.
    func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws
}

/// #208: undo and redo of whole-document steps.
public protocol ProjectHistory: HaloService {
    /// How many steps undo keeps; the oldest drops past it.
    var limit: Int { get }
    /// Adds a step named `name` whose undo returns `before`, and clears redo.
    /// With a non-nil `coalesceKey` equal to the newest step's, the newest
    /// step keeps its own `before` and nothing is added.
    func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory)
    /// The state to return to, moving the step onto redo with `current`.
    /// Nil when there is nothing to undo.
    func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState?
    /// The state to go forward to, moving the step back onto undo. Nil when
    /// there is nothing to redo.
    func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState?
}

/// #209: the project file.
public protocol ProjectFiles: HaloService {
    /// JSON with sorted keys and `"format": "halo"`, `"version": 1`.
    func encode(_ state: HaloDocumentState) throws -> Data
    /// Checks everything `encode` promises (unique composition ids and
    /// names, in point before out point, sizes and rates in range, sorted
    /// unique keys, no parent cycle) and throws `HaloFileError` otherwise.
    func decode(_ data: Data) throws -> HaloDocumentState
}

/// #37: which frame to show while playing.
public protocol PlaybackClock: HaloService {
    /// The frame `elapsed` seconds after play began on `startFrame`. Loop
    /// wraps to 0; play-once stops on the last frame with `ended` true.
    func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool) -> HaloPlaybackTick
}

/// #451, #430: a frame as pixels (CoreRaster), the reference the viewer and
/// every rendered file must match.
public protocol FrameRendering: HaloService {
    /// Renders `list` at 1/`scale` size (1 = full). `text` draws text layers;
    /// with nil they are skipped and counted in `skippedLayerCount`.
    func render(_ list: HaloDrawList, scale: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame
}

/// #430: words to pixels. HaloApp supplies the CoreText one; tests use a fake.
public protocol TextRasterizing: Sendable {
    /// The text in `color` on a transparent buffer just big enough for it,
    /// linear light, premultiplied; its (0, 0) is the line box's top left.
    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer
}

/// #429: where rendered frames go. HaloApp supplies the PNG and movie writers.
public protocol RenderSink {
    mutating func begin(_ plan: HaloRenderPlan) throws
    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws
    /// Called once, after the last frame or on cancel (`cancelled` true),
    /// when the sink removes a partly written movie.
    mutating func finish(cancelled: Bool) throws
}

/// #429: render a whole composition to files.
public protocol CompositionRendering: HaloService {
    /// The frames and names for `settings`. Throws `.noComposition` for a
    /// composition with no frames.
    func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan
    /// Sends every planned frame to `sink` in order, checking `isCancelled`
    /// before each one. A sink error stops at that frame.
    func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, into sink: inout some RenderSink,
        isCancelled: () -> Bool
    ) -> HaloRenderOutcome
}
```

### 5.3 Defaults shared by fake and live (`HaloLayerDefaults.swift`)

```swift
// HaloLayerDefaults.swift (W0): a layer's own box and the value each
// property has with no track, shared by the fakes and the live types so
// they agree. The defaults put the anchor and the position at the box's
// center, so an unkeyed layer's world matrix is the identity. Linux-safe.

extension HaloLayer {
    /// The layer's box in layer space (composition pixels, top-left origin).
    public func bounds(in composition: HaloComposition) -> HaloLayerRect {
        let w = Double(composition.width), h = Double(composition.height)
        switch kind {
        case .solid: return rect ?? HaloLayerRect(x: 0, y: 0, width: w, height: h)
        case .shape: return rect ?? HaloLayerRect(x: w / 2 - 100, y: h / 2 - 100, width: 200, height: 200)
        case .text:
            let content = text ?? HaloTextContent()
            let width = content.fontSize * 0.6 * Double(max(content.string.count, 1))
            return HaloLayerRect(x: w / 2 - width / 2, y: h / 2 - content.fontSize / 2, width: width, height: content.fontSize)
        case .null: return HaloLayerRect(x: w / 2, y: h / 2, width: 0, height: 0)
        }
    }

    /// The value `property` has when the layer has no track for it.
    public func defaultValue(_ property: HaloProperty, in composition: HaloComposition) -> Double {
        let box = bounds(in: composition)
        switch property {
        case .x, .anchorX: return box.x + box.width / 2
        case .y, .anchorY: return box.y + box.height / 2
        case .scaleX, .scaleY: return 1
        case .rotation: return 0
        case .opacity: return opacity
        }
    }
}
```

### 5.4 Wiring (`HaloServices.swift`) and the W0 live stubs

```swift
// HaloServices.swift (W0): one existential per Halo contract. HaloProject
// takes it at init; `.fake` runs the views on fakes, `.live` is what the app
// ships. W0 fills `.live` with `HaloNotBuilt`, which says why for every
// control; each feature swaps its own live type in by editing only its own
// Live/<Name>.swift file, because W0 already names `LiveFrameDrawing` and the
// rest here as typealiases of `HaloNotBuilt`.
public struct HaloServices: Sendable {
    public var drawing: any FrameDrawing
    public var placing: any LayerPlacing
    public var keying: any PropertyKeying
    public var dragging: any ViewerDragging
    public var easing: any KeyEasing
    public var history: any ProjectHistory
    public var files: any ProjectFiles
    public var clock: any PlaybackClock
    public var rendering: any FrameRendering
    public var compositionRendering: any CompositionRendering

    public init(
        drawing: any FrameDrawing, placing: any LayerPlacing, keying: any PropertyKeying,
        dragging: any ViewerDragging, easing: any KeyEasing, history: any ProjectHistory, files: any ProjectFiles,
        clock: any PlaybackClock, rendering: any FrameRendering, compositionRendering: any CompositionRendering
    ) {
        self.drawing = drawing; self.placing = placing; self.keying = keying; self.dragging = dragging
        self.easing = easing; self.history = history; self.files = files; self.clock = clock
        self.rendering = rendering; self.compositionRendering = compositionRendering
    }

    public static let fake = HaloServices(
        drawing: FakeFrameDrawing(), placing: FakeLayerPlacing(), keying: FakePropertyKeying(),
        dragging: FakeViewerDragging(), easing: FakeKeyEasing(), history: FakeProjectHistory(),
        files: FakeProjectFiles(), clock: FakePlaybackClock(), rendering: FakeFrameRendering(),
        compositionRendering: FakeCompositionRendering())

    public static let live = HaloServices(
        drawing: LiveFrameDrawing(), placing: LiveLayerPlacing(), keying: LivePropertyKeying(),
        dragging: LiveViewerDragging(), easing: LiveKeyEasing(), history: LiveProjectHistory(),
        files: LiveProjectFiles(), clock: LivePlaybackClock(), rendering: LiveFrameRendering(),
        compositionRendering: LiveCompositionRendering())
}
```

Each live stub (one shown; all ten are in `contracts/LiveStubs.swift`):

```swift
public struct LivePropertyKeying: PropertyKeying {
    public init() {}
    public var unavailableHelp: String? { "Keys arrive with the layer inspector (#38)." }
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] { [] }
    public func setValue(_ value: Double, for property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func toggleAnimation(_ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func toggleKey(_ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func setParent(_ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Parenting")
    }
}
```

### 5.5 The fakes (`Fakes/`)

```swift
// Fakes/HaloFakes.swift: a small, predictable conformance of every Halo
// contract, so HaloApp's views, snapshots and journeys run before the live
// types land. Fakes ignore parenting and draw text as a box; everything else
// follows the contract's doc comment. Linux-safe. Never used by `.live`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import FlareCore

public struct FakeLayerPlacing: LayerPlacing {
    public init() {}
    public func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return nil }
        if let track = layer.tracks[property.rawValue], let v = Timeline.value(of: track, at: Double(frame)) { return v }
        return layer.defaultValue(property, in: composition)
    }
    public func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? {
        func v(_ p: HaloProperty) -> Double { value(p, of: layerID, in: composition, at: frame) ?? 0 }
        guard composition.layers.contains(where: { $0.id == layerID }) else { return nil }
        return HaloMatrix.translation(x: v(.x), y: v(.y)) * HaloMatrix.rotation(degrees: v(.rotation))
            * HaloMatrix.scale(x: v(.scaleX), y: v(.scaleY)) * HaloMatrix.translation(x: -v(.anchorX), y: -v(.anchorY))
    }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] {
        composition.layers.map(\.id).filter { $0 != layerID }
    }
}

public struct FakeFrameDrawing: FrameDrawing {
    public init() {}
    public func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        let placing = FakeLayerPlacing()
        let items = composition.layers.reversed().filter { $0.kind != .null && $0.isVisible(at: frame) }.map { layer in
            HaloDrawItem(
                layerID: layer.id, kind: layer.kind, bounds: layer.bounds(in: composition),
                matrix: placing.worldMatrix(of: layer.id, in: composition, at: frame) ?? .identity,
                opacity: placing.value(.opacity, of: layer.id, in: composition, at: frame) ?? 1,
                color: layer.color, blendMode: layer.blendMode, text: layer.text)
        }
        return HaloDrawList(width: composition.width, height: composition.height, frame: frame, items: items)
    }
}

public struct FakePropertyKeying: PropertyKeying {
    public init() {}
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return [] }
        let placing = FakeLayerPlacing()
        return HaloProperty.allCases.map { p in
            let value = placing.value(p, of: layerID, in: composition, at: frame) ?? 0
            let track = layer.tracks[p.rawValue] ?? []
            let state: HaloKeyState =
                track.count < 2 ? .notAnimated : track.contains { $0.frame == frame } ? .keyedHere : .animated
            return HaloPropertyRow(property: p, value: value, text: p.text(value), keyState: state)
        }
    }
    public func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition
    ) throws {
        guard value.isFinite else { throw HaloEditError.notANumber(property) }
        let v = min(max(value, property.range.lowerBound), property.range.upperBound)
        try change(layerID, in: &composition) { layer in
            let track = layer.tracks[property.rawValue] ?? []
            if track.count >= 2 { layer.tracks[property.rawValue] = Self.keyed(track, frame: frame, value: v) }
            else if property == .opacity, track.isEmpty { layer.opacity = v }
            else { layer.tracks[property.rawValue] = [HaloKeyframe(frame: track.first?.frame ?? 0, value: v)] }
        }
    }
    public func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) ?? 0
        let last = composition.lastFrame
        try change(layerID, in: &composition) { layer in
            let track = layer.tracks[property.rawValue] ?? []
            if track.count >= 2 { layer.tracks[property.rawValue] = [HaloKeyframe(frame: 0, value: v)] }
            else { layer.tracks[property.rawValue] = Self.keyed(Self.keyed([], frame: frame, value: v), frame: frame == last ? 0 : last, value: v) }
        }
    }
    public func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) ?? 0
        try change(layerID, in: &composition) { layer in
            var track = layer.tracks[property.rawValue] ?? []
            if track.contains(where: { $0.frame == frame }) { track.removeAll { $0.frame == frame } }
            else { track = Self.keyed(track, frame: frame, value: v) }
            layer.tracks[property.rawValue] = track
        }
    }
    public func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        if let parentID, parentID == layerID { throw HaloEditError.parentCycle(layerID) }
        try change(layerID, in: &composition) { $0.parentID = parentID }
    }

    /// `track` with a key at `frame` set to `value`, kept sorted.
    static func keyed(_ track: [HaloKeyframe], frame: Int, value: Double) -> [HaloKeyframe] {
        var t = track.filter { $0.frame != frame }
        t.append(HaloKeyframe(frame: frame, value: value, easing: track.first { $0.frame == frame }?.easing ?? .linear))
        return t.sorted { $0.frame < $1.frame }
    }

    func change(_ layerID: String, in composition: inout HaloComposition, _ body: (inout HaloLayer) -> Void) throws {
        guard let i = composition.layers.firstIndex(where: { $0.id == layerID }) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        body(&composition.layers[i])
    }
}

public struct FakeViewerDragging: ViewerDragging {
    public init() {}
    public func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? {
        for item in FakeFrameDrawing().drawList(composition, at: frame).items.reversed() {
            guard let local = try? item.matrix.inverted().apply(point) else { continue }
            let b = item.bounds
            if local.x >= b.x, local.x <= b.x + b.width, local.y >= b.y, local.y <= b.y + b.height { return item.layerID }
        }
        return nil
    }
    public func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard delta.x != 0 || delta.y != 0 else { return }
        let placing = FakeLayerPlacing(), keying = FakePropertyKeying()
        guard let x = placing.value(.x, of: layerID, in: composition, at: frame),
            let y = placing.value(.y, of: layerID, in: composition, at: frame)
        else { throw HaloEditError.unknownLayer(layerID) }
        var copy = composition
        try keying.setValue(x + delta.x, for: .x, of: layerID, at: frame, in: &copy)
        try keying.setValue(y + delta.y, for: .y, of: layerID, at: frame, in: &copy)
        composition = copy
    }
}

public struct FakeKeyEasing: KeyEasing {
    public init() {}
    public func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef] {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return [] }
        return HaloProperty.allCases.flatMap { p in
            (layer.tracks[p.rawValue] ?? []).map { HaloKeyRef(layerID: layerID, property: p, frame: $0.frame) }
        }
    }
    public func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing? {
        composition.layers.first { $0.id == key.layerID }?.tracks[key.property.rawValue]?.first { $0.frame == key.frame }?.easing
    }
    public func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws {
        guard !keys.isEmpty else { throw HaloEditError.noKeySelected }
        var copy = composition
        for key in keys {
            guard let l = copy.layers.firstIndex(where: { $0.id == key.layerID }),
                let k = copy.layers[l].tracks[key.property.rawValue]?.firstIndex(where: { $0.frame == key.frame })
            else { throw HaloEditError.unknownLayer(key.layerID) }
            copy.layers[l].tracks[key.property.rawValue]?[k].easing = easing
        }
        composition = copy
    }
}

public struct FakeProjectHistory: ProjectHistory {
    public let limit = 100
    public init() {}
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {
        if let coalesceKey, history.undo.last?.coalesceKey == coalesceKey { return }
        history.undo.append(HaloHistoryEntry(name: name, before: before, coalesceKey: coalesceKey))
        if history.undo.count > limit { history.undo.removeFirst() }
        history.redo = []
    }
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        guard let step = history.undo.popLast() else { return nil }
        history.redo.append(HaloHistoryEntry(name: step.name, before: current))
        return step.before
    }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        guard let step = history.redo.popLast() else { return nil }
        history.undo.append(HaloHistoryEntry(name: step.name, before: current))
        return step.before
    }
}

public struct FakeProjectFiles: ProjectFiles {
    public init() {}
    public func encode(_ state: HaloDocumentState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }
    public func decode(_ data: Data) throws -> HaloDocumentState {
        do { return try JSONDecoder().decode(HaloDocumentState.self, from: data) } catch {
            throw HaloFileError.notAHaloFile
        }
    }
}

public struct FakePlaybackClock: PlaybackClock {
    public init() {}
    public func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        guard durationFrames > 0, framesPerSecond > 0, elapsed.isFinite, elapsed > 0 else {
            return HaloPlaybackTick(frame: max(0, min(startFrame, durationFrames - 1)), ended: false)
        }
        let ahead = Int(min(elapsed * Double(framesPerSecond), 1e9))
        let raw = startFrame + ahead
        if loops { return HaloPlaybackTick(frame: raw % durationFrames, ended: false) }
        return raw >= durationFrames - 1
            ? HaloPlaybackTick(frame: durationFrames - 1, ended: true) : HaloPlaybackTick(frame: raw, ended: false)
    }
}

/// Fills the frame with the top item's color: enough for the viewer to show
/// "a rendered frame" and for render loops to count frames.
public struct FakeFrameRendering: FrameRendering {
    public init() {}
    public func render(_ list: HaloDrawList, scale: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        let s = max(scale, 1)
        let top = list.items.last.map { RGBA(r: Float($0.color.red), g: Float($0.color.green), b: Float($0.color.blue), a: 1) }
        let pixels = try PixelBuffer(width: max(1, list.width / s), height: max(1, list.height / s), fill: top ?? .clear)
        let skipped = text == nil ? list.items.filter { $0.kind == .text }.count : 0
        return HaloRenderedFrame(pixels: pixels, frame: list.frame, skippedLayerCount: skipped)
    }
}

public struct FakeTextRasterizer: TextRasterizing {
    public init() {}
    public func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        let w = max(1, Int(text.fontSize * 0.6 * Double(max(text.string.count, 1))))
        return try PixelBuffer(
            width: w, height: max(1, Int(text.fontSize)),
            fill: RGBA(r: Float(color.red), g: Float(color.green), b: Float(color.blue), a: 1))
    }
}

public struct FakeCompositionRendering: CompositionRendering {
    public init() {}
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        guard composition.durationFrames > 0 else { throw HaloEditError.noComposition }
        let even = { (n: Int) in max(2, n / 2 / 2 * 2) }
        let w = settings.halfSize ? even(composition.width) : composition.width
        let h = settings.halfSize ? even(composition.height) : composition.height
        let frames = Array(0..<composition.durationFrames)
        let names: [String] = switch settings.format {
        case .movie: ["\(composition.name).mp4"]
        case .pngSequence: frames.map { f in
            let n = String(f + 1)
            return "\(composition.name)_\(String(repeating: "0", count: max(0, 4 - n.count)))\(n).png"
        }
        }
        return HaloRenderPlan(width: w, height: h, framesPerSecond: composition.framesPerSecond, frames: frames, fileNames: names)
    }
    public func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, into sink: inout some RenderSink,
        isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        do { try sink.begin(plan) } catch { return .failed(frame: 0, message: "\(error)") }
        for (i, frame) in plan.frames.enumerated() {
            if isCancelled() {
                try? sink.finish(cancelled: true)
                return .cancelled(frames: i)
            }
            do {
                let list = FakeFrameDrawing().drawList(composition, at: frame)
                let image = try FakeFrameRendering().render(list, scale: 1, text: nil)
                let name = plan.fileNames.count == plan.frames.count ? plan.fileNames[i] : plan.fileNames.first ?? ""
                try sink.write(image, named: name)
            } catch {
                try? sink.finish(cancelled: true)
                return .failed(frame: frame, message: "\(error)")
            }
        }
        do { try sink.finish(cancelled: false) } catch { return .failed(frame: plan.frames.last ?? 0, message: "\(error)") }
        return .finished(frames: plan.frames.count)
    }
}
```

### 5.6 The proof tests (`contracts/Tests/HaloContractTests.swift`)

```swift
import Testing
import HaloModel

@Suite struct HaloContractTests {
    func keyed() -> HaloComposition {
        var solid = HaloLayer(
            id: "s", name: "Solid 1", kind: .solid, inFrame: 0, outFrame: 60,
            color: HaloLayerColor(red: 1, green: 0, blue: 0), rect: HaloLayerRect(x: 0, y: 0, width: 100, height: 100))
        solid.tracks["x"] = [HaloKeyframe(frame: 0, value: 50), HaloKeyframe(frame: 30, value: 150)]
        let null = HaloLayer(id: "n", name: "Null 1", kind: .null, inFrame: 0, outFrame: 60, color: HaloLayerColor(red: 0, green: 0, blue: 0))
        return HaloComposition(id: "c", name: "Intro", width: 400, height: 200, framesPerSecond: 24, durationFrames: 60, layers: [null, solid])
    }

    @Test func fakeDrawListSkipsNullsAndInterpolates() {
        let list = FakeFrameDrawing().drawList(keyed(), at: 15)
        #expect(list.items.map(\.layerID) == ["s"])
        #expect(FakeLayerPlacing().value(.x, of: "s", in: keyed(), at: 15) == 100)
    }

    @Test func fakeEaseInBendsTheCurve() throws {
        var comp = keyed()
        try FakeKeyEasing().setEasing(.easeIn, on: [HaloKeyRef(layerID: "s", property: .x, frame: 0)], in: &comp)
        #expect((FakeLayerPlacing().value(.x, of: "s", in: comp, at: 15) ?? 0) < 100)
        #expect(HaloEasingPreset(FakeKeyEasing().easing(of: HaloKeyRef(layerID: "s", property: .x, frame: 0), in: comp) ?? .linear) == .easeIn)
    }

    @Test func fakeDragKeysAnimatedPosition() throws {
        var comp = keyed()
        #expect(FakeViewerDragging().hit(comp, at: 0, point: HaloPoint(x: 50, y: 50)) == "s")
        try FakeViewerDragging().commitMove("s", by: HaloPoint(x: 10, y: 0), at: 15, in: &comp)
        #expect(comp.layers[1].tracks["x"]?.map(\.frame) == [0, 15, 30])
    }

    @Test func fakeHistoryCoalescesAndUndoes() {
        let history = FakeProjectHistory()
        var h = HaloHistory()
        let a = HaloDocumentState(), b = HaloDocumentState(nextCompositionNumber: 2)
        history.record("Change Rotation", before: a, coalesceKey: "rot", in: &h)
        history.record("Change Rotation", before: b, coalesceKey: "rot", in: &h)
        #expect(h.undo.count == 1)
        #expect(h.undoTitle == "Undo Change Rotation")
        #expect(history.undo(b, in: &h) == a)
        #expect(h.redoTitle == "Redo Change Rotation")
    }

    @Test func fakeFilesRoundTrip() throws {
        let state = HaloDocumentState(compositions: [keyed()], selectedCompositionID: "c", nextCompositionNumber: 2)
        let files = FakeProjectFiles()
        #expect(try files.decode(files.encode(state)) == state)
    }

    @Test func fakeRenderRunsEveryFrame() throws {
        struct Count: RenderSink {
            var names: [String] = []
            var finished = false
            mutating func begin(_ plan: HaloRenderPlan) throws {}
            mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws { names.append(fileName) }
            mutating func finish(cancelled: Bool) throws { finished = !cancelled }
        }
        let r = FakeCompositionRendering()
        let plan = try r.plan(keyed(), settings: HaloRenderSettings(format: .pngSequence))
        var sink = Count()
        #expect(r.run(plan, of: keyed(), into: &sink, isCancelled: { false }) == .finished(frames: 60))
        #expect(sink.names.first == "Intro_0001.png" && sink.names.last == "Intro_0060.png")
    }

    @Test func liveStubsSayWhy() {
        #expect(HaloServices.live.drawing.unavailableHelp != nil)
        #expect(HaloServices.fake.drawing.unavailableHelp == nil)
        #expect(FakePlaybackClock().tick(startFrame: 50, elapsed: 1, framesPerSecond: 24, durationFrames: 60, loops: true).frame == 14)
    }
}
```


---

## 6. Look

Halo adds no new visual language. It is a `SuiteWindow` app (`docs/design.md`,
Window structure) whose inspector uses the Studio rows and chips of Flare's
easing editor, the house reference: `StudioScrubRow` and
`InspectorSliderRow` bars, `KeyframeButton`, `ChoiceChips`, `CurveEditor`,
`InspectorPickerRow`, `InspectorColorRow`, small-caps group headers. Colors
mean what they mean everywhere: accent is selected or active,
`SuiteColor.keyframed` (amber) is a key, the recording ring is unused (Halo
has no auto-key in v1).

### What Halo adds to `docs/design.md`

To be added to `docs/design.md` by W0's last task (one short "Halo" subsection
under Canvas apps), not by this blueprint, since other architects edit that
file in parallel:

1. **Viewer.** The artboard is drawn by `CanvasSurface`; layers paint in one
   SwiftUI `Canvas` inside it, flat (content, no glass). The selected layer
   shows `SelectionOutline` around its world bounds' axis-aligned box. While
   a rendered frame is shown it replaces the vector drawing inside the same
   artboard, with a small note under the status bar when it is stale.
2. **Transport** sits on the status row under the viewer, left of the
   pills: `TransportCapsule` (#340) with go to start, step back, play/pause,
   step forward, go to end and a loop toggle. Timecode in `SuiteFont.timecode`
   ("00:00:01:12" primary, " / 10 s at 30 fps" secondary).
3. **Timeline lanes** follow the Visual language's Timeline rules: one lane
   per layer with its span bar (the clip block, slate blue, radius `lane`),
   key diamonds on it (idle `textSecondary`, selected `accent`, at the
   playhead `stateKeyed`), easing shown by the diamond's shape (#428:
   diamond linear, rounded eased, square hold; needs SuiteUI, below).
4. **Inspector order** for a selected layer: header (layer name; kind, span,
   parent), TRANSFORM (Position X, Position Y, Scale X, Scale Y, Rotation,
   Opacity, Anchor X, Anchor Y, each a bar with its `KeyframeButton`), LAYER
   (Parent, Blend), EASING (the selected layer's key segments, chips, curve),
   TEXT for a text layer. With no layer selected: the composition header and
   rows, then the layer list.
5. **Numbers** show their unit and places from `HaloProperty` (`unit`,
   `decimals`, `displayFactor`): "960.0 px", "100%", "45°".

### Screens and their components

Components are SuiteUI unless named `Halo*`. "Needs" lists a SuiteUI gap
(existing issue, or one to file as `needs-ui` on `line:suiteui`); the Halo
view uses the placeholder named until it lands.

| Screen / region | Contents | Uses | Needs (placeholder meanwhile) |
|---|---|---|---|
| Window | Compositions sidebar, viewer content, inspector | `SuiteWindow`, `SidebarSection`, `SidebarItem`, `SidebarRow` (rename), `ToolbarAction` | #577 rename message on the row, for #139 (the alert stays meanwhile) |
| Viewer empty | "No Composition", New Composition… | `EmptyStateView` | – |
| Viewer | Artboard, layers, selection, drag, rendered frame | `CanvasSurface`, `SelectionOutline`, `HaloViewerCanvas` (a SwiftUI `Canvas`) | a rotated selection box with handles (#273 moves Design's handles into SuiteUI; v1 uses the axis-aligned `SelectionOutline`); an anchor-point mark (#706; v1 draws none) |
| Status row | Zoom, size, layer count pills; timecode; transport | `ViewerStatusBar` | `TransportCapsule` (#340; meanwhile plain `Button`s with SF Symbols in an `HStack` inside the status bar's trailing slot) |
| Timeline | Lanes, spans, diamonds, playhead, scrub, key select | `TimelineStrip`, `TimelineTrack` | key shape by easing and a selected-keys set (Flare S10/S11, not filed: file `needs-ui`; meanwhile plain diamonds and selection shown in the inspector's EASING rows); keyboard and VoiceOver for keys (#63); diamonds on a selected span (#62) |
| Inspector, composition | Header, Size, Frame Rate, Duration rows, layer list | `InspectorHeader`, `InspectorSection`, `InspectorRow`, `SidebarRow` in a system `List` (reorder with `.onMove`, rename) | – |
| Inspector, TRANSFORM | 8 bars, each with stopwatch and diamond | `InspectorSliderRow` (unit, decimals, `keyed:`), `KeyframeButton` | values read empty in XCUITest (#262): journeys read the row's `accessibilityValue` from `HaloPropertyRow.text`, set by the Halo view |
| Inspector, LAYER | Parent, Blend | `InspectorPickerRow` | – |
| Inspector, EASING | Key segment rows ("Position X 0 → 24"), preset chips, curve, four numbers | `ChoiceChips`, `CurveEditor`, `StudioScrubRow`, group header text style (as `FlareEasingInspector`) | – |
| Inspector, TEXT | Text field, size bar, color | `TextField` (system), `InspectorSliderRow`, `InspectorColorRow` | – |
| New Composition sheet | Name, width, height, rate, duration, problems, Create | system `Form`, `TextField`, `Picker` | – (#286 adds `.accessibilityLabel`s in the Halo view) |
| Render sheet | Format (PNG sequence, Movie), size (Full, Half), destination, Render; progress row "Frame 48 of 240" with Cancel; success with Reveal in Finder; failure with the frame and reason | system `Form`, `Picker(.segmented)`, `ProgressView`, `Button` | – |
| Alerts | Open and save failures, close with unsaved changes | system `.alert` | – |
| Menus | File: New Composition…, Open… ⌘O, Open Recent, Save ⌘S, Save As… ⇧⌘S, Render… ⇧⌘R, Render Frame ⌘R. Edit: Undo <step> ⌘Z, Redo <step> ⇧⌘Z, plus the system items. Composition: New ⌥⌘N, Duplicate ⌘D, Delete ⌘⌫. Layer: New ▸ (Solid, Shape, Text, Null), Duplicate ⇧⌘D, Rename, Delete ⌫, Bring Forward ⌘], Send Backward ⌘[. Animation: Play/Pause, Loop, Next Frame, Previous Frame, Go to Start, Go to End, Set In Point, Set Out Point, Keyframe Easing ▸ (the five presets). Space, →, ←, Home, End, I and O act while the viewer or the timeline has focus (`onKeyPress`, as the timeline's I and O do today) and the menu items show them in their help, not as key equivalents, so typing in a field never plays or sets a point. Every item works or is disabled with `unavailableHelp(for:)` | `CommandMenu`, `CommandGroup(replacing: .undoRedo)`, `CommandGroup(replacing: .newItem)` | – |

`Duplicate` is ⌘D for compositions today (shipped). Layer > Duplicate takes
⇧⌘D so the two don't collide; section 9 asks the captain whether ⌘D should
follow the focus instead.

### Snapshots and goldens this adds

Each feature adds its PNGs (`<app>-<state>-<light|dark>.png`) in its own
`Tests/AppSnapshotTests/Halo<Area>Snapshots.swift`, and its goldens once
QH-2 (#331) and QH-2b (#332) land: `halo-viewer-three-layers`,
`halo-viewer-keyed-frame-12`, `halo-playback-transport`,
`halo-inspector-transform-keyed`, `halo-inspector-easing`,
`halo-timeline-keys`, `halo-layer-list`, `halo-render-sheet-progress`,
`halo-text-layer`, `halo-opened-project` (names follow the open issues where
they already name one).

---

## 7. Quality bar

Every item names where it is measured and the test that measures it. "Gate"
means a test fails over the number; "report-only" means the test records the
number and fails only on too few samples, until ten green CI runs set the
gate at the measured CI p95 × 1.5, never tighter than the device target
(`docs/review-rubric.md`, How gates are set). A gate never loosens without
the captain.

### 7.1 Input-to-screen speed budgets

Two halves for each interactive tool. The **Model half** is the work between
the input event and a value the view can draw: measured on Linux and macOS
by budget tests in HaloModelTests (median and p95 over 200 runs on the
named fixture; debug CI gates carry the rubric's ×10). `HaloBudgetTests.<name>`
below names a test, not one file: W0 adds the shared timing helper
`Tests/HaloModelTests/HaloBudget.swift`, and each feature writes its rows
in its own `Tests/HaloModelTests/Halo<Feature>BudgetTests.swift`, so no two
features share a budget file. The **UI
half** is input to the first display refresh that shows it, in frames late,
measured by the frame probe (SuiteUI QH-1, #330) in the perf journeys
H-P1 to H-P4. Until #330 lands, `Tests/AppSnapshotTests/HaloViewerLatencyTests.swift`
(macOS, like `PhotoBrushLatencyTests`) times the Model plus SwiftUI path of
each tool and writes one `HALO-LATENCY` line to
`.build/snapshots/halo-latency.txt`, which the contact sheet shows.

| id | Tool | What is timed | Fixture | Device target | CI gate | Test | Status |
|---|---|---|---|---|---|---|---|
| HB-1 | Viewer drag (key position) | one `moveViewerDrag(to:)` plus `viewerDrawList` | `reference` | ≤ 1 ms | ≤ 10 ms debug | `HaloBudgetTests.viewerDragStep` | gate from its first PR (layer-keys) |
| HB-2 | Viewer redraw | `FrameDrawing.drawList` for one frame | `reference` | ≤ 2 ms | ≤ 20 ms debug | `HaloBudgetTests.drawList` | gate (viewer-playback) |
| HB-3 | Viewer hit | `ViewerDragging.hit` per pointer move | `reference` | ≤ 1 ms | ≤ 10 ms debug | `HaloBudgetTests.hit` | gate (layer-keys) |
| HB-4 | Inspector bar scrub | one `setProperty(_:to:)` (with `edit`'s copy and coalesced record) plus `propertyRows` | `reference` | ≤ 1 ms | ≤ 10 ms debug | `HaloBudgetTests.inspectorScrubStep` | gate (layer-keys) |
| HB-5 | Playhead scrub | `scrub(to:)` plus `timelineRows` plus `viewerDrawList` | `reference` | ≤ 3 ms | ≤ 30 ms debug | `HaloBudgetTests.playheadScrubStep` | gate (viewer-playback) |
| HB-6 | Timeline with many layers | `timelineRows` | `crowd` | ≤ 5 ms | ≤ 50 ms debug | `HaloBudgetTests.timelineRowsCrowd` (QB-L10's model half) | gate (W0, extends `HaloTimelineCostTests`) |
| HB-7 | Easing chip | `setEasing` on two keys plus `keySegments` | `reference` | ≤ 1 ms | ≤ 10 ms debug | `HaloBudgetTests.easingStep` | gate (easing) |
| HB-8 | Undo, Redo | one `undo()` or `redo()` | `crowd` | ≤ 2 ms | ≤ 20 ms debug | `HaloBudgetTests.undoStep` | gate (history-files) |
| HB-9 | Any edit | `edit`'s copy, compare and record | `crowd` | ≤ 2 ms | ≤ 20 ms debug | `HaloBudgetTests.editRecord` | gate (W0) |
| HB-10 | Save, Open | `fileData()`; `open(_:)` | `crowd` | ≤ 50 ms each | ≤ 500 ms debug | `HaloBudgetTests.saveCrowd`, `.openCrowd` | gate (history-files) |
| HB-11 | Playback tick | `tick(now:)` plus `viewerDrawList` | `reference` | ≤ 2 ms | ≤ 20 ms debug | `HaloBudgetTests.playbackTick` | gate (viewer-playback) |
| HB-12 | Render Frame (⌘R) | `FrameRendering.render` at preview scale (480 × 270) | `reference` | ≤ 50 ms release | report-only | `HaloBudgetTests.renderPreview` | report-only (render-out) |
| HB-13 | Render… | 48 frames at 1920 × 1080 into a counting sink | `keyed` | < 5 s release | report-only, then < 10 s | `HaloBudgetTests.renderSequence` | report-only (render-out) |
| HB-U1 | Viewer drag on screen | input to refresh | `reference` | p95 ≤ 2 frames late (QB-L1) | set from CI (placeholder 3) | H-P1 | report-only until #330 |
| HB-U2 | Inspector bar on screen | input to refresh | `reference` | p95 ≤ 2 frames late (QB-L2) | set from CI (placeholder 3) | H-P2 | report-only until #330 |
| HB-U3 | Playhead on screen | input to refresh | `reference` | p95 ≤ 2 frames late (QB-L3) | set from CI (placeholder 3) | H-P3 | report-only until #330 |
| HB-U4 | Playback | 5 s at 30 fps | `reference` | 0 dropped, tick jitter p95 < 2 ms (QB-L4) | ≤ 2 dropped in 5 s | H-P4 | report-only until #330 |
| HB-U5 | Open, Render… | command to progress shown | `crowd` file; `keyed` render | ≤ 100 ms (QB-L9) | set from CI (placeholder 200 ms) | the probe's progress mark in H-J10 and H-J21 | report-only until #330 |

### 7.2 App-audit checks that apply

All six checks of `docs/blueprints/app-audit.md` run on every Halo shot:
`disabled-dim`, `overlap`, `contrast`, `identifier`, `offscreen`, `unnamed`.
Halo's baseline today is contrast 2, identifier 10, offscreen 8, unnamed 5.

| Check | Today | v1 target | How it gets there | Measured by |
|---|---|---|---|---|
| `unnamed` | 5 | 0 | #286 (W0): the sheet's fields get `.accessibilityLabel` | `audit-halo-*.json`, CI's Audit lower |
| `identifier` | 10 | ≤ 3 (the SuiteUI chrome left to SuiteUI) | #290 (W0) for Halo's own views; every new Halo control ships with a `halo.*` identifier (review rubric) | same |
| `offscreen` | 8 | 0 | the layout spec below at 1024 × 768 (the runner's display) | same, plus L1 |
| `contrast` | 2 | 0 | SuiteUI #283 and #284 (sidebar headers, card text) | same |
| `overlap`, `disabled-dim` | 0 | 0 | the status row's transport and pills (L5); every disabled item from `unavailableHelp` is drawn by the system or SuiteUI | same |

Rule for every Halo feature: no count goes up (the audit fails the journeys
if one does), and its PR body states the counts it expects.

### 7.3 Layout spec

Checked at window sizes **minimum** (`SuiteSize.windowMinimum`), **1024 ×
768** (the CI runner's display), **1280 × 800**, **1440 × 900** and **1920 ×
1080**, through `-HaloWindowSize`, with the `keyed` fixture and a layer
selected.

| id | Rule | Tolerance | Measured by |
|---|---|---|---|
| L1 | Nothing off the window, no two enabled controls overlapping | the audit's own (1 pt slack, 2 pt overlap) | `testLayoutAtWidths` (`+Layout`, W0): relaunch at each size, shoot `halo-layout-<w>`; the audit runs on each shot |
| L2 | The artboard is centered in the viewer and keeps its aspect | centers within 1 pt; aspect within 0.5% | same journey: frames of `halo.viewer` and `halo.viewer.artboard`; Linux half: `CanvasLayout`/fit math unchanged |
| L3 | The playhead sits on its frame: lane origin + frame × frame width | ≤ 1 pt at frames 0, last / 2, last | `HaloLayoutTests` (macOS, AppSnapshotTests) hosting `HaloTimelineView` at 600, 900 and 1400 pt; Linux half: `frameWidth(toFit:)` tests |
| L4 | Inspector rows align: every TRANSFORM bar starts and ends at the same x; keyframe buttons in one column; labels never truncate | ≤ 0.5 pt | `HaloLayoutTests` hosting `HaloLayerInspector` at the inspector's minimum, ideal and maximum widths |
| L5 | Status row: transport left, pills right, never overlapping; the timecode never truncates | 0 pt overlap | `HaloLayoutTests` hosting the status row at the content minimum width |
| L6 | At the minimum window size the artboard is at least 160 pt wide and every inspector row is reachable by scrolling | ≥ 160 pt | `testLayoutAtWidths` at minimum |

### 7.4 Fidelity tests (output equals a reference)

| id | Output | Reference | Tolerance | Test (where) |
|---|---|---|---|---|
| HF-1 | The viewer's drawing of `keyed` at frame 12, at full composition size | `FrameRendering.render(scale: 1)` of the same draw list | channel ≤ 2/255, ≤ 0.5% of pixels differ (QB-V2, QB-V4) | `HaloViewerFidelityTests` (macOS, viewer-playback) |
| HF-2 | `LiveFrameRendering` of a 40 × 20 test composition: a 50% red solid in Multiply over blue, and a solid rotated 45° | pixel values written in the test from the W3C formulas [S3]; coverage 1 at the rotated solid's center, 0 at a far corner, strictly between on its edge | exact for the blend values (`Float` equality after CoreRaster's math); edge strictly in (0, 1) | `LiveFrameRenderingTests` (Linux, viewer-playback) |
| HF-3 | `LayerPlacing.value` for every property and frame of `reference` | FlareCore `Timeline.value(of:at:)` on the same track | exact | `LayerPlacingContractTests` (Linux, layer-keys) |
| HF-4 | Position X at frames 6, 12, 18 for each easing preset on `keyed` | `160 + 800 × Easing.value(at: f / 24)` | exact; Hold equals 160 until frame 24 | `HaloEasingTests` (Linux, easing) |
| HF-5 | World matrix of a three-deep parent chain; a layer's screen position before and after `setParent` | the matrices multiplied by hand in the test | 1e-9; 1e-6 | `LayerPlacingContractTests`, `PropertyKeyingContractTests` (Linux, layer-keys) |
| HF-6 | `fileData()` of every fixture | itself after a decode and encode | byte for byte; and the decoded project equals the original | `ProjectFilesContractTests` (Linux, history-files) |
| HF-7 | Frame n of a PNG sequence, decoded | `render(scale: 1)` of frame n as `rgba8` | exact bytes | `HaloPNGWriterTests` (macOS, render-out) |
| HF-8 | The H.264 movie | the plan | frame count and duration exact; frame 0 within 4/255 of HF-7's PNG on ≥ 99% of pixels (H.264 is lossy) | `HaloMovieWriterTests` (macOS, render-out) |
| HF-9 | Timecode of frames at 24, 25, 30 and 60 fps | the SMPTE-style table in the test [S5] | exact | `HaloTimelineTests` (exists) |
| HF-10 | A rendered text layer's ink bounds | the viewer's text bounds for the same layer | ≤ 1 px at full size (QB-V4) | `HaloTextLayerTests` (Linux with the fake rasterizer for placement), `HaloTextFidelityTests` (macOS with CoreText) (text-layers) |

### 7.5 Feel (rubric section 6)

| id | How Halo meets it | Measured by |
|---|---|---|
| QB-F1 No dead controls | every command's availability is `unavailableHelp(for:)` | `HaloCommandTests` (Linux, W0: on `.live` today every command is disabled with a reason; on `.fake` with `keyed` every command but those needing a selection is enabled); H-J13 |
| QB-F2 Immediate feedback | drag preview before mouse-up; refusals shown under the row that refused | the probe's preview mark (H-P1); H-J3, H-J6 asserts |
| QB-F3 One gesture, one named step | `edit` and its names (section 2) | Model tests count `history.undo` after each gesture; journeys read the Edit menu |
| QB-F4 Keyboard parity | bars step with arrows (Shift ×10, Option ×0.1); Space, ←, →, Home, End, I, O on the viewer and timeline | H-J4, H-J6 |
| QB-F5 Reduce Motion, Increase Contrast | playback is content, not an animation; the curve's preview dot hides (SuiteUI); goldens in Increase Contrast once #332 lands | goldens |
| QB-F6 Geometry holds | only SuiteUI components and tokens | design lint; L4 |
