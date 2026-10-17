# Feature packet: draw-key-save

**Status:** built (2026-10-16), feature issue #1365. PRs: #1524 #1525
#1543 #1544 #1580 #1581 #1597 #1608 #1627 #1644 #1649 #1658 #1673 #1676
#1690 #1691 #1695, and DK-15's journey J26.

**Feature:** a person opens Flare, draws a rectangle, keys its position on
the timeline by dragging it with auto-key on, plays it, and saves it as a
`.flare` file they can open again. The window is `SuiteWindow` (glass
toolbar, sidebar, hideable inspector), with the stage over the timeline in
the content, the floating glass tool palette on the stage, and every
control routed through one `FlareIntent`.
**Line:** `line:flare` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/draw-key-save`

**Covers:** F1a #346, F1b #347 (and #287, which F1b closes), F3a #12, F4a
#203, F2 #15, F7a #11, F17a #205, the drag-to-key half of #204 (its title:
drag a layer to key its position; the box handles and J5 stay with
`stage-edit`, which closes it), the transport half of F7b #376 (the fps pill
and `TransportCapsule` stay with `inspector-timeline`), and the recording
ring of F5 #391. Writes "see #N" in PRs; the issues close as listed under
Tasks.

**Depends on:** #793 (mac-platform, closed). At task level only, DK-3 waits
on #798 (live-stage), #799 (live-keys) and #800 (live-scenes): it puts their
live types behind the window. Everything else codes against the contracts
and fakes that are on `dev` now, so the lead starts at once and builds DK-3
when those three close. No SuiteUI issue blocks it: every component it uses
is on `dev` (`SuiteWindow`, `ToolbarGroup(.floating)`, `ToolbarAction` with
`unavailableHelp`, `CanvasViewport`, `CanvasMarks`, `TimelineStrip`,
`SegmentedTabs`, `ViewerStatusBar`, `EmptyStateView`). The old deps of #346
on S9 #342 (`EditorShell` timeline slot) are dropped: the window is no
longer `EditorShell`.

**The look (captain, 2026-10-15).** Every app uses `SuiteWindow`; Flare
keeps its floating glass tool palette (`ToolbarGroup` `.floating`), which
becomes the suite standard; an app switcher row sits centred in the toolbar
(SuiteUI adds it to `SuiteWindow`; Flare passes nothing for it). So the old
`EditorShell` plan of `docs/blueprints/flare.md` section 3.1 maps as:

| was (section 3.1) | now |
|---|---|
| Top bar: New, Open, Save, Undo, Redo, Auto-key, Animate…, Export… | `SuiteWindow` toolbar `actions`, in that order. Animate… and Export… are disabled with their area's reason until their features land |
| Right panel tabs Properties, Layers, Library | The inspector: `SegmentedTabs` with Properties and Library. The Layers tab's content (SCENES, then LAYERS) is the sidebar, as today: scenes and layers stay in the sidebar |
| Stage, tool rail | The content's top: the stage on `CanvasViewport`, the floating palette on it |
| Under the stage: transport, readouts, pills; timeline in the bottom slot | The content's bottom, under the stage: transport and readouts, then `TimelineStrip` |

Blueprint sections: 2 (one undo step, rendering and feel), 3.1, 3.4, 4 (J0,
J1, J3, J6, J9, J10, J26, J29), 6.3 (wiring), 7.3 (F1a, F1b, F2, F3a, F4a,
F7a, F17a), 7.6 (the swap rule).

**Where it starts from.** The Model already does the work: `drag`,
`dragChanged`, `endDrag` for every tool (`FlareDrag.swift`), `toolHelp`,
playback and `tick` (`FlarePlayback.swift`, `FlarePlaybackTicks.swift`),
`toggleAutoKey` and the not-animated rule (`FlareAnimate.swift`), and open,
save, dirty and Open Recent (`FlareFiles.swift`). `PlaybackDriver`,
`StagePath` and `FlareAutosave` are on `dev` (mac-platform). What is
missing is the window that shows and drives it. `FlareApp.swift` today holds
the whole window, a placeholder canvas, and the easing inspector.

**Live services without breaking the fakes' tests.** About 20 Model test
files build `FlareWorkspace()` and rely on `FlareServices.live` being
`NotBuilt`. So DK-3 does not edit `.live`. It adds `FlareServices.built`:
the live type for every member whose live conformance has merged (stage,
hits, shapes, properties, keyframes, easing, scenes) and `NotBuilt` for the
rest. A launch with no arguments, `-FlareSample` and `-FlareOpenFile` run on
`.built`; `-FlareFixture` runs on `.fake()`. IN-1 #397, IN-2 #385 and IN-4
#398 still swap their lines in `.live`, and IN-9 #399 folds `.built` into
`.live`. Until IN-9 the "Preview data" pill reads `services.isPreview` as
today.

## Journey steps

| # | step | task | journey test |
|---|---|---|---|
| 1 | Launch: the window, an empty state with New Animation (Open is the toolbar's), the toolbar actions, the palette's five tools each enabled or with a reason | DK-6, DK-7, DK-8 | J0 `FlareJourneyTests.testLaunchShowsWindowShell` |
| 2 | Every menu opens and lists section 3.4's items; every control acts or says why; Space, →, Home, End and ⌘Z act from the keyboard | DK-13 | J1 `testEveryMenuOpens`: each menu's item count equals section 3.4's (Open Sample lists Bounce, Character, Button and the keyed sample); J29 `testEveryControlActsOrSaysWhy` on `bounce`: every enabled `flare.*` control changes a value or the shot, every disabled one has a reason; `testKeys` on `bounce`: Home 0, End 47, Space plays and pauses, → steps one, ⌘Z undoes; the easing journey's first step clicks File > Open Sample > the keyed sample | an item is hidden, a control is dead, or a key does nothing |
| 3 | R, drag a rectangle; E with Shift; P three corners then the first; P two clicks and Return; Escape mid-drag; Edit > Undo | DK-8, DK-9 | J3 slice `FlareDrawJourneys.testDrawShapesWithEachTool` |
| 4 | Scrub the playhead to 30; the readouts follow | DK-10 | J9 slice `FlareTimelineJourneys.testTimelineScrub` |
| 5 | The transport's Play: the frame moves; Pause; Step Forward twice | DK-11 | J10 slice `FlarePlaybackJourneys.testPlayAndStep` |
| 6 | Auto-key on; frame 30; drag Ball 100 pt right; a key at 30 on Ball's lane; one ⌘Z removes only that key | DK-14 | J6 slice `FlareAnimateJourneys.testMoveAndKeyByDrag` |
| 7 | Save to `-FlareSaveTo`; the title shows the name, no dot; relaunch with `-FlareOpenFile` | DK-12 | `FlareFileJourneys.testSaveAndReopen` |
| 8 | No fixture: New; draw a rectangle; Auto-key on; key X at 0 and 24 by drag; play; ⌘Z; ⇧⌘Z; ⌘S; Open Recent; the keys are at 0 and 24 | DK-15 | J26 `FlareLoopJourneys.testDrawKeyAndSave` in `+Loop.swift`, un-skipped (the skipped stub leaves `FlareJourneyTests.swift`), no fixture flag: New; R and drag a rectangle; Auto-key on; V; frame 0, drag the rectangle 100 pt right (the new shape has no track, so this keys 0); frame 24, drag it 200 pt right (keys 24); Space, wait, Space; ⌘Z then ⇧⌘Z; ⌘S to `-FlareSaveTo`; File > Open Recent lists it; open it: the rectangle's lane has keys at 0 and 24 and the title shows the name with no dot | any step fails on `.built`: draw, key, play, save or reopen |

Steps 1–7 launch with `-FlareFixture <name>` (fakes) so they don't wait on
DK-3; step 8 launches with no fixture, on `.built`.

## Screens and states

| screen | state | snapshot PNG (`Tests/AppSnapshotTests`) |
|---|---|---|
| Window | no document: empty state with New Animation (`EmptyStateView` takes one action; Open is the toolbar's); Undo, Redo, Save, Auto-key, Animate…, Export… disabled with reasons | `flare-window-empty-light.png`, `flare-window-empty-dark.png` (DK-6) |
| Window | `bounce` open: sidebar SCENES and LAYERS, stage, timeline, inspector on Properties | `flare-window-bounce-light.png`, `flare-window-bounce-dark.png` (DK-6) |
| Inspector | Library tab: "Not built yet" empty state until `library` lands | `flare-inspector-library.png` (DK-6) |
| Stage | `bounce` at 0 and at 30, 2x; `character` at 12; a rectangle draft; a marquee; one selection's outline | `flare-stage-bounce-0@2x.png`, `flare-stage-bounce-30@2x.png`, `flare-stage-character@2x.png`, `flare-stage-draft.png`, `flare-stage-marquee.png` (DK-8) |
| Stage | a drawing tool over a locked layer: the palette tool disabled with "Unlock Background to draw on it." | `flare-stage-locked.png` (DK-8) |
| Timeline | `bounce`: lanes, diamonds, playhead at 12, readouts "00:12 / 02:00" and "12 / 48" (`timecode`, `frameReadout`) | `flare-timeline-bounce.png` (DK-10) |
| Timeline | `empty`: "No layers yet. Draw on the stage to add one." | `flare-timeline-empty.png` (DK-10) |
| Transport | paused and playing; loop on | `flare-transport-paused.png`, `flare-transport-playing.png` (DK-11) |
| Recording | auto-key on: the ring around stage and timeline, Auto-key selected | `flare-recording-on.png` (DK-14) |
| Files | title "bounce", no dot; after an edit, the dot | journey shots only (system chrome) |

Error and loading states this feature owns: a save that fails says
`saveError` in a system alert (DK-12; the "Not saved" status and the
recovery offer are `layers-files`); an open that fails keeps the document
open and shows `loadState`'s message in an alert (DK-12; the progress row
and the text pill are `layers-files`).

## Contract slice

Model (Linux, tested):

```swift
// Sources/FlareModel/FlareLaunch.swift (DK-1)
public struct FlareLaunch: Sendable, Equatable {
    public enum Source: Sendable, Equatable { case none, fixture(String), sample(String), file(String) }
    public var source: Source
    public var saveFolder: String?            // -FlareSaveTo
    public var exportFolder: String?          // -FlareExportTo (read by export later)
    public init(arguments: [String])          // unknown flags ignored; a flag with no value is ignored
    public var usesFakes: Bool                // true only for .fixture
}
extension FlareWorkspace {
    public init(launch: FlareLaunch)          // services by source; .fixture/.sample load the fixture document
}

