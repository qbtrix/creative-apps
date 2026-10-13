// DesignFileTests.swift: the file codec (DesignFile). A saved document opens
// again equal; the next id after opening is above every opened id; opening
// clears undo; and every refused file (not JSON, a newer version, no pages, a
// repeated id, children under a shape, a size under 1) throws the right error
// and leaves the workspace exactly as it was. Reaches the internal load(_:)
// with @testable to build documents the model API would never make. Runs on
// Linux and macOS.
@testable import DesignModel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private func bytes(_ json: String) -> Data { Data(json.utf8) }

private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

/// Two pages: Desktop with a group of a rectangle and an ellipse, a locked hidden
/// recolored rectangle and a text node; and an empty second page.
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    let box = rc(40, 40, 200, 120)
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.addNode(.rectangle, frame: box, in: group)
    try workspace.addNode(.ellipse, frame: rc(60, 60, 50, 50), in: group)
    let locked = try workspace.addNode(.rectangle, frame: rc(300, 300, 30, 30), in: "node-1")
    try workspace.setFill(locked, DesignColor(12, 34, 56))
    try workspace.setNodeHidden(locked, true)
    try workspace.setNodeLocked(locked, true)
    workspace.gesture(.text, pt(500, 500), pt(500, 500))
    workspace.setTextDraft("Hello, \"Design\"\nsecond line é")
    workspace.commitTextEdit()
    workspace.addPage()
    return workspace
}

@Test func aSavedDocumentOpensEqual() throws {
    let original = try sample()
    #expect(original.pages.count == 2 && original.pages[0].nodes[0].children.count == 3)
    let data = try original.fileData()
    var reopened = DesignWorkspace()
    try reopened.open(data)
    #expect(reopened.pages == original.pages)
    #expect(reopened.pages[0].nodes[0].children[2].text == "Hello, \"Design\"\nsecond line é")
    #expect(reopened.pages[0].nodes[0].children[1].fill == DesignColor(12, 34, 56))
    #expect(reopened.pages[0].nodes[0].children[1].isHidden && reopened.pages[0].nodes[0].children[1].isLocked)
    // Writing it again gives the same bytes: the keys are sorted.
    #expect(try reopened.fileData() == data)
}

@Test func theFileIsVersionOneJSONWithSortedKeys() throws {
    let json = text(try openDesign().fileData())
    #expect(json.contains("\"version\":1"))
    #expect(json.hasPrefix("{\"pages\":[{") && json.hasSuffix("\"version\":1}"))
}

@Test func openingSelectsTheFirstPageAndClearsTheHistory() throws {
    var workspace = try sample()
    #expect(workspace.canUndo)
    let data = try workspace.fileData()
    workspace.selectPage("page-2")
    try workspace.open(data)
    #expect(workspace.selectedPageID == "page-1" && workspace.selectedNodeID == nil)
    #expect(!workspace.canUndo && !workspace.canRedo && workspace.undoActionName == "Undo")
    #expect(workspace.expandedNodeIDs.isEmpty && workspace.editingTextID == nil)
    workspace.undo()
    #expect(workspace.pages.count == 2)
}

@Test func theNextIDAfterOpeningIsAboveEveryOpenedID() throws {
    let data = try sample().fileData()
    var workspace = DesignWorkspace()
    try workspace.open(data)
    // The sample used node-1 to node-6 and page-1, page-2.
    #expect(try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10)) == "node-7")
    workspace.addPage()
    #expect(workspace.pages.last?.id == "page-3")
}

@Test func openingReplacesAnOpenDocument() throws {
    let data = try sample().fileData()
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(1, 1), pt(5, 5))
    try workspace.open(data)
    #expect(workspace.pages.count == 2 && !workspace.canUndo)
}

@Test func savingWithNothingOpenThrows() {
    let workspace = DesignWorkspace()
    #expect(throws: DesignFileError.noFile) { try workspace.fileData() }
}

@Test func notJSONIsUnreadableAndChangesNothing() throws {
    var workspace = try sample()
    let before = workspace
    for corrupt in ["", "not json", "{", "[]", "{\"version\":1}", "{\"version\":1,\"pages\":[{\"id\":\"page-1\"}]}"] {
        #expect(throws: DesignFileError.unreadable, "\(corrupt)") { try workspace.open(bytes(corrupt)) }
    }
    #expect(workspace == before && workspace.canUndo)
}

@Test func aNewerVersionReportsItsVersion() throws {
    var workspace = openDesign()
    let before = workspace
    // A version 2 file whose pages have a shape this version doesn't know.
    #expect(throws: DesignFileError.unsupportedVersion(2)) {
        try workspace.open(bytes("{\"version\":2,\"pages\":{\"future\":true}}"))
    }
    #expect(throws: DesignFileError.unsupportedVersion(0)) { try workspace.open(bytes("{\"version\":0,\"pages\":[]}")) }
    #expect(workspace == before)
}

@Test func aFileWithNoPagesIsRefused() throws {
    var workspace = openDesign()
    let before = workspace
    #expect(throws: DesignFileError.noPages) { try workspace.open(bytes("{\"pages\":[],\"version\":1}")) }
    #expect(workspace == before)
}

