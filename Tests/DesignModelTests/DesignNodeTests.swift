// DesignNodeTests.swift: the plain value types: a node's defaults per kind,
// the tool-to-kind map, page size text, a color's light or dark side and the
// Codable round trip the file format builds on, and shape nodes
// (DesignShapeNodeTests, below). Runs on Linux and macOS.
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

@Test func onlyThePenIsDisabledAndSaysWhy() {
    for tool in DesignTool.allCases where tool != .pen {
        #expect(tool.isEnabled && tool.unavailableHelp == nil)
    }
    #expect(!DesignTool.pen.isEnabled && DesignTool.pen.unavailableHelp == "Drawing paths isn't built yet.")
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

// Shape nodes (shape-tools DS-1, MJ-DS): old files still open with no spec, a node's spec is written only
// when set, and the tool's options are view state. Drawing and a node's path are in DesignShapeTests.
struct DesignShapeNodeTests {
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

    @Test func aNodeWithNoSpecHasNoPath() {
        var node = DesignNode(id: "node-9", name: "Star", kind: .shape, frame: rc(0, 0, 100, 100))
        #expect(node.path(in: node.frame) == nil, "no spec, no path")
        node.shape = .defaults(.star)
        #expect(node.path(in: node.frame) != nil)
    }
}
