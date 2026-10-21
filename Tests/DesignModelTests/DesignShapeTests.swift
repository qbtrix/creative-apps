// DesignShapeTests.swift (shape-tools DS-1, MJ-DS): the Shape tool and shape nodes on DesignWorkspace's
// ShapeTarget stubs. Old files still open with no spec, a node's spec is written only when set, and the tool's
// options are view state. Drawing (`addShape`, a drag) and a node's path wait on DS-5, so those tests are
// disabled until it lands. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import SuiteKernel
import Testing

struct DesignShapeTests {
    static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)

    @Test func aFileWithoutShapesStillOpensWithNoSpec() throws {
        let old = #"""
            {"pages":[{"frameHeight":100,"frameWidth":100,"id":"page-1","name":"Page 1","nodes":[
            {"children":[],"fill":{"blue":0,"green":0,"red":0},"frame":{"height":10,"width":10,"x":0,"y":0},
            "id":"node-1","isHidden":false,"isLocked":false,"kind":"rectangle","name":"R","text":""}]}],"version":1}
            """#
        var workspace = DesignWorkspace()
        try workspace.open(Data(old.utf8))
        #expect(workspace.treeNode("node-1")?.kind == .rectangle)
        #expect(workspace.treeNode("node-1")?.shape == nil)
    }

    @Test func aSpecIsWrittenOnlyWhenSetAndReadBack() throws {
        var node = DesignNode(id: "node-9", name: "Star", kind: .shape, frame: rc(0, 0, 100, 100))
        let plain = String(decoding: try JSONEncoder().encode(node), as: UTF8.self)
        #expect(!plain.contains("\"shape\""))
        node.shape = ShapeIntent.points(7).applied(to: .defaults(.star))
        let back = try JSONDecoder().decode(DesignNode.self, from: try JSONEncoder().encode(node))
        #expect(back.kind == .shape && back.shape == node.shape)
        #expect(DesignNode(id: "node-10", copying: node).shape == node.shape)
    }

    @Test func shapeIsAToolWithAReasonUntilItDraws() {
        #expect(DesignTool.allCases.contains(.shape))
        #expect(!DesignTool.shape.isEnabled)
        #expect(DesignTool.shape.unavailableHelp?.isEmpty == false)
        #expect(DesignTool.shape.nodeKind == nil)
        #expect(openDesign().shapeHelp == DesignTool.shape.unavailableHelp)
    }

    @Test func theToolStartsOnAFivePointStar() {
        let workspace = DesignWorkspace()
        #expect(workspace.shapeTool == .defaults(.star) && workspace.shapeTool.points == 5)
    }

    @Test func pickingOptionsIsViewState() {
        var workspace = openDesign()
        workspace.pickShapeTool(.defaults(.arrow))
        #expect(workspace.shapeTool.kind == .arrow)
        workspace.runShape(.kind(.polygon))
        workspace.runShape(.sides(8))
        #expect(workspace.shapeTool.kind == .polygon && workspace.shapeTool.sides == 8)
        #expect(!workspace.canUndo, "picking options is view state, not an undo step")
    }

    @Test func addShapeRefusesUntilItIsBuilt() {
        var workspace = openDesign()
        let before = workspace.pages
        #expect(throws: ShapeRefusal.self) { try workspace.addShape(.defaults(.star), in: Self.box, name: "Draw Star") }
        #expect(workspace.pages == before && !workspace.canUndo)
    }

    @Test(.disabled("DS-5")) func drawIsOneStep() throws {
        var workspace = openDesign()
        let id = try workspace.addShape(.defaults(.star), in: Self.box, name: "Draw Star")
        #expect(workspace.treeNode(id)?.kind == .shape && workspace.selectedNodeID == id)
        #expect(workspace.treeNode(id)?.shape == .defaults(.star))
        #expect(workspace.undoActionName == "Undo Draw Star")
        workspace.undo()
        #expect(workspace.treeNode(id) == nil)
    }

    @Test(.disabled("DS-5")) func aDragWithTheShapeToolDrawsTheSpec() throws {
        var workspace = openDesign()
        workspace.selectTool(.shape)
        workspace.drag(from: DesignPoint(x: 10, y: 10), to: DesignPoint(x: 110, y: 60), modifiers: [.shift])
        let node = try #require(workspace.selectedNode)
        #expect(node.kind == .shape && node.shape?.kind == .star)
        #expect(node.frame.width == node.frame.height, "Shift squares the box")
        #expect(workspace.undoActionName == "Undo Draw Star")
    }

    @Test(.disabled("DS-5")) func theSpecSurvivesSaveAndOpen() throws {
        var workspace = openDesign()
        workspace.runShape(.points(6))
        let id = try workspace.addShape(workspace.shapeTool, in: Self.box, name: "Draw Star")
        var reopened = DesignWorkspace()
        try reopened.open(try workspace.fileData())
        #expect(reopened.treeNode(id)?.kind == .shape && reopened.treeNode(id)?.shape?.points == 6)
    }

    @Test(.disabled("DS-5")) func aNodePathIsTheKernelPathInItsFrame() throws {
        var node = DesignNode(id: "node-9", name: "Star", kind: .shape, frame: rc(0, 0, 100, 100))
        #expect(node.path(in: node.frame) == nil, "no spec, no path")
        node.shape = .defaults(.star)
        #expect(node.path(in: node.frame) == (try ShapeRules.path(.defaults(.star), in: Self.box)))
        #expect(DesignNode(id: "node-1", name: "R", kind: .rectangle, frame: rc(0, 0, 10, 10)).path(in: rc(0, 0, 10, 10)) == nil)
    }
}
