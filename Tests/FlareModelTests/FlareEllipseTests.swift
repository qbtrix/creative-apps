// FlareEllipseTests.swift: the Ellipse tool on FlareWorkspace: the live draft
// by box, the commit as one "Add Ellipse" undo step, and the layer naming.
// Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

/// A new document with the Ellipse tool active.
private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

private func cubicCount(_ shape: FlareShape?) -> Int {
    shape?.path?.elements.filter { if case .cubic = $0 { true } else { false } }.count ?? 0
}

private func expectBounds(_ shape: FlareShape?, _ expected: Rect) {
    let b = shape?.bounds
    #expect(b.map { abs($0.minX - expected.minX) < 1e-6 && abs($0.minY - expected.minY) < 1e-6 } == true)
    #expect(b.map { abs($0.maxX - expected.maxX) < 1e-6 && abs($0.maxY - expected.maxY) < 1e-6 } == true)
}

@Test func ellipseToolIsDisabledUntilTheStageSendsDrags() {
    #expect(!FlareTool.ellipse.isEnabled)
    #expect(FlareTool.ellipse.unavailableHelp?.isEmpty == false)
}

@Test func ellipseDragAddsAnEllipseLayerInOneUndoStep() {
    var workspace = ellipseWorkspace()
    workspace.drag(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    #expect(workspace.layers.map(\.name) == ["Ellipse 1"])
    #expect(workspace.selectedLayerID == "ellipse-1")
    #expect(workspace.layerError == nil)
    #expect(workspace.draft == nil)
    let shape = workspace.layers.first?.shapes.first
    #expect(workspace.layers.first?.shapes.count == 1)
    expectBounds(shape, Rect(minX: 40, minY: 40, maxX: 200, maxY: 160))
    #expect(cubicCount(shape) == 4)
    #expect(workspace.undoActionName == "Undo Add Ellipse")

    workspace.undo()
    #expect(workspace.layers.isEmpty)
    #expect(workspace.selectedLayerID == nil)
    #expect(!workspace.canUndo)
}

@Test func draftFollowsTheBoxInAnyDirection() {
    var workspace = ellipseWorkspace()
    workspace.dragChanged(from: Point(x: 200, y: 160), to: Point(x: 40, y: 40))
    expectBounds(workspace.draft?.shape, Rect(minX: 40, minY: 40, maxX: 200, maxY: 160))
    #expect(cubicCount(workspace.draft?.shape) == 4)
    // The draft is only a preview: the document is untouched.
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
    workspace.selectTool(.select)
    #expect(workspace.draft == nil)
}

@Test func aDragWithNoAreaAddsNothing() {
    var workspace = ellipseWorkspace()
    workspace.dragChanged(from: Point(x: 40, y: 40), to: Point(x: 40, y: 160))
    #expect(workspace.draft == nil)
    workspace.drag(from: Point(x: 40, y: 40), to: Point(x: 40, y: 40))
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
    #expect(FlareWorkspace.ellipse(from: Point(x: 0, y: 0), to: Point(x: .infinity, y: 10)) == nil)
}

@Test func secondEllipseIsNamedEllipseTwoAboveTheSelectedLayer() {
    var workspace = ellipseWorkspace()
    workspace.addLayer()
    workspace.addLayer()
    workspace.selectLayer("layer-1")
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 10, y: 20))
    workspace.selectLayer("layer-1")
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 10, y: 20))
    #expect(workspace.layers.map(\.name) == ["Layer 2", "Ellipse 1", "Ellipse 2", "Layer 1"])
    #expect(workspace.selectedLayerID == "ellipse-2")
    workspace.undo()
    #expect(workspace.layers.map(\.name) == ["Layer 2", "Ellipse 1", "Layer 1"])
}

@Test func ellipseDragWithNoDocumentIsRefused() {
    var workspace = FlareWorkspace()
    workspace.selectTool(.ellipse)
    workspace.drag(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    #expect(workspace.layerError == .noDocument)
    #expect(workspace.document == nil)
}
