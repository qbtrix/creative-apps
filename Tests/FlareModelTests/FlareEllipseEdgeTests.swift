// FlareEllipseEdgeTests.swift: edge cases for the Ellipse tool on
// FlareWorkspace: the shape stays finite and inscribed in its box, the
// draft and the commit agree, undo and redo round-trip, and naming counts
// up from the names in use. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

private func allPoints(_ shape: FlareShape) -> [Point] {
    shape.points + (shape.path?.elements ?? []).flatMap { element -> [Point] in
        switch element {
        case .move(let p): [p]
        case .cubic(let c1, let c2, let p): [c1, c2, p]
        default: []
        }
    }
}

@Test(arguments: [
    (Point(x: 0, y: 0), Point(x: 1, y: 1)),
    (Point(x: -500, y: 300), Point(x: 500, y: -300)),
    (Point(x: 0.25, y: 0.25), Point(x: 1.25, y: 1e6)),
    (Point(x: 1e12, y: -1e12), Point(x: -1e12, y: 1e12)),
])
func ellipseIsInscribedInItsBoxAndClosed(start: Point, end: Point) throws {
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end))
    let box = Rect(
        minX: min(start.x, end.x), minY: min(start.y, end.y),
        maxX: max(start.x, end.x), maxY: max(start.y, end.y))
    let b = try #require(shape.bounds)
    let tolerance = 1e-9 * max(1, box.maxX - box.minX, box.maxY - box.minY)
    #expect(abs(b.minX - box.minX) <= tolerance && abs(b.maxX - box.maxX) <= tolerance)
    #expect(abs(b.minY - box.minY) <= tolerance && abs(b.maxY - box.maxY) <= tolerance)
    #expect(allPoints(shape).allSatisfy { $0.x.isFinite && $0.y.isFinite })
    let elements = shape.path?.elements ?? []
    #expect(elements.first.map { if case .move = $0 { true } else { false } } == true)
    #expect(elements.last.map { if case .close = $0 { true } else { false } } == true)
    #expect(elements.count == 6)
}

@Test func ellipseIsTheSameWhicheverCornerTheDragStartsFrom() {
    let a = Point(x: 40, y: 40), b = Point(x: 200, y: 160)
    let corners = [(a, b), (b, a), (Point(x: 40, y: 160), Point(x: 200, y: 40)), (Point(x: 200, y: 40), Point(x: 40, y: 160))]
    let shapes = corners.map { FlareWorkspace.ellipse(from: $0.0, to: $0.1) }
    #expect(shapes.allSatisfy { $0 != nil && $0 == shapes.first ?? nil })
}

@Test(arguments: [Double.nan, -Double.infinity, Double.infinity])
func ellipseRefusesNonFiniteCoordinates(bad: Double) {
    #expect(FlareWorkspace.ellipse(from: Point(x: bad, y: 0), to: Point(x: 10, y: 10)) == nil)
    #expect(FlareWorkspace.ellipse(from: Point(x: 0, y: 0), to: Point(x: 10, y: bad)) == nil)
    var workspace = ellipseWorkspace()
    workspace.dragChanged(from: Point(x: 0, y: bad), to: Point(x: 10, y: 10))
    #expect(workspace.draft == nil)
    workspace.drag(from: Point(x: 0, y: bad), to: Point(x: 10, y: 10))
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func committedShapeIsTheLastDraft() {
    var workspace = ellipseWorkspace()
    let start = Point(x: 12.5, y: -7), end = Point(x: -80, y: 33.25)
    workspace.dragChanged(from: start, to: Point(x: 0, y: 0))
    workspace.dragChanged(from: start, to: end)
    let draft = workspace.draft
    workspace.drag(from: start, to: end)
    #expect(draft != nil)
    #expect(workspace.layers.first?.shapes.first == draft)
    #expect(workspace.draft == nil)
}

@Test func aDraftShrunkToNoAreaClearsThePreview() {
    var workspace = ellipseWorkspace()
    workspace.dragChanged(from: Point(x: 10, y: 10), to: Point(x: 50, y: 50))
    #expect(workspace.draft != nil)
    workspace.dragChanged(from: Point(x: 10, y: 10), to: Point(x: 10, y: 50))
    #expect(workspace.draft == nil)
}

@Test(arguments: [FlareTool.select, .pen, .rectangle])
func otherToolsMakeNoEllipseDraftOrLayer(tool: FlareTool) {
    var workspace = ellipseWorkspace()
    workspace.selectTool(tool)
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.draft == nil)
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.layers.allSatisfy { !$0.name.hasPrefix("Ellipse") })
}

@Test func undoThenRedoRestoresTheEllipseLayer() {
    var workspace = ellipseWorkspace()
    workspace.drag(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    let after = workspace.document
    workspace.undo()
    #expect(workspace.layers.isEmpty)
    #expect(workspace.redoActionName == "Redo Add Ellipse")
    workspace.redo()
    #expect(workspace.document == after)
    #expect(workspace.layerError == nil)
}

@Test func manyEllipsesTakeIncreasingNamesAndUndoOneAtATime() {
    var workspace = ellipseWorkspace()
    for i in 0..<5 {
        let d = Double(i)
        workspace.drag(from: Point(x: d, y: d), to: Point(x: d + 10, y: d + 20))
    }
    #expect(Set(workspace.layers.map(\.name)) == Set((1...5).map { "Ellipse \($0)" }))
    #expect(Set(workspace.layers.map(\.id)).count == 5)
    #expect(workspace.selectedLayerID == "ellipse-5")
    for remaining in (0..<5).reversed() {
        workspace.undo()
        #expect(workspace.layers.count == remaining)
    }
    #expect(!workspace.canUndo)
}

@Test func undoFreesTheEllipseNameForTheNextDrag() {
    var workspace = ellipseWorkspace()
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 10, y: 10))
    workspace.undo()
    // After undo the name is free again, so the next ellipse reuses it.
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 10, y: 10))
    #expect(workspace.layers.map(\.name) == ["Ellipse 1"])
}

@Test func ellipseOnTopWhenNothingIsSelected() {
    var workspace = ellipseWorkspace()
    workspace.addLayer()
    workspace.addLayer()
    workspace.selectItem("scene-1")
    #expect(workspace.selectedLayerID == nil)
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 10, y: 10))
    #expect(workspace.layers.first?.name == "Ellipse 1")
    #expect(workspace.layers.count == 3)
}

@Test func aFailedDragKeepsAnEarlierErrorUntilASuccessClearsIt() {
    var workspace = FlareWorkspace()
    workspace.selectTool(.ellipse)
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 10, y: 10))
    #expect(workspace.layerError == .noDocument)
    workspace.newDocument()
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 10, y: 10))
    #expect(workspace.layerError == nil)
    #expect(workspace.layers.count == 1)
}

@Test func newDocumentDropsARunningDraft() {
    var workspace = ellipseWorkspace()
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 10, y: 10))
    workspace.newDocument()
    #expect(workspace.draft == nil)
}