// Sources/FlareModel/FlareIntent.swift (DK-2a): the top enum, its areas, every nested case with
// plain-value payloads, and the identifiers. DK-2b adds the titles. No later task adds a case:
// the list below is section 3 and 3.4 in full, so no wave-4 task edits these files.
public enum FlareIntent: Sendable, Equatable {
    case file(File), edit(Edit), stage(Stage), tools(Tools), view(View), inspector(Inspector),
         timeline(Timeline), layers(Layers), library(Library), interactions(Interactions),
         export(Export), assist(Assist)
    public enum Area: String, CaseIterable, Sendable { case file, edit, stage, tools, view, inspector,
         timeline, layers, library, interactions, export, assist }
    public enum File: Sendable, Equatable { case new, create(preset: String?, width: Double, height: Double,
         fps: Int, durationFrames: Int, backgroundHex: String), open, openRecent(path: String), clearRecent,
         openSample(name: String), save, saveAs, close }
    public enum Edit: Sendable, Equatable { case undo, redo, cut, copy, paste, duplicate, delete,
         selectAll, deselect, bringForward, sendBackward }
    public enum Stage: Sendable, Equatable { case dragChanged(start: Point, end: Point, shift: Bool,
         option: Bool, stageScale: Double), endDrag, cancelDrag }
    public enum Tools: Sendable, Equatable { case choose(FlareTool), finishPath }
    public enum View: Sendable, Equatable { case zoomIn, zoomOut, fit, actualSize, toggleOnion, toggleMotionPath,
         toggleRulers, toggleGuides, clearGuides, addGuide(horizontal: Bool, at: Double),
         moveGuide(index: Int, to: Double, dragStart: Double), endGuideDrag, removeGuide(index: Int) }
    public enum Inspector: Sendable, Equatable { case showTab(String), scrub(property: String, value: Double,
         dragStart: Double), endScrub, toggleAnimated(String), toggleKey(String), setFill(hex: String),
         setStrokeColor(hex: String), setStrokeWidth(Double), setStrokeCap(String), setStrokeJoin(String),
         setSceneSize(width: Double, height: Double), setSceneBackground(hex: String),
         setSceneTiming(fps: Int, durationFrames: Int), easingPreset(String), easingHandle(index: Int, x: Double,
         y: Double), endEasingHandle }
    public enum Timeline: Sendable, Equatable { case scrub(frame: Int), goToStart, goToEnd, step(Int),
         nextKeyframe, previousKeyframe, togglePlay, setLoops(Bool), toggleAutoKey, selectKey(layerID: String,
         property: String?, frame: Int, extending: Bool), moveKeys(by: Int, dragStart: Int), endKeyDrag,
         removeKeys, addKey, removeKey, insertFrames(Int), removeFrames(Int), setLabel(String?) }
    public enum Layers: Sendable, Equatable { case select(id: String), toggle(id: String, flag: String),
         move(section: String, from: Int, to: Int), rename(id: String, name: String), addLayer, addScene,
         remove(id: String), duplicate(id: String) }
    public enum Library: Sendable, Equatable { case convertToSymbol(name: String), place(id: String),
         edit(id: String), exitSymbol, rename(id: String, name: String), remove(id: String), addSwatch,
         applySwatch(Int), removeSwatch(Int) }
    public enum Interactions: Sendable, Equatable { case toggleEditor }   // the editor's own controls are tier 3, later
    public enum Export: Sendable, Equatable { case showSheet }
    public enum Assist: Sendable, Equatable { case showPopover }
    public var area: Area
    public var identifier: String             // "flare.<area>.<case name>", unique; payloads don't change it
}
// Sources/FlareModel/FlareIntent+Titles.swift (DK-2b)
extension FlareIntent { public var title: String }   // the menu or toolbar title, section 3.4's words

