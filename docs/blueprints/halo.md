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
