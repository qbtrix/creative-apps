// SymbolEditSelectionTests.swift: while a symbol is edited in place, stage clicks and marquees hit the symbol's own
// items, never the scene's, and the selected layer stays one of `layers` (#641, docs/blueprints/flare.md, 3.4).
import FlareCore
@testable import FlareModel
import Testing

private let hand = StageAddress(owner: .symbol("wave"), layerID: "hand", item: .shape(0))

private func editingWave(_ tool: FlareTool = .select) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    w.editSymbol("wave")
    w.selectTool(tool)
    return w
}

/// The centre of the hand as the stage draws it inside Wave.
private func handCentre(_ w: FlareWorkspace) throws -> Point {
    let doc = try #require(w.document), scene = try #require(w.selectedSceneID)
    let item = try #require(FakeStage().drawList(doc, sceneID: scene, frame: w.currentFrame, editing: "wave").items
        .first { $0.address == hand })
    let box = try #require(item.path.bounds)
    return item.transform.apply(Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2))
}

@Test(arguments: [FlareTool.select, .directSelect])
func aClickInASymbolSelectsTheSymbolsArt(tool: FlareTool) throws {
    var w = editingWave(tool)
    let centre = try handCentre(w)
    w.drag(from: centre, to: centre)
    #expect(w.selection == [hand])
    #expect(w.selectedLayerID == "hand")
    #expect(w.selectionBounds != nil)
}

@Test func aMarqueeInASymbolSelectsOnlyTheSymbolsArt() {
    var w = editingWave()
    w.drag(from: Point(x: -5000, y: -5000), to: Point(x: 5000, y: 5000))
    #expect(w.selection == [hand])
    #expect(w.selectedLayerID.map { id in w.layers.contains { $0.id == id } } == true)
}

@Test func aClickOnEmptyStageInASymbolDeselects() throws {
    var w = editingWave()
    let centre = try handCentre(w)
    w.drag(from: centre, to: centre)
    w.drag(from: Point(x: -5000, y: -5000), to: Point(x: -5000, y: -5000))
    #expect(w.selection.isEmpty && w.selectedLayerID == nil)
}

@Test func backInTheSceneAMarqueeSelectsTheScenesArt() {
    var w = editingWave()
    w.exitSymbol()
    w.drag(from: Point(x: -5000, y: -5000), to: Point(x: 5000, y: 5000))
    #expect(!w.selection.isEmpty && w.selection.allSatisfy { $0.owner == .scene("scene-1") })
}

@Test func aDirectSelectDragInASymbolMovesTheSymbolsArt() throws {
    var w = editingWave(.directSelect)
    let centre = try handCentre(w)
    w.drag(from: centre, to: Point(x: centre.x + 10, y: centre.y))
    #expect(w.layerError == nil && w.selection == [hand])
    #expect(abs(try handCentre(w).x - centre.x - 10) < 0.001)
}
