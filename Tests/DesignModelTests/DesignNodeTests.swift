// DesignNodeTests.swift: the plain value types: a node's defaults per kind,
// the tool-to-kind map, page size text and the Codable round trip the file
// format builds on. Runs on Linux and macOS.
import DesignModel
import Foundation
import Testing

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

@Test func onlyThePenIsDisabledAndItSaysWhy() {
    for tool in DesignTool.allCases where tool != .pen { #expect(tool.isEnabled && tool.unavailableHelp == nil) }
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
