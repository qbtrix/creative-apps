// FlareEllipseMinimumAdversarialTests.swift: edge cases around the Ellipse
// tool's minimum box: non-finite and extreme pointers, a sub-minimum drag
// after a valid draft, other tools, and repeated jittery clicks. Runs on
// Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

private let m = FlareWorkspace.minimumEllipseExtent

@Test func theMinimumIsAPositiveFiniteExtent() {
    #expect(m.isFinite)
    #expect(m >= 1)
}

@Test(arguments: [
    (Point(x: .nan, y: 0), Point(x: 50, y: 50)),
    (Point(x: 0, y: 0), Point(x: .infinity, y: 50)),
    (Point(x: 0, y: 0), Point(x: 50, y: -.infinity)),
    (Point(x: -1e308, y: 0), Point(x: 1e308, y: 50)),
    (Point(x: 0, y: 0), Point(x: .leastNonzeroMagnitude, y: .leastNonzeroMagnitude)),
    (Point(x: 0, y: 0), Point(x: -0.0, y: 50)),
])
func aNonFiniteOrDegenerateBoxCommitsNothing(start: Point, end: Point) {
    var workspace = ellipseWorkspace()
    let before = workspace.document
    #expect(FlareWorkspace.ellipse(from: start, to: end) == nil)
    workspace.dragChanged(from: start, to: end)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end)
    #expect(workspace.document == before)
    #expect(!workspace.canUndo)
}

@Test func shrinkingADraftBelowTheMinimumClearsIt() {
    var workspace = ellipseWorkspace()
    let start = Point(x: 40, y: 40)
    workspace.dragChanged(from: start, to: Point(x: 90, y: 90))
    #expect(workspace.draft != nil)
    workspace.dragChanged(from: start, to: Point(x: 40.4, y: 40.4))
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: Point(x: 40.4, y: 40.4))
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func manyJitteryClicksAddNothing() {
    var workspace = ellipseWorkspace()
    let jitters = [0.0, 0.1, -0.3, 0.49, -0.5, m * 0.999]
    for (i, dx) in jitters.enumerated() {
        for dy in jitters.reversed() {
            let start = Point(x: 100 + Double(i), y: 200)
            workspace.drag(from: start, to: Point(x: start.x + dx, y: start.y + dy))
        }
    }
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func aJitteryClickBetweenTwoEllipsesKeepsTheNumbering() {
    var workspace = ellipseWorkspace()
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 20, y: 20))
    workspace.drag(from: Point(x: 50, y: 50), to: Point(x: 50.2, y: 50.3))
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: -m, y: -m))
    #expect(workspace.layers.map(\.name).sorted() == ["Ellipse 1", "Ellipse 2"])
    workspace.undo()
    workspace.undo()
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test(arguments: [FlareTool.select, .pen, .rectangle])
func otherToolsLeaveNoDraftForAnyBox(tool: FlareTool) {
    var workspace = ellipseWorkspace()
    workspace.selectTool(tool)
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 80, y: 80))
    #expect(workspace.shapeDraft?.tool != .ellipse)
}

@Test func aBoxJustOverTheMinimumIsInscribedAndFinite() throws {
    let start = Point(x: 3, y: 7), end = Point(x: 3 + m * 1.01, y: 7 + m * 1.01)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end))
    for p in shape.points {
        #expect(p.x.isFinite && p.y.isFinite)
        #expect(p.x >= start.x - 1e-9 && p.x <= end.x + 1e-9)
        #expect(p.y >= start.y - 1e-9 && p.y <= end.y + 1e-9)
    }
}
