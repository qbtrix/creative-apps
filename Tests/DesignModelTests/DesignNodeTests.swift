// DesignNodeTests.swift: the plain value types: a node's defaults per kind,
// the tool-to-kind map, page size text, a color's light or dark side and the
// Codable round trip the file format builds on, and shape nodes (DesignShapeTests,
// below). Runs on Linux and macOS.
import DesignModel
import Foundation
import SuiteKernel
import Testing

@Test func aColorIsDarkUnderTheBrightnessMidpoint() {
    #expect(DesignColor.black.isDark)
    #expect(!DesignColor.white.isDark && !DesignColor.shape.isDark)
    // Pure blue weighs 29 of 255, pure green 150; gray 127 sits just under the midpoint, 128 on it.
    #expect(DesignColor(0, 0, 255).isDark && !DesignColor(0, 255, 0).isDark)
    #expect(DesignColor(127, 127, 127).isDark && !DesignColor(128, 128, 128).isDark)
}

@Test func eachKindHasItsDefaultFillAndSize() {
    #expect(DesignNodeKind.frame.defaultFill == DesignColor.white)
    #expect(DesignNodeKind.text.defaultFill == DesignColor.black)
    for kind in [DesignNodeKind.group, .rectangle, .ellipse, .instance] { #expect(kind.defaultFill == DesignColor.shape) }
    #expect((DesignColor.shape.red, DesignColor.shape.green, DesignColor.shape.blue) == (217, 217, 217))
    #expect(DesignNodeKind.text.defaultSize == (120, 24))
    for kind in DesignNodeKind.allCases where kind != .text { #expect(kind.defaultSize == (100, 100)) }
}

@Test func aNodeTakesItsKindsFillAndEmptyTextUnlessGivenOthers() {
    let plain = DesignNode(id: "n", name: "N", kind: .ellipse, frame: rc(0, 0, 1, 1))
    #expect(plain.fill == DesignColor.shape && plain.text == "")
    let custom = DesignNode(id: "n", name: "N", kind: .text, frame: rc(0, 0, 1, 1), fill: DesignColor(1, 2, 3), text: "Hi")
    #expect(custom.fill == DesignColor(1, 2, 3) && custom.text == "Hi")
}

@Test func onlyTheDrawingToolsHaveANodeKind() {
    #expect(DesignTool.frame.nodeKind == .frame && DesignTool.rectangle.nodeKind == .rectangle)
    #expect(DesignTool.ellipse.nodeKind == .ellipse && DesignTool.text.nodeKind == .text)
    #expect(DesignTool.move.nodeKind == nil && DesignTool.pen.nodeKind == nil)
}

@Test func onlyThePenTheEyedropperAndTheShapeToolAreDisabledAndSayWhy() {
    for tool in DesignTool.allCases where tool != .pen && tool != .eyedropper && tool != .shape {
        #expect(tool.isEnabled && tool.unavailableHelp == nil)
    }
    #expect(!DesignTool.pen.isEnabled && DesignTool.pen.unavailableHelp == "Drawing paths isn't built yet.")
    // Until DY-5 makes its drag act.
    #expect(!DesignTool.eyedropper.isEnabled && DesignTool.eyedropper.unavailableHelp != nil)
    // Until DS-5 makes its drag draw.
    #expect(!DesignTool.shape.isEnabled && DesignTool.shape.unavailableHelp == "Drawing shapes isn't built yet.")
}

@Test func pageSizeTextShowsWholePoints() throws {
    let workspace = openDesign()
    #expect(workspace.selectedPage?.sizeText == "1440 × 1024 pt")
    let json = #"{"id":"p","name":"P","frameWidth":375.4,"frameHeight":811.6,"nodes":[]}"#
    let page = try JSONDecoder().decode(DesignPage.self, from: Data(json.utf8))
    #expect(page.sizeText == "375 × 812 pt")
    let wild = #"{"id":"p","name":"P","frameWidth":1e300,"frameHeight":-1e300,"nodes":[]}"#
    #expect(try JSONDecoder().decode(DesignPage.self, from: Data(wild.utf8)).sizeText.hasSuffix(" pt"))
}

@Test func aNodeTreeSurvivesAJSONRoundTrip() throws {
    var workspace = openDesign()
    workspace.gesture(.frame, pt(10, 10), pt(300, 300))
    workspace.gesture(.text, pt(20, 20), pt(20, 20))
    workspace.setTextDraft("Héllo")
    workspace.commitTextEdit()
    try workspace.setFill("node-2", DesignColor(10, 20, 30))
    try workspace.setNodeHidden("node-3", true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(workspace.pages)
    #expect(try JSONDecoder().decode([DesignPage].self, from: data) == workspace.pages)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains(#""fill":{"blue":30,"green":20,"red":10}"#))
    #expect(text.contains(#""kind":"frame""#) && text.contains("Héllo"))
}

// DesignShapeTests (shape-tools DS-1, MJ-DS): the Shape tool and shape nodes on DesignWorkspace's ShapeTarget
// stubs. Old files still open with no spec, a node's spec is written only when set, and the tool's options are
// view state. Drawing (`addShape`, a drag) and a node's path wait on DS-5, so those tests are disabled until it
// lands; DS-5 may move the suite to its own file.
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
        #expect(!plain.contains("\"shape\":"), "no spec, no key")
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
