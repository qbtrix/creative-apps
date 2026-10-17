// FlareStageReadTests.swift: the stage read model (DK-4, packet draw-key-save). `stageList` is the move preview while
// one runs, else the stage service's list at the playhead; `stageMarks` carries the draft, marquee and selection box.
import FlareCore
@testable import FlareModel
import Testing

private func opened(_ document: Document, tool: FlareTool = .select) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(document)
    workspace.selectTool(tool)
    return workspace
}

private func corners(_ path: FlarePath?) -> Set<String> {
    Set((path?.elements ?? []).compactMap { element -> String? in
        switch element {
        case .move(let p), .line(let p): "\(p.x),\(p.y)"
        default: nil
        }
    })
}

@Test func bounceAtFrameZeroIsTheStageServicesList() {
    let workspace = opened(FlareFixtures.bounce)
    let want = FakeStage().drawList(FlareFixtures.bounce, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(workspace.stageList == want)
    #expect(workspace.stageList?.items.isEmpty == false)
    #expect(workspace.stageMarks == StageMarks())
}

@Test func duringAMoveDragTheListIsTheDragPreview() throws {
    var workspace = opened(FlareFixtures.bounce)
    let still = try #require(workspace.stageList)
    workspace.dragChanged(from: Point(x: 80, y: 100), to: Point(x: 120, y: 140))
    let preview = try #require(workspace.dragPreview)
    #expect(workspace.stageList == preview)
    #expect(preview != still)
    workspace.endDrag()
    let document = try #require(workspace.document)
    #expect(workspace.dragPreview == nil)
    #expect(workspace.stageList == FakeStage().drawList(document, sceneID: "scene-1", frame: 0, editing: nil))
}

@Test func aRectangleDragGivesAFourCornerDraftUntilItEnds() {
    var workspace = opened(FlareFixtures.empty, tool: .rectangle)
    workspace.dragChanged(from: Point(x: 10, y: 20), to: Point(x: 110, y: 70))
    let draft = workspace.stageMarks.draft
    #expect(draft != nil && draft == workspace.draft?.shape.outline)
    #expect(corners(draft) == ["10.0,20.0", "110.0,20.0", "110.0,70.0", "10.0,70.0"])
    workspace.endDrag()
    #expect(workspace.stageMarks.draft == nil)
}

@Test func aMarqueeDragGivesItsRect() {
    var workspace = opened(FlareFixtures.bounce)
    workspace.dragChanged(from: Point(x: 540, y: 60), to: Point(x: 400, y: 10))
    #expect(workspace.stageMarks.marquee == Rect(minX: 400, minY: 10, maxX: 540, maxY: 60))
    #expect(workspace.stageMarks.draft == nil && workspace.stageMarks.selection == nil)
    workspace.endDrag()
    #expect(workspace.stageMarks.marquee == nil)
}

@Test func oneSelectionGivesItsBounds() throws {
    var workspace = opened(FlareFixtures.bounce)
    workspace.drag(from: Point(x: 80, y: 100), to: Point(x: 80, y: 100))
    #expect(workspace.selection.count == 1)
    let box = try #require(workspace.stageMarks.selection)
    #expect(box == workspace.selectionBounds)
    #expect(box == Rect(minX: 50, minY: 70, maxX: 110, maxY: 130))
}

@Test func noDocumentGivesNoList() {
    let workspace = FlareWorkspace(services: .fake())
    #expect(workspace.stageList == nil)
    #expect(workspace.stageMarks == StageMarks())
}
