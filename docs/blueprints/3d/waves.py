# waves.py: parts 4 and 9 of docs/blueprints/3d.md as data, and their checks.
#   python3 docs/blueprints/3d/waves.py check   # fails (prints each problem) when two features in one
#                                               # wave own a file, a feature owns a Sources/ file no
#                                               # component owns exactly once, or c4-planned.json is stale
#   python3 docs/blueprints/3d/waves.py c4      # rewrites docs/blueprints/3d/c4-planned.json
#   python3 docs/blueprints/3d/waves.py md      # prints part 9.3 (features and owned files)
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
M, A, T, SN, U = "Sources/PrismModel/", "Sources/PrismApp/", "Tests/PrismModelTests/", "Tests/AppSnapshotTests/", "UITests/"
AV = M + "Availability/PrismAvailability+"

contracts = {  # contract -> feature that replaces its W0 live stub
    "SceneImporting": "import", "ImageDecoding": "import", "PrimitiveMaking": "objects", "SceneArranging": "objects",
    "ViewNavigating": "viewport", "ViewportPicking": "viewport", "FrameDrawing": "viewport",
    "SceneHistory": "history-files", "SceneFiles": "history-files", "GizmoDragging": "transform",
    "MaterialEditing": "look", "LightEditing": "look", "CameraDirecting": "look", "MeshEditing": "modeling",
    "PropertyKeying": "keys", "KeyEasing": "keys", "PlaybackClock": "keys", "FrameRendering": "render",
    "SequenceRendering": "render", "ShapeExtruding": "shapes", "VectorArtReading": "shapes", "GlyphOutlining": "shapes",
    "ModifierEvaluating": "modifiers", "SceneExporting": "export", "RenderHandingOff": "handoff",
}
areas = {  # availability / window area -> feature
    "Scene": "history-files", "Files": "history-files", "History": "history-files", "Viewport": "viewport",
    "Selection": "viewport", "Objects": "objects", "Import": "import", "Transform": "transform", "Look": "look",
    "Modeling": "modeling", "Keys": "keys", "Render": "render", "Shapes": "shapes", "Modifiers": "modifiers",
    "Export": "export", "HandOff": "handoff",
}
inspector = {  # inspector section file -> feature
    "Transform": "transform", "Material": "look", "Light": "look", "Camera": "look", "Mesh": "modeling",
    "Keys": "keys", "Easing": "keys", "Text": "shapes", "Modifiers": "modifiers", "Scene": "history-files",
}
platform = {  # PrismApp macOS-only conformances and writers -> feature
    "PrismDocumentType.swift": "history-files", "PrismModelIOImporter.swift": "import", "PrismImageDecoder.swift": "import",
    "PrismRealityRenderer.swift": "render", "PrismFrameImage.swift": "render", "PrismPNGWriter.swift": "render",
    "PrismMovieWriter.swift": "render", "PrismGlyphOutliner.swift": "shapes", "PrismPasteboard.swift": "shapes",
}

def stubs_of(feature):
    return ([M + f"Live/Live{c}.swift" for c, f in contracts.items() if f == feature]
            + [AV + a + ".swift" for a, f in areas.items() if f == feature]
            + [A + f"PrismWindow+{a}.swift" for a, f in areas.items() if f == feature]
            + [A + f"PrismInspector+{s}.swift" for s, f in inspector.items() if f == feature])

def contract_tests(feature):
    return [T + f"{c}ContractTests.swift" for c, f in contracts.items() if f == feature]

