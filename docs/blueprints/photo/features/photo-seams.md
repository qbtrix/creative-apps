# Feature packet: photo-seams

**Feature:** PV-0, the seams. Lands the v2 contracts, fakes, `PhotoServices`,
the `NotBuilt` stand-ins, every v2 stored property, step ids, drag routing
by component, the per-layer composite hook, and splits Photo's five shared
files (`PhotoWorkspace`, `PhotoIntent`, `PhotoWindow`, `PhotoCommands`,
`PhotoPanel`) so every later Photo feature owns its own files.
**Line:** `line:photo` · **Wave:** 0 (`waves.md`) · **Tier:** p1 by dependency
· **Lead branch:** `lead/photo-seams`

**Status:** built on `dev` (lead #812). Tasks: S-1 #932, S-2 #948, S-3 #950,
S-4 #951, S-6a #956, S-6b #959, S-5 #966, S-7a #969, S-7c #972, S-7b #974,
S-8a #978, S-8b #985, S-9 #986, S-10a #987, S-10b #988, S-11a #989,
S-11b #991, S-12 #992, S-13 #979 (model budgets) and #997 (latency series).
Anatomy round 1 (CI run 727): fixes #1010 (refusal names the Layers tab;
clone and heal stop re-stamping the previous dab), #1011 (Escape-cancels-crop
and `-PhotoFixture` journeys), #1012 (warning pill, refusals in the error
style). Anatomy round 2 (CI run 38694361192): fixes #1029 (a fixture launch
stays fitted while the window settles), #1030 (Eyedropper hint, Preview data
tooltip, refusal in the caption type) and #1031 (fitted-picture, unknown-fixture
and `.live` Eyedropper journey checks; the clone and heal budget times 20 px
moves). Anatomy round 3 (CI runs 38700713285 and 38704216123): fixes #1050
(the fixture and launch journeys check geometry and the disabled Eyedropper
instead of the zoom pill's label and a hover tooltip) and #1053 (the QB-F1
tools tests compare what each tool changes, so a dead stroke tool fails).
Needs-ui filed: #952, #953, #954, #1049. Gaps filed from the rounds (v1
behaviour or follow-ups): #1024, #1025, #1026, #1027, #1032. The paint
refusal now reads "Select an image layer in the Layers tab to paint on."

**Covers:** no open issue (blueprint 8.1: PV-0 has none). It is the critical
path: photo-documents, photo-edit and photo-crop (wave 1) and
photo-adjustment-layers (wave 2) start from its merged result.

**Depends on:** none. No creative-core issue: every contract compiles against
CoreRaster on creative-core `dev` 4cac701 (`main` is cfad97f; no CoreRaster
difference), as blueprint section 5 records.

Blueprint sections it builds on: 2.4 (why the seams first), 5.1–5.3 (every
type and signature, verbatim), 4.4 (fixtures), 6.1 rules 5, 7 and 9, 7.1
(PB-2, PB-9), 7.2.

**What it changes for a person:** nothing on `.live` except the Eyedropper
tool on the rail (I), disabled with "Not built yet (PV-9).". Under
`-PhotoFixture <name>` the window runs on the fakes and shows a "Preview
data" pill. The 309+ existing Photo model tests and the twelve v1 journeys
(V1–V12) are the regression gate and must stay green unchanged.

**Not in this feature** (owned elsewhere, see `waves.md`):

