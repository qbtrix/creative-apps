// DesignPasteboardTests.swift: LiveClipboard, the live Cut, Copy and Paste and
// their LayerPayload (copy-group C-3, #415 (a)), through the workspace on
// `.live`. A copied frame with children pastes with new ids and the same names,
// fills and relative positions; a selected frame takes the copies; pasting over
// the original offsets by (10, 10) and elsewhere does not; Cut is one step that
// Undo reverses with the selection; the bytes paste into another file at its top
// level; bad bytes throw `.unreadable` and change nothing. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

// One page, back to front: the frame Card node-1 (100 100 200 150) holding Box node-2 and
// Label node-3, the rectangle Top node-4, and the empty frame Tray node-5 (600 100 300 300).
private enum ID { static let card = "node-1", box = "node-2", label = "node-3", top = "node-4", tray = "node-5" }

private func cardsFile() throws -> DesignWorkspace {
    let box = DesignNode(id: ID.box, name: "Box", kind: .rectangle, frame: rc(120, 120, 40, 30),
                         fill: DesignColor(255, 0, 0), cornerRadius: 4, opacity: 0.5)
    let label = DesignNode(id: ID.label, name: "Label", kind: .text, frame: rc(120, 200, 100, 20), text: "Hi")
    let card = DesignNode(id: ID.card, name: "Card", kind: .frame, frame: rc(100, 100, 200, 150), children: [box, label])
    let top = DesignNode(id: ID.top, name: "Top", kind: .rectangle, frame: rc(600, 600, 50, 50))
    let tray = DesignNode(id: ID.tray, name: "Tray", kind: .frame, frame: rc(600, 100, 300, 300))
    return try file([card, top, tray])
}

private func file(_ nodes: [DesignNode]) throws -> DesignWorkspace {
    let page = DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: nodes)
    var workspace = DesignWorkspace()
    try workspace.open(LiveFiling().encode(DesignDocument(pages: [page])))
    workspace.useServices(.live)
    return workspace
}

private func top(_ workspace: DesignWorkspace) -> [DesignNode] { workspace.selectedPage?.nodes ?? [] }

private func allIDs(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + allIDs($0.children) } }

private func pasted(_ workspace: DesignWorkspace) throws -> DesignNode {
    try #require(workspace.selectedNodeIDs.last.flatMap { workspace.selectedPage?.nodes.node($0) })
}

/// `node` with every id blanked and moved back by `offset`, so a copy compares to its original.
private func normalized(_ node: DesignNode, back offset: DesignPoint = pt(0, 0)) -> DesignNode {
    var out = DesignNode(id: "", copying: node)
    out.children = node.children.map { normalized($0) }
    out.translate(by: pt(-offset.x, -offset.y))
    return out
}

private func bytes(_ json: String) -> Data { Data(json.utf8) }

