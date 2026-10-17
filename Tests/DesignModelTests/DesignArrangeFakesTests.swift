// DesignArrangeFakesTests.swift: the arrange-area fakes on DesignFixtures.cards (every layer
// inside Desktop), and MJ2 on `.fake` and `.live`. Runs on Linux and macOS.
@testable import DesignModel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// cards: Desktop node-1 holds A node-2, B node-3, C node-4, Title node-5, Pair node-6 (E1 node-7,
// E2 node-8), Locked node-9 and Hidden node-10.
private let (desktop, a, b, c, title, pair, e1, e2) =
    ("node-1", "node-2", "node-3", "node-4", "node-5", "node-6", "node-7", "node-8")

private func cardsPage() -> DesignPage { DesignFixtures.cards.selectedPage ?? DesignPage(id: "", name: "", frameWidth: 1, frameHeight: 1) }

private func freshMint() -> DesignIDMint { DesignIDMint(taken: Set((1...10).map { "node-\($0)" }), after: 10) }

private func children(_ id: String, _ nodes: [DesignNode]) -> [DesignNode] { nodes.node(id)?.children ?? [] }

private func allIDs(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + allIDs($0.children) } }

@Suite struct DesignArrangeFakesTests {
    let page = cardsPage()
    @Test func duplicateSitsRightAboveItsOriginalUnlockedWithFreshIDs() throws {
        var locked = page
        _ = locked.nodes.update(a) { $0.isLocked = true }
        var mint = freshMint()
        let edit = try FakeDuplicating().duplicate([a], offset: pt(10, 10), on: locked, mint: &mint)
        #expect(edit.name == "Duplicate")
        let level = children(desktop, edit.nodes)
        #expect(level.map(\.name).prefix(2) == ["A", "A"])
        let copy = try #require(level.dropFirst().first)
        #expect(edit.selection == [copy.id])
        #expect(copy.id == "node-11" && copy.frame == rc(110, 110, 100, 80) && !copy.isLocked)
        let pairCopy = FakeDuplicating().copySubtree(try #require(page.nodes.node(pair)), mint: &mint)
        #expect(Set(allIDs([pairCopy])).isDisjoint(with: allIDs(page.nodes)))
        #expect(pairCopy.children.map(\.frame) == children(pair, page.nodes).map(\.frame))
    }
    @Test func groupKeepsEveryLeafFrameAndRefusesMixedParents() throws {
        var mint = freshMint()
        let edit = try FakeGrouping().group([a, b], on: page, mint: &mint)
        #expect(edit.name == "Group" && edit.selection == ["node-11"])
        let group = try #require(edit.nodes.node("node-11"))
        #expect(group.name == "Group" && group.kind == .group && group.frame == rc(100, 100, 400, 120))
        #expect(group.children.map(\.id) == [a, b])
        #expect(group.children.map(\.frame) == [rc(100, 100, 100, 80), rc(300, 140, 200, 80)])
        #expect(throws: DesignRefusal.notSameParent) { try FakeGrouping().group([a, e1], on: page, mint: &mint) }
        #expect(FakeGrouping().groupHelp([a, e1], on: page) == "Select layers that share a parent.")
    }
    @Test func ungroupPutsTheChildrenInTheGroupsPlace() throws {
        let edit = try FakeGrouping().ungroup([pair], on: page)
        #expect(edit.name == "Ungroup" && edit.selection == [e1, e2])
        #expect(children(desktop, edit.nodes).map(\.id) == [a, b, c, title, e1, e2, "node-9", "node-10"])
        #expect(throws: DesignRefusal.notAGroup(a)) { try FakeGrouping().ungroup([a], on: page) }
    }
    @Test func pasteLandsInTheParentItCameFromOffsetWithFreshIDs() throws {
        let clipboard = FakeClipboard()
        let data = try clipboard.encode([pair], on: page)
        #expect(clipboard.pasteHelp(data) == nil)
        var mint = freshMint()
        let edit = try clipboard.paste(data, into: nil, on: page, mint: &mint)
        #expect(edit.name == "Paste")
        let pasted = try #require(children(desktop, edit.nodes).last)
        #expect(edit.selection == [pasted.id] && pasted.name == "Pair")
        #expect(pasted.frame == rc(910, 410, 300, 100) && pasted.children.count == 2)
        #expect(pasted.children.map(\.frame) == [rc(910, 410, 100, 100), rc(1110, 410, 100, 100)])
        #expect(Set(allIDs([pasted])).isDisjoint(with: allIDs(page.nodes)))
        #expect(clipboard.pasteHelp(Data("hello".utf8)) == "The pasteboard holds no Design layers.")
        #expect(clipboard.pasteHelp(nil) == "The pasteboard holds no Design layers.")
    }
    @Test func orderingMovesIntoAGroupAndSendsToBack() throws {
        let moved = try FakeOrdering().move(title, into: pair, at: 2, on: page)
        #expect(moved.name == "Move Layer")
        #expect(children(pair, moved.nodes).map(\.id) == [e1, e2, title])
        #expect(!children(desktop, moved.nodes).contains { $0.id == title })
        #expect(throws: DesignRefusal.notAContainer(a)) { try FakeOrdering().move(b, into: a, at: 0, on: page) }
        let back = try FakeOrdering().arrange(.sendToBack, [b], on: page)
        #expect(back.name == "Send to Back")
        #expect(children(desktop, back.nodes).map(\.id).prefix(2) == [b, a])
    }
    @Test func setFrameSetsEachSelectedLayer() throws {
        let edit = try FakeStyling().setFrame(.x, to: 300, [a, b], on: page)
        #expect(edit.name == "Change Frame" && edit.coalescingKey == DesignEdit.runKey("frame", [a, b]))
        #expect(edit.nodes.node(a)?.frame == rc(300, 100, 100, 80))
        #expect(edit.nodes.node(b)?.frame == rc(300, 140, 200, 80))
    }
    @Test func fakeFilingRoundTripsThePages() throws {
        let filing = FakeFiling()
        let document = DesignDocument(pages: [page])
        #expect(try filing.decode(filing.encode(document)) == document)
        #expect(throws: DesignFileError.unreadable) { try filing.decode(Data("hello".utf8)) }
    }
    /// MJ2: marquee, Align Top, duplicate, group, copy and paste on `.fake`, each a named edit; on `.live` the stubs say what isn't built.
    @Test func testFakesWalk() throws {
        let fake = DesignServices.fake
        let marquee = DesignRect(from: pt(80, 80), to: pt(520, 240))
        #expect(fake.marquee.layers(touching: marquee, in: desktop, on: page) == [a, b])
        var current = page
        var mint = freshMint()
        let aligned = try fake.aligning.align(.top, [a, b, c], on: current)
        #expect(aligned.name == "Align Top")
        current.nodes = aligned.nodes
        #expect([a, b, c].map { current.nodes.node($0)?.frame.y } == [100, 100, 100])
        let duplicated = try fake.duplicating.duplicate([a], offset: pt(10, 10), on: current, mint: &mint)
        #expect(duplicated.name == "Duplicate")
        current.nodes = duplicated.nodes
        let grouped = try fake.grouping.group([a, b], on: current, mint: &mint)
        #expect(grouped.name == "Group")
        current.nodes = grouped.nodes
        let pasted = try fake.clipboard.paste(fake.clipboard.encode([pair], on: current), into: nil, on: current, mint: &mint)
        #expect(pasted.name == "Paste" && children(desktop, pasted.nodes).last?.children.count == 2)
        let live = DesignServices.live
        #expect(live.marquee is LiveMarquee && live.aligning is LiveAligning)
        #expect(throws: DesignRefusal.notBuilt("Duplicate")) {
            try live.duplicating.duplicate([a], offset: pt(10, 10), on: page, mint: &mint)
        }
        #expect(throws: DesignRefusal.notBuilt("Group")) { try live.grouping.group([a, b], on: page, mint: &mint) }
        #expect(throws: DesignRefusal.notBuilt("Copy and paste")) { try live.clipboard.encode([pair], on: page) }
        #expect(throws: DesignRefusal.notBuilt("Copy and paste")) {
            try live.clipboard.paste(Data("hello".utf8), into: nil, on: page, mint: &mint)
        }
        #expect(DesignServices.fake != live && fake.export is LiveExport && fake.export.exportHelp([a], on: page) == nil)
    }
}
