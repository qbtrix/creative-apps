// SceneGuideEditTests.swift: scenes, guides and the Edit menu on FlareWorkspace (LM-0a4), each edit one named undo step
// (QB-F3); every Edit action either acts or is disabled with the reason it refuses with.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import Testing

private func workspace(_ document: Document, _ services: FlareServices = .fake()) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: services)
    workspace.load(document)
    return workspace
}

private func layer(_ w: FlareWorkspace, _ name: String) -> Layer? { w.layers.first { $0.name == name } }

@Test func theLastSceneCantBeRemovedAndScenesFollowJ16() {
    var w = workspace(FlareFixtures.bounce)
    w.removeScene("scene-1")
    #expect(w.sceneRemoveHelp("scene-1") == "An animation needs at least one scene.")
    #expect(w.layerError?.message == "An animation needs at least one scene." && w.document == FlareFixtures.bounce)
    w.addScene()
    #expect(w.scenes.map(\.name) == ["Scene 1", "Scene 2"] && w.selectedSceneID == "scene-2")
    #expect(w.selectedScene?.width == 550 && w.undoActionName == "Undo Add Scene")
    w.renameScene("scene-2", to: "  Outro ")
    w.renameScene("scene-2", to: "   ")
    #expect(w.scenes.last?.name == "Outro" && w.layerError?.message == "Type a name for the scene.")
    w.moveScene(from: 1, to: 0)
    #expect(w.scenes.map(\.name) == ["Outro", "Scene 1"] && w.sceneRemoveHelp("scene-1") == nil)
    w.removeScene("scene-2")
    #expect(w.scenes.map(\.name) == ["Scene 1"] && w.selectedSceneID == "scene-1" && w.undoActionName == "Undo Delete Scene")
    w.setSceneTiming(fps: 30, durationFrames: 60)
    #expect(w.selectedScene?.fps == 30 && w.undoActionName == "Undo Set Scene Timing")
    w.setSceneCanvas(width: 640, height: 480, background: FlareColor(r: 0, g: 0, b: 0))
    #expect(w.selectedScene?.width == 640 && w.undoActionName == "Undo Set Canvas")
}

@Test func aGuideDragOf50MovesIsOneMoveGuideStep() {
    var w = workspace(FlareFixtures.bounce)
    #expect(w.clearGuidesHelp == "There are no guides to clear.")
    w.addGuide(.horizontal, at: 300)
    for i in 1...50 { w.moveGuide(at: 0, to: 300 + Double(i) * 0.4, dragStart: 300) }
    #expect(w.guides == [Guide(axis: .horizontal, position: 320)] && w.undoActionName == "Undo Move Guide")
    w.moveGuide(at: 0, to: 330, dragStart: 320)
    w.undo()
    #expect(w.guides.first?.position == 320 && w.undoActionName == "Undo Move Guide")
    w.undo()
    #expect(w.guides.first?.position == 300 && w.undoActionName == "Undo Add Guide")
    w.addGuide(.vertical, at: 100)
    w.clearGuides()
    #expect(w.guides.isEmpty && w.undoActionName == "Undo Clear Guides")
    w.undo()
    w.removeGuide(at: 0)
    #expect(w.guides == [Guide(axis: .vertical, position: 100)] && w.undoActionName == "Undo Remove Guide")
}

@Test func copyPasteDuplicateCutDeleteFollowJ15() {
    var w = workspace(FlareFixtures.bounce)
    w.selectLayer("ball")
    let copied = w.copy()
    w.paste(copied)
    #expect(w.layers.map(\.name) == ["Ball copy", "Ball", "Shadow", "Background"] && w.undoActionName == "Undo Paste")
    #expect(layer(w, "Ball copy")?.tracks["x"]?.first?.value == 90 && w.selectedLayerIDs == [w.layers.first?.id])
    w.duplicate()
    #expect(w.layers.first?.name == "Ball copy 2" && w.undoActionName == "Undo Duplicate")
    w.selectLayer("shadow")
    let cut = w.cut()
    #expect(cut != nil && layer(w, "Shadow") == nil && w.undoActionName == "Undo Cut" && w.selectedLayerID == nil)
    w.paste(cut)
    #expect(layer(w, "Shadow copy") != nil && w.undoActionName == "Undo Paste")
    w.selectItem(w.layers.first { $0.name == "Ball copy 2" }?.id ?? "")
    w.delete()
    #expect(layer(w, "Ball copy 2") == nil && w.undoActionName == "Undo Delete")
    for _ in 1...5 { w.undo() }
    #expect(w.document == FlareFixtures.bounce && !w.canUndo)  // five acts, five steps (QB-F3)
}

