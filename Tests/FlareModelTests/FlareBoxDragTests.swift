// FlareBoxDragTests.swift: SE-0 (docs/blueprints/flare/features/stage-edit.md). A Select drag from the selection box's
// handles scales or rotates on `.fake()` and `.built`: the preview performs nothing, mouse-up is one "Undo Scale" or
// "Undo Rotate", and a drag starting 10 pt off every handle moves or marquees as it did before.
import FlareCore
@testable import FlareModel
import Testing

private func services(_ name: String) -> FlareServices { name == "built" ? .built : .fake() }

/// bounce on `name`'s services with Ball selected by a click, and Ball's box.
private func ballSelected(_ name: String) throws -> (FlareWorkspace, Rect) {
    var workspace = FlareWorkspace(services: services(name))
    workspace.load(FlareFixtures.bounce)
    workspace.selectTool(.select)
    workspace.drag(from: Point(x: 80, y: 100), to: Point(x: 80, y: 100))
    try #require(workspace.selectedLayerIDs == ["ball"], "the click didn't select Ball")
    return (workspace, try #require(workspace.selectionBounds))
}

private func ball(_ workspace: FlareWorkspace) -> Transform? {
    workspace.document?.layers(of: .scene("scene-1"))?.first { $0.id == "ball" }?.placement(at: 0).transform
}

private func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) <= tolerance }

private func near(_ m: Matrix, _ n: Matrix) -> Bool {
    [(m.a, n.a), (m.b, n.b), (m.c, n.c), (m.d, n.d), (m.tx, n.tx), (m.ty, n.ty)].allSatisfy { near($0, $1) }
}

@Test func handlesAreNineAtTheCornersEdgeMiddlesAndAboveTheTopEdge() {
    let workspace = FlareWorkspace(services: .fake())
    let handles = workspace.handles(of: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50), rotation: 0)
    #expect(handles.count == 9)
    #expect(handles.map(\.kind) == [.corner(0), .corner(1), .corner(2), .corner(3), .edge(0), .edge(1), .edge(2), .edge(3), .rotate])
    let points = handles.map { [$0.point.x, $0.point.y] }
    #expect(points == [[0, 0], [100, 0], [100, 50], [0, 50], [50, 0], [100, 25], [50, 50], [0, 25], [50, -24]])
    // A quarter turn carries the rotate zone round the centre (50, 25) to the right side.
    let turned = workspace.handles(of: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50), rotation: 90)
    let zone = turned.first { $0.kind == .rotate }?.point
    #expect(zone.map { near($0.x, 99) && near($0.y, 25) } == true)
}

@Test(arguments: ["fake", "built"])
func aBottomRightHandleDragPreviewsScaleThenCommitsOneUndoScale(_ name: String) throws {
    var (workspace, box) = try ballSelected(name)
    let before = workspace.document, grip = Point(x: box.maxX + 2, y: box.maxY - 2)
    let end = Point(x: grip.x + box.width / 2, y: grip.y + box.height / 2)
    workspace.dragChanged(from: grip, to: end)
    // The preview draws, and nothing is performed until mouse-up.
    let preview = try #require(workspace.dragPreview, "no scale preview")
    #expect(workspace.document == before && !workspace.canUndo && workspace.marquee == nil)
    workspace.endDrag()
    #expect(workspace.undoActionName == "Undo Scale" && workspace.selectedLayerIDs == ["ball"])
    let scaled = try #require(workspace.selectionBounds)
    #expect(near(scaled.minX, box.minX) && near(scaled.minY, box.minY), "the top-left corner moved")
    #expect(near(scaled.width, box.width * 1.5) && near(scaled.height, box.height * 1.5))
    let drawn = try #require(workspace.stageList).items.filter { $0.address.layerID == "ball" }
    let shown = preview.items.filter { $0.address.layerID == "ball" }
    #expect(!drawn.isEmpty && drawn.count == shown.count && zip(drawn, shown).allSatisfy { near($0.transform, $1.transform) })
    workspace.undo()
    #expect(workspace.document == before && !workspace.canUndo, "the scale was more than one step")
}

@Test(arguments: ["fake", "built"])
func aQuarterTurnOnTheRotateZoneIsOneUndoRotateAboutTheBoxCentre(_ name: String) throws {
    var (workspace, box) = try ballSelected(name)
    let before = workspace.document, was = try #require(ball(workspace))
    let zone = try #require(workspace.handles(of: box, rotation: 0).first { $0.kind == .rotate }).point
    let centre = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2), arm = centre.y - zone.y
    workspace.dragChanged(from: zone, to: Point(x: centre.x + arm, y: centre.y))
    #expect(workspace.dragPreview != nil && workspace.document == before && !workspace.canUndo)
    workspace.endDrag()
    #expect(workspace.undoActionName == "Undo Rotate")
    let turned = try #require(ball(workspace))
    #expect(near(turned.rotation, was.rotation + 90))
    // Ball's origin turned a quarter clockwise about the box centre.
    #expect(near(turned.x, centre.x - (was.y - centre.y)) && near(turned.y, centre.y + (was.x - centre.x)))
    workspace.undo()
    #expect(workspace.document == before && !workspace.canUndo, "the rotate was more than one step")
}

@Test(arguments: ["fake", "built"])
func aDragStartingTenPointsOffEveryHandleMovesOrMarqueesAsBefore(_ name: String) throws {
    let (selected, box) = try ballSelected(name)
    let offsets = [Point(x: -10, y: 0), Point(x: 10, y: 0), Point(x: 0, y: -10), Point(x: 0, y: 10)]
    for handle in selected.handles(of: box, rotation: 0) {
        for offset in offsets {
            var workspace = selected
            let start = Point(x: handle.point.x + offset.x, y: handle.point.y + offset.y)
            let onBall = workspace.hit(at: start, stageScale: 1)?.layerID == "ball", was = try #require(ball(workspace))
            workspace.drag(from: start, to: Point(x: start.x + 20, y: start.y + 15))
            let at = "\(handle.kind) \(offset.x), \(offset.y)"
            if onBall {
                let moved = try #require(ball(workspace))
                #expect(workspace.undoActionName == "Undo Move" && moved.x == was.x + 20 && moved.y == was.y + 15, "\(at)")
                #expect(moved.scaleX == was.scaleX && moved.rotation == was.rotation, "\(at)")
            } else {
                #expect(workspace.document == selected.document && !workspace.canUndo, "\(at) changed the document")
            }
        }
    }
}
