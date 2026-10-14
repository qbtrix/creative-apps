# waves.py: section 8 of docs/blueprints/halo.md as data, and its check.
#   python3 docs/blueprints/halo/waves.py check docs/blueprints/halo/c4-planned.json
# fails loudly (prints each problem) when two features in one wave own the same
# file, or an owned Sources/ file has no single owner in c4-planned.json.
#   python3 docs/blueprints/halo/waves.py md     # prints section 8.3
import json, sys, itertools

M, A, T, SN, U = "Sources/HaloModel/", "Sources/HaloApp/", "Tests/HaloModelTests/", "Tests/AppSnapshotTests/", "UITests/"
contracts = ["FrameDrawing", "LayerPlacing", "PropertyKeying", "ViewerDragging", "KeyEasing", "ProjectHistory",
             "ProjectFiles", "PlaybackClock", "FrameRendering", "CompositionRendering"]

features = [
  dict(wave=0, id="foundation", name="Foundation: contracts, fakes, state and the window's seams",
       covers=["#286", "#290", "#149"], waits_ui=["#333 not needed (alone in its wave)"],
       core="none",
       owns=[M+"Contracts/HaloValues.swift", M+"Contracts/HaloContracts.swift"]
         + [M+f"Fakes/Fake{c}.swift" for c in contracts] + [M+"Fakes/FakeTextRasterizer.swift"]
         + [M+f"Live/Live{c}.swift" for c in contracts]
         + [M+"HaloServices.swift", M+"HaloLayerDefaults.swift", M+"HaloFixtures.swift", M+"HaloCommand.swift",
            M+"HaloViewerState.swift", M+"HaloProject.swift", M+"HaloLayer.swift", M+"HaloTimeline.swift",
            M+"HaloStatusText.swift", M+"NameKey.swift",
            A+"HaloApp.swift", A+"HaloLaunch.swift", A+"HaloWindow.swift", A+"HaloViewer.swift"]
         + [A+f"HaloWindow+{x}.swift" for x in ["Viewer", "Playback", "Keys", "Layers", "Edit", "File", "Easing", "Render", "Text"]]
         + [A+"HaloViewerCanvas.swift", A+"HaloViewerGestures.swift", A+"HaloRenderedFrameView.swift", A+"HaloTransport.swift",
            A+"HaloLayerInspector.swift", A+"HaloEasingInspector.swift", A+"HaloTextInspector.swift", A+"HaloTextRasterizer.swift",
            A+"HaloFileMenu.swift", A+"HaloEditMenu.swift", A+"HaloAnimationMenu.swift", A+"HaloCommands.swift",
            A+"HaloCompositionCommands.swift", A+"NewCompositionSheet.swift", A+"HaloCompositionInspector.swift",
            A+"HaloTimelineView.swift"]
         + [T+f"{c}ContractTests.swift" for c in contracts]
         + [T+"HaloCommandTests.swift", T+"HaloFixturesTests.swift", T+"HaloEditTests.swift", T+"HaloBudget.swift",
            T+"HaloFoundationBudgetTests.swift", T+"HaloNameWhitespaceTests.swift",
            SN+"HaloWindowSnapshots.swift", U+"HaloJourneyTests.swift",
            "docs/c4/model.json", "docs/design.md"],
       note="Copies section 5's files into Sources (fakes and live stubs one file per contract); every W1 and W2 file below that W0 creates as a stub passes to its feature, which replaces it whole."),
  dict(wave=1, id="viewer-playback", name="See and play the composition",
       covers=["#37", "#457"], waits_ui=["#333 (journey files)", "#340 TransportCapsule (placeholder meanwhile)"],
       core="none to start. Rotated shape layers in the pixel render wait on creative-core#182 (ellipse path builder, LC-4); until it lands the renderer draws an axis-aligned shape with `Mask.ellipse` and counts a rotated one as skipped (the viewer draws it either way)",
       owns=[M+"Live/LiveFrameDrawing.swift", M+"Live/LivePlaybackClock.swift", M+"Live/LiveFrameRendering.swift",
             M+"FrameRenderer.swift", M+"HaloPlayback.swift",
             A+"HaloViewerCanvas.swift", A+"HaloTransport.swift", A+"HaloPlaybackDriver.swift",
             A+"HaloWindow+Viewer.swift", A+"HaloWindow+Playback.swift",
             T+"FrameDrawingContractTests.swift", T+"PlaybackClockContractTests.swift", T+"FrameRenderingContractTests.swift",
             T+"HaloPlaybackTests.swift", T+"LiveFrameRenderingTests.swift", T+"HaloRenderTests.swift", T+"HaloRenderEdgeTests.swift",
             T+"HaloViewerBudgetTests.swift",
             SN+"HaloPreviewSnapshots.swift", SN+"HaloViewerFidelityTests.swift",
             U+"HaloJourneyTests+Viewer.swift", U+"HaloJourneyTests+Playback.swift", U+"HaloJourneyTests.swift"],
       note="H-J2, H-J3 (extends the shipped scrub journey), H-J4; HB-2, HB-5, HB-11; HF-1, HF-2."),
  dict(wave=1, id="layer-keys", name="Key layers: inspector, drag and parent",
       covers=["#38", "#207"], waits_ui=["#333 (journey files)"],
       core="none",
       owns=[M+"Live/LiveLayerPlacing.swift", M+"Live/LivePropertyKeying.swift", M+"Live/LiveViewerDragging.swift",
             M+"HaloKeying.swift", M+"HaloViewerDrag.swift",
             A+"HaloLayerInspector.swift", A+"HaloViewerGestures.swift", A+"HaloWindow+Keys.swift",
             T+"LayerPlacingContractTests.swift", T+"PropertyKeyingContractTests.swift", T+"ViewerDraggingContractTests.swift",
             T+"HaloKeyingTests.swift", T+"HaloKeyByDragTests.swift", T+"HaloKeysBudgetTests.swift",
             SN+"HaloInspectorSnapshots.swift", SN+"HaloKeyByDragSnapshots.swift",
             U+"HaloJourneyTests+Drag.swift", U+"HaloJourneyTests+Inspector.swift", U+"HaloJourneyTests+Parent.swift"],
       note="H-J5, H-J6, H-J23; HB-1, HB-3, HB-4; HF-3, HF-5."),
  dict(wave=1, id="history-files", name="Undo, redo, save and open",
       covers=["#208", "#209"], waits_ui=["#333 (journey files)"],
       core="none",
       owns=[M+"Live/LiveProjectHistory.swift", M+"Live/LiveProjectFiles.swift", M+"HaloHistory.swift", M+"HaloFiles.swift",
             A+"HaloWindow+Edit.swift", A+"HaloWindow+File.swift", A+"HaloDocumentType.swift",
             T+"ProjectHistoryContractTests.swift", T+"ProjectFilesContractTests.swift", T+"HaloUndoTests.swift",
             T+"HaloFileTests.swift", T+"HaloFilesBudgetTests.swift",
             SN+"HaloEditMenuSnapshots.swift", SN+"HaloFileSnapshots.swift",
             U+"HaloJourneyTests+History.swift", U+"HaloJourneyTests+Files.swift", U+"HaloJourneyTests+FileErrors.swift"],
       note="H-J8, H-J10, H-J11; HB-8, HB-10; HF-6. Closes the gap #127 left (undo of Delete Composition)."),
  dict(wave=1, id="layer-panel", name="Layer housekeeping",
       covers=["L-1 (to file)"], waits_ui=["#333 (journey files)"],
       core="none",
       owns=[M+"HaloLayerEdits.swift", A+"HaloLayerList.swift", A+"HaloWindow+Layers.swift",
             T+"HaloLayerEditsTests.swift", SN+"HaloLayersSnapshots.swift", U+"HaloJourneyTests+Layers.swift"],
       note="H-J9."),
  dict(wave=2, id="easing", name="Ease keys",
       covers=["#428"], waits_ui=["#333", "timeline key shapes and selection (Flare S10/S11, to file as needs-ui; plain diamonds meanwhile)"],
       core="none (FlareCore `Easing` and `Timeline.value` already ease)",
       owns=[M+"Live/LiveKeyEasing.swift", M+"HaloKeySelection.swift",
             A+"HaloEasingInspector.swift", A+"HaloTimelineView.swift", A+"HaloWindow+Easing.swift",
             T+"KeyEasingContractTests.swift", T+"HaloEasingTests.swift", T+"HaloEasingBudgetTests.swift",
             SN+"HaloEasingSnapshots.swift", U+"HaloJourneyTests+Easing.swift"],
       note="H-J7; HB-7; HF-4. Waits on layer-keys (keys to ease) and history-files (the journey reads the Undo name)."),
  dict(wave=2, id="render-out", name="Render a frame and render to files",
       covers=["#451", "#429"], waits_ui=["#333"],
       core="none (the PNG and movie writers are app-side: ImageIO and AVFoundation)",
       owns=[M+"Live/LiveCompositionRendering.swift", M+"HaloRenderFrame.swift", M+"HaloRenderJob.swift",
             A+"HaloRenderSheet.swift", A+"HaloRenderedFrameView.swift", A+"HaloFrameImage.swift", A+"HaloPNGWriter.swift",
             A+"HaloMovieWriter.swift", A+"HaloWindow+Render.swift",
             T+"CompositionRenderingContractTests.swift", T+"HaloRenderPlanTests.swift", T+"HaloRenderFrameTests.swift",
             T+"HaloRenderBudgetTests.swift",
             SN+"HaloRenderSheetSnapshots.swift", SN+"HaloRenderSnapshots.swift", SN+"HaloPNGWriterTests.swift",
             SN+"HaloMovieWriterTests.swift",
             U+"HaloJourneyTests+RenderFrame.swift", U+"HaloJourneyTests+Render.swift"],
       note="H-J20, H-J21; HB-12, HB-13; HF-7, HF-8. Waits on viewer-playback (the live renderer)."),
  dict(wave=2, id="text-layers", name="Text layers",
       covers=["#430"], waits_ui=["#333"],
       core="needs a new core issue: CoreRaster draws a PixelBuffer through a 2D affine matrix with bilinear sampling (suite plan H6), so scaled or rotated text renders; until it lands, text renders only at scale 1 and rotation 0 and is otherwise counted as skipped",
       owns=[M+"HaloTextEdits.swift", A+"HaloTextInspector.swift", A+"HaloTextRasterizer.swift", A+"HaloWindow+Text.swift",
             T+"HaloTextLayerTests.swift", SN+"HaloTextLayerSnapshots.swift", SN+"HaloTextFidelityTests.swift",
             U+"HaloJourneyTests+Text.swift"],
       note="H-J22; HF-10. Waits on layer-keys (inspector), viewer-playback (the renderer's text hook) and history-files (Undo name)."),
  dict(wave=3, id="core-loop", name="The core loop, live, measured",
       covers=["the H-J12 XCTSkip in HaloJourneyTests.swift"], waits_ui=["#333", "#330 FrameProbe for H-P1 to H-P4 (report-only until then)"],
       core="none",
       owns=[U+"HaloJourneyTests.swift", U+"HaloJourneyTests+Perf.swift", SN+"HaloViewerLatencyTests.swift", SN+"HaloLayoutTests.swift",
             U+"HaloJourneyTests+Viewer.swift", U+"HaloJourneyTests+Playback.swift", U+"HaloJourneyTests+Drag.swift",
             U+"HaloJourneyTests+Inspector.swift", U+"HaloJourneyTests+Parent.swift", U+"HaloJourneyTests+History.swift",
             U+"HaloJourneyTests+Layers.swift", U+"HaloJourneyTests+Easing.swift", U+"HaloJourneyTests+Text.swift",
             U+"HaloJourneyTests+RenderFrame.swift", U+"HaloJourneyTests+Render.swift"],
       note="H-J12 live; H-P1 to H-P4; layout L3 to L5; flips every fixture journey still on `-HaloFixture` to `-HaloSample`. Waits on every W1 and W2 feature."),
]