// Sources/FlareModel/FlareServicesBuilt.swift (DK-3)
extension FlareServices {
    public static var built: FlareServices    // Live* where merged, NotBuilt elsewhere
}

// Sources/FlareModel/FlareStageRead.swift (DK-4)
public struct StageMarks: Sendable, Equatable {
    public var draft: FlarePath?, marquee: Rect?, selection: Rect?
}
extension FlareWorkspace {
    public var stageList: StageDrawList?      // dragPreview ?? services.stage.drawList(..., currentFrame, editing)
    public var stageMarks: StageMarks
}

// Sources/FlareModel/FlareTimelineRead.swift (DK-5)
extension FlareWorkspace {
    public var timelineRows: [TimelineRow]    // services.keyframes.rows(document, owner:)
    public var timelineEmptyText: String?     // "No layers yet. Draw on the stage to add one." when no rows
    public var selectedTimelineRowID: String? // the selected layer's row
}
```

App (macOS, compiled on `dev`):

```swift
// FlareWindow.swift (DK-6, then DK-7, DK-13)
struct FlareWindow: View {
    @State var model: FlareWorkspace          // FlareWorkspace(launch: FlareLaunch(arguments:))
    @State var zoom: Double?                  // presentation: nil fits; set once the user zooms
    @State var showsRulers = true, showsGuides = true   // View menu; stage-edit's +View flips them
    @State var inspectorTab: FlareInspectorTab
    @State var presented: FlarePresentation?  // new sheet, alerts, recovery offer
}
// The stubs DK-6 creates, with the signatures later tasks fill without touching their call sites.
// `model` is read-only (views are dumb); every change goes through `perform`.
FlareStage(model:, zoom:, showsRulers:, showsGuides:, perform:, help:)            // DK-8 fills
FlareTimeline(model:, zoom:, perform:, tick: (Double, inout PlaybackTicker) -> Bool)   // DK-10 fills
FlareInspector(model:, tab:, perform:)        // Properties shows today's scene card and FlareEasingInspector
FlareLibraryPanel(model:, perform:)           // "Not built yet" empty state
FlareRecording(model:)                        // DK-14 fills
FlareFilePanels(model:, launch:, perform:)    // a modifier; DK-12 fills
FlareNewSheet(presented:, perform:)           // a modifier; layers-files LF-3 fills
FlareOpenStatus(model:)                       // a modifier; layers-files LF-4 fills
FlareRecovery(model:, restore: (Document) -> Void)   // a modifier, restore wired to model.restoreRecovery; LF-5 fills
// FlareWindow+Router.swift (DK-7)
extension FlareWindow {
    func perform(_ intent: FlareIntent)       // switch on area -> perform<Area>(_:)
    func help(for intent: FlareIntent) -> String?   // nil when it can act; switch on area -> <area>Help(_:)
}
// FlareWindow+<Area>.swift (DK-7 stubs; each later owned by one task)
extension FlareWindow {
    func performFile(_ intent: FlareIntent.File)
    func fileHelp(_ intent: FlareIntent.File) -> String?   // stub: "Not built yet (F17a)."
    func toolKey(_ key: KeyPress) -> KeyPress.Result        // +Tools stub: .ignored; DK-9 fills (Escape, Return)
}
// Not stubs: DK-7's +Edit routes .undo and .redo to model.undo()/redo() (help nil when canUndo/canRedo),
// so ⌘Z keeps working; its other Edit cases stay "Not built yet (F18)." until stage-edit SE-3.
// DK-7's +Layers routes today's sidebar calls (selectItem, toggleLayerFlag, moveLayer, renameLayer,
// addLayer), so the sidebar never goes dead; layers-files LF-1 adds scenes, remove and dimming.
// DK-7 builds the Auto-key ToolbarAction with isSelected: model.autoKey.
```

Views take values and one `perform: (FlareIntent) -> Void` plus `help:
(FlareIntent) -> String?`; they never hold the model. Every control's
accessibility identifier is its intent's `identifier`, so `suite.controls`
and the audit name it the same way.

## Pseudocode

```
FlareLaunch(arguments):                                   # DK-1
  walk pairs: -FlareFixture n -> .fixture(n); -FlareSample n -> .sample(n);
              -FlareOpenFile p -> .file(p); -FlareSaveTo d; -FlareExportTo d
  last source flag wins; an unknown fixture name -> .none (an empty window, never a crash)
