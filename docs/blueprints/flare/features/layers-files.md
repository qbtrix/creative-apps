# Feature packet: layers-files

**Feature:** manage scenes and layers in the sidebar, start a document from
a preset, and handle files without ever losing work or failing silently:
the New Animation sheet, open progress and open errors, a failed save that
says so, and the recovery offer after a crash.
**Line:** `line:flare` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/layers-files`

**Covers:** F11a #350 (the scenes and layers list, now the sidebar), F11b
#351, F17b #392, F17c #393, and the files half of IN-4 #398 (J2, J16 and
J26 to J28 green live). #398 closes with whichever of this feature's LF-6
and `stage-edit`'s SE-5 (J14, guides) lands second.

**Depends on:** the `draw-key-save` feature issue (its window, sidebar
routing, file panels and `.built` services). Of the four running features it
needs live-scenes #800 (through `draw-key-save`'s DK-3) and mac-platform
#793 (closed: autosave, the recovery file, Open Recent). At task level only:
LF-1 waits on S15 #146 (the dimmed sidebar row for hidden and locked
layers) and LF-2 on #73 (context menus on sidebar rows). LF-3, LF-4 and LF-5
need no SuiteUI change (`PresetGrid` S5 #338 is closed) and start at once.

**The sidebar, not a Layers tab.** Section 3.1's Layers tab becomes the
`SuiteWindow` sidebar (captain, 2026-10-15): SCENES on top, then LAYERS of
the selected scene, as `FlareLayerItems.swift` builds them today. So #350
keeps `FlareLayerItems.swift` (it doesn't delete it) and doesn't add
`FlareLayersPanel.swift`; `FlareLayersSnapshots.swift` is extended, not
replaced. J16's step that sets the scene's background is the SCENE section's
(`inspector-timeline`), so J16 here leaves it out.

Blueprint sections: 2 (one undo step), 3.1 (Layers tab), 3.3 (New Animation
sheet, open progress, recovery offer, alerts and their texts), 3.4 (File
menu, layer and scene context menus), 4 (J2, J16, J26 to J28), 7.3 (F11a,
F11b, F17b, F17c), 7.6 (IN-4).

**Where it starts from.** The Model has scene and layer editing with their
refusals (`FlareScenes.swift`, `FlareLayers.swift`: "An animation needs at
least one scene.", the machine rule, locked layers), the file states
(`FlareFiles.swift`: `loadState`, `saveError`, `recent`,
`restoreRecovery`), and `FlareAutosave` with `RecoveryFile` and the
`RecoveryOffer` (mac-platform MP-5, MP-6). `draw-key-save` routes the
sidebar's gestures through `.layers` intents into `FlareWindow+Layers.swift`,
which already performs today's calls (select, eye and lock, layer move,
rename, add layer), handles every `.file` intent in `FlareWindow+File.swift` (⌘N makes a
1080p document directly until LF-3), shows open and save failures as
alerts, and leaves `FlareNewSheet.swift`, `FlareOpenStatus.swift` and
`FlareRecovery.swift` as no-op modifiers on the window (`FlareRecovery(model:,
restore:)`, `restore` wired to `model.restoreRecovery`). Removing a scene or a
layer has no sidebar affordance until the row context menus (#73), so those
steps are LF-2's.

## Journey steps

All launch with `-FlareSample <fixture>` or no fixture (live).

| # | step | task | journey test |
|---|---|---|---|
| 1 | add a scene; rename it "Outro"; drag Outro above Scene 1; select Scene 1; hide and lock Ball (dimmed rows); add a layer and rename it | LF-1 | J16 `FlareScenesJourneys.testScenesAddRenameReorderRemove` |
| 2 | the layer row's and the scene row's context menus: Rename, Hide, Lock, Duplicate, Delete; Rename, Delete; remove Outro; try to remove Scene 1; delete a layer | LF-2 | `FlareSceneMenuJourneys.testRowContextMenus` |
| 3 | ⌘N; pick Vertical 9:16; set 30 fps; Create | LF-3 | J2 `FlareNewSheetJourneys.testNewAnimationFromPreset` |
| 4 | open four bad files with `-FlareOpenFile`; open a large file: the progress row | LF-4 | J27 `FlareOpenErrorJourneys.testOpenBadFiles` |
| 5 | ⌘S to a read-only `-FlareSaveTo`; then move Ball, wait for the autosave mark, terminate, relaunch, Restore | LF-5 | J28 `FlareRecoveryJourneys.testSaveFailureAndRecovery` |

## Screens and states

| screen | state | snapshot PNG |
|---|---|---|
| Sidebar | `bounce` with Shadow hidden first (`toggleLayerFlag`): SCENES (Scene 1), LAYERS (Background locked and dimmed, Ball, Shadow hidden and dimmed) | `flare-sidebar-bounce-light.png`, `flare-sidebar-bounce-dark.png` (LF-1) |
| Sidebar | two scenes, renaming one inline; the last scene's Remove disabled with its reason | `flare-sidebar-scenes.png`, `flare-sidebar-last-scene.png` (LF-1) |
| Sidebar | `empty`: LAYERS empty with its add button | `flare-sidebar-empty.png` (LF-1) |
| New sheet | presets grid with Vertical 9:16 picked; Custom with width, height, fps, duration, background | `flare-new-sheet.png`, `flare-new-sheet-custom.png` (LF-3) |
| New sheet | a width of 0 or over the format's limit: Create disabled with the reason | `flare-new-sheet-invalid.png` (LF-3) |
| Open | the progress row in the stage area while a large file reads | `flare-open-progress.png` (LF-4) |
| Open | each open failure: system alert with section 3.3's text; the document that was open stays | journey shots only (system alert) |
| Save | a failed save: "Not saved" in the error color in the window's subtitle, and the alert | `flare-save-failed.png` (LF-5) |
| Recovery | the offer "Restore the unsaved animation from <time>?" with Restore and Discard | journey shot only (system alert) |

## Contract slice

Model (Linux, tested):

```swift
// Sources/FlareModel/FlareNewDocument.swift (LF-3)
public struct NewDocumentSpec: Sendable, Equatable {
    public var preset: CanvasPreset?          // nil = Custom
    public var width: Double, height: Double, fps: Int, durationFrames: Int, background: FlareColor
    public init(preset: CanvasPreset)
    public var problem: String?               // "Width must be 1 to 16384 px." ... nil when it can be made
}
extension FlareWorkspace {
    public mutating func newDocument(_ spec: NewDocumentSpec)   // through services.scenes.newDocument; no undo history
}