features = [
  dict(wave=0, id="foundation", name="Foundation: targets, contracts, fakes, workspace and the window's seams",
       tier="p1 by dependency", waits_core="none", waits_other="none (alone in its wave)",
       proves="P-J0, P-J1, P-J21, PL1, PL2, PL6; PB-10",
       owns=["Package.swift", "project.yml", "UITests/audit-baseline.json", "docs/c4/model.json", "docs/design.md",
             M+"Contracts/PrismValues.swift", M+"Contracts/PrismContracts.swift", M+"Live/PrismRules.swift",
             M+"PrismServices.swift", M+"PrismWorkspace.swift", M+"PrismCommand.swift", M+"PrismFixtures.swift",
             M+"PrismStatusText.swift"]
         + [M+f"Fakes/Fake{c}.swift" for c in contracts] + [M+"Fakes/CountingSink.swift"]
         + [M+f"Live/Live{c}.swift" for c in contracts]
         + [AV + a + ".swift" for a in areas]
         + [A+"PrismApp.swift", A+"PrismLaunch.swift", A+"PrismWindow.swift", A+"PrismControls.swift",
            A+"PrismCommands.swift", A+"PrismInspector.swift", A+"PrismSidebar.swift", A+"PrismPalette.swift",
            A+"PrismViewportView.swift"]
         + [A+f"PrismWindow+{a}.swift" for a in areas] + [A+f"PrismInspector+{s}.swift" for s in inspector]
         + [T+f"{c}ContractTests.swift" for c in contracts]
         + [T+"PrismCommandTests.swift", T+"PrismToolsTests.swift", T+"PrismFixturesTests.swift", T+"PrismEditTests.swift", T+"PrismBudget.swift",
            T+"PrismFoundationBudgetTests.swift", SN+"PrismWindowSnapshots.swift", U+"PrismJourneyTests.swift"]),
  dict(wave=1, id="viewport", name="See and navigate the scene; select objects",
       tier="p1", waits_core="none (RealityKit draws; the draw list is Model code)", waits_other="SuiteUI QH-4 #333 (journey files)",
       proves="P-J2, P-J3; PB-1, PB-2, PB-3, PB-4; PF-1, PF-2",
       owns=stubs_of("viewport") + contract_tests("viewport")
         + [M+"PrismViewport.swift", M+"PrismOverlay.swift", M+"PrismSelection.swift",
            A+"PrismRealityBridge.swift", A+"PrismOverlayCanvas.swift", A+"PrismViewportGestures.swift", A+"PrismAxisWidget.swift",
            T+"PrismViewportTests.swift", T+"PrismSelectionTests.swift", T+"PrismViewportBudgetTests.swift",
            SN+"PrismViewportSnapshots.swift", SN+"PrismViewportFidelityTests.swift",
            U+"PrismJourneyTests+Viewport.swift", U+"PrismJourneyTests+Selection.swift"]),
  dict(wave=1, id="objects", name="Add, organize and delete objects",
       tier="p1", waits_core="none", waits_other="#333",
       proves="P-J4; PB-11",
       owns=stubs_of("objects") + contract_tests("objects")
         + [M+"PrismSceneEdits.swift", M+"PrismOutliner.swift", A+"PrismOutlinerView.swift",
            T+"PrismSceneEditsTests.swift", T+"PrismOutlinerTests.swift", T+"PrismObjectsBudgetTests.swift",
            SN+"PrismOutlinerSnapshots.swift", U+"PrismJourneyTests+Objects.swift"]),
  dict(wave=1, id="history-files", name="New scene, undo, redo, save and open",
       tier="p1", waits_core="none", waits_other="#333; the suite's recents and router (suite.md, recents-open-in) for P-J7's Open Recent step (the step skips until then)",
       proves="P-J5, P-J6, P-J7; PB-8, PB-9; PF-6",
       owns=stubs_of("history-files") + contract_tests("history-files")
         + [M+"PrismHistoryOps.swift", M+"PrismFiles.swift", M+"PrismSceneSettings.swift"]
         + [A+k for k, f in platform.items() if f == "history-files"]
         + [A+"NewSceneSheet.swift", T+"PrismUndoTests.swift", T+"PrismFileTests.swift", T+"PrismFilesBudgetTests.swift",
            SN+"PrismFileSnapshots.swift", U+"PrismJourneyTests+History.swift", U+"PrismJourneyTests+Files.swift",
            U+"PrismJourneyTests+FileErrors.swift"]),
  dict(wave=1, id="import", name="Import models and images",
       tier="p1", waits_core="C3D-2 model readers (glTF/GLB, OBJ+MTL, STL, PLY). Until it lands, LiveSceneImporting reads only the USD family through the macOS importer and the core formats stay disabled with their reason; the fake carries P-J8",
       waits_other="#333",
       proves="P-J8; PB-12; PF-7",
       owns=stubs_of("import") + contract_tests("import")
         + [M+"PrismImport.swift"] + [A+k for k, f in platform.items() if f == "import"]
         + [A+"PrismImportProgress.swift", T+"PrismImportTests.swift", T+"PrismImportBudgetTests.swift",
            SN+"PrismImportSnapshots.swift", U+"PrismJourneyTests+Import.swift"]),
  dict(wave=2, id="transform", name="Move, rotate and scale with the gizmo and inspector",
       tier="p1", waits_core="none", waits_other="#333; after viewport and objects",
       proves="P-J9; PB-5; PF-3",
       owns=stubs_of("transform") + contract_tests("transform")
         + [M+"PrismTransformDrag.swift", M+"PrismTransformRows.swift", A+"PrismGizmoView.swift",
            T+"PrismTransformTests.swift", T+"PrismTransformBudgetTests.swift", SN+"PrismTransformSnapshots.swift",
            U+"PrismJourneyTests+Transform.swift"]),
  dict(wave=2, id="modeling", name="Edit mode and the modeling tools",
       tier="p1", waits_core="C3D-1 mesh kernel (half-edge mesh, ear clipping, extrude, inset, bevel, loop cut, merge, fill, BVH pick); bevel stays disabled with its reason until C3D-1's bevel lands",
       waits_other="#333; after viewport and history-files",
       proves="P-J10, P-J11; PB-6; PF-4",
       owns=stubs_of("modeling") + contract_tests("modeling")
         + [M+"PrismEditMode.swift", M+"PrismModelingTools.swift", A+"PrismModelingPalette.swift",
            T+"PrismEditModeTests.swift", T+"PrismModelingToolsTests.swift", T+"PrismModelingBudgetTests.swift",
            SN+"PrismModelingSnapshots.swift", U+"PrismJourneyTests+Modeling.swift"]),
  dict(wave=2, id="look", name="Materials, lights, environment and cameras",
       tier="p1", waits_core="none (RealityKit's PhysicallyBasedMaterial and lights draw them)",
       waits_other="#333; after viewport and objects",
       proves="P-J12, P-J13, P-J14; PB-13",
       owns=stubs_of("look") + contract_tests("look")
         + [M+"PrismMaterials.swift", M+"PrismLights.swift", M+"PrismCameras.swift", A+"PrismMaterialList.swift",
            T+"PrismMaterialsTests.swift", T+"PrismLightsTests.swift", T+"PrismCamerasTests.swift", T+"PrismLookBudgetTests.swift",
            SN+"PrismLookSnapshots.swift", U+"PrismJourneyTests+Look.swift"]),
  dict(wave=2, id="keys", name="Key, ease and play",
       tier="p1", waits_core="none (FlareCore Keyframe, Easing and Timeline.value)",
       waits_other="#333; SuiteUI TransportCapsule #340 (placeholder buttons meanwhile); after objects and history-files",
       proves="P-J15, P-J16, P-J17; PB-14, PB-15; PF-5",
       owns=stubs_of("keys") + contract_tests("keys")
         + [M+"PrismKeying.swift", M+"PrismKeySelection.swift", M+"PrismPlayback.swift", M+"PrismTimeline.swift",
            A+"PrismTimelineView.swift", A+"PrismPlaybackDriver.swift",
            T+"PrismKeyingTests.swift", T+"PrismEasingTests.swift", T+"PrismPlaybackTests.swift", T+"PrismKeysBudgetTests.swift",
            SN+"PrismTimelineSnapshots.swift", U+"PrismJourneyTests+Keys.swift", U+"PrismJourneyTests+Playback.swift"]),
  dict(wave=3, id="render", name="Render stills, sequences and movies",
       tier="p1", waits_core="C3D-4 reference renderer (for PF-8 and the Linux live FrameRendering)",
       waits_other="#333; after look and keys",
       proves="P-J18; PB-16, PB-17; PF-8, PF-9, PF-10",
       owns=stubs_of("render") + contract_tests("render")
         + [M+"PrismRenderJob.swift", M+"PrismRenderStill.swift"] + [A+k for k, f in platform.items() if f == "render"]
         + [A+"PrismRenderSheet.swift", A+"PrismRenderPreview.swift",
            T+"PrismRenderPlanTests.swift", T+"PrismRenderBudgetTests.swift", SN+"PrismRenderSnapshots.swift",
            SN+"PrismRenderFidelityTests.swift", SN+"PrismWriterTests.swift", U+"PrismJourneyTests+Render.swift"]),
  dict(wave=3, id="shapes", name="Extrude text and vector art",
       tier="p2", waits_core="C3D-3 outline extrusion with holes and bevel; C3D-5 SVG reading (paths, basic shapes, fills)",
       waits_other="#333; Design's pasteboard SVG (suite clipboard-drag) for P-J20's paste step; after modeling and look",
       proves="P-J19, P-J20; PB-18",
       owns=stubs_of("shapes") + contract_tests("shapes")
         + [M+"PrismShapes.swift"] + [A+k for k, f in platform.items() if f == "shapes"]
         + [T+"PrismShapesTests.swift", T+"PrismShapesBudgetTests.swift", SN+"PrismShapesSnapshots.swift",
            U+"PrismJourneyTests+Shapes.swift"]),
  dict(wave=3, id="modifiers", name="Subdivision Surface and Mirror",
       tier="p2", waits_core="C3D-1 Catmull-Clark subdivision and mirror",
       waits_other="#333; after modeling",
       proves="P-J22; PB-7",
       owns=stubs_of("modifiers") + contract_tests("modifiers")
         + [M+"PrismModifiers.swift", T+"PrismModifiersTests.swift", T+"PrismModifiersBudgetTests.swift",
            SN+"PrismModifiersSnapshots.swift", U+"PrismJourneyTests+Modifiers.swift"]),
  dict(wave=3, id="export", name="Export GLB, USDZ, OBJ and STL",
       tier="p2", waits_core="C3D-2 writers (GLB, OBJ, STL, USDZ as USDA in a zip)",
       waits_other="#333; after import",
       proves="P-J23; PF-11",
       owns=stubs_of("export") + contract_tests("export")
         + [M+"PrismExport.swift", T+"PrismExportTests.swift", U+"PrismJourneyTests+Export.swift"]),
  dict(wave=4, id="handoff", name="Send renders to Halo, Flare and Design",
       tier="p2", waits_core="none",
       waits_other="the suite hand-off transport (suite.md, switching) and image or footage placement in Halo, Flare and Design (part 9.5)",
       proves="P-J24",
       owns=stubs_of("handoff") + contract_tests("handoff")
         + [M+"PrismHandOff.swift", T+"PrismHandOffTests.swift", U+"PrismJourneyTests+HandOff.swift"]),
  dict(wave=4, id="core-loop", name="The core loop, live, measured",
       tier="p1", waits_core="none", waits_other="every W1 to W3 feature; SuiteUI frame probe #330 for PB-U1 to PB-U4",
       proves="P-J25 live; P-P1 to P-P5; PL3 to PL5",
       owns=[U+"PrismJourneyTests+CoreLoop.swift", U+"PrismJourneyTests+Perf.swift", SN+"PrismLatencyTests.swift",
             SN+"PrismLayoutTests.swift"]),
]