FlareWorkspace(launch):
  services = launch.usesFakes ? .fake() : .live           # DK-3 changes .live to .built here
  .fixture(n), .sample(n): load(FlareFixtures.named(n))   # fixture docs are built in code
  .file(p): nothing here; the window reads the file off the main thread (DK-12)

FlareServices.built:                                      # DK-3
  .live with stage = LiveStage(), hits = LiveHits(), shapes = LiveShapes(),
  properties = LiveProperties(), keyframes = LiveKeyframes(), easing = LiveEasing(),
  scenes = LiveScenes(); isPreview stays true until IN-9

stageList: guard document, sceneID; dragPreview ?? services.stage.drawList(doc, sceneID, currentFrame, editingSymbolID)   # DK-4
stageMarks: draft?.path, marquee, selection.isEmpty ? nil : selectionBounds

FlareWindow.body:                                         # DK-6
  SuiteWindow(title: document == nil ? "Flare" : model.title,
              sections: SidebarSection.flare(model, ...),   # scenes and layers, as today
              actions: [New, Open, Save, Undo, Redo, Auto-key, Animate…, Export…]) {
    if document: VStack { FlareStage(...); FlareTimeline(...) } else EmptyStateView(New Animation, Open)
  } inspector: { FlareInspector(tab, ...) }                # Properties: today's scene card + easing editor
  .modifier(FlareFilePanels(...)).modifier(FlareNewSheet(...))
  .modifier(FlareOpenStatus(...)).modifier(FlareRecovery(...))   # stubs: no-op modifiers for later tasks
  .focusedSceneValue(\.flareMenu, ...)

perform(intent): switch intent { case .file(let f): performFile(f) ... }   # DK-7
toolbar action i: ToolbarAction(i.title, image, unavailableHelp: help(for: i), identifier: i.identifier) { perform(i) }

FlareStage:                                               # DK-8
  CanvasViewport(document: scene size, zoom, onDrag: { prev, cur in
      start = dragStart ?? prev; dragStart = start
      perform(.stage(.dragChanged(start, cur, modifiers, stageScale: zoom))) },
    onDragEnd: { perform(.stage(.endDrag)); dragStart = nil }) {
    Canvas { draw each item of stageList: StagePath.cgPath(path, matrix), fill, stroke, opacity }
      .drawingGroup()                                     # committed art, redrawn only when the list changes
    FlareStageOverlay(marks)                              # draft, marquee, selection outline (CanvasMarks)
    FlareStageSelection(...) ; FlareStageGuides(...)      # stubs for stage-edit
  }
  onKey: toolKey                                          # +Tools, filled by DK-9
  overlay(alignment: .leading) { ToolbarGroup(FlareTool.allCases.map { t in
      ToolbarAction(t.title, systemImage: t.systemImage, isSelected: t == model.tool,
                    unavailableHelp: model.toolHelp(t), shortcut: t.shortcut,      # V A R E P
                    identifier: FlareIntent.tools(.choose(t)).identifier) { perform(.tools(.choose(t))) } },
      axis: .vertical, style: .floating) }                 # the floating glass palette, with the lock reason
  .modifier(FlareStageContextMenu(...))                    # stub for stage-edit SE-3
performStage(.dragChanged(...)): model.dragChanged(...) ; .endDrag: model.endDrag()

performTools(.choose(t)): model.selectTool(t)             # DK-9
performTools(.finishPath): model.finishPath()             # Return; Escape -> perform(.stage(.cancelDrag))
finishPath (Model, DK-9): commit the open pen draft as one "Add Path"; refuse fewer than 2 anchors

FlareTimeline:                                            # DK-10
  if let text = timelineEmptyText: the text
  else TimelineStrip(tracks: timelineRows -> name + keyFrames, duration, playhead: currentFrame,
                     onScrub: { perform(.timeline(.scrub($0))) }, onSelectTrack: ...)
  readouts: model.timecode, model.frameReadout ; FlareTransport(...) above the strip
