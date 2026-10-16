// DesignStyleSchemaTests.swift: the style schema (design-contracts D0-1). A
// node gains opacity, stroke and text style beside its corner radius, each with
// a default, so a version-1 file written before any of them opens unchanged;
// `DesignNode(id:copying:)` keeps every field but the id; `DesignPage` has a
// public memberwise init. Plain `import DesignModel`, so every name used here is
// public. Holds MJ1. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import Testing

/// A version-1 file as it was written before corner radius and the style fields: a Desktop
/// frame (node-1) holding a rectangle "A" (node-2) and a text "T" (node-3).
private let versionOne = #"""
    {"pages":[{"frameHeight":1024,"frameWidth":1440,"id":"page-1","name":"Page 1","nodes":[
    {"children":[
    {"children":[],"fill":{"blue":217,"green":217,"red":217},"frame":{"height":80,"width":100,"x":100,"y":100},
    "id":"node-2","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","text":""},
    {"children":[],"fill":{"blue":0,"green":0,"red":0},"frame":{"height":24,"width":120,"x":100,"y":300},
    "id":"node-3","isHidden":false,"isLocked":true,"kind":"text","name":"T","text":"Hello"}],
    "fill":{"blue":255,"green":255,"red":255},"frame":{"height":1024,"width":1440,"x":0,"y":0},
    "id":"node-1","isHidden":false,"isLocked":false,"kind":"frame","name":"Desktop","text":""}]}],"version":1}
    """#

/// A rectangle with every field set away from its default.
private let everyField = DesignNode(
    id: "node-7", name: "Card", kind: .rectangle, frame: DesignRect(x: 1, y: 2, width: 30, height: 40),
    children: [], isHidden: true, isLocked: true, fill: DesignColor(1, 2, 3), text: "x", cornerRadius: 6,
    opacity: 0.25, stroke: DesignStroke(color: DesignColor(9, 8, 7), width: 3),
    textStyle: DesignTextStyle(family: "Serif", size: 22, weight: 700, alignment: .center))

private func node(_ id: String, in workspace: DesignWorkspace) -> DesignNode? {
    func find(_ nodes: [DesignNode]) -> DesignNode? {
        for node in nodes {
            if node.id == id { return node }
            if let inner = find(node.children) { return inner }
        }
        return nil
    }
    return workspace.pages.lazy.compactMap { find($0.nodes) }.first
}

@Test func versionOneOpens() throws {
    var workspace = DesignWorkspace()
    try workspace.open(Data(versionOne.utf8))
    for id in ["node-1", "node-2", "node-3"] {
        let opened = try #require(node(id, in: workspace))
        #expect(opened.opacity == 1)
        #expect(opened.stroke == nil)
        #expect(opened.textStyle == .default)
        #expect(opened.cornerRadius == 0)
    }
    #expect(node("node-3", in: workspace)?.text == "Hello")
    #expect(node("node-3", in: workspace)?.isLocked == true)
}

@Test func aNodeWithEveryFieldSetRoundTrips() throws {
    let data = try JSONEncoder().encode(everyField)
    #expect(try JSONDecoder().decode(DesignNode.self, from: data) == everyField)
}

@Test func aCopyKeepsEveryFieldButTheID() {
    let parent = DesignNode(
        id: "node-6", name: "Group", kind: .group, frame: DesignRect(x: 0, y: 0, width: 50, height: 50),
        children: [everyField], opacity: 0.5)
    for original in [everyField, parent] {
        let copy = DesignNode(id: "node-99", copying: original)
        #expect(copy.id == "node-99")
        // Put the id back and nothing else differs.
        #expect(DesignNode(id: original.id, copying: copy) == original)
        #expect(copy.name == original.name && copy.kind == original.kind && copy.frame == original.frame)
        #expect(copy.children == original.children && copy.fill == original.fill && copy.text == original.text)
        #expect(copy.isHidden == original.isHidden && copy.isLocked == original.isLocked)
        #expect(copy.cornerRadius == original.cornerRadius && copy.opacity == original.opacity)
        #expect(copy.stroke == original.stroke && copy.textStyle == original.textStyle)
    }
}

@Test func aPageBuildsFromOutsideTheModule() {
    let page = DesignPage(id: "page-4", name: "Cards", frameWidth: 390, frameHeight: 844, nodes: [everyField])
    #expect(page.id == "page-4" && page.name == "Cards")
    #expect(page.frameWidth == 390 && page.frameHeight == 844)
    #expect(page.nodes == [everyField])
    #expect(DesignPage(id: "page-5", name: "Empty", frameWidth: 10, frameHeight: 10).nodes.isEmpty)
}

@Test func theWorkspaceStartsWithNoMarquee() {
    #expect(DesignWorkspace().marquee == nil)
}

@Test func aFileWithAStyleOutOfRangeIsRefused() throws {
    for bad in [#""opacity":2,"#, #""opacity":-0.5,"#, #""stroke":{"color":{"blue":0,"green":0,"red":0},"width":-1},"#,
                #""textStyle":{"alignment":"leading","family":"System","size":0,"weight":400},"#] {
        let file = versionOne.replacingOccurrences(of: #""id":"node-2","#, with: bad + #""id":"node-2","#)
        var workspace = DesignWorkspace()
        #expect(throws: DesignFileError.invalidNumber("node-2")) { try workspace.open(Data(file.utf8)) }
        #expect(!workspace.isOpen)
    }
}

/// MJ1: an old file opens with every new field at its default; A's corner radius set to 12
/// survives a save and reopen, and nothing else in the file moves.
@Test func testOldFileAndCornersWalk() throws {
    var workspace = DesignWorkspace()
    try workspace.open(Data(versionOne.utf8))
    let a = try #require(node("node-2", in: workspace))
    #expect(a.name == "A")
    #expect(a.cornerRadius == 0 && a.opacity == 1 && a.stroke == nil && a.textStyle == .default)
    let (desktop, text) = (node("node-1", in: workspace), node("node-3", in: workspace))
    let page = try #require(workspace.pages.first)

    try workspace.setCornerRadius("node-2", 12)
    var reopened = DesignWorkspace()
    try reopened.open(try workspace.fileData())

    var rounded = a
    rounded.cornerRadius = 12
    #expect(node("node-2", in: reopened) == rounded)
    #expect(node("node-3", in: reopened) == text)
    let reopenedDesktop = try #require(node("node-1", in: reopened))
    #expect(reopenedDesktop.children == [rounded, try #require(text)])
    #expect(DesignNode(id: "x", copying: reopenedDesktop).name == desktop?.name)
    #expect(reopenedDesktop.frame == desktop?.frame && reopenedDesktop.fill == desktop?.fill)
    #expect(reopenedDesktop.opacity == 1 && reopenedDesktop.stroke == nil && reopenedDesktop.cornerRadius == 0)
    let reopenedPage = try #require(reopened.pages.first)
    #expect(reopened.pages.count == 1 && reopenedPage.id == page.id && reopenedPage.name == page.name)
    #expect(reopenedPage.frameWidth == page.frameWidth && reopenedPage.frameHeight == page.frameHeight)
}
