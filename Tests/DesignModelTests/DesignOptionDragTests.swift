// DesignOptionDragTests.swift: an Option-drag on a selected layer duplicates it
// and drags the copy as ONE "Duplicate" undo step (design-seams D0-3c). The copy's
// id is minted once at the press and kept on every step, so a long drag never
// burns ids; one Undo puts the tree back, and a second Option-drag is a second
// step. On services whose Duplicate isn't built, Option-drag stays a plain move.
// Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignOptionDragTests {
    /// `cards` on the fake services with A (node-2, 100 100 100 80) selected.
    static func cardsWithA() -> DesignWorkspace {
        var workspace = DesignGestureRouteTests.cards()
        workspace.selectItem("node-2")
        return workspace
    }

    static func named(_ name: String, _ workspace: DesignWorkspace) -> [DesignNode] {
        workspace.selectedPage?.nodes.first?.children.filter { $0.name == name } ?? []
    }

    @Test func fiveStepsAreOneDuplicateStepWithOneCopyID() throws {
        var workspace = Self.cardsWithA()
        let start = workspace
        var copyIDs: [[String]] = []
        for step in 1...5 {
            workspace.drag(from: pt(150, 140), to: pt(150, 140 + Double(step) * 20), modifiers: .option)
            copyIDs.append(workspace.selectedNodeIDs)
        }
        workspace.endDrag()
        #expect(workspace.history.undo.count == 1)
        #expect(workspace.undoActionName == "Undo Duplicate")
        let copies = Self.named("A", workspace)
        #expect(copies.count == 2)
        #expect(workspace.frame("node-2") == rc(100, 100, 100, 80))
        let copy = try #require(copies.first { $0.id != "node-2" })
        #expect(copy.frame == rc(100, 200, 100, 80))
        #expect(copyIDs.allSatisfy { $0 == [copy.id] })
        #expect(workspace.selectedNodeIDs == [copy.id])
        workspace.undo()
        #expect(workspace.pages == start.pages)
        #expect(workspace.selectedNodeIDs == ["node-2"])
    }

    @Test func theCopyIDIsMintedOnceSoTheNextAddFollowsIt() throws {
        var workspace = Self.cardsWithA()
        for step in 1...5 { workspace.drag(from: pt(150, 140), to: pt(150, 140 + Double(step)), modifiers: .option) }
        workspace.endDrag()
        let copy = try #require(workspace.selectedNodeIDs.last)
        #expect(copy == "node-11")
        #expect(workspace.nodeCount == 11)
    }

    @Test func aSecondOptionDragIsASecondStep() {
        var workspace = Self.cardsWithA()
        workspace.gesture(.move, pt(150, 140), pt(150, 240), .option)
        workspace.gesture(.move, pt(150, 240), pt(150, 340), .option)
        #expect(workspace.history.undo.count == 2)
        #expect(Self.named("A", workspace).count == 3)
        workspace.undo()
        #expect(Self.named("A", workspace).count == 2)
    }

    @Test func anOptionClickWithoutMovingCopiesNothing() {
        var workspace = Self.cardsWithA()
        workspace.gesture(.move, pt(150, 140), pt(150, 140), .option)
        #expect(workspace.history.undo.isEmpty)
        #expect(Self.named("A", workspace).count == 1)
    }

    @Test func withoutABuiltDuplicateOptionDragStillMoves() {
        var workspace = DesignFixtures.cards
        workspace.selectItem("node-2")
        workspace.gesture(.move, pt(150, 140), pt(150, 240), .option)
        #expect(workspace.frame("node-2") == rc(100, 200, 100, 80))
        #expect(workspace.undoActionName == "Undo Move")
    }
}
