// HaloLayersTests.swift: layers in a Halo composition: adding them from
// Layer > New, their names and spans, and the layer selection. Runs on Linux
// and macOS.
import HaloModel
import Testing

@Test func newSolidSpansTheWholeCompositionAndIsSelected() {
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    let layer = project.selectedLayer
    #expect(layer?.name == "Solid 1")
    #expect(layer?.kind == .solid)
    #expect(layer?.inFrame == 0)
    #expect(layer?.outFrame == 300)
    #expect(layer?.color == HaloLayerKind.solid.defaultColor)
}

@Test func layerNamesNumberPerKindAndNewLayersGoOnTop() {
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    project.newLayer(.solid)
    project.newLayer(.text)
    #expect(project.selectedComposition?.layers.map(\.name) == ["Text 1", "Solid 2", "Solid 1"])
    #expect(project.selectedLayer?.name == "Text 1")
    #expect(Set(project.selectedComposition?.layers.map(\.id) ?? []).count == 3)
}

@Test func addingWithNoCompositionDoesNothing() {
    var project = HaloProject()
    #expect(project.canAddLayer == false)
    project.newLayer(.shape)
    #expect(project.compositions.isEmpty)
    #expect(project.selectedLayerID == nil)
    project.newComposition()
    #expect(project.canAddLayer)
}

@Test func selectingAnotherCompositionClearsTheLayerSelection() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.newLayer(.null)
    #expect(project.selectedLayerID == "comp-2-layer-1")
    project.selectComposition("comp-2")
    #expect(project.selectedLayerID == "comp-2-layer-1")
    project.selectComposition("comp-1")
    #expect(project.selectedLayerID == nil)
    #expect(project.selectedComposition?.layers.isEmpty == true)
}

@Test func selectLayerIgnoresLayersOutsideTheSelectedComposition() {
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    project.newLayer(.shape)
    project.selectLayer("comp-1-layer-1")
    #expect(project.selectedLayer?.name == "Solid 1")
    project.newComposition()
    project.selectLayer("comp-1-layer-1")
    #expect(project.selectedLayerID == nil)
}

@Test func layerSummaryCountsLayers() {
    var project = HaloProject()
    project.newComposition()
    #expect(project.selectedComposition?.layerSummary == "No layers")
    project.newLayer(.solid)
    #expect(project.selectedComposition?.layerSummary == "1 layer")
    project.newLayer(.shape)
    project.newLayer(.text)
    #expect(project.selectedComposition?.layerSummary == "3 layers")
}
