// SymbolExitRefusalTests.swift: a refusal that belongs to a symbol edit, "Exit the symbol…", stays while the user is
// inside the symbol and clears when they exit it or enter another (#686).
import FlareCore
@testable import FlareModel
import Testing

/// Character with Body converted to "Torso" and opened with the Select tool, after a refused Select drag on the
/// symbol's body art.
private func refusedMoveInTorso() throws -> (FlareWorkspace, String) {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    w.selectTool(.select)
    w.drag(from: Point(x: 275, y: 220), to: Point(x: 275, y: 220))
    let converted = w.convertToSymbol(named: "Torso")
    let id = try #require(converted)
    w.editSymbol(id)
    w.selectTool(.select)
    let doc = try #require(w.document), scene = try #require(w.selectedSceneID)
    let item = try #require(FakeStage().drawList(doc, sceneID: scene, frame: w.currentFrame, editing: id).items
        .first(where: { $0.address.owner == .symbol(id) && $0.address.layerID == "body" }))
    let box = try #require(item.path.bounds)
    let c = item.transform.apply(Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2))
    w.drag(from: c, to: Point(x: c.x + 40, y: c.y))
    w.drag(from: c, to: c)
    return (w, id)
}

@Test func theMoveRefusalStillShowsInsideTheSymbol() throws {
    let (w, id) = try refusedMoveInTorso()
    #expect(w.editingSymbolID == id)
    #expect(w.layerError == .refused(FlareWorkspace.moveInSymbolMessage))
}

@Test func exitingTheSymbolClearsItsMoveRefusal() throws {
    var (w, _) = try refusedMoveInTorso()
    w.exitSymbol()
    #expect(w.editingSymbolID == nil)
    #expect(w.layerError == nil)
}

@Test func exitingTheSymbolClearsItsConvertRefusal() throws {
    var (w, _) = try refusedMoveInTorso()
    _ = w.convertToSymbol(named: "Again")
    #expect(w.layerError == .refused(FlareWorkspace.convertInSymbolMessage))
    w.exitSymbol()
    #expect(w.layerError == nil)
}

@Test func enteringASymbolClearsTheSceneRefusal() throws {
    var (w, id) = try refusedMoveInTorso()
    w.exitSymbol()
    _ = w.convertToSymbol(named: "Nothing")
    #expect(w.layerError != nil)
    w.editSymbol(id)
    #expect(w.layerError == nil)
}
