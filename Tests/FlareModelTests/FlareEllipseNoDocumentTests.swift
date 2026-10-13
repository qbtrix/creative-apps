// FlareEllipseNoDocumentTests.swift: with no document open the Ellipse tool
// previews nothing, matching the drag's refusal to commit (#471). Runs on
// Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Test func ellipseDraftIsNilWithNoDocument() {
    var workspace = FlareWorkspace()
    workspace.selectTool(.ellipse)
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.draft == nil)

    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.draft == nil)
    #expect(workspace.layerError == .noDocument)
    #expect(workspace.layers.isEmpty)
}

@Test func ellipseDraftAppearsOnceADocumentIsOpen() {
    var workspace = FlareWorkspace()
    workspace.selectTool(.ellipse)
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.draft == nil)

    workspace.newDocument()
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.draft != nil)
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.draft == nil)
    #expect(workspace.layers.map(\.name) == ["Ellipse 1"])
}
