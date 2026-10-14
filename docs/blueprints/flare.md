# Flare blueprint

Flare is the suite's 2D vector animation app. You draw on a stage, key
properties on a timeline, ease them, reuse drawings as symbols, wire simple
interactive state machines, and export SVG, Lottie and PNG sequences. This
blueprint is the gate before any code. It covers scope, architecture, every
screen, every journey, a feature coverage matrix, the use-case contracts, and
the task list for the two parallel tracks and the integration after them.

Sources read through git refs on 2026-10-13: creative-core `origin/main`
08e0b88 (FlareCore), creative-apps `origin/main` d1e57a3 (FlareApp,
FlareModel, SuiteUI, docs), the suite design doc (Flare section and phased
plan), and our web Studio editor for the look. The look itself is the
"Visual language" section of `docs/design.md`. The quality rows and budgets
(every `QB-` id below) are section 6 of `docs/review-rubric.md`.

Where Flare is today: a shell. You can make an empty animation and manage
layers in a sidebar. All four tools are disabled, nothing draws on the stage,
and there is no timeline, playback, file I/O, inspector or menu bar. FlareCore
underneath is much further along: 41 undoable commands, timeline sampling,
easing, symbols, state machines, and SVG and Lottie export. So the risk is the
drawing feel and the UI, not the model, which is why every feature below
carries a quality bar and the test that measures it.

Contents: 0 Status on dev · 1 Scope · 2 Architecture · 3 Screens · 4 Journeys · 5 Coverage
matrix · 6 Contracts · 7 Tasks · 8 Order · 9 Decisions · 10 Still open

---

## 0. Status on dev (2026-10-14)

Read on `origin/dev` e823592 (checked again at 65e2707) and creative-core `main` cfad97f (the revision
`Package.swift` resolves). The rest of this blueprint is the plan as approved
at G0; this section says how far dev has got and where names moved.

