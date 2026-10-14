// HaloLayersTests.swift: layers in a Halo composition: adding them from
// Layer > New, their names and spans, the layer selection, their tracks,
// parent and text through Codable and withID, and the default property
// values. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
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

/// A shape layer with a track, a parent and text, so every W0 field is set.
private func keyedLayer() -> HaloLayer {
    var layer = HaloLayer(
        id: "c-layer-2", name: "Ball", kind: .shape, inFrame: 2, outFrame: 40,
        color: HaloLayerColor(red: 0.1, green: 0.2, blue: 0.3), opacity: 0.75, blendMode: .multiply,
        rect: HaloLayerRect(x: 10, y: 20, width: 30, height: 40))
    layer.tracks[HaloProperty.x.rawValue] = [
        HaloKeyframe(frame: 0, value: 50), HaloKeyframe(frame: 24, value: 150, easing: .easeInOut),
    ]
    layer.parentID = "c-layer-1"
    layer.text = HaloTextContent(string: "Hello Halo", fontSize: 48)
    return layer
}

@Test func aLayerWithTracksAParentAndTextEncodesAndDecodesEqual() throws {
    let layer = keyedLayer()
    let data = try JSONEncoder().encode(layer)
    #expect(try JSONDecoder().decode(HaloLayer.self, from: data) == layer)
}

@Test func aFileWithoutTheW0FieldsDecodesThemEmpty() throws {
    let json = """
        {"id":"a","name":"A","kind":"solid","inFrame":0,"outFrame":30,
         "color":{"red":1,"green":1,"blue":1},"opacity":1,"blendMode":"normal"}
        """
    let layer = try JSONDecoder().decode(HaloLayer.self, from: Data(json.utf8))
    #expect(layer.tracks.isEmpty && layer.parentID == nil && layer.text == nil && layer.rect == nil)
}

@Test func withIDCopiesTracksParentAndText() {
    let layer = keyedLayer()
    let copy = layer.withID("d-layer-2")
    #expect(copy.id == "d-layer-2")
    #expect(copy.tracks == layer.tracks)
    #expect(copy.parentID == layer.parentID)
    #expect(copy.text == layer.text)
}

@Test(arguments: HaloLayerKind.allCases)
func defaultValuePutsAnchorAndPositionAtTheBoxCenter(kind: HaloLayerKind) {
    let comp = HaloComposition(id: "c", name: "C", width: 1920, height: 1080, framesPerSecond: 30, durationFrames: 300)
    var layer = HaloLayer(id: "l", name: "L", kind: kind, inFrame: 0, outFrame: 300, color: kind.defaultColor, opacity: 0.4)
    if kind == .text { layer.text = HaloTextContent(string: "Hi", fontSize: 100, width: 120, height: 100) }
    let box = layer.bounds(in: comp)
    #expect(box.x + box.width / 2 == 960 && box.y + box.height / 2 == 540)
    for property in [HaloProperty.x, .anchorX] { #expect(layer.defaultValue(property, in: comp) == 960) }
    for property in [HaloProperty.y, .anchorY] { #expect(layer.defaultValue(property, in: comp) == 540) }
    #expect(layer.defaultValue(.scaleX, in: comp) == 1 && layer.defaultValue(.rotation, in: comp) == 0)
    #expect(layer.defaultValue(.opacity, in: comp) == 0.4)
}
