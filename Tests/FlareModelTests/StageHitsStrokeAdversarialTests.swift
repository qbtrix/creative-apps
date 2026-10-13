// StageHitsStrokeAdversarialTests.swift: adversarial checks on #466's scaled stroke in FakeHits. A mirrored scale,
// a quarter turn with a non-uniform scale, an instance scaled inside a scaled host, a zero scale and odd stroke
// widths. Ball is a radius-30 circle on `bounce`, stroked 10 wide and held at (100, 100).
import FlareCore
import FlareModel
import Testing

private let hits = FlareServices.fake().hits
private let ball = StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0))

/// `bounce` with Ball stroked `width` wide, held at (100, 100), scaled by `sx` × `sy` and turned `degrees`.
private func ballDoc(width: Double = 10, sx: Double = 1, sy: Double = 1, degrees: Double = 0) -> Document {
    var doc = FlareFixtures.bounce
    doc.scenes[0].layers[2].shapes[0].stroke = Stroke(width: width)
    doc.scenes[0].layers[2].tracks = ["x": [Keyframe(frame: 0, value: 100)], "y": [Keyframe(frame: 0, value: 100)],
                                      "scaleX": [Keyframe(frame: 0, value: sx)], "scaleY": [Keyframe(frame: 0, value: sy)],
                                      "rotation": [Keyframe(frame: 0, value: degrees)]]
    return doc
}

private func box(_ doc: Document, _ items: [StageAddress] = [ball]) -> Rect? {
    hits.bounds(doc, sceneID: "scene-1", frame: 0, of: items)
}

/// Whether two boxes agree to within rounding from the trig in a rotation.
private func near(_ a: Rect?, _ b: Rect) -> Bool {
    guard let a else { return false }
    return [a.minX - b.minX, a.minY - b.minY, a.maxX - b.maxX, a.maxY - b.maxY].allSatisfy { abs($0) < 1e-9 }
}

@Test func aMirroredScaleGrowsTheBoxLikeItsMagnitude() {
    #expect(box(ballDoc(sx: -3, sy: 3)) == Rect(minX: -5, minY: -5, maxX: 205, maxY: 205))
    #expect(box(ballDoc(sx: -3, sy: -2)) == Rect(minX: -5, minY: 30, maxX: 205, maxY: 170))
    #expect(hits.hit(ballDoc(sx: -3, sy: 3), sceneID: "scene-1", frame: 0, at: Point(x: -4, y: 100), tolerance: 0) == ball)
}

@Test func aQuarterTurnSendsEachAxisItsOtherScaledHalfStroke() {
    // Scaled 3 × 2 and then turned 90°, the 3× axis runs vertically: y 100 ± 35 × 3, x 100 ± 35 × 2.
    let doc = ballDoc(sx: 3, sy: 2, degrees: 90)
    #expect(near(box(doc), Rect(minX: 30, minY: -5, maxX: 170, maxY: 205)))
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 100, y: 204), tolerance: 0) == ball)
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 171, y: 100), tolerance: 0) == nil)
}

@Test func anInstanceScaledInsideAScaledHostScalesItsStrokeByBoth() {
    var shape = FlareFixtures.bounce.scenes[0].layers[2].shapes[0]
    shape.stroke = Stroke(width: 10)
    var host = Layer(id: "host", name: "Host", instances: [Instance(symbolID: "s", transform: Transform(scaleX: 2, scaleY: 2))])
    host.tracks = ["x": [Keyframe(frame: 0, value: 200)], "y": [Keyframe(frame: 0, value: 200)],
                   "scaleX": [Keyframe(frame: 0, value: 2)], "scaleY": [Keyframe(frame: 0, value: 2)]]
    let doc = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [host])],
                       symbols: [Symbol(id: "s", name: "S", layers: [Layer(id: "in", name: "In", shapes: [shape])])])
    let instance = StageAddress(owner: .scene("scene-1"), layerID: "host", item: .instance(0))
    // 200 ± (30 + 5) × 2 × 2.
    #expect(box(doc, [instance]) == Rect(minX: 60, minY: 60, maxX: 340, maxY: 340))
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 339, y: 200), tolerance: 0) == instance)
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 341, y: 200), tolerance: 0) == nil)
}

@Test func aZeroScaleFlattensTheStrokeOnThatAxis() {
    #expect(box(ballDoc(sx: 0, sy: 2)) == Rect(minX: 100, minY: 30, maxX: 100, maxY: 170))
    #expect(hits.hit(ballDoc(sx: 0, sy: 2), sceneID: "scene-1", frame: 0, at: Point(x: 101, y: 100), tolerance: 0) == nil)
}

@Test func oddStrokeWidthsAddNothingAtAnyScale() {
    let unstroked = Rect(minX: 10, minY: 10, maxX: 190, maxY: 190)
    for width in [0, -10, .nan, .infinity, -.infinity] as [Double] {
        #expect(box(ballDoc(width: width, sx: 3, sy: 3)) == unstroked)
    }
    var none = ballDoc(sx: 3, sy: 3)
    none.scenes[0].layers[2].shapes[0].stroke = nil
    #expect(box(none) == unstroked)
}