# Components (part 4 L3). Paths ending in "/" own a folder; a file belongs to the longest matching path.
def comp(cid, name, container, status, desc, paths, rels):
    return dict(id=cid, name=name, container=container, status=status, desc=desc, paths=paths, rels=rels)

components = [
  comp("prism-workspace", "Workspace", "prism-model", "planned",
       "PrismWorkspace: the window's one value-type state (document, services, history, playback, viewpoint, edit mode, drags, file, render job, refusal), each stored property written only by its own extension file; edit(_:_:) is the one place an edit records undo.",
       [M+"PrismWorkspace.swift", M+"PrismStatusText.swift", M+"PrismSceneSettings.swift"], [("prism-services", "reads its services"), ("prism-contracts", "stores PrismDocumentState and PrismHistory")]),
  comp("prism-contracts", "Use-case contracts", "prism-model", "planned",
       "One protocol per use case (25, part 6) and the values they speak; FlareCore's Keyframe and Easing under Prism names from W0.",
       [M+"Contracts/"], [("flarecore", "names Keyframe and Easing")]),
  comp("prism-services", "Services and live conformances", "prism-model", "planned",
       "PrismServices with .fake, .unbuilt and .live; Live/ holds one file per contract (a W0 NotBuilt stub replaced whole by its feature) and PrismRules, the rules fakes and live types share.",
       [M+"PrismServices.swift", M+"Live/"], [("prism-contracts", "conforms to"), ("coremesh", "edits meshes"), ("coremodelio", "reads and writes model files"), ("corerender3d", "renders reference frames"), ("flarecore", "samples keys and eases")]),
  comp("prism-fakes", "Fakes and fixtures", "prism-model", "planned",
       "One fake per contract and PrismFixtures (empty, starter, cube-keyed, modeling, product, crowd, huge), built in code.",
       [M+"Fakes/", M+"PrismFixtures.swift"], [("prism-contracts", "conforms to")]),
  comp("prism-commands", "Commands and availability", "prism-model", "planned",
       "PrismCommand (every menu, palette and key command of v1) and unavailableHelp(for:), dispatched to one Availability/ file per area that its feature replaces.",
       [M+"PrismCommand.swift", M+"Availability/"], [("prism-services", "reads each service's unavailableHelp")]),
  comp("prism-viewport-model", "Viewport state", "prism-model", "planned",
       "The viewpoint, orbit, pan, dolly, frame and view presets; the draw list at the playhead; the 2D overlay geometry (grid labels, selection outline, edit-mode dots and lines, gizmo handles) projected for the SwiftUI overlay; click and box selection.",
       [M+"PrismViewport.swift", M+"PrismOverlay.swift", M+"PrismSelection.swift"], [("prism-contracts", "calls ViewNavigating, ViewportPicking, FrameDrawing")]),
  comp("prism-scene-edits", "Objects and outliner", "prism-model", "planned",
       "Add primitives, groups, lights and cameras; rename, hide, duplicate, delete, group, ungroup, reparent (keeping the world place); the outliner rows.",
       [M+"PrismSceneEdits.swift", M+"PrismOutliner.swift"], [("prism-contracts", "calls PrimitiveMaking, SceneArranging")]),
  comp("prism-transform", "Transform", "prism-model", "planned",
       "Gizmo drags (begin, preview, commit as one step, cancel) and the TRANSFORM rows with typed values and snapping.",
       [M+"PrismTransformDrag.swift", M+"PrismTransformRows.swift"], [("prism-contracts", "calls GizmoDragging, PropertyKeying")]),
  comp("prism-import", "Import", "prism-model", "planned",
       "The import job: sidecars, progress, cancel, warnings note, placing the result as one group in one step.",
       [M+"PrismImport.swift"], [("prism-contracts", "calls SceneImporting, ImageDecoding")]),
  comp("prism-modeling", "Modeling", "prism-model", "planned",
       "Edit mode: element selection by mode, loop select, tool drags for extrude, inset, bevel and loop cut with typed amounts, Mesh menu operations, each one step.",
       [M+"PrismEditMode.swift", M+"PrismModelingTools.swift"], [("prism-contracts", "calls MeshEditing")]),
  comp("prism-modifiers", "Modifiers", "prism-model", "planned",
       "The modifier stack per mesh (add, remove, hide, levels) and the evaluated mesh the viewport, render and export read.",
       [M+"PrismModifiers.swift"], [("prism-contracts", "calls ModifierEvaluating")]),
  comp("prism-look", "Materials, lights, cameras", "prism-model", "planned",
       "Material list, presets, assignment and rows; lights, environment and lighting presets; cameras, the active camera, camera from view.",
       [M+"PrismMaterials.swift", M+"PrismLights.swift", M+"PrismCameras.swift"], [("prism-contracts", "calls MaterialEditing, LightEditing, CameraDirecting")]),
  comp("prism-keying", "Keys, easing, playback", "prism-model", "planned",
       "Stopwatch and key-here per keyable row, K to key the transform, key segments and easing, the timeline rows, play, pause, loop and step through PlaybackClock.",
       [M+"PrismKeying.swift", M+"PrismKeySelection.swift", M+"PrismPlayback.swift", M+"PrismTimeline.swift"], [("prism-contracts", "calls PropertyKeying, KeyEasing, PlaybackClock")]),
  comp("prism-history-files", "History and files", "prism-model", "planned",
       "Undo and redo of whole-document steps with names; .prism packages: fileData, beginOpen and finishOpen around an off-main decode, unsaved state, errors.",
       [M+"PrismHistoryOps.swift", M+"PrismFiles.swift"], [("prism-contracts", "calls SceneHistory, SceneFiles")]),
  comp("prism-render", "Render", "prism-model", "planned",
       "Render Still into the preview and the Render… job: plan, progress, cancel, outcome, driving SequenceRendering into a sink the app supplies.",
       [M+"PrismRenderJob.swift", M+"PrismRenderStill.swift"], [("prism-contracts", "calls FrameDrawing, FrameRendering, SequenceRendering")]),
  comp("prism-shapes", "Text and vector art", "prism-model", "planned",
       "Text objects and vector-art objects rebuilt from their shape source on each edit; Convert to Mesh.",
       [M+"PrismShapes.swift"], [("prism-contracts", "calls GlyphOutlining, VectorArtReading, ShapeExtruding")]),
  comp("prism-export", "Export", "prism-model", "planned", "Export Model…: format, the baked frame, the written data.",
       [M+"PrismExport.swift"], [("prism-contracts", "calls SceneExporting")]),
  comp("prism-handoff", "Hand-offs", "prism-model", "planned",
       "Send To ▸ after a render: the target's refusal, the PrismHandOffRequest the suite carries.",
       [M+"PrismHandOff.swift"], [("prism-contracts", "calls RenderHandingOff"), ("suite-model", "hands the request to HandOffSending")]),
  # PrismApp
  comp("prism-scene", "App scene and launch", "prism-app", "planned",
       "The App scene and the launch arguments for journeys: -PrismFixture, -PrismSample, -PrismOpenFile, -PrismSaveTo, -PrismImport, -PrismRenderTo, -PrismWindowSize, -PrismPerfProbe, -PrismControlsProbe; assembles .live with the platform pieces.",
       [A+"PrismApp.swift", A+"PrismLaunch.swift"], [("prism-window", "shows"), ("prism-platform", "installs the macOS conformances")]),
  comp("prism-window", "Window and command router", "prism-app", "planned",
       "PrismWindow: SuiteWindow with the switcher row, the one @State workspace, presentation flags, perform(_:) routing each command to its PrismWindow+<Area> file; PrismControls for the every-control journey; the menu bar from PrismCommand.",
       [A+"PrismWindow.swift", A+"PrismControls.swift", A+"PrismCommands.swift", A+"PrismWindow+"], [("prism-workspace", "reads state, calls methods"), ("prism-commands", "asks availability"), ("suiteui", "SuiteWindow shell")]),
  comp("prism-viewport", "Viewport", "prism-app", "planned",
       "PrismViewportView: RealityView fed from the draw list by PrismRealityBridge (entities, PhysicallyBasedMaterial, lights, camera; LowLevelMesh for edited meshes), the SwiftUI overlay canvas, gestures, the axis widget, the gizmo, the floating palette and the status pills.",
       [A+"PrismViewportView.swift", A+"PrismRealityBridge.swift", A+"PrismOverlayCanvas.swift", A+"PrismViewportGestures.swift",
        A+"PrismAxisWidget.swift", A+"PrismGizmoView.swift", A+"PrismPalette.swift", A+"PrismModelingPalette.swift"],
       [("prism-viewport-model", "reads the draw list and overlay, calls navigation"), ("suiteui", "ToolbarGroup floating palette, ViewerStatusBar")]),
  comp("prism-panels", "Sidebar, inspector and timeline", "prism-app", "planned",
       "Sidebar (SCENE outliner, MATERIALS), the inspector sections (one file each), the timeline with transport and the display-link playback driver.",
       [A+"PrismSidebar.swift", A+"PrismOutlinerView.swift", A+"PrismMaterialList.swift", A+"PrismInspector.swift", A+"PrismInspector+",
        A+"PrismTimelineView.swift", A+"PrismPlaybackDriver.swift"],
       [("prism-workspace", "reads rows, calls methods"), ("suiteui", "SidebarSection, InspectorSection, StudioScrubRow, KeyframeButton, ChoiceChips, CurveEditor, TimelineStrip")]),
  comp("prism-sheets", "Sheets and previews", "prism-app", "planned",
       "New Scene sheet, import progress row, the Render… sheet and the render preview.",
       [A+"NewSceneSheet.swift", A+"PrismImportProgress.swift", A+"PrismRenderSheet.swift", A+"PrismRenderPreview.swift"],
       [("prism-render", "starts and cancels the job")]),
  comp("prism-platform", "Platform pieces", "prism-app", "planned",
       "macOS-only conformances with no SwiftUI: the .prism package UTType, the Model I/O USD importer, the ImageIO decoder, the RealityRenderer offscreen FrameRendering, the frame image, the PNG and movie writers (AVAssetWriter inputPixelBufferReceiver), the Core Text glyph outliner, the pasteboard bridge for SVG and images.",
       [A+k for k in platform], [("prism-contracts", "conforms to SceneImporting, ImageDecoding, FrameRendering, RenderSink, GlyphOutlining"), ("suite-shell", "reads pasteboard items through PasteboardBridge")]),
  # tests
  comp("prism-model-tests", "PrismModelTests", "prism-tests", "planned",
       "Model behavior, a conformance suite per contract against fake and live, fixtures, budgets and Linux fidelity checks.", [T], [("prism-model", "tests")]),
  comp("prism-snapshots", "Prism snapshots and goldens", "prism-tests", "planned",
       "Prism*Snapshots PNGs in Light and Dark, fidelity tests (viewport equals render), writer tests, latency and layout tests.", [SN+"Prism"], [("prism-app", "renders views of")]),
  comp("prism-journeys", "Prism journeys", "prism-tests", "planned",
       "UITests/PrismJourneyTests.swift and one +<Area> file per feature: P-J0 to P-J25 and the perf journeys P-P1 to P-P5.", [U+"PrismJourneyTests"], [("prism-app", "drives the release bundle of")]),
]