private func page(_ id: String, _ nodes: [DesignNode] = [], width: Double = 800, height: Double = 600) -> DesignPage {
    DesignPage(id: id, name: id, frameWidth: width, frameHeight: height, nodes: nodes)
}

private func node(_ id: String, _ kind: DesignNodeKind = .rectangle, _ frame: DesignRect = rc(0, 0, 10, 10), children: [DesignNode] = [])
    -> DesignNode
{
    DesignNode(id: id, name: id, kind: kind, frame: frame, children: children)
}

/// The bytes a document with these pages writes. `load` doesn't check, `fileData` does, so pages that
/// are bad on purpose can't go through here: edit a good file's JSON instead.
private func file(_ pages: [DesignPage]) throws -> Data {
    var workspace = DesignWorkspace()
    workspace.load(pages)
    return try workspace.fileData()
}

@Test func aRepeatedIDIsRefused() throws {
    var workspace = openDesign()
    let before = workspace
    // The same node id twice on one page, on two pages, and a node using a page's id.
    let twice = try file([page("page-1", [node("a"), node("b")])])
    let sameNode = text(twice).replacing("\"id\":\"b\"", with: "\"id\":\"a\"")
    #expect(throws: DesignFileError.duplicateID("a")) { try workspace.open(bytes(sameNode)) }
    let pages = try file([page("page-1", [node("a")]), page("page-2", [node("b")])])
    let acrossPages = text(pages).replacing("\"id\":\"b\"", with: "\"id\":\"a\"")
    #expect(throws: DesignFileError.duplicateID("a")) { try workspace.open(bytes(acrossPages)) }
    let samePage = text(pages).replacing("\"id\":\"page-2\"", with: "\"id\":\"page-1\"")
    #expect(throws: DesignFileError.duplicateID("page-1")) { try workspace.open(bytes(samePage)) }
    let pageAsNode = text(pages).replacing("\"id\":\"a\"", with: "\"id\":\"page-2\"")
    #expect(throws: DesignFileError.duplicateID("page-2")) { try workspace.open(bytes(pageAsNode)) }
    #expect(workspace == before)
}

@Test func childrenUnderAShapeAreRefused() throws {
    var workspace = openDesign()
    let before = workspace
    let nested = node("outer", .group, rc(0, 0, 50, 50), children: [node("inner")])
    let data = try file([page("page-1", [nested])])
    try workspace.open(data)
    #expect(workspace.pages[0].nodes[0].children.count == 1)
    // The same file with the group turned into a rectangle, and into text.
    for kind in ["rectangle", "ellipse", "text", "instance"] {
        let shape = text(data).replacing("\"kind\":\"group\"", with: "\"kind\":\"\(kind)\"")
        var other = before
        #expect(throws: DesignFileError.notAContainer("outer")) { try other.open(bytes(shape)) }
        #expect(other == before)
    }
}

@Test func aSizeUnderOnePointIsRefused() throws {
    let good = try file([page("page-1", [node("a", .rectangle, rc(5, 5, 10, 10))])])
    var workspace = DesignWorkspace()
    try workspace.open(good)
    let before = workspace
    for (from, to, id) in [
        ("\"width\":10", "\"width\":0", "a"), ("\"height\":10", "\"height\":0.5", "a"), ("\"width\":10", "\"width\":-3", "a"),
        ("\"frameWidth\":800", "\"frameWidth\":0", "page-1"), ("\"frameHeight\":600", "\"frameHeight\":-1", "page-1"),
    ] {
        let bad = text(good).replacing(from, with: to)
        #expect(bad != text(good), "\(from) is in the file")
        var other = before
        #expect(throws: DesignFileError.invalidNumber(id), "\(to)") { try other.open(bytes(bad)) }
        #expect(other == before)
    }
}

@Test func aDocumentThatCouldNotBeOpenedAgainIsNotWritten() {
    var workspace = DesignWorkspace()
    workspace.load([page("page-1", [node("a", .rectangle, rc(0, 0, .nan, 10))])])
    #expect(throws: DesignFileError.invalidNumber("a")) { try workspace.fileData() }
    workspace.load([page("page-1", [node("b", .rectangle, rc(.infinity, 0, 10, 10))])])
    #expect(throws: DesignFileError.invalidNumber("b")) { try workspace.fileData() }
    workspace.load([page("page-1", [node("c", .rectangle, rc(0, 0, 10, 0))])])
    #expect(throws: DesignFileError.invalidNumber("c")) { try workspace.fileData() }
}

@Test func everyErrorSaysWhatToDo() {
    let errors: [DesignFileError] = [
        .noFile, .unreadable, .unsupportedVersion(3), .noPages, .duplicateID("node-4"), .notAContainer("node-5"),
        .invalidNumber("page-2"),
    ]
    let reasons = errors.map(\.reason)
    #expect(Set(reasons).count == errors.count && reasons.allSatisfy { $0.hasSuffix(".") })
    #expect(reasons[2].contains("3") && reasons[4].contains("node-4") && reasons[5].contains("node-5"))
}
