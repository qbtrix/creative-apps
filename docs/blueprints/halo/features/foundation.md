# Feature packet: foundation

**Feature:** Foundation: contracts, fakes, state and the window's seams. It
copies the blueprint's contracts into HaloModel, gives every use case a fake
and a disabled live stub, moves the document under one `edit` that records
undo, adds every stored property v1 needs, splits the window into one file
per area, and ships launch arguments and fixtures so the four W1 leads can
build side by side without touching a shared file.
**Line:** `line:halo` · **Wave:** W0 (`waves.md`) · **Lead branch:** `lead/foundation`

**Covers:** #286, #290, #149. Each closes through the task PR named in the
table below. The rest of the tasks have no issue of their own; they close
through the feature issue's `feature-done` PR.

**Depends on:** none. No SuiteUI or creative-core issue is needed: W0 is
alone in its wave, so its journeys stay in `UITests/HaloJourneyTests.swift`
(no #333), and FlareCore and CoreRaster on creative-core `main` already have
everything the contracts use (`docs/blueprints/halo/contracts/check.sh`
passes against them).

Blueprint sections it builds on: 2 (rules the components keep, launch
arguments, fixtures), 5 (contracts, fakes, live stubs, proof tests), 6
(command table), 7.1 (HB-6, HB-9), 7.2 (audit), 7.3 (L1, L2, L6), 8.3 (W0's
owned files). The packet wins over the blueprint and over any issue body
where they differ; the differences are listed under "Review notes folded in".

**Building blind.** FD-13 to FD-18 are in `Sources/HaloApp/`,
`Tests/AppSnapshotTests/` and `UITests/`, which the Linux gate never
compiles; the macOS job compiles them on `dev` after the lane merges. So:
copy the import and shape of a HaloApp file that already builds, check every
SwiftUI and AppKit API with the `apple-docs` MCP before use (say so in the
PR), keep views dumb (no assignment to Model state: the app-state lint), and
put every decision that can be pure into HaloModel tasks FD-1 to FD-12.

**Shared-file rule.** This feature owns only Halo files: `Sources/HaloModel/`,
`Sources/HaloApp/`, `Tests/HaloModelTests/`, `Tests/AppSnapshotTests/Halo*`
and `UITests/HaloJourneyTests.swift`. It never edits `Sources/SuiteUI/**`,
`project.yml`, `UITests/Journey*.swift`, `UITests/Journey+Input.swift`,
`Tests/AppSnapshotTests/AppSnapshotTests.swift`, `docs/c4/model.json` or
`docs/design.md`. `AppSnapshotTests.swift` keeps calling `HaloProject()` and
`HaloViewer(model:)`, so both keep those spellings. The C4 descriptions and
the Halo subsection of `docs/design.md` (blueprint sections 2 and 6) are
folded in later by the supervisor, not by this feature: the C4 lint passes
without them because every new file sits in an existing target folder.

## Journey steps

1. **H-J0** `testLaunchShowsWindowShell` (shipped, extended): launch; the
   window shell; the viewer's empty state "No Composition" with New
   Composition…; the inspector reads "No Selection". (FD-18)
2. **H-J1** `testNewComposition` (shipped, extended): New Composition…; type
   `abc` in Width: "Width must be a whole number of pixels." and Create
   disabled; type `1080` and `1920`; pick 24 fps; Create; the inspector header
   reads "1080 × 1920" and "24 fps · 10 s"; the sidebar row reads "Comp 1".
   The fields are found by their labels (#286). (FD-17, FD-18)
3. **H-J13** `testEveryControlActsOrSaysWhy` (new) on `-HaloFixture keyed
   -HaloControlsProbe`: read the `halo.controls` JSON; click each enabled
   control, Escape, ⌘Z; every enabled control changed the shot or a value;
   every disabled one has non-empty help (QB-F1). `testEveryMenuOpens` keeps
   opening every menu and checks each holds exactly section 6's Halo items.
   (FD-18)
4. **Layout** `testLayoutAtWidths` (new) on `-HaloFixture keyed` with a layer
   selected, relaunched with `-HaloWindowSize` at the minimum, 1024 × 768,
   1280 × 800, 1440 × 900 and 1920 × 1080: L1 nothing off the window and no
   overlap (the audit on each `halo-layout-<w>` shot), L2 the artboard
   centered within 1 pt with its aspect within 0.5%, L6 the artboard at least
   160 pt wide at the minimum. (FD-18)

The Model half of every step runs on Linux first: `HaloCommandTests` (QB-F1
on `.fake` and `.live`), `HaloViewerStateTests` (the artboard's value), and
`HaloFixturesTests`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Viewer | no composition: `EmptyStateView` "No Composition" with New Composition…; a composition with no layers: the artboard and the value "Frame 0: no layers" | none (drawing never fails; on `.live` the W0 stub draws nothing and the artboard value still lists the layers, from `viewerSummary`) | none |
| Inspector | no composition: "No Selection"; a composition, no layer: the composition rows and LAYERS; a layer: its header (name; kind, "Frames 20–50", parent) and "Select a layer to see its properties." in place of TRANSFORM until layer-keys | a refused edit's message (`refusal.message`) in `SuiteFont.caption` under the control `refusal.control` names | none |
| New Composition sheet | the defaults | each `CompositionSettings.problems` line under the form, Create disabled | none |
| Menus | every v1 item present; each one that can't act yet is disabled with `unavailableHelp(for:)` as help ("Create a composition first.", "Select a layer first.", then "Not built yet (#n).") | none | none |
| Transport (stub) | plain SF Symbol buttons in the status bar's trailing slot, disabled with "Playback arrives with #37." | none | none |

## Contract slice

The code is in `docs/blueprints/halo/contracts/` and blueprint section 5;
copy it, don't retype it. What W0 adds beyond those files:

```swift
// HaloProject.swift (FD-8, FD-10)
public struct HaloProject: Sendable, Equatable {          // == skips `services`
    public internal(set) var document: HaloDocumentState  // compositions, selection, id counters
    public internal(set) var services: HaloServices
    public internal(set) var history: HaloHistory          // written by HaloHistory.swift (history-files) and edit
    public internal(set) var playback: HaloPlaybackState   // HaloPlayback.swift (viewer-playback)
    public internal(set) var viewerDrag: HaloViewerDragState?  // HaloViewerDrag.swift (layer-keys)
    public internal(set) var selectedKeys: Set<HaloKeyRef> // HaloKeySelection.swift (easing)
    public internal(set) var file: HaloFileState           // HaloFiles.swift (history-files)
    public internal(set) var renderedFrame: HaloShownFrame?   // HaloRenderFrame.swift (render-out)
    public internal(set) var renderJob: HaloRenderJobState?   // HaloRenderJob.swift (render-out)
    public internal(set) var refusal: HaloRefusal?          // edit sets it; the next edit or dismissRefusal() clears it
    public init()                                           // .live
    public init(services: HaloServices)
    public var compositions: [HaloComposition] { get }      // computed over document, names unchanged
    public var selectedCompositionID: String? { get }
    public var selectedLayerID: String? { get }
    mutating func edit(_ name: String, control: String, coalesceKey: String? = nil,
                       _ body: (inout HaloDocumentState) throws -> Void)   // internal
    public mutating func endCoalescing()
    public mutating func dismissRefusal()
    mutating func takeLayerID(in compositionID: String) -> String           // internal
}
/// The frame Render Frame shows and the composition it was made from. Its
/// staleness is computed by render-out (HaloRenderFrame.swift) as
/// `source != selectedComposition`, so a scrub (the playhead lives in the
/// composition), a tick or any edit makes it stale with no stored flag.
public struct HaloShownFrame: Sendable, Equatable { public var frame: HaloRenderedFrame; public var source: HaloComposition }
// Also declared here, all Sendable and Equatable with public memberwise inits:
// HaloPlaybackState (playing, loops, startFrame, startTime), HaloViewerDragState
// (layerID, start, delta), HaloFileState (name, path, unsaved, opening, error, recent),
// HaloRecentFile (name, path), HaloRenderJobState (settings, plan, progress, outcome).

// HaloCommand.swift (FD-11)
public enum HaloCommand: Hashable, Sendable, CaseIterable { … }       // every v1 command, blueprint section 6
public enum HaloCommandArea: Sendable { case composition, playback, keys, layers, history, files, easing, render, text }
extension HaloProject {
    public func unavailableHelp(for command: HaloCommand) -> String?  // dispatches to Availability/HaloAvailability+<Area>.swift
    public func title(for command: HaloCommand) -> String             // "Undo New Layer" from history.undoTitle
}

// HaloViewerState.swift (FD-12)
extension HaloProject {
    public var viewerDrawList: HaloDrawList? { get }   // services.drawing at the playhead, offset by viewerDrag
    public var viewerSummary: String { get }           // "Frame 30: Background, Badge, Title: Hello Halo"
}

// HaloFixtures.swift (FD-9)
public enum HaloFixtures {
    public static let names: [String]   // empty, three-layers, keyed, parented, two-comps, reference, crowd, huge
    public static func project(_ name: String) -> HaloDocumentState?
}

// HaloApp (FD-13): HaloLaunch reads -HaloFixture, -HaloSample, -HaloOpenFile,
// -HaloSaveTo, -HaloRenderTo, -HaloWindowSize, -HaloControlsProbe, -HaloPerfProbe;
// HaloControls defines .haloControl(id:enabled:help:) and the halo.controls JSON.
```

`viewerSummary` lists layers bottom first, by name; a text layer reads
`<name>: <string>` (so H-J22 can read "Text 1: Hello"). Nulls and layers out
of their span are left out; nothing visible reads "no layers".

## Pseudocode

```
edit(name, control, coalesceKey, body):           # FD-10, the one place undo is recorded
  var copy = document
  do { try body(&copy) } catch let e as HaloEditError {
    refusal = HaloRefusal(control: control, message: e.message); return }
  refusal = nil
  guard copy != document else { return }          # a no-op edit is not a step
  let before = document; document = copy
  services.history.record(name, before: before, coalesceKey: coalesceKey, in: &history)

endCoalescing():  services.history.endCoalescing(in: &history)

takeLayerID(in compID):  defer { document.nextLayerNumber += 1 }
                         return "\(compID)-layer-\(document.nextLayerNumber)"   # never reused

unavailableHelp(for c):                           # FD-11
  switch c.area {
    case .composition: compositionHelp(c)          # state only: "Create a composition first."
    case .playback:    playbackHelp(c)             # In/Out state only; the rest "Not built yet (#37)."
    case .layers:      layersHelp(c)               # New state only; the rest "Not built yet (#770)."
    case .keys:        keysHelp(c)  ...            # one function per Availability/ file
  }

title(for .undo) = history.undoTitle ?? "Undo"; title(for .redo) = history.redoTitle ?? "Redo"

viewerDrawList:                                   # FD-12
  guard let comp = selectedComposition else nil
  var list = services.drawing.drawList(comp, at: comp.playheadFrame)
  if let drag = viewerDrag { list = list.offsetting(drag.layerID, by: drag.delta) }
  return list

viewerSummary:
  guard let comp = selectedComposition else "No composition"
  names = comp.layers.reversed().filter { $0.kind != .null && $0.isVisible(at: playhead) }
               .map { $0.kind == .text ? "\($0.name): \($0.text?.string ?? "Text")" : $0.name }
  return "Frame \(playhead): " + (names.isEmpty ? "no layers" : names.joined(", "))

HaloFixtures.huge:                                # FD-9; whole-number key values only
  2,000 layers; every property keyed every 2 frames over 120 frames,
  lowering keys per track until FakeProjectFiles().encode(huge).count <= 48 MiB
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: foundation`, `Fast-Check:
pass`, `Head:`. FD-18 also carries `feature-done`. Sizes are estimates from
the contract files' line counts; split any task that comes out bigger.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FD-1 | – | Key values and the W0 layer: the FlareCore aliases, `HaloProperty`, `HaloKeyState`, `HaloPropertyRow`, `HaloKeyRef`, `HaloEasingPreset`, `HaloTextContent`, `HaloEditError`, `HaloRefusal`, `HaloFileError` (lines 1–186 and 321–377 of `contracts/Contracts/HaloValues.swift`); `HaloLayer` gains `tracks`, `parentID`, `text` and `Codable` (`contracts/W0/HaloLayer.swift`, decoding through the clamping init); `HaloLayerDefaults.swift` | `Sources/HaloModel/Contracts/HaloValues.swift`, `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/HaloLayerDefaults.swift`, `Tests/HaloModelTests/HaloLayersTests.swift`, `Tests/HaloModelTests/HaloLayerOpacityClampTests.swift`, `Tests/HaloModelTests/HaloPropertyTests.swift` | – | ~380 |
| FD-2 | – | Document values: `HaloDrawItem`, `HaloDrawList` (with `offsetting`), `HaloDocumentState`, `HaloHistoryEntry`, `HaloHistory`, `HaloPlaybackTick`, the render settings, plan and outcome (lines 188–319 of `HaloValues.swift`, in their own file); `HaloComposition: Codable`; `duplicateComposition` remaps `parentID` to the copy's ids | `Sources/HaloModel/Contracts/HaloDocumentValues.swift`, `Sources/HaloModel/HaloProject.swift`, `Tests/HaloModelTests/HaloDocumentValuesTests.swift`, `Tests/HaloModelTests/HaloCompositionTests.swift` | FD-1 | ~260 |
| FD-3 | – | The protocols (`contracts/Contracts/HaloContracts.swift`) | `Sources/HaloModel/Contracts/HaloContracts.swift`, `Tests/HaloModelTests/HaloContractShapeTests.swift` | FD-2 | ~220 |
| FD-4 | – | Fakes A: `FakeLayerPlacing`, `FakeFrameDrawing`, `FakePropertyKeying` and their conformance suites, each `@Test(arguments:)` over `[HaloServices]`-style values so the live type joins later by adding one argument | `Sources/HaloModel/Fakes/FakeLayerPlacing.swift`, `Sources/HaloModel/Fakes/FakeFrameDrawing.swift`, `Sources/HaloModel/Fakes/FakePropertyKeying.swift`, `Tests/HaloModelTests/LayerPlacingContractTests.swift`, `Tests/HaloModelTests/FrameDrawingContractTests.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift` | FD-3 | ~360 |
| FD-5 | – | Fakes B: `FakeViewerDragging`, `FakeKeyEasing`, `FakeProjectHistory`, `FakeProjectFiles` and their suites | `Sources/HaloModel/Fakes/FakeViewerDragging.swift`, `Sources/HaloModel/Fakes/FakeKeyEasing.swift`, `Sources/HaloModel/Fakes/FakeProjectHistory.swift`, `Sources/HaloModel/Fakes/FakeProjectFiles.swift`, `Tests/HaloModelTests/ViewerDraggingContractTests.swift`, `Tests/HaloModelTests/KeyEasingContractTests.swift`, `Tests/HaloModelTests/ProjectHistoryContractTests.swift`, `Tests/HaloModelTests/ProjectFilesContractTests.swift` | FD-4 | ~330 |
| FD-6 | – | Fakes C: `FakePlaybackClock`, `FakeFrameRendering`, `FakeTextRasterizer`, `FakeCompositionRendering` and their suites | `Sources/HaloModel/Fakes/FakePlaybackClock.swift`, `Sources/HaloModel/Fakes/FakeFrameRendering.swift`, `Sources/HaloModel/Fakes/FakeTextRasterizer.swift`, `Sources/HaloModel/Fakes/FakeCompositionRendering.swift`, `Tests/HaloModelTests/PlaybackClockContractTests.swift`, `Tests/HaloModelTests/FrameRenderingContractTests.swift`, `Tests/HaloModelTests/CompositionRenderingContractTests.swift` | FD-4 | ~280 |
| FD-7 | – | The ten live stubs, one file each (`contracts/LiveStubs.swift`), and `HaloServices` with `.fake` and `.live` | `Sources/HaloModel/Live/LiveFrameDrawing.swift`, `Sources/HaloModel/Live/LiveLayerPlacing.swift`, `Sources/HaloModel/Live/LivePropertyKeying.swift`, `Sources/HaloModel/Live/LiveViewerDragging.swift`, `Sources/HaloModel/Live/LiveKeyEasing.swift`, `Sources/HaloModel/Live/LiveProjectHistory.swift`, `Sources/HaloModel/Live/LiveProjectFiles.swift`, `Sources/HaloModel/Live/LivePlaybackClock.swift`, `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Sources/HaloModel/Live/LiveCompositionRendering.swift`, `Sources/HaloModel/HaloServices.swift`, `Tests/HaloModelTests/HaloServicesTests.swift` | FD-5, FD-6 | ~230 |
| FD-8 | – | `HaloProject` holds `document: HaloDocumentState` with computed accessors for today's names; every stored property in the contract slice and their state types (`renderedFrame` is a `HaloShownFrame`, no stored stale flag); stored state `public internal(set)`; `init()` (live) beside `init(services:)`; hand-written `==` that skips `services` | `Sources/HaloModel/HaloProject.swift`, `Tests/HaloModelTests/HaloProjectTests.swift`, `Tests/HaloModelTests/HaloCompositionEdgeTests.swift` | FD-7 | ~300 |
| FD-9 | – | `HaloFixtures`: the eight fixtures in code, with the text strings H-J2 and H-J22 read ("Title" says "Hello Halo"); `huge` with whole-number values and encoded size under 48 MiB | `Sources/HaloModel/HaloFixtures.swift`, `Tests/HaloModelTests/HaloFixturesTests.swift` | FD-8 | ~330 |
| FD-10 | – | `edit`, `endCoalescing`, `dismissRefusal`, `takeLayerID`; today's mutators move under `edit` with the blueprint's step names (opacity writes its one static home, `HaloLayer.opacity`); I and O refusals become `HaloEditError` with control `halo.timeline`; Layer > New > Text stores its box from `services.text?.measure` (the estimate when nil); HB-9 | `Sources/HaloModel/HaloProject.swift`, `Sources/HaloModel/HaloTimeline.swift`, `Tests/HaloModelTests/HaloEditTests.swift`, `Tests/HaloModelTests/HaloBudget.swift`, `Tests/HaloModelTests/HaloFoundationBudgetTests.swift`, `Tests/HaloModelTests/HaloLayersTests.swift`, `Tests/HaloModelTests/HaloTimelineTests.swift` | FD-9 | ~380 |
| FD-11 | – | `HaloCommand` (every v1 command, its area and title; commands that carry a value have payload cases, e.g. `.setEasing(HaloEasingPreset)`, `.selectKey(HaloKeyRef, extending: Bool)`, `.setProperty(HaloProperty, Double)`, `.renameLayer(String, String)`, so every view acts through `perform(_:)`), `unavailableHelp(for:)` and `title(for:)`, and the nine area files as stubs (composition and the shipped Layer > New, Set In Point and Set Out Point answer state only) | `Sources/HaloModel/HaloCommand.swift`, `Sources/HaloModel/Availability/HaloAvailability+Composition.swift`, `Sources/HaloModel/Availability/HaloAvailability+Playback.swift`, `Sources/HaloModel/Availability/HaloAvailability+Keys.swift`, `Sources/HaloModel/Availability/HaloAvailability+Layers.swift`, `Sources/HaloModel/Availability/HaloAvailability+History.swift`, `Sources/HaloModel/Availability/HaloAvailability+Files.swift`, `Sources/HaloModel/Availability/HaloAvailability+Easing.swift`, `Sources/HaloModel/Availability/HaloAvailability+Render.swift`, `Sources/HaloModel/Availability/HaloAvailability+Text.swift`, `Tests/HaloModelTests/HaloCommandTests.swift` | FD-10 | ~320 |
| FD-12 | – | `viewerDrawList` and `viewerSummary`; timeline rows carry each layer's key frames (union of its tracks) for the diamonds; the status text's timecode suffix (" / 10 s at 30 fps"); HB-6 | `Sources/HaloModel/HaloViewerState.swift`, `Sources/HaloModel/HaloTimeline.swift`, `Sources/HaloModel/HaloStatusText.swift`, `Tests/HaloModelTests/HaloViewerStateTests.swift`, `Tests/HaloModelTests/HaloTimelineCostTests.swift`, `Tests/HaloModelTests/HaloStatusTextTests.swift` | FD-10 | ~300 |
| FD-13 | – | App: `HaloWindow` and `HaloViewer` move out of `HaloApp.swift` into their own files unchanged in behavior; `HaloLaunch` (the eight launch arguments; `services.text` set to `HaloTextRasterizer`); `HaloControls` (the `.haloControl(id:enabled:help:)` modifier, the preference key, the `halo.controls` JSON under `-HaloControlsProbe`); the stub `HaloTextRasterizer` | `Sources/HaloApp/HaloApp.swift`, `Sources/HaloApp/HaloWindow.swift`, `Sources/HaloApp/HaloViewer.swift`, `Sources/HaloApp/HaloLaunch.swift`, `Sources/HaloApp/HaloControls.swift`, `Sources/HaloApp/HaloTextRasterizer.swift` | FD-11, FD-12 | ~380 |
| FD-14 | – | `HaloWindow.perform(_:)` routes each command by area to the nine area files; each is a stub except the shipped commands it routes (composition, Layer > New, Set In / Out Point) | `Sources/HaloApp/HaloWindow.swift`, `Sources/HaloApp/HaloWindow+Viewer.swift`, `Sources/HaloApp/HaloWindow+Playback.swift`, `Sources/HaloApp/HaloWindow+Keys.swift`, `Sources/HaloApp/HaloWindow+Layers.swift`, `Sources/HaloApp/HaloWindow+Edit.swift`, `Sources/HaloApp/HaloWindow+File.swift`, `Sources/HaloApp/HaloWindow+Easing.swift`, `Sources/HaloApp/HaloWindow+Render.swift`, `Sources/HaloApp/HaloWindow+Text.swift` | FD-13 | ~260 |
| FD-15 | – | The stub views each W1/W2 feature replaces whole (canvas, gestures, rendered frame, transport, layer, easing and text inspectors); the inspector always shows LAYERS and hosts `HaloLayerInspector`, which shows the layer header and hosts the EASING and TEXT slots; the timeline draws each lane's key diamonds; every slot view a later feature replaces (`HaloEasingInspector`, `HaloTextInspector`, `HaloTransport`, `HaloRenderedFrameView`, `HaloViewerCanvas`, `HaloViewerGestures`) has the one initializer `init(model: HaloProject, perform: @escaping (HaloCommand) -> Void)`, so a feature replaces the body and never the call site; the refusal caption; `HaloViewer` (which holds the artboard, status row and timeline) routes Space, ←, →, Home, End, I, O and ⌫ through `onKeyPress` to `perform(_:)`, so each later feature only fills its area file | `Sources/HaloApp/HaloViewer.swift`, `Sources/HaloApp/HaloViewerCanvas.swift`, `Sources/HaloApp/HaloViewerGestures.swift`, `Sources/HaloApp/HaloRenderedFrameView.swift`, `Sources/HaloApp/HaloTransport.swift`, `Sources/HaloApp/HaloLayerInspector.swift`, `Sources/HaloApp/HaloEasingInspector.swift`, `Sources/HaloApp/HaloTextInspector.swift`, `Sources/HaloApp/HaloCompositionInspector.swift`, `Sources/HaloApp/HaloLayerList.swift`, `Sources/HaloApp/HaloTimelineView.swift`, `Tests/AppSnapshotTests/HaloWindowSnapshots.swift`, `Tests/AppSnapshotTests/HaloLayersSnapshots.swift`, `Tests/AppSnapshotTests/HaloTimelineSnapshots.swift` | FD-14 | ~380 |
| FD-16 | – | Menus on `HaloCommand`: Composition, Layer, File, Edit (`CommandGroup(replacing: .undoRedo)` titled by `title(for:)`) and Animation; every item sends a command through the focused window and is disabled with `unavailableHelp(for:)` as help; the plain keys (Space, arrows, Home, End, I, O, ⌫) are named in each item's help, not set as key equivalents (blueprint D5) | `Sources/HaloApp/HaloCommands.swift`, `Sources/HaloApp/HaloCompositionCommands.swift`, `Sources/HaloApp/HaloFileMenu.swift`, `Sources/HaloApp/HaloEditMenu.swift`, `Sources/HaloApp/HaloAnimationMenu.swift` | FD-14 | ~300 |
| FD-17 | #286, #290 (closes both) | The New Composition fields get `.accessibilityLabel`s matching their column labels; every Halo-owned control gets a `halo.*` identifier through `.haloControl` (the SuiteUI chrome stays with SuiteUI) | `Sources/HaloApp/NewCompositionSheet.swift`, `Sources/HaloApp/HaloCompositionInspector.swift`, `Sources/HaloApp/HaloLayerList.swift`, `Sources/HaloApp/HaloTimelineView.swift`, `Sources/HaloApp/HaloWindow.swift`, `Tests/AppSnapshotTests/HaloCompositionSnapshots.swift`, `Tests/AppSnapshotTests/HaloCompositionInspectorSnapshots.swift` | FD-15, FD-16 | ~150 |
| FD-18 | – (`feature-done`) | Journeys: H-J0 and H-J1 extended, H-J13 `testEveryControlActsOrSaysWhy`, `testLayoutAtWidths` (L1, L2, L6); the last test in run order still launches a Journey | `UITests/HaloJourneyTests.swift` | FD-17 | ~220 |
| FD-19 | #149 (closes) | Names compare after collapsing inner whitespace runs to one space and dropping format characters (category Cf); stored names are normalized the same way | `Sources/HaloModel/NameKey.swift`, `Tests/HaloModelTests/HaloNameWhitespaceTests.swift` | – | ~120 |

FD-19 touches no other task's file, so it can run in the first build wave
with FD-1. The Model chain is FD-1 → FD-2 → FD-3 → FD-4 → (FD-5 ∥ FD-6) →
FD-7 → FD-8 → FD-9 → FD-10 → (FD-11 ∥ FD-12); the app chain is FD-13 → FD-14
→ (FD-15 ∥ FD-16) → FD-17 → FD-18. The other existing Halo tests
(`HaloComposition*`, `HaloRename*`, `HaloUniqueName*`, `HaloNameCaseFoldingTests`,
`HaloCompositionDeleteCommandTests`, `HaloRenderTests`, `HaloRenderEdgeTests`)
are foundation's to keep green: a task whose change breaks one fixes it in
the same PR and lists it as an owned file (FD-8 and FD-10 are the likely
ones). `HaloRenderTests` and `HaloRenderEdgeTests` pass to viewer-playback
once this feature is done.

**Stubs W0 hands over.** Each file below is created here as a stub and
replaced whole by the feature named, which is why W0 writes the least that
compiles and says why it is disabled: `Live/*` (their features),
`Availability/HaloAvailability+<Area>.swift` (the area's feature),
`HaloWindow+<Area>.swift` (same), `HaloViewerCanvas`, `HaloTransport`
(viewer-playback), `HaloViewerGestures`, `HaloLayerInspector` (layer-keys,
which keeps the EASING and TEXT slots), `HaloLayerList` (layer-panel),
`HaloRenderedFrameView` (render-out), `HaloEasingInspector`,
`HaloTimelineView` (easing), `HaloTextInspector`, `HaloTextRasterizer`
(text-layers).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| FD-1 | `HaloPropertyTests`: `parse` reads "45", "45°", " 50 %" (0.5 for opacity) and refuses "abc" and "inf"; `text` gives "960.0 px", "100%", "45°" and "–" for NaN. `HaloLayersTests`: a layer with tracks, a parent and text encodes and decodes equal; a decoded opacity of 3 or NaN comes back clamped (`HaloLayerOpacityClampTests`); `withID` copies all three fields; `defaultValue` puts anchor and position at the box center | a typed value is misread, a field is dropped by `Codable` or `withID`, or a file can carry an out-of-range opacity |
| FD-2 | `HaloDocumentValuesTests`: `offsetting` moves only the named layer; `HaloHistory.undoTitle` reads "Undo New Layer" and nil when empty; a document with two compositions round-trips through `JSONEncoder`/`JSONDecoder` equal. `HaloCompositionTests`: Duplicate Composition of a parented pair points the copy's child at the copy's parent | the drag preview moves other layers, a title is wrong, or a duplicated child follows the original's parent |
| FD-3 | `HaloContractShapeTests`: a minimal conformer of `HaloService` has `unavailableHelp == nil` by default; each protocol can be used as an existential (`any FrameDrawing` …) | a protocol can't be held in `HaloServices` |
| FD-4 | The three suites copy the proof tests `fakeDrawListSkipsNullsAndInterpolates`, `fakeParentingFollowsAndRefusesCycles`, `fakeOpacityHasOneStaticHome`, plus: a layer outside its span is absent; draw order is bottom first; a stopwatch on keys the playhead and the last frame; `setValue(.nan)` throws `.notANumber` and changes nothing | any fake breaks its protocol's doc comment |
| FD-5 | Suites copy `fakeDragKeysAnimatedPosition`, `fakeEaseInBendsTheCurve`, `fakeHistoryCoalescesEndsAndClearsRedo`, `fakeFilesRoundTripAndRefuse`, plus: the 101st record drops the oldest; a zero drag changes nothing; `decode` of 64 MiB + 1 byte throws `.tooLarge`, of version 2 `.newerVersion(2)` | coalescing keeps redo, a drag of zero records, or a refused file isn't refused |
| FD-6 | Suites copy `fakeRenderRunsEveryFrameAtThePlanSize` and the clock edges of `liveStubsSayWhyAndClockMatchesFlareCoreEdges`: loop wraps to 0, play-once stops on the last frame with `ended`, NaN elapsed stays on `startFrame`; `render` of a list with a null counts no skipped layer; a cancelled run reports `.cancelled(frames:)` with the frames written | a frame is skipped, mis-sized or written after cancel |
| FD-7 | `HaloServicesTests` checks an invariant that stays true as each feature lands its live type: every `.live` service either has `unavailableHelp == nil`, or has non-empty help naming its issue and every write throws `.notBuilt` leaving the composition equal; on W0's `dev` all ten are the second kind (that part is asserted per contract in its own suite, which the feature that lands the live type rewrites); every `.fake` service has `unavailableHelp == nil` | a stub acts, says nothing, or a later live type would have to edit this file |
| FD-8 | `HaloProjectTests`: `HaloProject()` and `HaloProject(services: .fake)` both start with no compositions; two projects with equal documents and state but different services are `==`; `compositions` and `selectedCompositionID` read through `document` (every existing composition test still passes unchanged) | a computed accessor drifts from `document`, or `==` compares services |
| FD-9 | `HaloFixturesTests`: each fixture matches its row in blueprint section 2 (counts of compositions, layers and keys; `keyed` Ball x 160 at 0 and 960 at 24; `three-layers` order Title, Badge, Background, Rig with Title "Hello Halo" in 24–72); every fixture round-trips through `FakeProjectFiles`; `huge` encodes to more than 16 MiB and at most 48 MiB (three quarters of `FakeProjectFiles.maxBytes`) and every key value is a whole number | a fixture drifts from what its journeys assert, or `huge` could cross the 64 MiB limit and break H-J10 |
| FD-10 | `HaloEditTests`: each shipped mutator records exactly one step with its name ("New Composition", "Delete Composition", "New Layer", "Set In Point", "Change Opacity", …); a throwing body sets `refusal` with its control and message and changes nothing; a no-op edit records nothing; three scrubs with one `coalesceKey` are one step and `endCoalescing` makes the fourth a new one; `takeLayerID` never repeats after a delete; New Text with a rasterizer whose `measure` returns 250 × 90 stores width 250 and height 90; I after O sets the refusal `inPointAfterOut` on `halo.timeline` | an edit records zero or two steps, a refusal changes the document, or an id is reused |
| FD-11 | `HaloCommandTests`: on `.fake` and `.live` with `keyed`, every command is enabled or disabled with non-empty help; shipped commands (composition, Layer > New, Set In / Out Point) are enabled on `.live` when state allows; every other area's commands read "Not built yet (#n)." with the area's issue; `title(for: .undo)` reads "Undo New Layer" after New Layer on `.fake` | a command is disabled with no help, a shipped command turns off, or an unbuilt one turns on |
| FD-12 | `HaloViewerStateTests` on `three-layers` (`.fake`): at 12 "Frame 12: Background, Badge"; at 30 "Frame 30: Background, Badge, Title: Hello Halo"; on `empty` "Frame 0: no layers"; `viewerDrawList` with a `viewerDrag` of (100, 0) moves only that layer. `HaloTimelineTests`: Ball's row carries key frames [0, 12, 24]. `HaloStatusTextTests`: " / 10 s at 30 fps" | the summary lists a null or an out-of-span layer, or the drag preview is lost |
| FD-13 | Snapshot `HaloWindowSnapshots` (macOS): the window on `HaloProject()` looks as before the move (`halo-window-launch-light.png`, `-dark.png`); `HaloLaunch` parsing is covered on Linux by nothing (it is app-side), so its reader stays a switch over strings with no logic beyond `HaloFixtures.project(_:)` | `AppSnapshotTests.swift` stops compiling or the launch window changes |
| FD-14 | The macOS build on `dev` and H-J13 (FD-18): every routed command does what its menu item did before; nothing else acts | a shipped command stops working |
| FD-15 | Snapshots: `halo-inspector-layer-selected-light/dark.png` (header and the "Select a layer…" text, LAYERS shown), `halo-timeline-keys-light/dark.png` (Ball's diamonds at 0, 12, 24), `halo-refusal-light/dark.png` (the caption under the timeline) | the layer list hides when a layer is selected, diamonds are missing, or the refusal has no caption |
| FD-16 | H-J13 and `testEveryMenuOpens` (FD-18): each menu holds exactly the section 6 items; every disabled item shows its help | an item is missing, extra, or disabled with no help |
| FD-17 | H-J1 finds the fields by label (`app.textFields["Width"]`); the audit on the sheet shot reads `unnamed` 0 for `halo`; snapshots `halo-composition-*` unchanged | a field has no label or a Halo control no identifier |
| FD-18 | The four journeys above on the `dev` CI run | any step's assert |
| FD-19 | `HaloNameWhitespaceTests`: renaming "Comp 2" to `Comp\u{00A0}1`, `Comp\u{2009}1`, `Comp 1\u{200B}`, `Comp 1\u{FEFF}`, `Comp  1`, `Comp\t1` while "Comp 1" exists is refused; "Comp\t3" is stored as "Comp 3" | any listed look-alike is accepted, or a tab lands in a stored name |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-6 timeline with many layers (QB-L10 model half) | `timelineRows` on `crowd` ≤ 5 ms device, ≤ 50 ms debug CI | `HaloTimelineCostTests.timelineRowsCrowd` (FD-12) |
| HB-9 any edit | `edit`'s copy, compare and record on `crowd` ≤ 2 ms device, ≤ 20 ms debug CI | `HaloFoundationBudgetTests.editRecord` (FD-10) |
| QB-F1 no dead controls | every command enabled or disabled with help | `HaloCommandTests.everyCommandActsOrSaysWhy` (FD-11), H-J13 (FD-18) |
| QB-F3 one gesture, one step | each shipped mutator is one named step | `HaloEditTests.eachMutatorIsOneNamedStep` (FD-10) |
| Audit `unnamed` | 5 → 0 | `audit-halo-*.json` on the `feature-done` run (FD-17) |
| Audit `identifier` | 10 → ≤ 3 (SuiteUI chrome left) | same (FD-17) |
| Layout L1, L2, L6 | blueprint 7.3 tolerances | `testLayoutAtWidths` (FD-18) |

The baselines in `UITests/audit-baseline.json` are lowered by CI's `Audit
lower` job after a green run, never by hand; FD-17's PR body states the
counts it expects.

## Done check

- **Journeys green:** the macOS run on `dev` triggered by FD-18's
  `feature-done` PR is green, with H-J0, H-J1, H-J13, `testEveryMenuOpens`
  and `testLayoutAtWidths` passing and every other app's journeys unchanged.
- **Audit zero new:** no `halo` count over `UITests/audit-baseline.json`;
  `unnamed` and `identifier` measured lower (the Audit lower job commits them).
- **Contact sheet:** the lead comments on this feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per journey and the audit
  counts. Expected new shots: `halo-layout-<w>` at five sizes and the
  controls sweep; the launch and new-composition shots look as before apart
  from the inspector's layer header and the timeline diamonds.

## Review notes folded in

From the review of the blueprint PR (#767), where they change this feature:

- **No shared docs.** The blueprint's last W0 task (C4 descriptions and the
  Halo subsection of `docs/design.md`) is dropped: the supervisor folds
  those in. W0 owns neither file.
- **`renderedFrameStale` is not stored.** W0 stores `renderedFrame:
  HaloShownFrame?` (the frame and the composition it was made from);
  render-out computes staleness in its own file. Scrub, tick and edit live in
  other features' files and could never keep a stored flag right.
- **`huge` fixture margin.** Whole-number key values and an encoded size of
  at most 48 MiB, asserted in `HaloFixturesTests`, so H-J10's large-file step
  can't trip the 64 MiB `tooLarge` limit.
- **Viewer summary and text.** The blueprint's H-J2 (names only) and H-J22
  ("Text 1: Hello") disagreed on how a text layer reads; the summary reads
  `<name>: <string>` for text, and `three-layers`' Title says "Hello Halo".
- **C4 statuses.** `halo-window` and `halo-viewer` are `planned` until FD-13
  creates their files (fixed in `c4-planned.json` by the packet PR).
- **Split values.** `HaloValues.swift` (377 lines) is copied as two files,
  `HaloValues.swift` and `HaloDocumentValues.swift`, so FD-1 and FD-2 each
  stay under 400 lines; both sit in `Contracts/`, the `halo-contracts`
  component.
