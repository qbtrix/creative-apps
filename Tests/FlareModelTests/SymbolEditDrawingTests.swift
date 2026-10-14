// SymbolEditDrawingTests.swift: while a symbol is edited in place, Ellipse, Rectangle and Pen add their new layer to
// the symbol, above its selected layer, and select it; the scene is left alone (#642, docs/blueprints/flare.md, 3.4).
import FlareCore
@testable import FlareModel
import Testing

private func drawingInWave(_ tool: FlareTool) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    w.editSymbol("wave")
    w.selectLayer("hand")
    w.selectTool(tool)
    return w
}

private let sceneLayers = ["legs", "body", "arms", "head"]

@Test(arguments: [(FlareTool.ellipse, "ellipse-1"), (.rectangle, "rectangle-1")])
func aBoxToolInASymbolDrawsIntoTheSymbol(tool: FlareTool, id: String) {
    var w = drawingInWave(tool)
    w.drag(from: Point(x: 10, y: 10), to: Point(x: 60, y: 50))
    #expect(w.layerError == nil)
    #expect(w.layers.map(\.id) == [id, "hand"] && w.selectedLayerID == id)
    #expect(w.selectedScene?.layers.map(\.id) == sceneLayers)
    w.undo()
    #expect(w.layers.map(\.id) == ["hand"])
}

@Test func thePenInASymbolDrawsIntoTheSymbol() {
    var w = drawingInWave(.pen)
    for (x, y) in [(0.0, 0.0), (50, 0), (50, 50), (0, 0)] { w.drag(from: Point(x: x, y: y), to: Point(x: x, y: y)) }
    #expect(w.layerError == nil)
    #expect(w.layers.map(\.id) == ["path-1", "hand"] && w.selectedLayerID == "path-1")
    #expect(w.selectedScene?.layers.map(\.id) == sceneLayers)
}

@Test func anEllipseSkipsNamesSymbolLayersUse() {
    var w = drawingInWave(.ellipse)
    w.drag(from: Point(x: 10, y: 10), to: Point(x: 60, y: 50))
    w.exitSymbol()
    w.drag(from: Point(x: 10, y: 10), to: Point(x: 60, y: 50))
    #expect(w.layerError == nil && w.layers.first.map { [$0.id, $0.name] } == ["ellipse-2", "Ellipse 2"])
}
