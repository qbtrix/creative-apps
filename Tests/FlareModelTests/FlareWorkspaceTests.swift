// FlareWorkspaceTests.swift: behavior of FlareWorkspace, the state behind
// Flare's window. Runs on Linux and macOS.
import FlareModel
import Testing

@Test func startsWithNoDocument() {
    let workspace = FlareWorkspace()
    #expect(workspace.document == nil)
    #expect(workspace.selectedScene == nil)
    #expect(workspace.tool == .select)
}

@Test func newDocumentSelectsItsOnlyScene() {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    #expect(workspace.scenes.map(\.name) == ["Scene 1"])
    #expect(workspace.selectedScene?.id == "scene-1")
    #expect(workspace.selectedScene?.width == 550)
}

@Test func selectingAnUnknownSceneKeepsTheSelection() {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectScene("nope")
    #expect(workspace.selectedSceneID == "scene-1")
}

@Test func selectToolChangesTheActiveTool() {
    var workspace = FlareWorkspace()
    workspace.selectTool(.pen)
    #expect(workspace.tool == .pen)
}