- No journey file. Moving `writeTestPhoto` into
  `UITests/PhotoJourneyTests+Fixtures.swift` is photo-journey-kit (it waits
  on SuiteUI #778, which makes the journey template compile a second Photo
  file, #333). The perf journeys PJ-P1 and PJ-P2 are photo-crop's CP-7.
- No `docs/c4/model.json` and no `docs/design.md` edit. The component
  `photo-model-sources` / `photo-app-sources` (path = the target folder)
  already owns every new file, so the C4 gate passes; the supervisor folds
  `docs/blueprints/photo/c4-planned.json` and section 6.1 in later.
- No `Sources/SuiteUI/**`, `project.yml`, `UITests/Journey*.swift` or
  `Tests/AppSnapshotTests/AppSnapshotTests.swift` edit (shared-file rule).
  Missing components use plain placeholders (CLAUDE.md).

## Review notes folded in (review of #768)

1. **Overlay marks are found by journeys.** Blueprint 7.2 says the new marks
   are `accessibilityHidden`, and SuiteUI's `CanvasMarks` hides its marks
   today, but PJ-11, PJ-12 and PJ-14 query them. So `PhotoCanvasOverlay`
   (S-10b) wraps each mark in one **identified, non-control** accessibility
   element: a clear shape at the mark's frame with
   `.accessibilityElement()`, an identifier (`photo.canvas.crop`,
   `photo.canvas.selection`, `photo.canvas.transform-box`,
   `photo.canvas.brush-cursor`), a label ("Crop area", "Selection",
   "Transform box", "Brush size"), the `.isImage` trait, no button trait and
   `.allowsHitTesting(false)`. The SuiteUI mark inside stays hidden. The
   audit's `identifier` and `unnamed` checks stay at baseline because each
   element carries both.
2. **One composite hook for render, Merge Down and Flatten.** The per-layer
   step lives in `PhotoLayerComposite.swift` as a static function that takes
   the adjustment and masking services as arguments, so both
   `PhotoRender` and photo-edit's `LiveEdit` merging call the same code. When
   photo-adjustment-layers (and later PV-5) fill it, Merge Down and Flatten
   pick up adjustment layers and masks without either feature owning
   `Live/LiveEdit.swift`.
3. **The brush cursor needs the pointer.** S-10b passes `CanvasViewport`'s
   existing `onPointer` (an artboard point, nil on exit) into
   `PhotoCanvasOverlay` as `hover: CGPoint?`, so PV-4 (wave 3) draws the ring
   in `BrushCursorOverlay.swift` alone and never edits `PhotoEditor.swift`
   (PV-10's in wave 3).
4. **How `.live` gets a recovery folder.** `PhotoWindow` builds its services
   once through `PhotoWindow.fileServices(_:)`, declared in
   `PhotoWindow+File.swift` (S-8b) as the identity. photo-documents (who owns
   that file in wave 1) returns `.live` with `recovery` pointed at
   `-PhotoRecoveryDir` or the default folder, without touching
   `PhotoWindow.swift` or `PhotoServices.swift`.

## Journey steps

No new journey. What each task proves, in Model tests on Linux and in the
existing journeys on the next macOS run:

1. A new image, every v1 tool, every v1 menu and the Adjust and Layers tabs
   behave exactly as before on `.live` (V1–V12 unchanged; all existing model
   tests unchanged).
2. `PhotoWorkspace(services: .fake)` runs each tool on every fixture, and every
   tool changes the image (`PhotoToolsTests`, through `toolHelp`).
3. `.live` holds no `Fake` type, and lists which use cases are still
   `NotBuilt` (`LiveServicesTests`).
4. An edit, an undo and a new edit leave `currentStepID` different from the
   saved one; undoing everything after a 50-step trim still reads dirty.
5. Launching with `-PhotoFixture sample` shows the sample picture, the
   Eyedropper tool enabled and a "Preview data" pill; without it the
   Eyedropper is disabled with "Not built yet (PV-9).".

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Main window on `.live` | no image: today's empty canvas and "No Image Open" | a v2 command reached anyway refuses with "Not built yet (PV-n)." in the status line (4 s, warning color) | none new |
| Main window under `-PhotoFixture empty` | the empty state plus the "Preview data" pill | an unknown fixture name: launch as `empty`, status line "No fixture named <name>." | none |
| Tool rail | – | Eyedropper disabled on `.live`, tooltip "Not built yet (PV-9)." | – |
| Status line | no message: only the pills | `statusMessage` shown left of the pills with `exclamationmark.triangle` until `clearStatus()` (the window calls it 4 s later) | – |

## Contract slice

Verbatim from blueprint 5.1–5.3; S-1 to S-7 land exactly those blocks (the
blueprint compiled them on Linux). The additions below are this packet's,
from the review notes:

```swift
// Sources/PhotoModel/PhotoLayerComposite.swift (S-7b). One layer's
// contribution to the picture under it, for the renderer and for LiveEdit's
// Merge Down and Flatten (review note 2). Today: a pixel layer composited
// with its blend and opacity at its offset; an adjustment layer returns
// `below` unchanged until photo-adjustment-layers fills that case; masks are
// ignored until PV-5 fills them.
public enum PhotoLayerComposite {
    public static func composite(_ content: LayerContent, onto below: PixelBuffer,
                                 origin: (x: Int, y: Int),
                                 adjusting: any AdjustmentLayering,
                                 masking: any LayerMasking) throws -> PixelBuffer
}

// Sources/PhotoModel/PhotoFixtures.swift (S-5, S-12)
public enum PhotoFixture: String, CaseIterable, Sendable { case empty, sample, layered, large }
extension PhotoWorkspace {
    /// The fixture on `.fake` services (blueprint 4.4; `limit` is left out, see S-5).
    public static func fixture(_ name: PhotoFixture) throws -> PhotoWorkspace
}
public struct PhotoLaunchOptions: Equatable, Sendable {   // S-12
    public var fixture: PhotoFixture?            // -PhotoFixture <name>
    public var unknownFixture: String?           // a name that isn't one
    public var windowWidth: Double?              // -PhotoWindowWidth <pt>, 880...4096
    public init(arguments: [String])
}

// Sources/PhotoApp/PhotoWindow+File.swift (S-8b)
extension PhotoWindow {
    /// The services a window runs on when no fixture is asked for. PV-0: `.live`.
    /// photo-documents points `recovery` at -PhotoRecoveryDir here.
    static func fileServices(_ live: PhotoServices) -> PhotoServices { live }
}

// Sources/PhotoApp/PhotoWindow+<Area>.swift (S-8a), one per area; PhotoWindow applies all nine.
// A feature keeps its own @State, alerts, dialogs and timers inside its area's modifier.
struct PhotoFileArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: (PhotoIntent) -> Void
    func body(content: Content) -> some View { content }   // identity until photo-documents
}

// Sources/PhotoApp/PhotoRailTool.swift (S-10a): the rail's tool, carrying model.toolHelp(tool).
struct PhotoRailTool: PaletteTool { let tool: PhotoTool; let help: String? }

// Sources/PhotoModel/PhotoWorkspace.swift (S-6a)
extension PhotoWorkspace {
    mutating func insertLayer(named: String, pixels: TiledPixels?, kind: PhotoLayerKind, at index: Int) -> PhotoLayer.ID
    mutating func reserveLayerIDs(after maxID: Int)
}

// Sources/PhotoApp/PhotoCanvasOverlay.swift (S-10b)
struct PhotoCanvasOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double
    let hover: CGPoint?   // CanvasViewport's onPointer, artboard points; nil when outside
}
```

## Pseudocode

```
S-6a  PhotoWorkspace: add the stored v2 properties of 5.3 (services excluded from ==);
      PhotoLayer: kind, hasMask, isMaskEnabled; AdjustmentSettings (and CurvePoint): Hashable, Codable
        (photo-documents writes them into photo/document.json; the file is frozen after this task)
      PhotoTool gains .eyedropper ("I"); PhotoTool.unavailableHelp gives "Not built yet (PV-9)." for it
        (the fallback text), so today's PhotoToolsTests still passes; empty .eyedropper arms in the
        switches of PhotoStroke.swift (:71, :111), PhotoIntent.swift (:41, :53, :65), PhotoPanel.swift (:62)
      toolHelp(tool) = tool == .eyedropper ? services.sampling.unavailableHelp : tool.unavailableHelp
      insertLayer(named:pixels: TiledPixels?, kind:at:) and nextLayerNumber made internal;
        reserveLayerIDs(after: maxID) so a loaded document's ids are never handed out again
      LayerGeometryChange and layerGeometryChanged(_:_:) declared in a new PhotoMask.swift (empty body);
        removeLayer calls it with .removed
      start(): reset selectionMask, masks, editsMask, transformDraft, statusMessage, fileKind
      invariant comment: pixels holds one buffer per *pixel* layer

S-6b  PhotoHistory: nextID counter (never reused); each recorded step carries id;
      currentStepID = undo.last?.id ?? baseStepID; trimming the oldest step sets
        baseStepID = trimmed.id (like baseName)
      isDirty = canvas != nil && savedStepID != currentStepID (here, not in PV-1's file, so every
        feature reads one definition); start() sets savedStepID = currentStepID
      new edits .selection(PixelRect?, Mask?), .maskTiles(layer, [Int: PixelBuffer]);
      PhotoStack keeps masks; apply(.layers) guard compares pixel-layer ids only

S-7a  drag(from:to:pressure:modifiers:zoom:) and drags([...], zoom:) are the real ones;
      drag(from:to:pressure:sampling:) == drag(..., modifiers: sampling ? [.option] : [], zoom: 1)
      route by tool: transformDraft != nil -> transformDrag (stub: no-op)
                     .marquee -> selectionDrag (today's code, moved)
                     .crop    -> cropDrag (today's code, moved)
                     .eyedropper -> sampleDrag: services.sampling.sample(picture around point)
                                    -> tool options color; never a history step
                     else today's paint

S-7c  paintTarget(): .pixels(id); nil + statusMessage "Select an image layer in the Layers tab to paint on." on an
        adjustment layer; brush, eraser, clone and heal write through it
      every dab (PhotoStroke, PhotoRetouch), Delete and Fill weight each pixel by
        selectionCoverage(x:y:) (1 inside today's rect, 1 everywhere with no selection: no change yet)
      Select All, Deselect and Apply Crop set or clear selectionMask through PhotoSelectionMask.swift;
        applyCrop calls layerGeometryChanged(id, .cropped(rect)) for each layer

S-7b  PhotoRender: for each visible layer bottom-up: picture = PhotoLayerComposite.composite(...)
      Image Size, Rotate and Straighten call layerGeometryChanged for each layer

S-8a  PhotoIntent: case file(FileIntent), edit(EditIntent), crop(CropIntent), history(...),
      select(...), adjustmentLayer(...), transform(...), export(...), sample(...), confirm, dismiss;
      the flat .selectAll case stays (PhotoSelectAllMenuTests matches on it)
      each PhotoWindow+<Area>.swift (all nine, File and Export included as stubs) declares its area
        enum, an empty perform switch, and an identity ViewModifier PhotoWindow applies:
        `struct Photo<Area>Area: ViewModifier { let model: PhotoWorkspace; let perform: (PhotoIntent) -> Void }`
        so a feature adds its own @State, alerts, dialogs, timers and window hooks inside its area's
        modifier without editing PhotoWindow.swift (photo-documents: autosave, Keep layers?, the failed-save
        flag, the close prompt, the edited dot)
      perform(.confirm): if confirmTransform() {} else today's applyCrop
      perform(.dismiss): if dismissTransform() {} else today's cancelCrop / deselect
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: photo-seams`, `Fast-Check:
pass`, `Head:`. The last merged task carries `feature-done`. `M/` is
`Sources/PhotoModel/`, `A/` `Sources/PhotoApp/`, `MT/`
`Tests/PhotoModelTests/`, `ST/` `Tests/AppSnapshotTests/`. A moved block
counts twice in the diff, so the split tasks below are sized for that.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| S-1 | – | Shared values, document, edit and crop contracts (5.1, verbatim) | `M/Contracts/PhotoContractTypes.swift`, `M/Contracts/DocumentContracts.swift`, `M/Contracts/EditContracts.swift`, `M/Contracts/CropContracts.swift`, `MT/PhotoContractsTests.swift` | – | ~330, 5 |
| S-2 | – | Selection, layer and output contracts (5.1, verbatim) | `M/Contracts/SelectionContracts.swift`, `M/Contracts/LayerContracts.swift`, `M/Contracts/OutputContracts.swift`, `MT/PhotoContractsLayerTests.swift` | S-1 | ~300, 4 |
| S-3 | – | The fakes (5.2), one file per contract file | `M/Fakes/FakeDocuments.swift`, `M/Fakes/FakeEdit.swift`, `M/Fakes/FakeGeometry.swift`, `M/Fakes/FakeOutput.swift`, `MT/PhotoFakesTests.swift` | S-2 | ~340, 5 |
| S-4 | – | `PhotoServices`, `NotBuilt` stand-ins and the eight `Live/` stubs; `LiveServicesTests` | `M/PhotoServices.swift`, `M/Live/NotBuilt.swift`, `M/Live/LiveDocuments.swift`, `M/Live/LiveEdit.swift`, `M/Live/LiveCrop.swift`, `M/Live/LiveSelection.swift`, `M/Live/LiveAdjustmentLayers.swift`, `M/Live/LiveTransform.swift`, `M/Live/LiveExportSizing.swift`, `M/Live/LiveSampling.swift`, `MT/LiveServicesTests.swift` | S-3 | ~330, 11 |
| S-6a | – | v2 stored state, layer kinds and mask flags, `AdjustmentSettings: Hashable, Codable`, `.eyedropper` with its empty arms and fallback help, `toolHelp`, internal `insertLayer` and `reserveLayerIDs`, the geometry hook's declaration, `start()` resets, `clearStatus()` | `M/PhotoWorkspace.swift`, `M/PhotoLayer.swift`, `M/AdjustmentSettings.swift`, `M/PhotoMask.swift`, `M/PhotoStroke.swift`, `A/PhotoIntent.swift`, `A/PhotoPanel.swift`, `MT/PhotoV2StateTests.swift` | S-4 | ~300, 8 |
| S-6b | – | Step ids, `currentStepID`, `baseStepID`, `isDirty`, `savedStepID` set by `start()`, `.selection` and `.maskTiles` steps, masks in `PhotoStack`, the pixel-layer guard | `M/PhotoHistory.swift`, `MT/PhotoStepIDTests.swift` | S-6a | ~270, 2 |
| S-5 | – | Fixtures `empty`, `sample`, `layered`, `large` built in code (the blueprint's test-only `limit`, about 4 GB of Float32, is left out; no packet test uses it) | `M/PhotoFixtures.swift`, `MT/PhotoFixturesTests.swift` | S-6b | ~200, 2 |
| S-7a | – | Drags with modifiers and zoom (old two kept as wrappers); routing by component; marquee and crop drags moved; the real eyedropper stub; `PhotoToolsTests` reads `toolHelp` and runs every tool on `.fake` | `M/PhotoStroke.swift`, `M/PhotoSelectionMask.swift`, `M/PhotoCropSize.swift`, `M/PhotoTransform.swift`, `M/PhotoEyedropper.swift`, `MT/PhotoToolsTests.swift`, `MT/PhotoDragRoutingTests.swift` | S-5 | ~340, 7 |
| S-7c | – | `paintTarget()`; every dab, Delete and Fill weighted by `selectionCoverage`; Select All, Deselect and Apply Crop through `PhotoSelectionMask.swift`; Apply Crop calls the geometry hook | `M/PhotoStroke.swift`, `M/PhotoRetouch.swift`, `M/PhotoSelection.swift`, `M/PhotoSelectionMask.swift`, `MT/PhotoPaintTargetTests.swift` | S-7a | ~260, 5 |
| S-7b | – | `PhotoLayerComposite` hook (review note 2), render through it; Image Size, Rotate and Straighten call the geometry hook | `M/PhotoRender.swift`, `M/PhotoLayerComposite.swift`, `M/PhotoImageOps.swift`, `M/PhotoStraighten.swift`, `MT/PhotoLayerCompositeTests.swift` | S-7c | ~240, 5 |
| S-8a | – | `PhotoIntent` sub-enums, `.confirm` / `.dismiss`, `PhotoWindow` state made internal with the v2 presentation flags; all nine area files as stubs, each with its identity area modifier applied by `PhotoWindow` | `A/PhotoIntent.swift`, `A/PhotoWindow.swift`, `A/PhotoWindow+File.swift`, `A/PhotoWindow+Export.swift`, `A/PhotoWindow+Edit.swift`, `A/PhotoWindow+Crop.swift`, `A/PhotoWindow+History.swift`, `A/PhotoWindow+Select.swift`, `A/PhotoWindow+AdjustmentLayer.swift`, `A/PhotoWindow+Transform.swift`, `A/PhotoWindow+Sample.swift` | S-7b | ~380, 11 |
| S-8b | – | Today's open, save and export moved into their area files; `fileServices(_:)` (review note 4) | `A/PhotoWindow.swift`, `A/PhotoWindow+File.swift`, `A/PhotoWindow+Export.swift` | S-8a | ~300, 3 |
| S-9 | – | The menu bar split per menu (`PhotoMenu` already carries the workspace value; each menu file reads it) | `A/PhotoCommands.swift`, `A/PhotoCommands+File.swift`, `A/PhotoCommands+Edit.swift`, `A/PhotoCommands+Select.swift`, `A/PhotoCommands+Image.swift`, `A/PhotoCommands+Layer.swift`, `A/PhotoCommands+View.swift` | S-8b | ~380, 7 |
| S-10a | – | Top bar and status line out of `PhotoEditor`; the status line shows `statusMessage`; the rail reads `toolHelp` through an app-side `PaletteTool` wrapper (`PhotoRailTool`), and the "I" key never selects a disabled tool | `A/PhotoEditor.swift`, `A/PhotoTopBar.swift`, `A/PhotoStatusLine.swift`, `A/PhotoRailTool.swift`, `ST/PhotoEditorSnapshots.swift` | S-9 | ~340, 5 |
| S-10b | – | The overlay files (identified marks, review note 1), `hover` from `onPointer` (note 3), Return and Escape as `.confirm` and `.dismiss`, `StrokePacer` passes modifiers per event (and the window's call that builds its moves) | `A/PhotoEditor.swift`, `A/PhotoWindow.swift`, `A/PhotoCanvasOverlay.swift`, `A/CropOverlay.swift`, `A/SelectionOverlay.swift`, `A/TransformOverlay.swift`, `A/BrushCursorOverlay.swift`, `A/StrokePacer.swift`, `ST/PhotoStrokePacerTests.swift` | S-10a | ~360, 9 |
| S-11a | – | Panel split, part 1: the Adjust tab and the tool options out of `PhotoPanel`; the crop's Apply and Cancel buttons move into `CropOptions.swift` unchanged | `A/PhotoPanel.swift`, `A/PhotoAdjustTab.swift`, `A/PhotoToolOptions.swift`, `A/CropOptions.swift`, `A/SelectOptions.swift`, `A/TransformOptions.swift`, `A/SampleOptions.swift`, `ST/PhotoProInspectorSnapshots.swift` | S-10b | ~360, 8 |
| S-11b | – | Panel split, part 2: the Layers tab out; `PhotoHistoryTab` stub (not shown until PV-4) | `A/PhotoPanel.swift`, `A/PhotoLayersTab.swift`, `A/PhotoHistoryTab.swift`, `ST/PhotoLayerRowSnapshots.swift` | S-11a | ~260, 4 |
| S-12 | – | Launch arguments `-PhotoFixture`, `-PhotoWindowWidth`; `.fake` under a fixture; the "Preview data" pill | `M/PhotoFixtures.swift`, `MT/PhotoLaunchOptionsTests.swift`, `A/PhotoApp.swift`, `A/PhotoWindow.swift`, `A/PhotoStatusLine.swift`, `ST/PhotoSeamsSnapshots.swift` | S-11b | ~240, 6 |
| S-13 | – | Budgets PB-2 (clone, heal dab) and PB-9 (move drag) on `large`; PB-2's event-to-picture series | `MT/PhotoBudgetTests.swift`, `ST/PhotoBrushLatencyTests.swift` | S-12 | ~200, 2 |

Chains: S-1 → S-2 → S-3 → S-4 → S-6a → S-6b → S-5 → S-7a → S-7c → S-7b
(each needs the types before it; S-6a, S-7a and S-7c share
`PhotoStroke.swift`, S-6a shares `PhotoIntent.swift` and `PhotoPanel.swift`
with S-8a and S-11a later in the line); S-8a → S-8b → S-9 → S-10a → S-10b →
S-11a → S-11b → S-12 share `PhotoWindow.swift`, `PhotoEditor.swift`,
`PhotoPanel.swift` or `PhotoStatusLine.swift` in turn. S-8a starts after
S-7b because the window calls the new `drag` and intents. S-13 is last and
carries `feature-done`; a lead may run its Model half beside the app chain
once S-7b has merged (it owns no file of that chain).

**Lead step, no PR:** after S-4 merges, the lead files the four `needs-ui`
issues of blueprint 6.3 that don't exist yet (each labelled `needs-ui` and
`line:suiteui`, after checking `docs/blueprints/suiteui/features/` does not
already cover them): `SelectionPathOutline`, `SelectionHandles` with rotation
(on top of #273), `BrushCursorMark`, and a leading symbol and trailing
accessory on `LayerList` rows (lists-and-layers' LL-5). #339 and #340 exist.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| S-1 | `PhotoContractsTests`: `ArchiveError.message` gives the four texts of PJ-4 exactly; `CropAspect.presets` titles are Free, Original, 1:1, 3:2, 4:3, 16:9; `PhotoRefusal("x") == PhotoRefusal("x")`; `DragModifiers([.shift, .option])` contains both | a text, title or option differs from 5.1 |
| S-2 | `PhotoContractsLayerTests`: `SelectionCombine([.shift]) == .add`, `([.option]) == .subtract`, `([]) == .replace`, Shift wins over both; `SampleSize` titles; `LayerTransform.identity` is all 1 and 0; `ExportOptions()` is PNG, 0.9, 100 % | a default or mapping differs from 5.1 |
| S-3 | `PhotoFakesTests`: every fake's `unavailableHelp` is nil; `FakeArchive` round-trips a snapshot through `encode`, `container`, `package(fromContainer:)`, `decode`, and a second instance does not see the first's snapshot; `FakeSampling` gives (255, 204, 0); `FakeAdjustmentLayers` changes a gray pixel | a fake is unavailable, shares state across instances, or changes nothing a journey sees |
| S-4 | `LiveServicesTests`: no member of `.live` is a type whose name starts with `Fake`; each member's `unavailableHelp` is either nil or exactly "Not built yet (PV-n)." with that member's n (archive and recovery PV-1, clipboard and merging PV-2, crop PV-3, selection and masking PV-5, adjustment layers PV-6, transform PV-7, export sizing PV-8, sampling PV-9), and the test prints which are still `NotBuilt`; `PhotoServices.fake` read twice gives two different `FakeArchive` instances (`!==`) | `.live` holds a fake, a help text names the wrong feature, or `.fake` shares instances (it keeps passing as each feature replaces its stand-in) |
| S-6a | `PhotoV2StateTests`: a new workspace is `.live`; `toolHelp(.eyedropper) == services.sampling.unavailableHelp` on `.live` and nil on `.fake`; `newCanvas` then `open` resets every v2 field; two workspaces differing only in `services` are `==`; `reserveLayerIDs(after: 40)` makes the next `insertLayer` id 41; `AdjustmentSettings` round-trips through `JSONEncoder` and `JSONDecoder` equal; deleting a layer calls `layerGeometryChanged(_, .removed)` once (a counting test hook); every existing Photo model test passes unchanged | a v2 field survives `start()`, a loaded id can repeat, settings don't round-trip, or `services` takes part in `==` |
| S-6b | `PhotoStepIDTests`: edit, undo, edit gives a `currentStepID` never seen before; 51 edits then 50 undos leave `currentStepID != 0` (the trim moved `baseStepID`); `isDirty` is false right after `newCanvas`, after `open` and with no canvas, true after an edit, false after undoing it; a `.selection` step undoes the selection; `.layers` undo works with a layer that has no pixels entry (an adjustment layer built in the test) | an id repeats, undo-all after a trim reads as the base, a new image reads dirty, or layer-list undo is a no-op with an adjustment layer |
| S-5 | `PhotoFixturesTests`: `sample` is 800 × 600 with the sun's center pixel yellow and (10, 10) blue; `layered` has 3 layers top first Paint (Multiply, 60 %, masked), Curves 1 (adjustment), Background; `large` is 4000 × 3000 with 3 layers; every fixture runs on `.fake` | a fixture's size, layer order or kinds differ from 4.4 |
| S-7a | `PhotoToolsTests` (edited): on `.fake` each tool's drag on `sample` changes the workspace; on `.live` each tool either changes the workspace or has a non-empty `toolHelp`. `PhotoDragRoutingTests`: a Shift-drag reaches `selectionDrag` with `.shift`; the wrapper with `sampling: true` equals a drag with `[.option]`; the eyedropper drag adds no history step. Every existing Photo model test passes unchanged | a tool is dead on either services, a modifier is dropped, or an old test needed an edit |
| S-7c | `PhotoPaintTargetTests`: `refusalIsImmediate` (QB-F2), a brush drag on an adjustment layer leaves pixels unchanged and `statusMessage` reads "Select an image layer in the Layers tab to paint on." after that one call; with `selectionCoverage` forced to 0 outside a test rect (a test hook), brush, eraser, clone and heal dabs and Fill change no pixel outside it; with no selection every existing brush, eraser, clone, heal and fill test passes unchanged; Apply Crop calls `layerGeometryChanged` once per layer | a dab ignores the coverage, a refusal is late, or today's paint changes |
| S-7b | `PhotoLayerCompositeTests`: `PhotoRenderer.render` of `sample` and of a 3-layer stack equals the image from before the change bit for bit (stored as the reference from today's code in the test); `composite` of an adjustment layer returns `below` unchanged; Image Size, Rotate and Straighten call `layerGeometryChanged` once per layer | the render changes by one bit, or a geometry change skips a layer |
| S-8a | `scripts/ci` app-state rule passes; V1–V12 green on the next macOS run (the window still routes every v1 intent, each area modifier is the identity); `PhotoSelectAllMenuTests` unchanged and passing | an existing journey breaks, or a view assigns model state |
| S-8b | V5, V6 (open, paint, save, Save As) and the export step of V2 green on the next macOS run; `fileServices` returns its argument | open, save or export behaves differently |
| S-9 | V4 (every menu opens) green; each menu's item titles, shortcuts and enabled states equal today's (`PhotoSelectAllMenuTests` unchanged and passing) | a menu item moves, loses its shortcut or its disabled state |
| S-10a | `PhotoEditorSnapshots` PNGs unchanged apart from the Eyedropper on the rail (named in the PR); with `statusMessage` set, a new snapshot `photo-status-message-dark.png` shows it left of the pills; a unit test that `PhotoRailTool(.eyedropper)` on `.live` reports the sampling help and on `.fake` nil | the shell's look changes, the message doesn't show, or the rail enables the eyedropper on `.live` |
| S-10b | `PhotoStrokePacerTests` (edited): a frame's events keep their own modifiers; a crop pending shows an element `photo.canvas.crop` that is not a button (a snapshot-host accessibility check); `hover` is nil after the pointer leaves; V7 and V9 green (Return applies a pending crop, Escape cancels it) | a modifier is merged across events, a mark is a control or has no identifier, or Return and Escape stop working |
| S-11a | `PhotoProInspectorSnapshots` and `PhotoAdjustmentsSnapshots` PNGs unchanged; V3, V9 and V11 green | the Adjust tab's look changes |
| S-11b | `PhotoLayerRowSnapshots` PNGs unchanged; V10 green; the History tab is not shown | the Layers tab changes, or an empty History tab appears |
| S-12 | `PhotoLaunchOptionsTests`: `["-PhotoFixture", "layered"]` gives `.layered`; `"nope"` gives `unknownFixture == "nope"` and no fixture; `-PhotoWindowWidth 500` is ignored (under 880); `PhotoSeamsSnapshots` records `photo-preview-pill-dark.png` | an argument parses wrongly, or fixtures run on `.live` |
| S-13 | `PhotoBudgetTests`: PB-2 clone and heal 64 px dab ≤ 1 ms median in release (reported in debug), PB-9 move drag ≤ 0.1 ms release (reported in debug), 60 events each on `large`; the latency file adds the clone and heal series | a series has fewer than 60 samples, or a release gate is missed locally |

## Quality tests

| quality row | budget | test |
|---|---|---|
| PB-2 clone, heal drag event | ≤ 1 ms release, report in debug; ≤ 8 ms event to picture (release p50) | `PhotoBudgetTests.cloneHealDab`, `PhotoBrushLatencyTests` (new series) |
| PB-9 move drag | ≤ 0.1 ms release, report in debug | `PhotoBudgetTests.moveDrag` |
| PB-1 brush (regression) | ≤ 3 ms, ≤ 8 ms (existing) | `PhotoBrushLatencyTests.dragBudget` unchanged after S-7a |
| QB-F1 no dead controls | every tool on `.fake` changes the image; on `.live` each tool acts or has help, and the rail shows that help | `PhotoToolsTests` (S-7a), `PhotoRailTool` test (S-10a) |
| QB-F2 live feedback | a refusal reaches `statusMessage` in the same call that refuses | `PhotoPaintTargetTests.refusalIsImmediate` (S-7c) |
| 7.2 audit | no Photo count rises; new marks are identified non-controls | the app audit of the `feature-done` CI run against `UITests/audit-baseline.json` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR is green with V1–V12 unchanged (this feature adds no journey).
- **Audit zero new:** that run's `audit-photo-*.json` has no count over
  `UITests/audit-baseline.json` (`identifier: 23`, every other check 0).
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue; Photo's shots must match the previous sheet except the
  Eyedropper on the rail.
