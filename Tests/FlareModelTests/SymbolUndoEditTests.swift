// SymbolUndoEditTests.swift: an undo or redo that removes the symbol being edited in place ends the edit, back to
// the scene at the frame it left, so no edit targets a missing symbol (#603).
import FlareCore
@testable import FlareModel
import Testing

private func editingLegs() -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(FlareFixtures.character)
    workspace.selectLayer("legs")
    if let id = workspace.convertToSymbol(named: "Legs") { workspace.editSymbol(id) }
    return workspace
}

@Test func undoingConvertWhileEditingTheSymbolReturnsToTheScene603() {
    var w = editingLegs()
    #expect(w.editingSymbolID == "symbol-1" && w.breadcrumb == ["Scene 1", "Legs"])
    w.undo()
    #expect(w.editingSymbolID == nil && w.propertyOwner == .scene("scene-1"))
    #expect(w.breadcrumb == ["Scene 1"] && w.selection.isEmpty)
    w.selectLayer("legs")
    w.placeSymbol("wave", at: Point(x: 1, y: 1))
    #expect(w.layerError != .command(.symbolNotFound("symbol-1")))
}

@Test func redoingConvertDoesNotReenterTheSymbol603() {
    var w = editingLegs()
    w.undo()
    w.redo()
    #expect(w.editingSymbolID == nil && w.propertyOwner == .scene("scene-1"))
}

@Test func anUndoThatKeepsTheSymbolKeepsTheEdit603() {
    var w = editingLegs()
    w.addLayer()
    w.undo()
    #expect(w.editingSymbolID == "symbol-1" && w.editingSymbol != nil)
}
