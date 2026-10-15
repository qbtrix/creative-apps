// LiveShapesTests.swift: ST-6 of the live-stage packet (docs/blueprints/flare/features/live-stage.md). A Rectangle
// draft is FlareCore's rectangle path for its box and Shift squares it; an Ellipse is four cubics; a pen drag makes a
// smooth anchor whose handles are collinear (G1); a commit is one "Undo Add Rectangle" entry whose layer id and name
// equal the fake's; a commit above a locked layer throws `CommandError.layerLocked` with its id.
import FlareCore
import FlareModel
import Testing

private let live = LiveShapes()
private let scene = LayerOwner.scene("scene-1")
private func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
private func draft(_ tool: FlareTool, _ a: Point, _ b: Point, _ keys: DragModifiers = [],
                   _ previous: ShapeDraft? = nil) -> ShapeDraft? {
    live.draft(tool, from: a, to: b, modifiers: keys, previous: previous)
}

@Test func everyToolIsAvailable() {
    #expect(FlareTool.allCases.allSatisfy { live.unavailableHelp(for: $0) == nil })
}

@Test func aRectangleDraftIsTheBuilderRectangleAndShiftSquaresIt() throws {
    let box = try #require(draft(.rectangle, p(100, 100), p(300, 200)))
    #expect(box.shape.path == (try PathBuilders.rectangle(in: Rect(minX: 100, minY: 100, maxX: 300, maxY: 200))))
    let square = try #require(draft(.rectangle, p(100, 100), p(300, 200), .shift))
    #expect(square.shape.path == (try PathBuilders.rectangle(in: Rect(minX: 100, minY: 100, maxX: 300, maxY: 300))))
    #expect(draft(.rectangle, p(5, 5), p(5, 50)) == nil && draft(.select, p(0, 0), p(9, 9)) == nil)
}

@Test func ellipseIsFourCubics() throws {
    let oval = try #require(draft(.ellipse, p(100, 100), p(300, 200)))
    let path = try #require(oval.shape.path)
    #expect(path == (try PathBuilders.ellipse(in: Rect(minX: 100, minY: 100, maxX: 300, maxY: 200))))
    #expect(path.elements.filter { if case .cubic = $0 { true } else { false } }.count == 4)
    let circle = try #require(draft(.ellipse, p(100, 100), p(110, 130), .shift))
    #expect(circle.shape.path == (try PathBuilders.ellipse(in: Rect(minX: 100, minY: 100, maxX: 130, maxY: 130))))
}

@Test func aPenDragMakesASmoothAnchorWithCollinearHandles() throws {
    let one = try #require(draft(.pen, p(0, 0), p(0, 0)))
    let two = try #require(draft(.pen, p(100, 0), p(130, 40), [], one))
    let three = try #require(draft(.pen, p(200, 100), p(200, 100), [], two))
    #expect(three.anchors == [p(0, 0), p(100, 0), p(200, 100)] && three.smoothAnchors == [1])
    let elements = try #require(three.shape.path).elements
    guard elements.count == 3, case .cubic(_, let handleIn, let a) = elements[1],
          case .cubic(let handleOut, _, let end) = elements[2] else {
        Issue.record("expected move, cubic, cubic: \(elements)"); return
    }
    #expect(a == p(100, 0) && end == p(200, 100) && handleOut == p(130, 40) && handleIn == p(70, -40))
    let (u, v) = ((handleIn.x - a.x, handleIn.y - a.y), (handleOut.x - a.x, handleOut.y - a.y))
    #expect(abs(u.0 * v.1 - u.1 * v.0) <= 1e-9 && u.0 * v.0 + u.1 * v.1 < 0)
}

