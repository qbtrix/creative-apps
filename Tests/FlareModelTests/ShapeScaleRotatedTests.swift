// ShapeScaleRotatedTests.swift: #511, a Scale box gesture on a layer turned a multiple of 90° stretches the world
// axes under the pointer about the opposite handle. Other angles are ShapeScaleObliqueTests (#560).
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
    try engine.perform(SetKeyframe(owner: .scene("scene-1"), layerID: "shadow", property: "rotation",
                                   keyframe: Keyframe(frame: 0, value: degrees)))
    return engine
}
private func near(_ a: Point, _ b: Point) -> Bool { abs(a.x - b.x) < 1e-6 && abs(a.y - b.y) < 1e-6 }

@Test func aScaleOnANinetyDegreeLayerStretchesTheAxesUnderThePointer() throws {
    var engine = try rotated(90)
    let box = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    try shapes.commitBox(.scale(handle: 4, to: Point(x: box.maxX + 50, y: box.maxY + 20)), layers: ["shadow"],
                         sceneID: "scene-1", frame: 0, box: box, autoKey: false, in: &engine)
    let after = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    #expect(near(Point(x: after.minX, y: after.minY), Point(x: box.minX, y: box.minY)))
    #expect(near(Point(x: after.maxX, y: after.maxY), Point(x: box.maxX + 50, y: box.maxY + 20)))
}