// Sources/FlareModel/FlareLoadProgress.swift (LF-4)
extension FlareWorkspace {
    public static let loadProgressDelay = 0.1  // seconds
    public func showsLoadProgress(startedAt: Double, now: Double) -> Bool   // loading and 100 ms passed
}

// Sources/FlareModel/FlareSaveStatus.swift (LF-5)
extension FlareWorkspace {
    public var saveStatus: String?            // "Not saved" after a failed save, nil once a save succeeds
}

// Sources/FlareModel/FlareSidebarHelp.swift (LF-1)
extension FlareWorkspace {
    public func removeSceneHelp(_ id: String) -> String?   // "An animation needs at least one scene.", the machine rule
    public func layerRowIsDimmed(_ id: String) -> Bool      // hidden or locked
}
```

App: `FlareNewSheet` (a modifier: `.sheet` on the window's
`presented == .newAnimation`), `FlareOpenStatus` (the progress row over the
stage area while `showsLoadProgress`), `FlareRecovery` (owns the
`FlareAutosave`: notes each edit, ticks once a second, writes on quit,
removes the file once `isDirty` is false, and shows the launch offer).

## Pseudocode

```
performLayers:                                             # LF-1
  .selectRow(id) -> selectItem ; .toggle(id, flag) -> toggleLayerFlag
  .move("scenes", rows, to) -> moveScene ; .move("layers", ...) -> moveLayer
  .rename(id, name) -> renameScene or renameLayer by id ; .addScene -> addScene ; .addLayer -> addLayer
  .remove(id) -> removeScene (guard removeSceneHelp == nil) or removeLayer