def check(c4path):
    c4 = json.load(open(c4path))
    paths = [p for s in c4["model"]["systems"] for c in s["containers"] for comp in c["components"] for p in comp["paths"]]
    problems = []
    for w in sorted({f["wave"] for f in features}):
        fs = [f for f in features if f["wave"] == w]
        for a, b in itertools.combinations(fs, 2):
            shared = set(a["owns"]) & set(b["owns"])
            if shared:
                problems.append(f"W{w}: {a['id']} and {b['id']} share {sorted(shared)}")
    for f in features:
        for o in f["owns"]:
            if o.startswith("Sources/"):
                owners = [p for p in paths if o == p or (p.endswith("/") and o.startswith(p))]
                if len(owners) != 1:
                    problems.append(f"{f['id']}: {o} has {len(owners)} C4 owners {owners}")
    return problems

if __name__ == "__main__":
    if sys.argv[1] == "check":
        probs = check(sys.argv[2])
        print("\n".join(probs) if probs else "WAVES: no shared files within a wave; every owned source file has one C4 owner")
        sys.exit(1 if probs else 0)
    else:
        for w in sorted({f["wave"] for f in features}):
            for f in [f for f in features if f["wave"] == w]:
                print(f"#### W{w} · `{f['id']}`: {f['name']}\n")
                print(f"- **Covers:** {', '.join(f['covers'])}")
                print(f"- **Waits on (SuiteUI and harness):** {'; '.join(f['waits_ui'])}")
                print(f"- **Waits on (creative-core):** {f['core']}")
                print(f"- **Proves:** {f['note']}")
                print(f"- **Owned files ({len(f['owns'])}):** " + ", ".join(f"`{o}`" for o in f["owns"]))
                print()