containers = {
  "prism-model": ("PrismModel", "existing" if False else "planned", "Linux-safe state and logic for Prism (3D): workspace, contracts, fakes, live conformances over creative-core.", "Swift 6, Foundation, Linux + macOS"),
  "prism-app": ("PrismApp", "planned", "The Prism app: SwiftUI window from SuiteUI, RealityKit viewport, menus and macOS-only platform pieces. Reads PrismModel and calls its methods.", "Swift 6, SwiftUI, RealityKit, macOS 26"),
  "prism-tests": ("Prism tests", "planned", "PrismModelTests (Linux), snapshots and goldens, journeys (XCUITest).", "Swift Testing, XCTest"),
}
externals = [
  ("creative-apps", "suiteui", "SuiteUI", "existing", "The shared design system (Sources/SuiteUI)."),
  ("creative-apps", "suite-model", "SuiteModel", "planned", "suite.md: shared values and contracts (hand-offs, recents, pasteboard, routing)."),
  ("creative-apps", "suite-shell", "SuiteShell", "planned", "suite.md: macOS glue every app links (switch, hand-off transport, pasteboard bridges)."),
  ("creative-core", "flarecore", "FlareCore", "existing", "Keyframe, Easing, Timeline sampling, Path flattening."),
  ("creative-core", "coremesh", "CoreMesh", "planned", "Needs new core issues C3D-1 and C3D-3: polygon mesh kernel, modeling operations, subdivision, mirror, BVH picking, outline extrusion."),
  ("creative-core", "coremodelio", "CoreModelIO", "planned", "Needs new core issues C3D-2 and C3D-5: glTF/GLB, OBJ+MTL, STL, PLY readers; GLB, OBJ, STL, USDZ writers; SVG shapes."),
  ("creative-core", "corerender3d", "CoreRender3D", "planned", "Needs new core issue C3D-4: CPU reference rasterizer with the glTF 2.0 BRDF, punctual lights, coverage and id passes."),
]

