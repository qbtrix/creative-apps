// DirectSelectMoveSpaceTests.swift: a Direct Select move on a scaled or rotated layer lands where the preview drew
// the item (#554). The drag is in scene points; the item's geometry is in layer space.
import FlareCore
@testable import FlareModel
import Testing

private func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

/// The bounce fixture with Ball's scale and rotation held at the given values.
private func bounce(scale: Double?, rotation: Double?) -> Document {
    var doc = FlareFixtures.bounce
    for (s, scene) in doc.scenes.enumerated() {
        for (l, layer) in scene.layers.enumerated() where layer.id == "ball" {
            for key in ["scaleX", "scaleY"] where scale != nil { doc.scenes[s].layers[l].tracks[key] = [Keyframe(frame: 0, value: scale ?? 1)] }
            if let rotation { doc.scenes[s].layers[l].tracks["rotation"] = [Keyframe(frame: 0, value: rotation)] }
        }
    }
    return doc
}

private func ball(_ w: FlareWorkspace) -> Layer? { w.document?.scenes.first?.layers.first { $0.id == "ball" } }

/// Ball's first point in scene space at the playhead.
private func scenePoint(_ w: FlareWorkspace) -> Point? {
    guard let layer = ball(w), let point = layer.shapes.first?.points.first else { return nil }
    return layer.placement(at: Double(w.currentFrame)).transform.matrix.apply(point)
}

/// Drags Ball by (10, 10) from its origin; returns the preview's and the commit's scene position of its first point.
private func move(_ document: Document, frame: Int) -> (start: Point?, preview: Point?, landed: Point?, undo: String?) {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.currentFrame = frame
    w.selectTool(.directSelect)
    guard let layer = ball(w), let local = layer.shapes.first?.points.first else { return (nil, nil, nil, nil) }
    let origin = layer.placement(at: Double(frame)).transform, start = scenePoint(w)
    w.dragChanged(from: p(origin.x, origin.y), to: p(origin.x + 10, origin.y + 10))
    let preview = w.dragPreview?.items.first { $0.address.layerID == "ball" }.map { $0.transform.apply(local) }
    w.endDrag()
    return (start, preview, scenePoint(w), w.undoActionName)
}

private func near(_ a: Point?, _ b: Point?) -> Bool {
    guard let a, let b else { return false }
    return abs(a.x - b.x) <= 1e-9 && abs(a.y - b.y) <= 1e-9
}

@Test(arguments: [(2.0, nil), (nil, 30.0), (2.0, 30.0)] as [(Double?, Double?)])
func aDirectSelectMoveOnATransformedLayerLandsUnderThePreview(scale: Double?, rotation: Double?) {
    let r = move(bounce(scale: scale, rotation: rotation), frame: 0)
    #expect(near(r.landed, r.preview))
    #expect(near(r.landed, r.start.map { p($0.x + 10, $0.y + 10) }))
    #expect(r.undo == "Undo Move")
}

@Test func theSquashedBounceRepro() {
    // #554's repro: Ball at frame 12 is squashed (scaleX 1.25, scaleY 0.75); the scene move is (10, 10).
    let r = move(FlareFixtures.bounce, frame: 12)
    #expect(near(r.landed, r.start.map { p($0.x + 10, $0.y + 10) }) && near(r.landed, r.preview))
}

@Test func aDirectSelectMoveStaysWithinTheEditBudget() {
    // QB-L7's debug bound for a step through the engine (≤ 10 ms), the space conversion included.
    var w = FlareWorkspace(services: .fake())
    w.load(bounce(scale: 2, rotation: 30))
    w.selectTool(.directSelect)
    guard let origin = ball(w)?.placement(at: 0).transform else { return #expect(Bool(false)) }
    let clock = ContinuousClock()
    let cost = clock.measure {
        for i in 0..<100 {
            let d = Double(i % 2 == 0 ? 1 : -1)
            w.drag(from: p(origin.x, origin.y), to: p(origin.x + d, origin.y + d))
        }
    }
    #expect(cost / 100 < .milliseconds(10))
}
