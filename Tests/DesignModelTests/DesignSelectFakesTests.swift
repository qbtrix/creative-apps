// DesignSelectFakesTests.swift: the select-area fakes (marquee, transform, align
// and distribute, framing) and the shared fake helpers on a `cards`-shaped tree
// built here, every layer inside the Desktop frame so a fake that acts only at
// the top level fails. Runs on Linux and macOS.
@testable import DesignModel
import Testing

/// Blueprint 4's `cards`: Desktop holding A, B, C, Title, Pair (E1, E2), Locked and Hidden.
private func cards(hidingPair: Bool = false) -> DesignPage {
    let pair = DesignNode(
        id: "pair", name: "Pair", kind: .group, frame: rc(900, 400, 300, 100),
        children: [
            DesignNode(id: "e1", name: "E1", kind: .ellipse, frame: rc(900, 400, 100, 100)),
            DesignNode(id: "e2", name: "E2", kind: .ellipse, frame: rc(1100, 400, 100, 100)),
        ], isHidden: hidingPair)
    let desktop = DesignNode(
        id: "desktop", name: "Desktop", kind: .frame, frame: rc(0, 0, 1440, 1024),
        children: [
            DesignNode(id: "a", name: "A", kind: .rectangle, frame: rc(100, 100, 100, 80)),
            DesignNode(id: "b", name: "B", kind: .rectangle, frame: rc(300, 140, 200, 80)),
            DesignNode(id: "c", name: "C", kind: .rectangle, frame: rc(700, 100, 100, 120)),
            DesignNode(id: "title", name: "Title", kind: .text, frame: rc(100, 40, 200, 32)),
            pair,
            DesignNode(id: "locked", name: "Locked", kind: .rectangle, frame: rc(400, 600, 100, 100), isLocked: true),
            DesignNode(id: "hidden", name: "Hidden", kind: .rectangle, frame: rc(600, 600, 100, 100), isHidden: true),
        ])
    return DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [desktop])
}

private func frame(_ id: String, _ nodes: [DesignNode]) -> DesignRect? { nodes.node(id)?.frame }

@Suite struct DesignSelectFakesTests {
    let page = cards()

    @Test func marqueePicksWhatItTouchesInsideItsFrame() {
        let marquee = FakeMarquee()
        #expect(marquee.layers(touching: DesignRect(from: pt(80, 80), to: pt(520, 240)), in: "desktop", on: page) == ["a", "b"])
        #expect(marquee.layers(touching: DesignRect(from: pt(380, 580), to: pt(720, 720)), in: "desktop", on: page) == [])
        // From outside every frame it picks at the top level: Desktop, never its children.
        #expect(marquee.layers(touching: rc(80, 80, 440, 160), in: nil, on: page) == ["desktop"])
    }

    @Test func marqueeNeverPicksInsideAHiddenLayer() {
        let marquee = FakeMarquee()
        let overE1 = rc(890, 390, 50, 50)
        #expect(marquee.layers(touching: overE1, in: "pair", on: page) == ["e1"])
        #expect(marquee.layers(touching: overE1, in: "pair", on: cards(hidingPair: true)) == [])
        #expect(marquee.layers(touching: overE1, in: "nowhere", on: page) == [])
    }

    @Test func moveShiftsEachLayerWithItsSubtreeAsOneRun() throws {
        let edit = try FakeTransforming().move(["a", "pair"], by: pt(40, 0), on: page)
        #expect(edit.name == "Move")
        #expect(edit.coalescingKey == DesignEdit.runKey("move", ["a", "pair"]))
        #expect(edit.selection == ["a", "pair"])
        #expect(frame("a", edit.nodes) == rc(140, 100, 100, 80))
        #expect(frame("pair", edit.nodes) == rc(940, 400, 300, 100))
        #expect(frame("e1", edit.nodes) == rc(940, 400, 100, 100))
        #expect(frame("e2", edit.nodes) == rc(1140, 400, 100, 100))
        #expect(frame("b", edit.nodes) == rc(300, 140, 200, 80))
        #expect(throws: DesignRefusal.unchanged) { try FakeTransforming().move(["a"], by: pt(0, 0), on: page) }
    }