**Shipped.** The LM-0 chain up to LM-0c2 (#314–#323, plus the splits #473
LM-0a2c, #547 LM-0a3b and #605 LM-0c2b), LM-1 (#356, open, save data, file
name and dirty flag only), LM-6 `LiveEasing` (#359), LM-7 playback (#360) and
LM-15 `MachineLayout` (#327), LM-0c3 fake export, the shared warnings
scan and fixture `showcase` (#324, in #747), LA-2 `PlaybackDriver` with a
Linux-tested `PlaybackTicker` in `FlarePlaybackTicks.swift` (#372, in #751),
and about 60 follow-up fixes (#603–#710:
editing in place, locked layers, playback edge cases, plain refusal text).
`FlareServices.fake` holds every fake except `assist`, still `NotBuilt`; `FlareServices.live` is all `NotBuilt`. On the UI side nothing of
section 7.3 has started: the window is still `SuiteWindow` with the sidebar
and the easing inspector (`FlareApp.swift`, `FlareCommands.swift`,
`FlareEasingInspector.swift`, `FlareLayerItems.swift`). SuiteUI already has
`KeyframeButton`, `PresetGrid`, `ChipRow`, `InspectorAction`, `CurveEditor`,
`CanvasMarks`, `EditorShell` and `EditorTopBar`; S7 (#340), S9 (#342), S12
(#273), S13 (#343), QH-2 (#331), QH-2b (#332) and QH-4 (#333) are still open.

**Names that moved.**

- `StageHitTesting` takes `editing symbolID:` (#641); section 6.2 now shows it.
- `ExportState`, `AssistState` and `LoadState` live in
  `Sources/FlareModel/FlareWorkspaceState.swift`, not in `FlareExport.swift`
  and `FlareAssist.swift`; `FlareExport.swift` holds the workspace's export
  methods (LM-0c3), and `FlareAssist.swift` will hold assist's (LM-0c4).
- The display-link tick math is in the Model: `PlaybackTicker` and
  `FlareWorkspace.tick(target:ticker:)` in `FlarePlaybackTicks.swift`;
  `Sources/FlareApp/PlaybackDriver.swift` only owns the link.
- The Ellipse tool works on the workspace itself in
  `Sources/FlareModel/FlareDrawing.swift`, a stopgap until LC-4's
  ellipse builder in `PathBuilders.swift` (qbtrix/creative-core#182). Machine refusal text sits in
  `FlareMachineMessages.swift`.
- The per-key easing protocol is `KeyframeEasing`; `EasingEditing` stays the
  window-level editor (see `flare-issues.md`).

**Closed but not finished.** #356 (LM-1) closed without the Open Recent list
and the autosave due time (`FlareFiles.swift` says they follow later), and
#206 (LM-3) closed with the Ellipse stopgap but no `LiveShapes`. Both are
needed by p1 work (LA-3 and IN-1), so the feature packets carry them as new
tasks (#739, #740).

**The engine.** creative-core `main` has none of LC-1–LC-10 yet: no render
list, topmost hit, world bounds, path builders, `owner:` on keyframe
commands, `SetShapeStroke`, `SetShapePath`, `DuplicateLayer`, scene rename,
reorder or canvas commands, onion frames, or `SetKeyframe` and `MoveGuide`
merges. Every live conformance except `LiveEasing` waits on them.

**What is left, as feature packets.** The open p1 logic work is grouped into
four features in `docs/blueprints/flare/features/` (`waves.md` gives the
order): wave 1 `mac-platform` (#370, #373, #739), which waits on nothing;
wave 2, as their engine issues land, `live-stage` (#357, #740), `live-keys`
(#13, #358) and `live-scenes` (#362).

**Later features (UI and integrate, not in a packet yet).** The Flare UI on
fakes: F1a #346, F1b #347, F3c #375, F5 #391, F6b #348, F6c #349, F7b #376,
F8 #377, F9 #378, F11a #350, F11b #351, F17b #392, F17c #393, F18 #384, and
the older issues that now carry F tasks (#11, #12, #15, #186, #203, #204,
#205). The p1 integrate tasks IN-1 #397, IN-2 #385, IN-4 #398 and IN-9 #399
wait on that UI and on gate G2.

---

## 1. Scope

### MVP (v1)

The suite design's Flare MVP, made concrete.

| Area | In v1 |
|---|---|
| Files | New from a preset (1080p 16:9, square, 9:16, 550x400 web, custom); open and save `.flare`; Open Recent; autosave to a recovery file with a restore offer after a crash; the title shows the file name; an unsaved dot; undo and redo named for the step. One document per window: New and Open act in the front window after the unsaved-changes prompt |
| Stage | Draws the scene at the current frame with curves kept as curves; zoom (pinch, menu, fit, 100%); pan (Space-drag, scroll); rulers; guides dragged out of the rulers, moved and removed; Retina-sharp |
| Tools | Select (V): click, Shift-click, marquee, move, and the eight scale handles and the rotate zone. Direct Select (A): pick a path's anchors and handles and drag them. Rectangle (R) with corner radius, Ellipse (E), Pen (P): click for corners, drag for smooth points, close on the first point |
| Edit | Delete, Cut, Copy, Paste, Duplicate of layers (Paste lands above the selection, offset by 10 pt), Select All, Deselect, Bring Forward, Send Backward |
| Inspector | File-name title, info card, TRANSFORM (X, Y, scale X and Y, rotation, opacity) as bar sliders with keyframe buttons, FILL (solid editing; a gradient shows as a read-only gradient swatch), STROKE (color, width, cap, join), INSTANCE (symbol, loop mode, first frame) for an instance, SCENE when nothing is selected. A multi-selection shows "Mixed" for values that differ |
| Timeline | One lane per layer, key diamonds, playhead with a time pill, scrub, retime keys by drag, delete keys, insert and remove frames, frame labels, timecode and frame readout |
| Animate | Auto-key (record) mode, keyframe buttons per property, motion tweens with easing presets and a custom cubic-bezier curve editor, hold keys |
| Onion skin | Before and after ghosts with tints, counts and falloff; the motion path as a dotted line with frame ticks |
| Playback | Play, pause, loop, step a frame, jump to start and end, held at the scene's frame rate on a display-link clock; an actual-fps pill that turns the warning color when frames drop |
| Scenes | Add, rename, remove, reorder, switch; canvas size, background, fps and duration |
| Library | Symbols with usage counts; Convert to Symbol, place an instance, edit a symbol in place with a breadcrumb, rename, delete when unused. Swatches: add the current fill as a swatch, apply one, remove one |
| Interact | A state machine editor (machines added with a first state, rename and delete; states from frame ranges or labels; transitions with a trigger and conditions; bool and number inputs with defaults) with inline issues, and a live preview with a control per input |
| Export | SVG of the current frame, Lottie JSON (position, scale, rotation and opacity tracks), PNG sequence (range, step, 1x or 2x), with a named warning for anything not written. Nothing is dropped silently |
| Assist | "Animate this": a prompt becomes a list of registered commands, shown as a proposal in the AI-suggestion color, previewed, then accepted as one undo step or rejected. UI and contract ship in v1 on the fake; the live provider arrives with the suite's model provider (Phase 3) |
| Text in files | v1 has no text tool. A file or proposal that holds text still works: text items are not drawn, a "Text not shown (n)" warning pill appears, the items survive save untouched, and export skips them with a named warning. Assist proposals that add or edit text are rejected whole, with a reason |

### Later (v1.1 and after)

Video and GIF export; audio track and waveform (G50); shape tween (G48);
bones (G49); the text tool, text on the stage and text in SVG and Lottie;
masks and clipping; boolean and path ops; a graph (value over time) editor;
editing the motion path and follow-a-path; pencil with smoothing and a
variable-width brush; frame-by-frame polish (blank keyframes, exposure
holds); copy and paste of frames (G47); fps conversion (G53); asset import
(G51); layer parenting; group and ungroup inside a layer (in v1, a symbol is
the group); snapping to guides, edges and the pixel grid; an align and
distribute panel; play range (in and out points); gradient editing with
stops and on-canvas handles; dashed strokes; blend modes; state machine
listeners, blend states and runtime export; dragging machine nodes to
positions you choose; play across scenes; swap symbol; renaming swatches; a
version browser; the shared suite library.

If the pencil or brush ships later, its quality bar is already written
(QB-L1 and QB-V1) and it does not ship without it.

### Non-goals

Raster painting (Photo), compositing and effects (Halo), UI layout and
components (Design), a web runtime player, a scripting language or plugin
API, collaboration or cloud sync, an iPad build, and reading or writing any
closed file format.

### Calls made against the domain read

The domain read (public specs and common practice for 2D animation tools)
lists a must-ship cut. Where this blueprint differs, it says so here; the
captain settled the debatable ones in section 9.

| Item | Call | Why |
|---|---|---|
| Direct selection (anchor editing) | v1 | Without it a pen path can never be fixed after it is drawn |
| Cut, Copy, Paste, Duplicate | v1 | Expected on every Mac editor; DuplicateLayer is already planned in LC-7 |
| Autosave and crash recovery | v1, recovery file only (decision 4) | Losing work is worse than any missing feature |
| Open Recent | v1 | Small, and part of the file loop |
| Group and ungroup | Later | A symbol already groups art in v1 |
| Snapping and align | Later | Guides land in v1; snapping to them is the first Later item |
| Play range | Later | Loop over the whole scene covers v1 |
| Actual fps readout | v1 | It makes playback quality visible to the person, not only to tests |
| GIF export | Later (decision 10) | The suite doc's MVP lists SVG, Lottie and PNG sequence; the domain read lists GIF too |
| State machine editor and Assist | v1, after the core loop | The suite doc puts both in Flare's MVP. They come last in the order (section 8), so cutting them later costs nothing built before them |

---

## 2. Architecture

Three layers, unchanged from `docs/engineering.md`. SuiteUI sits beside the
app and knows no Model.

```
creative-core            creative-apps
FlareCore  ───────────▶  FlareModel  ─────────▶  FlareApp  ◀── SuiteUI
(engine, Linux)          (state + contracts,      (EditorShell window,
                          live + fake, Linux)      stage renderer, rasterizer,
                                                   display-link driver; macOS)
```

### FlareCore (creative-core, Linux-safe)

FlareCore owns the document, every edit as an undoable `Command`, timeline
sampling, easing, symbols, state machines, hit testing, bounds, the file
format and the SVG and Lottie exporters. Flare work adds the following, as
`needs-core` issues (task ids in section 7.4):

- `Scene.renderList(at:symbols:)` (G45): the ordered draw items that the
  stage, the rasterizer and the exporters all share. Today each exporter
  walks the scene on its own, so the stage would drift from export without it.
- A topmost-hit query that returns an address, marquee intersection, a
  zoom-aware tolerance, and world bounds that include strokes.
- Path builders: rectangle with corner radius, ellipse, polygon and star.
- The owner migration for keyframe commands (Q5c) and instance commands
  (Q5e, including `SetInstancePlayback`), `SetShapeStroke`, `SetShapePath`,
  `DuplicateLayer`, `SetSceneCanvas`, `RenameScene`, `ReorderScene`,
  `RenameSymbol`, onion frames (G46), a merge for `SetKeyframe` and
  `MoveGuide` drags, the state machine command family with a public issues
  query, a runtime player, and Lottie opacity, scale and rotation tracks (G52).

Coordinates: the stage uses the exporters' y-down scene space, so a positive
rotation shows clockwise on screen, exactly as it exports. The `Transform`
doc comment ("counter-clockwise in a y-up frame") gets a one-line fix in
LC-1, so nobody builds the stage against the wrong reading.

### FlareModel (creative-apps, Linux-safe, depends on FlareCore only)

**The workspace.** `FlareWorkspace` stays the one value-type state behind the
window (`Sendable`, `Equatable`). Task LM-0a3 adds, in one PR to
`FlareWorkspace.swift`, every stored property this blueprint needs, so no
later task edits that file:

| Stored property | Read by | Written by (extension file) |
|---|---|---|
| `services: FlareServices` | every extension | `init(services:)` |
| `selection: [StageAddress]`, `marquee: Rect?` | stage, inspector | `Sources/FlareModel/FlareSelection.swift` (LM-0a3) |
| `draft: ShapeDraft?`, `dragPreview: StageDrawList?` | stage overlay | `Sources/FlareModel/FlareDrag.swift` (LM-0a3) |
| `currentFrame: Int`, `isPlaying`, `loops`, `playClock: Double` | timeline, stage | `Sources/FlareModel/FlarePlayback.swift` (LM-7) |
| `autoKey: Bool` | inspector, stage | `Sources/FlareModel/FlareAnimate.swift` (LM-0b) |
| `onion: OnionSettings`, `showsMotionPath` | stage overlay | `Sources/FlareModel/FlareOnionState.swift` (LM-0b) |
| `editingSymbolID: String?` | every owner-aware call | `Sources/FlareModel/FlareSymbols.swift` (LM-0c1) |
| `machineID: String?`, `machinePreview: MachinePreview?`, `machineError: String?` | Interactions | `Sources/FlareModel/FlareMachines.swift` (LM-0c2) |
| `exportState: ExportState` | export sheet | `Sources/FlareModel/FlareExport.swift` (LM-0c3) |
| `assist: AssistState` (prompt, proposal, preview list, error) | Assist popover | `Sources/FlareModel/FlareAssist.swift` (LM-0c3) |
| `fileName: String?`, `isDirty`, `saveError: String?`, `loadState: LoadState` | top bar, alerts | `Sources/FlareModel/FlareFiles.swift` (LM-1) |
| `recent: [String]` | File menu | `Sources/FlareModel/FlareFiles.swift` (LM-1) |

LM-0a3 also changes the access rules so extensions in other files can do
their job: stored state becomes `public internal(set)` (the app still cannot
assign it, since FlareApp is another module, so the app-state lint and the
compiler still hold), `engine` becomes `internal`, and the private `step`
becomes `internal func step(_ label: String?, _ body:)`. With a label, `step`
runs the body inside `engine.group(label)`; that is only for workspace-level
compositions such as Cut (copy, then the contract's delete). Every other
group is opened by the contract conformance itself, so fake and live tests
count undo entries without a workspace. It also adds
`internal mutating func load(_ document: Document)`, which replaces the
engine with a fresh one (no history). Each later Model task owns only its
own extension file.

**One undo step, exactly.** `CommandEngine.group` resets `coalesceKey` and
ignores the key inside, so the two cases never mix:

- *Scrubs and drags of one value* (bar slider, key retime, easing handle,
  instance transform from the inspector, guide drag) perform one command per
  call at the top level with a non-nil `coalesceKey`, never inside a group.
  Consecutive calls with the same key share one undo entry (FlareCore's
  existing coalescing), and LC-10's merge keeps it to one command.
- *Stage gestures* (draw, move, scale, rotate, anchor drag) never perform a
  command while the pointer moves. They change only `draft` and
  `dragPreview`. On mouse-up the workspace calls the contract's commit once,
  and the conformance opens one group: "Add Rectangle", "Move", "Scale",
  "Rotate" or "Edit Path". One group, one entry, one name.
- *Other multi-command writes* (Convert to Symbol, Paste, Delete of several
  items) run in one group opened by the conformance: "Convert to Symbol",
  "Paste", "Delete". Assist accept is grouped "Assist" by the shared apply
  code, and Cut by the workspace (above).

Each write in section 6 says which case it is. LM-0a2 and LM-0b test it: 120
`setValues` calls with one key leave exactly one undo entry, and a fake
rectangle commit leaves exactly one entry, whose undo name is
"Undo Add Rectangle".

**Where a property's value lives.** FlareCore layers have no static
transform. `x`, `y`, `scaleX`, `scaleY`, `rotation` and `opacity` exist only
as tracks, with `Layer.standardDefaults` when a track is missing. The rule,
used by the fake and the live conformance alike:

- No track, or a track with exactly one key: **not animated**. The value is
  that key's value (or the default). Editing it with auto-key off sets that
  one key (creating it at frame 0 if there is none). The stopwatch is idle.
- Two or more keys: **animated**. Editing it at any frame writes a key at
  the playhead, whether auto-key is on or not, because the track is the only
  storage. The stopwatch is filled; the row shows "keyed here" when a key
  sits at the playhead.
- Auto-key on and the property not animated: an edit writes a key at the
  playhead and keeps any key at another frame, so an edit at a second frame
  makes the property animated.
- The stopwatch on a not-animated property adds a key at the playhead. If
  that still leaves one key (the playhead was on it), it also keys the
  scene's last frame with the same value, so the person sees two diamonds
  and the row turns animated. The stopwatch off keeps one key at frame 0
  holding the value at the playhead.

**Selection and transforms.** A shape has no transform of its own; transforms
belong to layers. So:

- Select (V) selects layers. A click hits the topmost item and selects its
  layer; the box shows that layer's world bounds. Move, the eight scale
  handles and the rotate zone write the layer's `x`, `y`, `scaleX`, `scaleY`
  and `rotation` by the rule above. A scale keeps the opposite handle fixed,
  and a rotation turns about the box center, by adjusting `x` and `y` in the
  same commit. With several layers selected, each layer changes about the
  shared box.
- Direct Select (A) selects items and anchors inside a layer. Dragging an
  item moves its geometry (`TranslateShape`, not animatable); dragging an
  anchor or handle edits the path (`SetShapePath`). Fill and Stroke act on
  the selected items.
- To animate one part separately, it goes on its own layer or into a symbol.
  The `character` fixture has each part on its own layer for this reason.

**Contracts.** One Swift protocol per use case (section 6), in
`Sources/FlareModel/Contracts/`. Signatures use FlareCore and Foundation types
only, never CoreGraphics or SwiftUI, so they build on Linux. Frames are `Int`
everywhere; a conformance converts with `Double(frame)` where FlareCore
samples. FlareCore's `Path`, `Color`, `Scene`, `Shape` and `Transition` collide with
SwiftUI names, so FlareModel adds `public typealias FlarePath =
FlareCore.Path` (and `FlareColor`, `FlareScene`, `FlareShape`, `FlareTransition`), and app
files use those names.

**`FlareServices`** is a struct with one existential per contract.
`FlareWorkspace(services:)` takes it. `.fake` and `.live` are its two values.
Integration is one line per use case in `.live`.

**Fakes** (`Sources/FlareModel/Fakes/`) run fixture documents through the
real FlareCore engine wherever FlareCore already does the job (layers, keys,
undo, files), with hand fakes only where the engine has nothing yet. A fake
that changes the document does it through `FixtureEdit`, a `Command` that
swaps in an edited copy of the document, so fake edits are validated and
undoable like real ones. `FixtureEdit` is never registered in the
`CommandRegistry`. FlareCore's undo stack is internal, so the check is a
source scan: `LiveConformanceTests.noFixtureEditInLive` reads every file
under `Sources/FlareModel/Live/` and fails on the string `FixtureEdit`.

**Engine-direct** (no protocol, because there would be one conformer): the
layers panel (already live), file decode and encode (`FlareFormat`), playback
timing (`Timeline.playbackFrame`), and the interactions graph layout
(`MachineLayout`, below). Fixture documents are their fake data.

**Interactions graph layout.** FlareCore's `MachineState` has no position,
and v1 adds none to the format. `MachineLayout.swift` (FlareModel, task
LM-15, Linux-tested) lays the graph out from the machine alone: columns by
breadth-first distance from the initial state, rows by state order within a
column, unreachable states in a last column, fixed node size and gaps. The
same machine always gives the same layout. Letting people drag nodes is
Later, with a position field added to the format then.

**Tool availability.** `FlareTool.unavailableHelp` is a static switch today.
LM-0a3 moves availability to `FlareWorkspace.toolHelp(_:) -> String?`, which
reads each tool's service (`services.shapes.unavailableHelp(for:)`), and
keeps `FlareTool.unavailableHelp` only as the fallback text.
`FlareToolsTests` changes in the same PR: it reads `toolHelp`, runs `drag`
then `endDrag` (a draw commits on mouse-up), and the fixture for the select
tool is `bounce`, so a select drag has something to move.

**Why not a separate contracts or fakes target:** `Package.swift` is
protected and every target already exists. FlareModel is Linux-safe and
tested, which is exactly where contracts and fakes belong.

### FlareApp (creative-apps, macOS)

- `FlareApp` uses `.windowStyle(.hiddenTitleBar)` and `FlareCommands`. It
  stays a `WindowGroup` (decision 4). Each window has its own model.
- `FlareWindow` owns the one `model` and presentation state (zoom, panel
  tab, popovers, file URL). Every control sends a `FlareIntent` to
  `FlareWindow.perform`. F1 writes `FlareIntent` with every case this
  blueprint lists, grouped by area (`.file`, `.edit`, `.stage`, `.timeline`,
  `.library`, `.interactions`, `.export`, `.assist`), and a router that hands
  each area to `FlareWindow+<Area>.swift`. F1 creates those area files as
  stubs whose `help(for:)` returns "Not built yet (Fn)". After that each
  area file belongs to exactly one F task, and no later task edits
  `FlareIntent.swift`, `FlareWindow.swift` or `FlareCommands.swift`.
- Launch arguments pick the data: `-FlareFixture <name>` (fake services plus
  a fixture document), `-FlareSample <name>` (the same fixture document on
  live services, for integrated journeys), `-FlareOpenFile <path>` (live, a
  real file), `-FlareSaveTo <folder>`, `-FlareExportTo <folder>`,
  `-FlareAssistMode ok|fail|timeout|empty` (fake assist only), and
  `-FlarePerfProbe` (exposes frame timings to journeys).
- Views: `FlareEditor` (the EditorShell), `FlareStage` (with
  `readOnly:` from its first PR), `FlareInspector`, `FlareLayersPanel`,
  `FlareLibraryPanel`, `FlareTimeline`, `FlareInteractions`,
  `FlareExportSheet`, `FlareAssistPopover`.
- `StagePath.swift`: FlareCore `Path` plus `Matrix` to `CGPath`, and document
  colors to `CGColor(srgbRed:green:blue:alpha:)`. It is the one conversion
  both the stage and the rasterizer use, so export matches the screen. The
  design lint bans `Color(red:` (which also matches `CGColor(red:`) and
  `NSColor(` in app files; `CGColor(srgbRed:` passes it. StagePath is a
  logic task (LA-0) with no SwiftUI.
- Other platform files, built by the logic track with no SwiftUI:
  `StageRasterizer.swift` (CoreGraphics, a draw list to PNG at a pixel
  scale) and `PlaybackDriver.swift` (a display link from
  `NSScreen.displayLink(target:selector:)` that calls `advance(elapsed:)`).
  `FlareWindow` picks the rasterizer: `FakeRasterizer` when the services are
  `.fake`, `StageRasterizer` otherwise. It passes it to `export` as an
  argument, so `FlareServices` has no rasterizer member.
- Opening a file reads and decodes in a detached task (`FlareFormat.decode`
  is pure and `Sendable`), so a 64 MB file never blocks the main thread. The
  workspace shows `loadState = .loading` and the window shows progress once
  100 ms have passed. Autosave writes the recovery file the same way, off the
  main thread, 30 s after the last edit and on quit.

### Rendering and feel (where "laggy" is designed out)

1. The Model turns the scene at the current frame into a `StageDrawList`.
   Committed layers draw in one SwiftUI `Canvas` under `.drawingGroup()`
   (offscreen, Metal-backed). The live draft, selection handles, the motion
   path and onion ghosts draw in a separate overlay `Canvas`. A pointer move
   redraws the overlay only.
2. A pointer move changes only `draft` or `dragPreview`. It never performs a
   command. The edit is committed once on mouse-up as one named group.
   Inspector scrubs coalesce with a key, and LC-10 makes `SetKeyframe` merge,
   so a long scrub stays one small command.
3. Curves stay curves end to end: `PathElement.cubic` becomes
   `CGPath.addCurve`, never a polyline. The canvas draws at the backing
   scale; handles are 1 device pixel lines aligned to the pixel grid.
4. If a frame takes longer than its budget, only the latest request is drawn
   (the Photo `CanvasRenderer` rule), so a fast drag never queues stale frames.
5. `FrameProbe` (SuiteUI) records input-to-display timings, plus the moments
   a drag preview first draws, a progress state first shows, and an
   animation ends. Journeys read them from `suite.perf` and attach them as a
   JSON artifact (rubric section 6).

### C4 deltas (proposed; each lands with the task named)

No new container or component: every new file sits under the existing
`Sources/FlareModel/` and `Sources/FlareApp/` path prefixes.

- creative-apps `flare-model` description, in LM-0a3: "FlareWorkspace
  (document, selection, tool, frame and playback, drafts) and FlareServices:
  the use-case contracts, their live conformances over FlareCore, and the
  fixture fakes the UI track and snapshots run on."
- creative-apps `flare-app` description, in F1: "The EditorShell window built
  from SuiteUI, the stage renderer and PNG rasterizer (CoreGraphics), and the
  display-link playback driver. Reads FlareModel and calls its methods."
- creative-apps `suiteui` description, in S16 (the last SuiteUI task): names
  the new components (keyframe button, bar slider, info card, preset grid,
  chips, transport, curve editor, node graph, layer list, frame probe).
- creative-core FlareCore description, in LC-1, LC-2 and LC-11b: adds
  "render list, hit and bounds queries, state machine commands and runtime".

---

## 3. Screen inventory

One window (with the Interactions editor as a mode of it), sheets and
popovers, and the menu bar.
Components are SuiteUI unless named `Flare*`.

### 3.1 Main window: `FlareEditor` on `EditorShell` (dark, hidden title bar)

| Region | What is in it | Components |
|---|---|---|
| Top bar (48 pt) | "Flare / <file name>" menu; New, Open, Save (outlined); Undo, Redo (icon); Auto-key toggle with the recording dot; Assist ("Animate…", sparkle); Export… (the one filled primary); save status (Saved, unsaved dot, "Not saved" in error color) | `EditorTopBar`, `EditorBarItem` (outlined), `EditorBarItem(.primary)`, `EditorBarMenu`, `EditorBarDivider` |
| Tool rail | Select V, Direct Select A, Rectangle R, Ellipse E, Pen P; each disabled with a reason until it works | `ToolbarGroup(style: .rail)` |
| Stage | Artboard at the scene size and background, rulers, guides, committed art, overlay (draft, selection box with 8 handles and a rotate zone, path anchors and handles, motion path, onion ghosts, marquee). Empty state when no document: New and Open | `CanvasViewport`, `SelectionHandles`, `PathMarks`, `MotionPathMarks`, `GhostLayer`, `EmptyStateView`, `FlareStage` |
| Under the stage | Transport capsule (start, step back, play/pause round blue, step forward, end, loop), timecode "00:12 / 02:00" and frame "12 / 48"; status pills (16:9, 1080p, 24 fps, actual fps while playing, zoom %, onion on), a "Text not shown (n)" warning pill when the document holds text, and a "Preview data" warning pill while fake services run | `TransportCapsule`, `ViewerStatusBar` (restyled into pills; the name stays) |
| Timeline (bottom slot) | Toolbar of toggle chips (onion skin, insert frame, remove frame, add label, zoom), ruler with labels, one lane per layer (name chip with eye and lock), key diamonds (idle, selected, at playhead, AI suggestion), easing segments, playhead with time pill, the recording ring when auto-key is on. Empty: "No layers yet. Draw on the stage to add one." | `EditorShell(timeline:)`, `TimelineStrip` (restyled), `ChipRow` |
| Right panel (280 pt) | Tabs Properties, Layers, Library | `SegmentedTabs` (capsule) |
| Properties tab | Title = selection name or file name; info card (Kind, Frame, Size, Keys); sections TRANSFORM, FILL, STROKE, INSTANCE (only for an instance), TIMING (easing dropdown row for the key under the playhead), each property a bar slider plus keyframe button; values that differ across a multi-selection read "Mixed" with no marker. Nothing selected = SCENE (size, background, fps, duration, presets grid) | `InspectorHeader` (info card), `InspectorSection`, `InspectorSliderRow` (bar), `KeyframeButton`, `InspectorPickerRow` (filled), `InspectorColorRow` (pill swatch), `PresetGrid`, `InspectorAction` |
| Layers tab | SCENES on top (rows, add, rename, remove, drag to reorder), then LAYERS of the selected scene (eye, lock, dimmed when hidden, drag to reorder, add, delete, rename) | `LayerList`, built on `SidebarRow` |
| Library tab | SYMBOLS (name, usage count, duration; place, rename, delete when unused; empty: "No symbols yet. Select art and choose Convert to Symbol."), SWATCHES (chips; click applies fill; a plus chip adds the current fill; context menu removes), Convert to Symbol action, breadcrumb "Scene 1 › Walk cycle" while editing a symbol | `LayerList` rows, `ChipRow`, `InspectorAction`, `FlareBreadcrumb`, `EmptyStateView` |
| Status line | Active tool, selection count, last message | inside the pills row |

While editing a symbol in place, the timeline shows the symbol's own layers
and duration, the playhead runs over the symbol's frames, play loops the
symbol, the stage dims everything outside the symbol, and the breadcrumb
leads back. Escape or the breadcrumb returns to the scene at the frame it
left.

### 3.2 Interactions editor (Window > Interactions, ⇧⌘M)

The Interactions editor replaces the stage and timeline inside the main
window while it is open; ⇧⌘M or Escape closes it. It is not a second
window, because a second window could not share the window's one model.

| Region | What | Components |
|---|---|---|
| Top bar | Machine menu (add, rename, delete), Preview toggle | `EditorTopBar` |
| Graph | States as rounded nodes (name, scene, frame range), placed by `MachineLayout`; transitions as arrows with condition chips; the initial state marked; the active state highlighted in preview; warnings on the node or arrow. Empty: "No interactions yet. Add a machine to make this animation respond to input." | `NodeGraph`, `EmptyStateView` |
| Inspector | State: name, scene, start and end frame (bar sliders) or a label; Transition: from, to, trigger, conditions (input, op, value); Inputs list with defaults, add and remove. A refused edit shows its reason inline in the error color under the row | `InspectorSection`, `InspectorPickerRow`, `InspectorSliderRow`, `ChipRow` |
| Preview | A read-only stage that plays the active state, plus a control per input (checkbox row for bool, bar slider for number, button for trigger) | `FlareStage(readOnly: true)`, `InspectorSliderRow`, toggle row |

### 3.3 Sheets, popovers and alerts

| Screen | Opened from | Contents |
|---|---|---|
| New Animation sheet | File > New ⌘N, empty state | Presets grid (1080p 16:9, Square 1080, Vertical 9:16, Web 550x400, Custom), width, height, fps (12, 24, 25, 30, 60), duration, background; Create (primary) |
| Export sheet | File > Export… ⇧⌘E, top bar Export | Format tabs (SVG frame, Lottie, PNG sequence); options (frame or range, step, scale 1x or 2x, transparent background); warnings list (warning color, triangle); progress with Cancel; "Replace existing files?" confirm when the folder already holds them; on success a success row with Reveal in Finder; on failure an error row with the reason and Try Again |
| Easing popover | Timeline segment, inspector TIMING row | Presets grid (Linear, Ease, Ease In, Ease Out, Ease In Out, Hold), the curve editor with two handles and a playing dot, four numbers |
| Onion skin popover | Timeline chip, View menu | On, before count, after count, falloff, tint chips before and after |
| Assist popover | Top bar Animate…, Animate menu | Prompt field, Generate, progress, proposal list (each command as a row in the AI color), Preview, Accept (one undo), Reject. Errors in place: "Assist didn't answer in 20 s. Try again.", "Assist had no suggestion for this.", the provider's message on failure, and the reason when a proposal is refused (unknown command, or text) |
| Open progress | Opening a large file | Progress row in the stage area after 100 ms; the window stays responsive |
| Recovery offer | Launch after a crash with a recovery file | "Restore the unsaved animation from <time>?" Restore, Discard |
| Alerts | Open failure (not a Flare file, damaged, newer version, too large), save failure, close with unsaved changes | System alert, message from the Model, never at launch |

Open failure messages, from `FormatError`: "This file isn't a Flare
animation." (`notAFlareFile`, `malformed`), "This file was made by a newer
Flare (format 2). Update Flare to open it." (`unsupportedVersion`), "This
file is larger than Flare can open (64 MB)." (`tooLarge`), "This file is
damaged: <detail>." (`invalid`). The document that was open stays open.

### 3.4 Menu bar (`FlareCommands`)

Every item works or is disabled with a reason, never hidden.

- **Flare**: About, Hide, Quit (no Settings window in v1).
- **File**: New ⌘N, Open… ⌘O, Open Recent, Open Sample (Bounce, Character, Button), Save ⌘S, Save As… ⇧⌘S, Export… ⇧⌘E, Close ⌘W.
- **Edit**: Undo <step> ⌘Z, Redo <step> ⇧⌘Z, Cut ⌘X, Copy ⌘C, Paste ⌘V, Duplicate ⌘D, Delete ⌫, Select All ⌘A, Deselect ⇧⌘A.
- **View**: Zoom In ⌘+, Zoom Out ⌘−, Fit ⌘0, Actual Size ⌘1, Onion Skin ⌥⌘O, Motion Path, Show Rulers ⌘R, Show Guides ⌘;, Clear Guides.
- **Object**: Convert to Symbol ⌥⌘K, Edit Symbol (Return on an instance), Exit Symbol (Escape); Bring Forward ⌘], Send Backward ⌘[.
- **Animate**: Play/Pause Space, Loop, Next Frame →, Previous Frame ←, Next Keyframe ⌥→, Previous Keyframe ⌥←, Go to Start Home, Go to End End, Add Keyframe K, Remove Keyframe ⇧K, Auto-Key ⌥K, Insert Frame ⌥=, Remove Frame ⌥−, Add Label, Easing (submenu of presets), Animate with Assist… ⌥⌘A.
- **Window**: Interactions ⇧⌘M (a toggle), then the system items.
- **Help**: system.

Context menus: stage item (Cut, Copy, Duplicate, Delete, Convert to Symbol,
Bring Forward, Send Backward), layer row (Rename, Hide, Lock, Duplicate,
Delete), scene row (Rename, Delete), timeline key (Easing submenu, Delete
Keyframe), symbol row (Place, Rename, Delete), swatch chip (Remove), guide
(Remove).

Disabled reasons for the edge cases: removing the last scene ("An animation
needs at least one scene."), deleting the last layer is allowed (the
timeline shows its empty state), placing an instance on a locked layer or
drawing on one ("Unlock <layer> to draw on it."), deleting a symbol in use
("<name> is used 3 times."), Paste with nothing Flare can read on the
pasteboard ("Nothing to paste.").

---

## 4. Journeys

**Files.** Today `project.yml`'s `Journey` template compiles exactly
`UITests/Journey.swift` plus `UITests/<target>.swift`, so every feature would
append to one file. Task QH-4 changes the template (project.yml is not a
protected path) to compile `UITests/Journey*.swift` plus
`UITests/<target>*.swift`. Each feature then owns its own file,
`UITests/FlareJourneyTests+<Area>.swift`, holding its own `XCTestCase`
class. QH-4's acceptance proves that a second file is picked up. QH-4 also
adds the shared helpers in `UITests/Journey+Input.swift`: keystrokes with
modifiers, a velocity-controlled drag
(`click(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`) with an
optional mid-point list, and `perf()`, which reads the `suite.perf` JSON and
attaches it to the test as `perf-<test>.json`.

**Modes.** Each journey runs first in fixture mode (`-FlareFixture <name>`,
UI track) and is flipped to live mode (`-FlareSample <name>`) by its
integrate task. Every step takes a `shot`. "Value" means the element's
accessibility value; every control and stage mark carries an identifier
`flare.<area>.<name>` (rule set in F1).

**Waiting.** No journey asserts "within one frame" through an XCUI query.
State changes are awaited with `waitForExistence` or a value predicate
(2 s timeout), and timing claims are read from the probe's JSON.

| # | Test (file, owner task) | Fixture | Steps (each shot) | Asserts |
|---|---|---|---|---|
| J0 | `testLaunchShowsEditorShell` (`FlareJourneyTests.swift`, F1) | none | launch; `clickEachTool()` | `expectEditorShell()`; empty state with New and Open; "Preview data" pill; each disabled tool listed in the tools shot. Replaces `testLaunchShowsWindowShell` and `testNewAnimationAndEveryTool`; the skipped `testDrawKeyAndSave` moves to J26 |
| J1 | `testEveryMenuOpens` (`+Menus`, F2) | bounce | open each menu | every menu shot; the item count of each menu equals section 3.4's list, so nothing is hidden |
| J2 | `testNewAnimationFromPreset` (`+NewSheet`, F11b) | none | ⌘N; pick "Vertical 9:16"; set 30 fps; Create | info card reads 1080 × 1920; pills read 9:16 and 30 fps |
| J3 | `testDrawShapesWithEachTool` (`+Draw`, F4a) | empty | timeline empty state; R drag; E drag with Shift; P click 3 corners and click the first to close; P click, drag at the second point, click a third, Return; ⌘Z | timeline empty text before the first draw; layers Rectangle 1, Ellipse 1 (equal width and height), Path 1, Path 2; Path 2's second anchor value is "smooth"; after ⌘Z the Edit menu reads "Redo Add Path" and Path 2 is gone; the probe reports a drag preview drawn before mouse-up for each draw |
| J4 | `testDirectSelectEditsAPath` (`+DirectSelect`, F4b) | empty | P draw a closed triangle; A; click the path; drag its second anchor 40 pt right; drag that anchor's handle with Option | anchor value x grew by 40 (±1); Edit menu reads "Undo Edit Path"; one ⌘Z restores the anchor; the shape's layer transform is unchanged |
| J5 | `testSelectMarqueeScaleRotate` (`+Select`, F3b) | bounce | V; click Ball; Shift-click Shadow; click empty stage; marquee around Ball and Shadow; click Ball; drag the bottom-right handle out by half the box; drag the rotate zone a quarter turn | 1 then 2 selected; inspector X reads "Mixed" with 2; 0 after the empty click; 2 after the marquee; scale X reads 1.50 (±0.02); rotation reads 90° (±1°); Edit menu reads "Undo Rotate" |
| J6 | `testMoveAndKeyByDrag` (`+Animate`, F5) | bounce | ⌥K (auto-key on); frame 24; drag Ball 100 pt right; frame 12; ⌥K off; frame 0; drag Shadow 50 pt right; frame 30 | recording ring exists while on; Ball X at frame 12 is the interpolated value; one ⌘Z removes only the new key; Shadow X moved by 50 at frame 0 and at frame 30 (not animated) and its keyframe button value is "Not animated" |
| J7 | `testInspectorKeysTransform` (`+Inspector`, F6a) | bounce | select Ball; click the Rotation keyframe button; frame 20; drag the Rotation bar; focus it and press → twice, then Shift-→ | button value "Animated", then "Keyed at this frame" at 20; a diamond on Ball's lane at 20; value steps +1, +1, then +10 |
| J8 | `testFillAndStroke` (`+FillStroke`, F6b) | bounce | select Ball; type `FF3B30` in the FILL hex field; STROKE width bar to 4; cap Round; join Round; ⌘Z | fill value reads FF3B30 and the stage shot differs; width reads 4.0 pt; cap and join read Round; ⌘Z restores only the join |
| J9 | `testTimelineScrub` (`+Timeline`, F7a) | bounce | drag the playhead to frame 30; Home; End; ⌥→; ⌥← | readout 30, then 0, then 47; next and previous keyframe land on Ball's key frames |
| J10 | `testPlayLoopAndStep` (`+Playback`, F7b) | bounce | frame 30; Space; wait 1 s; Space; → twice | play button value "Playing" while playing; the actual-fps pill exists while playing; after pause the frame f is not 30 (it moved); after the steps the frame is f + 2 (mod 48 with loop on) |
| J11 | `testRetimeDeleteInsertAndLabel` (`+TimelineEdit`, F8) | bounce | drag Ball's key at 24 to 28; select the key at 12 and press ⌫; frame 10, ⌥= twice; ⌥− once; frame 29, Add Label "hit" | key at 28 and Edit menu "Undo Move Keyframe"; key 12 gone; key 28 now at 30, then 29; label "hit" on the ruler at 29; each step is one ⌘Z |
| J12 | `testEasingPresetAndCurve` (`+Easing`, F9) | bounce | open easing on Ball's first segment; Ease Out; drag the first handle; focus the handle and press ↑ | TIMING row reads "Ease Out", then "Custom"; the four numbers change; each edit is one ⌘Z |
| J13 | `testOnionSkinAndMotionPath` (`+Onion`, F10) | bounce | ⌥⌘O; set before 3 and after 3; View > Motion Path | pill reads 3 + 3; 6 ghost elements; the motion path element exists with 48 ticks |
| J14 | `testZoomPanAndGuides` (`+View`, F3c) | bounce | ⌘+ twice; Space-drag 100 pt; ⌘0; drag from the top ruler to y 300; drag that guide to 320; drag it back onto the ruler; ⌘R | zoom pill 200%, then "Fit"; the ruler origin label changed after the pan; guide value "y 300", then "y 320" with "Undo Move Guide" as one step; guide gone; rulers hidden |
| J15 | `testCopyPasteDuplicateDelete` (`+Edit`, F18) | bounce | select Ball; ⌘C; ⌘V; ⌘D; select Shadow; ⌘X; ⌘V; select "Ball copy 2"; ⌫ | "Ball copy" above Ball, 10 pt right; "Ball copy 2"; Shadow gone, then back; "Ball copy 2" gone; Edit menu names "Undo Paste", "Undo Duplicate", "Undo Cut", "Undo Delete" in turn |
| J16 | `testScenesAddRenameReorderRemove` (`+Scenes`, F11a) | bounce | Layers tab; add scene; rename it "Outro"; set its background; drag Outro above Scene 1; select Scene 1; remove Outro; try to remove Scene 1 | "Scene 2" then "Outro"; Outro first in the list; the info card title follows the selected scene; Outro gone; Remove disabled with "An animation needs at least one scene." |
| J17 | `testSymbolConvertPlaceAndEdit` (`+Symbols`, F12a) | character | Library tab (empty state); select Legs; ⌥⌘K, name "Legs"; place Legs twice; select one instance and press Return; set the fill to `2D7FF9`; Escape; rename the symbol "Leg pair"; try to delete it | symbols empty text first; Legs usage 1, then 3; breadcrumb "Scene 1 › Legs" and the timeline shows the symbol's layers, then both gone; the fill value of all three instances reads 2D7FF9; row reads "Leg pair"; Delete disabled with "Leg pair is used 3 times." |
| J18 | `testInstancePlaybackAndSwatches` (`+Library`, F12b) | character | select the Arms instance; INSTANCE loop mode Play Once; first frame 4; select Body; add the current fill as a swatch; select Head; click the new swatch; remove the swatch | INSTANCE rows read Play Once and 4; swatch count +1; Head's fill equals Body's; swatch count back |
| J19 | `testMachineGraphAndStates` (`+Machines`, F13a) | button | ⇧⌘M (empty state); Add Machine "Button" with first state idle from its label; add states hover and pressed from labels; rename the machine "Hover button" | empty text first; 1, then 3 nodes placed left to right; idle marked initial; machine menu reads "Hover button" |
| J20 | `testTransitionsInputsAndRefusals` (`+Transitions`, F13b) | button with states | add bool input hover (default false); set its default true, then false; wire idle → hover on trigger "pointer" with hover == true; change the condition to hover == false, then back; remove state hover; add a number input "speed"; remove it; wire hover → pressed on trigger "click" | input row default reads true then false; arrow idle → hover with chip "hover == true"; removing hover is refused inline: "hover is used by the transition idle → hover"; the graph is unchanged; speed row appears then goes; issues list empty |
| J21 | `testMachinePreview` (`+Preview`, F14) | button with machine | Preview on; toggle hover on; toggle hover off | active state value "idle", then "hover", then "idle"; the probe reports the state switch on the next frame tick |
| J22 | `testExportSVGLottieAndPNGSequence` (`+Export`, F15a) | showcase | ⇧⌘E SVG; Lottie; PNG 0–12 step 2 to `-FlareExportTo` | files exist; SVG starts `<svg`; Lottie parses with `fr` 24; 7 PNGs with the PNG header; the warnings list shows "Text isn't exported yet (1 layer).", "Symbol animation exports as its first frame (1 instance)." and "Interactions aren't exported (1 machine).", plus "Background color isn't part of Lottie." for Lottie (each ends with a period, as `ExportResult.warnings` documents) |
| J23 | `testExportFailuresCancelAndReplace` (`+ExportErrors`, F15b) | bounce | export PNG to the same folder twice; Replace; export to a read-only folder; start a 2x PNG export of 0–47 and Cancel | "Replace existing files?" shown, then success; error row with the reason and Try Again; after Cancel no PNG is left in the folder |
| J24 | `testAssistProposalAcceptAndReject` (`+Assist`, F16a) | bounce | ⌥⌘A; "pop in and settle"; Generate; Preview; Reject; Generate; Accept | progress, then proposal rows in the AI color; suggested diamonds during preview; after Reject the Edit menu's Undo title is unchanged; after Accept it reads "Undo Assist" and one ⌘Z removes every proposed key |
| J25 | `testAssistFailures` (`+AssistErrors`, F16b) | bounce with `-FlareAssistMode fail`, `timeout`, `empty`, `text` | Generate in each launch | the matching message from section 3.3; Accept disabled; the document unchanged |
| J26 | `testDrawKeyAndSave` (`+Files`, F17a) | empty | ⌘N; draw a rectangle; key X at 0 and 24; play; ⌘Z; ⇧⌘Z; ⌘S to `-FlareSaveTo`; File > Open Recent; open it | title shows the file name and no dot; Open Recent lists it; the reopened file shows keys at 0 and 24 |
| J27 | `testOpenBadFilesAndText` (`+OpenErrors`, F17b) | none, then showcase | write four files in the test's temp folder (bytes `not json`; `{"format":"flare","version":2}`; `{"a":1}`; 65 MB of spaces) and open each with `-FlareOpenFile`; then launch on showcase, ⌘S, relaunch on that file | each alert's text matches section 3.3 and the empty state stays; the reopened showcase shows "Text not shown (1)" |
| J28 | `testSaveFailureAndRecovery` (`+Recovery`, F17c) | bounce | ⌘S to a read-only `-FlareSaveTo`; then move Ball, wait for the probe's autosave mark, terminate the app, relaunch | "Not saved" in the error color and an alert; on relaunch the recovery offer, Restore, and Ball is at the moved spot |
| J29 | `testEveryControlActsOrSaysWhy` (`+EveryControl`, F2) | bounce | read the `suite.controls` JSON (every `flare.*` control with enabled and reason), click each enabled one, then Escape and ⌘Z | every enabled control changed the window shot or a value; every disabled one has a reason. This is a sweep, not feature coverage: the matrix never cites it |
| P1 | `testCanvasDragLatency` (`+Perf`, QH-5) | reference | four velocity-controlled drags across 600 pt at 300 pt/s: move a shape, draw a rectangle, drag a pen handle, Space-pan | each series reports at least 60 samples (else the test fails as invalid); p95 frames late per QB-L1 |
| P2 | `testSliderScrubLatency` (`+Perf`, QH-5) | reference | velocity-controlled drag on the Rotation bar | at least 60 samples; QB-L2 |
| P3 | `testTimelineScrubLatency` (`+Perf`, QH-5) | reference | velocity-controlled drag of the playhead | at least 60 samples; QB-L3 |
| P4 | `testPlaybackHoldsFrameRate` (`+Perf`, QH-5) | reference | play 5 s at 24 fps | dropped frames per QB-L4 |
| P5 | `testNestedInstancesPlayback` (`+PerfLarge`, QH-6) | crowd | play 5 s at 30 fps | dropped frames per QB-L11 |
| P6 | `testTimelineAndLayerListScroll` (`+PerfLarge`, QH-6) | crowd | scroll the timeline lanes and the layer list end to end | frame intervals per QB-L10 |
| P7 | `testOpenLargeFile` (`+PerfLarge`, QH-6) | crowd, saved then reopened | ⌘O the saved file | progress shown within QB-L9 of the command; no main-thread stall over QB-L12 |

**Fixtures** (`FlareFixtures`, FlareModel). Built in code, never read from
disk, so the UI test target never has to build a `.flare` file:

| Fixture | Contents | Used by |
|---|---|---|
| `empty` | one scene, no layers | J3, J4, J26 |
| `bounce` | Background (locked, so stage clicks and marquees skip it), Ball, Shadow; Ball X, Y and scale keys at 0, 12, 24, 36, 47; Shadow not animated; 48 frames at 24 fps | most journeys |
| `character` | Head, Body, Arms (an instance of an animated "Wave" symbol), Legs, each on its own layer | J17, J18 |
| `button` | labels idle, hover and pressed; no machine (J19 builds it). `button with states` is the J19 result (no inputs or transitions); `button with machine` adds the hover input and the transitions idle → hover, hover → idle and hover → pressed | J19–J21 |
| `showcase` | bounce plus a text layer "Title", an instance of an animated "Spin" symbol, and one machine | J22, J27 |
| `reference` | 20 layers, 1,000 shapes, 300 frames, every property keyed, 50 instances of a two-level nested symbol | P1–P4, model budgets |
| `crowd` | 300 layers, 500 animated instances of a two-level nested symbol, 5,000 keys | P5–P7, model budgets |
| `limit` (tests only) | 9,999 layers in one scene, near `FlareFormat.maxLayersPerScene` | `HugeDocumentBudgetTests` |

---

## 5. Feature coverage matrix

Engine API status is FlareCore on `origin/main` today. The Journey column
names only journeys whose steps touch the feature; J29 (the control sweep) is
never cited. QB ids are in `docs/review-rubric.md` section 6.

| Feature | Screen | Journey | Engine API | Status | Quality bar |
|---|---|---|---|---|---|
| New from preset | New sheet | J2 | `Document`, `Scene` init | exists | QB-F1 |
| Open, save, title, dirty | File menu, top bar | J26 | `FlareFormat.decode/encode` | exists | QB-F1, byte round trip (LM-1) |
| Open Recent | File menu | J26 | none (app list) | n/a | QB-F1 |
| Open errors (not Flare, damaged, newer version, too large) | Alert | J27 | `FormatError` cases | exists | message per case (LM-1 test) |
| Open a large file off the main thread | Stage progress | P7 | `FlareFormat.decode` | exists | QB-L9, QB-L12 |
| Save failure | Top bar, alert | J28 | none (file write) | n/a | QB-F2 |
| Autosave and recovery | Recovery offer | J28 | `FlareFormat.encode` | exists | no data loss after a kill (J28) |
| Undo, redo named | Edit menu, top bar | J3, J6, J11, J15 | `CommandEngine.undoActionName` | exists | QB-F3 |
| Scenes add, rename, remove | Layers tab | J16 | `AddScene`, `RemoveScene`; `RenameScene` | partial (LC-8) | QB-F1 |
| Scene reorder | Layers tab | J16 | `ReorderScene` | missing (LC-8) | QB-F3 |
| Scene canvas and background | Layers tab, Scene inspector | J2, J16 | `SetSceneTiming`; `SetSceneCanvas` | partial (LC-8) | QB-F1 |
| Layers panel | Layers tab | J16 | layer commands | exists (shipped #147) | QB-F1 |
| Stage draws the scene | Stage | J3, J5, J8 | `Scene.renderList` (G45) | missing (LC-1) | QB-V1, QB-V2, QB-V3, QB-L6 |
| Click and Shift-click select | Stage | J5 | `Layer.hits` (Bool only); topmost address | partial (LC-2) | QB-L5 |
| Marquee select | Stage | J5 | marquee query | missing (LC-2) | QB-L5 |
| Selection box, scale and rotate handles | Stage overlay | J5 | world bounds with stroke; `SetKeyframe` | partial (LC-3) | QB-V3, QB-L1 |
| Mixed values in a multi-selection | Properties | J5 | none (Model) | n/a | QB-F1 |
| Rectangle, ellipse | Rail, stage | J3 | `AddLayer`, `AddShape`; `Path` builders | partial (LC-4, creative-core#182 open) | QB-L1, QB-V1 |
| Pen corners | Rail, stage | J3 | `Path` elements, `AddShape` | exists | QB-L1, QB-V1 |
| Pen smooth points (drag) | Rail, stage | J3 | cubic `PathElement` | exists | QB-V1 (G1 continuity, LM-3) |
| Direct select: anchors and handles | Rail, stage | J4 | `SetShapePath`, `TranslateShape` | partial (LC-7) | QB-L1 |
| Delete item | Edit menu, stage menu | J15 | `RemoveLayer`, `RemoveShape` | exists | QB-F3 |
| Cut, copy, paste, duplicate | Edit menu | J15 | `CommandRegistry` envelopes; `DuplicateLayer` | partial (LC-7) | QB-F3 |
| Move and key by drag | Stage | J6 | `SetKeyframe`, `group` | exists for scene layers | QB-L1, QB-F3 |
| Auto-key (record) | Top bar, timeline | J6 | none (Model) | n/a | QB-F2 |
| Not-animated values | Properties, stage | J6 | one-key tracks (section 2) | exists | QB-F3 |
| Transform rows with key buttons | Properties | J7 | `SetKeyframe`, `RemoveKeyframe`, `Layer.sample` | exists; scrub merge partial (LC-10) | QB-L2, QB-F4 |
| Fill (solid) | Properties | J8 | `SetShapeFill` | exists | QB-F1 |
| Gradient fill shown read-only | Properties | – (snapshot `flare-inspector-gradient`) | `Fill` | exists | golden |
| Stroke | Properties | J8 | `SetShapeStroke` | missing (LC-7) | QB-F1 |
| Symbol-layer keys | Timeline in a symbol | J17 | keyframe commands with `owner:` (Q5c) | partial (LC-5) | QB-F3 |
| Timeline lanes, diamonds, scrub | Timeline | J9 | `Layer.tracks`, `Timeline.value` | exists | QB-L3 |
| Retime keys | Timeline | J11 | `MoveKeyframe` (merges) | exists | QB-L3, QB-F3 |
| Delete keys | Timeline | J11 | `RemoveKeyframe` | exists | QB-F3 |
| Insert, remove frames | Timeline | J11 | `ShiftKeyframes` | exists | QB-F3 |
| Labels | Timeline | J11 (add), J19 (states from labels) | `SetFrameLabel`, `RemoveFrameLabel` | exists | QB-F1 |
| Easing presets and curve | Easing popover, TIMING row | J12 | `Easing`, `SetKeyframeEasing` | exists | QB-L2 (handle), easing golden table (LM-6) |
| Playback and loop | Transport, menu | J10, P4 | `Timeline.playbackFrame` | exists | QB-L4 |
| Actual fps pill | Pills | J10 | none (driver) | n/a | QB-L4 |
| Onion skin | Timeline chip, stage | J13 | `Layer.onionFrames` (G46) | missing (LC-9) | QB-L4 with ghosts |
| Motion path display | Stage overlay | J13 | `Layer.sample` per frame | exists | tick spacing follows easing (`LiveOnionTests.ticksFollowEasing`) |
| Zoom and pan | Stage, View menu | J14, P1 (pan) | none (view) | n/a | QB-L1 |
| Rulers and guides | Stage, View menu | J14 | `AddGuide`, `MoveGuide`, `RemoveGuide` | exists; drag merge missing (LC-10) | QB-F3 |
| Convert to Symbol | Library tab | J17 | `ConvertToSymbol` | exists | render diff 0 after convert (QB-V4, LM-10) |
| Symbols list with usage counts | Library tab | J17 | `Document.symbols`; usage counted by a walk (`symbolIsUsed` is internal and a Bool) | partial (LM-10 counts) | QB-F1 |
| Place instance | Library tab, stage | J17 | `AddInstance` (Q5e) | missing (LC-6) | QB-L1 |
| Instance playback (loop, play once, single frame, first frame) | INSTANCE section | J18 | `Instance.loop`, `firstFrame`; `SetInstancePlayback` | partial (LC-6) | QB-F1 |
| Edit in place | Stage, breadcrumb, timeline | J17 | owner switch; keys need Q5c | partial (LC-5) | QB-F2 |
| Rename symbol | Library tab | J17 | `RenameSymbol` | missing (LC-12b) | QB-F1 |
| Delete symbol when unused | Library tab | J17 (disabled reason) | `RemoveSymbol` | exists | QB-F1 |
| Swatches add, apply, remove | Library tab | J18 | `AddSwatch`, `RemoveSwatch`, `SetShapeFill` | exists | QB-F1 |
| Machine add, rename, delete | Interactions | J19 | state machine commands | missing (LC-11b) | QB-F3 |
| States from labels | Interactions | J19 | `MachineState` | missing commands (LC-11b) | QB-F1 |
| Graph layout | Interactions | J19 | none (`MachineLayout`, LM-15) | n/a | layout golden |
| Transitions and conditions | Interactions | J20 | `Transition`, `Condition`; commands | missing (LC-11c) | refusal inline (QB-F2) |
| Inputs and defaults | Interactions | J20 | `MachineInput`; commands | missing (LC-11c) | QB-F1 |
| Machine issues | Interactions | J20 | `StateMachine.issues(in:)` | missing (LC-11a) | QB-F2 |
| Machine preview | Interactions | J21 | `next(from:trigger:inputs:)`; runtime player | partial (LC-12) | switch on the next tick (probe) |
| SVG export | Export sheet | J22 | `SVGExporter` (text throws) | exists | golden SVG, QB-L8 |
| Lottie export | Export sheet | J22 | `LottieExporter` (position only animated) | partial (LC-13, G52) | golden JSON, QB-L8 |
| PNG sequence | Export sheet | J22 | `PNGExportPlan` + app rasterizer | plan exists; rasterizer missing (LA-1) | QB-V4, QB-L8 |
| Export warnings | Export sheet | J22 | none: exporters flatten instances at frame 0, skip the background and machines, and throw on text | missing (LM-13b scans the document) | never a silent drop (a test per case) |
| Export failure, cancel, replace | Export sheet | J23 | none (file write) | n/a | QB-F2 |
| Text in opened files | Pills, export | J27, J22 | `TextShape` | exists (not drawn in v1) | warning pill, survives save |
| Assist proposal | Assist popover | J24 | `CommandRegistry.decode`, `group` | exists; provider missing (Phase 3) | QB-L9, one undo step |
| Assist failure, timeout, empty, text | Assist popover | J25 | none (Model) | n/a | QB-F2 |
| Empty states (timeline, library, interactions, stage) | each | J0, J3, J17, J19 | none | n/a | QB-F1 |
| Huge documents | everywhere | P5, P6, P7 | all of the above | – | QB-L10, QB-L11, QB-L12 |

---

## 6. Contracts

All in `Sources/FlareModel/Contracts/`, with `import FlareCore` and the
`FoundationEssentials` import pattern. Reads take the document; writes take
the engine `inout` and throw `CommandError`. The workspace runs each write
inside `step`, so an error leaves nothing changed. Every write's doc comment
names its undo case from section 2: **coalescible** (one top-level perform
with the caller's `coalesceKey`, never grouped), **grouped "Name"** (wrapped
by the conformance in `engine.group("Name")`), or **single** (one perform,
no key). Fakes may ignore the engine for reads and use `FixtureEdit` for
writes, but keep the same undo case.

Every public struct has an explicit public memberwise init, so FlareApp can
build it. The code below is meant to compile as written; LM-0a1 checks that
by building it.

### 6.1 Shared value types (`Contracts/StageContracts.swift`)

```swift
/// Where a stage item lives: the layer list, the layer, the item, and the
/// instance indices walked from the scene layer down to it.
public struct StageAddress: Hashable, Sendable {
    public enum Item: Hashable, Sendable { case shape(Int), text(Int), instance(Int) }
    public var owner: LayerOwner
    public var layerID: String
    public var item: Item
    public var instancePath: [Int]
    public init(owner: LayerOwner, layerID: String, item: Item, instancePath: [Int] = []) {
        self.owner = owner; self.layerID = layerID; self.item = item; self.instancePath = instancePath
    }
}

/// One thing to draw, in scene space (y-down, like the exporters).
/// Text items are listed (so counts and warnings see them) but carry an empty path in v1.
public struct StageItem: Equatable, Sendable {
    public var address: StageAddress
    public var path: FlarePath          // curves kept; never flattened for drawing
    public var fill: Fill?
    public var stroke: Stroke?
    public var transform: Matrix
    public var opacity: Double          // 0...1, already multiplied down the instance chain
    public var isText: Bool
    public init(address: StageAddress, path: FlarePath, fill: Fill?, stroke: Stroke?,
                transform: Matrix, opacity: Double, isText: Bool = false) {
        self.address = address; self.path = path; self.fill = fill; self.stroke = stroke
        self.transform = transform; self.opacity = opacity; self.isText = isText
    }
}

public struct StageDrawList: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var background: FlareColor
    public var items: [StageItem]       // paint order, bottom first
    public var hiddenTextCount: Int     // drives the "Text not shown (n)" pill
    public init(width: Double, height: Double, background: FlareColor,
                items: [StageItem], hiddenTextCount: Int = 0) {
        self.width = width; self.height = height; self.background = background
        self.items = items; self.hiddenTextCount = hiddenTextCount
    }
}

public struct DragModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let shift = DragModifiers(rawValue: 1)    // constrain
    public static let option = DragModifiers(rawValue: 2)   // from center, break handles
}

public struct CanvasPreset: Hashable, Sendable {
    public var name: String
    public var width: Double
    public var height: Double
    public var fps: Int
    public var durationFrames: Int
    public init(name: String, width: Double, height: Double, fps: Int, durationFrames: Int) {
        self.name = name; self.width = width; self.height = height
        self.fps = fps; self.durationFrames = durationFrames
    }
    public static let hd1080 = CanvasPreset(name: "1080p 16:9", width: 1920, height: 1080, fps: 24, durationFrames: 120)
    public static let square = CanvasPreset(name: "Square", width: 1080, height: 1080, fps: 24, durationFrames: 120)
    public static let vertical = CanvasPreset(name: "Vertical 9:16", width: 1080, height: 1920, fps: 30, durationFrames: 150)
    public static let web = CanvasPreset(name: "Web 550 × 400", width: 550, height: 400, fps: 24, durationFrames: 48)
    public static let all: [CanvasPreset] = [hd1080, square, vertical, web]
}
```

### 6.2 The use-case protocols

```swift
// Contracts/SceneContracts.swift. Scenes, canvas, timing and guides.
public protocol SceneEditing: Sendable {
    func newDocument(_ preset: CanvasPreset) -> Document
    /// Single. Returns the new scene's id.
    func addScene(_ preset: CanvasPreset, in engine: inout CommandEngine) throws -> String
    /// Single.
    func renameScene(_ id: String, to name: String, in engine: inout CommandEngine) throws
    /// Single. Throws when it is the last scene.
    func removeScene(_ id: String, in engine: inout CommandEngine) throws
    /// Single.
    func reorderScene(_ id: String, to index: Int, in engine: inout CommandEngine) throws
    /// Single.
    func setCanvas(_ id: String, width: Double, height: Double, background: FlareColor,
                   in engine: inout CommandEngine) throws
    /// Single.
    func setTiming(_ id: String, fps: Int, durationFrames: Int, in engine: inout CommandEngine) throws
    /// Single. Returns the new guide's index.
    func addGuide(_ axis: Guide.Axis, at position: Double, sceneID: String,
                  in engine: inout CommandEngine) throws -> Int
    /// Coalescible (LC-10 merges `MoveGuide`).
    func moveGuide(at index: Int, to position: Double, sceneID: String, coalesceKey: String?,
                   in engine: inout CommandEngine) throws
    /// Single.
    func removeGuide(at index: Int, sceneID: String, in engine: inout CommandEngine) throws
}

// Contracts/StageContracts.swift. The stage picture at a frame.
public protocol StageRendering: Sendable {
    /// `editing` is the symbol being edited in place; nil draws the scene.
    func drawList(_ document: Document, sceneID: String, frame: Int,
                  editing symbolID: String?) -> StageDrawList
}

// What is under the pointer, inside a marquee, and the selection's bounds.
// `editing` is the symbol edited in place: its own items are hit, never the
// scene's (#641). An extension keeps the three calls without `editing:`.
public protocol StageHitTesting: Sendable {
    /// `tolerance` is in scene points (the app passes 4 pt divided by zoom).
    /// Hidden and locked layers and text items are never hit.
    func hit(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?, at point: Point,
             tolerance: Double) -> StageAddress?
    func marquee(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?, rect: Rect) -> [StageAddress]
    /// World bounds including stroke width; nil for an empty selection.
    func bounds(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?,
                of items: [StageAddress]) -> Rect?
}

// Contracts/ShapeContracts.swift. Tool gestures to shapes, direct selection, edit menu.
public struct ShapeDraft: Equatable, Sendable {
    public var tool: FlareTool
    public var shape: FlareShape
    public var anchors: [Point]         // pen only; empty for primitives
    public var smoothAnchors: Set<Int>  // pen anchors made by a drag
    public var isClosed: Bool
    public init(tool: FlareTool, shape: Shape, anchors: [Point] = [],
                smoothAnchors: Set<Int> = [], isClosed: Bool = false) {
        self.tool = tool; self.shape = shape; self.anchors = anchors
        self.smoothAnchors = smoothAnchors; self.isClosed = isClosed
    }
}

/// What a handle drag on the selection box asks for, in scene space.
public enum BoxGesture: Hashable, Sendable {
    case move(dx: Double, dy: Double)
    case scale(handle: Int, to: Point)      // handle 0...7 clockwise from top-left
    case rotate(degrees: Double)
}

public protocol ShapeBuilding: Sendable {
    /// Why `tool` can't draw yet, or nil; the rail shows it as the disabled reason.
    func unavailableHelp(for tool: FlareTool) -> String?
    func draft(_ tool: FlareTool, from start: Point, to end: Point, modifiers: DragModifiers,
               previous: ShapeDraft?) -> ShapeDraft?
    /// Grouped "Add Rectangle", "Add Ellipse" or "Add Path". Adds the draft as a new
    /// layer above `aboveLayerID` and returns the new layer's id. Throws on a locked layer.
    func commit(_ draft: ShapeDraft, sceneID: String, aboveLayerID: String?,
                in engine: inout CommandEngine) throws -> String
    /// The layer values a box gesture would give, for the live preview and the commit.
    func boxResult(_ gesture: BoxGesture, layers: [String], document: Document, sceneID: String,
                   frame: Int, box: Rect) -> [String: [String: Double]]
    /// Grouped "Move", "Scale" or "Rotate": writes `boxResult` through the
    /// not-animated / animated rule of section 2.
    func commitBox(_ gesture: BoxGesture, layers: [String], sceneID: String, frame: Int, box: Rect,
                   autoKey: Bool, in engine: inout CommandEngine) throws
    /// Grouped "Edit Path" (direct select).
    func setPath(_ path: FlarePath, of item: StageAddress, in engine: inout CommandEngine) throws
    /// Grouped "Move" (direct select of whole items).
    func translate(_ items: [StageAddress], dx: Double, dy: Double, in engine: inout CommandEngine) throws
    /// Grouped "Delete".
    func delete(_ items: [StageAddress], in engine: inout CommandEngine) throws
    /// Grouped "Duplicate". Returns the new layer ids.
    func duplicate(layers: [String], owner: LayerOwner, in engine: inout CommandEngine) throws -> [String]
    /// The layers as a registry envelope list for the pasteboard (no engine change).
    func copy(layers: [String], owner: LayerOwner, from document: Document) throws -> Data
    /// Grouped "Paste". Decodes only through `CommandRegistry.builtIn`; returns new layer ids.
    func paste(_ data: Data, owner: LayerOwner, aboveLayerID: String?, offset: Double,
               in engine: inout CommandEngine) throws -> [String]
}

// Contracts/AnimateContracts.swift. Inspector rows, keyframe buttons, drag-to-key, auto-key.
public enum KeyState: Hashable, Sendable {
    case notAnimated       // no track or one key (section 2); stopwatch idle
    case animated          // two or more keys, none at the playhead
    case keyedHere         // two or more keys, one at the playhead
}

public struct AnimatedProperty: Hashable, Sendable {
    public var name: String            // "x", "y", "scaleX", "scaleY", "rotation", "opacity"
    public var title: String           // "X", "Rotation"
    public var value: Double?          // nil = "Mixed" across a multi-selection
    public var range: ClosedRange<Double>
    public var unit: String            // "pt", "×", "°", "%"
    public var decimals: Int
    public var keyState: KeyState
    public init(name: String, title: String, value: Double?, range: ClosedRange<Double>,
                unit: String, decimals: Int, keyState: KeyState) {
        self.name = name; self.title = title; self.value = value; self.range = range
        self.unit = unit; self.decimals = decimals; self.keyState = keyState
    }
}

public protocol PropertyAnimating: Sendable {
    func properties(_ document: Document, owner: LayerOwner, layerIDs: [String],
                    frame: Int) -> [AnimatedProperty]
    /// Coalescible. Sets `value` of one property on each layer at `frame` by the
    /// rule in section 2: a not-animated property edits its one key (or adds a key
    /// at the playhead when `autoKey` is on); an animated one keys the playhead.
    func setValue(_ value: Double, of property: String, owner: LayerOwner, layerIDs: [String],
                  frame: Int, autoKey: Bool, coalesceKey: String?,
                  in engine: inout CommandEngine) throws
    /// Grouped "Animate <Title>" or "Stop Animating <Title>" (section 2's stopwatch rule).
    func toggleAnimated(_ property: String, owner: LayerOwner, layerID: String, frame: Int,
                        lastFrame: Int, in engine: inout CommandEngine) throws
    /// Single: adds or removes the key at `frame`.
    func toggleKey(_ property: String, owner: LayerOwner, layerID: String, frame: Int,
                   in engine: inout CommandEngine) throws
    /// Grouped "Set Fill". Applies to every shape of the selected layers, or to the
    /// direct-selected items.
    func setFill(_ fill: Fill, of items: [StageAddress], in engine: inout CommandEngine) throws
    /// Grouped "Set Stroke".
    func setStroke(_ stroke: Stroke?, of items: [StageAddress], in engine: inout CommandEngine) throws
}

// The timeline.
public struct KeyRef: Hashable, Sendable {
    public var layerID: String
    public var property: String?       // nil = the layer's summary key (every track at that frame)
    public var frame: Int
    public init(layerID: String, property: String?, frame: Int) {
        self.layerID = layerID; self.property = property; self.frame = frame
    }
}

public struct TimelineRow: Hashable, Sendable {
    public var layerID: String
    public var name: String
    public var isVisible: Bool
    public var isLocked: Bool
    public var keyFrames: [Int]                  // summary diamonds
    public var segments: [ClosedRange<Int>]      // tweens between keys
    public var easedSegments: [Int: Easing]      // start frame -> easing
    public init(layerID: String, name: String, isVisible: Bool, isLocked: Bool, keyFrames: [Int],
                segments: [ClosedRange<Int>], easedSegments: [Int: Easing]) {
        self.layerID = layerID; self.name = name; self.isVisible = isVisible; self.isLocked = isLocked
        self.keyFrames = keyFrames; self.segments = segments; self.easedSegments = easedSegments
    }
}

public protocol KeyframeEditing: Sendable {
    func rows(_ document: Document, owner: LayerOwner) -> [TimelineRow]
    func labels(_ document: Document, sceneID: String) -> [String: Int]
    /// Coalescible. Throws, changing nothing, when a key would land on another key.
    func moveKeys(_ keys: Set<KeyRef>, by delta: Int, owner: LayerOwner,
                  coalesceKey: String?, in engine: inout CommandEngine) throws
    /// Grouped "Delete Keyframe".
    func removeKeys(_ keys: Set<KeyRef>, owner: LayerOwner, in engine: inout CommandEngine) throws
    /// Single ("Insert Frame").
    func insertFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                      in engine: inout CommandEngine) throws
    /// Single ("Remove Frame").
    func removeFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                      in engine: inout CommandEngine) throws
    /// Single. A nil name removes the label at `frame`.
    func setLabel(_ name: String?, at frame: Int, sceneID: String, in engine: inout CommandEngine) throws
}

// Easing on the segment that starts at a key. Named `KeyframeEasing`, not
// `EasingEditing`: `EasingEditing` (Sources/FlareModel/EasingEditing.swift) is
// the window-level easing editor protocol FlareWorkspace conforms to. Both use
// the `EasingPreset` enum declared there (`title`, `easing`, six cases).
public protocol KeyframeEasing: Sendable {
    var presets: [EasingPreset] { get }
    /// `count` points of the curve in 0...1 time, for drawing the editor.
    func curve(_ easing: Easing, count: Int) -> [Point]
    /// Coalescible.
    func setEasing(_ easing: Easing, at key: KeyRef, owner: LayerOwner,
                   coalesceKey: String?, in engine: inout CommandEngine) throws
}

// Onion skin and the motion path.
public struct OnionSettings: Hashable, Sendable {
    public var isOn: Bool
    public var before: Int
    public var after: Int
    public var falloff: Double
    public init(isOn: Bool = false, before: Int = 2, after: Int = 2, falloff: Double = 0.5) {
        self.isOn = isOn; self.before = before; self.after = after; self.falloff = falloff
    }
}

public struct Ghost: Equatable, Sendable {
    public enum Side: Hashable, Sendable { case before, after }
    public var frame: Int
    public var side: Side
    public var opacity: Double
    public var items: [StageItem]
    public init(frame: Int, side: Side, opacity: Double, items: [StageItem]) {
        self.frame = frame; self.side = side; self.opacity = opacity; self.items = items
    }
}

public protocol OnionSkinning: Sendable {
    /// Honors `settings.before`, `.after` and `.falloff` exactly (the fake too).
    func ghosts(_ document: Document, sceneID: String, layerIDs: [String], frame: Int,
                settings: OnionSettings) -> [Ghost]
    /// Positions of the layer's origin for every frame, for the dotted path and ticks.
    func motionPath(_ document: Document, owner: LayerOwner, layerID: String) -> [Point]
}

// Contracts/LibraryContracts.swift. Symbols, instances and swatches.
public struct SymbolSummary: Hashable, Sendable {
    public var id: String
    public var name: String
    public var durationFrames: Int
    public var usage: Int              // instances counted by walking every layer list
    public init(id: String, name: String, durationFrames: Int, usage: Int) {
        self.id = id; self.name = name; self.durationFrames = durationFrames; self.usage = usage
    }
}

public protocol LibraryManaging: Sendable {
    func symbols(_ document: Document) -> [SymbolSummary]
    func swatches(_ document: Document) -> [Swatch]
    /// Grouped "Convert to Symbol". Returns the symbol id.
    func convertToSymbol(_ layerIDs: [String], sceneID: String, name: String,
                         in engine: inout CommandEngine) throws -> String
    /// Single ("Place Symbol"). Throws on a locked layer.
    func placeInstance(of symbolID: String, at point: Point, owner: LayerOwner, layerID: String,
                       in engine: inout CommandEngine) throws -> StageAddress
    /// Coalescible.
    func setInstanceTransform(_ transform: Transform, at address: StageAddress,
                              coalesceKey: String?, in engine: inout CommandEngine) throws
    /// Single (`SetInstancePlayback`, LC-6).
    func setInstancePlayback(_ loop: Instance.LoopMode, firstFrame: Int, at address: StageAddress,
                             in engine: inout CommandEngine) throws
    /// Single.
    func renameSymbol(_ id: String, to name: String, in engine: inout CommandEngine) throws
    /// Single. Throws `symbolInUse` while any instance uses it.
    func removeSymbol(_ id: String, in engine: inout CommandEngine) throws
    /// Single.
    func addSwatch(_ swatch: Swatch, in engine: inout CommandEngine) throws
    /// Single.
    func removeSwatch(_ id: String, in engine: inout CommandEngine) throws
}

// Contracts/InteractContracts.swift. State machines: editing.
// The engine validates every machine on every perform, so it can never hold a
// dangling transition or an unknown initial state. Bad edits are refused (the
// throw names the rule); issues are only the warnings a valid machine can have.
public struct MachineIssue: Hashable, Sendable {
    public var message: String              // "pressed can't be reached from idle."
    public var stateID: String?
    public var transitionIndex: Int?
    public init(message: String, stateID: String?, transitionIndex: Int?) {
        self.message = message; self.stateID = stateID; self.transitionIndex = transitionIndex
    }
}

public protocol StateMachineEditing: Sendable {
    func machines(_ document: Document) -> [StateMachine]
    /// From FlareCore's public `StateMachine.issues(in:)` (LC-11a).
    func issues(_ document: Document, machineID: String) -> [MachineIssue]
    /// Single. A machine is born with its first state, which becomes the initial state.
    func addMachine(named name: String, firstState: MachineState,
                    in engine: inout CommandEngine) throws -> String
    /// Single.
    func renameMachine(_ id: String, to name: String, in engine: inout CommandEngine) throws
    /// Single.
    func removeMachine(_ id: String, in engine: inout CommandEngine) throws
    /// Single.
    func addState(_ state: MachineState, to machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func updateState(_ state: MachineState, in machineID: String, in engine: inout CommandEngine) throws
    /// Single. Throws while a transition uses the state or it is the initial state.
    func removeState(_ stateID: String, from machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func addTransition(_ transition: Transition, to machineID: String,
                       in engine: inout CommandEngine) throws
    /// Single. Replaces from, to, trigger and conditions.
    func updateTransition(at index: Int, to transition: Transition, in machineID: String,
                          in engine: inout CommandEngine) throws
    /// Single.
    func removeTransition(at index: Int, from machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func addInput(_ input: MachineInput, to machineID: String, in engine: inout CommandEngine) throws
    /// Single. Replaces the input's default value (same name and kind).
    func updateInput(_ input: MachineInput, in machineID: String, in engine: inout CommandEngine) throws
    /// Single. Throws while a condition uses the input.
    func removeInput(named name: String, from machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func setInitialState(_ stateID: String, of machineID: String, in engine: inout CommandEngine) throws
}

// State machines: the live preview (no document edits).
public struct MachinePreview: Equatable, Sendable {
    public var machineID: String
    public var stateID: String
    public var frame: Int                        // within the state's range
    public var inputs: [String: InputValue]
    public init(machineID: String, stateID: String, frame: Int, inputs: [String: InputValue]) {
        self.machineID = machineID; self.stateID = stateID; self.frame = frame; self.inputs = inputs
    }
}

public protocol StateMachinePreviewing: Sendable {
    func start(_ document: Document, machineID: String) throws -> MachinePreview
    func set(_ input: String, to value: InputValue, _ preview: MachinePreview,
             in document: Document) -> MachinePreview
    func fire(_ trigger: String, _ preview: MachinePreview, in document: Document) -> MachinePreview
    func advance(_ preview: MachinePreview, frames: Int, in document: Document) -> MachinePreview
}

// Contracts/ExportContracts.swift.
public enum ExportFormat: String, CaseIterable, Hashable, Sendable { case svgFrame, lottie, pngSequence }

public struct ExportOptions: Hashable, Sendable {
    public var format: ExportFormat
    public var sceneID: String
    public var frames: ClosedRange<Int>          // svgFrame uses lowerBound
    public var step: Int
    public var scale: Double                     // 1 or 2
    public var transparentBackground: Bool
    public init(format: ExportFormat, sceneID: String, frames: ClosedRange<Int>, step: Int = 1,
                scale: Double = 1, transparentBackground: Bool = false) {
        self.format = format; self.sceneID = sceneID; self.frames = frames; self.step = step
        self.scale = scale; self.transparentBackground = transparentBackground
    }
}

public struct ExportFile: Equatable, Sendable {
    public var name: String
    public var data: Data
    public init(name: String, data: Data) { self.name = name; self.data = data }
}

public struct ExportResult: Equatable, Sendable {
    public var files: [ExportFile]
    public var warnings: [String]                // "Text isn't exported yet (1 layer)."
    public init(files: [ExportFile], warnings: [String]) { self.files = files; self.warnings = warnings }
}

/// Implemented in FlareApp with CoreGraphics; the fake returns a fixed tiny PNG.
public protocol FrameRasterizing: Sendable {
    func png(_ list: StageDrawList, scale: Double, transparent: Bool) throws -> Data
}

public protocol Exporting: Sendable {
    /// The warnings this export will carry, from a scan of the document (shown before Export).
    func warnings(_ document: Document, options: ExportOptions) -> [String]
    /// Checks `Task.isCancelled` between frames and throws `CancellationError`, writing nothing.
    func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                progress: @Sendable (Double) -> Void) async throws -> ExportResult
}

// Contracts/AssistContracts.swift. A prompt becomes registered commands.
public struct AssistProposal: Equatable, Sendable {
    public var summary: String
    public var envelopes: [Data]                 // CommandRegistry envelopes, in order
    public var titles: [String]                  // one readable line per envelope
    public init(summary: String, envelopes: [Data], titles: [String]) {
        self.summary = summary; self.envelopes = envelopes; self.titles = titles
    }
}

public protocol AnimationAssisting: Sendable {
    /// Why assist can't run (no model provider configured), or nil.
    var unavailableHelp: String? { get }
    /// Throws `AssistError.noSuggestion`, `.timedOut` or `.failed(message)`.
    func propose(_ prompt: String, document: Document, selection: [StageAddress],
                 frame: Int) async throws -> AssistProposal
}
```

Applying a proposal is not a contract. `FlareAssist.swift` (LM-0c3)
decodes the envelopes with `CommandRegistry.builtIn`, rejects the whole
proposal if any id is unknown or starts with `text.` (with a reason), runs
them on a copy of the engine for the preview draw list, and on Accept
performs them in one `engine.group("Assist")`. So Assist can never touch the
document outside the registry, and one undo removes all of it. Fake and live
share this code; only `propose` differs.

### 6.3 Wiring and fakes (`Sources/FlareModel/FlareServices.swift`)

This is the final form, after the LM-0 chain has landed every fake; until
then the missing members hold `NotBuilt` (below). `FakeAssistMode` (`ok`,
`fail`, `timeout`, `empty`, `text`) is declared in `AssistContracts.swift` so
this file compiles before the assist fake exists.

```swift
public struct FlareServices: Sendable {
    public var scenes: any SceneEditing
    public var stage: any StageRendering
    public var hits: any StageHitTesting
    public var shapes: any ShapeBuilding
    public var properties: any PropertyAnimating
    public var keyframes: any KeyframeEditing
    public var easing: any KeyframeEasing
    public var onion: any OnionSkinning
    public var library: any LibraryManaging
    public var machines: any StateMachineEditing
    public var preview: any StateMachinePreviewing
    public var export: any Exporting
    public var assist: any AnimationAssisting
    /// True while any member is a fake; drives the "Preview data" pill.
    public var isPreview: Bool

    public init(scenes: any SceneEditing, stage: any StageRendering, hits: any StageHitTesting,
                shapes: any ShapeBuilding, properties: any PropertyAnimating,
                keyframes: any KeyframeEditing, easing: any KeyframeEasing, onion: any OnionSkinning,
                library: any LibraryManaging, machines: any StateMachineEditing,
                preview: any StateMachinePreviewing, export: any Exporting,
                assist: any AnimationAssisting, isPreview: Bool) {
        self.scenes = scenes; self.stage = stage; self.hits = hits; self.shapes = shapes
        self.properties = properties; self.keyframes = keyframes; self.easing = easing
        self.onion = onion; self.library = library; self.machines = machines
        self.preview = preview; self.export = export; self.assist = assist
        self.isPreview = isPreview
    }

    /// Every member a fake. `assistMode` comes from `-FlareAssistMode`.
    public static func fake(assistMode: FakeAssistMode = .ok) -> FlareServices {
        FlareServices(scenes: FakeScenes(), stage: FakeStage(), hits: FakeHits(), shapes: FakeShapes(),
                      properties: FakeProperties(), keyframes: FakeKeyframes(), easing: FakeEasing(),
                      onion: FakeOnion(), library: FakeLibrary(), machines: FakeMachines(),
                      preview: FakePreview(), export: FakeExport(),
                      assist: FakeAssist(mode: assistMode), isPreview: true)
    }

    /// Live members once integrated. Until an IN task swaps a member in, its
    /// slot holds the fake built with an `unavailable` reason, so the control
    /// shows disabled with that reason. Each IN task edits one line here.
    public static var live: FlareServices {
        FlareServices(
            scenes: FakeScenes(unavailable: "Not connected yet (IN-4)."),
            stage: FakeStage(unavailable: "Not connected yet (IN-1)."),
            hits: FakeHits(unavailable: "Not connected yet (IN-1)."),
            shapes: FakeShapes(unavailable: "Not connected yet (IN-1)."),
            properties: FakeProperties(unavailable: "Not connected yet (IN-1)."),
            keyframes: FakeKeyframes(unavailable: "Not connected yet (IN-2)."),
            easing: FakeEasing(unavailable: "Not connected yet (IN-2)."),
            onion: FakeOnion(unavailable: "Not connected yet (IN-3)."),
            library: FakeLibrary(unavailable: "Not connected yet (IN-5)."),
            machines: FakeMachines(unavailable: "Not connected yet (IN-6)."),
            preview: FakePreview(unavailable: "Not connected yet (IN-6)."),
            export: FakeExport(unavailable: "Not connected yet (IN-7)."),
            assist: FakeAssist(mode: .ok, unavailable: "Assist needs the suite's model provider."),
            isPreview: true)
    }
}

/// Why a proposal could not be made.
public enum AssistError: Error, Equatable, Sendable {
    case noSuggestion, timedOut, failed(String)
}
```

`FlareServices.easing` is the per-keyframe `KeyframeEasing` contract above.
`EasingEditing` stays FlareWorkspace's window-level protocol (segment list,
selection, presets, handles, undo) over `SetKeyframeEasing`, with
`FakeEasingEditing` as its stand-in; FlareServices never holds it.

Each fake's `init(unavailable: String? = nil)` (and `FakeAssist.init(mode:unavailable:)`)
lives in its own file under `Fakes/`. IN-9 sets `isPreview` to false once no
member is a fake, except Assist while it has no provider.

| Contract | Fake (`Sources/FlareModel/Fakes/`) | Live (`Sources/FlareModel/Live/`) |
|---|---|---|
| `SceneEditing` | `FakeScenes`: real `AddScene`, `RemoveScene`, `SetSceneTiming` and guide commands; `FixtureEdit` for rename, reorder and canvas | `LiveScenes` over LC-8, LC-10 |
| `StageRendering` | `FakeStage`: visible scene layers by `Layer.placement(at:)`, plus instances one level deep (each instance's symbol layers at `Instance.resolve`), text counted not drawn | `LiveStage` over `renderList` (LC-1) |
| `StageHitTesting` | `FakeHits`: bounding-box hit on the fake draw list, instances included | `LiveHits` over LC-2, LC-3 |
| `ShapeBuilding` | `FakeShapes`: rectangle and ellipse as polygons, pen as straight segments with smooth anchors marked; commit, box gestures, delete, duplicate, copy and paste through real commands or `FixtureEdit` in the right groups | `LiveShapes` over LC-4 builders, pen curves, LC-7 |
| `PropertyAnimating` | `FakeProperties`: real `SetKeyframe` on scene layers with the section 2 rule; stroke via `FixtureEdit` | `LiveProperties` (LM-4) |
| `KeyframeEditing` | `FakeKeyframes`: rows from `Layer.tracks`; real move, remove, shift and labels | `LiveKeyframes` (LM-5) |
| `KeyframeEasing` | `FakeEasing`: six presets, curve from `Easing.value(at:)`; real `SetKeyframeEasing` | `LiveEasing` (LM-6) |
| `OnionSkinning` | `FakeOnion`: ghosts from `FakeStage` at the requested before and after counts and falloff | `LiveOnion` over LC-9 |
| `LibraryManaging` | `FakeLibrary`: real convert and swatch commands; `FixtureEdit` for place, playback and rename; usage counted by walking layers | `LiveLibrary` over LC-6, LC-12b |
| `StateMachineEditing` | `FakeMachines`: `FixtureEdit` on `Document.stateMachines`, refusing the same rules the engine validates; issues: unreachable states | `LiveMachines` over LC-11a–c |
| `StateMachinePreviewing` | `FakePreview`: real `next(from:trigger:inputs:)`, loops each state's range | `LivePreview` over LC-12 |
| `Exporting` | `FakeExport`: real SVG for the frame, canned Lottie JSON, PNGs from the rasterizer at 20 ms per frame (so Cancel is reachable), warnings from the shared scan | `LiveExport` (LM-13a, LM-13b) |
| `AnimationAssisting` | `FakeAssist(mode:)`: canned proposal per fixture after 300 ms (pop in: scale keys at 0, 6, 10 with ease out); `fail`, `timeout` (after 20 s, shortened to 1 s under the journey flag), `empty`, `text` (a `text.add` envelope) | `LiveAssist` over the suite model provider (Phase 3) |
| `FrameRasterizing` | `FakeRasterizer`: a fixed 1×1 PNG | `StageRasterizer` in FlareApp (LA-1) |

Until the fake for a member lands, `.fake` and `.live` hold
`NotBuilt(reason:)` there (LM-0a1b): one struct that conforms to every
contract, returns empty reads and throws its reason on writes. Each fake task
swaps its own members in `FlareServices.swift`; those tasks are stacked
(section 7.1), so the edits never collide.

Every fake takes `unavailable: String?`. Set, it returns empty results and
reports the string, so `.live` can point at a fake that is not integrated
yet and the control shows as disabled with that reason, never dead.

Which services a launch gets:

- `-FlareFixture <name>`: `.fake` plus that fixture (journeys, snapshots).
- `-FlareOpenFile <path>` or a document opened in the app: `.live`.
- `-FlareSample <name>`: that fixture on `.live` (integrated journeys).
- No arguments (how the Review Room opens a build): the empty state on
  `.fake` until IN-9. File > Open Sample loads a fixture, so the captain can
  play every screen at G1. The "Preview data" pill shows whenever
  `services.isPreview` is true. IN-9 switches the no-argument launch to `.live`.

---

## 7. Task breakdown

Every task is one PR: at most 400 changed lines and 15 files, one line, the
rubric applies. `track:ui` tasks build on `FlareServices.fake` and fixture
documents only. `track:logic` tasks touch no SwiftUI. `track:integrate`
tasks swap one use case to live and rerun its journeys. "Supersedes" names
the existing issue a task replaces or extends, so nothing is filed twice.
Paths are repo-relative and complete; creative-core paths are marked (core).

**Shared files and how they stay safe.** A file in two tasks' owns cells
means those tasks are stacked, and the later one lists the earlier in its
deps. The shared files are: `Sources/FlareModel/FlareServices.swift` and
`Sources/FlareModel/Fakes/FlareFixtures.swift` (the LM-0 chain, stacked in
order, except that LM-0c2 and LM-0c4 branch off it, so whichever of two
siblings lands second rebases on the other); `Sources/SuiteUI/InspectorRows.swift` (S1 then S3);
`Sources/SuiteUI/TimelineStrip.swift` (S10 then S11); each
`Sources/FlareApp/FlareWindow+<Area>.swift`, created by F1b and then edited
only by its area's tasks, stacked in this order: Stage F3a, F3b, F5; Tools
F4a, F4b; View F3c, F10; Inspector F6a, F6b, F6c, F9; Timeline F7a, F7b, F8;
Layers F11a; File F11b, F17a, F17b, F17c; Library F12a, F12b; Interactions
F13a, F13b, F14; Export F15a, F15b; Assist F16a, F16b; Edit F18 (each task's
deps column holds the one before it); the slot views F1a creates as stubs
(`FlareStage`, `FlareTimeline`, `FlareInspector`, `FlareLayersPanel`,
`FlareLibraryPanel`, `FlareInteractions`, `FlareRecording`), each then owned
by the one task that lists it; (core) `Sources/FlareCore/CommandRegistry.swift` (one
registration line each, merged in this order: LC-6, LC-7, LC-8, LC-11b,
LC-11c, LC-11d, LC-11e, LC-12b; each rebases on the last); (core)
`Sources/FlareCore/Commands.swift` (LC-5 then LC-10); and `docs/c4/model.json`
(LM-0a3, F1a and S16 edit different objects far apart, so git merges them;
LC-1 edits creative-core's own file). Nothing else is shared.

### 7.0 Docs

| id | title | line | owns | deps | acceptance | quality |
|---|---|---|---|---|---|---|
| DOC-1 | Visual language in `docs/design.md`, quality rows in `docs/review-rubric.md` | docs | `docs/design.md`, `docs/review-rubric.md`, `docs/blueprints/flare.md` | – | this PR; captain review | n/a |
| DOC-2 | gaps.md: copy G45–G54 from `docs/design/suite.md`, map LC-1 to G45, LC-9 to G46, LC-13 to G52 (G54 is the existing `PNGExportPlan`), add the other LC tasks as G55 onward | core docs | (core) `docs/gaps.md` | G0 | every LC task below has exactly one G row; no G id appears twice | n/a |

### 7.1 track:logic: contracts, fakes and workspace (line:flare), stacked in order

| id | title | owns | deps | acceptance | quality |
|---|---|---|---|---|---|
| LM-0a1 | Contracts part 1 (stage, scene, shape, animate), typealiases, `FixtureEdit` | `Sources/FlareModel/Contracts/StageContracts.swift`, `Sources/FlareModel/Contracts/SceneContracts.swift`, `Sources/FlareModel/Contracts/ShapeContracts.swift`, `Sources/FlareModel/Contracts/AnimateContracts.swift`, `Sources/FlareModel/FlareTypealiases.swift`, `Sources/FlareModel/Fakes/FixtureEdit.swift`, `Tests/FlareModelTests/FixtureEditTests.swift` | G0 | `FixtureEdit` undo restores the document exactly; its id is absent from `CommandRegistry.builtIn`; `DragModifiers([.shift, .option]).rawValue == 3`; the test builds every public struct without `@testable` | – |
| LM-0a1b | Contracts part 2 (library, interact, export, assist), `NotBuilt`, `FlareServices` with `fake(assistMode:)` and `live` | `Sources/FlareModel/Contracts/LibraryContracts.swift`, `Sources/FlareModel/Contracts/InteractContracts.swift`, `Sources/FlareModel/Contracts/ExportContracts.swift`, `Sources/FlareModel/Contracts/AssistContracts.swift`, `Sources/FlareModel/Fakes/NotBuilt.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/ServicesTests.swift` | LM-0a1 | `.fake` and `.live` build; a `NotBuilt` write throws its reason and a read is empty; `isPreview` is true for both | – |
| LM-0a2 | Fakes: scenes, stage (instances one level deep, text counted), hits; fixtures `empty` and `bounce` | `Sources/FlareModel/Fakes/FakeScenes.swift`, `Sources/FlareModel/Fakes/FakeStage.swift`, `Sources/FlareModel/Fakes/FakeHits.swift`, `Sources/FlareModel/Fakes/FlareFixtures.swift`, `Sources/FlareModel/Fakes/Fixtures/BounceFixture.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/StageFakesTests.swift` | LM-0a1b | `bounce` draws 3 items in paint order; a hit at Ball's center returns Ball; removing the last scene throws; a guide drag of 50 steps is one undo entry | – |
| LM-0a2b | Fake shapes: drafts, commit, box gestures, path edit, delete, duplicate, copy, paste | `Sources/FlareModel/Fakes/FakeShapes.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/ShapeFakesTests.swift` | LM-0a2 | a rectangle commit leaves exactly one entry, "Undo Add Rectangle"; Shift gives equal sides; a scale gesture keeps the opposite corner within 1e-9; copy then paste adds "Ball copy" in one entry "Undo Paste"; garbage paste data throws "Nothing to paste." | – |
| LM-0a3 | Workspace wiring: the `directSelect` tool case, every stored property from section 2, access changes, `step(label:)`, `load`, `init(services:)`, `toolHelp`, selection, marquee and drag drafts; `FlareToolsTests` rewrite; C4 `flare-model` description | `Sources/FlareModel/FlareWorkspace.swift`, `Sources/FlareModel/FlareSelection.swift`, `Sources/FlareModel/FlareDrag.swift`, `Tests/FlareModelTests/FlareToolsTests.swift`, `Tests/FlareModelTests/WorkspaceWiringTests.swift`, `docs/c4/model.json` | LM-0a2b | rectangle `drag` then `endDrag` on `empty` adds Rectangle 1 with one entry; during a drag the document is unchanged and `draft` is set; `cancelDrag` leaves nothing; a select drag on `bounce` moves Ball in one entry "Undo Move"; `FlareWorkspaceTests` and `FlareLayersTests` still pass | QB-F1 (`FlareToolsTests`) |
| LM-0a4 | Workspace: scenes, guides, Edit menu actions (cut, copy, paste, duplicate, delete, select all) | `Sources/FlareModel/FlareScenes.swift`, `Sources/FlareModel/FlareGuides.swift`, `Sources/FlareModel/FlareEdit.swift`, `Tests/FlareModelTests/SceneGuideEditTests.swift` | LM-0a3 | remove of the last scene is refused with "An animation needs at least one scene."; Cut is one entry "Undo Cut"; delete on a locked layer says "Unlock <layer> to draw on it." | QB-F3 |
| LM-0b1 | Fake properties and the not-animated rule; auto-key state | `Sources/FlareModel/Fakes/FakeProperties.swift`, `Sources/FlareModel/FlareAnimate.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/PropertyFakesTests.swift` | LM-0a4 | Ball X is `.animated`, Shadow X `.notAnimated`; `setValue` on Shadow X at frame 30 with auto-key off edits its one key and it stays `.notAnimated`; the stopwatch at frame 0 on Shadow gives keys at 0 and 47 and `.animated`; 120 `setValue` calls with one key leave exactly 1 undo entry; Ball and Shadow selected give X `nil` (Mixed) | QB-F3 |
| LM-0b2 | Fake keyframes, easing, onion; onion and motion path state | `Sources/FlareModel/Fakes/FakeKeyframes.swift`, `Sources/FlareModel/Fakes/FakeEasing.swift`, `Sources/FlareModel/Fakes/FakeOnion.swift`, `Sources/FlareModel/FlareOnionState.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/TimelineFakesTests.swift` | LM-0b1 | moving key 24 onto 36 throws and changes nothing; onion 3 and 3 gives 6 ghosts with opacity falling by the falloff; `motionPath` has 48 points | – |
| LM-0c1 | Fake library; editing in place (owner switch, symbol duration for the timeline, return frame); fixture `character` | `Sources/FlareModel/Fakes/FakeLibrary.swift`, `Sources/FlareModel/Fakes/Fixtures/CharacterFixture.swift`, `Sources/FlareModel/Fakes/FlareFixtures.swift`, `Sources/FlareModel/FlareSymbols.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/LibraryFakesTests.swift` | LM-0b2 | convert Legs: the fake draw list is equal before and after; usage 3 after two places; enter a symbol: owner `.symbol`, timeline length = the symbol's; exit returns to the frame left | – |
| LM-0c2 | Fake machines and preview; machine state; fixture `button` | `Sources/FlareModel/Fakes/FakeMachines.swift`, `Sources/FlareModel/Fakes/FakePreview.swift`, `Sources/FlareModel/Fakes/Fixtures/ButtonFixture.swift`, `Sources/FlareModel/Fakes/FlareFixtures.swift`, `Sources/FlareModel/FlareMachines.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/MachineFakesTests.swift` | LM-0c1 | `addMachine` makes the first state initial; removing a state a transition uses throws a message naming the transition and changes nothing; an unreachable state is a warning on that state; preview goes idle to hover on `hover = true` | – |
| LM-0c3 | Fake export and rasterizer; the shared warnings scan; export state; fixture `showcase` | `Sources/FlareModel/Fakes/FakeExport.swift`, `Sources/FlareModel/Fakes/FakeRasterizer.swift`, `Sources/FlareModel/ExportScan.swift`, `Sources/FlareModel/Fakes/Fixtures/ShowcaseFixture.swift`, `Sources/FlareModel/Fakes/FlareFixtures.swift`, `Sources/FlareModel/FlareExport.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/ExportScanTests.swift` | LM-0c1 | one test per warning: text layer, animated symbol instance, machine, background in Lottie; `bounce` 0–12 step 2 gives 7 PNGs; a cancelled export returns no files | never a silent drop |
| LM-0c4 | Fake assist (modes ok, fail, timeout, empty, text); the shared assist apply | `Sources/FlareModel/Fakes/FakeAssist.swift`, `Sources/FlareModel/FlareAssist.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/AssistApplyTests.swift` | LM-0c3 | accept is exactly one entry "Undo Assist"; reject leaves the document and undo stack equal; a `text.add` or unknown envelope rejects the whole proposal with a reason; each failure mode sets its message | QB-F2 |
| LM-0c5 | Large fixtures: `reference`, `crowd`, `limit` | `Sources/FlareModel/Fakes/Fixtures/ReferenceFixture.swift`, `Sources/FlareModel/Fakes/Fixtures/CrowdFixture.swift`, `Sources/FlareModel/Fakes/Fixtures/LimitFixture.swift`, `Sources/FlareModel/Fakes/FlareFixtures.swift`, `Tests/FlareModelTests/LargeFixtureTests.swift` | LM-0c3 | counts match section 4; `crowd` nests instances two deep; each builds in under 1 s in debug; `limit` has 9,999 layers and passes `FlareFormat.validate` | – |
| LM-15 | `MachineLayout`: columns by distance from the initial state | `Sources/FlareModel/MachineLayout.swift`, `Tests/FlareModelTests/MachineLayoutTests.swift` | LM-0a1b | the same machine gives the same layout; unreachable states sit in the last column; no two nodes overlap for 50 states | layout golden values |
| QH-3 | Linux budget helper and model budgets | `Tests/FlareModelTests/Budget.swift`, `Tests/FlareModelTests/StageBudgetTests.swift`, `Tests/FlareModelTests/HugeDocumentBudgetTests.swift` | LM-0c5 | the helper reports median and p95 over N runs; QB-L7 and the model half of QB-L10 asserted now; QB-L5 and QB-L6 run on the fakes report-only (bounding boxes measure nothing real) and become asserts in IN-1 | QB-L5, QB-L6, QB-L7, QB-L10 |

### 7.2 track:ui: SuiteUI and harnesses (line:suiteui)

Goldens are contact sheets (one PNG per component per appearance) under
`Tests/AppSnapshotTests/Golden/`, recorded on CI (rubric section 6). A
SuiteUI component is recorded in Light, Dark, Light + Increase Contrast and
Dark + Increase Contrast, because `SuiteWindow` apps use it too.

| id | title | owns | deps | acceptance | quality |
|---|---|---|---|---|---|
| S0 | Visual-language tokens: surfaces, ladder, text, accent, state colors in four appearances as literal hex; radii, spacing, insets, sizes, type, motion | `Sources/SuiteUI/Tokens.swift`, `Tests/SuiteUITests/TokensTests.swift` | G0 | every token in design.md's Visual language exists with that value; `proDensityRowsAreTightAndFitTheInspector` is rewritten as `editorRowsMatchTheVisualLanguage` (34 pt rows, no label column); the window minimum still fits | QB-V6 (`TokensTests.contrast` over the full table), QB-F6 |
| QH-1 | `FrameProbe`: input-to-display timings in frames late, plus marks (preview drawn before mouse-up, progress shown, animation ended, autosaved, state switched), as the `suite.perf` JSON value under a launch flag | `Sources/SuiteUI/FrameProbe.swift`, `Tests/SuiteUITests/FrameProbeTests.swift` | – | percentile math on fixed samples; frames late computed against the given refresh interval; disabled records nothing | harness for QB-L1–L4, L9–L12, F2, F5 |
| QH-2 | Golden compare: baselines by `#filePath`; a mismatch writes the actual and a diff PNG into `.build/snapshots/` (the existing `snapshots` artifact) | `Tests/AppSnapshotTests/GoldenImage.swift`, `Tests/AppSnapshotTests/GoldenImageTests.swift`, `Tests/AppSnapshotTests/Golden/README.md` | – | an identical image passes; one pixel over tolerance fails and writes both PNGs; a missing baseline fails and writes the actual | harness for QB-V2–V5 |
| QH-2b | Snapshot host at backing scale 2 with the four appearances (`.aqua`, `.darkAqua`, `.accessibilityHighContrastAqua`, `.accessibilityHighContrastDarkAqua`) | `Tests/AppSnapshotTests/SnapshotHost.swift`, `Tests/AppSnapshotTests/SnapshotHostTests.swift` | QH-2 | a 100 × 50 pt view renders 200 × 100 px; a 1 pt hairline is 2 px wide; the high-contrast host resolves a dynamic token to its IC value | QB-V2, V3, V5 |
| QH-4 | Journey files and helpers: the Journey template compiles `UITests/Journey*.swift` and `UITests/<target>*.swift`; input, velocity-drag and perf helpers | `project.yml`, `UITests/Journey+Input.swift`, `UITests/FlareJourneyTests+Smoke.swift` | – | the CI log lists `FlareSmokeJourneys.testSecondFileRuns` from the second file; Design, Photo, Library and Halo journeys still run | – |
| S1 | Bar slider: `InspectorSliderRow` restyle (label inside, fill, marker, ticks, value with unit, keyframe slots), ScrubField semantics kept | `Sources/SuiteUI/InspectorRows.swift`, `Sources/SuiteUI/ScrubField.swift`, `Tests/SuiteUITests/SliderBarTests.swift`, `Tests/AppSnapshotTests/SuiteSliderSnapshots.swift` | S0, QH-2b | value math from `ScrubValue`; arrows, Shift, Option, Home, End; the row width is the same keyed or not | goldens: rest, hover, focus, dragging, editing, disabled, keyed, mixed (QB-V5) |
| S2 | `KeyframeButton` (idle, animated, keyed here, disabled; the add-or-remove-key diamond) | `Sources/SuiteUI/KeyframeButton.swift`, `Tests/SuiteUITests/KeyframeButtonTests.swift`, `Tests/AppSnapshotTests/SuiteKeyframeSnapshots.swift` | S0, QH-2b | each `KeyState` maps to a symbol, a color and a VoiceOver value | goldens per state |
| S3 | Section header, filled `InspectorRow`, filled `InspectorPickerRow`, checkbox toggle row; one color row (`InspectorColorRow` with the pill swatch; `InspectorColorWellRow` becomes a thin wrapper over it) | `Sources/SuiteUI/InspectorRows.swift`, `Sources/SuiteUI/ColorWell.swift`, `Tests/AppSnapshotTests/SuiteRowsSnapshots.swift` | S1, QH-2b | old call sites compile unchanged; Photo's color rows render through the one row | goldens; design lint passes |
| S4 | `InspectorHeader` info card (new `facts:` init; `details:` stays until callers move) | `Sources/SuiteUI/InspectorHeader.swift`, `Tests/AppSnapshotTests/SuiteHeaderSnapshots.swift` | S0, QH-2b | both inits draw; values right-aligned, tabular | golden |
| S5 | `PresetGrid`, `ChipRow` (toggle chips too), `InspectorAction` | `Sources/SuiteUI/PresetGrid.swift`, `Sources/SuiteUI/ChipRow.swift`, `Sources/SuiteUI/InspectorAction.swift`, `Tests/SuiteUITests/PresetGridTests.swift`, `Tests/AppSnapshotTests/SuitePresetsSnapshots.swift` | S0, QH-2b | arrow keys move in the grid; a toggle chip reports on and off | goldens per state |
| S6 | `EditorBarItem` outlined and `.primary`; save status; `EmptyStateView`'s button in the primary style | `Sources/SuiteUI/EditorTopBar.swift`, `Sources/SuiteUI/EmptyStateView.swift`, `Tests/AppSnapshotTests/SuiteTopBarSnapshots.swift` | S0, QH-2b | primary hover lightens and never greys | golden; contrast of the primary label |
| S7 | `ViewerStatusBar` restyled into pills (name and API kept, so Photo, Design and Halo need no change) and a new `TransportCapsule` | `Sources/SuiteUI/ViewerStatusBar.swift`, `Sources/SuiteUI/TransportCapsule.swift`, `Tests/AppSnapshotTests/SuiteStatusSnapshots.swift` | S0, QH-2b | `ViewerZoom.percentText` unchanged; toggle and warning pills | goldens |
| S8 | `SegmentedTabs` as a capsule; `ToolbarGroup` rail colors | `Sources/SuiteUI/SegmentedTabs.swift`, `Sources/SuiteUI/ToolbarGroup.swift`, `Tests/AppSnapshotTests/SuiteTabsSnapshots.swift` | S0, QH-2b | still a `Picker` underneath; Photo and Design PNGs listed in the PR | goldens |
| S9 | `EditorShell(timeline:)` bottom slot, resizable and collapsible | `Sources/SuiteUI/EditorShell.swift`, `Tests/SuiteUITests/EditorShellTests.swift`, `Tests/AppSnapshotTests/SuiteShellSnapshots.swift` | S0, QH-2b | apps without a timeline unchanged; the window minimum still fits | golden |
| S10 | `TimelineStrip` restyle: lane beds, name chips with eye and lock, key states, easing segments, playhead time pill, recording ring, empty text; fixes #62, #61 | `Sources/SuiteUI/TimelineStrip.swift`, `Sources/SuiteUI/FrameMapping.swift`, `Tests/AppSnapshotTests/SuiteTimelineSnapshots.swift` | S9 | Halo PNGs listed; #219 long timeline not blank; 300 lanes lay out lazily | goldens per state |
| S11 | `TimelineStrip` key drag (one gesture, delta out), keyboard key select, VoiceOver (#63) | `Sources/SuiteUI/TimelineStrip.swift`, `Tests/SuiteUITests/TimelineKeyDragTests.swift` | S10 | drag reports a delta in frames; ←/→ moves the selection | QB-L3 hook |
| S12 | `SelectionHandles`, `PathMarks`, `MotionPathMarks`, `GhostLayer`, guide marks | `Sources/SuiteUI/CanvasMarks.swift`, `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Tests/SuiteUITests/CanvasMarksTests.swift`, `Tests/AppSnapshotTests/SuiteMarksSnapshots.swift` | S0, QH-2b | handle hit rects are the hit token at any zoom; lines pixel-aligned; smooth and corner anchors differ in shape | QB-V3 hairline golden |
| S13 | `CurveEditor` (two handles, the playing dot, keyboard nudges) | `Sources/SuiteUI/CurveEditor.swift`, `Tests/SuiteUITests/CurveEditorTests.swift`, `Tests/AppSnapshotTests/SuiteCurveSnapshots.swift` | S0, QH-2b | handle x clamps to 0...1; ↑/↓ nudge; the dot stops under Reduce Motion (probe mark) | QB-L2 hook, QB-F5 |
| S14 | `NodeGraph` (nodes at the positions it is given, arrows with chips, warning badges) | `Sources/SuiteUI/NodeGraph.swift`, `Tests/SuiteUITests/NodeGraphTests.swift`, `Tests/AppSnapshotTests/SuiteGraphSnapshots.swift` | S0, QH-2b | arrow endpoints meet node edges; a self-loop draws | golden |
| S15 | `LayerList`: a non-split container that wraps the existing `SidebarRow` and `SidebarItem` rows with sections, drag to reorder and rename; #146 dimmed rows added once, in `SidebarRow` | `Sources/SuiteUI/LayerList.swift`, `Sources/SuiteUI/SidebarRow.swift`, `Tests/SuiteUITests/LayerListTests.swift`, `Tests/AppSnapshotTests/SuiteLayerListSnapshots.swift` | S0, QH-2b | Design's sidebar still renders; jscpd stays under 0.8% | golden |
| S16 | C4 `suiteui` description names the new components | `docs/c4/model.json` | S1–S15 | every new SuiteUI file is under the component's paths and named in its description | – |

### 7.3 track:ui: Flare on fakes (line:flare)

Order follows the core loop first (rubric 1.7): shell, menus, stage, draw,
key, timeline, save, then the panels. Engine-direct use cases have no fake,
so F7a needs LM-7 (playback state) and F17a needs LM-1 (files); both are
first-wave logic tasks with no engine dependency, so the UI line never waits
on creative-core.

| id | title | supersedes | owns | deps | acceptance (journey) | quality |
|---|---|---|---|---|---|---|
| F1a | Move Flare onto `EditorShell`: split `FlareApp.swift`, launch arguments, Open Sample, stub views for every slot | – | `Sources/FlareApp/FlareApp.swift`, `Sources/FlareApp/FlareWindow.swift`, `Sources/FlareApp/FlareEditor.swift`, `Sources/FlareApp/FlareLaunch.swift`, `Sources/FlareApp/FlareStage.swift`, `Sources/FlareApp/FlareTimeline.swift`, `Sources/FlareApp/FlareInspector.swift`, `Sources/FlareApp/FlareLayersPanel.swift`, `Sources/FlareApp/FlareLibraryPanel.swift`, `Sources/FlareApp/FlareInteractions.swift`, `Sources/FlareApp/FlareRecording.swift`, `UITests/FlareJourneyTests.swift`, `Tests/AppSnapshotTests/AppSnapshotTests.swift`, `docs/c4/model.json` | LM-0a3, S9, QH-4 | J0 | `flare-open` golden |
| F1b | `FlareIntent` with every case, the router, area stubs, control identifiers and `suite.controls` | – | `Sources/FlareApp/FlareIntent.swift`, `Sources/FlareApp/FlareWindow+Router.swift`, `Sources/FlareApp/FlareControls.swift`, `Sources/FlareApp/FlareWindow+File.swift`, `Sources/FlareApp/FlareWindow+Edit.swift`, `Sources/FlareApp/FlareWindow+Stage.swift`, `Sources/FlareApp/FlareWindow+Tools.swift`, `Sources/FlareApp/FlareWindow+View.swift`, `Sources/FlareApp/FlareWindow+Inspector.swift`, `Sources/FlareApp/FlareWindow+Timeline.swift`, `Sources/FlareApp/FlareWindow+Layers.swift`, `Sources/FlareApp/FlareWindow+Library.swift`, `Sources/FlareApp/FlareWindow+Interactions.swift`, `Sources/FlareApp/FlareWindow+Export.swift`, `Sources/FlareApp/FlareWindow+Assist.swift` | F1a | J0 still green; every area's `help(for:)` returns "Not built yet (Fn)" | QB-F1 |
| F2 | Menu bar `FlareCommands`: every item bound to an intent, disabled with the area's reason; Undo and Redo named | #15 (menu half) | `Sources/FlareApp/FlareCommands.swift`, `UITests/FlareJourneyTests+Menus.swift`, `UITests/FlareJourneyTests+EveryControl.swift` | F1b | J1, J29 | QB-F1 |
| F3a | Stage: draw list in a `Canvas` under `.drawingGroup()`, the overlay (draft, selection, ghosts, motion path, guides), `readOnly:` | #12, SuiteUI #6 | `Sources/FlareApp/FlareStage.swift`, `Sources/FlareApp/FlareStageOverlay.swift`, `Sources/FlareApp/FlareWindow+Stage.swift`, `Tests/AppSnapshotTests/FlareStageSnapshots.swift` | F1b, S12, LA-0, LM-0c1, QH-2b | stage goldens of `bounce` and `character` at 2x | QB-V1, QB-V2, QB-V3 |
| F3b | Select tool: click, Shift-click, marquee, the box, scale and rotate handles, move | #204 (move half) | `Sources/FlareApp/FlareStageSelection.swift`, `UITests/FlareJourneyTests+Select.swift` | F3a, F6a, LM-0a3 | J5 | QB-L1, QB-F2 |
| F3c | View: zoom, pan, rulers, guides | – | `Sources/FlareApp/FlareStageGuides.swift`, `Sources/FlareApp/FlareWindow+View.swift`, `UITests/FlareJourneyTests+View.swift` | F3a, LM-0a4 | J14 | QB-L1 (pan) |
| F4a | Tools: Rectangle, Ellipse, Pen with the live draft and one-key shortcuts | #203, #206 (UI) | `Sources/FlareApp/FlareStageTools.swift`, `Sources/FlareApp/FlareWindow+Tools.swift`, `UITests/FlareJourneyTests+Draw.swift` | F3a, F7a, LM-0a2b | J3 | QB-L1, QB-F2 |
| F4b | Direct Select: anchors, handles, item move | – | `Sources/FlareApp/FlareStageDirect.swift`, `UITests/FlareJourneyTests+DirectSelect.swift` | F4a | J4 | QB-L1 |
| F5 | Auto-key: the recording ring on stage and timeline and the top-bar dot | #204 (UI) | `Sources/FlareApp/FlareRecording.swift`, `UITests/FlareJourneyTests+Animate.swift` | F3b, F7a, LM-0b1 | J6 | QB-F2, QB-F3 |
| F6a | Properties inspector: title, info card, TRANSFORM rows with keyframe buttons, Mixed | #13, #186 | `Sources/FlareApp/FlareInspector.swift`, `Sources/FlareApp/FlareInspectorTransform.swift`, `Sources/FlareApp/FlareWindow+Inspector.swift`, `UITests/FlareJourneyTests+Inspector.swift`, `Tests/AppSnapshotTests/FlareInspectorSnapshots.swift` | F1b, S1, S2, S4, LM-0b1, QH-2b | J7 | QB-L2, QB-F4 |
| F6b | FILL (solid editing, gradient read-only) and STROKE | – | `Sources/FlareApp/FlareInspectorFill.swift`, `UITests/FlareJourneyTests+FillStroke.swift`, `Tests/AppSnapshotTests/FlareFillSnapshots.swift` | F6a, S3 | J8 | QB-F1; gradient golden |
| F6c | SCENE section (size, background, fps, duration, presets) and INSTANCE section | – | `Sources/FlareApp/FlareInspectorScene.swift`, `Sources/FlareApp/FlareInspectorInstance.swift`, `Tests/AppSnapshotTests/FlareSceneSnapshots.swift` | F6b, S5, LM-0c1 | goldens; its journey steps are in J16 and J18 | QB-F1 |
| F7a | Timeline: lanes, diamonds, scrub, readouts, empty text, symbol timeline | #11 (UI) | `Sources/FlareApp/FlareTimeline.swift`, `Sources/FlareApp/FlareWindow+Timeline.swift`, `UITests/FlareJourneyTests+Timeline.swift`, `Tests/AppSnapshotTests/FlareTimelineSnapshots.swift` | F1b, S10, LM-0b2, LM-7, QH-2b | J9 | QB-L3 |
| F7b | Transport, Space to play, loop, actual-fps pill (ticked by `TimelineView(.animation)` until IN-2 brings `PlaybackDriver`) | #11 (UI) | `Sources/FlareApp/FlareTransport.swift`, `UITests/FlareJourneyTests+Playback.swift` | F7a, S7 | J10 | QB-L4 report-only until IN-2 |
| F8 | Timeline editing: retime, delete, insert and remove frames, labels, key context menu | – | `Sources/FlareApp/FlareTimelineEdit.swift`, `UITests/FlareJourneyTests+TimelineEdit.swift` | F7b, S11 | J11 | QB-F3 |
| F9 | Easing popover and the TIMING row | – | `Sources/FlareApp/FlareEasingPopover.swift`, `Sources/FlareApp/FlareInspectorTiming.swift`, `UITests/FlareJourneyTests+Easing.swift` | F8, F6c, S13 | J12 | QB-L2 (handle) |
| F10 | Onion skin popover and toggles; motion path toggle | – | `Sources/FlareApp/FlareOnionPopover.swift`, `UITests/FlareJourneyTests+Onion.swift` | F3c, F7a, LM-0b2 | J13 | QB-L4 with ghosts |
| F11a | Layers tab with scenes on top, built on `LayerList` | sidebar of today | `Sources/FlareApp/FlareLayersPanel.swift`, `Sources/FlareApp/FlareWindow+Layers.swift`, `Sources/FlareApp/FlareLayerItems.swift` (deleted), `Tests/AppSnapshotTests/FlareLayersSnapshots.swift` (deleted), `Tests/AppSnapshotTests/FlareLayersPanelSnapshots.swift`, `UITests/FlareJourneyTests+Scenes.swift` | F1b, F6c, S15, LM-0a4 | J16 | QB-F1 |
| F11b | New Animation sheet | – | `Sources/FlareApp/FlareNewSheet.swift`, `Sources/FlareApp/FlareWindow+File.swift`, `UITests/FlareJourneyTests+NewSheet.swift` | F1b, S5 | J2 | QB-F1 |
| F12a | Library tab: symbols, Convert to Symbol, place, edit in place, breadcrumb, empty text | #14 | `Sources/FlareApp/FlareLibraryPanel.swift`, `Sources/FlareApp/FlareBreadcrumb.swift`, `Sources/FlareApp/FlareWindow+Library.swift`, `UITests/FlareJourneyTests+Symbols.swift`, `Tests/AppSnapshotTests/FlareLibrarySnapshots.swift` | F3b, F6b, F7a, S5, S15, LM-0c1 | J17 | QB-V4 (LM-10 render diff) |
| F12b | INSTANCE playback steps and swatches | – | `Sources/FlareApp/FlareLibrarySwatches.swift`, `UITests/FlareJourneyTests+Library.swift` | F12a, F6c | J18 | QB-F1 |
| F13a | Interactions editor: mode switch, graph from `MachineLayout`, machine menu, empty text | – | `Sources/FlareApp/FlareInteractions.swift`, `Sources/FlareApp/FlareWindow+Interactions.swift`, `UITests/FlareJourneyTests+Machines.swift`, `Tests/AppSnapshotTests/FlareInteractionsSnapshots.swift` | F1b, S14, LM-0c2, LM-15 | J19 | QB-F1 |
| F13b | Interactions inspector: state, transition and condition, inputs and defaults, refusals inline | – | `Sources/FlareApp/FlareMachineInspector.swift`, `UITests/FlareJourneyTests+Transitions.swift` | F13a, S1, S3 | J20 | QB-F2 |
| F14 | Interactions preview: read-only stage, input controls, active highlight | – | `Sources/FlareApp/FlareMachinePreview.swift`, `UITests/FlareJourneyTests+Preview.swift` | F13b, F3a, F7b | J21 | switch on the next tick (probe) |
| F15a | Export sheet: tabs, options, warnings, progress, Reveal | – | `Sources/FlareApp/FlareExportSheet.swift`, `Sources/FlareApp/FlareWindow+Export.swift`, `UITests/FlareJourneyTests+Export.swift`, `Tests/AppSnapshotTests/FlareExportSnapshots.swift` | F2, S5, LM-0c3 | J22 | QB-L8 on the fake |
| F15b | Export failure, Cancel, Replace | – | `Sources/FlareApp/FlareExportStatus.swift`, `UITests/FlareJourneyTests+ExportErrors.swift` | F15a | J23 | QB-F2 |
| F16a | Assist popover: prompt, progress, proposal rows, Preview, Accept, Reject | – | `Sources/FlareApp/FlareAssistPopover.swift`, `Sources/FlareApp/FlareWindow+Assist.swift`, `UITests/FlareJourneyTests+Assist.swift` | F2, F3a, F7a, LM-0c4 | J24 | QB-L9 |
| F16b | Assist failure, timeout, empty and text messages | – | `Sources/FlareApp/FlareAssistErrors.swift`, `UITests/FlareJourneyTests+AssistErrors.swift` | F16a | J25 | QB-F2 |
| F17a | Open and save panels, title, unsaved dot, Open Recent, close prompt | #15 (open), #205 (UI) | `Sources/FlareApp/FlareFilePanels.swift`, `Sources/FlareApp/FlareWindow+File.swift`, `UITests/FlareJourneyTests+Files.swift` | F11b, F4a, F7b, LM-1 | J26 | QB-F1 |
| F17b | Open errors, load progress, the text pill | – | `Sources/FlareApp/FlareOpenStatus.swift`, `UITests/FlareJourneyTests+OpenErrors.swift` | F17a, LM-0c3 | J27 | QB-L9 |
| F17c | Save failure and the recovery offer | – | `Sources/FlareApp/FlareRecovery.swift`, `UITests/FlareJourneyTests+Recovery.swift` | F17b, LA-3 | J28 | no data loss |
| F18 | Edit menu actions and the pasteboard | – | `Sources/FlareApp/FlareWindow+Edit.swift`, `Sources/FlareApp/FlarePasteboard.swift`, `UITests/FlareJourneyTests+Edit.swift` | F2, F3b, LM-0a4 | J15 | QB-F3 |
| QH-5 | Perf journeys P1–P4, report-only: attach the perf JSON, assert only the sample counts | – | `UITests/FlareJourneyTests+Perf.swift` | QH-1, QH-4, F3c, F4a, F6a, F7b, LM-0c5 | P1–P4 produce JSON on CI | QB-L1–L4 (data) |
| QH-6 | Perf journeys P5–P7, report-only | – | `UITests/FlareJourneyTests+PerfLarge.swift` | QH-5, F11a, F17b | P5–P7 produce JSON on CI | QB-L9–L12 (data) |
| QH-7 | Set the gates: p95 from ten CI runs times the margin in rubric section 6, as constants; the rubric's CI-gate column updated in the same PR | – | `UITests/Journey+Budgets.swift`, `docs/review-rubric.md` | QH-5, QH-6, ten green CI runs | P1–P7 assert their gates | QB-L1–L4, L9–L12 |

### 7.4 track:logic: engine gaps (creative-core, label `needs-core`)

| id | title | owns (core) | deps | acceptance | quality |
|---|---|---|---|---|---|
| LC-1 | `Scene.renderList(at:symbols:)` (G45); SVG exporter moved onto it; `Transform` doc fix; C4 description | `Sources/FlareCore/RenderList.swift`, `Sources/FlareCore/Export/SVGExporter.swift`, `Sources/FlareCore/Geometry.swift`, `Tests/FlareCoreTests/RenderListTests.swift`, `docs/c4/model.json` | – | SVG golden byte-identical; hidden layers absent; nested instance opacity multiplies; text items listed with no path | QB-L6 (LC-14) |
| LC-2 | Topmost hit with address, marquee, tolerance | `Sources/FlareCore/HitTest.swift`, `Sources/FlareCore/HitQuery.swift`, `Tests/FlareCoreTests/HitQueryTests.swift` | LC-1 | 4 pt from a 0-width stroke hits; marquee returns paint order; hidden, locked and text skipped | QB-L5 |
| LC-3 | World bounds of layers, instances and selections including stroke | `Sources/FlareCore/ShapeBounds.swift`, `Sources/FlareCore/WorldBounds.swift`, `Tests/FlareCoreTests/WorldBoundsTests.swift` | LC-1 | rotated rect bounds within 1e-9; stroke widens by width/2 | – |
| LC-4 | Path builders: rect with corner radius, ellipse (#182), polygon, star | `Sources/FlareCore/PathBuilders.swift`, `Tests/FlareCoreTests/PathBuilderTests.swift` | – | ellipse bounds within 1e-6 and four cubics; radius clamps to half the short side | QB-V1 |
| LC-5 | Q5c: keyframe commands take `owner:`; remove the scene-only shim | `Sources/FlareCore/KeyframeCommands.swift`, `Sources/FlareCore/Commands.swift`, `Sources/FlareCore/LayerCommand.swift`, `Sources/FlareCore/Document.swift`, `Tests/FlareCoreTests/KeyframeOwnerTests.swift` | – | symbol layer keys set, move and undo exactly; old envelopes still decode | – |
| LC-6 | Q5e: `AddInstance`, `RemoveInstance`, `SetInstanceTransform` (drag merge), `SetInstancePlayback`; finite transform validation | `Sources/FlareCore/InstanceCommands.swift`, `Sources/FlareCore/FlareFormat.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/InstanceCommandTests.swift` | – | a 100-step drag is one undo entry; NaN fails validate; `firstFrame < 0` throws | QB-L7 |
| LC-7 | `SetShapeStroke`, `SetShapePath`, `DuplicateLayer` | `Sources/FlareCore/ShapeCommands.swift`, `Sources/FlareCore/LayerCommands.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/StrokePathDuplicateTests.swift` | LC-6 (registry line) | undo exact; negative width throws; duplicate gets a fresh id and "<name> copy" | – |
| LC-8 | `SetSceneCanvas`, `RenameScene`, `ReorderScene` | `Sources/FlareCore/SceneCommands.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/SceneEditCommandTests.swift` | LC-7 (registry line) | undo exact; zero size throws; reorder out of range throws | – |
| LC-9 | `Layer.onionFrames(at:before:after:)` (G46) | `Sources/FlareCore/Onion.swift`, `Tests/FlareCoreTests/OnionTests.swift` | – | frame 10 with 2 and 2 gives [8, 9, 11, 12]; clamps at the edges | – |
| LC-10 | `SetKeyframe` merge for scrubs; `MoveGuide` merge | `Sources/FlareCore/Commands.swift`, `Sources/FlareCore/GuideCommands.swift`, `Tests/FlareCoreTests/ScrubMergeTests.swift` | LC-5 | 200 scrub steps leave one command holding the first old and the last new value | QB-L7 |
| LC-11a | Public non-throwing `StateMachine.issues(in:)` (severity, message, state id, transition index); `validateStateMachines` throws its first error with today's message | `Sources/FlareCore/StateMachineIssues.swift`, `Sources/FlareCore/StateMachineValidation.swift`, `Tests/FlareCoreTests/StateMachineIssuesTests.swift` | – | every existing validation test passes; an unreachable state is a warning; a dangling transition is an error on its index | – |
| LC-11b | Machine commands: add (with its first state), rename, remove, set initial | `Sources/FlareCore/StateMachineCommands.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/MachineCommandTests.swift` | LC-11a, LC-8 (registry line) | each undo exact; fuzz added to `CommandFuzzTests` | – |
| LC-11c | State commands: add, update, remove (refused while a transition uses it or it is initial) | `Sources/FlareCore/MachineStateCommands.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/MachineStateCommandTests.swift` | LC-11b | the refusal names the transition; undo exact | – |
| LC-11d | Transition commands: add, update, remove | `Sources/FlareCore/TransitionCommands.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/TransitionCommandTests.swift` | LC-11c | an update to an unknown state throws; undo exact | – |
| LC-11e | Input commands: add, update default, remove (refused while a condition uses it) | `Sources/FlareCore/MachineInputCommands.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/MachineInputCommandTests.swift` | LC-11d | a kind change through update throws; undo exact | – |
| LC-12 | State machine runtime player | `Sources/FlareCore/MachinePlayer.swift`, `Tests/FlareCoreTests/MachinePlayerTests.swift` | LC-11a | the same input script gives the same frame trace | deterministic replay |
| LC-12b | `RenameSymbol` | `Sources/FlareCore/SymbolCommands.swift`, `Sources/FlareCore/CommandRegistry.swift`, `Tests/FlareCoreTests/RenameSymbolTests.swift` | LC-8 (registry line; the LC-11 chain no longer blocks it) | undo exact; empty name throws | – |
| LC-13 | Lottie opacity, scale, rotation tracks (G52); gradient stop alpha | `Sources/FlareCore/Export/LottieExporter.swift`, `Tests/FlareCoreTests/LottieTracksTests.swift` | – | golden JSON per track | QB-L8 |
| LC-14 | Core budgets: render list per frame, hit per move, drag perform step, export of the reference scene | `Tests/FlareCoreTests/FlareBudgetTests.swift` | LC-1, LC-2, LC-6, LC-10 | budgets asserted with the debug factor in rubric section 6 | QB-L5–L8 |

### 7.5 track:logic: FlareModel live conformances and platform files (line:flare)

| id | title | supersedes | owns | deps | acceptance | quality |
|---|---|---|---|---|---|---|
| LM-1 | Files: open through `load`, save data, file name, dirty flag, Open Recent list, autosave due time, a message per `FormatError` | #15, #205 (model) | `Sources/FlareModel/FlareFiles.swift`, `Tests/FlareModelTests/FlareFilesTests.swift` | LM-0a3 | bad data throws and keeps the document; each `FormatError` maps to section 3.3's text; save then open is byte-identical | – |
| LM-2 | `LiveStage`, `LiveHits`; the `FixtureEdit` source scan | #12 (model) | `Sources/FlareModel/Live/LiveStage.swift`, `Sources/FlareModel/Live/LiveHits.swift`, `Tests/FlareModelTests/LiveStageTests.swift`, `Tests/FlareModelTests/LiveConformanceTests.swift` | LC-1, LC-2, LC-3 | live and fake agree on `bounce`; instances nested two deep all draw (`crowd` once LM-0c5 lands); `noFixtureEditInLive` passes | QB-L5, QB-L6, QB-L11 (model) |
| LM-3 | `LiveShapes`: builders, pen curves, box gestures, path edit, duplicate, copy, paste | #203, #206 (model) | `Sources/FlareModel/Live/LiveShapes.swift`, `Tests/FlareModelTests/LiveShapesTests.swift` | LC-4, LC-7, LM-0a2b | Shift gives equal sides; a pen drag makes a smooth point with G1 continuity; a commit is one entry | QB-V1 |
| LM-4 | `LiveProperties` with the section 2 rule and stroke | #13, #204 (model) | `Sources/FlareModel/Live/LiveProperties.swift`, `Tests/FlareModelTests/LivePropertiesTests.swift` | LC-5, LC-7, LC-10, LM-0b1 | keys at 0 and 24 give `placement(at: 12).x == 60`; 120 `setValue` calls give 1 entry holding 1 command; the LM-0b1 rule tests pass on live | QB-L7 |
| LM-5 | `LiveKeyframes` | – | `Sources/FlareModel/Live/LiveKeyframes.swift`, `Tests/FlareModelTests/LiveKeyframesTests.swift` | LC-5, LM-0b2 | moving a key onto another throws and changes nothing | – |
| LM-6 | `LiveEasing` | – | `Sources/FlareModel/Live/LiveEasing.swift`, `Tests/FlareModelTests/LiveEasingTests.swift` | LM-0b2 | preset table golden; curve endpoints exact | – |
| LM-7 | Playback: frame, playing, loop, `advance(elapsed:)`, the symbol's range while editing in place | #11 (model) | `Sources/FlareModel/FlarePlayback.swift`, `Tests/FlareModelTests/FlarePlaybackTests.swift` | LM-0a3 | 2.5 s at 24 fps looping lands on 12; without loop it stops on the last frame; inside a 12-frame symbol it loops 0–11 | – |
| LM-8 | `LiveOnion` and the motion path | – | `Sources/FlareModel/Live/LiveOnion.swift`, `Tests/FlareModelTests/LiveOnionTests.swift` | LC-9, LM-2 | ghost opacity falls monotonically; the path point at f equals the sampled position; `ticksFollowEasing`: with ease-out, tick spacing shrinks toward the end key | QB-L6 with ghosts |
| LM-9 | `LiveScenes` with guides | – | `Sources/FlareModel/Live/LiveScenes.swift`, `Tests/FlareModelTests/LiveScenesTests.swift` | LC-8, LC-10, LM-0a2 | add, rename, reorder, canvas undo exactly; a guide drag is one command | – |
| LM-10 | `LiveLibrary` with usage counts and instance playback | #14 (model) | `Sources/FlareModel/Live/LiveLibrary.swift`, `Tests/FlareModelTests/LiveLibraryTests.swift` | LC-6, LC-12b, LM-2, LM-0c1 | convert then render list diff is empty; usage counts nested instances | QB-V4 |
| LM-11 | `LiveMachines` | – | `Sources/FlareModel/Live/LiveMachines.swift`, `Tests/FlareModelTests/LiveMachinesTests.swift` | LC-11e, LM-0c2 | removing a state a transition uses is refused with the transition named and nothing changed; an unreachable state is a warning on that state | – |
| LM-12 | `LivePreview` | – | `Sources/FlareModel/Live/LivePreview.swift`, `Tests/FlareModelTests/LivePreviewTests.swift` | LC-12, LM-0c2 | the trace matches the player | – |
| LM-13a | `LiveExport`: SVG frame, Lottie, PNG sequence through the rasterizer, cancellation | – | `Sources/FlareModel/Live/LiveExport.swift`, `Tests/FlareModelTests/LiveExportTests.swift` | LC-13, LM-2, LM-0c3 | 0–48 step 2 gives 25 files; cancel leaves no files | QB-L8 |
| LM-13b | Export never throws for content v1 can't write: text removed from a copy before export, the scan's warnings attached | – | `Sources/FlareModel/Live/LiveExportCleaning.swift`, `Tests/FlareModelTests/LiveExportWarningsTests.swift` | LM-13a | `showcase` exports SVG, Lottie and PNG with the four warnings; one test per case | never a silent drop |
| LM-14 | `LiveAssist` behind a provider protocol, disabled until one exists | – | `Sources/FlareModel/Live/LiveAssist.swift`, `Tests/FlareModelTests/LiveAssistTests.swift` | LM-0c4 | with no provider, `unavailableHelp` is set; a stub provider's proposal goes through the shared apply | QB-L9 |
| LA-0 | `StagePath`: `Path` and `Matrix` to `CGPath`, colors to `CGColor(srgbRed:…)` | – | `Sources/FlareApp/StagePath.swift`, `Tests/AppSnapshotTests/StagePathTests.swift` | LM-0a1 | each `cubic` maps to one `addCurve`; element counts equal; the design lint passes | QB-V1 |
| LA-1 | `StageRasterizer` (CoreGraphics) on `StagePath` | – | `Sources/FlareApp/StageRasterizer.swift`, `Tests/AppSnapshotTests/RasterizerTests.swift` | LA-0, QH-2b | 2x output is twice the pixel size; transparent corners have alpha 0 | QB-V4: a rasterized frame equals the stage golden |
| LA-2 | `PlaybackDriver` on `NSScreen.displayLink` | – | `Sources/FlareApp/PlaybackDriver.swift`, `Tests/AppSnapshotTests/PlaybackDriverTests.swift` | LM-7 | stops when paused; uses the link's target timestamp, not wall time | QB-L4 |
| LA-3 | Autosave writer and recovery file, off the main thread | – | `Sources/FlareApp/FlareAutosave.swift`, `Tests/AppSnapshotTests/AutosaveTests.swift` | LM-1 | writes 30 s after the last edit and on quit; a recovery file is removed after a clean save | no data loss |

### 7.6 track:integrate (line:flare)

Each one changes its members of `FlareServices.live` from the fake to the
live conformance, flips its journeys from `-FlareFixture <name>` to
`-FlareSample <name>`, and reruns them and their perf tests. All start after
the captain approves the UI (gate G2).

| id | title | swaps | deps | acceptance | quality |
|---|---|---|---|---|---|
| IN-1 | Stage, hits, shapes, properties | `stage`, `hits`, `shapes`, `properties` | LM-2, LM-3, LM-4, F3a, F3b, F4a, F5, F6a, F6b, F18 | J3, J5–J8, J15 green live (J4 goes live with F4b) | P1, P2; QB-L5 and QB-L6 model budgets now asserted |
| IN-2 | Timeline, easing, playback driver | `keyframes`, `easing` | LM-5, LM-6, LM-7, LA-2, F7a, F7b, F8, F9 | J9–J12 green live | P3, P4 |
| IN-3 | Onion and motion path | `onion` | LM-8, F10 | J13 green live | P4 with ghosts |
| IN-4 | Scenes, guides and files | `scenes` | LM-1, LM-9, LA-3, F3c, F11a, F11b, F17a, F17b, F17c | J2, J14, J16, J26–J28 green live | P6, P7 |
| IN-5 | Library | `library` | LM-10, F6c, F12a, F12b | J17, J18 green live | P5; convert render diff 0 |
| IN-6 | Interactions | `machines`, `preview` | LM-11, LM-12, F13a, F13b, F14 | J19–J21 green live | switch on the next tick |
| IN-7 | Export | `export`; `FlareWindow` picks `StageRasterizer` | LM-13a, LM-13b, LA-1, F15a, F15b | J22, J23 green live; SVG parses with Foundation's `XMLParser` and Lottie as JSON with its required keys (no new dependency) | QB-V4, QB-L8 |
| IN-8 | Assist | `assist` | LM-14, the suite model provider, F16a, F16b | J24, J25 green live | QB-L9 |
| IN-9 | No-argument launch on `.live`; the "Preview data" pill goes; fixtures only by flag and for snapshots | what IN-1, IN-2 and IN-4 made live | IN-1, IN-2, IN-4 | J0 and the IN-1, IN-2 and IN-4 journeys green without `-FlareFixture`; no `Fake*` reachable from `.live` except members whose IN task is still open (a test lists them and fails when one is already live) | P1–P7 at their gates, report-only until QH-7 |

---

## 8. Order and parallelism

The foreman orders work from the deps columns above. This picture is the
same graph, drawn by lane.

```
Gate G0  captain approves this blueprint (this PR)
   │
   ├─ core lane (creative-core) ─────────────────────────────────────────────
   │   DOC-2
   │   LC-1 ─▶ LC-2, LC-3        LC-4      LC-9      LC-13
   │   LC-5 ─▶ LC-10
   │   LC-6 ─▶ LC-7 ─▶ LC-8 ─▶ LC-11b ─▶ LC-11c ─▶ LC-11d ─▶ LC-11e ─▶ LC-12b
   │   LC-11a ─▶ (LC-11b) ; LC-11a ─▶ LC-12
   │   LC-14 after LC-1, LC-2, LC-6, LC-10
   │
   ├─ model lane (creative-apps, logic) ─────────────────────────────────────
   │   LM-0a1 ─▶ LM-0a1b ─▶ LM-0a2 ─▶ LM-0a2b ─▶ LM-0a3 ─▶ LM-0a4
   │        ─▶ LM-0b1 ─▶ LM-0b2 ─▶ LM-0c1 ─▶ LM-0c2 ─▶ LM-0c3 ─▶ LM-0c4
   │        ─▶ LM-0c5 ─▶ QH-3
   │   LM-15 after LM-0a1b ; LA-0 after LM-0a1 ; LA-1 after LA-0, QH-2b
   │   LM-1, LM-7 after LM-0a3 ; LA-2 after LM-7 ; LA-3 after LM-1
   │   LM-2…LM-14 each after its LC tasks and its fake (deps column)
   │
   ├─ SuiteUI lane ───────────────────────────────────────────────────────────
   │   QH-1, QH-2 ─▶ QH-2b, QH-4 (any time)
   │   S0 ─▶ S1 ─▶ S3 ; S2 ; S4 ; S5 ; S6 ; S7 ; S8 ; S9 ─▶ S10 ─▶ S11 ;
   │         S12 ; S13 ; S14 ; S15            (S1–S15 also need QH-2b)
   │   S16 last
   │
   ├─ Flare UI lane ──────────────────────────────────────────────────────────
   │   F1a (LM-0a3, S9, QH-4) ─▶ F1b ─▶ F2 ─▶ F18 (also F3b, LM-0a4)
   │   F1b ─▶ F3a (S12, LA-0, LM-0c1) ─▶ F3b (F6a) ─▶ F5 (F7a, LM-0b1)
   │                                 ─▶ F3c (LM-0a4) ─▶ F10 (F7a, LM-0b2)
   │                                 ─▶ F4a (F7a, LM-0a2b) ─▶ F4b
   │   F1b ─▶ F6a (S1, S2, S4, LM-0b1) ─▶ F6b (S3) ─▶ F6c (S5, LM-0c1) ─▶ F9
   │   F1b ─▶ F7a (S10, LM-0b2, LM-7) ─▶ F7b (S7) ─▶ F8 (S11) ─▶ F9 (S13)
   │   F1b ─▶ F11b (S5) ─▶ F17a (F4a, F7b, LM-1) ─▶ F17b ─▶ F17c (LA-3)
   │   F11a (F6c, S15, LM-0a4) ; F12a (F3b, F6b, F7a, S15, LM-0c1) ─▶ F12b
   │   F13a (S14, LM-0c2, LM-15) ─▶ F13b ─▶ F14 (F3a, F7b)
   │   F15a (F2, S5, LM-0c3) ─▶ F15b ; F16a (F2, F3a, F7a, LM-0c4) ─▶ F16b
   │   QH-5 ─▶ QH-6 ─▶ (ten CI runs) ─▶ QH-7
   │
Gate G1  captain plays the fake build in the Review Room, per screen
Gate G2  captain says "UI approved" → the integrate mandate is set active
   IN-1 … IN-8 in matrix order; IN-9 once IN-1, IN-2 and IN-4 are live
Gate G3  quality bar: J0–J29 and P1–P7 green on live at their gates, goldens
         recorded; captain signs off
```

Parallel lanes:

- **creative-core**: LC tasks touch separate files except the
  `CommandRegistry.swift` line chain and `Commands.swift` (LC-5 then LC-10).
  FlareCore is a multi-file package, so the rest run in parallel.
- **SuiteUI**: S0 first, then S1–S15 in parallel, with S1 then S3 and S9,
  S10, S11 stacked.
- **Flare UI**: after F1b, the stage, inspector, timeline, file, library,
  interactions, export and assist chains above run side by side; each owns
  its own view files, journey file and area file.
- **Flare logic**: the LM-0 chain is strictly stacked (it shares
  `FlareServices.swift` and `FlareFixtures.swift`); each task is small, so
  the chain lands in a few agent-hours. After it, every LM task owns its own
  file.
- Halo shares `TimelineStrip` and FlareCore, so S10, S11 and LC-1 pay off
  there too.

Agent-time estimate (pilot rates, 3 to 10 minutes per PR worker; macOS CI
round trips are the slow part): SuiteUI and harnesses ~8–10 agent-hours,
Flare UI ~14–16, logic ~16–20, integrate ~4. Wall-clock is bound by macOS CI
concurrency and the captain's review gates, not by workers.

---

## 9. Decisions (captain, G0, 2026-10-13)

The captain approved this blueprint at G0 on 2026-10-13 and took the
recommended option in every row. Rows 1 to 6 change what gets built; the rest
are look and policy. The alternatives are kept as a record of what was
weighed, not as open options.

| # | Decision | Decided (captain, 2026-10-13) | Alternative not taken |
|---|---|---|---|
| 1 | Where a not-animated value lives | **Decided:** a property with one key or none counts as not animated (section 2); the format does not change. The stopwatch at the key's own frame also keys the last frame, so the person sees two diamonds | An LC task adding static layer values to the format (an optional field, older files still open); cleaner, about 2 more PRs in core plus exporter updates |
| 2 | What Select moves | **Decided:** Select moves whole layers; Direct Select edits the shapes inside a layer. Parts that animate apart go on their own layers or into a symbol | Per-shape transforms, which needs a transform on `Shape` in the format and in every exporter |
| 3 | Scope of v1 | **Decided:** anchor editing, cut, copy, paste, duplicate, autosave with recovery and Open Recent are in v1. Group, snapping, align, play range and GIF come later. State machines and Assist stay in v1 and are last in the order | Cutting state machines or Assist from v1 to ship the core loop sooner |
| 4 | Autosave | **Decided:** a recovery file in a `WindowGroup`, with a restore offer | `DocumentGroup` for system autosave, versions, Open Recent and one window per document; it changes the launch (an open panel at start), the journeys' launch arguments and the Photo and Design pattern |
| 5 | Inspector numbers | **Decided:** the bar slider replaces the system `Slider` and `Stepper` in inspectors, with full keyboard and VoiceOver parity; exact coordinates stay ScrubFields | Keeping the system controls and restyling only around them; less premium, closer to stock |
| 6 | Interactions | **Decided:** a mode inside the main window, because a second window can't share the one model | A real second window, which needs the model moved into a shared reference type first |
| 7 | Primary button blue | **Decided:** `#156BDB` fill under white text (5.05:1). It is visibly darker than the brand blue, so the Export button reads a shade deeper than the selection and playhead | Brand `#1877F2` fill at 4.23:1, which fails the 4.5:1 text rule for the 12 pt label (the icon helps but does not count) |
| 8 | Keyframe button shape | **Decided:** a 28 pt circle | The web reference's rounded square |
| 9 | Slider drag | **Decided:** relative scrub from the current value (Option fine, Shift coarse); click the value to type | Jumping to the pointer on press, as the web reference does |
| 10 | GIF export | **Decided:** later, with video | In v1; one more exporter task and a size budget |
| 11 | Toggle rows | **Decided:** a checkbox inside the filled row; the design lint enforces checkboxes and `scripts/` is protected | A switch, which needs a captain PR to the lint |
| 12 | Editor appearance | **Decided:** dark in both system appearances, as today; Light tokens exist for `SuiteWindow` apps | Following the system (one line in `EditorShell`) |
| 13 | Assist in v1 | **Decided:** ships on the fake, disabled with a reason in live until the suite model provider exists (Phase 3) | Holding the UI until then |
| 14 | Protocols where the engine already works | **Decided:** layers, files, playback timing and graph layout have no protocol (one conformer each) | A protocol and fake for each, about 200 more lines |

---

## 10. Still open

- **Gate numbers are not measured yet.** Every CI gate in rubric section 6
  is a placeholder until QH-7 sets it from ten CI runs. QH-5 and QH-6 ship
  report-only for that reason.
- **XcodeGen glob.** QH-4 assumes the template's sources accept
  `includes` globs; its acceptance proves it before any feature journey
  depends on it. If it fails, the fallback is one `UITests/Flare/` folder.
- **Synthesized drag density.** P1–P3 assume a 300 pt/s velocity drag gives
  at least 60 pointer events on the hosted runner. The sample-count assert
  catches it if not; then the speed or distance changes, not the budget.
- **Crash simulation.** J28 uses `XCUIApplication.terminate()` as the crash.
  If the runner sends a clean quit instead, the quit-time autosave makes the
  journey pass for the wrong reason; LA-3's test covers the kill case
  directly.
- **The suite model provider** (Phase 3) has no date, so IN-8 has none.
- **Belt allowlist.** The logic mandates' `swift test --filter Budget` check
  needs `swift` on the factory's command allowlist (see the process doc).

---

## 11. Pseudo-C4 (`flare/c4-planned.json`)

`docs/blueprints/flare/c4-planned.json` is Flare's planned C4 model in the
shape of `docs/c4/model.json`: every L3 component Flare v1 needs, read from
section 2, the task tables in section 7 and the four feature packets. Each
component has a name, a description, the source paths it owns, its
relationships (on the component; the model's `relationships` list holds
the container edges, as in `docs/c4/model.json`, then every component edge
flattened), `"authored": true`, and a status:

- **existing**: every path it lists is on `origin/dev` (956d946, 2026-10-14).
- **planned**: at least one of its paths is not on dev yet. Today every
  planned component has none of its files; components were split so that
  no component was half built on 956d946. A planned component turns
  existing in the PR that lands its last file.

What it holds:

| Container | Existing | Planned |
|---|---|---|
| FlareModel (`Sources/FlareModel/`) | workspace and services, contracts, stage gestures, Edit menu, animate, playback, scenes and layers, symbols, machines, files, export state, fakes, live easing | assist state, fake assist, large fixtures, live stage, live keys, live scenes, live onion and library, live interact, live export, live assist |
| FlareApp (`Sources/FlareApp/`) | today's shell (`FlareApp`, `FlareCommands`, layer items, easing inspector), stage path and playback driver | rasterizer, autosave and recovery, window and intents, stage, inspector, timeline, panels, interactions, file and edit, export, assist views |
| SuiteUI (the parts Flare uses; `line:suiteui` owns them) | tokens, window shell, content surfaces, editor shell, canvas and marks, inspector parts, timeline strip, segmented tabs | vector marks (S12), transport (S7), layer list (S15), node graph (S14), frame probe (QH-1) |
| FlareCore (creative-core) | document, engine, timeline and format; edit commands; hit test and shape bounds; exporters | render list, hit query, world bounds, builders and onion (LC-1 to LC-4, LC-9); instance commands (LC-6); machine commands and player (LC-11, LC-12) |

The FlareModel and FlareApp components together own every file under
`Sources/FlareModel/` and `Sources/FlareApp/` on dev exactly once, the same
rule `scripts/ci` applies to `docs/c4/model.json`. FlareCore paths are in
creative-core and list only the files the LC tasks name; their status was
read from creative-core `main` cfad97f, the revision dev resolves, not from
this repo.

This file is a plan, not the gate. `docs/c4/model.json` stays the checked
model: there each Flare target is still one component, and its description
grows in the PR that adds the behavior (section 2, C4 deltas). Nothing reads
this file in CI.

---

## 12. Quality bar

What "fast, aligned and faithful" means for Flare v1, as numbers a run can
check. Rubric section 6 defines the ids (QB-…) and how CI gates are set;
this section binds them to Flare's tools, screens and exports. Every item
names where it is measured:

- **Linux**: `scripts/ci` (Model tests in debug), the local gate before every PR (no CI runs on a PR).
- **macOS unit**: `Tests/AppSnapshotTests` and `Tests/SuiteUITests`, in the `macOS` job on `dev`.
- **macOS journey**: `UITests/FlareJourneyTests*.swift`, in the `macOS` job
  on `dev`; locally `scripts/ui-test`, then `scripts/contact-sheet`. Perf
  journeys attach `perf-<test>.json`; audits attach `audit-counts.json`
  (both in the `ui-screens` artifact).
- **Release, local**: `swift test -c release --filter <suite>`, for the
  release half of a model budget.

Status: **covered** means the named test is on dev 956d946 and asserts the
item now. **planned** names the task that adds it. A planned item is still
part of the bar: its feature is not done until the test exists and passes.

### 12.1 Input-to-screen speed, per interactive tool

"Frames late" is the rubric's unit: display refreshes between an input
event's timestamp and the refresh whose frame first shows it, read from
`FrameProbe` (QH-1). Device targets are release builds on a 60 or 120 Hz
Mac; CI gates are the rubric's placeholders until QH-7 sets them from ten
runs (never tighter than the device target). The model half is the work
the Model does per input event; its CI gate is debug, ten times the device
target, as the rubric says, measured as the median of N runs on `bounce`
in the packets' budget tests and as median and p95 on `reference` in QH-3's
`StageBudgetTests` and creative-core's `FlareBudgetTests` (LC-14), which
own QB-L5 to QB-L7 for the whole app. The easing editor keeps its own
tighter p95 gate (5 ms debug, 1 ms release).

| Tool | End to end (device; CI gate) | End-to-end test | Model half per event (debug CI gate) | Model tests |
|---|---|---|---|---|
| **Stage drag**: move, draw Rectangle, drag a Pen handle, Space-pan; also scale and rotate handles, Ellipse, Direct Select anchor drag | QB-L1: p95 ≤ 2 frames late; CI 3 (placeholder). A drag preview draws before mouse-up (QB-F2, the probe's mark) | P1 `testCanvasDragLatency` on `reference`: four series (move a shape, draw a rectangle, drag a pen handle, Space-pan), ≥ 60 samples each (planned, QH-5). Scale, rotate, ellipse, anchor drag and the QB-F2 mark: gap 5 | hit ≤ 10 ms (QB-L5); draw list ≤ 20 ms (QB-L6); one drag step ≤ 10 ms (QB-L7); a pointer move performs no command (section 2) | covered: `WorkspaceWiringTests.aLongDragPerformsNothingUntilMouseUpThenOneStep` (no command until mouse-up), `DirectSelectMoveSpaceTests.aDirectSelectMoveStaysWithinTheEditBudget` (QB-L7). Behaviour, not timing: `FlareToolsTests.flareToolActsOrIsDisabled`, `ShapeFakesTests.aRectangleCommitIsOneUndoAddRectangleEntry`, `ShapeFakesTests.editPathMoveAndDeleteAreOneEntryEachAndUndoExactly`. Planned: hit and draw list in `LiveStageBudgetTests` (ST-10), `StageBudgetTests` (QH-3), `FlareBudgetTests` (LC-14) |
| **Scrub**: drag the playhead | QB-L3: p95 ≤ 2 frames late; CI 3 | P3 `testTimelineScrubLatency` (planned, QH-5) | set the frame, then the draw list for it ≤ 20 ms (QB-L6); a scrub is never an undo step (QB-F3) | covered: `FlarePlaybackTests.playbackAndScrubbingAreNotUndoSteps`, `FlarePlaybackTests.scrubbingWhilePlayingContinuesFromTheNewFrame`, `PlayheadClampTests`. Planned: `LiveStageBudgetTests.drawListWithinBudget` (ST-10) |
| **Inspector scrub**: drag a TRANSFORM bar slider | QB-L2: p95 ≤ 2 frames late; CI 3 | P2 `testSliderScrubLatency` on the Rotation bar (planned, QH-5) | one `setValue` step ≤ 10 ms (QB-L7); a whole scrub is one undo entry (one merged command once LC-10 lands) | covered: `PropertyFakesTests.oneHundredTwentyScrubValuesLeaveExactlyOneUndoEntry`, `PropertyScrubUndoTests.aScrubThatEndsOnItsStartValueDoesNotSwallowTheNextScrub`. Planned: `LiveKeysBudgetTests.scrubStepWithinBudget` (live-keys KY-9) |
| **Keyframe drag**: retime a key on the timeline | QB-L3: p95 ≤ 2 frames late; CI 3 | P3, second series: drag Ball's key at 24 across 24 frames (planned; gap 1 below) | one `moveKeys` step ≤ 10 ms (QB-L7); a 50-step drag is one entry (`MoveKeyframe` merges) | covered: `TimelineFakesTests.keyMovesAreOneStepAndPassOverKeysThatMoveToo`, `TimelineFakesTests.movingKey24Onto36ThrowsAndChangesNothing`. Planned: `LiveKeyframesEditTests.coalescedDragIsOneEntry` (KY-6); the step budget (gap 2) |
| **Easing curve drag**: drag a curve handle | QB-L2: p95 ≤ 2 frames late; CI 3. The handle follows the pointer to 0.03 of the curve's unit square | P2, second series on `flare.easing.handle1` (planned; gap 1). Covered now, for position not timing: `FlareJourneyTests.testEditEasingOfAKeyframeSegment` | one handle move p95 ≤ 5 ms debug, ≤ 1 ms release; one drag is one undo step | covered: `FlareEasingDragCostTests.handleDragP95UnderBudget` (200 layers × 4 tracks × 25 keys), `LiveEasingTests.coalescedDragStepP95UnderBudget`, `FlareEasingTests.oneDragIsOneUndoStep`, `LiveEasingTests.coalescedDragIsOneStepThatUndoesToTheStart` |
| **Playback**: play at the document rate | QB-L4: 0 dropped frames and tick jitter p95 < 2 ms over 5 s; CI ≤ 2 dropped frames in 5 s. QB-L11: 500 nested instances at 30 fps drop 0 | P4 `testPlaybackHoldsFrameRate` on `reference`, P5 `testNestedInstancesPlayback` on `crowd` (planned, QH-5, QH-6) | the ticker turns link timestamps into frames with no drift; one nested frame's draw list ≤ 40 ms (QB-L11) | covered: `FlarePlaybackTicksTests.fiveSecondsAtTheDocumentRateDropNoFrames` (60 and 120 Hz), `FlarePlaybackTicksTests.oneStallStaysInsideTheCIGate`, `FlarePlaybackTests.fiveSecondsAt60HzTicksShowsEveryFrameWithoutDrift`, `PlaybackDriverTests.theDriverAgreesWithTheFakeOnTheSameTicks` and `.usesTheTargetTimestampNotWallTime` (macOS unit). Planned: `LiveStageBudgetTests.nestedDrawListWithinBudget` (ST-10) |
| **Guide drag**: drag a guide out of a ruler and along it | QB-L1: p95 ≤ 2 frames late; CI 3 | P1, a guide series (gap 5) | one `moveGuide` step ≤ 10 ms (QB-L7, median of 50); a drag is one entry | covered: `StageFakesTests.aGuideDragOfFiftyStepsIsOneUndoEntry`, `GuideDragUndoTests.aGuideDragThatEndsWhereItStartedDoesNotSwallowTheNextDrag`. Planned: `LiveScenesGuidesTests.dragStepWithinBudget` (live-scenes SN-4) |
| **Scroll**: timeline lanes and layer list of `crowd` | QB-L10: p95 frame interval ≤ 1.5 refreshes; CI set from CI | P6 `testTimelineAndLayerListScroll` (planned, QH-6) | 300 timeline rows ≤ 50 ms debug | planned: `HugeDocumentBudgetTests` (QH-3) |

Waits are part of speed too: open, export and assist show their progress
state ≤ 100 ms after the command (QB-L9; covered for open's model half by
`FlareFilesTests.progressShowsAtOnceAndOpenFinishesOffTheDecode`; P7 and
J24 planned), and opening up to 64 MB never stalls the main thread longer
than 2 refreshes (QB-L12; P7 planned, QH-6), and export of an SVG frame, 300 Lottie frames and 48 1080p
PNGs stays inside QB-L8 (covered on the fake by
`ExportScanTests.svgFrameLottieAndPNGSequenceStayInsideQBL8`; live in
LM-13a).

### 12.2 App-audit checks

Every check in `AppAudit.checks` has scope `.all`, so all six run on every
Flare journey shot (`docs/blueprints/app-audit.md`): `disabled-dim`,
`overlap`, `contrast`, `identifier`, `offscreen` and `unnamed`. Measured on
the macOS job on `dev` (`audit-counts.json` in `ui-screens`) and locally with
`scripts/ui-test`; the checks' own logic is tested on Linux by
`AuditChecksTests`.

| Check | Flare baseline today (`UITests/audit-baseline.json`) | Bar |
|---|---|---|
| `disabled-dim` | 0 (not listed) | stays 0: every disabled tool and menu item (section 3) reads as disabled |
| `overlap` | 0 (not listed) | stays 0 at every width in 12.3 |
| `contrast` | 3 | no rise in any PR; 0 when v1 ships |
| `identifier` | 15 | no rise; 0 once F1b gives every control its `flare.<area>.<name>` identifier (section 4, Modes) |
| `offscreen` | 15 | no rise; target 0 after F1a moves the window to `EditorShell` (its columns need 762 pt, 12.3); F1a's PR lowers the count or says what is left and why |
| `unnamed` | 0 (not listed) | stays 0 |

A Flare count never goes up (an unlisted check counts as 0, so a first
finding is a rise; CLAUDE.md, Fast lane); falls are written back by CI's
`Audit lower` job. Every new screen Flare adds gets a journey `shot`, so the
audit sees it.

### 12.3 Layout at several window widths

The editor's columns come from tokens: the rail is `toolButton` + 2 × `xs`
= 40 pt, the right panel `editorPanelWidth` = 280 pt, with a 1 pt divider
after the rail and before the panel (`EditorShell`), the top bar
`editorTopBar` = 48 pt, the timeline's name column `timelineLabelColumn` =
160 pt. Widths checked:

| Width × height | Why |
|---|---|
| 880 × 560 | `SuiteSize.windowMinimum` |
| 1000 × 640 | `SuiteSize.windowLaunch` |
| 1024 × 700 | the CI runner's screen width (1024 × 768 less the menu bar) |
| 1440 × 900 | a laptop; the snapshot frame |

At every width, with `bounce` open:

1. The top bar spans the window, 48 pt tall; its first item starts at
   `windowControlsInset` (76 pt); the save status is the trailing item,
   `SuiteSpacing.s` (8 pt) from the window's edge (`EditorTopBar`'s
   padding); Export… is the one filled item; no two items overlap.
2. The rail is 40 pt wide at x = 0 under the top bar. The panel is exactly
   280 pt wide, its trailing edge on the window's; it never shrinks. The
   stage column takes the rest: W − 322 pt (558 pt at the minimum, above
   `contentMinimum` 440).
3. At Fit, the artboard is centred in the stage viewport to 0.5 pt and
   leaves at least `SuiteSpacing.xxl` (32 pt), `CanvasViewport`'s fit
   margin, on its limiting side, and Fit never zooms past 100%.
4. The timeline's lanes start on the same x as its ruler, after the 160 pt
   name column; the playhead's x equals `FrameMapping`'s x for the current
   frame to 0.5 pt; the transport capsule is centred in the stage column to
   0.5 pt.
5. In the Properties tab every bar slider spans the panel minus its keyframe
   slots, and the trailing edges of all value texts line up to 0.5 pt.
6. Nothing is hidden to make room: the panel shows without hiding anything
   (today's `testEditEasingOfAKeyframeSegment` hides the sidebar to fit the
   1024 runner; that ends with F1a), and the audit's `overlap` and
   `offscreen` find nothing.
7. At 560 pt tall the stage keeps `EditorShell`'s 360 pt minimum height
   (`contentMinimum.height`) and the timeline shows its ruler and two lanes
   (88 pt), so S9's timeline slot and the status row share at most
   560 − 48 − 360 = 152 pt.

| Measured by | Widths | Status |
|---|---|---|
| `EditorShellTests.editorShellFitsTheWindowMinimum` (macOS unit): rail + content minimum + panel ≤ window minimum | all | covered |
| `TokensTests.splitViewIdealWidthsFitTheWindowMinimum`, `.windowLaunchSizeComesFromTheColumnTokens` | 880, 1000 | covered (today's `SuiteWindow`) |
| `ScrubValueTests.fitScaleFitsInsideTheInsetAndNeverZoomsIn` (rule 3's Fit), `EditorShellTests.canvasLayoutCentresAFittingDocument` (centring at a fixed zoom) | all | covered |
| `SuiteWindowMinimumSnapshots` (`suiteui-window-minimum-*.png`) | 880 | covered (the shell Flare leaves) |
| `FlareJourneyTests+Layout.testLayoutAtEachWidth`: launches with a `-FlareWindowSize <w>x<h>` argument, reads the frames of `EditorShell`'s `suite.tools` (rail) and `suite.inspector` (panel) and of new `flare.topbar`, `flare.artboard`, `flare.timeline` and `flare.transport` ids, asserts rules 1–7 with the token values written into the journey (UITests import no SuiteUI), and shoots each width (so the audit runs) | 880, 1000, 1024 | planned (gap 3) |
| `FlareLayoutSnapshots`: `FlareEditor` on `bounce` at each width inside the 1440 × 900 frame, `flare-layout-<w>-dark.png` | all four | planned (gap 3) |

### 12.4 Fidelity: export equals a reference

| Item | Reference and tolerance | Test | Status |
|---|---|---|---|
| Curves stay curves (QB-V1) | each FlareCore `cubic` is one `addCurve`, element for element | `StagePathTests.cubicsStayCurves` (macOS unit); `LiveStageTests.cubicsKept`, `LiveShapesTests.ellipseIsFourCubics` (Linux, ST-1, ST-6) | covered on macOS; Linux planned |
| Save then open | byte-identical file | `FlareFilesTests.saveThenOpenIsByteIdentical` | covered |
| Easing | each preset's curve at x = 0.25, 0.5 and 0.75 within 1e-9 of the table; samples within 1e-9 of FlareCore | `LiveEasingTests.presetTableGolden`, `.curveEndpointsExact`, `FlareEasingTests.samplesMatchFlareCoreWithinOneBillionth` | covered |
| Playback timing | the same link timestamps give the same frames, live and fake | `PlaybackDriverTests.theDriverAgreesWithTheFakeOnTheSameTicks`, `FlarePlaybackTests.fiveSecondsAt60HzTicksShowsEveryFrameWithoutDrift` | covered |
| Warnings, never a silent drop | `showcase` exports carry the scan's warnings for their format: three for SVG and PNG, four for Lottie (its background) | `ExportScanTests.everyFormatExportsShowcaseCarryingTheScansWarnings`, `.showcaseIsValidAndHoldsOneOfEachWarning` (fake); `LiveExportWarningsTests` (LM-13b) | covered on the fake; live planned |
| PNG sequence shape | `bounce` 0–12 step 2 gives 7 PNGs; 0–48 step 2 gives 25 | `ExportScanTests.bounceZeroToTwelveStepTwoGivesSevenPNGs` (fake); `LiveExportTests` (LM-13a) | covered on the fake; live planned |
| Stage golden (QB-V2, V3) | `bounce` and `character` at frame 24, 2x: channel tolerance 2/255, ≤ 0.5% differing pixels; a 1 pt hairline is 2 px | `FlareStageSnapshots` on `GoldenImage` and `SnapshotHost` (F3a, QH-2, QH-2b) | planned |
| PNG export equals the stage (QB-V4) | the PNG `StageRasterizer` writes for `bounce` frames 0 and 24 at 2x equals the stage golden of that frame within QB-V2's tolerance | `RasterizerTests` (LA-1) | planned |
| SVG export equals a reference | `bounce` frame 24 SVG byte-identical to a committed reference; parses with `XMLParser` | creative-core `RenderListTests` (LC-1, SVG golden byte-identical); `LiveExportTests` against `Tests/FlareModelTests/Golden/bounce-24.svg` (gap 4); IN-7's parse check | planned |
| Lottie export equals a reference | `bounce` Lottie decodes to the same JSON object as a committed reference (key order free; numbers to 1e-6); `fr` 24; position, scale, rotation and opacity tracks present | creative-core `LottieTracksTests` (LC-13); `LiveExportTests` against `Tests/FlareModelTests/Golden/bounce.lottie.json` (gap 4) | planned |
| Live equals fake | the live stage's draw list equals the fake's on `bounce` and `character` | `LiveConformanceTests` (ST-5) | planned |
| Convert to Symbol changes no pixel | the render-list diff before and after is empty | `LiveLibraryTests` (LM-10) | planned |

### 12.5 Gaps this bar opens

Each is a test no task owns yet; the next packet that touches its file
takes it, and until then it is listed here, not silently dropped.

1. **P2 and P3 second series.** QH-5's P2 adds a drag of the easing curve
   handle and P3 a key drag, each ≥ 60 samples, so keyframe and easing drags
   are timed end to end, not only the Rotation bar and the playhead.
2. **Key drag step budget.** `LiveKeysBudgetTests` (KY-9) adds
   `moveKeyStepWithinBudget`: the median of 50 `moveKeys` steps on `bounce`
   ≤ 10 ms debug (QB-L7).
3. **Layout journey and snapshots.** A `-FlareWindowSize` launch argument
   (in `FlareLaunch.swift`, F1a), `UITests/FlareJourneyTests+Layout.swift`
   and `Tests/AppSnapshotTests/FlareLayoutSnapshots.swift`, after F1b gives
   the regions their identifiers and QH-4 makes the journey template
   compile `UITests/FlareJourneyTests*.swift`.
4. **Export references.** `Tests/FlareModelTests/Golden/bounce-24.svg` and
   `bounce.lottie.json`, written once by LM-13a from the live exporters,
   reviewed by eye in that PR, then compared on every run. No test target
   holds non-Swift files yet and `Package.swift` is protected, so SwiftPM
   would warn about them as unhandled files: LM-13a either embeds the
   references as string literals in a Swift file or files the
   `Package.swift` resource change as its own issue first.
5. **More P1 series.** QH-5's P1 adds scale and rotate handle drags, an
   Ellipse draw, a Direct Select anchor drag and a guide drag, and records
   the probe's "preview before mouse-up" mark for each draw (QB-F2).
