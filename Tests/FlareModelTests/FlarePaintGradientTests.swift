// FlarePaintGradientTests.swift: gradient-fill FG-6 on `.built`. Two shapes with different gradients read Mixed (no
// gradient for the editor), two with the same gradient read it, and a hex set on a gradient turns it solid as one
// "Set Fill" step that one undo reverts.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private func linear(_ end: Double) -> FlareCore.Fill {
    .linear(stops: [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)],
            start: Point(x: 0, y: 0), end: Point(x: end, y: 0))
}

private let layers = ["ball", "shadow"]

/// Bounce with Ball's and Shadow's first shapes filled `first` and `second`, both selected, on `.built`.
private func pair(_ first: FlareCore.Fill, _ second: FlareCore.Fill) -> FlareWorkspace {
    var doc = FlareFixtures.bounce
    for (id, fill) in zip(layers, [first, second]) {
        if let i = doc.scenes.first?.layers.firstIndex(where: { $0.id == id }),
           !doc.scenes[0].layers[i].shapes.isEmpty { doc.scenes[0].layers[i].shapes[0].fill = fill }
    }
    var w = FlareWorkspace(services: .built)
    w.load(doc)
    w.selectLayer("ball")
    w.setSelection(layers.map { StageAddress(owner: .scene("scene-1"), layerID: $0, item: .shape(0)) })
    return w
}

private func fills(_ w: FlareWorkspace) -> [FlareCore.Fill] {
    layers.compactMap { id in w.document?.layers(of: .scene("scene-1"))?.first { $0.id == id }?.shapes.first?.fill }
}

@Suite struct FlarePaintGradientTests {
    @Test func differingGradientsAreMixed() throws {
        let w = pair(linear(1), linear(2))
        try #require(w.paint != nil)
        #expect(w.paint?.fillIsGradient == true && w.paint?.fillHex == nil)
        #expect(w.paint?.gradient == nil)
    }

    @Test func theSameGradientReadsIt() throws {
        let w = pair(linear(1), linear(1))
        #expect(w.paint?.gradient?.fill == linear(1))
    }

    @Test func solidReplacesGradient() throws {
        var w = pair(linear(1), linear(2))
        let before = w.document
        w.setFill(hex: "FF3B30")
        #expect(w.paintError == nil)
        let red = FlareCore.Fill.solid(FlareColor(r: 1, g: 59.0 / 255, b: 48.0 / 255))
        #expect(fills(w) == [red, red])
        #expect(w.paint?.fillHex == "FF3B30" && w.paint?.gradient == nil)
        #expect(w.undoActionName == "Undo Set Fill")
        w.undo()
        #expect(w.document == before && !w.canUndo)
    }
}
