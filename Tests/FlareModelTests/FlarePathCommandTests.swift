// FlarePathCommandTests.swift (pen-paths FP-1, on in FP-6): the twelve path commands in Flare's catalog, one step each;
// `path.draw` adds "Path 1" as one "Add Path" and `path.read` reads it back in the same document points.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlarePathCommandTests {
    static let ids = ["path.anchor-convert", "path.anchor-insert", "path.anchor-move", "path.anchor-remove",
                      "path.anchor-select", "path.cancel", "path.close", "path.draw", "path.finish", "path.handle-move",
                      "path.pen-add", "path.read"]

    @Test func pathSpecsRegistered() throws {
        let pathIDs = FlareWorkspace.catalog.ids.filter { $0.hasPrefix("path.") }
        #expect(pathIDs == Self.ids)
        for id in Self.ids { #expect(FlareWorkspace.catalog.spec(id) != nil, "\(id)") }
    }

    @Test func penAddThenCloseIsOneAddPath() throws {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        workspace.selectTool(.pen)
        for (x, y) in [(0.0, 0.0), (80.0, 0.0), (80.0, 80.0)] { workspace.runPath(.penAdd(Point(x: x, y: y), handleOut: nil)) }
        workspace.runPath(.close)
        #expect(workspace.layers.count == 1 && workspace.undoActionName == "Undo Add Path" && workspace.penDraft == nil)
    }

    @Test func anchorMoveIsOneMovePointsStep() throws {
        var workspace = FlareAnchorEditTests.picked()
        workspace.runPath(.selectAll)
        let outcome = try FlareWorkspace.catalog.run("path.anchor-move", params: .object(["dx": .number(5), "dy": .number(0)]), on: &workspace)
        #expect(outcome.undoStep == "Move Points" && workspace.undoActionName == "Undo Move Points")
    }

    /// A closed four-corner contour as `path.draw` and `path.read` write it.
    static let square: JSONValue = .object(["contours": .array([.object(["closed": .bool(true), "anchors": .array(
        [(10.0, 10.0), (50.0, 10.0), (50.0, 40.0), (10.0, 40.0)].map { .object(["x": .number($0.0), "y": .number($0.1), "kind": .string("corner")]) })])])])

    @Test func drawAddsPathOneInOneStep() throws {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        let outcome = try FlareWorkspace.catalog.run("path.draw", params: Self.square, on: &workspace)
        #expect(outcome.undoStep == "Add Path")
        #expect(workspace.layers.map(\.name) == ["Path 1"] && workspace.undoActionName == "Undo Add Path")
        workspace.undo()
        #expect(workspace.layers.isEmpty && !workspace.canUndo, "one undo takes the whole path back")
    }

    @Test func readReadsTheDrawnPathBack() throws {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        _ = try FlareWorkspace.catalog.run("path.draw", params: Self.square, on: &workspace)
        workspace.selectTool(.directSelect)
        workspace.drag(from: Point(x: 30, y: 25), to: Point(x: 30, y: 25))
        let read = try FlareWorkspace.catalog.run("path.read", params: .object([:]), on: &workspace).result
        guard case .object(let fields) = read, case .array(let contours)? = fields["contours"],
              case .object(let contour)? = contours.first, case .array(let anchors)? = contour["anchors"] else {
            Issue.record("path.read gave \(read)"); return
        }
        let points = anchors.compactMap { anchor -> Point? in
            guard case .object(let a) = anchor, case .number(let x)? = a["x"], case .number(let y)? = a["y"] else { return nil }
            return Point(x: x, y: y)
        }
        #expect(contours.count == 1 && contour["closed"] == .bool(true))
        #expect(points == [Point(x: 10, y: 10), Point(x: 50, y: 10), Point(x: 50, y: 40), Point(x: 10, y: 40)])
    }
}
