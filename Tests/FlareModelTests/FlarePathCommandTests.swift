// FlarePathCommandTests.swift (pen-paths FP-1, on in FP-6): the twelve path commands in Flare's catalog, one step each.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlarePathCommandTests {
    static let ids = ["path.anchor-convert", "path.anchor-insert", "path.anchor-move", "path.anchor-remove",
                      "path.anchor-select", "path.cancel", "path.close", "path.draw", "path.finish", "path.handle-move",
                      "path.pen-add", "path.read"]

    @Test(.disabled("waits on FP-6")) func catalogHasTheTwelvePathCommands() throws {
        let pathIDs = FlareWorkspace.catalog.ids.filter { $0.hasPrefix("path.") }
        #expect(pathIDs == Self.ids)
        for id in Self.ids { #expect(FlareWorkspace.catalog.spec(id) != nil, "\(id)") }
    }

    @Test(.disabled("waits on FP-6")) func penAddThenCloseIsOneAddPath() throws {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        workspace.selectTool(.pen)
        for (x, y) in [(0.0, 0.0), (80.0, 0.0), (80.0, 80.0)] { workspace.runPath(.penAdd(Point(x: x, y: y), handleOut: nil)) }
        workspace.runPath(.close)
        #expect(workspace.layers.count == 1 && workspace.undoActionName == "Undo Add Path" && workspace.penDraft == nil)
    }

    @Test(.disabled("waits on FP-6")) func anchorMoveIsOneMovePointsStep() throws {
        var workspace = FlareAnchorEditTests.picked()
        workspace.runPath(.selectAll)
        workspace.runPath(.move(dx: 5, dy: 0, drag: nil))
        #expect(workspace.undoActionName == "Undo Move Points")
    }
}