@Test func lockedLayersGarbagePasteAndSelectAll() {
    var w = workspace(FlareFixtures.bounce)
    w.selectLayer("background")
    for action in [FlareEditAction.cut, .delete, .paste] {
        #expect(w.editHelp(action, pasteboard: Data([1])) == "Unlock Background to draw on it.")
    }
    #expect(w.cut() == nil && w.layerError?.message == "Unlock Background to draw on it.")
    w.delete()
    w.selectLayer("ball")
    w.paste(Data("not layers".utf8))
    #expect(w.layerError?.message == "Nothing to paste." && w.document == FlareFixtures.bounce && !w.canUndo)
    #expect(w.editHelp(.paste) == "Nothing to paste.")
    w.selectAll()  // locked Background is left out
    #expect(Set(w.selectedLayerIDs) == ["ball", "shadow"] && w.editHelp(.selectAll) == "Everything is already selected.")
    w.deselect()
    #expect(w.selection.isEmpty && w.selectedLayerID == nil && w.editHelp(.deselect) == "Nothing is selected.")
    #expect(workspace(FlareFixtures.empty).editHelp(.selectAll) == "There is nothing to select.")
}

/// Runs `action` on `w`, with `pasteboard` for Paste.
private func run(_ action: FlareEditAction, on w: inout FlareWorkspace, pasteboard: Data?) -> Data? {
    switch action {
    case .cut: return w.cut()
    case .copy: return w.copy()
    case .paste: w.paste(pasteboard)
    case .duplicate: w.duplicate()
    case .delete: w.delete()
    case .selectAll: w.selectAll()
    case .deselect: w.deselect()
    }
    return nil
}

/// No dead controls, and QB-F3: on every fixture, selection and service set, an enabled Edit action changes the
/// document in exactly one undo step or changes the selection; a disabled one changes nothing and refuses with its help.
@Test(arguments: [FlareServices.fake(), .live])
func everyEditActionActsInOneStepOrSaysWhyNot(services: FlareServices) throws {
    let pasteboard = try FakeShapes().copy(layers: ["ball"], owner: .scene("scene-1"), from: FlareFixtures.bounce)
    let picks: [(inout FlareWorkspace) -> Void] = [{ _ in }, { $0.selectLayer("ball") }, { $0.selectLayer("background") },
                                                   { $0.selectAll() }, { $0.selectTool(.directSelect); $0.selectAll() }]
    for action in FlareEditAction.allCases {
        #expect(FlareWorkspace(services: services).editHelp(action, pasteboard: pasteboard) == FlareLayerError.noDocument.message)
    }
    for document in [FlareFixtures.empty, FlareFixtures.bounce] {
        for pick in picks {
            for action in FlareEditAction.allCases {
                var w = workspace(document, services)
                pick(&w)
                let before = w
                let help = w.editHelp(action, pasteboard: pasteboard)
                let data = run(action, on: &w, pasteboard: pasteboard)
                if let help {
                    #expect(w.layerError?.message == help && w.document == document && !w.canUndo
                            && w.selection == before.selection && w.selectedLayerID == before.selectedLayerID, "\(action)")
                } else if w.document != document {
                    #expect(w.layerError == nil && w.canUndo, "\(action)")
                    w.undo()
                    #expect(w.document == document && !w.canUndo, "\(action) is one step")
                } else {
                    let selected = w.selection != before.selection || w.selectedLayerID != before.selectedLayerID
                    #expect(w.layerError == nil && (selected || data != nil), "\(action) did nothing")
                }
            }
        }
    }
}