    @Test func resizeNudgeAndDeleteNameTheirSteps() throws {
        let fake = FakeTransforming()
        let resize = try fake.resize(["a", "b"], handle: .bottomRight, by: pt(20, 20), modifiers: [], on: page)
        #expect(resize.name == "Resize")
        #expect(frame("a", resize.nodes) == rc(100, 100, 120, 100))
        #expect(frame("b", resize.nodes) == rc(300, 140, 220, 100))

        let small = try fake.nudge(["a", "b"], .right, large: false, on: page)
        #expect(small.name == "Nudge")
        #expect(small.coalescingKey == "nudge-a,b")
        #expect(frame("a", small.nodes)?.x == 101)
        let large = try fake.nudge(["a", "b"], .up, large: true, on: page)
        #expect(frame("b", large.nodes)?.y == 130)

        let delete = try fake.delete(["a", "e1"], on: page)
        #expect(delete.name == "Delete")
        #expect(delete.selection.isEmpty)
        #expect(delete.coalescingKey == nil)
        #expect(delete.nodes.node("a") == nil && delete.nodes.node("e1") == nil)
        #expect(delete.nodes.node("e2") != nil)
        #expect(throws: DesignRefusal.nothingSelected) { try fake.delete([], on: page) }
    }

    @Test func transformHelpFollowsTheSelection() {
        #expect(FakeTransforming().transformHelp(["a"], on: page) == nil)
        #expect(FakeTransforming().transformHelp([], on: page) == "Select a layer first.")
    }

    @Test func alignTopLinesUpTheSelection() throws {
        let edit = try FakeAligning().align(.top, ["a", "b", "c"], on: page)
        #expect(edit.name == "Align Top")
        #expect(edit.coalescingKey == nil)
        #expect(["a", "b", "c"].map { frame($0, edit.nodes)?.y } == [100, 100, 100])
        #expect(frame("b", edit.nodes)?.x == 300)
        #expect(throws: DesignRefusal.unchanged) { try FakeAligning().align(.top, ["a", "c"], on: page) }
    }

    @Test func distributeLeavesEqualGaps() throws {
        let row = DesignNode(
            id: "row", name: "Row", kind: .frame, frame: rc(0, 0, 300, 100),
            children: [
                DesignNode(id: "l", name: "L", kind: .rectangle, frame: rc(0, 0, 20, 20)),
                DesignNode(id: "m", name: "M", kind: .rectangle, frame: rc(30, 0, 40, 20)),
                DesignNode(id: "r", name: "R", kind: .rectangle, frame: rc(280, 0, 20, 20)),
            ])
        let strip = DesignPage(id: "page-1", name: "Strip", frameWidth: 300, frameHeight: 100, nodes: [row])
        let fake = FakeAligning()
        #expect(fake.distributeHelp(.horizontal, ["r", "m", "l"], on: strip) == nil)
        let edit = try fake.distribute(.horizontal, ["r", "m", "l"], on: strip)
        #expect(edit.name == "Distribute Horizontally")
        let (l, m, r) = (frame("l", edit.nodes), frame("m", edit.nodes), frame("r", edit.nodes))
        #expect(l == rc(0, 0, 20, 20) && r == rc(280, 0, 20, 20))
        let gaps = [(m?.x ?? 0) - 20, 280 - (m?.maxX ?? 0)]
        #expect(abs(gaps[0] - gaps[1]) < 1e-9)
        #expect(abs(gaps[0] - 110) < 1e-9)
    }

    @Test func distributeNeedsThreeLayers() {
        let fake = FakeAligning()
        #expect(fake.distributeHelp(.horizontal, ["a", "b"], on: page) == "Select three or more layers to distribute.")
        #expect(throws: DesignRefusal.tooFewToDistribute) { try fake.distribute(.horizontal, ["a", "b"], on: page) }
    }

    @Test func framingShowsTheSelectionsBounds() {
        let fake = FakeFraming()
        #expect(fake.rectToShow(["c"], on: page) == rc(700, 100, 100, 120))
        #expect(fake.framingHelp(["c"], on: page) == nil)
        #expect(fake.rectToShow(["a", "c"], on: page) == rc(100, 100, 700, 120))
        #expect(fake.rectToShow([], on: page) == nil)
        #expect(fake.framingHelp([], on: page) == "Select a layer first.")
    }

    @Test func sharedHelpersFindParentsAndKeepTheHelpLaw() throws {
        #expect(try fakeSharedParent(["a", "b"], page) == "desktop")
        #expect(try fakeSharedParent(["desktop"], page) == nil)
        #expect(throws: DesignRefusal.notSameParent) { try fakeSharedParent(["a", "e1"], page) }
        let reversed = fakeSiblings("pair", page.nodes) { $0.reverse() }
        #expect(reversed.node("pair")?.children.map(\.id) == ["e2", "e1"])
        #expect(fakeHelp { () throws(DesignRefusal) in throw .unchanged } == nil)
        #expect(fakeHelp { () throws(DesignRefusal) in throw .notSameParent } == "Select layers that share a parent.")
    }
}
