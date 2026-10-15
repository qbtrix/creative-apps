// LiveShapesBoxTests.swift: ST-8 of live-stage (#740), the live box gestures. A scale keeps the handle opposite the
// grip, a rotate keeps the box center, each `commitBox` is one named entry that one undo() reverts (QB-F3), and the
// box and the layer transforms after each gesture equal `FakeShapes` on `bounce`.
import FlareCore
import FlareModel
import Testing

private let scene = "scene-1"

/// The world box of `layers` on the live stage: each drawn item's path box, its corners through the item's matrix.
private func box(_ document: Document, layers: [String], frame: Int = 0) -> Rect? {
    let list = LiveStage().drawList(document, sceneID: scene, frame: frame, editing: nil)
    var points: [Point] = []
    for item in list.items where layers.contains(item.address.layerID) {
        guard let r = item.path.bounds else { continue }
        points += [Point(x: r.minX, y: r.minY), Point(x: r.maxX, y: r.minY), Point(x: r.maxX, y: r.maxY),
                   Point(x: r.minX, y: r.maxY)].map(item.transform.apply)
    }
    return Rect(enclosing: points)
}

private func near(_ a: Point, _ b: Point) -> Bool { abs(a.x - b.x) <= 1e-9 && abs(a.y - b.y) <= 1e-9 }

/// Every handle dragged by (50, 20), a move and a 15° rotate, on `box`.
private func gestures(on box: Rect) -> [BoxGesture] {
    (0..<8).map { i in
        let grip = BoxGestureMath.handle(i, on: box)
        return .scale(handle: i, to: Point(x: grip.x + 50, y: grip.y + 20))
    } + [.move(dx: 12, dy: -7), .rotate(degrees: 15)]
}

@Test(arguments: 0..<8)
func liveScaleKeepsTheOppositeHandle(_ handle: Int) throws {
    let picked = ["shadow", "ball"]
    let before = try #require(box(FlareFixtures.bounce, layers: picked))
    let grip = BoxGestureMath.handle(handle, on: before)
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try LiveShapes().commitBox(.scale(handle: handle, to: Point(x: grip.x + 50, y: grip.y + 20)), layers: picked,
                               sceneID: scene, frame: 0, box: before, autoKey: false, in: &engine)
    let after = try #require(box(engine.document, layers: picked))
    #expect(near(BoxGestureMath.handle(handle + 4, on: after), BoxGestureMath.handle(handle + 4, on: before)))
}

@Test func liveRotateKeepsTheBoxCenter() throws {
    let before = try #require(box(FlareFixtures.bounce, layers: ["shadow"]))
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try LiveShapes().commitBox(.rotate(degrees: 30), layers: ["shadow"], sceneID: scene, frame: 0, box: before,
                               autoKey: false, in: &engine)
    let after = try #require(box(engine.document, layers: ["shadow"]))
    let center = { (r: Rect) in Point(x: (r.minX + r.maxX) / 2, y: (r.minY + r.maxY) / 2) }
    #expect(near(center(after), center(before)))
    #expect(engine.document.scenes.first?.layers.first { $0.id == "shadow" }?.sample(at: 0)["rotation"] == 30)
}

@Test(arguments: [(0, false), (5, false), (5, true)])
func liveBoxGesturesAreOneStepAndEqualTheFake(_ frame: Int, _ autoKey: Bool) throws {
    let picked = ["shadow", "ball"]
    let start = try #require(box(FlareFixtures.bounce, layers: picked, frame: frame))
    for gesture in gestures(on: start) {
        let name = switch gesture { case .move: "Move"; case .scale: "Scale"; case .rotate: "Rotate" }
        let live = LiveShapes().boxResult(gesture, layers: picked, document: FlareFixtures.bounce, sceneID: scene,
                                          frame: frame, box: start)
        let fake = FakeShapes().boxResult(gesture, layers: picked, document: FlareFixtures.bounce, sceneID: scene,
                                          frame: frame, box: start)
        #expect(live == fake, "\(gesture)")
        #expect(Set(live.keys) == Set(picked), "\(gesture)")

        var liveEngine = CommandEngine(document: FlareFixtures.bounce)
        var fakeEngine = CommandEngine(document: FlareFixtures.bounce)
        try LiveShapes().commitBox(gesture, layers: picked, sceneID: scene, frame: frame, box: start,
                                   autoKey: autoKey, in: &liveEngine)
        try FakeShapes().commitBox(gesture, layers: picked, sceneID: scene, frame: frame, box: start,
                                   autoKey: autoKey, in: &fakeEngine)
        #expect(liveEngine.document == fakeEngine.document, "\(gesture)")
        #expect(box(liveEngine.document, layers: picked, frame: frame) == box(fakeEngine.document, layers: picked, frame: frame))
        #expect(liveEngine.document != FlareFixtures.bounce, "\(gesture)")

        // QB-F3: one named entry, and one undo() restores the document and leaves canUndo as before.
        #expect(liveEngine.undoActionName == "Undo \(name)")
        try liveEngine.undo()
        #expect(liveEngine.document == FlareFixtures.bounce, "\(gesture)")
        #expect(!liveEngine.canUndo, "\(gesture)")
    }
}

@Test func liveCommitBoxOnALockedLayerChangesNothing() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let start = try #require(box(FlareFixtures.bounce, layers: ["ball", "background"]))
    #expect(throws: CommandError.self) {
        try LiveShapes().commitBox(.move(dx: 5, dy: 5), layers: ["ball", "background"], sceneID: scene, frame: 0,
                                   box: start, autoKey: false, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}