@Test func aPenPathClosesOnItsFirstPoint() throws {
    var pen = try #require(draft(.pen, p(0, 0), p(-20, 10)))
    for point in [p(100, 0), p(100, 100), p(1, 1)] { pen = try #require(draft(.pen, point, point, [], pen)) }
    #expect(pen.isClosed && pen.anchors.count == 3 && pen.smoothAnchors == [0])
    let elements = try #require(pen.shape.path).elements
    #expect(elements.first == .move(to: p(0, 0)) && elements.last == .close)
    guard case .cubic(let out, _, _) = elements[1], case .cubic(_, let back, let end) = elements[elements.count - 2] else {
        Issue.record("expected cubics round the smooth first anchor: \(elements)"); return
    }
    #expect(out == p(-20, 10) && back == p(20, -10) && end == p(0, 0))
}

@Test func aRectangleCommitIsOneUndoEntryNamedAsTheFakeNamesIt() throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    var fake = engine
    let box = try #require(draft(.rectangle, p(100, 100), p(300, 200)))
    let id = try live.commit(box, owner: scene, aboveLayerID: nil, in: &engine)
    let fakeBox = try #require(FakeShapes().draft(.rectangle, from: p(100, 100), to: p(300, 200), modifiers: [], previous: nil))
    #expect(id == (try FakeShapes().commit(fakeBox, owner: scene, aboveLayerID: nil, in: &fake)))
    let layers = engine.document.layers(of: scene) ?? []
    #expect(id == "rectangle-1" && layers.map(\.name) == ["Rectangle 1"])
    #expect(layers.map(\.name) == (fake.document.layers(of: scene) ?? []).map(\.name))
    #expect(layers.first?.shapes.first?.path == box.shape.path)
    #expect(engine.undoActionName == "Undo Add Rectangle")
    try engine.undo()
    #expect(engine.document == FlareFixtures.empty && !engine.canUndo)
}

@Test func aSecondShapeTakesTheNextNumber() throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    let oval = try #require(draft(.ellipse, p(0, 0), p(50, 50)))
    #expect(try live.commit(oval, owner: scene, aboveLayerID: nil, in: &engine) == "ellipse-1")
    #expect(try live.commit(oval, owner: scene, aboveLayerID: "ellipse-1", in: &engine) == "ellipse-2")
    #expect((engine.document.layers(of: scene) ?? []).map(\.name) == ["Ellipse 1", "Ellipse 2"])
    #expect(engine.undoActionName == "Undo Add Ellipse")
}

@Test func aCommitAboveALockedLayerThrowsLayerLocked() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let box = try #require(draft(.rectangle, p(10, 10), p(60, 60)))
    #expect(throws: CommandError.layerLocked("background")) {
        _ = try live.commit(box, owner: scene, aboveLayerID: "background", in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

/// QB-F3 for each drawing tool: one commit on an empty document is one named entry, and one undo() gives back the
/// empty document with nothing left to undo.
@Test(arguments: [FlareTool.rectangle, .ellipse, .pen])
func oneCommitIsOneNamedEntryThatOneUndoReverts(_ tool: FlareTool) throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    var shape = try #require(draft(tool, p(100, 100), p(300, 200)))
    if tool == .pen {
        for point in [p(300, 100), p(200, 250)] { shape = try #require(draft(.pen, point, point, [], shape)) }
    }
    _ = try live.commit(shape, owner: scene, aboveLayerID: nil, in: &engine)
    #expect((engine.document.layers(of: scene) ?? []).count == 1)
    let name = switch tool { case .rectangle: "Rectangle"; case .ellipse: "Ellipse"; default: "Path" }
    #expect(engine.undoActionName == "Undo Add \(name)")
    try engine.undo()
    #expect(engine.document == FlareFixtures.empty && !engine.canUndo)
}

/// A one-click pen path is refused with the fake's words, which say what to do without using "point" as a distance.
@Test func aOneClickPenPathIsRefusedInPlainWords() throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    let dot = try #require(draft(.pen, p(40, 40), p(40, 40)))
    do {
        _ = try live.commit(dot, owner: scene, aboveLayerID: nil, in: &engine)
        Issue.record("a one-click pen path committed")
    } catch let CommandError.invalidDocument(message) {
        #expect(message == FakeShapes.degeneratePath && !message.contains("a point apart"))
    }
    #expect(engine.document == FlareFixtures.empty && !engine.canUndo)
}
