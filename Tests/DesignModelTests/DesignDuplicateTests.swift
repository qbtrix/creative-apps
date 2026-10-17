// DesignDuplicateTests.swift: LiveDuplicating, the live Duplicate and the copy an
// Option-drag moves (copy-group C-1, #414 (a), blueprint 5.4), through the
// workspace on `.live`. Duplicating a frame with two children mints three new
// ids at +10, +10 directly above the original; Undo puts back the tree and the
// selection; an Option-drag is one "Duplicate" step; nothing selected records
// nothing; a Locked layer's copy is unlocked; a saved file reopens with no
// repeated id; the copy equals the original but for ids, offset and lock (QD-V5).
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

// One page, back to front: the frame Card node-1 (100 100 200 150) holding Box node-2 and
// Label node-3, the rectangle Top node-4, and the locked rectangle Pin node-5.
private enum ID { static let card = "node-1", box = "node-2", label = "node-3", top = "node-4", pin = "node-5" }

private func cardsFile() throws -> DesignWorkspace {
    let box = DesignNode(id: ID.box, name: "Box", kind: .rectangle, frame: rc(120, 120, 40, 30),
                         fill: DesignColor(255, 0, 0), cornerRadius: 4, opacity: 0.5)
    let label = DesignNode(id: ID.label, name: "Label", kind: .text, frame: rc(120, 200, 100, 20), text: "Hi")
    let card = DesignNode(id: ID.card, name: "Card", kind: .frame, frame: rc(100, 100, 200, 150), children: [box, label])
    let top = DesignNode(id: ID.top, name: "Top", kind: .rectangle, frame: rc(600, 600, 50, 50))
    let pin = DesignNode(id: ID.pin, name: "Pin", kind: .rectangle, frame: rc(800, 100, 50, 50), isLocked: true)
    let page = DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [card, top, pin])
    var workspace = DesignWorkspace()
    try workspace.open(LiveFiling().encode(DesignDocument(pages: [page])))
    workspace.useServices(.live)
    return workspace
}

private func top(_ workspace: DesignWorkspace) -> [DesignNode] { workspace.selectedPage?.nodes ?? [] }

private func allIDs(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + allIDs($0.children) } }

/// `node` with every id blanked, moved back by `offset` and unlocked, so a copy compares to its original.
private func normalized(_ node: DesignNode, back offset: DesignPoint = pt(0, 0)) -> DesignNode {
    var out = DesignNode(id: "", copying: node)
    out.children = node.children.map { normalized($0) }
    out.translate(by: pt(-offset.x, -offset.y))
    out.isLocked = false
    return out
}