def owner(path):
    best = [(c["id"], p) for c in components for p in c["paths"] if path == p or (p.endswith("/") and path.startswith(p)) or (not p.endswith("/") and not p.endswith(".swift") and path.startswith(p))]
    if not best:
        return []
    longest = max(len(p) for _, p in best)
    return [cid for cid, p in best if len(p) == longest]

def build_c4():
    systems = {}
    for sid in ["creative-apps", "creative-core"]:
        systems[sid] = dict(id=sid, name=sid, status="existing", authored=True,
                            description="The macOS app shells of AfterGlow." if sid == "creative-apps" else "The engines (pure Swift, Linux-safe).",
                            containers=[])
    for cid, (name, status, desc, tech) in containers.items():
        comps = [dict(id=c["id"], name=c["name"], description=c["desc"], paths=c["paths"], status=c["status"], authored=True,
                      relationships=[dict(target=t, description=d, style="sync") for t, d in c["rels"]])
                 for c in components if c["container"] == cid]
        systems["creative-apps"]["containers"].append(dict(id=cid, name=name, description=desc, technology=tech,
                                                           status=status, authored=True, components=comps))
    for sid, cid, name, status, desc in externals:
        systems[sid]["containers"].append(dict(id=cid, name=name, description=desc, status=status, authored=True,
                                               components=[dict(id=cid + "-sources", name=name + " sources", description=desc,
                                                                paths=[], status=status, authored=True, relationships=[])]))
    rels = [dict(source="designer", target="prism-app", description="models, lights, animates and renders scenes in", style="sync"),
            dict(source="prism-app", target="prism-model", description="reads state and calls its methods", style="sync"),
            dict(source="prism-app", target="suiteui", description="builds its window from SuiteUI components", style="sync"),
            dict(source="prism-app", target="suite-shell", description="switcher row, hand-offs, pasteboard", style="sync"),
            dict(source="prism-model", target="suite-model", description="hand-off requests, document kinds", style="sync"),
            dict(source="prism-model", target="flarecore", description="keys and easing", style="sync"),
            dict(source="prism-model", target="coremesh", description="mesh editing, subdivision, extrusion", style="sync"),
            dict(source="prism-model", target="coremodelio", description="import and export", style="sync"),
            dict(source="prism-model", target="corerender3d", description="reference frames", style="sync")]
    return {"version": "1.0", "scope": "creative-apps/prism (planned)", "generated_at": "2026-10-15T00:00:00Z", "source_path": ".",
            "authored": True,
            "note": "Prism (3D) blueprint, part 4. Same shape as docs/c4/model.json, one level finer: L3 components with the files each owns. Every element is planned (nothing exists on origin/dev f2ef824). Generated by waves.py c4; not read by scripts/ci.",
            "model": {"people": [dict(id="designer", name="Designer or motion designer adding 3D", description="Models, materials, lights, animates and renders 3D for motion and design work.", status="existing", authored=True)],
                      "systems": list(systems.values()), "relationships": rels}}

