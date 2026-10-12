// PhotoWorkspaceTests.swift: behavior of PhotoWorkspace, the state behind
// Photo's window. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Test func newCanvasIsWhiteWithABackgroundLayer() throws {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 4, height: 3)
    #expect(workspace.canvas?.width == 4)
    #expect(workspace.canvas?.height == 3)
    #expect(try workspace.canvas?.pixel(x: 3, y: 2) == RGBA(r: 1, g: 1, b: 1, a: 1))
    #expect(workspace.layerNames == ["Background"])
    #expect(workspace.selectedLayer == "Background")
}

@Test func invalidSizeThrowsAndLeavesTheWorkspaceEmpty() {
    var workspace = PhotoWorkspace()
    #expect(throws: RasterError.self) { try workspace.newCanvas(width: 0, height: 10) }
    #expect(workspace.canvas == nil)
    #expect(workspace.layerNames.isEmpty)
}

@Test func layerAndToolSelection() throws {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 1, height: 1)
    workspace.selectLayer("Missing")
    workspace.selectTool(.brush)
    #expect(workspace.selectedLayer == "Background")
    #expect(workspace.tool == .brush)
}