@Suite struct DesignDuplicateTests {
    @Test func aFrameWithTwoChildrenGetsThreeNewIDsAboveIt() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.card)
        let before = allIDs(top(workspace))
        try workspace.run(.duplicate)
        #expect(top(workspace).map(\.id).first == ID.card)
        let copy = try #require(top(workspace).dropFirst().first)
        #expect(top(workspace).map(\.id).dropFirst(2) == [ID.top, ID.pin])
        let fresh = allIDs([copy])
        #expect(fresh.count == 3 && Set(fresh).count == 3 && Set(fresh).isDisjoint(with: before))
        #expect(copy.frame == rc(110, 110, 200, 150))
        #expect(copy.children.map(\.frame) == [rc(130, 130, 40, 30), rc(130, 210, 100, 20)])
        #expect(workspace.selectedNodeIDs == [copy.id])
        #expect(workspace.undoActionName == "Undo Duplicate" && workspace.history.undo.count == 1)
    }

    @Test func undoRemovesTheCopiesAndRestoresTheSelection() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.card)
        workspace.toggleSelection(ID.top)
        let before = workspace.pages
        try workspace.run(.duplicate)
        #expect(top(workspace).map(\.name) == ["Card", "Card", "Top", "Top", "Pin"])
        workspace.undo()
        #expect(workspace.pages == before)
        #expect(workspace.selectedNodeIDs == [ID.card, ID.top])
    }

    @Test func aSelectedChildIsCopiedOnceInsideItsCopiedParent() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.card)
        workspace.toggleSelection(ID.box)
        try workspace.run(.duplicate)
        #expect(allIDs(top(workspace)).count == 8)
        #expect(workspace.selectedNodeIDs.count == 1)
    }

    @Test func aChildCopyStaysInItsParentAboveIt() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.box)
        try workspace.run(.duplicate)
        let card = try #require(top(workspace).first)
        #expect(card.children.map(\.name) == ["Box", "Box", "Label"])
        #expect(card.children.dropFirst().first?.frame == rc(130, 130, 40, 30))
        #expect(top(workspace).count == 3)
    }

    @Test func optionDragIsOneDuplicateStep() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.top)
        workspace.gesture(.move, pt(620, 620), pt(660, 620), .option)
        #expect(workspace.frame(ID.top) == rc(600, 600, 50, 50))
        let copy = try #require(top(workspace).dropFirst(2).first)
        #expect(copy.name == "Top" && copy.id != ID.top)
        #expect(copy.frame == rc(640, 600, 50, 50))
        #expect(workspace.history.undo.count == 1 && workspace.undoActionName == "Undo Duplicate")
    }

    @Test func nothingSelectedChangesNothing() throws {
        var workspace = try cardsFile()
        let before = workspace
        #expect(workspace.help(.duplicate) == "Select a layer first.")
        #expect(throws: DesignRefusal.nothingSelected) { try workspace.run(.duplicate) }
        #expect(workspace == before && workspace.history.undo.isEmpty)
        let page = try #require(workspace.selectedPage)
        var mint = DesignIDMint(taken: [], after: 5)
        #expect(LiveDuplicating().duplicateHelp([], on: page) == "Select a layer first.")
        #expect(throws: DesignRefusal.nothingSelected) {
            try LiveDuplicating().duplicate(["nope"], offset: pt(10, 10), on: page, mint: &mint)
        }
        #expect(mint.minted.isEmpty)
    }

    @Test func aLockedLayerDuplicatesUnlocked() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.pin)
        #expect(workspace.help(.duplicate) == nil)
        try workspace.run(.duplicate)
        let copy = try #require(top(workspace).last)
        #expect(copy.name == "Pin" && copy.id != ID.pin && !copy.isLocked)
        #expect(workspace.treeNode(ID.pin)?.isLocked == true)
    }

    @Test func aSavedDuplicateReopensWithNoRepeatedID() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.card)
        try workspace.run(.duplicate)
        try workspace.run(.duplicate)
        var reopened = DesignWorkspace()
        try reopened.open(workspace.fileData())
        let ids = allIDs(top(reopened))
        #expect(ids.count == 11 && Set(ids).count == ids.count)
        #expect(reopened.pages == workspace.pages)
    }

    @Test func copyIsFaithful() throws {
        var workspace = try cardsFile()
        workspace.selectItem(ID.card)
        try workspace.run(.duplicate)
        workspace.selectItem(ID.pin)
        try workspace.run(.duplicate)
        let nodes = top(workspace)
        #expect(nodes.map(\.name) == ["Card", "Card", "Top", "Pin", "Pin"])
        for (original, copy) in [(0, 1), (3, 4)] {
            let (o, c) = try (#require(nodes.dropFirst(original).first), #require(nodes.dropFirst(copy).first))
            #expect(normalized(c, back: pt(10, 10)) == normalized(o))
        }
    }

    @Test func copySubtreeMintsEveryIDParentFirst() throws {
        let page = try #require(try cardsFile().selectedPage)
        let card = try #require(page.nodes.first)
        var mint = DesignIDMint(taken: Set(allIDs(page.nodes)), after: 5)
        let copy = LiveDuplicating().copySubtree(card, mint: &mint)
        #expect(allIDs([copy]) == ["node-6", "node-7", "node-8"] && mint.minted == ["node-6", "node-7", "node-8"])
        #expect(normalized(copy) == normalized(card) && copy.frame == card.frame)
    }

    @Test func helpLawHoldsOnLive() throws {
        let page = try #require(try cardsFile().selectedPage)
        let law = DesignContractLaw.check(.live, on: page)
        #expect(law.violations.isEmpty, "\(law.violations)")
    }
}