performTimeline: scrub -> setCurrentFrame ; start/end -> goToStart/goToEnd ; step(n) -> stepFrame(by:)
  play/pause -> togglePlay ; loop -> setLoops ; autoKey -> toggleAutoKey

FlareTransport:                                           # DK-11
  ToolbarGroup([start, back, play/pause, forward, end, loop])   # TransportCapsule replaces it (#340, inspector-timeline)
  owns a PlaybackDriver: on isPlaying true -> driver.start(on: screen) { target, ticker in tick(target, &ticker) }
  # tick comes from FlareTimeline's `tick` parameter, wired in FlareWindow to model.tick(target:ticker:)
  on false -> driver.stop()

performFile:                                              # DK-12
  .new -> model.newDocument()        # the preset sheet is layers-files (F11b); ⌘N makes 1080p until then
  .open -> NSOpenPanel (.flare) ; read bytes in a detached task ; model.beginOpen ; finishOpen(decodeFile(bytes), name)
  .save -> guard save = model.saveData() ; url = launch.saveFolder ?? last URL ?? NSSavePanel
           write atomically off the main actor ; ok -> didSave(save, name), noteRecent(path)   # layers-files LF-5 removes the recovery file once clean
           error -> saveFailed(reason)
  .saveAs -> same with the panel always ; .openRecent(path) -> as .open on that path
  .file(p) at launch -> as .open on p
  title: model.title ; the dot: NSWindow documentEdited = model.isDirty (FlareFilePanels' window accessor)
  # the toolbar's New Sample Animation goes (captain's toolbar list); DK-6 moves the easing journey's
  # first step to File > New Sample Animation, and DK-13 keeps it as Open Sample's keyed sample

FlareCommands:                                            # DK-13
  every section 3.4 item: Button(i.title) { menu.perform(i) }.disabled(menu.help(i) != nil)
  .keyboardShortcut per 3.4 ; Undo/Redo titled undoActionName/redoActionName
  # each key lives only on its menu item (Space, →, ←, Home, End, ⌘ keys); no view binds them again
  Open Sample ▸ Bounce, Character, Button, and today's keyed sample (the easing journey's route)
  Open Recent: model.recent, then Clear Menu

