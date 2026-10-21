// FlareAnchorEditTests.swift (pen-paths FP-1): Direct Select's PathEditTarget. The reads (`pathInEdit`, its help, the
// anchor selection clearing on a new item selection) run now; the edits wait on FP-7. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareAnchorEditTests {
    /// A 40 by 30 rectangle at (10, 10), picked with Direct Select.
    static func picked() -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        workspace.selectTool(.rectangle)
        workspace.drag(from: Point(x: 10, y: 10), to: Point(x: 50, y: 40))
        workspace.selectTool(.directSelect)
        workspace.drag(from: Point(x: 30, y: 25), to: Point(x: 30, y: 25))
        return workspace
    }

    @Test func pathInEditIsTheOneDirectSelectedShape() throws {
        var workspace = Self.picked()
        let edit = try #require(workspace.pathInEdit)
        // Today's rectangle path draws its closing edge as a line back to the start, a fifth anchor on the first.
        #expect(edit.path.contours.first?.anchors.count == 5 && workspace.pathHelp == nil, "\(edit.path.elements)")
        workspace.selectTool(.select)
        #expect(workspace.pathInEdit == nil)
        #expect(workspace.pathHelp == "Select one shape with Direct Select to edit its points.")
    }

    @Test func anchorSelectionClearsWhenTheItemSelectionChanges() {
        var workspace = Self.picked()
        workspace.anchorSelection = Selection([AnchorRef(contour: 0, index: 1)])
        workspace.drag(from: Point(x: 30, y: 25), to: Point(x: 30, y: 25))
        #expect(workspace.anchorSelection.ordered == [AnchorRef(contour: 0, index: 1)])
        workspace.drag(from: Point(x: 300, y: 300), to: Point(x: 300, y: 300))
        #expect(workspace.anchorSelection.ordered.isEmpty && workspace.selection.isEmpty && workspace.pathInEdit == nil)
    }

    @Test(.disabled("waits on FP-7")) func onlyPickedAnchorsMove() throws {
        var workspace = Self.picked()
        let before = try #require(workspace.pathInEdit?.path.contours.first?.anchors)
        workspace.runPath(.select(anchors: [AnchorRef(contour: 0, index: 1)], rect: nil, extend: false))
        workspace.runPath(.move(dx: 30, dy: 0, drag: nil))
        let after = try #require(workspace.pathInEdit?.path.contours.first?.anchors)
        #expect(after.count == before.count && workspace.undoActionName == "Undo Edit Path")
        for (index, (old, new)) in zip(before, after).enumerated() {
            let moved = index == 1 ? Point(x: old.point.x + 30, y: old.point.y) : old.point
            #expect(new.point == moved, "anchor \(index)")
        }
    }
}