def check():
    problems = []
    for w in sorted({f["wave"] for f in features}):
        seen = {}
        for f in [f for f in features if f["wave"] == w]:
            if len(set(f["owns"])) != len(f["owns"]):
                problems.append(f"{f['id']} lists a file twice")
            for p in f["owns"]:
                if p in seen:
                    problems.append(f"W{w}: {p} owned by {seen[p]} and {f['id']}")
                seen[p] = f["id"]
    all_sources = sorted({p for f in features for p in f["owns"] if p.startswith("Sources/") or p.startswith("Tests/") or p.startswith("UITests/Prism")})
    for p in all_sources:
        o = owner(p)
        if len(o) != 1:
            problems.append(f"{p} has {len(o)} C4 owners {o}")
    for c in contracts:
        if not any(M + f"Live/Live{c}.swift" in f["owns"] for f in features if f["wave"] > 0):
            problems.append(f"no feature replaces Live{c}")
    path = os.path.join(HERE, "c4-planned.json")
    if not os.path.exists(path) or json.load(open(path)) != build_c4():
        problems.append("c4-planned.json is stale: run waves.py c4")
    for p in problems:
        print("PROBLEM:", p)
    print("waves: " + ("PASS" if not problems else f"FAIL ({len(problems)})"), f"({len(features)} features, {len(all_sources)} owned source and test files, {len(components)} components)")
    return not problems

def md():
    for f in features:
        print(f"#### W{f['wave']} · `{f['id']}`: {f['name']}\n")
        print(f"- **Tier:** {f['tier']}")
        print(f"- **Waits on (creative-core):** {f['waits_core']}")
        print(f"- **Waits on (other lines and harness):** {f['waits_other']}")
        print(f"- **Proves:** {f['proves']}")
        print(f"- **Owned files ({len(f['owns'])}):** " + ", ".join(f"`{p}`" for p in f["owns"]) + "\n")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "c4":
        json.dump(build_c4(), open(os.path.join(HERE, "c4-planned.json"), "w"), indent=2, ensure_ascii=False)
        print("wrote c4-planned.json")
    elif cmd == "md":
        md()
    else:
        sys.exit(0 if check() else 1)
