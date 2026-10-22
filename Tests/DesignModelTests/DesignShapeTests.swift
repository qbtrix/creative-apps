// DesignShapeTests.swift (shape-tools DS-5): the Shape tool draws one node of kind `shape` carrying the
// tool's spec as one undo step "Draw <Kind>"; every drawing tool takes its box from the kernel's
// `ShapeRules.dragged` (Shift squares, Option grows from the centre); a line keeps the ends it was dragged
// along; the spec survives a save and reopen; and a shape node's path is the kernel's. The drags sit away
// from the Desktop frame's snap lines. Runs on Linux and macOS.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignShapeTests {
    @Test func drawIsOneStep() {
        var workspace = openDesign()
        workspace.selectTool(.shape)
        for step in 1...5 { workspace.drag(from: pt(300, 300), to: pt(300 + Double(step) * 20, 300 + Double(step) * 20)) }
        workspace.endDrag()
        #expect(workspace.treeNode("node-2")?.kind == .shape)
        #expect(workspace.treeNode("node-2")?.shape == .defaults(.star))
        #expect(workspace.frame("node-2") == rc(300, 300, 100, 100))
        #expect(workspace.treeNode("node-3") == nil, "one gesture draws one node")
        #expect(workspace.selectedNodeID == "node-2" && workspace.tool == .move)
        #expect(workspace.undoActionName == "Undo Draw Star")
        workspace.undo()
        #expect(workspace.treeNode("node-2") == nil && !workspace.canUndo, "one undo takes the whole draw back")
        workspace.redo()
        #expect(workspace.treeNode("node-2")?.shape == .defaults(.star))
    }

    @Test func specSaved() throws {
        var workspace = openDesign()
        workspace.runShape(.points(7))
        workspace.runShape(.innerRatio(0.3))
        workspace.gesture(.shape, pt(300, 300), pt(380, 360))
        let spec = workspace.shapeTool
        #expect(workspace.treeNode("node-2")?.shape == spec)
        var reopened = DesignWorkspace()
        try reopened.open(try workspace.fileData())
        #expect(reopened.treeNode("node-2")?.kind == .shape)
        #expect(reopened.treeNode("node-2")?.shape == spec && spec.points == 7 && spec.innerRatio == 0.3)
    }

    @Test(arguments: [(DesignTool.rectangle, DesignNodeKind.rectangle, ShapeKind.rectangle),
                      (.ellipse, .ellipse, .ellipse), (.shape, .shape, .star)])
    func shiftSquares(_ tool: DesignTool, _ kind: DesignNodeKind, _ shape: ShapeKind) {
        var workspace = openDesign()
        workspace.gesture(tool, pt(300, 300), pt(340, 320), .shift)
        let rule = ShapeRules.dragged(shape, from: Point(x: 300, y: 300), to: Point(x: 340, y: 320), modifiers: .shift)
        #expect(workspace.treeNode("node-2")?.kind == kind)
        #expect(workspace.frame("node-2") == rc(300, 300, 40, 40))
        #expect(workspace.frame("node-2") == rule.map { DesignRect($0.box) })
    }

    @Test(arguments: [DesignTool.frame, .rectangle, .ellipse, .shape])
    func optionDrawsFromTheCentre(_ tool: DesignTool) {
        var workspace = openDesign()
        workspace.gesture(tool, pt(300, 300), pt(340, 320), .option)
        #expect(workspace.frame("node-2") == rc(260, 280, 80, 40))
    }

    @Test func aLineKeepsTheEndsItWasDraggedAlong() {
        var workspace = openDesign()
        workspace.runShape(.kind(.line))
        workspace.gesture(.shape, pt(400, 350), pt(300, 300))
        #expect(workspace.frame("node-2") == rc(300, 300, 100, 50))
        #expect(workspace.treeNode("node-2")?.shape?.start == Point(x: 1, y: 1))
        #expect(workspace.treeNode("node-2")?.shape?.end == Point(x: 0, y: 0))
        #expect(workspace.undoActionName == "Undo Draw Line")
    }

    @Test func theCommandAddsOneSelectedShapeAndItsPathIsTheKernels() throws {
        var workspace = openDesign()
        let spec = ShapeIntent.sides(6).applied(to: .defaults(.polygon))
        let id = try workspace.addShape(spec, in: Rect(minX: 300, minY: 300, maxX: 400, maxY: 380), name: "Draw Polygon")
        let node = try #require(workspace.treeNode(id))
        #expect(node.kind == .shape && node.shape == spec && workspace.selectedNodeID == id)
        #expect(workspace.undoActionName == "Undo Draw Polygon")
        #expect(node.path(in: node.frame) == (try ShapeRules.path(spec, in: node.frame.kernelRect)))
        #expect(workspace.treeNode("node-1")?.path(in: rc(0, 0, 10, 10)) == nil, "a frame has no shape path")
        #expect(throws: ShapeRefusal.self) {
            try workspace.addShape(ShapeIntent.sides(2).applied(to: .defaults(.polygon)), in: Rect(minX: 0, minY: 0, maxX: 9, maxY: 9), name: "x")
        }
    }

    @Test func theShapeToolWorksOnlyWithADesignOpen() {
        #expect(DesignTool.shape.isEnabled && DesignTool.shape.nodeKind == .shape)
        #expect(openDesign().shapeHelp == nil)
        #expect(DesignWorkspace().shapeHelp?.isEmpty == false)
    }
}
