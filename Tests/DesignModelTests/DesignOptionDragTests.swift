// DesignOptionDragTests.swift: an Option-drag on a selected layer duplicates it
// and drags the copy as ONE "Duplicate" undo step (design-seams D0-3c). The copy's
// id is minted once at the press and kept on every step, so a long drag never
// burns ids; one Undo puts the tree back, and a second Option-drag is a second
// step. The copies are made once, at the first step, and later steps only move
// them (#6198). On services whose Duplicate isn't built, Option-drag stays a
// plain move. Runs on Linux and macOS.
@testable import DesignModel
import Synchronization
import Testing

/// The live Duplicate, counting its calls.
private final class CountingDuplicating: LayerDuplicating {
    let calls = Mutex(0)
    func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? { LiveDuplicating().duplicateHelp(ids, on: page) }
    func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                   mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        calls.withLock { $0 += 1 }
        return try LiveDuplicating().duplicate(ids, offset: offset, on: page, mint: &mint)
    }
    func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode {
        LiveDuplicating().copySubtree(node, mint: &mint)
    }
}

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

    /// Twenty steps duplicate once: a step moves the copies its first step made, never copies again (#6198).
    @Test func twentyStepsDuplicateOnce() throws {
        var workspace = Self.cardsWithA()
        let counting = CountingDuplicating()
        workspace.services.duplicating = counting
        for step in 1...20 {
            workspace.drag(from: pt(150, 140), to: pt(150 + Double(step), 140 + Double(step) * 5), modifiers: .option)
        }
        workspace.endDrag()
        #expect(counting.calls.withLock { $0 } == 1)
        let copy = try #require(Self.named("A", workspace).first { $0.id != "node-2" })
        #expect(copy.frame == rc(120, 200, 100, 80))
        #expect(workspace.undoActionName == "Undo Duplicate")
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
        var services = DesignServices.live
        services.duplicating = NotBuilt("Duplicate")
        workspace.useServices(services)
        workspace.selectItem("node-2")
        workspace.gesture(.move, pt(150, 140), pt(150, 240), .option)
        #expect(workspace.frame("node-2") == rc(100, 200, 100, 80))
        #expect(workspace.undoActionName == "Undo Move")
    }
}
