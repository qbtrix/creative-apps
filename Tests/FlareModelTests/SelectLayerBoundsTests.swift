// SelectLayerBoundsTests.swift: under Select (V) the selection box frames the selected layers, every hittable item on
// them, not just the clicked item (#565). Direct Select (A) keeps the item box.
import FlareCore
@testable import FlareModel
import Testing

private func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

private func square(_ x: Double, _ y: Double) -> FlareShape {
    FlareShape(points: [p(x, y), p(x + 10, y), p(x + 10, y + 10), p(x, y + 10)], fill: .solid(FlareColor(r: 1, g: 0, b: 0)))
}

/// One scene, one unlocked layer `L` holding square A (0…10) and square B (100…110), under `tracks`.
private func twoSquares(tracks: [String: [Keyframe]] = [:]) -> Document {
    Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 48, layers: [
        Layer(id: "L", name: "L", shapes: [square(0, 0), square(100, 100)], tracks: tracks),
    ])])
}

private func clicked(_ document: Document, _ tool: FlareTool, at point: Point) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.selectTool(tool)
    w.drag(from: point, to: point)
    return w
}

@Test func selectFramesTheClickedItemsWholeLayer() {
    let w = clicked(twoSquares(), .select, at: p(5, 5))
    #expect(w.selectedLayerIDs == ["L"])
    #expect(w.selectionBounds == Rect(minX: 0, minY: 0, maxX: 110, maxY: 110))
}

@Test func selectFramesTheLayerUnderItsTransform() {
    let w = clicked(twoSquares(tracks: ["x": [Keyframe(frame: 0, value: 20)], "scaleX": [Keyframe(frame: 0, value: 2)]]),
                    .select, at: p(30, 5))
    #expect(w.selectionBounds == Rect(minX: 20, minY: 0, maxX: 240, maxY: 110))
}

@Test func directSelectKeepsTheClickedItemsBox() {
    let w = clicked(twoSquares(), .directSelect, at: p(5, 5))
    #expect(w.selectionBounds == Rect(minX: 0, minY: 0, maxX: 10, maxY: 10))
}
