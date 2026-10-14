// SymbolEditMoveTests.swift: while a symbol is edited in place, a Select-tool drag never keys a scene layer that
// shares the symbol layer's id (#674). Symbol layers can't be keyed yet, so the move refuses with a message.
import FlareCore
@testable import FlareModel
import Testing

/// Character with Body converted to "Torso" and opened: the scene keeps layer "body" holding the instance, and the
/// symbol's own layer is "body" too.
private func editingTorso() throws -> (FlareWorkspace, String) {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    w.selectTool(.select)
    w.drag(from: Point(x: 275, y: 220), to: Point(x: 275, y: 220))
    let converted = w.convertToSymbol(named: "Torso")
    let id = try #require(converted)
    w.editSymbol(id)
    w.selectTool(.select)
    return (w, id)
}

/// The centre of the symbol's body art as the stage draws it.
private func bodyCentre(_ w: FlareWorkspace, _ id: String) throws -> Point {
    let doc = try #require(w.document), scene = try #require(w.selectedSceneID)
    let item = try #require(FakeStage().drawList(doc, sceneID: scene, frame: w.currentFrame, editing: id).items
        .first(where: { $0.address.owner == .symbol(id) && $0.address.layerID == "body" }))
    let box = try #require(item.path.bounds)
    return item.transform.apply(Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2))
}

@Test func aSelectDragInASymbolNeverKeysTheScenesSameIdLayer() throws {
    var (w, id) = try editingTorso()
    let sceneBefore = try #require(w.document?.layers(of: .scene("scene-1"))?.first(where: { $0.id == "body" }))
    let symbolBefore = try #require(w.document?.layers(of: .symbol(id))?.first(where: { $0.id == "body" }))
    let c = try bodyCentre(w, id)
    w.drag(from: c, to: c)
    #expect(w.selection.map(\.owner) == [.symbol(id)])
    let undoBefore = w.canUndo
    w.dragChanged(from: c, to: Point(x: c.x + 40, y: c.y))
    #expect(w.dragPreview == nil)
    w.endDrag()
    #expect(w.document?.layers(of: .scene("scene-1"))?.first(where: { $0.id == "body" }) == sceneBefore)
    #expect(w.document?.layers(of: .symbol(id))?.first(where: { $0.id == "body" }) == symbolBefore)
    #expect(w.layerError == .refused(FlareWorkspace.moveInSymbolMessage))
    #expect(w.canUndo == undoBefore)
    #expect(w.selection.map(\.owner) == [.symbol(id)])
}

@Test func aSelectDragInTheSceneStillMovesTheLayer() throws {
    var (w, _) = try editingTorso()
    w.exitSymbol()
    let c = Point(x: 275, y: 220)
    w.drag(from: c, to: c)
    #expect(w.selection.map(\.layerID) == ["body"])
    w.drag(from: c, to: Point(x: c.x + 40, y: c.y))
    #expect(w.layerError == nil)
    let body = try #require(w.document?.layers(of: .scene("scene-1"))?.first(where: { $0.id == "body" }))
    #expect(body.tracks["x"]?.first?.value == 40)
}