@Suite struct DesignPasteboardTests {
    @Test func copyThenPasteGivesNewIDsAndTheSameLayers() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.card)
        let before = allIDs(top(workspace))
        let data = try workspace.copySelection()
        workspace.deselect()
        try workspace.paste(data)
        let copy = try pasted(workspace)
        let fresh = allIDs([copy])
        #expect(fresh.count == 3 && Set(fresh).count == 3 && Set(fresh).isDisjoint(with: before))
        #expect(copy.children.map(\.name) == ["Box", "Label"])
        #expect(copy.children.first?.fill == DesignColor(255, 0, 0))
        #expect(top(workspace).map(\.id).prefix(3) == [ID.card, ID.top, ID.tray] && top(workspace).count == 4)
        #expect(workspace.undoActionName == "Undo Paste" && workspace.history.undo.count == 1)
    }

    @Test func pasteIsFaithful() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.card)
        let original = try #require(top(workspace).first)
        try workspace.paste(try workspace.copySelection())
        let copy = try #require(top(workspace).first?.children.last)
        let offset = pt(copy.frame.x - original.frame.x, copy.frame.y - original.frame.y)
        #expect(normalized(copy, back: offset) == normalized(original))
    }

    @Test func pasteIntoASelectedFrameNestsTheCopies() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.top)
        let data = try workspace.copySelection()
        workspace.selectItem(ID.tray)
        try workspace.paste(data)
        let copy = try pasted(workspace)
        #expect(workspace.selectedPage?.nodes.ancestors(of: copy.id) == [ID.tray])
        #expect(copy.name == "Top" && copy.frame == rc(600, 600, 50, 50))
        #expect(top(workspace).count == 3)
    }

    @Test func pastingOverTheOriginalOffsetsAndElsewhereDoesNot() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.box)
        let data = try workspace.copySelection()
        workspace.deselect()
        try workspace.paste(data)
        let over = try pasted(workspace)
        #expect(workspace.selectedPage?.nodes.ancestors(of: over.id) == [ID.card])
        #expect(over.frame == rc(130, 130, 40, 30))
        workspace.selectItem(ID.tray)
        try workspace.paste(data)
        let away = try pasted(workspace)
        #expect(workspace.selectedPage?.nodes.ancestors(of: away.id) == [ID.tray])
        #expect(away.frame == rc(120, 120, 40, 30))
    }

    @Test func cutRemovesAndUndoRestoresWithTheSelection() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.box)
        workspace.toggleSelection(ID.label)
        let before = workspace.pages
        let data = try workspace.cutSelection()
        #expect(top(workspace).first?.children.isEmpty == true)
        #expect(workspace.undoActionName == "Undo Cut" && workspace.history.undo.count == 1)
        workspace.undo()
        #expect(workspace.pages == before)
        #expect(workspace.selectedNodeIDs == [ID.box, ID.label])
        workspace.deselect()
        try workspace.paste(data)
        #expect(workspace.selectedNodeIDs.count == 2)
    }

    @Test func bytesPasteIntoAnotherFileAtItsTopLevel() throws {
        var source = try cardsFile()
        source.selectItem(ID.box)
        let data = try source.copySelection()
        let other = DesignNode(id: "node-40", name: "Other", kind: .rectangle, frame: rc(0, 0, 10, 10))
        let shelf = DesignNode(id: "node-41", name: "Shelf", kind: .frame, frame: rc(50, 50, 400, 400))
        var target = try file([other, shelf])
        #expect(target.selectedPage?.nodes.node(ID.card) == nil)
        try target.paste(data)
        let copy = try pasted(target)
        #expect(top(target).map(\.id) == ["node-40", "node-41", copy.id])
        #expect(copy.name == "Box" && copy.frame == rc(120, 120, 40, 30))
        #expect(!["node-40", "node-41"].contains(copy.id))
    }

    /// A payload of one rectangle X with `version` and, unless `empty`, its node.
    private static func payload(version: Int, empty: Bool = false) -> Data {
        let node = DesignNode(id: "node-9", name: "X", kind: .rectangle, frame: rc(0, 0, 1, 1))
        let payload = LayerPayload(version: version, parentID: nil, nodes: empty ? [] : [node])
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }

    static let badBytes = [bytes("not layers at all"), payload(version: 2), payload(version: 1, empty: true)]

    @Test(arguments: badBytes) func badBytesThrowUnreadableAndChangeNothing(_ data: Data) throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.tray)
        let before = (workspace.pages, workspace.selectedNodeIDs)
        #expect(throws: DesignRefusal.unreadable) { try workspace.paste(data) }
        #expect(workspace.pages == before.0 && workspace.selectedNodeIDs == before.1)
        #expect(workspace.history.undo.isEmpty)
        #expect(workspace.pasteHelp(data) == "The pasteboard holds no Design layers.")
    }

    @Test func aVersionOnePayloadPastes() throws {
        var workspace = try cardsFile()
        try workspace.paste(Self.payload(version: 1))
        #expect(try pasted(workspace).name == "X")
    }

    @Test func pasteHelpOfPlainTextSaysWhy() throws {
        let workspace = try cardsFile()
        #expect(workspace.pasteHelp(bytes("hello")) == "The pasteboard holds no Design layers.")
        #expect(workspace.pasteHelp(nil) == "The pasteboard holds no Design layers.")
        var copying = workspace
        copying.selectItem(ID.card)
        #expect(workspace.pasteHelp(try copying.copySelection()) == nil)
        #expect(LiveClipboard().pasteboardType == "org.creativesuite.design.layers")
    }

    @Test func thePayloadIsVersionOneWithTheFirstLayersParent() throws {
        let workspace = try cardsFile()
        let page = try #require(workspace.selectedPage)
        let data = try LiveClipboard().encode([ID.label, ID.box], on: page)
        let payload = try #require(LiveClipboard.payload(data))
        #expect(payload.version == 1 && payload.parentID == ID.card)
        #expect(payload.nodes.map(\.id) == [ID.label, ID.box])
        #expect(throws: DesignRefusal.nothingSelected) { try LiveClipboard().encode(["nope"], on: page) }
        #expect(LiveClipboard().copyHelp(["nope"], on: page) == "Select a layer first.")
    }

    @Test func helpLawHoldsOnLive() throws {
        let page = try #require(DesignFixtures.cards.selectedPage)
        let law = DesignContractLaw.check(.live, on: page)
        #expect(law.violations.isEmpty, "\(law.violations)")
    }
}
