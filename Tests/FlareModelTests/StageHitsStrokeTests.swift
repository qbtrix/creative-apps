// StageHitsStrokeTests.swift: FakeHits grows an item's box by its half-stroke before the transform, so a scaled
// item's stroke widens its bounds and hit box by the scaled half-stroke (#466). Ball is a radius-30 circle on `bounce`.
import FlareCore
import FlareModel
import Testing

private let hits = FlareServices.fake().hits
private let ball = StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0))

/// `bounce` with Ball stroked 10 wide, held at (100, 100) and scaled by `sx` × `sy`.
private func strokedBall(sx: Double, sy: Double) -> Document {
    var doc = FlareFixtures.bounce
    doc.scenes[0].layers[2].shapes[0].stroke = Stroke(width: 10)
    doc.scenes[0].layers[2].tracks = ["x": [Keyframe(frame: 0, value: 100)], "y": [Keyframe(frame: 0, value: 100)],
                                      "scaleX": [Keyframe(frame: 0, value: sx)], "scaleY": [Keyframe(frame: 0, value: sy)]]
    return doc
}

@Test func anUnscaledStrokeGrowsTheBoxByHalfItsWidth() {
    let doc = strokedBall(sx: 1, sy: 1)
    #expect(hits.bounds(doc, sceneID: "scene-1", frame: 0, of: [ball]) == Rect(minX: 65, minY: 65, maxX: 135, maxY: 135))
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 135, y: 100), tolerance: 0) == ball)
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 136, y: 100), tolerance: 0) == nil)
}

@Test func aUniformScaleGrowsTheBoxByTheScaledHalfStroke() {
    let doc = strokedBall(sx: 3, sy: 3)
    // The circle spans 10...190; its 10-wide stroke scaled 3× is 30 wide, so 15 reaches past each side.
    #expect(hits.bounds(doc, sceneID: "scene-1", frame: 0, of: [ball]) == Rect(minX: -5, minY: -5, maxX: 205, maxY: 205))
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 204, y: 100), tolerance: 0) == ball)
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 100, y: -4), tolerance: 0) == ball)
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 206, y: 100), tolerance: 0) == nil)
    #expect(hits.marquee(doc, sceneID: "scene-1", frame: 0, rect: Rect(minX: 200, minY: 0, maxX: 210, maxY: 10)) == [ball])
}

@Test func aNonUniformScaleGrowsEachAxisByItsOwnScaledHalfStroke() {
    let doc = strokedBall(sx: 3, sy: 2)
    // x: 100 ± (30 + 5) × 3; y: 100 ± (30 + 5) × 2.
    #expect(hits.bounds(doc, sceneID: "scene-1", frame: 0, of: [ball]) == Rect(minX: -5, minY: 30, maxX: 205, maxY: 170))
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 204, y: 100), tolerance: 0) == ball)
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 100, y: 31), tolerance: 0) == ball)
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 100, y: 28), tolerance: 0) == nil)
}