layersHelp(.remove(sceneID)) = removeSceneHelp(id)
SidebarItem(layer:) dims when layerRowIsDimmed (S15 #146)

FlareLayerItems context menus (#73):                        # LF-2
  layer row: Rename, Hide/Show, Lock/Unlock, Duplicate, Delete ; scene row: Rename, Delete (disabled with its reason)

FlareNewSheet:                                             # LF-3
  PresetGrid(CanvasPreset.all + Custom) ; width, height (NumericInput), fps (12, 24, 25, 30, 60), duration, background
  Create disabled with spec.problem ; Create -> perform(.file(.create(spec)))
performFile(.new) -> presented = .newAnimation ; .create(spec) -> model.newDocument(spec), presented = nil

FlareOpenStatus:                                           # LF-4
  TimelineView(.periodic(by: 0.05)) while loadState == .loading:
    if showsLoadProgress(startedAt, now): ProgressView("Opening <name>…") over the stage
  # the alerts stay draw-key-save's (FlareFilePanels)

FlareRecovery:                                             # LF-5
  .task { if let offer = await FlareAutosave.launch() { presented = .recovery(offer) } }
  alert(offer.message) { Restore -> restore(offer.document); autosave.discard()   # discard removes the file
                         Discard -> autosave.discard() }
  # FlareAutosave.restore(_:into:) takes the model inout, which a view can't pass; restore(_:) is the
  # window's closure to model.restoreRecovery, so FlareAutosave.swift stays as it is
  .onChange(of: model.document) { autosave.noteEdit(now) }
  every 1 s: autosave.tick(model: model, now)              # writes off the main actor when autosaveDue
  NSApplication.willTerminate: autosave.willQuit(model)
  .onChange(of: model.isDirty) { if !$0: autosave.didSave() }
  window subtitle: model.saveStatus in the error color
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: layers-files`, `Fast-Check:
pass`, `Head:`. LF-6 also carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LF-1 | #350 (part) | Scenes and layers in the sidebar: add, rename, reorder, select, eye and lock, dimmed rows, and the remove reasons in the Model; J16 | `Sources/FlareModel/FlareSidebarHelp.swift`, `Tests/FlareModelTests/FlareSidebarHelpTests.swift`, `Sources/FlareApp/FlareLayerItems.swift`, `Sources/FlareApp/FlareWindow+Layers.swift`, `Tests/AppSnapshotTests/FlareLayersSnapshots.swift`, `UITests/FlareJourneyTests+Scenes.swift` | #146 | ~340, 6 files |
| LF-2 | #350 (closes) | The layer and scene rows' context menus, with remove and delete | `Sources/FlareApp/FlareLayerItems.swift`, `UITests/FlareJourneyTests+SceneMenus.swift` | LF-1, #73 | ~150, 2 files |
| LF-3 | #351 (closes) | The New Animation sheet and `newDocument(_:)` from a spec; ⌘N shows it; J2 | `Sources/FlareModel/FlareNewDocument.swift`, `Tests/FlareModelTests/FlareNewDocumentTests.swift`, `Sources/FlareApp/FlareNewSheet.swift`, `Sources/FlareApp/FlareWindow+File.swift`, `Tests/AppSnapshotTests/FlareNewSheetSnapshots.swift`, `UITests/FlareJourneyTests+NewSheet.swift`, `UITests/FlareJourneyTests+Loop.swift` | – | ~380, 7 files |
| LF-4 | #392 (closes) | The open progress row after 100 ms; the open-error journey | `Sources/FlareModel/FlareLoadProgress.swift`, `Tests/FlareModelTests/FlareLoadProgressTests.swift`, `Sources/FlareApp/FlareOpenStatus.swift`, `Tests/AppSnapshotTests/FlareOpenStatusSnapshots.swift`, `UITests/FlareJourneyTests+OpenErrors.swift` | – | ~260, 5 files |
| LF-5 | #393 (closes) | Autosave wired to the window, the recovery offer, "Not saved" after a failed save; J28 | `Sources/FlareModel/FlareSaveStatus.swift`, `Tests/FlareModelTests/FlareSaveStatusTests.swift`, `Sources/FlareApp/FlareRecovery.swift`, `Tests/AppSnapshotTests/FlareRecoverySnapshots.swift`, `UITests/FlareJourneyTests+Recovery.swift` | – | ~320, 5 files |
| LF-6 | see #398 | J26 also runs from a preset made in the sheet; this packet's status line | `UITests/FlareJourneyTests+Loop.swift`, `docs/blueprints/flare/features/layers-files.md` | LF-1, LF-2, LF-3, LF-4, LF-5 | ~80, 2 files |

`FlareLayerItems.swift`, `FlareWindow+Layers.swift`, `FlareWindow+File.swift`,
`FlareNewSheet.swift`, `FlareOpenStatus.swift`, `FlareRecovery.swift`,
`FlareLayersSnapshots.swift` and `UITests/FlareJourneyTests+Loop.swift` are
`draw-key-save`'s or older; each is edited by one task here (LF-1 and LF-2
stack on `FlareLayerItems.swift`, LF-3 and LF-6 on `+Loop.swift`) and by no
other wave-4 feature. LF-3 adds the sheet's Create step to J26 in
`+Loop.swift` in the same PR that makes ⌘N show the sheet, so J26 never goes red.

**Shared docs.** A wave-4 feature beside `stage-edit` and
`inspector-timeline`: its final task edits no shared doc. New files sit
under the `flare-app` and `flare-model` paths, which the C4 descriptions
already cover. The status goes in this packet and `layers-files.wave.json`.

## Build waves

- Wave 1: LF-1, LF-3, LF-4, LF-5. Independent in this wave: all four (LF-1
  starts when #146 closes).
- Wave 2: LF-2. Independent in this wave: LF-2 (alone; it starts when #73
  closes).
- Wave 3: LF-6 (final).

Longest chain: LF-1 → LF-2 → LF-6 (3).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| LF-1 | `FlareSidebarHelpTests`: the last scene's `removeSceneHelp` is "An animation needs at least one scene."; a scene a machine uses gives the machine rule; Background (locked) and a hidden layer are dimmed, Ball isn't. `FlareLayersSnapshots` (four PNGs). J16 on `-FlareSample bounce`: "Scene 2" then "Outro"; Outro first; selecting Scene 1's row selects it (its row reads selected); Ball hidden and locked reads dimmed; a layer added and renamed, each one ⌘Z | a scene edit fails live, a refusal reason is wrong, or a row isn't dimmed |
| LF-2 | `testRowContextMenus`: a layer row's menu lists Rename, Hide, Lock, Duplicate, Delete and each acts (one ⌘Z each); a scene row's lists Rename and Delete; Delete removes Outro; on the last scene Delete is disabled with "An animation needs at least one scene." | an item is missing, dead, removes the last scene, or acts without an undo step |
| LF-3 | `FlareNewDocumentTests` on `.built`: Vertical 9:16 gives 1080 × 1920 at 30 fps and 150 frames; Custom width 0 gives a problem and `newDocument` refuses; the new document has no undo history and is not dirty. `FlareNewSheetSnapshots` (three PNGs). J2: the artboard (`suite.canvas`) is 9:16 (height ÷ width within 0.01 of 1920 ÷ 1080) and the timecode's total reads 05:00 (the info card and the pills are `inspector-timeline`'s); J26 in `+Loop.swift` passes with the sheet's Create step | a preset's values are wrong, a bad size makes a document, ⌘N skips the sheet, or J26 breaks |
| LF-4 | `FlareLoadProgressTests`: loading for 0.05 s shows nothing, 0.1 s shows the row, `.idle` never does. `FlareOpenStatusSnapshots` (one PNG). J27 on the test's four files (`not json`; `{"format":"flare","version":2}`; `{"a":1}`; 65 MB of spaces): each alert's text matches section 3.3 and the empty state stays | the row shows too early or never, or an alert's text differs |
| LF-5 | `FlareSaveStatusTests`: `saveFailed` gives "Not saved", `didSave` clears it. `FlareRecoverySnapshots` (one PNG). J28 on `-FlareSample bounce`: a read-only folder gives "Not saved" in the error color and the alert; move Ball, wait for the probe's autosave mark, terminate, relaunch: the offer, Restore, Ball at the moved spot and the document dirty | autosave never writes, the offer is missing, Restore loses the move, or a failed save is silent |
| LF-6 | J26 extended in `+Loop.swift`: after `testDrawKeyAndSave`'s steps, ⌘N through the sheet on Square makes a 1080 × 1080 document, and the saved file still reopens with its keys | the sheet breaks the save loop |

## Quality tests

| quality row | budget | test |
|---|---|---|
| No data loss | a crash after an edit offers the work back; a failed save keeps the dot and says so | J28 (LF-5), `MacPlatformJourneyTests` stay green |
| QB-L9 open progress | the progress row within 100 ms of the command on a large file | `FlareLoadProgressTests` (LF-4); P7 (QH-6 #395) reports it |
| QB-L12 no stall | the file is read and decoded off the main thread | draw-key-save's DK-12 path; P7 reports it |
| QB-F1 no dead controls | every sidebar button, row menu item and sheet control acts or says why | J16, `testRowContextMenus`, J2; J29 stays green |
| QB-F3 one gesture, one step | each scene and layer edit is one ⌘Z | J16 (LF-1), LF-2 |
| Keyboard parity | ⌘N, Return to Create, Escape to cancel the sheet, Return to rename a row | J2, J16 |
| App audit | no Flare count over `UITests/audit-baseline.json` | the macOS run's `audit-flare-*.json` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by LF-6
  (`feature-done`) is green: J2, J16, the row menus, J26 to J28, with
  `testDrawKeyAndSave` still green.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey and the audit counts.
