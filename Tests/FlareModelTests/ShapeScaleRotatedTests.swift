// ShapeScaleRotatedTests.swift: #511, a Scale box gesture on a rotated layer scales in the layer's own axes about
// the opposite handle. The scene point under that handle stays put, and only the dragged handle's axes stretch.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let shadow = StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))

private func rotated(_ degrees: Double) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try engine.perform(SetKeyframe(sceneID: "scene-1", layerID: "shadow", property: "rotation",
                                   keyframe: Keyframe(frame: 0, value: degrees)))
    return engine
}
private func transform(_ e: CommandEngine) throws -> Transform {
    let layer = try #require(e.document.layers(of: .scene("scene-1"))?.first { $0.id == "shadow" })
    return layer.placement(at: 0).transform
}
private func near(_ a: Point, _ b: Point) -> Bool { abs(a.x - b.x) < 1e-6 && abs(a.y - b.y) < 1e-6 }

@Test(arguments: [0, 1, 2, 3, 4, 5, 6, 7])
func aScaleOnAThirtyDegreeLayerKeepsTheOppositeHandleAndScalesItsOwnAxes(_ handle: Int) throws {
    var engine = try rotated(30)
    let box = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    let fixed = FakeShapes.handle(handle + 4, on: box), grip = FakeShapes.handle(handle, on: box)
    let before = try transform(engine)
    // Drag the grip 1.5x as far from the fixed handle, along the layer's own axes.
    let turn = Matrix.rotation(degrees: 30), back = Matrix.rotation(degrees: -30)
    let local = back.apply(Point(x: grip.x - fixed.x, y: grip.y - fixed.y))
    let drag = turn.apply(Point(x: local.x * 1.5, y: local.y * 1.5))
    let to = Point(x: fixed.x + drag.x, y: fixed.y + drag.y)
    let pinned = try before.matrix.inverted().apply(fixed)  // the layer point under the fixed handle
    try shapes.commitBox(.scale(handle: handle, to: to), layers: ["shadow"], sceneID: "scene-1", frame: 0, box: box,
                         autoKey: false, in: &engine)
    let after = try transform(engine)
    #expect(near(after.matrix.apply(pinned), fixed) && after.rotation == 30 && engine.undoActionName == "Undo Scale")
    // A corner stretches both local axes by 1.5; an edge only the local axis nearest its drag, the other stays.
    let (sx, sy) = (after.scaleX / before.scaleX, after.scaleY / before.scaleY)
    let expected = switch handle % 4 { case 1: (1.0, 1.5); case 3: (1.5, 1.0); default: (1.5, 1.5) }
    #expect(abs(sx - expected.0) < 1e-6 && abs(sy - expected.1) < 1e-6)
}

@Test func aScaleOnANinetyDegreeLayerStretchesTheAxesUnderThePointer() throws {
    var engine = try rotated(90)
    let box = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    try shapes.commitBox(.scale(handle: 4, to: Point(x: box.maxX + 50, y: box.maxY + 20)), layers: ["shadow"],
                         sceneID: "scene-1", frame: 0, box: box, autoKey: false, in: &engine)
    let after = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    #expect(near(Point(x: after.minX, y: after.minY), Point(x: box.minX, y: box.minY)))
    #expect(near(Point(x: after.maxX, y: after.maxY), Point(x: box.maxX + 50, y: box.maxY + 20)))
}
