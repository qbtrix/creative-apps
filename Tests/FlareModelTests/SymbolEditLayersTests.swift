// SymbolEditLayersTests.swift: while a symbol is edited in place, the Layers list, layer selection, layer edits and
// Select All target the symbol's own layers, not the scene's (#602, docs/blueprints/flare.md, 3.4).
import FlareCore
@testable import FlareModel
import Testing

private func editingWave() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    w.editSymbol("wave")
    return w
}

@Test func editingASymbolListsAndSelectsItsOwnLayers() {
    var w = editingWave()
    #expect(w.layers.map(\.id) == ["hand"])
    w.selectLayer("hand")
    #expect(w.selectedLayerID == "hand" && w.propertyLayerIDs == ["hand"])
    w.selectLayer("legs")
    #expect(w.selectedLayerID == "hand")
    w.exitSymbol()
    #expect(w.layers.map(\.id) == ["head", "arms", "body", "legs"])
}

@Test func aSymbolLayerSelectionSurvivesAnEditInTheSymbol() {
    var w = editingWave()
    w.selectLayer("hand")
    w.placeSymbol("wave", at: Point(x: 1, y: 1))
    #expect(w.layerError != nil && w.selectedLayerID == "hand")
    w.renameLayer("hand", to: "Palm")
    #expect(w.layerError == nil && w.selectedLayerID == "hand")
    #expect(w.editingSymbol?.layers.map(\.name) == ["Palm"] && w.layers.map(\.name) == ["Palm"])
    #expect(w.selectedScene?.layers.map(\.id) == ["legs", "body", "arms", "head"])
}

@Test func layerEditsInASymbolChangeTheSymbol() {
    var w = editingWave()
    w.selectLayer("hand")
    w.addLayer()
    #expect(w.layerError == nil && w.layers.map(\.id) == ["layer-1", "hand"] && w.selectedLayerID == "layer-1")
    w.toggleLayerFlag("hand", .visible)
    #expect(w.editingSymbol?.layers.first { $0.id == "hand" }?.isVisible == false)
    w.moveLayer(from: 1, to: 0)
    #expect(w.layers.map(\.id) == ["hand", "layer-1"])
    w.removeLayer("layer-1")
    #expect(w.layers.map(\.id) == ["hand"] && w.selectedLayerID == "hand")
    #expect(w.selectedScene?.layers.count == 4)
}

@Test func selectAllInASymbolSelectsTheSymbolsItems() {
    var w = editingWave()
    w.selectAll()
    #expect(w.layerError == nil)
    #expect(w.selection == [StageAddress(owner: .symbol("wave"), layerID: "hand", item: .shape(0))])
    #expect(w.propertyLayerIDs == ["hand"] && w.selectedLayerID == "hand")
    #expect(w.editHelp(.selectAll) == "Everything is already selected.")
}

@Test func editMenuActsOnTheSymbolsLayers() {
    var w = editingWave()
    w.selectLayer("hand")
    w.duplicate()
    #expect(w.layerError == nil && w.layers.count == 2 && w.selectedScene?.layers.count == 4)
    w.delete()
    #expect(w.layerError == nil && w.layers.map(\.id) == ["hand"])
}
