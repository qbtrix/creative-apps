// FlareToolSwitchTests.swift: choosing another tool with an open pen path under way (#1862). Two or more anchors are
// committed as "Path N" in one "Add Path" step, as Finish Path does, so a mouse-only user leaving the Pen keeps the
// work; one anchor is still dropped. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Suite struct FlareToolSwitchTests {
    private func penWorkspace(clicks: [(Double, Double)]) -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        workspace.newDocument()
        workspace.selectTool(.pen)
        for (x, y) in clicks { workspace.drag(from: Point(x: x, y: y), to: Point(x: x, y: y)) }
        return workspace
    }

    @Test func choosingSelectFinishesAnOpenTwoAnchorPath() throws {
        var workspace = penWorkspace(clicks: [(20, 20), (120, 80)])
        workspace.selectTool(.select)
        let layer = try #require(workspace.layers.first)
        #expect(workspace.layers.count == 1 && layer.name == "Path 1")
        #expect(layer.shapes.first?.closed == false)
        #expect(workspace.tool == .select && workspace.draft == nil)
        #expect(workspace.undoActionName == "Undo Add Path")
    }

    @Test func choosingAnotherToolDropsAOneAnchorDraft() {
        var workspace = penWorkspace(clicks: [(20, 20)])
        workspace.selectTool(.rectangle)
        #expect(workspace.layers.isEmpty && !workspace.canUndo)
        #expect(workspace.tool == .rectangle && workspace.draft == nil)
    }
}