FlareRecording: if model.autoKey: a ring in the recording color around stage and timeline   # DK-14
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: draw-key-save`, `Fast-Check:
pass`, `Head:`. DK-15 also carries `feature-done`. Snapshot files named
`Tests/AppSnapshotTests/Flare*.swift` and journey files named
`UITests/FlareJourneyTests*.swift` are Flare's; no task touches
`SnapshotHost.swift`, `AppSnapshotTests.swift`, `UITests/Journey*.swift` or
`project.yml` (shared, SuiteUI's).

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DK-1 | #346 (part) | `FlareLaunch`: parse the launch flags; `FlareWorkspace(launch:)` | `Sources/FlareModel/FlareLaunch.swift`, `Tests/FlareModelTests/FlareLaunchTests.swift` | – | ~150, 2 files |
| DK-2a | #347 (part) | `FlareIntent`: the top enum, `Area`, every nested case of the contract slice, `area` and `identifier` | `Sources/FlareModel/FlareIntent.swift`, `Tests/FlareModelTests/FlareIntentTests.swift` | – | ~260, 2 files |
| DK-2b | #347 (part) | `FlareIntent.title`: section 3.4's words for every case; the table test of every menu item and toolbar action | `Sources/FlareModel/FlareIntent+Titles.swift`, `Tests/FlareModelTests/FlareIntentTitleTests.swift` | DK-2a | ~280, 2 files |
| DK-3 | see #397, #385, #398 | `FlareServices.built`; the launch's default services become `.built` | `Sources/FlareModel/FlareServicesBuilt.swift`, `Sources/FlareModel/FlareLaunch.swift`, `Tests/FlareModelTests/FlareServicesBuiltTests.swift` | DK-1, #798, #799, #800 | ~120, 3 files |
| DK-4 | #12 (part) | `stageList` and `stageMarks` | `Sources/FlareModel/FlareStageRead.swift`, `Tests/FlareModelTests/FlareStageReadTests.swift` | – | ~150, 2 files |
| DK-5 | #11 (part) | `timelineRows`, `timelineEmptyText`, `selectedTimelineRowID` | `Sources/FlareModel/FlareTimelineRead.swift`, `Tests/FlareModelTests/FlareTimelineReadTests.swift` | – | ~120, 2 files |
| DK-6 | #346 (closes) | Split `FlareApp.swift`: `FlareWindow` on `SuiteWindow` with the toolbar, sidebar, stage-over-timeline content, inspector tabs, launch flags, the palette items (`FlareTool: PaletteTool` with V A R E P) in their own file, and the stubs of the contract slice; the easing journey starts from File > New Sample Animation | `Sources/FlareApp/FlareApp.swift`, `Sources/FlareApp/FlareWindow.swift`, `Sources/FlareApp/FlareToolItems.swift`, `Sources/FlareApp/FlareStage.swift`, `Sources/FlareApp/FlareTimeline.swift`, `Sources/FlareApp/FlareInspector.swift`, `Sources/FlareApp/FlareLibraryPanel.swift`, `Sources/FlareApp/FlareRecording.swift`, `Sources/FlareApp/FlareFilePanels.swift`, `Sources/FlareApp/FlareNewSheet.swift`, `Sources/FlareApp/FlareOpenStatus.swift`, `Sources/FlareApp/FlareRecovery.swift`, `Tests/AppSnapshotTests/FlareWindowSnapshots.swift`, `UITests/FlareJourneyTests.swift` | DK-1 | ~380, 14 files |
| DK-7 | #347 (closes) | The router `perform`/`help`, twelve area files (stubs except Undo, Redo and today's sidebar calls), toolbar and sidebar through intents, Auto-key `isSelected`, identifiers on every control | `Sources/FlareApp/FlareWindow+Router.swift`, `Sources/FlareApp/FlareWindow+File.swift`, `Sources/FlareApp/FlareWindow+Edit.swift`, `Sources/FlareApp/FlareWindow+Stage.swift`, `Sources/FlareApp/FlareWindow+Tools.swift`, `Sources/FlareApp/FlareWindow+View.swift`, `Sources/FlareApp/FlareWindow+Inspector.swift`, `Sources/FlareApp/FlareWindow+Timeline.swift`, `Sources/FlareApp/FlareWindow+Layers.swift`, `Sources/FlareApp/FlareWindow+Library.swift`, `Sources/FlareApp/FlareWindow+Interactions.swift`, `Sources/FlareApp/FlareWindow+Export.swift`, `Sources/FlareApp/FlareWindow+Assist.swift`, `Sources/FlareApp/FlareWindow.swift`, `UITests/FlareJourneyTests.swift` | DK-2a, DK-2b, DK-6 | ~330, 15 files |
| DK-8 | #12 (closes) | The stage: draw list in a `Canvas` under `.drawingGroup()` on `CanvasViewport`, the overlay (draft, marquee, selection outline), the floating palette from `toolHelp`, drags to `.stage` intents, `onKey` to `toolKey`; every `FlareTool.unavailableHelp` nil (each acts through `drag` in the Model); stubs for selection handles, guides and the context menu, each given `model`, `zoom` and `perform` | `Sources/FlareApp/FlareStage.swift`, `Sources/FlareApp/FlareStageOverlay.swift`, `Sources/FlareApp/FlareStageSelection.swift`, `Sources/FlareApp/FlareStageGuides.swift`, `Sources/FlareApp/FlareStageContextMenu.swift`, `Sources/FlareApp/FlareWindow+Stage.swift`, `Sources/FlareModel/FlareWorkspace.swift`, `Tests/FlareModelTests/FlareToolsTests.swift`, `Tests/AppSnapshotTests/FlareStageSnapshots.swift` | DK-4, DK-7 | ~390, 9 files |
| DK-9 | #203 (closes) | Tools: choosing a tool, `finishPath` in the Model (Return ends an open pen path), Escape cancels a draft; the J3 slice | `Sources/FlareModel/FlarePenFinish.swift`, `Tests/FlareModelTests/FlarePenFinishTests.swift`, `Sources/FlareApp/FlareWindow+Tools.swift`, `UITests/FlareJourneyTests+Draw.swift` | DK-8 | ~260, 4 files |
| DK-10 | #11 (closes) | The timeline: `TimelineStrip` lanes and diamonds, scrub, readouts, empty text; every `.timeline` intent routed; the `FlareTransport(model:, zoom:, perform:, tick:)` stub | `Sources/FlareApp/FlareTimeline.swift`, `Sources/FlareApp/FlareTransport.swift`, `Sources/FlareApp/FlareWindow+Timeline.swift`, `Tests/AppSnapshotTests/FlareTimelineSnapshots.swift`, `UITests/FlareJourneyTests+Timeline.swift` | DK-5, DK-7 | ~330, 5 files |
| DK-11 | see #376 | The transport: start, step, play/pause, end, loop on a floating `ToolbarGroup`; `PlaybackDriver` started and stopped by `isPlaying` through `tick` | `Sources/FlareApp/FlareTransport.swift`, `Tests/AppSnapshotTests/FlareTransportSnapshots.swift`, `UITests/FlareJourneyTests+Playback.swift` | DK-10 | ~220, 3 files |
| DK-12 | #205 (closes) | Files: open and save panels, `-FlareSaveTo` and `-FlareOpenFile`, the off-main read and write, title and dirty dot, Open Recent, the close prompt, save and open failures as alerts | `Sources/FlareApp/FlareFilePanels.swift`, `Sources/FlareApp/FlareWindow+File.swift`, `UITests/FlareJourneyTests+Files.swift` | DK-1, DK-7 | ~340, 3 files |
| DK-13 | #15 (closes) | The menu bar: every section 3.4 item bound to an intent, disabled with its reason; Undo and Redo named; Open Sample with the keyed sample; Open Recent; the keyboard keys of J9 and J10 | `Sources/FlareApp/FlareCommands.swift`, `Sources/FlareApp/FlareWindow.swift`, `UITests/FlareJourneyTests.swift`, `UITests/FlareJourneyTests+Menus.swift`, `UITests/FlareJourneyTests+EveryControl.swift` | DK-7 | ~380, 5 files |
| DK-14 | see #204, #391 | Drag to key: the recording ring; the J6 slice on `bounce` | `Sources/FlareApp/FlareRecording.swift`, `Tests/AppSnapshotTests/FlareRecordingSnapshots.swift`, `UITests/FlareJourneyTests+Animate.swift` | DK-9, DK-10 | ~200, 3 files |
| DK-15 | – | `testDrawKeyAndSave` moved to its own file and un-skipped on `.built`; shared docs | `UITests/FlareJourneyTests.swift`, `UITests/FlareJourneyTests+Loop.swift`, `docs/c4/parts/creative-apps/flare-app/flare-app-sources.json`, `docs/c4/parts/creative-apps/flare-model/flare-model-sources.json`, `docs/blueprints/flare.md`, `docs/blueprints/flare/features/draw-key-save.wave.json`, `docs/blueprints/flare/features/draw-key-save.md` | DK-3, DK-11, DK-12, DK-13, DK-14 | ~220, 6 files |

Notes on the cut:

- DK-6 and DK-7 sit at 14 and 15 files because the stubs are what lets every
  later task own its own file. Each stub is a few lines: a view that shows
  nothing (or today's content, for the inspector), a no-op modifier, or an
  area whose `help` says "Not built yet (F<n>)." and whose `perform` does
  nothing. The exceptions keep today's behavior alive: `+Edit` routes Undo
  and Redo, `+Layers` routes today's sidebar calls. If DK-7 goes over 400
  lines, the lead moves the Interactions, Export and Assist stubs into their
  own PR first.
- DK-8 is the one task near 400. If it goes over, the lead splits off the
  overlay (`FlareStageOverlay.swift`, `flare-stage-draft.png`,
  `flare-stage-marquee.png`) into its own PR after it.
- **Keys live on menu items.** Space, →, ←, Home, End, ⌥K and the ⌘ keys
  are section 3.4 menu shortcuts, bound once in DK-13. DK-9, DK-10 and
  DK-11's journeys click (the Edit menu's Undo, which works from DK-7, the
  ruler, the transport buttons); DK-13's journey presses the keys. Only the
  tool letters (on the palette's `ToolbarAction.shortcut`, DK-6 and DK-8)
  and Escape and Return on the stage (`toolKey`, DK-9) are view keys.
- `FlareWorkspace.swift` is edited only in DK-8 in this feature, and only
  `FlareTool`'s `unavailableHelp` (all five nil: each tool's drag changes
  the document in the Model today, which `FlareToolsTests` checks).
- `FlareIntent.swift` and `FlareIntent+Titles.swift` hold every case and
  title of the contract slice, so no later feature edits them.
- `FlareEasingInspector.swift` stays as it is; DK-6's Properties tab shows
  it where today's inspector does. `inspector-timeline` (F9) retires it.
- `FlareLayerItems.swift` stays as it is; DK-7 only routes its toggles,
  moves and renames through `.layers` intents. `layers-files` owns it.
- `testDrawKeyAndSave` moves into `UITests/FlareJourneyTests+Loop.swift` in
  DK-15, so `layers-files` LF-3 (the New sheet) can add its Create step there
  without touching `FlareJourneyTests.swift`, which `inspector-timeline`'s
  IT-8 edits in the same wave.

## Build waves

- Wave 1: DK-1, DK-2a, DK-4, DK-5. Independent in this wave: all four.
- Wave 2: DK-2b, DK-3, DK-6. Independent in this wave: all three (DK-3
  starts when #798, #799 and #800 close; nothing but DK-15 needs it).
- Wave 3: DK-7. Independent in this wave: DK-7 (alone).
- Wave 4: DK-8, DK-10, DK-12, DK-13. Independent in this wave: all four
  (DK-13 is the only one that edits `FlareWindow.swift` and
  `FlareJourneyTests.swift`).
- Wave 5: DK-9, DK-11. Independent in this wave: both.
- Wave 6: DK-14. Independent in this wave: DK-14 (alone).
- Wave 7: DK-15 (shared docs, final).

Longest chain: DK-1 → DK-6 → DK-7 → DK-8 → DK-9 → DK-14 → DK-15 (7).
Chain of 7: each link needs the one before it merged to run its test: the
window needs the launch flags its journey uses, the router extends that
window, the stage's drags go through the router, choosing a tool and
finishing a path need the stage to draw, drag-to-key needs the Select tool
chosen, and the final journey walks all of them. Wave 4 is where the work
fans out.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| DK-1 | `FlareLaunchTests`: `-FlareFixture bounce` gives `.fixture("bounce")`, fakes, and `bounce` loaded; `-FlareSample bounce` gives `bounce` on non-fake services; `-FlareOpenFile /tmp/a.flare -FlareSaveTo /tmp/out` sets both; no flags give `.none` and no document; `-FlareFixture` with no value, an unknown flag, and an unknown fixture name each give `.none` and no crash; the last source flag wins | a flag is misread, a fixture launch runs on live services, or a bad flag crashes |
| DK-2a | `FlareIntentTests`: identifiers are unique and match `^flare\.[a-z]+\.[a-zA-Z0-9]+$`; a payload doesn't change one (`.timeline(.scrub(frame: 3))` and `(frame: 9)` share it); every `Area` has at least one case; `area` agrees with the case | an identifier repeats, depends on its payload, or names the wrong area |
| DK-2b | `FlareIntentTitleTests`: a table of every section 3.4 menu item and every toolbar action maps to exactly one case with that title; no two menu cases share a title within one menu | a menu item has no intent, or a title differs from section 3.4 |
| DK-3 | `FlareServicesBuiltTests`: each of stage, hits, shapes, properties, keyframes, easing and scenes in `.built` is the `Live*` type (by `type(of:)`); every other member equals `.live`'s reason; `FlareWorkspace(launch: FlareLaunch(arguments: []))` draws a rectangle on a new document through `LiveShapes` (one "Undo Add Rectangle"); `-FlareFixture` still gives `.fake()` | a member is still `NotBuilt`, a `Fake*` is in `.built`, or a fixture launch goes live |
| DK-4 | `FlareStageReadTests` on `.fake()`: `bounce` at 0 equals `FakeStage().drawList(...)`; during a move drag `stageList` is the `dragPreview`; a rectangle drag gives `stageMarks.draft` with 4 corners and nil after `endDrag`; a marquee drag gives its rect; one selection gives its bounds; no document gives nil | the stage reads the wrong frame, a drag preview is ignored, or a mark outlives its gesture |
| DK-5 | `FlareTimelineReadTests` on `.fake()`: `bounce` gives three rows, Ball's keys 0, 12, 24, 36, 47; `empty` gives no rows and the empty text; selecting Ball gives its row id; editing a symbol in place gives the symbol's rows | rows differ from `FakeKeyframes`, the empty text is missing, or a symbol edit shows the scene's rows |
| DK-6 | `FlareWindowSnapshots` writes the five PNGs above; J0 `testLaunchShowsWindowShell` asserts `suite.sidebar`, `suite.inspector`, the empty state's New Animation, the toolbar's Open, and each toolbar action by title; the easing journey passes from File > New Sample Animation | the window isn't `SuiteWindow`, a toolbar action is missing, or the easing route breaks |
| DK-7 | J0 extended: every toolbar button's identifier is its intent's (`flare.file.new` …); a disabled one's tooltip is its area's help; Auto-key reads selected after a click; the easing journey's six Edit > Undo steps still pass (Undo routed); selecting Ball in the sidebar still selects it (layers routed) | an identifier is missing, a disabled control has no reason, or Undo or the sidebar went dead |
| DK-8 | `FlareStageSnapshots` (goldens at 2x: `bounce` 0 and 30, `character` 12, draft, marquee, locked); `FlareToolsTests` with every tool enabled: each tool's drag on `empty` and `bounce` changes the document or the selection | the stage draws nothing or the wrong frame, a curve is flattened (the golden), or an enabled tool's drag changes nothing |
| DK-9 | `FlarePenFinishTests` on `.fake()`: two clicks then `finishPath` give one "Undo Add Path" with an open path; one anchor refuses and changes nothing; no draft is a no-op. J3 slice `testDrawShapesWithEachTool` on `-FlareFixture empty`: layers Rectangle 1, Ellipse 1 (equal width and height), Path 1 (closed), Path 2 (two clicks and Return); Escape mid-rectangle adds no layer; after Edit > Undo the menu reads "Redo Add Path"; R, E, P, V select their tools by key | a tool shortcut does nothing, Return doesn't finish a path, Escape commits, or Undo removes more than the last shape |
| DK-10 | `FlareTimelineSnapshots` (two PNGs); J9 slice `testTimelineScrub` on `bounce`: drag the playhead to 30, readout "30 / 48" and the timecode "01:06 / 02:00"; click Ball's name: its row selects Ball | the readouts don't follow the scrub, or a row click doesn't select |
| DK-11 | `FlareTransportSnapshots` (two PNGs); `testPlayAndStep` on `bounce`: scrub to 30, click Play; after 1 s the frame is not 30 and the play button's value is "Playing"; click Pause; Step Forward twice gives f + 2; Go to Start gives 0 | play doesn't advance, pause doesn't stop, or a button is wrong |
| DK-12 | `testSaveAndReopen` on `-FlareFixture bounce -FlareSaveTo <tmp>`: the toolbar's Save writes `<tmp>/Untitled.flare` (bytes start `{"`), the title reads the name with no dot; a relaunch with `-FlareOpenFile` on it shows Ball, Shadow and Background in the sidebar's LAYERS and the title "Untitled"; a read-only folder shows the save alert and the dot stays | nothing is written, the title is wrong, the reopened file differs, or a failed save is silent |
| DK-13 | J1 `testEveryMenuOpens`: each menu's item count equals section 3.4's; J29 `testEveryControlActsOrSaysWhy` on `bounce`: every enabled `flare.*` control changes a value or the shot, every disabled one has a reason | an item is hidden, or a control is dead |
| DK-14 | `FlareRecordingSnapshots` (one PNG); J6 slice `testMoveAndKeyByDrag` on `bounce`: Auto-key on and the ring exists; frame 30 (no key of Ball's there); V; drag Ball 100 pt right: Ball's lane gains a key at 30; Edit > Undo removes only that key; Auto-key off; frame 0; drag Shadow 50 pt right: at frame 30 Shadow sits 50 pt right too, and Shadow's lane has no key at 30 (only its static key at 0) | the ring is missing, a drag with auto-key on adds no key, Undo removes more than one, or a drag with it off keys the playhead |
| DK-15 | J26 `testDrawKeyAndSave`, un-skipped, no fixture flag: New; R and drag a rectangle; Auto-key on; V; frame 24, drag the rectangle 200 pt right (a new shape has its one key at 0, so this keys 24 and keeps 0); Space, wait, Space; ⌘Z then ⇧⌘Z; ⌘S to `-FlareSaveTo`; File > Open Recent lists it; open it: the rectangle's lane has keys at 0 and 24 and the title shows the name with no dot | any step fails on `.built`: draw, key, play, save or reopen |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-F1 no dead controls | every toolbar action, palette tool and menu item acts or is disabled with a reason | J29 (DK-13), `FlareToolsTests` (DK-8), J0 tooltips (DK-7) |
| QB-F3 one gesture, one step | a draw and a key drag are each one Undo | J3 slice (DK-9), J6 slice (DK-14), J26 (DK-15) |
| QB-L1 drag preview | the draft draws before mouse-up: the overlay redraws on a pointer move, the committed `Canvas` only when the list changes | `FlareStageReadTests` (draft set during the drag, DK-4); the probe's drag-preview mark in J3 is report-only until QH-5 |
| QB-V1 curves stay curves | an ellipse and a pen curve draw as cubics | `flare-stage-character@2x.png` golden (DK-8) |
| Keyboard parity | V A R E P, Escape, Return, Space, →, Home, End, ⌘N ⌘O ⌘S ⌘Z ⇧⌘Z ⌥K | J3 slice (DK-9), `testKeys` (DK-13), J26 |
| App audit | no Flare count over `UITests/audit-baseline.json` | the macOS run's `audit-flare-*.json` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by DK-15
  (`feature-done`) is green, `FlareJourneyTests` included, with
  `testDrawKeyAndSave` un-skipped in `+Loop.swift` and passing on `.built`.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey above and the audit counts. This is the first point
  at which a person can draw a rectangle, key its position, play it and
  save it.
